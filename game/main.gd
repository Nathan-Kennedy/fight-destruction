extends Node2D
## Integrador: roda a simulação em passo fixo de 60 Hz, lê input, grava replay e alimenta as views.
## Argumentos (depois de `--`):
##   --test [--seconds N]       testes headless + autotest com 4 sementes; código de saída 1 se falhar
##   --capture PASTA [--scene vitrine|colapso|fixos]  roda a demo gravada e salva PNGs de ticks fixos, depois fecha
##   --demo                     roda a demo gravada na janela
##   --replay ARQUIVO.json      reproduz inputs gravados
##   --p1/--p2 leve|medio|pesado, --cpu (J2 controlado pelo bot), --bots (os dois)

const C = preload("res://sim/sim_const.gd")
const MatchSim = preload("res://sim/match_sim.gd")
const InputReader = preload("res://input/input_reader.gd")
const Bot = preload("res://input/bot.gd")
const SimTests = preload("res://tests/sim_tests.gd")
const WorldView = preload("res://view/world_view.gd")
const FighterView = preload("res://view/fighter_view.gd")
const DynamicView = preload("res://view/dynamic_view.gd")
const DebrisFX = preload("res://view/debris_fx.gd")
const CameraDirector = preload("res://view/camera_director.gd")
const Backdrop = preload("res://view/backdrop.gd")
const SpriteLib = preload("res://view/sprite_lib.gd")
const VfxDirector = preload("res://view/vfx_director.gd")
const AmbientView = preload("res://view/ambient_view.gd")
const DepthView = preload("res://view/depth_view.gd")
const FixturesView = preload("res://view/fixtures_view.gd")
const Hud = preload("res://view/hud.gd")
const AudioDirector = preload("res://view/audio_director.gd")

const DT := 1.0 / C.TICK_HZ
const REPLAY_DIR := "user://replays"
const DEMO_LENGTH := 260
const CAPTURE_TICKS := [1, 22, 30, 38, 50, 70, 120, 200, 259]

var sim := MatchSim.new()
var defs := ["medio", "leve"]
var start_pct := [0, 0]
var cpu := [false, false]
var bots := [Bot.new(11), Bot.new(23)]
var mode := "play"
var replay_inputs := []
var recording := []
var capture_dir := ""
var scene := "vitrine"   # roteiro da demo/captura: vitrine | colapso | fixos

var world_view
var fighter_view
var debris
var camera
var vfx
var ambient   # estágio vivo (§8.4): só visual, F8 liga/desliga
var fixtures_view   # elementos reativos e luz 2D: F7 liga/desliga luzes
var hud   # painéis, banners, ajuda e debug (view/hud.gd)
var audio   # sons por evento, loops dos fixos e ambiente (view/audio_director.gd); F9 muta
var show_debug := false
var _acc := 0.0
var _keys_down := {}
var _hash_cache := ""


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if args.has("test"):
		set_process(false)
		var failed := SimTests.run_all(int(args.get("seconds", "60")))
		get_tree().quit(1 if failed > 0 else 0)
		return
	for k in ["p1", "p2"]:
		if args.has(k) and C.FIGHTERS.has(args[k]):
			defs[0 if k == "p1" else 1] = args[k]
	cpu[1] = args.has("cpu") or args.has("bots")
	cpu[0] = args.has("bots")
	if args.has("replay"):
		_load_replay(args.replay)
	elif args.has("capture") or args.has("demo"):
		mode = "capture" if args.has("capture") else "demo"
		capture_dir = args.get("capture", "")
		scene = args.get("scene", "vitrine")
	_build_scene()
	_new_match()
	if mode == "capture":
		_run_capture()


func _parse_args(list: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < list.size():
		var a := list[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			if i + 1 < list.size() and not list[i + 1].begins_with("--"):
				out[key] = list[i + 1]
				i += 1
			else:
				out[key] = "true"
		i += 1
	return out


func _build_scene() -> void:
	RenderingServer.set_default_clear_color(Color(0.12, 0.11, 0.15))
	var lib := SpriteLib.new()
	var backdrop := Backdrop.new()
	backdrop.lib = lib
	add_child(backdrop)
	world_view = WorldView.new()
	world_view.sim = sim
	world_view.lib = lib
	world_view.has_backdrop = backdrop.build()
	add_child(world_view)
	var dynamic_view := DynamicView.new()
	dynamic_view.sim = sim
	dynamic_view.lib = lib
	add_child(dynamic_view)
	fixtures_view = FixturesView.new()
	fixtures_view.sim = sim
	add_child(fixtures_view)
	ambient = AmbientView.new()
	ambient.sim = sim
	ambient.lib = lib
	add_child(ambient)
	ambient.attach(backdrop, world_view)
	# Profundidade 2.5D (chão em perspectiva e interiores em camadas), antes de figurantes e grade.
	var depth := DepthView.new()
	depth.sim = sim
	depth.lib = lib
	world_view.add_child(depth)
	world_view.move_child(depth, 0)
	fighter_view = FighterView.new()
	fighter_view.sim = sim
	fighter_view.lib = lib
	add_child(fighter_view)
	debris = DebrisFX.new()
	debris.lib = lib
	add_child(debris)
	camera = CameraDirector.new()
	camera.sim = sim
	camera.fighter_view = fighter_view
	add_child(camera)
	camera.make_current()

	vfx = VfxDirector.new()
	vfx.sim = sim
	add_child(vfx)
	hud = Hud.new()
	hud.sim = sim
	add_child(hud)
	audio = AudioDirector.new()
	audio.sim = sim
	audio.ambient = ambient
	add_child(audio)


func _new_match() -> void:
	var pct := start_pct
	if mode == "capture" or mode == "demo":
		pct = [0, 90] if scene == "vitrine" else ([0, 0] if scene == "fixos" else [0, 110])
	sim.setup(defs, pct)
	if mode == "capture" or mode == "demo":
		sim.fighters[0].x = 250 * C.SUB
		sim.fighters[1].x = 300 * C.SUB
		sim.fighters[1].facing = -1
		if scene == "colapso":
			# J1 encostado no pilar do térreo; J2 na frente da loja, embaixo do trecho que vai cair.
			sim.fighters[0].x = 704 * C.SUB - sim.fighters[0].hw
			sim.fighters[1].x = 420 * C.SUB
		elif scene == "fixos":
			# J1 na loja ao lado do botijão; J2 na sobreloja colado no cano de vapor.
			sim.fighters[0].x = 540 * C.SUB
			sim.fighters[0].facing = 1
			sim.fighters[1].x = 618 * C.SUB
			sim.fighters[1].y = 272 * C.SUB
			sim.fighters[1].facing = 1
	recording.clear()
	_store_prev()
	fighter_view.alpha = 1.0
	camera.update_camera(DT, true)
	hud.reset()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_hotkeys()
	if mode == "capture":
		return
	_acc += delta
	var n := 0
	while _acc >= DT and n < 5:
		_tick()
		_acc -= DT
		n += 1
	if n == 5:
		_acc = 0.0
	fighter_view.alpha = _acc / DT
	_present(delta)


func _tick() -> void:
	var inputs := []
	if mode == "replay":
		inputs = replay_inputs[sim.tick] if sim.tick < replay_inputs.size() else [0, 0]
	elif mode == "demo":
		inputs = _demo_input(sim.tick)
	else:
		for i in 2:
			inputs.append(bots[i].decide(sim, i) if cpu[i] else InputReader.read(i))
		if sim.winner < 0:
			recording.append(inputs)
	_store_prev()
	sim.step(inputs)
	_consume_events()


func _store_prev() -> void:
	fighter_view.prev = []
	for f in sim.fighters:
		fighter_view.prev.append([f.x, f.y])


func _consume_events() -> void:
	for e in sim.events:
		ambient.on_event(e)
		hud.on_event(e)
		fixtures_view.on_event(e)
		audio.on_event(e)
		match e.kind:
			"break":
				debris.on_break(e, e.mats)
				camera.add_shake(minf(1.5 + e.cells.size() / 5.0, 6.0))
			"bounce":
				if not e.broken.is_empty():
					debris.on_break({"cells": e.broken, "axis": e.axis, "dir": e.dir}, e.mats)
				camera.add_shake(minf(e.e / 800.0, 4.0))
			"hit":
				camera.add_shake(minf(e.kb / 700.0, 6.0))
				var v: Dictionary = sim.fighters[e.target]
				var hp := Vector2(v.x, v.y - v.h / 2) / C.SUB
				var dir_x: int = 1 if e.emitter < 0 else sim.fighters[e.emitter].facing
				debris.on_hit(hp, e.kb, dir_x)
				vfx.hit(hp, e.kb)
				fighter_view.on_hit(e.target, e.kb, e.emitter)
			"chip":
				debris.on_chip(e, sim.grid)
			"burst":
				debris.on_burst(Vector2(e.x, e.y) / C.SUB, e.radius)
				vfx.burst(Vector2(e.x, e.y) / C.SUB)
				camera.add_shake(6.0)
			"explosion":
				debris.on_burst(Vector2(e.x, e.y) / C.SUB, e.radius)
				vfx.burst(Vector2(e.x, e.y) / C.SUB)
				camera.add_shake(7.0)
			"shield_hit":
				var sv: Dictionary = sim.fighters[e.target]
				debris.on_shield_hit(Vector2(sv.x, sv.y - sv.h / 2) / C.SUB)
				camera.add_shake(1.0)
			"shield_break":
				var sb: Dictionary = sim.fighters[e.emitter]
				debris.on_shield_break(Vector2(sb.x, sb.y - sb.h / 2) / C.SUB)
				vfx.shockwave(Vector2(sb.x, sb.y - sb.h / 2) / C.SUB, 1.0, 0.25, 0.35)
				camera.add_shake(5.0)
			"collapse_warn":
				debris.on_warn(e.cells)
			"collapse_land":
				debris.on_dust_cells(e.cells)
				if not e.cells.is_empty():
					var ci: int = e.cells[e.cells.size() / 2]
					vfx.collapse(Vector2((ci % C.GRID_W) * C.CELL, (ci / C.GRID_W) * C.CELL), e.cells.size())
				camera.add_shake(minf(3.0 + e.cells.size() / 40.0, 9.0))
			"crushed", "buried":
				camera.add_shake(7.0)
			"prop_break":
				debris.on_dust(Vector2(e.x, e.y) / C.SUB, 14)
				camera.add_shake(2.5)
			"prop_hit":
				camera.add_shake(3.0)
			"land":
				var f: Dictionary = sim.fighters[e.emitter]
				debris.on_dust(Vector2(f.x, f.y) / C.SUB, 4)
			"ko":
				camera.add_shake(8.0)
				vfx.ko(Vector2(clampf(e.x / C.SUB, 0, C.WORLD_W), clampf(e.y / C.SUB, -200, C.WORLD_H)))
			"match_end":
				_save_replay()


func _present(delta: float) -> void:
	world_view.refresh()
	ambient.update(delta)
	camera.update_camera(delta)
	var debug_text := ""
	if show_debug:
		if sim.tick % 30 == 0 or _hash_cache == "":
			_hash_cache = sim.state_hash()
		var lines := ["tick %d  fps %d  freeze %d  hash %s" % [sim.tick, Engine.get_frames_per_second(), sim.freeze, _hash_cache]]
		for f in sim.fighters:
			lines.append("J%d x %d y %d v (%.1f, %.1f) E %d hitstun %d rupturas %d" % [f.id + 1, f.x / C.SUB, f.y / C.SUB,
				f.vx / float(C.SUB), f.vy / float(C.SUB), C.energy(C.FIGHTERS[f.def].mass, f.vx, f.vy), f.hitstun, f.breaks])
		debug_text = "\n".join(lines)
	var msg := "FIM DO REPLAY" if mode == "replay" and sim.tick >= replay_inputs.size() and sim.winner < 0 else ""
	hud.update_hud(delta, cpu, not show_debug and sim.tick < 600 and mode == "play", debug_text, msg)


func _hotkeys() -> void:
	if _pressed_once(KEY_F1):
		show_debug = not show_debug
	if _pressed_once(KEY_F2):
		cpu[1] = not cpu[1]
	if _pressed_once(KEY_F3):
		fighter_view.show_hitboxes = not fighter_view.show_hitboxes
	if _pressed_once(KEY_F7):
		fixtures_view.set_lights(not fixtures_view.lights_on)
	if _pressed_once(KEY_F8):
		ambient.set_enabled(not ambient.enabled)
	if _pressed_once(KEY_F6):
		# Acessibilidade (§19.3): liga/desliga flashes de tela (impact frame).
		vfx.flashes = not vfx.flashes
	if _pressed_once(KEY_F5):
		_save_replay()
	if _pressed_once(KEY_F11):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if _pressed_once(KEY_ESCAPE):
		get_tree().quit()
	var start := false
	for dev in Input.get_connected_joypads():
		start = start or Input.is_joy_button_pressed(dev, JOY_BUTTON_START)
	if _pressed_once(KEY_R) or (_edge("start", start) and sim.winner >= 0):
		if mode == "replay":
			mode = "play"
		_new_match()


func _pressed_once(key: Key) -> bool:
	return _edge(key, Input.is_physical_key_pressed(key))


func _edge(id, down: bool) -> bool:
	var was: bool = _keys_down.get(id, false)
	_keys_down[id] = down
	return down and not was


# ---------------------------------------------------------------- replay, demo e captura

func _save_replay() -> void:
	if recording.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	var data := {"versao": 4, "defs": defs, "start_pct": start_pct, "inputs": recording, "hash_final": sim.state_hash()}
	var path := REPLAY_DIR.path_join("partida_%s.json" % Time.get_datetime_string_from_system().replace(":", "-"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	print("replay salvo em ", ProjectSettings.globalize_path(path))


func _load_replay(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("replay inválido: " + path)
		return
	mode = "replay"
	defs = [str(data.defs[0]), str(data.defs[1])]
	start_pct = [int(data.start_pct[0]), int(data.start_pct[1])]
	replay_inputs = []
	for inp in data.inputs:
		replay_inputs.append([int(inp[0]), int(inp[1])])


func _demo_length() -> int:
	return DEMO_LENGTH if scene == "vitrine" else (340 if scene == "fixos" else 480)


func _capture_ticks() -> Array:
	if scene == "vitrine":
		return CAPTURE_TICKS
	if scene == "fixos":
		return [14, 40, 70, 90, 100, 170, 214, 262, 329]
	return [1, 200, 236, 260, 282, 296, 310, 322, 332, 360, 420, 479]


func _demo_input(t: int) -> Array:
	if scene == "colapso":
		return _colapso_input(t)
	if scene == "fixos":
		return _fixos_input(t)
	## Sequência de referência curta (§19.2): aproximação, golpe forte, lançamento pela vitrine,
	## e o atacante entra pelo buraco atrás do defensor.
	var p1 := 0
	var p2 := 0
	if t < 8:
		p1 = C.IN_RIGHT
	elif t == 10:
		p1 = C.IN_STRONG
	elif t > 70 and t < 200:
		p1 = C.IN_RIGHT
		if t == 150:
			p1 |= C.IN_JUMP
	if t > 150 and t < 170:
		p2 = C.IN_LEFT
	elif t == 172:
		p2 = C.IN_STRONG | C.IN_LEFT
	return [p1, p2]


func _run_capture() -> void:
	var dir := capture_dir if capture_dir.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(capture_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().process_frame
	for t in _demo_length():
		_store_prev()
		sim.step(_demo_input(sim.tick))
		_consume_events()
		fighter_view.alpha = 1.0
		_present(DT)
		if _capture_ticks().has(sim.tick):
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(dir.path_join("tick_%04d.png" % sim.tick))
		else:
			await get_tree().process_frame
	var f1: Dictionary = sim.fighters[0]
	var f2: Dictionary = sim.fighters[1]
	print("captura concluída em %s | hash %s | J1 (%d, %d) J2 (%d, %d) %d%%" % [dir, sim.state_hash(),
		f1.x / C.SUB, f1.y / C.SUB, f2.x / C.SUB, f2.y / C.SUB, f2.pct])
	get_tree().quit()


func _colapso_input(t: int) -> Array:
	## Roteiro do colapso (§4.2): golpes fortes seguidos no pilar até ele romper; o trecho da frente
	## racha, avisa e cai. J2 percebe o aviso tarde e tenta fugir para a rua.
	var p1 := 0
	if t < 300 and t % 44 == 2:
		p1 = C.IN_STRONG | C.IN_RIGHT
	var p2 := 0
	if t > 272 and t < 330:
		p2 = C.IN_LEFT
	return [p1, p2]


func _fixos_input(t: int) -> Array:
	## Roteiro dos elementos reativos: J1 golpeia o botijão da loja (aviso → explosão), foge pela
	## vitrine e entorta o poste da esquerda com dois fortes, quebrando-o no terceiro. J2 estoura o
	## cano de vapor da sobreloja com um jab e é empurrado pelo jato.
	var p1 := 0
	if t == 2:
		p1 = C.IN_STRONG
	elif t >= 40 and t < 94:
		p1 = C.IN_LEFT
	elif t == 96:
		p1 = C.IN_LIGHT | C.IN_LEFT
	elif t >= 104 and t < 160:
		p1 = C.IN_LEFT
	elif t == 164 or t == 220 or t == 276:
		# Espaçados para caber golpe + hitstop (fórmula nova, até 14 ticks) antes do próximo.
		p1 = C.IN_STRONG
	var p2 := C.IN_LIGHT if t == 3 else 0
	return [p1, p2]
