extends Camera2D
## Enquadra todos os lutadores com margem; no lançamento antecipa a direção do voo e abre o
## zoom com a velocidade (§8). Tremor proporcional ao impacto, com teto.

const C = preload("res://sim/sim_const.gd")

const VIEW := Vector2(640, 360)
const MARGIN := Vector2(300, 190)
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.25

var sim
var fighter_view
var shake_enabled := true
var _trauma := 0.0   # 0..1; tremor = trauma² × MAX_SHAKE (modelo "trauma", GDC 2016, ver art/third_party/REFERENCIAS_VFX.md)
var _t := 0.0
const MAX_SHAKE := 12.0


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount / 10.0, 1.0)


func update_camera(delta: float, snap := false) -> void:
	var pts := []
	var lead := Vector2.ZERO
	for i in sim.fighters.size():
		var f: Dictionary = sim.fighters[i]
		if f.stocks <= 0 or f.respawn > 0:
			continue
		var p: Vector2 = fighter_view.pos_of(i) - Vector2(0, f.h / 2.0 / C.SUB)
		pts.append(p)
		if f.hitstun > 0:
			var v := Vector2(f.vx, f.vy) / C.SUB
			lead += v * 10.0
	if pts.is_empty():
		return
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	r = r.expand(r.get_center() + lead)
	var need := r.size + MARGIN
	var z := clampf(minf(VIEW.x / need.x, VIEW.y / need.y), ZOOM_MIN, ZOOM_MAX)
	var target := r.get_center()
	# Não mostrar abaixo do chão de base mais do que o necessário.
	var half_h := VIEW.y / z / 2.0
	target.y = minf(target.y, C.WORLD_H - half_h + 24)
	var k := 1.0 if snap else 1.0 - exp(-delta * 6.0)
	zoom = zoom.lerp(Vector2(z, z), 1.0 if snap else 1.0 - exp(-delta * 3.0))
	position = position.lerp(target, k)
	_t += delta
	if shake_enabled and _trauma > 0.01:
		# Ruído suave (senoides defasadas) em vez de aleatório puro: treme sem "pular".
		var amp := _trauma * _trauma * MAX_SHAKE
		offset = Vector2(sin(_t * 71.0) + sin(_t * 43.0) * 0.5, cos(_t * 67.0) + sin(_t * 53.0) * 0.5) * amp * 0.67
		rotation = sin(_t * 37.0) * 0.012 * _trauma * _trauma
		_trauma = maxf(_trauma - delta * 1.6, 0.0)
	else:
		offset = Vector2.ZERO
		rotation = 0.0
		_trauma = 0.0
