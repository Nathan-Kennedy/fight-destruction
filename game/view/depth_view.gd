extends Node2D
## Profundidade "2.5D" no cenário (só visual; pedido do dono): chão com parallax em perspectiva na
## calçada e interiores com parede de fundo e piso em camadas. Entra como filho da world_view ANTES do
## sprite da grade (main.gd), então fachadas e paredes da grade cobrem tudo que está atrás delas.
##
## Interiores: a parede de fundo rola BACK_K mais devagar que a câmera (parece mais funda); o piso do
## cômodo é cortado em FLOOR_STRIPS faixas horizontais cujo parallax vai de BACK_K (fundo do piso) a 0
## (frente, onde os lutadores pisam) — é o truque clássico de chão em perspectiva dos jogos de luta 2D.

const C = preload("res://sim/sim_const.gd")
const WorldView = preload("res://view/world_view.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const FloorShader = preload("res://view/depth_floor.gdshader")

const BACK_K := 0.12          # fração do deslocamento da câmera que a parede de fundo "perde"
const FLOOR_FRAC := 0.24      # parte de baixo da imagem do interior que é piso
const FLOOR_STRIPS := 12
const WINDOW := 0.84          # fração da imagem mostrada (a sobra é margem para o parallax)
const STREET_Y := 52 * 8      # topo da rua (px de mundo)
const STREET_DEPTH := 30.0    # altura da faixa de calçada atrás do plano de jogo (px de mundo)
# Camadas separadas (prompts §8.6): se existirem, substituem o modo de imagem única.
# Móveis: posição por sala [x em fração da largura, profundidade k (0 = plano de jogo, 1 = fundo)],
# um por item da folha _moveis, na ordem do pipeline. Ajustável quando a arte chegar.
const MOVEIS_K_MIN := 0.3
const MOVEIS_LAYOUT := {
	"loja": [[0.15, 0.6], [0.45, 0.5], [0.75, 0.6], [0.3, 0.4], [0.62, 0.45], [0.9, 0.5], [0.05, 0.7], [0.55, 0.7]],
	"escritorio": [[0.12, 0.6], [0.35, 0.5], [0.6, 0.55], [0.85, 0.6], [0.25, 0.4], [0.5, 0.45], [0.72, 0.4], [0.95, 0.7]],
	"fundos": [[0.15, 0.6], [0.4, 0.5], [0.65, 0.55], [0.9, 0.6], [0.25, 0.4], [0.55, 0.45], [0.8, 0.4], [0.05, 0.7]],
}

var sim
var lib: SpriteLib
var enabled := true
var _street: Array = []       # nós de faixa de calçada (Node2D com shader)


func _ready() -> void:
	if lib == null:
		lib = SpriteLib.new()
	_build_street()


func _build_street() -> void:
	# Calçada fora do prédio: à esquerda da vitrine e à direita da parede dos fundos, até as bordas.
	var b0: float = 44 * C.CELL
	var b1: float = 104 * C.CELL
	var tex: Texture2D = lib.texture("mod/mod_textura_rua.png")
	if tex == null:
		tex = lib.texture("mod/mod_textura_concreto.png")
	for seg in [[-400.0, b0], [b1, C.WORLD_W + 400.0]]:
		var r := Rect2(seg[0], STREET_Y - STREET_DEPTH, seg[1] - seg[0], STREET_DEPTH)
		var s := Sprite2D.new()
		# Textura branca 1×1 esticada: o shader pinta tudo.
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		s.texture = ImageTexture.create_from_image(img)
		s.centered = false
		s.position = r.position
		s.scale = r.size
		var m := ShaderMaterial.new()
		m.shader = FloorShader
		m.set_shader_parameter("rect_pos", r.position)
		m.set_shader_parameter("rect_size", r.size)
		if tex != null:
			m.set_shader_parameter("floor_tex", tex)
			m.set_shader_parameter("has_tex", 1.0)
		s.material = m
		add_child(s)
		_street.append(s)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on


func _cam_center() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size / 2.0)


func _process(_delta: float) -> void:
	if not enabled:
		return
	var cx := _cam_center().x
	for s in _street:
		(s.material as ShaderMaterial).set_shader_parameter("cam_x", cx)
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var cam := _cam_center()
	for r in WorldView.ROOMS:
		var rect := Rect2(r[0] * C.CELL, r[1] * C.CELL, (r[2] - r[0] + 1) * C.CELL, (r[3] - r[1] + 1) * C.CELL)
		if _draw_room_layers(r[5], rect, cam):
			continue
		var t: Texture2D = lib.texture("bg/mod_interior_%s.png" % r[5])
		if t == null:
			continue
		_draw_room(t, rect, cam)


func _draw_room(t: Texture2D, rect: Rect2, cam: Vector2) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	# Região da imagem na proporção da sala, ancorada embaixo (igual à world_view) ...
	var sh := minf(th, tw * rect.size.y / rect.size.x)
	var src := Rect2(0, th - sh, tw, sh)
	# ... e uma janela menor dentro dela, que desliza com a câmera.
	var win := Vector2(src.size.x * WINDOW, src.size.y * WINDOW)
	var slack := src.size - win
	var px_per_world := win.x / rect.size.x
	# Deslocamento da câmera em relação ao centro da sala, convertido para px da imagem.
	var d := (cam - rect.get_center()) * px_per_world
	var back := Vector2(clampf(d.x * BACK_K, -slack.x / 2, slack.x / 2), clampf(d.y * BACK_K * 0.5, -slack.y / 2, slack.y / 2))
	var base := src.position + slack / 2
	# Parede de fundo: tudo acima da faixa de piso, com o deslocamento cheio.
	var floor_h := rect.size.y * FLOOR_FRAC
	var wall_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - floor_h))
	var wall_src := Rect2(base + back, Vector2(win.x, win.y * (1.0 - FLOOR_FRAC)))
	draw_texture_rect_region(t, wall_rect, wall_src)
	# Piso em faixas: parallax diminui do fundo (BACK_K) para a frente (0).
	var strip_h := floor_h / FLOOR_STRIPS
	var src_strip_h := win.y * FLOOR_FRAC / FLOOR_STRIPS
	for i in FLOOR_STRIPS:
		var k: float = 1.0 - float(i) / (FLOOR_STRIPS - 1)   # 1 no fundo do piso, 0 na frente
		var off := Vector2(back.x * k, back.y * k)
		var dst := Rect2(rect.position.x, rect.position.y + rect.size.y - floor_h + i * strip_h, rect.size.x, strip_h + 0.6)
		var s := Rect2(base.x + off.x, base.y + off.y + win.y * (1.0 - FLOOR_FRAC) + i * src_strip_h, win.x, src_strip_h)
		draw_texture_rect_region(t, dst, s)
	# Leve escurecimento: interior atrás do plano de jogo (igual à world_view).
	draw_rect(rect, Color(0.1, 0.06, 0.1, 0.18))
	# Sombra de contato na junção parede/piso ajuda a ler a profundidade.
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - floor_h - 1, rect.size.x, 3), Color(0, 0, 0, 0.18))



# ---------------------------------------------------------------- camadas separadas (§8.6)

func _layer_src(t: Texture2D, rect: Rect2) -> Array:
	## [região base na proporção da sala, tamanho da janela, px da imagem por px de mundo].
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var sh := minf(th, tw * rect.size.y / rect.size.x)
	var src := Rect2(0, th - sh, tw, sh)
	var win := Vector2(src.size.x * WINDOW, src.size.y * WINDOW)
	return [src, win, win.x / rect.size.x]


func _shifted(src: Rect2, win: Vector2, d: Vector2, k: float) -> Vector2:
	var slack := src.size - win
	return src.position + slack / 2 + Vector2(clampf(d.x * k, -slack.x / 2, slack.x / 2), clampf(d.y * k * 0.5, -slack.y / 2, slack.y / 2))


func _draw_room_layers(sala: String, rect: Rect2, cam: Vector2) -> bool:
	var fundo: Texture2D = lib.texture("bg/mod_interior_%s_fundo.png" % sala)
	if fundo == null:
		return false
	# Fundo: parede inteira, parallax cheio.
	var a := _layer_src(fundo, rect)
	var d: Vector2 = (cam - rect.get_center()) * a[2]
	draw_texture_rect_region(fundo, rect, Rect2(_shifted(a[0], a[1], d, BACK_K), a[1]))
	# Piso: imagem do tamanho do quadro, transparente acima; faixas com parallax de BACK_K (topo) a 0.
	var piso: Texture2D = lib.texture("bg/mod_interior_%s_piso.png" % sala)
	if piso != null:
		var b := _layer_src(piso, rect)
		var dp: Vector2 = (cam - rect.get_center()) * b[2]
		var n := FLOOR_STRIPS * 3
		for i in n:
			var k: float = BACK_K * (1.0 - float(i) / (n - 1))
			var pos := _shifted(b[0], b[1], dp, k)
			var sy: float = b[1].y / n
			draw_texture_rect_region(piso, Rect2(rect.position.x, rect.position.y + i * rect.size.y / n, rect.size.x, rect.size.y / n + 0.6),
				Rect2(pos.x, pos.y + i * sy, b[1].x, sy))
	# Móveis: cada item da folha na sua profundidade (quanto mais fundo, mais lento).
	var moveis := lib.strip("bg/mod_interior_%s_moveis" % sala)
	if not moveis.is_empty():
		var layout: Array = MOVEIS_LAYOUT.get(sala, [])
		var floor_y := rect.end.y
		for idx in mini(moveis.frames, layout.size()):
			var fx: float = layout[idx][0]
			var kz: float = layout[idx][1]
			var k: float = BACK_K * kz
			var sc: float = moveis.scale * lerpf(1.0, 0.8, kz)   # mais fundo = um pouco menor
			var size := Vector2(moveis.w, moveis.h) * sc
			var base_x: float = rect.position.x + rect.size.x * fx
			var par: float = (cam.x - base_x) * k
			var feet := Vector2(base_x + par, floor_y - rect.size.y * FLOOR_FRAC * kz)
			draw_texture_rect_region(moveis.tex, Rect2(feet - moveis.pivot * sc, size), SpriteLib.frame_rect(moveis, idx),
				Color(1, 1, 1).darkened(0.25 * kz))
	# Frente: objetos no plano de jogo, sem parallax.
	var frente: Texture2D = lib.texture("bg/mod_interior_%s_frente.png" % sala)
	if frente != null:
		var c := _layer_src(frente, rect)
		draw_texture_rect_region(frente, rect, Rect2(c[0].position + (c[0].size - c[1]) / 2, c[1]))
	draw_rect(rect, Color(0.1, 0.06, 0.1, 0.14))
	return true
