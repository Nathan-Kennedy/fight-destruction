extends RefCounted
## Objetos autoritativos. Âncora no centro dos pés; caixas [l,r) × [t,b).

const C = preload("res://sim/sim_const.gd")

const FREE := 0
const HELD := 1
const THROWN := 2
const BROKEN := 3
const GRAVITY := 96
const MAX_FALL := 12 * C.SUB
const MAX_THROWN_FALL := 24 * C.SUB
const MOVE_GUARD := 64
const UNSTUCK_CELLS := 12
const FRICTION := 64
const STOP_SPEED := C.BOUNCE_MIN
const HIT_MIN := 2 * C.SUB
const HIT_REST := 500
const IMPACT_HP_DIV := 40
const HIT_HP := 8
const KINDS := [
	{"name": "caixa", "w": 16, "h": 16, "mass": 30, "hp": 35, "dmg": 6, "throw_mul": 1000},
	{"name": "barril", "w": 14, "h": 20, "mass": 65, "hp": 85, "dmg": 9, "throw_mul": 850},
	{"name": "maquina", "w": 24, "h": 40, "mass": 160, "hp": 220, "dmg": 14, "throw_mul": 550},
	# Elementos reativos (Docs/design_elementos_reativos.md). Botijão: qualquer dano acende o pavio
	# (chia e pisca) e ele explode FUSE ticks depois, mesmo na mão de alguém. Extintor: golpeado ou
	# arremessado dispara um jato no sentido do movimento por JET_T ticks (uma vez).
	{"name": "botijao", "w": 14, "h": 22, "mass": 45, "hp": 60, "dmg": 8, "throw_mul": 900},
	{"name": "extintor", "w": 10, "h": 20, "mass": 30, "hp": 50, "dmg": 7, "throw_mul": 1000},
]
const BOTIJAO := 3
const EXTINTOR := 4
const FUSE := 70              # ticks de aviso do botijão (≈ 1,2 s)
const JET_T := 90             # ticks de jato do extintor
const JET_RECOIL := 20        # sub/tick² contra o movimento enquanto o jato sai
const PROP_KEYS := ["id", "kind", "x", "y", "vx", "vy", "hw", "h", "mass", "hp", "state",
	"holder", "thrower", "hit_mask", "breaks", "t", "fx", "fx_dir", "fx_used"]

var props: Array = []
# strike() não retorna eventos: a quebra sai no próximo step(), uma única vez.
var _pending: Array = []


func setup_test_district() -> void:
	props.clear()
	_pending.clear()
	# Rua, loja, fundos e sobreloja. Começam a 8 px do apoio.
	var placements := [[0, 200, 408], [1, 440, 408], [0, 552, 408],
		[2, 760, 408], [0, 480, 264], [1, 744, 264], [BOTIJAO, 690, 264], [EXTINTOR, 792, 264]]
	for a in placements:
		var d: Dictionary = KINDS[a[0]]
		props.append({"id": props.size(), "kind": a[0], "x": a[1] * C.SUB, "y": a[2] * C.SUB,
			"vx": 0, "vy": 0, "hw": d.w * C.SUB / 2, "h": d.h * C.SUB,
			"mass": d.mass, "hp": d.hp, "state": FREE, "holder": -1, "thrower": -1,
			"hit_mask": 0, "breaks": 0, "t": 0, "fx": 0, "fx_dir": 0, "fx_used": 0})


func step(grid, targets: Array) -> Array:
	var events: Array = _pending
	_pending = []
	var ordered: Array = targets.duplicate()
	ordered.sort_custom(_by_id)
	for p in props:
		_step_fx(p, events)
		if p.state == HELD or p.state == BROKEN:
			continue
		if _check_blast(p, events):
			continue
		_unstuck(grid, p)
		if _check_blast(p, events):
			continue
		p.t += 1
		if p.vy >= 0 and _solid_below(grid, p):
			p.vx = signi(p.vx) * maxi(0, absi(p.vx) - FRICTION)
		p.vy = mini(p.vy + GRAVITY, MAX_FALL if p.state == FREE else MAX_THROWN_FALL)
		_hit_targets(p, ordered, events)
		_move_axis(grid, p, 0, p.vx, ordered, events)
		_move_axis(grid, p, 1, p.vy, ordered, events)
		if p.state == THROWN and _solid_below(grid, p) and p.vx * p.vx + p.vy * p.vy < STOP_SPEED * STOP_SPEED:
			p.state = FREE
	return events


func find_grabbable(l: int, t: int, r: int, b: int) -> int:
	var ids := in_rect(l, t, r, b)
	return -1 if ids.is_empty() else int(ids[0])


func grab(pid: int, holder: int) -> void:
	var p := _get_prop(pid)
	if p.is_empty() or p.state == HELD or p.state == BROKEN:
		return
	p.state = HELD
	p.holder = holder
	p.vx = 0
	p.vy = 0
	p.t = 0


func hold_at(pid: int, x: int, y: int) -> void:
	var p := _get_prop(pid)
	if not p.is_empty() and p.state == HELD:
		p.x = x
		p.y = y


func throw(pid: int, vx: int, vy: int, thrower: int) -> void:
	var p := _get_prop(pid)
	if p.is_empty() or p.state == BROKEN:
		return
	_launch(p, vx, vy, thrower)


func drop(pid: int) -> void:
	var p := _get_prop(pid)
	if p.is_empty() or p.state != HELD:
		return
	p.state = FREE
	p.holder = -1
	p.thrower = -1
	p.vx = 0
	p.vy = 0
	p.hit_mask = 0
	p.breaks = 0
	p.t = 0


func strike(pid: int, vx: int, vy: int, attacker: int, dmg: int, ignite := true) -> void:
	## ignite = false: um botijão atingido não acende o pavio (limite de cadeia de explosões).
	var p := _get_prop(pid)
	if p.is_empty() or p.state == HELD or p.state == BROKEN:
		return
	_launch(p, vx, vy, attacker)
	p.hp -= maxi(0, dmg)
	if ignite:
		_damaged(p, _pending)
	elif p.kind == BOTIJAO:
		p.hp = maxi(p.hp, 1)
	_break_if_dead(p, _pending)


func ignite(pid: int) -> void:
	## Fogo/explosão externos acendem o pavio de um botijão (quem chama já consumiu a cadeia).
	var p := _get_prop(pid)
	if not p.is_empty() and p.state != BROKEN:
		_damaged(p, _pending)


func jet_of(p: Dictionary) -> Array:
	## Jato do extintor ativo: [x, y, dir] (origem no bico, dir ±1) ou [] sem jato.
	if p.kind != EXTINTOR or p.fx <= 0 or p.state == BROKEN:
		return []
	return [p.x + p.fx_dir * p.hw, p.y - p.h * 2 / 3, p.fx_dir]


func in_rect(l: int, t: int, r: int, b: int) -> Array:
	var ids: Array = []
	if l >= r or t >= b:
		return ids
	for p in props:
		if p.state != HELD and p.state != BROKEN and _overlaps(box_of(p), [l, t, r, b]):
			ids.append(p.id)
	return ids


func box_of(p: Dictionary) -> Array:
	return [p.x - p.hw, p.y - p.h, p.x + p.hw, p.y]


func throw_mul(pid: int) -> int:
	var p := _get_prop(pid)
	return 1000 if p.is_empty() else int(KINDS[p.kind].throw_mul)


func hash_ints() -> PackedInt64Array:
	var ints := PackedInt64Array([props.size()])
	for p in props:
		for key in PROP_KEYS:
			ints.append(int(p[key]))
	ints.append(_pending.size())
	for e in _pending:
		ints.append(e.kind.hash())
		for key in ["prop", "x", "y", "kind_id"]:
			ints.append(int(e[key]))
	return ints


func snapshot() -> Dictionary:
	return {"props": props.duplicate(true), "pending": _pending.duplicate(true)}


func restore(s: Dictionary) -> void:
	props = s.props.duplicate(true)
	props.sort_custom(_by_id)
	_pending = s.pending.duplicate(true)


func _by_id(a: Dictionary, b: Dictionary) -> bool:
	return a.id < b.id


func _get_prop(pid: int) -> Dictionary:
	for p in props:
		if p.id == pid:
			return p
	return {}


func _launch(p: Dictionary, vx: int, vy: int, thrower: int) -> void:
	p.state = THROWN
	p.holder = -1
	p.thrower = thrower
	p.vx = vx
	p.vy = vy
	p.hit_mask = 0
	p.breaks = 0
	p.t = 0
	if p.kind == EXTINTOR and p.fx_used == 0:
		# Bico estoura: jato no sentido do movimento (empurra quem está na frente).
		p.fx_used = 1
		p.fx = JET_T
		p.fx_dir = 1 if vx >= 0 else -1
		_pending.append({"kind": "prop_jet", "prop": p.id, "x": p.x, "y": p.y, "kind_id": p.kind, "dir": p.fx_dir})


func _damaged(p: Dictionary, events: Array) -> void:
	## Botijão: o primeiro dano acende o pavio (aviso), uma vez só.
	if p.kind != BOTIJAO or p.fx_used != 0 or p.state == BROKEN:
		return
	p.fx_used = 1
	p.fx = FUSE
	p.hp = maxi(p.hp, 1)
	events.append({"kind": "prop_fuse", "prop": p.id, "x": p.x, "y": p.y, "kind_id": p.kind})


func _step_fx(p: Dictionary, events: Array) -> void:
	## Pavio do botijão e jato do extintor correm mesmo com o objeto na mão.
	if p.fx <= 0 or p.state == BROKEN:
		return
	p.fx -= 1
	if p.kind == BOTIJAO:
		if p.fx == 0:
			p.hp = 0
			p.state = BROKEN
			p.vx = 0
			p.vy = 0
			events.append({"kind": "prop_explode", "prop": p.id, "x": p.x, "y": p.y - p.h / 2, "kind_id": p.kind,
				"thrower": p.thrower, "holder": p.holder})
			p.holder = -1
	elif p.kind == EXTINTOR and p.state != HELD:
		# Recuo leve contra o jato.
		p.vx -= p.fx_dir * JET_RECOIL


func _break_if_dead(p: Dictionary, events: Array, lost := false) -> void:
	if p.hp > 0 or p.state == BROKEN:
		return
	if p.kind == BOTIJAO and not lost:
		# Botijão não some sem aviso: segura com 1 de HP até o pavio terminar.
		p.hp = 1
		_damaged(p, events)
		return
	p.hp = 0
	p.state = BROKEN
	p.holder = -1
	p.vx = 0
	p.vy = 0
	events.append({"kind": "prop_break", "prop": p.id, "x": p.x, "y": p.y, "kind_id": p.kind})


func _overlaps(a: Array, b: Array) -> bool:
	return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


func _check_blast(p: Dictionary, events: Array) -> bool:
	# Mesma convenção de âncora dos lutadores: no fundo, sai o topo da caixa.
	if p.state == BROKEN:
		return true
	if p.x < C.BLAST_LEFT or p.x > C.BLAST_RIGHT or p.y < C.BLAST_TOP or p.y - p.h > C.BLAST_BOTTOM:
		p.hp = 0
		_break_if_dead(p, events, true)
		events[-1]["lost"] = 1
		return true
	return false


func _inside_matter(grid, p: Dictionary) -> bool:
	var b := box_of(p)
	return grid.any_solid_in_rect(b[0], b[1], b[2], b[3])


func _unstuck(grid, p: Dictionary) -> void:
	if not _inside_matter(grid, p):
		return
	var x0: int = p.x
	var y0: int = p.y
	for distance in range(1, UNSTUCK_CELLS + 1):
		p.y = y0 - distance * C.CELL_SUB
		if not _inside_matter(grid, p):
			return
	p.y = y0
	# Sem saída acima: esquerda, direita, depois a próxima distância.
	for distance in range(1, UNSTUCK_CELLS + 1):
		for direction in [-1, 1]:
			p.x = x0 + direction * distance * C.CELL_SUB
			if not _inside_matter(grid, p):
				return
	# Busca limitada sem destino livre: preserva a posição para tentar no próximo tick.
	p.x = x0


func _hit_targets(p: Dictionary, targets: Array, events: Array) -> bool:
	if p.state != THROWN:
		return false
	var speed := C.isqrt(p.vx * p.vx + p.vy * p.vy)
	if speed < HIT_MIN:
		return false
	for target in targets:
		var fid: int = target.id
		# IDs dos lutadores são índices do bitmask (0..63).
		if fid < 0 or fid > 63 or fid == p.thrower or (p.hit_mask & (1 << fid)) != 0:
			continue
		if not _overlaps(box_of(p), target.box):
			continue
		p.hit_mask |= 1 << fid
		var d: Dictionary = KINDS[p.kind]
		var dmg: int = d.dmg + speed / C.SUB
		events.append({"kind": "prop_hit", "prop": p.id, "target": fid, "thrower": p.thrower,
			"dmg": dmg, "vx": p.vx, "vy": p.vy})
		p.vx = -p.vx * HIT_REST / 1000
		p.vy = -p.vy * HIT_REST / 1000
		p.hp -= HIT_HP
		_damaged(p, events)
		_break_if_dead(p, events)
		return true
	return false


func _move_axis(grid, p: Dictionary, axis: int, amount: int, targets: Array, events: Array) -> void:
	var remaining := amount
	var guard := 0
	while remaining != 0 and p.state != BROKEN and guard < MOVE_GUARD:
		guard += 1
		var stepv := clampi(remaining, -C.MAX_STEP, C.MAX_STEP)
		var hit := _probe(grid, p, axis, stepv)
		if hit.is_empty():
			if axis == 0:
				p.x += stepv
			else:
				p.y += stepv
			remaining -= stepv
			if _check_blast(p, events):
				return
			if _hit_targets(p, targets, events):
				return
			continue
		var before: int = p.x if axis == 0 else p.y
		_flush(p, axis, stepv, hit.line)
		remaining -= (p.x if axis == 0 else p.y) - before
		var vn: int = p.vx if axis == 0 else p.vy
		if p.state == THROWN and absi(vn) >= C.BOUNCE_MIN:
			var old_speed := absi(vn)
			var through := _impact(grid, p, axis, hit.cells, events)
			if _hit_targets(p, targets, events):
				return
			if through:
				var new_speed := absi(int(p.vx) if axis == 0 else int(p.vy))
				remaining = remaining * new_speed / maxi(1, old_speed)
				continue
			return
		if axis == 0:
			p.vx = 0
		else:
			p.vy = 0
		_hit_targets(p, targets, events)
		return


func _probe(grid, p: Dictionary, axis: int, stepv: int) -> Dictionary:
	var b := box_of(p)
	var cs := C.CELL_SUB
	var lines: Array = []
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
		for k in range(a0, a1 + 1):
			var cx: int = line if axis == 0 else k
			var cy: int = k if axis == 0 else line
			if grid.get_mat(cx, cy) != C.M_EMPTY:
				cells.append(grid.index(cx, cy))
		if not cells.is_empty():
			return {"line": line, "cells": cells}
	return {}


func _flush(p: Dictionary, axis: int, stepv: int, line: int) -> void:
	if axis == 0:
		p.x = line * C.CELL_SUB - p.hw if stepv > 0 else (line + 1) * C.CELL_SUB + p.hw
	else:
		p.y = line * C.CELL_SUB if stepv > 0 else (line + 1) * C.CELL_SUB + p.h


func _impact(grid, p: Dictionary, axis: int, cells: PackedInt32Array, events: Array) -> bool:
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
	var vn: int = p.vx if axis == 0 else p.vy
	# Só a energia normal paga ruptura, dano acumulado e desgaste no quique.
	# Altera trajetórias/hashes de replays anteriores; regressões em props_tests.gd.
	var e := C.energy(p.mass, vn, 0)
	var dir := signi(vn)
	if not core and p.breaks < C.MAX_BREAKS and absi(vn) >= min_v and e >= r:
		grid.destroy(cells)
		p.breaks += 1
		var e2 := (e - r) * (1000 - absorb) / 1000
		var ratio := C.isqrt(e2 * 1048576 / maxi(1, e))
		# A tangente conserva energia salvo absorção: não paga a resistência R.
		var tangent_ratio := C.isqrt((1000 - absorb) * 1048576 / 1000)
		if axis == 0:
			p.vx = p.vx * ratio / 1024
			p.vy = p.vy * tangent_ratio / 1024
		else:
			p.vy = p.vy * ratio / 1024
			p.vx = p.vx * tangent_ratio / 1024
		events.append({"kind": "break", "prop": p.id, "cells": cells, "mats": grid.last_mats.duplicate(),
			"axis": axis, "dir": dir, "e": e, "r": r})
		# HP: custo da matéria rompida / 40; no quique, energia incidente / 40. Mínimo 1.
		p.hp -= maxi(1, r / IMPACT_HP_DIV)
		_damaged(p, events)
		_break_if_dead(p, events)
		return p.state != BROKEN
	if not core and absi(vn) * 2 >= min_v:
		var broken: PackedInt32Array = grid.damage(cells, e)
		if not broken.is_empty():
			events.append({"kind": "break", "prop": p.id, "cells": broken, "mats": grid.last_mats.duplicate(),
				"axis": axis, "dir": dir, "e": e, "r": r})
	var bounced := -vn * rest / 1000
	if absi(bounced) < C.BOUNCE_MIN:
		bounced = 0
	if axis == 0:
		p.vx = bounced
		p.vy = p.vy * 4 / 5
	else:
		p.vy = bounced
		p.vx = p.vx * 4 / 5
	events.append({"kind": "prop_bounce", "prop": p.id, "e": e})
	p.hp -= maxi(1, e / IMPACT_HP_DIV)
	_damaged(p, events)
	_break_if_dead(p, events)
	return false


func _solid_below(grid, p: Dictionary) -> bool:
	return p.y % C.CELL_SUB == 0 and grid.any_solid_in_rect(p.x - p.hw, p.y, p.x + p.hw, p.y + 1)
