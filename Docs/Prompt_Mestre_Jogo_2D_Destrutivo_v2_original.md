# PROMPT MESTRE — Platform fighter 2D com destruição sistêmica

> Versão 2 (23/09/2026). Reescrita a partir do prompt original, das lições do projeto
> **Gloamwick: Last Vigil** (`C:\Projetos Dev\Gloamwick Last Vigil`) e de pesquisa sobre destruição
> 2D (Noita, Broforce, Worms, War of the Monsters, Red Faction: Guerrilla, Dead Cells).
> O que está marcado como **decisão padrão** já vem decidido: só mude com um teste que prove o
> contrário, registrado em ADR. O que está marcado como **em aberto** é para o time decidir.

Você faz parte de uma equipe de agentes de IA que vai transformar o conceito abaixo em um jogo real,
jogável e progressivamente expansível. Atue como designer, diretor técnico, programador de gameplay,
arquiteto de sistemas, level designer, diretor de arte e produtor, conforme a tarefa. Não entregue só
ideias: entregue decisões, documentos curtos, protótipos que rodam, testes e código.

---

## 0. Como ler este documento

1. §1–§2: o que o jogo é e o que não pode ser perdido.
2. §3: o que já sabemos que funciona (Gloamwick). Leia antes de propor stack ou pipeline.
3. §4–§8: **o coração técnico** — como a destruição funciona, o que é procedural e o que é autorado.
4. §9: direção de arte e pipeline de IA para manter consistência.
5. §10–§16: produção, fases, testes, coordenação e o que entregar agora.

---

## 1. Visão

Um jogo de luta 2D na estrutura de um platform fighter: leitura imediata, mobilidade vertical e
horizontal, partidas curtas e intensas, elenco original. A diferença: **o cenário não é fundo, é
material de combate**. Ele é destruído, atravessado, derrubado e reorganizado pelos golpes, e a
cidade que sobra no fim da partida é outra.

A sensação alvo é a de super-humanos lutando numa cidade viva: um golpe forte lança o adversário
através de uma parede, de uma loja inteira, de um andar, até cair na rua, **sem cutscene e sem trocar
de fase**. A câmera acompanha o voo, abre quando os lutadores se afastam e fecha quando se reencontram.

Referências de **sensação** (nunca de conteúdo): War of the Monsters e GigaBash (prédios que caem e
viram arma e terreno), Super Smash Bros. e Rivals of Aether (leitura e knockback), Comic Stars
Fighting e cenas de super-heróis (escala do impacto), Broforce e Noita (destruição 2D que muda o
caminho).

Frase-guia: **"Um platform fighter 2D em que a arena não contém a luta — a luta transforma a arena."**

Todo personagem, nome, cenário, poder, história e identidade visual é original. Não copiar
personagens, golpes, assets, nomes, interface ou qualquer propriedade intelectual de terceiros.

---

## 2. Pilares inegociáveis

**A. Combate legível.** Movimento responsivo, ataques leves/fortes/aéreos/especiais/agarrões (lista
final a definir), combos curtos e legíveis, verticalidade real, personagens realmente diferentes.
**A luta tem que ser divertida numa sala intacta**; a destruição amplifica, não substitui.

**B. Destruição sistêmica, não cosmética.** Destruir muda rotas, cobertura, espaço e opções de ataque.
Nada de "prédio = um objeto com barra de vida". Existem props, painéis, lajes, pilares e grandes
estruturas, cada um com regras próprias.

**C. Impacto e momentum.** Um sistema de energia de impacto decide se o corpo lançado atravessa, quica
ou para (especificação em §5).

**D. Cidade contínua.** Mapas são pequenos distritos conectados — rua, lojas, prédio de vários
andares, telhado, garagem, metrô — não plataformas flutuantes. A luta pode começar na avenida e
terminar no subsolo ou no telhado.

**E. Estado persistente na partida.** O que quebrou fica quebrado. Buraco no piso vira rota. Escombro
vira terreno. A arena do fim pode ser irreconhecível.

**F. Destruição aprendível.** O jogador tem que conseguir **prever** o que vai quebrar olhando para o
material. Aleatoriedade só no cosmético. (Pilar novo: sem isso não há intenção estratégica, e sem
intenção não há jogo de luta.)

**G. Câmera dinâmica** que aproxima, abre, acompanha arremessos e nunca perde a leitura.

**H. Elenco grande e variado**, balanceado por mobilidade, alcance, recuperação, peso, tempo de
ataque, recursos e **relação com o cenário** — força bruta não pode decidir sozinha.

---

## 3. O que o Gloamwick já provou (usar como base, não reinventar)

O Gloamwick (Godot 4.7.2, pixel art, arte e som gerados por IA, vários agentes em paralelo) chegou a
um jogo jogável em poucos dias. Estas lições são **decisões padrão** aqui:

### 3.1 Stack e processo
- **Engine: Godot 4.x.** O Gloamwick passou por protótipo web → Unity → Godot; a versão Godot foi a
  que ficou jogável e bonita. Trocar de stack no meio custou dias. Godot já está instalado em
  `C:\deps\godot-4.7.2\`. Não repetir a peregrinação: a Fase 1 aqui é **validar** Godot com um spike
  de destruição, não uma comparação aberta (ver §12).
- **Simulação em passo fixo separada da apresentação.** O Gloamwick simula a 12 Hz e interpola a
  renderização. Aqui: **simulação a 60 Hz fixa**, renderização interpolada.
- **RNG cosmético separado do RNG de simulação.** O clima do Gloamwick tem RNG próprio derivado da
  semente e "não toca em nada da simulação". Mesma regra para poeira, faíscas e debris cosmético.
- **Bot + autotest headless com sementes** (`--autotest N --semente S` em 4 sementes fixas) pegou
  bugs que ninguém teria jogado. **Flags de captura** (`--capture-scene --pular N --captura-em PASTA`)
  geraram screenshots de momentos exatos para revisão visual.
- **Revisão medida, não por impressão.** A revisão visual mediu luminância média das capturas
  (dia 48 vs noite 28 = amplitude 2×, quando precisava de 3–4×), consertou e mediu de novo (3×).
  Aqui: medir tempo de frame, corpos ativos, custo de reconstruir colisão, contraste lutador × fundo.
- **Revisão externa verificada contra o código.** A revisão do ChatGPT errou 4 pontos que só a
  leitura do código mostrou. Toda revisão externa passa por essa conferência antes de virar tarefa.

### 3.2 Coordenação de agentes
- **Contrato de módulos com dono único por arquivo** (`CONTRATO_MODULOS.md`): cada subagente tem
  posse exclusiva dos seus arquivos; o integrador cuida de `project.godot`, README e launcher.
- **API de leitura + eventos**: o núcleo expõe `state()` (snapshot só-leitura) e emite eventos
  nomeados; UI, áudio, câmera e VFX só escutam. **Evento ou som com nome desconhecido = silêncio,
  nunca erro.** Isso deixou quatro agentes trabalharem ao mesmo tempo sem se quebrar.
- **README com "Estado atual (leia isto primeiro)"** no topo: o que está jogável, o que mudou por
  último, o que falta sem enfeite. O diário das sessões fica abaixo.
- **Relatório por rodada** em `Docs/` com o que foi feito, o que falhou e por quê.

### 3.3 Arte e som com IA
- Pipeline que funcionou: **gpt-image via `codex exec`** (`GeradorAssets/scripts/gpt_image.py`) →
  limpeza (`pixelfixer` recupera a grade, snap na paleta mestra, alpha binário, remoção de pixels
  órfãos) → normalização de canvas/pivô → **validação automática** → PNG + JSON irmão
  (`frame_size`, `frames`, `fps`, `pivot`). Ferramentas também disponíveis: ComfyUI local
  (RTX 3060 Ti), Aseprite 1.3 + `pixel-mcp`, Blender, BiRefNet.
- **Âncora de identidade**: aprovar a imagem base primeiro; toda pose/estado seguinte anexa a âncora
  como Imagem 1. Rejeitar deriva de identidade em vez de tentar consertar.
- **Fundo magenta `#FF00FF`**; geração sem imagem de referência voltou com fundo escuro impossível de
  recortar. Sempre passar `--ref` apontando para uma prancha já em magenta.
- **Reduzir no máximo 1–2×.** Personagem gerado a 140 px e reduzido a 42 px vira borrão. Gerar já perto
  da grade final. Objetos finos (≤4 px) são desenhados à mão (tabela `DRAWN`).
- **Sprite não leva luz, brilho, sombra projetada, névoa nem chuva.** A engine faz isso. "Mecânica vem
  da engine, não do sprite": moedas, faíscas, poeira, tremor e pisca de dano eram código, com
  partículas de 1–2 px na paleta.
- **Cota do ChatGPT acaba** em lotes grandes: planejar lotes e usar ComfyUI local para iterar.
- **Som: ElevenLabs** (chave em `C:\Projetos Dev\GeradorVideos\.env`, pay-as-you-go, ≈5,3 créditos
  por segundo de áudio). O script tem freio `--teto` que relê o saldo antes de cada chamada. Manter.

### 3.4 O que deu errado lá e não pode repetir
- **Nenhum playtest humano** em toda a produção; tudo foi calibrado contra um bot fraco. Aqui, um jogo
  de luta sem humano jogando é inútil: **playtest humano ao fim de cada fase a partir da Fase 3.**
- Arte bloqueou regra (o Vigia a pé esperou sprite). Aqui, **greybox primeiro**: toda mecânica é
  provada com retângulos coloridos antes de pedir arte.
- A névoa a 92% de opacidade apagava a silhueta do jogador. Aqui: **nenhum efeito pode cobrir um
  lutador acima de um teto de opacidade** (ver §9.6).

---

## 4. Arquitetura da destruição: o modelo recomendado

### 4.1 As técnicas que existem, e onde cada uma serve

| Técnica | Exemplo | Serve para | Não serve para |
|---|---|---|---|
| **Grade de células/tiles** com HP por célula | Broforce, Terraria | gameplay determinístico, barato, colisão fácil | formas orgânicas em alta resolução |
| **Máscara por pixel + contorno** (marching squares → simplificação Douglas-Peucker → triangulação) | Worms, Noita (chunks de 64×64) | buracos com forma exata do golpe | cidade inteira com física por pixel |
| **Recorte de polígono** (`Geometry2D.clip_polygons`/`merge_polygons`) | libs Godot de fratura | fragmentos texturizados com a própria arte | ser a verdade do gameplay online (float) |
| **Estados autorados** (intacto → rachado → destruído, troca de sprite) | War of the Monsters, Rampage | peças-chave, marcos, leitura clara | variedade infinita |
| **Peças pré-fraturadas** soltas como corpos | jogos AAA 3D | colapsos grandes e espetaculares | tudo (custo de arte) |
| **Partículas/debris só visuais** | quase todos | poeira, faíscas, cacos, fumaça | afetar gameplay |
| **Colapso por grafo estrutural** | Red Faction: Guerrilla (pontos de tensão que o jogador aprende) | prédio que cai quando perde apoio | precisão de engenharia |

Nenhuma sozinha resolve. **Decisão padrão: o híbrido abaixo.**

### 4.2 O modelo híbrido em três níveis de resolução

**Nível fino — Grade de matéria (verdade do gameplay).**
- Cada estrutura é uma grade de **células de 8×8 px de mundo** (proposta; validar no spike). Cada
  célula guarda: `material_id`, `hp` (inteiro), `modulo_id`, flags (`estrutural`, `indestrutível`).
- Golpes e corpos lançados aplicam **carimbos de dano** (círculo, cápsula, linha de corte, cone de
  explosão) que reduzem `hp` das células; célula com `hp ≤ 0` vira vazia.
- A grade é dividida em **chunks** (proposta: 32×32 células). Só chunk alterado reconstrói colisão:
  marching squares → simplificação → polígonos de colisão. Orçamento fixo de reconstrução por frame;
  o que passar do orçamento entra na fila do próximo.
- Tudo em inteiros, passo fixo, sem float no caminho crítico → **determinístico** (necessário para
  rollback online no futuro, e para replays e testes hoje).

**Nível médio — Módulos (unidade de arte e de estrutura).**
- Um módulo é um bloco arquitetônico com arte própria: painel de parede, trecho de laje, pilar, viga,
  vitrine, porta, escada, trecho de trilho. Proposta: módulos múltiplos de 32 px (4×4 células).
- A arte do módulo é **multiplicada pela máscara das células** num shader: o buraco aparece com a forma
  exata do dano, mas cada pixel visível ainda é arte autorada (ver §6.2 sobre a borda).
- A integridade do módulo (% de células vivas, ponderada) decide o estado visual autorado
  (intacto / rachado / rompido) e alimenta o grafo estrutural.

**Nível grosso — Grafo estrutural (colapsos).**
- Nós = módulos estruturais (pilares, vigas, lajes, paredes portantes). Arestas = conexões.
  Âncoras = fundação/solo/estruturas indestrutíveis.
- Vidro, divisórias e props **não entram no grafo** (ou entram como folhas que só caem).
- **Só roda quando algo muda** (orientado a evento, nunca a cada frame):
  1. BFS a partir das âncoras. Todo conjunto de nós que perdeu caminho até uma âncora é uma **ilha**.
  2. Carga simplificada: cada nó soma o peso do que sustenta acima; se
     `carga > capacidade × integridade`, o nó entra em **falha anunciada**.
  3. Falha anunciada = **telegrafada**: 0,5–1,5 s de rachadura crescendo, poeira caindo, rangido.
     O jogador precisa ver o colapso vindo para usar e fugir dele (pilar F).
  4. A ilha cai (§4.3).
- O jogador aprende "pontos de tensão" como em Red Faction: derrubar um pilar do térreo derruba a ala;
  quebrar uma parede não portante não derruba nada.

### 4.3 Como a estrutura cai: cinemático no gameplay, físico no cosmético

**Decisão padrão:** colapsos que afetam gameplay são **cinemáticos e determinísticos**, não física de
corpo rígido.
- Uma ilha cai como **um corpo agrupado**: queda vertical, ou tombamento em torno de um pivô calculado
  (o último apoio de um lado), com trajetória de inteiros. Previsível, replicável, barata.
- A ilha causa dano e knockback em quem estiver embaixo (com a janela de aviso de §4.2).
- Ao bater no chão, a ilha se desfaz em módulos e vira **escombro** (§4.4).
- **Física real (RigidBody2D) só para o cosmético**: cacos, tijolos soltos, placas voando, com vida
  curta, pool fixo e sem colisão com lutadores. Pode variar entre máquinas sem problema.
- Props leves de gameplay (caixa, lixeira, carro pequeno) podem usar física, mas numa camada que
  **não altera colisão de terreno** e com número máximo ativo.

### 4.4 Escombro vira terreno

- Escombro é uma camada própria de células grossas (proposta: 8 px) com um **"falling sand" mínimo**:
  cada célula de escombro cai enquanto houver vazio abaixo e escorrega para a diagonal até assentar
  num ângulo de repouso. Determinístico, barato (só chunks ativos), e gera pilhas **jogáveis**:
  rampas, barreiras, bloqueios de porta.
- Escombro pode ser destruído de novo (material "entulho", classe baixa).
- Pedaços grandes (viga, laje inteira) podem virar **arma arremessável** (como em War of the Monsters)
  antes de assentar.

### 4.5 Camadas de profundidade de um prédio (problema específico da vista lateral)

Em vista lateral, a fachada fica **de frente para a câmera** e esconde o interior. Regras:

| Camada | Colisão | Destruição |
|---|---|---|
| Fundo distante (skyline, parallax) | não | só eventos autorados (prédio caindo ao fundo) |
| **Parede de fundo interna** (papel de parede, janelas do fundo) | não | visual: rasga e revela o céu/prédio de trás |
| **Plano de jogo**: lajes, pilares, paredes laterais, escadas, props | sim | grade de matéria completa |
| **Fachada frontal** | não | **cutaway**: fica translúcida/recortada quando há lutador dentro; pode ser estourada visualmente |
| Primeiro plano (postes, grades, placas) | não | cosmética, com teto de opacidade |

O interior de cada sala é autorado (loja, escritório, apartamento) e **aparece quando a fachada some** —
é isso que dá a sensação War of the Monsters de "abrir o prédio".

### 4.6 Nunca travar a partida (lição do Broforce)

- Elementos indestrutíveis mínimos garantem navegação: solo base, bordas do mapa, alguns núcleos.
- Todo mapa passa num **teste de navegabilidade por bot**: após destruição máxima scriptada, cada
  lutador ainda alcança o outro.
- Queda para fora do mapa/subsolo sem saída tem regra clara (respawn, dano, ou blast zone — ver §5.4).

---

## 5. Impacto e momentum: especificação inicial

### 5.1 Knockback do golpe
Base conhecida de platform fighter (fórmula pública do Rivals of Aether, adaptar):

```
KB = KB_base + (dano_acumulado + dano_golpe) × escala_KB × 0,12 × ajuste_peso
velocidade_inicial = KB × constante_de_mundo, na direção do ângulo do golpe
hitstun = proporcional a KB (fórmula própria, afinar em playtest)
hitstop = 3–12 frames conforme força (proposta)
```

### 5.2 Energia contra o cenário
Todo corpo lançado carrega energia `E = ½ · m · v²` (m = massa do personagem ou objeto).
Todo material tem **limiar de ruptura `R`** e **absorção `a`** (0–1).

Ao encostar numa superfície com células sólidas:
- **Se `E ≥ R`**: atravessa. As células na cápsula do corpo são destruídas.
  `E' = (E − R) × (1 − a)`; `v' = √(2E'/m)`, mesma direção com desvio pequeno e determinístico.
  Hitstop curto proporcional a `R` (atravessar concreto pesa mais que atravessar vidro).
- **Se `E < R`**: não atravessa. Quica (`v' = −v × restituição`) ou gruda (wall-splat) conforme
  o material; a superfície recebe dano proporcional a `E`. **Dano acumula**: a mesma parede quebra no
  segundo impacto. Rachadura visível comunica isso.
- Cadeia limitada: velocidade mínima de corte e máximo de rupturas por lançamento.
- Atravessar estrutura pode causar dano ao lançado (propor e testar; evitar punição dupla excessiva).

### 5.3 Classes de material (valores iniciais para afinar)
Unidade: energia de um golpe forte padrão contra personagem médio a 100%.

| Classe | Exemplos | R (proposta) | Leitura visual obrigatória |
|---|---|---|---|
| A | vidro, placas, caixas, divisórias finas | 0,05 | transparente/frágil, brilho frio |
| B | madeira, portas, móveis robustos, drywall | 0,2 | tons quentes, veio |
| C | alvenaria, tijolo, paredes comuns | 0,5 | padrão de tijolo/bloco |
| D | concreto armado, pilares, lajes | 1,2 | cinza liso, ferragem aparente ao romper |
| E | núcleos indestrutíveis, fundação, marcos especiais | ∞ ou condição | marcação consistente (ex.: faixa/metal escuro) |

**Material tem que ser legível pela cor e pela textura** — é o que torna a destruição aprendível.

### 5.4 Propriedades de ataque
Cada golpe declara um tipo de carimbo: **impacto** (círculo), **penetração** (multiplica contra D),
**explosão** (radial, dano em área), **corte** (linha fina e longa), **perfuração** (buraco pequeno e
fundo), **empurrão** (desloca props sem quebrar). Especiais de personagem podem ter propriedades
de cenário próprias (derreter, congelar, erguer escombro etc.).

**Em aberto:** condição de vitória. Percentual + blast zones (bordas/céu do distrito) ou vida/stocks?
Numa cidade contínua a blast zone precisa ser legível. Prototipar as duas na Fase 3.

---

## 6. O que é procedural e o que é autorado

"Destruição animada" não significa desenhar cada quebra. A sensação de animação vem da soma de
hitstop, tremor, flipbooks de VFX, peças voando e a forma do buraco — a maior parte gerada em tempo
real sobre arte autorada.

### 6.1 Tabela de responsabilidades

| Elemento | Procedural (código) | Autorado (arte/IA) |
|---|---|---|
| Forma do buraco | ✅ carimbo na grade de matéria | — |
| Borda do buraco | aplicação por shader | ✅ textura de "borda quebrada" por material |
| Interior revelado (tijolo sob reboco, ferragem no concreto) | seleção por material | ✅ camada "miolo" por material |
| Rachaduras | ✅ posição/crescimento a partir do impacto | ✅ 3–4 decalques de rachadura por material |
| Estado do módulo (intacto/rachado/rompido) | ✅ escolhe pela integridade | ✅ arte de cada estado |
| Fragmentos voando | ✅ recorte de polígono **amostrando a própria arte do módulo** | — |
| Poeira, faíscas, fumaça, cacos | ✅ spawn, direção, quantidade | ✅ flipbooks de 6–8 quadros por material |
| Partículas finas (1–2 px) | ✅ na paleta do material | — |
| Colapso de ilha | ✅ grafo + queda cinemática | — |
| Pilha de escombro | ✅ falling sand mínimo | ✅ tileset de escombro por material |
| Grandes eventos (torre, ponte, letreiro gigante) | gatilho pelo grafo | ✅ sequência autorada (animação + peças pré-fraturadas) |
| Reação do lutador ao atravessar | ✅ hitstop, tremor, rastro | ✅ quadros de "atravessando"/"splat" do personagem |
| Interior das salas | disposição por módulos | ✅ salas autoradas |
| Layout do distrito | — | ✅ autorado (procedural só em variação de props) |

### 6.2 Por que isso mantém consistência com IA
- **Fragmentos amostram a textura original**: não há arte nova no caco, então não há deriva de estilo.
- **Buracos respeitam a grade de pixels e a paleta**: a máscara está alinhada ao pixel de arte, então
  o recorte procedural parece desenhado à mão (é por isso que Noita funciona).
- **A borda é arte autorada aplicada proceduralmente**: o shader pinta o anel de pixels junto à borda
  da máscara com a textura de borda quebrada do material. Sem isso, buraco procedural parece
  "recortado com tesoura".
- A IA gera **peças pequenas e repetíveis** (módulo, borda, miolo, decalque, flipbook) em vez de cenas
  inteiras destruídas — é o formato em que a consistência dela é alta.

---

## 7. Mapa e cidade

- Distrito de teste: proposta de **4–6 telas de largura e 3 de altura** incluindo subsolo.
- Grade de tiles 16 px; módulos de 32 px; **andar = 128 px** (≈2 alturas de personagem, para caber
  luta dentro de sala). Portas ≈80 px. Validar no greybox.
- Regiões possíveis: avenida, lojas, prédio residencial, escritório, telhado, estacionamento, estação,
  metrô, túnel, praça, garagem.
- Cada mapa tem um **roteiro de destruição**: quais colapsos existem, que rotas abrem/fecham, onde
  estão os núcleos indestrutíveis. Destruição é level design, não acaso.
- Cidade viva: veículos, semáforos, postes, vitrines, elevadores, tubulações, letreiros, fiação,
  portões. **Civis e animais**: fuga, evacuação e reação estilizada; sem gore nem violência gráfica.

---

## 8. Câmera

- Enquadra todos os lutadores com margem; zoom limitado entre um mínimo e um máximo definidos pela
  densidade de pixel (§9.3).
- **Modo arremesso**: acompanha o corpo lançado com antecipação na direção do voo e abre o zoom
  conforme a velocidade; volta suave quando a energia acaba.
- Colapsos grandes podem ganhar câmera lenta curta e rara (≤0,5 s), nunca em sequência.
- Tremor proporcional à energia, com teto e opção de acessibilidade.
- Split-screen dinâmico: estudar só se o playtest mostrar perda de leitura com distância; não adotar
  sem medir.

---

## 9. Direção de arte e pipeline com IA

### 9.1 As três opções pesquisadas

| | A. Pixel art low-res (como Gloamwick, 480×270) | **B. Hi-bit pixel art (640×360) com personagens renderizados de 3D** | C. HD pintado/vetorial com animação por esqueleto (cutout) |
|---|---|---|---|
| Pipeline de IA | provado | provado para cenário; 3D→pixel a validar | não testado aqui |
| Destruição procedural | nativa (grade de pixels) | **nativa** | recorte limpo demais, precisa borda autorada pesada |
| Consistência entre quadros de personagem | fraca em sprites grandes com muitos golpes | **forte** (o modelo 3D garante) | forte |
| Volume de animação de jogo de luta (30–60 animações × elenco) | inviável quadro a quadro | **viável**: anima uma vez, renderiza todas | viável |
| Zoom dinâmico | difícil | exige shader (§9.3) | nativo |
| Detalhe do lutador na tela | pouco (≈40 px) | bom (≈64–96 px) | alto |

### 9.2 Decisão padrão: **B — hi-bit pixel art, 640×360 de base**
- 640×360 escala ×3 para 1080p e ×6 para 4K, sem sobra.
- **Personagens:** pipeline Dead Cells — modelo 3D com esqueleto, animado por keyframes, renderizado
  em tamanho pequeno **sem antialiasing**, com shader toon, snap na paleta e normal map por quadro.
  Vantagens para este jogo: mudar o timing de um golpe leva minutos, a identidade nunca deriva e
  poses de "atravessando parede" e "splat" saem do mesmo rig. O modelo pode nascer de concept gerado
  por IA + geração 3D (o pipeline 3D do ComfyUI/Blender já existe em `GeradorAssets`).
  Retoque no Aseprite só nos quadros-chave de impacto.
- **Cenário, módulos, bordas, miolos, decalques e VFX:** pixel art 2D pelo pipeline do Gloamwick
  (gpt-image com âncora + limpeza + paleta + validação).
- **Validar antes de produzir (bake-off da Fase 0):** um personagem com 3 animações (idle, golpe
  forte, lançado/atravessando) e um módulo de parede em 3 estados + buraco procedural, feitos em
  **A e B** (C só se B falhar). Critérios: consistência entre quadros, leitura a 1× e com zoom, tempo
  por animação, custo de cota. Registrar o resultado em ADR. Se B falhar, cair para A com elenco de
  sprites menores, ou C.

### 9.3 Zoom com pixel art
- Não usar framebuffer de baixa resolução escalado (quebra com zoom contínuo). Renderizar os sprites
  no mundo em alta resolução com filtro **"sharp bilinear" / "fat pixel"**: nearest dentro do texel e
  interpolação só na borda. Remove o tremido de pixel ao mover e permite zoom fracionário.
- **Regra de densidade**: um pixel de arte ocupa entre 2 e 6 pixels de tela em 1080p. O zoom da
  câmera fica dentro dessa faixa.
- Todos os assets na **mesma escala de pixel**. Nunca misturar sprites com resoluções diferentes.

### 9.4 Style bible (preencher na Fase 0, antes de gerar qualquer asset)
- Paleta mestra (~48 cores): **cidade dessaturada e de valor médio; lutadores saturados e com contorno
  de valor mais escuro**, para separar lutador de fundo sob qualquer destruição.
- Paleta por material que bate com §5.3 (vidro frio, madeira quente, tijolo vermelho, concreto cinza,
  metal azulado, núcleo indestrutível com marca própria).
- Luz única de cima-esquerda; sombra de 1 tom; sem sombra projetada nem brilho pintado no sprite.
- Alpha sempre 0 ou 255.
- **Régua de escala** com lutador leve, médio e pesado, porta, andar, carro e módulo lado a lado.
- Nome em `snake_case` com prefixos: `chr_`, `mod_` (módulo), `brk_` (borda quebrada), `core_`
  (miolo), `dec_` (decalque), `rub_` (escombro), `fx_`, `bg_`, `ui_`, `prop_`.
- Tema visual da cidade: **em aberto** (proposta: quadrinho urbano contemporâneo, silhuetas fortes,
  letreiros sem texto legível de marcas reais).

### 9.5 Regras de geração com IA (consistência)
1. Uma peça por imagem, vista **estritamente lateral/ortográfica**, fundo magenta, `--ref` sempre.
2. **Módulos em canvas-padrão** (múltiplo de 32 px) e mesma borda de base.
3. Estado intacto aprovado vira âncora. Rachado e rompido saem **por edição da âncora** ("a mesma
   parede, agora com…"), nunca de prompt do zero.
4. Borda quebrada, miolo e decalques são **texturas repetíveis** (tileáveis) por material.
5. VFX em flipbook de 6–8 quadros, âncora central, sem fundo.
6. Toda saída passa por: limpeza → paleta → alpha binário → pixels órfãos → canvas/pivô → JSON irmão
   → **validador automático** → inspeção a 1× → só então entra no jogo.
7. Guardar prompt, referências e imagem bruta de cada asset (rastreabilidade, como no Gloamwick).
8. Lotes planejados por cota; ComfyUI local para iterar silhuetas sem custo.

### 9.6 Legibilidade no caos
- Poeira e fumaça **nunca** passam de um teto de opacidade sobre lutadores (proposta: 0,6); lutadores
  podem ganhar contorno/rim light quando cobertos.
- Debris cosmético mais escuro e menos saturado que lutadores.
- Medir por captura: contraste médio lutador × fundo em cenas de destruição máxima.

### 9.7 Som
ElevenLabs com `--teto`. Som de quebra em **camadas por material**: impacto + ruptura + cauda de
detritos, com variações e volume pela energia. Nomes semânticos (`brk_concreto_grande`); nome ausente
= silêncio.

---

## 10. Arquitetura de software

Duas metades que nunca se misturam:

**Simulação (determinística, dona da verdade, 60 Hz fixos, inteiros/ponto fixo onde importa)**
`InputBuffer` · `Fighter` (estado, física cinemática própria — não RigidBody) · `CombatSystem`
(hitbox/hurtbox, dano, knockback, hitstun) · `ImpactResolver` (§5.2) · `MatterGrid` (células, chunks,
carimbos) · `CollisionBuilder` (marching squares, orçamento por frame) · `StructuralGraph` (ilhas,
carga, falha anunciada) · `CollapseSystem` (queda cinemática) · `RubbleSim` (falling sand mínimo) ·
`MatchManager` · `SimRNG` · `Snapshot` (serializa o estado inteiro).

**Apresentação (cosmética, descartável, pode variar entre máquinas)**
`CameraDirector` · `FighterView` · `ModuleView` (shader de máscara + borda + miolo) · `DebrisFX`
(RigidBody2D em pool) · `VfxSpawner` · `AudioEvents` · `Hud` · `DebugOverlay`.

Regras:
- A simulação expõe `state()` e emite eventos; a apresentação só lê e escuta (padrão Gloamwick).
- **A simulação é uma função de (estado, inputs)**. Preparar rollback desde o dia 1 custa pouco;
  retrofit custa o projeto. Online em si fica para depois (§11).
- Linguagem: GDScript para gameplay. Caminhos quentes (`MatterGrid`, `CollisionBuilder`,
  `RubbleSim`) podem ir para C#/GDExtension **se o profiling mandar**, não antes.
- Física do Godot só na apresentação. Se um dia precisar de física determinística na simulação,
  avaliar o Rapier 2D na variante determinística multiplataforma (registrar em ADR).

### 10.1 Orçamentos de performance (propostas para medir e ajustar)
- 60 fps estáveis em hardware-alvo com 4 lutadores (**hardware-alvo em aberto**; proposta: a máquina
  de desenvolvimento com RTX 3060 Ti como teto e uma integrada como piso).
- Reconstrução de colisão: ≤2 ms por frame, fila para o excedente.
- Grafo estrutural: só em evento, ≤1 ms por evento.
- Debris cosmético: ≤150 corpos ativos; o excedente vira partícula ou é descartado pelo mais antigo.
- Escombro: só chunks não assentados simulam.

---

## 11. Modos de jogo (ordem)
1. Duelo local 1v1.
2. Local 2–4 jogadores.
3. Bots simples (também usados em teste).
4. Online com rollback **só** depois de combate, destruição e determinismo estarem estáveis e com
   teste de replay passando. O online nunca bloqueia o protótipo.

---

## 12. Fases

**Fase 0 — Formalizar (curto).** GDD enxuto, decisões em aberto, essencial/desejável/futuro, riscos.
Style bible e **bake-off de arte (§9.2)**. Não expandir escopo para parecer criativo.

**Fase 1 — Spike técnico de destruição em Godot (substitui a comparação aberta de engines).**
Em greybox: grade de matéria com carimbos, reconstrução de colisão por chunk, um grafo com uma ilha
que cai, escombro assentando, 150 debris cosmético. Medir custos. Passou nos orçamentos → Godot
confirmado em ADR. Falhou → ADR com o motivo e só então comparar alternativas (Unity/Unreal), com
os mesmos testes.

**Fase 2 — Arquitetura.** Módulos de §10, contrato de módulos com dono por arquivo, API `state()` +
eventos, estrutura de pastas, launcher `.bat`, flags de teste.

**Fase 3 — Movimento e combate em greybox.** Um lutador placeholder, movimento, pulo, esquiva,
ataques, hitstop, hitstun, knockback, câmera simples, protótipo das duas condições de vitória.
**Primeiro playtest humano.**

**Fase 4 — Impacto em estruturas.** Corpo lançado contra paredes, energia, ruptura, continuação,
classes A–D, dano acumulado, wall-splat.

**Fase 5 — Integridade estrutural.** Grafo, falha anunciada, colapso cinemático, escombro jogável.

**Fase 6 — Quarteirão da vertical slice.** Rua + prédio de 2–3 andares com interiores + subsolo;
roteiro de destruição; teste de navegabilidade.

**Fase 7 — Segundo lutador** de filosofia oposta (ex.: pesado de alto impacto × leve e veloz).

**Fase 8 — Arte e som de verdade na slice.** Pipeline de §9 aplicado a 2 lutadores, 1 material
completo de cada classe, VFX e som por material.

**Fase 9 — Polimento e análise.** Profiling, bugs, legibilidade medida, câmera, controle de debris,
playtests repetidos.

**Fase 10 — Expansão só depois da slice validada.** Elenco, distritos, modos, online, progressão,
cosméticos, narrativa se fizer sentido.

---

## 13. Testes e ferramentas (desde a Fase 2)

- `--autotest N --semente S`: bots lutam N segundos headless em 4 sementes fixas; falha em erro de
  script ou invariante quebrada.
- **Teste de replay determinístico**: grava inputs → reproduz → compara o hash do `Snapshot` a cada
  N frames. Diferença = bug de determinismo. É a rede de segurança da destruição e do futuro online.
- **Cena de estresse de destruição**: explode X% de um quarteirão e grava tempo de frame, corpos
  ativos e ms de reconstrução em CSV.
- **Teste de navegabilidade** pós-destruição por mapa.
- Testes unitários para lógica determinística: `ImpactResolver`, carimbos, BFS de ilhas, carga,
  falling sand.
- `--capture-scene --pular N --captura-em PASTA` para capturas de momentos exatos; revisão visual
  com medição (contraste, luminância, opacidade sobre lutadores).
- **Debug overlay** alternável: células por material/HP, chunks sujos, grafo com carga por nó, ilhas,
  vetores de energia de impacto, hitboxes.
- Validador de assets (paleta, alpha, canvas, pivô, JSON).

---

## 14. Regras para os agentes

- Não virar fighting game genérico. Não reduzir destruição a efeito visual.
- **Greybox antes de arte.** Nenhuma mecânica espera sprite.
- Não criar dezenas de sistemas antes de validar o loop. Não produzir dezenas de personagens cedo.
- Não usar IP de terceiros. Não adicionar dependência sem explicar finalidade e licença.
- Não assumir que destruição precisa de física real; gameplay é determinístico, física é cosmética.
- Nada cosmético decide resultado de combate.
- Código modular, legível, sem monólito; sistemas desacoplados e testáveis.
- Toda feature entregue diz **como executar e como testar manualmente**.
- Teste automático para toda lógica determinística.
- Sistema caro tem orçamento e estratégia de profiling.
- Decisão importante vira ADR. Revisão externa é conferida contra o código antes de virar tarefa.
- Atualizar o "Estado atual" do README ao fim de cada rodada, sem enfeite.

---

## 15. Coordenação entre agentes

- Fonte de verdade única: `VISION.md`, `ARCHITECTURE.md`, `CONTRATO_MODULOS.md`, `BACKLOG.md`, ADRs.
- **Um dono por arquivo** durante trabalho paralelo; interface pública só muda com registro no
  contrato. Integrador cuida de `project.godot`, README e launcher.
- Cada agente reporta: arquivos criados/alterados, decisões, testes rodados (com saída), pendências.
- Revisão antes de integrar mudança grande. Backlog único com prioridade explícita.

Papéis:
- **Diretor/Integrador** — visão, prioridades, contrato, integração, README.
- **Gameplay** — lutadores, estados, ataques, knockback, balanceamento inicial.
- **Destruição** — `MatterGrid`, `ImpactResolver`, grafo, colapso, escombro, colisão.
- **Mundo/Level design** — distrito, módulos no mapa, roteiro de destruição, navegabilidade.
- **Arte/Pipeline** — style bible, bake-off, geração, limpeza, validação, shaders de módulo e VFX.
- **Técnico** — arquitetura, performance, determinismo, build, ferramentas de teste.
- **Áudio** — eventos, geração com teto de custo, mixagem.
- **QA** — replays, regressões, casos extremos, playtest humano organizado.

---

## 16. Documentação mínima do repositório

`README.md` (com "Estado atual — leia isto primeiro"), `VISION.md`, `GDD.md`, `ARCHITECTURE.md`,
`CONTRATO_MODULOS.md`, `ROADMAP.md`, `BACKLOG.md`, `ADR/`, `TESTING.md`, `PERFORMANCE.md`,
`ART_BIBLE.md` (+ paleta `.gpl` e régua de escala), `ASSET_PROMPTS.md`, `Docs/rodadas/` (um relatório
por rodada), `CHANGELOG.md` quando amadurecer.

---

## 17. Definição de pronto da vertical slice

- Dois jogadores lutam de forma divertida com dois lutadores diferentes — **confirmado por playtest
  humano**, não só por bot.
- Knockback coerente; corpos atravessam elementos quando a energia basta e quicam quando não basta.
- Um jogador consegue **prever** o que quebra olhando o material.
- A destruição abre e fecha rotas úteis; existe pelo menos um colapso estrutural telegrafado e legível.
- Escombro vira terreno jogável; o mapa continua navegável após destruição máxima (teste passa).
- Câmera acompanha luta próxima e arremessos longos sem perder leitura.
- Orçamentos de §10.1 cumpridos no hardware-alvo, com CSV da cena de estresse como prova.
- Teste de replay determinístico passa.
- Arte dos 2 lutadores e dos materiais da slice passou pelo pipeline e pelo validador.
- Sobe com um duplo clique, sem configuração manual.

---

## 18. O que entregar agora

Modo de planejamento técnico primeiro. Entregue, nesta ordem:
1. Interpretação do projeto em até 10 pontos.
2. Decisões em aberto (inclua as marcadas **em aberto** neste documento) com recomendação para cada.
3. Riscos técnicos e de produção, com como cada um será testado cedo.
4. Plano do **spike de destruição** (Fase 1) e do **bake-off de arte** (Fase 0).
5. Loop principal de gameplay.
6. Especificação refinada de impacto e destruição (partindo de §4–§6).
7. Arquitetura inicial (partindo de §10) e contrato de módulos.
8. Plano da vertical slice e backlog priorizado por fase.
9. Estrutura de pastas do repositório.
10. Primeiros testes e ferramentas de debug.
11. Só depois disso, os primeiros arquivos de código.

Antes de modificar um repositório existente: inspecione a estrutura, leia README e documentação,
identifique engine e versão, não sobrescreva trabalho sem necessidade, faça checkpoints pequenos e
descritivos.

Ao implementar, trabalhe incrementalmente e informe em cada etapa: objetivo, arquivos alterados,
comportamento esperado, como executar, como testar, limitações atuais e próxima tarefa recomendada.

O foco é provar a experiência central, não construir o jogo inteiro de uma vez.

---

## Apêndice — Referências da pesquisa

- Noita, GDC 2019 "Exploring the Tech and Design of Noita": falling sand, chunks de 64×64, corpos
  rígidos por marching squares → Douglas-Peucker → triangulação → Box2D.
  https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design
- Dead Cells, pipeline 3D → pixel art: https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-
- Broforce, terreno por blocos com núcleos indestrutíveis: https://en.wikipedia.org/wiki/Broforce
- War of the Monsters, prédios destrutíveis que viram arma: https://en.wikipedia.org/wiki/War_of_the_Monsters
- Red Faction: Guerrilla, destruição por tensão estrutural: https://gdcvault.com/play/1012330/Multiplayer-Level-Design-in-Red
- Godot, terreno destrutível com `Geometry2D.clip_polygons`: https://github.com/CortezSMz/godot-smartshape2d-destructible-terrain
- Godot, fratura de polígonos: https://github.com/SoloByte/godot-polygon2d-fracture
- Godot, terreno por marching squares com chunks: https://github.com/richardhyy/Godot-4-Destructable-Terrain
- Rapier 2D determinístico para Godot: https://godot.rapier.rs/
- Filtro sharp bilinear para pixel art com zoom: https://github.com/godotengine/godot-proposals/issues/6995 e https://jorenjoestar.github.io/post/pixel_art_filtering/
- Fórmula de knockback do Rivals of Aether: https://rivalsofaether.com/get_kb_formula/
- Gloamwick (local): `GodotGame/README.md`, `GodotGame/CONTRATO_MODULOS.md`, `Docs/Art/GLOAMWICK_ART_BIBLE.md`,
  `Docs/Art/PRODUCTION_ASSET_PROMPTS.md`, `Docs/Art/RELATORIO_ARTE_17_09.md`, `AssetPipeline/README.md`,
  `C:\Projetos Dev\GeradorAssets\PLANO_PIXELART.md`.

