# Pacote de tarefa M2: estrutura, colapso e escombro (§4.2–§4.4)

> **Objetivo observável:** quando o jogador destrói o apoio de um trecho do prédio (pilar,
> parede portante), esse trecho racha (aviso), cai como bloco e vira entulho que assenta em pilha
> jogável. Tudo determinístico e inteiro.

**Estado atual e arquivos relevantes:** ler `AGENTS.md`, `Docs/contrato_sim.md`,
`game/sim/sim_const.gd`, `game/sim/matter_grid.gd`. Hoje, o que perde apoio fica flutuando.
Já existem (não mudar): `C.M_RUBBLE = 6` (entulho) com HP/absorção/restituição nas tabelas;
`grid.struct_dirty` (fica true quando alguma célula é destruída ou escrita); `grid.set_cell(i, m, hp)`.
O prédio de teste está em `matter_grid.build_test_district()` (ver coordenadas nos comentários).

**Contrato público e invariantes:**
- `game/sim/` só inteiros, sem nós, sem física do Godot, sem RNG, sem tempo real. Ordem estável.
- Scripts por `preload`, sem `class_name`.
- Criar `game/sim/structure.gd` (`extends RefCounted`) com esta API (o integrador depende dela):
  ```
  var islands: Array        # ilhas em aviso ou caindo, ordem por id
  func setup(grid) -> void
  func step(grid, blocked: Array) -> Array
      # Um tick. `blocked` = retângulos [l, t, r, b] em subpixels (corpos dos lutadores) onde
      # entulho não pode entrar. Retorna eventos (Dictionaries com "kind" e dados), sem tick/seq:
      #   {"kind": "collapse_warn", "island": id, "cells": PackedInt32Array}
      #   {"kind": "collapse_fall", "island": id}
      #   {"kind": "break", "island": id, "cells": PackedInt32Array, "mats": PackedByteArray,
      #    "axis": 1, "dir": 1, "e": E, "r": R}               # ilha caindo rompe o que está embaixo
      #   {"kind": "collapse_land", "island": id, "cells": PackedInt32Array, "e": E}  # virou entulho
  func island_overlaps(island: Dictionary, l: int, t: int, r: int, b: int) -> bool
      # true se alguma célula da ilha (na posição atual, com o deslocamento de queda) toca o retângulo
  func cells_of(island: Dictionary) -> Array   # para a apresentação: [[x_sub, y_sub, mat], ...]
  func hash_ints() -> PackedInt64Array         # todo o estado que afeta o futuro, ordem fixa
  func snapshot() -> Dictionary
  func restore(s: Dictionary) -> void
  ```
  Cada ilha é um Dictionary com pelo menos `id`, `state` (0 aviso, 1 caindo), `t` (ticks no estado),
  `vy` (sub/tick), `dy` (deslocamento em subpixels desde a posição original), `cells`
  (índices originais na grade), `mats`, `hp`, `breaks`, `mass`, `hit_mask` (bitmask de lutadores
  já atingidos; o integrador lê e escreve este campo).
- Regras (decididas; constantes de ajuste ficam no topo de `structure.gd`):
  1. **Só roda quando algo muda** (`grid.struct_dirty`); o passo zera a flag após a análise.
  2. Âncoras: `M_CORE`. Estruturais: `M_BRICK`, `M_CONCRETE`. Folhas: `M_GLASS`, `M_DRYWALL`
     (ficam apoiadas se encostarem, direto ou por outras folhas, numa célula apoiada; nunca
     transmitem apoio a estruturais). Entulho não participa do grafo: é tratado pela areia.
  3. **Vão máximo**: célula estrutural precisa de caminho até âncora (4-vizinhança) em que a
     soma de passos horizontais seja ≤ `SPAN` (proposta 40 células). Passos verticais custam 0
     (BFS 0-1 com deque, desempate por índice). Isso cria pontos de tensão: no prédio de teste,
     quebrar o pilar (x 88–89) deixa a parte dianteira da laje e da sobreloja longe demais da parede
     dos fundos (x 102–103), e ela cai; quebrar a divisória (drywall) não derruba nada.
  4. Células não apoiadas e ainda não marcadas → componentes conexos (4-viz.), um por ilha,
     ordenados pelo menor índice. Estado aviso por `WARN_TICKS` (proposta 50). Células de uma ilha
     em aviso continuam sólidas e podem ser destruídas nesse tempo (a ilha perde essas células).
  5. Ao fim do aviso: células vivas saem da grade estática (`set_cell(i, M_EMPTY, 0)`) e a ilha
     cai por translação vertical pura: `vy += GRAVITY` com teto, sub-passos ≤ meia célula.
     Contato = alguma célula da ilha passaria a ocupar célula sólida da grade.
     Energia da ilha `E = mass·vy²/(2·SUB²)` com `mass = n_células · CELL_MASS`. Na linha de contato
     (células sólidas imediatamente abaixo), `R = soma do hp`; se não houver núcleo, `vy ≥ MAT_MIN_V`
     do mais duro e `E ≥ R` e `breaks < MAX_BREAKS` → destrói as células, reduz `vy` por
     `√((E−R)(1−absorção)/E)` (mesma fórmula de match_sim `_impact`) e continua. Senão assenta.
  6. Assentar: alinhar à célula, escrever cada célula da ilha como `M_RUBBLE` (hp cheio de entulho)
     na posição final; se a posição final estiver ocupada, subir até a primeira livre na mesma
     coluna (determinístico). Limite `RUBBLE_MAX` células de entulho no mapa: excesso vira poeira
     (não é escrito; contar no evento).
  7. **Areia mínima**: entulho com vazio embaixo cai uma célula a cada `SAND_EVERY` ticks
     (proposta 2); senão tenta diagonal baixo-esquerda/baixo-direita, lado alternando por paridade
     do tick; ordem de atualização de baixo para cima, esquerda para direita. Manter um conjunto de
     entulhos ativos; ao `struct_dirty`, reativar os que ficaram sem apoio. Entulho não entra em
     célula que toque `blocked` (não enterra lutador). Entulho não é afetado pelo vão.
- Tudo que afeta o futuro entra em `hash_ints()` e `snapshot()`: ilhas, marcas, entulho ativo, próximo id.

**Arquivos permitidos para alteração:** criar `game/sim/structure.gd` e `game/tests/structure_tests.gd`.
Não editar nenhum outro arquivo (outro agente está editando `match_sim.gd`, `main.gd`, as views e
`props.gd`). Se precisar de algo em `matter_grid.gd` ou `sim_const.gd`, descrever na entrega.

**Fora do escopo:** lutadores (dano/KO por colapso é do integrador), apresentação, props, rotação
de ilhas, carga distribuída.

**Critérios de aceite (testes em `structure_tests.gd`, `static func run_all() -> int` que imprime
`ok`/`FALHA` por teste como `sim_tests.gd` e devolve o número de falhas):**
1. Distrito intacto: nenhum aviso em 300 ticks.
2. Destruir a divisória (x 74–75, y 36–51): nenhuma ilha.
3. Destruir o pilar (x 88–89, y 36–51): surge ilha em aviso; após o aviso ela cai; ao final
   não há célula flutuante (toda célula não-entulho apoiada; todo entulho em repouso) e existe
   entulho na rua/térreo.
4. Destruir pilar e parede dos fundos: sobreloja inteira cai.
5. Ilha caindo sobre vidro rompe o vidro; sobre núcleo nunca passa.
6. `blocked` impede o entulho de ocupar o retângulo.
7. Determinismo: mesma sequência duas vezes → mesmo `hash_ints`; snapshot no meio da queda +
   restore + mesmos ticks → mesmo hash.
8. Custo: pior `step` com BFS completo medido e impresso (orçamento: bem abaixo de 1 ms).

**Comando e cenário de prova:**
`C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/run_suite.gd -- --suite structure`
(código de saída 0 = passou). Esse runner não carrega `match_sim.gd`, então não depende do outro agente.

**Entrega:** arquivos criados, saída dos testes, custo medido, limitações e o que o integrador precisa saber.
