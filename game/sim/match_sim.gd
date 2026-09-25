extends RefCounted
## Simulação autoritativa: função de (estado, inputs). Só inteiros, sem nós e sem render.
## A apresentação lê `fighters`/`grid` e escuta `events` (padrão state() + eventos, §3.2).

const C = preload("res://sim/sim_const.gd")
const A = preload("res://sim/attacks.gd")
const MatterGrid = preload("res://sim/matter_grid.gd")
const Structure = preload("res://sim/structure.gd")
const Props = preload("res://sim/props.gd")
const Fixtures = preload("res://sim/fixtures.gd")

# Ordem canônica dos campos inteiros de um lutador (hash e snapshot).
const FIGHTER_KEYS := ["x", "y", "vx", "vy", "facing", "grounded", "jumps", "pct", "stocks", "hitstun",
	"attack", "atk_t", "atk_hit", "invuln", "prev_in", "respawn", "breaks",
	"shield", "shielding", "lag", "stun", "dodge", "dodge_kind", "dodge_dir", "intang", "air_dodged",
	"grabbing", "grab_t", "held_by", "hold_prop", "burst_cd", "buf", "buf_t", "coyote"]

# Tipos de esquiva (campo dodge_kind).
const DODGE_NONE := 0
const DODGE_ROLL := 1
const DODGE_SPOT := 2
const DODGE_AIR := 3
# Botões de golpe: começar um golpe ou arremesso consome todos do buffer (um aperto, uma ação).
const ATTACK_BITS := 32 | 64 | 128 | 512

var tick := 0
var freeze := 0
var winner := -1
var grid: MatterGrid
var structure: Structure
var props: Props
var fixtures: Fixtures
var fighters: Array = []
var events: Array = []
var _seq := 0


func setup(defs: Array, start_pct: Array = []) -> void:
	tick = 0
	freeze = 0
	winner = -1
	_seq = 0
	grid = MatterGrid.new()
	grid.build_test_district()
	structure = Structure.new()
	structure.setup(grid)
	props = Props.new()
	props.setup_test_district()
	fixtures = Fixtures.new()
	fixtures.setup_test_district(grid)
	fighters.clear()
	for i in defs.size():
		var d: Dictionary = C.FIGHTERS[defs[i]]
		var f := {
			"id": i, "def": defs[i], "hw": d.w * C.SUB / 2, "h": d.h * C.SUB,
			"x": C.SPAWN_X[i], "y": 416 * C.SUB, "vx": 0, "vy": 0, "facing": 1 if i % 2 == 0 else -1,
			"grounded": 1, "jumps": 1, "pct": start_pct[i] if i < start_pct.size() else 0,
			"stocks": C.STOCKS, "hitstun": 0, "attack": A.NONE, "atk_t": 0, "atk_hit": 0,
			"invuln": 0, "prev_in": 0, "respawn": 0, "breaks": 0,
			"shield": C.SHIELD_MAX, "shielding": 0, "lag": 0, "stun": 0, "dodge": 0, "dodge_kind": DODGE_NONE,
			"dodge_dir": 0, "intang": 0, "air_dodged": 0, "grabbing": -1, "grab_t": 0, "held_by": -1, "hold_prop": -1,
			"burst_cd": 0, "buf": 0, "buf_t": 0, "coyote": C.COYOTE_TICKS,
		}
		fighters.append(f)


# ---------------------------------------------------------------- passo

func step(inputs: Array) -> void:
	events.clear()
	if winner >= 0:
		tick += 1
		return
	if freeze > 0:
		# Hitstop: o mundo para, mas a entrada continua registrada (§5.5): o que for apertado agora
		# entra no buffer, que não corre durante o congelamento e vale ao fim dele.
		freeze -= 1
		for i in fighters.size():
			var f: Dictionary = fighters[i]
			var inp: int = inputs[i] if i < inputs.size() else 0
			_buffer_press(f, inp & ~f.prev_in)
			f.prev_in = inp
		tick += 1
		return
	fixtures.begin_tick()
	for i in fighters.size():
		_update_fighter(fighters[i], inputs[i] if i < inputs.size() else 0)
	_update_holds()
	_resolve_attacks()
	_step_props()
	_step_fixtures()
	_step_structure()
	for f in fighters:
		_check_blast(f)
	tick += 1


func _update_fighter(f: Dictionary, inp: int) -> void:
	var d: Dictionary = C.FIGHTERS[f.def]
	var pressed: int = inp & ~f.prev_in
	var released: int = f.prev_in & ~inp
	f.prev_in = inp
	if f.stocks <= 0:
		return
	# Input buffer (§5.5): botão de ação apertado agora fica guardado BUFFER_TICKS ticks. As ações
	# leem `pressed | buf` e consomem o bit ao disparar, então nada dispara duas vezes.
	if f.buf_t > 0:
		f.buf_t -= 1
		if f.buf_t == 0:
			f.buf = 0
	_buffer_press(f, pressed)
	var raw: int = pressed
	pressed |= f.buf
	if f.respawn > 0:
		f.respawn -= 1
		if f.respawn == 0:
			_respawn(f)
		return
	if f.invuln > 0:
		f.invuln -= 1
	if f.intang > 0:
		f.intang -= 1
	if f.burst_cd > 0:
		f.burst_cd -= 1
	if f.held_by >= 0:
		# Preso: sem controle nem física própria; quem segura posiciona (_update_holds).
		return
	if f.shielding == 0 and f.shield < C.SHIELD_MAX and f.stun == 0:
		f.shield = mini(f.shield + C.SHIELD_REGEN, C.SHIELD_MAX)

	var dir_x := int((inp & C.IN_RIGHT) != 0) - int((inp & C.IN_LEFT) != 0)

	if f.hitstun > 0:
		f.shielding = 0
		f.hitstun -= 1
		f.vy += d.gravity
		f.vx -= f.vx / 80
		if f.grounded:
			f.vx = f.vx * 7 / 8
		if f.hitstun == 0:
			f.breaks = 0
	elif f.stun > 0 or f.lag > 0:
		# Atordoado (escudo quebrou) ou travado pelo impacto no escudo: só física.
		if f.stun > 0:
			f.stun -= 1
			if f.stun == 0:
				f.shield = C.SHIELD_MAX / 2
		else:
			f.lag -= 1
		_passive_physics(f, d)
	elif f.dodge > 0:
		_update_dodge(f, d)
	elif f.grabbing >= 0:
		_update_grabbing(f, d, raw, dir_x)
	elif f.grounded and (inp & C.IN_SHIELD) and f.attack == A.NONE and f.hold_prop < 0 and not (pressed & C.IN_JUMP):
		_update_shield(f, d, pressed, dir_x)
	else:
		if f.shielding:
			f.shielding = 0
		_update_free(f, d, inp, pressed, released, dir_x)

	_move_axis(f, 0, f.vx)
	_move_axis(f, 1, f.vy)
	var was_grounded: int = f.grounded
	f.grounded = int(_solid_below(f))
	# Coyote time: saiu do chão sem pular (borda, piso rompido) → o pulo continua sendo do chão por
	# COYOTE_TICKS ticks no ar. Pular, ser lançado ou esquivar no ar zera.
	if f.grounded:
		f.coyote = C.COYOTE_TICKS
	elif not was_grounded and f.coyote > 0:
		f.coyote -= 1
	if f.grounded:
		f.jumps = 1
		f.air_dodged = 0
		if not was_grounded:
			_emit("land", f.id, {})
			if f.dodge_kind == DODGE_AIR:
				# Pousar durante a esquiva aérea encurta o resto dela (landing lag curto).
				f.dodge = mini(f.dodge, 6)
				f.dodge_kind = DODGE_SPOT


func _update_free(f: Dictionary, d: Dictionary, inp: int, pressed: int, released: int, dir_x: int) -> void:
	if f.attack == A.NONE:
		if f.hold_prop >= 0 and (pressed & (C.IN_LIGHT | C.IN_STRONG | C.IN_GRAB)):
			_consume(f, ATTACK_BITS)
			_throw_prop(f, inp, dir_x)
		elif not f.grounded and (pressed & C.IN_SHIELD) and f.air_dodged == 0 and f.hold_prop < 0:
			f.coyote = 0
			_start_dodge(f, DODGE_AIR, dir_x, inp)
			return
		elif (pressed & C.IN_SPECIAL) and f.burst_cd == 0:
			_free_hands(f)
			_start_attack(f, A.BURST)
			f.burst_cd = C.BURST_COOLDOWN
			f.vy = mini(f.vy, 0)
			_emit("burst_charge", f.id, {})
		elif pressed & C.IN_STRONG:
			if inp & C.IN_UP:
				_start_attack(f, A.STRONG_UP)
			elif inp & C.IN_DOWN:
				_start_attack(f, A.STOMP if f.grounded else A.STRONG_DOWN_AIR)
			else:
				if dir_x != 0 and f.grounded:
					f.facing = dir_x
				_start_attack(f, A.STRONG_SIDE)
		elif pressed & C.IN_GRAB:
			_start_attack(f, A.GRAB)
		elif pressed & C.IN_LIGHT:
			_start_attack(f, A.JAB)
	else:
		f.atk_t += 1
		if f.atk_t >= A.total_frames(f.attack):
			f.attack = A.NONE
		elif f.attack == A.BURST and f.atk_t <= A.LIST[A.BURST].startup + A.LIST[A.BURST].active:
			f.vx = 0
			f.vy = 0
			return

	var locked: bool = f.attack != A.NONE and f.grounded
	if f.grounded:
		var target: int = 0 if locked else dir_x * d.walk
		f.vx = _approach(f.vx, target, d.accel)
		if dir_x != 0 and not locked:
			f.facing = dir_x
	elif dir_x != 0:
		f.vx = _approach(f.vx, dir_x * d.air, d.air_accel)
	else:
		f.vx -= f.vx / 32

	if (pressed & C.IN_JUMP) and not locked and (f.grounded or f.coyote > 0 or f.jumps > 0):
		_consume(f, C.IN_JUMP)
		if f.grounded or f.coyote > 0:
			f.vy = -d.jump
			f.grounded = 0
		else:
			f.vy = -d.djump
			f.jumps -= 1
		f.coyote = 0
		# Pulo do buffer com o botão já solto sai como pulo curto (mesma regra da altura variável).
		if not (inp & C.IN_JUMP):
			f.vy /= 2
	elif (released & C.IN_JUMP) and f.vy < 0:
		f.vy /= 2

	f.vy += d.gravity
	var fall: int = d.fast_fall if (inp & C.IN_DOWN) and not f.grounded and f.vy > 0 else d.max_fall
	f.vy = mini(f.vy, fall)


func _passive_physics(f: Dictionary, d: Dictionary) -> void:
	f.vy = mini(f.vy + d.gravity, d.max_fall)
	if f.grounded:
		f.vx = _approach(f.vx, 0, d.accel)
	else:
		f.vx -= f.vx / 32


# ---------------------------------------------------------------- escudo e esquiva (§5.5)

func _update_shield(f: Dictionary, d: Dictionary, pressed: int, dir_x: int) -> void:
	if f.shielding == 0:
		f.shielding = 1
		_emit("shield_up", f.id, {})
	f.shield -= C.SHIELD_DRAIN
	if f.shield <= 0:
		_shield_break(f)
		_passive_physics(f, d)
		return
	if pressed & (C.IN_LEFT | C.IN_RIGHT):
		_start_dodge(f, DODGE_ROLL, dir_x, 0)
	elif pressed & C.IN_DOWN:
		_start_dodge(f, DODGE_SPOT, 0, 0)
	elif pressed & C.IN_GRAB:
		# Agarrar saindo do escudo.
		f.shielding = 0
		_start_attack(f, A.GRAB)
	_passive_physics(f, d)


func _shield_break(f: Dictionary) -> void:
	f.shielding = 0
	f.shield = 0
	f.stun = C.SHIELD_BREAK_STUN
	f.vy = -1400
	f.grounded = 0
	f.coyote = 0
	_emit("shield_break", f.id, {})


func _start_dodge(f: Dictionary, kind: int, dir_x: int, inp: int) -> void:
	f.shielding = 0
	f.attack = A.NONE
	f.dodge_kind = kind
	f.dodge_dir = dir_x
	match kind:
		DODGE_ROLL:
			f.dodge = C.ROLL_TICKS
			f.intang = C.ROLL_INTANG
		DODGE_SPOT:
			f.dodge = C.SPOT_TICKS
			f.intang = C.SPOT_INTANG
			f.vx = 0
		DODGE_AIR:
			f.dodge = C.AIR_DODGE_TICKS
			f.intang = C.AIR_DODGE_INTANG
			f.air_dodged = 1
			var dir_y := int((inp & C.IN_DOWN) != 0) - int((inp & C.IN_UP) != 0)
			f.vx = dir_x * C.AIR_DODGE_V
			f.vy = dir_y * C.AIR_DODGE_V
			if dir_x != 0 and dir_y != 0:
				# Diagonal: 724/1024 ≈ 1/√2.
				f.vx = f.vx * 724 / 1024
				f.vy = f.vy * 724 / 1024
	_emit("dodge", f.id, {"type": kind})


func _update_dodge(f: Dictionary, d: Dictionary) -> void:
	f.dodge -= 1
	match f.dodge_kind:
		DODGE_ROLL:
			f.vx = f.dodge_dir * C.ROLL_V if f.dodge > 6 else _approach(f.vx, 0, d.accel * 2)
			f.vy = mini(f.vy + d.gravity, d.max_fall)
		DODGE_AIR:
			# Deslocamento que desacelera; sem gravidade na primeira metade.
			f.vx = f.vx * 7 / 8
			f.vy = f.vy * 7 / 8
			if f.dodge < C.AIR_DODGE_TICKS / 2:
				f.vy = mini(f.vy + d.gravity, d.max_fall)
		_:
			_passive_physics(f, d)
	if f.dodge == 0:
		f.dodge_kind = DODGE_NONE


# ---------------------------------------------------------------- agarrão e arremesso

func _update_grabbing(f: Dictionary, d: Dictionary, pressed: int, dir_x: int) -> void:
	_passive_physics(f, d)
	f.grab_t -= 1
	var v: Dictionary = fighters[f.grabbing]
	var thr := -1
	if pressed & C.IN_UP:
		thr = A.THROW_UP
	elif pressed & C.IN_DOWN:
		thr = A.THROW_DOWN
	elif (pressed & (C.IN_LEFT | C.IN_RIGHT)) and dir_x == -f.facing:
		thr = A.THROW_BACK
	elif pressed & (C.IN_LEFT | C.IN_RIGHT | C.IN_LIGHT | C.IN_STRONG | C.IN_GRAB):
		thr = A.THROW_FWD
	if thr >= 0:
		_throw_fighter(f, v, thr)
	elif f.grab_t <= 0:
		_release_grab(f)
		# Escapou: os dois se afastam um pouco.
		v.vx = f.facing * 640
		f.vx = -f.facing * 384
		_emit("grab_escape", v.id, {"by": f.id})


func _release_grab(f: Dictionary) -> void:
	if f.grabbing < 0:
		return
	var v: Dictionary = fighters[f.grabbing]
	v.held_by = -1
	f.grabbing = -1
	f.grab_t = 0


func _throw_fighter(f: Dictionary, v: Dictionary, thr: int) -> void:
	_release_grab(f)
	if thr == A.THROW_BACK:
		# Passa o oponente para trás e lança no sentido oposto ao que o agarrador olhava.
		f.facing = -f.facing
		v.x = f.x + f.facing * (f.hw + v.hw)
		if overlaps_solid(v):
			v.x = f.x
	_emit("throw", f.id, {"target": v.id, "type": thr})
	_hit(f, v, A.THROWS[thr])


func _update_holds() -> void:
	## Depois de todos se moverem: quem está preso vai para a frente de quem segura, e o objeto
	## segurado acompanha as mãos.
	for f in fighters:
		if f.hold_prop >= 0:
			props.hold_at(f.hold_prop, f.x + f.facing * f.hw / 2, f.y - f.h + 4 * C.SUB)
		if f.grabbing < 0:
			continue
		var v: Dictionary = fighters[f.grabbing]
		v.vx = 0
		v.vy = 0
		v.y = f.y
		v.x = f.x + f.facing * (f.hw + v.hw)
		if overlaps_solid(v):
			v.x = f.x
			if overlaps_solid(v):
				# Sem espaço para segurar (teto baixo): solta onde ele estava.
				_release_grab(f)
				v.x = f.x - f.facing * (f.hw + v.hw)
				if overlaps_solid(v):
					v.x = f.x
		v.grounded = f.grounded


func _place_prop_safely(pid: int, f: Dictionary) -> void:
	## Objeto segurado não colide; ao soltar, precisa estar fora de matéria. Tenta as mãos, depois
	## o espaço do próprio corpo (que é livre), deslizando para trás se o objeto for mais largo.
	var p: Dictionary = props.props[pid]
	var tries := [[p.x, p.y], [f.x, f.y], [f.x - f.facing * p.hw, f.y], [f.x + f.facing * p.hw, f.y]]
	for c in tries:
		var b := [c[0] - p.hw, c[1] - p.h, c[0] + p.hw, c[1]]
		if not grid.any_solid_in_rect(b[0], b[1], b[2], b[3]):
			p.x = c[0]
			p.y = c[1]
			return
	p.x = f.x
	p.y = f.y


func _throw_prop(f: Dictionary, inp: int, dir_x: int) -> void:
	var pid: int = f.hold_prop
	f.hold_prop = -1
	var mul: int = props.throw_mul(pid)
	var sp: int = C.PROP_THROW_V * mul / 1000
	var vx: int = (dir_x if dir_x != 0 else f.facing) * sp
	var vy: int = -sp / 6
	if inp & C.IN_UP:
		vx = f.facing * sp / 5
		vy = -sp
	elif (inp & C.IN_DOWN) and not f.grounded:
		vx = f.facing * sp / 5
		vy = sp
	if dir_x != 0:
		f.facing = dir_x
	_place_prop_safely(pid, f)
	props.throw(pid, vx, vy, f.id)
	f.attack = A.NONE
	f.lag = 8
	_emit("prop_throw", f.id, {"prop": pid})


func _start_attack(f: Dictionary, id: int) -> void:
	f.attack = id
	f.atk_t = 0
	f.atk_hit = 0
	_consume(f, ATTACK_BITS)


func _buffer_press(f: Dictionary, pressed: int) -> void:
	var b: int = pressed & C.BUFFER_MASK
	if b != 0:
		f.buf = b
		f.buf_t = C.BUFFER_TICKS


func _consume(f: Dictionary, bits: int) -> void:
	f.buf &= ~bits
	if f.buf == 0:
		f.buf_t = 0


func _approach(v: int, target: int, amount: int) -> int:
	if v < target:
		return mini(v + amount, target)
	return maxi(v - amount, target)


# ---------------------------------------------------------------- colisão e impacto (§5.2)

func _box(f: Dictionary) -> Array:
	return [f.x - f.hw, f.y - f.h, f.x + f.hw, f.y]


func _move_axis(f: Dictionary, axis: int, amount: int) -> void:
	var remaining := amount
	var guard := 0
	while remaining != 0 and guard < 64:
		guard += 1
		var stepv := clampi(remaining, -C.MAX_STEP, C.MAX_STEP)
		var hit := _probe(f, axis, stepv)
		if not hit.is_empty() and axis == 0 and f.grounded and f.hitstun == 0 and _try_step_up(f, stepv):
			continue
		if hit.is_empty():
			if axis == 0:
				f.x += stepv
			else:
				f.y += stepv
			remaining -= stepv
			continue
		var before: int = f.x if axis == 0 else f.y
		_flush(f, axis, stepv, hit.line)
		remaining -= (f.x if axis == 0 else f.y) - before
		var vn: int = f.vx if axis == 0 else f.vy
		if f.hitstun > 0 and absi(vn) >= C.BOUNCE_MIN:
			var old_speed := absi(f.vx) + absi(f.vy)
			if _impact(f, axis, hit.cells):
				var new_speed := absi(f.vx) + absi(f.vy)
				remaining = remaining * new_speed / maxi(1, old_speed)
				continue
			return
		if axis == 0:
			f.vx = 0
		else:
			f.vy = 0
		return


func _try_step_up(f: Dictionary, stepv: int) -> bool:
	## Andando no chão contra um degrau de até STEP_UP células (borda de entulho, laje quebrada):
	## sobe se o corpo couber em cima. Sem isso, qualquer sobra de 8 px prende o lutador.
	var y0: int = f.y
	for k in range(1, C.STEP_UP + 1):
		f.y = y0 - k * C.CELL_SUB
		if not overlaps_solid(f) and _probe(f, 0, stepv).is_empty():
			return true
	f.y = y0
	return false


func _probe(f: Dictionary, axis: int, stepv: int) -> Dictionary:
	## Primeira linha de células sólidas que o corpo passaria a ocupar neste sub-passo.
	var b := _box(f)
	var cs := C.CELL_SUB
	var lines := []
	var a0: int
	var a1: int
	if axis == 0:
		if stepv > 0:
			for c in range(C.fdiv(b[2] - 1, cs) + 1, C.fdiv(b[2] + stepv - 1, cs) + 1):
				lines.append(c)
		else:
			for c in range(C.fdiv(b[0], cs) - 1, C.fdiv(b[0] + stepv, cs) - 1, -1):
				lines.append(c)
		a0 = C.fdiv(b[1], cs)
		a1 = C.fdiv(b[3] - 1, cs)
	else:
		if stepv > 0:
			for c in range(C.fdiv(b[3] - 1, cs) + 1, C.fdiv(b[3] + stepv - 1, cs) + 1):
				lines.append(c)
		else:
			for c in range(C.fdiv(b[1], cs) - 1, C.fdiv(b[1] + stepv, cs) - 1, -1):
				lines.append(c)
		a0 = C.fdiv(b[0], cs)
		a1 = C.fdiv(b[2] - 1, cs)
	for line in lines:
		var cells := PackedInt32Array()
		var core := false
		for k in range(a0, a1 + 1):
			var cx: int = line if axis == 0 else k
			var cy: int = k if axis == 0 else line
			var m := grid.get_mat(cx, cy)
			if m != C.M_EMPTY:
				cells.append(grid.index(cx, cy))
				core = core or m == C.M_CORE
		if not cells.is_empty():
			return {"line": line, "cells": cells, "core": core}
	return {}


func _flush(f: Dictionary, axis: int, stepv: int, line: int) -> void:
	var cs := C.CELL_SUB
	if axis == 0:
		f.x = line * cs - f.hw if stepv > 0 else (line + 1) * cs + f.hw
	else:
		f.y = line * cs if stepv > 0 else (line + 1) * cs + f.h


func _impact(f: Dictionary, axis: int, cells: PackedInt32Array) -> bool:
	## Corpo lançado encosta em matéria. Retorna true se atravessou (e o movimento continua).
	var d: Dictionary = C.FIGHTERS[f.def]
	var r := 0
	var absorb := 0
	var rest := 0
	var min_v := 0
	var core := false
	for i in cells:
		var m: int = grid.mat[i]
		core = core or m == C.M_CORE
		r += grid.hp[i]
		absorb = maxi(absorb, C.MAT_ABSORB[m])
		rest = maxi(rest, C.MAT_REST[m])
		min_v = maxi(min_v, C.MAT_MIN_V[m])
	var e := C.energy(d.mass, f.vx, f.vy)
	var vn: int = f.vx if axis == 0 else f.vy
	var dir: int = signi(vn)
	if not core and f.breaks < C.MAX_BREAKS and absi(vn) >= min_v and e >= r:
		grid.destroy(cells)
		f.breaks += 1
		var e2 := (e - r) * (1000 - absorb) / 1000
		var ratio := C.isqrt(e2 * 1048576 / maxi(1, e))
		f.vx = f.vx * ratio / 1024
		f.vy = f.vy * ratio / 1024
		freeze = maxi(freeze, mini(1 + r / 400, 5))
		_emit("break", f.id, {"cells": cells, "mats": grid.last_mats, "axis": axis, "dir": dir, "e": e, "r": r})
		return true
	# Dano acumula (§5.2), mas só de impactos com pelo menos metade da velocidade de ruptura.
	var broken := PackedInt32Array()
	if not core and absi(vn) * 2 >= min_v:
		broken = grid.damage(cells, e)
	var bounced := -vn * rest / 1000
	if absi(bounced) < C.BOUNCE_MIN:
		bounced = 0
	if axis == 0:
		f.vx = bounced
		f.vy = f.vy * 4 / 5
	else:
		f.vy = bounced
		f.vx = f.vx * 4 / 5
	_emit("bounce", f.id, {"cells": cells, "broken": broken, "mats": grid.last_mats if not broken.is_empty() else PackedByteArray(),
		"axis": axis, "dir": dir, "e": e, "r": r})
	return false


func _solid_below(f: Dictionary) -> bool:
	if f.y % C.CELL_SUB != 0:
		return false
	return grid.any_solid_in_rect(f.x - f.hw, f.y, f.x + f.hw, f.y + 1)


func overlaps_solid(f: Dictionary) -> bool:
	## Invariante: nenhum lutador ativo dentro de matéria.
	return grid.any_solid_in_rect(f.x - f.hw, f.y - f.h, f.x + f.hw, f.y)


# ---------------------------------------------------------------- golpes

func attack_box(f: Dictionary) -> Array:
	## Retângulo [l, t, r, b] em subpixels; vazio fora dos frames ativos.
	if f.attack == A.NONE or not A.is_active(f.attack, f.atk_t):
		return []
	var box: Array = A.LIST[f.attack].box
	if A.LIST[f.attack].get("radial", false):
		var cy: int = f.y - f.h / 2
		return [f.x + box[0] * C.SUB, cy + box[1] * C.SUB, f.x + (box[0] + box[2]) * C.SUB, cy + (box[1] + box[3]) * C.SUB]
	var w: int = box[2] * C.SUB
	var l: int = f.x + box[0] * C.SUB if f.facing > 0 else f.x - box[0] * C.SUB - w
	var t: int = f.y + box[1] * C.SUB
	return [l, t, l + w, t + box[3] * C.SUB]


func _resolve_attacks() -> void:
	for a in fighters:
		var box := attack_box(a)
		if box.is_empty() or a.atk_hit:
			continue
		var atk: Dictionary = A.LIST[a.attack]
		var is_grab: bool = atk.get("grab", false)
		if a.atk_t == atk.startup and not is_grab:
			if atk.cell_dmg > 0:
				_stamp(a, atk, box)
			_strike_props(a, atk, box)
			_strike_fixtures(a, atk, box)
		for v in fighters:
			if v.id == a.id or not _hittable(v):
				continue
			var hb := _box(v)
			if box[0] < hb[2] and hb[0] < box[2] and box[1] < hb[3] and hb[1] < box[3]:
				if is_grab:
					if v.held_by >= 0:
						continue
					_grab(a, v)
				elif atk.get("radial", false) and not _in_radius(a, atk.radius, hb):
					continue
				elif v.shielding:
					_shield_hit(a.id, a.facing, v, atk.dmg, atk.base, atk.hitstop)
				elif atk.get("radial", false):
					var d := _radial_dir(a, v)
					_launch(a.id, v, atk.dmg, atk.base, atk.growth, d[0], d[1], atk.hitstop, a.attack)
				else:
					_hit(a, v, atk)
				a.atk_hit = 1
				break
		if is_grab and not a.atk_hit and a.hold_prop < 0 and a.attack == A.GRAB:
			var pid: int = props.find_grabbable(box[0], box[1], box[2], box[3])
			if pid >= 0:
				props.grab(pid, a.id)
				a.hold_prop = pid
				a.atk_hit = 1
				a.attack = A.NONE
				_emit("prop_grab", a.id, {"prop": pid})


func _hittable(v: Dictionary) -> bool:
	return v.stocks > 0 and v.respawn == 0 and v.invuln == 0 and v.intang == 0


func _in_radius(a: Dictionary, radius: int, r: Array) -> bool:
	## Círculo (centro no meio do corpo de `a`) contra retângulo, em subpixels.
	var cx: int = a.x
	var cy: int = a.y - a.h / 2
	var nx: int = clampi(cx, r[0], r[2])
	var ny: int = clampi(cy, r[1], r[3])
	var rr: int = radius * C.SUB
	return (nx - cx) * (nx - cx) + (ny - cy) * (ny - cy) <= rr * rr


func _radial_dir(a: Dictionary, v: Dictionary) -> Array:
	## Direção do centro de `a` ao centro de `v` em 1/1024, com viés para cima (lançamento legível).
	var dx: int = v.x - a.x
	var dy: int = (v.y - v.h / 2) - (a.y - a.h / 2) - 12 * C.SUB
	if dx == 0 and dy == 0:
		dx = a.facing
	var n: int = maxi(1, C.isqrt(dx * dx + dy * dy))
	return [dx * 1024 / n, dy * 1024 / n]


func _stamp(a: Dictionary, atk: Dictionary, box: Array) -> void:
	## Todo golpe lasca o cenário que a hitbox toca; o que zera o HP rompe (§5.4, carimbo de impacto).
	var hit_cells := grid.cells_in_rect(box[0], box[1], box[2], box[3])
	if atk.get("radial", false):
		# Explosão: só as células cujo centro cai dentro do raio.
		var cx: int = a.x
		var cy: int = a.y - a.h / 2
		hit_cells = _cells_in_circle(hit_cells, cx, cy, atk.radius)
		_emit("burst", a.id, {"x": cx, "y": cy, "radius": atk.radius})
	if hit_cells.is_empty():
		return
	var broken := grid.damage(hit_cells, atk.cell_dmg * hit_cells.size())
	if not broken.is_empty():
		_emit("break", a.id, {"cells": broken, "mats": grid.last_mats, "axis": 0, "dir": a.facing, "e": 0, "r": 0})
	if broken.size() < hit_cells.size():
		_emit("chip", a.id, {"cells": hit_cells, "dir": a.facing})
	# Bater em matéria tem peso: congelamento curto mesmo sem acertar ninguém.
	if atk.cell_dmg >= 35:
		freeze = maxi(freeze, 3)


func _cells_in_circle(cells: PackedInt32Array, cx: int, cy: int, radius_px: int) -> PackedInt32Array:
	var inside := PackedInt32Array()
	var rr: int = radius_px * C.SUB
	for i in cells:
		var ex: int = (i % C.GRID_W) * C.CELL_SUB + C.CELL_SUB / 2 - cx
		var ey: int = (i / C.GRID_W) * C.CELL_SUB + C.CELL_SUB / 2 - cy
		if ex * ex + ey * ey <= rr * rr:
			inside.append(i)
	return inside


func _strike_fixtures(a: Dictionary, atk: Dictionary, box: Array) -> void:
	## Golpe em fixo do cenário: a explosão especial aciona tudo no raio; o resto usa a hitbox.
	if atk.get("radial", false):
		_apply_fixture_events(fixtures.blast(a.x, a.y - a.h / 2, atk.radius, false))
	else:
		_apply_fixture_events(fixtures.hit_rect(box[0], box[1], box[2], box[3], atk.dir[0] * a.facing, atk.dir[1], atk.dmg))


func _strike_props(a: Dictionary, atk: Dictionary, box: Array) -> void:
	for pid in props.in_rect(box[0], box[1], box[2], box[3]):
		var p: Dictionary = props.props[pid]
		# Objeto sem percentual: o golpe o lança como se ele estivesse a 40%, escalado pela massa.
		var kb: int = (atk.base + 40 * atk.growth) * 100 / maxi(40, p.mass)
		var dx: int = atk.dir[0] * a.facing
		var dy: int = atk.dir[1]
		if atk.get("radial", false):
			if not _in_radius(a, atk.radius, props.box_of(p)):
				continue
			var d := _radial_dir(a, {"x": p.x, "y": p.y, "h": p.h})
			dx = d[0]
			dy = d[1]
		props.strike(pid, dx * kb / 1024, dy * kb / 1024 - 256, a.id, atk.dmg)
		_emit("prop_struck", a.id, {"prop": pid})


func _grab(a: Dictionary, v: Dictionary) -> void:
	a.attack = A.NONE
	a.grabbing = v.id
	a.grab_t = C.GRAB_HOLD
	a.vx = 0
	_free_hands(v)
	v.held_by = a.id
	v.attack = A.NONE
	v.shielding = 0
	v.dodge = 0
	v.dodge_kind = DODGE_NONE
	v.lag = 0
	v.hitstun = 0
	_emit("grab", a.id, {"target": v.id})


func _free_hands(v: Dictionary) -> void:
	## Quem é agarrado ou atingido solta o que segurava.
	if v.grabbing >= 0:
		_release_grab(v)
	if v.hold_prop >= 0:
		_place_prop_safely(v.hold_prop, v)
		props.drop(v.hold_prop)
		v.hold_prop = -1


func _shield_hit(attacker: int, facing: int, v: Dictionary, dmg: int, base: int, hitstop: int, melee := true) -> void:
	v.shield -= dmg * C.SHIELD_DMG_MUL
	v.lag = 4 + dmg / 2
	v.vx = facing * (256 + base / 4)
	if melee and attacker >= 0:
		# Recuo de quem bateu de perto; arremesso de longe não empurra o arremessador.
		var a: Dictionary = fighters[attacker]
		if a.grounded:
			a.vx = -facing * 256
	freeze = maxi(freeze, hitstop_for(dmg, 0, hitstop) * C.HS_SHIELD_NUM / C.HS_SHIELD_DEN)
	_emit("shield_hit", attacker, {"target": v.id, "dmg": dmg, "shield": v.shield})
	if v.shield <= 0:
		_shield_break(v)


func _hit(a: Dictionary, v: Dictionary, atk: Dictionary) -> void:
	_launch(a.id, v, atk.dmg, atk.base, atk.growth, atk.dir[0] * a.facing, atk.dir[1], atk.hitstop, a.attack)


static func hitstop_for(dmg: int, kb: int, floor_ticks: int) -> int:
	## Hitstop do acerto (contrato em sim_const/Docs): cresce com o dano e um pouco com o kb, com teto.
	## `floor_ticks` é o `hitstop` da tabela do golpe; 0 = dano de cenário sem golpe (fogo, choque).
	if floor_ticks <= 0:
		return mini(kb / 512, C.HS_ENV_MAX)
	var hs: int = C.HS_BASE + dmg * C.HS_DMG_NUM / C.HS_DMG_DEN + kb / C.HS_KB_DIV
	return mini(maxi(hs, floor_ticks), C.HS_MAX)


func _launch(attacker: int, v: Dictionary, dmg: int, base: int, growth: int, dx: int, dy: int, hitstop: int, attack_id: int) -> void:
	## Aplica dano e knockback. (dx, dy) em 1/1024, já no sentido do mundo.
	var vd: Dictionary = C.FIGHTERS[v.def]
	_free_hands(v)
	if v.held_by >= 0:
		_release_grab(fighters[v.held_by])
	v.pct += dmg
	# §5.1: KB = base + (percentual + dano) × crescimento × ajuste de peso.
	var kb: int = base + v.pct * growth * vd.weight / 1000
	v.vx = dx * kb / 1024
	v.vy = dy * kb / 1024
	v.attack = A.NONE
	v.breaks = 0
	v.shielding = 0
	v.dodge = 0
	v.dodge_kind = DODGE_NONE
	v.lag = 0
	v.stun = 0
	v.coyote = 0
	if kb >= C.LAUNCH_KB:
		v.hitstun = kb / 96
		v.grounded = 0 if v.vy < 0 else v.grounded
	else:
		v.hitstun = maxi(4, kb / 96)
	freeze = maxi(freeze, hitstop_for(dmg, kb, hitstop))
	_emit("hit", attacker, {"target": v.id, "kb": kb, "dmg": dmg, "pct": v.pct, "attack": attack_id})


# ---------------------------------------------------------------- objetos e estrutura

func _step_props() -> void:
	var targets := []
	for f in fighters:
		if _hittable(f) and f.held_by < 0:
			targets.append({"id": f.id, "box": _box(f)})
	for e in props.step(grid, targets):
		if e.kind == "prop_hit":
			var v: Dictionary = fighters[e.target]
			var sp: int = maxi(1, C.isqrt(e.vx * e.vx + e.vy * e.vy))
			if v.shielding:
				_shield_hit(e.thrower, signi(e.vx) if e.vx != 0 else 1, v, e.dmg, sp / 2, 4, false)
			else:
				# Levanta um pouco o alvo para o lançamento não morrer no chão.
				var dy: int = mini(e.vy * 1024 / sp - 300, -200)
				_launch(e.thrower, v, e.dmg, 500 + sp / 4, 10, e.vx * 1024 / sp, dy, 5, -1)
		elif e.kind == "prop_explode":
			for f in fighters:
				if f.hold_prop == e.prop:
					f.hold_prop = -1
		_emit(e.kind, e.get("thrower", -1), e)
		if e.kind == "prop_explode":
			_explode(e.x, e.y, Fixtures.PROP_EXPL_RADIUS, "botijao_objeto")
	_apply_prop_jets()


func _apply_prop_jets() -> void:
	## Extintor disparando: jato horizontal de 64 px empurra lutadores na frente do bico.
	for p in props.props:
		var j: Array = props.jet_of(p)
		if j.is_empty():
			continue
		var jet := {"x": j[0], "y": j[1], "dx": j[2] * 1024, "dy": 0, "len": 64 * C.SUB, "w": 12 * C.SUB}
		for f in fighters:
			if f.stocks > 0 and f.respawn == 0 and f.held_by < 0 and f.id != p.holder and fixtures.jet_hits(jet, _box(f)):
				_push(f, j[2] * 200, 0, 1400, j[2] * 1024, 0)


func _push(f: Dictionary, ax: int, ay: int, cap: int, dx: int, dy: int) -> void:
	## Jato: acelera ao longo de (dx, dy) enquanto a velocidade nessa direção for menor que `cap`.
	if (f.vx * dx + f.vy * dy) / 1024 >= cap:
		return
	f.vx += ax
	f.vy += ay
	if ay < 0 and f.has("grounded"):
		f.grounded = 0


func _explode(x: int, y: int, radius: int, source: String) -> void:
	## Explosão de elemento do cenário: mesma regra da explosão especial (células no raio, lutadores
	## e objetos lançados para fora do centro com viés para cima), com dano moderado e sem autor.
	var center := {"x": x, "y": y, "h": 0, "facing": 1}
	var rr: int = radius * C.SUB
	var cells := _cells_in_circle(grid.cells_in_rect(x - rr, y - rr, x + rr, y + rr), x, y, radius)
	_emit("explosion", -1, {"x": x, "y": y, "radius": radius, "source": source})
	if not cells.is_empty():
		var broken := grid.damage(cells, Fixtures.EXPL_CELL_DMG * cells.size())
		if not broken.is_empty():
			_emit("break", -1, {"cells": broken, "mats": grid.last_mats, "axis": 0, "dir": 1, "e": 0, "r": 0})
	for v in fighters:
		if not _hittable(v) or not _in_radius(center, radius, _box(v)):
			continue
		var d := _radial_dir(center, v)
		if v.shielding:
			_shield_hit(-1, 1 if d[0] >= 0 else -1, v, Fixtures.EXPL_DMG, Fixtures.EXPL_BASE, 6, false)
		else:
			_launch(-1, v, Fixtures.EXPL_DMG, Fixtures.EXPL_BASE, Fixtures.EXPL_GROWTH, d[0], d[1], 6, -1)
	for pid in props.in_rect(x - rr, y - rr, x + rr, y + rr):
		var p: Dictionary = props.props[pid]
		if not _in_radius(center, radius, props.box_of(p)):
			continue
		var kb: int = (Fixtures.EXPL_BASE + 40 * Fixtures.EXPL_GROWTH) * 100 / maxi(40, p.mass)
		var d := _radial_dir(center, {"x": p.x, "y": p.y, "h": p.h})
		var ignite: bool = p.kind != Props.BOTIJAO or p.fx_used != 0 or fixtures.chain_take()
		props.strike(pid, d[0] * kb / 1024, d[1] * kb / 1024 - 256, -1, 20, ignite)
	freeze = maxi(freeze, 6)
	_apply_fixture_events(fixtures.blast(x, y, radius, true))


func _step_fixtures() -> void:
	## Fixos do cenário (fixtures.gd): âncoras, contato de corpo lançado/objeto arremessado, timers,
	## ignição e efeitos (jatos, fogo, choque, explosão) aplicados aqui.
	var targets := []
	for f in fighters:
		if f.stocks <= 0 or f.respawn > 0 or f.held_by >= 0:
			continue
		targets.append({"kind": 0, "id": f.id, "box": _box(f), "vx": f.vx, "vy": f.vy,
			"moving": f.hitstun > 0 and f.vx * f.vx + f.vy * f.vy >= 768 * 768, "hurt": _hittable(f), "botijao": false})
	for p in props.props:
		if p.state != Props.FREE and p.state != Props.THROWN:
			continue
		targets.append({"kind": 1, "id": p.id, "box": props.box_of(p), "vx": p.vx, "vy": p.vy,
			"moving": p.state == Props.THROWN and p.vx * p.vx + p.vy * p.vy >= 512 * 512, "hurt": false,
			"botijao": p.kind == Props.BOTIJAO and p.fx_used == 0})
	_apply_fixture_events(fixtures.step(grid, targets))


func _apply_fixture_events(evs: Array) -> void:
	for e in evs:
		match e.kind:
			"fix_push":
				if e.has("target"):
					_push(fighters[e.target], e.ax, e.ay, e.cap, e.dx, e.dy)
				else:
					var p: Dictionary = props.props[e.prop]
					if p.state == Props.FREE or p.state == Props.THROWN:
						_push(p, e.ax / 2, e.ay / 2, e.cap / 2, e.dx, e.dy)
			"fix_hurt":
				var v: Dictionary = fighters[e.target]
				if not _hittable(v):
					continue
				if e.kb == 0:
					v.pct += e.dmg
				elif v.shielding:
					_shield_hit(-1, 1 if e.dx >= 0 else -1, v, e.dmg, e.kb, 0, false)
				else:
					_launch(-1, v, e.dmg, e.kb, 0, e.dx, e.dy, 0, -1)
					v.hitstun = maxi(v.hitstun, e.stun)
				_emit("fix_hurt", -1, e)
			"fix_ignite_prop":
				if fixtures.chain_take():
					props.ignite(e.prop)
			"fix_explode":
				_explode(e.x, e.y, Fixtures.EXPL_RADIUS, "botijao_fixo")
			_:
				_emit(e.kind, -1, e)


func _step_structure() -> void:
	var blocked := []
	for f in fighters:
		if f.stocks > 0 and f.respawn == 0:
			blocked.append(_box(f))
	# Entulho também não assenta dentro de objetos parados.
	for p in props.props:
		if p.state == 0 or p.state == 2:
			blocked.append(props.box_of(p))
	_crush_check()
	for e in structure.step(grid, blocked):
		_emit(e.kind, -1, e)
	# Entulho nunca enterra: quem ficou dentro de matéria sobe até o primeiro espaço livre.
	for f in fighters:
		if f.stocks > 0 and f.respawn == 0 and overlaps_solid(f):
			_unstick(f)


func _crush_check() -> void:
	## Ilha caindo esmaga quem está embaixo (§4.3). Um acerto por ilha por lutador. A caixa do alvo
	## é estendida para cima pela queda deste tick, então o contato no tick do assentamento conta.
	for isl in structure.islands:
		if isl.state != 1:
			continue
		var reach: int = maxi(0, isl.vy) + C.CELL_SUB
		for p in props.props:
			if p.state != 0 and p.state != 2:
				continue
			var pb: Array = props.box_of(p)
			if structure.island_overlaps(isl, pb[0], pb[1] - reach, pb[2], pb[3]):
				# Objeto embaixo da ilha é arremessado para baixo e para o lado (e costuma quebrar).
				props.strike(p.id, 256 if p.x >= _island_center_x(isl) else -256, maxi(isl.vy, 512), -1, 12)
		for f in fighters:
			if not _hittable(f) or (isl.hit_mask & (1 << f.id)) != 0:
				continue
			var b := _box(f)
			if not structure.island_overlaps(isl, b[0], b[1] - reach, b[2], b[3]):
				continue
			isl.hit_mask |= 1 << f.id
			if f.pct >= C.ENV_KO_PCT and f.grounded:
				# KO ambiental (§5.4): soterrado com percentual alto. Anunciado pelo aviso da ilha.
				_emit("buried", f.id, {"island": isl.id})
				_lose_stock(f)
				continue
			var dmg: int = mini(C.CRUSH_DMG_MAX, C.CRUSH_DMG + isl.mass / C.CRUSH_MASS_DIV)
			var side: int = 1 if f.x >= _island_center_x(isl) else -1
			_launch(-1, f, dmg, 700 + isl.vy / 2, 12, side * 700, 730, 6, -1)
			_emit("crushed", f.id, {"island": isl.id, "dmg": dmg})


func _island_center_x(isl: Dictionary) -> int:
	var sum := 0
	for i in isl.cells:
		sum += (i % C.GRID_W) * C.CELL_SUB + C.CELL_SUB / 2
	return sum / maxi(1, isl.cells.size())


func _unstick(f: Dictionary) -> void:
	var y0: int = f.y
	var x0: int = f.x
	# Primeiro para cima (até 12 células), depois para os lados, alternando.
	var base: int = C.fdiv(y0, C.CELL_SUB) * C.CELL_SUB
	for k in C.GRID_H + 8:
		f.y = base - k * C.CELL_SUB
		if not overlaps_solid(f):
			f.vy = mini(f.vy, 0)
			return
	# Coluna toda tomada (não acontece no distrito atual): procura para os lados na altura original.
	f.y = y0
	for k in range(1, C.GRID_W):
		for s in [-1, 1]:
			f.x = x0 + s * k * C.CELL_SUB
			if not overlaps_solid(f):
				return
	# Último recurso: acima da grade, que é sempre vazio.
	f.x = x0
	f.y = -C.CELL_SUB


# ---------------------------------------------------------------- stocks

func _check_blast(f: Dictionary) -> void:
	if f.stocks <= 0 or f.respawn > 0:
		return
	if f.x < C.BLAST_LEFT or f.x > C.BLAST_RIGHT or f.y < C.BLAST_TOP or f.y - f.h > C.BLAST_BOTTOM:
		_lose_stock(f)


func _lose_stock(f: Dictionary) -> void:
	_free_hands(f)
	if f.held_by >= 0:
		_release_grab(fighters[f.held_by])
	f.stocks -= 1
	_emit("ko", f.id, {"x": f.x, "y": f.y, "stocks": f.stocks})
	if f.stocks > 0:
		f.respawn = C.RESPAWN_DELAY
		f.vx = 0
		f.vy = 0
	else:
		var alive := []
		for o in fighters:
			if o.stocks > 0:
				alive.append(o.id)
		if alive.size() == 1:
			winner = alive[0]
			_emit("match_end", winner, {})


func _respawn(f: Dictionary) -> void:
	f.x = C.SPAWN_X[f.id]
	f.y = C.RESPAWN_Y
	f.vx = 0
	f.vy = 0
	f.pct = 0
	f.hitstun = 0
	f.attack = A.NONE
	f.invuln = C.RESPAWN_INVULN
	f.breaks = 0
	f.grounded = 0
	f.shield = C.SHIELD_MAX
	f.shielding = 0
	f.lag = 0
	f.stun = 0
	f.dodge = 0
	f.dodge_kind = DODGE_NONE
	f.intang = 0
	f.burst_cd = 0
	f.coyote = 0
	f.buf = 0
	f.buf_t = 0
	# Se o ponto de volta foi soterrado, sobe até achar ar livre.
	while overlaps_solid(f) and f.y > 0:
		f.y -= C.CELL_SUB
	_emit("respawn", f.id, {})


# ---------------------------------------------------------------- eventos, hash e snapshot

func _emit(kind: String, emitter: int, data: Dictionary) -> void:
	# (tick, emitter_id, sequence, kind): a apresentação deduplica por essa chave (§10).
	data.tick = tick
	data.emitter = emitter
	data.seq = _seq
	data.kind = kind
	_seq += 1
	events.append(data)


func state_hash() -> String:
	var ints := PackedInt64Array([tick, freeze, winner, _seq, int(grid.struct_dirty)])
	for f in fighters:
		ints.append(C.FIGHTERS.keys().find(f.def))
		ints.append(f.hw)
		ints.append(f.h)
		for k in FIGHTER_KEYS:
			ints.append(int(f[k]))
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(ints.to_byte_array())
	ctx.update(grid.mat)
	ctx.update(grid.hp.to_byte_array())
	ctx.update(structure.hash_ints().to_byte_array())
	ctx.update(props.hash_ints().to_byte_array())
	ctx.update(fixtures.hash_ints().to_byte_array())
	return ctx.finish().hex_encode().substr(0, 16)


func snapshot() -> Dictionary:
	return {"tick": tick, "freeze": freeze, "winner": winner, "seq": _seq,
		"fighters": fighters.duplicate(true), "mat": grid.mat.duplicate(), "hp": grid.hp.duplicate(),
		"struct_dirty": grid.struct_dirty, "structure": structure.snapshot(), "props": props.snapshot(),
		"fixtures": fixtures.snapshot()}


func restore(s: Dictionary) -> void:
	tick = s.tick
	freeze = s.freeze
	winner = s.winner
	_seq = s.seq
	fighters = s.fighters.duplicate(true)
	grid.mat = s.mat.duplicate()
	grid.hp = s.hp.duplicate()
	grid.struct_dirty = s.struct_dirty
	structure.restore(s.structure)
	props.restore(s.props)
	fixtures.restore(s.fixtures)
	grid.changed.clear()
	grid.full_dirty = true
	events.clear()
