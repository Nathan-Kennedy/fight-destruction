extends RefCounted
## Estrutura, colapso e escombro (§4.2–§4.4). Tudo inteiro, determinístico, sem nós.
## Apoio: BFS 0-1 a partir do núcleo (passo horizontal custa 1, vertical 0) limitado a SPAN.
## O que perde apoio vira ilha: aviso (racha), queda por translação vertical, assenta como entulho.
## Entulho cai como areia mínima. A análise só roda quando `grid.struct_dirty` está ligado.

const C = preload("res://sim/sim_const.gd")

# Ajuste (decididos no pacote M2).
# SPAN: o pacote propunha 40, mas o prédio intacto já tem a fachada (x 44) a 44 células do pilar
# (x 88); com 40 a frente flutuaria no mapa de origem. 45 mantém o prédio de pé e, sem o pilar,
# a parede dos fundos (x 102) só segura até x 57: a frente (x 44..56) cai.
const SPAN := 45              # soma máxima de passos horizontais até uma âncora
const WARN_TICKS := 50        # ticks de aviso antes de cair
const GRAVITY := 32           # sub/tick²
const VY_MAX := 2048          # teto de queda, sub/tick
const CELL_MASS := 20         # massa por célula de ilha
const RUBBLE_MAX := 1200      # entulho máximo no mapa; excesso vira poeira
const SAND_EVERY := 2         # entulho anda uma célula a cada N ticks

const W := C.GRID_W
const H := C.GRID_H
const N := C.GRID_W * C.GRID_H
const CS := C.CELL_SUB
const FAR := 1 << 30

var islands: Array = []       # ilhas em aviso ou caindo, ordem por id
var next_id := 1
var tick := 0
var active := PackedInt32Array()   # entulho que ainda pode andar (sem ordem; `_act` evita repetição)
var pins := PackedInt32Array()     # células que já flutuavam no setup (ex.: marquise): âncoras

var _act := PackedByteArray()      # 1 = está em `active`
var _mark := PackedByteArray()     # 1 = pertence a ilha em aviso
var _dist := PackedInt32Array()
var _sup := PackedByteArray()      # 1 = apoiada (núcleo, estrutural no vão, folha encostada, pino)
var _core_edge := PackedInt32Array()


func setup(grid) -> void:
	islands = []
	next_id = 1
	tick = 0
	active = PackedInt32Array()
	_act = PackedByteArray()
	_act.resize(N)
	_mark = PackedByteArray()
	_mark.resize(N)
	_dist = PackedInt32Array()
	_dist.resize(N)
	_sup = PackedByteArray()
	_sup.resize(N)
	pins = PackedInt32Array()
	# Núcleo que encosta em não-núcleo: sementes do BFS. O núcleo é indestrutível: não muda.
	_core_edge = PackedInt32Array()
	var mat: PackedByteArray = grid.mat
	var i := mat.find(C.M_CORE)
	while i >= 0:
		var x := i % W
		if (x > 0 and mat[i - 1] != C.M_CORE) or (x < W - 1 and mat[i + 1] != C.M_CORE) \
				or (i >= W and mat[i - W] != C.M_CORE) or (i + W < N and mat[i + W] != C.M_CORE):
			_core_edge.append(i)
		i = mat.find(C.M_CORE, i + 1)
	# O que já flutua no mapa de origem é cenário preso: vira âncora (senão cairia no 1º dano).
	pins = unsupported(grid)


static func _leaf(m: int) -> bool:
	return m == C.M_GLASS or m == C.M_DRYWALL


func step(grid, blocked: Array) -> Array:
	var events := []
	if grid.struct_dirty:
		_analyze(grid, events)
		grid.struct_dirty = false
	var keep := []
	for isl in islands:
		var d: Dictionary = isl
		if d.state == 0:
			d.t += 1
			if d.t >= WARN_TICKS:
				_start_fall(grid, d)
				events.append({"kind": "collapse_fall", "island": d.id})
			keep.append(d)
		else:
			d.t += 1
			if not _fall(grid, d, blocked, events):
				keep.append(d)
	islands = keep
	if tick % SAND_EVERY == 0:
		_sand(grid, blocked)
	tick += 1
	return events


# ---------------------------------------------------------------- análise

static func _solid_cells(mat: PackedByteArray) -> PackedInt32Array:
	## Índices de vidro, divisória, tijolo e concreto (agrupados por material, não ordenados).
	## Varredura nativa com find(): o laço em GDScript só visita células sólidas.
	var out := PackedInt32Array()
	for m in [C.M_GLASS, C.M_DRYWALL, C.M_BRICK, C.M_CONCRETE]:
		var i := mat.find(m)
		while i >= 0:
			out.append(i)
			i = mat.find(m, i + 1)
	return out


func _support(grid, cells: PackedInt32Array) -> void:
	## Preenche `_sup`. BFS 0-1 em camadas de distância: `cur` recebe passos verticais (custo 0),
	## `nxt` os horizontais (custo 1). Entradas velhas (dist já menor) são puladas.
	## `dist` = -1 para o que não é nó (só tijolo/concreto fora de ilha em aviso são nós), então
	## `dist[n] > d` já filtra material e marca. Tudo em variáveis locais: é o laço quente.
	var mat: PackedByteArray = grid.mat
	var mark := _mark
	var dist := _dist
	var sup := _sup
	dist.fill(-1)
	sup.fill(0)
	var leafc := PackedInt32Array()
	for i in cells:
		if mark[i] == 0:
			var m: int = mat[i]
			if m >= C.M_BRICK:
				dist[i] = FAR
			else:
				leafc.append(i)
	var cur := PackedInt32Array()
	for i in _core_edge:
		dist[i] = 0
		sup[i] = 1
		cur.append(i)
	for i in pins:
		var m: int = mat[i]
		if m >= C.M_GLASS and m <= C.M_CONCRETE and mark[i] == 0:
			sup[i] = 1
			if m >= C.M_BRICK:
				dist[i] = 0
				cur.append(i)
	var d := 0
	while not cur.is_empty():
		var nxt := PackedInt32Array()
		var d1 := d + 1
		var horiz := d < SPAN
		var k := 0
		while k < cur.size():
			var i: int = cur[k]
			k += 1
			if dist[i] != d:
				continue
			var n := i - W
			if n >= 0 and dist[n] > d:
				dist[n] = d
				sup[n] = 1
				cur.append(n)
			n = i + W
			if n < N and dist[n] > d:
				dist[n] = d
				sup[n] = 1
				cur.append(n)
			if horiz:
				var x := i % W
				n = i - 1
				if x > 0 and dist[n] > d1:
					dist[n] = d1
					sup[n] = 1
					nxt.append(n)
				n = i + 1
				if x < W - 1 and dist[n] > d1:
					dist[n] = d1
					sup[n] = 1
					nxt.append(n)
		cur = nxt
		d = d1
	# Folhas: apoiadas se encostam (direto ou via folhas) numa célula apoiada. Não repassam apoio
	# a estruturais (o BFS acima já terminou).
	var leaves := PackedInt32Array()
	for i in leafc:
		if sup[i] == 0:
			var x := i % W
			if (i >= W and sup[i - W] == 1) or (i + W < N and sup[i + W] == 1) \
					or (x > 0 and sup[i - 1] == 1) or (x < W - 1 and sup[i + 1] == 1):
				sup[i] = 1
				leaves.append(i)
	var k2 := 0
	while k2 < leaves.size():
		var i: int = leaves[k2]
		k2 += 1
		var x := i % W
		for dn in 4:
			var n := -1
			if dn == 0 and i >= W:
				n = i - W
			elif dn == 1 and i + W < N:
				n = i + W
			elif dn == 2 and x > 0:
				n = i - 1
			elif dn == 3 and x < W - 1:
				n = i + 1
			if n >= 0 and sup[n] == 0 and mark[n] == 0 and (mat[n] == C.M_GLASS or mat[n] == C.M_DRYWALL):
				sup[n] = 1
				leaves.append(n)
	_dist = dist
	_sup = sup


func unsupported(grid) -> PackedInt32Array:
	## Células de estrutura/folha sem apoio e fora de ilhas em aviso (crescente). Testes e depuração.
	var cells := _solid_cells(grid.mat)
	_support(grid, cells)
	var out := PackedInt32Array()
	for i in cells:
		if _sup[i] == 0 and _mark[i] == 0:
			out.append(i)
	out.sort()
	return out


func _analyze(grid, events: Array) -> void:
	var mat: PackedByteArray = grid.mat
	# Ilhas em aviso perdem células destruídas (ou trocadas) nesse tempo.
	var keep := []
	for isl in islands:
		var d: Dictionary = isl
		if d.state == 0:
			_prune(grid, d)
			if (d.cells as PackedInt32Array).is_empty():
				continue
		keep.append(d)
	islands = keep
	# Entulho que ficou sem apoio volta a andar.
	var r := mat.find(C.M_RUBBLE)
	while r >= 0:
		if _act[r] == 0 and _can_fall(mat, r):
			_activate(r)
		r = mat.find(C.M_RUBBLE, r + 1)
	# Componentes conexos (4-viz.) sem apoio, na ordem do menor índice: uma ilha cada.
	var loose := unsupported(grid)
	if loose.is_empty():
		return
	var seen := PackedByteArray()
	seen.resize(N)
	for i0 in loose:
		if seen[i0] == 1:
			continue
		var comp := PackedInt32Array([i0])
		seen[i0] = 1
		var k := 0
		while k < comp.size():
			var c: int = comp[k]
			k += 1
			var x := c % W
			for dn in 4:
				var n := -1
				if dn == 0 and c >= W:
					n = c - W
				elif dn == 1 and c + W < N:
					n = c + W
				elif dn == 2 and x > 0:
					n = c - 1
				elif dn == 3 and x < W - 1:
					n = c + 1
				if n < 0 or seen[n] == 1:
					continue
				var mn: int = mat[n]
				if mn >= C.M_GLASS and mn <= C.M_CONCRETE and _sup[n] == 0 and _mark[n] == 0:
					seen[n] = 1
					comp.append(n)
		comp.sort()
		var mats := PackedByteArray()
		var hps := PackedInt32Array()
		for c in comp:
			mats.append(mat[c])
			hps.append(grid.hp[c])
		var isl := {"id": next_id, "state": 0, "t": 0, "vy": 0, "dy": 0, "cells": comp, "mats": mats,
			"hp": hps, "breaks": 0, "mass": comp.size() * CELL_MASS, "hit_mask": 0}
		next_id += 1
		islands.append(isl)
		events.append({"kind": "collapse_warn", "island": isl.id, "cells": comp.duplicate()})
	# Marca depois de montar todas (a marca tira a célula do grafo de apoio).
	for isl in islands:
		var d: Dictionary = isl
		if d.state == 0:
			for c in (d.cells as PackedInt32Array):
				_mark[c] = 1


func _prune(grid, d: Dictionary) -> void:
	var cells: PackedInt32Array = d.cells
	var mats: PackedByteArray = d.mats
	var hps: PackedInt32Array = d.hp
	var c2 := PackedInt32Array()
	var m2 := PackedByteArray()
	var h2 := PackedInt32Array()
	for k in cells.size():
		var i: int = cells[k]
		if grid.mat[i] == mats[k]:
			c2.append(i)
			m2.append(mats[k])
			h2.append(grid.hp[i])
		else:
			_mark[i] = 0
	d.cells = c2
	d.mats = m2
	d.hp = h2
	d.mass = c2.size() * CELL_MASS


# ---------------------------------------------------------------- queda

func _start_fall(grid, d: Dictionary) -> void:
	## Fim do aviso: as células vivas saem da grade estática e a ilha passa a cair.
	_prune(grid, d)
	var was: bool = grid.struct_dirty
	var cells: PackedInt32Array = d.cells
	for i in cells:
		_mark[i] = 0
		grid.set_cell(i, C.M_EMPTY, 0)
	# Tirar células sem apoio não muda o apoio do resto; só o entulho em cima precisa acordar.
	grid.struct_dirty = was
	for i in cells:
		_wake_above(grid.mat, i)
	d.state = 1
	d.t = 0


func _fall(grid, d: Dictionary, blocked: Array, events: Array) -> bool:
	## Um tick de queda. Retorna true se a ilha assentou (e deve sair da lista).
	var cells: PackedInt32Array = d.cells
	if cells.is_empty():
		return true
	var vy: int = mini(int(d.vy) + GRAVITY, VY_MAX)
	var dy: int = d.dy
	var mass: int = d.mass
	var remaining := vy
	while remaining > 0:
		var s := mini(remaining, CS / 2)
		var old_last := C.fdiv(dy + CS - 1, CS)
		var new_last := C.fdiv(dy + s + CS - 1, CS)
		if new_last > old_last:
			var hit := PackedInt32Array()
			var core := false
			for i in cells:
				var row := i / W + new_last
				if row >= H:
					core = true
					continue
				var n := row * W + i % W
				var m: int = grid.mat[n]
				if m != C.M_EMPTY:
					hit.append(n)
					core = core or m == C.M_CORE
			if core or not hit.is_empty():
				var r := 0
				var absorb := 0
				var min_v := 0
				for n in hit:
					var m: int = grid.mat[n]
					r += grid.hp[n]
					absorb = maxi(absorb, C.MAT_ABSORB[m])
					# Folha sob o peso da ilha não pede velocidade mínima: é esmagada.
					if not _leaf(m):
						min_v = maxi(min_v, C.MAT_MIN_V[m])
				var e := mass * vy * vy / (2 * C.SUB * C.SUB)
				if not core and int(d.breaks) < C.MAX_BREAKS and vy >= min_v and e >= r and e > 0:
					grid.destroy(hit)
					d.breaks += 1
					events.append({"kind": "break", "island": d.id, "cells": hit, "mats": grid.last_mats,
						"axis": 1, "dir": 1, "e": e, "r": r})
					var e2 := (e - r) * (1000 - absorb) / 1000
					var ratio := C.isqrt(e2 * 1048576 / maxi(1, e))
					var nvy := vy * ratio / 1024
					remaining = remaining * nvy / maxi(1, vy)
					vy = nvy
					continue
				d.dy = C.fdiv(dy + s - 1, CS) * CS
				d.vy = vy
				_settle(grid, d, blocked, events, e)
				return true
		dy += s
		remaining -= s
	d.vy = vy
	d.dy = dy
	return false


func _settle(grid, d: Dictionary, blocked: Array, events: Array, e: int) -> void:
	## Escreve a ilha como entulho na posição final. Ocupado (ou lutador) → sobe na coluna.
	var budget: int = RUBBLE_MAX - (grid.mat as PackedByteArray).count(C.M_RUBBLE)
	var shift: int = int(d.dy) / CS
	var cells: PackedInt32Array = d.cells
	var out := PackedInt32Array()
	var dust := 0
	var was: bool = grid.struct_dirty
	for k in range(cells.size() - 1, -1, -1):
		var i: int = cells[k]
		var x := i % W
		var y := mini(i / W + shift, H - 1)
		while y >= 0 and (grid.mat[y * W + x] != C.M_EMPTY or _blocked(x, y, blocked)):
			y -= 1
		if y < 0 or budget <= 0:
			dust += 1
			continue
		var n := y * W + x
		grid.set_cell(n, C.M_RUBBLE, C.MAT_HP[C.M_RUBBLE])
		budget -= 1
		out.append(n)
		_activate(n)
	grid.struct_dirty = was
	out.sort()
	events.append({"kind": "collapse_land", "island": d.id, "cells": out, "e": e, "dust": dust})


# ---------------------------------------------------------------- areia

func _activate(i: int) -> void:
	if _act[i] == 0:
		_act[i] = 1
		active.append(i)


func _wake_above(mat: PackedByteArray, i: int) -> void:
	var x := i % W
	# Vizinhos da mesma linha: a diagonal de baixo deles passa por esta célula.
	if x > 0 and mat[i - 1] == C.M_RUBBLE:
		_activate(i - 1)
	if x < W - 1 and mat[i + 1] == C.M_RUBBLE:
		_activate(i + 1)
	if i < W:
		return
	var u := i - W
	if mat[u] == C.M_RUBBLE:
		_activate(u)
	if x > 0 and mat[u - 1] == C.M_RUBBLE:
		_activate(u - 1)
	if x < W - 1 and mat[u + 1] == C.M_RUBBLE:
		_activate(u + 1)


static func _can_fall(mat: PackedByteArray, i: int) -> bool:
	var y := i / W
	if y >= H - 1:
		return false
	var x := i % W
	var b := i + W
	if mat[b] == C.M_EMPTY:
		return true
	if x > 0 and mat[b - 1] == C.M_EMPTY and mat[i - 1] == C.M_EMPTY:
		return true
	return x < W - 1 and mat[b + 1] == C.M_EMPTY and mat[i + 1] == C.M_EMPTY


static func _blocked(x: int, y: int, blocked: Array) -> bool:
	## A célula toca algum retângulo [l, t, r, b) (subpixels)?
	var l := x * CS
	var t := y * CS
	for rect in blocked:
		var q: Array = rect
		if l < int(q[2]) and l + CS > int(q[0]) and t < int(q[3]) and t + CS > int(q[1]):
			return true
	return false


func _sand(grid, blocked: Array) -> void:
	## De baixo para cima, esquerda para direita. Reto para baixo; senão diagonal (lado alterna).
	## Lê grid.mat direto (sem cópia local): segurar a referência faria cada escrita copiar a grade.
	if active.is_empty():
		return
	var keys := PackedInt32Array()
	for i in active:
		keys.append((H - 1 - i / W) * W + i % W)
	keys.sort()
	for i in active:
		_act[i] = 0
	active = PackedInt32Array()
	var side := 1 if (tick / SAND_EVERY) % 2 == 0 else -1
	var was: bool = grid.struct_dirty
	for key in keys:
		var y := H - 1 - key / W
		var x := key % W
		var i := y * W + x
		if grid.mat[i] != C.M_RUBBLE or y >= H - 1:
			continue
		var target := -1
		var stuck := false   # havia vaga, mas um lutador ocupa
		var b := i + W
		if grid.mat[b] == C.M_EMPTY:
			if _blocked(x, y + 1, blocked):
				stuck = true
			else:
				target = b
		else:
			for dx in [side, -side]:
				var nx: int = x + dx
				if nx < 0 or nx >= W or grid.mat[b + dx] != C.M_EMPTY or grid.mat[i + dx] != C.M_EMPTY:
					continue
				if _blocked(nx, y + 1, blocked):
					stuck = true
					continue
				target = b + dx
				break
		if target < 0:
			if stuck:
				_activate(i)
			continue
		var h: int = grid.hp[i]
		grid.set_cell(i, C.M_EMPTY, 0)
		grid.set_cell(target, C.M_RUBBLE, h)
		_activate(target)
		_wake_above(grid.mat, i)
	grid.struct_dirty = was


# ---------------------------------------------------------------- consulta

func island_overlaps(island: Dictionary, l: int, t: int, r: int, b: int) -> bool:
	var dy: int = island.dy
	var cells: PackedInt32Array = island.cells
	for i in cells:
		var cl := (i % W) * CS
		var ct := (i / W) * CS + dy
		if cl < r and cl + CS > l and ct < b and ct + CS > t:
			return true
	return false


func cells_of(island: Dictionary) -> Array:
	var out := []
	var dy: int = island.dy
	var cells: PackedInt32Array = island.cells
	var mats: PackedByteArray = island.mats
	for k in cells.size():
		var i: int = cells[k]
		out.append([(i % W) * CS, (i / W) * CS + dy, mats[k]])
	return out


# ---------------------------------------------------------------- estado

func _active_sorted() -> PackedInt32Array:
	var a := active.duplicate()
	a.sort()
	return a


func hash_ints() -> PackedInt64Array:
	var h := PackedInt64Array([tick, next_id, islands.size()])
	for isl in islands:
		var d: Dictionary = isl
		h.append_array(PackedInt64Array([d.id, d.state, d.t, d.vy, d.dy, d.breaks, d.mass, d.hit_mask]))
		var cells: PackedInt32Array = d.cells
		var mats: PackedByteArray = d.mats
		var hps: PackedInt32Array = d.hp
		h.append(cells.size())
		for k in cells.size():
			h.append(cells[k])
			h.append(mats[k])
			h.append(hps[k])
	var a := _active_sorted()
	h.append(a.size())
	for i in a:
		h.append(i)
	h.append(pins.size())
	for i in pins:
		h.append(i)
	return h


func snapshot() -> Dictionary:
	return {"tick": tick, "next_id": next_id, "islands": islands.duplicate(true),
		"active": _active_sorted(), "pins": pins.duplicate()}


func restore(s: Dictionary) -> void:
	## Requer setup() antes (bordas do núcleo e buffers).
	tick = s.tick
	next_id = s.next_id
	islands = (s.islands as Array).duplicate(true)
	pins = (s.pins as PackedInt32Array).duplicate()
	active = (s.active as PackedInt32Array).duplicate()
	_act.fill(0)
	for i in active:
		_act[i] = 1
	_mark.fill(0)
	for isl in islands:
		var d: Dictionary = isl
		if d.state == 0:
			for i in (d.cells as PackedInt32Array):
				_mark[i] = 1
