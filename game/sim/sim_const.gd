extends RefCounted
## Constantes e tabelas da simulação. Tudo inteiro; contrato em Docs/contrato_sim.md.
## Posições e velocidades em subpixels (SUB por pixel de mundo), tempo em ticks de 60 Hz.

const TICK_HZ := 60
const SUB := 256
const CELL := 8
const CELL_SUB := CELL * SUB
const GRID_W := 160
const GRID_H := 60
const WORLD_W := GRID_W * CELL
const WORLD_H := GRID_H * CELL

# Blast zones fixas no mundo (§5.4): a câmera não define morte.
const BLAST_LEFT := -160 * SUB
const BLAST_RIGHT := (WORLD_W + 160) * SUB
const BLAST_TOP := -320 * SUB
const BLAST_BOTTOM := (WORLD_H + 120) * SUB

const STOCKS := 3
const RESPAWN_DELAY := 60
const RESPAWN_INVULN := 90
const RESPAWN_Y := 300 * SUB
const SPAWN_X := [100 * SUB, 240 * SUB, 900 * SUB, 1100 * SUB]

# Varredura contínua: nenhum sub-passo anda mais que meia célula.
const MAX_STEP := 4 * SUB
# Limite de rupturas por lançamento (§5.2: cadeia limitada).
const MAX_BREAKS := 24
# Abaixo disso a componente normal do quique zera (pousa/encosta).
const BOUNCE_MIN := 384
# Degrau máximo que o lutador sobe andando no chão, em células.
const STEP_UP := 2
# Kb a partir do qual o golpe vira lançamento capaz de quebrar cenário.
const LAUNCH_KB := 512

# Hitstop (congelamento global no acerto), inspirado no hitlag do Smash (floor(dano·0,65 + 6),
# teto 30). Aqui: HS_BASE + dano·HS_DMG_NUM/HS_DMG_DEN + kb/HS_KB_DIV, nunca abaixo do `hitstop`
# da tabela do golpe (piso) e nunca acima de HS_MAX. Jab 3% → 5; forte 13% → 11-13; explosão → 12-13.
# Teto 14 a 60 Hz (~0,23 s): o hitstop é global (o mundo todo para), então fica bem abaixo dos 30 do
# Smash para não travar a partida; a proposta de REFERENCIAS_VFX.md é forte 10-14.
const HS_BASE := 3
const HS_DMG_NUM := 2
const HS_DMG_DEN := 3
const HS_KB_DIV := 1024
const HS_MAX := 14
const HS_ENV_MAX := 4             # dano de cenário sem golpe (fogo, choque): só kb/512, teto baixo
# Escudo (Smash s = 0,67): hitstop do golpe × 2/3.
const HS_SHIELD_NUM := 2
const HS_SHIELD_DEN := 3

# Input buffer e coyote time (§5.5). Hipóteses para playtest.
const BUFFER_TICKS := 5           # golpe/pulo/agarrão/especial apertado sem poder agir espera isto
const BUFFER_MASK := 16 | 32 | 64 | 128 | 512   # JUMP | LIGHT | STRONG | GRAB | SPECIAL
const COYOTE_TICKS := 4           # ticks no ar depois de sair de uma borda em que o pulo ainda é do chão

# Escudo, esquiva e agarrão (§5.5). Hipóteses para playtest.
const SHIELD_MAX := 600
const SHIELD_DRAIN := 2           # por tick segurando
const SHIELD_REGEN := 1           # por tick solto
const SHIELD_DMG_MUL := 12        # escudo perdido por ponto de dano do golpe
const SHIELD_BREAK_STUN := 150    # ticks atordoado quando o escudo quebra
const ROLL_TICKS := 22
const ROLL_INTANG := 14
const ROLL_V := 1024
const SPOT_TICKS := 20
const SPOT_INTANG := 14
const AIR_DODGE_TICKS := 24
const AIR_DODGE_INTANG := 16
const AIR_DODGE_V := 1400
const GRAB_HOLD := 50             # ticks máximos segurando o oponente antes de ele escapar
# Explosão (especial): destrói tudo num raio em volta do corpo, inclusive concreto e entulho.
# Serve para sair de soterramento e abrir rota. Recarga longa para não virar spam.
const BURST_COOLDOWN := 240
const PROP_THROW_V := 2600        # velocidade base do arremesso de objeto (sub/tick), × throw_mul

# Colapso contra lutadores (§4.3) e KO ambiental (§5.4, decisão híbrida de §0.1).
const CRUSH_DMG := 10
const CRUSH_DMG_MAX := 30
const CRUSH_MASS_DIV := 200       # +1 de dano a cada CRUSH_MASS_DIV de massa da ilha
const ENV_KO_PCT := 100           # soterrado no chão com percentual >= isto perde o stock

# Entradas: um bitmask por jogador por tick.
const IN_LEFT := 1
const IN_RIGHT := 2
const IN_UP := 4
const IN_DOWN := 8
const IN_JUMP := 16
const IN_LIGHT := 32
const IN_STRONG := 64
const IN_GRAB := 128
const IN_SHIELD := 256
const IN_SPECIAL := 512

# Materiais (§5.3). Índices fixos: entram no hash e em replays.
const M_EMPTY := 0
const M_GLASS := 1
const M_DRYWALL := 2
const M_BRICK := 3
const M_CONCRETE := 4
const M_CORE := 5
# Entulho: escombro solto (§4.4). Não sustenta estrutura; cai como areia; classe baixa.
const M_RUBBLE := 6
const MAT_NAME := ["vazio", "vidro", "divisória", "tijolo", "concreto", "núcleo", "entulho"]
# HP por célula de 8 px. R de uma coluna = soma do HP das células tocadas.
const MAT_HP := [0, 5, 20, 70, 300, 0, 15]
# Absorção por coluna rompida, em milésimos da energia restante.
const MAT_ABSORB := [0, 40, 90, 160, 260, 1000, 60]
# Restituição do quique, em milésimos.
const MAT_REST := [0, 150, 250, 350, 450, 450, 100]
# Velocidade mínima (sub/tick) para romper: vidro quebra com pouco, concreto pede lançamento forte.
const MAT_MIN_V := [0, 512, 768, 1024, 1280, 999999, 512]

# Arquétipos placeholder (§0.1). Medidas em px, velocidades em sub/tick, gravidade em sub/tick².
# weight: multiplicador de knockback recebido, em milésimos.
const FIGHTERS := {
	"leve": {"w": 20, "h": 44, "mass": 80, "walk": 896, "air": 768, "accel": 128, "air_accel": 72,
		"jump": 2150, "djump": 1900, "gravity": 96, "max_fall": 1792, "fast_fall": 2560, "weight": 1150},
	"medio": {"w": 24, "h": 50, "mass": 100, "walk": 768, "air": 704, "accel": 112, "air_accel": 64,
		"jump": 2048, "djump": 1792, "gravity": 102, "max_fall": 2048, "fast_fall": 2816, "weight": 1000},
	"pesado": {"w": 30, "h": 56, "mass": 130, "walk": 640, "air": 576, "accel": 96, "air_accel": 48,
		"jump": 1900, "djump": 1600, "gravity": 110, "max_fall": 2304, "fast_fall": 3072, "weight": 850},
}


static func fdiv(a: int, b: int) -> int:
	## Divisão com arredondamento para baixo (a de GDScript trunca para zero).
	var q := a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


static func isqrt(n: int) -> int:
	## Raiz inteira por Newton: maior r com r*r <= n. Contrato de arredondamento da simulação.
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


static func energy(mass: int, vx: int, vy: int) -> int:
	## E = ½·m·v², v em px/tick. Unidade própria do jogo, não joules.
	return mass * (vx * vx + vy * vy) / (2 * SUB * SUB)
