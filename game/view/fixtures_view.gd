extends Node2D
## Elementos reativos (placeholders procedurais, Docs/design_elementos_reativos.md): desenha postes,
## luminárias, canos, botijão, transformador, fiação, hidrante, letreiro neon, e os objetos botijão e
## extintor; jatos d'água com poça, vapor, gás, fogo com núcleo claro, faíscas em arco zigue-zague.
## Luz 2D real: CanvasModulate de entardecer e PointLight2D (texturas geradas em código) para postes,
## luminárias, neon, fogo, transformador, aviso do botijão e explosões. F7 (main.gd) liga/desliga.
## Só lê a simulação e escuta eventos; RNG próprio, nunca escreve no estado.

const C = preload("res://sim/sim_const.gd")
const F = preload("res://sim/fixtures.gd")
const Props = preload("res://sim/props.gd")

const OUTLINE := Color(0.07, 0.05, 0.09)
const DUSK := Color(0.74, 0.68, 0.82)
const SODIUM := Color(1.0, 0.78, 0.46)
const WARM := Color(1.0, 0.86, 0.62)
const NEON_PINK := Color(1.0, 0.32, 0.72)
const NEON_CYAN := Color(0.35, 0.95, 1.0)
const FIRE_COL := Color(1.0, 0.55, 0.18)
const ELEC := Color(0.55, 0.8, 1.0)
const WATER_COL := Color(0.55, 0.78, 1.0)
const MAX_PARTS := 700
const GRAV := 520.0
# Letreiro: traços das letras "BAR" em px locais de 12×16; a última (R) cai quando dá curto.
const LETTERS := [
	[[Vector2(0, 16), Vector2(0, 0), Vector2(7, 0), Vector2(10, 3), Vector2(10, 5), Vector2(7, 8), Vector2(0, 8)],
		[Vector2(7, 8), Vector2(11, 11), Vector2(11, 13), Vector2(8, 16), Vector2(0, 16)]],
	[[Vector2(0, 16), Vector2(6, 0), Vector2(12, 16)], [Vector2(3, 10), Vector2(9, 10)]],
	[[Vector2(0, 16), Vector2(0, 0), Vector2(8, 0), Vector2(11, 3), Vector2(11, 5), Vector2(8, 8), Vector2(0, 8)],
		[Vector2(5, 8), Vector2(11, 16)]],
]

var sim
var lights_on := true
var rng := RandomNumberGenerator.new()
var _time := 0.0
var _parts := []      # [pos, vel, idade, vida, tam0, tam1, cor, tipo] tipo: 0 gota 1 nuvem 2 brasa 3 faísca 4 fumaça
var _arcs := []       # [a, b, idade, vida, cor]
var _flashes := []    # [PointLight2D, idade, vida, energia]
var _modulate: CanvasModulate
var _lights := {}     # chave → PointLight2D
var _tex_radial: Texture2D
var _tex_cone: Texture2D
var _last_state := {} # id do fixo → estado visto (para detectar troca sem depender de evento)
var _puddle := {}     # id do fixo → raio da poça (px)


func _ready() -> void:
	rng.seed = 7071
	_tex_radial = _make_radial()
	_tex_cone = _make_cone()
	_modulate = CanvasModulate.new()
	_modulate.color = DUSK
	add_child(_modulate)
	for k in 3:
		var l := _new_light(_tex_radial, FIRE_COL, 0.0, 2.2)
		_flashes.append([l, 1.0, 1.0, 0.0])


func set_lights(on: bool) -> void:
	lights_on = on
	_modulate.visible = on
	for k in _lights:
		_lights[k].visible = on and _lights[k].visible
	for fl in _flashes:
		fl[0].visible = on


# ---------------------------------------------------------------- texturas de luz

func _make_radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _make_cone() -> Texture2D:
	## Cone apontando para baixo com ápice no centro da textura (a luz gira em volta do ápice).
	## Gradiente radial (GradientTexture2D) recortado por uma máscara angular suave.
	var g := (_tex_radial as GradientTexture2D).gradient
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := deg_to_rad(34.0)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5)
			var a := 0.0
			if d.length() > 1.5:
				a = absf(d.angle_to(Vector2(0, 1)))
			var m := clampf((half - a) / deg_to_rad(12.0), 0.0, 1.0)
			# Brilho junto do ápice (a lâmpada), mesmo fora do cone.
			var glow := clampf(1.0 - d.length() / (n * 0.1), 0.0, 1.0)
			var c := g.sample(clampf(d.length() / (n * 0.5), 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, c.a * maxf(m, glow)))
	return ImageTexture.create_from_image(img)


func _new_light(tex: Texture2D, col: Color, energy: float, scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.color = col
	l.energy = energy
	l.texture_scale = scale
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.visible = lights_on
	add_child(l)
	return l


func _light(key: String, tex: Texture2D, col: Color, scale: float) -> PointLight2D:
	if not _lights.has(key):
		_lights[key] = _new_light(tex, col, 1.0, scale)
	return _lights[key]


# ---------------------------------------------------------------- eventos

func on_event(e: Dictionary) -> void:
	match e.kind:
		"fix_state":
			_on_state(e)
		"fix_spark":
			var p := Vector2(e.x, e.y) / C.SUB
			_spark_burst(p, 10)
			_arc(p + Vector2(rng.randf_range(-10, 10), -8), p + Vector2(rng.randf_range(-18, 18), 10), 0.12)
		"fix_bend":
			var b := Vector2(e.x, e.y) / C.SUB
			for k in 6:
				_part(b + Vector2(rng.randf_range(-6, 6), -2), Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, -10)),
					0.5, 3.0, 8.0, Color(0.8, 0.75, 0.7, 0.5), 1)
			_spark_burst(b + Vector2(0, -60), 5)
		"fix_hurt":
			var v: Dictionary = sim.fighters[e.target]
			var hp := Vector2(v.x, v.y - v.h / 2) / C.SUB
			if e.fix >= 0 and sim.fixtures.fixtures[e.fix].type == F.GAS:
				for k in 8:
					_part(hp, Vector2(rng.randf_range(-60, 60), rng.randf_range(-120, -30)), 0.6, 2.0, 1.0, FIRE_COL, 2)
			elif e.kb > 0:
				_spark_burst(hp, 12)
				_arc(hp + Vector2(-10, -14), hp + Vector2(10, 12), 0.15)
		"fix_extinguish":
			var q := Vector2(e.x, e.y) / C.SUB
			for k in 8:
				_part(q, Vector2(rng.randf_range(-30, 30), rng.randf_range(-80, -20)), 1.2, 6.0, 20.0, Color(0.95, 0.95, 1.0, 0.5), 1)
		"explosion":
			var c := Vector2(e.x, e.y) / C.SUB
			_flash(c, 3.0, 0.7)
			for k in 18:
				var ang := rng.randf_range(0, TAU)
				_part(c, Vector2(cos(ang), sin(ang)) * rng.randf_range(80, 260) + Vector2(0, -80), rng.randf_range(0.6, 1.2), 2.0, 1.0, FIRE_COL, 2)
			for k in 8:
				_part(c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-10, 6)), Vector2(rng.randf_range(-30, 30), rng.randf_range(-60, -20)),
					rng.randf_range(1.4, 2.4), 10.0, 34.0, Color(0.22, 0.2, 0.22, 0.6), 4)
		"prop_fuse":
			_spark_burst(Vector2(e.x, e.y - 20 * C.SUB) / C.SUB, 6)
		"prop_jet":
			for k in 6:
				_part(Vector2(e.x, e.y - 12 * C.SUB) / C.SUB, Vector2(e.dir * rng.randf_range(80, 160), rng.randf_range(-30, 30)),
					0.8, 4.0, 18.0, Color(0.96, 0.96, 1.0, 0.7), 1)


func _on_state(e: Dictionary) -> void:
	var f: Dictionary = sim.fixtures.fixtures[e.fix]
	var o := Vector2(f.x, f.y) / C.SUB
	match int(e.type):
		F.WATER, F.HYDRANT:
			if e.state == F.ACTIVE:
				for k in 14:
					_part(o, Vector2(rng.randf_range(-90, 90), rng.randf_range(-160, -20)), 0.6, 2.0, 1.0, WATER_COL, 0)
		F.STEAM, F.GAS:
			if e.state == F.ACTIVE:
				for k in 10:
					_part(o, Vector2(f.dx, f.dy) / 1024.0 * rng.randf_range(60, 200) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)),
						0.7, 4.0, 18.0, Color(1, 1, 1, 0.5), 1)
				_spark_burst(o, 5)
			elif e.state == F.FIRE:
				_flash(o, 1.6, 0.4)
		F.POLE, F.LAMP:
			if e.state == F.DONE:
				var head := _pole_head(f) if f.type == F.POLE else _lamp_pos(f)
				_spark_burst(head, 16)
				for k in 10:
					_part(head, Vector2(rng.randf_range(-70, 70), rng.randf_range(-90, 10)), rng.randf_range(0.6, 1.1), 2.0, 2.0,
						Color(0.85, 0.95, 1.0, 0.9), 0)
		F.NEON, F.TRAFO:
			_spark_burst(o, 12)


func _spark_burst(p: Vector2, n: int) -> void:
	for k in n:
		var ang := rng.randf_range(0, TAU)
		_part(p, Vector2(cos(ang), sin(ang)) * rng.randf_range(60, 220), rng.randf_range(0.15, 0.4), 1.0, 1.0,
			Color(0.8, 0.92, 1.0) if k % 3 else Color(1.0, 0.95, 0.6), 3)


func _arc(a: Vector2, b: Vector2, life: float, col := ELEC) -> void:
	if _arcs.size() < 24:
		_arcs.append([a, b, 0.0, life, col])


func _flash(p: Vector2, energy: float, life: float) -> void:
	var best: Array = _flashes[0]
	for fl in _flashes:
		if fl[1] / fl[2] > best[1] / best[2]:
			best = fl
	best[0].position = p
	best[1] = 0.0
	best[2] = life
	best[3] = energy


func _part(p: Vector2, v: Vector2, life: float, s0: float, s1: float, col: Color, kind: int) -> void:
	if _parts.size() >= MAX_PARTS:
		_parts.pop_front()
	_parts.append([p, v, 0.0, life, s0, s1, col, kind])


# ---------------------------------------------------------------- geometria

func _turn(angle: int) -> float:
	return angle * TAU / 1024.0


func _pole_arm(f: Dictionary) -> float:
	return 1.0 if f.x < C.WORLD_W * C.SUB / 2 else -1.0


func _pole_angle(f: Dictionary) -> float:
	var a: float = _turn(f.angle)
	if f.state == F.DONE and absi(f.angle) < 96:
		a = _turn(240) * _pole_arm(f)   # caiu pelo pé: deita para o lado do braço
	return a


func _pole_head(f: Dictionary) -> Vector2:
	var base := Vector2(f.x, f.y) / C.SUB
	return base + Vector2(_pole_arm(f) * 22.0, -F.POLE_H + 3.0).rotated(_pole_angle(f))


func _pole_top(f: Dictionary) -> Vector2:
	var base := Vector2(f.x, f.y) / C.SUB
	return base + Vector2(0, -F.POLE_H + 6.0).rotated(_pole_angle(f))


func _lamp_pos(f: Dictionary) -> Vector2:
	return Vector2(f.x, f.y) / C.SUB + Vector2(0, 22).rotated(_turn(f.angle))


func _floor_below(p: Vector2) -> float:
	var cx := int(p.x) / C.CELL
	for cy in range(maxi(0, int(p.y) / C.CELL), C.GRID_H):
		if sim.grid.get_mat(cx, cy) != C.M_EMPTY:
			return cy * C.CELL
	return C.WORLD_H


# ---------------------------------------------------------------- quadro

func _process(delta: float) -> void:
	if sim == null or sim.fixtures == null:
		return
	_time += delta
	_emit_continuous(delta)
	for p in _parts:
		p[2] += delta
		match p[7]:
			0, 2, 3:
				p[1].y += GRAV * delta * (0.25 if p[7] == 2 else 1.0)
				if p[7] == 2:
					p[1].y -= 260.0 * delta
			1, 4:
				p[1] *= 1.0 - 2.2 * delta
				p[1].y -= (18.0 if p[7] == 1 else 30.0) * delta
		p[0] += p[1] * delta
		if p[7] == 0 and p[0].y > _floor_below(p[0] - p[1] * delta) and p[1].y > 0:
			p[2] = p[3]
	_parts = _parts.filter(func(p): return p[2] < p[3])
	for a in _arcs:
		a[2] += delta
	_arcs = _arcs.filter(func(a): return a[2] < a[3])
	for fl in _flashes:
		fl[1] += delta
		var k: float = clampf(fl[1] / fl[2], 0.0, 1.0)
		fl[0].energy = fl[3] * (1.0 - k) * (1.0 - k)
		fl[0].visible = lights_on and k < 1.0
	for id in _puddle.keys():
		if sim.fixtures.fixtures[id].state != F.ACTIVE:
			_puddle[id] = maxf(0.0, _puddle[id] - delta * 1.5)
	_update_lights()
	queue_redraw()


func _emit_continuous(delta: float) -> void:
	## Partículas contínuas dos jatos ativos (taxa por segundo, independente do fps).
	for f in sim.fixtures.fixtures:
		var o := Vector2(f.x, f.y) / C.SUB
		var d := Vector2(f.dx, f.dy) / 1024.0
		match f.type:
			F.WATER, F.HYDRANT:
				if f.state == F.ACTIVE:
					var fade := clampf(f.t / 90.0, 0.25, 1.0)
					var sp := 260.0 if f.type == F.WATER else 330.0
					for k in _count(90.0 * fade, delta):
						var v := d * sp * rng.randf_range(0.7, 1.05) + Vector2(rng.randf_range(-25, 25), rng.randf_range(-20, 10))
						_part(o, v, rng.randf_range(0.5, 1.0), rng.randf_range(1.5, 2.5), 1.0, WATER_COL.lightened(rng.randf_range(0, 0.4)), 0)
					if rng.randf() < delta * 8.0:
						var mist := o + d * (60.0 if f.type == F.HYDRANT else 30.0)
						_part(mist, Vector2(rng.randf_range(-20, 20), -10), 1.0, 6.0, 20.0, Color(0.85, 0.92, 1.0, 0.25), 1)
					_puddle[f.id] = minf(_puddle.get(f.id, 0.0) + delta * 6.0, 34.0)
			F.STEAM:
				if f.state == F.ACTIVE:
					var fade2 := clampf(f.t / 60.0, 0.2, 1.0)
					for k in _count(40.0 * fade2, delta):
						var v2 := d * rng.randf_range(220, 380) * fade2 + Vector2(rng.randf_range(-20, 20), rng.randf_range(-24, 24))
						_part(o, v2, rng.randf_range(0.45, 0.8), 3.0, rng.randf_range(16, 26), Color(1, 1, 1, 0.55), 1)
			F.GAS:
				if f.state == F.ACTIVE and rng.randf() < delta * 10.0:
					_part(o, d * 60.0 + Vector2(0, rng.randf_range(-15, 15)), 0.8, 3.0, 12.0, Color(0.75, 0.9, 0.7, 0.18), 1)
				elif f.state == F.FIRE:
					for k in _count(26.0, delta):
						_part(o + d * rng.randf_range(10, 50), Vector2(rng.randf_range(-20, 20), rng.randf_range(-90, -40)),
							rng.randf_range(0.5, 1.0), 1.5, 1.0, Color(1.0, rng.randf_range(0.5, 0.85), 0.25), 2)
					if rng.randf() < delta * 6.0:
						_part(o + d * 50.0 + Vector2(0, -10), Vector2(rng.randf_range(-10, 10), -40), 1.8, 8.0, 26.0, Color(0.2, 0.18, 0.2, 0.45), 4)
			F.TANK:
				if f.state == F.ACTIVE and rng.randf() < delta * 14.0:
					var top := o + Vector2(0, -16)
					_part(top, Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, -20)), 0.4, 2.0, 9.0, Color(1, 1, 1, 0.4), 1)
			F.TRAFO:
				if f.state == F.ACTIVE:
					var arc_on: bool = f.t % F.TRAFO_PERIOD < F.TRAFO_ARC
					if arc_on and rng.randf() < delta * 30.0:
						var ang := rng.randf_range(0, TAU)
						_arc(o + Vector2(rng.randf_range(-8, 8), -14), o + Vector2(cos(ang), sin(ang)) * rng.randf_range(20, F.TRAFO_R), 0.08)
						_spark_burst(o + Vector2(rng.randf_range(-10, 10), rng.randf_range(-12, 12)), 2)
					elif rng.randf() < delta * 2.0:
						_part(o + Vector2(0, -16), Vector2(rng.randf_range(-8, 8), -30), 1.6, 5.0, 16.0, Color(0.25, 0.24, 0.26, 0.4), 4)
			F.WIRE:
				if f.state == F.ACTIVE and rng.randf() < delta * 5.0:
					var tip := _wire_tip(f)
					_spark_burst(tip, 4)
					_arc(tip, tip + Vector2(rng.randf_range(-14, 14), rng.randf_range(4, 16)), 0.06)
			F.NEON:
				if f.state == F.ACTIVE and rng.randf() < delta * 3.0:
					_spark_burst(o + Vector2(24, -12), 3)
	for p in sim.props.props:
		if p.state == Props.BROKEN or p.fx <= 0:
			continue
		var pb := Vector2(p.x, p.y) / C.SUB
		if p.kind == Props.EXTINTOR:
			for k in _count(45.0, delta):
				_part(pb + Vector2(p.fx_dir * p.hw / C.SUB, -p.h * 2.0 / 3.0 / C.SUB),
					Vector2(p.fx_dir * rng.randf_range(160, 260), rng.randf_range(-30, 30)), rng.randf_range(0.6, 1.1), 4.0,
					rng.randf_range(18, 30), Color(0.96, 0.97, 1.0, 0.6), 1)
		elif p.kind == Props.BOTIJAO and rng.randf() < delta * 16.0:
			_part(pb + Vector2(0, -p.h / C.SUB), Vector2(rng.randf_range(-50, 50), rng.randf_range(-60, -20)), 0.35, 2.0, 8.0,
				Color(1, 1, 1, 0.4), 1)


func _count(rate: float, delta: float) -> int:
	var x := rate * delta
	return int(x) + int(rng.randf() < x - int(x))


func _update_lights() -> void:
	var fl := 0.85 + 0.15 * sin(_time * 23.0) * sin(_time * 7.3)
	for f in sim.fixtures.fixtures:
		var key := "f%d" % f.id
		match f.type:
			F.POLE:
				var l := _light(key, _tex_cone, SODIUM, 2.0)
				l.position = _pole_head(f) + Vector2(0, 2).rotated(_pole_angle(f))
				l.rotation = _pole_angle(f)
				var on := _pole_lit(f)
				l.energy = 1.6 if on else 0.0
				l.visible = lights_on and on
				var g := _light(key + "g", _tex_radial, SODIUM, 0.32)
				g.position = l.position
				g.energy = 0.9 if on else 0.0
				g.visible = l.visible
			F.LAMP:
				var l2 := _light(key, _tex_cone, WARM, 1.3)
				l2.position = _lamp_pos(f)
				l2.rotation = _turn(f.angle)
				var on2: bool = f.state != F.DONE or (f.age < 20 and int(_time * 30.0) % 3 == 0)
				l2.energy = 1.1
				l2.visible = lights_on and on2
			F.NEON:
				var l3 := _light(key, _tex_radial, NEON_PINK, 0.45)
				l3.position = Vector2(f.x, f.y) / C.SUB + Vector2(0, -14)
				var on3 := _neon_lit(f)
				l3.energy = 0.9 * fl
				l3.visible = lights_on and on3
			F.GAS:
				var l4 := _light(key, _tex_radial, FIRE_COL, 0.7)
				l4.position = Vector2(f.x, f.y) / C.SUB + Vector2(f.dx, f.dy) / 1024.0 * 28.0
				l4.energy = 1.5 * fl * (0.6 + 0.4 * sin(_time * 31.0))
				l4.visible = lights_on and f.state == F.FIRE
			F.TRAFO:
				var l5 := _light(key, _tex_radial, ELEC, 0.5)
				l5.position = Vector2(f.x, f.y) / C.SUB
				var arc_on: bool = f.state == F.ACTIVE and f.t % F.TRAFO_PERIOD < F.TRAFO_ARC
				l5.energy = 1.6 * rng.randf_range(0.5, 1.0)
				l5.visible = lights_on and arc_on
			F.TANK:
				var l6 := _light(key, _tex_radial, Color(1.0, 0.2, 0.15), 0.25)
				l6.position = Vector2(f.x, f.y) / C.SUB + Vector2(0, -14)
				l6.energy = 1.4
				l6.visible = lights_on and f.state == F.ACTIVE and _blink(f.t)


func _pole_lit(f: Dictionary) -> bool:
	if f.state != F.DONE:
		# Entortado: a lâmpada treme de vez em quando.
		return f.state == F.IDLE or f.age > 30 or int(_time * 24.0) % 4 != 0
	# Quebrou: pisca algumas vezes e apaga.
	return f.age < 50 and int(_time * 20.0) % 3 == 0


func _neon_lit(f: Dictionary) -> bool:
	if f.state == F.IDLE:
		return true
	if f.state == F.DONE:
		return false
	var h := (int(_time * 18.0) * 7919) % 11
	return h > 4


func _blink(t: int) -> bool:
	## Aviso do botijão: pisca cada vez mais rápido perto de explodir.
	var period := 4 + t / 6
	return (t / maxi(2, period / 2)) % 2 == 0


func _wire_tip(f: Dictionary) -> Vector2:
	var top := _pole_top(sim.fixtures.fixtures[f.link]) if f.link >= 0 else Vector2(f.x2, f.y2) / C.SUB
	var swing := sin(_time * 3.1) * 0.45 * exp(-f.age / 600.0) + 0.08
	return top + Vector2(0, F.WIRE_DROP).rotated(swing)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if sim == null or sim.fixtures == null:
		return
	_draw_puddles()
	for f in sim.fixtures.fixtures:
		match f.type:
			F.WATER, F.STEAM, F.GAS:
				_draw_pipe(f)
			F.TANK:
				_draw_tank(f)
			F.TRAFO:
				_draw_trafo(f)
			F.HYDRANT:
				_draw_hydrant(f)
			F.NEON:
				_draw_neon(f)
			F.LAMP:
				_draw_lamp(f)
	for f in sim.fixtures.fixtures:
		if f.type == F.WIRE:
			_draw_wire(f)
		elif f.type == F.POLE:
			_draw_pole(f)
	_draw_props()
	for f in sim.fixtures.fixtures:
		if f.type == F.GAS and f.state == F.FIRE:
			_draw_fire(f)
		elif f.type == F.HYDRANT and f.state == F.ACTIVE:
			_draw_column(f)
		elif f.type == F.WATER and f.state == F.ACTIVE:
			_draw_stream(f)
	_draw_parts()
	for a in _arcs:
		_draw_arc(a[0], a[1], 1.0 - a[2] / a[3], a[4])


func _poly(pts: PackedVector2Array, fill: Color, line := OUTLINE, w := 1.0) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, w)


func _rect(r: Rect2, fill: Color, line := OUTLINE) -> void:
	_poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), fill, line)


func _box(f: Dictionary) -> Rect2:
	return Rect2(Vector2(f.bx0, f.by0) / C.SUB, Vector2(f.bx1 - f.bx0, f.by1 - f.by0) / C.SUB)


func _draw_pipe(f: Dictionary) -> void:
	var r := _box(f)
	var cols := {F.WATER: Color(0.42, 0.53, 0.62), F.STEAM: Color(0.72, 0.44, 0.27), F.GAS: Color(0.86, 0.7, 0.18)}
	var col: Color = cols[f.type]
	var o := Vector2(f.x, f.y) / C.SUB
	var pw := 6.0
	var px := r.position.x + (r.size.x - pw) * 0.5
	var burst: bool = f.state != F.IDLE
	# Cano vertical com sombra lateral e brilho; se estourou, o trecho do furo fica aberto.
	var gap_y := o.y if burst else -1.0
	var segs := [[r.position.y, r.end.y]]
	if burst:
		segs = [[r.position.y, gap_y - 3.0], [gap_y + 3.0, r.end.y]]
	for s in segs:
		if s[1] - s[0] < 1.0:
			continue
		var rr := Rect2(px, s[0], pw, s[1] - s[0])
		_rect(rr, col)
		draw_rect(Rect2(rr.position + Vector2(pw - 2, 0), Vector2(2, rr.size.y)), col.darkened(0.35))
		draw_rect(Rect2(rr.position + Vector2(1, 0), Vector2(1, rr.size.y)), col.lightened(0.35))
	# Flanges e abraçadeiras presas à parede.
	var y := r.position.y + 6.0
	while y < r.end.y - 4.0:
		if not burst or absf(y - gap_y) > 6.0:
			_rect(Rect2(px - 1.5, y, pw + 3.0, 3.0), col.darkened(0.2))
		y += 22.0
	if burst:
		# Borda rasgada nas duas pontas do furo.
		for s in [-1.0, 1.0]:
			var e: float = gap_y + s * 3.0
			var pts := PackedVector2Array([Vector2(px - 1, e), Vector2(px + 1.5, e + s * 3.5), Vector2(px + 3, e + s * 1),
				Vector2(px + 4.5, e + s * 4), Vector2(px + pw + 1, e)])
			draw_polyline(pts, col.lightened(0.2), 1.5)
	if f.type == F.STEAM:
		# Registro (volante) perto do topo.
		var c := Vector2(px + pw * 0.5 - 5.0, r.position.y + 14.0)
		draw_line(c, c + Vector2(5, 0), OUTLINE, 2.0)
		draw_circle(c, 4.5, OUTLINE)
		draw_circle(c, 3.5, Color(0.75, 0.15, 0.12))
		for k in 3:
			var a := TAU * k / 3.0 + _time * (8.0 if burst and f.state == F.ACTIVE else 0.0)
			draw_line(c, c + Vector2(cos(a), sin(a)) * 3.5, OUTLINE, 1.0)
	elif f.type == F.GAS:
		# Medidor de gás no pé do cano.
		var m := Rect2(r.position.x - 7, r.end.y - 20, 12, 12)
		_rect(m, Color(0.62, 0.62, 0.58))
		draw_circle(m.get_center(), 3.0, Color(0.95, 0.95, 0.88))
		draw_line(m.get_center(), m.get_center() + Vector2(2, -2), OUTLINE, 1.0)
		if f.state == F.ACTIVE:
			# Vazamento visível: ondas de calor verdes tremendo na frente do furo.
			for k in 3:
				var ph := _time * 6.0 + k * 2.0
				var a0 := o + Vector2(4 + k * 6, sin(ph) * 2.0)
				draw_arc(a0, 3.0 + k * 2.0, -0.9, 0.9, 6, Color(0.7, 1.0, 0.7, 0.35 - k * 0.08), 1.0)
	if f.type == F.GAS and f.state == F.DONE:
		draw_circle(o + Vector2(3, 0), 2.5, Color(0.1, 0.08, 0.08))   # furo queimado


func _draw_stream(f: Dictionary) -> void:
	## Jato d'água em arco balístico, com núcleo claro; enfraquece no fim do vazamento.
	var o := Vector2(f.x, f.y) / C.SUB
	var d := Vector2(f.dx, f.dy) / 1024.0
	var fade := clampf(f.t / 90.0, 0.25, 1.0)
	var v0 := d * 250.0 * fade
	var pts := PackedVector2Array()
	var floor_y := _floor_below(o + Vector2(0, 2))
	for k in 16:
		var t := k * 0.03
		var p := o + v0 * t + Vector2(0, 0.5 * GRAV * t * t) + Vector2(sin(_time * 30.0 + k) * 0.6, 0)
		pts.append(p)
		if p.y >= floor_y:
			break
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.5, 0.72, 1.0, 0.55), 4.0 * fade)
		draw_polyline(pts, Color(0.9, 0.97, 1.0, 0.85), 1.5)


func _draw_column(f: Dictionary) -> void:
	var o := Vector2(f.x, f.y) / C.SUB
	var fade := clampf(f.t / 90.0, 0.2, 1.0)
	var h: float = 108.0 * fade * (0.92 + 0.08 * sin(_time * 17.0))
	var top := o + Vector2(sin(_time * 5.0) * 2.0, -h)
	var pts := PackedVector2Array([o + Vector2(-3, 0), o + Vector2(3, 0), top + Vector2(6, 0), top + Vector2(-6, 0)])
	draw_colored_polygon(pts, Color(0.55, 0.78, 1.0, 0.55))
	draw_line(o, top, Color(0.92, 0.98, 1.0, 0.9), 1.5)
	draw_circle(top, 7.0, Color(0.8, 0.9, 1.0, 0.45))
	if rng.randf() < 0.5:
		_part(top, Vector2(rng.randf_range(-90, 90), rng.randf_range(-40, 20)), rng.randf_range(0.5, 0.9), 2.0, 1.0, WATER_COL, 0)


func _draw_fire(f: Dictionary) -> void:
	## Chama: línguas camadas (vermelho → laranja → núcleo claro) tremendo ao longo do jato.
	var o := Vector2(f.x, f.y) / C.SUB
	var d := Vector2(f.dx, f.dy) / 1024.0
	var n := Vector2(-d.y, d.x)
	var fade := clampf(f.t / 60.0, 0.3, 1.0)
	var length: float = f.len / float(C.SUB) * fade
	var layers := [[Color(0.85, 0.18, 0.08, 0.7), 1.0, 1.0], [Color(1.0, 0.55, 0.12, 0.85), 0.78, 0.7], [Color(1.0, 0.92, 0.65, 0.95), 0.5, 0.38]]
	for L in layers:
		var pts := PackedVector2Array()
		var len_k: float = length * L[1]
		var w: float = 9.0 * L[2]
		pts.append(o + n * 2.0)
		for k in 7:
			var t := (k + 1) / 7.0
			var wob := sin(_time * 22.0 + k * 1.7) * 2.5 + sin(_time * 13.0 + k) * 1.5
			var up := -t * t * 14.0
			pts.append(o + d * len_k * t + n * (w * sin(t * PI) + wob) + Vector2(0, up))
		for k in range(6, -1, -1):
			var t := (k + 0.5) / 7.0
			var wob := sin(_time * 19.0 + k * 2.1) * 2.0
			var up := -t * t * 14.0
			pts.append(o + d * len_k * t - n * (w * 0.8 * sin(t * PI) + wob) + Vector2(0, up))
		draw_colored_polygon(pts, L[0])


func _draw_puddles() -> void:
	for id in _puddle:
		var f: Dictionary = sim.fixtures.fixtures[id]
		var o := Vector2(f.x, f.y) / C.SUB
		var land := o + Vector2(f.dx, f.dy) / 1024.0 * 40.0 if f.type == F.WATER else o
		var fy := _floor_below(land)
		var r: float = _puddle[id]
		var c := Vector2(land.x, fy - 1.0)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, r, Color(0.3, 0.45, 0.62, 0.55))
		draw_circle(Vector2(-r * 0.25, -2), r * 0.55, Color(0.55, 0.7, 0.85, 0.35))
		# Brilho do pôr do sol na poça.
		draw_circle(Vector2(r * 0.3 + sin(_time * 2.0) * 3.0, -3), r * 0.18, Color(1.0, 0.8, 0.55, 0.55))
		draw_set_transform(Vector2.ZERO)


func _draw_tank(f: Dictionary) -> void:
	var r := _box(f)
	var base := Vector2(r.get_center().x, r.end.y)
	if f.state == F.DONE and f.angle != 256:
		# Explodiu: marca de queimado e a base retorcida.
		draw_set_transform(base, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2(0, -2), 22.0, Color(0.08, 0.06, 0.06, 0.55))
		draw_set_transform(Vector2.ZERO)
		_poly(PackedVector2Array([base + Vector2(-9, 0), base + Vector2(-7, -5), base + Vector2(-2, -3), base + Vector2(3, -7),
			base + Vector2(8, -4), base + Vector2(9, 0)]), Color(0.3, 0.12, 0.1))
		return
	var shake := Vector2.ZERO
	var rot := 0.0
	if f.state == F.ACTIVE:
		shake = Vector2(sin(_time * 70.0), 0) * (1.0 + 2.0 * (1.0 - f.t / float(F.TANK_FUSE)))
	if f.state == F.DONE:
		rot = PI / 2.0   # tombou sem explodir
	draw_set_transform(base + shake, rot)
	var w := r.size.x
	var h := r.size.y
	var body := Color(0.78, 0.2, 0.15)
	if f.state == F.ACTIVE and _blink(f.t):
		body = Color(1.0, 0.45, 0.35)
	var pts := PackedVector2Array()
	for k in 9:
		var a := PI + PI * k / 8.0
		pts.append(Vector2(cos(a) * w * 0.5, -h + 6 + sin(a) * 6.0))
	pts.append(Vector2(w * 0.5, -3))
	pts.append(Vector2(w * 0.5 - 2, 0))
	pts.append(Vector2(-w * 0.5 + 2, 0))
	pts.append(Vector2(-w * 0.5, -3))
	_poly(pts, body)
	draw_rect(Rect2(-w * 0.5 + 2, -h + 8, 3, h - 12), body.lightened(0.3))
	draw_rect(Rect2(w * 0.5 - 5, -h + 8, 3, h - 12), body.darkened(0.3))
	# Faixa de aviso e rótulo.
	draw_rect(Rect2(-w * 0.5, -h * 0.55, w, 5), Color(0.95, 0.85, 0.2))
	for k in 4:
		draw_line(Vector2(-w * 0.5 + 1 + k * 5.5, -h * 0.55 + 5), Vector2(-w * 0.5 + 4 + k * 5.5, -h * 0.55), OUTLINE, 1.5)
	_rect(Rect2(-3, -h - 3, 6, 5), Color(0.55, 0.55, 0.6))
	draw_arc(Vector2(0, -h - 1), 6.0, PI, TAU, 10, OUTLINE, 1.5)
	if f.state == F.ACTIVE:
		# Chiado: linhas de pressão saindo da válvula.
		for k in 3:
			var a2 := -PI * 0.5 + (k - 1) * 0.6
			var s := 6.0 + fmod(_time * 40.0 + k * 3.0, 6.0)
			draw_line(Vector2(0, -h - 3) + Vector2(cos(a2), sin(a2)) * s, Vector2(0, -h - 3) + Vector2(cos(a2), sin(a2)) * (s + 4), Color(1, 1, 1, 0.8), 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_trafo(f: Dictionary) -> void:
	var r := _box(f)
	var col := Color(0.36, 0.44, 0.4)
	if f.state == F.DONE:
		col = col.darkened(0.45)
	_rect(Rect2(r.position.x - 2, r.position.y + 6, 3, r.size.y - 12), Color(0.25, 0.25, 0.28))   # suporte
	_rect(r, col)
	for k in 4:
		var x := r.position.x + 4 + k * 5.5
		draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), col.darkened(0.3), 2.0)
	# Isoladores no topo.
	for k in 2:
		var ix := r.position.x + 7 + k * 11
		for j in 3:
			draw_rect(Rect2(ix - 2 + j * 0.0, r.position.y - 3 - j * 3, 4, 2), Color(0.75, 0.55, 0.4))
	# Placa de perigo (triângulo com raio).
	var c := r.get_center() + Vector2(0, 3)
	_poly(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 5), c + Vector2(-6, 5)]), Color(1.0, 0.85, 0.15))
	draw_polyline(PackedVector2Array([c + Vector2(1, -3), c + Vector2(-1.5, 1), c + Vector2(1.5, 1), c + Vector2(-1, 4)]), OUTLINE, 1.0)
	if f.state != F.IDLE:
		# Porta arrancada: buraco escuro com brilho azul.
		var hole := Rect2(r.position + Vector2(3, 3), Vector2(8, 10))
		draw_rect(hole, Color(0.05, 0.05, 0.08))
		if f.state == F.ACTIVE:
			draw_rect(hole.grow(-2), Color(0.6, 0.85, 1.0, 0.4 + 0.4 * sin(_time * 40.0)))


func _draw_hydrant(f: Dictionary) -> void:
	var r := _box(f)
	var cx := r.get_center().x
	var b := r.end.y
	var red := Color(0.82, 0.16, 0.12)
	_rect(Rect2(cx - 7, b - 3, 14, 3), red.darkened(0.3))
	_rect(Rect2(cx - 5, b - 13, 10, 10), red)
	draw_rect(Rect2(cx - 4, b - 12, 2, 8), red.lightened(0.3))
	_rect(Rect2(cx - 8, b - 10, 3, 4), red.darkened(0.2))
	_rect(Rect2(cx + 5, b - 10, 3, 4), red.darkened(0.2))
	if f.state == F.IDLE:
		_poly(PackedVector2Array([Vector2(cx - 5, b - 13), Vector2(cx - 3, b - 17), Vector2(cx + 3, b - 17), Vector2(cx + 5, b - 13)]), red)
		_rect(Rect2(cx - 1, b - 19, 2, 2), Color(0.8, 0.8, 0.75))
	else:
		# Tampa arrancada caída ao lado.
		_rect(Rect2(cx + 9, b - 3, 6, 3), red.darkened(0.1))


func _draw_neon(f: Dictionary) -> void:
	var r := _box(f)
	# Suportes até a marquise e painel escuro.
	draw_line(Vector2(r.position.x + 6, r.end.y - 2), Vector2(r.position.x + 6, r.end.y + 2), OUTLINE, 2.0)
	draw_line(Vector2(r.end.x - 6, r.end.y - 2), Vector2(r.end.x - 6, r.end.y + 2), OUTLINE, 2.0)
	_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), Color(0.12, 0.1, 0.16))
	var lit := _neon_lit(f)
	for i in LETTERS.size():
		var col: Color = NEON_CYAN if i == 2 else NEON_PINK
		var off := r.position + Vector2(12 + i * 16, 4)
		var rot := 0.0
		if i == 2 and f.state != F.IDLE:
			# A última letra solta e fica pendurada torta; no fim, cai.
			var drop := minf(f.age * 0.4, 10.0) if f.state == F.ACTIVE else 22.0
			off += Vector2(2, drop)
			rot = 0.35 if f.state == F.ACTIVE else 1.2
		var on: bool = lit and not (i == 2 and f.state == F.ACTIVE and int(_time * 11.0) % 2 == 0)
		for stroke in LETTERS[i]:
			var pts := PackedVector2Array()
			for p in stroke:
				pts.append(off + (p as Vector2).rotated(rot))
			if on:
				draw_polyline(pts, Color(col, 0.28), 5.0)
				draw_polyline(pts, col, 2.0)
				draw_polyline(pts, col.lightened(0.6), 0.8)
			else:
				draw_polyline(pts, Color(0.3, 0.28, 0.34), 2.0)


func _draw_lamp(f: Dictionary) -> void:
	var top := Vector2(f.x, f.y) / C.SUB
	if f.state == F.DONE:
		# Cabo arrebentado balançando.
		var tip := top + Vector2(0, 10).rotated(sin(_time * 4.0) * 0.3 * exp(-f.age / 200.0))
		draw_line(top, tip, OUTLINE, 1.5)
		return
	var a := _turn(f.angle)
	var p := _lamp_pos(f)
	draw_rect(Rect2(top + Vector2(-3, 0), Vector2(6, 2)), OUTLINE)
	draw_line(top, p, OUTLINE, 1.5)
	var pts := PackedVector2Array()
	for k in 9:
		var t := PI + PI * k / 8.0
		pts.append(p + Vector2(cos(t) * 8.0, sin(t) * 6.0 + 3.0).rotated(a))
	_poly(pts, Color(0.2, 0.42, 0.38))
	draw_circle(p + Vector2(0, 4).rotated(a), 2.5, Color(1.0, 0.95, 0.75))


func _draw_pole(f: Dictionary) -> void:
	var base := Vector2(f.x, f.y) / C.SUB
	var a := _pole_angle(f)
	var arm := _pole_arm(f)
	draw_set_transform(base, a)
	var steel := Color(0.3, 0.32, 0.36)
	var H := float(F.POLE_H)
	_poly(PackedVector2Array([Vector2(-3.5, 0), Vector2(-2, -H), Vector2(2, -H), Vector2(3.5, 0)]), steel)
	draw_line(Vector2(-1.5, -2), Vector2(-0.8, -H + 2), steel.lightened(0.3), 1.0)
	_rect(Rect2(-6, -6, 12, 6), steel.darkened(0.2))
	# Braço curvo e cabeça da luminária.
	var arm_pts := PackedVector2Array()
	for k in 7:
		var t := k / 6.0
		arm_pts.append(Vector2(arm * 22.0 * t, -H + 2 - sin(t * PI) * 6.0))
	draw_polyline(arm_pts, OUTLINE, 4.0)
	draw_polyline(arm_pts, steel, 2.0)
	var hx := arm * 22.0
	_poly(PackedVector2Array([Vector2(hx - 8, -H + 1), Vector2(hx + 8, -H + 1), Vector2(hx + 5, -H + 6), Vector2(hx - 5, -H + 6)]), steel.darkened(0.1))
	var lit := _pole_lit(f)
	var lens := Color(1.0, 0.9, 0.6) if lit else Color(0.25, 0.25, 0.3)
	draw_rect(Rect2(hx - 4.5, -H + 5, 9, 2.5), lens)
	if lit:
		draw_circle(Vector2(hx, -H + 7), 5.0, Color(1.0, 0.85, 0.5, 0.35))
	draw_set_transform(Vector2.ZERO)


func _draw_wire(f: Dictionary) -> void:
	var a := Vector2(f.x, f.y) / C.SUB
	draw_circle(a, 2.0, Color(0.6, 0.55, 0.5))
	var pole: Dictionary = sim.fixtures.fixtures[f.link] if f.link >= 0 else {}
	var b := _pole_top(pole) if not pole.is_empty() else Vector2(f.x2, f.y2) / C.SUB
	var pts := PackedVector2Array()
	if f.state == F.IDLE:
		for k in 13:
			var t := k / 12.0
			pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 16.0 + sin(_time * 1.3) * sin(t * PI) * 1.0))
	elif f.state == F.ACTIVE:
		# Solta do prédio: pendurada no poste, balança e faísca na ponta.
		var tip := _wire_tip(f)
		for k in 9:
			var t := k / 8.0
			pts.append(b.lerp(tip, t) + Vector2(sin(t * PI) * 5.0 * sin(_time * 3.1 + 0.6), 0))
		draw_circle(tip, 2.5, Color(0.7, 0.9, 1.0, 0.5 + 0.5 * sin(_time * 50.0)))
	else:
		var fy := _floor_below(b)
		pts = PackedVector2Array([b, b + Vector2(4, 30), Vector2(b.x + 10, fy - 1), Vector2(b.x + 40, fy - 1)])
	draw_polyline(pts, OUTLINE, 2.0)
	draw_polyline(pts, Color(0.22, 0.2, 0.24), 1.0)


func _draw_props() -> void:
	## Botijão e extintor (objetos móveis novos). Os demais objetos ficam na dynamic_view.
	for p in sim.props.props:
		if p.state == Props.BROKEN or p.kind < Props.BOTIJAO:
			continue
		var feet := Vector2(p.x, p.y) / C.SUB
		var w: float = p.hw * 2.0 / C.SUB
		var h: float = p.h / float(C.SUB)
		if p.kind == Props.BOTIJAO:
			var body := Color(0.2, 0.36, 0.72)
			var shake := Vector2.ZERO
			if p.fx > 0:
				shake = Vector2(sin(_time * 80.0) * 1.2, 0)
				if _blink(p.fx):
					body = Color(1.0, 0.4, 0.3)
			var o := feet + shake
			var pts := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				pts.append(o + Vector2(cos(a) * w * 0.5, -h + 7 + sin(a) * 5.0))
			pts.append(o + Vector2(w * 0.5, -4))
			pts.append(o + Vector2(w * 0.5 - 2, 0))
			pts.append(o + Vector2(-w * 0.5 + 2, 0))
			pts.append(o + Vector2(-w * 0.5, -4))
			_poly(pts, body)
			draw_rect(Rect2(o + Vector2(-w * 0.5 + 2, -h + 8), Vector2(2, h - 12)), body.lightened(0.35))
			draw_line(o + Vector2(-w * 0.5, -h * 0.45), o + Vector2(w * 0.5, -h * 0.45), body.darkened(0.35), 1.5)
			draw_arc(o + Vector2(0, -h + 1), 4.5, PI, TAU, 8, OUTLINE, 2.0)
			draw_rect(Rect2(o + Vector2(-1.5, -h - 1), Vector2(3, 3)), Color(0.75, 0.7, 0.4))
		else:
			var red := Color(0.86, 0.14, 0.12)
			var o2 := feet
			_rect(Rect2(o2 + Vector2(-w * 0.5, -h + 4), Vector2(w, h - 4)), red)
			draw_rect(Rect2(o2 + Vector2(-w * 0.5 + 1.5, -h + 5), Vector2(1.5, h - 7)), red.lightened(0.35))
			draw_rect(Rect2(o2 + Vector2(-w * 0.5, -h * 0.55), Vector2(w, 4)), Color(0.95, 0.95, 0.9))
			_rect(Rect2(o2 + Vector2(-2, -h), Vector2(4, 4)), Color(0.2, 0.2, 0.22))
			var dirx := float(p.fx_dir if p.fx_dir != 0 else 1)
			draw_polyline(PackedVector2Array([o2 + Vector2(0, -h + 1), o2 + Vector2(dirx * 5, -h + 2), o2 + Vector2(dirx * (w * 0.5 + 1), -h * 2.0 / 3.0)]), OUTLINE, 1.5)


func _draw_parts() -> void:
	for p in _parts:
		var k: float = p[2] / p[3]
		var col: Color = p[6]
		match p[7]:
			0:
				col.a *= 1.0 - k * 0.6
				var v: Vector2 = p[1]
				draw_line(p[0], p[0] - v.normalized() * minf(v.length() * 0.012, 3.0), col, p[4])
			1, 4:
				var r: float = lerpf(p[4], p[5], 1.0 - pow(1.0 - k, 2.0))
				col.a *= 1.0 - k
				draw_circle(p[0], r, col)
				if p[7] == 1:
					draw_circle(p[0] + Vector2(-r * 0.3, -r * 0.3), r * 0.5, Color(1, 1, 1, col.a * 0.6))
			2:
				col.a *= 1.0 - k
				draw_circle(p[0], p[4] * (1.0 - k * 0.5) + 1.0, Color(col, col.a * 0.35))
				draw_circle(p[0], p[4] * (1.0 - k * 0.5), col)
			3:
				col.a *= 1.0 - k
				var v2: Vector2 = p[1]
				draw_line(p[0], p[0] - v2 * 0.02, col, 1.0)


func _draw_arc(a: Vector2, b: Vector2, alpha: float, col: Color) -> void:
	## Arco elétrico zigue-zague: brilho largo + núcleo branco.
	var pts := PackedVector2Array([a])
	var n := 6
	var nrm := (b - a).orthogonal().normalized()
	for k in range(1, n):
		pts.append(a.lerp(b, k / float(n)) + nrm * rng.randf_range(-5, 5))
	pts.append(b)
	draw_polyline(pts, Color(col, 0.35 * alpha), 4.0)
	draw_polyline(pts, Color(col.lightened(0.5), alpha), 1.5)
