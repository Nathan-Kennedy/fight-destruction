# Validação do lote 01 — conceitos

Imagens em `art/concept/lote01/` (PNG + JSON). Prompts em [prompts_arte_lote01.md](prompts_arte_lote01.md).
Todas estão como **candidate**. Quem aprova é o dono do projeto: preencher a coluna "Decisão" com
`aprovado`, `refazer` (dizer o quê) ou `rejeitado`. A triagem abaixo é do Opus, que abriu cada
imagem; ela aponta problemas, não aprova.

**Ordem sugerida:** comece por `ui_tela_gameplay_hud`, a referência-mestra. As outras se julgam
contra ela.

| # | Arquivo | Triagem do Opus | Decisão |
|---|---|---|---|
| 1 | `ui_tela_gameplay_hud` | **Melhor do lote.** Cutaway do prédio com interiores, rastro de vidro, divisória e tijolo rompidos, laje com rachadura laranja de aviso, pilha de escombro, caixa e máquina de venda como objetos, P1/P2 flutuando, HUD com retrato, %, stocks e recarga. Bloco e Faísca consistentes com a régua. Ressalvas: arte ilustrada, não pixel art de 640×360; a máquina tem letras soltas ("ZZZ"). | |
| 2 | `ui_prancha_hud` | Estados de % (branco→amarelo→laranja→vermelho), stocks cheios e perdidos, anel de recarga, barra de escudo, P1/P2, GO!/GAME!, pausa. Brilhante no estilo pedido. **Problema:** o retrato é um garoto genérico de faixa vermelha, que não é nenhum dos nossos três e lembra um personagem de luta conhecido. Refazer os retratos com Faísca/Brasa/Bloco. | |
| 3 | `bg_prancha_composicao` | Composição muito bonita (monotrilho, letreiros, loja iluminada, vitrine explodindo, laje rachando). **Problema:** os dois lutadores são personagens aleatórios (menina rosa, rapaz azul), não os nossos. Vale como alvo de clima e cenário, não de personagem. | |
| 4 | `chr_regua_elenco` | Régua boa: silhuetas bem distintas (magro, em V, quadrado), porta e andar para escala. **Diverge dos conceitos individuais:** a Faísca aparece como rapaz de cabelo branco e a Brasa como mulher. Decidir qual versão vale para cada um. | |
| 5 | `chr_faisca_conceito` | Poses de corrida e soco com raios ciano excelentes, cachecol legível. Aqui a Faísca é mulher de cabelo preto, diferente da régua (#4) e da tela (#1). | |
| 6 | `chr_brasa_conceito` | Manoplas, faixa e agarrão com arremesso muito claros; boa identidade laranja/grafite. Consistente com a régua (#4). Tem painéis extras de detalhe (rosto, luva, costas), o que é útil. | |
| 7 | `chr_bloco_conceito` | Forte: exoesqueleto, pisada e **explosão radial com anel âmbar**, que casa com o golpe novo do jogo. Silhueta quadrada ótima. Consistente com a régua e com a tela. | |
| 8 | `mod_prancha_materiais` | Muito útil: vidro, divisória, tijolo, concreto com ferragem e núcleo com faixa, nos 3 estados, mais a pilha de escombro. Pixel art de verdade. É o mais próximo de virar âncora de módulo (§9.5). Ressalva: tem uma personagem extra no canto. | |
| 9 | `fx_prancha_impacto` | Faísca leve, estrela de impacto forte, bolha de escudo, escudo quebrando, anel de explosão, poeira, rachadura de aviso e estilhaço de vidro. Legíveis e brilhantes. O fundo de castelo fugiu do tema metropolitano (irrelevante para os efeitos). | |
| 10 | `bg_skyline_nova_aurora` | Excelente: torre-anel como marco da cidade, monotrilho, caixas d'água, neon abstrato, entardecer violeta-pêssego. Candidato forte a fundo. | |
| 11 | `chr_brasa_teste_sprite` | Primeiro teste de sprite em pixel art: leitura boa em idle, soco e lançamento. **Fora do pedido:** bem maior que 50 px, com mais de 16 cores e borda com antialiasing. Serve para comparar direção, não como sprite. | |

## Decisões que só o dono pode tomar

1. **Gênero e visual da Faísca e da Brasa.** As imagens discordam. Opções: Faísca rapaz de cabelo
   branco (régua e tela) ou mulher de cabelo preto (conceito); Brasa mulher (régua e conceito).
2. **Acabamento final.** A tela de gameplay (#1) é ilustração HD cel-shaded. O briefing decidiu
   pixel art hi-bit (§9.2), e o #8 mostra como ficaria. Se a tela #1 for o alvo, é preciso rever a
   decisão B do §9.2 (a opção C, HD com recorte, tem outro custo de animação).

## Próximo lote (depois das decisões)

- Folhas de referência (turnaround) dos três lutadores com a identidade escolhida, fixando rosto,
  cabelo e roupa, para usar como âncora em todas as imagens seguintes.
- Retratos do HUD com os nossos lutadores.
- Bake-off A/B de sprite (§9.2) no tamanho certo, com paleta travada.
