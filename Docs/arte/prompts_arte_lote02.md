# Prompts de arte — lote 02 (assets de produção a partir da tela de gameplay)

Autor dos prompts: Opus 5.5. Geração: GPT-6 Astra (ferramenta de imagem do Codex).
Data: 24/09/2026. Status de tudo: **candidate** até o dono aprovar.

## 0. Pedido e decisões

Pedido do dono: "gere dessa mesma composição [a tela `ui_tela_gameplay_hud`], algo mais
profissional, separando em assets tudo corretamente e sprites; aumente a quantidade de frames por
animação para ficar fluido, sem perder a consistência".

Decisões do Opus (reversíveis, registradas no estado):
1. **Alvo visual = `art/concept/lote01/ui_tela_gameplay_hud.png`** (a referência de estilo). Isso
   significa sprites ilustrados cel-shaded em alta resolução desenhados em escala no jogo, e não
   pixel art de 640×360 (§9.2 fica em revisão; o dono gostou do ilustrado).
2. **Identidades travadas** (as imagens do lote 01 discordavam):
   - **Faísca (leve):** rapaz jovem e magro, cabelo branco com mechas ciano espetado para trás,
     cachecol longo ciano e branco, jaqueta curta branca e ciano com gola alta, luvas pretas sem
     dedo, calça preta justa com friso ciano, tênis preto e branco com solado ciano luminoso.
     (Como na régua e na tela de gameplay.)
   - **Brasa (média):** mulher atlética, pele morena, rabo de cavalo castanho-escuro alto, faixa
     laranja na testa com pontas soltas, top grafite com detalhes laranja, manoplas mecânicas
     laranja e grafite grandes, calça cargo laranja e grafite, botas laranja com sola branca.
     (Como na régua e no conceito dela.)
   - **Bloco (pesado):** exoesqueleto de demolição âmbar e verde-oliva, capacete com viseira âmbar
     brilhante, braços enormes com martelete hidráulico, faixas de perigo preto-amarelas nos
     antebraços, tanque e canos nas costas, pés largos. (Como na régua, no conceito e na tela.)
3. **Consistência entre frames:** cada animação sai numa única imagem (folha em grade), porque
   frames gerados juntos variam muito menos que frames gerados separados. A folha de identidade
   (`anchor`) de cada lutador é gerada primeiro e usada como imagem de referência de todas as
   animações dele.

## 1. Regras técnicas para TODA folha de sprite

Acrescentar ao fim de cada prompt de sprite:

> Sprite sheet for a 2D side-view fighting game. Strict side view, character facing RIGHT in every
> frame. Grid of 4 columns × 2 rows, 8 equal cells, read left-to-right then top-to-bottom as frames
> 1 to 8 of ONE continuous animation. The SAME character in every cell: identical proportions,
> costume, colors and scale; only the pose changes, with smooth in-between motion from one frame
> to the next. Feet (or lowest point when grounded) on the same baseline at 88% of the cell height;
> the character's body centered horizontally in each cell; nothing crosses cell borders. Clean
> cel-shaded anime illustration matching the reference image: thick dark outline (#15101C), two-tone
> flat shading, crisp rim light in the character's accent color. Fully transparent background
> (if transparency is impossible, flat pure magenta #FF00FF with no gradient and no shadow). No
> grid lines, no frame numbers, no text, no ground, no drop shadow, no effects outside the character
> unless the prompt asks for them.

Para animações com 6 frames: "Grid of 3 columns × 2 rows, 6 equal cells".

## 2. Lutadores

Tamanho de saída: 1536×1024 (8 frames, células de 384×512) ou 1536×1024 com 3×2 (células de 512×512).

Para cada lutador, **na ordem**:

### 2.0 `chr_<nome>_anchor` — folha de identidade (âncora)
> Character model sheet of <IDENTIDADE>, three views on a transparent background: strict side view
> facing right (large, full body), front view, back view, plus a close-up of the face and hands.
> Neutral standing pose. Clean cel-shaded anime illustration, thick dark outline, two-tone shading,
> rim light in the accent color. Consistent with the reference image. No text.

### 2.1 Animações (todas com o anchor e a tela de gameplay como referência)

| asset_id | frames | loop | descrição da animação (vai no prompt) |
|---|---|---|---|
| `chr_<nome>_idle` | 8 | sim | fighting-stance idle breathing loop: slight up-down bob of the torso, hair/scarf/cloth sway, fists guard; frame 8 flows back into frame 1 |
| `chr_<nome>_run` | 8 | sim | full run cycle: contact, down, passing, up for each leg; arms pumping; body leaning forward; hair and scarf trailing |
| `chr_<nome>_jump` | 6 | não | crouch anticipation, takeoff stretch, rising tuck, apex, falling with legs extending, landing crouch |
| `chr_<nome>_jab` | 6 | não | quick light punch: guard, wind-up, fast extension with small smear, full extension contact, recoil, back to guard |
| `chr_<nome>_strong` | 8 | não | heavy side strike: big anticipation twist, step in, smear frame, full-extension impact pose with a bright white-core star flash at the fist (frame 5), follow-through, recovery ×2, back to guard |
| `chr_<nome>_hurt` | 6 | não | launched by a heavy hit: impact recoil with eyes shut, body folding backward, spinning tumble ×3 in the air, uncurling |
| `chr_<nome>_grab` | 6 | não | grab and throw: reach forward, clutch, lift, pivot, throw forward with full arm swing, recover |
| `chr_<nome>_burst` | 8 | não | radial burst special: crouch and gather energy with glowing accent-color aura, energy tightening into the core, explosive release with a ring of light around the body (frames 5–6), dissipating, recover |

| `chr_<nome>_fall` | 6 | sim | falling loop in the air: arms up for balance, cloth and hair blowing upward, slight rotation back and forth |
| `chr_<nome>_land` | 6 | não | landing impact: legs absorb, deep crouch squash, small dust puff at the feet, rise back to stance |
| `chr_<nome>_strong_up` | 8 | não | upward heavy strike (uppercut / rising hammer): crouch, spring up, arm sweeps overhead with smear, impact flash above the head (frame 5), follow-through, land back |
| `chr_<nome>_stomp` | 8 | não | ground stomp: lift one leg high, slam down with both fists/foot, cracks and debris burst at the feet (frames 5–6), recover |
| `chr_<nome>_spike` | 6 | não | airborne downward spike: tuck in the air, hammer both fists/foot downward with smear, impact flash below, recover in air |
| `chr_<nome>_grabbed` | 6 | sim | being held by an opponent (opponent NOT drawn): lifted off the ground by the collar/torso, struggling, legs kicking, loop |
| `chr_<nome>_carry_idle` | 6 | sim | holding a heavy object overhead with both hands (object NOT drawn, hands clearly open at the same position above the head in every frame), knees slightly bent, breathing |
| `chr_<nome>_carry_run` | 8 | sim | running while holding an object overhead (object NOT drawn, hands stay at the same spot above the head), legs in full run cycle |
| `chr_<nome>_throw_obj` | 6 | não | throwing an object held overhead forward (object NOT drawn): lean back, whip forward, release, follow-through, recover |
| `chr_<nome>_shield` | 6 | sim | defensive guard crouch behind raised arms (the shield bubble is a separate effect, NOT drawn), tense breathing loop |
| `chr_<nome>_roll` | 8 | não | evasive roll forward along the ground: tuck, roll ×2 with afterimage-free clean poses, pop back up into guard |
| `chr_<nome>_spot_dodge` | 6 | não | spot dodge in place: quick sidestep lean into the background and back, body semi-transparent feel conveyed only by pose (no transparency in the art) |
| `chr_<nome>_air_dodge` | 6 | não | mid-air dodge: quick twist and tuck with a streak pose, back to falling pose |
| `chr_<nome>_stun` | 6 | sim | dizzy after the shield breaks: wobbling on the spot, head swaying, eyes spiraled; (stars are a separate effect, NOT drawn) |
| `chr_<nome>_ko` | 6 | não | knocked out / defeated: huge hit reaction, flying away shrinking pose, limp, last frame lying flat on the ground |
| `chr_<nome>_victory` | 8 | sim | victory pose loop, character-specific and heroic, confident smile/visor flash |

Regras para permitir **combinação** entre assets (pedido do dono):
- Nenhuma folha de lutador desenha outro lutador, objeto, efeito de escudo ou estrela de atordoado:
  cada coisa é um asset separado e o jogo compõe.
- Em `carry_*` e `throw_obj` as mãos ficam no mesmo ponto acima da cabeça, para o objeto encaixar.
- Em `grabbed` o corpo fica suspenso com o ponto de pega (gola/tronco) na mesma posição em todos os
  frames, para alinhar com a mão de quem agarra.
- Mesma luz (entardecer vindo da esquerda) e mesmo contorno em tudo, para nada parecer colado.

Frames por lutador: ~150 em 24 folhas. Total: ~450 frames + 3 âncoras + 3 retratos.

### 2.2 Expressões e retrato (por lutador)
| asset_id | conteúdo |
|---|---|
| `chr_<nome>_expressoes` | grade 4×2 de rostos (ombros para cima, vista 3/4): neutro, determinado, gritando golpe, dor, atordoado, rindo, bravo, vitória |

Estilo específico dos golpes: Faísca com raios ciano elétricos; Brasa com fogo/impacto laranja nas
manoplas; Bloco com poeira, lascas de concreto e brilho âmbar.

## 3. Cenário (a partir da tela de gameplay)

Todos em vista lateral/frontal ortográfica, mesmo estilo e luz de entardecer vindo da esquerda.

| asset_id | tamanho | fundo | prompt (essência) |
|---|---|---|---|
| `bg_ceu` | 1536×1024 | opaco | dusk sky only: violet-to-peach gradient, big soft setting sun low on the left, a few stylized clouds, one small airship silhouette; no buildings |
| `bg_skyline_far` | 1536×1024 | transparente | far skyline silhouettes of the retrofuturist city with the giant ring-shaped tower, hazy, low contrast, violet tones, bottom edge flat; nothing else |
| `bg_skyline_mid` | 1536×1024 | transparente | mid layer: apartment blocks with warm lit windows, elevated monorail with a train crossing, a few abstract neon signs (no readable text), bottom edge flat |
| `bg_rua_near` | 1536×512 | transparente | foreground street furniture strip: street lamps, trees in planters, metal railings, a banner pole; darker, bottom-aligned |
| `mod_textura_<material>` | 1024×1024 | opaco | seamless tileable front-view texture of one material, flat even lighting, no perspective: `vidro` (glass curtain wall with thin mullions and cold reflections), `divisoria` (warm beige drywall panels), `tijolo` (red brick courses), `concreto` (smooth grey poured concrete with form-tie holes), `nucleo` (dark steel plate with rivets and a yellow-black hazard stripe band), `entulho` (packed rubble of broken concrete and brick chunks), `rua` (asphalt and sidewalk slab top) |
| `mod_interior_loja` | 1536×768 | opaco | interior back wall of a cozy shop seen straight on: shelves, plants, pendant lamps, counter, warm light; no front wall, no people |
| `mod_interior_escritorio` | 1536×768 | opaco | interior back wall of an office floor: desks, monitors, bookshelf, plants, window blinds, warm lamp light; no front wall, no people |
| `brk_bordas` | 1536×1024 | transparente | sheet of broken-edge strips per material for hole borders, 6 rows: glass (jagged shards), drywall (crumbled paper edge), brick (stepped broken bricks), concrete (chunky edge with rusty rebar sticking out), rubble edge, asphalt edge; each strip horizontal and tileable |
| `dec_rachaduras` | 1536×1024 | transparente | decal sheet 4×2 of damage marks: hairline cracks, medium cracks, heavy spiderweb cracks, scorch mark, impact crater ring, orange glowing warning cracks, dust stain, bullet-free chipped paint |
| `mod_fachada_detalhes` | 1536×1024 | transparente | facade kit 4×2: window frame, shop awning, neon sign (abstract, no text), AC unit, drainpipe segment, fire escape segment, rooftop water tank, antenna |
| `prop_extras` | 1536×512 | transparente | extra street props 4×1: traffic cone, trash bin, fire hydrant, street bench |
| `mod_interior_fundos` | 1536×768 | opaco | interior back room / stairwell: stairs going up, doors, lockers, boxes, fluorescent light |

## 4. Objetos (props), cada um numa folha de 4 frames (grade 4×1, 1536×512, transparente)

| asset_id | frames | descrição |
|---|---|---|
| `prop_caixa` | 4 | wooden crate: intact, cracked, heavily damaged, broken apart into planks |
| `prop_barril` | 4 | teal steel barrel with hazard label (no readable text): intact, dented, badly dented, burst |
| `prop_maquina` | 4 | red retro vending machine with glowing panel and cans, abstract logo (no readable letters): intact, cracked glass, smashed, broken open with cans spilling |

## 5. Efeitos (flipbooks, grade 4×2 = 8 frames, 1536×768, transparente)

`fx_acerto_leve`, `fx_acerto_forte` (estrela de núcleo branco), `fx_escudo` (bolha ciano em loop),
`fx_escudo_quebra`, `fx_explosao_anel` (anel âmbar que expande), `fx_poeira`, `fx_vidro_estilhaco`,
`fx_aviso_colapso` (rachaduras laranja pulsando, loop). Cada prompt: "8-frame VFX flipbook of
<efeito>, centered in each cell, grows and fades smoothly across frames, anime platform-fighter
style, bright glossy colors with a white core, transparent background, no text".

## 6. Interface (transparente)

| asset_id | conteúdo |
|---|---|
| `ui_painel_p1`, `ui_painel_p2` | painel arredondado vazio (sem número, sem retrato), borda laranja (P1) / ciano (P2), espaço para retrato à esquerda, % ao centro e anel à direita |
| `ui_retratos` | 3 retratos quadrados na mesma folha 3×1: Bloco, Faísca, Brasa, busto em 3/4, fundo transparente |
| `ui_icones` | folha: stock de cada lutador (3), marcadores P1/P2, anel de recarga vazio/carregando/pronto, escudo |
| `ui_banners` | "GO!" e "GAME!" em letras itálicas grossas com linhas de velocidade |

Números de % serão renderizados pelo jogo com fonte, não pela imagem.

## 7. Pipeline depois da geração (feito pelo Opus e subagente Claude, não pelo gerador)

`tools/art/process_sheets.py`: fatia a grade, tira o fundo, recorta, alinha a base dos pés e o
centro horizontal (pivô), aplica **uma escala única por lutador** (a do idle), exporta frames,
atlas e JSON (§20.2) em `game/assets/`, e mede consistência (altura, largura, histograma de cor
contra a âncora, deslocamento do pivô). Frame que foge do limite é marcado para refazer, sem
correção silenciosa.

## 8. Revisão de direção do dono (24/09/2026, depois do lote 02 parcial) — VALE PARA A PRÓXIMA GERAÇÃO

Pedido do dono: "substituir o cenário por uma versão mais parecida com a cidade do Operação Big Hero,
que tem uma estética bem legal; daria para colocar um balão voando e outros elementos legais, assim
como no Kingdom Hearts 3 fizeram o mapa bem bonito; e aumentar bastante a qualidade das imagens".

**O que muda:** todo o cenário (seção 3: céu, skylines, rua, interiores, texturas de fachada, kit de
fachada) é **substituído** pela cidade v2 abaixo. Lutadores, efeitos e interface continuam.

### 8.1 Cidade v2 — "Nova Aurora" como fusão costa do Pacífico + Tóquio

Referência de **qualidades** (não copiar): a cidade de Operação Big Hero (San Fransokyo) e a versão
dela em Kingdom Hearts 3. Tirar: fusão de cidade litorânea montanhosa ocidental com Japão moderno,
luz dourada de fim de tarde, céu vivo cheio de coisas voando, riqueza de detalhe em camadas,
vitalidade e cor. **Não copiar:** a ponte-portão característica do filme, prédios, logotipos,
personagens ou qualquer marco reconhecível; nada de texto legível.

Elementos originais para usar:
- Sobrados de estilo vitoriano em ladeira com telhados de telha japonesa curvada; prédios altos
  com coroamento em pagode e varandas com lanternas.
- **Balões e dirigíveis:** dirigíveis-turbina (geradores eólicos flutuantes presos por cabos),
  balões em forma de carpa (koinobori) originais, balões de ar quente com padrões geométricos.
- Bondinhos em trilhos na ladeira, monotrilho elevado, cabos e fios cruzando a rua.
- Cerejeiras em flor com pétalas ao vento, lanternas de papel vermelhas, placas neon abstratas em
  formas de kanji estilizado **ilegível**.
- Porto ao fundo com uma ponte suspensa vermelha de desenho próprio (torres em treliça, não portão).
- Colinas ao longe com casas empilhadas e uma torre de antena original.

### 8.2 Assets de cenário v2 (substituem os da seção 3; mesmos asset_id com revision 2)

| asset_id | tamanho | fundo | prompt (essência) |
|---|---|---|---|
| `bg_ceu` (rev 2) | máximo que a ferramenta permitir, 16:9 | opaco | golden-hour sky over a Pacific-coast-meets-Tokyo city: warm peach and gold near the horizon fading to violet, big soft sun, layered stylized clouds with rim light, several floating wind-turbine airships tethered by thin cables, a couple of original koi-shaped balloons and patterned hot-air balloons at different distances; no buildings |
| `bg_skyline_far` (rev 2) | idem | transparente | far layer: hazy hills covered with stacked houses, a harbor with an original red lattice-tower suspension bridge (not a gate), distant pagoda-crowned skyscrapers and an antenna tower; atmospheric perspective, low contrast, bottom edge flat |
| `bg_skyline_mid` (rev 2) | idem | transparente | mid layer: skyscrapers with pagoda crowns and lantern-lit balconies, elevated monorail with a train, abstract neon signs with illegible stylized glyphs, cherry trees between buildings, bottom edge flat |
| `bg_rua_near` (rev 2) | 2:1 | transparente | foreground strip: hillside street with a cable-tram track, Victorian row-house facades with curved Japanese tile roofs, paper lanterns strung on wires, cherry blossom tree, street lamp; darker, bottom-aligned |
| `bg_elementos_ceu` | folha 4×2 | transparente | 8 separate sky props for animated parallax: 3 wind-turbine airships (different sizes), 2 koi balloons, 2 hot-air balloons, 1 flock of birds; each isolated, side view |
| `mod_fachada_detalhes` (rev 2) | folha 4×2 | transparente | curved Japanese tile roof segment, paper lantern string, bay window of a Victorian row house, neon sign with illegible glyph, AC unit, drainpipe, balcony with plants, rooftop water tank |
| `mod_interior_loja` / `_escritorio` / `_fundos` (rev 2) | 2:1 | opaco | same rooms, now with the city's fusion style (shoji-like partitions, lanterns, plants, warm light) |
| `mod_textura_*` | 1024 | opaco | mantém; regerar só `rua` com paralelepípedo e trilho de bonde |

O jogo já tem camadas de parallax (view/backdrop.gd); `bg_elementos_ceu` entra como objetos que
flutuam devagar na camada do céu (animação só visual).

### 8.3 Qualidade (vale para TODAS as próximas imagens, inclusive refações)

- Pedir a **maior resolução** que a ferramenta suportar; nunca abaixo de 1536 no lado maior.
- Acrescentar ao prompt: "masterpiece-level key art quality, highly detailed, crisp clean
  linework, rich layered lighting with warm golden-hour key light and cool shadows, detailed
  background depth, no blur, no smudged details, no AI artifacts, no melted shapes".
- **Autorrevisão do Astra:** depois de cada imagem, abrir, comparar com o prompt e com a referência
  (`ui_tela_gameplay_hud.png` e a âncora do lutador) e **regerar uma vez** se houver: forma derretida,
  detalhe borrado, identidade diferente, texto legível, fundo errado ou escala errada. Registrar a
  decisão no JSON (`self_review`).
- O pipeline pode aplicar upscale só nas prévias; o jogo usa a saída original recortada.

### 8.4 Cenário vivo (esclarecimento do dono)

"Não precisa copiar exatamente; quero o mapa bem vivo, assim como os Street Fighter e jogos
semelhantes fazem, deixam ele bem bonito." A cidade v2 é ponto de partida de estilo; o objetivo é
**vida**: o estágio se mexe o tempo todo e reage à luta. Referência de qualidade: estágios de
Street Fighter (II a 6), Garou, KOF XV, Skullgirls, Smash — público, animais, veículos, luzes
piscando, tudo em loop leve sem roubar a leitura dos lutadores (§9.6: fundo com menos saturação).

**Refinamento do dono:** "o público pode tirar foto, gravar, ou estar fazendo coisas da rotina,
como caminhando, banhando, assistindo TV; enfim, eles estão pacíficos até o momento que a luta chega
até eles, e aí ficam com medo, assustados ou impressionados."

Cada figurante tem **dois momentos**: rotina calma (em loop) → reação quando a luta chega perto.
Os moradores ficam **dentro do prédio** também, e aparecem quando a fachada some (§4.5): quem estava
vendo TV no sofá se assusta quando a parede explode ao lado.

Assets adicionais (folhas de sprite, transparente, mesmas regras de folha da §1, vista lateral;
personagens originais e diversos, proporção um pouco menor e menos saturada que os lutadores):

| asset_id | frames | rotina (loop) | reações (cada uma numa folha própria `_medo`, `_uau`) |
|---|---|---|---|
| `npc_pedestre_a` / `_b` | 8 | caminhando pela calçada (executiva com pasta; rapaz com fone) | medo: corre com as mãos na cabeça · uau: para e aponta |
| `npc_fotografo` | 8 | turista fotografando a paisagem | uau: vira e fotografa a luta com flash · medo: foge protegendo a câmera |
| `npc_streamer` | 8 | gravando vídeo de si mesma com o celular | uau: vira o celular para a luta, empolgada · medo: se abaixa |
| `npc_idosa_sacola` | 8 | andando devagar com sacola de compras | medo: se encolhe, deixa cair as laranjas · uau: bate palmas |
| `npc_vendedor` | 8 | cozinhando na barraca com vapor | medo: se esconde atrás do balcão · uau: levanta a espátula e comemora |
| `npc_sofa_tv` (interior) | 8 | morador no sofá vendo TV (luz da TV piscando) | medo: pula do sofá · uau: olha pelo buraco na parede |
| `npc_banho` (interior) | 8 | morador no banho de banheira com espuma, cantando (cortina, sem nudez) | medo: puxa a cortina e se esconde · uau: espia pela cortina |
| `npc_cozinha` (interior) | 8 | cozinhando no fogão com panela | medo: derruba a panela · uau: filma com o celular |
| `npc_escritorio` (interior) | 8 | digitando no computador, tomando café | medo: se esconde debaixo da mesa · uau: grava da janela |
| `npc_criancas` | 8 | duas crianças brincando de bola | uau: pulam animadas imitando golpes · medo: correm para dentro |
| `amb_gato_passaros` | 8 | gato na marquise balançando o rabo; pombos comendo | reação: gato arrepia e pula fora; pombos levantam voo |
| `amb_veiculos` | 6 | bonde, van de entrega, scooter passando (uma linha cada) | — |
| `amb_bandeiras_lanternas` | 8 | faixas e lanternas balançando, pétalas caindo | — |
| `amb_vapor_neon` | 8 | vapor de bueiro; letreiro neon piscando | neon falha com tremor forte |

Comportamento no jogo (só visual, nunca na simulação; RNG próprio da apresentação):
- Estado por figurante: `rotina → reage → (recupera)`. Reage quando um lutador passa perto (≈ 120 px),
  quando há golpe forte, ruptura ou explosão num raio maior, ou quando a parede do cômodo dele some.
- Tipo de reação sorteado por personalidade (fotógrafo e streamer tendem a "uau"; idosa e crianças
  tendem a "medo"); aviso de colapso sempre gera medo em quem está embaixo.
- Quem foge sai da tela ou se esconde; volta à rotina depois de alguns segundos de calma.
- Morador de interior só aparece quando a fachada daquele cômodo foi aberta.
- Loops com fase deslocada; densidade controlada; nada de alto contraste atrás da área de luta.
- Figurante nunca é atingível, nunca bloqueia e nunca morre: some de cena fugindo (tom leve, como SF).

### 8.5 Elementos reativos (pedido do dono)

Canos de água/vapor/gás, botijões, transformador, hidrante, postes e luminárias que entortam ou
quebram, letreiro neon, extintor. Design e lista de arte em
[../design_elementos_reativos.md](../design_elementos_reativos.md) §5. Cada fixo numa folha 4×1 com
os estados (intacto, danificado, quebrado/emitindo, destruído), vista lateral, transparente, mesma
luz e contorno; efeitos em flipbook 4×2. Regras de qualidade da §8.3.

### 8.6 Profundidade em camadas (pedido do dono, 24/09 ~19:10) — VALE PARA A PRÓXIMA GERAÇÃO

"O efeito parallax nos interiores precisa melhorar: o piso deve ser um asset separado do resto, já que
o piso está mais próximo e o fundo do interior é mais longe; se tiver objetos no interior que estejam
mais perto, recorte ou gere para fazer o parallax deles mais perto; e assim também se aplica a outras
coisas dentro do game."

**Regra geral:** todo cenário vem em **planos de profundidade separados**, cada um com seu parallax.
Nada que esteja em profundidades diferentes pode vir "pintado junto" numa imagem só.

Interiores (substituem `mod_interior_*` de imagem única), mesmo cômodo, mesma luz, mesma câmera
ortográfica, alinhados pelo mesmo enquadramento 2:1:
| asset_id | plano | conteúdo | parallax no jogo |
|---|---|---|---|
| `mod_interior_<sala>_fundo` | mais longe | só a parede de fundo: janelas, quadros, prateleiras presas na parede, luz; sem piso, sem móveis soltos | 0,12 (mais lento) |
| `mod_interior_<sala>_piso` | chão | só o piso visto de cima em perspectiva, do rodapé até a borda da frente, transparente acima | faixas de 0,12 (fundo) → 0 (frente) |
| `mod_interior_<sala>_moveis` | meio | folha 4×2 de móveis/objetos soltos isolados (balcão, estante, sofá, mesa, planta grande, luminária de chão…), vista lateral, transparente | 0,04–0,08 conforme a posição |
| `mod_interior_<sala>_frente` | perto | objetos colados ao plano de jogo (vaso, cadeira, caixa no chão), transparente | 0 (junto dos lutadores) ou leve negativo |

Salas: `loja`, `escritorio`, `fundos` (e as próximas). O mesmo vale para:
- **Rua:** `bg_rua_piso` (calçada e asfalto em perspectiva, separado), `bg_rua_meio` (postes, árvores,
  bancas), `bg_rua_frente` (grades e placas em primeiro plano, com opacidade limitada, §4.5).
- **Fachadas e skyline:** já estão em camadas (céu, far, mid); `bg_elementos_ceu` continua separado.

Implementação: `game/view/depth_view.gd` já usa essas camadas se os arquivos existirem em
`game/assets/bg/` (`mod_interior_<sala>_fundo/_piso/_moveis/_frente`); sem eles, cai no modo atual
(imagem única cortada em parede + faixas de piso).
