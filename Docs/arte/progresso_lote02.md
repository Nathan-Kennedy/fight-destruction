# Progresso do lote 02 — assets de produção

Registro vivo, atualizado a cada etapa (pedido do dono). Prompts: [prompts_arte_lote02.md](prompts_arte_lote02.md).
Status dos assets: tudo **candidate** até o dono aprovar.

Legenda: ✅ feito · 🔁 refazer · ⏳ falta gerar · ⚠ gerado com ressalva

## Linha do tempo

| Data/hora | Etapa | Quem | Resultado |
|---|---|---|---|
| 24/09 ~12:30 | Prompts do lote 02 escritos (identidades travadas, regras de folha, regras de combinação) | Opus | [prompts_arte_lote02.md](prompts_arte_lote02.md) |
| 24/09 ~12:35 | Geração em 5 processos paralelos (3 lutadores, cenário+props, fx+ui) | Astra (Codex) | 35 imagens; parou no limite de uso da assinatura (volta 17:38) |
| 24/09 ~12:40 | Integração no Godot preparada com fallback para placeholder | Opus | sprite_lib, lutador por estado, grade texturizada por shader, interiores, parallax, props com dano |
| 24/09 ~13:00 | VFX procedural | Opus | faíscas, lascas por material, fumaça, anéis; pós-processo (onda de choque, aberração, impact frame, speed lines, vinheta); tremor no hitstop, flash, afterimage, rastro, squash/stretch; F6 desliga flashes |
| 24/09 ~13:10 | Pipeline `tools/art/process_sheets.py` | subagente Claude | recorte, pivô nos pés, escala única por lutador, métricas de consistência, GIFs e pranchas em `art/lote02/_preview/` |
| 24/09 ~13:10 | Pesquisa de assets CC0/MIT e referências de VFX (Smash, Sparking Zero, FighterZ, Strive, Rivals) | subagente Claude | em andamento → `art/third_party/` |
| 24/09 ~13:30 | Primeira integração verificada em captura | Opus | Brasa e Faísca animadas no jogo, fundo da cidade, texturas de tijolo/concreto/divisória/vidro/núcleo na grade, ilha caindo texturizada, cacos, rastro e afterimage. Testes passam. Interiores ainda lisos (sem arte) |
| 24/09 ~13:40 | Direção nova do cenário (cidade v2) e regras de qualidade registradas | dono → Opus | prompts §8 |
| 24/09 ~14:00 | Estágio vivo refinado (rotina → medo/uau, moradores no interior) e elementos reativos especificados | dono → Opus | prompts §8.4–8.5, [design_elementos_reativos.md](../design_elementos_reativos.md) |
| 24/09 ~14:00 | Subagentes sem dependência do GPT: (a) elementos reativos na sim + luz 2D + placeholders; (b) camada de estágio vivo com placeholders | subagentes Claude | em andamento |
| 24/09 ~14:30 | Pesquisa concluída: 16 pacotes CC0/MIT (~108 MB) + 17 shaders em `art/third_party/` com licença e origem; catálogo e [REFERENCIAS_VFX.md](../../art/third_party/REFERENCIAS_VFX.md) (Smash, SF6, Strive, FighterZ) | subagente Claude | ✅ |
| 24/09 ~14:40 | Integrados do pacote de terceiros: faíscas anime (Sinestesia, CC0), anéis dourado e de fogo, fumaça e brilho ciano (para_particlefx, CC0) em `game/assets/third_party/` com licenças; flipbooks em grade; camadas de acerto estilo Smash; tremor de câmera por "trauma" (GDC 2016) | Opus | ✅ capturado. Falta da lista da pesquisa: fórmula de hitstop do Smash (mexe na sim, depois do agente de fixos), hit_flash em shader, PolygonFracture para cacos, rachadura por ruído `Cracks`, impact frame mangá no golpe final, rastro na cor do atacante |
| 24/09 ~15:00–17:00 | Subagentes de elementos reativos e de estágio vivo pararam no limite de uso do Claude (reset 17:00); `main.gd` ficou sem compilar no meio da integração | — | retomados às 17:02 com o contexto; corrigindo |
| 24/09 ~17:15 | Elementos reativos concluídos: `fixtures.gd` na sim (água, vapor, hidrante, gás→fogo, botijão com aviso, transformador, fiação, poste e luminária que entortam, neon), botijão e extintor como props, luz 2D (CanvasModulate + cones que giram), placeholders procedurais, cena `--scene fixos`, 7 testes novos, versão de replay 3 | subagente Claude | ✅ testes 60 s passam; capturas conferidas (poste entortado, vapor empurrando, explosão, cone da luminária) |
| 24/09 ~17:25 | Estágio vivo concluído: figurantes vetoriais com rotina → medo/uau (crianças, executiva, fotógrafo com flash, vendedor, streamer, idosa com laranjas, rapaz de fone), moradores que aparecem quando o cômodo abre (cozinha, sofá/TV, escritório, banho com cortina), pombos, gato, lanternas, neon que falha, pétalas, vapor, dirigíveis/balões em parallax, bonde/van/scooter; F8 desliga | subagente Claude | ✅ capturas conferidas; hash da sim igual com e sem a camada |
| 24/09 ~17:30 | Bateria completa com fixos + estágio vivo | Opus | ✅ 60 s × 4 sementes, pior tick 1,8 ms. Pendente: regra `npc`/`amb` no `process_sheets.py` para trocar placeholders por sprites |
| 24/09 17:45 | Retomada: cenário antigo guardado em `art/lote02/bg/rev1/`; JSONs órfãos (falhas do limite) removidos; 2 processos: (a) lutadores — strongs rev 2, fall/land/burst/shield/grab/carry/throw, resto e expressões; (b) cidade v2 + npc/amb + props + fixos + fx + ui + bordas. Pipeline ganhou regra `npc` (escala da rotina vale para as reações) | Astra + Opus | em andamento |
| 24/09 ~18:10 | Primeiros da retomada: strongs rev 2 dos três (escala correta, smear e impacto), cidade v2 (céu com dirigíveis, balões de carpa e de ar quente; skyline com pagodas, cerejeiras e monotrilho). Processados e no jogo; camadas de fundo reescaladas para ler como distantes e escurecidas (§9.6) | Astra + Opus | ✅ capturado |
| 24/09 ~18:00 | **Corte de escopo aprovado pelo dono** (ritmo ~11 imagens/h com autorrevisão; o conjunto completo levaria 10–12 h). Processos anteriores encerrados; relançados só com: lutadores land/shield/grab/carry_idle/carry_run/throw_obj/burst; interiores v2; figurantes pedestre_a, fotografo, idosa_sacola, vendedor, cozinha (rotina+medo+uau); props caixa/barril/maquina/botijao/extintor; fx explosao_anel/poeira/vidro_estilhaco/aviso_colapso (~48 imagens) | dono → Opus → Astra | em andamento |
| 24/09 18:03 | Limite do Codex (plano Plus) de novo, libera ~22:45. Saíram: land dos três, interiores v2 loja e escritório (conferidos no jogo: ótimos). Faltam 25 da lista cortada: shield/grab/carry_idle/carry_run/throw_obj/burst dos três (grab da Brasa já existe), interior fundos, 5 figurantes × 3, 5 props, 4 fx | Astra | retomada agendada 22:47 |
| 24/09 | HUD de produção procedural (`game/view/hud.gd`), fiel a `ui_tela_gameplay_hud`/`ui_prancha_hud`: painel arredondado com brilho por jogador (P1 laranja, P2 ciano), retrato recortado da âncora (tabela configurável + heurística, silhueta de fallback), nome, chip P1/P2/CPU, stocks com mini-retrato que estouram e apagam, % grande em itálico pesado com contorno que esquenta branco→amarelo→laranja→vermelho, treme acima de 120% e dá "pop" ao subir, anel da explosão que brilha quando pronta, barra de escudo, banners GO!/GAME! com linhas de velocidade, callout KO!/SOTERRADO! na cor de quem caiu; ajuda e debug em caixas limpas. Layer 10, acima do pós-processo | subagente Claude | ✅ capturas `captures/hud` (vitrine) e `captures/hud_colapso` conferidas em 1280×720; prévia em 1920×1080 nítida (MSDF). Candidate até o dono aprovar |
| 24/09 ~19:30 | Áudio completo só com CC0 (antes o jogo não tinha som): 16 pacotes em `art/third_party/` (Kenney sci-fi/rpg/impact + 13 do OpenGameArt) com licença e origem; 235 sons semânticos em `game/assets/sfx/` (+ LICENSES.md), feitos por `tools/audio/build_sfx.py`, que também sintetiza o que não achei (concreto grande, desmoronamento, rangido, faísca, choque, revoada). `game/view/audio_director.gd`: pool com teto de vozes por categoria, pitch/volume aleatórios com RNG próprio, anti-repetição, ruptura em camadas por material (impacto + ruptura + grande + cauda) com volume pela energia e pelo nº de células, whoosh no startup, loops posicionais dos fixos, ambiente de rua e pássaros, público lido do estágio vivo, buses SFX/Amb com limitador e ducking; F9 muta; `--audio-log` | subagente Claude | ✅ testes 10 s passam; capturas vitrine/colapso/fixos rodam com log conferido. Mixagem ainda não ouvida por humano |
| 24/09 ~19:00 | Profundidade 2.5D (pedido do dono): `view/depth_view.gd` + `depth_floor.gdshader` — parede de fundo dos interiores rola 12% mais devagar que a câmera, piso do cômodo em 12 faixas com parallax decrescente até o plano de jogo, calçada fora do prédio com faixa em perspectiva (tile estreita e escurece no fundo). Só visual | Opus | ✅ capturado; efeito é de movimento, conferir no playtest |
| 24/09 ~20:00 | Sensação de combate + VFX restantes da pesquisa | Opus | Sim: hitstop por dano com teto 14 (`3 + dano·2/3 + kb/1024`), input buffer 5 ticks (vale no hitstop), coyote 4 ticks, teste de navegabilidade §4.6 (3 cenários, passa); replay `versao` 4. Visual: cacos por fratura Delaunay (PolygonFracture, MIT) com textura do material em vidro/tijolo/concreto, rachadura progressiva por HP (`Cracks 1`, CC0) no `matter.gdshader`, impact frame mangá no KO e em golpe ≥ 150%/kb ≥ 3000 (1/s, respeita F6), Finish Zoom de tela no golpe com KO previsto, tremor do atacante no hitstop. Conferido em `captures/feel/` |
| 24/09 ~19:10 | Pedido: interiores e cenário em planos de profundidade separados (fundo, piso, móveis, frente) com parallax próprio | dono → Opus | anotado em prompts §8.6; depth_view preparada |

## Lutadores (folha → processado → no jogo)

| Animação | Faísca | Brasa | Bloco |
|---|---|---|---|
| anchor | ✅ | ✅ | ✅ |
| idle (8) | ✅ | ✅ | ✅ |
| run (8) | ⚠ f6 menor | ✅ | ✅ |
| jump (6) | ✅ | ✅ | ✅ |
| jab (6) | ✅ | ✅ | ✅ |
| strong (8) | ⏳ | 🔁 ~25% menor que o idle, flash vaza da célula | 🔁 ~25% menor, pés fora da base |
| hurt (6) | ⚠ fundo em gradiente (pipeline tirou) | ✅ | ✅ |
| grab (6) | ⏳ | ✅ | ⏳ |
| fall, land, strong_up, stomp, spike, grabbed, carry_idle, carry_run, throw_obj, shield, roll, spot_dodge, air_dodge, stun, ko, victory, burst | ⏳ | ⏳ | ⏳ |
| expressoes | ⏳ | ⏳ | ⏳ |

No jogo, animação que falta usa a mais próxima (ex.: `fall`→`jump`, `strong_up`→`strong`).

## Cenário, props, efeitos e interface

| Grupo | Feito | Falta |
|---|---|---|
| Fundos | ✅ bg_ceu, bg_skyline_far, bg_skyline_mid, bg_rua_near | — |
| Texturas | ✅ vidro, divisória, tijolo, concreto, núcleo, entulho | ⏳ rua; ⚠ núcleo e vidro com costura de tile a revisar |
| Interiores | — | ⏳ loja, escritório, fundos |
| Kits | — | ⏳ brk_bordas, dec_rachaduras, mod_fachada_detalhes |
| Props | — | ⏳ caixa, barril, máquina, extras |
| Efeitos | ✅ acerto_leve, acerto_forte, escudo, escudo_quebra | ⏳ explosao_anel, poeira, vidro_estilhaco, aviso_colapso |
| Interface | — | ⏳ painéis P1/P2, retratos, ícones, banners |

## Próximo lote (adiado no corte de 24/09)

strong_up, stomp, spike, grabbed, roll, spot_dodge, air_dodge, stun, ko, victory e expressões dos três
lutadores; figurantes pedestre_b, streamer, sofa_tv, banho, escritorio, criancas; amb_*; arte dos fixos
(postes, canos, transformador, hidrante, neon); fx_jato_*/fogo/faisca_eletrica/poca; ui (painéis,
retratos, ícones, banners); brk_bordas, dec_rachaduras, mod_fachada_detalhes v2, mod_textura_rua.

## Pendências abertas

- **Opção Blender (dono, 24/09 noite):** testar alguns assets modelados no Blender 5.1 (instalado) e
  renderizados em toon para o jogo; começar por objetos e fixos, lutador só se der certo. Plano e
  critério de bake-off em [opcao_blender.md](opcao_blender.md).

- **Profundidade em camadas (dono, 24/09 ~19:10):** parallax dos interiores precisa de piso como asset
  separado, móveis/objetos mais próximos recortados com parallax próprio, e a mesma regra no resto do
  jogo (rua, primeiro plano). Especificação em [prompts_arte_lote02.md §8.6](prompts_arte_lote02.md);
  o código já aceita as camadas quando existirem. Gerar no próximo lote (interiores em 4 camadas).

0. **Direção nova do dono (24/09):** na próxima geração, substituir TODO o cenário pela cidade v2
   (fusão costa do Pacífico + Tóquio, inspirada nas qualidades de Operação Big Hero / Kingdom Hearts
   3, com balões e dirigíveis voando) e subir bastante a qualidade das imagens, com autorrevisão do
   Astra. Especificação em [prompts_arte_lote02.md §8](prompts_arte_lote02.md). Esclarecimento:
   não é para copiar; o objetivo é um **estágio vivo** como os de Street Fighter (público reagindo,
   gente nas janelas, veículos, animais, luzes, balões) — assets e comportamento na §8.4.
   Refinamento: figurantes em rotina calma (caminhando, fotografando, gravando, vendo TV, no banho,
   cozinhando, trabalhando) que só reagem com medo ou "uau" quando a luta chega perto; moradores
   aparecem dentro do prédio quando a fachada abre.
0b. **Elementos reativos (24/09):** canos de água/vapor/gás, botijões, transformador, hidrante, postes
   e luminárias que entortam ou quebram (luz muda de direção), neon, extintor. Design em
   [../design_elementos_reativos.md](../design_elementos_reativos.md); arte na fila (prompts §8.5);
   lógica e placeholders sendo feitos por subagente Claude.
1. Refazer `strong` da Brasa e do Bloco (escala e base).
2. Gerar o que falta depois das 17:38 (ordem de prioridade no agendamento).
3. Avaliação do Astra sobre o conjunto (depende do limite do Codex).
4. Aprovação do dono, asset por asset.
