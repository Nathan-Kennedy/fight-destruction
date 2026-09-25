extends RefCounted
## Grade de matéria: verdade do gameplay (§4.2, nível fino). Células de 8 px com material e HP.
## Fora da grade é vazio. `changed` e `full_dirty` são só para a apresentação e não entram no hash.

const C = preload("res://sim/sim_const.gd")

var mat := PackedByteArray()
var hp := PackedInt32Array()
var changed := PackedInt32Array()
var full_dirty := true
# Alguma célula mudou de sólida para vazia (ou foi preenchida) desde o último passo da estrutura.
# É estado da simulação: entra no hash e no snapshot. Quem consome é structure.gd.
var struct_dirty := false
# Materiais das células do último destroy(), na mesma ordem (para eventos da apresentação).
var last_mats := PackedByteArray()


func _init() -> void:
	mat.resize(C.GRID_W * C.GRID_H)
	hp.resize(C.GRID_W * C.GRID_H)


func index(cx: int, cy: int) -> int:
	return cy * C.GRID_W + cx


func get_mat(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= C.GRID_W or cy >= C.GRID_H:
		return C.M_EMPTY
	return mat[cy * C.GRID_W + cx]


func fill(x0: int, y0: int, x1: int, y1: int, m: int) -> void:
	## Retângulo inclusivo em coordenadas de célula.
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i := index(cx, cy)
			mat[i] = m
			hp[i] = C.MAT_HP[m]
	full_dirty = true
	struct_dirty = true


func set_cell(i: int, m: int, h: int) -> void:
	## Escreve uma célula (estrutura e escombro usam isto). Marca para a apresentação e a estrutura.
	mat[i] = m
	hp[i] = h
	changed.append(i)
	struct_dirty = true


func destroy(cells: PackedInt32Array) -> void:
	last_mats = PackedByteArray()
	for i in cells:
		last_mats.append(mat[i])
		mat[i] = C.M_EMPTY
		hp[i] = 0
		changed.append(i)
	if not cells.is_empty():
		struct_dirty = true


func damage(cells: PackedInt32Array, total: int) -> PackedInt32Array:
	## Distribui `total` de dano entre as células (mínimo 1 cada). Retorna as que romperam.
	var broken := PackedInt32Array()
	if cells.is_empty():
		return broken
	var each := maxi(1, total / cells.size())
	for i in cells:
		if mat[i] == C.M_CORE or mat[i] == C.M_EMPTY:
			continue
		hp[i] -= each
		if hp[i] <= 0:
			broken.append(i)
		else:
			changed.append(i)
	destroy(broken)
	return broken


func cells_in_rect(l: int, t: int, r: int, b: int) -> PackedInt32Array:
	## Células sólidas destrutíveis que tocam o retângulo [l,r) x [t,b) em subpixels.
	var out := PackedInt32Array()
	var cx0 := maxi(0, C.fdiv(l, C.CELL_SUB))
	var cx1 := mini(C.GRID_W - 1, C.fdiv(r - 1, C.CELL_SUB))
	var cy0 := maxi(0, C.fdiv(t, C.CELL_SUB))
	var cy1 := mini(C.GRID_H - 1, C.fdiv(b - 1, C.CELL_SUB))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var m := mat[cy * C.GRID_W + cx]
			if m != C.M_EMPTY and m != C.M_CORE:
				out.append(cy * C.GRID_W + cx)
	return out


func any_solid_in_rect(l: int, t: int, r: int, b: int) -> bool:
	var cx0 := C.fdiv(l, C.CELL_SUB)
	var cx1 := C.fdiv(r - 1, C.CELL_SUB)
	var cy0 := C.fdiv(t, C.CELL_SUB)
	var cy1 := C.fdiv(b - 1, C.CELL_SUB)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if get_mat(cx, cy) != C.M_EMPTY:
				return true
	return false


func build_test_district() -> void:
	## Greybox do M1: rua, loja com vitrine, divisória, pilar, sobreloja e mureta de concreto.
	## Coordenadas em células (8 px). Rua no topo da linha 52 (y = 416 px). Andar = 16 células.
	mat.fill(0)
	hp.fill(0)
	fill(0, 54, C.GRID_W - 1, C.GRID_H - 1, C.M_CORE)          # base indestrutível
	fill(0, 52, C.GRID_W - 1, 53, C.M_CONCRETE)               # laje da rua
	# Prédio: x 44..103, térreo linhas 36..51, sobreloja 18..33.
	fill(44, 38, 45, 51, C.M_GLASS)                           # vitrine do térreo
	fill(44, 36, 45, 37, C.M_CONCRETE)                        # verga
	fill(74, 36, 75, 51, C.M_DRYWALL)                         # divisória interna
	fill(88, 36, 89, 51, C.M_CONCRETE)                        # pilar
	fill(102, 36, 103, 51, C.M_BRICK)                         # parede dos fundos
	fill(44, 34, 103, 35, C.M_CONCRETE)                       # laje entre andares
	fill(44, 18, 45, 25, C.M_BRICK)                           # fachada superior
	fill(44, 26, 45, 33, C.M_GLASS)                           # janela da sobreloja
	fill(80, 18, 81, 33, C.M_BRICK)                           # parede interna da sobreloja
	fill(102, 18, 103, 33, C.M_BRICK)
	fill(44, 16, 103, 17, C.M_CONCRETE)                       # cobertura
	fill(32, 37, 41, 38, C.M_CONCRETE)                        # marquise (acesso pela rua)
	fill(128, 44, 131, 51, C.M_CONCRETE)                      # mureta na rua da direita
	changed.clear()
	full_dirty = true
	struct_dirty = false
