# Contrato mínimo da simulação (M1–M2)

Vale para `game/sim/`. Mudança aqui muda replays e hashes: registrar em ADR e subir `versao` do replay.

## Tempo
- 60 ticks fixos por segundo. `MatchSim.step(inputs)` avança exatamente um tick.
- Render interpola entre o tick anterior e o atual; nunca escreve no estado.
- Hitstop (`freeze`) congela o mundo inteiro por N ticks. Durante ele a entrada continua sendo
  registrada: `prev_in` acompanha o controle e os apertos entram no input buffer (abaixo), que não
  corre no congelamento. Botão apertado e solto dentro do hitstop vale quando ele termina.
- Duração (`MatchSim.hitstop_for`, versão 4): `min(max(3 + dano·2/3 + kb/1024, hitstop_da_tabela), 14)`.
  Inspirado no hitlag do Smash (`dano·0,65 + 6`, teto 30), mas com teto 14 (~0,23 s a 60 Hz)
  porque aqui o congelamento é global. Jab 3% → 5; forte 13% → 12 a 0% e 13 a 100%; explosão → 12–13.
  O campo `hitstop` da tabela vira piso. Escudo: × 2/3 (Smash 0,67), sem o termo de kb. Dano de
  cenário sem golpe (fogo, choque, `hitstop` 0): `min(kb/512, 4)`. Ruptura de parede:
  `min(1 + R/400, 5)`; carimbo com `cell_dmg ≥ 35`: 3; explosão de elemento: 6.

## Unidades
- Posição e velocidade: inteiros em subpixels, `SUB = 256` por pixel de mundo. Velocidade em sub/tick.
- Gravidade/aceleração: sub/tick². Ângulos de golpe: vetor inteiro em 1/1024 (sem trigonometria).
- Célula da grade: 8×8 px. Grade 160×60 (1280×480 px). Fora da grade é vazio.
- Lutador: âncora no centro dos pés; caixa `[x−hw, y−h, x+hw, y]`.
- Energia: `E = m·(vx²+vy²) / (2·SUB²)`, ou seja ½·m·v² com v em px/tick. Unidade do jogo.
- Divisão inteira de GDScript trunca para zero; onde o sinal importa usar `fdiv` (para baixo).
  Raiz: `isqrt` (Newton, maior r com r² ≤ n).

## Entradas
Bitmask por jogador por tick: `LEFT 1, RIGHT 2, UP 4, DOWN 8, JUMP 16, LIGHT 32, STRONG 64,
GRAB 128, SHIELD 256, SPECIAL 512`. Golpe/pulo/agarrão/explosão disparam na borda (apertou neste tick); escudo vale
enquanto segurado. Replay = lista de `[j1, j2]` por tick (`versao` 4 desde hitstop por dano, buffer
e coyote; 3 com os elementos reativos; 2 no M2).
- **Input buffer (5 ticks, `BUFFER_TICKS`)**: pulo, leve, forte, agarrar e explosão apertados quando o
  lutador não pode agir (recovery, lag, hitstun, esquiva, hitstop) ficam em `buf`/`buf_t` e disparam no
  primeiro tick possível dentro da janela. O aperto mais recente substitui o anterior. Começar um golpe
  ou arremesso consome todos os botões de golpe do buffer; pular consome o pulo. Assim um aperto gera
  uma ação só. O agarrão segurando oponente usa só o aperto do tick (sem buffer). Pulo que sai do
  buffer com o botão já solto é pulo curto (mesma regra da altura variável).
- **Coyote time (4 ticks, `COYOTE_TICKS`)**: quem sai do chão sem pular (borda, piso rompido) ainda
  tem o pulo do chão (sem gastar o salto duplo) por 4 ticks no ar. Pular, ser lançado, quebrar o
  escudo, esquivar no ar ou reaparecer zera. `buf`, `buf_t` e `coyote` entram no hash e no snapshot.

| | Teclado J1 | Teclado J2 (alternativa sem numpad) | Gamepad (N → jogador N) |
|---|---|---|---|
| Mover | WASD | setas | analógico esquerdo / direcional |
| Pular | Espaço | Numpad 0 (Insert) | A |
| Leve | F | Numpad 1 (Delete) | X |
| Forte | G | Numpad 2 (End) | B |
| Explosão (especial) | J | Numpad 4 (Page Up) | Y |
| Agarrar / arremessar | H | Numpad 3 (Page Down) | RB |
| Escudo / esquiva | Shift | Numpad Enter (Home) | LB ou gatilhos |

Forte + cima = golpe para cima; forte + baixo no chão = pisada (quebra piso); no ar = spike.
Explosão: carrega 10 ticks parado no ar, destrói tudo num raio de 56 px em volta do corpo
(inclusive concreto e entulho, nunca núcleo), lança oponentes e objetos para fora; recarga de 4 s.
Andando no chão, o lutador sobe sozinho degraus de até 2 células (16 px).
Escudo + esquerda/direita = rolamento; escudo + baixo = esquiva parada; escudo no ar = esquiva
aérea (uma por salto, direcional). Agarrão pega oponente (ignora escudo) ou objeto. Segurando
oponente: cima/baixo/trás/frente (ou qualquer golpe) arremessa. Segurando objeto: leve, forte ou
agarrar arremessa (com cima = para cima; com baixo no ar = para baixo).

## Ordem de um tick
1. Cada lutador na ordem do ID: estado (hitstun, atordoado, esquiva, segurando, escudo, livre)
   → eixo X → eixo Y → teste de chão.
2. Posições presas: agarrado vai para a frente de quem segura; objeto segurado vai às mãos.
0. `fixtures.begin_tick()`: zera os limites por tick da cadeia de explosões.
3. Golpes: no primeiro frame ativo, carimbo no cenário (todo golpe lasca; `cell_dmg` por célula),
   golpe em objeto livre e em fixo do cenário (`fixtures.hit_rect`; a explosão especial usa
   `fixtures.blast`); depois acerto (um alvo por golpe): agarrão, escudo ou lançamento.
4. Objetos (`props.gd`): pavio do botijão e jato do extintor (correm até na mão), física, impacto
   contra a grade, acerto em lutador. `prop_explode` vira explosão radial na hora; depois o jato dos
   extintores ativos empurra lutadores.
4b. Fixos (`fixtures.gd`, na ordem do id): âncora perdida, contato de corpo lançado (hitstun e
   |v| ≥ 3 px/tick) ou objeto arremessado (|v| ≥ 2 px/tick), timers, fio preso a poste quebrado,
   ignição de gás (faísca/fogo a 80 px, só depois de 40 ticks vazando), água apagando fogo, e por
   fim os efeitos: `fix_push` (jato), `fix_hurt` (fogo/choque/vapor), `fix_explode` (botijão fixo),
   `fix_ignite_prop`. O integrador aplica na ordem em que vêm.
5. Estrutura (`structure.gd`): análise de apoio se a grade mudou, avisos, ilhas caindo, entulho.
   Ilha caindo esmaga quem toca (um acerto por ilha); com percentual ≥ `ENV_KO_PCT` e no chão, é
   KO ambiental (soterrado). Quem ficou dentro de matéria sobe até o primeiro espaço livre.
6. Blast zones e stocks.
Eventos saem em `events` com `(tick, emitter, seq, kind)`; emitter −1 = cenário.

## Elementos reativos (Docs/design_elementos_reativos.md)
- Estados inteiros: `IDLE 0`, `ACTIVE 1`, `FIRE 2` (só gás), `DONE 3`; `t` (timer), `age` (ticks
  desde a troca), `angle` em 1/1024 de volta (poste: soma do golpe no sentido de `dx`; luminária:
  pêndulo inteiro `a16`/`av`), `cd`/`hcd` (recargas de gatilho e de dano). Tudo no hash e snapshot.
- Explosão de elemento (`_explode`): células com centro no raio levam 320 de dano (rompe concreto
  novo, nunca núcleo); lutadores no raio: dano 12, base 1000, crescimento 9, direção radial com viés
  para cima (a mesma de `_radial_dir`); objetos lançados; depois `fixtures.blast` no mesmo raio.
  Raio 56 px (botijão fixo) e 44 px (botijão objeto).
- Cadeia: explosivo acionado por explosão, fogo ou chão arrancado é um elo; no máximo 2 elos por tick
  e 6 por partida (`chain_take`); sem cota o botijão não acende (o fixo tomba apagado). No máximo 2
  botijões fixos detonam por tick; o resto espera o tick seguinte.
- Eventos novos: `explosion {x, y, radius, source}`, `fix_state {fix, type, state, x, y, cause}`,
  `fix_spark`, `fix_bend {angle}`, `fix_hurt {target, dmg, kb, stun}`, `fix_extinguish`,
  `prop_fuse`, `prop_jet {dir}`, `prop_explode {x, y, thrower, holder}`.

## Colisão e impacto (§5.2)
- Varredura por eixo em sub-passos de no máximo meia célula; contato na primeira linha de células
  sólidas que o corpo passaria a ocupar. Não existe colisão derivada ou atrasada.
- Só corpo em hitstun com velocidade normal ≥ `BOUNCE_MIN` faz impacto. `R` = soma do HP das
  células da linha tocada. Rompe se `E ≥ R`, `|v_normal| ≥ MAT_MIN_V` do material mais duro e
  não houver núcleo; aí `E' = (E−R)·(1−absorção)` e a velocidade escala por `√(E'/E)`.
- Senão quica com restituição do material, e o dano `E` é distribuído nas células
  (só se `|v_normal| ≥ MAT_MIN_V/2`). Dano acumula.
- Até `MAX_BREAKS` linhas rompidas por lançamento.

## Invariantes testadas (`Testar.bat`)
- Nenhum lutador ativo dentro de matéria, em nenhum tick do autotest.
- Mesmas entradas → mesmo hash (duas execuções por semente).
- Snapshot em T + restore + mesmas entradas → mesmo hash.
- Navegabilidade (§4.6, `_test_navigability`): três destruições máximas scriptadas ("térreo": paredes
  do térreo do prédio; "colapso": tudo destrutível abaixo da linha 36, inclusive laje da rua, mureta
  e marquise; "arrasado": o colapso e depois todo o entulho), com estrutura e entulho assentados. Uma
  busca em grafo sobre a grade (corpo 4×7 células do pesado; andar ±1 célula subindo degrau de até 2;
  cair da borda; pular até 10 células de altura, que é 75% do salto + duplo do pesado, e andar até 6
  no topo) tem que ligar cada um dos 4 spawns a todos os outros. Um muro de núcleo de 11 células
  bloqueia a busca (conferido), então o teste não passa por vacuidade.
