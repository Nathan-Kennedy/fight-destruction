extends RefCounted
## Testes headless da simulação: `Testar.bat` ou `godot --headless --path game -- --test`.
## Cada teste devolve "" quando passa ou a descrição da falha.

const C = preload("res://sim/sim_const.gd")
const A = preload("res://sim/attacks.gd")
const MatchSim = preload("res://sim/match_sim.gd")
const Bot = preload("res://input/bot.gd")
const Fixtures = preload("res://sim/fixtures.gd")
const Props = preload("res://sim/props.gd")

const SEEDS := [1, 7, 42, 1337]


static func run_all(seconds: int) -> int:
	var tests := {
		"vidro rompe e o corpo continua": _test_glass_break,
		"concreto devolve o corpo e acumula dano": _test_concrete_bounce,
		"dano acumula no concreto (2º impacto rompe)": _test_damage_accumulates,
		"lançamento rápido não atravessa núcleo": _test_no_tunnel_core,
		"golpe forte na vitrine lança através dela": _test_strong_through_storefront,
		"blast zone tira stock e reaparece": _test_blast_zone,
		"snapshot/restore ressimula igual": _test_snapshot_restore,
		"soco leve quebra vidro batendo": _test_jab_breaks_glass,
		"forte quebra tijolo em 2 golpes": _test_strong_breaks_brick,
		"escudo segura golpe e quebra se gasto": _test_shield,
		"rolamento é intangível": _test_roll_intangible,
		"agarrão ignora escudo; arremesso p/ baixo rompe laje": _test_grab_throw,
		"agarra caixa e arremessa pela vitrine": _test_prop_throw,
		"quebrar o pilar derruba a laje e esmaga": _test_collapse_crush,
		"hash distingue arquétipos": _test_hash_defs,
		"explosão abre saída do entulho": _test_burst_digs_out,
		"sobe degrau de entulho andando": _test_step_up,
		"desenterrar sempre acha espaço livre": _test_unstick,
		"cano de vapor empurra quem está no jato": _test_steam_push,
		"botijão avisa, explode, rompe células e lança": _test_tank_explodes,
		"cadeia de explosões respeita o limite": _test_chain_limit,
		"poste entorta conforme a direção do golpe": _test_pole_bend,
		"gás vazando pega fogo com faísca e água apaga": _test_gas_ignites,
		"botijão objeto chia e explode; extintor empurra": _test_prop_botijao_extintor,
		"snapshot/restore no meio de um vazamento": _test_fixture_snapshot,
		"hitstop cresce com o dano e tem teto": _test_hitstop_formula,
		"input buffer: golpe no recovery e pulo no hitstop, sem repetir": _test_input_buffer,
		"coyote time: pulo do chão logo após a borda": _test_coyote,
		"navegabilidade após destruição máxima (§4.6)": _test_navigability,
	}
	var failed := 0
	for name in tests:
		var ret = tests[name].call()
		# Erro de script faz a chamada devolver null: isso é falha, nunca "ok".
		var err: String = ret if typeof(ret) == TYPE_STRING else "teste abortou (erro de script)"
		print(("  ok    " if err == "" else "  FALHA ") + name + ("" if err == "" else ": " + err))
		if err != "":
			failed += 1
	# Suítes dos módulos (também rodam isoladas por tests/run_suite.gd).
	for suite in ["structure", "props"]:
		print("  -- suíte %s" % suite)
		var n = load("res://tests/%s_tests.gd" % suite).run_all()
		if typeof(n) != TYPE_INT or n > 0:
			print("  FALHA suíte %s" % suite)
			failed += 1
	for s in SEEDS:
		var ret = autotest(seconds, s)
		var err: String = ret if typeof(ret) == TYPE_STRING else "autotest abortou (erro de script)"
		print(("  ok    " if err == "" else "  FALHA ") + "autotest %ds semente %d" % [seconds, s] + ("" if err == "" else ": " + err))
		if err != "":
			failed += 1
	print("RESULTADO: %s (%d falha(s))" % ["PASSOU" if failed == 0 else "FALHOU", failed])
	return failed


static func autotest(seconds: int, seed_value: int) -> String:
	## Dois bots lutam; invariantes checadas a cada tick. Roda duas vezes: hashes têm que bater.
	var hashes := []
	var summary := ""
	for run in 2:
		var sim := MatchSim.new()
		sim.setup(["medio", "leve"])
		var bots := [Bot.new(seed_value), Bot.new(seed_value * 31 + 1)]
		var broken := 0
		var kos := 0
		var t0 := Time.get_ticks_usec()
		var worst := 0
		for i in seconds * C.TICK_HZ:
			var s0 := Time.get_ticks_usec()
			sim.step([bots[0].decide(sim, 0), bots[1].decide(sim, 1)])
			worst = maxi(worst, Time.get_ticks_usec() - s0)
			for e in sim.events:
				if e.kind == "break":
					broken += e.cells.size()
				elif e.kind == "ko":
					kos += 1
			for f in sim.fighters:
				if f.stocks > 0 and f.respawn == 0 and sim.overlaps_solid(f):
					return "tick %d: lutador %d dentro de matéria em (%d, %d)" % [sim.tick, f.id, f.x / C.SUB, f.y / C.SUB]
			if sim.winner >= 0:
				sim.setup(["medio", "leve"])
		hashes.append(sim.state_hash())
		summary = "células rompidas %d, KOs %d, pior tick %d us, média %d us" % [
			broken, kos, worst, (Time.get_ticks_usec() - t0) / (seconds * C.TICK_HZ)]
	if hashes[0] != hashes[1]:
		return "hash divergiu entre execuções: %s != %s" % hashes
	print("        semente %d: %s, hash %s" % [seed_value, summary, hashes[0]])
	return ""


static func _launched(sim, id: int, x_px: int, y_px: int, vx: int, vy: int) -> Dictionary:
	var f: Dictionary = sim.fighters[id]
	f.x = x_px * C.SUB
	f.y = y_px * C.SUB
	f.vx = vx
	f.vy = vy
	f.hitstun = 60
	f.grounded = 0
	return f


static func _park_other(sim, id: int) -> void:
	var o: Dictionary = sim.fighters[id]
	o.x = 20 * C.SUB
	o.y = 416 * C.SUB


static func _test_glass_break() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	_park_other(sim, 0)
	var f := _launched(sim, 1, 320, 410, 10 * C.SUB, 0)
	for i in 20:
		sim.step([0, 0])
	if sim.grid.get_mat(44, 45) != C.M_EMPTY:
		return "vidro na altura do corpo continua lá"
	if f.x <= 360 * C.SUB:
		return "corpo não passou da vitrine (x=%d px)" % (f.x / C.SUB)
	if sim.grid.get_mat(44, 39) == C.M_EMPTY:
		return "vidro acima do corpo também sumiu (carimbo maior que o corpo)"
	return ""


static func _test_concrete_bounce() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	_park_other(sim, 0)
	# Mureta de concreto em x 1024..1055 px; corpo no ar vindo da esquerda a 5 px/tick.
	var f := _launched(sim, 1, 990, 380, 5 * C.SUB, 0)
	var hp_before: int = sim.grid.hp[sim.grid.index(128, 46)]
	for i in 12:
		sim.step([0, 0])
	if sim.grid.get_mat(128, 46) != C.M_CONCRETE:
		return "concreto rompeu com lançamento fraco"
	if f.vx >= 0:
		return "não quicou (vx=%d)" % f.vx
	if sim.grid.hp[sim.grid.index(128, 46)] >= hp_before:
		return "impacto não deixou dano acumulado"
	return ""


static func _test_damage_accumulates() -> String:
	## Chama o impacto direto numa coluna de 6 células de concreto (R = 1800) para ter números exatos.
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	var cells := PackedInt32Array()
	for cy in range(46, 52):
		cells.append(sim.grid.index(128, cy))
	var f: Dictionary = sim.fighters[1]
	f.hitstun = 30
	f.vx = 1664   # 6,5 px/tick, leve (m 80): E = 1690 < R
	f.vy = 0
	if sim._impact(f, 0, cells):
		return "1º impacto rompeu com E < R"
	if f.vx >= 0:
		return "1º impacto não quicou"
	f.vx = 1664
	if not sim._impact(f, 0, cells):
		return "2º impacto igual não rompeu o concreto danificado (hp=%d)" % sim.grid.hp[cells[0]]
	return ""


static func _test_no_tunnel_core() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	_park_other(sim, 0)
	# Descendo a 40 px/tick: rompe a laje da rua (se tiver energia) mas nunca entra no núcleo.
	var f := _launched(sim, 1, 1200, 300, 0, 40 * C.SUB)
	for i in 30:
		sim.step([0, 0])
		if sim.overlaps_solid(f):
			return "corpo dentro de matéria no tick %d" % sim.tick
	if f.y > 432 * C.SUB:
		return "passou do topo do núcleo (y=%d px)" % (f.y / C.SUB)
	return ""


static func _test_strong_through_storefront() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"], [0, 90])
	var a: Dictionary = sim.fighters[0]
	var v: Dictionary = sim.fighters[1]
	a.x = 300 * C.SUB
	a.facing = 1
	v.x = 326 * C.SUB
	var hit := false
	for i in 120:
		sim.step([C.IN_STRONG if i == 0 else 0, 0])
		for e in sim.events:
			hit = hit or e.kind == "hit"
	if not hit:
		return "golpe forte não acertou"
	if v.x <= 368 * C.SUB and v.stocks == C.STOCKS:
		return "defensor não atravessou a vitrine (x=%d px)" % (v.x / C.SUB)
	return ""


static func _test_blast_zone() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	var f: Dictionary = sim.fighters[1]
	f.x = C.BLAST_LEFT - C.SUB
	sim.step([0, 0])
	if f.stocks != C.STOCKS - 1:
		return "stock não caiu"
	for i in C.RESPAWN_DELAY + 1:
		sim.step([0, 0])
	if f.respawn != 0 or f.invuln == 0 or f.x != C.SPAWN_X[1]:
		return "não reapareceu com invulnerabilidade"
	return ""


static func _test_snapshot_restore() -> String:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"])
	var bots := [Bot.new(5), Bot.new(9)]
	for i in 600:
		sim.step([bots[0].decide(sim, 0), bots[1].decide(sim, 1)])
	var snap := sim.snapshot()
	var inputs := []
	for i in 240:
		var inp := [bots[0].decide(sim, 0), bots[1].decide(sim, 1)]
		inputs.append(inp)
		sim.step(inp)
	var expected := sim.state_hash()
	sim.restore(snap)
	for inp in inputs:
		sim.step(inp)
	if sim.state_hash() != expected:
		return "estado após restore + 240 ticks diverge"
	return ""


# ---------------------------------------------------------------- combate e destruição (M2)

static func _duel(pct2: int = 0) -> Object:
	var sim := MatchSim.new()
	sim.setup(["medio", "leve"], [0, pct2])
	return sim


static func _run(sim, inputs: Array, ticks: int) -> Array:
	## Repete `inputs` (ou só no primeiro tick se for um Callable) e devolve os eventos.
	var evs := []
	for i in ticks:
		sim.step(inputs)
		evs.append_array(sim.events)
	return evs


static func _press_once(sim, p1: int, p2: int, ticks: int) -> Array:
	var evs := []
	for i in ticks:
		sim.step([p1 if i == 0 else 0, p2 if i == 0 else 0])
		evs.append_array(sim.events)
	return evs


static func _test_jab_breaks_glass() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var a: Dictionary = sim.fighters[0]
	# Encostado na vitrine (x 352 px) pelo lado de fora, olhando para a direita.
	a.x = 352 * C.SUB - a.hw
	a.facing = 1
	_press_once(sim, C.IN_LIGHT, 0, 20)
	if sim.grid.get_mat(44, 48) != C.M_EMPTY:
		return "vidro na altura do soco continua lá"
	return ""


static func _test_strong_breaks_brick() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var a: Dictionary = sim.fighters[0]
	# Parede dos fundos de tijolo (x 816 px) pelo lado de dentro.
	a.x = 816 * C.SUB - a.hw
	a.facing = 1
	_press_once(sim, C.IN_STRONG, 0, 40)
	if sim.grid.get_mat(102, 46) != C.M_BRICK:
		return "tijolo rompeu com um golpe só"
	_press_once(sim, C.IN_STRONG, 0, 40)
	if sim.grid.get_mat(102, 46) != C.M_EMPTY:
		return "tijolo não rompeu no 2º golpe forte (hp=%d)" % sim.grid.hp[sim.grid.index(102, 46)]
	return ""


static func _test_shield() -> String:
	var sim = _duel()
	var a: Dictionary = sim.fighters[0]
	var v: Dictionary = sim.fighters[1]
	a.x = 250 * C.SUB
	v.x = 276 * C.SUB
	a.facing = 1
	# Defensor segura escudo; atacante dá forte.
	var evs := []
	for i in 40:
		sim.step([C.IN_STRONG if i == 2 else 0, C.IN_SHIELD])
		evs.append_array(sim.events)
	var blocked := false
	for e in evs:
		if e.kind == "hit":
			return "golpe atravessou o escudo"
		blocked = blocked or e.kind == "shield_hit"
	if not blocked or v.pct != 0:
		return "escudo não registrou o golpe (pct=%d)" % v.pct
	# Segurar o escudo até gastar tudo quebra e atordoa.
	for i in C.SHIELD_MAX:
		sim.step([0, C.IN_SHIELD])
		if v.stun > 0:
			return ""
	return "escudo gasto não quebrou"


static func _test_roll_intangible() -> String:
	var sim = _duel()
	var a: Dictionary = sim.fighters[0]
	var v: Dictionary = sim.fighters[1]
	a.x = 250 * C.SUB
	v.x = 276 * C.SUB
	a.facing = 1
	sim.step([0, C.IN_SHIELD])
	for i in 30:
		# Defensor rola para a direita (para longe) enquanto o jab sai.
		sim.step([C.IN_LIGHT if i == 0 else 0, (C.IN_SHIELD | C.IN_RIGHT) if i == 0 else 0])
		for e in sim.events:
			if e.kind == "hit":
				return "jab acertou durante o rolamento"
	if v.x <= 290 * C.SUB:
		return "rolamento não deslocou (x=%d px)" % (v.x / C.SUB)
	return ""


static func _test_grab_throw() -> String:
	var sim = _duel(160)
	var a: Dictionary = sim.fighters[0]
	var v: Dictionary = sim.fighters[1]
	a.x = 1150 * C.SUB
	v.x = 1172 * C.SUB
	a.facing = 1
	var grabbed := false
	for i in 12:
		sim.step([C.IN_GRAB if i == 0 else 0, C.IN_SHIELD])
		for e in sim.events:
			grabbed = grabbed or e.kind == "grab"
	if not grabbed or a.grabbing != 1:
		return "agarrão não pegou o oponente de escudo"
	var evs := _press_once(sim, C.IN_DOWN, 0, 60)
	var broke := false
	for e in evs:
		broke = broke or e.kind == "break"
	if not broke:
		return "arremesso para baixo a 160%% não rompeu a laje da rua"
	for f in sim.fighters:
		if sim.overlaps_solid(f):
			return "lutador dentro de matéria após o arremesso"
	return ""


static func _test_prop_throw() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var a: Dictionary = sim.fighters[0]
	# Deixa os objetos assentarem e leva o J1 até o mais perto da vitrine, do lado de fora.
	_run(sim, [0, 0], 60)
	var pid := -1
	for p in sim.props.props:
		if p.state == 0 and p.x < 352 * C.SUB and (pid < 0 or p.x > sim.props.props[pid].x):
			pid = p.id
	if pid < 0:
		return "nenhum objeto do lado de fora da vitrine"
	var p: Dictionary = sim.props.props[pid]
	a.x = p.x - 10 * C.SUB
	a.y = p.y
	a.facing = 1
	var evs := _press_once(sim, C.IN_GRAB, 0, 12)
	if a.hold_prop != pid:
		return "não pegou o objeto %d" % pid
	a.x = 300 * C.SUB
	evs = _press_once(sim, C.IN_STRONG | C.IN_RIGHT, 0, 60)
	var broke := false
	for e in evs:
		broke = broke or (e.kind == "break" and e.has("prop"))
	if not broke:
		return "objeto arremessado não rompeu a vitrine"
	return ""


static func _test_collapse_crush() -> String:
	## Destrói o pilar e a parede dos fundos direto na grade; quem está embaixo é esmagado.
	var sim = _duel(20)
	var v: Dictionary = sim.fighters[1]
	_park_other(sim, 0)
	v.x = 640 * C.SUB
	v.y = 416 * C.SUB
	var cells := PackedInt32Array()
	for cy in range(36, 52):
		for cx in [88, 89, 102, 103]:
			cells.append(sim.grid.index(cx, cy))
	sim.grid.destroy(cells)
	var warned := false
	var crushed := false
	for i in 400:
		sim.step([0, 0])
		for e in sim.events:
			warned = warned or e.kind == "collapse_warn"
			crushed = crushed or e.kind == "crushed" or e.kind == "buried"
		for f in sim.fighters:
			if f.stocks > 0 and f.respawn == 0 and sim.overlaps_solid(f):
				return "tick %d: lutador dentro de matéria" % sim.tick
	if not warned:
		return "sem aviso de colapso"
	if not crushed:
		return "ninguém foi esmagado pela laje"
	var rubble := 0
	for m in sim.grid.mat:
		rubble += int(m == C.M_RUBBLE)
	if rubble == 0:
		return "colapso não deixou entulho"
	return ""


static func _test_hash_defs() -> String:
	var a := MatchSim.new()
	a.setup(["leve", "medio"])
	var b := MatchSim.new()
	b.setup(["pesado", "medio"])
	if a.state_hash() == b.state_hash():
		return "leve e pesado dão o mesmo hash inicial"
	return ""


static func _test_unstick() -> String:
	var sim = _duel()
	var f: Dictionary = sim.fighters[1]
	# Enterra o lutador no núcleo, fundo do mapa.
	f.x = 600 * C.SUB
	f.y = 470 * C.SUB
	sim._unstick(f)
	if sim.overlaps_solid(f):
		return "continuou dentro de matéria em (%d, %d)" % [f.x / C.SUB, f.y / C.SUB]
	return ""


static func _test_burst_digs_out() -> String:
	## Lutador cercado de entulho e concreto (caixa fechada) explode e fica livre para andar.
	var sim = _duel()
	_park_other(sim, 1)
	var f: Dictionary = sim.fighters[0]
	f.x = 560 * C.SUB + C.CELL_SUB / 2
	f.y = 416 * C.SUB
	var fx: int = f.x / C.CELL_SUB
	for cy in range(40, 52):
		for cx in range(fx - 5, fx + 6):
			var inside: bool = absi(cx - fx) <= 2 and cy >= 45
			if not inside:
				sim.grid.set_cell(sim.grid.index(cx, cy), C.M_RUBBLE if cy < 46 else C.M_CONCRETE, 300)
	sim.structure.setup(sim.grid)
	var x0: int = f.x
	for i in 10:
		sim.step([C.IN_RIGHT, 0])
	if f.x > x0 + 16 * C.SUB:
		return "cenário do teste não prende o lutador"
	for i in 40:
		sim.step([C.IN_SPECIAL if i == 0 else 0, 0])
	if f.burst_cd == 0:
		return "explosão sem recarga"
	for i in 40:
		sim.step([C.IN_RIGHT, 0])
		if sim.overlaps_solid(f):
			return "lutador dentro de matéria"
	if f.x <= x0 + 16 * C.SUB:
		return "não conseguiu andar depois da explosão (x=%d px)" % (f.x / C.SUB)
	return ""


static func _test_step_up() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var f: Dictionary = sim.fighters[0]
	f.x = 200 * C.SUB
	# Degrau de 2 células de entulho na rua, depois um muro de 4 células (não sobe).
	for cx in range(28, 31):
		for cy in range(50, 52):
			sim.grid.set_cell(sim.grid.index(cx, cy), C.M_RUBBLE, 15)
	for cx in range(40, 42):
		for cy in range(44, 52):
			sim.grid.set_cell(sim.grid.index(cx, cy), C.M_CONCRETE, 300)
	sim.structure.setup(sim.grid)
	for i in 50:
		sim.step([C.IN_RIGHT, 0])
		if sim.overlaps_solid(f):
			return "dentro de matéria ao subir"
	if f.x < 250 * C.SUB:
		return "não passou do degrau de 2 células (x=%d px)" % (f.x / C.SUB)
	if f.x > 320 * C.SUB:
		return "subiu um muro de 8 células (x=%d px)" % (f.x / C.SUB)
	return ""


# ---------------------------------------------------------------- elementos reativos (fixtures.gd)

static func _fix(sim, type: int, nth: int = 0) -> Dictionary:
	for f in sim.fixtures.fixtures:
		if f.type == type:
			if nth == 0:
				return f
			nth -= 1
	return {}


static func _hit_fixture(sim, f: Dictionary, dx: int = 1024, force: int = 10) -> void:
	sim._apply_fixture_events(sim.fixtures.hit_rect(f.bx0, f.by0, f.bx1, f.by1, dx, 0, force))


static func _test_steam_push() -> String:
	var sim = _duel()
	_park_other(sim, 0)
	var v: Dictionary = sim.fighters[1]
	# Na sobreloja, colado no cano de vapor (x 630..640), olhando para ele: o jab estoura o cano.
	v.x = 618 * C.SUB
	v.y = 272 * C.SUB
	v.facing = 1
	var steam := _fix(sim, Fixtures.STEAM)
	var x0: int = v.x
	for i in 8:
		sim.step([0, C.IN_LIGHT if i == 0 else 0])
	if steam.state != Fixtures.ACTIVE:
		return "jab não estourou o cano de vapor (estado %d)" % steam.state
	for i in 52:
		sim.step([0, 0])
	if v.x > x0 - 40 * C.SUB:
		return "jato não empurrou (andou %d px)" % ((x0 - v.x) / C.SUB)
	if v.pct < 1:
		return "vapor quente não causou dano leve"
	# Controle: sem o cano estourado, parado não anda.
	var ctl = _duel()
	_park_other(ctl, 0)
	ctl.fighters[1].x = 560 * C.SUB
	ctl.fighters[1].y = 272 * C.SUB
	var cx0: int = ctl.fighters[1].x
	_run(ctl, [0, 0], 60)
	if ctl.fighters[1].x != cx0:
		return "controle se moveu sem jato"
	return ""


static func _test_tank_explodes() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var a: Dictionary = sim.fighters[0]
	a.x = 540 * C.SUB
	a.facing = 1
	var tank := _fix(sim, Fixtures.TANK)
	var cells_before := 0
	var cells_after := 0
	var cx: int = tank.x / C.CELL_SUB
	var cy: int = tank.y / C.CELL_SUB
	for yy in range(cy - 6, cy + 7):
		for xx in range(cx - 6, cx + 7):
			cells_before += int(sim.grid.get_mat(xx, yy) != C.M_EMPTY and sim.grid.get_mat(xx, yy) != C.M_CORE)
	var warn_tick := -1
	var boom_tick := -1
	for i in 150:
		sim.step([C.IN_STRONG if i == 0 else 0, 0])
		for e in sim.events:
			if e.kind == "fix_state" and e.type == Fixtures.TANK and e.state == Fixtures.ACTIVE:
				warn_tick = sim.tick
			if e.kind == "explosion":
				boom_tick = sim.tick
		if boom_tick >= 0:
			break
	if warn_tick < 0:
		return "golpe não acendeu o aviso do botijão"
	if boom_tick < 0:
		return "botijão não explodiu"
	if boom_tick - warn_tick < Fixtures.TANK_FUSE - 1:
		return "explodiu sem janela de aviso (%d ticks)" % (boom_tick - warn_tick)
	for yy in range(cy - 6, cy + 7):
		for xx in range(cx - 6, cx + 7):
			cells_after += int(sim.grid.get_mat(xx, yy) != C.M_EMPTY and sim.grid.get_mat(xx, yy) != C.M_CORE)
	if cells_after >= cells_before:
		return "explosão não rompeu células"
	if a.pct < Fixtures.EXPL_DMG or a.hitstun == 0 or a.vx >= 0:
		return "lutador ao lado não foi lançado para fora (pct %d, vx %d)" % [a.pct, a.vx]
	return ""


static func _test_chain_limit() -> String:
	var sim = _duel()
	for f in sim.fighters:
		f.x = 1200 * C.SUB
	# Fileira de 12 botijões na rua da esquerda, 24 px entre si: cada explosão alcança vários.
	var ids := []
	for k in 12:
		var x: int = 24 + 24 * k
		var t: Dictionary = sim.fixtures._add(Fixtures.TANK, [x, 401], [], [x - 10, 386, x + 11, 416], [[x / 8, 52]])
		ids.append(t.id)
	_hit_fixture(sim, sim.fixtures.fixtures[ids[0]])
	var explosions := 0
	for i in 600:
		sim.step([0, 0])
		var n := 0
		for e in sim.events:
			n += int(e.kind == "explosion")
		explosions += n
		if n > Fixtures.EXPL_PER_TICK:
			return "%d explosões no mesmo tick" % n
		if sim.fixtures.chain_tick > Fixtures.CHAIN_PER_TICK:
			return "cadeia passou do limite por tick"
	if explosions < 3:
		return "cadeia não propagou (%d explosões)" % explosions
	if explosions > 1 + Fixtures.CHAIN_MAX or sim.fixtures.chain_total > Fixtures.CHAIN_MAX:
		return "cadeia passou do limite da partida (%d explosões)" % explosions
	var intact := 0
	for id in ids:
		var t: Dictionary = sim.fixtures.fixtures[id]
		intact += int(t.state == Fixtures.IDLE or (t.state == Fixtures.DONE and t.angle == 256))
	if intact == 0:
		return "todos explodiram: limite não segurou"
	return ""


static func _test_pole_bend() -> String:
	var angles := []
	for side in [1, -1]:
		var sim = _duel()
		_park_other(sim, 1)
		var a: Dictionary = sim.fighters[0]
		a.x = (216 - side * 16) * C.SUB
		a.facing = side
		var pole := _fix(sim, Fixtures.POLE)
		_press_once(sim, C.IN_LIGHT, 0, 20)
		if pole.state != Fixtures.ACTIVE:
			return "jab não entortou o poste"
		var first: int = pole.angle
		_press_once(sim, C.IN_STRONG, 0, 40)
		if absi(pole.angle) <= absi(first) and pole.state != Fixtures.DONE:
			return "segundo golpe não entortou mais"
		angles.append(first)
		for i in 6:
			_press_once(sim, C.IN_STRONG, 0, 40)
		if pole.state != Fixtures.DONE:
			return "poste não quebrou depois de muitos golpes (ângulo %d)" % pole.angle
	if angles[0] <= 0 or angles[1] >= 0:
		return "ângulo não segue a direção do golpe: %s" % [angles]
	return ""


static func _test_gas_ignites() -> String:
	var sim = _duel()
	for f in sim.fighters:
		f.x = 100 * C.SUB
	var gas := _fix(sim, Fixtures.GAS)
	var trafo := _fix(sim, Fixtures.TRAFO)
	_hit_fixture(sim, gas)
	if gas.state != Fixtures.ACTIVE:
		return "cano de gás não vazou"
	_hit_fixture(sim, trafo)
	var lit_at := -1
	for i in 200:
		sim.step([0, 0])
		if gas.state == Fixtures.FIRE and lit_at < 0:
			lit_at = i + 1
	if lit_at < 0:
		return "faísca do transformador não acendeu o gás"
	if lit_at < Fixtures.IGNITE_MIN:
		return "pegou fogo sem aviso de vazamento (%d ticks)" % lit_at
	# Fogo queima quem está no jato de chama.
	var v: Dictionary = sim.fighters[1]
	v.x = 860 * C.SUB
	v.y = 416 * C.SUB
	var burned := false
	for i in 30:
		sim.step([0, 0])
		for e in sim.events:
			burned = burned or (e.kind == "fix_hurt" and e.target == 1 and e.kb > 0)
	if not burned or v.pct == 0:
		return "chama não feriu quem estava no jato"
	# Água apaga: hidrante reposicionado para jogar no pé do cano em chama.
	var hyd := _fix(sim, Fixtures.HYDRANT)
	hyd.x = gas.x
	hyd.y = gas.y + 40 * C.SUB
	_hit_fixture(sim, hyd)
	sim.step([0, 0])
	if gas.state != Fixtures.DONE:
		return "água não apagou o fogo"
	return ""


static func _test_prop_botijao_extintor() -> String:
	var sim = _duel()
	_park_other(sim, 1)
	var bot: Dictionary = {}
	var ext: Dictionary = {}
	for p in sim.props.props:
		if p.kind == Props.BOTIJAO:
			bot = p
		elif p.kind == Props.EXTINTOR:
			ext = p
	if bot.is_empty() or ext.is_empty():
		return "botijão ou extintor ausente do distrito"
	_run(sim, [0, 0], 30)
	if bot.fx_used != 0 or ext.fx_used != 0:
		return "repouso acendeu pavio ou jato"
	# Botijão golpeado chia (pavio) e só explode depois de FUSE ticks.
	sim.props.strike(bot.id, 300, -600, 0, 5)
	var boom := -1
	for i in Props.FUSE + 20:
		sim.step([0, 0])
		for e in sim.events:
			if e.kind == "explosion":
				boom = i + 1
		if boom >= 0:
			break
	if boom < 0:
		return "botijão objeto não explodiu"
	if boom < Props.FUSE - 1:
		return "botijão explodiu sem aviso (%d ticks)" % boom
	# Extintor arremessado dispara jato no sentido do movimento e empurra quem está na frente.
	var v: Dictionary = sim.fighters[1]
	ext.state = Props.FREE
	ext.x = 200 * C.SUB
	ext.y = 416 * C.SUB
	ext.vx = 0
	ext.vy = 0
	v.x = 240 * C.SUB
	v.y = 416 * C.SUB
	v.vx = 0
	var x0: int = v.x
	sim.props.throw(ext.id, 256, 0, 0)
	for i in 30:
		sim.step([0, 0])
	if ext.fx_used != 1:
		return "extintor arremessado não disparou"
	if v.x <= x0 + 8 * C.SUB:
		return "jato do extintor não empurrou (%d px)" % ((v.x - x0) / C.SUB)
	return ""


static func _test_fixture_snapshot() -> String:
	var sim = _duel()
	var bots := [Bot.new(3), Bot.new(8)]
	for type in [Fixtures.WATER, Fixtures.STEAM, Fixtures.GAS, Fixtures.HYDRANT, Fixtures.TRAFO]:
		_hit_fixture(sim, _fix(sim, type))
	for i in 60:
		sim.step([bots[0].decide(sim, 0), bots[1].decide(sim, 1)])
	if _fix(sim, Fixtures.WATER).state != Fixtures.ACTIVE:
		return "cano de água não está vazando no meio do teste"
	var snap: Dictionary = sim.snapshot()
	var h0: String = sim.state_hash()
	var inputs := []
	for i in 180:
		var inp := [bots[0].decide(sim, 0), bots[1].decide(sim, 1)]
		inputs.append(inp)
		sim.step(inp)
	var expected: String = sim.state_hash()
	sim.restore(snap)
	if sim.state_hash() != h0:
		return "restore não voltou ao hash do snapshot"
	for inp in inputs:
		sim.step(inp)
	if sim.state_hash() != expected:
		return "estado após restore + 180 ticks diverge"
	# O hash vê o estado dos fixos.
	sim.fixtures.fixtures[0].angle += 1
	if sim.state_hash() == expected:
		return "hash ignora o estado dos fixos"
	return ""


# ---------------------------------------------------------------- sensação de combate (hitstop, buffer, coyote)

static func _test_hitstop_formula() -> String:
	# Jab (3%, kb ~400): 3 + 2 + 0 = 5. Forte de lado (13%) a 0% e a 100% (kb 1321 / 3021): 12 e 13.
	var cases := [[3, 400, 3, 5], [13, 1321, 6, 12], [13, 3021, 6, 13], [40, 9000, 6, C.HS_MAX], [0, 1000, 0, 1], [3, 9999, 0, C.HS_ENV_MAX]]
	for c in cases:
		var got: int = MatchSim.hitstop_for(c[0], c[1], c[2])
		if got != c[3]:
			return "hitstop_for(%d, %d, %d) = %d, esperado %d" % [c[0], c[1], c[2], got, c[3]]
	# No jogo: o forte acerta e o congelamento é o da fórmula.
	var sim = _duel()
	var a: Dictionary = sim.fighters[0]
	var v: Dictionary = sim.fighters[1]
	a.x = 250 * C.SUB
	v.x = 276 * C.SUB
	a.facing = 1
	for i in 30:
		sim.step([C.IN_STRONG if i == 0 else 0, 0])
		for e in sim.events:
			if e.kind == "hit":
				var want: int = MatchSim.hitstop_for(e.dmg, e.kb, A.LIST[A.STRONG_SIDE].hitstop)
				if sim.freeze != want:
					return "freeze %d depois do forte, fórmula dá %d" % [sim.freeze, want]
				return ""
	return "forte não acertou"


static func _count_starts(sim, id: int, attack: int, script: Dictionary, ticks: int) -> int:
	## Roda `ticks` ticks apertando `script[tick]` no lutador `id`; conta inícios do golpe `attack`.
	var n := 0
	var f: Dictionary = sim.fighters[id]
	for i in ticks:
		var inp := [0, 0]
		inp[id] = script.get(i, 0)
		sim.step(inp)
		if f.attack == attack and f.atk_t == 0:
			n += 1
	return n


static func _test_input_buffer() -> String:
	# Jab dura 14 ticks (termina no tick 14, o próximo pode sair no 15). Apertar de novo no tick 11
	# (recovery) fica no buffer e sai sozinho, uma vez; no tick 3 está fora da janela de 5 ticks.
	var sim = _duel()
	_park_other(sim, 1)
	var n := _count_starts(sim, 0, A.JAB, {0: C.IN_LIGHT, 11: C.IN_LIGHT}, 60)
	if n != 2:
		return "jab apertado no recovery saiu %d vez(es) no total, esperado 2" % n
	sim = _duel()
	_park_other(sim, 1)
	n = _count_starts(sim, 0, A.JAB, {0: C.IN_LIGHT, 3: C.IN_LIGHT}, 60)
	if n != 1:
		return "jab apertado fora da janela saiu %d vezes, esperado 1" % n
	# Segurar o botão não repete o golpe (borda só no aperto).
	sim = _duel()
	_park_other(sim, 1)
	var hold := {}
	for i in 60:
		hold[i] = C.IN_LIGHT
	n = _count_starts(sim, 0, A.JAB, hold, 60)
	if n != 1:
		return "segurar leve disparou %d jabs" % n
	# Pulo apertado e solto durante o hitstop sai quando o mundo volta (e sai curto: botão solto).
	sim = _duel()
	_park_other(sim, 1)
	var f: Dictionary = sim.fighters[0]
	sim.freeze = 10
	for i in 16:
		sim.step([C.IN_JUMP if i == 2 else 0, 0])
	if f.grounded or f.vy >= 0:
		return "pulo apertado no hitstop se perdeu (vy %d)" % f.vy
	var d: Dictionary = C.FIGHTERS[f.def]
	if f.jumps != 1:
		return "pulo do buffer gastou o salto duplo"
	if absi(f.vy) > d.jump / 2:
		return "pulo do buffer com botão solto não saiu curto (vy %d)" % f.vy
	return ""


static func _test_coyote() -> String:
	## Sai andando da borda direita da mureta (x 1024..1055 px, topo y 352 px) e pula k ticks depois.
	var got := []
	for k in [2, 6]:
		var sim = _duel()
		_park_other(sim, 1)
		var f: Dictionary = sim.fighters[0]
		f.x = 1046 * C.SUB
		f.y = 352 * C.SUB
		f.vx = 0
		sim.step([0, 0])
		if not f.grounded:
			return "cenário: lutador não ficou em pé na mureta"
		var guard := 0
		while f.grounded and guard < 60:
			sim.step([C.IN_RIGHT, 0])
			guard += 1
		for i in k:
			sim.step([C.IN_RIGHT, 0])
		sim.step([C.IN_RIGHT | C.IN_JUMP, 0])
		got.append(f.jumps)
	if got[0] != 1:
		return "pulo 2 ticks depois da borda gastou o salto duplo (coyote não valeu)"
	if got[1] != 0:
		return "pulo 6 ticks depois da borda ainda contou como do chão"
	return ""


# ---------------------------------------------------------------- navegabilidade (§4.6)

const NAV_W := 4          # corpo do pesado (30×56 px) arredondado para células alinhadas
const NAV_H := 7
const NAV_REACH_H := 6    # alcance horizontal no topo do pulo, em células (conservador)


static func _nav_jump_cells() -> int:
	## Altura de pulo (salto + duplo) do lutador que pula menos, com 75% de margem, em células.
	var best := 1 << 30
	for k in C.FIGHTERS:
		var d: Dictionary = C.FIGHTERS[k]
		var hpx: int = (d.jump * d.jump + d.djump * d.djump) / (2 * d.gravity) / C.SUB
		best = mini(best, hpx)
	return best * 3 / 4 / C.CELL


static func _nav_fit(g) -> PackedByteArray:
	## fit[cy*W + cx] = 1 se o corpo com coluna esquerda cx e pés no topo da linha cy cabe no vazio.
	var fit := PackedByteArray()
	fit.resize(C.GRID_W * (C.GRID_H + 1))
	for cy in C.GRID_H + 1:
		for cx in C.GRID_W - NAV_W + 1:
			var ok := true
			for yy in range(cy - NAV_H, cy):
				for xx in range(cx, cx + NAV_W):
					if g.get_mat(xx, yy) != C.M_EMPTY:
						ok = false
						break
				if not ok:
					break
			fit[cy * C.GRID_W + cx] = int(ok)
	return fit


static func _nav_ok(fit: PackedByteArray, cx: int, cy: int) -> bool:
	if cx < 0 or cx > C.GRID_W - NAV_W or cy > C.GRID_H:
		return false
	if cy < NAV_H:
		return true   # acima da grade é vazio
	return fit[cy * C.GRID_W + cx] == 1


static func _nav_fall(g, fit: PackedByteArray, cx: int, cy: int) -> int:
	## Cai reto a partir de (cx, cy) até ter apoio; -1 se sair da grade (morte).
	var y := cy
	while y < C.GRID_H:
		var sup := false
		for xx in range(cx, cx + NAV_W):
			sup = sup or g.get_mat(xx, y) != C.M_EMPTY
		if sup:
			return y if _nav_ok(fit, cx, y) else -1
		y += 1
	return -1


static func _nav_reach(g, fit: PackedByteArray, start_x_px: int, jump: int) -> Dictionary:
	## BFS sobre posições em pé: andar (±1 célula, sobe degrau de até STEP_UP), cair da borda e pular
	## (sobe até `jump` células num vão livre, anda até NAV_REACH_H no topo e cai). Devolve {cx: true}.
	var cx0: int = start_x_px / C.CELL - NAV_W / 2
	var cy0 := 52
	while not _nav_ok(fit, cx0, cy0) and cy0 > NAV_H:
		cy0 -= 1
	cy0 = _nav_fall(g, fit, cx0, cy0)
	var reached := {}
	if cy0 < 0:
		return reached
	var seen := {}
	var queue := [[cx0, cy0]]
	seen[cy0 * 1000 + cx0] = true
	while not queue.is_empty():
		var n: Array = queue.pop_back()
		var cx: int = n[0]
		var cy: int = n[1]
		reached[cx] = true
		var nexts := []
		for s in [-1, 1]:
			for up in C.STEP_UP + 1:
				if _nav_ok(fit, cx, cy - up) and _nav_ok(fit, cx + s, cy - up):
					nexts.append([cx + s, cy - up])
					break
		for k in range(1, jump + 1):
			if not _nav_ok(fit, cx, cy - k):
				break
			for s in [-1, 1]:
				for j in range(1, NAV_REACH_H + 1):
					if not _nav_ok(fit, cx + s * j, cy - k):
						break
					nexts.append([cx + s * j, cy - k])
		for m in nexts:
			var ly := _nav_fall(g, fit, m[0], m[1])
			if ly < 0:
				continue
			var key: int = ly * 1000 + m[0]
			if not seen.has(key):
				seen[key] = true
				queue.append([m[0], ly])
	return reached


static func _nav_settle(sim) -> int:
	## Deixa ilhas caírem e o entulho assentar. Devolve os passos gastos (-1 se não assentou).
	for i in 6000:
		sim.structure.step(sim.grid, [])
		if sim.structure.islands.is_empty() and sim.structure.active.is_empty() and not sim.grid.struct_dirty:
			return i
	return -1


static func _test_navigability() -> String:
	## §4.6: depois da destruição máxima scriptada, todo spawn alcança todos os outros.
	## "térreo": só as paredes do térreo do prédio somem (os andares de cima desabam em entulho sobre
	## a laje). "colapso": tudo que é destrutível abaixo da linha 36 some (térreo, laje da rua,
	## mureta, marquise) e o prédio de cima vira entulho no núcleo. "arrasado": depois disso, o
	## entulho também é destruído (sobra só o núcleo).
	var jump := _nav_jump_cells()
	var report := []
	var fails := []
	for scen in ["térreo", "colapso", "arrasado"]:
		var sim = _duel()
		var g = sim.grid
		var cells := PackedInt32Array()
		for cy in C.GRID_H:
			for cx in C.GRID_W:
				var m: int = g.get_mat(cx, cy)
				if m == C.M_EMPTY or m == C.M_CORE:
					continue
				if scen == "térreo" and (cy < 36 or cy > 51 or cx < 44 or cx > 103):
					continue
				if scen != "térreo" and cy < 36:
					continue
				cells.append(g.index(cx, cy))
		g.destroy(cells)
		var steps := _nav_settle(sim)
		if steps < 0:
			fails.append("%s: estrutura não assentou" % scen)
			continue
		if scen == "arrasado":
			var rest := PackedInt32Array()
			for i in g.mat.size():
				if g.mat[i] != C.M_EMPTY and g.mat[i] != C.M_CORE:
					rest.append(i)
			g.destroy(rest)
			_nav_settle(sim)
		var rubble := 0
		var top := C.GRID_H
		for i in g.mat.size():
			if g.mat[i] == C.M_RUBBLE:
				rubble += 1
				top = mini(top, i / C.GRID_W)
		var fit := _nav_fit(g)
		for a in C.SPAWN_X.size():
			var reach := _nav_reach(g, fit, C.SPAWN_X[a] / C.SUB, jump)
			for b in C.SPAWN_X.size():
				if a == b:
					continue
				var goal: int = C.SPAWN_X[b] / C.SUB / C.CELL - NAV_W / 2
				if not (reach.has(goal) or reach.has(goal - 1) or reach.has(goal + 1)):
					fails.append("%s: spawn %d (x %d) não alcança spawn %d (x %d)" % [scen, a, C.SPAWN_X[a] / C.SUB, b, C.SPAWN_X[b] / C.SUB])
		report.append("%s: %d entulhos, topo linha %d, assentou em %d passos" % [scen, rubble, top, steps])
	print("        navegabilidade (pulo %d células, corpo %dx%d): %s" % [jump, NAV_W, NAV_H, "; ".join(report)])
	return "" if fails.is_empty() else "; ".join(fails)
