# Fight Destruction

Platform fighter 2D em que a luta destrói e transforma a cidade. Briefing completo em
[Prompt_Mestre_Jogo_2D_Destrutivo.md](Prompt_Mestre_Jogo_2D_Destrutivo.md) (v3.1).

## Estado atual (leia isto primeiro)

**Marco: M1 e parte técnica do M2 em greybox. Ainda não houve playtest humano.**

O que já funciona (verificado em 24/09/2026):
- Duelo local 1v1 com teclado compartilhado ou gamepads, J2 pode ser CPU (F2).
- Três arquétipos placeholder (leve, médio, pesado): andar, pulo duplo, pulo curto, queda rápida.
- Golpes: leve, forte lateral, forte para cima, pisada no chão e spike no ar. Hitstop, hitstun,
  knockback por percentual, 3 stocks e blast zones fixas.
- **Todo golpe quebra o cenário:** o soco leve estoura vidro, o forte rompe tijolo em dois acertos
  e concreto em seis; o dano acumula e aparece escurecendo a célula.
- **Escudo, rolamento, esquiva parada e esquiva aérea.** O escudo gasta e quebra (atordoa).
- **Explosão (J / Num4 / Y):** destrói tudo em volta do personagem num raio de 56 px, inclusive
  concreto e entulho, e lança quem estiver perto. Recarga de 4 s (aparece no HUD). Serve para sair
  de soterramento e abrir caminho. Andando, o personagem sobe degraus de até 16 px sozinho.
- **Agarrão:** prende o oponente (vence o escudo) e arremessa para frente, trás, cima ou baixo.
  O arremesso para baixo com percentual alto fura a laje da rua.
- **Objetos:** caixas, barris e uma máquina de venda. Agarrar pega o objeto; golpe ou agarrar
  arremessa. O objeto quebra vidro e divisória, acerta o oponente e se despedaça. Golpear um objeto
  solto também o lança.
- **Colapso anunciado:** o que perde apoio racha (brilho laranja e poeira por 50 ticks), cai como
  bloco, rompe o que for frágil embaixo e vira entulho que escorre como areia e forma pilha.
  Quebrar o pilar do térreo derruba a frente do prédio; quebrar a divisória não derruba nada.
- **Elementos reativos:** canos de água, vapor e gás (vira fogo), hidrante, botijão com aviso que
  explode (fixo ou arremessável), extintor, transformador e fiação com choque, postes e luminárias que
  entortam para o lado do golpe (a luz gira junto) e quebram, neon que falha. Luz 2D de entardecer (F7).
- **Estágio vivo (placeholders vetoriais):** público em rotina que reage com medo ou empolgação quando a
  luta chega (fotógrafo com flash, crianças, vendedor, idosa…), moradores que aparecem quando a fachada
  do cômodo cai, pombos, gato, neon, pétalas, dirigíveis e balões no céu, bonde passando (F8).
- **VFX:** faíscas anime em camadas (CC0), anéis de choque, lascas por material, fumaça, rastro na cor
  de quem bateu, tremor no hitstop, afterimage, onda de choque e impact frame na tela (F6 desliga flashes).
- **Arte:** sprites ilustrados dos três lutadores e texturas de material já no jogo (lote 02, candidatos);
  progresso em `Docs/arte/progresso_lote02.md`.
- **KO ambiental:** ser soterrado por colapso com 100% ou mais tira o stock; abaixo disso, esmaga.
- Grade de destruição 8 px com vidro, divisória, tijolo, concreto, núcleo e entulho.
- `Testar.bat`: testes de integração + suítes `structure` e `props` + autotest de bots em 4 sementes.
- `Capturar.bat`: demo da vitrine → `captures/demo/`. Demo do colapso:
  `Godot --path game -- --capture ../captures/colapso --scene colapso`.

Plano atual: [Docs/plano_desenvolvimento.md](Docs/plano_desenvolvimento.md) (visão do dono em [Docs/visao_dono_proximas_prioridades.md](Docs/visao_dono_proximas_prioridades.md)).

O que falta (próximos passos, §23):
- **Playtest humano do M1/M2**: sensação de movimento, golpe, escudo, agarrão, arremesso e se o
  colapso é legível e dá para fugir. Quem decide é o dono do projeto.
- Teste de navegabilidade por bot após destruição máxima (§4.6); input buffer e coyote time (§5.5).
- Arte: tudo é placeholder de retângulos. O bake-off visual (§19) ainda não começou.

## Como rodar

| Ação | Comando |
|---|---|
| Jogar | `Jogar.bat` (ou `Jogar.bat --cpu`, `--p1 pesado --p2 leve`) |
| Jogar contra o bot | `JogarVsBot.bat` (aceita `--p1`/`--p2`) |
| Testes | `Testar.bat` |
| Capturas da demo | `Capturar.bat` |
| Replay | `Jogar.bat --replay "%APPDATA%\Godot\app_userdata\Fight Destruction\replays\<arquivo>.json"` |

Controles do J1 (teclado): WASD move, Espaço pula, F leve, G forte (com W: para cima; com S: pisada/spike),
H agarra/arremessa (pega oponente ou objeto), J explosão (recarga 4 s), Shift escudo (+A/D rola, +S esquiva,
no ar esquiva aérea). J2: setas, Num0 pula, Num1 leve, Num2 forte, Num3 agarra, Num4 explosão, NumEnter
escudo (sem numpad: Ins/Del/End/PgDn/PgUp/Home). Gamepad: A pula, X leve, B forte, Y explosão, RB agarra, LB/gatilho escudo.

Teclas: F1 debug, F2 CPU no J2, F3 hitboxes, F5 salva replay, F6 flashes de tela, F7 luzes, F8 público/céu vivo,
F9 som, R reinicia, F11 tela cheia, Esc sai. Detalhes em [Docs/contrato_sim.md](Docs/contrato_sim.md).

## Estrutura

```
game/sim/     simulação determinística (inteiros, sem nós): match_sim, matter_grid, structure, props, attacks, sim_const
game/input/   leitura de teclado/gamepad e bot
game/view/    apresentação: cenário, lutadores, destroço, câmera
game/tests/   testes headless
Docs/         contrato da simulação, estado, revisões
```

A simulação não conhece a apresentação: expõe estado e `events`, e as views só leem e escutam.
