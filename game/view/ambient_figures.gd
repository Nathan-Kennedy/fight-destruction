extends RefCounted
## Desenho vetorial dos placeholders do cenário vivo (§8.4): figurante articulado (quadril, joelho,
## ombro, cotovelo) com contorno único, cores dessaturadas e poses por ângulo. Só funções estáticas;
## quem chama passa o CanvasItem que está em _draw. Some quando existirem as folhas npc_*/amb_*.
##
## Convenção dos ângulos da pose (radianos): 0 = apontando para baixo; positivo = para a frente
## (lado para onde o figurante olha). Canela (`sh_*`) e antebraço (`la_*`) são relativos ao segmento
## de cima. `lean` inclina o tronco para a frente; `lift` levanta o corpo (pulo).

const OUTLINE := Color(0.11, 0.09, 0.14)
const OUT_W := 1.1


static func mute(c: Color, desat: float, dark: float) -> Color:
	## Tira saturação e escurece (§9.6: fundo menos saturado que os lutadores).
	var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var out := c.lerp(Color(l, l, l, c.a), desat).darkened(dark)
	out.a = c.a
	return out


static func pose(over := {}) -> Dictionary:
	var p := {"lean": 0.0, "head": 0.0, "ua_f": 0.12, "la_f": 0.2, "ua_b": -0.1, "la_b": 0.15,
		"th_f": 0.05, "sh_f": 0.0, "th_b": -0.05, "sh_b": 0.0, "lift": 0.0}
	p.merge(over, true)
	return p


static func walk(ph: float, amp := 0.45) -> Dictionary:
	var s := sin(ph)
	return pose({"th_f": s * amp, "th_b": -s * amp, "sh_f": -maxf(0.0, -cos(ph)) * amp * 1.3,
		"sh_b": -maxf(0.0, cos(ph)) * amp * 1.3, "ua_f": -s * amp * 0.8, "ua_b": s * amp * 0.8,
		"la_f": 0.35, "la_b": 0.35, "lift": absf(cos(ph)) * 0.6})


static func run(ph: float) -> Dictionary:
	var p := walk(ph, 0.85)
	p.lean = 0.28
	p.la_f = 1.5
	p.la_b = 1.5
	p.ua_f = -sin(ph) * 1.0
	p.ua_b = sin(ph) * 1.0
	p.lift = absf(cos(ph)) * 2.0
	return p


static func run_panic(ph: float) -> Dictionary:
	## Corre com as mãos na cabeça.
	var p := run(ph)
	p.lean = 0.18
	p.ua_f = 2.55
	p.la_f = 1.9
	p.ua_b = 2.35
	p.la_b = 2.0
	p.head = 0.25
	return p


static func crouch(shiver: float) -> Dictionary:
	## Encolhido, braços protegendo a cabeça.
	return pose({"lean": 0.75, "head": 0.3, "th_f": 1.45, "sh_f": -2.5, "th_b": 1.2, "sh_b": -2.45,
		"ua_f": 2.2 + shiver, "la_f": 2.1, "ua_b": 2.0 - shiver, "la_b": 2.2})


static func sit(over := {}) -> Dictionary:
	var p := pose({"th_f": 1.5, "sh_f": -1.45, "th_b": 1.45, "sh_b": -1.5, "lean": -0.08})
	p.merge(over, true)
	return p


static func _dir(a: float, face: float) -> Vector2:
	return Vector2(sin(a) * face, cos(a))


static func person(ci: CanvasItem, feet: Vector2, face: float, p: Dictionary, look: Dictionary,
		h: float, alpha := 1.0) -> Dictionary:
	## Desenha o figurante com os pés em `feet` e devolve os pontos úteis para acessórios.
	var l1 := h * 0.25
	var l2 := h * 0.25
	var tl := h * 0.30
	var ua := h * 0.17
	var la := h * 0.16
	var hr := h * 0.095
	var kf := _dir(p.th_f, face) * l1
	var ff := kf + _dir(p.th_f + p.sh_f, face) * l2
	var kb := _dir(p.th_b, face) * l1
	var fb := kb + _dir(p.th_b + p.sh_b, face) * l2
	var hip := feet - Vector2(0, maxf(ff.y, fb.y) + float(p.lift))
	var up := Vector2(sin(p.lean) * face, -cos(p.lean))
	var neck := hip + up * tl
	var sh := neck - up * h * 0.03
	var hup := Vector2(sin(p.lean + p.head) * face, -cos(p.lean + p.head))
	var head := neck + hup * hr * 1.2
	var ef := sh + _dir(p.ua_f, face) * ua
	var hf := ef + _dir(p.ua_f + p.la_f, face) * la
	var eb := sh + _dir(p.ua_b, face) * ua
	var hb := eb + _dir(p.ua_b + p.la_b, face) * la

	var skin: Color = look.get("skin", Color(0.72, 0.56, 0.46))
	var top: Color = look.get("top", Color(0.45, 0.48, 0.52))
	var bottom: Color = look.get("bottom", Color(0.3, 0.3, 0.36))
	var shoes: Color = look.get("shoes", Color(0.18, 0.16, 0.2))
	var hair: Color = look.get("hair", Color(0.2, 0.16, 0.14))
	var sleeve: Color = look.get("sleeve", top)
	var lw := h * 0.105
	var aw := h * 0.08
	var caps := []   # [a, b, largura, cor]
	var polys := []  # [PackedVector2Array, cor]
	var dots := []   # [centro, raio, cor]
	# Ordem de preenchimento = de trás para a frente.
	caps.append([sh, eb, aw, sleeve.darkened(0.2)])
	caps.append([eb, hb, aw * 0.9, skin.darkened(0.2)])
	caps.append([hip, hip + kb, lw, bottom.darkened(0.18)])
	caps.append([hip + kb, hip + fb, lw * 0.9, bottom.darkened(0.18)])
	caps.append([hip + fb, hip + fb + Vector2(face * lw * 0.6, 0), lw * 0.75, shoes])
	caps.append([hip, hip + kf, lw, bottom])
	caps.append([hip + kf, hip + ff, lw * 0.9, bottom])
	caps.append([hip + ff, hip + ff + Vector2(face * lw * 0.6, 0), lw * 0.75, shoes])
	var side := Vector2(-up.y, up.x)
	var tw := h * float(look.get("chest", 0.11))
	var hw := h * float(look.get("waist", 0.09))
	polys.append([PackedVector2Array([sh + side * tw, sh - side * tw, hip - side * hw, hip + side * hw]), top])
	if look.get("skirt", false):
		var sk := hip + Vector2(0, h * 0.16)
		polys.append([PackedVector2Array([hip + side * hw * 1.1, hip - side * hw * 1.1,
			sk - Vector2(h * 0.12, 0), sk + Vector2(h * 0.12, 0)]), bottom])
	if look.has("apron"):
		polys.append([PackedVector2Array([sh.lerp(hip, 0.3) + side * tw * 0.7, sh.lerp(hip, 0.3) - side * tw * 0.7,
			hip + Vector2(0, h * 0.12) - side * hw, hip + Vector2(0, h * 0.12) + side * hw]), look.apron])
	caps.append([neck - up * 0.5, neck + hup * hr * 0.3, h * 0.05, skin])
	# Cabelo atrás, cabeça, detalhes.
	var style: String = look.get("hair_style", "curto")
	var back := Vector2(-face, 0)
	match style:
		"longo":
			polys.append([PackedVector2Array([head + hup * hr * 1.05 + back * hr * 0.2, head + back * hr * 1.15,
				head + back * hr * 1.0 - hup * hr * 2.3, head - hup * hr * 2.1 + back * hr * 0.1]), hair])
		"rabo":
			caps.append([head + back * hr * 0.8, head + back * hr * 1.8 - hup * hr * 1.1, hr * 0.7, hair])
	dots.append([head + hup * hr * 0.18 + back * hr * 0.16, hr * 1.06, hair])
	dots.append([head + Vector2(face * hr * 0.12, hr * 0.06), hr * 0.92, skin])
	match style:
		"coque":
			dots.append([head + hup * hr * 0.9 + back * hr * 0.55, hr * 0.5, hair])
		"branco":
			dots.append([head + hup * hr * 0.75 + back * hr * 0.4, hr * 0.55, hair])
	caps.append([ef, hf, aw * 0.9, skin])
	caps.append([sh, ef, aw, sleeve])
	dots.append([hf, aw * 0.62, skin])

	# Passo 1: contorno único de toda a silhueta.
	var oc := Color(OUTLINE, OUTLINE.a * alpha)
	for c in caps:
		ci.draw_line(c[0], c[1], oc, c[2] + OUT_W * 2.0)
		ci.draw_circle(c[0], c[2] * 0.5 + OUT_W, oc)
		ci.draw_circle(c[1], c[2] * 0.5 + OUT_W, oc)
	for pl in polys:
		pl[0] = safe(pl[0])
		for off in Geometry2D.offset_polygon(pl[0], OUT_W):
			ci.draw_colored_polygon(off, oc)
	for d in dots:
		ci.draw_circle(d[0], d[1] + OUT_W, oc)
	# Passo 2: preenchimento.
	for c in caps:
		var col := Color(c[3], c[3].a * alpha)
		ci.draw_line(c[0], c[1], col, c[2])
		ci.draw_circle(c[0], c[2] * 0.5, col)
		ci.draw_circle(c[1], c[2] * 0.5, col)
	for pl in polys:
		ci.draw_colored_polygon(pl[0], Color(pl[1], pl[1].a * alpha))
	for d in dots:
		ci.draw_circle(d[0], d[1], Color(d[2], d[2].a * alpha))
	# Rosto: olho e franja.
	var eye := head + Vector2(face * hr * 0.5, -hr * 0.05)
	ci.draw_circle(eye, maxf(0.55, hr * 0.17), Color(0.1, 0.08, 0.12, alpha))
	ci.draw_line(head + hup * hr * 0.8 + back * hr * 0.5, head + hup * hr * 0.55 + Vector2(face * hr * 0.75, 0),
		Color(hair, alpha), hr * 0.35)
	if look.has("hat"):
		var hc: Color = look.hat
		var top_c := head + hup * hr * 0.85
		ci.draw_line(top_c - side * hr * 1.6 + Vector2(face * hr * 0.3, 0), top_c + side * hr * 1.6 + Vector2(face * hr * 0.3, 0), Color(OUTLINE, alpha), hr * 0.55)
		ci.draw_line(top_c - side * hr * 1.45 + Vector2(face * hr * 0.3, 0), top_c + side * hr * 1.45 + Vector2(face * hr * 0.3, 0), Color(hc, alpha), hr * 0.3)
		ci.draw_circle(top_c + hup * hr * 0.35, hr * 0.8, Color(hc, alpha))
	if look.has("phones"):
		var pc: Color = look.phones
		ci.draw_arc(head, hr * 1.12, -PI, 0.0, 8, Color(OUTLINE, alpha), 1.3)
		ci.draw_circle(head + Vector2(-face * hr * 0.15, hr * 0.1), hr * 0.42, Color(pc, alpha))
	if look.has("band"):
		ci.draw_line(head - side * hr * 0.95 + hup * hr * 0.35, head + side * hr * 0.95 + hup * hr * 0.35, Color(look.band, alpha), hr * 0.4)
	return {"hf": hf, "hb": hb, "head": head, "neck": neck, "hip": hip, "hr": hr, "up": up, "sh": sh}


# ---------------------------------------------------------------- acessórios e objetos

static func box(ci: CanvasItem, r: Rect2, col: Color, alpha := 1.0, out := OUT_W) -> void:
	ci.draw_rect(r.grow(out), Color(OUTLINE, alpha))
	ci.draw_rect(r, Color(col, col.a * alpha))


static func ball(ci: CanvasItem, c: Vector2, r: float, col: Color, alpha := 1.0) -> void:
	ci.draw_circle(c, r + OUT_W, Color(OUTLINE, alpha))
	ci.draw_circle(c, r, Color(col, alpha))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(col.lightened(0.3), alpha * 0.8))


static func camera(ci: CanvasItem, hand: Vector2, face: float, alpha := 1.0) -> Vector2:
	## Câmera na mão; devolve a posição da lente (origem do flash).
	var r := Rect2(hand + Vector2(-1.0 if face > 0 else -4.0, -2.8), Vector2(5.0, 3.6))
	box(ci, r, Color(0.2, 0.2, 0.23), alpha)
	var lens := hand + Vector2(face * 2.8, -1.0)
	ci.draw_circle(lens, 1.5, Color(OUTLINE, alpha))
	ci.draw_circle(lens, 0.9, Color(0.45, 0.5, 0.55, alpha))
	return lens + Vector2(face * 1.2, 0)


static func phone(ci: CanvasItem, hand: Vector2, face: float, glow: float, alpha := 1.0) -> Vector2:
	var r := Rect2(hand + Vector2(-1.2, -4.2), Vector2(2.4, 4.4))
	box(ci, r, Color(0.16, 0.16, 0.2), alpha, 0.8)
	if glow > 0.0:
		ci.draw_rect(r.grow(-0.5), Color(0.7, 0.85, 0.95, alpha * glow))
	return r.get_center()


static func flash(ci: CanvasItem, c: Vector2, k: float) -> void:
	## Flash de câmera: halo curto + estrela. k: 1 → 0 ao longo do flash.
	ci.draw_circle(c, 16.0 * (1.2 - k * 0.2), Color(1.0, 0.97, 0.88, 0.12 * k))
	ci.draw_circle(c, 7.0, Color(1.0, 0.98, 0.9, 0.35 * k))
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c - d * 7.0 * k, c + d * 7.0 * k, Color(1, 1, 0.95, 0.9 * k), 1.0)
	ci.draw_line(c - Vector2(11 * k, 0), c + Vector2(11 * k, 0), Color(1, 1, 0.95, 0.9 * k), 1.2)
	ci.draw_line(c - Vector2(0, 9 * k), c + Vector2(0, 9 * k), Color(1, 1, 0.95, 0.9 * k), 1.2)
	ci.draw_circle(c, 2.2 * k + 0.5, Color(1, 1, 1, k))


static func note(ci: CanvasItem, p: Vector2, alpha: float) -> void:
	## Nota musical (desenho, não texto).
	var col := Color(0.92, 0.9, 0.85, alpha)
	ci.draw_circle(p, 1.3, col)
	ci.draw_line(p + Vector2(1.1, 0), p + Vector2(1.1, -4.5), col, 0.8)
	ci.draw_line(p + Vector2(1.1, -4.5), p + Vector2(3.0, -3.5), col, 0.8)


class Canvas extends Node2D:
	## Nó de desenho genérico: delega o _draw a quem o criou.
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


static func ellipse(c: Vector2, rx: float, ry: float, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func safe(pts: PackedVector2Array) -> PackedVector2Array:
	## Polígono que o servidor consegue triangular (pose extrema pode cruzar arestas): senão, casco convexo.
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return Geometry2D.convex_hull(pts)
	return pts


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, alpha := 1.0, out := OUT_W) -> void:
	pts = safe(pts)
	if out > 0.0:
		for o in Geometry2D.offset_polygon(pts, out):
			ci.draw_colored_polygon(o, Color(OUTLINE, alpha))
	ci.draw_colored_polygon(pts, Color(col, col.a * alpha))
