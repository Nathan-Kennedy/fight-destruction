extends RefCounted
## Tabela de golpes placeholder. Hitbox em px relativa ao centro dos pés, espelhada pelo facing:
## ox é a borda próxima no sentido do facing (negativo = centrado), oy é o topo (negativo = acima).
## dir é a direção do lançamento em 1/1024 (x no sentido do facing). base em sub/tick,
## growth em sub/tick por ponto de percentual. cell_dmg é o carimbo no cenário, em HP por célula
## tocada no primeiro frame ativo: todo golpe lasca o cenário, o forte rompe tijolo em dois acertos.
## grab = true: não causa dano; prende o oponente (ignora escudo) ou pega um objeto.

const NONE := -1
const JAB := 0
const STRONG_SIDE := 1
const STRONG_UP := 2
const STRONG_DOWN_AIR := 3
const STOMP := 4
const GRAB := 5
const BURST := 6

const LIST := [
	{"name": "jab", "startup": 3, "active": 3, "recovery": 8, "dmg": 3, "base": 400, "growth": 3,
		"dir": [940, -400], "box": [6, -40, 22, 16], "hitstop": 3, "cell_dmg": 10},
	{"name": "forte_lado", "startup": 10, "active": 4, "recovery": 22, "dmg": 13, "base": 1100, "growth": 17,
		"dir": [870, -500], "box": [6, -44, 30, 26], "hitstop": 6, "cell_dmg": 50},
	{"name": "forte_cima", "startup": 8, "active": 5, "recovery": 20, "dmg": 11, "base": 1100, "growth": 15,
		"dir": [180, -1010], "box": [-16, -76, 32, 30], "hitstop": 5, "cell_dmg": 35},
	{"name": "forte_baixo_ar", "startup": 9, "active": 4, "recovery": 18, "dmg": 12, "base": 900, "growth": 14,
		"dir": [120, 1015], "box": [-12, -8, 24, 22], "hitstop": 6, "cell_dmg": 70},
	{"name": "pisada", "startup": 12, "active": 3, "recovery": 24, "dmg": 10, "base": 1000, "growth": 12,
		"dir": [500, -890], "box": [-22, -14, 44, 22], "hitstop": 6, "cell_dmg": 140},
	{"name": "agarrao", "startup": 5, "active": 3, "recovery": 22, "dmg": 0, "base": 0, "growth": 0,
		"dir": [0, 0], "box": [2, -46, 20, 40], "hitstop": 0, "cell_dmg": 0, "grab": true},
	# Explosão radial (§5.4): carimbo em círculo de `radius` px centrado no meio do corpo; lança
	# para longe do centro. box é só o quadrado envolvente (ox -radius, oy relativo ao centro).
	{"name": "explosao", "startup": 10, "active": 2, "recovery": 26, "dmg": 12, "base": 1200, "growth": 14,
		"dir": [0, -1024], "box": [-56, -56, 112, 112], "hitstop": 8, "cell_dmg": 400, "radial": true, "radius": 56},
]

# Arremessos do agarrão: mesmos campos de golpe; o lançado sai pela frente do agarrador.
const THROW_FWD := 0
const THROW_BACK := 1
const THROW_UP := 2
const THROW_DOWN := 3
const THROWS := [
	{"name": "arremesso_frente", "dmg": 8, "base": 950, "growth": 15, "dir": [860, -560], "hitstop": 5},
	{"name": "arremesso_tras", "dmg": 10, "base": 1000, "growth": 16, "dir": [900, -480], "hitstop": 6},
	{"name": "arremesso_cima", "dmg": 7, "base": 1000, "growth": 13, "dir": [0, -1024], "hitstop": 5},
	# Para baixo: crava o oponente no chão. Com percentual alto rompe a laje da rua.
	{"name": "arremesso_baixo", "dmg": 9, "base": 1100, "growth": 14, "dir": [120, 1017], "hitstop": 7},
]


static func total_frames(id: int) -> int:
	var a: Dictionary = LIST[id]
	return a.startup + a.active + a.recovery


static func is_active(id: int, t: int) -> bool:
	var a: Dictionary = LIST[id]
	return t >= a.startup and t < a.startup + a.active
