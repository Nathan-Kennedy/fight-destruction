extends Node
## Diretor de áudio (§9.7, §19.3). Só apresentação: lê o estado da sim e escuta `events`.
##
## - Sons em `res://assets/sfx/` (ver LICENSES.md), carregados em tempo de execução sem importação
##   do editor. Nome `<grupo>_NN.ogg` = variação do grupo; `*_loop.ogg` toca em loop.
## - Pool fixo de players por categoria com teto de vozes e roubo da voz mais fraca, teto global,
##   RNG próprio para pitch/volume, anti-repetição (não repete as últimas variações do grupo) e
##   intervalo mínimo por grupo contra metralhadora do mesmo som.
## - Ruptura em camadas por material: impacto + ruptura (+ grande) + cauda de detritos, volume pela
##   energia e pelo número de células. Rupturas do mesmo quadro são somadas antes de tocar.
## - Buses Master (limitador) / SFX (compressor) / Amb, com ducking breve do ambiente em eventos grandes.
## - F9 muta. `--audio-log` nos argumentos imprime cada som disparado (nome, dB, pitch).
## - Grupo ausente = fallback (`sfx_hit_leve`) e aviso uma vez só.

const C = preload("res://sim/sim_const.gd")
const A = preload("res://sim/attacks.gd")
const Fx = preload("res://sim/fixtures.gd")
const Props = preload("res://sim/props.gd")

const DIR := "res://assets/sfx/"
const FALLBACK := "sfx_hit_leve"
const MAT_KEY := ["", "vidro", "divisoria", "tijolo", "concreto", "nucleo", "entulho"]
const MAX_VOICES := 28
const MAX_LOOPS := 6
const POSITIONAL_MAX_DIST := 1500.0

# categoria → vozes simultâneas
const CATS := {
	"golpe": 5, "whoosh": 3, "corpo": 5, "ruptura": 8, "cauda": 4, "explosao": 3, "estrutura": 3,
	"objeto": 4, "fixo": 4, "publico": 2, "passaros": 2,
}
const FLAT_CATS := ["publico"]   # sem posição (AudioStreamPlayer)

# grupo → [dB base, variação de pitch (±), variação de volume dB (±), intervalo mínimo s, categoria]
const G := {
	"sfx_hit_leve": [-3.0, 0.07, 1.5, 0.03, "golpe"],
	"sfx_hit_forte": [0.0, 0.06, 1.5, 0.03, "golpe"],
	"sfx_hit_grave": [-4.0, 0.05, 1.0, 0.05, "golpe"],
	"sfx_whoosh_leve": [-11.0, 0.1, 2.0, 0.04, "whoosh"],
	"sfx_whoosh_forte": [-8.0, 0.08, 2.0, 0.05, "whoosh"],
	"sfx_esquiva": [-13.0, 0.08, 2.0, 0.08, "whoosh"],
	"sfx_grab": [-7.0, 0.08, 2.0, 0.06, "corpo"],
	"sfx_throw": [-6.0, 0.08, 2.0, 0.06, "corpo"],
	"sfx_land": [-11.0, 0.08, 2.0, 0.06, "corpo"],
	"sfx_corpo_impacto": [-4.0, 0.08, 1.5, 0.05, "corpo"],
	"sfx_escudo_hit": [-7.0, 0.06, 1.5, 0.05, "corpo"],
	"sfx_escudo_quebra": [-2.0, 0.03, 1.0, 0.2, "corpo"],
	"sfx_explosao_carga": [-9.0, 0.04, 1.0, 0.2, "corpo"],
	"sfx_respawn": [-11.0, 0.03, 1.0, 0.2, "corpo"],
	"sfx_explosao": [0.0, 0.07, 1.0, 0.06, "explosao"],
	"sfx_explosao_grave": [-3.0, 0.05, 1.0, 0.1, "explosao"],
	"sfx_ko": [0.0, 0.03, 0.5, 0.3, "explosao"],
	"sfx_rangido": [-5.0, 0.06, 1.5, 0.15, "estrutura"],
	"sfx_desmoronamento": [-2.0, 0.05, 1.0, 0.25, "estrutura"],
	"brk_concreto_grande": [-1.0, 0.06, 1.0, 0.12, "estrutura"],
	"brk_vidro_grande": [-3.0, 0.06, 1.0, 0.1, "ruptura"],
	"prop_extintor_jato": [-9.0, 0.05, 1.0, 0.3, "objeto"],
	"sfx_passaros_revoada": [-12.0, 0.1, 2.0, 0.25, "passaros"],
	"amb_publico_susto": [-13.0, 0.05, 1.5, 1.2, "publico"],
	"amb_publico_aplauso": [-13.0, 0.04, 1.5, 1.2, "publico"],
}

# (tipo, estado) do fixo → [loop, dB]
const FIX_LOOPS := {
	Fx.WATER: {Fx.ACTIVE: ["fix_agua_loop", -9.0]},
	Fx.STEAM: {Fx.ACTIVE: ["fix_vapor_loop", -7.0]},
	Fx.GAS: {Fx.ACTIVE: ["fix_gas_loop", -12.0], Fx.FIRE: ["fix_fogo_loop", -5.0]},
	Fx.TANK: {Fx.ACTIVE: ["fix_pavio_loop", -9.0]},
	Fx.TRAFO: {Fx.ACTIVE: ["fix_eletrico_loop", -9.0]},
	Fx.WIRE: {Fx.ACTIVE: ["fix_fiacao_loop", -10.0]},
	Fx.HYDRANT: {Fx.ACTIVE: ["fix_hidrante_loop", -7.0]},
	Fx.NEON: {Fx.ACTIVE: ["fix_neon_loop", -14.0]},
}
# tipo de objeto → [impacto, quebra]
const PROP_SND := [
	["prop_madeira_impacto", "brk_divisoria_ruptura"],   # caixa
	["prop_metal_impacto", "prop_metal_quebra"],         # barril
	["brk_nucleo_impacto", "prop_metal_quebra"],         # máquina
	["prop_lata_impacto", "prop_metal_hit"],             # botijão
	["prop_lata_impacto", "prop_metal_hit"],             # extintor
]
const REQUIRED := ["sfx_hit_leve", "sfx_hit_forte", "sfx_whoosh_leve", "sfx_whoosh_forte", "sfx_explosao",
	"brk_vidro_ruptura", "brk_concreto_ruptura", "brk_concreto_grande", "sfx_rangido", "amb_cidade_loop"]

var sim
var ambient   # opcional: estágio vivo (ambient_view.gd), lido para reação do público e pássaros
var log_enabled := false
var muted := false

var rng := RandomNumberGenerator.new()
var _streams := {}      # grupo → Array[AudioStream]
var _recent := {}       # grupo → Array[int] (últimas variações)
var _last_t := {}       # grupo → [tempo, dB]
var _warned := {}
var _pools := {}        # categoria → Array[player]
var _pending := []      # [tempo, grupo, pos, dB, pitch]
var _now := 0.0
var _loops := {}        # chave → {player, name}
var _amb_city: AudioStreamPlayer
var _amb_birds: AudioStreamPlayer
var _duck := 0.0        # dB atuais de ducking do ambiente
var _duck_hold := 0.0
var _bus_sfx := 0
var _bus_amb := 0
var _last_tick := -1
var _atk_prev := [[-1, 0], [-1, 0]]
var _islands := {}      # ilha → centro (Vector2), do aviso até a queda
var _brk := {}          # acumulado do quadro: {counts: Array, sum: Vector2, n, e}
var _chip := {}
var _npc_state := []
var _bird_state := []
var _crowd_cd := {"susto": 0.0, "aplauso": 0.0}
var _f9 := false
var stats := {"played": 0, "dropped": 0, "stolen": 0}


func _ready() -> void:
	rng.seed = 7_031_977
	log_enabled = OS.get_cmdline_user_args().has("--audio-log")
	_setup_buses()
	_load_all()
	for cat in CATS:
		var arr := []
		for i in CATS[cat]:
			var p
			if FLAT_CATS.has(cat):
				p = AudioStreamPlayer.new()
			else:
				var p2 := AudioStreamPlayer2D.new()
				p2.max_distance = POSITIONAL_MAX_DIST
				p2.attenuation = 0.6
				p2.panning_strength = 0.7
				p = p2
			p.bus = "SFX"
			p.set_meta("vol", -80.0)
			p.set_meta("t0", 0.0)
			add_child(p)
			arr.append(p)
		_pools[cat] = arr
	_amb_city = _amb_player("amb_cidade_loop", -9.0)
	_amb_birds = _amb_player("amb_passaros_loop", -13.0)
	_brk = _acc_new()
	_chip = _acc_new()


# ---------------------------------------------------------------- carga e mixagem

func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 4000.0
		comp.release_ms = 180.0
		AudioServer.add_bus_effect(i, comp)
	if AudioServer.get_bus_index("Amb") < 0:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "Amb")
		AudioServer.set_bus_send(j, "Master")
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim: AudioEffect
		if ClassDB.class_exists("AudioEffectHardLimiter"):
			lim = ClassDB.instantiate("AudioEffectHardLimiter")
			lim.set("ceiling_db", -0.5)
		else:
			lim = AudioEffectLimiter.new()
			lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	_bus_sfx = AudioServer.get_bus_index("SFX")
	_bus_amb = AudioServer.get_bus_index("Amb")


func _load_all() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		push_warning("audio: pasta %s não existe; jogo sem som" % DIR)
		return
	var re := RegEx.new()
	re.compile("_\\d+$")
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	for f in files:
		var ext := f.get_extension().to_lower()
		if ext != "ogg" and ext != "wav":
			continue
		var path := ProjectSettings.globalize_path(DIR + f)
		var s: AudioStream = null
		if ext == "ogg":
			s = AudioStreamOggVorbis.load_from_file(path)
		else:
			s = AudioStreamWAV.load_from_file(path)
		if s == null:
			push_warning("audio: falha ao carregar " + f)
			continue
		var base := f.get_basename()
		var group := re.sub(base, "")
		if group.ends_with("_loop"):
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = int(w.get_length() * w.mix_rate)
		if not _streams.has(group):
			_streams[group] = []
		_streams[group].append(s)
	for r in REQUIRED:
		if not _streams.has(r):
			push_warning("audio: grupo obrigatório ausente: " + r)
	if log_enabled:
		var total := 0
		for g in _streams:
			total += _streams[g].size()
		print("[audio] %d grupos, %d arquivos" % [_streams.size(), total])


func _amb_player(group: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Amb"
	p.volume_db = db
	add_child(p)
	var arr: Array = _streams.get(group, [])
	if arr.is_empty():
		_warn(group)
		return p
	p.stream = arr[0]
	p.play(rng.randf() * maxf(0.0, arr[0].get_length() - 1.0))
	return p


func _warn(group: String) -> void:
	if not _warned.has(group):
		_warned[group] = true
		push_warning("audio: som ausente '%s' (fallback %s)" % [group, FALLBACK])


func duck(db: float, hold: float) -> void:
	## Ambiente abaixa `db` por `hold` s e volta devagar (§19.3).
	_duck = maxf(_duck, db)
	_duck_hold = maxf(_duck_hold, hold)


# ---------------------------------------------------------------- disparo

func _cfg(group: String) -> Array:
	if G.has(group):
		return G[group]
	if group.begins_with("brk_"):
		if group.ends_with("_cauda"):
			return [-9.0, 0.08, 2.0, 0.06, "cauda"]
		if group.ends_with("_lasca"):
			return [-11.0, 0.1, 2.0, 0.05, "ruptura"]
		if group.ends_with("_impacto"):
			return [-5.0, 0.07, 1.5, 0.06, "ruptura"]
		return [-4.0, 0.07, 1.5, 0.06, "ruptura"]
	if group.begins_with("prop_"):
		return [-6.0, 0.08, 2.0, 0.06, "objeto"]
	if group.begins_with("fix_"):
		return [-7.0, 0.07, 1.5, 0.08, "fixo"]
	return [-6.0, 0.06, 1.5, 0.05, "corpo"]


func play(group: String, pos = null, db := 0.0, pitch := 1.0, delay := 0.0) -> bool:
	## pos: Vector2 em px de mundo, ou null (centro da câmera). db soma ao volume base do grupo.
	if delay > 0.0:
		_pending.append([_now + delay, group, pos, db, pitch])
		return true
	var arr: Array = _streams.get(group, [])
	var name := group
	if arr.is_empty():
		_warn(group)
		name = FALLBACK
		arr = _streams.get(FALLBACK, [])
		if arr.is_empty():
			return false
	var cfg := _cfg(group)
	var vol: float = cfg[0] + db + rng.randf_range(-cfg[2], cfg[2]) * 0.5
	# Intervalo mínimo: o mesmo grupo logo em seguida só passa se vier bem mais alto.
	var last: Array = _last_t.get(group, [-10.0, -80.0])
	if _now - last[0] < cfg[3] and vol < last[1] + 3.0:
		_log("pula", group, vol, pitch)
		return false
	var player = _voice(cfg[4], vol)
	if player == null:
		stats.dropped += 1
		_log("DESCARTA", group, vol, pitch)
		return false
	_last_t[group] = [_now, vol]
	player.stream = arr[_pick(name, arr.size())]
	player.volume_db = vol
	player.pitch_scale = clampf(pitch * (1.0 + rng.randf_range(-cfg[1], cfg[1])), 0.4, 2.5)
	if player is AudioStreamPlayer2D:
		(player as AudioStreamPlayer2D).global_position = pos if pos is Vector2 else _listener()
	player.set_meta("vol", vol)
	player.set_meta("t0", _now)
	player.play()
	stats.played += 1
	_log("toca", group if name == group else "%s->%s" % [group, name], vol, player.pitch_scale)
	return true


func _pick(group: String, n: int) -> int:
	if n <= 1:
		return 0
	var rec: Array = _recent.get(group, [])
	var avoid := mini(rec.size(), n - 1 if n <= 3 else 2)
	var i := rng.randi_range(0, n - 1)
	var tries := 0
	while rec.slice(rec.size() - avoid).has(i) and tries < 8:
		i = rng.randi_range(0, n - 1)
		tries += 1
	rec.append(i)
	if rec.size() > 3:
		rec.pop_front()
	_recent[group] = rec
	return i


func _voice(cat: String, vol: float):
	var pool: Array = _pools.get(cat, _pools.corpo)
	var playing := 0
	for c in _pools:
		for p in _pools[c]:
			if p.playing:
				playing += 1
	var victim = null
	var worst := INF
	for p in pool:
		if not p.playing:
			if playing < MAX_VOICES:
				return p
			break
		# Voz mais fraca: volume menos idade (vozes velhas estão na cauda).
		var score: float = p.get_meta("vol") - (_now - p.get_meta("t0")) * 8.0
		if score < worst:
			worst = score
			victim = p
	if victim == null or vol < worst - 2.0:
		return null
	victim.stop()
	stats.stolen += 1
	return victim


func _listener() -> Vector2:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	return cam.get_screen_center_position() if cam else Vector2(C.WORLD_W * 0.5, C.WORLD_H * 0.5)


func _log(what: String, group: String, vol: float, pitch: float) -> void:
	if log_enabled:
		print("[audio] t%d %s %s %.1f dB p%.2f" % [sim.tick if sim else -1, what, group, vol, pitch])


# ---------------------------------------------------------------- energia

static func _e01(e: float, lo := 300.0, hi := 12000.0) -> float:
	## Energia do jogo (½·m·v²) em 0..1, escala logarítmica.
	if e <= lo:
		return 0.0
	return clampf(log(e / lo) / log(hi / lo), 0.0, 1.0)


static func _cell_pos(i: int) -> Vector2:
	return Vector2((i % C.GRID_W) * C.CELL + C.CELL * 0.5, (i / C.GRID_W) * C.CELL + C.CELL * 0.5)


func _cells_center(cells) -> Vector2:
	if cells == null or cells.size() == 0:
		return _listener()
	var s := Vector2.ZERO
	for i in cells:
		s += _cell_pos(i)
	return s / cells.size()


func _fighter_pos(id: int) -> Vector2:
	if id < 0 or id >= sim.fighters.size():
		return _listener()
	var f: Dictionary = sim.fighters[id]
	return Vector2(f.x, f.y - f.h / 2) / C.SUB


func _prop(pid) -> Dictionary:
	if pid == null or sim.props == null or pid < 0 or pid >= sim.props.props.size():
		return {}
	return sim.props.props[pid]


func _prop_pos(pid) -> Vector2:
	var p := _prop(pid)
	return Vector2(p.x, p.y - p.h / 2) / C.SUB if not p.is_empty() else _listener()


func _fixture(fid) -> Dictionary:
	if sim.fixtures == null or fid == null:
		return {}
	for f in sim.fixtures.fixtures:
		if f.id == fid:
			return f
	return {}


func _acc_new() -> Dictionary:
	return {"counts": [0, 0, 0, 0, 0, 0, 0], "sum": Vector2.ZERO, "n": 0, "e": 0}


func _acc_add(acc: Dictionary, cells, mats, e: int) -> void:
	for k in cells.size():
		var i: int = cells[k]
		var m: int = mats[k] if mats != null and k < mats.size() else sim.grid.mat[i]
		if m <= 0 or m >= acc.counts.size():
			continue
		acc.counts[m] += 1
		acc.sum += _cell_pos(i)
		acc.n += 1
	acc.e = maxi(acc.e, e)


func _dominant(counts: Array) -> Array:
	## Materiais por quantidade, maior primeiro: [[mat, n], ...].
	var out := []
	for m in range(1, counts.size()):
		if counts[m] > 0:
			out.append([m, counts[m]])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out


# ---------------------------------------------------------------- eventos

func on_event(e: Dictionary) -> void:
	match e.kind:
		"hit":
			var hp := _fighter_pos(e.target)
			var t := clampf((e.kb - 400) / 2600.0, 0.0, 1.0)
			var strong: bool = e.attack != A.JAB and (e.attack >= 0 or e.kb >= 900)
			play("sfx_hit_forte" if strong else "sfx_hit_leve", hp, lerpf(-5.0, 0.0, t), lerpf(1.06, 0.9, t))
			if e.kb >= 1600:
				play("sfx_hit_grave", hp, lerpf(-6.0, 0.0, clampf((e.kb - 1600) / 1600.0, 0.0, 1.0)))
				duck(4.0, 0.25)
		"shield_hit":
			play("sfx_escudo_hit", _fighter_pos(e.target), lerpf(-4.0, 1.0, clampf(e.dmg / 14.0, 0.0, 1.0)))
		"shield_break":
			var sp := _fighter_pos(e.emitter)
			play("sfx_escudo_quebra", sp)
			play("brk_vidro_cauda", sp, -4.0, 1.2, 0.12)
			duck(6.0, 0.5)
		"grab":
			play("sfx_grab", _fighter_pos(e.target))
		"grab_escape":
			play("sfx_throw", _fighter_pos(e.emitter), -5.0, 1.15)
		"throw":
			play("sfx_throw", _fighter_pos(e.emitter))
			play("sfx_whoosh_forte", _fighter_pos(e.emitter), 0.0, 0.95, 0.04)
		"dodge":
			play("sfx_esquiva", _fighter_pos(e.emitter))
		"land":
			var def: String = sim.fighters[e.emitter].def
			var m: float = C.FIGHTERS[def].mass
			var lp := Vector2(sim.fighters[e.emitter].x, sim.fighters[e.emitter].y) / C.SUB
			play("sfx_land", lp, (m - 100.0) / 12.0, 100.0 / m)
		"burst_charge":
			play("sfx_explosao_carga", _fighter_pos(e.emitter))
		"burst":
			var bp := Vector2(e.x, e.y) / C.SUB
			play("sfx_explosao", bp, -1.0)
			play("sfx_explosao_grave", bp, -2.0)
			duck(8.0, 0.6)
		"explosion":
			var xp := Vector2(e.x, e.y) / C.SUB
			var k := clampf(e.radius / 56.0, 0.5, 1.2)
			play("sfx_explosao", xp, lerpf(-4.0, 0.0, k), 1.1 - 0.15 * k)
			play("sfx_explosao_grave", xp, lerpf(-5.0, 0.0, k))
			play("brk_concreto_cauda", xp, -3.0, 1.0, 0.18)
			duck(10.0, 0.9)
		"break":
			_acc_add(_brk, e.cells, e.get("mats"), int(e.get("e", 0)))
		"bounce":
			_on_bounce(e)
		"chip":
			# Energia do carimbo: `cell_dmg` do golpe (jab 10 … pisada 140).
			var cd := 10
			if e.emitter >= 0 and sim.fighters[e.emitter].attack != A.NONE:
				cd = A.LIST[sim.fighters[e.emitter].attack].cell_dmg
			_acc_add(_chip, e.cells, null, cd * 40)
		"collapse_warn":
			var c := _cells_center(e.cells)
			_islands[e.island] = [c, e.cells.size()]
			var big := clampf(e.cells.size() / 60.0, 0.0, 1.0)
			# Rangido crescente: três estalos cada vez mais altos durante o aviso (50 ticks).
			play("sfx_rangido", c, lerpf(-8.0, -4.0, big), 0.85)
			play("sfx_rangido", c, lerpf(-5.0, -1.0, big), 0.95, 0.35)
			play("brk_concreto_lasca", c, -4.0, 0.7, 0.6)
		"collapse_fall":
			var info: Array = _islands.get(e.island, [_listener(), 20])
			play("sfx_desmoronamento", info[0], lerpf(-6.0, 0.0, clampf(info[1] / 80.0, 0.0, 1.0)))
		"collapse_land":
			var lc := _cells_center(e.cells)
			var n: int = e.cells.size() + int(e.get("dust", 0))
			var t := clampf(n / 90.0, 0.0, 1.0)
			play("brk_concreto_grande", lc, lerpf(-5.0, 1.0, t), lerpf(1.05, 0.85, t))
			play("brk_concreto_cauda", lc, lerpf(-6.0, -1.0, t), 0.9, 0.2)
			play("brk_entulho_impacto", lc, -3.0, 0.9, 0.35)
			play("sfx_explosao_grave", lc, lerpf(-14.0, -4.0, t), 0.8)
			duck(lerpf(6.0, 12.0, t), 1.2)
			_islands.erase(e.island)
		"crushed", "buried":
			var cp := _fighter_pos(e.emitter)
			play("sfx_corpo_impacto", cp, 0.0, 0.85)
			play("brk_entulho_impacto", cp, 0.0)
		"prop_grab":
			play("sfx_grab", _prop_pos(e.prop), -3.0, 1.1)
		"prop_throw":
			play("sfx_whoosh_forte", _prop_pos(e.prop), -2.0, 0.9)
		"prop_struck":
			var ps := _prop(e.prop)
			if not ps.is_empty():
				play(PROP_SND[ps.kind][0], _prop_pos(e.prop), 0.0)
		"prop_hit":
			var ph := _prop(e.prop)
			if not ph.is_empty():
				play(PROP_SND[ph.kind][0], _fighter_pos(e.target), 1.0)
			play("sfx_hit_forte", _fighter_pos(e.target), -3.0)
		"prop_bounce":
			var pb := _prop(e.prop)
			if not pb.is_empty():
				var t := _e01(float(e.e), 100.0, 6000.0)
				play(PROP_SND[pb.kind][0], _prop_pos(e.prop), lerpf(-14.0, -2.0, t), 1.05 - 0.1 * t)
		"prop_break":
			var bp2 := Vector2(e.x, e.y) / C.SUB
			var kid: int = e.get("kind_id", 0)
			if kid != Props.BOTIJAO:
				play(PROP_SND[kid][1], bp2, 0.0)
				play("brk_divisoria_cauda" if kid == 0 else "prop_metal_hit", bp2, -5.0, 0.9, 0.12)
		"prop_jet":
			play("prop_extintor_jato", Vector2(e.x, e.y) / C.SUB)
		"fix_state":
			_on_fix_state(e)
		"fix_spark":
			play("fix_faisca", Vector2(e.x, e.y) / C.SUB, rng.randf_range(-4.0, 0.0))
		"fix_bend":
			play("fix_entorta", Vector2(e.x, e.y) / C.SUB, lerpf(-6.0, 0.0, clampf(absi(e.angle) / 176.0, 0.0, 1.0)))
		"fix_hurt":
			var fx := _fixture(e.fix)
			var tp := _fighter_pos(e.target)
			var ty: int = fx.get("type", -1)
			if ty == Fx.GAS:
				play("fix_queima", tp)
			elif ty == Fx.STEAM or ty == Fx.WATER or ty == Fx.HYDRANT:
				play("fix_vapor_jato", tp, -8.0, 1.3)
			else:
				play("fix_choque", tp)
			if int(e.get("kb", 0)) > 0:
				play("sfx_corpo_impacto", tp, -6.0)
		"fix_extinguish":
			play("fix_extingue", Vector2(e.x, e.y) / C.SUB)
		"ko":
			play("sfx_ko", null)
			play("amb_publico_susto", null, 2.0, 1.0, 0.15)
			play("amb_publico_aplauso", null, 0.0, 1.0, 0.6)
			duck(12.0, 1.4)
		"respawn":
			play("sfx_respawn", _fighter_pos(e.emitter))
		"match_end":
			play("amb_publico_aplauso", null, 3.0, 1.0, 0.3)


func _on_bounce(e: Dictionary) -> void:
	var c := _cells_center(e.cells)
	var t := _e01(float(e.e))
	play("sfx_corpo_impacto", c, lerpf(-9.0, 0.0, t), lerpf(1.05, 0.9, t))
	var acc := _acc_new()
	_acc_add(acc, e.cells, null, 0)
	var dom := _dominant(acc.counts)
	if not dom.is_empty():
		var key: String = MAT_KEY[dom[0][0]]
		play("brk_%s_impacto" % key, c, lerpf(-9.0, 0.0, t), 1.0)
	if not e.broken.is_empty():
		_acc_add(_brk, e.broken, e.get("mats"), int(e.e))


func _flush_breaks() -> void:
	## Camadas por material do que rompeu neste quadro (§9.7): impacto + ruptura (+ grande) + cauda.
	if _brk.n > 0:
		var c: Vector2 = _brk.sum / _brk.n
		var dom := _dominant(_brk.counts)
		var total: int = _brk.n
		var t := maxf(clampf(total / 30.0, 0.0, 1.0), _e01(float(_brk.e)))
		for k in mini(dom.size(), 2):
			var m: int = dom[k][0]
			var n: int = dom[k][1]
			var key: String = MAT_KEY[m]
			var sub := -4.0 * k   # segundo material mais baixo
			var mt := clampf(n / 20.0, 0.0, 1.0)
			var lvl := lerpf(-7.0, 1.0, maxf(mt, t * 0.8)) + sub
			if m == C.M_RUBBLE:
				play("brk_entulho_impacto", c, lvl)
				continue
			if m == C.M_CORE:
				play("brk_nucleo_impacto", c, lvl)
				continue
			play("brk_%s_impacto" % key, c, lvl - 2.0, lerpf(1.05, 0.9, mt))
			play("brk_%s_ruptura" % key, c, lvl, lerpf(1.05, 0.88, mt), 0.01)
			var big_n := 6 if m == C.M_GLASS else 12
			if n >= big_n and (m == C.M_GLASS or m == C.M_CONCRETE or m == C.M_BRICK):
				play("brk_vidro_grande" if m == C.M_GLASS else "brk_concreto_grande", c, lvl - 3.0, 1.0, 0.02)
			if n >= 3:
				play("brk_%s_cauda" % key, c, lvl - 3.0, 1.0, rng.randf_range(0.08, 0.16))
		if total >= 25:
			duck(lerpf(4.0, 9.0, clampf(total / 80.0, 0.0, 1.0)), 0.7)
		_brk = _acc_new()
	if _chip.n > 0:
		var cc: Vector2 = _chip.sum / _chip.n
		var d := _dominant(_chip.counts)
		var ct := maxf(clampf(_chip.n / 12.0, 0.0, 1.0), _e01(float(_chip.e), 400.0, 5600.0))
		play("brk_%s_lasca" % MAT_KEY[d[0][0]], cc, lerpf(-4.0, 4.0, ct), lerpf(1.05, 0.85, ct))
		if ct > 0.6:
			play("brk_%s_impacto" % MAT_KEY[d[0][0]], cc, lerpf(-8.0, -2.0, ct), 0.95)
		_chip = _acc_new()


func _on_fix_state(e: Dictionary) -> void:
	var p := Vector2(e.x, e.y) / C.SUB
	var s: int = e.state
	match e.type:
		Fx.STEAM:
			if s == Fx.ACTIVE:
				play("fix_vapor_jato", p, 2.0)
		Fx.WATER, Fx.HYDRANT:
			if s == Fx.ACTIVE:
				play("fix_agua_jorro", p, 0.0)
				play("prop_metal_hit", p, -6.0, 0.8)
		Fx.GAS:
			if s == Fx.ACTIVE:
				play("fix_vapor_jato", p, -6.0, 1.4)
			elif s == Fx.FIRE:
				play("fix_fogo_ignicao", p, 2.0)
				duck(4.0, 0.4)
		Fx.TANK:
			if s == Fx.ACTIVE:
				play("prop_metal_hit", p, -2.0, 0.8)
		Fx.TRAFO:
			if s == Fx.ACTIVE:
				play("fix_choque", p, 2.0, 0.9)
				play("fix_faisca", p, 0.0, 1.0, 0.05)
		Fx.WIRE:
			if s == Fx.ACTIVE:
				play("fix_choque", p, 0.0, 1.1)
				play("prop_metal_hit", p, -4.0, 1.2)
		Fx.POLE:
			if s == Fx.ACTIVE:
				play("fix_entorta", p, 0.0, 0.9)
			elif s == Fx.DONE:
				play("fix_poste_queda", p, 2.0)
				play("brk_vidro_ruptura", p + Vector2(0, -Fx.POLE_H), -4.0, 1.1, 0.25)
		Fx.LAMP:
			if s == Fx.ACTIVE:
				play("prop_lata_impacto", p, -6.0, 1.2)
			elif s == Fx.DONE:
				play("brk_vidro_ruptura", p, -1.0, 1.1)
				play("prop_metal_hit", p, -4.0, 1.0, 0.25)
		Fx.NEON:
			if s == Fx.ACTIVE:
				play("fix_neon_estalo", p, -4.0)
			elif s == Fx.DONE:
				play("fix_neon_estalo", p, 0.0, 0.8)
				play("brk_vidro_lasca", p, -2.0, 1.0, 0.05)


# ---------------------------------------------------------------- estado por quadro

func _process(delta: float) -> void:
	_now += delta
	if _pressed_f9():
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
	_flush_breaks()
	var i := 0
	while i < _pending.size():
		var q: Array = _pending[i]
		if q[0] <= _now:
			_pending.remove_at(i)
			play(q[1], q[2], q[3], q[4])
		else:
			i += 1
	if sim and sim.tick != _last_tick:
		_last_tick = sim.tick
		_poll_attacks()
	if sim:
		_update_loops()
	_poll_ambient()
	# Ducking do ambiente: segura e volta ~10 dB/s.
	if _duck_hold > 0.0:
		_duck_hold -= delta
	else:
		_duck = maxf(0.0, _duck - 10.0 * delta)
	AudioServer.set_bus_volume_db(_bus_amb, -_duck)


func _pressed_f9() -> bool:
	var down := Input.is_physical_key_pressed(KEY_F9)
	var edge := down and not _f9
	_f9 = down
	return edge


func _poll_attacks() -> void:
	## Whoosh no startup dos golpes: detecta golpe novo pelo estado dos lutadores.
	for f in sim.fighters:
		if f.id >= _atk_prev.size():
			continue
		var prev: Array = _atk_prev[f.id]
		var started: bool = f.attack != A.NONE and (f.attack != prev[0] or f.atk_t < prev[1])
		_atk_prev[f.id] = [f.attack, f.atk_t]
		if not started:
			continue
		var atk: Dictionary = A.LIST[f.attack]
		var p := _fighter_pos(f.id)
		# Toca um pouco antes do frame ativo, para o ar cortar junto com o golpe.
		var wait := maxf(0.0, (atk.startup - 4 - f.atk_t) / float(C.TICK_HZ))
		match f.attack:
			A.JAB:
				play("sfx_whoosh_leve", p, 0.0, 1.0, wait)
			A.GRAB:
				play("sfx_whoosh_leve", p, -5.0, 0.8, wait)
			A.BURST:
				pass   # burst_charge cuida
			_:
				play("sfx_whoosh_forte", p, 0.0, 1.0, wait)


func _update_loops() -> void:
	## Loops posicionais dos fixos ativos e do pavio de botijão móvel. Sai quem parou.
	var want := {}
	if sim.fixtures != null:
		for f in sim.fixtures.fixtures:
			var by_state: Dictionary = FIX_LOOPS.get(f.type, {})
			if by_state.has(f.state):
				want["f%d" % f.id] = [by_state[f.state][0], by_state[f.state][1], Vector2(f.x, f.y) / C.SUB]
	if sim.props != null:
		for p in sim.props.props:
			if p.kind == Props.BOTIJAO and p.fx > 0 and p.state != Props.BROKEN:
				want["p%d" % p.id] = ["fix_pavio_loop", -6.0, Vector2(p.x, p.y - p.h / 2) / C.SUB]
	# Teto: os mais próximos da câmera.
	if want.size() > MAX_LOOPS:
		var cam := _listener()
		var keys := want.keys()
		keys.sort_custom(func(a, b): return want[a][2].distance_squared_to(cam) < want[b][2].distance_squared_to(cam))
		for k in keys.slice(MAX_LOOPS):
			want.erase(k)
	for k in _loops.keys():
		var l: Dictionary = _loops[k]
		if not want.has(k) or want[k][0] != l.name:
			l.player.stop()
			l.player.queue_free()
			_loops.erase(k)
			_log("loop fim", l.name, 0.0, 1.0)
	for k in want:
		var w: Array = want[k]
		if not _loops.has(k):
			var arr: Array = _streams.get(w[0], [])
			if arr.is_empty():
				_warn(w[0])
				continue
			var pl := AudioStreamPlayer2D.new()
			pl.bus = "SFX"
			pl.stream = arr[0]
			pl.max_distance = POSITIONAL_MAX_DIST
			pl.attenuation = 0.8
			pl.panning_strength = 0.7
			pl.volume_db = w[1]
			pl.pitch_scale = rng.randf_range(0.95, 1.05)
			add_child(pl)
			pl.global_position = w[2]
			pl.play(rng.randf() * maxf(0.0, arr[0].get_length() - 0.5))
			_loops[k] = {"player": pl, "name": w[0]}
			_log("loop", w[0], w[1], pl.pitch_scale)
		else:
			_loops[k].player.global_position = w[2]


func _poll_ambient() -> void:
	## Reação do público e revoada, lidas do estado do estágio vivo (sem mexer nele).
	for k in _crowd_cd:
		_crowd_cd[k] = maxf(0.0, _crowd_cd[k] - get_process_delta_time())
	if ambient == null or not ambient.get("enabled"):
		if _amb_birds:
			_amb_birds.volume_db = -40.0
		return
	if _amb_birds:
		_amb_birds.volume_db = -13.0
	var npcs = ambient.get("_npcs")
	if npcs is Array:
		if _npc_state.size() != npcs.size():
			_npc_state.resize(npcs.size())
		var uau := 0
		var medo := 0
		for i in npcs.size():
			var st = npcs[i].get("state", "")
			if st != _npc_state[i]:
				if _npc_state[i] == null:
					pass   # primeira leitura: só registra
				elif st == "uau":
					uau += 1
				elif st == "medo":
					medo += 1
				_npc_state[i] = st
		if medo > 0 and _crowd_cd.susto <= 0.0:
			play("amb_publico_susto", null, minf(-3.0 + 2.0 * medo, 4.0) - 3.0)
			_crowd_cd.susto = 2.5
		elif uau > 0 and _crowd_cd.aplauso <= 0.0:
			play("amb_publico_aplauso", null, minf(-4.0 + 2.0 * uau, 3.0) - 3.0)
			_crowd_cd.aplauso = 2.5
	var birds = ambient.get("_birds")
	if birds is Array:
		if _bird_state.size() != birds.size():
			_bird_state.resize(birds.size())
		for i in birds.size():
			var st = birds[i].get("state", "")
			if st == "voa" and _bird_state[i] != "voa" and _bird_state[i] != null:
				play("sfx_passaros_revoada", birds[i].get("pos", _listener()))
			_bird_state[i] = st
