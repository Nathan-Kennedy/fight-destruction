# Pacote de tarefa M2: objetos arremessáveis (props) (§4.3, §5.4)

> **Objetivo observável:** caixas, barris e uma máquina de venda espalhados pelo mapa; o lutador
> agarra, carrega e arremessa; o objeto voa, quebra vidro/divisória conforme a energia, acerta o
> oponente e se despedaça. Movimento autoritativo, inteiro e no snapshot (§4.3: "props que causam
> dano ou podem ser arremessados usam movimento autoritativo próprio e entram no snapshot").

**Estado atual e arquivos relevantes:** ler `AGENTS.md`, `Docs/contrato_sim.md`,
`game/sim/sim_const.gd`, `game/sim/matter_grid.gd` e, como referência de colisão e impacto,
`_move_axis`, `_probe`, `_flush` e `_impact` em `game/sim/match_sim.gd` (mesma regra de energia
de §5.2; pode copiar a lógica adaptada, não importar de match_sim).
Coordenadas do distrito de teste: topo da rua em y = 416 px (linha 52); piso da sobreloja em
y = 272 px (laje linhas 34–35); loja térrea x 368–591 px; fundos x 608–815 px; sobreloja x 368–815 px.

**Contrato público e invariantes:**
- `game/sim/` só inteiros, sem nós, sem física do Godot, sem RNG, sem tempo real. Ordem estável por id.
- Scripts por `preload`, sem `class_name`. Unidades: subpixels (`C.SUB = 256`), âncora no centro dos pés.
- Criar `game/sim/props.gd` (`extends RefCounted`) com esta API (o integrador depende dela):
  ```
  var props: Array   # Dictionaries, ordem por id
  func setup_test_district() -> void          # posiciona os objetos autorados (4 a 8 objetos)
  func step(grid, targets: Array) -> Array
      # Um tick. targets = [{"id": fighter_id, "box": [l, t, r, b]}] (subpixels) dos lutadores
      # atingíveis. Retorna eventos (Dictionaries, sem tick/seq):
      #   {"kind": "prop_hit", "prop": pid, "target": fid, "thrower": fid_ou_-1, "dmg": int,
      #    "vx": int, "vy": int}                        # o integrador aplica dano e knockback
      #   {"kind": "break", "prop": pid, "cells": PackedInt32Array, "mats": PackedByteArray,
      #    "axis": 0|1, "dir": -1|1, "e": E, "r": R}   # objeto rompeu cenário
      #   {"kind": "prop_bounce", "prop": pid, "e": E}
      #   {"kind": "prop_break", "prop": pid, "x": x, "y": y, "kind_id": k}   # objeto se despedaçou
  func find_grabbable(l: int, t: int, r: int, b: int) -> int   # id do objeto livre (não segurado,
      # não destruído) que toca o retângulo, o de menor id; -1 se nenhum
  func grab(pid: int, holder: int) -> void
  func hold_at(pid: int, x: int, y: int) -> void    # o integrador posiciona o objeto segurado
  func throw(pid: int, vx: int, vy: int, thrower: int) -> void
  func drop(pid: int) -> void                         # solta sem velocidade (ex.: portador levou golpe)
  func strike(pid: int, vx: int, vy: int, attacker: int, dmg: int) -> void  # golpe acertou o objeto
  func in_rect(l: int, t: int, r: int, b: int) -> Array   # ids de objetos livres que tocam o retângulo
  func box_of(p: Dictionary) -> Array                 # [l, t, r, b]
  func throw_mul(pid: int) -> int                     # milésimos: objeto pesado sai mais devagar
  func hash_ints() -> PackedInt64Array
  func snapshot() -> Dictionary
  func restore(s: Dictionary) -> void
  ```
  Campos mínimos por objeto: `id`, `kind`, `x`, `y`, `vx`, `vy`, `hw`, `h`, `mass`, `hp`, `state`
  (0 livre/repouso, 1 segurado, 2 arremessado, 3 destruído), `holder`, `thrower`, `hit_mask`,
  `breaks`, `t`.
- Regras (decididas; constantes de ajuste no topo de `props.gd`):
  1. Tipos (tabela no arquivo): `caixa` (16×16 px, leve, frágil), `barril` (14×20 px, médio),
     `maquina` (24×40 px, pesada, resistente; arremesso lento). Massa na mesma escala dos lutadores
     (`C.FIGHTERS[*].mass` ≈ 80–130).
  2. Livre: gravidade, atrito no chão, colide com a grade por varredura contínua por eixo
     (sub-passos ≤ meia célula; nunca dentro de matéria). Se o chão some, cai.
  3. Arremessado: mesma regra de impacto de §5.2 contra a grade (E = ½mv² em `C.energy`;
     rompe se `E ≥ R`, `|v_n| ≥ MAT_MIN_V` e sem núcleo; senão quica com restituição e aplica dano
     acumulado). O objeto perde hp com impactos (proporcional a R ou a E, documentar) e com
     `prop_hit`; hp ≤ 0 → `prop_break` e estado 3 (sai da colisão). Volta a livre quando a
     velocidade cai abaixo de um limiar.
  4. Acerto em lutador: só em estado 2, velocidade acima de limiar, alvo diferente do `thrower`
     e fora de `hit_mask`. Um acerto por alvo por arremesso. Após o acerto o objeto quica para trás
     com velocidade reduzida e perde hp. Dano do evento depende do tipo e da velocidade.
  5. Segurado: sem física própria; `hold_at` define a posição; não colide nem acerta.
  6. `strike`: objeto livre golpeado vira arremessado com `thrower = attacker` e perde hp.
  7. Objetos não colidem com lutadores (não são plataforma) nem entre si nesta versão.
- Tudo que afeta o futuro entra em `hash_ints()` e `snapshot()`.

**Arquivos permitidos para alteração:** criar `game/sim/props.gd` e `game/tests/props_tests.gd`.
Não editar nenhum outro arquivo (outros agentes estão editando `match_sim.gd`, `main.gd`, views e
`structure.gd`). Se precisar de algo em `matter_grid.gd` ou `sim_const.gd`, descrever na entrega.

**Fora do escopo:** input, agarrar lutador, apresentação, integração em `match_sim.gd`.

**Critérios de aceite (testes em `props_tests.gd`, `static func run_all() -> int` que imprime
`ok`/`FALHA` por teste como `game/tests/sim_tests.gd` e devolve o número de falhas; usar
`MatterGrid.new()` + `build_test_district()`):**
1. Objetos autorados assentam no chão em até 60 ticks e ficam parados; nenhum dentro de matéria.
2. Caixa arremessada rápido contra a vitrine (x 352–367 px, vidro) rompe o vidro e continua.
3. Objeto arremessado devagar contra concreto quica e deixa dano acumulado; nunca atravessa núcleo.
4. `prop_hit` sai uma vez só por alvo e nunca para o próprio `thrower`.
5. Objeto que perde o chão (destruir células embaixo) cai.
6. Varredura: objeto a 40 px/tick nunca termina dentro de matéria (checar todo tick).
7. Determinismo: duas execuções → mesmo `hash_ints`; snapshot/restore no meio de um voo → mesmo hash.

**Comando e cenário de prova:**
`C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/run_suite.gd -- --suite props`
(código de saída 0 = passou). Esse runner não carrega `match_sim.gd`.

**Entrega:** arquivos criados, saída dos testes, limitações e o que o integrador precisa saber.
Responder em português.
