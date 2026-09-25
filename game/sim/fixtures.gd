extends RefCounted
## Elementos reativos fixos do cenário (Docs/design_elementos_reativos.md): canos, botijão fixo,
## transformador, fiação, hidrante, postes, luminárias e letreiro neon. Presos a células da grade.
## Só inteiros, sem nós, sem RNG, sem tempo real. Posições em subpixels, ângulos em 1/1024 de volta.
##
## Este módulo não mexe em lutadores nem em objetos: `step()` e os gatilhos devolvem eventos, e o
## integrador (match_sim.gd) aplica os efeitos de gameplay:
##   fix_push   {target|prop, ax, ay, cap, dx, dy}  jato: acelera ao longo de (dx, dy) até `cap`
##   fix_hurt   {target, dmg, kb, dx, dy, stun, fix} fogo/choque/vapor: dano e hitstun leve (kb 0 = só dano)
##   fix_explode {fix, x, y}                         botijão fixo explodiu: explosão radial no integrador
##   fix_ignite_prop {prop, fix}                     fogo alcançou um botijão móvel (consome cadeia)
## e eventos só de apresentação: fix_state {fix, type, state, x, y, cause}, fix_spark {fix, x, y},
## fix_extinguish {fix}.

const C = preload("res://sim/sim_const.gd")

# Tipos (índices fixos: entram no hash).
const WATER := 0      # cano de água
const STEAM := 1      # cano de vapor
const GAS := 2        # cano de gás inflamável
const TANK := 3       # botijão / tanque fixo
const TRAFO := 4      # transformador / caixa elétrica
const WIRE := 5       # fiação entre prédio e poste
const HYDRANT := 6    # hidrante
const POLE := 7       # poste com luminária de rua
const LAMP := 8       # luminária pendente interna
const NEON := 9       # letreiro neon
const TYPE_NAMES := ["cano_agua", "cano_vapor", "cano_gas", "botijao", "transformador", "fiacao",
	"hidrante", "poste", "luminaria", "neon"]

# Estados genéricos. ACTIVE = vazando / jato / chiando / faiscando / solta / jorrando / entortado /
# balançando / falhando, conforme o tipo. FIRE só existe no cano de gás.
const IDLE := 0
const ACTIVE := 1
const FIRE := 2
const DONE := 3

# Causas de gatilho (só informativas no evento; entram no hash via estado resultante).
const CAUSE_ANCHOR := 0
const CAUSE_HIT := 1
const CAUSE_BODY := 2
const CAUSE_PROP := 3
const CAUSE_BLAST := 4
const CAUSE_FIRE := 5

# Durações em ticks (60 Hz).
const WATER_T := 480          # 8 s vazando
const STEAM_T := 240          # 4 s de jato
const GAS_LEAK_T := 600       # 10 s vazando antes de acabar
const GAS_FIRE_T := 300       # 5 s de chama
const IGNITE_MIN := 40        # gás vaza (chiando) pelo menos isso antes de poder pegar fogo
const IGNITE_R := 80          # px: faísca/fogo a essa distância acende gás vazando
const TANK_FUSE := 72         # 1,2 s de aviso (chia e pisca) depois de golpe/impacto
const TANK_CHAIN_FUSE := 36   # 0,6 s quando o gatilho foi outra explosão/fogo
const TRAFO_T := 420          # 7 s faiscando
const TRAFO_PERIOD := 45      # arco elétrico a cada 45 ticks...
const TRAFO_ARC := 10         # ...durante 10 ticks
const TRAFO_R := 40           # px, raio do choque
const WIRE_T := 720           # 12 s solta e viva
const WIRE_DROP := 88         # px pendurada abaixo do topo do poste
const HYDRANT_T := 480        # 8 s jorrando
const NEON_T := 240           # 4 s falhando antes de apagar
const CONTACT_CD := 20        # ticks entre gatilhos por contato no mesmo fixo
const POLE_H := 104           # px do pé ao topo do poste
const POLE_MAX := 176         # |ângulo| acima disso o poste quebra (≈ 62°)
const POLE_BEND_BLAST := 112
const LAMP_BREAK := 176       # |ângulo| do pêndulo acima disso a luminária cai

# Jatos: aceleração por tick ao longo da direção, teto da velocidade nessa direção (sub/tick).
const WATER_PUSH := 150
const WATER_CAP := 512
const STEAM_PUSH := 260
const STEAM_CAP := 1800
const STEAM_SCALD_EVERY := 20 # vapor quente: 1% a cada 20 ticks dentro do jato
const HYDRANT_PUSH := 300
const HYDRANT_CAP := 2000
# Perigos: dano, knockback base (sub/tick), hitstun e recarga por fixo.
const FIRE_DMG := 4
const FIRE_KB := 420
const FIRE_STUN := 12
const FIRE_CD := 24
const SHOCK_DMG := 3
const SHOCK_KB := 380
const SHOCK_STUN := 14
const SHOCK_CD := 30
const WIRE_DMG := 2
const WIRE_STUN := 10
const WIRE_CD := 40

# Explosão do botijão fixo (e do móvel, com raio menor): mesma regra da explosão especial.
const EXPL_RADIUS := 56
const PROP_EXPL_RADIUS := 44
const EXPL_CELL_DMG := 320    # por célula no raio: rompe concreto novo, nunca núcleo
const EXPL_DMG := 12
const EXPL_BASE := 1000
const EXPL_GROWTH := 9
# Cadeia limitada (§2): gatilhos de explosivos por outra explosão/fogo, por tick e por partida;
# e no máximo EXPL_PER_TICK botijões fixos detonam no mesmo tick (os outros esperam o próximo).
const CHAIN_PER_TICK := 2
const CHAIN_MAX := 6
const EXPL_PER_TICK := 2

# Campos inteiros canônicos de um fixo (hash). anchors entra à parte.
const FIX_KEYS := ["id", "type", "state", "t", "age", "angle", "a16", "av", "cd", "hcd", "link",
	"x", "y", "x2", "y2", "dx", "dy", "len", "w", "bx0", "by0", "bx1", "by1"]

var fixtures: Array = []
var chain_total := 0
var chain_tick := 0
var expl_tick := 0


# ---------------------------------------------------------------- montagem

func setup_test_district(_grid = null) -> void:
	## Posições do §4 do design no distrito de matter_grid.build_test_district (px; células de 8 px).
	## Rua no topo da linha 52 (y 416). Prédio x 352..831; térreo y 288..415; sobreloja y 144..271.
	fixtures.clear()
	chain_total = 0
	chain_tick = 0
	expl_tick = 0
	# Postes na calçada da esquerda e da direita (apoio: laje da rua).
	_add(POLE, [216, 416], [], [212, 312, 221, 416], [[27, 52]])
	_add(POLE, [976, 416], [], [972, 312, 981, 416], [[122, 52]])
	# Hidrante na rua, depois do prédio. Jato vertical.
	_add(HYDRANT, [880, 398], [0, -1024, 112, 12], [874, 398, 887, 416], [[110, 52]])
	# Cano de água na face interna da parede dos fundos (tijolo x 816), perto do teto; jorra para baixo
	# e para dentro da sala dos fundos.
	_add(WATER, [806, 330], [-724, 724, 72, 10], [804, 288, 816, 336], [[102, 36], [102, 38], [102, 40]])
	# Cano de vapor na sobreloja, na face esquerda da parede interna (x 640); jato horizontal.
	_add(STEAM, [630, 232], [-1024, 0, 104, 14], [630, 150, 640, 272], [[80, 20], [80, 26], [80, 32]])
	# Botijão/tanque na loja, no canto da divisória.
	_add(TANK, [568, 401], [], [558, 386, 579, 416], [[70, 52], [71, 52]])
	# Transformador na face externa da parede dos fundos, com o cano de gás logo abaixo.
	_add(TRAFO, [844, 332], [], [832, 316, 857, 349], [[103, 40], [103, 42]])
	_add(GAS, [840, 390], [1024, 0, 64, 12], [832, 368, 841, 416], [[103, 46], [103, 49]])
	# Luminárias pendentes na loja (teto y 288) e no escritório da sobreloja (teto y 144).
	_add(LAMP, [468, 288], [], [460, 288, 477, 318], [[58, 35]])
	_add(LAMP, [732, 144], [], [724, 144, 741, 176], [[91, 17]])
	# Letreiro neon sobre a marquise (x 256..335, topo y 296).
	_add(NEON, [296, 296], [], [264, 272, 329, 296], [[34, 37], [38, 37]])
	# Fiação: da fachada de tijolo (x 352, y 182) até o topo do poste da esquerda.
	var w := _add(WIRE, [352, 182], [], [216, 182, 352, 320], [[44, 22]])
	w.x2 = 220 * C.SUB
	w.y2 = 316 * C.SUB
	w.link = 0


func _add(type: int, pos: Array, jet: Array, box: Array, anchors: Array) -> Dictionary:
	var a := PackedInt32Array()
	for c in anchors:
		a.append(c[1] * C.GRID_W + c[0])
	var f := {"id": fixtures.size(), "type": type, "state": IDLE, "t": 0, "age": 0, "angle": 0,
		"a16": 0, "av": 0, "cd": 0, "hcd": 0, "link": -1,
		"x": pos[0] * C.SUB, "y": pos[1] * C.SUB, "x2": 0, "y2": 0,
		"dx": jet[0] if jet.size() > 0 else 0, "dy": jet[1] if jet.size() > 0 else 0,
		"len": jet[2] * C.SUB if jet.size() > 0 else 0, "w": jet[3] * C.SUB if jet.size() > 0 else 0,
		"bx0": box[0] * C.SUB, "by0": box[1] * C.SUB, "bx1": box[2] * C.SUB, "by1": box[3] * C.SUB,
		"anchors": a}
	fixtures.append(f)
	return f


# ---------------------------------------------------------------- passo

func begin_tick() -> void:
	## Chamado no início de cada tick simulado (fora do hitstop): zera os limites por tick.
	chain_tick = 0
	expl_tick = 0


func chain_take() -> bool:
	## Um elo de cadeia (explosivo acionado por outra explosão/fogo). Falso se o limite estourou.
	if chain_tick >= CHAIN_PER_TICK or chain_total >= CHAIN_MAX:
		return false
	chain_tick += 1
	chain_total += 1
	return true


func step(grid, targets: Array) -> Array:
	## targets: [{kind 0 = lutador | 1 = objeto, id, box [l,t,r,b], vx, vy, moving, hurt, botijao}]
	## em ordem fixa (lutadores por id, depois objetos por id).
	var ev: Array = []
	for f in fixtures:
		if f.age < 1000000:
			f.age += 1
		if f.cd > 0:
			f.cd -= 1
		if f.hcd > 0:
			f.hcd -= 1
		if f.state != DONE and _anchor_lost(grid, f):
			_on_anchor(f, ev)
		if f.state != DONE and f.cd == 0:
			for tg in targets:
				if tg.moving and _touches(f, tg.box):
					var sp: int = maxi(1, C.isqrt(tg.vx * tg.vx + tg.vy * tg.vy))
					_trigger(f, tg.vx * 1024 / sp, tg.vy * 1024 / sp, sp / C.SUB * 2, false, ev,
						CAUSE_BODY if tg.kind == 0 else CAUSE_PROP)
					f.cd = CONTACT_CD
					break
		_tick_state(f, ev)
	# Fio ligado ao poste: poste quebrado derruba a fiação (morta).
	for f in fixtures:
		if f.type == WIRE and f.state != DONE and f.link >= 0 and fixtures[f.link].state == DONE:
			_set_state(f, DONE, CAUSE_ANCHOR, ev)
	_ignition(ev)
	_extinguish(ev)
	_effects(targets, ev)
	return ev


func _tick_state(f: Dictionary, ev: Array) -> void:
	match f.type:
		LAMP:
			if f.state == ACTIVE:
				# Pêndulo inteiro: a16 = ângulo × 16; mola ≈ ω² 11/1024, amortecimento 1/128 por tick.
				f.av -= f.a16 * 11 / 1024
				f.av -= f.av / 128
				f.a16 += f.av
				f.angle = f.a16 / 16
				if absi(f.angle) > LAMP_BREAK:
					_set_state(f, DONE, CAUSE_HIT, ev)
				elif absi(f.a16) < 32 and absi(f.av) < 8:
					f.a16 = 0
					f.av = 0
					f.angle = 0
					_set_state(f, IDLE, CAUSE_HIT, ev)
		POLE:
			pass
		TANK:
			if f.state == ACTIVE:
				if f.t > 1:
					f.t -= 1
				elif expl_tick < EXPL_PER_TICK:
					f.t = 0
					expl_tick += 1
					_set_state(f, DONE, CAUSE_FIRE, ev)
					ev.append({"kind": "fix_explode", "fix": f.id, "x": f.x, "y": f.y})
				# Senão fica em t = 1 e detona no próximo tick (limite por tick).
		_:
			if (f.state == ACTIVE or f.state == FIRE) and f.t > 0:
				f.t -= 1
				if f.t == 0:
					_set_state(f, DONE, CAUSE_ANCHOR, ev)


func _set_state(f: Dictionary, s: int, cause: int, ev: Array) -> void:
	if f.state == s:
		return
	f.state = s
	f.age = 0
	ev.append({"kind": "fix_state", "fix": f.id, "type": f.type, "state": s, "x": f.x, "y": f.y, "cause": cause})


func _anchor_lost(grid, f: Dictionary) -> bool:
	for i in f.anchors:
		if grid.mat[i] == C.M_EMPTY:
			return true
	return false


func _on_anchor(f: Dictionary, ev: Array) -> void:
	match f.type:
		POLE, LAMP, NEON:
			_set_state(f, DONE, CAUSE_ANCHOR, ev)
			ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x, "y": f.y})
		TANK:
			# Chão arrancado (quase sempre por outra explosão): conta como elo de cadeia. Sem cota,
			# o botijão tomba apagado (angle = 256, um quarto de volta) e não explode.
			if f.state != IDLE:
				return
			if chain_take():
				f.t = TANK_CHAIN_FUSE
				_set_state(f, ACTIVE, CAUSE_ANCHOR, ev)
			else:
				f.angle = 256
				_set_state(f, DONE, CAUSE_ANCHOR, ev)
		_:
			_trigger(f, 0, 0, 0, false, ev, CAUSE_ANCHOR)


# ---------------------------------------------------------------- gatilhos

func hit_rect(l: int, t: int, r: int, b: int, dx: int, dy: int, force: int) -> Array:
	## Hitbox de golpe (primeiro frame ativo). (dx, dy) em 1/1024 no sentido do mundo; force = dano.
	var ev: Array = []
	for f in fixtures:
		if f.state != DONE and _touches(f, [l, t, r, b]):
			_trigger(f, dx, dy, force, false, ev, CAUSE_HIT)
	return ev


func blast(x: int, y: int, radius_px: int, chained: bool) -> Array:
	## Explosão ou fogo forte em (x, y): aciona o que estiver no raio. Explosivos acionados assim são
	## elos de cadeia (limitados por chain_take). `chained` falso só para a explosão especial.
	var ev: Array = []
	var rr: int = radius_px * C.SUB
	for f in fixtures:
		if f.state == DONE:
			continue
		var nx: int = clampi(x, f.bx0, f.bx1)
		var ny: int = clampi(y, f.by0, f.by1)
		if (nx - x) * (nx - x) + (ny - y) * (ny - y) > rr * rr:
			continue
		var ddx: int = f.x - x
		var ddy: int = f.y - y
		var n: int = maxi(1, C.isqrt(ddx * ddx + ddy * ddy))
		_trigger(f, ddx * 1024 / n, ddy * 1024 / n, 24, chained, ev, CAUSE_BLAST)
	return ev


func _trigger(f: Dictionary, dx: int, dy: int, force: int, chained: bool, ev: Array, cause := CAUSE_HIT) -> void:
	var from_blast: bool = cause == CAUSE_BLAST or cause == CAUSE_FIRE
	match f.type:
		WATER, STEAM, HYDRANT, TRAFO, WIRE:
			if f.state == IDLE:
				f.t = [WATER_T, STEAM_T, 0, 0, TRAFO_T, WIRE_T, HYDRANT_T][f.type]
				_set_state(f, ACTIVE, cause, ev)
				if f.type == TRAFO or f.type == WIRE:
					ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x, "y": f.y})
		GAS:
			if f.state == IDLE:
				f.t = GAS_LEAK_T
				_set_state(f, ACTIVE, cause, ev)
			elif f.state == ACTIVE and from_blast and f.age >= IGNITE_MIN:
				_ignite(f, ev)
		TANK:
			if f.state == IDLE:
				if from_blast and chained and not chain_take():
					return
				f.t = TANK_CHAIN_FUSE if from_blast else TANK_FUSE
				_set_state(f, ACTIVE, cause, ev)
		POLE:
			var s: int = signi(dx)
			if s == 0:
				s = 1
			var bend: int = POLE_BEND_BLAST if from_blast else clampi(24 + force * 4, 32, 128)
			if cause == CAUSE_ANCHOR:
				_set_state(f, DONE, cause, ev)
				return
			f.angle += s * bend
			if absi(f.angle) > POLE_MAX:
				f.angle = clampi(f.angle, -POLE_MAX - 32, POLE_MAX + 32)
				_set_state(f, DONE, cause, ev)
				ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x, "y": f.y - POLE_H * C.SUB})
			else:
				_set_state(f, ACTIVE, cause, ev)
				ev.append({"kind": "fix_bend", "fix": f.id, "angle": f.angle, "x": f.x, "y": f.y})
		LAMP:
			if from_blast or cause == CAUSE_ANCHOR:
				_set_state(f, DONE, cause, ev)
				return
			var s2: int = signi(dx)
			if s2 == 0:
				s2 = 1
			f.av += s2 * (60 + force * 4)
			_set_state(f, ACTIVE, cause, ev)
		NEON:
			if f.state == IDLE:
				f.t = NEON_T / 2 if from_blast else NEON_T
				_set_state(f, ACTIVE, cause, ev)
				ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x, "y": f.y})


func _ignite(f: Dictionary, ev: Array) -> void:
	f.t = GAS_FIRE_T
	_set_state(f, FIRE, CAUSE_FIRE, ev)


# ---------------------------------------------------------------- fogo, faísca e água

func _sources() -> Array:
	## Pontos de ignição deste tick: [x, y] em subpixels.
	var out: Array = []
	for f in fixtures:
		match f.type:
			TRAFO:
				if f.state == ACTIVE and f.t % TRAFO_PERIOD < TRAFO_ARC:
					out.append([f.x, f.y])
			WIRE:
				if f.state == ACTIVE and f.age % 20 == 0:
					out.append([f.x2, f.y2 + WIRE_DROP * C.SUB])
			NEON:
				if f.state == ACTIVE and f.age % 30 == 0:
					out.append([f.x, f.y])
			GAS:
				if f.state == FIRE:
					out.append([f.x + f.dx * f.len / 1024, f.y + f.dy * f.len / 1024])
	return out


func _ignition(ev: Array) -> void:
	var src := _sources()
	if src.is_empty():
		return
	var rr: int = IGNITE_R * C.SUB
	for f in fixtures:
		if f.type != GAS or f.state != ACTIVE or f.age < IGNITE_MIN:
			continue
		for s in src:
			if (s[0] - f.x) * (s[0] - f.x) + (s[1] - f.y) * (s[1] - f.y) <= rr * rr:
				_ignite(f, ev)
				break
	# Chama alcança botijões fixos no jato de fogo.
	for g in fixtures:
		if g.type != GAS or g.state != FIRE:
			continue
		for f in fixtures:
			if f.type == TANK and f.state == IDLE and jet_hits(g, [f.bx0, f.by0, f.bx1, f.by1]):
				_trigger(f, g.dx, g.dy, 0, true, ev, CAUSE_FIRE)


func _extinguish(ev: Array) -> void:
	for g in fixtures:
		if g.type != GAS or g.state != FIRE:
			continue
		for w in fixtures:
			if (w.type == WATER or w.type == HYDRANT) and w.state == ACTIVE \
					and jet_hits(w, [g.x - 4 * C.SUB, g.y - 4 * C.SUB, g.x + 4 * C.SUB, g.y + 4 * C.SUB]):
				_set_state(g, DONE, CAUSE_FIRE, ev)
				ev.append({"kind": "fix_extinguish", "fix": g.id, "x": g.x, "y": g.y})
				break


# ---------------------------------------------------------------- efeitos nos alvos

func _effects(targets: Array, ev: Array) -> void:
	for f in fixtures:
		match f.type:
			WATER, STEAM, HYDRANT:
				if f.state != ACTIVE:
					continue
				var push: int = [WATER_PUSH, STEAM_PUSH, 0, 0, 0, 0, HYDRANT_PUSH][f.type]
				var cap: int = [WATER_CAP, STEAM_CAP, 0, 0, 0, 0, HYDRANT_CAP][f.type]
				var scald: bool = f.type == STEAM and f.age % STEAM_SCALD_EVERY == 0
				for tg in targets:
					if not jet_hits(f, tg.box):
						continue
					var e := {"kind": "fix_push", "fix": f.id, "ax": f.dx * push / 1024, "ay": f.dy * push / 1024,
						"cap": cap, "dx": f.dx, "dy": f.dy}
					if tg.kind == 0:
						e.target = tg.id
						if scald and tg.hurt:
							ev.append({"kind": "fix_hurt", "fix": f.id, "target": tg.id, "dmg": 1, "kb": 0,
								"dx": f.dx, "dy": f.dy, "stun": 0})
					else:
						e.prop = tg.id
					ev.append(e)
			GAS:
				if f.state != FIRE:
					continue
				var burned := false
				for tg in targets:
					if not jet_hits(f, tg.box):
						continue
					if tg.kind == 0 and tg.hurt and f.hcd == 0:
						ev.append({"kind": "fix_hurt", "fix": f.id, "target": tg.id, "dmg": FIRE_DMG, "kb": FIRE_KB,
							"dx": f.dx * 870 / 1024, "dy": -500, "stun": FIRE_STUN})
						burned = true
					elif tg.kind == 1 and tg.botijao:
						ev.append({"kind": "fix_ignite_prop", "fix": f.id, "prop": tg.id})
				if burned:
					f.hcd = FIRE_CD
			TRAFO:
				if f.state != ACTIVE or f.t % TRAFO_PERIOD >= TRAFO_ARC:
					continue
				if f.t % TRAFO_PERIOD == TRAFO_ARC - 1:
					ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x, "y": f.y})
				_shock_radius(f, targets, ev)
			WIRE:
				if f.state != ACTIVE or f.hcd > 0:
					continue
				var hb := wire_hazard(f)
				for tg in targets:
					if tg.kind == 0 and tg.hurt and _overlaps(hb, tg.box):
						var dx: int = 1024 if (tg.box[0] + tg.box[2]) / 2 >= f.x2 else -1024
						ev.append({"kind": "fix_hurt", "fix": f.id, "target": tg.id, "dmg": WIRE_DMG, "kb": SHOCK_KB,
							"dx": dx * 700 / 1024, "dy": -700, "stun": WIRE_STUN})
						f.hcd = WIRE_CD
						ev.append({"kind": "fix_spark", "fix": f.id, "x": f.x2, "y": f.y2 + WIRE_DROP * C.SUB})


func _shock_radius(f: Dictionary, targets: Array, ev: Array) -> void:
	if f.hcd > 0:
		return
	var rr: int = TRAFO_R * C.SUB
	for tg in targets:
		if tg.kind != 0 or not tg.hurt:
			continue
		var b: Array = tg.box
		var nx: int = clampi(f.x, b[0], b[2])
		var ny: int = clampi(f.y, b[1], b[3])
		if (nx - f.x) * (nx - f.x) + (ny - f.y) * (ny - f.y) > rr * rr:
			continue
		var cx: int = (b[0] + b[2]) / 2
		var dx: int = 700 if cx >= f.x else -700
		ev.append({"kind": "fix_hurt", "fix": f.id, "target": tg.id, "dmg": SHOCK_DMG, "kb": SHOCK_KB,
			"dx": dx, "dy": -700, "stun": SHOCK_STUN})
		f.hcd = SHOCK_CD


# ---------------------------------------------------------------- geometria

func jet_hits(f: Dictionary, box: Array) -> bool:
	## Jato como sequência de quadrados de meia largura `w` a cada 8 px ao longo de (dx, dy).
	var n: int = f.len / C.CELL_SUB
	for k in n + 1:
		var px: int = f.x + f.dx * k * C.CELL_SUB / 1024
		var py: int = f.y + f.dy * k * C.CELL_SUB / 1024
		if px - f.w < box[2] and box[0] < px + f.w and py - f.w < box[3] and box[1] < py + f.w:
			return true
	return false


func wire_hazard(f: Dictionary) -> Array:
	## Fiação solta: pendurada do topo do poste, balança; caixa de perigo inclui o balanço.
	return [f.x2 - 14 * C.SUB, f.y2, f.x2 + 14 * C.SUB, f.y2 + WIRE_DROP * C.SUB]


func _touches(f: Dictionary, box: Array) -> bool:
	if f.type == WIRE:
		if f.state == IDLE:
			# Segmento do prédio ao poste, amostrado a cada 8 px.
			var ddx: int = f.x2 - f.x
			var ddy: int = f.y2 - f.y
			var n: int = maxi(1, maxi(absi(ddx), absi(ddy)) / C.CELL_SUB)
			for k in n + 1:
				var px: int = f.x + ddx * k / n
				var py: int = f.y + ddy * k / n
				if px >= box[0] and px < box[2] and py >= box[1] and py < box[3]:
					return true
			return false
		return _overlaps(wire_hazard(f), box)
	return _overlaps([f.bx0, f.by0, f.bx1, f.by1], box)


func _overlaps(a: Array, b: Array) -> bool:
	return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


# ---------------------------------------------------------------- hash e snapshot

func hash_ints() -> PackedInt64Array:
	var ints := PackedInt64Array([fixtures.size(), chain_total, chain_tick, expl_tick])
	for f in fixtures:
		for k in FIX_KEYS:
			ints.append(int(f[k]))
		ints.append(f.anchors.size())
		for i in f.anchors:
			ints.append(i)
	return ints


func snapshot() -> Dictionary:
	return {"fixtures": fixtures.duplicate(true), "chain_total": chain_total, "chain_tick": chain_tick,
		"expl_tick": expl_tick}


func restore(s: Dictionary) -> void:
	fixtures = s.fixtures.duplicate(true)
	chain_total = s.chain_total
	chain_tick = s.chain_tick
	expl_tick = s.expl_tick
