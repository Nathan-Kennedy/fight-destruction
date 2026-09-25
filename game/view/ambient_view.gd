extends Node2D
## Estágio vivo (Docs/arte/prompts_arte_lote02.md §8.4): figurantes na rua e moradores nos cômodos com
## rotina calma → reação (medo | uau) → recuperação, pássaros, gato, laranjas, lanternas, bandeiras,
## pétalas, vapor, neon que falha com tremor, céu com dirigíveis e balões, veículos ao fundo.
##
## Só apresentação: lê `sim.fighters` e `sim.grid`, recebe `events` via main.gd (`on_event`) e
## nunca escreve na simulação. RNG próprio semeado; nada aqui entra no hash nem no replay.
## Camadas: céu e veículos dentro do backdrop (Parallax2D, ambient_sky.gd); figurantes e moradores
## num nó filho da world_view desenhado ENTRE os interiores e a grade (a grade os encobre); este nó
## (entre a grade e os lutadores) desenha vapor, pétalas, pássaros voando e flashes.
## Folhas opcionais (formato de sprite_lib.strip, pivô nos pés): npc/npc_<tipo>[_medo|_uau],
## amb/amb_*; havendo folha, ela substitui o placeholder vetorial. F8 liga/desliga (main.gd).

const C = preload("res://sim/sim_const.gd")
const WorldView = preload("res://view/world_view.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const Fig = preload("res://view/ambient_figures.gd")
const SkyScript = preload("res://view/ambient_sky.gd")

const STREET_Y := 416.0
const NEAR_PX := 120.0        # lutador a esta distância faz o figurante reagir
const CALM_S := 3.2           # segundos de calma para voltar à rotina (mais jitter por figurante)
const RUN_V := 120.0
const WALK_BACK_V := 34.0
const MAX_PETALS := 22
const MAX_STEAM := 40
const MAX_FLASHES := 6
const BIRD_CALM_S := 7.0
const DESAT_STREET := 0.38
const DESAT_ROOM := 0.48

# Figurantes da rua: [tipo, x, lo, hi, velocidade de rotina, tendência a "uau", fuga, altura]
const STREET := [
	["crianca_a", 64.0, 0.0, 0.0, 0.0, 0.45, "corre", 21.0],
	["crianca_b", 106.0, 0.0, 0.0, 0.0, 0.4, "corre", 20.0],
	["pedestre_a", 150.0, 30.0, 330.0, 20.0, 0.35, "corre", 34.0],
	["fotografo", 196.0, 0.0, 0.0, 0.0, 0.9, "corre", 33.0],
	["vendedor", 318.0, 0.0, 0.0, 0.0, 0.45, "esconde", 32.0],
	["streamer", 930.0, 0.0, 0.0, 0.0, 0.85, "esconde", 32.0],
	["idosa", 1000.0, 900.0, 1170.0, 9.0, 0.25, "esconde", 29.0],
	["pedestre_b", 1150.0, 860.0, 1270.0, 24.0, 0.5, "corre", 34.0],
]
# Moradores: [tipo, cômodo (índice em WorldView.ROOMS), x, tendência a "uau", fuga, altura]
const RESIDENTS := [
	["cozinha", 0, 540.0, 0.45, "esconde", 32.0],
	["sofa", 1, 772.0, 0.4, "corre", 32.0],
	["escritorio", 2, 452.0, 0.55, "esconde", 32.0],
	["banho", 3, 734.0, 0.3, "esconde", 32.0],
]
const SHEET_OF := {"crianca_a": "npc_criancas", "idosa": "npc_idosa_sacola", "sofa": "npc_sofa_tv"}
const LOOKS := {
	"pedestre_a": {"top": Color(0.34, 0.37, 0.48), "bottom": Color(0.26, 0.26, 0.32), "skin": Color(0.80, 0.64, 0.54),
		"hair": Color(0.22, 0.16, 0.14), "hair_style": "coque", "skirt": true, "chest": 0.1},
	"pedestre_b": {"top": Color(0.42, 0.56, 0.46), "bottom": Color(0.30, 0.34, 0.46), "skin": Color(0.52, 0.38, 0.28),
		"hair": Color(0.1, 0.09, 0.1), "phones": Color(0.78, 0.42, 0.38)},
	"fotografo": {"top": Color(0.72, 0.54, 0.34), "bottom": Color(0.56, 0.52, 0.42), "skin": Color(0.84, 0.70, 0.60),
		"hair": Color(0.5, 0.36, 0.24), "hat": Color(0.80, 0.76, 0.64), "chest": 0.12},
	"streamer": {"top": Color(0.66, 0.42, 0.56), "bottom": Color(0.26, 0.26, 0.34), "skin": Color(0.74, 0.58, 0.48),
		"hair": Color(0.42, 0.30, 0.52), "hair_style": "longo", "chest": 0.1},
	"idosa": {"top": Color(0.54, 0.46, 0.58), "bottom": Color(0.42, 0.38, 0.36), "skin": Color(0.80, 0.66, 0.58),
		"hair": Color(0.86, 0.84, 0.82), "hair_style": "branco", "skirt": true},
	"vendedor": {"top": Color(0.34, 0.44, 0.54), "bottom": Color(0.28, 0.28, 0.32), "skin": Color(0.66, 0.50, 0.38),
		"hair": Color(0.15, 0.12, 0.12), "band": Color(0.74, 0.36, 0.32), "apron": Color(0.84, 0.82, 0.76), "chest": 0.12},
	"crianca_a": {"top": Color(0.82, 0.66, 0.34), "bottom": Color(0.30, 0.40, 0.56), "skin": Color(0.60, 0.44, 0.34),
		"hair": Color(0.14, 0.1, 0.1), "chest": 0.13, "waist": 0.11},
	"crianca_b": {"top": Color(0.40, 0.62, 0.66), "bottom": Color(0.44, 0.36, 0.40), "skin": Color(0.84, 0.70, 0.60),
		"hair": Color(0.66, 0.44, 0.26), "hair_style": "rabo", "chest": 0.13, "waist": 0.11, "skirt": true},
	"sofa": {"top": Color(0.52, 0.58, 0.42), "bottom": Color(0.34, 0.36, 0.44), "skin": Color(0.70, 0.54, 0.44),
		"hair": Color(0.28, 0.2, 0.16)},
	"banho": {"top": Color(0.78, 0.62, 0.52), "bottom": Color(0.78, 0.62, 0.52), "skin": Color(0.78, 0.62, 0.52),
		"hair": Color(0.82, 0.62, 0.68), "hair_style": "branco"},
	"cozinha": {"top": Color(0.88, 0.86, 0.82), "bottom": Color(0.30, 0.30, 0.34), "skin": Color(0.56, 0.42, 0.32),
		"hair": Color(0.9, 0.9, 0.88), "hat": Color(0.94, 0.92, 0.9), "chest": 0.12},
	"escritorio": {"top": Color(0.66, 0.70, 0.78), "bottom": Color(0.28, 0.30, 0.36), "skin": Color(0.82, 0.66, 0.56),
		"hair": Color(0.3, 0.22, 0.18)},
}
const POLES := [20.0, 240.0, 870.0, 1010.0, 1250.0]
const LANTERN_WIRES := [[20.0, 240.0], [870.0, 1010.0]]
const NEONS := [[30.0, 312.0, 0], [880.0, 318.0, 1]]   # [x, y do topo, estilo]
const MANHOLES := [180.0, 985.0]
const TREE_X := 1195.0
const CAT_PERCH := Vector2(296, 296)
const OUTLINE := Fig.OUTLINE

var sim
var lib: SpriteLib
var enabled := true
var rng := RandomNumberGenerator.new()
var sky
var _back          # Fig.Canvas filho da world_view (entre interiores e grade)
var _t := 0.0
var _frame := 0
var _last_tick := -1
var _npcs := []
var _birds := []
var _cat := {}
var _oranges := []
var _petals := []
var _steam := []
var _flashes := []     # [pos, idade]
var _rooms := []
var _shake := 0.0
var _neon := []        # por letreiro: {fail, off}
var _ball := {}
var _fighters := []    # centros dos lutadores ativos neste quadro
var _view := Rect2(0, 0, 640, 360)


func _init() -> void:
	rng.seed = 424242


func attach(backdrop: Node, world_view: Node) -> void:
	## Chamado por main.gd depois de montar backdrop e world_view.
	if lib == null:
		lib = SpriteLib.new()
	sky = SkyScript.new()
	sky.lib = lib
	sky.rng = rng
	sky.build(backdrop)
	_back = Fig.Canvas.new()
	_back.painter = _draw_back
	world_view.add_child(_back)
	world_view.move_child(_back, 0)   # antes do sprite da grade: a grade encobre os figurantes


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if _back:
		_back.visible = on
	if sky:
		sky.set_on(on)


# ---------------------------------------------------------------- estado

func _reset() -> void:
	rng.seed = 424242
	_npcs.clear()
	_oranges.clear()
	_flashes.clear()
	_steam.clear()
	_petals.clear()
	for s in STREET:
		var n := _npc(s[0], s[1], STREET_Y, s[5], s[6], s[7], -1)
		n.lo = s[2]
		n.hi = s[3]
		n.speed = s[4]
		n.face = 1.0 if rng.randf() < 0.5 else -1.0
		_npcs.append(n)
	_npc_by("fotografo").face = -1.0
	_npc_by("crianca_b").face = -1.0
	_npc_by("crianca_a").face = 1.0
	_npc_by("vendedor").face = 1.0
	_npc_by("streamer").face = -1.0
	_rooms.clear()
	var g = sim.grid
	for r in WorldView.ROOMS:
		var cells := PackedInt32Array()
		for cy in range(r[1] - 2, r[3] + 3):
			for cx in range(r[0] - 2, r[2] + 3):
				if cx < 0 or cy < 0 or cx >= C.GRID_W or cy >= C.GRID_H:
					continue
				var i: int = cy * C.GRID_W + cx
				var m: int = g.mat[i]
				if m != C.M_EMPTY and m != C.M_CORE:
					cells.append(i)
		var px := Rect2(r[0] * C.CELL, r[1] * C.CELL, (r[2] - r[0] + 1) * C.CELL, (r[3] - r[1] + 1) * C.CELL)
		_rooms.append({"cells": cells, "open": 0, "shown": false, "rect": px, "reveal": 0.0})
	for s in RESIDENTS:
		var room: Rect2 = _rooms[s[1]].rect
		var n := _npc(s[0], s[2], room.end.y, s[3], s[4], s[5], s[1])
		n.face = 1.0
		n.state = "oculto"
		n.alpha = 0.0
		_npcs.append(n)
	_birds.clear()
	for k in 4:
		_birds.append(_bird(Vector2(560 + k * 19 + rng.randf_range(-4, 4), 16 * C.CELL)))
	for k in 3:
		_birds.append(_bird(Vector2(1085 + k * 14, STREET_Y)))
	_cat = {"pos": CAT_PERCH, "state": "rotina", "t": 0.0, "calm": 0.0, "face": -1.0, "alpha": 1.0, "vy": 0.0}
	_ball = {"pos": Vector2(85, STREET_Y - 3), "vel": Vector2.ZERO, "free": false}
	_neon = []
	for s in NEONS:
		_neon.append({"fail": 0.0, "off": false, "seed": rng.randf() * 100.0})
	_shake = 0.0


func _npc(kind: String, x: float, y: float, wow: float, flee: String, h: float, room: int) -> Dictionary:
	var look := {}
	var raw: Dictionary = LOOKS[kind]
	var desat := DESAT_ROOM if room >= 0 else DESAT_STREET
	var dark := 0.12 if room >= 0 else 0.04
	for k in raw:
		look[k] = Fig.mute(raw[k], desat, dark) if raw[k] is Color else raw[k]
	return {"kind": kind, "x": x, "y": y, "home": x, "lo": x, "hi": x, "speed": 0.0, "face": 1.0,
		"state": "rotina", "t": 0.0, "ph": rng.randf() * TAU, "wow": wow, "flee": flee, "h": h,
		"room": room, "look": look, "calm": 0.0, "need": CALM_S + rng.randf() * 1.5, "threat": Vector2(x, y),
		"alpha": 1.0, "dir": 1.0, "run": false, "flash_t": 0.0, "lens": Vector2(x, y - h), "dropped": false, "pan": 0.0}


func _npc_by(kind: String) -> Dictionary:
	for n in _npcs:
		if n.kind == kind:
			return n
	return {}


func _bird(p: Vector2) -> Dictionary:
	return {"perch": p, "pos": p, "vel": Vector2.ZERO, "state": "pousado", "t": rng.randf() * 5.0,
		"calm": 0.0, "ph": rng.randf() * TAU, "face": 1.0 if rng.randf() < 0.5 else -1.0, "from": p}


# ---------------------------------------------------------------- eventos (via main.gd)

func on_event(e: Dictionary) -> void:
	if not enabled or _npcs.is_empty():
		return
	match e.kind:
		"hit":
			var v: Dictionary = sim.fighters[e.target]
			var hp := Vector2(v.x, v.y - v.h / 2) / C.SUB
			_shake_add(e.kb / 700.0)
			if e.kb >= 700:
				_threat(hp, 170.0 + e.kb / 12.0, e.kb / 1100.0)
				_scare_birds(hp, 260.0)
		"break":
			var c := _cells_center(e.cells)
			var n: int = e.cells.size()
			_shake_add(1.5 + n / 5.0)
			_threat(c, 130.0 + n * 3.0, 0.9 + n / 25.0)
			_scare_birds(c, 220.0 + n * 4.0)
		"burst":
			var bp := Vector2(e.x, e.y) / C.SUB
			_shake_add(6.0)
			_threat(bp, 280.0, 2.6)
			_scare_birds(bp, 420.0)
		"collapse_warn":
			_collapse_warn(e.cells)
		"collapse_land":
			var lc := _cells_center(e.cells)
			_shake_add(3.0 + e.cells.size() / 40.0)
			_threat(lc, 340.0, 2.8)
			_scare_birds(lc, 600.0)
		"crushed", "buried", "ko":
			_shake_add(7.0)
		"prop_break":
			var pp := Vector2(e.x, e.y) / C.SUB
			_shake_add(2.5)
			_threat(pp, 150.0, 1.2)
			_scare_birds(pp, 200.0)


func _shake_add(a: float) -> void:
	_shake = minf(_shake + a, 10.0)
	if _shake > 4.5:
		for s in _neon:
			if s.fail <= 0.0:
				s.fail = rng.randf_range(1.2, 2.2)


func _cells_center(cells) -> Vector2:
	if cells.is_empty():
		return Vector2(-9999, -9999)
	var s := Vector2.ZERO
	var n := mini(cells.size(), 60)
	for k in n:
		var i: int = cells[k * cells.size() / n]
		s += Vector2((i % C.GRID_W) * C.CELL + 4, (i / C.GRID_W) * C.CELL + 4)
	return s / n


func _collapse_warn(cells) -> void:
	## Aviso de colapso: quem está embaixo (ou perto da borda) sempre sente medo.
	if cells.is_empty():
		return
	var x0 := 99999.0
	var x1 := -99999.0
	var top := 99999.0
	for i in cells:
		var cx: float = (i % C.GRID_W) * C.CELL
		x0 = minf(x0, cx)
		x1 = maxf(x1, cx + C.CELL)
		top = minf(top, (i / C.GRID_W) * C.CELL)
	var c := Vector2((x0 + x1) * 0.5, top)
	for n in _npcs:
		if n.state == "oculto":
			continue
		var under: bool = n.x > x0 - 60.0 and n.x < x1 + 60.0 and n.y > top - 40.0
		if under:
			_trigger(n, 3.0, c, true)
		elif absf(n.x - c.x) < 360.0:
			_trigger(n, 1.8, c)
	_scare_birds(c, 400.0)


func _threat(p: Vector2, radius: float, strength: float) -> void:
	for n in _npcs:
		if n.state == "oculto":
			continue
		if (Vector2(n.x, n.y - n.h * 0.5) - p).length() < radius:
			_trigger(n, strength, p)
	if _cat.state == "rotina" and (_cat.pos - p).length() < radius + 40.0:
		_cat_react(p)


func _trigger(n: Dictionary, strength: float, p: Vector2, force_fear := false) -> void:
	n.calm = 0.0
	n.threat = p
	if force_fear and strength >= 3.0:
		n.run = true   # colapso em cima ou chão sumindo: até quem se esconderia foge
	match n.state:
		"rotina", "volta":
			var p_wow: float = n.wow * clampf(1.35 - strength * 0.35, 0.12, 1.0)
			_start(n, "medo" if force_fear or rng.randf() > p_wow else "uau")
		"uau":
			if force_fear or (strength >= 2.0 and rng.randf() < 0.6 * (1.0 - n.wow)):
				_start(n, "medo")


func _start(n: Dictionary, st: String) -> void:
	n.state = st
	n.t = 0.0
	if st == "uau":
		n.flash_t = 0.15 + rng.randf() * 0.3
	elif st == "medo":
		if n.room >= 0:
			var r: Rect2 = _rooms[n.room].rect
			n.dir = 1.0 if n.x >= n.threat.x else -1.0
			if r.end.x - n.x < 20.0:
				n.dir = -1.0   # encostado na parede do fundo: sai pelo outro lado
		else:
			n.dir = -1.0 if n.home < C.WORLD_W * 0.5 else 1.0
		match n.kind:
			"idosa":
				if not n.dropped:
					n.dropped = true
					for k in 5:
						_oranges.append({"pos": Vector2(n.x + n.face * 5.0, n.y - 12.0), "alpha": 1.0, "fade": false,
							"vel": Vector2(rng.randf_range(-70, 70), rng.randf_range(-120, -40))})
			"cozinha":
				n.pan = 0.001


func _back_to(n: Dictionary) -> void:
	n.state = "rotina"
	n.t = 0.0
	n.run = false
	if n.kind == "idosa" and n.dropped:
		n.dropped = false
		for o in _oranges:
			o.fade = true
	n.pan = 0.0


# ---------------------------------------------------------------- atualização (chamada em _present)

func update(dt: float) -> void:
	if sim == null:
		return
	if sim.tick < _last_tick or _npcs.is_empty():
		_reset()
	_last_tick = sim.tick
	if not enabled:
		return
	_t += dt
	_frame += 1
	_shake *= exp(-dt * 2.5)
	var ct := get_viewport().get_canvas_transform()
	_view = ct.affine_inverse() * get_viewport_rect()
	_fighters.clear()
	for f in sim.fighters:
		if f.stocks > 0 and f.respawn <= 0:
			_fighters.append(Vector2(f.x, f.y - f.h / 2) / C.SUB)
	if _frame % 3 == 0:
		_update_rooms()
	for n in _npcs:
		_update_npc(n, dt)
	_update_birds(dt)
	_update_cat(dt)
	_update_objects(dt)
	_update_particles(dt)
	for s in _neon:
		s.fail = maxf(0.0, s.fail - dt)
		if s.fail > 0.0:
			s.off = rng.randf() < 0.55
		else:
			s.off = rng.randf() < 0.004
	sky.update(dt)
	_back.queue_redraw()
	queue_redraw()


func _update_rooms() -> void:
	## Cômodo "aberto" = células de parede/laje em volta dele (e pilares dentro) que viraram vazio.
	var g = sim.grid
	for ri in _rooms.size():
		var room: Dictionary = _rooms[ri]
		var n := 0
		for i in room.cells:
			if g.mat[i] == C.M_EMPTY:
				n += 1
		if n >= room.open + 2:
			var first: bool = not room.shown
			room.open = n
			room.shown = true
			for r in _npcs:
				if r.room != ri:
					continue
				if first:
					r.state = "rotina"
				var p: Vector2 = _nearest_fighter(Vector2(r.x, r.y))
				_trigger(r, 2.2 if first else 1.5, p)


func _nearest_fighter(p: Vector2) -> Vector2:
	var best := p + Vector2(40, -20)
	var bd := INF
	for f in _fighters:
		if (f - p).length() < bd:
			bd = (f - p).length()
			best = f
	return best


func _supported(p: Vector2) -> bool:
	var cx := int(p.x) / C.CELL
	var cy := int(p.y + 1.0) / C.CELL
	if cx < 0 or cx >= C.GRID_W or cy < 0 or cy >= C.GRID_H:
		return true
	return sim.grid.mat[cy * C.GRID_W + cx] != C.M_EMPTY


func _update_npc(n: Dictionary, dt: float) -> void:
	n.t += dt
	if n.state == "oculto":
		return
	var room_shown: bool = n.room < 0 or _rooms[n.room].shown
	var target_a := 1.0 if room_shown else 0.0
	if n.state == "fora" and n.room >= 0:
		target_a = 0.0
	n.alpha = move_toward(n.alpha, target_a, dt * 4.0)
	# Lutador perto (~120 px) e chão que sumiu embaixo do figurante da rua.
	if n.state != "fora":
		var c := Vector2(n.x, n.y - n.h * 0.5)
		for f in _fighters:
			var d: float = (f - c).length()
			if d < NEAR_PX:
				_trigger(n, 0.6 + (1.0 - d / NEAR_PX), f)
		if not _supported(Vector2(n.x, n.y)):
			_trigger(n, 3.0, Vector2(n.x, n.y + 10.0), true)
	match n.state:
		"rotina":
			n.ph += dt * (6.0 if n.speed > 0.0 else 1.0)
			if n.speed > 0.0:
				n.x += n.face * n.speed * dt
				if n.x > n.hi:
					n.face = -1.0
				elif n.x < n.lo:
					n.face = 1.0
		"uau":
			n.calm += dt
			n.face = signf(n.threat.x - n.x) if absf(n.threat.x - n.x) > 2.0 else n.face
			if n.kind == "fotografo":
				n.flash_t -= dt
				if n.flash_t <= 0.0:
					n.flash_t = rng.randf_range(0.45, 0.9)
					if _flashes.size() < MAX_FLASHES:
						_flashes.append([n.lens, 0.0])
			if n.calm > n.need:
				_back_to(n)
		"medo":
			n.calm += dt
			if (n.flee == "corre" or n.run) and n.t > 0.3:
				n.face = n.dir
				n.ph += dt * 13.0
				n.x += n.dir * RUN_V * dt
				if n.room >= 0:
					var r: Rect2 = _rooms[n.room].rect
					if n.x < r.position.x + 6.0 or n.x > r.end.x - 6.0:
						n.state = "fora"
				elif n.x < -70.0 or n.x > C.WORLD_W + 70.0:
					n.state = "fora"
			elif n.flee == "esconde":
				if n.kind == "cozinha" and n.pan > 0.0:
					n.pan += dt
				if n.calm > n.need + 1.0:
					_back_to(n)
			else:
				n.face = signf(n.threat.x - n.x) if absf(n.threat.x - n.x) > 2.0 else n.face
		"fora":
			n.calm += dt
			if n.calm > n.need + 2.0:
				n.state = "volta"
				n.t = 0.0
				if n.room >= 0:
					n.x = n.home
		"volta":
			if n.room >= 0:
				_back_to(n)
			else:
				n.face = signf(n.home - n.x)
				n.ph += dt * 6.0
				n.x = move_toward(n.x, n.home, WALK_BACK_V * dt)
				if absf(n.x - n.home) < 0.5:
					_back_to(n)


func _update_birds(dt: float) -> void:
	for b in _birds:
		b.t += dt
		match b.state:
			"pousado":
				for f in _fighters:
					if (f - b.pos).length() < 80.0:
						_fly(b, f)
				if not _supported(b.perch):
					_fly(b, b.pos + Vector2(0, 20))
			"voa":
				b.vel.y -= 40.0 * dt
				b.pos += b.vel * dt
				b.calm += dt
				if b.pos.y < -300.0 or b.calm > 6.0:
					b.state = "fora"
			"fora":
				b.calm += dt
				if b.calm > BIRD_CALM_S and _supported(b.perch):
					b.state = "volta"
					b.t = 0.0
					b.from = b.perch + Vector2(b.face * -260.0, -220.0)
			"volta":
				var k := clampf(b.t / 3.0, 0.0, 1.0)
				var s := k * k * (3.0 - 2.0 * k)
				b.pos = b.from.lerp(b.perch, s) + Vector2(0, -sin(k * PI) * 30.0)
				b.face = signf(b.perch.x - b.from.x)
				if k >= 1.0:
					b.state = "pousado"


func _fly(b: Dictionary, from: Vector2) -> void:
	if b.state == "voa":
		return
	b.state = "voa"
	b.calm = 0.0
	var away := signf(b.pos.x - from.x)
	if away == 0.0:
		away = 1.0
	b.face = away
	b.vel = Vector2(away * rng.randf_range(50, 95), rng.randf_range(-150, -95))


func _scare_birds(p: Vector2, radius: float) -> void:
	for b in _birds:
		if b.state == "pousado" and (b.pos - p).length() < radius:
			_fly(b, p)
		elif b.state == "volta" and (b.pos - p).length() < radius:
			b.state = "voa"
			b.vel = Vector2(b.face * -80.0, -120.0)
			b.calm = 0.0
		elif b.state == "fora":
			b.calm = 0.0


func _cat_react(p: Vector2) -> void:
	_cat.state = "arrepia"
	_cat.t = 0.0
	_cat.calm = 0.0
	_cat.face = -1.0 if p.x > _cat.pos.x else 1.0


func _update_cat(dt: float) -> void:
	_cat.t += dt
	match _cat.state:
		"rotina":
			for f in _fighters:
				if (f - _cat.pos).length() < 90.0:
					_cat_react(f)
			if not _supported(CAT_PERCH):
				_cat_react(_cat.pos + Vector2(0, 10))
		"arrepia":
			if _cat.t > 0.45:
				_cat.state = "foge"
				_cat.t = 0.0
				_cat.vy = -90.0
		"foge":
			_cat.pos.x += _cat.face * 150.0 * dt
			if _cat.pos.y < STREET_Y or _cat.vy < 0.0:
				_cat.vy += 500.0 * dt
				_cat.pos.y = minf(_cat.pos.y + _cat.vy * dt, STREET_Y)
			var off: bool = _cat.pos.x < -40.0 or _cat.pos.x > C.WORLD_W + 40.0
			if off:
				_cat.state = "fora"
				_cat.calm = 0.0
		"fora":
			_cat.calm += dt
			if _cat.calm > 8.0 and _supported(CAT_PERCH):
				_cat.state = "rotina"
				_cat.pos = CAT_PERCH
				_cat.alpha = 0.0
	_cat.alpha = move_toward(_cat.alpha, 1.0, dt * 1.5)


func _update_objects(dt: float) -> void:
	for o in _oranges:
		o.vel.y += 500.0 * dt
		o.pos += o.vel * dt
		if o.pos.y > STREET_Y - 2.0:
			o.pos.y = STREET_Y - 2.0
			o.vel.y *= -0.35
			o.vel.x *= 0.9
		o.vel.x *= exp(-dt * 0.8)
		if o.fade:
			o.alpha -= dt * 1.5
	_oranges = _oranges.filter(func(o): return o.alpha > 0.0)
	# Bola das crianças: passa de uma para a outra enquanto as duas estão na rotina.
	var a := _npc_by("crianca_a")
	var b := _npc_by("crianca_b")
	if a.state == "rotina" and b.state == "rotina" and not _ball.free:
		var k := fposmod(_t * 0.7, 2.0)
		var u := k if k < 1.0 else 2.0 - k
		var x0: float = a.x + 6.0
		var x1: float = b.x - 6.0
		_ball.pos = Vector2(lerpf(x0, x1, u), STREET_Y - 2.5 - sin(u * PI) * 14.0)
	else:
		if not _ball.free:
			_ball.free = true
			_ball.vel = Vector2(rng.randf_range(-40, 40), -60)
		_ball.vel.y += 400.0 * dt
		_ball.pos += _ball.vel * dt
		if _ball.pos.y > STREET_Y - 2.5:
			_ball.pos.y = STREET_Y - 2.5
			_ball.vel.y *= -0.5
			_ball.vel.x *= 0.95
		if a.state == "rotina" and b.state == "rotina":
			_ball.free = false


func _update_particles(dt: float) -> void:
	# Vapor de bueiro e da barraca.
	var sources := []
	for mx in MANHOLES:
		sources.append([Vector2(mx, STREET_Y - 1), 1.0])
	var v := _npc_by("vendedor")
	sources.append([Vector2(v.home + 10.0, STREET_Y - 29.0), 0.6])
	for s in sources:
		if _steam.size() < MAX_STEAM and rng.randf() < dt * 5.0 * s[1]:
			_steam.append({"pos": s[0] + Vector2(rng.randf_range(-4, 4), 0), "vel": Vector2(rng.randf_range(-4, 6), rng.randf_range(-20, -12)),
				"r": rng.randf_range(2.0, 3.5), "age": 0.0, "dur": rng.randf_range(1.6, 2.6)})
	for s in _steam:
		s.age += dt
		s.pos += s.vel * dt
		s.vel.x += sin(_t * 1.3 + s.r) * 3.0 * dt
	_steam = _steam.filter(func(s): return s.age < s.dur)
	# Pétalas: da cerejeira e do alto da tela, poucas.
	if _petals.size() < MAX_PETALS and rng.randf() < dt * 4.0:
		var from_tree := rng.randf() < 0.4
		var p := Vector2(TREE_X + rng.randf_range(-22, 22), STREET_Y - 60 + rng.randf_range(-12, 12)) if from_tree \
			else Vector2(rng.randf_range(_view.position.x, _view.end.x + 60), _view.position.y - 6)
		_petals.append({"pos": p, "vel": Vector2(rng.randf_range(-22, -8), rng.randf_range(10, 20)), "ph": rng.randf() * TAU, "age": 0.0})
	for p in _petals:
		p.age += dt
		p.pos += (p.vel + Vector2(sin(_t * 1.7 + p.ph) * 10.0, 0)) * dt
	_petals = _petals.filter(func(p): return p.age < 12.0 and p.pos.y < STREET_Y + 4)
	for f in _flashes:
		f[1] += dt
	_flashes = _flashes.filter(func(f): return f[1] < 0.16)


# ---------------------------------------------------------------- desenho: camada da frente (este nó)

func _draw() -> void:
	if not enabled:
		return
	for mx in MANHOLES:
		draw_line(Vector2(mx - 7, STREET_Y + 0.5), Vector2(mx + 7, STREET_Y + 0.5), Color(0.08, 0.07, 0.1, 0.9), 1.4)
		for k in 3:
			draw_line(Vector2(mx - 5 + k * 5, STREET_Y), Vector2(mx - 5 + k * 5, STREET_Y + 1.2), Color(0.35, 0.32, 0.36, 0.8), 0.8)
	for s in _steam:
		var k: float = s.age / s.dur
		draw_circle(s.pos, s.r * (1.0 + k * 2.2), Color(0.86, 0.84, 0.86, 0.22 * (1.0 - k) * minf(1.0, k * 6.0)))
	for p in _petals:
		var ang: float = _t * 2.0 + p.ph
		var d := Vector2(cos(ang), sin(ang) * 0.5)
		var pc := Color(0.90, 0.72, 0.76, 0.75 * minf(1.0, (12.0 - p.age) / 2.0))
		draw_line(p.pos - d * 1.4, p.pos + d * 1.4, pc, 1.3)
	for b in _birds:
		if b.state == "voa" or b.state == "volta":
			_draw_bird_flying(self, b)
	for f in _flashes:
		Fig.flash(self, f[0], 1.0 - f[1] / 0.16)


func _draw_bird_flying(ci: CanvasItem, b: Dictionary) -> void:
	var fl := sin(b.t * 22.0 + b.ph)
	var col := Color(0.36, 0.34, 0.40)
	var p: Vector2 = b.pos
	ci.draw_circle(p, 2.0, OUTLINE)
	ci.draw_circle(p, 1.4, col)
	ci.draw_line(p, p + Vector2(-3.5, -3.5 * fl), OUTLINE, 1.6)
	ci.draw_line(p, p + Vector2(3.5, -3.5 * fl), OUTLINE, 1.6)
	ci.draw_line(p, p + Vector2(-3.2, -3.2 * fl), col.lightened(0.15), 0.8)
	ci.draw_line(p, p + Vector2(3.2, -3.2 * fl), col.lightened(0.15), 0.8)
	ci.draw_circle(p + Vector2(b.face * 2.0, -0.6), 1.0, col)


# ---------------------------------------------------------------- desenho: camada de trás (entre interiores e grade)

func _draw_back(ci: CanvasItem) -> void:
	if not enabled or _npcs.is_empty():
		return
	_draw_street_furniture(ci)
	for n in _npcs:
		if n.room >= 0:
			_draw_room(ci, n)
	for n in _npcs:
		if n.room < 0:
			_draw_street_npc(ci, n)
	_draw_stall_front(ci)
	for o in _oranges:
		Fig.ball(ci, o.pos, 1.8, Color(0.82, 0.56, 0.30), o.alpha)
	Fig.ball(ci, _ball.pos, 2.5, Fig.mute(Color(0.80, 0.40, 0.36), 0.3, 0.0))
	for b in _birds:
		if b.state == "pousado":
			_draw_bird_perched(ci, b)
	_draw_cat(ci)


func _fade_near_fighters(n: Dictionary) -> float:
	## Legibilidade (§9.6): figurante atrás de lutador fica mais apagado.
	var c := Vector2(n.x, n.y - n.h * 0.5)
	for f in _fighters:
		if absf(f.x - c.x) < 22.0 and absf(f.y - c.y) < 30.0:
			return 0.55
	return 1.0


func _sheet(n: Dictionary) -> Dictionary:
	var base: String = SHEET_OF.get(n.kind, "npc_" + n.kind)
	var suf := ""
	if n.state == "medo":
		suf = "_medo"
	elif n.state == "uau":
		suf = "_uau"
	var s: Dictionary = lib.strip("npc/%s%s" % [base, suf])
	if s.is_empty() and suf != "":
		s = lib.strip("npc/%s" % base)
	return s


func _draw_sheet_npc(ci: CanvasItem, n: Dictionary, sheet: Dictionary, a: float) -> void:
	## Folha npc_*: frame pelo tempo do estado; altura do quadro ≈ 1,25 × altura do figurante.
	var fr := int(n.t * sheet.fps)
	fr = fr % sheet.frames if sheet.loop or n.state == "rotina" else mini(fr, sheet.frames - 1)
	var sc: float = n.h * 1.25 / float(sheet.h)
	ci.draw_set_transform(Vector2(n.x, n.y), 0.0, Vector2(sc * n.face, sc))
	ci.draw_texture_rect_region(sheet.tex, Rect2(-sheet.pivot, Vector2(sheet.w, sheet.h)),
		Rect2(fr * sheet.w, 0, sheet.w, sheet.h), Color(0.86, 0.84, 0.86, a))
	ci.draw_set_transform(Vector2.ZERO)
	n.lens = Vector2(n.x + n.face * n.h * 0.2, n.y - n.h * 0.85)


func _draw_street_npc(ci: CanvasItem, n: Dictionary) -> void:
	if n.state == "fora" or n.alpha <= 0.01:
		return
	if n.kind == "crianca_b" and not lib.strip("npc/npc_criancas").is_empty():
		return
	var a: float = n.alpha * _fade_near_fighters(n)
	var sheet := _sheet(n)
	if not sheet.is_empty():
		_draw_sheet_npc(ci, n, sheet, a)
		return
	var feet := Vector2(n.x, n.y)
	var p := _pose(n)
	if n.kind == "vendedor" and n.state == "medo" and not n.run:
		feet.x -= n.face * 4.0
	var j := Fig.person(ci, feet, n.face, p, n.look, n.h, a)
	_draw_props(ci, n, j, a)


func _run_pose(n: Dictionary) -> Dictionary:
	if n.t < 0.3:
		return Fig.pose({"lean": -0.3, "ua_f": 2.5, "la_f": 0.4, "ua_b": 2.2, "la_b": 0.5, "lift": 2.0, "head": -0.2,
			"th_f": 0.3, "th_b": -0.3})
	if n.kind == "fotografo":
		var p := Fig.run(n.ph)
		p.ua_f = 0.5
		p.la_f = 2.2
		p.ua_b = 0.7
		p.la_b = 2.1
		return p
	return Fig.run_panic(n.ph)


func _pose(n: Dictionary) -> Dictionary:
	var st: String = n.state
	var t: float = n.t
	if st == "volta":
		return Fig.walk(n.ph, 0.4)
	if st == "medo" and (n.flee == "corre" or n.run):
		return _run_pose(n)
	match n.kind:
		"pedestre_a", "pedestre_b":
			if st == "uau":
				return Fig.pose({"ua_f": 2.2, "la_f": 0.05, "ua_b": 0.2, "la_b": 0.8, "lean": -0.06, "head": -0.1})
			return Fig.walk(n.ph, 0.42)
		"idosa":
			if st == "uau":
				var c := sin(t * 14.0) * 0.35
				return Fig.pose({"ua_f": 1.1, "la_f": 1.0 + c, "ua_b": 1.1, "la_b": 1.0 - c, "lean": 0.15})
			if st == "medo":
				return Fig.crouch(sin(t * 30.0) * 0.06)
			var w := Fig.walk(n.ph, 0.22)
			w.lean = 0.22
			w.ua_f = 0.25
			w.la_f = 0.4
			return w
		"fotografo":
			if st == "uau" or fposmod(t + n.ph, 4.0) < 2.4:
				return Fig.pose({"ua_f": 1.35, "la_f": 1.75, "ua_b": 1.2, "la_b": 1.9,
					"head": -0.3 if st == "rotina" else 0.0, "lean": -0.08 if st == "rotina" else 0.05})
			return Fig.pose({"ua_f": 0.35, "la_f": 1.2, "head": 0.1})
		"streamer":
			if st == "uau":
				return Fig.pose({"ua_f": 1.75, "la_f": 0.1, "ua_b": 2.3 + sin(t * 9.0) * 0.3, "la_b": 0.4,
					"lift": absf(sin(t * 8.0)) * 3.0, "lean": 0.05})
			if st == "medo":
				return Fig.crouch(sin(t * 25.0) * 0.05)
			return Fig.pose({"ua_f": 1.4, "la_f": 0.25, "head": 0.08 + sin(t * 5.0) * 0.06,
				"ua_b": 0.5 + sin(t * 2.6) * 0.35, "la_b": 1.1})
		"vendedor":
			if st == "uau":
				return Fig.pose({"ua_f": 2.85 + sin(t * 10.0) * 0.15, "la_f": 0.15, "ua_b": 2.5, "la_b": 0.4, "lift": absf(sin(t * 7.0)) * 1.5})
			if st == "medo":
				return Fig.crouch(sin(t * 28.0) * 0.05)
			return Fig.pose({"ua_f": 0.95 + sin(t * 5.0) * 0.25, "la_f": 0.9, "ua_b": 0.7, "la_b": 1.0, "lean": 0.08})
		"crianca_a", "crianca_b":
			if st == "uau":
				var punch := sin(t * 9.0) > 0.0
				return Fig.pose({"ua_f": 1.57 if punch else 0.7, "la_f": 0.0 if punch else 1.8,
					"ua_b": 0.7 if punch else 1.57, "la_b": 1.8 if punch else 0.0, "lift": absf(sin(t * 9.0)) * 4.0,
					"th_f": 0.3, "th_b": -0.3})
			# Chute quando a bola chega.
			var bd: float = absf(_ball.pos.x - n.x)
			if bd < 9.0 and not _ball.free:
				return Fig.pose({"th_f": 0.9, "sh_f": -0.2, "th_b": -0.1, "ua_f": -0.4, "ua_b": 0.6, "lean": -0.1})
			return Fig.pose({"lift": absf(sin(_t * 3.0 + n.ph)) * 0.8, "ua_f": 0.3, "ua_b": -0.3})
	return Fig.pose()


func _draw_props(ci: CanvasItem, n: Dictionary, j: Dictionary, a: float) -> void:
	var face: float = n.face
	var hf: Vector2 = j.hf
	var hb: Vector2 = j.hb
	match n.kind:
		"pedestre_a":
			if n.state != "medo":
				Fig.box(ci, Rect2(hb + Vector2(-3.5, 0), Vector2(7, 5)), Fig.mute(Color(0.42, 0.30, 0.24), 0.3, 0.0), a)
		"fotografo":
			n.lens = Fig.camera(ci, hf, face, a)
			ci.draw_line(j.neck, hf + Vector2(0, -1), Color(0.15, 0.13, 0.16, a * 0.8), 0.6)
		"streamer", "cozinha", "escritorio":
			if n.state == "uau" or n.kind == "streamer":
				var sc := Fig.phone(ci, hf, face, 0.6 if n.state == "uau" else 0.35, a)
				if n.state == "uau" and int(n.t * 2.0) % 2 == 0:
					ci.draw_circle(sc + Vector2(face * 2.0, -1.5), 0.9, Color(1.0, 0.35, 0.3, a))
		"idosa":
			if not n.dropped:
				var bag := Rect2(hf + Vector2(-3.5, -1.0), Vector2(7, 7))
				Fig.box(ci, bag, Fig.mute(Color(0.62, 0.54, 0.40), 0.3, 0.0), a)
				for k in 3:
					ci.draw_circle(bag.position + Vector2(1.8 + k * 1.8, 0.2), 1.3, Color(0.80, 0.55, 0.32, a))
		"vendedor":
			if n.state != "medo":
				var tip := hf + Vector2(face * 2.0, -5.0) if n.state == "uau" else hf + Vector2(face * 5.0, 1.0)
				ci.draw_line(hf, tip, Color(OUTLINE, a), 2.0)
				ci.draw_line(hf, tip, Color(0.72, 0.72, 0.74, a), 1.0)


# ---------------------------------------------------------------- rua: mobiliário

func _draw_street_furniture(ci: CanvasItem) -> void:
	var pole_c := Fig.mute(Color(0.30, 0.30, 0.36), 0.3, 0.0)
	for x in POLES:
		ci.draw_line(Vector2(x, STREET_Y), Vector2(x, 252), OUTLINE, 3.2)
		ci.draw_line(Vector2(x, STREET_Y), Vector2(x, 252), pole_c, 1.6)
		ci.draw_line(Vector2(x, 254), Vector2(x + 7, 250), OUTLINE, 2.0)
		ci.draw_circle(Vector2(x + 8, 252), 7.0, Color(1.0, 0.82, 0.55, 0.10))
		Fig.box(ci, Rect2(x + 5, 250, 6, 3), Fig.mute(Color(0.98, 0.86, 0.6), 0.2, 0.0))
	# Fios com lanternas de papel balançando.
	var sway := 1.0 + minf(_shake, 6.0) * 0.35
	for w in LANTERN_WIRES:
		var pts := PackedVector2Array()
		for k in 17:
			var u := k / 16.0
			pts.append(Vector2(lerpf(w[0], w[1], u), 262.0 + sin(u * PI) * 16.0))
		ci.draw_polyline(pts, Color(0.12, 0.1, 0.14, 0.9), 0.8)
		for k in range(1, 6):
			var u := k / 6.0
			var at := Vector2(lerpf(w[0], w[1], u), 262.0 + sin(u * PI) * 16.0)
			var ang := sin(_t * 1.6 + k * 1.3 + w[0]) * 0.14 * sway
			var c := at + Vector2(sin(ang), cos(ang)) * 7.0
			ci.draw_line(at, c, Color(0.1, 0.08, 0.12), 0.6)
			ci.draw_circle(c, 7.0, Color(1.0, 0.6, 0.4, 0.07))
			Fig.poly(ci, Fig.ellipse(c, 3.6, 4.4, 14), Fig.mute(Color(0.86, 0.34, 0.28), 0.25, 0.0))
			ci.draw_line(c + Vector2(0, -4.4), c + Vector2(0, 4.4), Color(0.6, 0.22, 0.2, 0.7), 0.5)
			ci.draw_circle(c + Vector2(-0.8, -0.6), 1.5, Color(1.0, 0.8, 0.55, 0.45))
			ci.draw_rect(Rect2(c + Vector2(-2, -5.2), Vector2(4, 1.2)), Color(0.15, 0.12, 0.14))
	# Letreiros neon (glifos abstratos ilegíveis); falham com tremor forte.
	for si in NEONS.size():
		_draw_neon(ci, NEONS[si], _neon[si])
	_draw_tree(ci)
	# Barraca do vendedor (fundo): toldo listrado, bandeira nobori e chapa.
	var vx: float = _npc_by("vendedor").home
	var aw_y := STREET_Y - 42.0
	ci.draw_line(Vector2(vx - 20, STREET_Y), Vector2(vx - 20, aw_y), OUTLINE, 2.4)
	ci.draw_line(Vector2(vx + 20, STREET_Y), Vector2(vx + 20, aw_y), OUTLINE, 2.4)
	var awn := PackedVector2Array([Vector2(vx - 24, aw_y - 2), Vector2(vx + 24, aw_y - 2), Vector2(vx + 27, aw_y + 6), Vector2(vx - 27, aw_y + 6)])
	Fig.poly(ci, awn, Fig.mute(Color(0.86, 0.82, 0.74), 0.3, 0.0))
	for k in 5:
		var x0 := vx - 24 + k * 10.8
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, aw_y - 2), Vector2(x0 + 5.4, aw_y - 2), Vector2(x0 + 5.4 + (k - 2) * 0.6, aw_y + 6), Vector2(x0 + (k - 2) * 0.6, aw_y + 6)]),
			Fig.mute(Color(0.78, 0.34, 0.30), 0.3, 0.0))
	var fx := vx - 30.0
	ci.draw_line(Vector2(fx, STREET_Y), Vector2(fx, STREET_Y - 46), OUTLINE, 1.6)
	var flag := PackedVector2Array()
	var wave := 1.0 + minf(_shake, 6.0) * 0.4
	for k in 7:
		flag.append(Vector2(fx + 1 + sin(_t * 3.0 + k * 0.7) * 0.8 * wave * k / 6.0, STREET_Y - 44 + k * 4.5))
	for k in range(6, -1, -1):
		flag.append(Vector2(fx + 8 + sin(_t * 3.0 + k * 0.7 + 0.8) * 1.4 * wave * k / 6.0 + k * 0.1, STREET_Y - 44 + k * 4.5))
	Fig.poly(ci, flag, Fig.mute(Color(0.34, 0.56, 0.62), 0.3, 0.0))
	for k in 3:
		ci.draw_line(Vector2(fx + 3, STREET_Y - 38 + k * 8), Vector2(fx + 6, STREET_Y - 38 + k * 8 + (k % 2) * 2), Color(0.92, 0.9, 0.84, 0.8), 1.0)


func _draw_stall_front(ci: CanvasItem) -> void:
	var vx: float = _npc_by("vendedor").home
	var top := STREET_Y - 17.0
	Fig.box(ci, Rect2(vx - 2, top - 3, 22, 3), Fig.mute(Color(0.32, 0.30, 0.34), 0.2, 0.0))
	Fig.box(ci, Rect2(vx - 20, top, 40, 17), Fig.mute(Color(0.58, 0.40, 0.28), 0.35, 0.0))
	ci.draw_rect(Rect2(vx - 20, top + 3, 40, 2), Fig.mute(Color(0.78, 0.34, 0.30), 0.3, 0.0))
	for k in 3:
		ci.draw_circle(Vector2(vx + 3 + k * 6, top - 4), 1.8, Color(0.84, 0.66, 0.40))
	# Lanterna pendurada no toldo.
	var c := Vector2(vx - 14, STREET_Y - 30) + Vector2(sin(_t * 2.0) * 1.2, 0)
	Fig.poly(ci, Fig.ellipse(c, 2.8, 3.6, 12), Fig.mute(Color(0.9, 0.4, 0.3), 0.2, 0.0))


func _draw_neon(ci: CanvasItem, s: Array, st: Dictionary) -> void:
	var x: float = s[0]
	var y: float = s[1]
	var r := Rect2(x, y, 12, 40)
	ci.draw_line(Vector2(x - 6 if s[2] == 0 else x + 18, y + 4), Vector2(x, y + 4), OUTLINE, 1.2)
	Fig.box(ci, r, Color(0.14, 0.12, 0.18))
	var col := Fig.mute(Color(1.0, 0.36, 0.62) if s[2] == 0 else Color(0.36, 0.9, 0.95), 0.35, 0.0)
	if st.off:
		col = col.darkened(0.7)
	var strokes := [[Vector2(3, 5), Vector2(9, 5)], [Vector2(6, 5), Vector2(6, 14)], [Vector2(3, 11), Vector2(9, 16)],
		[Vector2(3, 21), Vector2(9, 21)], [Vector2(9, 21), Vector2(5, 28)], [Vector2(3, 32), Vector2(9, 35)], [Vector2(6, 30), Vector2(6, 37)]]
	for k in strokes.size():
		var a: Vector2 = strokes[k][0]
		var b: Vector2 = strokes[k][1]
		if s[2] == 1:
			a = Vector2(12 - a.x, a.y)
			b = Vector2(12 - b.x, b.y)
		if not st.off:
			ci.draw_line(r.position + a, r.position + b, Color(col, 0.25), 3.2)
		ci.draw_line(r.position + a, r.position + b, col, 1.1)
	if not st.off:
		ci.draw_rect(r.grow(3), Color(col, 0.05))
	elif st.fail > 0.0 and rng.randf() < 0.2:
		var sp := r.position + Vector2(rng.randf_range(0, 12), rng.randf_range(0, 40))
		ci.draw_line(sp, sp + Vector2(rng.randf_range(-3, 3), rng.randf_range(1, 4)), Color(1.0, 0.9, 0.6), 0.8)


func _draw_tree(ci: CanvasItem) -> void:
	var base := Vector2(TREE_X, STREET_Y)
	var trunk := Fig.mute(Color(0.34, 0.26, 0.24), 0.2, 0.0)
	ci.draw_line(base, base + Vector2(-3, -40), OUTLINE, 5.0)
	ci.draw_line(base, base + Vector2(-3, -40), trunk, 3.0)
	ci.draw_line(base + Vector2(-2, -30), base + Vector2(12, -52), OUTLINE, 3.4)
	ci.draw_line(base + Vector2(-2, -30), base + Vector2(12, -52), trunk, 1.8)
	var blobs := [[-14, -56, 13], [4, -64, 14], [18, -54, 11], [-2, -46, 12], [-22, -44, 8], [14, -44, 9]]
	for b in blobs:
		ci.draw_circle(base + Vector2(b[0], b[1] + sin(_t * 0.9 + b[0]) * 0.6), b[2] + 1.1, OUTLINE)
	for b in blobs:
		ci.draw_circle(base + Vector2(b[0], b[1] + sin(_t * 0.9 + b[0]) * 0.6), b[2], Fig.mute(Color(0.90, 0.66, 0.74), 0.3, 0.05))
	for b in blobs:
		ci.draw_circle(base + Vector2(b[0] - 3, b[1] - 3), b[2] * 0.5, Fig.mute(Color(0.96, 0.80, 0.84), 0.3, 0.0))


func _draw_bird_perched(ci: CanvasItem, b: Dictionary) -> void:
	var p: Vector2 = b.pos
	var peck := fposmod(b.t, 2.6) < 0.4
	var f: float = b.face
	var col := Color(0.44, 0.44, 0.50)
	Fig.poly(ci, Fig.ellipse(p + Vector2(0, -3), 3.2, 2.2, 10), col)
	var head := p + Vector2(f * 3.0, -3.5 if peck else -5.5)
	ci.draw_circle(head, 1.9, OUTLINE)
	ci.draw_circle(head, 1.3, col.darkened(0.1))
	ci.draw_line(head + Vector2(f * 1.2, 0.2), head + Vector2(f * 2.6, 0.8), Color(0.75, 0.62, 0.4), 0.8)
	ci.draw_line(p + Vector2(-f * 3.0, -3), p + Vector2(-f * 5.5, -2), OUTLINE, 1.6)


func _draw_cat(ci: CanvasItem) -> void:
	if _cat.state == "fora":
		return
	var p: Vector2 = _cat.pos
	var f: float = _cat.face
	var a: float = _cat.alpha
	var col := Fig.mute(Color(0.86, 0.60, 0.36), 0.35, 0.05)
	var arch: bool = _cat.state == "arrepia"
	var run: bool = _cat.state == "foge"
	var body_c := p + Vector2(0, -6.5 if arch else -4.0)
	# Rabo.
	var tail := PackedVector2Array()
	for k in 6:
		var u := k / 5.0
		var sw := sin(_t * 2.2 - u * 2.0) * 3.0 * u
		if arch:
			tail.append(p + Vector2(-f * (5 + u * 2), -6 - u * 9))
		elif run:
			tail.append(p + Vector2(-f * (5 + u * 7), -5 - u * 2))
		else:
			tail.append(p + Vector2(-f * (4 + u * 5) + sw, -2 - u * 6 + absf(sw) * 0.3))
	ci.draw_polyline(tail, Color(OUTLINE, a), 3.0 if arch else 2.4)
	ci.draw_polyline(tail, Color(col, a), 1.6 if arch else 1.2)
	if arch:
		Fig.poly(ci, PackedVector2Array([p + Vector2(-5, -3), p + Vector2(-3, -9), p + Vector2(0, -10.5), p + Vector2(3, -9), p + Vector2(5, -3)]), col, a)
		for k in 5:
			var sp := p + Vector2(-4 + k * 2, -9.5 - absf(k - 2.0) * -0.5)
			ci.draw_line(sp, sp + Vector2(0, -1.5), Color(OUTLINE, a), 0.7)
	else:
		Fig.poly(ci, Fig.ellipse(body_c, 5.0, 2.8, 12), col, a)
	# Patas.
	var legs := [Vector2(-3, 0), Vector2(3, 0)]
	for l in legs:
		var sw2 := sin(_t * 18.0 + l.x) * 2.0 if run else 0.0
		ci.draw_line(body_c + Vector2(l.x, 1), p + Vector2(l.x + sw2, 0), Color(OUTLINE, a), 1.8)
		ci.draw_line(body_c + Vector2(l.x, 1), p + Vector2(l.x + sw2, 0), Color(col, a), 0.9)
	var head := body_c + Vector2(f * 5.0, -2.5)
	Fig.poly(ci, PackedVector2Array([head + Vector2(-2.2, -1.5), head + Vector2(-1.6, -4.2), head + Vector2(0, -2.2), head + Vector2(1.6, -4.2), head + Vector2(2.2, -1.5)]), col, a)
	ci.draw_circle(head, 2.6, Color(OUTLINE, a))
	ci.draw_circle(head, 2.0, Color(col, a))
	ci.draw_circle(head + Vector2(f * 0.9, -0.3), 0.55 if not arch else 0.8, Color(0.1, 0.1, 0.1, a))


# ---------------------------------------------------------------- moradores (dentro dos cômodos)

func _draw_room(ci: CanvasItem, n: Dictionary) -> void:
	var room: Dictionary = _rooms[n.room]
	if not room.shown:
		return
	room.reveal = move_toward(room.reveal, 1.0, 0.08)
	var ra: float = room.reveal
	var fl: float = n.y
	var a: float = n.alpha * _fade_near_fighters(n)
	var sheet := _sheet(n)
	var dim := func(c: Color) -> Color: return Fig.mute(c, DESAT_ROOM, 0.14)
	match n.kind:
		"sofa":
			var sx: float = n.home
			# Luz da TV piscando na parede.
			var tv := Vector2(sx + 30, fl - 20)
			var flick := 0.5 + 0.5 * sin(_t * 13.0) * sin(_t * 3.7 + 1.0)
			ci.draw_circle(tv + Vector2(-6, -4), 26.0, Color(0.55, 0.7, 0.95, (0.05 + 0.06 * flick) * ra))
			Fig.box(ci, Rect2(sx - 16, fl - 22, 7, 22), dim.call(Color(0.52, 0.34, 0.30)), ra)
			Fig.box(ci, Rect2(sx - 14, fl - 11, 30, 7), dim.call(Color(0.58, 0.38, 0.32)), ra)
			Fig.box(ci, Rect2(sx - 13, fl - 5, 3, 5), dim.call(Color(0.3, 0.24, 0.22)), ra)
			Fig.box(ci, Rect2(sx + 12, fl - 5, 3, 5), dim.call(Color(0.3, 0.24, 0.22)), ra)
			Fig.box(ci, Rect2(tv.x - 1, fl - 10, 8, 10), dim.call(Color(0.40, 0.32, 0.28)), ra)
			Fig.box(ci, Rect2(tv.x - 2, fl - 26, 3, 15), Color(0.12, 0.12, 0.15), ra)
			ci.draw_rect(Rect2(tv.x - 1.5, fl - 25, 2, 13), Color(0.55, 0.72, 0.95, (0.4 + 0.5 * flick) * ra))
		"escritorio":
			var dx: float = n.home
			Fig.box(ci, Rect2(dx - 7, fl - 12, 2, 12), dim.call(Color(0.3, 0.3, 0.34)), ra)
			Fig.box(ci, Rect2(dx - 10, fl - 13, 9, 2), dim.call(Color(0.36, 0.36, 0.42)), ra)
			Fig.box(ci, Rect2(dx - 11, fl - 26, 2, 14), dim.call(Color(0.36, 0.36, 0.42)), ra)
	if n.state != "oculto" and n.state != "fora" and a > 0.01:
		if not sheet.is_empty():
			_draw_sheet_npc(ci, n, sheet, a)
		else:
			_draw_resident(ci, n, a)
	# Frente do mobiliário (encobre o morador).
	match n.kind:
		"escritorio":
			var dx: float = n.home
			Fig.box(ci, Rect2(dx + 8, fl - 16, 38, 3), dim.call(Color(0.58, 0.46, 0.36)), ra)
			Fig.box(ci, Rect2(dx + 10, fl - 13, 3, 13), dim.call(Color(0.46, 0.36, 0.30)), ra)
			Fig.box(ci, Rect2(dx + 41, fl - 13, 3, 13), dim.call(Color(0.46, 0.36, 0.30)), ra)
			Fig.box(ci, Rect2(dx + 14, fl - 30, 14, 10), Color(0.14, 0.14, 0.18), ra)
			ci.draw_rect(Rect2(dx + 15, fl - 29, 12, 8), Color(0.45, 0.62, 0.72, 0.8 * ra))
			ci.draw_line(Vector2(dx + 21, fl - 20), Vector2(dx + 21, fl - 16), Color(0.14, 0.14, 0.18, ra), 1.5)
			Fig.box(ci, Rect2(dx + 32, fl - 20, 3, 4), dim.call(Color(0.86, 0.84, 0.8)), ra)
		"cozinha":
			var kx: float = n.home
			Fig.box(ci, Rect2(kx + 12, fl - 20, 30, 20), dim.call(Color(0.62, 0.62, 0.66)), ra)
			ci.draw_rect(Rect2(kx + 14, fl - 14, 26, 10), Color(0.2, 0.2, 0.24, ra))
			var pan_fall: float = n.pan
			if pan_fall <= 0.0:
				Fig.box(ci, Rect2(kx + 16, fl - 25, 12, 5), Color(0.2, 0.2, 0.24), ra)
				ci.draw_line(Vector2(kx + 16, fl - 23), Vector2(kx + 9, fl - 24), Color(OUTLINE, ra), 1.6)
				if n.state != "oculto" and fposmod(_t, 0.5) < 0.25:
					ci.draw_circle(Vector2(kx + 22, fl - 28), 2.2, Color(0.9, 0.9, 0.9, 0.18 * ra))
			else:
				var k := clampf(pan_fall / 0.35, 0.0, 1.0)
				var pp := Vector2(kx + 16 - k * 12, fl - 25 + k * 22)
				ci.draw_set_transform(pp, k * 2.2, Vector2.ONE)
				Fig.box(ci, Rect2(-6, -2.5, 12, 5), Color(0.2, 0.2, 0.24), ra)
				ci.draw_set_transform(Vector2.ZERO)
				if k >= 1.0:
					ci.draw_colored_polygon(Fig.ellipse(Vector2(kx + 2, fl - 0.5), 9, 1.2, 12), Color(0.72, 0.6, 0.32, 0.6 * ra))
		"banho":
			_draw_bath_front(ci, n, ra)


func _draw_resident(ci: CanvasItem, n: Dictionary, a: float) -> void:
	var st: String = n.state
	var t: float = n.t
	var feet := Vector2(n.x, n.y)
	var p := Fig.pose()
	if st == "medo" and n.run and n.t > 0.3:
		Fig.person(ci, feet, n.face, _run_pose(n), n.look, n.h, a)
		return
	match n.kind:
		"sofa":
			if st == "rotina":
				feet += Vector2(4, -6)
				p = Fig.sit({"ua_f": 0.7, "la_f": 1.1, "ua_b": 0.2, "la_b": 0.9, "head": 0.05 + sin(_t * 0.7) * 0.04})
			elif st == "uau":
				p = Fig.pose({"ua_f": 2.1, "la_f": 0.05, "ua_b": 0.3, "la_b": 1.0, "lean": 0.1})
			elif st == "medo":
				p = _run_pose(n)
		"escritorio":
			if st == "rotina":
				feet += Vector2(0, -8)
				var sip := fposmod(_t + n.ph, 7.0) < 1.2
				p = Fig.sit({"ua_f": 1.1, "la_f": 0.5 + sin(_t * 18.0) * 0.08, "ua_b": 1.4 if sip else 1.0,
					"la_b": 2.3 if sip else 0.55 + sin(_t * 17.0 + 1.0) * 0.08, "head": -0.1 if sip else 0.05})
			elif st == "uau":
				feet.x += 6.0
				p = Fig.pose({"ua_f": 1.6, "la_f": 0.25, "ua_b": 0.3, "la_b": 1.0})
			else:
				feet.x += 24.0
				p = Fig.crouch(sin(t * 25.0) * 0.05)
		"cozinha":
			if st == "rotina":
				p = Fig.pose({"ua_f": 1.0 + sin(_t * 4.0) * 0.18, "la_f": 0.7, "ua_b": 0.6, "la_b": 1.1, "lean": 0.1})
			elif st == "uau":
				p = Fig.pose({"ua_f": 1.6, "la_f": 0.2, "ua_b": 0.3, "la_b": 0.8})
			else:
				p = _run_pose(n) if t < 0.3 else Fig.crouch(sin(t * 25.0) * 0.05)
		"banho":
			if st != "rotina":
				return   # medo: atrás da cortina fechada; uau: espia pela fresta (_draw_bath_front)
			feet = Vector2(n.x, n.y - 5.0)
			p = Fig.sit({"lean": -0.35, "ua_f": 2.4 + sin(_t * 3.0) * 0.3, "la_f": 0.6, "ua_b": 0.4, "la_b": 1.0,
				"head": -0.2 + sin(_t * 2.0) * 0.1})
	var j := Fig.person(ci, feet, n.face, p, n.look, n.h, a)
	_draw_props(ci, n, j, a)
	if n.kind == "banho" and st == "rotina":
		for k in 2:
			var u := fposmod(_t * 0.5 + k * 0.5, 1.0)
			Fig.note(ci, j.head + Vector2(6 + u * 8, -6 - u * 12), (1.0 - u) * 0.8 * a)


func _draw_bath_front(ci: CanvasItem, n: Dictionary, ra: float) -> void:
	var bx: float = n.home
	var fl: float = n.y
	var tub := Rect2(bx - 22, fl - 13, 46, 13)
	Fig.box(ci, tub, Fig.mute(Color(0.9, 0.9, 0.92), 0.2, 0.1), ra)
	ci.draw_rect(Rect2(tub.position + Vector2(0, 2), Vector2(tub.size.x, 1.5)), Color(0.6, 0.7, 0.8, 0.5 * ra))
	# Espuma.
	for k in 8:
		var fx := bx - 18 + k * 5.5
		ci.draw_circle(Vector2(fx, fl - 13 + sin(_t * 2.0 + k) * 0.6), 3.0 + (k % 3), Color(0.94, 0.94, 0.96, 0.95 * ra))
	if n.state == "rotina" and fposmod(_t, 1.2) < 0.9:
		var bu := Vector2(bx - 6 + sin(_t * 3.0) * 6.0, fl - 18 - fposmod(_t, 1.2) * 12.0)
		ci.draw_arc(bu, 1.5, 0, TAU, 10, Color(0.9, 0.95, 1.0, 0.6 * ra), 0.6)
	# Cortina: aberta na rotina, fresta no "uau", fechada e tremendo no medo.
	var rail_y := fl - 58.0
	var x0 := bx - 26.0
	var x1 := bx + 28.0
	ci.draw_line(Vector2(x0 - 2, rail_y), Vector2(x1 + 2, rail_y), Color(0.3, 0.3, 0.34, ra), 1.4)
	var open := 0.8
	if n.state == "uau":
		open = 0.3
	elif n.state == "medo":
		open = 0.0
	var cw := (x1 - x0) * (1.0 - open)
	cw = maxf(cw, 8.0)
	var shake := sin(_t * 40.0) * 1.2 if n.state == "medo" else 0.0
	var pts := PackedVector2Array()
	var folds := 7
	for k in folds + 1:
		pts.append(Vector2(x1 - cw * k / folds, rail_y))
	for k in range(folds, -1, -1):
		pts.append(Vector2(x1 - cw * k / folds + sin(k * 1.9 + _t * 1.5) * 1.2 + shake, fl - 8.0))
	Fig.poly(ci, pts, Fig.mute(Color(0.56, 0.72, 0.74), 0.35, 0.1), ra)
	for k in range(1, folds):
		var fx2 := x1 - cw * k / folds
		ci.draw_line(Vector2(fx2, rail_y + 1), Vector2(fx2 + shake, fl - 9), Color(0.3, 0.42, 0.46, 0.5 * ra), 0.8)
	if n.state == "uau":
		var j := Fig.person(ci, Vector2(x1 - cw - 2, fl - 2), -1.0, Fig.pose({"lean": 0.6, "ua_f": -0.2, "ua_b": -0.2}), n.look, n.h, n.alpha)
		# Reencobre o corpo com a cortina: só a cabeça espiando pela fresta.
		Fig.poly(ci, PackedVector2Array([Vector2(x1 - cw, j.head.y + 3), Vector2(x1, j.head.y + 3), Vector2(x1, fl - 8), Vector2(x1 - cw, fl - 8)]),
			Fig.mute(Color(0.56, 0.72, 0.74), 0.35, 0.1), ra)
