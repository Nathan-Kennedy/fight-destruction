extends CanvasLayer
## HUD de partida, todo desenhado em código (sem imagem gerada), seguindo os conceitos aprovados
## `art/concept/lote01/ui_tela_gameplay_hud.png` e `ui_prancha_hud.png`: um painel arredondado e
## brilhante por jogador na base da tela (retrato, nome, P1/P2/CPU, stocks, % grande que esquenta e
## treme, anel de recarga da explosão, barra de escudo), banners GO!/GAME!, callout de KO, ajuda e
## debug (F1). Só lê o estado da simulação e os eventos; nunca escreve nela.
## Coordenadas em unidades do viewport base (640×360); o stretch `canvas_items` escala para
## 1280×720/1920×1080, e as fontes MSDF continuam nítidas em qualquer escala.

const C = preload("res://sim/sim_const.gd")
const FighterView = preload("res://view/fighter_view.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")

const NAMES := {"faisca": "FAÍSCA", "brasa": "BRASA", "bloco": "BLOCO"}
## Recorte do retrato na âncora (folha de personagem), em fração da imagem: Rect2(x, y, w, h).
## Ausente → heurística (topo da figura mais alta). Ajuste aqui se a âncora mudar.
const PORTRAIT_CROP := {
	"faisca": Rect2(0.815, 0.0, 0.185, 0.36),
	"brasa": Rect2(0.76, 0.0, 0.24, 0.44),
	"bloco": Rect2(0.02, 0.62, 0.30, 0.38),
}
const PORTRAIT_PX := 128
const PANEL_SIZE := Vector2(222, 54)
const MARGIN := Vector2(14, 8)
const INK := Color(0.05, 0.035, 0.07)
const SKEW := -0.21   # itálico do texto grande (cisalhamento)
## Faixas do %: branco → amarelo → laranja → vermelho → vermelho escuro (prancha de UI).
const PCT_STOPS := [[0, Color(1, 1, 1)], [60, Color(1.0, 0.86, 0.22)], [120, Color(1.0, 0.52, 0.12)],
	[180, Color(0.97, 0.16, 0.14)], [260, Color(0.72, 0.04, 0.1)]]

var sim
var cpu := [false, false]
var flip_p2_portrait := false

var _root: Control
var _panels := []        # Control por jogador (âncora na base, esquerda/direita)
var _fx: Control         # banners e callouts, tela toda
var _help: PanelContainer
var _help_label: Label
var _debug: PanelContainer
var _debug_label: Label
var _font_big: Font      # display: negrito pesado, itálico, MSDF
var _font_ui: Font       # texto pequeno (nome, chip)
var _portraits := {}     # "char:i" → [ImageTexture colorida, ImageTexture apagada] ou []

var _time := 0.0
var _last_tick := -1
var _last_pct := [0, 0]
var _last_stocks := [C.STOCKS, C.STOCKS]
var _pop := [0.0, 0.0]
var _lost_t := [[], []]  # por jogador: tempo desde a perda de cada stock (índice = stock perdido)
var _shield_a := [0.0, 0.0]
var _ready_t := [99.0, 99.0]
var _go_t := -1.0
var _game_t := -1.0
var _callouts := []      # [jogador, texto, idade]
var _buried := {}        # jogador → tick em que foi soterrado
var _message := ""       # mensagem central pequena (fim do replay)


func _ready() -> void:
	layer = 10   # acima do pós-processo (vfx_director usa 5)
	_font_big = _make_font(["Arial Black", "Segoe UI Black", "Impact", "Arial"], 900)
	_font_ui = _make_font(["Segoe UI Black", "Arial Black", "Arial"], 800)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in 2:
		var p := Control.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var left := i == 0
		p.anchor_left = 0.0 if left else 1.0
		p.anchor_right = p.anchor_left
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.offset_left = MARGIN.x if left else -MARGIN.x - PANEL_SIZE.x
		p.offset_right = p.offset_left + PANEL_SIZE.x
		p.offset_top = -MARGIN.y - PANEL_SIZE.y
		p.offset_bottom = -MARGIN.y
		p.draw.connect(_draw_panel.bind(p, i))
		_root.add_child(p)
		_panels.append(p)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)
	_help = _make_box(9)
	_help_label = _help.get_child(0)
	_help_label.text = ("J1  WASD · Espaço pula · F leve · G forte · H agarra/arremessa · J explosão · Shift escudo (+direção esquiva)\n"
		+ "J2  setas · Num0 pula · Num1 leve · Num2 forte · Num3 agarra · Num4 explosão · NumEnter escudo\n"
		+ "       sem numpad: Ins/Del/End/PgDn/PgUp/Home\n"
		+ "Gamepad  A pula · X leve · B forte · Y explosão · RB agarra · LB/gatilho escudo\n"
		+ "F1 debug · F2 CPU no J2 · F3 hitboxes · F5 salva replay · F6 flashes · F7 luzes · F8 ambiente · R reinicia · F11 tela cheia · Esc sai")
	_debug = _make_box(8)
	_debug_label = _debug.get_child(0)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	_debug_label.add_theme_font_override("font", mono)
	_debug.visible = false


func _make_font(names: Array, weight: int) -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.font_weight = weight
	sf.multichannel_signed_distance_field = true
	sf.msdf_pixel_range = 24   # comporta contorno de até ~12 px na fonte de referência
	sf.msdf_size = 64
	sf.font_italic = false   # o itálico vem do cisalhamento em _xf (vale para qualquer fonte do sistema)
	return sf


func _make_box(font_size: int) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.06, 0.72)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(5)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(6, 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = Color(0.92, 0.92, 0.96)
	ls.outline_size = 0
	ls.line_spacing = 1
	l.label_settings = ls
	box.add_child(l)
	_root.add_child(box)
	return box


# ---------------------------------------------------------------- API usada pelo main.gd

func reset() -> void:
	## Nova partida: zera animações e dispara o GO!.
	_last_tick = -1
	_message = ""


func on_event(e: Dictionary) -> void:
	match e.kind:
		"buried":
			_buried[e.emitter] = e.tick
		"ko":
			var who: int = e.emitter
			var txt := "SOTERRADO!" if int(_buried.get(who, -99)) == int(e.tick) else "KO!"
			_callouts.append([who, txt, 0.0])
		"match_end":
			_game_t = 0.0


func update_hud(delta: float, cpu_flags: Array, show_help: bool, debug_text: String, message: String) -> void:
	cpu = cpu_flags
	_message = message
	if _last_tick < 0 or sim.tick < _last_tick:
		_start_match()
	_last_tick = sim.tick
	_time += delta
	if _go_t >= 0.0:
		_go_t += delta
	if sim.winner >= 0 and _game_t < 0.0:
		_game_t = 0.0
	if _game_t >= 0.0:
		_game_t += delta
	for c in _callouts:
		c[2] += delta
	_callouts = _callouts.filter(func(c): return c[2] < 1.6)
	for i in 2:
		var f: Dictionary = sim.fighters[i]
		var dp: int = f.pct - _last_pct[i]
		if dp > 0:
			_pop[i] = minf(1.0, _pop[i] + 0.45 + dp / 25.0)
		_last_pct[i] = f.pct
		_pop[i] *= exp(-9.0 * delta)
		while _last_stocks[i] > f.stocks:
			_last_stocks[i] -= 1
			_lost_t[i].append(0.0)
		for k in _lost_t[i].size():
			_lost_t[i][k] += delta
		var want: float = 1.0 if f.shielding else 0.0
		_shield_a[i] = move_toward(_shield_a[i], want, delta * (8.0 if want > 0 else 3.0))
		if f.burst_cd == 0:
			_ready_t[i] += delta
		else:
			_ready_t[i] = 0.0
		_panels[i].queue_redraw()
	_help.visible = show_help
	_debug.visible = debug_text != ""
	if _debug.visible:
		_debug_label.text = debug_text
	_fx.queue_redraw()


func _start_match() -> void:
	_go_t = 0.0
	_game_t = -1.0
	_callouts.clear()
	_buried.clear()
	for i in 2:
		var f: Dictionary = sim.fighters[i]
		_last_pct[i] = f.pct
		_last_stocks[i] = f.stocks
		_lost_t[i] = []
		for k in C.STOCKS - f.stocks:
			_lost_t[i].append(9.0)
		_pop[i] = 0.0
		_ready_t[i] = 9.0
		_shield_a[i] = 0.0


# ---------------------------------------------------------------- painel do jogador

func _draw_panel(p: Control, i: int) -> void:
	var f: Dictionary = sim.fighters[i]
	var col: Color = FighterView.COLORS[i]
	var out: bool = f.stocks <= 0
	var char_name: String = SpriteLib.CHAR_OF.get(f.def, f.def)
	# Pílula: fundo escuro, borda na cor do jogador, brilho externo.
	var pill := Rect2(10, 10, PANEL_SIZE.x - 10, PANEL_SIZE.y - 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.07, 0.1, 0.9)
	sb.set_corner_radius_all(int(pill.size.y / 2))
	sb.border_color = col if not out else Color(0.4, 0.4, 0.45)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(col, 0.0 if out else 0.45)
	sb.shadow_size = 7
	sb.anti_aliasing_size = 0.8
	p.draw_style_box(sb, pill)
	# Brilho interno e reflexo na metade de cima.
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.045)
	gloss.corner_radius_top_left = int(pill.size.y / 2) - 3
	gloss.corner_radius_top_right = gloss.corner_radius_top_left
	gloss.corner_radius_bottom_left = 4
	gloss.corner_radius_bottom_right = 4
	p.draw_style_box(gloss, Rect2(pill.position + Vector2(20, 3), Vector2(pill.size.x - 26, pill.size.y * 0.42)))
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.border_color = Color(col.lerp(Color.WHITE, 0.5), 0.35 if not out else 0.1)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(int(pill.size.y / 2) - 3)
	p.draw_style_box(inner, pill.grow(-3))

	# Retrato circular à esquerda, saltando um pouco para fora da pílula.
	var pc := Vector2(29, 31)
	var pr := 23.0
	p.draw_circle(pc + Vector2(0, 1.5), pr + 3.5, Color(0, 0, 0, 0.45))
	p.draw_circle(pc, pr + 3.0, INK)
	var tex := _portrait(char_name, i)
	if tex.is_empty():
		_draw_silhouette(p, pc, pr, col)
	else:
		p.draw_texture_rect(tex[1] if out else tex[0], Rect2(pc - Vector2(pr, pr), Vector2(pr, pr) * 2), false)
	p.draw_arc(pc, pr + 1.2, 0, TAU, 48, col if not out else Color(0.45, 0.45, 0.5), 2.4, true)

	# Chip P1/P2/CPU + nome.
	var tag := "CPU" if cpu[i] else "P%d" % (i + 1)
	var chip := Rect2(58, 14, 8 + tag.length() * 6.5, 11)
	var csb := StyleBoxFlat.new()
	csb.bg_color = col
	csb.set_corner_radius_all(3)
	csb.skew = Vector2(0.25, 0)
	p.draw_style_box(csb, chip)
	p.draw_string(_font_ui, chip.position + Vector2(4, 9), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
	var nm: String = NAMES.get(char_name, char_name.to_upper())
	p.draw_string_outline(_font_ui, Vector2(chip.end.x + 4, 23.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, INK)
	p.draw_string(_font_ui, Vector2(chip.end.x + 4, 23.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.93, 0.92, 0.96))

	# Stocks: mini retratos; o perdido estoura e fica apagado.
	for k in C.STOCKS:
		var sc := Vector2(63 + k * 13.5, 38.5)
		var alive: bool = k < f.stocks
		if alive:
			p.draw_circle(sc, 6.8, INK)
			if tex.is_empty():
				p.draw_circle(sc, 5.4, col)
			else:
				p.draw_texture_rect(tex[0], Rect2(sc - Vector2(5.6, 5.6), Vector2(11.2, 11.2)), false)
			p.draw_arc(sc, 5.8, 0, TAU, 24, col, 1.2, true)
		else:
			var order := C.STOCKS - 1 - k   # perde da direita para a esquerda
			var t: float = _lost_t[i][order] if order < _lost_t[i].size() else 9.0
			p.draw_circle(sc, 6.4, Color(0.02, 0.02, 0.03, 0.8))
			if not tex.is_empty():
				p.draw_texture_rect(tex[1], Rect2(sc - Vector2(5.4, 5.4), Vector2(10.8, 10.8)), false, Color(1, 1, 1, 0.4))
			p.draw_arc(sc, 5.8, 0, TAU, 24, Color(0.35, 0.35, 0.4), 1.0, true)
			if t < 0.55:
				var k2 := t / 0.55
				p.draw_circle(sc, 5.0 * (1.0 + k2 * 0.8), Color(col.lerp(Color.WHITE, 0.6), 0.9 * (1.0 - k2)))
				p.draw_arc(sc, 5.0 + k2 * 11.0, 0, TAU, 24, Color(col, 1.0 - k2), 2.0 * (1.0 - k2) + 0.5, true)

	# Anel de recarga da explosão.
	_draw_burst_ring(p, Vector2(PANEL_SIZE.x - 21, 31), f, col if not out else Color(0.4, 0.4, 0.45), i)

	# % grande.
	if out:
		_draw_big(p, Vector2(PANEL_SIZE.x - 47, 46), "FORA", 18, Color(0.5, 0.5, 0.56), 1.0, Vector2.ZERO, true)
	else:
		var pc_col := _pct_color(f.pct).lerp(Color.WHITE, _pop[i] * 0.55)
		var shake := Vector2.ZERO
		if f.pct > 120:
			var amp: float = clampf((f.pct - 120) / 70.0, 0.0, 1.0) * 1.8 + _pop[i] * 1.5
			shake = Vector2(sin(_time * 71.0 + i * 3.0), cos(_time * 53.0 + i)) * amp
		_draw_pct(p, Vector2(PANEL_SIZE.x - 47, 47.5), f.pct, pc_col, 1.0 + 0.24 * _pop[i], shake)

	# Barra de escudo (só enquanto segura escudo; some suave).
	if _shield_a[i] > 0.01:
		var a: float = _shield_a[i]
		var frac: float = clampf(float(f.shield) / C.SHIELD_MAX, 0.0, 1.0)
		var bar := Rect2(60, 1, 90, 6)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.03, 0.03, 0.05, 0.85 * a)
		bsb.set_corner_radius_all(3)
		bsb.border_color = Color(0.6, 0.85, 1.0, 0.5 * a)
		bsb.set_border_width_all(1)
		p.draw_style_box(bsb, bar.grow(1))
		var fc := Color(1.0, 0.25, 0.2).lerp(Color(1.0, 0.85, 0.3), frac * 2.0) if frac < 0.5 else Color(1.0, 0.85, 0.3).lerp(Color(0.4, 0.85, 1.0), frac * 2.0 - 1.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(fc, a)
		fill.set_corner_radius_all(2)
		if frac > 0.02:
			p.draw_style_box(fill, Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * frac, bar.size.y - 2)))
		_draw_shield_icon(p, Vector2(54, 4), fc, a)


func _draw_pct(p: CanvasItem, anchor: Vector2, pct: int, col: Color, scale: float, shake: Vector2) -> void:
	## Número à direita-alinhado em `anchor` (linha de base), "%" menor colado.
	var num := str(pct)
	var ns := 30
	var ps := 16
	var wn := _font_big.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	var wp := _font_big.get_string_size("%", HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
	var total := wn + wp
	var origin := anchor + shake
	# Escala a partir do centro do número.
	var pivot := origin + Vector2(-total * 0.5 + wp * 0.5, -9)
	_xf(p, pivot, scale)
	var base := origin - pivot
	_big_layers(p, base + Vector2(-total, 0), num, ns, col, 8)
	_big_layers(p, base + Vector2(-wp, 0), "%", ps, col, 5)
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_big(p: CanvasItem, anchor: Vector2, text: String, size: int, col: Color, scale: float, shake: Vector2, right := false) -> void:
	var w := _font_big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := anchor + shake - Vector2(w if right else w * 0.5, 0)
	_xf(p, anchor, scale)
	_big_layers(p, pos - anchor, text, size, col, maxi(4, size / 4))
	p.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _xf(p: CanvasItem, pos: Vector2, scale: float, rot := 0.0) -> void:
	p.draw_set_transform_matrix(Transform2D(rot, Vector2(scale, scale), SKEW, pos))


func _big_layers(p: CanvasItem, pos: Vector2, text: String, size: int, col: Color, outline: int) -> void:
	## Contorno pesado + sombra + "extrusão" escura + fio de luz no topo (lê como gradiente).
	var f := _font_big
	var drop := Vector2(1.0, 2.0) * size / 25.0
	p.draw_string_outline(f, pos + drop, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline + 2, Color(0, 0, 0, 0.55))
	p.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	var dark := col.darkened(0.45)
	dark.s = minf(1.0, dark.s * 1.15)
	p.draw_string(f, pos + Vector2(0.6, 1.4) * size / 25.0, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, dark)
	p.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	# Fio de luz: o próprio texto clareado, deslocado 0.5 px para cima e atrás do principal não dá
	# gradiente real; aqui fica só um toque de brilho no topo.
	p.draw_string(f, pos + Vector2(0, -0.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.lerp(Color.WHITE, 0.55), 0.35))


func _pct_color(pct: int) -> Color:
	for k in range(1, PCT_STOPS.size()):
		if pct <= PCT_STOPS[k][0]:
			var a: Array = PCT_STOPS[k - 1]
			var b: Array = PCT_STOPS[k]
			return (a[1] as Color).lerp(b[1], float(pct - a[0]) / float(b[0] - a[0]))
	return PCT_STOPS[-1][1]


func _draw_burst_ring(p: Control, c: Vector2, f: Dictionary, col: Color, i: int) -> void:
	var r := 13.5
	var w := 4.0
	var ready: bool = f.burst_cd == 0 and f.stocks > 0
	var k: float = 1.0 - clampf(float(f.burst_cd) / C.BURST_COOLDOWN, 0.0, 1.0)
	var glow := col.lerp(Color.WHITE, 0.25)
	if ready:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0 + i)
		var flash := clampf(1.0 - _ready_t[i] / 0.35, 0.0, 1.0)   # clarão ao ficar pronto
		p.draw_circle(c, r + 5.0 + pulse * 2.0 + flash * 6.0, Color(col, 0.16 + 0.1 * pulse + 0.4 * flash))
		p.draw_circle(c, r + 2.5, Color(col, 0.25))
	p.draw_circle(c, r + w * 0.5 + 1.5, INK)
	p.draw_arc(c, r, 0, TAU, 48, Color(0.22, 0.22, 0.27), w, true)
	if k > 0.001:
		var start := -PI / 2
		p.draw_arc(c, r, start, start + TAU * k, maxi(4, int(48 * k)), glow if ready else col.darkened(0.1), w, true)
	# Quatro cortes, como no conceito.
	for s in 4:
		var ang := -PI / 2 + s * PI / 2 + PI / 4
		var d := Vector2(cos(ang), sin(ang))
		p.draw_line(c + d * (r - w * 0.7), c + d * (r + w * 0.7), INK, 1.6, true)
	p.draw_circle(c, r - w * 0.5 - 0.5, Color(0.06, 0.06, 0.09))
	# Ícone da explosão: estrela de 8 pontas; gira devagar quando pronta.
	var rot := _time * 1.5 if ready else 0.0
	var pts := PackedVector2Array()
	for s in 16:
		var ang := rot + s * TAU / 16
		var rr := 7.0 if s % 2 == 0 else 3.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	p.draw_colored_polygon(pts, Color.WHITE if ready else Color(0.42, 0.42, 0.48))
	p.draw_circle(c, 2.2, col if ready else Color(0.3, 0.3, 0.35))
	if ready:
		for s in 6:
			var ang := _time * 0.8 + s * TAU / 6
			var d := Vector2(cos(ang), sin(ang))
			p.draw_line(c + d * (r + 4), c + d * (r + 7.5), Color(glow, 0.8), 1.2, true)


func _draw_shield_icon(p: Control, c: Vector2, col: Color, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-4, -3.5), c + Vector2(0, -5), c + Vector2(4, -3.5),
		c + Vector2(3.5, 1.5), c + Vector2(0, 5), c + Vector2(-3.5, 1.5)])
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(c + (q - c) * 1.35)
	p.draw_colored_polygon(outline, Color(INK, a))
	p.draw_colored_polygon(pts, Color(col, a))


func _draw_silhouette(p: Control, c: Vector2, r: float, col: Color) -> void:
	p.draw_circle(c, r, col.darkened(0.6))
	p.draw_circle(c + Vector2(0, -r * 0.2), r * 0.36, col.darkened(0.2))
	var pts := PackedVector2Array()
	for s in 13:
		var ang := PI + s * PI / 12
		pts.append(c + Vector2(0, r * 0.85) + Vector2(cos(ang) * r * 0.65, sin(ang) * r * 0.55))
	p.draw_colored_polygon(pts, col.darkened(0.2))


# ---------------------------------------------------------------- retratos

func _portrait(char_name: String, i: int) -> Array:
	var key := "%s:%d" % [char_name, i]
	if _portraits.has(key):
		return _portraits[key]
	var res := []
	var path := "res://assets/chr/%s/anchor.png" % char_name
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			var crop := _crop_rect(img, char_name)
			var sub := img.get_region(crop)
			sub.resize(PORTRAIT_PX, PORTRAIT_PX, Image.INTERPOLATE_LANCZOS)
			if i == 1 and flip_p2_portrait:
				sub.flip_x()
			res = [ImageTexture.create_from_image(_disc(sub, FighterView.COLORS[i], false)),
				ImageTexture.create_from_image(_disc(sub, FighterView.COLORS[i], true))]
	_portraits[key] = res
	return res


func _crop_rect(img: Image, char_name: String) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var r: Rect2
	if PORTRAIT_CROP.has(char_name):
		var n: Rect2 = PORTRAIT_CROP[char_name]
		r = Rect2(n.position * Vector2(w, h), n.size * Vector2(w, h))
	else:
		r = _heuristic_head(img)
	# Quadrado centrado no recorte, preso à imagem.
	var side := minf(maxf(r.size.x, r.size.y), minf(w, h))
	var ctr := r.get_center()
	var pos := Vector2(clampf(ctr.x - side / 2, 0, w - side), clampf(ctr.y - side / 2, 0, h - side))
	return Rect2i(Vector2i(pos), Vector2i(int(side), int(side)))


func _heuristic_head(img: Image) -> Rect2:
	## Sem configuração: acha a figura (faixa de colunas opacas) mais alta e recorta o topo dela.
	var small := img.duplicate() as Image
	var sw := 160
	var sh := maxi(1, int(img.get_height() * sw / float(img.get_width())))
	small.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var tops := []
	var bots := []
	for x in sw:
		var t := -1
		var b := -1
		for y in sh:
			if small.get_pixel(x, y).a > 0.5:
				if t < 0:
					t = y
				b = y
		tops.append(t)
		bots.append(b)
	var best := [0, 0, 0]   # [x0, x1, altura]
	var x := 0
	while x < sw:
		if tops[x] < 0:
			x += 1
			continue
		var x0 := x
		var t0 := sh
		var b0 := 0
		while x < sw and tops[x] >= 0:
			t0 = mini(t0, tops[x])
			b0 = maxi(b0, bots[x])
			x += 1
		if b0 - t0 > best[2]:
			best = [x0, x - 1, b0 - t0]
	if best[2] == 0:
		return Rect2(0, 0, img.get_width(), img.get_height())
	var top := sh
	for cx in range(best[0], best[1] + 1):
		top = mini(top, tops[cx])
	var head_x := 0.0
	var n := 0
	for cx in range(best[0], best[1] + 1):
		if tops[cx] >= 0 and tops[cx] <= top + best[2] * 0.06:
			head_x += cx
			n += 1
	head_x /= maxi(1, n)
	var side: float = best[2] * 0.26
	var s := img.get_width() / float(sw)
	return Rect2((head_x - side / 2) * s, top * s, side * s, side * s)


func _disc(src: Image, col: Color, grey: bool) -> Image:
	## Compõe o retrato sobre um fundo radial na cor do jogador e recorta em círculo (borda suave).
	var n := src.get_width()
	var out := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr := Vector2(n, n) * 0.5
	var rad := n * 0.5
	var bg_in := col.darkened(0.25)
	var bg_out := col.darkened(0.8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(ctr)
			var m := clampf(rad - d, 0.0, 1.0)
			if m <= 0.0:
				continue
			var t := clampf(Vector2(x + 0.5, y + 0.5).distance_to(ctr + Vector2(-n * 0.15, -n * 0.2)) / (rad * 1.5), 0.0, 1.0)
			var bg := bg_in.lerp(bg_out, t)
			var s := src.get_pixel(x, y)
			var c := bg.lerp(Color(s.r, s.g, s.b), s.a)
			# Faixas diagonais de velocidade no fundo, como na prancha.
			if s.a < 0.5 and int((x + y * 0.6) / (n / 9.0)) % 3 == 0:
				c = c.lerp(col, 0.18)
			if grey:
				var l := c.get_luminance() * 0.55
				c = Color(l, l, l * 1.05)
			c.a = m
			out.set_pixel(x, y, c)
	return out


# ---------------------------------------------------------------- banners e callouts

func _draw_fx() -> void:
	var sz := _fx.size
	if _go_t >= 0.0 and _go_t < 0.95:
		_draw_banner(sz * Vector2(0.5, 0.3), "GO!", _go_t, 0.95, 64,
			Color(1.0, 0.8, 0.2), [Color(1.0, 0.35, 0.1), Color(1.0, 0.72, 0.15), Color(1.0, 0.95, 0.55)], true)
	if _game_t >= 0.0:
		_draw_banner(sz * Vector2(0.5, 0.42), "GAME!", _game_t, -1.0, 60,
			Color(0.85, 0.94, 1.0), [Color(0.15, 0.35, 1.0), Color(0.3, 0.75, 1.0), Color(0.85, 0.95, 1.0)], false)
		if _game_t > 1.1 and sim.winner >= 0:
			var a := clampf((_game_t - 1.1) / 0.3, 0.0, 1.0)
			var wc: Color = FighterView.COLORS[sim.winner]
			var wdef: String = sim.fighters[sim.winner].def
			var wname: String = NAMES.get(SpriteLib.CHAR_OF.get(wdef, wdef), wdef.to_upper())
			var txt := "%s VENCE!" % wname
			_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var pos := sz * Vector2(0.5, 0.56)
			_draw_chip_text(pos, txt, 16, Color(wc, a), a)
			_draw_small_center(pos + Vector2(0, 17), "R ou Start para jogar de novo", 8, Color(0.9, 0.9, 0.95, a))
	for c in _callouts:
		_draw_callout(c[0], c[1], c[2])
	if _message != "":
		_draw_chip_text(sz * Vector2(0.5, 0.4), _message, 14, Color(0.8, 0.85, 0.95), 1.0)


func _draw_banner(center: Vector2, text: String, t: float, life: float, size: int, fill: Color, streak_cols: Array, from_left: bool) -> void:
	# Linha do tempo: entrada 0–0.2 s (desliza + escala), segura, saída nos últimos 0.25 s.
	var enter := clampf(t / 0.2, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - enter, 3.0)
	var over := sin(clampf(t / 0.32, 0.0, 1.0) * PI) * 0.12   # overshoot
	var alpha := 1.0
	var off := Vector2.ZERO
	if from_left:
		off.x = -260.0 * (1.0 - e)
	var scale := (2.2 - 1.2 * e) + over if not from_left else 1.0 + (1.0 - e) * 0.4 + over
	if life > 0.0 and t > life - 0.25:
		var k := clampf((t - (life - 0.25)) / 0.25, 0.0, 1.0)
		alpha = 1.0 - k
		off.x += 220.0 * k * k
		scale *= 1.0 + 0.15 * k
	if not from_left:
		alpha = enter
		scale += 0.03 * sin(t * 4.0) * clampf(t - 0.4, 0.0, 1.0)
	var c := center + off
	# Faixa escura atrás + linhas de velocidade (determinísticas, animadas pelo tempo).
	var band_h := size * 0.9
	var band_w := (_fx.size.x + 80) * e
	var band := PackedVector2Array([c + Vector2(-band_w / 2 + 20, -band_h / 2), c + Vector2(band_w / 2 + 20, -band_h / 2),
		c + Vector2(band_w / 2 - 20, band_h / 2), c + Vector2(-band_w / 2 - 20, band_h / 2)])
	_fx.draw_colored_polygon(band, Color(0.02, 0.02, 0.05, 0.45 * alpha))
	for s in 22:
		var h := fposmod(sin(s * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(s * 78.233) * 12543.123, 1.0)
		var y := (h - 0.5) * size * 1.2
		var len := (60.0 + h2 * 170.0) * (0.4 + 0.6 * e)
		var speed := 400.0 + h2 * 500.0
		var x := fposmod(h * 900.0 + t * speed, 520.0) - 260.0
		var th := 1.0 + h2 * 3.5
		var sc: Color = streak_cols[s % streak_cols.size()]
		var p0 := c + Vector2(x - len * 0.5, y)
		var p1 := c + Vector2(x + len * 0.5, y)
		_fx.draw_colored_polygon(PackedVector2Array([p0 + Vector2(6, -th), p1, p0 + Vector2(-6, th)]), Color(sc, 0.75 * alpha))
	var w := _font_big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_xf(_fx, c, scale)
	var base := Vector2(-w * 0.5, size * 0.36)
	var ol := int(size * 0.16)
	_fx.draw_string_outline(_font_big, base + Vector2(3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ol + 3, Color(0, 0, 0, 0.6 * alpha))
	_fx.draw_string_outline(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ol, Color(INK, alpha))
	var ext: Color = streak_cols[0]
	_fx.draw_string(_font_big, base + Vector2(1.5, 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(ext.darkened(0.2), alpha))
	_fx.draw_string(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(fill, alpha))
	_fx.draw_string(_font_big, base + Vector2(0, -1.2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.45 * alpha))
	_fx.draw_string(_font_big, base + Vector2(0, -0.2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(fill, alpha))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_callout(who: int, text: String, t: float) -> void:
	## "KO!" curto sobre o painel de quem perdeu o stock, na cor dele.
	var col: Color = FighterView.COLORS[who]
	var panel: Control = _panels[who]
	var anchor := panel.position + Vector2(PANEL_SIZE.x * 0.55, -14)
	var pop := clampf(t / 0.12, 0.0, 1.0)
	var scale := 1.8 - 0.8 * pop + sin(clampf(t / 0.3, 0.0, 1.0) * PI) * 0.1
	var a := 1.0 - clampf((t - 1.25) / 0.35, 0.0, 1.0)
	var rise := -6.0 * clampf(t / 1.6, 0.0, 1.0)
	var c := anchor + Vector2(0, rise)
	# Raios curtos atrás.
	for s in 10:
		var ang := s * TAU / 10 + 0.3
		var d := Vector2(cos(ang) * 1.8, sin(ang))
		var r0 := 10.0 + 6.0 * pop
		_fx.draw_line(c + d * r0, c + d * (r0 + 8.0 + 10.0 * pop), Color(col, 0.7 * a * (1.0 - clampf(t / 0.6, 0.0, 1.0))), 2.0, true)
	var size := 22 if text.length() <= 3 else 17
	var w := _font_big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_xf(_fx, c, scale, -0.06)
	var base := Vector2(-w * 0.5, size * 0.36)
	_fx.draw_string_outline(_font_big, base + Vector2(1.5, 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7, Color(0, 0, 0, 0.55 * a))
	_fx.draw_string_outline(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(INK, a))
	_fx.draw_string(_font_big, base + Vector2(0.8, 1.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.darkened(0.45), a))
	_fx.draw_string(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.lerp(Color.WHITE, 0.15), a))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_chip_text(center: Vector2, text: String, size: int, col: Color, a: float) -> void:
	var w := _font_big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rect := Rect2(center - Vector2(w * 0.5 + 12, size * 0.75), Vector2(w + 24, size * 1.3))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.08, 0.85 * a)
	sb.set_corner_radius_all(int(rect.size.y / 2))
	sb.border_color = Color(col, a)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(col, 0.35 * a)
	sb.shadow_size = 6
	sb.skew = Vector2(0.2, 0)
	_fx.draw_style_box(sb, rect)
	var base := Vector2(-w * 0.5, size * 0.36)
	_xf(_fx, center, 1.0)
	_fx.draw_string_outline(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(INK, a))
	_fx.draw_string(_font_big, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col.lerp(Color.WHITE, 0.2), a))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_small_center(center: Vector2, text: String, size: int, col: Color) -> void:
	var w := _font_ui.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_fx.draw_string_outline(_font_ui, center - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(INK, col.a))
	_fx.draw_string(_font_ui, center - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
