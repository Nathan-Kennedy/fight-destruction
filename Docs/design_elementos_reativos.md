# Elementos reativos do cenário (pedido do dono, 24/09/2026)

> "Canos ou coisas que quando você quebra sai água, canos que sai ar, coisas que sai fogo ou explode,
> em objetos interagíveis ou até no cenário, porque dão mais intensidade na destruição. Por exemplo,
> as luzes que quando acesas fazem um efeito de iluminação e quando o jogador interage ela quebra, ou
> então entorta e muda a direção da luz."

Referências de qualidade: canos e extintores que estouram em jogos de ação, barris explosivos,
postes que entortam, letreiros que dão curto. O objetivo é **intensidade e leitura**: o jogador vê
o elemento antes, entende o que vai acontecer e pode usar a seu favor (pilar F: previsível).

## 1. Onde vivem

- **Fixos do cenário (`fixtures`)**: presos a células da grade (cano na parede, poste na calçada,
  luminária no teto, transformador, hidrante, letreiro neon, fiação). Reagem quando **as células
  em que estão presos são destruídas** ou quando **uma hitbox/corpo lançado/objeto os atinge**.
- **Objetos móveis (`props`)**: variantes interagíveis que já podem ser agarradas/arremessadas:
  botijão de gás (explode), extintor (jato de pó que empurra), barril de óleo (pega fogo).

## 2. Tipos e efeitos

| Tipo | Estados | Efeito na simulação (determinístico) | Efeito visual |
|---|---|---|---|
| Cano de água | intacto → vazando (N s) → seco | jato empurra levemente quem está no jato; apaga fogo no alcance | jato d'água com gotas, poça que brilha, respingos em quem passa |
| Cano de gás/vapor | intacto → jato (N s) → vazio | **jato empurra forte** (recurso de recuperação e de combo); vapor quente causa dano leve | jato branco com distorção de calor, assobio |
| Cano de gás inflamável | intacto → vazando → **pega fogo** se houver faísca/fogo perto | vira jato de fogo: dano e hitstun leve em contato | chama com núcleo claro, fumaça, luz laranja tremendo |
| Botijão / tanque | intacto → danificado (chiando, aviso) → **explode** | explosão radial: rompe células no raio, lança lutadores e objetos (mesma regra da explosão especial), pode encadear | flash, anel, fogo, fumaça, impact frame |
| Transformador / caixa elétrica | intacto → faiscando → curto | área de choque intermitente (hitstun curto) por alguns segundos; acende fogo em gás | faíscas azuis, arco elétrico, luzes da rua piscam |
| Fiação solta | pendurada → balançando com faíscas | toque causa choque leve | cabo balançando, faíscas |
| Hidrante | intacto → jorrando | jato vertical empurra para cima quem está em cima (vira "mola") | coluna d'água, névoa, arco-íris leve no pôr do sol |
| Poste / luminária de rua | aceso → **entortado** (luz muda de direção conforme o golpe) → quebrado (apaga, faísca) | só estado (ângulo e aceso/apagado) no snapshot; sem efeito de gameplay | luz 2D real (cone), sombra, poeira no feixe; ao entortar o cone gira; ao quebrar, pisca e apaga com faíscas |
| Luminária interna | acesa → balançando → quebrada | idem | cone balançando (pêndulo), vidro caindo |
| Letreiro neon | aceso → falhando → apagado | — | pisca, dá curto, cai uma letra (abstrata) |
| Extintor (prop) | intacto → disparando | arremessado/golpeado dispara jato que empurra e deixa nuvem | nuvem branca que cobre a visão parcialmente (sem esconder lutador) |

Regras gerais:
- **Aviso antes de perigo** (como o colapso): botijão chia e pisca antes de explodir; gás vaza e
  faz barulho antes de pegar fogo. Janela de reação de 0,5–1,5 s.
- **Cadeias limitadas**: explosão pode acionar outro elemento, mas com limite por tick e por partida
  para não travar nem virar caos ilegível.
- **Nada disso mata sozinho sem aviso.** Dano e knockback moderados; KO só por lançamento normal.
- Tudo que afeta gameplay entra no hash e no snapshot; o resto (luz, gotas, fumaça) é apresentação.

## 3. Iluminação

- O entardecer ganha luz 2D: `CanvasModulate` leve para o ambiente e `PointLight2D`/cone para
  postes, luminárias, neon, fogo e explosões. Interiores acesos iluminam para fora quando a fachada
  abre.
- Poste entortado: o ângulo vem da direção do golpe/corpo que o atingiu (inteiro no estado).
- Opção de desempenho: desligar sombras e reduzir luzes em GPU fraca (§10.1).

## 4. Onde colocar no distrito de teste

Poste na calçada da esquerda e da direita, hidrante na rua, cano de água na parede dos fundos, cano de
vapor na sobreloja, botijão na loja, transformador na parede externa, luminárias pendentes na loja e no
escritório, letreiro neon na marquise, fiação entre prédio e poste.

## 5. Arte necessária (entra na próxima geração, com as regras de qualidade da §8.3 dos prompts)

`fix_poste` (aceso, entortado, quebrado), `fix_luminaria`, `fix_cano_agua`, `fix_cano_vapor`,
`fix_cano_gas`, `fix_transformador`, `fix_hidrante`, `fix_letreiro_neon`, `prop_botijao`,
`prop_extintor`; flipbooks `fx_jato_agua`, `fx_jato_vapor`, `fx_fogo`, `fx_explosao_gas`,
`fx_faisca_eletrica`, `fx_poca`. Até lá, placeholders procedurais.
