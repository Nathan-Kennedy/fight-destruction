extends Node2D
## Lutadores: sprite animado pelo estado da simulação (assets de game/assets/chr, lote 02) ou,
## sem asset, placeholder de retângulo (§9.4). Hitbox visível com F3, piscar em hitstun e
## invulnerabilidade, posição interpolada. Só lê o estado; nunca escreve na simulação.

const C = preload("res://sim/sim_const.gd")
const A = preload("res://sim/attacks.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")

# Golpe → animação. O frame acompanha atk_t, então contato visual e hitbox andam juntos.
const ATTACK_ANIM := {A.JAB: "jab", A.STRONG_SIDE: "strong", A.STRONG_UP: "strong_up",
	A.STRONG_DOWN_AIR: "spike", A.STOMP: "stomp", A.GRAB: "grab", A.BURST: "burst"}

const COLORS := [Color(1.0, 0.48, 0.18), Color(0.25, 0.82, 1.0), Color(0.62, 1.0, 0.3), Color(1.0, 0.35, 0.7)]
const OUTLINE := Color(0.08, 0.06, 0.1)

var sim
var prev := []   # posições [x, y] em subpixels do tick anterior
var alpha := 0.0
var show_hitboxes := false
var lib := SpriteLib.new()
var _anim := {}     # id → nome da animação atual
var _start := {}    # id → tick em que ela começou
var _air := {}      # id → estava no ar no último quadro (para a animação de pouso)
var _land := {}     # id → tick do último pouso
var _hit := {}      # id → [tick do acerto, kb, atacante, freeze no acerto]
var _ghosts := {}   # id → [[origem, tamanho, região, espelho, textura, idade]] afterimages
var _trail := []    # rastro de fumaça do lançamento: [pos, idade, raio, cor]
var _last_trail := {}


func on_hit(id: int, kb: int, attacker := -1) -> void:
	_hit[id] = [sim.tick, kb, attacker, maxi(1, sim.freeze)]


func _hitstop_shake(i: int, f: Dictionary) -> Vector2:
	## Tremor durante o hitstop (Smash, REFERENCIAS_VFX.md §2): o atingido vibra de lado no chão e
	## para cima/baixo no ar; o atacante vibra junto com ~30% da amplitude. Amplitude cai linearmente
	## até 0 no fim do congelamento. Alterna pela paridade do tick (determinístico, igual no replay).
	if sim.freeze <= 0:
		return Vector2.ZERO
	var amp := 0.0
	if f.hitstun > 0 and _hit.has(i):
		var h: Array = _hit[i]
		if sim.tick - int(h[0]) < int(h[3]):
			amp = clampf(h[1] / 500.0, 2.0, 5.0) * float(sim.freeze) / float(h[3])
	if amp == 0.0:
		for id in _hit:
			var h: Array = _hit[id]
			if int(h[2]) == i and sim.tick - int(h[0]) < int(h[3]):
				var full: float = clampf(h[1] / 500.0, 2.0, 5.0) * float(sim.freeze) / float(h[3])
				amp = maxf(amp, maxf(1.0, full * 0.3))
	if amp == 0.0:
		return Vector2.ZERO
	var sgn := 1.0 if sim.tick % 2 == 0 else -1.0
	return Vector2(0, amp * sgn) if not f.grounded else Vector2(amp * sgn, 0)


func pos_of(i: int) -> Vector2:
	var f: Dictionary = sim.fighters[i]
	var p := Vector2(f.x, f.y)
	if i < prev.size():
		p = Vector2(prev[i][0], prev[i][1]).lerp(p, alpha)
	return p / C.SUB


func _process(delta: float) -> void:
	_process_trail(delta)
	for id in _ghosts:
		for g in _ghosts[id]:
			g[5] += delta
		_ghosts[id] = _ghosts[id].filter(func(g): return g[5] < 0.18)
	queue_redraw()


func _process_trail(delta: float) -> void:
	for t in _trail:
		t[1] += delta
	_trail = _trail.filter(func(t): return t[1] < 0.7)
	for i in sim.fighters.size():
		var f: Dictionary = sim.fighters[i]
		if f.hitstun <= 0 or f.respawn > 0:
			continue
		var sp := Vector2(f.vx, f.vy).length() / C.SUB
		if sp < 6.0 or sim.tick == int(_last_trail.get(i, -1)):
			continue
		# Rastro só em lançamento forte (Smash): kb do último acerto acima do limiar.
		var info: Array = _hit.get(i, [0, 0, -1])
		if int(info[1]) < 1400:
			continue
		_last_trail[i] = sim.tick
		# Na cor de quem bateu (Smash 4); esquenta para vermelho com percentual alto.
		var who: int = int(info[2])
		var base: Color = Color(0.92, 0.9, 0.88) if who < 0 else COLORS[who].lerp(Color.WHITE, 0.35)
		var hot: float = clampf((f.pct - 100) / 80.0, 0.0, 1.0)
		var col: Color = base.lerp(Color(1.0, 0.3, 0.2), hot)
		_trail.append([pos_of(i) - Vector2(0, f.h / 2.0 / C.SUB), 0.0, 3.0 + sp * 0.35, col])


func _draw() -> void:
	for t in _trail:
		var k: float = t[1] / 0.7
		draw_circle(t[0], t[2] * (1.0 + k * 1.5), Color(t[3], 0.55 * (1.0 - k)))
	for i in sim.fighters.size():
		var f: Dictionary = sim.fighters[i]
		if f.stocks <= 0 or f.respawn > 0:
			continue
		if f.invuln > 0 and (f.invuln / 4) % 2 == 0:
			continue
		var p := pos_of(i)
		var w: float = f.hw * 2.0 / C.SUB
		var h: float = float(f.h) / C.SUB
		var body := Rect2(p.x - w / 2, p.y - h, w, h)
		var col: Color = COLORS[i]
		if f.hitstun > 0 and (sim.tick / 3) % 2 == 0:
			col = col.lerp(Color.WHITE, 0.6)
		if f.intang > 0:
			col.a = 0.45   # esquiva: intangível
		if f.stun > 0:
			col = col.lerp(Color(0.5, 0.5, 0.5), 0.4)
		if not _draw_sprite(i, f, p, col):
			draw_rect(body.grow(1), Color(OUTLINE, col.a))
			draw_rect(body, col)
			var eye_x: float = p.x + (w / 2 - 6) * f.facing
			draw_rect(Rect2(eye_x - 2, p.y - h + 8, 4, 5), OUTLINE)
		# Marcador do jogador (P1/P2) acima da cabeça, na cor do jogador.
		var mk := Vector2(p.x, p.y - h - 10)
		draw_colored_polygon(PackedVector2Array([mk + Vector2(-4, -3), mk + Vector2(4, -3), mk + Vector2(0, 2)]), COLORS[i])
		draw_string(ThemeDB.fallback_font, Vector2(p.x - 7, p.y - h - 14), "P%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLORS[i])
		if f.shielding:
			# Bolha do escudo: encolhe e esquenta conforme perde carga.
			var frac: float = clampf(float(f.shield) / C.SHIELD_MAX, 0.0, 1.0)
			var sc: Color = Color(0.55, 0.9, 1.0).lerp(Color(1.0, 0.35, 0.25), 1.0 - frac)
			var rad: float = (h * 0.45 + 6.0) * (0.55 + 0.45 * frac)
			draw_circle(p - Vector2(0, h / 2), rad, Color(sc, 0.35))
			draw_arc(p - Vector2(0, h / 2), rad, 0, TAU, 32, Color(sc, 0.9), 1.5)
		if f.stun > 0:
			# Atordoado: estrelinhas girando sobre a cabeça.
			for k in 3:
				var ang: float = sim.tick * 0.15 + k * TAU / 3
				draw_rect(Rect2(p + Vector2(cos(ang) * 10 - 1.5, -h - 10 + sin(ang) * 3), Vector2(3, 3)), Color(1, 0.95, 0.4))
		if f.attack == A.BURST:
			# Carga da explosão: anel que fecha até o disparo; depois a onda sai pela debris_fx.
			var st: int = A.LIST[A.BURST].startup
			var k: float = clampf(float(f.atk_t) / st, 0.0, 1.0)
			var ctr := p - Vector2(0, h / 2)
			draw_arc(ctr, 48.0 * (1.0 - k) + 10.0, 0, TAU, 40, Color(1.0, 0.85, 0.35, 0.5 + 0.5 * k), 2.0)
			draw_circle(ctr, 6.0 + 8.0 * k, Color(1.0, 0.95, 0.7, 0.35 + 0.4 * k))
		if f.grabbing >= 0:
			# Mão estendida até o agarrado.
			draw_line(Vector2(p.x + f.facing * w / 2, p.y - h * 0.6), Vector2(p.x + f.facing * (w / 2 + 6), p.y - h * 0.6), OUTLINE, 3)
		if show_hitboxes:
			var box: Array = sim.attack_box(f)
			if not box.is_empty():
				var off := p - Vector2(f.x, f.y) / C.SUB
				var r := Rect2(Vector2(box[0], box[1]) / C.SUB + off, Vector2(box[2] - box[0], box[3] - box[1]) / C.SUB)
				draw_rect(r, Color(1, 0.2, 0.2, 0.45))
			elif f.attack != A.NONE:
				# Anticipação: contorno fino na cor do jogador enquanto o golpe carrega.
				draw_rect(body.grow(3), Color(col, 0.5), false, 1.0)



# ---------------------------------------------------------------- sprites

func _pick(i: int, f: Dictionary) -> Array:
	## [nome da animação, frame em float ou -1 para usar o tempo desde o início].
	if f.held_by >= 0:
		return ["grabbed", -1.0]
	if f.stun > 0:
		return ["stun", -1.0]
	if f.hitstun > 0:
		return ["hurt", -1.0]
	if f.dodge > 0:
		match f.dodge_kind:
			1:
				return ["roll", 1.0 - float(f.dodge) / C.ROLL_TICKS]
			3:
				return ["air_dodge", 1.0 - float(f.dodge) / C.AIR_DODGE_TICKS]
			_:
				return ["spot_dodge", 1.0 - float(f.dodge) / C.SPOT_TICKS]
	if f.shielding:
		return ["shield", -1.0]
	if f.grabbing >= 0:
		return ["grab", 0.5]
	if f.attack != A.NONE and ATTACK_ANIM.has(f.attack):
		return [ATTACK_ANIM[f.attack], float(f.atk_t) / A.total_frames(f.attack)]
	if f.hold_prop >= 0:
		if f.grounded and absi(f.vx) > 64:
			return ["carry_run", -1.0]
		return ["carry_idle", -1.0]
	if f.lag > 0:
		return ["throw_obj", -1.0]
	if not f.grounded:
		return ["jump", -1.0] if f.vy < 0 else ["fall", -1.0]
	if sim.tick - int(_land.get(i, -99)) < 8:
		return ["land", float(sim.tick - int(_land[i])) / 8.0]
	if absi(f.vx) > 64:
		return ["run", -1.0]
	return ["idle", -1.0]


func _draw_sprite(i: int, f: Dictionary, p: Vector2, col: Color) -> bool:
	var was_air: bool = _air.get(i, false)
	_air[i] = not f.grounded
	if was_air and f.grounded:
		_land[i] = sim.tick
	var pick := _pick(i, f)
	var name: String = pick[0]
	var a := lib.anim(f.def, name)
	if a.is_empty() and name != "idle":
		# Animação que ainda não existe: cai para uma próxima que exista.
		var fallback := {"fall": "jump", "land": "idle", "carry_run": "run", "carry_idle": "idle",
			"throw_obj": "jab", "strong_up": "strong", "spike": "strong", "stomp": "strong",
			"air_dodge": "fall", "spot_dodge": "shield", "roll": "run", "grabbed": "hurt", "stun": "idle"}
		name = fallback.get(name, "idle")
		pick = [name, pick[1]]
		a = lib.anim(f.def, name)
	if a.is_empty():
		a = lib.anim(f.def, "idle")
		if a.is_empty():
			return false
	if _anim.get(i, "") != name:
		_anim[i] = name
		_start[i] = sim.tick
	var n: int = a.frames
	var k: int
	if pick[1] >= 0.0:
		k = clampi(int(pick[1] * n), 0, n - 1)
	else:
		var t := int((sim.tick - int(_start[i])) * a.fps / 60.0)
		if a.loop:
			k = t % n
		elif name == "hurt" and t >= n:
			k = 2 + (t - n) % maxi(1, n - 3)   # rolando no ar enquanto durar o hitstun
		else:
			k = mini(t, n - 1)
	var sc: float = a.scale
	var src: Rect2 = Rect2(k * a.w, 0, a.w, a.h)
	var size: Vector2 = Vector2(a.w, a.h) * sc
	var local := Rect2(-a.pivot * sc, size)
	# Squash ao pousar, stretch ao subir (só visual).
	var sq := Vector2.ONE
	var since_land: int = sim.tick - int(_land.get(i, -99))
	if since_land < 6:
		var t: float = 1.0 - since_land / 6.0
		sq = Vector2(1.0 + 0.12 * t, 1.0 - 0.14 * t)
	elif not f.grounded and f.vy < -1200 and f.hitstun == 0:
		sq = Vector2(0.92, 1.08)
	# Tremor do atingido e do atacante durante o hitstop (_hitstop_shake).
	var pos: Vector2 = p + _hitstop_shake(i, f)
	var tint := Color(1, 1, 1, col.a) if col.a < 1.0 else _tint(i, f)
	# Afterimages coloridas quando voa rápido lançado.
	if f.hitstun > 0 and Vector2(f.vx, f.vy).length() / C.SUB > 7.0 and Engine.get_frames_drawn() % 3 == 0:
		if not _ghosts.has(i):
			_ghosts[i] = []
		_ghosts[i].append([pos, sq, src, f.facing, a.tex, 0.0, local])
	for g in _ghosts.get(i, []):
		draw_set_transform(g[0], 0.0, Vector2(g[3] * g[1].x, g[1].y))
		draw_texture_rect_region(g[4], g[6], g[2], Color(COLORS[i], 0.35 * (1.0 - g[5] / 0.18)))
	draw_set_transform(pos, 0.0, Vector2(f.facing * sq.x, sq.y))
	draw_texture_rect_region(a.tex, local, src, tint)
	draw_set_transform(Vector2.ZERO)
	return true


func _tint(i: int, f: Dictionary) -> Color:
	# Flash branco nos primeiros quadros do acerto; depois pisca durante o hitstun.
	if _hit.has(i) and sim.tick - int(_hit[i][0]) < 3:
		return Color(3.0, 3.0, 3.0)
	if f.hitstun > 0 and (sim.tick / 3) % 2 == 0:
		return Color(1.6, 1.6, 1.6)
	if f.stun > 0:
		return Color(0.8, 0.8, 0.8)
	return Color.WHITE
