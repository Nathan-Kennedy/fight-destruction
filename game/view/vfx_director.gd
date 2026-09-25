extends CanvasLayer
## Diretor de efeitos de tela (§19.3): recebe eventos da simulação via main.gd e anima o shader de
## pós-processo (ondas de choque, aberração cromática, impact frame, speed lines). Só visual.
## Opções separadas (§19.3): `flashes` (impact frame) e `intensity` (0..1) — F6 alterna flashes.
## Impact frame mangá (REFERENCIAS_VFX.md §3): 5 quadros no KO e no golpe que leva a ≥ 150% ou tem kb
## muito alto; no máximo 1 por segundo (fotossensibilidade) e nunca com F6 desligando flashes.
## Finish Zoom (§4): golpe cujo voo previsto (só kb e ângulo, sem obstáculos, como no Smash) cruza a
## blast zone → zoom de tela + tinta vermelha enquanto dura o hitstop. Nada disso toca a sim: é a
## mesma pausa do hitstop, sem câmera lenta. Desligado com mais de 2 lutadores.

const C = preload("res://sim/sim_const.gd")
const ScreenShader = preload("res://view/screen_fx.gdshader")

var sim
var intensity := 1.0
var flashes := true
var _rect: ColorRect
var _mat: ShaderMaterial
var _waves := []        # [pos_mundo, idade, duração, força, raio_max]
var _chroma := 0.0
var _impact := 0.0
var _impact_world := Vector2.ZERO
var _lines := 0.0
var _time := 0.0
const MANGA_FRAMES := 5
const MANGA_PCT := 150
const MANGA_KB := 3000
const MANGA_COOLDOWN := 1.0
const ZOOM_MAX := 0.16            # fração da tela (≈ +19% de zoom)
const ZOOM_IN_FRAMES := 6.0
const ZOOM_OUT_FRAMES := 8.0
var _manga_left := 0              # quadros restantes do impact frame mangá
var _last_manga := -99.0
var _zoom := 0.0
var _zoom_hold := 0               # quadros mínimos segurando o zoom
var _zoom_world := Vector2.ZERO
var _tint := 0.0


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = ScreenShader
	_rect.material = _mat
	add_child(_rect)


func shockwave(world: Vector2, strength: float, radius := 0.35, duration := 0.45) -> void:
	if _waves.size() >= 4:
		_waves.pop_front()
	_waves.append([world, 0.0, duration, strength * intensity, radius])


func hit(world: Vector2, kb: int) -> void:
	var s := clampf(kb / 2400.0, 0.0, 1.0)
	_chroma = maxf(_chroma, 0.004 + 0.012 * s * intensity)
	if kb >= 1600:
		shockwave(world, 0.6 + s, 0.22, 0.3)
	# O evento que gerou esta chamada ainda está em sim.events (main.gd consome logo após o passo).
	var target := -1
	var pct := 0
	for e in sim.events:
		if e.kind == "hit" and int(e.kb) == kb:
			target = e.target
			pct = e.pct
	var finish: bool = target >= 0 and sim.fighters.size() <= 2 and predict_ko(target)
	if finish:
		_zoom_world = world
		_zoom_hold = maxi(sim.freeze, 4)
		_tint = 1.0
	if finish or pct >= MANGA_PCT or kb >= MANGA_KB:
		if _manga(world):
			return
	if kb >= 2000 and flashes:
		_impact = 1.0
		_impact_world = world


func _manga(world: Vector2) -> bool:
	## Dispara o impact frame mangá se a F6 permitir e o último foi há mais de 1 s.
	if not flashes or _time - _last_manga < MANGA_COOLDOWN:
		return false
	_last_manga = _time
	_manga_left = MANGA_FRAMES
	_impact_world = world
	_impact = 0.0
	return true


func predict_ko(id: int) -> bool:
	## Voo balístico do lançado a partir do estado atual (mesmas regras de hitstun da sim, em float,
	## sem paredes: só para a apresentação). Para no núcleo. true se cruzar uma blast zone.
	var f: Dictionary = sim.fighters[id]
	var d: Dictionary = C.FIGHTERS[f.def]
	var x := float(f.x)
	var y := float(f.y)
	var vx := float(f.vx)
	var vy := float(f.vy)
	for t in 240:
		if t < f.hitstun:
			vy += d.gravity
			vx -= vx / 80.0
		else:
			vy = minf(vy + d.gravity, d.max_fall)
			vx -= vx / 32.0
		x += vx
		y += vy
		if x < C.BLAST_LEFT or x > C.BLAST_RIGHT or y < C.BLAST_TOP or y - f.h > C.BLAST_BOTTOM:
			return true
		if sim.grid.get_mat(int(floor(x / C.CELL_SUB)), int(floor(y / C.CELL_SUB))) == C.M_CORE:
			return false
	return false


func burst(world: Vector2) -> void:
	shockwave(world, 1.6, 0.42, 0.5)
	_chroma = maxf(_chroma, 0.018 * intensity)
	if flashes:
		_impact = 1.0
		_impact_world = world


func collapse(world: Vector2, cells: int) -> void:
	shockwave(world, clampf(cells / 60.0, 0.4, 1.4), 0.5, 0.6)
	_chroma = maxf(_chroma, 0.008 * intensity)


func ko(world: Vector2) -> void:
	shockwave(world, 1.8, 0.6, 0.7)
	_chroma = maxf(_chroma, 0.02 * intensity)
	if not _manga(world) and flashes:
		_impact = 1.0
		_impact_world = world


func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var xf := vp.get_canvas_transform()
	var arr := []
	for w in _waves:
		w[1] += delta
	_waves = _waves.filter(func(w): return w[1] < w[2])
	for i in 4:
		if i < _waves.size():
			var w: Array = _waves[i]
			var k: float = w[1] / w[2]
			var p: Vector2 = xf * w[0] / size
			arr.append(Vector4(p.x, p.y, w[4] * k, w[3] * (1.0 - k)))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	_mat.set_shader_parameter("waves", arr)
	_mat.set_shader_parameter("aspect", size.x / size.y)
	_mat.set_shader_parameter("chroma", _chroma)
	_mat.set_shader_parameter("impact", _impact)
	_mat.set_shader_parameter("impact_center", xf * _impact_world / size)
	# Speed lines: enquanto alguém voa lançado rápido, centradas nele.
	var target := 0.0
	var center := Vector2(0.5, 0.5)
	for f in sim.fighters:
		if f.hitstun > 0 and f.respawn == 0:
			var sp := Vector2(f.vx, f.vy).length() / C.SUB
			if sp > 9.0:
				target = maxf(target, clampf((sp - 9.0) / 10.0, 0.0, 1.0) * intensity)
				center = xf * (Vector2(f.x, f.y - f.h / 2) / C.SUB) / size
	_lines = move_toward(_lines, target, delta * 4.0)
	_mat.set_shader_parameter("lines", _lines)
	_mat.set_shader_parameter("lines_center", center)
	_mat.set_shader_parameter("time", _time)
	# Impact frame mangá: 5 quadros, cheio nos 2 primeiros e rampa de saída.
	var manga := 0.0
	if _manga_left > 0:
		manga = minf(1.0, float(_manga_left) / 3.0)
		_manga_left -= 1
	_mat.set_shader_parameter("manga", manga * (1.0 if flashes else 0.0))
	# Finish Zoom: entra em ZOOM_IN_FRAMES, segura enquanto o mundo está congelado, sai em ZOOM_OUT.
	var holding: bool = _zoom_hold > 0 or (_tint > 0.0 and sim.freeze > 0)
	if _zoom_hold > 0:
		_zoom_hold -= 1
	if holding:
		_zoom = move_toward(_zoom, ZOOM_MAX * intensity, ZOOM_MAX / ZOOM_IN_FRAMES)
	else:
		_zoom = move_toward(_zoom, 0.0, ZOOM_MAX / ZOOM_OUT_FRAMES)
		_tint = move_toward(_tint, 0.0, 1.0 / ZOOM_OUT_FRAMES)
	var zc: Vector2 = xf * _zoom_world / size
	_mat.set_shader_parameter("zoom", _zoom)
	_mat.set_shader_parameter("zoom_center", zc)
	_mat.set_shader_parameter("tint", Vector4(1.0, 0.16, 0.12, 0.5 * _tint * intensity if flashes else 0.0))
	if _zoom > 0.0:
		_lines = maxf(_lines, _zoom / ZOOM_MAX * 0.8)
		_mat.set_shader_parameter("lines", _lines)
		_mat.set_shader_parameter("lines_center", zc)
	# Impact frame dura ~3 quadros; aberração decai rápido.
	_impact = move_toward(_impact, 0.0, delta * 20.0)
	_chroma = move_toward(_chroma, 0.0, delta * 0.06)
