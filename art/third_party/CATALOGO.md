# Catálogo de material de terceiros (VFX, shaders, código, som)

Pesquisa e download: Opus 5.5, 24/09/2026. Status de tudo: **candidate** (nada foi integrado em `game/`).
Total em disco: ~108 MB. Cada pasta tem `LICENSE.txt` (licença, URL e data) e `origem.json` (§20.2).
Pastas OpenGameArt/Kenney também guardam a página de origem em `pagina_fonte*.html`.

Licenças aceitas: CC0 e MIT. Nenhum item CC-BY foi baixado, então não há atribuição obrigatória
de CC-BY. Quatro autores MIT exigem manter o aviso junto do código (ver §3).

## 1. Sprites, flipbooks e texturas

| Pasta | Licença | Conteúdo | Serve para | Encaixe visual |
|---|---|---|---|---|
| `oga_sinestesia_hit-animations` | CC0 | 2 folhas 4096² com 16 frames de 1024²: faísca de acerto amarela desenhada à mão (radial e direcional) | impacto leve/forte (núcleo do hitspark) | **Muito bom.** Traço anime, glow amarelo. Recolorir por matiz para ciano (Faísca), laranja (Brasa) e âmbar (Bloco). Reduzir para 256-512 px por frame |
| `oga_sinestesia_explosions-1` e `-2` | CC0 | 8 folhas 4096² (+ Half Sized 2048²) de explosões anime: bola de fogo, anel, raios, brasas, fumaça | explosão radial, golpe final, colapso de módulo | **Muito bom.** Paleta quente que casa com o entardecer. Usar a versão Half Sized |
| `oga_dirkwybe_toon-explosions` | CC0 | 5 folhas (8×7, ~56 frames, 211-300 px) de explosão toon **com contorno escuro**: creme, laranja, fumaça preta, cinza | explosão de concreto, destruição de módulo, poeira pesada | **Bom.** É o único com outline, como os sprites. Traço mais "3D toon": testar ao lado dos lutadores |
| `oga_para_particlefx-1` | CC0 | 14 folhas 1024² (8×8 de 128 px): anéis de choque (dourado, laranja, azul, violeta), anel de fumaça, explosão com fumaça, chama, jato vertical | onda de choque de golpe forte, **poeira de pouso** (anel de fumaça), escudo quebrando (anel azul), lançamento | **Bom.** Anéis são o melhor uso. Resolução baixa (128 px), então usar só em tamanho pequeno ou médio |
| `oga_para_particlefx-2` | CC0 | fogo (4 folhas), chama, teleporter e teleporter_hit | fogo em prédio, faísca de energia/escudo | Médio. Fogo mais realista. Teleporter_hit serve como "respawn/escudo" |
| `kenney_particle-pack` | CC0 | 80 texturas soltas (transparente + fundo preto): círculos, anéis, estrelas/flare, **slash/arcos de corte**, **traces**, fumaça, terra (`dirt_*`), marcas de queimado (`scorch_*`), raios, chamas, muzzle, `window_*` (grades de janela, usáveis como caco de vidro) | matéria-prima para GPUParticles2D: faíscas, lascas, arcos de golpe, flare no ponto de contato, poeira | **Muito bom como base.** Tudo em branco/cinza, então se tinge pela cor da partícula. Sem estilo próprio, herda o do jogo |
| `kenney_smoke-particles` | CC0 | puffs de fumaça (preta, branca, explosão laranja, flash amarelo, verde) | fumaça de colapso, poeira de pouso, puff de lançamento, aviso de colapso (poeira caindo) | Bom. Suave, sem outline. Usar pequeno ou somar outline via `smoke_puff_toon` |
| `oga_wreaderror_lightning-arcs` | CC0 | 8 arcos elétricos 2048×512 (4 violeta, 4 azul-ciano) | golpes elétricos da Faísca, cabo de energia rompido, escudo | Bom em blend aditivo. O ciano já está na cor da Faísca |
| `oga_calinou_lightning-animation` | CC0 | raio animado em 11 PNGs | raio vertical (queda de poste, especial) | Médio. Simples, precisa de glow |
| `oga_sbs_abstract-noise-pack` | CC0 | 100 ruídos abstratos seamless 512² | máscara de dissolve, distorção, fumaça, speed lines, heat haze | Não aparece na tela: é insumo de shader |
| `oga_sbs_noise-texture-pack` | CC0 | 263 ruídos 128² em 18 famílias (**Cracks**, Voronoi, Perlin, Streak, Spokes…) | `Cracks` e `Voronoi` servem para rachaduras em módulo danificado; `Streak`/`Spokes` para speed lines | Insumo de shader. Versões 256/512 não baixadas (29/99 MB) |
| `kenney_impact-sounds` | CC0 | 130 OGG (metal, madeira, vidro, placa, soco, sino, passos) | som de impacto e de passos provisório | Som genérico, bom como placeholder |

## 2. Código Godot (MIT)

| Pasta | Conteúdo | Serve para | Observações |
|---|---|---|---|
| `gdquest_vfx-2d-explosion` | Explosão 2D **100% procedural** (3 ColorRects com shaders de ruído/gradiente + GPUParticles2D + AnimationPlayer) e `Trail2D` (Line2D que segue um nó) | explosão radial estilizada sem textura; rastro de lançamento/dash | As **artes** do repositório são CC-BY-NC-SA: foram apagadas, e o que ficou não depende delas. Os caminhos `res://effects/...` precisam de ajuste. Escala nativa grande (usar 0.3-0.6). Carregou no 4.7.2 sem erro |
| `github_solobyte_polygon2d-fracture` | `PolygonFracture.gd` (fratura Delaunay, por corte e por ponto), `PolygonLib.gd`, `PolygonRestorer.gd` + `demo_ref/` | **ruptura de vidro/concreto**: quebrar o polígono do módulo em cacos na hora do evento | Usa `class_name`: remover e usar `preload` (AGENTS.md). Aceita seed fixa. Cacos são só apresentação |

## 3. Shaders (`shaders/`, todos compilam no Godot 4.7.2)

Teste: cada um num ColorRect com ShaderMaterial, Forward+, sem `SHADER ERROR`. O código do
godotshaders.com foi transcrito da página, porque o site bloqueia download por bot-check.

| Arquivo | Autor / licença | Efeito | Uso no jogo |
|---|---|---|---|
| `shockwave_zawarudo` | IceTeea / CC0 | anel de distorção + aberração + miolo invertido | **onda de choque de golpe forte e explosão radial**; o miolo invertido já faz um impact frame |
| `shockwave_ring_simple` | snesmocha / CC0 (portado do G3) | anel de distorção barato | impacto médio, pouso pesado do Bloco |
| `speedlines_anime` | ProfesorShader / CC0 | speed lines radiais/planares com distorção | **lançamento forte**, golpe final, dash |
| `impact_frame_manga` | hailyn / CC0 | tela vira mangá P&B com linhas radiais, zoom e tremor | **golpe final/KO**, 3-6 frames |
| `impact_frame_threshold` | TTien63 / CC0 | silhueta P&B por limiar, com inversão | impact frame de 1-2 frames (anime) |
| `chromatic_aberration_radial` | alfroids / **MIT** | aberração radial | pulso em golpe forte |
| `hit_flash` | triangledevv / **MIT** (corrigido e estendido) | sprite fica branco ou colorido | **flash do atingido durante o hitstop** |
| `outline_inline_2d` | Juulpower / CC0 (adaptado) | contorno externo/interno de sprite | legibilidade no caos, rim de escudo |
| `afterimage_ghost` | original / CC0 | fantasma aditivo com borda realçada | afterimage de dash/lançamento |
| `smoke_puff_toon` | original / CC0 | puff de fumaça cel-shaded com outline #15101C | **poeira de pouso**, fumaça de colapso, rastro de lançamento |
| `dissolve_burn_edge` | mreliptik / CC0 | dissolve com borda queimando | escombros sumindo, módulo derretendo, KO |
| `heat_haze_shimmer` | Gerardo LCDF / CC0 | ondulação de calor na tela | fogo em prédio, explosão, escapamento do Bloco |
| `lightning_arc` | lumenfruit / **MIT** (samplers ajustados) | arco elétrico procedural | golpes da Faísca, fio rompido |
| `shield_bubble_2d` | Pan / CC0 (portado do G3) | bolha com padrão esférico girando | **escudo** |
| `screen_glass_shatter` | miwls / CC0 | tela (ou região) quebra em cacos Voronoi que caem | transição de KO/fim, ou fachada de vidro com BackBufferCopy |
| `bloom_screen` | VEGAMETA / CC0 | bloom por blur (caro) | fallback; preferir o glow do WorldEnvironment |
| `glow_screen_cheap` | GDQuest / **MIT** | glow barato por mipmap | brilho geral de VFX |

Avisos MIT (alfroids, lumenfruit, triangledevv, GDQuest) estão em `shaders/LICENSE.txt`.
Manter esse arquivo junto se os shaders forem para `game/`.

## 4. Rejeitados (não baixados)

- **Cracked Glass** (godotshaders): CC BY-NC-SA 3.0, port de Shadertoy.
- **Artes do GDQuest godot-4-VFX-assets**: CC-BY-NC-SA 4.0. Só o código MIT foi mantido.
- Glass Shatter Impact Points e Stylized Smoke: são shaders 3D (spatial).
- Blender Volumetric Particles (24 MB, violeta), Blue Ring Explosion e 5x Special Effects:
  pouco úteis ou em resolução baixa.
- Packs em pixel art (itch.io): não combinam com o ilustrado em alta resolução.

## 5. Mapa efeito → material (rápido)

| Evento do jogo | Primeira escolha | Complemento |
|---|---|---|
| Impacto leve | hit_yellow_01 (pequeno, tingido) + `hit_flash` | 4-6 faíscas Kenney `spark`/`trace` |
| Impacto forte | hit_yellow_02 direcional + anel para_particlefx + `shockwave_ring_simple` | `chromatic_aberration_radial` em pulso; afterimage |
| Ruptura de vidro | `PolygonFracture` nos cacos + faíscas brancas Kenney `star`/`flare` | `screen_glass_shatter` numa região |
| Ruptura de concreto | `PolygonFracture` + Kenney `dirt_*` + `smoke_puff_toon` cinza | noise `Cracks` como máscara de rachadura antes de romper |
| Colapso | dirkwybe toon explosion (fumaça) + Kenney smoke em volume | `heat_haze_shimmer` se houver fogo |
| Explosão radial | sinestesia explosions (Half Sized) ou GDQuest procedural | `shockwave_zawarudo` |
| Escudo | `shield_bubble_2d` na cor do lutador | anel azul para_particlefx ao quebrar |
| Aviso de colapso | poeira caindo (Kenney smoke branco pequeno) + `smoke_puff_toon` | tremor local do módulo + rachadura por noise |
| Poeira de pouso | anel de fumaça para_particlefx + 2 `smoke_puff_toon` laterais | escala pela velocidade de queda |
| Lançamento | `speedlines_anime` (golpe forte) + Trail2D + `afterimage_ghost` | puff `smoke_puff_toon` a cada 3-4 frames (rastro estilo Smash) |
| Golpe final/KO | `impact_frame_threshold` 1-2 frames → `impact_frame_manga` 3-6 frames | explosão sinestesia no ponto de saída |

## 6. Áudio (CC0, integrado em `game/assets/sfx/`)

Pesquisa e download: Opus 5.5, 24/09/2026, para o sistema de áudio (`game/view/audio_director.gd`).
Só CC0. `kenney_impact-sounds` (acima) passou a ser usado. Montagem da pasta do jogo e sons
procedurais (concreto grande, desmoronamento, rangido, faísca, choque, revoada, baque grave):
`tools/audio/build_sfx.py`. Mapa grupo → arquivo de origem em `game/assets/sfx/LICENSES.md`.

| Pasta | Autor | Conteúdo | Uso |
|---|---|---|---|
| `kenney_sci-fi-sounds` | Kenney | 73 OGG | explosão (explosionCrunch, lowFrequency_explosion), escudo/carga/respawn (forceField), fogo (thrusterFire) |
| `kenney_rpg-audio` | Kenney | 50 OGG | rangido (creak), agarrão/arremesso (cloth) |
| `oga_rubberduck_75-breaking-falling-hit` | rubberduck | 75 OGG | ruptura e cauda de vidro, pedra, madeira e metal |
| `oga_rubberduck_100-cc0-sfx` | rubberduck | 100 OGG | vidro grande, respingo |
| `oga_rubberduck_100-cc0-sfx-2` | rubberduck | 100 OGG | vidro, entulho (stones), ar (whoosh, extintor), loops de água |
| `oga_rubberduck_40-water-splash` | rubberduck | 40 OGG | jorro de água |
| `oga_tinyworlds_glass-break` | tinyworlds | 1 WAV | vidro grande, escudo quebrando |
| `oga_artisticdude_swishes` | artisticdude | 13 WAV | whoosh de golpe e esquiva |
| `oga_faxcorp_electricity` | faxcorp | 4 WAV (de 17) | transformador e fiação em loop, impacto de escudo |
| `oga_themightyglider_electric-buzz` | themightyglider | 1 OGG | zumbido do neon, choque |
| `oga_bart_steam-release` | Bart K. | 5 WAV | vapor, gás vazando, pavio, extintor |
| `oga_pagdev_fireplace-loop` | pagdev | 1 WAV | fogo do cano de gás |
| `oga_ignasd_high-traffic-road` | ignasd | 1 OGG | ambiente de rua com trânsito |
| `oga_isaiah658_ambient-birds` | isaiah658 | 1 OGG | pássaros ambiente |
| `oga_starninjas_crowd-shouting` | starninjas | 1 OGG | público assustado (gritos) |
| `oga_expl0it3r_applause` | eXpl0it3r | 1 WAV | público "uau"/KO (aplausos) |

Descartados: "OoOoOo" (nocturnalvanguard, voz solo, não é público), "Park ambiences" (86 MB de WAV),
"Scifi City" (ficção científica, não combina com a rua). Não achei CC0 bom para desmoronamento,
rangido estrutural, faísca/choque curtos e revoada de pombos: foram sintetizados.
