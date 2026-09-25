extends RefCounted
## Lê teclado e gamepad e devolve o bitmask de input de um jogador (§0.1: os dois desde o M1).
## Teclas por posição física, então funcionam igual em ABNT e US.
## J1: WASD, Espaço pula, F leve, G forte, H agarra, J explosão, Shift escudo/esquiva.
## J2: setas, Num0 pula, Num1 leve, Num2 forte, Num3 agarra, Num4 explosão, Num Enter escudo/esquiva.
##     Sem numpad: Insert pula, Delete leve, End forte, Page Down agarra, Page Up explosão, Home escudo.
## Gamepad N vai para o jogador N: analógico/direcional, A pula, X leve, B forte, Y explosão, RB agarra,
## LB ou gatilhos escudo/esquiva.

const C = preload("res://sim/sim_const.gd")

const KEYS := [
	{C.IN_LEFT: [KEY_A], C.IN_RIGHT: [KEY_D], C.IN_UP: [KEY_W], C.IN_DOWN: [KEY_S],
		C.IN_JUMP: [KEY_SPACE], C.IN_LIGHT: [KEY_F], C.IN_STRONG: [KEY_G], C.IN_GRAB: [KEY_H],
		C.IN_SHIELD: [KEY_SHIFT], C.IN_SPECIAL: [KEY_J]},
	{C.IN_LEFT: [KEY_LEFT], C.IN_RIGHT: [KEY_RIGHT], C.IN_UP: [KEY_UP], C.IN_DOWN: [KEY_DOWN],
		C.IN_JUMP: [KEY_KP_0, KEY_INSERT], C.IN_LIGHT: [KEY_KP_1, KEY_DELETE], C.IN_STRONG: [KEY_KP_2, KEY_END],
		C.IN_GRAB: [KEY_KP_3, KEY_PAGEDOWN], C.IN_SHIELD: [KEY_KP_ENTER, KEY_HOME],
		C.IN_SPECIAL: [KEY_KP_4, KEY_PAGEUP]},
]
const PAD_BUTTONS := {
	C.IN_LEFT: [JOY_BUTTON_DPAD_LEFT], C.IN_RIGHT: [JOY_BUTTON_DPAD_RIGHT],
	C.IN_UP: [JOY_BUTTON_DPAD_UP], C.IN_DOWN: [JOY_BUTTON_DPAD_DOWN],
	C.IN_JUMP: [JOY_BUTTON_A], C.IN_LIGHT: [JOY_BUTTON_X],
	C.IN_STRONG: [JOY_BUTTON_B], C.IN_SPECIAL: [JOY_BUTTON_Y], C.IN_GRAB: [JOY_BUTTON_RIGHT_SHOULDER],
	C.IN_SHIELD: [JOY_BUTTON_LEFT_SHOULDER],
}
const DEADZONE := 0.45


static func read(player: int) -> int:
	var bits := 0
	if player < KEYS.size():
		var map: Dictionary = KEYS[player]
		for bit in map:
			for key in map[bit]:
				if Input.is_physical_key_pressed(key):
					bits |= bit
	var pads := Input.get_connected_joypads()
	if player < pads.size():
		var dev: int = pads[player]
		for bit in PAD_BUTTONS:
			for b in PAD_BUTTONS[bit]:
				if Input.is_joy_button_pressed(dev, b):
					bits |= bit
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if ax < -DEADZONE:
			bits |= C.IN_LEFT
		elif ax > DEADZONE:
			bits |= C.IN_RIGHT
		if ay < -DEADZONE:
			bits |= C.IN_UP
		elif ay > DEADZONE:
			bits |= C.IN_DOWN
		if Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5 or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
			bits |= C.IN_SHIELD
	return bits
