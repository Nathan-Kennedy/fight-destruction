# Prompts de arte — lote 01 (conceitos do M3)

Autor dos prompts: Opus 5.5. Geração: GPT-6 Astra (ferramenta de imagem do Codex).
Data: 24/09/2026. Status de tudo que sair deste lote: **candidate** (§20.1). Nada aqui é arte
final nem âncora aprovada; a aprovação é do dono do projeto.

## 1. Direção pedida pelo dono

"Bem bonito, lembrando anime, bem metropolitano como Invincible e War of the Monsters, com a
estética brilhante de Super Smash Bros."

Tradução em qualidades (as obras citadas são referência de **qualidade**, não de cópia: nenhum
personagem, logotipo, traje ou cenário delas pode aparecer; §19.1 exige assets originais):

| Referência | O que tirar dela | O que NÃO tirar |
|---|---|---|
| Anime de ação | poses de impacto exageradas, linhas de velocidade, cabelo e tecido com volume, rostos expressivos simples, smear frames, flashes de impacto em forma de estrela | personagens, uniformes ou símbolos de séries existentes |
| Invincible | cor chapada com sombra em uma ou duas camadas, contorno grosso de valor escuro, destruição urbana brutal e legível, céu limpo contrastando com o caos | o traje amarelo e azul, o logotipo e os personagens |
| War of the Monsters | cidade como arena, prédios que abrem e revelam interiores, poeira e escombro em escala, neon de cidade à noite e ao entardecer | monstros, mapas e nomes do jogo |
| Super Smash Bros. | brilho: rim light forte, cores saturadas e limpas nos lutadores, efeitos de acerto luminosos, cenário vivo mas sem roubar a leitura, HUD redondo e alegre | personagens, logotipo e o círculo cortado característico |

## 2. Como isso cabe na decisão já tomada (§9.2)

A decisão continua **hi-bit pixel art com base de 640×360**. O visual pedido não briga com ela:
é pixel art de alta densidade com **acabamento cel-shaded de anime**. Na prática:
- contorno de 1 px de valor escuro nos lutadores; cenário com contorno só nas massas grandes;
- sombra chapada em 2 tons (luz, sombra) + **rim light** de 1 px na cor do acento do lutador;
- lutadores saturados contra cidade dessaturada de valor médio (§9.4);
- brilho: efeitos, poderes e vidro com highlights fortes; bloom só nos efeitos, nunca no cenário.

Este lote é **conceito** (pranchas e personagens em ilustração limpa), não sprite. Os conceitos
aprovados viram referência para o bake-off (§9.2) e para os sprites. Por isso os prompts de
conceito pedem "clean cel-shaded illustration" e os de teste de sprite pedem pixel art.

## 3. Style bible v0 (proposta para aprovação)

**Cidade: "Nova Aurora".** Metrópole retrofuturista (§19.1): concreto, cerâmica vitrificada,
vidro em grelha, infraestrutura exposta (trilhos suspensos, cabos, caixas d'água, dutos),
letreiros originais em neon. Hora: **entardecer** — céu de violeta a laranja-pêssego, fachadas frias
em sombra, **interiores quentes** acesos. Massas grandes com detalhe agrupado; nada de ruído
uniforme.

**Paleta mestra (valores iniciais, ~24 de 48):**

| Uso | Hex |
|---|---|
| Céu alto / céu médio / horizonte | `#2B2346` `#6B3F6E` `#F09A6B` |
| Skyline distante (silhueta) | `#3A3050` `#4A3D5E` |
| Concreto luz / sombra / ferragem | `#8C8F99` `#5E6170` `#B5653A` |
| Tijolo luz / sombra | `#A5523F` `#6E3530` |
| Divisória/drywall luz / sombra | `#CFC6B4` `#9C927F` |
| Vidro base / reflexo | `#8FD3E8` `#F2FBFF` |
| Núcleo indestrutível + faixa | `#23232E` `#E0B43C` |
| Interior quente luz / sombra | `#D98A4E` `#6B4130` |
| Neon ciano / magenta / âmbar | `#39E6FF` `#FF3FA4` `#FFC23D` |
| Entulho | `#857565` `#5A4E44` |

**Lutadores (saturados, contorno `#15101C`):**
- **Leve — "Faísca"**: entregadora-velocista; jaqueta curta aerodinâmica, cachecol longo que rastreia
  o movimento, tênis com solado luminoso; acento **ciano elétrico** `#39E6FF` + branco. Silhueta
  magra, inclinada para frente, cabelo espetado para trás.
- **Médio — "Brasa"**: herói de rua equilibrado; traje de duas cores (laranja `#FF6A1F` e grafite),
  manoplas de impacto grandes, faixa na cabeça; acento **laranja-fogo**. Silhueta em V, pose firme.
- **Pesado — "Bloco"**: operário em exoesqueleto de demolição; braços enormes com martelete,
  capacete com viseira, tanque nas costas; acento **âmbar** `#FFC23D` + verde-oliva. Silhueta
  quadrada, centro de gravidade baixo.
- Régua (§9.4): leve 44 px, médio 50 px, pesado 56 px de altura em jogo; porta 48 px; andar 128 px.

**Regras de legibilidade (§9.6):** lutador sempre mais saturado e com contorno mais escuro que
qualquer escombro; debris cosmético mais escuro e menos saturado; efeito de poder nunca cobre o rosto.

## 4. Regras comuns a todos os prompts

Acrescentar ao fim de cada prompt de conceito:

> Original character and environment design, no existing franchise characters, logos or
> costumes. Clean cel-shaded anime illustration, thick dark outlines, two-tone flat shading with
> a crisp rim light, saturated heroes against a desaturated mid-value city, dusk lighting from the
> left, strict side view where stated, no text, no watermark.

Negativo (quando o gerador aceitar): `photorealistic, 3D render look, painterly blur, gradients on
characters, text, logo, watermark, extra limbs, cropped feet, busy uniform noise`.

## 5. Prompts do lote 01

Cada item vira um arquivo em `art/concept/lote01/<asset_id>.png` com um JSON irmão (§20.2).

### 5.1 `bg_prancha_composicao` — prancha de composição de gameplay (16:9)
> Side-view 2D fighting game screenshot mockup, 16:9. A retrofuturist metropolis street at dusk:
> a three-story corner building in cutaway with its concrete facade partly blown open, revealing a
> warm-lit shop on the ground floor and an office above. Two small heroes fight in the street, one
> slammed through a shattering glass storefront with anime speed lines and a bright star-shaped
> impact flash. Floating elevated rail line and neon signs in the background, violet-to-peach sky,
> skyline silhouettes in parallax layers. Dust and debris fall from a cracked slab. The heroes are
> the most saturated and readable elements; the city is mid-value and slightly desaturated.
> Bright, glossy, joyful platform-fighter feel. [regras comuns]

### 5.2 `chr_regua_elenco` — régua dos três lutadores (lado a lado)
> Character lineup turnaround sheet, strict side view facing right, three original heroes standing
> on a baseline with a height ruler: (1) "Spark", a slim light-weight courier speedster, cropped
> aerodynamic jacket, long trailing scarf, glowing sneakers, electric cyan and white; (2) "Ember",
> a balanced street brawler, two-tone orange and graphite suit, big impact gauntlets, headband,
> V-shaped silhouette; (3) "Block", a heavy demolition worker in a chunky exosuit, huge hydraulic
> hammer arms, visor helmet, amber and olive, square low silhouette. Next to them, for scale, a
> shop door and one building floor. Flat neutral background. [regras comuns]

### 5.3 `chr_faisca_conceito` — leve, conceito e poses
> Original anime action heroine "Spark", light-weight speedster courier. Sheet with: full body side
> view idle, a dashing punch pose with smear and speed lines, and a hurt/launched pose. Electric
> cyan accents, white jacket, black outline, crisp rim light, expressive simple face, spiky hair
> swept back, long scarf showing motion. [regras comuns]

### 5.4 `chr_brasa_conceito` — médio, conceito e poses
> Original anime street-brawler hero "Ember", balanced fighter. Sheet with: full body side view idle
> guard, a heavy side strike with a flame-orange impact burst, and a grab-and-throw pose. Two-tone
> orange and graphite suit, oversized impact gauntlets, headband tails. [regras comuns]

### 5.5 `chr_bloco_conceito` — pesado, conceito e poses
> Original heavy hero "Block", a demolition worker in a chunky powered exosuit. Sheet with: full body
> side view idle, a ground stomp shattering concrete with shockwave, and the radial burst move where
> an amber energy ring blasts debris outward. Amber and olive palette, visor glow, hydraulic arms.
> [regras comuns]

### 5.6 `mod_prancha_materiais` — materiais intactos e rompidos (§5.3, §19.1)
> Material study sheet for a destructible 2D city, strict front orthographic view, a grid of
> 64x64 wall tiles in three states each (intact, cracked, broken with a hole): glass curtain wall
> (cold cyan, shards), drywall partition (warm beige, crumbles), red brick (breaks into block chunks),
> reinforced concrete (grey, resists, exposed rusty rebar when broken), indestructible core
> (dark steel with yellow hazard stripe). Also loose rubble pile. Each material must be readable by
> color and texture alone. Hi-bit pixel art look, limited palette, no anti-aliasing. [regras comuns]

### 5.7 `fx_prancha_impacto` — efeitos de acerto e poder
> Visual effects sheet on a dark neutral background, anime and platform-fighter style: light hit
> spark, heavy hit star burst with white core, shield bubble (glossy cyan dome with highlight),
> shield break shatter, radial burst shockwave ring in amber, dust cloud puffs, collapse warning
> cracks glowing orange, glass shatter burst. Bright, glossy, readable, flat colors with strong
> highlights, each effect isolated. [regras comuns]

### 5.8 `bg_skyline_nova_aurora` — fundo em camadas
> Side-scrolling background for a 2D game, retrofuturist metropolis "Nova Aurora" at dusk, three
> parallax layers: far skyline silhouettes with antenna and a giant ring-shaped tower, mid layer of
> apartment blocks with lit windows and an elevated monorail, near layer of rooftops with water tanks
> and original neon signs (abstract shapes, no readable text). Violet to peach sky gradient with a
> big soft sun. Mid-value, slightly desaturated so fighters pop. [regras comuns]

### 5.9 `chr_brasa_teste_sprite` — teste de sprite (bake-off A/B, §9.2)
> Pixel art sprite test, hi-bit style, strict side view facing right, the hero "Ember" (orange and
> graphite suit, big gauntlets, headband) at exactly 50 pixels tall inside a 96x96 canvas, 1-pixel
> dark outline, two-tone shading plus 1-pixel orange rim light, no anti-aliasing, limited palette of
> 16 colors, transparent background. Three frames side by side: idle, heavy punch contact, launched.

### 5.10 `ui_tela_gameplay_hud` — tela de gameplay completa com HUD (16:9, pedido do dono)
Referência-mestra para validar o conjunto: cenário, lutadores, destruição, efeitos e HUD juntos.
> Final in-game screenshot of an original 2D side-view platform fighter, 16:9, 1920x1080 feel,
> hi-bit pixel art with anime cel-shading. Scene: a retrofuturist metropolis street at dusk in
> front of a three-story building shown in cutaway. The heavy hero "Block" (amber and olive
> exosuit, hammer arms) has just launched the light hero "Spark" (electric cyan courier with a
> long scarf) through the building: a trail of shattered glass, a broken drywall partition and a
> torn brick wall marks the flight path, with a bright white-core star impact flash and anime speed
> lines. On the right, a concrete slab glows orange with warning cracks and dust falls from it,
> about to collapse; a rubble pile is already on the street. A wooden crate and a red vending
> machine lie in the street as throwable props. Camera slightly zoomed out framing both fighters.
> HUD at the bottom: two rounded, glossy player panels (left orange-trimmed for player 1, right
> cyan-trimmed for player 2), each with a small character portrait, a big bold damage percentage
> number with a heavy outline (e.g. "87%" and "132%", the higher one tinted hotter red), three
> stock icons, and a small circular special-move cooldown gauge. Tiny floating "P1"/"P2" markers
> above each fighter. The HUD is bright, clean and joyful like a premium platform fighter, never
> covering the fighters. [regras comuns]

### 5.11 `ui_prancha_hud` — prancha de elementos do HUD
> UI design sheet for an original 2D platform fighter HUD, on a flat dark neutral background, each
> element isolated with spacing: player damage panel in four states (0%, 60%, 120%, 180%, number
> color shifting from white to yellow to orange to red and slightly shaking at high damage),
> stock icons full and lost, special-move cooldown ring (empty, charging, ready with a glow),
> shield meter bar, player markers "P1" (orange) and "P2" (cyan) as small arrow tags, a "GO!" start
> banner and a "GAME!" end banner with bold italic lettering and speed lines, pause menu button
> style. Rounded glossy shapes, thick dark outlines, bright highlights, legible at 720p. The only
> text allowed is the numbers, "P1", "P2", "GO!" and "GAME!". Original design, no existing
> franchise logos or fonts.

## 6. Registro

Para cada imagem: salvar a saída bruta, este arquivo como `prompt_file`, e um JSON com
`asset_id`, `revision`, `kind`, `status: "candidate"`, `provider`, `model_id`, `prompt_file`,
`prompt_section`, `output_files`, `notes`. Rejeições também ficam registradas com motivo.
