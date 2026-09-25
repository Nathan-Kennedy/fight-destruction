# Visão do dono — o que vai fazer mais diferença (registrado em 24/09/2026)

Texto do dono, na íntegra:

> Sei que o GPT ainda não terminou de fazer as imagens e nem mesmo terminamos todo o processo do jogo,
> mas já quero deixar anotado o que eu sinto que vai fazer muita diferença implementar agora além das
> animações/sprites. Os cenários dá pra melhorar muito, creio que com aquela adição do Blender na
> modelagem vai dar pra criar algo bem "3D" dentro do 2D que vai ficar bem charmoso, inclusive usando
> referências criadas pelas imagens do GPT e mandando a IA fazer pelo Blender fica completo. Sobre os
> combos, eu quero que deixe mais complexa a sequência de golpes, assim como temos no Dragon Ball
> FighterZ e no Sparking Zero ou até mesmo Street Fighter; acho que dá pra melhorar muito. Sobre
> personagem, quero que foque em criar um personagem estilo Superman/Invencível que voe, tenha super
> força, ou seja, os golpes dele têm bem mais impacto; dependendo pode jogar pra muito longe, golpes que
> seguram o adversário e arrastam junto do golpe até uma direção, golpes estilo Mortal Kombat que têm uma
> animação muito louca; tudo dá pra gente tentar criar pra parecer que estamos vendo uma cena de luta da
> DC ou da Marvel.

Status: **visão registrada; nada disso implementado ainda.** Ordem a combinar com o dono. As obras
citadas são referência de sensação; o personagem e os golpes serão originais (§19.1).

## 1. Cenário "3D dentro do 2D" com Blender

- Montar o quarteirão (fachadas, interiores, móveis, postes, carros) como cena Blender modelada por IA
  via scripts Python, usando as imagens do GPT como referência de cor, forma e clima.
- Renderizar em **camadas de profundidade** (fundo, meio, piso, frente — §8.6 dos prompts) com câmera
  ortográfica ou levemente perspectiva, shader toon e contorno, + passes de normal/profundidade para a
  luz 2D do jogo. Resultado: parallax com volume real, charme de diorama.
- Módulos destrutíveis também podem sair do Blender em estados (intacto/rachado/rompido) e em pedaços
  pré-fraturados para a queda cosmética.
- Plano de teste e critério: [arte/opcao_blender.md](arte/opcao_blender.md).

## 2. Combos mais profundos (FighterZ, Sparking Zero, Street Fighter)

O que existe hoje: leve, forte (lado/cima/baixo/ar), agarrão com 4 arremessos, explosão, escudo e esquivas,
buffer de 5 ticks. O que falta para sequências de verdade:
- **Cadeias (chains):** leve → leve → médio → forte, com janelas de cancelamento definidas por tick
  (hit-confirm), como o auto-combo e as target combos.
- **Lançador + combo aéreo:** golpe que lança para cima, perseguição (super dash/teleporte estilo FighterZ
  e Sparking Zero) e sequência no ar com finalizador (spike, wall bounce, ground bounce).
- **Cancelamentos:** golpe normal → especial → super; custo em uma **barra de energia** que enche batendo
  e apanhando.
- **Especiais por comando** (quarto de círculo, carga) para quem quiser técnica, com atalho simples
  (botão + direção) para acessibilidade.
- **Wall splat/ground bounce como parte do combo:** o sistema de energia contra o cenário já existe; o
  combo aproveita (jogar contra a parede, ela racha, segundo golpe atravessa).
- **Proteções de sistema (§5.5):** escalonamento de dano no combo, gravidade crescente por hit, limite de
  combos infinitos, burst/escape defensivo com custo.
- Ferramentas: modo treino com contador de combo, dano, frame data e replay de input.

## 3. Personagem-âncora: herói voador de super força (original, na linha Superman/Invencível)

- **Voo:** estado de voo com aceleração e inércia (entra com pulo duplo segurado ou especial), controle
  em 8 direções, com limite (barra de voo ou tempo) para não quebrar o neutro.
- **Super força:** knockback e energia contra o cenário muito acima dos outros; um golpe carregado atravessa
  vários prédios (a regra de ruptura em cadeia já existe; ele ganha multiplicador e mais `MAX_BREAKS`).
- **Golpes de arrasto (grab-drag):** agarra e **carrega o oponente junto** numa direção — voando pela
  rua, arrastando pela parede, subindo e cravando no chão — com o corpo do oponente rompendo tudo no
  caminho (dano ao cenário e ao alvo a cada ruptura), estilo Invencível.
- **Golpe-cena (estilo Mortal Kombat / Krushing Blow / super cinematográfico):** um especial de barra
  cheia que, ao conectar, entra numa sequência encenada: câmera própria, cortes, close no impacto,
  zoom e câmera lenta de apresentação, lançamento através de vários andares, e retorno ao jogo com o
  resultado aplicado na simulação. A simulação continua determinística: a cena é uma sequência roteirizada
  de estados/ticks com resultado fixo (posição final, dano, cenário destruído) e a apresentação só encena.
- **Leitura:** golpes dele "pesam" mais (hitstop maior, impact frame, onda de choque, poeira), para
  parecer luta de filme DC/Marvel.

## 3b. Lançamentos longos e perseguição (acréscimo do dono, 24/09 noite)

> "Nos golpes pode adicionar para ele ter golpes que façam o personagem quase que voar para muito longe e
> também perseguir para muito longe, já que mais para frente, com personagens super rápidos ou com
> habilidades especiais de transporte ou telecinese, isso fica mais dinâmico também, além de no futuro
> ter gigantes."

- **Golpes de longo alcance:** lançamentos que mandam o oponente muito longe (vários quarteirões), com a
  câmera acompanhando o voo e o cenário sendo rompido no caminho — sem virar KO automático: o alvo
  recupera controle no ar ou ao parar numa parede.
- **Perseguição:** o atacante pode ir atrás a alta velocidade (dash de perseguição/voo) e continuar o
  combo no destino, como a perseguição de FighterZ e Sparking Zero, só que atravessando a cidade.
- **Consequência de design:** o mapa precisa comportar distâncias grandes. Opções a avaliar: mapa largo
  com vários quarteirões e streaming de trechos; câmera que acompanha o voo e depois reenquadra os dois;
  blast zones que se afastam na perseguição, ou regra de KO por distância só no fim do combo.
- **Base para o elenco futuro:** o sistema de perseguição/deslocamento deve ser genérico para servir a
  personagens super-rápidos (corrida pela cidade), de **transporte** (teleporte, portais) e de
  **telecinese** (mover o oponente, objetos e pedaços do cenário à distância).
- **Gigantes (futuro):** lutadores de escala muito maior (estilo War of the Monsters). Implicações:
  colisão e hitbox em outra escala, destruição por contato ao andar, câmera que abre bem mais, regras de
  equilíbrio contra lutadores de tamanho normal e desempenho da grade com áreas de impacto grandes.
- **Equilíbrio gigante × pequeno (decisão do dono):** a grande desvantagem do gigante é a **lentidão dos
  golpes**. Ele é mais forte e mais resistente, mas o golpe precisa acertar primeiro: startup e recovery
  longos, telegrafia bem visível (anticipação, sombra/área de impacto no chão), deslocamento pesado. O
  pequeno vence pela velocidade: entra e sai entre os golpes, pune o recovery, usa o cenário para se
  esconder e fazer o gigante destruir o próprio apoio. Alvo de design: o gigante ganha quem ele acerta,
  o pequeno ganha quem não é acertado.

## 3c. Queda no chão, levantada e golpes-surpresa (acréscimo do dono, 24/09 noite)

> "Quando o boneco cai no chão seria interessante deixar ele imortal por alguns segundos caso ele já esteja
> bem cansado; daí ele pode ter a chance de levantar para não ser acertado por combos infinitos. E pode até
> ter um personagem que consiga usar isso a seu favor: quando no chão nesse estado, ele pode agarrar o
> personagem adversário para dar um golpe especial surpresa. Acho muito legal golpes especiais surpresas e
> até mesmo animações de bonecos bem fluidas, como no jogo Marvel Tōkon e Guilty Gear."

- **Knockdown com proteção:** ao cair no chão (knockdown), invulnerabilidade por um tempo que **cresce com o
  cansaço** (tamanho do combo sofrido, dano recebido em sequência, percentual alto). Levantada com opções:
  levantar no lugar, rolar para um lado, levantar atacando (com risco). Isto é a peça que falta contra
  combos infinitos (§5.5), junto do escalonamento de dano do combo.
- **Personagem que usa o chão a favor:** durante a proteção de knockdown, um comando de **agarrão no chão**
  (pegar o pé/perna de quem está perto) que abre um especial-surpresa. Precisa de contra-jogo: não pode
  ser invulnerável E sem risco ao mesmo tempo (ex.: só na janela final da levantada, com recuperação longa
  se errar, e visível para quem conhece o personagem).
- **Especiais-surpresa** em geral: golpes com entrada inesperada (counter, reversão, agarrão escondido) que
  viram uma sequência encenada; se encaixam no sistema de golpe-cena da §3.
- **Animação fluida de referência:** Marvel Tōkon: Fighting Souls e Guilty Gear (Arc System Works) —
  poses-chave fortes com poucos quadros intermediários segurados (animação "limitada" de anime), smear
  frames, câmera acompanhando o golpe, silhueta sempre legível. Ver também `art/third_party/REFERENCIAS_VFX.md`
  (Xrd/FighterZ: sem interpolação entre poses, ~15 fps de animação num jogo a 60).

## 3d. Estudar composição e cenários de Guilty Gear (a fazer)

O dono acha que a pegada de Guilty Gear combina com o nosso jogo. Estudo a fazer (referência de qualidade,
sem copiar): Guilty Gear Xrd e Strive — cenários 3D renderizados como ilustração 2D, composição em planos
(primeiro plano, plano de luta, fundo vivo), paleta por estágio, uso de luz e cor para separar lutador e
fundo, câmera dinâmica nos supers, transição de estágio com Wall Break (o mais próximo da nossa destruição),
e o pipeline 2D-em-3D da Arc System Works (palestras GDC de Junya Motomura sobre Xrd). Entregar um
documento de estudo em `Docs/arte/estudo_guilty_gear.md` com capturas de referência citadas (não baixar
assets do jogo) e o que aplicar no nosso cenário v2 e no pipeline Blender.

## 4. Implicações técnicas (para planejar)

- Voo, arrasto e golpe-cena mexem na simulação (novos estados, hash e replay); precisam de testes de
  determinismo e de "não prender o outro jogador sem saída" (§5.5).
- Golpe-cena precisa de sistema de **cutscene determinística**: roteiro por ticks + câmera/vfx dedicados
  + opção de pular/encurtar para partidas rápidas.
- Combos exigem dados de golpe mais ricos (cancel windows, hit-confirm, scaling) e um modo treino.
- Arte: o herói é o primeiro candidato forte para o pipeline Blender (rig reaproveitável para voo,
  arrasto e poses extremas), com as imagens do GPT como referência de design.
