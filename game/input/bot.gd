extends RefCounted
## Bot simples: gera bitmask de input a partir do estado. RNG próprio e semeado; não toca na
## simulação. Serve de CPU no jogo (F2) e de jogador no autotest, então usa todas as ações:
## golpes, escudo, esquivas, agarrão, arremesso e objetos.

const C = preload("res://sim/sim_const.gd")
const A = preload("res://sim/attacks.gd")

var rng := RandomNumberGenerator.new()
var _hold := 0
var _timer := 0


func _init(seed_value: int) -> void:
	rng.seed = seed_value


func decide(sim, me: int) -> int:
	var f: Dictionary = sim.fighters[me]
	var t: Dictionary = sim.fighters[(me + 1) % sim.fighters.size()]
	# Botões são pulsos de um tick; direção e escudo são mantidos por alguns ticks.
	var out := _hold & (C.IN_LEFT | C.IN_RIGHT | C.IN_UP | C.IN_DOWN | C.IN_SHIELD)
	_timer -= 1
	var dx: int = (t.x - f.x) / C.SUB
	var dy: int = (t.y - f.y) / C.SUB
	# Segurando alguém: arremessa numa direção sorteada logo depois de agarrar.
	if f.grabbing >= 0:
		if _timer > 0:
			return 0
		_timer = 3
		var dirs := [C.IN_UP, C.IN_DOWN, C.IN_LEFT, C.IN_RIGHT, C.IN_LIGHT]
		return dirs[rng.randi_range(0, dirs.size() - 1)]
	# Reação: escudo quando o oponente começa um golpe perto (nem sempre).
	if f.grounded and t.attack != A.NONE and t.attack != A.GRAB and absi(dx) < 48 and _timer <= 0 and rng.randf() < 0.3:
		_hold = C.IN_SHIELD
		_timer = rng.randi_range(8, 20)
		if rng.randf() < 0.3:
			return C.IN_SHIELD | (C.IN_LEFT if rng.randf() < 0.5 else C.IN_RIGHT) if (f.prev_in & C.IN_SHIELD) else C.IN_SHIELD
		return C.IN_SHIELD
	if _timer > 0:
		return out
	_timer = rng.randi_range(4, 12)
	_hold = 0
	# Com objeto na mão: aproxima e arremessa.
	if f.hold_prop >= 0:
		_hold |= C.IN_RIGHT if dx > 0 else C.IN_LEFT
		if absi(dx) < 160 or rng.randf() < 0.1:
			return _hold | (C.IN_STRONG if rng.randf() < 0.5 else C.IN_LIGHT)
		return _hold
	# Às vezes vai buscar um objeto próximo.
	var target_x: int = t.x
	for p in sim.props.props:
		if p.state == 0 and absi(p.x - f.x) < 120 * C.SUB and absi(p.y - f.y) < 40 * C.SUB and rng.randf() < 0.25:
			target_x = p.x
			if absi(p.x - f.x) < 18 * C.SUB:
				return C.IN_GRAB
			break
	var gx: int = (target_x - f.x) / C.SUB
	# Volta para o centro do mapa se estiver perto da borda.
	if f.x < 60 * C.SUB:
		_hold |= C.IN_RIGHT
	elif f.x > (C.WORLD_W - 60) * C.SUB:
		_hold |= C.IN_LEFT
	elif absi(gx) > 28:
		_hold |= C.IN_RIGHT if gx > 0 else C.IN_LEFT
	elif rng.randf() < 0.2:
		_hold |= C.IN_LEFT if rng.randf() < 0.5 else C.IN_RIGHT
	var press := 0
	var stuck: bool = f.grounded and f.vx == 0 and absi(gx) > 28
	if dy < -40 or stuck or rng.randf() < 0.08:
		press |= C.IN_JUMP
	if f.burst_cd == 0 and ((stuck and rng.randf() < 0.3) or (absi(dx) < 40 and absi(dy) < 40 and rng.randf() < 0.05)):
		press |= C.IN_SPECIAL   # explosão: abre caminho ou pune de perto
	if not f.grounded and rng.randf() < 0.04:
		press |= C.IN_SHIELD   # esquiva aérea
	if absi(dx) <= 40 and absi(dy) <= 60:
		var roll := rng.randf()
		if roll < 0.3:
			press |= C.IN_STRONG
			if dy < -24:
				_hold |= C.IN_UP
			elif rng.randf() < 0.25:
				_hold |= C.IN_DOWN
		elif roll < 0.42:
			press |= C.IN_GRAB
		elif roll < 0.8:
			press |= C.IN_LIGHT
	return _hold | press
