extends RefCounted
## Céu vivo e veículos ao fundo (§8.4): dirigíveis-turbina, balões de carpa e de ar quente em duas
## camadas de Parallax2D entre as camadas do backdrop, bando de pássaros cruzando o céu e bonde,
## van e scooter passando numa faixa ao fundo de vez em quando. Só visual; RNG próprio.
## Folhas opcionais (mesmo formato de sprite_lib.strip): amb/amb_ceu_<tipo>, amb/amb_veiculo_<tipo>.

const Fig = preload("res://view/ambient_figures.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")

const HAZE := Color(0.80, 0.62, 0.60)
const REPEAT := 2400.0
const VEHICLE_Y := 413.0
const MAX_VEHICLES := 2

var lib: SpriteLib
var rng: RandomNumberGenerator
var _layers := []     # [{par, canvas, speed, haze, items}]
var _veh_par: Parallax2D
var _veh_canvas
var _vehicles := []   # {type, x, dir, speed}
var _veh_timer := 3.0
var _flock := []      # bando cruzando: {x, y, vx, n, ph}
var _flock_timer := 2.0
var _t := 0.0


func build(backdrop: Node) -> void:
	## Insere as camadas no backdrop: longe (depois do céu), perto (depois do skyline distante) e
	## veículos (depois do skyline médio). Sem arte de backdrop, a world_view pinta o céu de reserva
	## por cima e o céu vivo fica escondido (limitação aceita).
	var far := _layer(backdrop, 0.06, -4.0, 0.5, [
		{"type": "dirigivel", "x": 300.0, "y": 60.0, "s": 0.5},
		{"type": "arquente", "x": 900.0, "y": 110.0, "s": 0.45},
		{"type": "carpa", "x": 1500.0, "y": 50.0, "s": 0.45},
		{"type": "dirigivel", "x": 2000.0, "y": 95.0, "s": 0.4}])
	var near := _layer(backdrop, 0.14, -9.0, 0.25, [
		{"type": "dirigivel", "x": 150.0, "y": 25.0, "s": 0.85},
		{"type": "carpa", "x": 700.0, "y": 80.0, "s": 0.8},
		{"type": "arquente", "x": 1250.0, "y": 40.0, "s": 0.75},
		{"type": "carpa", "x": 1900.0, "y": 105.0, "s": 0.6}])
	var n := backdrop.get_child_count()
	backdrop.add_child(far.par)
	backdrop.move_child(far.par, mini(1, n))
	backdrop.add_child(near.par)
	backdrop.move_child(near.par, mini(3, n + 1))
	_veh_par = Parallax2D.new()
	_veh_par.scroll_scale = Vector2(0.85, 1.0)
	_veh_canvas = Fig.Canvas.new()
	_veh_canvas.painter = _draw_vehicles
	_veh_canvas.modulate = Color(0.58, 0.52, 0.64)   # rua de trás na sombra: sem contraste atrás da luta
	_veh_par.add_child(_veh_canvas)
	backdrop.add_child(_veh_par)
	# Um veículo já em cena para as capturas curtas.
	_vehicles.append({"type": "bonde", "x": 260.0, "dir": 1, "speed": 26.0})


func _layer(_backdrop: Node, scroll: float, speed: float, haze: float, items: Array) -> Dictionary:
	var par := Parallax2D.new()
	par.scroll_scale = Vector2(scroll, scroll * 0.5)
	par.repeat_size = Vector2(REPEAT, 0)
	par.repeat_times = 3
	var cv = Fig.Canvas.new()
	par.add_child(cv)
	for it in items:
		it.ph = rng.randf() * TAU
	var l := {"par": par, "canvas": cv, "speed": speed, "haze": haze, "items": items}
	cv.painter = func(ci): _draw_layer(ci, l)
	_layers.append(l)
	return l


func set_on(on: bool) -> void:
	for l in _layers:
		l.par.visible = on
	if _veh_par:
		_veh_par.visible = on


func update(dt: float) -> void:
	_t += dt
	for l in _layers:
		l.par.scroll_offset.x = fposmod(l.par.scroll_offset.x + l.speed * dt, REPEAT)
		l.canvas.queue_redraw()
	# Veículos: um de cada vez na maior parte do tempo, de vez em quando dois.
	_veh_timer -= dt
	if _veh_timer <= 0.0 and _vehicles.size() < MAX_VEHICLES:
		var types := ["bonde", "van", "scooter", "van", "scooter"]
		var ty: String = types[rng.randi() % types.size()]
		var dir := 1 if rng.randf() < 0.5 else -1
		var spd: float = {"bonde": 34.0, "van": 70.0, "scooter": 95.0}[ty]
		_vehicles.append({"type": ty, "x": -500.0 if dir > 0 else 1800.0, "dir": dir, "speed": spd})
		_veh_timer = rng.randf_range(7.0, 16.0)
	for v in _vehicles:
		v.x += v.dir * v.speed * dt
	_vehicles = _vehicles.filter(func(v): return v.x > -600.0 and v.x < 1900.0)
	# Bando cruzando o céu (na camada de perto).
	_flock_timer -= dt
	if _flock_timer <= 0.0:
		_flock.append({"x": REPEAT * rng.randf(), "y": rng.randf_range(20.0, 120.0), "vx": rng.randf_range(18.0, 30.0) * (1 if rng.randf() < 0.5 else -1),
			"n": rng.randi_range(4, 7), "ph": rng.randf() * TAU, "life": 40.0})
		_flock_timer = rng.randf_range(12.0, 25.0)
	for f in _flock:
		f.x += f.vx * dt
		f.life -= dt
	_flock = _flock.filter(func(f): return f.life > 0.0)
	if _veh_canvas:
		_veh_canvas.queue_redraw()


func _tint(c: Color, haze: float) -> Color:
	return Fig.mute(c, 0.35, 0.0).lerp(HAZE, haze)


func _draw_layer(ci: CanvasItem, l: Dictionary) -> void:
	var hz: float = l.haze
	for it in l.items:
		var sheet: Dictionary = lib.strip("amb/amb_ceu_%s" % it.type) if lib else {}
		var p := Vector2(it.x, it.y + sin(_t * 0.4 + it.ph) * 4.0)
		if not sheet.is_empty():
			_draw_sheet(ci, sheet, p, it.s, 1.0, Color(1, 1, 1).lerp(HAZE, hz))
			continue
		match it.type:
			"dirigivel":
				_airship(ci, p, it.s, hz, it.ph)
			"carpa":
				_koi(ci, p, it.s, hz, it.ph)
			"arquente":
				_hot_air(ci, p, it.s, hz, it.ph)
	if l.speed < -6.0:
		for f in _flock:
			for k in f.n:
				var off := Vector2(-signf(f.vx) * (k * 7.0 + (k % 2) * 3.0), (k % 2) * 5.0 + k * 1.5)
				var bp := Vector2(fposmod(f.x, REPEAT), f.y) + off
				var fl := sin(_t * 9.0 + f.ph + k) * 2.0
				var bc := _tint(Color(0.25, 0.22, 0.28), hz)
				ci.draw_line(bp + Vector2(-3, -fl), bp, bc, 1.0)
				ci.draw_line(bp, bp + Vector2(3, -fl), bc, 1.0)


func _draw_sheet(ci: CanvasItem, sheet: Dictionary, p: Vector2, s: float, face: float, mod: Color) -> void:
	var fr := int(_t * sheet.fps) % maxi(1, sheet.frames)
	var sc: float = sheet.scale * s
	ci.draw_set_transform(p, 0.0, Vector2(sc * face, sc))
	ci.draw_texture_rect_region(sheet.tex, Rect2(-sheet.pivot, Vector2(sheet.w, sheet.h)),
		Rect2(fr * sheet.w, 0, sheet.w, sheet.h), mod)
	ci.draw_set_transform(Vector2.ZERO)


func _airship(ci: CanvasItem, p: Vector2, s: float, hz: float, ph: float) -> void:
	## Dirigível-turbina: envelope, anel do gerador com pás girando, gôndola e cabo de amarra.
	var body := _tint(Color(0.86, 0.80, 0.70), hz)
	var dark := _tint(Color(0.42, 0.40, 0.46), hz)
	var red := _tint(Color(0.72, 0.36, 0.30), hz)
	var a := 1.0 - hz * 0.3
	ci.draw_line(p + Vector2(0, 14 * s), p + Vector2(40 * s, 800), Color(dark, 0.35), 0.8)
	Fig.poly(ci, PackedVector2Array([p + Vector2(-38, -2) * s, p + Vector2(-50, -12) * s, p + Vector2(-46, 0) * s, p + Vector2(-50, 10) * s]), dark, a)
	Fig.poly(ci, Fig.ellipse(p, 42 * s, 12 * s, 24), body, a)
	ci.draw_colored_polygon(Fig.ellipse(p + Vector2(0, 5 * s), 36 * s, 4 * s, 16), Color(body.darkened(0.18), a))
	ci.draw_line(p + Vector2(-20, -11) * s, p + Vector2(-20, 11) * s, Color(red, a), 3.0 * s)
	ci.draw_line(p + Vector2(18, -11) * s, p + Vector2(18, 11) * s, Color(red, a), 3.0 * s)
	# Anel do gerador (turbina), visto de lado: aro grosso com pás.
	var rc := p + Vector2(0, -2 * s)
	ci.draw_arc(rc, 17 * s, 0, TAU, 28, Color(Fig.OUTLINE, a), 6.0 * s + 2.0)
	ci.draw_arc(rc, 17 * s, 0, TAU, 28, Color(dark, a), 6.0 * s)
	for k in 3:
		var ang := _t * 2.2 + ph + k * TAU / 3.0
		ci.draw_line(rc, rc + Vector2(cos(ang), sin(ang)) * 14 * s, Color(body.darkened(0.3), a), 2.0 * s)
	ci.draw_circle(rc, 2.5 * s, Color(red, a))
	Fig.box(ci, Rect2(p + Vector2(-8, 11) * s, Vector2(16, 5) * s), dark, a, 0.8)
	for k in 3:
		ci.draw_rect(Rect2(p + Vector2(-6 + k * 5, 12) * s, Vector2(2.5, 2) * s), Color(_tint(Color(1.0, 0.8, 0.45), hz * 0.5), a))


func _koi(ci: CanvasItem, p: Vector2, s: float, hz: float, ph: float) -> void:
	## Balão de carpa (koinobori original): corpo ondulando, escamas em manchas, cauda.
	var red := _tint(Color(0.80, 0.34, 0.28), hz)
	var white := _tint(Color(0.92, 0.88, 0.82), hz)
	var gold := _tint(Color(0.86, 0.66, 0.30), hz)
	var a := 1.0 - hz * 0.3
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := 10
	for i in n + 1:
		var u := float(i) / n
		var x := lerpf(22.0, -22.0, u)
		var wv := sin(_t * 2.0 + ph - u * 4.0) * 3.0 * u
		var r := lerpf(8.0, 3.0, u * u)
		top.append(p + Vector2(x, -r + wv) * s)
		bot.append(p + Vector2(x, r + wv) * s)
	var body := top.duplicate()
	bot.reverse()
	body.append_array(bot)
	var tail_c: Vector2 = top[n].lerp(bot[0], 0.5)
	var tw := sin(_t * 2.0 + ph - 4.0) * 3.0
	Fig.poly(ci, PackedVector2Array([tail_c, tail_c + Vector2(-9, -8 + tw) * s, tail_c + Vector2(-5, 0) * s, tail_c + Vector2(-9, 8 + tw) * s]), red, a)
	Fig.poly(ci, body, white, a)
	for k in 3:
		var u := 0.2 + k * 0.25
		var c: Vector2 = top[int(u * n)].lerp(bot[n - int(u * n)], 0.4)
		ci.draw_colored_polygon(Fig.ellipse(c, 4.5 * s, 3.5 * s, 10), Color(red if k != 1 else gold, a))
	var head := p + Vector2(20, 0) * s
	ci.draw_arc(head + Vector2(2, 0) * s, 6.5 * s, -1.2, 1.2, 8, Color(red, a), 2.0 * s)
	ci.draw_circle(head + Vector2(-3, -2.5) * s, 1.8 * s, Color(Fig.OUTLINE, a))
	ci.draw_circle(head + Vector2(-3, -2.5) * s, 1.0 * s, Color(white, a))
	ci.draw_line(head + Vector2(3, 0) * s, head + Vector2(3, 0) * s + Vector2(10, 60), Color(Fig.OUTLINE, 0.25), 0.7)


func _hot_air(ci: CanvasItem, p: Vector2, s: float, hz: float, ph: float) -> void:
	## Balão de ar quente com gomos e faixa geométrica.
	var c1 := _tint(Color(0.34, 0.60, 0.62), hz)
	var c2 := _tint(Color(0.88, 0.74, 0.40), hz)
	var c3 := _tint(Color(0.78, 0.40, 0.36), hz)
	var a := 1.0 - hz * 0.3
	var env := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		env.append(p + Vector2(cos(ang) * 16, sin(ang) * 17) * s)
	env.append(p + Vector2(9, 16) * s)
	env.append(p + Vector2(4, 24) * s)
	env.append(p + Vector2(-4, 24) * s)
	env.append(p + Vector2(-9, 16) * s)
	Fig.poly(ci, env, c1, a)
	ci.draw_colored_polygon(Fig.ellipse(p + Vector2(0, 2) * s, 8 * s, 18 * s, 16), Color(c2, a))
	ci.draw_colored_polygon(Fig.ellipse(p + Vector2(0, 2) * s, 3 * s, 19 * s, 12), Color(c1, a))
	var zz := PackedVector2Array()
	for i in 9:
		zz.append(p + Vector2(-15 + i * 3.75, 4 + (i % 2) * 4) * s)
	ci.draw_polyline(zz, Color(c3, a), 2.2 * s)
	ci.draw_line(p + Vector2(-4, 24) * s, p + Vector2(-3, 31) * s, Color(Fig.OUTLINE, a * 0.7), 0.7)
	ci.draw_line(p + Vector2(4, 24) * s, p + Vector2(3, 31) * s, Color(Fig.OUTLINE, a * 0.7), 0.7)
	Fig.box(ci, Rect2(p + Vector2(-3.5, 31) * s, Vector2(7, 5) * s), _tint(Color(0.5, 0.38, 0.26), hz), a, 0.8)
	if int(_t * 1.3 + ph) % 5 == 0:
		ci.draw_circle(p + Vector2(0, 26) * s, 2.0 * s, Color(1.0, 0.75, 0.35, 0.6 * a))


func _draw_vehicles(ci: CanvasItem) -> void:
	var hz := 0.3
	# Fio aéreo do bonde, discreto.
	ci.draw_line(Vector2(-700, VEHICLE_Y - 34), Vector2(2000, VEHICLE_Y - 34), Color(0.15, 0.12, 0.18, 0.35), 0.8)
	for v in _vehicles:
		var face: float = v.dir
		var p := Vector2(v.x, VEHICLE_Y)
		var sheet: Dictionary = lib.strip("amb/amb_veiculo_%s" % v.type) if lib else {}
		if not sheet.is_empty():
			_draw_sheet(ci, sheet, p, 0.8, face, Color(1, 1, 1).lerp(HAZE, hz))
			continue
		match v.type:
			"bonde":
				_tram(ci, p, face, hz)
			"van":
				_van(ci, p, face, hz)
			"scooter":
				_scooter(ci, p, face, hz)


func _wheel(ci: CanvasItem, c: Vector2, r: float, hz: float) -> void:
	ci.draw_circle(c, r + 1.0, Fig.OUTLINE)
	ci.draw_circle(c, r, _tint(Color(0.2, 0.2, 0.24), hz))
	ci.draw_circle(c, r * 0.4, _tint(Color(0.55, 0.55, 0.58), hz))


func _tram(ci: CanvasItem, p: Vector2, face: float, hz: float) -> void:
	var cream := _tint(Color(0.88, 0.82, 0.68), hz)
	var teal := _tint(Color(0.32, 0.52, 0.52), hz)
	var body := Rect2(p + Vector2(-30, -26), Vector2(60, 22))
	ci.draw_line(p + Vector2(-4, -26), p + Vector2(4, -34), Fig.OUTLINE, 1.0)
	ci.draw_line(p + Vector2(4, -34), p + Vector2(10, -34), Fig.OUTLINE, 1.0)
	Fig.box(ci, Rect2(body.position + Vector2(2, -3), Vector2(56, 4)), teal)
	Fig.box(ci, body, cream)
	ci.draw_rect(Rect2(body.position + Vector2(0, 14), Vector2(60, 8)), teal)
	for k in 6:
		var w := Rect2(body.position + Vector2(4 + k * 9, 3), Vector2(6, 8))
		ci.draw_rect(w, _tint(Color(1.0, 0.82, 0.52), hz * 0.6))
		ci.draw_rect(Rect2(w.position, Vector2(6, 2)), _tint(Color(0.6, 0.45, 0.35), hz))
	_wheel(ci, p + Vector2(-18, -2), 2.5, hz)
	_wheel(ci, p + Vector2(18, -2), 2.5, hz)
	ci.draw_circle(p + Vector2(face * 29, -8), 1.5, Color(1.0, 0.9, 0.6, 0.8))


func _van(ci: CanvasItem, p: Vector2, face: float, hz: float) -> void:
	## Desenhada virada para a direita e espelhada por transformação.
	var col := _tint(Color(0.86, 0.84, 0.80), hz)
	var stripe := _tint(Color(0.78, 0.46, 0.30), hz)
	ci.draw_set_transform(p, 0.0, Vector2(face, 1.0))
	Fig.box(ci, Rect2(-20, -21, 28, 17), col)
	Fig.poly(ci, PackedVector2Array([Vector2(8, -21), Vector2(14, -21), Vector2(20, -12), Vector2(20, -4), Vector2(8, -4)]), col)
	ci.draw_rect(Rect2(-20, -12, 40, 3), stripe)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, -19), Vector2(14, -19), Vector2(18, -13), Vector2(12, -13)]), _tint(Color(0.5, 0.62, 0.7), hz))
	_wheel(ci, Vector2(-13, -3), 3.0, hz)
	_wheel(ci, Vector2(13, -3), 3.0, hz)
	ci.draw_circle(Vector2(19.5, -7), 1.3, Color(1.0, 0.9, 0.6, 0.8))
	ci.draw_set_transform(Vector2.ZERO)


func _scooter(ci: CanvasItem, p: Vector2, face: float, hz: float) -> void:
	var col := _tint(Color(0.62, 0.78, 0.70), hz)
	_wheel(ci, p + Vector2(-6 * face, -2.5), 2.5, hz)
	_wheel(ci, p + Vector2(7 * face, -2.5), 2.5, hz)
	Fig.poly(ci, PackedVector2Array([p + Vector2(-8 * face, -4), p + Vector2(4 * face, -4), p + Vector2(6 * face, -12), p + Vector2(8 * face, -12), p + Vector2(8 * face, -5), p + Vector2(-6 * face, -9)]), col)
	var look := {"top": _tint(Color(0.55, 0.42, 0.50), hz), "bottom": _tint(Color(0.28, 0.28, 0.34), hz), "hair": Color(0.2, 0.18, 0.2),
		"skin": _tint(Color(0.7, 0.55, 0.45), hz), "hat": _tint(Color(0.85, 0.82, 0.78), hz)}
	Fig.person(ci, p + Vector2(-1 * face, -6), face, Fig.sit({"ua_f": 1.3, "la_f": 0.2, "ua_b": 1.2, "la_b": 0.2, "lean": 0.15}), look, 17.0)
