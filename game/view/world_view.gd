extends Node2D
## Desenha interiores (revelados quando a fachada some, §4.5) e a grade de matéria. A grade vira uma
## textura de 1 texel por célula (material, HP) e um shader desenha cada célula com a textura do
## material em espaço de mundo (assets do lote 02). Sem textura, usa a cor de reserva do material.
## Céu e skyline em parallax ficam em backdrop.gd; aqui só o céu de reserva, se faltar arte.

const C = preload("res://sim/sim_const.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const MatterShader = preload("res://view/matter.gdshader")

# Paleta de reserva (§9.4): cidade dessaturada de valor médio; retrofuturista ao entardecer (§19.1).
const MAT_COLOR := [Color(0, 0, 0, 0), Color(0.66, 0.90, 0.97, 0.72), Color(0.74, 0.70, 0.62),
	Color(0.58, 0.33, 0.27), Color(0.47, 0.49, 0.53), Color(0.20, 0.20, 0.25), Color(0.52, 0.46, 0.40)]
const SKY_TOP := Color(0.20, 0.17, 0.30)
const SKY_BOTTOM := Color(0.86, 0.52, 0.38)
# Texturas por material (índice = material) e da rua. Nomes do pipeline tools/art.
const MAT_TEX := ["", "vidro", "divisoria", "tijolo", "concreto", "nucleo", "entulho"]
const MAT_UNIFORM := ["", "tex_glass", "tex_drywall", "tex_brick", "tex_concrete", "tex_core", "tex_rubble"]
# Interiores em células [x0, y0, x1, y1], cor de reserva e imagem.
const ROOMS := [
	[46, 36, 73, 51, Color(0.42, 0.30, 0.24), "loja"],
	[76, 36, 101, 51, Color(0.36, 0.28, 0.25), "fundos"],
	[46, 18, 79, 33, Color(0.38, 0.33, 0.28), "escritorio"],
	[82, 18, 101, 33, Color(0.33, 0.29, 0.27), "escritorio"],
]

var sim
var lib: SpriteLib
var has_backdrop := false
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D


func _ready() -> void:
	if lib == null:
		lib = SpriteLib.new()
	_image = Image.create(C.GRID_W, C.GRID_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(C.CELL, C.CELL)
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = MatterShader
	var bits := 0
	for m in range(1, MAT_TEX.size()):
		var t := lib.texture("mod/mod_textura_%s.png" % MAT_TEX[m])
		if t != null:
			mat.set_shader_parameter(MAT_UNIFORM[m], t)
			bits |= 1 << m
	var street := lib.texture("mod/mod_textura_rua.png")
	if street != null:
		mat.set_shader_parameter("tex_street", street)
		bits |= 128
	mat.set_shader_parameter("has_tex", bits)
	# Máscara de rachadura por dano (CC0, assets/third_party/noise).
	var cracks := lib.texture("third_party/noise/cracks_1.png")
	if cracks != null:
		mat.set_shader_parameter("tex_cracks", cracks)
		mat.set_shader_parameter("has_cracks", true)
	var pal := []
	for c in MAT_COLOR:
		pal.append(Vector4(c.r, c.g, c.b, c.a))
	mat.set_shader_parameter("pal", pal)
	_sprite.material = mat
	add_child(_sprite)


func refresh() -> void:
	var grid = sim.grid
	if grid.full_dirty:
		for i in C.GRID_W * C.GRID_H:
			_paint(grid, i)
		grid.full_dirty = false
		grid.changed.clear()
	elif not grid.changed.is_empty():
		for i in grid.changed:
			_paint(grid, i)
		grid.changed.clear()
	else:
		return
	_texture.update(_image)


func _paint(grid, i: int) -> void:
	var m: int = grid.mat[i]
	if m == C.M_EMPTY:
		_image.set_pixel(i % C.GRID_W, i / C.GRID_W, Color(0, 0, 0, 0))
		return
	var frac := 1.0
	if m != C.M_CORE:
		frac = clampf(float(grid.hp[i]) / float(C.MAT_HP[m]), 0.0, 1.0)
	_image.set_pixel(i % C.GRID_W, i / C.GRID_W, Color(m / 255.0, frac, 0.0, 1.0))


func _draw() -> void:
	var w := float(C.WORLD_W)
	if not has_backdrop:
		var steps := 12
		for k in steps:
			var y0 := -400.0 + (C.WORLD_H + 400.0) * k / steps
			var y1 := -400.0 + (C.WORLD_H + 400.0) * (k + 1) / steps
			draw_rect(Rect2(-400, y0, w + 800, y1 - y0 + 1), SKY_TOP.lerp(SKY_BOTTOM, float(k) / steps))
		var skyline := [[-300, 180, 140], [-120, 240, 90], [0, 150, 110], [130, 200, 70], [860, 170, 120],
			[1000, 110, 90], [1110, 210, 150], [1280, 140, 160]]
		for b in skyline:
			draw_rect(Rect2(b[0], b[1], b[2], C.WORLD_H - b[1]), Color(0.24, 0.20, 0.30, 0.85))
	# Subsolo: aparece quando a laje da rua rompe.
	draw_rect(Rect2(-400, 52 * C.CELL, w + 800, C.WORLD_H), Color(0.14, 0.12, 0.16))
	for r in ROOMS:
		var rect := Rect2(r[0] * C.CELL, r[1] * C.CELL, (r[2] - r[0] + 1) * C.CELL, (r[3] - r[1] + 1) * C.CELL)
		var t := lib.texture("bg/mod_interior_%s.png" % r[5])
		if t != null:
			# Recorta a imagem na proporção da sala (sem distorcer), ancorada embaixo.
			var tw := float(t.get_width())
			var th := float(t.get_height())
			var sh := minf(th, tw * rect.size.y / rect.size.x)
			draw_texture_rect_region(t, rect, Rect2(0, th - sh, tw, sh))
			draw_rect(rect, Color(0.1, 0.06, 0.1, 0.18))   # leve escurecimento: interior atrás do plano de jogo
		else:
			draw_rect(rect, r[4])
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color(1.0, 0.78, 0.45, 0.6))
