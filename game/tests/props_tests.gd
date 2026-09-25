extends RefCounted
## Suíte isolada: godot --headless --path game --script res://tests/run_suite.gd -- --suite props

const C = preload("res://sim/sim_const.gd")
const MatterGrid = preload("res://sim/matter_grid.gd")
const Props = preload("res://sim/props.gd")


static func run_all() -> int:
	var tests := {
		"objetos autorados assentam e ficam fora da matéria": _test_settle,
		"caixa rompe vitrine e continua com energia menor": _test_glass,
		"caixa rompe divisória com energia suficiente": _test_drywall,
		"concreto quica e acumula dano": _test_concrete,
		"segundo impacto rompe concreto danificado": _test_accumulation,
		"núcleo nunca rompe nem permite passagem": _test_core,
		"prop_hit respeita autor, máscara e novo arremesso": _test_hits,
		"alvo estreito é atingido durante a varredura": _test_target_sweep,
		"alvos simultâneos seguem ordem de id": _test_target_order,
		"objeto cai quando perde o chão": _test_lost_floor,
		"varredura a 40 px/tick nos quatro sentidos": _test_sweep,
		"agarrar, carregar, soltar e consultar objetos": _test_grab,
		"golpe lança e quebra emite evento uma vez": _test_strike,
		"impacto e acerto também despedaçam objeto": _test_breaks,
		"velocidade baixa encerra arremesso": _test_slow,
		"queda arremessada tem teto e termina fora do mundo": _test_fall_limit,
		"quatro blast zones quebram uma vez, inclusive durante movimento": _test_blast_zones,
		"varredura limita trabalho mesmo com velocidade extrema": _test_move_guard,
		"arremesso comum preserva laje e ainda rompe vitrine": _test_street_throw,
		"energia tangencial não paga dano nem HP no quique": _test_normal_bounce,
		"ruptura escala normal e absorve tangente nos dois eixos": _test_normal_break,
		"ápice lento permanece arremessado até pousar": _test_apex,
		"entulho desenterra para cima ou lados alternados": _test_unstuck,
		"duas execuções e snapshot em voo coincidem": _test_determinism,
		"snapshot preserva quebra pendente e não compartilha estado": _test_pending_snapshot,
	}
	var failed := 0
	for name in tests:
		var ret = tests[name].call()
		var err: String = ret if typeof(ret) == TYPE_STRING else "teste abortou (erro de script)"
		print(("  ok    " if err == "" else "  FALHA ") + name + ("" if err == "" else ": " + err))
		if err != "":
			failed += 1
	print("RESULTADO: %s (%d falha(s))" % ["PASSOU" if failed == 0 else "FALHOU", failed])
	return failed


static func _world() -> Dictionary:
	var grid := MatterGrid.new()
	grid.build_test_district()
	var sim := Props.new()
	sim.setup_test_district()
	return {"grid": grid, "sim": sim}


static func _single(w: Dictionary, kind: int, x: int, y: int) -> Dictionary:
	for p in w.sim.props:
		if p.kind == kind:
			p.x = x * C.SUB
			p.y = y * C.SUB
			w.sim.props = [p]
			return p
	return {}


static func _embedded(w: Dictionary) -> bool:
	for p in w.sim.props:
		if p.state == Props.HELD or p.state == Props.BROKEN:
			continue
		var b: Array = w.sim.box_of(p)
		if w.grid.any_solid_in_rect(b[0], b[1], b[2], b[3]):
			return true
	return false


static func _count(events: Array, kind: String) -> int:
	var n := 0
	for e in events:
		if e.kind == kind:
			n += 1
	return n


static func _test_settle() -> String:
	var w := _world()
	if w.sim.props.size() < 4 or w.sim.props.size() > 8:
		return "quantidade autorada fora do pacote"
	for tick in 60:
		if not w.sim.step(w.grid, []).is_empty() or _embedded(w):
			return "repouso gerou evento ou penetração no tick %d" % tick
	var positions: Array = []
	for p in w.sim.props:
		var expected_y: int = (272 if p.id >= 4 else 416) * C.SUB
		if p.y != expected_y or p.vx != 0 or p.vy != 0 or p.state != Props.FREE:
			return "objeto %d não assentou" % p.id
		positions.append([p.x, p.y, p.hp])
	for tick in 60:
		w.sim.step(w.grid, [])
		for i in w.sim.props.size():
			var p: Dictionary = w.sim.props[i]
			if [p.x, p.y, p.hp] != positions[i] or _embedded(w):
				return "repouso não permaneceu estável"
	return ""


static func _test_glass() -> String:
	var w := _world()
	var p := _single(w, 0, 328, 380)
	w.sim.throw(p.id, 10 * C.SUB, 0, 0)
	var broken := 0
	for tick in 8:
		var events: Array = w.sim.step(w.grid, [])
		for e in events:
			if e.kind == "break":
				broken += 1
				if e.axis != 0 or e.dir != 1 or e.e < e.r or e.cells.size() != e.mats.size():
					return "evento de ruptura inválido"
				for m in e.mats:
					if m != C.M_GLASS:
						return "rompeu material inesperado"
		if _embedded(w):
			return "caixa entrou em matéria"
	if broken < 2 or p.x <= 376 * C.SUB or p.vx <= 0 or p.vx >= 10 * C.SUB:
		return "não atravessou as duas colunas perdendo energia"
	if p.state == Props.BROKEN or p.hp >= Props.KINDS[0].hp:
		return "durabilidade não sofreu desgaste ou caixa quebrou cedo"
	if w.grid.get_mat(44, 40) != C.M_GLASS:
		return "ruptura excedeu a altura da caixa"
	return ""


static func _test_drywall() -> String:
	var w := _world()
	var p := _single(w, 0, 572, 380)
	w.sim.throw(p.id, 10 * C.SUB, 0, 0)
	var breaks := 0
	for tick in 6:
		breaks += _count(w.sim.step(w.grid, []), "break")
		if _embedded(w):
			return "caixa entrou na divisória"
	if breaks < 2 or p.x <= 616 * C.SUB or p.state == Props.BROKEN:
		return "caixa não atravessou a divisória"
	return ""


static func _test_concrete() -> String:
	var w := _world()
	var p := _single(w, 0, 1012, 380)
	var cell: int = w.grid.index(128, 46)
	w.sim.throw(p.id, 896, 0, 0)
	for tick in 8:
		var events: Array = w.sim.step(w.grid, [])
		if _embedded(w):
			return "penetração no concreto"
		if _count(events, "prop_bounce") > 0:
			if p.vx >= 0 or w.grid.mat[cell] != C.M_CONCRETE or w.grid.hp[cell] >= C.MAT_HP[C.M_CONCRETE]:
				return "não quicou ou não acumulou dano"
			return ""
	return "nenhum quique"


static func _test_accumulation() -> String:
	var w := _world()
	var p := _single(w, 0, 1016, 384)
	var cells := PackedInt32Array([w.grid.index(128, 46), w.grid.index(128, 47)])
	w.sim.throw(p.id, 6 * C.SUB, 0, 0)
	var events: Array = []
	if w.sim._impact(w.grid, p, 0, cells, events) or p.vx >= 0:
		return "primeiro impacto deveria quicar (E=540 < R=600)"
	if w.grid.hp[cells[0]] != 30 or w.grid.hp[cells[1]] != 30:
		return "dano não foi distribuído igualmente"
	w.sim.throw(p.id, 6 * C.SUB, 0, 0)
	if not w.sim._impact(w.grid, p, 0, cells, events):
		return "segundo impacto deveria romper (E=540 >= R=60)"
	return ""


static func _test_core() -> String:
	var w := _world()
	var p := _single(w, 2, 1200, 432)
	# Retira só a laje: isola a proteção do núcleo da vida útil do objeto.
	w.grid.destroy(w.grid.cells_in_rect(1184 * C.SUB, 416 * C.SUB, 1216 * C.SUB, 432 * C.SUB))
	p.hp = 100000
	w.sim.throw(p.id, 0, 40 * C.SUB, 0)
	var bounces := 0
	for tick in 60:
		bounces += _count(w.sim.step(w.grid, []), "prop_bounce")
		if _embedded(w) or p.y > 432 * C.SUB:
			return "objeto atravessou núcleo"
	for cy in range(54, C.GRID_H):
		for cx in C.GRID_W:
			if w.grid.get_mat(cx, cy) != C.M_CORE:
				return "núcleo foi destruído"
	return "" if bounces > 0 else "não houve impacto no núcleo"


static func _test_hits() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 380)
	var targets := [{"id": 0, "box": [0, 0, 240 * C.SUB, 416 * C.SUB]},
		{"id": 1, "box": [0, 0, 240 * C.SUB, 416 * C.SUB]}]
	w.sim.throw(p.id, 8 * C.SUB, 0, 0)
	var hits := 0
	for tick in 8:
		for e in w.sim.step(w.grid, targets):
			if e.kind == "prop_hit":
				hits += 1
				if e.target != 1 or e.thrower != 0 or e.dmg != 14 or e.vx != 8 * C.SUB:
					return "alvo, autor, dano ou velocidade do evento inválidos"
		if tick == 0 and (p.vx >= 0 or p.hp != Props.KINDS[0].hp - Props.HIT_HP):
			return "acerto não rebateu ou não gastou HP"
	if hits != 1 or p.hit_mask != 2:
		return "não respeitou um acerto por alvo"
	w.sim.throw(p.id, 8 * C.SUB, 0, 0)
	if _count(w.sim.step(w.grid, targets), "prop_hit") != 1:
		return "novo arremesso não limpou máscara"
	return ""


static func _test_target_sweep() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 380)
	w.sim.throw(p.id, 40 * C.SUB, 0, 0)
	var events: Array = w.sim.step(w.grid, [{"id": 1, "box": [120 * C.SUB, 340 * C.SUB, 121 * C.SUB, 400 * C.SUB]}])
	if _count(events, "prop_hit") != 1 or p.vx >= 0 or p.x >= 121 * C.SUB:
		return "atravessou alvo estreito sem rebater"
	return ""


static func _test_target_order() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 380)
	p.hp = Props.HIT_HP
	var b := [0, 0, 200 * C.SUB, 400 * C.SUB]
	var targets := [{"id": 3, "box": b}, {"id": 1, "box": b}]
	w.sim.throw(p.id, 8 * C.SUB, 0, 0)
	var events: Array = w.sim.step(w.grid, targets)
	if events.is_empty() or events[0].kind != "prop_hit" or events[0].target != 1 or targets[0].id != 3:
		return "ordem instável ou array do integrador alterado"
	return ""


static func _test_lost_floor() -> String:
	var w := _world()
	var p := _single(w, 0, 480, 272)
	w.sim.step(w.grid, [])
	w.grid.destroy(w.grid.cells_in_rect(464 * C.SUB, 272 * C.SUB, 496 * C.SUB, 288 * C.SUB))
	for tick in 20:
		w.sim.step(w.grid, [])
		if _embedded(w):
			return "penetração durante queda"
	if p.y <= 288 * C.SUB or p.vy <= 0:
		return "objeto permaneceu suspenso"
	return ""


static func _test_sweep() -> String:
	var cases := [[328, 380, 40, 0], [400, 380, -40, 0], [1200, 380, 0, 40],
		[480, 340, 0, -40], [980, 380, 40, 0], [-24, 380, 40, 0]]
	for a in cases:
		var w := _world()
		var p := _single(w, 0, a[0], a[1])
		# Vida alta mantém a geometria sob teste após impactos fortes.
		p.hp = 100000
		w.sim.throw(p.id, a[2] * C.SUB, a[3] * C.SUB, 0)
		for tick in 45:
			w.sim.step(w.grid, [])
			if _embedded(w):
				return "caso %s, tick %d: dentro de matéria" % [a, tick]
	return ""


static func _test_grab() -> String:
	var w := _world()
	var bounds := [0, 0, C.WORLD_W * C.SUB, C.WORLD_H * C.SUB]
	if w.sim.find_grabbable(bounds[0], bounds[1], bounds[2], bounds[3]) != 0:
		return "não escolheu menor id"
	if w.sim.in_rect(0, 0, 0, 0) != [] or w.sim.find_grabbable(-100, -100, -1, -1) != -1:
		return "consulta vazia inválida"
	w.sim.grab(0, 2)
	w.sim.hold_at(0, 100 * C.SUB, 380 * C.SUB)
	var p: Dictionary = w.sim.props[0]
	var held: Dictionary = p.duplicate(true)
	w.sim.strike(0, 1000, 1000, 1, 999)
	w.sim.grab(0, 3)
	for tick in 10:
		if not w.sim.step(w.grid, [{"id": 1, "box": bounds}]).is_empty():
			return "segurado emitiu evento"
	if p != held or w.sim.in_rect(bounds[0], bounds[1], bounds[2], bounds[3]).has(0):
		return "segurado sofreu física/golpe ou ficou disponível"
	w.sim.drop(0)
	if p.state != Props.FREE or p.holder != -1 or p.vx != 0 or p.vy != 0:
		return "drop não soltou sem velocidade"
	w.sim.hold_at(0, 0, 0)
	if p.x != held.x or p.y != held.y:
		return "hold_at moveu objeto livre"
	w.sim.grab(0, 2)
	w.sim.throw(0, 1000, -1000, 2)
	if p.state != Props.THROWN or p.holder != -1 or p.thrower != 2 or p.vx != 1000:
		return "throw não liberou objeto segurado"
	if w.sim.throw_mul(3) >= w.sim.throw_mul(1) or w.sim.throw_mul(1) >= w.sim.throw_mul(0):
		return "multiplicador não respeita peso"
	return ""


static func _test_strike() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 380)
	w.sim.strike(p.id, 4 * C.SUB, -C.SUB, 2, 5)
	if p.state != Props.THROWN or p.thrower != 2 or p.hp != Props.KINDS[0].hp - 5:
		return "golpe não lançou/desgastou objeto"
	w.sim.strike(p.id, 1000, 0, 2, 999)
	if p.state != Props.BROKEN or w.sim.find_grabbable(0, 0, 200 * C.SUB, 400 * C.SUB) != -1:
		return "objeto destruído ainda disponível"
	w.sim.throw(p.id, 1000, 0, 0)
	w.sim.grab(p.id, 0)
	w.sim.drop(p.id)
	w.sim.strike(p.id, 1000, 0, 0, 999)
	var events: Array = w.sim.step(w.grid, [])
	if _count(events, "prop_break") != 1 or events[0].kind_id != 0 or p.state != Props.BROKEN:
		return "destruição duplicada ou objeto ressuscitou"
	return "" if w.sim.step(w.grid, []).is_empty() else "repetiu quebra"


static func _test_breaks() -> String:
	for hit_target in [false, true]:
		var w := _world()
		var p := _single(w, 0, 1016, 380)
		p.hp = 1
		w.sim.throw(p.id, 4 * C.SUB, 0, 0)
		var targets: Array = [{"id": 1, "box": [1000 * C.SUB, 360 * C.SUB, 1024 * C.SUB, 400 * C.SUB]}] if hit_target else []
		var events: Array = w.sim.step(w.grid, targets)
		if _count(events, "prop_break") != 1 or p.state != Props.BROKEN:
			return "impacto/acerto não destruiu objeto sem HP"
		if not w.sim.step(w.grid, targets).is_empty():
			return "objeto destruído ainda colide/acerta"
	return ""


static func _test_slow() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 416)
	w.sim.throw(p.id, Props.STOP_SPEED - 1, 0, 0)
	if not w.sim.step(w.grid, [{"id": 1, "box": [0, 0, 200 * C.SUB, 416 * C.SUB]}]).is_empty():
		return "objeto lento acertou lutador ou danificou chão"
	if p.state != Props.FREE:
		return "arremesso lento não terminou"
	w.sim.throw(p.id, 4 * C.SUB, 0, 0)
	for tick in 30:
		w.sim.step(w.grid, [])
	if p.state != Props.FREE or p.vx != 0 or p.vy != 0:
		return "atrito não encerrou deslizamento"
	return ""


static func _test_fall_limit() -> String:
	for state in [Props.FREE, Props.THROWN]:
		var w := _world()
		var p := _single(w, 0, -40, 0)
		p.state = state
		p.vy = 100 * C.SUB
		var limit: int = Props.MAX_FALL if state == Props.FREE else Props.MAX_THROWN_FALL
		var breaks := 0
		for tick in 100:
			breaks += _count(w.sim.step(w.grid, []), "prop_break")
			if p.vy > limit:
				return "queda excedeu teto no estado %d" % state
			if tick == 0 and (p.vy != limit or p.y != limit):
				return "teto não foi aplicado antes de mover"
		if p.state != Props.BROKEN or breaks != 1 or p.vx != 0 or p.vy != 0:
			return "objeto fora do mundo não terminou a queda uma única vez"
	return ""


static func _test_blast_zones() -> String:
	for side in 4:
		for moving in [false, true]:
			var w := _world()
			w.grid = MatterGrid.new()
			var p := _single(w, 0, 100, 100)
			var offset: int = -1 if moving else 1
			match side:
				0: p.x = C.BLAST_LEFT - offset
				1: p.x = C.BLAST_RIGHT + offset
				2: p.y = C.BLAST_TOP - offset
				3: p.y = C.BLAST_BOTTOM + p.h + offset
			var vx: int = (-C.SUB if side == 0 else C.SUB) if side < 2 else 0
			var vy: int = (-C.SUB if side == 2 else C.SUB) if side >= 2 else 0
			w.sim.throw(p.id, vx if moving else 0, vy if moving else 0, 0)
			var events: Array = w.sim.step(w.grid, [])
			if p.state != Props.BROKEN or _count(events, "prop_break") != 1:
				return "blast zone %d não removeu objeto (movendo=%s)" % [side, moving]
			var e: Dictionary = events[0]
			if e.get("lost", 0) != 1 or e.prop != p.id or e.kind_id != p.kind or e.x != p.x or e.y != p.y:
				return "evento de perda incompleto"
			if not w.sim.step(w.grid, []).is_empty():
				return "perda repetiu evento"
	return ""


static func _test_move_guard() -> String:
	for axis in 2:
		for direction in [-1, 1]:
			var w := _world()
			w.grid = MatterGrid.new()
			var p := _single(w, 0, 600, 200)
			var initial: int = p.x if axis == 0 else p.y
			var events: Array = []
			w.sim._move_axis(w.grid, p, axis, direction * 10000 * C.SUB, [], events)
			var final_pos: int = p.x if axis == 0 else p.y
			if final_pos - initial != direction * 64 * C.MAX_STEP or not events.is_empty():
				return "varredura não parou em 64 subpassos no eixo %d" % axis
	return ""


static func _test_street_throw() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 376)
	w.sim.throw(p.id, 2600, -433, 0)
	var bounced := false
	for tick in 60:
		var events: Array = w.sim.step(w.grid, [])
		for e in events:
			if e.kind == "break" and e.mats.has(C.M_CONCRETE):
				return "arremesso comum rompeu concreto"
		if _embedded(w) or p.y > 416 * C.SUB:
			return "arremesso comum atravessou a laje"
		if _count(events, "prop_bounce") > 0:
			bounced = true
			break
	if not bounced or p.state == Props.BROKEN:
		return "caixa não sobreviveu ao quique na rua"
	for cx in C.GRID_W:
		for cy in [52, 53]:
			if w.grid.get_mat(cx, cy) != C.M_CONCRETE:
				return "laje perdeu células"
	w = _world()
	p = _single(w, 0, 328, 376)
	w.sim.throw(p.id, 2600, -433, 0)
	var glass_breaks := 0
	for tick in 8:
		for e in w.sim.step(w.grid, []):
			if e.kind == "break" and e.mats.has(C.M_GLASS):
				glass_breaks += 1
	if glass_breaks < 2 or p.x <= 376 * C.SUB or p.state == Props.BROKEN:
		return "mesmo arremesso não atravessou vitrine"
	return ""


static func _test_normal_bounce() -> String:
	for axis in 2:
		var w := _world()
		var p := _single(w, 0, 100, 380)
		var cells := PackedInt32Array([w.grid.index(128, 46), w.grid.index(128, 47)])
		w.sim.throw(p.id, 896 if axis == 0 else 2600, 2600 if axis == 0 else 896, 0)
		var events: Array = []
		var e := C.energy(p.mass, 896, 0)
		if w.sim._impact(w.grid, p, axis, cells, events):
			return "energia tangencial rompeu concreto"
		for cell in cells:
			if w.grid.mat[cell] != C.M_CONCRETE or w.grid.hp[cell] != C.MAT_HP[C.M_CONCRETE] - e / 2:
				return "dano acumulado não usou energia normal"
		if _count(events, "prop_bounce") != 1 or events[0].e != e or p.hp != Props.KINDS[0].hp - maxi(1, e / Props.IMPACT_HP_DIV):
			return "evento ou HP do quique não usou energia normal"
	return ""


static func _test_normal_break() -> String:
	for axis in 2:
		var w := _world()
		var p := _single(w, 0, 100, 380)
		var cells := PackedInt32Array([w.grid.index(44, 46), w.grid.index(44, 47)])
		w.sim.throw(p.id, 2600 if axis == 0 else -1800, -1800 if axis == 0 else 2600, 0)
		var events: Array = []
		var e := C.energy(p.mass, 2600, 0)
		var r := 2 * C.MAT_HP[C.M_GLASS]
		var absorb: int = C.MAT_ABSORB[C.M_GLASS]
		var ratio := C.isqrt(((e - r) * (1000 - absorb) / 1000) * 1048576 / e)
		var tangent_ratio := C.isqrt((1000 - absorb) * 1048576 / 1000)
		if not w.sim._impact(w.grid, p, axis, cells, events):
			return "energia normal suficiente não rompeu vidro"
		var vn: int = p.vx if axis == 0 else p.vy
		var vt: int = p.vy if axis == 0 else p.vx
		if vn != 2600 * ratio / 1024 or vt != -1800 * tangent_ratio / 1024 or events[0].e != e:
			return "ruptura misturou energia normal e tangencial"
	return ""


static func _test_apex() -> String:
	var w := _world()
	var p := _single(w, 0, 100, 376)
	w.sim.throw(p.id, 0, -Props.GRAVITY, 0)
	w.sim.step(w.grid, [])
	if p.vy != 0 or p.state != Props.THROWN or p.y != 376 * C.SUB:
		return "ápice sem apoio encerrou arremesso"
	var bounced := false
	for tick in 120:
		bounced = _count(w.sim.step(w.grid, []), "prop_bounce") > 0 or bounced
		if p.state == Props.FREE:
			return "" if bounced and w.sim._solid_below(w.grid, p) else "encerrou antes do impacto/pouso"
	return "não encerrou após pousar"


static func _test_unstuck() -> String:
	for state in [Props.FREE, Props.THROWN]:
		for escape in [0, -1, 1, 2]:
			var w := _world()
			w.grid = MatterGrid.new()
			var p := _single(w, 0, 160, 240)
			p.state = state
			# Escreve entulho sobre um objeto que já estava parado.
			if escape == 0:
				w.grid.fill(19, 28, 20, 29, C.M_BRICK)
			elif escape == 2:
				w.grid.fill(0, 0, C.GRID_W - 1, C.GRID_H - 1, C.M_CORE)
			else:
				w.grid.fill(19 if escape == -1 else 0, 0, 39 if escape == -1 else 20, 29, C.M_BRICK)
			w.sim.step(w.grid, [])
			if escape == 2:
				if p.x != 160 * C.SUB or p.y != 240 * C.SUB:
					return "busca sem saída deixou deslocamento parcial"
				continue
			if _embedded(w):
				return "entulho manteve objeto enterrado"
			if escape == 0:
				if p.x != 160 * C.SUB or p.y != 224 * C.SUB:
					return "não escolheu primeiro espaço livre acima"
			elif p.x != (160 + escape * 16) * C.SUB or p.y != 240 * C.SUB + Props.GRAVITY:
				return "busca lateral não escolheu primeiro espaço livre"
	return ""


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.sim.hash_ints() == b.sim.hash_ints() and a.grid.mat == b.grid.mat and a.grid.hp == b.grid.hp and a.grid.struct_dirty == b.grid.struct_dirty


static func _test_determinism() -> String:
	var a := _world()
	var b := _world()
	for w in [a, b]:
		var p := _single(w, 0, 328, 380)
		w.sim.throw(p.id, 10 * C.SUB, -C.SUB, 0)
	a.sim.step(a.grid, [])
	b.sim.step(b.grid, [])
	var snap: Dictionary = a.sim.snapshot()
	var mat: PackedByteArray = a.grid.mat.duplicate()
	var hp: PackedInt32Array = a.grid.hp.duplicate()
	var dirty: bool = a.grid.struct_dirty
	var history: Array = []
	for tick in 45:
		var ea: Array = a.sim.step(a.grid, [])
		var eb: Array = b.sim.step(b.grid, [])
		if not _same(a, b) or ea != eb:
			return "duas execuções divergiram no tick %d" % tick
		history.append(ea.duplicate(true))
	a.sim.restore(snap)
	a.grid.mat = mat.duplicate()
	a.grid.hp = hp.duplicate()
	a.grid.struct_dirty = dirty
	for tick in 45:
		if a.sim.step(a.grid, []) != history[tick]:
			return "eventos divergiram após restore"
	if not _same(a, b):
		return "hash/grade divergiram após restore em voo"
	return ""


static func _test_pending_snapshot() -> String:
	var w := _world()
	w.sim.strike(0, 1000, 0, 0, 999)
	var expected: PackedInt64Array = w.sim.hash_ints()
	var snap: Dictionary = w.sim.snapshot()
	var restored := Props.new()
	restored.restore(snap)
	if restored.hash_ints() != expected:
		return "snapshot omitiu estado pendente"
	var events: Array = restored.step(w.grid, [])
	if _count(events, "prop_break") != 1:
		return "restore perdeu evento pendente"
	if snap.pending.size() != 1 or w.sim.hash_ints() != expected:
		return "restore compartilhou estado com snapshot/origem"
	# Isola a contribuição da fila no hash, mantendo todos os campos dos props.
	var no_pending: Dictionary = snap.duplicate(true)
	no_pending.pending = []
	restored.restore(no_pending)
	if restored.hash_ints() == expected:
		return "hash omitiu fila de eventos"
	for key in Props.PROP_KEYS:
		var changed: Dictionary = snap.duplicate(true)
		changed.props[0][key] += 1
		restored.restore(changed)
		if restored.hash_ints() == expected:
			return "hash omitiu campo " + key
	w.sim.setup_test_district()
	if _count(w.sim.step(w.grid, []), "prop_break") != 0:
		return "setup preservou evento de partida anterior"
	return ""
