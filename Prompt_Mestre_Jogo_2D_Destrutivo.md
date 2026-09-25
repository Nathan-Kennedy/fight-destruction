# PROMPT MESTRE — Platform fighter 2D com destruição sistêmica

> Versão 3.1 (24/09/2026): decisões da sessão de perguntas registradas em §0.1. Versão 3 preservada
> em `Docs/Prompt_Mestre_Jogo_2D_Destrutivo_v3.md`; versão 2 em
> `Docs/Prompt_Mestre_Jogo_2D_Destrutivo_v2_original.md`. Baseada nas lições do projeto
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
5. §10–§18: produção, fases, testes, coordenação e entregas.
6. §19–§23: padrão visual, fábrica de assets, Astra + Opus, skills e marcos de validação.

**Modo de uso:** este é o briefing de produção, não uma ordem para executar todas as fases numa
única sessão. Se a tarefa atual for revisar o documento, edite a documentação. Se for iniciar o
jogo, execute §18. As metas numéricas são hipóteses de projeto até serem medidas; exemplos de
CLI são contratos a implementar, não ferramentas que já existem neste repositório.

### 0.1 Decisões fechadas com o dono do projeto (24/09/2026)

| Tema | Decisão | Onde se aplica |
|---|---|---|
| Condição de vitória | **Híbrido**: percentual + 3 stocks com blast zones fixas, e KO também por evento ambiental forte (ex.: soterrado por colapso). Regra exata do KO ambiental se afina no M2 | §5.4 |
| Tema da cidade | **Retrofuturista** conforme §19.1 | §9.4, §19.1 |
| Hardware-alvo | RTX 3060 Ti (máquina de dev) como teto; GPU integrada como piso de medição | §10.1 |
| Entrada | **Gamepad e teclado desde o M1** (2 jogadores locais: teclado compartilhado ou gamepads) | §11, §23 |
| Implementação | **Opus 5.5 implementa o M0/M1; Astra revisa.** Alternar depois conforme §21.1 | §21.1 |
| Lutadores iniciais | Placeholders genéricos (leve, médio, pesado) até o M1 provar a sensação | §5.5, §23 |
| Custo de assets | Por enquanto só assinaturas que o dono já paga; sem gasto novo até revisão | §20.5 |
| Início | Implementação do M0/M1 autorizada | §23.1 |

**Ambição:** automatizar com IA grande parte de código, ferramentas, conceitos, assets e QA.
Direção estética, aceitação de marcos e sensação de controle exigem revisão e playtest humano.
Não prometer percentual de automação, prazo de produção ou qualidade comercial sem evidência.

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

O README local do Gloamwick registra uma versão jogável em Godot 4.7.2. O diretório local
`C:\deps\godot-4.7.2\` foi encontrado nesta revisão; conferir a versão do executável antes de usar.
As demais lições abaixo são histórico herdado, não benchmarks deste jogo. O README do
`AssetPipeline` ainda descreve integração com Unity: reaproveitar utilitários após inspeção,
sem assumir que a importação Godot ou o pipeline 3D já estejam prontos.
Estas lições orientam as **decisões padrão** aqui:

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
  nomeados; UI, áudio, câmera e VFX só escutam. **Evento obrigatório desconhecido = erro de validação em desenvolvimento;
  som opcional ausente = fallback ou silêncio com aviso deduplicado.** Essa distinção é melhoria
  desta revisão; o histórico anterior relatava tolerância silenciosa a eventos ausentes.
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
- **Fundo magenta `#FF00FF`** ajudou o pipeline anterior. Preferir alpha nativo quando disponível;
  usar chroma key como fallback conforme §9.5, com referência visual.
- **Reduzir no máximo 1–2×.** Personagem gerado a 140 px e reduzido a 42 px vira borrão. Gerar já perto
  da grade final. Objetos finos (≤4 px) são desenhados à mão (tabela `DRAWN`).
- **Sprite não leva luz, brilho, sombra projetada, névoa nem chuva.** A engine faz isso. "Mecânica vem
  da engine, não do sprite": moedas, faíscas, poeira, tremor e pisca de dano eram código, com
  partículas de 1–2 px na paleta.
- **Cota do ChatGPT acaba** em lotes grandes: planejar lotes e usar ComfyUI local para iterar.
- **Som: ElevenLabs como candidato já usado no histórico.** Validar acesso, termos e preço atual
  antes de gerar. Credenciais por ambiente, nunca no prompt ou nos manifests. Manter teto de
  gasto por lote, inclusive tentativas rejeitadas; verificar o comportamento real do script.

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
| **Máscara por pixel + contorno** (marching squares e simplificação) | família de terrenos destrutíveis; inspiração em Noita | recorte visual detalhado | assumir que resolução visual precisa ser a resolução do gameplay |
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
- A grade é dividida em **chunks** (proposta: 32×32 células). **Colisão dos lutadores consulta a
  grade autoritativa com varredura contínua**, incluindo paredes finas e bordas entre chunks.
  Destruição e colisão mudam atomicamente no tick; não pode existir parede invisível por atraso.
- Contornos via marching squares/simplificação são derivados para visualização e colisão de
  debris cosmético. Podem ter fila por tempo de frame; **essa fila nunca decide o gameplay**.
  Comparar contornos com mesclagem de retângulos antes de adotar triangulação mais complexa.
- Se trabalho autoritativo for distribuído entre ticks, usar quota fixa de operações, ordenação
  estável e fila serializada. Nunca usar relógio de parede para escolher o que a simulação resolve.
- Inteiros/ponto fixo e 60 Hz são uma base, **não prova de determinismo**. Fixar arredondamento,
  overflow, ordem de contatos, IDs, RNG e serialização; verificar replays e restauração (§13).
- 8×8 é resolução de gameplay, não pixel art fina. Testar células 4×4 e 8×8 no mesmo cenário.
  Máscara visual pode detalhar a borda, mas não mostrar passagem que a colisão proíbe.

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
  2. Na primeira slice, usar perda de conectividade às âncoras e regras autoradas de apoio mínimo.
     Carga distribuída é extensão: grafos com ciclos não podem simplesmente somar tudo acima.
     Se necessária, definir DAG de transferência de carga, desempates e conservação de peso,
     com fixtures de viga em dois apoios, balanço e ciclo. Não vender isso como engenharia real.
  3. Falha anunciada = **telegrafada**: 0,5–1,5 s de rachadura crescendo, poeira caindo, rangido.
     O jogador precisa ver o colapso vindo para usar e fugir dele (pilar F).
  4. A ilha cai (§4.3).
- O jogador aprende "pontos de tensão" como em Red Faction: derrubar um pilar do térreo derruba a ala;
  quebrar uma parede não portante não derruba nada.

### 4.3 Como a estrutura cai: cinemático no gameplay, físico no cosmético

**Decisão padrão:** colapsos que afetam gameplay são **cinemáticos e determinísticos**, não física de
corpo rígido.
- Uma ilha cai como **um corpo agrupado**, inicialmente por translação vertical. Tombamento com
  rotação fica para depois de provar varredura, contato e deposição. Modelar estados explícitos:
  `supported → warning → falling → settled`; tempos em ticks, IDs estáveis, uma única autoridade.
  Remover células da grade estática ao destacá-las; manter a ilha em colisão dinâmica própria.
- A ilha causa dano e knockback em quem estiver embaixo (com a janela de aviso de §4.2).
- Ao bater no chão, a ilha se desfaz em módulos e vira **escombro** (§4.4).
- **Física real (RigidBody2D) só para o cosmético**: cacos, tijolos soltos, placas voando, com vida
  curta, pool fixo e sem colisão com lutadores. Pode variar entre máquinas sem problema.
- Props que causam dano, bloqueiam ou podem ser arremessados usam movimento autoritativo próprio
  e entram no snapshot. Separar camadas não torna `RigidBody2D` determinístico.

### 4.4 Escombro vira terreno

- Escombro é uma camada própria de células grossas (proposta: 8 px) com um **"falling sand" mínimo**:
  cada célula de escombro cai enquanto houver vazio abaixo e escorrega para a diagonal até assentar
  num ângulo de repouso. Ordem fixa de atualização e custo a medir; gera pilhas **jogáveis**:
  rampas, barreiras, bloqueios de porta.
- Escombro pode ser destruído de novo (material "entulho", classe baixa).
- Pedaços grandes podem virar **arma arremessável** após a slice; não bloquear o primeiro colapso.
- Depositar escombro por ordem estável, com limite de células ativas e regra para sobreposição
  com lutadores: deslocamento seguro determinístico ou dano/respawn previsto. Nunca enterrar
  permanentemente o jogador. Massa descartada por simplificação vira apenas poeira visual.
- Falling sand é candidato, não obrigação de arquitetura. Se custar demais, usar pilhas autoradas
  parametrizadas pela área derrubada, mantendo escombro destrutível e rotas realmente alteradas.

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

Fórmula de projeto inspirada no gênero, **não reprodução verificada de Rivals of Aether**:

```
KB = KB_base + (dano_acumulado + dano_golpe) × escala_KB × 0,12 × ajuste_peso
velocidade_inicial = KB × constante_de_mundo, na direção do ângulo do golpe
hitstun = proporcional a KB (fórmula própria, afinar em playtest)
hitstop = 3–12 frames conforme força (proposta)
```

### 5.2 Energia contra o cenário

Modelo de design, não simulação física real: `E = ½ · m · v²`, com unidades de mundo documentadas.
Todo material tem resistência por espessura/área e absorção `a` (0–1). Calcular `R_efetivo` a partir
somente das células sólidas inéditas no percurso, do HP restante e da seção atravessada. Parede
mais espessa custa mais energia; material já removido não cobra energia novamente. Os valores
normalizados de §5.3 são referências de uma parede-padrão, não joules por célula.

Usar varredura do volume do corpo entre posição anterior e proposta; ordenar contatos por tempo
de impacto e ID como desempate. Processar o deslocamento restante após cada ruptura. Fixar
arredondamento e raiz inteira/ponto fixo; trigonometria e normalização também precisam de contrato.
Nos casos abaixo, `R` significa `R_efetivo`:

Ao encostar numa superfície com células sólidas:
- **Se `E ≥ R`**: atravessa. As células na cápsula do corpo são destruídas.
  `E' = (E − R) × (1 − a)`; `v' = √(2E'/m)`, mesma direção com desvio pequeno e determinístico.
  Hitstop curto proporcional a `R` (atravessar concreto pesa mais que atravessar vidro).
- **Se `E < R`**: não atravessa. Quica pela componente normal (`v' = v − (1 + e) · dot(v,n) · n`, com atrito tangencial definido)
  ou gruda (wall-splat) conforme
  o material; a superfície recebe dano proporcional a `E`. **Dano acumula**: a mesma parede quebra no
  segundo impacto. Rachadura visível comunica isso.
- Cadeia limitada: velocidade mínima de corte e máximo de rupturas por lançamento. Ao atingir
  o limite, parar no último ponto seguro, sem atravessar matéria intacta. Contatos já resolvidos
  não reaplicam dano no mesmo tick.
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

**Decidido (§0.1): condição de vitória híbrida.** Percentual + 3 stocks, blast zones fixas no mundo
e recuperação disponível aos dois lutadores; a câmera não define morte. Além disso, um evento
ambiental forte (ex.: ser soterrado por colapso com percentual alto) pode causar KO. O KO ambiental
tem que ser anunciado e evitável como todo colapso (§4.3); limiar e regra exata se afinam no M2.
Comparar com vida + rounds na Fase 3 se o playtest mostrar fuga excessiva ou KOs confusos.

### 5.5 Contrato de combate antes de ampliar o elenco

- Ataques em dados: startup/active/recovery em ticks, hitboxes e hurtboxes, dano, impulso,
  hitstop, hitstun, cancelamentos, carimbo de cenário e evento de apresentação.
- Simulação e colisão não dependem do quadro visual da animação. Um ataque tem `attack_id` e
  conjunto de alvos já atingidos; multi-hit define intervalo explícito.
- Prototipar input buffer (4–6 ticks), coyote time (3–5 ticks), altura variável do pulo,
  recuperação aérea e influência direcional no lançamento. São hipóteses para playtest.
- Definir prioridade de agarrão, esquiva, invulnerabilidade, landing lag e tech em parede/chão.
  Nenhum combo infinito ou wall-splat repetido sem saída: testar limite e defesa possível.
- Hitstop congela os participantes previstos por contador de ticks; input continua sendo
  registrado. O relógio fixo e o número do tick não param. Anunciar se destruição local acompanha
  a pausa; evitar congelamento global repetido em partidas de quatro jogadores.

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
- **Buracos respeitam a grade e a paleta**: alinhar a máscara ao espaço da arte e trabalhar a
  borda por material. Células de 8 px ainda produzem recortes grossos; validar aparência em zoom.
- **A borda é arte autorada aplicada proceduralmente**: o shader pinta o anel de pixels junto à borda
  da máscara com a textura de borda quebrada do material. Sem isso, buraco procedural parece
  "recortado com tesoura".
- Gerar **peças pequenas e repetíveis** facilita revisão e reuso. Isso não garante consistência:
  encaixes, estados e continuidade temporal precisam passar pelos gates de §20.

---

## 7. Mapa e cidade

- **Slice inicial: 2 telas de largura e 2–3 pavimentos**, com rua e acesso curto ao subsolo.
  Distrito de 4–6 telas é expansão: provar reencontro e tamanho dos lutadores na câmera antes.
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
- Câmera lenta é inicialmente exclusiva de replay/KO encerrado. Durante combate, só adotar como
  regra explícita da simulação, com inputs e duração em ticks; nunca pelo `time_scale` cosmético.
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
| Consistência entre quadros de personagem | exige âncoras e limpeza temporal | **geometria estável**; rig, silhueta e pixels ainda exigem revisão | rig estável; deformações e troca de lado exigem revisão |
| Volume de animação de jogo de luta | custo alto por quadro; limitar repertório inicial | reaproveita rig/render, mas golpes e proporções exigem autoria | eficiente para alguns movimentos; poses extremas precisam substituições |
| Zoom dinâmico | difícil | exige shader (§9.3) | nativo |
| Detalhe do lutador na tela | pouco (≈40 px) | bom (≈64–96 px) | alto |

### 9.2 Decisão padrão: **B — hi-bit pixel art, 640×360 de base**

- 640×360 escala ×3 para 1080p e ×6 para 4K, sem sobra.
- **Personagens:** pipeline Dead Cells — modelo 3D com esqueleto, animado por keyframes, renderizado
  em tamanho pequeno **sem antialiasing**, com shader toon e snap na paleta; normal maps opcionais.
  Vantagem esperada: retiming e poses de impacto reutilizam o mesmo rig. O modelo pode nascer
  de concept por IA, malha gerada ou modelagem simples por scripts Blender. **Validar** a existência
  e qualidade do pipeline em `GeradorAssets`; uma malha gerada não equivale a personagem pronto.
  Exigir topologia deformável, pesos, mãos legíveis, UVs e teste de poses extremas.
  Normal maps por quadro são opcionais até demonstrar ganho real sobre iluminação simples.
  Retoque no Aseprite só nos quadros-chave de impacto.
- **Cenário, módulos, bordas, miolos, decalques e VFX:** pixel art 2D pelo pipeline do Gloamwick
  (gpt-image com âncora + limpeza + paleta + validação).
- **Validar antes de produzir (bake-off da Fase 0):** um personagem com 3 animações (idle, golpe
  forte, lançado/atravessando) e um módulo de parede em 3 estados + buraco procedural, feitos em
  **A e B** (C só se B falhar). Critérios: consistência entre quadros, leitura a 1× e com zoom, tempo
  por animação, custo de cota. Registrar o resultado em ADR. Se B falhar, cair para A com elenco de
  sprites menores, ou C.

### 9.3 Zoom com pixel art

- Comparar duas implementações na mesma gravação: viewport 640×360 com escala inteira e zoom
  restrito; ou apresentação em resolução de saída com filtro sharp bilinear e zoom fracionário.
  Nenhuma garante eliminar shimmer. Avaliar movimento lateral, diagonais, contornos de 1 px,
  rotação, zoom e detalhes finos em 720p, 1080p e 1440p. Registrar escolha em ADR. [R3]
- 640×360 é referência de composição; não confundir densidade da arte, unidades físicas,
  resolução interna e resolução da janela. Suavizar câmera pode competir com pixel snapping.
- **Regra de densidade**: um pixel de arte ocupa entre 2 e 6 pixels de tela em 1080p. O zoom da
  câmera fica dentro dessa faixa.
- Todos os assets na **mesma escala de pixel**. Nunca misturar sprites com resoluções diferentes.

### 9.4 Style bible (preencher na Fase 0, antes de gerar qualquer asset)

- Paleta mestra (~48 cores): **cidade dessaturada e de valor médio; lutadores saturados e com contorno
  de valor mais escuro**, para separar lutador de fundo sob qualquer destruição.
- Paleta por material que bate com §5.3 (vidro frio, madeira quente, tijolo vermelho, concreto cinza,
  metal azulado, núcleo indestrutível com marca própria).
- Escolher iluminação predominantemente pintada ou dinâmica no teste visual. Para normal maps,
  não pintar sombras direcionais incompatíveis no albedo; travar luz ambiente e luz principal.
- Alpha 0/255 em sprites sólidos de pixel art. Fumaça, glow, distorção e interfaces podem usar
  alpha gradual deliberado; separar perfis de validação.
- **Régua de escala** com lutador leve, médio e pesado, porta, andar, carro e módulo lado a lado.
- Nome em `snake_case` com prefixos: `chr_`, `mod_` (módulo), `brk_` (borda quebrada), `core_`
  (miolo), `dec_` (decalque), `rub_` (escombro), `fx_`, `bg_`, `ui_`, `prop_`.
- Tema visual da cidade: **decidido: retrofuturista** (§19.1); silhuetas fortes e
  letreiros originais coerentes com a direção aprovada.

### 9.5 Regras de geração com IA (consistência)

1. Uma peça por imagem, vista **estritamente lateral/ortográfica**, referência de identidade e
   escala. Preferir alpha nativo quando o gerador permitir. Magenta é fallback para recorte,
   com teste de contaminação nas bordas e sem apagar cores legítimas do asset.
2. **Módulos em canvas-padrão** (múltiplo de 32 px) e mesma borda de base.
3. Estado intacto aprovado vira âncora. Rachado e rompido saem **por edição da âncora** ("a mesma
   parede, agora com…"), nunca de prompt do zero.
4. Borda quebrada, miolo e decalques são **texturas repetíveis** (tileáveis) por material.
5. VFX em flipbook de 6–8 quadros, âncora central, sem fundo.
6. Toda saída passa por: limpeza → paleta → alpha conforme classe → pixels órfãos → canvas/pivô → JSON irmão
   → **validador automático** → inspeção a 1× → só então entra no jogo.
7. Guardar prompt, referências e imagem bruta de cada asset (rastreabilidade, como no Gloamwick).
8. Lotes planejados por cota; ComfyUI local pode reduzir custo por chamada, mas consome tempo,
   energia e VRAM. Verificar licença dos modelos e nós; medir capacidade real da GPU.

### 9.6 Legibilidade no caos

- Controlar **oclusão acumulada**, não só alpha de cada partícula: camadas de 0,3 também podem
  esconder o lutador. Usar máscara de proteção da silhueta, ordenação e contorno de emergência;
  avaliar em movimento e em escala de cinza, inclusive com os dois lutadores sobrepostos.
- Debris cosmético mais escuro e menos saturado que lutadores.
- Comparar contraste local da silhueta e área visível em capturas com máscaras; média de luminância
  da cena não prova legibilidade. Validar identificação dos lutadores por pessoas (§19).

### 9.7 Som

Gerador de áudio validado com teto por lote. Som de quebra em **camadas por material**: impacto + ruptura + cauda de
detritos, com variações e volume pela energia. Nomes semânticos (`brk_concreto_grande`); nome ausente
= fallback e aviso em desenvolvimento para conteúdo obrigatório.

---

## 10. Arquitetura de software

Duas metades que nunca se misturam:

**Simulação (determinística, dona da verdade, 60 Hz fixos, inteiros/ponto fixo onde importa)**
`InputBuffer` · `Fighter` (estado, física cinemática própria — não RigidBody) · `CombatSystem`
(hitbox/hurtbox, dano, knockback, hitstun) · `ImpactResolver` (§5.2) · `MatterGrid` (células, chunks,
carimbos) · `TerrainQuery` (varredura na grade autoritativa) · `StructuralGraph` (ilhas,
carga, falha anunciada) · `CollapseSystem` (queda cinemática) · `RubbleSim` (falling sand mínimo) ·
`MatchManager` · `SimRNG` · `Snapshot` (serializa o estado inteiro).

**Apresentação (cosmética, descartável, pode variar entre máquinas)**
`CollisionBuilder` (contornos derivados, fila cosmética) · `CameraDirector` · `FighterView` ·
`ModuleView` (shader de máscara + borda + miolo) · `DebrisFX`
(RigidBody2D em pool) · `VfxSpawner` · `AudioEvents` · `Hud` · `DebugOverlay`.

Regras:
- A simulação expõe `state()` e emite eventos; a apresentação só lê e escuta (padrão Gloamwick).
- **A simulação é uma função de (estado, inputs)**. Snapshot inclui terreno, ilhas, filas, RNG,
  IDs, timers e ataques ativos. Preparar esse limite ajuda replays, mas rollback tem custo real
  de memória, restauração, ressimulação e correção visual; medir antes de prometer online. [R4]
- Linguagem: GDScript para gameplay. Caminhos quentes (`MatterGrid`, `CollisionBuilder`,
  `RubbleSim`) podem ir para C#/GDExtension **se o profiling mandar**, não antes.
- Física do Godot só na apresentação neste desenho. Não presumir determinismo multiplataforma
  de engine/plugin; qualquer alternativa precisa provar o replay nas builds e plataformas alvo.
- Eventos usam `(tick, emitter_id, sequence, kind)`; apresentação deduplica efeitos ao ressimular.
  Snapshot ordena campos/coleções de forma canônica e leva versão de esquema e hash do conteúdo.

### 10.1 Orçamentos de performance (propostas para medir e ajustar)

- 60 fps estáveis em hardware-alvo com 4 lutadores (**hardware-alvo decidido**: a máquina
  de desenvolvimento com RTX 3060 Ti como teto e uma integrada como piso).
- Reconstrução de contornos cosméticos: ≤2 ms por frame, fila para excedente. Não adiar colisão real.
- Medir build exportada: frame time p50/p95/p99, CPU de simulação, GPU, memória, fila e pior pico.
  Meta inicial 60 fps (16,67 ms), simulação p95 ≤4 ms, preservando margem para ressimulação.
  Metas propostas, não resultados obtidos. Fixar CPU/GPU/RAM, resolução e renderer no relatório.
- Grafo estrutural: ≤1 ms total por tick como meta inicial, inclusive múltiplos eventos de explosão.
- Debris cosmético: ≤150 corpos ativos; o excedente vira partícula ou é descartado pelo mais antigo.
- Escombro: só chunks não assentados simulam.

---

## 11. Modos de jogo (ordem)

1. Duelo local 1v1, com gamepad e teclado desde o início.
2. Local 2–4 jogadores.
3. Bots simples (também usados em teste).
4. Online com rollback **só** depois de combate, destruição e determinismo estarem estáveis e com
   teste de replay passando. O online nunca bloqueia o protótipo.

---

## 12. Fases

**Fase 0 — Formalizar e demonstrar.** Briefing curto, decisões provisórias, riscos e style bible.
Bake-off de arte (§9.2) em cena de teste; não exigir aprovação de imagens isoladas como prova final.
Planejar a sequência de referência (§19) e iniciar harness mínimo de input/replay no primeiro spike.

**Fase 1 — Spike técnico de destruição em Godot (substitui a comparação aberta de engines).**
Em greybox: grade de matéria com carimbos, reconstrução de colisão por chunk, um grafo com uma ilha
que cai, escombro assentando, 150 debris cosmético. Medir custos. Passou nos orçamentos → Godot
confirmado em ADR. Falhou → localizar custo, simplificar algoritmo e reduzir trabalho derivado.
Só comparar engines se houver limitação demonstrada da engine, não de código ou escopo.

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

**Fase 8 — Completar arte e som da slice.** O padrão visual já deve existir numa sala desde as
Fases 0–4 (§19), evoluindo junto do greybox. Pipeline de §9 aplicado a 2 lutadores, 1 material
completo de cada classe, VFX e som por material.

**Fase 9 — Polimento e análise.** Profiling, bugs, legibilidade medida, câmera, controle de debris,
playtests repetidos.

**Fase 10 — Expansão só depois da slice validada.** Elenco, distritos, modos, online, progressão,
cosméticos, narrativa se fizer sentido.

---

## 13. Testes e ferramentas (harness no primeiro spike; expansão na Fase 2)

- `--autotest N --semente S`: bots lutam N segundos headless em 4 sementes fixas; falha em erro de
  script ou invariante quebrada.
- **Replay determinístico**: mesmos inputs e conteúdo → hash canônico por tick. Repetir com
  render a 30/60/144 fps e headless; relatório informa primeiro tick divergente e campos alterados.
  Teste adicional: salvar em T, avançar, restaurar T e ressimular; deve atingir o mesmo estado.
  Cobrir explosões simultâneas, limite de chunks, alta velocidade, ilha e escombro. Testar outras
  plataformas/builds antes de declarar determinismo multiplataforma.
- **Rollback offline** antes de rede: atrasos de input simulados, restauração e deduplicação de VFX.
  Medir memória de snapshots/deltas e custo de ressimular 8 ticks. Replay linear não prova isso.
- **Cena de estresse de destruição**: explode X% de um quarteirão e grava tempo de frame, corpos
  ativos e ms de reconstrução em CSV.
- **Navegabilidade** por conjunto de movimentos do lutador, não flood fill de células vazias:
  testar saltos, alturas, recuperação e reencontro em estados intermediários e após destruição.
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

Quando receber a tarefa de **iniciar a implementação**, faça uma inspeção breve e entregue um
plano executável; limite a primeira rodada de documentação ao necessário para construir e testar.
Os itens abaixo são tópicos do plano, não onze documentos nem motivo para adiar o protótipo:
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
11. Na mesma rodada, se implementação estiver autorizada, primeiro incremento executável com
    launcher, cena mínima, input e verificação. Evitar sessão inteira só de planejamento.

Use os marcos de §23 para decidir a próxima tarefa. Não instalar catálogos de skills, gerar lotes
pagos ou iniciar o jogo ao receber apenas pedido de revisão deste documento.

Antes de modificar um repositório existente: inspecione a estrutura, leia README e documentação,
identifique engine e versão, não sobrescreva trabalho sem necessidade, faça checkpoints pequenos e
descritivos.

Ao implementar, trabalhe incrementalmente e informe em cada etapa: objetivo, arquivos alterados,
comportamento esperado, como executar, como testar, limitações atuais e próxima tarefa recomendada.

O foco é provar a experiência central, não construir o jogo inteiro de uma vez.

---

## 19. Qualidade visual demonstrada dentro do jogo

### 19.1 Identidade para o primeiro teste

**Proposta autoral a validar:** metrópole retrofuturista de concreto, cerâmica e infraestrutura
exposta ao entardecer; superfícies frias, interiores quentes e acentos elétricos nos poderes.
Arquitetura com massas grandes e detalhes agrupados. O interior revelado pela destruição recebe
o mesmo cuidado da fachada. Evitar ruído visual uniforme em todas as superfícies.

O material conta a história do impacto: vidro abre rápido, alvenaria rasga em blocos, concreto
resiste e expõe ferragem. Cada lutador tem silhueta, distribuição de valores, postura e assinatura
de movimento próprias. Cor não é o único identificador de jogador ou de resistência.

Preparar três pranchas: composição de gameplay, régua de personagens/arquitetura e materiais
intactos/rompidos. Referências externas orientam qualidades; os assets devem ser originais.

### 19.2 Sequência jogável de referência — 20 a 30 segundos

Criar uma cena jogável e reproduzível por inputs gravados:

1. Dois lutadores se aproximam numa rua; identidades e chão são imediatamente legíveis.
2. Um golpe forte lança o adversário através de uma vitrine e de uma divisória.
3. A câmera acompanha sem perder o atacante; interior e trajetória continuam visíveis.
4. Um apoio destruído anuncia colapso. O defensor recupera controle e pode escapar.
5. A laje cai, abre uma rota e deposita escombro; a luta continua no cenário transformado.

Essa sequência define o padrão de acabamento. Capturar a mesma situação antes/depois das mudanças.
Vídeo gerado por IA ou montagem serve como conceito, nunca como prova de implementação.
Entregar câmera, personagem, cenário, áudio e VFX funcionando juntos, não apenas imagens bonitas.

### 19.3 Animação e impacto

- Animar pose a pose: preparação, contato, continuação e recuperação. Poses legíveis em silhueta;
  interpolação não pode amolecer contato nem antecipação.
- O render 3D serve à animação 2D: permitir exagero, alongamento, smear e troca de desenho nos
  momentos decisivos. Não aceitar movimento genérico apenas porque o rig funciona.
- Começar com 8–12 clips essenciais por lutador; documentar lacunas. Medir produção, correção e
  reexportação antes de multiplicar repertório e elenco.
- Sincronizar contato, ruptura, acento breve de luz, rastro e som pelo mesmo evento.
  Escalonar por energia/material, com teto de shake, partículas e vozes simultâneas.
- Hierarquia: lutadores e ameaças, terreno jogável, efeitos, ambiente. A informação necessária
  para defender e recuperar permanece visível no maior colapso.
- Áudio: contato + corpo da ruptura + cauda de detritos; limitar repetição, clipping e sobreposição.
  Música/ambiente podem baixar brevemente quando um evento importante exigir espaço.
- Opções separadas de tremor, flashes e intensidade dos efeitos, preservando as regras do combate.

O relato do artista de Dead Cells sustenta a escolha de render pequeno e iteração de poses/timing,
mas também registra limitações visuais. Não é promessa de acabamento automático. [R1]

### 19.4 Critérios de aprovação

Metas iniciais do projeto, a calibrar no primeiro teste humano:

| Dimensão | Evidência exigida |
|---|---|
| Identidade | volumes, roupa e proporções coerentes em idle, ataque, dano e troca de lado |
| Silhueta | 4 de 5 pessoas distinguem lutadores em imagem pequena e escala de cinza |
| Material | 4 de 5 pessoas antecipam qual de duas paredes rompe mais fácil |
| Ação | observadores identificam atacante, direção do lançamento e início do colapso |
| Movimento | sem pivô saltando, pés deslizando sem intenção ou detalhe piscando de forma distrativa |
| Composição | ambos localizáveis no zoom mínimo e durante o pior colapso |
| Integração | aprovação com HUD, áudio, câmera e destruição ativos |
| Custo | tempo até aprovação, rejeições e custo por clip/material aprovado |

Cinco pessoas são teste formativo, não validação estatística de mercado. Se humanos não estiverem
disponíveis, registrar esse gate pendente e continuar tarefas independentes. Não inventar playtest.
Revisão multimodal ajuda a localizar problemas; não substitui sensação de controle nem prova beleza.

---

## 20. Fábrica de assets consistente e reproduzível

### 20.1 Fluxo de produção

**Conceito → âncora aprovada → fonte editável → exportação → validação → cena de prova → promoção.**

IA propõe conceitos, texturas e áudio; agentes podem construir scripts, rigs simples, shaders e
importadores. O build usa arquivos aprovados/versionados. Não gerar conteúdo por API na partida.

Estados: candidate, review, approved, integrated e rejected, com motivo. Não substituir âncora
aprovada a cada tentativa. Variantes recebem versão; mudar a âncora exige revisar os derivados.

### 20.2 Manifest de asset

Cada asset tem JSON com os seguintes campos, obrigatórios conforme a classe:

| Grupo | Campos |
|---|---|
| Identidade | asset_id, revision, kind, status, style_version |
| Origem | source_file, provider, model_id, prompt_file, reference_ids |
| Reprodução | seed quando disponível, workflow_hash, tool_versions, export_preset |
| Integração | output_files, frame_size, visible_bounds, pivot, pixel_density, palette_id |
| Animação | clips, frame_indices, ticks_per_frame, trim_offsets |
| Validação | alpha_profile, validator_report, preview_files |
| Procedência | reference_origin, terms_checked_on, attribution quando aplicável |
| Aceitação | reviewer, decision, rejection_reason, accepted_output_hash |

Seed pode não existir e não garante reprodução entre versões. Guardar saída bruta, fonte editável,
preset e hash da saída aprovada. Canvas do sprite e tamanho visível do corpo são coisas diferentes.
O manifest não contém credenciais. Reexportar não pode deslocar pivô nem alterar timing do ataque.

### 20.3 Contrato por família

| Família | Fonte e automação | Gate específico |
|---|---|---|
| Lutador | concept + rig + ações Blender + render em lote | proporção, contato, pivô, ambos os lados |
| Módulo | âncora intacta + variantes editadas + máscara | encaixe, escala, espessura, miolo e estados |
| Fragmento | recorte/UV da textura original | material coerente, pool e nenhuma autoridade |
| VFX | flipbook revisado ou shader/partículas | centro, duração, alpha, overdraw e oclusão |
| HUD | layout e tipografia autorados; ícones aprovados | leitura em 720p e navegação por controle |
| Áudio | geração/edição + camadas e variações | clipping, silêncio inicial, duração e evento |

Aseprite oferece exportação em lote e metadados via CLI; preservar offsets ao recortar frames. [R5]
Blender por scripts/CLI é candidato operacional; conferir comandos na versão instalada.
MCP do editor é opcional, não pré-requisito para exportação reproduzível.

### 20.4 Gates automáticos e inspeção temporal

- Paleta conforme classe, canvas, alpha, padding, UV, frames faltantes e esquema de metadados.
- Baseline dos pés, pivô e acessórios nas poses críticas.
- Prévia nativa, ampliada, em fundo claro/escuro e na arena real.
- Loop e inspeção frame a frame: contato visual coincide com hitbox.
- Atlas e normal map, se usado, compartilham recortes/índices; conferir luz ao espelhar.
- Similaridade automática apenas sinaliza possível deriva: poses legítimas mudam bastante.
  Não reprovar sozinho por limiar genérico de embedding ou SSIM.
- Asset reproduzível pode ser reconstruído de fontes/presets ou restaurado da saída aprovada.

### 20.5 Custo e capacidade

Lote piloto: um lutador, uma animação, um módulo e um som. Medir custo por resultado aprovado,
incluindo rejeições, limpeza, rig e reexportação. Estimar a slice a partir disso.

Proposta: no máximo três ciclos por item antes de mudar fonte, simplificar desenho ou corrigir
manualmente. Congelar arte aprovada evita refinamento infinito. Medir capacidade real da GPU local.
Geradores de imagem, 3D e áudio são ferramentas especializadas; Astra e Opus coordenam e avaliam.
Não assumir que todas as modalidades ou cotas estejam disponíveis na mesma assinatura.

---

## 21. Produção com GPT-6 Astra e Claude Opus 5.5

Os nomes aparecem na documentação oficial consultada. Acesso na conta, IDs de API, ferramentas,
cotas e opções de raciocínio precisam ser conferidos no ambiente. Não trocar o modelo solicitado
silenciosamente nem inventar parâmetros de CLI. [R6][R7]

### 21.1 Organização inicial

**Decidido (§0.1), não ranking de capacidades:** Opus 5.5 implementa o primeiro incremento
(M0/M1); Astra faz revisão independente. Alternar implementador/revisor nos próximos módulos e escolher
a divisão pelo resultado observado: defeitos encontrados, retrabalho, tempo e custo.

Implementador recebe escopo e critérios. Revisor recebe patch, contrato, testes e capturas;
procura falhas concretas e fornece reprodução. Discordância se resolve pelo menor teste/cena
que discrimine as alternativas, não por rodadas intermináveis de opiniões.

Não é necessário manter dois agentes sempre ativos. Paralelizar só trabalho independente,
com arquivos separados e contrato estável. Um integrador compõe o resultado e atualiza o estado.

### 21.2 Pacote de tarefa para qualquer modelo

Usar este formulário curto:

> Objetivo observável:
> Estado atual e arquivos relevantes:
> Contrato público e invariantes:
> Arquivos permitidos para alteração:
> Fora do escopo:
> Referências visuais/técnicas:
> Critérios de aceite:
> Comando e cenário de prova:
> Orçamento de tempo/custo, se definido:
> Entrega: patch, evidências, limitações e próxima ação.

Fornecer contexto relevante, sem reenviar todo o histórico. Usar mais raciocínio em decisões
difíceis, diagnóstico e revisão crítica; medir se o ganho compensa. Não atribuir superioridade
em pixel art ou física deste jogo com base em benchmark genérico.

### 21.3 Memória compartilhada

- AGENTS.md: comandos reais, invariantes e links curtos.
- CLAUDE.md: entrada compatível com Claude Code, referenciando a mesma fonte de regras.
- Docs/estado.md: build/commit, última tarefa concluída, falhas, gate pendente e próxima ação.
- ADR para decisão estrutural; backlog para pequenos ajustes.
- Modelos, dependências e assets com versão ou origem rastreável.

Distinguir observado no arquivo, medido executando e hipótese.
Não declarar build jogável sem executar, imagem revisada sem abrir, placeholder como arte final
ou teste humano a partir de bot. Se faltar ferramenta, entregar a parte verificável e registrar o limite.

---

## 22. Skills e ferramentas selecionadas pelo resultado

Skill é procedimento reutilizável com instruções e, quando útil, scripts/referências.
Codex e Claude Code documentam esses mecanismos; conferir diretórios e campos na versão instalada.
Compatibilidade de formato não garante compatibilidade dos comandos internos. [R8][R9]

### 22.1 Capacidades e uso proposto

| Skill/capacidade | Aplicação | Limite |
|---|---|---|
| openai-docs | conferir modelos e configuração Codex | não prova acesso na conta |
| imagegen | conceitos, âncoras e edição raster | não garante atlas nem consistência temporal |
| skill-creator | empacotar um fluxo já testado | evitar dezenas de skills antes do primeiro uso |
| skill-installer | incorporar skill selecionada e inspecionada | não instalar catálogo inteiro por quantidade |
| Godot CLI + runner | importar, executar, reproduzir e exportar | headless não valida render nem sensação |
| Aseprite + Blender | retoque, rigs e exportação repetível | conferir instalação e versões |
| MCP de editor | inspecionar cena, logs e capturas | validar integração; CLI é fallback |

Nesta revisão foi usada OpenAI Docs. As demais são recomendações; não foram instaladas/executadas
por este documento e nenhum asset foi gerado.

### 22.2 Skills locais a criar depois de provar os fluxos

Estes nomes são **propostas**, não pacotes existentes:

| Skill proposta | Entrada | Saída verificável |
|---|---|---|
| fight-sim-regression | patch + fixtures + replay | hashes, primeira divergência e reprodução |
| fight-art-consistency | âncora + candidato + manifest | prévias e defeitos localizados |
| fight-blender-sprite-export | fonte + preset + clips | atlas/metadados e preview Godot |
| fight-destruction-review | material/mapa + impactos | casos de borda, rotas e perfil |
| fight-visual-review | capturas/vídeo padronizados | problemas de leitura, movimento e acabamento |
| fight-release-check | build e escopo do marco | execução, arquivos e limitações |

Cada uma define gatilho, entradas, passos, artefatos, critérios e falhas conhecidas.
Manter regras compartilhadas numa fonte; adaptar só a integração com o agente. Scripts entram
quando aumentam confiabilidade de um trabalho repetido.

### 22.3 Recursos comunitários pesquisados

- [vl4dt/godot-skills](https://github.com/vl4dt/godot-skills): README lista padrões GDScript,
  revisão, debugging, performance e fluxo headless. Candidatos para inspeção pontual.
- [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills):
  catálogo por engine/disciplina; não equivale a pipeline validado para este projeto.
- [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4): framework de testes, distinto de skill;
  escolher versão compatível e provar um teste headless. [R10]

Status: READMEs consultados; código, licenças por componente e execução não auditados.
Antes de adotar, ler a skill/scripts escolhidos, verificar APIs na engine fixada e registrar commit.
Evitar instruções que contrariem nossa simulação autoritativa. Avaliar em tarefa real, por erros
e retrabalho, não por número de skills. Não instalar integrações nesta revisão do prompt.

---

## 23. Marcos, gates e primeira entrega

As fases de §12 detalham a construção. Estes marcos governam a passagem e evitam produzir elenco
antes de provar combate, destruição e aparência. Prazo vem das medições do spike/lote piloto.

| Marco | Entrega executável | Evidência | Continuidade |
|---|---|---|---|
| M0 Ambiente | cena mínima e launcher | versão, importação e execução | inicialização repetível |
| M1 Sensação | placeholders, movimento e ataque | playtest curto e captura | controle e lançamento compreensíveis |
| M2 Destruição | vitrine, parede, ilha e escombro | replay/restore e perfil | sem tunneling, parede fantasma ou jogador preso |
| M3 Visual | sala/lutador, áudio e impacto integrados | sequência §19 e custo por asset | acabamento e leitura aceitos |
| M4 Slice | dois lutadores e quarteirão pequeno | sessões humanas e build exportada | critérios §17 e §19 |
| M5 Escala | conteúdo adicional ou prova de rollback | expansão/ressimulação medidas | cabe no orçamento |

M1 e o estudo visual podem evoluir junto do spike; M3 fecha com destruição integrada.
Dependência de humano fica explícita, sem parar trabalho técnico independente.

### 23.1 Primeira sessão de implementação

1. Inspecionar workspace e ferramentas; conferir paths herdados.
2. Registrar estado inicial e contrato mínimo de unidades, ticks e inputs.
3. Subir cena Godot com dois placeholders, chão e parede de um material.
4. Aplicar movimento, lançamento e ruptura por grade; registrar inputs.
5. Entregar launcher, captura real, resultados e próxima falha a resolver.

Se não couber na sessão, concluir incremento executável menor e relatar exatamente o que existe.
Não começar por menus extensos, lore, monetização ou elenco grande.

### 23.2 Cortes de escopo

Cortar distritos extras, clips secundários, variedade de props, VFX redundantes, rotação de ilhas
e carga estrutural sofisticada. Preservar controle, identidade visual, ruptura que altera rota,
um colapso legível e escombro jogável. Falling sand pode ser simplificado conforme §4.4.

### 23.3 Sucesso da produção com IA

Cada rodada torna o jogo mais executável, legível, consistente ou mensuravelmente melhor.
Poucos arquivos podem resolver o principal risco. A meta é qualidade no build jogável,
não volume de código, agentes, assets ou documentação.

---

## Apêndice — Fontes e limites de evidência

Consulta: 23/09/2026. As soluções descritas são propostas para este projeto, salvo atribuição
expressa. Documentação stable/latest pode mudar; fixar a versão correspondente ao implementar.

- **[R1] Dead Cells — relato do artista Thomas Vasseur.** Rig 3D, poses, sprites/normal maps e limites:
  https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-
- **[R2] Noita — GDC, Exploring the Tech and Design of Noita.** Página da palestra consultada,
  não auditoria do vídeo integral. Não fixa tamanho de chunks nem comprova nossa arquitetura:
  https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design
- **[R3] Godot — múltiplas resoluções.** Viewport e escala inteira/fracionária:
  https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- **[R4] GGPO.** Referência de rollback, não plugin Godot já integrado:
  https://www.ggpo.net/
- **[R5] Aseprite — CLI oficial.**
  https://www.aseprite.org/docs/cli/
- **[R6] OpenAI — guia oficial de modelos, incluindo GPT-6 Astra.**
  https://developers.openai.com/api/docs/guides/latest-model
- **[R7] Anthropic — página oficial identificando Claude Opus 5.5 na consulta.**
  https://www.anthropic.com/claude/opus
- **[R8] OpenAI — estrutura e criação de skills.**
  https://learn.chatgpt.com/docs/build-skills
- **[R9] Anthropic — skills no Claude Code.**
  https://code.claude.com/docs/en/skills
- **[R10] gdUnit4 — repositório do projeto.**
  https://github.com/godot-gdunit-labs/gdUnit4
- **[R11] Godot — interpolação de física.** Não prova determinismo por si só:
  https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html

**Evidência local:** READMEs de Gloamwick Last Vigil/GodotGame e Gloamwick Last Vigil/AssetPipeline;
existência do diretório Godot citado em §3. Não executamos engine, geradores, build ou playtest
nesta revisão. Os demais relatos anteriores são histórico a conferir, não nova auditoria.

Os links herdados permanecem na versão 2 preservada. Wikis, repositórios de fratura e fórmulas
não verificados não sustentam decisões obrigatórias. Consultas às páginas de Blender e ComfyUI
falharam; isso não foi tratado como confirmação de versões ou integrações.
