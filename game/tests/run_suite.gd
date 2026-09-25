extends SceneTree
## Roda uma suíte de testes isolada, sem carregar main.gd nem match_sim.gd:
##   godot --headless --path game --script res://tests/run_suite.gd -- --suite structure
## Carrega res://tests/<suite>_tests.gd e chama `run_all() -> int` (número de falhas).


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var suite := ""
	for i in args.size():
		if args[i] == "--suite" and i + 1 < args.size():
			suite = args[i + 1]
	var script = load("res://tests/%s_tests.gd" % suite)
	if script == null:
		push_error("suíte não encontrada: " + suite)
		quit(2)
		return
	var failed = script.run_all()
	quit(1 if typeof(failed) != TYPE_INT or failed > 0 else 0)
