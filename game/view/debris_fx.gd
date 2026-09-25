extends Node2D
## Efeitos cosméticos procedurais (§4.3, §19.3): nunca afetam a simulação; RNG próprio.
## Tipos: lascas que giram (forma e cor por material: cacos de vidro triangulares, blocos de tijolo
## e concreto com ferragem), faíscas de impacto em estrela com núcleo branco e raios, fumaça que
## expande, brasas, anéis de choque e poeira. Flipbooks do lote 02 (fx/) entram por cima se existirem.
## Ruptura de vidro/concreto/tijolo também gera cacos por fratura Delaunay (PolygonFracture, MIT,
## view/third_party/polygon2d_fracture) texturizados com a textura do material; RNG semeado pelo
## evento (tick, seq, célula), então o mesmo replay dá os mesmos cacos. Pool limitado (MAX_SHARDS).

const C = preload("res://sim/sim_const.gd")
const WorldView = preload("res://view/world_view.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const PolygonFracture = preload("res://view/third_party/polygon2d_fracture/PolygonFracture.gd")

const MAX_PARTICLES := 900
const MAX_CHUNKS := 260
const MAX_SMOKE := 120
const OUTLINE := Color(0.08, 0.06, 0.11)
const GRAVITY := 600.0
const MAX_SHARDS := 180           # cacos texturizados vivos
const SHARDS_PER_EVENT := 48
const SHARD_BLOCK := 2            # bloco de fratura: 2×2 células (16 px)
const SHARD_TILE := 64.0          # mesma escala de textura do matter.gdshader (tile_px)
const SHARD_MATS := {1: "vidro", 3: "tijolo", 4: "concreto"}

var rng := RandomNumberGenerator.new()
var lib: SpriteLib
var intensity := 1.0
var _parts := []    # pontos: [pos, vel, color, life, size]
var _chunks := []   # lascas: [pos, vel, ang, spin, size, color, life, mat, verts]
var _smoke := []    # [pos, vel, raio, raio_final, idade, duração, cor]
var _sparks := []   # [pos, idade, duração, tamanho, cor, pontas, rotação]
var _rings := []    # [pos, raio, idade, duração, cor]
var _flip := []     # flipbooks: [nome, pos, idade, escala, espelhar, cor]
var _shards := []   # [pos, vel, ang, spin, poly centrado, uvs, textura, vida, mat, vida inicial]
var _host = null    # main.gd: lê `sim.grid` (só leitura) para os cacos quicarem no chão


func _init() -> void:
	rng.seed = 12345
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _ready() -> void:
	var host := get_parent()
	if host != null and "sim" in host:
		_host = host


# ---------------------------------------------------------------- eventos

func on_break(e: Dictionary, mats: Array) -> void:
	var cells: PackedInt32Array = e.cells
	var dir := Vector2(e.dir, 0) if e.axis == 0 else Vector2(0, e.dir)
	var n := mini(cells.size(), 40)
	var center_sum := Vector2.ZERO
	var glass := 0
	for k in n:
		var i: int = cells[k]
		var center := _cell_center(i)
		center_sum += center
		var m: int = mats[k] if k < mats.size() else C.M_CONCRETE
		glass += int(m == C.M_GLASS)
		for j in (3 if m == C.M_GLASS else 2):
			var v := dir * rng.randf_range(60, 240) + Vector2(rng.randf_range(-80, 80), rng.randf_range(-160, 20))
			_chunk(center + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), v, m)
		if k % 2 == 0:
			var col: Color = WorldView.MAT_COLOR[m]
			col.a = 1.0
			_spawn(center, dir * rng.randf_range(40, 140) + Vector2(0, rng.randf_range(-80, 0)), col.lightened(0.2), rng.randf_range(0.3, 0.7))
	_fracture(e, cells, mats, dir)
	if n > 0:
		var c := center_sum / n
		_puff(c, dir * 40.0, 6.0 + n * 0.6, Color(0.78, 0.72, 0.66, 0.55), 0.7 + n * 0.02)
		if glass > n / 2:
			_play("fx_vidro_estilhaco", c, 0.5, e.dir < 0)
			_spark(c, 10.0 + n, Color(0.75, 0.95, 1.0), 6)
		elif int(e.get("r", 0)) > 600:
			_ring(c, 10.0 + n * 1.5, 0.25, Color(1.0, 0.85, 0.6))


func on_chip(e: Dictionary, grid) -> void:
	## Golpe lascou sem romper: lascas pequenas voltando contra o golpe e um brilho seco.
	var cells: PackedInt32Array = e.cells
	var sum := Vector2.ZERO
	var cnt := 0
	for k in mini(cells.size(), 8):
		var i: int = cells[k]
		var m: int = grid.mat[i]
		if m == C.M_EMPTY:
			continue
		var c := _cell_center(i)
		sum += c
		cnt += 1
		if k % 2 == 0:
			_chunk(c, Vector2(-e.dir * rng.randf_range(40, 130), rng.randf_range(-150, -30)), m, 0.6)
	if cnt > 0:
		_spark(sum / cnt, 9.0, Color(1.0, 0.95, 0.8), 5)
		_puff(sum / cnt, Vector2(-e.dir * 20, -10), 5.0, Color(0.8, 0.76, 0.7, 0.45), 0.45)


func on_hit(pos: Vector2, kb: int, dir_x: int) -> void:
	## Faísca de acerto: estrela com núcleo branco; forte ganha raios, anel e flipbook.
	var s := clampf(kb / 2000.0, 0.0, 1.0)
	_spark(pos, 10.0 + 22.0 * s, Color(1.0, 0.9, 0.45) if s > 0.5 else Color(1.0, 0.97, 0.85), 8 if s > 0.5 else 6)
	for k in int(6 + 14 * s):
		var ang := rng.randf_range(-0.9, 0.9) + (0.0 if dir_x > 0 else PI)
		var v := Vector2(cos(ang), sin(ang)) * rng.randf_range(180, 420) * (0.6 + s)
		_spawn(pos, v, Color(1.0, 0.92, 0.6), rng.randf_range(0.15, 0.35))
	if s > 0.45:
		_ring(pos, 18.0 + 30.0 * s, 0.22, Color(1.0, 0.95, 0.8))
		_play("tp/ring_gold", pos, 0.28 + 0.18 * s, false)
		_play("tp/hit_b", pos, 0.2 + 0.12 * s, dir_x < 0)
		_play("fx_acerto_forte", pos, 0.35 + 0.25 * s, dir_x < 0)
	else:
		_play("tp/hit_a", pos, 0.18, dir_x < 0)
		_play("fx_acerto_leve", pos, 0.3, dir_x < 0)


func on_shield_hit(pos: Vector2) -> void:
	_spark(pos, 12.0, Color(0.6, 0.95, 1.0), 6)
	_play("tp/sparkle_cyan", pos, 0.3, false)
	_ring(pos, 16.0, 0.18, Color(0.6, 0.95, 1.0))


func on_shield_break(pos: Vector2) -> void:
	_play("fx_escudo_quebra", pos, 0.45, false)
	for k in 26:
		var ang := TAU * k / 26.0
		var v := Vector2(cos(ang), sin(ang)) * rng.randf_range(120, 260)
		_chunk(pos, v, C.M_GLASS, 0.8, Color(0.6, 0.92, 1.0))
	_ring(pos, 40.0, 0.35, Color(0.6, 0.95, 1.0))


func on_warn(cells: PackedInt32Array) -> void:
	## Aviso de colapso: poeira caindo e pequenas pedras das células que vão soltar (§4.2).
	for k in mini(cells.size(), 180):
		if k % 3 != 0:
			continue
		var i: int = cells[k]
		var p := Vector2((i % C.GRID_W) * C.CELL + rng.randf_range(0, 8), (i / C.GRID_W) * C.CELL + 8)
		_spawn(p, Vector2(rng.randf_range(-10, 10), rng.randf_range(0, 40)), Color(0.8, 0.75, 0.68, 0.8), rng.randf_range(0.4, 0.9))
		if k % 12 == 0:
			_chunk(p, Vector2(rng.randf_range(-15, 15), 10), C.M_CONCRETE, 0.45)


func on_dust_cells(cells: PackedInt32Array) -> void:
	## Assentamento de entulho: nuvem grande de poeira que rola para os lados, mais pedras.
	var sum := Vector2.ZERO
	for k in mini(cells.size(), 160):
		var i: int = cells[k]
		var p := Vector2((i % C.GRID_W) * C.CELL + 4, (i / C.GRID_W) * C.CELL)
		sum += p
		if k % 2 == 0:
			_spawn(p, Vector2(rng.randf_range(-90, 90), rng.randf_range(-110, -20)), Color(0.78, 0.72, 0.66, 0.75), rng.randf_range(0.5, 1.1))
		if k % 6 == 0:
			_puff(p, Vector2(rng.randf_range(-70, 70), rng.randf_range(-30, -5)), rng.randf_range(8, 16), Color(0.74, 0.68, 0.62, 0.5), rng.randf_range(1.0, 1.8))
		if k % 5 == 0:
			_chunk(p, Vector2(rng.randf_range(-120, 120), rng.randf_range(-200, -60)), C.M_RUBBLE, 1.0)
		if k % 24 == 0:
			_play("tp/smoke", p + Vector2(0, -10), 0.5, rng.randf() < 0.5, Color(0.9, 0.85, 0.8, 0.8))


func on_burst(pos: Vector2, radius: float) -> void:
	## Explosão: anel duplo, faíscas radiais, brasas e fumaça em volta.
	_ring(pos, radius, 0.3, Color(1.0, 0.85, 0.4))
	_ring(pos, radius * 1.5, 0.5, Color(1.0, 0.6, 0.25))
	_spark(pos, radius * 0.8, Color(1.0, 0.85, 0.45), 10)
	_play("fx_explosao_anel", pos, radius / 60.0, false)
	_play("tp/ring_fire", pos, radius / 40.0, false)
	_play("tp/smoke", pos, radius / 45.0, false, Color(1, 1, 1, 0.7))
	for k in 40:
		var ang := TAU * k / 40.0 + rng.randf_range(-0.05, 0.05)
		var v := Vector2(cos(ang), sin(ang)) * rng.randf_range(200, 380)
		_spawn(pos + v.normalized() * 6.0, v, Color(1.0, 0.9, 0.5), rng.randf_range(0.25, 0.5))
	for k in 10:
		var ang := TAU * k / 10.0
		_puff(pos + Vector2(cos(ang), sin(ang)) * radius * 0.6, Vector2(cos(ang), sin(ang)) * 60.0, 10.0, Color(0.7, 0.62, 0.55, 0.5), 1.2)


func on_dust(pos: Vector2, amount: int) -> void:
	for k in amount:
		_spawn(pos + Vector2(rng.randf_range(-10, 10), 0), Vector2(rng.randf_range(-50, 50), rng.randf_range(-40, -5)),
			Color(0.8, 0.75, 0.7, 0.7), rng.randf_range(0.25, 0.5))
	_puff(pos + Vector2(-6, -2), Vector2(-40, -8), 4.0 + amount * 0.4, Color(0.82, 0.77, 0.72, 0.5), 0.5)
	_puff(pos + Vector2(6, -2), Vector2(40, -8), 4.0 + amount * 0.4, Color(0.82, 0.77, 0.72, 0.5), 0.5)


# ---------------------------------------------------------------- cacos por fratura

func _fracture(e: Dictionary, cells: PackedInt32Array, mats: Array, dir: Vector2) -> void:
	## Agrupa as células rompidas em blocos de SHARD_BLOCK² por material e fratura cada bloco
	## (Delaunay em retângulo) em 3-5 cacos com a textura do material em espaço de mundo.
	if lib == null or cells.is_empty():
		return
	var seed_v: int = int(e.get("tick", 0)) * 7919 + int(e.get("seq", 0)) * 131 + cells[0] * 17 + cells.size()
	var frac = PolygonFracture.new(seed_v)
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var blocks := {}   # chave do bloco → material
	for k in cells.size():
		var m: int = mats[k] if k < mats.size() else C.M_CONCRETE
		if not SHARD_MATS.has(m):
			continue
		var i: int = cells[k]
		var key: int = ((i / C.GRID_W) / SHARD_BLOCK) * 1000 + (i % C.GRID_W) / SHARD_BLOCK
		if not blocks.has(key):
			blocks[key] = m
	var budget := SHARDS_PER_EVENT
	var keys := blocks.keys()
	keys.sort()
	for key in keys:
		if budget <= 0:
			break
		var m: int = blocks[key]
		var tex := lib.texture("mod/mod_textura_%s.png" % SHARD_MATS[m])
		if tex == null:
			continue
		var bs := float(SHARD_BLOCK * C.CELL)
		var center := Vector2((key % 1000) * bs, (key / 1000) * bs) + Vector2(bs, bs) / 2.0
		# Polígono local centrado na origem + transform: é o uso previsto da biblioteca (o
		# getBoundingRect dela parte de (0, 0) e erra retângulos que não contêm a origem).
		var hb := bs / 2.0
		var rect := PackedVector2Array([Vector2(-hb, -hb), Vector2(hb, -hb), Vector2(hb, hb), Vector2(-hb, hb)])
		var pieces: Array = frac.fractureDelaunayRectangle(rect, Transform2D(0.0, center), 2 if m == C.M_GLASS else 1, 4.0)
		for info in pieces:
			if budget <= 0:
				break
			budget -= 1
			var local_pts: PackedVector2Array = info.shape
			var uvs := PackedVector2Array()
			for q in local_pts:
				uvs.append((q + center) / SHARD_TILE)
			var pos: Vector2 = info.spawn_pos
			var v := dir * r.randf_range(50, 220) + Vector2(r.randf_range(-90, 90), r.randf_range(-190, -20))
			var life := r.randf_range(0.9, 1.7)
			if _shards.size() >= MAX_SHARDS:
				_shards.pop_front()
			_shards.append([pos, v, 0.0, r.randf_range(-9.0, 9.0), info.centered_shape, uvs, tex, life, m, life])


func _step_shards(delta: float) -> void:
	for s in _shards:
		s[1].y += GRAVITY * delta
		s[1].x *= 1.0 - 0.6 * delta
		var np: Vector2 = s[0] + s[1] * delta
		if s[1].y > 0.0 and _solid_px(np + Vector2(0, 2)):
			# Quica no chão perdendo energia e giro (só cosmético).
			s[1] = Vector2(s[1].x * 0.55, -s[1].y * 0.28)
			s[3] *= 0.5
			if absf(s[1].y) < 30.0:
				s[1].y = 0.0
		else:
			s[0] = np
		s[2] += s[3] * delta
		s[7] -= delta
	_shards = _shards.filter(func(s): return s[7] > 0.0)


func _solid_px(p: Vector2) -> bool:
	if _host == null or _host.sim == null or _host.sim.grid == null:
		return false
	var grid = _host.sim.grid
	var cx := int(floor(p.x / C.CELL))
	var cy := int(floor(p.y / C.CELL))
	if cx < 0 or cy < 0 or cx >= C.GRID_W or cy >= C.GRID_H:
		return false
	return grid.mat[cy * C.GRID_W + cx] != C.M_EMPTY


func _draw_shards() -> void:
	for s in _shards:
		var a: float = clampf(s[7] / 0.35, 0.0, 1.0)
		var glass: bool = s[8] == C.M_GLASS
		var tint := Color(1.1, 1.15, 1.2, 0.85 * a) if glass else Color(1, 1, 1, a)
		draw_set_transform(s[0], s[2], Vector2.ONE)
		var poly: PackedVector2Array = s[4]
		draw_polygon(poly, PackedColorArray([tint]), s[5], s[6])
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(OUTLINE, 0.9 * a), 1.0)
		if glass:
			draw_line(poly[0], poly[1], Color(1, 1, 1, 0.9 * a), 1.0)   # brilho da aresta
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- criação

func _cell_center(i: int) -> Vector2:
	return Vector2((i % C.GRID_W) * C.CELL + 4, (i / C.GRID_W) * C.CELL + 4)


func _spawn(p: Vector2, v: Vector2, col: Color, life: float) -> void:
	if _parts.size() >= MAX_PARTICLES:
		_parts.pop_front()
	_parts.append([p, v, col, life, 2.0 if rng.randf() < 0.7 else 3.0])


func _chunk(p: Vector2, v: Vector2, m: int, scale := 1.0, override := Color(0, 0, 0, 0)) -> void:
	if _chunks.size() >= MAX_CHUNKS:
		_chunks.pop_front()
	var col: Color = override if override.a > 0.0 else WorldView.MAT_COLOR[m]
	col.a = 1.0
	col = col.darkened(rng.randf_range(0.0, 0.25))
	var size := rng.randf_range(2.0, 4.5) * scale
	var verts := PackedVector2Array()
	if m == C.M_GLASS:
		# Caco: triângulo alongado.
		verts = PackedVector2Array([Vector2(-size, -size * 0.3), Vector2(size * 1.4, 0), Vector2(-size * 0.4, size * 0.8)])
	else:
		# Bloco irregular de 5 lados.
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
			verts.append(Vector2(cos(a), sin(a)) * size * rng.randf_range(0.7, 1.15))
	_chunks.append([p, v, rng.randf_range(0, TAU), rng.randf_range(-12, 12), size, col, rng.randf_range(0.8, 1.6), m, verts])


func _puff(p: Vector2, v: Vector2, r: float, col: Color, dur: float) -> void:
	if _smoke.size() >= MAX_SMOKE:
		_smoke.pop_front()
	_smoke.append([p, v, r * 0.5, r * 2.2, 0.0, dur, col])


func _spark(p: Vector2, size: float, col: Color, points: int) -> void:
	_sparks.append([p, 0.0, 0.16, size * intensity, col, points, rng.randf_range(0, TAU)])


func _ring(p: Vector2, r: float, dur: float, col: Color) -> void:
	_rings.append([p, r, 0.0, dur, col])


func _fx(name: String) -> Dictionary:
	## Flipbook do pipeline: aceita "fx/fx_nome" ou "fx/nome"; "tp/nome" = terceiros CC0
	## em assets/third_party (folhas em grade).
	if name.begins_with("tp/"):
		return lib.strip("third_party/" + name.substr(3))
	var a := lib.strip("fx/" + name)
	if a.is_empty():
		a = lib.strip("fx/" + name.trim_prefix("fx_"))
	return a


func _play(name: String, p: Vector2, scale: float, flip: bool, col := Color.WHITE) -> void:
	if lib == null or _fx(name).is_empty():
		return
	_flip.append([name, p, 0.0, scale, flip, col])


# ---------------------------------------------------------------- simulação cosmética

func _process(delta: float) -> void:
	for p in _parts:
		p[1].y += GRAVITY * delta
		p[0] += p[1] * delta
		p[3] -= delta
	_parts = _parts.filter(func(p): return p[3] > 0.0)
	for c in _chunks:
		c[1].y += GRAVITY * delta
		c[1].x *= 1.0 - 0.8 * delta
		c[0] += c[1] * delta
		c[2] += c[3] * delta
		c[6] -= delta
	_chunks = _chunks.filter(func(c): return c[6] > 0.0)
	_step_shards(delta)
	for s in _smoke:
		s[4] += delta
		s[0] += s[1] * delta
		s[1] *= 1.0 - 1.5 * delta
		s[1].y -= 12.0 * delta
	_smoke = _smoke.filter(func(s): return s[4] < s[5])
	for s in _sparks:
		s[1] += delta
	_sparks = _sparks.filter(func(s): return s[1] < s[2])
	for r in _rings:
		r[2] += delta
	_rings = _rings.filter(func(r): return r[2] < r[3])
	for f in _flip:
		f[2] += delta
	_flip = _flip.filter(func(f): return f[2] < _flip_len(f[0]))
	queue_redraw()


func _flip_len(name: String) -> float:
	var a := _fx(name)
	return 0.0 if a.is_empty() else float(a.frames) / a.fps


func _draw() -> void:
	# Fumaça atrás de tudo: círculos em camadas, crescendo e sumindo.
	for s in _smoke:
		var k: float = s[4] / s[5]
		var r: float = lerpf(s[2], s[3], 1.0 - pow(1.0 - k, 2.0))
		var col: Color = s[6]
		col.a *= (1.0 - k)
		draw_circle(s[0], r, col)
		draw_circle(s[0] + Vector2(-r * 0.3, -r * 0.25), r * 0.6, Color(col.lightened(0.15), col.a * 0.8))
	_draw_shards()
	for c in _chunks:
		var col: Color = c[5]
		col.a = clampf(c[6] * 2.0, 0.0, 1.0)
		var xf := Transform2D(c[2], c[0])
		var pts: PackedVector2Array = xf * (c[8] as PackedVector2Array)
		draw_colored_polygon(pts, col)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(OUTLINE, col.a), 1.0)
		if c[7] == C.M_GLASS:
			draw_line(pts[0], pts[1], Color(1, 1, 1, col.a * 0.8), 1.0)   # brilho do caco
	for p in _parts:
		var col: Color = p[2]
		col.a *= clampf(p[3] * 2.0, 0.0, 1.0)
		draw_rect(Rect2(p[0].floor(), Vector2(p[4], p[4])), col)
	for r in _rings:
		var k: float = r[2] / r[3]
		var rad: float = r[1] * (0.3 + 0.9 * k)
		draw_circle(r[0], rad, Color(r[4], 0.25 * (1.0 - k)))
		draw_arc(r[0], rad, 0, TAU, 48, Color(r[4], 1.0 - k), 3.0 * (1.0 - k) + 1.0)
	for s in _sparks:
		var k: float = s[1] / s[2]
		_draw_star(s[0], s[3] * (0.6 + 0.8 * k), s[5], s[6], Color(s[4], 1.0 - k))
	for f in _flip:
		var a := _fx(f[0])
		var idx: int = clampi(int(f[2] * a.fps), 0, a.frames - 1)
		var sc: float = a.scale * f[3] * 4.0
		var size: Vector2 = Vector2(a.w, a.h) * sc
		var src := SpriteLib.frame_rect(a, idx)
		draw_set_transform(f[1], 0.0, Vector2(-1 if f[4] else 1, 1))
		draw_texture_rect_region(a.tex, Rect2(-size / 2, size), src, f[5])
		draw_set_transform(Vector2.ZERO)


func _draw_star(c: Vector2, r: float, points: int, rot: float, col: Color) -> void:
	## Estrela de impacto estilo anime: pontas longas e finas, núcleo branco.
	var pts := PackedVector2Array()
	for k in points * 2:
		var a := rot + PI * k / points
		var rr := r if k % 2 == 0 else r * 0.28
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	draw_circle(c, r * 0.3, Color(1, 1, 1, col.a))
