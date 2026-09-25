# Referências de VFX e game feel para jogos de luta (estudo)

Pesquisa: Opus 5.5, 24/09/2026. Isto é **estudo**: nenhum sprite, textura, vídeo ou áudio de
jogo comercial foi baixado. Cada técnica traz o que é, quem faz e como (com fonte), os parâmetros
que dá para medir e como aplicar aqui (Godot 4, 60 Hz, sim determinística com hitstop global,
efeitos só na apresentação).

Grau de confiança:
- **[fonte]** = número ou regra citada de wiki, desenvolvedor ou palestra.
- **[observação]** = prática comum que não conferi em fonte primária.
- **[proposta]** = valor nosso, a ajustar no playtest.

O que já existe no jogo (conforme `Docs/arte/progresso_lote02.md` e `game/view/`):
`vfx_director.gd` (shockwave, hit, burst, collapse, ko), `screen_fx.gdshader` (4 ondas, chroma,
impact, speed lines, vinheta), tremor do atingido no hitstop, flash, afterimage, rastro,
squash/stretch e F6 para desligar flashes. Na sim: `freeze = min(hitstop + kb/512, 12)`.
Este documento serve para calibrar o que já existe e para decidir o que falta.

---

## 1. Hitstop (hitlag, freeze frames)

**O que é:** atacante e atingido congelam alguns frames no contato. É o que faz o golpe "pesar".

**Smash Ultimate [fonte]:** `hitlag = floor((dano × 0.65 + 6) × h × e × s)` em frames, com
h = multiplicador do hitbox (padrão 1), e = 1.5 se o golpe for elétrico, s = 0.67 no escudo.
Crouch cancel também dá 0.67. O teto é **30 frames** (20 com crouch cancel). Exemplos: 5% dá 9 f,
15% dá 15 f e 25% dá 22 f. Comparação para 15%: Smash 64 = 10, Melee = 8, Brawl/4 = 10,
Ultimate = 15. Ou seja, Ultimate aumentou o hitstop de propósito.
Fonte: [SmashWiki – Hitlag](https://www.ssbwiki.com/Hitlag).

**Sakurai (coluna Famitsu vol. 490) [fonte]:** quanto mais dano, mais hitstop, com teto. No
Smash o teto é mais baixo que num 1×1 porque, em partida com 3 ou mais, um terceiro pode bater
em quem está congelado. Casos especiais têm valor próprio: a ponta da espada do Marth tem mais
hitstop, e o Ryu tem hitstop bem maior, para lembrar o Street Fighter.
Fonte: [Source Gaming – "Thinking About Hitstop"](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/).
Vídeos do Sakurai: ["Stop for Big Moments!"](https://www.youtube.com/watch?v=OdVkEOzdCPw) e
["Eight Hit Stop Techniques"](https://www.youtube.com/watch?v=tycbMSjDDLg), ambos do canal
*Masahiro Sakurai on Creating Games*. Não consegui transcrever a lista das 8 técnicas. Vale o dono assistir.

**Rivals of Aether [fonte, wiki da comunidade]:** `hitpause = base + dano × escala × 0.05`
(+ extra só no alvo). Todos são propriedades do hitbox, e um golpe que dá "Galaxy" (KO
garantido) fixa 20 f.
Fontes: [RoA – get_hitstop_formula](https://rivalsofaether.com/get_hitstop_formula/),
[Rivals Wiki – Patch Notes](https://rivals-of-aether.fandom.com/wiki/Previous_Patch_Notes).

**Aplicação aqui:** nosso teto de 12 f é conservador (Smash chega a 30). Proposta
**[proposta]**: leve 3-5 f, médio 6-9 f, forte 10-14 f, finalizador 18-24 f. O teto de
jogo normal fica em 14, e só o golpe que causa KO ou colapso pode passar disso. Seguir
o "extra só no alvo" do Rivals: o atacante sai 1-2 frames antes, para não parecer travado. Tudo
isso é regra da sim (determinística). A apresentação só lê `freeze`.

## 2. Tremor do atingido durante o hitstop

**Smash [fonte]:** no Smash o personagem não fica só parado, ele vibra. O atingido vibra
**de lado a lado no chão** e **para cima e para baixo no ar**. O atacante também vibra um pouco. A
hurtbox fica parada e só o sprite treme. A amplitude **diminui ao longo dos frames** e é
ajustada pela distância da câmera.
Fonte: [Source Gaming – coluna Famitsu vol. 490](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/).
No Smash, o jogador usa esse tempo para o **SDI** (mover-se um pouco durante o hitlag).
Fonte: [SmashWiki – Hitlag](https://www.ssbwiki.com/Hitlag).

**Aplicação:** já existe em `fighter_view.gd`. Conferir o eixo (chão = x, ar = y), a amplitude
proporcional ao dano, o decaimento linear até 0 no último frame e o atacante com 25-35% da
amplitude **[proposta]**. Usar ruído determinístico por frame (`sin(frame × k)` ou hash do
frame), sem `randf()`, para o replay ficar igual na tela.

## 3. Flash no acerto e impact frames

**Anime [fonte]:** *impact frames* (ショックコマ) são quadros monocromáticos ou de cor
estilizada (preto e branco, invertido, silhueta) inseridos por uma fração de segundo para dar
peso ao golpe. Em geral duram **1-3 quadros**. Alguns animadores estendem de propósito.
Fontes: [Sakuga Blog – Impact Frames](https://blog.sakugabooru.com/glossary/impact-frames/),
[Sakugabooru – tag impact_frames](https://www.sakugabooru.com/wiki/show?title=impact_frames),
[Sakugabooru – tag effects](https://www.sakugabooru.com/post?tags=effects) (bom acervo para estudar
formas de fumaça, faísca e explosão desenhadas à mão).

**Flash branco do sprite atingido [observação]:** 1-4 frames, em quase todo jogo de ação.

**Aplicação:** usar três níveis. (a) Todo acerto: `hit_flash` do atingido durante o hitstop
(branco a 100% nos 2 primeiros frames, depois rampa). (b) Golpe forte: pulso de aberração +
anel de distorção. (c) Só no finalizador: 1-2 frames de `impact_frame_threshold` (P&B, invertendo
no 2º frame) e depois 3-6 frames de `impact_frame_manga` com rampa de saída. Respeitar a F6
(desliga flashes) e **nunca repetir impact frames em sequência**: no máximo 1 por segundo
**[proposta]**, por fotossensibilidade.

## 4. Zoom e câmera lenta no golpe decisivo

**Smash Ultimate – Special Zoom [fonte]:** em certos golpes, o fundo pisca **azul** com
"faíscas" em linhas apontando para o impacto, o tempo desacelera bastante e a câmera dá zoom no
ponto do golpe. **Finish Zoom:** mesma coisa com fundo **vermelho**, quando o golpe
provavelmente encerra a partida. O atingido faz cara de choque. O cálculo considera só knockback
e ângulo (ignora DI e obstáculos). Com mais de 2 jogadores o efeito quase some. Não dispara
nos últimos 5 s de partida por tempo.
Fonte: [SmashWiki – Special Zoom](https://www.ssbwiki.com/Special_Zoom).

**Aplicação:** a câmera lenta não pode ser só visual, senão a imagem se descola da sim. Fazer
assim: a sim estende o `freeze` do golpe decisivo (evento `finish`, 18-24 f), e a apresentação
usa esse congelamento para zoom (+15-25% em 6 f, segurar, soltar em 8 f), fundo tingido
(azul para golpe especial, vermelho para KO ou colapso) e speed lines radiais no ponto de
impacto **[proposta]**. Com mais de 2 lutadores ou muito caos na tela, desligar o zoom, como
o Smash faz.

## 5. Rastro de lançamento (launch smoke trail)

**Smash [fonte]:** o rastro de fumaça mostra o **ângulo** do lançamento e só aparece com
knockback alto. No Smash 4, com knockback ainda maior, vem junto um **rastro de luz grosso na cor
do jogador que bateu**. Quem foi lançado se reconhece pelo rastro colorido, pela velocidade alta
com desaceleração rápida e pelo som de lançamento. No Ultimate, com hitstun acima de 32 f, o
começo do voo é acelerado (*launch speed-up*).
Fontes: [SmashWiki – Knockback](https://www.ssbwiki.com/Knockback),
[SmashWiki – Hitstun](https://www.ssbwiki.com/Hitstun).

**Aplicação:** três faixas **[proposta]** pelo knockback que a sim já calcula. Baixo: nada.
Médio: puff `smoke_puff_toon` cinza a cada 3 frames. Alto: puffs + `Trail2D` na cor do
atacante (Faísca ciano, Brasa laranja, Bloco âmbar) + speed lines planares no primeiro terço do
voo. Parar o rastro quando a velocidade cair abaixo do limiar de tumble.

## 6. Speed lines

**Anime e Smash [fonte]:** o Special Zoom usa linhas radiais apontando para o impacto (§4).
Em mangá e anime há dois tipos: **radiais** (foco no impacto) e **paralelas** (movimento).

**Aplicação:** radiais só no finalizador e no Special Zoom. Paralelas no lançamento forte e no
dash especial. Alfa baixo (0.3-0.5), sem cobrir os lutadores: mascarar o miolo como o
`radial_min` do `speedlines_anime` **[proposta]**.

## 7. Partículas em camadas (núcleo + cor + fumaça) e forma do efeito

**Street Fighter 6 (coluna oficial "Behind the Effects") [fonte]:** o efeito do Drive Impact
**enche a tela por trás de quem ataca**, para ficar óbvio que lado está atacando. Como os
personagens do SF6 são mais realistas, efeito realista demais viraria excesso de informação,
então a equipe deixou uma **distância entre o efeito e o personagem**. No Drive Parry, a regra é
o efeito **transbordar para o oponente no acerto e parar antes dele na defesa**. No counter do
Drive Impact, o "grafite" do atacante invade o oponente, e a câmera faz um ângulo dramático.
Fontes: [SF6 – #001 The Secrets of Drive Impact](https://www.streetfighter.com/6/column/detail/effects02),
[SF6 – abertura da coluna](https://www.streetfighter.com/6/en-us/column/detail/effects01),
[SF6 – #003 Drive Parry](https://www.streetfighter.com/6/en-us/column/detail/effects003)
(o site bloqueou leitura automática; conteúdo do resumo indexado).

**Smash [fonte]:** efeito elétrico são faíscas azuis e amarelas cujo **tamanho acompanha a
força** do golpe. Kazuya usa "Sparks" + efeito normal para lembrar o Hit Spark do Tekken.
Fonte: [SmashWiki – Sparks (effect)](https://www.ssbwiki.com/Sparks_(effect)).

**Camadas [observação]:** núcleo branco (1-3 f, aditivo) → forma colorida (faísca/estrela do
elemento, 6-12 f) → fagulhas voando → fumaça/poeira (20-40 f, normal, escura).

**Aplicação:** montar o hitspark em 4 camadas com o material baixado. (1) flare/star Kenney
branco aditivo, 2 f. (2) `hit_yellow_01/02` sinestesia tingido na cor do atacante, a 24-30 fps
de flipbook. (3) 4-10 `spark`/`trace` Kenney, com vida 8-14 f. (4) `smoke_puff_toon` só em
golpe médio ou forte. Direção da camada 2 = vetor de knockback. Na defesa, o efeito **não
passa do escudo**, seguindo a regra do Drive Parry.

## 8. Animação limitada (efeitos "em dois" ou "em três")

**Guilty Gear Xrd (GDC 2015, Junya C. Motomura) [fonte]:** a equipe tentou animação completa e
desistiu porque "não parecia 2D". Tiraram a interpolação entre keyframes: cada frame é uma pose
chave, como stop motion. Deformam a malha a cada key para "adicionar imperfeição", usam muita
escala (squash e stretch, exagero) e não usam simulação física ("não parece 2D"). O contorno é
inverted hull com largura controlada por cor de vértice. Nas lutas a luz do personagem fica
fixa, e só nas cinemáticas ela é animada quadro a quadro.
Fontes: [GDC Vault](https://www.gdcvault.com/play/1022031/GuiltyGearXrd-s-Art-Style-The),
[handout PDF](https://www.ggxrd.com/Motomura_Junya_GuiltyGearXrd.pdf),
[Internet Archive](https://archive.org/details/GDC2015Motomura).

**Dragon Ball FighterZ [fonte]:** o jogo roda a 60 fps, mas os modelos são animados a
**~15 fps** para imitar anime desenhado.
Fontes: [Kotaku – Breaking Down The Animation Of Guilty Gear and Dragon Ball FighterZ](https://kotaku.com/breaking-down-the-animation-of-guilty-gear-and-dragonba-1836849279),
[vídeo "The Animation of Guilty Gear Xrd & Dragon Ball FighterZ"](https://www.youtube.com/watch?v=kZsboyfs-L4).

**Aplicação:** flipbooks de VFX a **12-20 fps (segurar 3-5 ticks por frame)**, sem blend entre
frames. Partículas procedurais podem andar a 60 Hz, mas as de forma "desenhada" (faísca,
explosão) ganham com o passo segurado. Squash e stretch no lutador atingido e nos
puffs **[proposta]**.

## 9. Tremor de câmera (screenshake)

**GDC 2016, Squirrel Eiserloh [fonte]:** manter um nível de **trauma entre 0 e 1**. Dano ou
estresse soma (+0.2 ou +0.5), e o trauma cai de forma linear com o tempo. O tremor é
**trauma² (ou trauma³)**: trauma 0.3/0.6/0.9 dá 3%/22%/73% de tremor. Usar **ruído suave
(Perlin)**, não aleatório puro, e combinar translação com rotação pequena.
Fontes: [GDC Vault](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing),
[slides PDF](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf),
[transcrição](https://archive.org/stream/GDC2016Eiserloh/GDC2016-Eiserloh_djvu.txt).

**Vlambeer, "The Art of Screenshake" [fonte]:** congelar 1-2 frames em morte, dano e explosão,
tremer a câmera, deixar marcas permanentes (cápsulas, destroços que ficam), fumaça em explosões.
Fonte: [YouTube – Jan Willem Nijman](https://www.youtube.com/watch?v=SkgkIXZ_13Y).

**Aplicação:** `camera_director.add_shake` deve virar trauma: leve +0.10, forte +0.25, colapso
+0.4, KO +0.5 **[proposta]**. Tremor = trauma² × (máx. 12 px e 1.5°). O ruído é indexado pelo
**frame da sim** (determinístico). **Durante o hitstop, tremer menos a câmera**, porque o foco é
o tremor do atingido, e soltar o tremor no 1º frame depois do freeze. Os destroços que ficam na
arena valem como "permanência" (Vlambeer).

## 10. Iluminação de impacto

**[observação]** Em jogos 2D-HD e em anime, o impacto costuma ter um clarão curto (2-4 f) que
ilumina o entorno. Guilty Gear Xrd controla a luz por personagem (§8).

**Aplicação:** `PointLight2D` aditivo no ponto de impacto (energia 1.5→0 em 6 f, cor do
atacante) com as sombras dos prédios desligadas. Na explosão ou colapso, flash de vinheta
quente (laranja do entardecer) a 10-15% por 8 f **[proposta]**.

## 11. Cores por tipo de golpe e por dono

**Smash [fonte]:** efeitos por elemento (elétrico azul e amarelo, com tamanho pela força). O
rastro de lançamento no Smash 4 usa a cor do jogador que bateu (§5).
**SF6 [fonte]:** o estilo visual do atacante (o grafite) invade o oponente no counter (§7).
**Riot [fonte]:** todo efeito precisa **pertencer claramente a um personagem ou fonte**, e o VFX
carrega "o fardo da contenção" para o jogador entender o que acontece.
Fonte: [Riot Games – Art Edu: Visual Effects](https://www.riotgames.com/en/artedu/visual-effects).

**Aplicação:** a cor da faísca e do rastro é a cor de acento do **atacante** (Faísca
ciano/branco, Brasa laranja/amarelo, Bloco âmbar/verde-oliva). O material destruído usa a cor
do material (vidro branco-azulado, concreto cinza-bege, metal laranja de faísca). Vermelho fica
reservado para perigo (aviso de colapso, Finish Zoom).

## 12. Legibilidade no caos

**[fonte]** Smash desliga o Special Zoom com mais de 2 jogadores (§4). SF6 deixa um espaço entre
o efeito e o personagem e põe o efeito atrás do atacante (§7). Riot pede contenção (§11).
Guilty Gear usa contorno controlado para separar as formas (§8).

**Aplicação [proposta]:**
1. Lutadores sempre na frente do VFX de cenário. VFX de acerto na frente do lutador só durante
   o hitstop.
2. Contorno `outline_inline_2d` #15101C de 2 px nos lutadores quando houver poeira ou fumaça atrás.
3. Orçamento de partículas por evento e total. Se passar, cortar a fumaça antes das faíscas.
4. Fumaça de colapso escura e baixa (atrás), faíscas claras e altas (na frente).
5. Aviso de colapso com cor e ritmo próprios: poeira caindo + tremor local + rachadura
   vermelha pulsando a 2 Hz. Não pode parecer acerto.

## 13. Destruição como finalizador e transição

**Guilty Gear Strive – Wall Break [fonte]:** no combo contra a borda, **rachaduras aparecem na
lateral da tela** e o oponente "gruda" na parede. Depois de hits suficientes, a parede quebra, o
oponente atravessa com dano extra e uma **cinemática** leva os dois para outra área, que reinicia
em neutro. Quem quebrou ganha Positive Bonus.
Fontes: [Guilty Gear Strive – Systems (oficial)](https://www.guiltygear.com/ggst/en/battle/systems/),
[Upcomer – starter guide](https://upcomer.com/guilty-gear-strive-starter-guide/).

**Dragon Ball FighterZ – Destructive Finish [fonte]:** um KO com golpe pesado, vanish ou super
(vida abaixo de ~20%) lança o oponente para o canto e **atravessa o cenário**, com transição de
área em alguns estágios.
Fontes: [Steam guide – List of Destructive Finishes](https://steamcommunity.com/sharedfiles/filedetails/?id=3279972533),
[DBFZ Wiki – Dramatic Finish](https://dragonballfighterz.fandom.com/wiki/Dramatic_Finish).

**Aplicação:** é o coração do nosso jogo. A **rachadura progressiva** (noise `Cracks` como
máscara, crescendo a cada acerto no módulo) avisa antes de romper, como o Wall Break. No
rompimento, hitstop estendido + `PolygonFracture` + fumaça + Special Zoom leve. Lutador que
atravessa uma parede ganha rastro forte e poeira de impacto do outro lado.

## 14. Trilhas e afterimages

**[observação]** Anime e jogos ArcSys usam imagens residuais e borrão de movimento desenhado
em golpes rápidos. O Smash 4 usa rastro de luz no lançamento (§5).

**Aplicação:** `afterimage_ghost` com 3-5 cópias a cada 2-3 frames, vida de 10-16 f, só em dash,
lançamento forte e especiais **[proposta]**. `Trail2D` (GDQuest) para arcos de arma e voo.

## 15. Jogos sem breakdown técnico público encontrado

- **Dragon Ball Sparking! Zero** (Spike Chunsoft, UE5): achei só material de divulgação
  ([site oficial](https://www.bandainamcoent.com/games/dragon-ball-sparking-zero)). Nada técnico
  sobre os efeitos. Estudar por vídeo: clashes de feixe, crateras e destruição de terreno.
- **Brawlhalla** e **Rivals 2**: nenhum artigo de VFX. Para Rivals 1, a API documenta hitpause e
  efeitos ([Visual Effects List](https://rivalsofaether.com/visual-effects-list/)).
- **Street Fighter 6**: só a coluna oficial (§7).

---

## Lista priorizada: 15 efeitos a implementar ou ajustar

Ordem pelo ganho de sensação de impacto por esforço. Os que já existem são para calibrar.

1. **Hitstop por força com teto** (sim): leve 3-5, médio 6-9, forte 10-14, finalizador 18-24;
   o atacante sai 1-2 f antes. Mexe no hash, então registrar e atualizar os testes.
2. **Tremor do atingido** (já existe): eixo chão/ar, decaimento linear, atacante com ~30%,
   ruído determinístico pelo frame.
3. **Flash do atingido** (`hit_flash`): branco nos 2 primeiros frames do hitstop, depois rampa.
4. **Hitspark em 4 camadas** (flare branco, faísca sinestesia tingida, fagulhas Kenney, fumaça),
   com a direção vinda do knockback e a cor do atacante.
5. **Screenshake por trauma** (trauma², ruído pelo frame, contido durante o hitstop).
6. **Anel de choque em golpe forte** (`screen_fx` onda ou `shockwave_ring_simple`) + pulso de
   aberração cromática de 8-10 f.
7. **Rastro de lançamento em 3 faixas** (puffs toon, depois Trail2D na cor do atacante e speed
   lines planares).
8. **Poeira de pouso** proporcional à velocidade de queda (anel de fumaça para_particlefx + 2 puffs).
9. **Rachadura progressiva no módulo** (noise `Cracks` como máscara) como aviso antes de romper.
10. **Ruptura de vidro e concreto** com `PolygonFracture` (cacos com seed do evento) + faíscas
    brancas no vidro e terra/poeira no concreto.
11. **Special/Finish Zoom** no golpe decisivo: freeze estendido na sim + zoom, fundo tingido e
    speed lines radiais na apresentação. Desligado com mais de 2 lutadores.
12. **Impact frame do finalizador**: 1-2 f de threshold P&B, depois 3-6 f de mangá, no máximo
    1 por segundo e respeitando a F6.
13. **Colapso**: fumaça escura baixa em volume (Kenney smoke + dirkwybe), destroços que ficam na
    arena, trauma +0.4 e flash quente na vinheta.
14. **Clarão de luz no impacto** (`PointLight2D` 6 f na cor do atacante) e iluminação quente na
    explosão.
15. **Afterimage** em dash, lançamento e especiais (`afterimage_ghost`), e **flipbooks a
    12-20 fps segurados** para os efeitos desenhados (animação limitada).
