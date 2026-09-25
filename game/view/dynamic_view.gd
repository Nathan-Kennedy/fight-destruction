extends Node2D
## Desenha o que se move fora da grade estática: ilhas em aviso (rachadura piscando) e caindo
## (§4.2–4.3) e os objetos arremessáveis. Só lê o estado da simulação.

const C = preload("res://sim/sim_const.gd")
const WorldView = preload("res://view/world_view.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const Props = preload("res://sim/props.gd")
const PROP_NAMES := ["caixa", "barril", "maquina"]

# Por tipo de objeto (props.gd KINDS): caixa, barril, maquina.
const PROP_COLORS := [Color(0.80, 0.58, 0.30), Color(0.30, 0.55, 0.45), Color(0.85, 0.30, 0.35)]
const OUTLINE := Color(0.08, 0.06, 0.1)

var sim
var lib: SpriteLib


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_islands()
	_draw_props()


func _draw_islands() -> void:
	var cs := float(C.CELL)
	for isl in sim.structure.islands:
		if isl.state == 0:
			# Aviso: brilho quente sempre visível, pulsando mais rápido perto da queda, e tremor leve.
			var speed: float = 0.25 + isl.t * 0.02
			var pulse: float = 0.5 + 0.5 * sin(sim.tick * speed)
			var jitter := Vector2(float((sim.tick * 7) % 3 - 1), 0.0)
			for c in sim.structure.cells_of(isl):
				var r := Rect2(Vector2(c[0], c[1]) / C.SUB + jitter, Vector2(cs, cs))
				draw_rect(r, Color(1.0, 0.5, 0.15, 0.22 + 0.3 * pulse))
		else:
			for c in sim.structure.cells_of(isl):
				var cell_pos := Vector2(c[0], c[1]) / C.SUB
				var tex: Texture2D = _mat_tex(c[2]) if lib != null else null
				if tex != null:
					# Mesma textura da grade, amostrada pela posição ORIGINAL da célula (não desliza ao cair).
					var orig := Vector2(c[0], c[1] - isl.dy) / C.SUB
					var tp: float = tex.get_width() / 64.0
					var src := Rect2(Vector2(fposmod(orig.x, 64.0), fposmod(orig.y, 64.0)) * tp, Vector2(cs, cs) * tp)
					draw_texture_rect_region(tex, Rect2(cell_pos, Vector2(cs, cs)), src)
				else:
					var col: Color = WorldView.MAT_COLOR[c[2]]
					col.a = maxf(col.a, 0.85)
					draw_rect(Rect2(cell_pos, Vector2(cs, cs)), col)


func _draw_props() -> void:
	for p in sim.props.props:
		if p.state == 3 or p.kind >= PROP_NAMES.size():   # botijão e extintor: fixtures_view.gd
			continue
		var b: Array = sim.props.box_of(p)
		var r := Rect2(Vector2(b[0], b[1]) / C.SUB, Vector2(b[2] - b[0], b[3] - b[1]) / C.SUB)
		if lib != null and _draw_prop_sprite(p, r):
			continue
		var col: Color = PROP_COLORS[p.kind]
		if p.state == 2 and (sim.tick / 2) % 2 == 0:
			col = col.lightened(0.3)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, col)
		# Faixa horizontal para ler como objeto e não como matéria da grade.
		draw_rect(Rect2(r.position + Vector2(2, r.size.y * 0.35), Vector2(r.size.x - 4, 2)), col.darkened(0.35))



func _draw_prop_sprite(p: Dictionary, r: Rect2) -> bool:
	## Frame = estado de dano pelo HP (intacto → quebrado). Base e centro alinhados à caixa da simulação.
	var a := lib.strip("prop/prop_" + PROP_NAMES[p.kind])
	if a.is_empty():
		return false
	var max_hp: int = Props.KINDS[p.kind].hp
	var dmg: float = 1.0 - clampf(float(p.hp) / max_hp, 0.0, 1.0)
	var k: int = clampi(int(dmg * (a.frames - 1) + 0.5), 0, a.frames - 2)   # último frame = despedaçado
	var sc: float = a.scale
	var size: Vector2 = Vector2(a.w, a.h) * sc
	var feet := Vector2(r.get_center().x, r.end.y)
	var tint := Color(1.4, 1.4, 1.4) if p.state == 2 and (sim.tick / 2) % 2 == 0 else Color.WHITE
	draw_texture_rect_region(a.tex, Rect2(feet - a.pivot * sc, size), Rect2(k * a.w, 0, a.w, a.h), tint)
	return true



func _mat_tex(m: int) -> Texture2D:
	if m <= 0 or m >= WorldView.MAT_TEX.size():
		return null
	return lib.texture("mod/mod_textura_%s.png" % WorldView.MAT_TEX[m])
