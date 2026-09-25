# Pacote de revisão M1 — para o Astra (§21.2)

> **Objetivo observável:** revisar de forma independente o primeiro incremento jogável e apontar
> falhas concretas com reprodução. Não reescrever o projeto.

**Estado atual e arquivos relevantes:** ver `README.md` (Estado atual) e `Docs/estado.md`.
Código: `game/sim/match_sim.gd` (tick, colisão, impacto, golpes, stocks), `game/sim/matter_grid.gd`,
`game/sim/sim_const.gd`, `game/sim/attacks.gd`, `game/main.gd` (loop fixo, replay, captura),
`game/tests/sim_tests.gd`.

**Contrato público e invariantes:** `Docs/contrato_sim.md`. A simulação só usa inteiros; a
apresentação nunca escreve no estado; mesmas entradas → mesmo hash; nenhum lutador dentro de matéria.

**Pontos que merecem olhar crítico:**
1. `_move_axis`/`_probe`/`_flush`: tunneling, bordas negativas, corpo maior que a célula, cantos.
2. `_impact`: fórmula de R por linha, mínimo por material, escalonamento de `remaining` depois da
   ruptura (usa razão de norma L1), limite `MAX_BREAKS`.
3. Ordem de atualização por ID: há vantagem sistemática para o J1 em trocas simultâneas?
4. Snapshot: falta algum campo que afete o futuro? (o RNG dos bots fica fora de propósito: o bot é
   gerador de input, não simulação).
5. Números de §5.3 em `sim_const.gd`: coerentes com o pilar F (destruição previsível)?

**Arquivos permitidos para alteração:** nenhum. Entregar achados, não patch, salvo pedido.

**Fora do escopo:** arte, som, online, elenco, menus.

**Comando e cenário de prova:** `Testar.bat` (código de saída 0/1), `Capturar.bat` (PNGs em
`captures/demo/`), `Jogar.bat --bots` para ver dois bots lutando.

**Entrega:** lista de achados ordenada por gravidade, cada um com arquivo:linha, cenário que
reproduz e efeito observado. Marcar o que foi executado e o que é hipótese.
