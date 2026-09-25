extends RefCounted
## Testes da estrutura (M2): `godot --headless --path game --script res://tests/run_suite.gd -- --suite structure`.
## Cada teste devolve "" quando passa ou a descrição da falha.

const C = preload("res://sim/sim_const.gd")
const Grid = preload("res://sim/matter_grid.gd")
const Structure = preload("res://sim/structure.gd")

const W := C.GRID_W


static func run_all() -> int:
	var tests := {
		"distrito intacto: nenhum aviso em 300 ticks": _test_intact,
		"sem divisória: nenhuma ilha": _test_drywall,
		"sem pilar: frente racha, cai e vira entulho assentado": _test_pillar,
		"sem pilar e parede dos fundos: sobreloja inteira cai": _test_pillar_and_back,
		"ilha rompe vidro e nunca passa do núcleo": _test_glass_and_core,
		"entulho não entra no retângulo bloqueado": _test_blocked,
		"determinismo e snapshot/restore no meio da queda": _test_determinism,
		"custo do pior passo (BFS completo)": _test_cost,
	}
	var failed := 0
	# Script que não compila faz os testes "passarem" em silêncio: checar antes.
	var probe: Script = load("res://sim/structure.gd")
	if probe == null or not probe.can_instantiate():
		print("  FALHA structure.gd não compila")
		print("RESULTADO: FALHOU (1 falha(s))")
		return 1
	for name in tests:
		var ret = tests[name].call()
		var err: String = ret if typeof(ret) == TYPE_STRING else "teste abortou (erro de script)"
		print(("  ok    " if err == "" else "  FALHA ") + name + ("" if err == "" else ": " + err))
		if err != "":
			failed += 1
	print("RESULTADO: %s (%d falha(s))" % ["PASSOU" if failed == 0 else "FALHOU", failed])
	return failed


# ---------------------------------------------------------------- utilidades

static func _district() -> Array:
	var g := Grid.new()
	g.build_test_district()
	var st := Structure.new()
	st.setup(g)
	return [g, st]


static func _rect_cells(g, x0: int, y0: int, x1: int, y1: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if g.get_mat(x, y) != C.M_EMPTY:
				out.append(g.index(x, y))
	return out


static func _run(g, st, n: int, blocked: Array = []) -> Array:
	var all := []
	for i in n:
		all.append_array(st.step(g, blocked))
	return all


static func _count(events: Array, kind: String) -> int:
	var k := 0
	for e in events:
		if e.kind == kind:
			k += 1
	return k


static func _settled(g, st) -> String:
	## Nada caindo, nada sem apoio, todo entulho em repouso.
	if not st.islands.is_empty():
		return "%d ilha(s) ainda ativas" % st.islands.size()
	var loose: PackedInt32Array = st.unsupported(g)
	if not loose.is_empty():
		return "%d célula(s) flutuando (ex.: %d,%d)" % [loose.size(), loose[0] % W, loose[0] / W]
	for i in g.mat.size():
		if g.mat[i] == C.M_RUBBLE and Structure._can_fall(g.mat, i):
			return "entulho fora de repouso em %d,%d" % [i % W, i / W]
	return ""


static func _count_rubble(g, x0: int, y0: int, x1: int, y1: int) -> int:
	var k := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if g.get_mat(x, y) == C.M_RUBBLE:
				k += 1
	return k


static func _grid_hash(g, st) -> int:
	var h: int = hash(g.mat)
	h = hash([h, hash(g.hp), hash(st.hash_ints())])
	return h


# ---------------------------------------------------------------- testes

static func _test_intact() -> String:
	var a := _district()
	var g = a[0]
	var st = a[1]
	if st.pins.size() != 20:
		return "esperava só a marquise (20 células) presa no setup, veio %d" % st.pins.size()
	g.struct_dirty = true   # força a análise completa
	var ev := _run(g, st, 300)
	if _count(ev, "collapse_warn") > 0 or not st.islands.is_empty():
		return "surgiu aviso no distrito intacto"
	return ""


static func _test_drywall() -> String:
	var a := _district()
	var g = a[0]
	var st = a[1]
	g.destroy(_rect_cells(g, 74, 36, 75, 51))
	var ev := _run(g, st, 200)
	if _count(ev, "collapse_warn") > 0:
		return "quebrar a divisória derrubou algo"
	return ""


static func _test_pillar() -> String:
	var a := _district()
	var g = a[0]
	var st = a[1]
	g.destroy(_rect_cells(g, 88, 36, 89, 51))
	var ev: Array = st.step(g, [])
	if _count(ev, "collapse_warn") != 1 or st.islands.size() != 1:
		return "esperava 1 ilha em aviso, veio %d" % _count(ev, "collapse_warn")
	var isl: Dictionary = st.islands[0]
	var cells: PackedInt32Array = isl.cells
	var maxx := 0
	for i in cells:
		maxx = maxi(maxx, i % W)
	if cells[0] % W != 44 or maxx != 102 - Structure.SPAN - 1:
		return "ilha inesperada: x %d..%d (%d células)" % [cells[0] % W, maxx, cells.size()]
	if g.get_mat(50, 34) != C.M_CONCRETE:
		return "célula em aviso não continua sólida"
	ev = _run(g, st, Structure.WARN_TICKS)
	if _count(ev, "collapse_fall") != 1 or int(st.islands[0].state) != 1:
		return "ilha não caiu ao fim do aviso"
	if g.get_mat(50, 34) != C.M_EMPTY:
		return "ilha caindo continua na grade estática"
	ev = _run(g, st, 600)
	if _count(ev, "collapse_land") != 1:
		return "ilha não assentou"
	if _count(ev, "break") == 0:
		return "a verga não rompeu a vitrine"
	var err := _settled(g, st)
	if err != "":
		return err
	var ground := _count_rubble(g, 30, 36, 101, 51)
	if ground == 0:
		return "sem entulho no térreo"
	if g.get_mat(102 - Structure.SPAN, 34) != C.M_CONCRETE or g.get_mat(103, 16) != C.M_CONCRETE:
		return "a parte dentro do vão também caiu"
	print("        pilar: %d células na ilha, %d rupturas, %d entulhos no térreo/rua" % [cells.size(), _count(ev, "break"), ground])
	return ""


static func _test_pillar_and_back() -> String:
	var a := _district()
	var g = a[0]
	var st = a[1]
	g.destroy(_rect_cells(g, 88, 36, 89, 51))
	g.destroy(_rect_cells(g, 102, 36, 103, 51))
	var ev := _run(g, st, Structure.WARN_TICKS + 800)
	if _count(ev, "collapse_warn") == 0:
		return "nenhum aviso"
	for y in range(16, 36):
		for x in range(44, 104):
			var m: int = g.get_mat(x, y)
			if m != C.M_EMPTY and m != C.M_RUBBLE:
				return "sobrou %s em %d,%d" % [C.MAT_NAME[m], x, y]
	var err := _settled(g, st)
	if err != "":
		return err
	print("        sobreloja: %d aviso(s), %d rupturas, %d entulhos no mapa" % [
		_count(ev, "collapse_warn"), _count(ev, "break"), g.mat.count(C.M_RUBBLE)])
	return ""


static func _test_glass_and_core() -> String:
	## Bloco de concreto preso por um braço a uma coluna. Cortar o braço: o bloco cai de 36 linhas
	## sobre vidro apoiado no núcleo. O vidro rompe; o núcleo segura.
	var g := Grid.new()
	g.fill(0, 54, W - 1, C.GRID_H - 1, C.M_CORE)
	g.fill(10, 50, 17, 53, C.M_GLASS)
	g.fill(12, 10, 15, 13, C.M_CONCRETE)
	g.fill(16, 10, 19, 10, C.M_CONCRETE)
	g.fill(20, 10, 20, 53, C.M_CONCRETE)
	g.struct_dirty = false
	var st := Structure.new()
	st.setup(g)
	if not st.pins.is_empty():
		return "cenário do teste já tinha células soltas"
	g.destroy(_rect_cells(g, 16, 10, 19, 10))
	var ev := []
	var glass_broken := false
	for t in 400:
		var e: Array = st.step(g, [])
		ev.append_array(e)
		for x in e:
			if x.kind == "break" and (x.mats as PackedByteArray).has(C.M_GLASS):
				glass_broken = true
		for isl in st.islands:
			if int(isl.state) == 1 and st.island_overlaps(isl, 0, 54 * C.CELL_SUB, W * C.CELL_SUB, C.GRID_H * C.CELL_SUB):
				return "ilha entrou no núcleo no tick %d" % t
	if not glass_broken:
		return "ilha não rompeu o vidro"
	for x in range(12, 16):
		if g.get_mat(x, 50) == C.M_GLASS:
			return "vidro sob o bloco ficou inteiro em %d,50" % x
	for i in range(54 * W, g.mat.size()):
		if g.mat[i] != C.M_CORE:
			return "núcleo perdeu célula"
	if _count(ev, "collapse_land") != 1:
		return "bloco não assentou"
	return _settled(g, st)


static func _test_blocked() -> String:
	var g := Grid.new()
	g.fill(0, 54, W - 1, C.GRID_H - 1, C.M_CORE)
	for y in range(30, 42):
		g.set_cell(g.index(50, y), C.M_RUBBLE, C.MAT_HP[C.M_RUBBLE])
	var st := Structure.new()
	st.setup(g)
	# "Lutador" de pé no núcleo, embaixo da coluna de entulho.
	var r := [50 * C.CELL_SUB + 256, 44 * C.CELL_SUB, 51 * C.CELL_SUB - 256, 54 * C.CELL_SUB]
	for t in 400:
		st.step(g, [r])
		for y in range(44, 54):
			if g.get_mat(50, y) != C.M_EMPTY:
				return "entulho entrou no retângulo no tick %d (%d,%d)" % [t, 50, y]
	if g.mat.count(C.M_RUBBLE) != 12:
		return "entulho sumiu ou duplicou (%d)" % g.mat.count(C.M_RUBBLE)
	# Tira o lutador: o entulho volta a cair.
	_run(g, st, 200)
	if g.get_mat(50, 53) != C.M_RUBBLE:
		return "entulho não caiu quando o retângulo saiu"
	return _settled(g, st)


static func _test_determinism() -> String:
	var hashes := []
	for run in 2:
		var a := _district()
		var g = a[0]
		var st = a[1]
		g.destroy(_rect_cells(g, 88, 36, 89, 51))
		_run(g, st, Structure.WARN_TICKS + 20)
		if st.islands.is_empty() or int(st.islands[0].state) != 1:
			return "ilha não está caindo no ponto do snapshot"
		var s: Dictionary = st.snapshot()
		var gm: PackedByteArray = g.mat.duplicate()
		var gh: PackedInt32Array = g.hp.duplicate()
		var gd: bool = g.struct_dirty
		_run(g, st, 300)
		var h1 := _grid_hash(g, st)
		# Restore sobre uma estrutura nova (setup + restore), como o integrador fará.
		g.mat = gm.duplicate()
		g.hp = gh.duplicate()
		g.struct_dirty = gd
		var st2 := Structure.new()
		st2.setup(g)
		st2.restore(s)
		_run(g, st2, 300)
		var h2 := _grid_hash(g, st2)
		if h1 != h2:
			return "restore divergiu: %d != %d" % [h1, h2]
		hashes.append(h1)
	if hashes[0] != hashes[1]:
		return "execuções divergiram: %s" % str(hashes)
	return ""


static func _test_cost() -> String:
	var a := _district()
	var g = a[0]
	var st = a[1]
	var worst := 0
	var total := 0
	for k in 30:
		g.struct_dirty = true
		var t0 := Time.get_ticks_usec()
		st.step(g, [])
		var dt := Time.get_ticks_usec() - t0
		worst = maxi(worst, dt)
		total += dt
	# Pior passo real: todo o colapso da sobreloja.
	g.destroy(_rect_cells(g, 88, 36, 89, 51))
	g.destroy(_rect_cells(g, 102, 36, 103, 51))
	var worst_run := 0
	for k in Structure.WARN_TICKS + 800:
		var t0 := Time.get_ticks_usec()
		st.step(g, [[60 * C.CELL_SUB, 44 * C.CELL_SUB, 63 * C.CELL_SUB, 52 * C.CELL_SUB]])
		worst_run = maxi(worst_run, Time.get_ticks_usec() - t0)
	print("        BFS completo: pior %d us, média %d us; colapso da sobreloja: pior passo %d us" % [
		worst, total / 30, worst_run])
	# Trava folgada contra regressão (máquina lenta/depuração): a média da análise completa.
	if total / 30 > 2000:
		return "análise completa média %d us (> 2000 us)" % (total / 30)
	return ""
