extends Node2D
## Céu e skyline em camadas com parallax (§4.5: fundo distante sem colisão). Usa Parallax2D, que
## segue a Camera2D atual. Sem os assets do lote 02, não cria nada e a world_view desenha a reserva.

const C = preload("res://sim/sim_const.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")

# [arquivo, fator de rolagem, largura em mundo, base (y do pé da camada), camada z]
const LAYERS := [
	["bg/bg_ceu.png", 0.05, 1500.0, 470.0],
	["bg/bg_skyline_far.png", 0.2, 900.0, 400.0],
	["bg/bg_skyline_mid.png", 0.45, 760.0, 424.0],
]

var lib: SpriteLib
var built := false


func build() -> bool:
	if lib == null:
		lib = SpriteLib.new()
	for l in LAYERS:
		var t := lib.texture(l[0])
		if t == null:
			continue
		var par := Parallax2D.new()
		par.scroll_scale = Vector2(l[1], l[1] * 0.5)
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		var k: float = l[2] / t.get_width()
		s.scale = Vector2(k, k)
		var h: float = t.get_height() * k
		s.position = Vector2(C.WORLD_W / 2.0 - l[2] / 2.0, l[3] - h)
		# Legibilidade (§9.6): fundo mais escuro e menos saturado que os lutadores; mais longe = mais névoa.
		var dim: float = 0.5 + 0.25 * (1.0 - l[1])
		s.modulate = Color(dim, dim * 0.97, dim * 1.02) if l[1] > 0.1 else Color.WHITE
		par.repeat_size = Vector2(l[2], 0)
		par.repeat_times = 3
		par.add_child(s)
		add_child(par)
		built = true
	return built
