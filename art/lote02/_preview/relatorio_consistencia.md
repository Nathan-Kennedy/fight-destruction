# Relatório de consistência — lote 02

Gerado por `tools/art/process_sheets.py` em 2026-09-24T18:04:15.
Status de todos os assets: **candidate**. Frames marcados continuam exportados; refazer ou aceitar é
decisão humana.

Limites: altura/idle ∈ [0.85, 1.15] (animações de pé, frames no chão); distância de cor
(Hellinger hue×sat vs idle f1) ≤ 0.40 (≤ 0.55 em animações com efeito desenhado);
|Δx do pivô| ≤ 0.20 da altura do idle; |Δy dos pés| ≤ 0.06 (frames no chão); área/idle ∈
[0.55, 1.8] em pé, [0.30, 3.0] demais; CRUZA_CELULA = parte do frame atravessa a borda da grade
(recuperada inteira); CORTADO = parte perdida; FUNDIDO_VIZINHO = frame encostado no vizinho.

Colunas: h = altura/idle; cor = dist. idle f1; cor⚓ = dist. âncora (informativa); dx/dy =
deslocamento do pivô na folha (fração da altura do idle); área = área/idle; ilhas = ilhas removidas.

## bloco

Escala 0.545 (referência: idle), altura-alvo 224 px, célula 374×292, pivô [187, 268]. Animações: 7.

**Frames marcados: 23 de 48.**

- `idle` f1: CRUZA_CELULA
- `idle` f5: CRUZA_CELULA
- `idle` f6: CRUZA_CELULA
- `idle` f7: CRUZA_CELULA
- `run` f1: CRUZA_CELULA
- `run` f2: CRUZA_CELULA
- `run` f3: CRUZA_CELULA
- `run` f5: ALTURA 0.85, CRUZA_CELULA
- `run` f6: ALTURA 0.81
- `run` f7: ALTURA 0.85
- `jump` f1: CRUZA_CELULA
- `jump` f2: CRUZA_CELULA
- `jump` f6: CRUZA_CELULA
- `jab` f3: CRUZA_CELULA
- `jab` f4: CRUZA_CELULA
- `strong` f2: ALTURA 0.81
- `strong` f3: ALTURA 0.80
- `strong` f4: ALTURA 0.75, CRUZA_CELULA
- `strong` f5: CRUZA_CELULA
- `strong` f6: CRUZA_CELULA
- `strong` f7: ALTURA 0.82, CRUZA_CELULA
- `hurt` f5: CRUZA_CELULA
- `fall` f6: CRUZA_CELULA

| anim | f | aéreo | h | cor | cor⚓ | dx | dy | área | ilhas | flags |
|---|---|---|---|---|---|---|---|---|---|---|
| idle | 1 |  | 1.04 | 0.00 | 0.15 | 0.02 | 0.04 | 1.04 | 0 | CRUZA_CELULA |
| idle | 2 |  | 1.02 | 0.02 | 0.14 | -0.01 | 0.04 | 1.01 | 0 |  |
| idle | 3 |  | 1.00 | 0.03 | 0.14 | -0.04 | 0.04 | 1.01 | 0 |  |
| idle | 4 |  | 0.98 | 0.03 | 0.15 | -0.05 | 0.05 | 0.99 | 0 |  |
| idle | 5 |  | 1.00 | 0.03 | 0.13 | 0.02 | -0.04 | 1.02 | 0 | CRUZA_CELULA |
| idle | 6 |  | 0.99 | 0.04 | 0.13 | 0.01 | -0.04 | 0.99 | 0 | CRUZA_CELULA |
| idle | 7 |  | 0.98 | 0.04 | 0.13 | 0.00 | -0.04 | 0.97 | 0 | CRUZA_CELULA |
| idle | 8 |  | 1.00 | 0.03 | 0.14 | -0.04 | -0.04 | 0.99 | 0 |  |
| run | 1 |  | 0.89 | 0.13 | 0.13 | -0.07 | 0.04 | 0.93 | 0 | CRUZA_CELULA |
| run | 2 |  | 0.89 | 0.15 | 0.12 | 0.06 | 0.04 | 0.81 | 0 | CRUZA_CELULA |
| run | 3 |  | 0.89 | 0.14 | 0.14 | 0.05 | 0.04 | 0.82 | 0 | CRUZA_CELULA |
| run | 4 |  | 0.90 | 0.15 | 0.13 | 0.07 | 0.04 | 0.82 | 0 |  |
| run | 5 |  | 0.85 | 0.12 | 0.12 | 0.01 | -0.05 | 0.86 | 1 | ALTURA 0.85 CRUZA_CELULA |
| run | 6 |  | 0.81 | 0.15 | 0.12 | -0.01 | -0.05 | 0.88 | 2 | ALTURA 0.81 |
| run | 7 |  | 0.85 | 0.14 | 0.13 | -0.09 | -0.05 | 0.78 | 0 | ALTURA 0.85 |
| run | 8 |  | 0.87 | 0.13 | 0.12 | -0.00 | -0.04 | 0.87 | 0 |  |
| jump | 1 |  | 0.72 | 0.17 | 0.14 | 0.03 | 0.04 | 0.88 | 0 | CRUZA_CELULA |
| jump | 2 | s | 1.12 | 0.24 | 0.23 | -0.07 | 0.04 | 1.31 | 3 | CRUZA_CELULA |
| jump | 3 | s | 1.02 | 0.16 | 0.15 | 0.08 | 0.01 | 0.83 | 2 |  |
| jump | 4 | s | 0.97 | 0.15 | 0.15 | 0.05 | -0.13 | 0.69 | 2 |  |
| jump | 5 | s | 0.98 | 0.15 | 0.11 | 0.11 | -0.11 | 0.88 | 4 |  |
| jump | 6 |  | 0.74 | 0.29 | 0.26 | -0.02 | -0.04 | 1.12 | 2 | CRUZA_CELULA |
| jab | 1 |  | 0.88 | 0.19 | 0.14 | -0.02 | 0.04 | 0.89 | 0 |  |
| jab | 2 |  | 0.92 | 0.18 | 0.13 | -0.05 | 0.04 | 0.99 | 0 |  |
| jab | 3 |  | 0.85 | 0.20 | 0.17 | -0.20 | 0.04 | 0.99 | 0 | CRUZA_CELULA |
| jab | 4 |  | 0.95 | 0.18 | 0.15 | -0.06 | -0.04 | 1.20 | 4 | CRUZA_CELULA |
| jab | 5 |  | 0.87 | 0.15 | 0.12 | -0.01 | -0.04 | 0.91 | 6 |  |
| jab | 6 |  | 0.88 | 0.17 | 0.14 | 0.01 | -0.04 | 0.90 | 0 |  |
| strong | 1 |  | 0.87 | 0.28 | 0.18 | -0.04 | 0.04 | 0.76 | 0 |  |
| strong | 2 |  | 0.81 | 0.28 | 0.18 | -0.04 | 0.04 | 0.81 | 0 | ALTURA 0.81 |
| strong | 3 |  | 0.80 | 0.27 | 0.17 | -0.04 | 0.04 | 0.79 | 5 | ALTURA 0.80 |
| strong | 4 |  | 0.75 | 0.28 | 0.19 | -0.08 | 0.04 | 0.74 | 8 | ALTURA 0.75 CRUZA_CELULA |
| strong | 5 |  | 0.87 | 0.28 | 0.20 | -0.04 | -0.04 | 0.88 | 9 | CRUZA_CELULA |
| strong | 6 |  | 0.90 | 0.27 | 0.16 | -0.02 | -0.04 | 0.77 | 11 | CRUZA_CELULA |
| strong | 7 |  | 0.81 | 0.27 | 0.17 | 0.04 | -0.04 | 0.75 | 6 | ALTURA 0.82 CRUZA_CELULA |
| strong | 8 |  | 0.86 | 0.29 | 0.18 | -0.00 | -0.04 | 0.77 | 0 |  |
| hurt | 1 | s | 0.97 | 0.17 | 0.28 | 0.06 | 0.07 | 1.06 | 5 |  |
| hurt | 2 | s | 0.95 | 0.23 | 0.31 | 0.01 | -0.06 | 1.06 | 2 |  |
| hurt | 3 | s | 1.14 | 0.23 | 0.32 | 0.01 | 0.07 | 1.11 | 2 |  |
| hurt | 4 | s | 0.95 | 0.19 | 0.29 | 0.01 | -0.10 | 0.92 | 3 |  |
| hurt | 5 | s | 0.83 | 0.31 | 0.34 | -0.01 | -0.07 | 1.21 | 5 | CRUZA_CELULA |
| hurt | 6 | s | 0.84 | 0.17 | 0.27 | 0.03 | -0.06 | 0.98 | 4 |  |
| fall | 1 | s | 1.17 | 0.29 | 0.20 | -0.02 | 0.06 | 1.10 | 0 |  |
| fall | 2 | s | 1.16 | 0.30 | 0.21 | -0.03 | 0.06 | 1.04 | 0 |  |
| fall | 3 | s | 1.10 | 0.28 | 0.19 | -0.03 | 0.03 | 1.06 | 0 |  |
| fall | 4 | s | 1.07 | 0.30 | 0.21 | 0.01 | -0.01 | 1.08 | 0 |  |
| fall | 5 | s | 1.09 | 0.29 | 0.21 | -0.01 | -0.01 | 1.04 | 0 |  |
| fall | 6 | s | 1.17 | 0.29 | 0.19 | -0.07 | 0.02 | 1.10 | 0 | CRUZA_CELULA |

## brasa

Escala 0.4224 (referência: idle), altura-alvo 200 px, célula 370×232, pivô [185, 222]. Animações: 8.

**Frames marcados: 17 de 54.**

- `run` f1: CRUZA_CELULA
- `run` f2: CRUZA_CELULA
- `run` f3: CRUZA_CELULA
- `run` f4: CRUZA_CELULA
- `run` f5: CRUZA_CELULA
- `jump` f2: CRUZA_CELULA
- `jump` f4: CRUZA_CELULA
- `jump` f5: CRUZA_CELULA
- `jab` f4: CRUZA_CELULA
- `strong` f3: CRUZA_CELULA
- `strong` f4: CRUZA_CELULA
- `strong` f5: CRUZA_CELULA
- `strong` f6: CRUZA_CELULA
- `hurt` f1: CRUZA_CELULA
- `hurt` f3: CRUZA_CELULA
- `hurt` f5: CRUZA_CELULA
- `grab` f5: CRUZA_CELULA

| anim | f | aéreo | h | cor | cor⚓ | dx | dy | área | ilhas | flags |
|---|---|---|---|---|---|---|---|---|---|---|
| idle | 1 |  | 1.02 | 0.00 | 0.11 | 0.00 | 0.02 | 1.00 | 0 |  |
| idle | 2 |  | 0.99 | 0.02 | 0.11 | 0.00 | 0.02 | 1.00 | 1 |  |
| idle | 3 |  | 1.01 | 0.02 | 0.11 | 0.01 | 0.02 | 1.00 | 1 |  |
| idle | 4 |  | 1.00 | 0.02 | 0.11 | 0.00 | 0.02 | 1.00 | 0 |  |
| idle | 5 |  | 1.00 | 0.03 | 0.11 | 0.01 | -0.02 | 1.00 | 0 |  |
| idle | 6 |  | 0.98 | 0.03 | 0.11 | 0.01 | -0.02 | 1.00 | 0 |  |
| idle | 7 |  | 0.98 | 0.03 | 0.11 | 0.01 | -0.02 | 1.00 | 0 |  |
| idle | 8 |  | 1.00 | 0.03 | 0.11 | 0.00 | -0.02 | 0.99 | 0 |  |
| run | 1 |  | 0.94 | 0.07 | 0.11 | 0.05 | 0.04 | 0.95 | 0 | CRUZA_CELULA |
| run | 2 |  | 0.90 | 0.09 | 0.11 | 0.01 | 0.04 | 0.88 | 0 | CRUZA_CELULA |
| run | 3 |  | 0.93 | 0.09 | 0.12 | -0.01 | 0.04 | 0.84 | 0 | CRUZA_CELULA |
| run | 4 |  | 0.94 | 0.08 | 0.11 | -0.16 | 0.03 | 0.94 | 0 | CRUZA_CELULA |
| run | 5 |  | 0.92 | 0.07 | 0.11 | 0.04 | -0.04 | 0.95 | 0 | CRUZA_CELULA |
| run | 6 |  | 0.88 | 0.08 | 0.12 | 0.01 | -0.03 | 0.87 | 0 |  |
| run | 7 |  | 0.91 | 0.07 | 0.11 | -0.01 | -0.03 | 0.86 | 0 |  |
| run | 8 |  | 0.95 | 0.08 | 0.11 | -0.10 | -0.04 | 0.87 | 0 |  |
| jump | 1 |  | 0.74 | 0.16 | 0.15 | -0.01 | -0.01 | 0.98 | 0 |  |
| jump | 2 | s | 1.00 | 0.09 | 0.10 | -0.07 | -0.01 | 1.04 | 0 | CRUZA_CELULA |
| jump | 3 | s | 0.89 | 0.12 | 0.12 | -0.03 | -0.15 | 0.88 | 0 |  |
| jump | 4 | s | 0.90 | 0.11 | 0.12 | 0.04 | -0.17 | 0.83 | 0 | CRUZA_CELULA |
| jump | 5 | s | 0.98 | 0.10 | 0.11 | 0.06 | -0.02 | 0.86 | 0 | CRUZA_CELULA |
| jump | 6 |  | 0.72 | 0.15 | 0.15 | 0.05 | 0.01 | 0.78 | 0 |  |
| jab | 1 |  | 1.01 | 0.09 | 0.14 | -0.01 | 0.03 | 0.96 | 0 |  |
| jab | 2 |  | 0.99 | 0.11 | 0.15 | -0.05 | 0.02 | 1.07 | 0 |  |
| jab | 3 |  | 1.00 | 0.13 | 0.17 | -0.12 | 0.02 | 1.10 | 0 |  |
| jab | 4 |  | 0.98 | 0.17 | 0.20 | -0.02 | -0.03 | 1.20 | 5 | CRUZA_CELULA |
| jab | 5 |  | 1.00 | 0.10 | 0.13 | 0.04 | -0.02 | 0.96 | 7 |  |
| jab | 6 |  | 0.99 | 0.08 | 0.13 | -0.00 | -0.02 | 0.95 | 0 |  |
| strong | 1 |  | 0.89 | 0.16 | 0.20 | -0.02 | 0.03 | 0.86 | 0 |  |
| strong | 2 |  | 0.88 | 0.15 | 0.21 | -0.01 | 0.03 | 0.84 | 0 |  |
| strong | 3 |  | 0.88 | 0.18 | 0.22 | -0.05 | 0.03 | 0.85 | 0 | CRUZA_CELULA |
| strong | 4 |  | 0.87 | 0.19 | 0.24 | -0.05 | 0.03 | 0.84 | 0 | CRUZA_CELULA |
| strong | 5 |  | 0.91 | 0.22 | 0.26 | -0.02 | -0.03 | 1.04 | 12 | CRUZA_CELULA |
| strong | 6 |  | 0.89 | 0.17 | 0.21 | -0.03 | -0.03 | 0.84 | 12 | CRUZA_CELULA |
| strong | 7 |  | 0.89 | 0.17 | 0.22 | -0.00 | -0.03 | 0.83 | 2 |  |
| strong | 8 |  | 0.90 | 0.16 | 0.21 | -0.02 | -0.03 | 0.80 | 0 |  |
| hurt | 1 | s | 0.96 | 0.09 | 0.13 | 0.03 | -0.03 | 1.16 | 8 | CRUZA_CELULA |
| hurt | 2 | s | 0.93 | 0.07 | 0.08 | -0.04 | -0.03 | 0.88 | 0 |  |
| hurt | 3 | s | 0.71 | 0.10 | 0.10 | -0.08 | -0.23 | 0.94 | 0 | CRUZA_CELULA |
| hurt | 4 | s | 0.91 | 0.11 | 0.10 | -0.05 | -0.11 | 0.83 | 0 |  |
| hurt | 5 | s | 0.97 | 0.06 | 0.10 | 0.07 | -0.06 | 0.87 | 0 | CRUZA_CELULA |
| hurt | 6 | s | 0.77 | 0.08 | 0.10 | 0.08 | -0.07 | 0.76 | 0 |  |
| grab | 1 |  | 0.93 | 0.10 | 0.07 | -0.08 | 0.03 | 0.97 | 0 |  |
| grab | 2 |  | 0.86 | 0.12 | 0.12 | -0.10 | 0.03 | 0.97 | 2 |  |
| grab | 3 |  | 0.99 | 0.11 | 0.11 | -0.02 | 0.03 | 0.98 | 0 |  |
| grab | 4 |  | 0.94 | 0.11 | 0.09 | 0.05 | -0.03 | 1.07 | 0 |  |
| grab | 5 |  | 0.89 | 0.13 | 0.14 | -0.14 | -0.03 | 1.11 | 0 | CRUZA_CELULA |
| grab | 6 |  | 0.89 | 0.12 | 0.10 | 0.03 | -0.04 | 0.90 | 0 |  |
| fall | 1 | s | 1.04 | 0.13 | 0.15 | 0.00 | 0.01 | 0.94 | 0 |  |
| fall | 2 | s | 1.03 | 0.13 | 0.15 | -0.03 | 0.00 | 0.91 | 0 |  |
| fall | 3 | s | 1.02 | 0.13 | 0.15 | -0.00 | -0.01 | 0.95 | 1 |  |
| fall | 4 | s | 0.93 | 0.14 | 0.16 | -0.01 | -0.07 | 0.94 | 2 |  |
| fall | 5 | s | 0.97 | 0.14 | 0.16 | -0.01 | -0.06 | 0.94 | 0 |  |
| fall | 6 | s | 1.04 | 0.13 | 0.15 | -0.02 | 0.00 | 0.94 | 0 |  |

## faisca

Escala 0.4084 (referência: idle), altura-alvo 176 px, célula 260×220, pivô [130, 205]. Animações: 8.

**Frames marcados: 11 de 54.**

- `run` f1: CRUZA_CELULA
- `run` f2: ALTURA 0.84
- `run` f6: ALTURA 0.76, PES -0.12
- `jab` f3: CRUZA_CELULA
- `jab` f4: CRUZA_CELULA
- `strong` f2: CRUZA_CELULA
- `strong` f3: CRUZA_CELULA
- `strong` f4: CRUZA_CELULA
- `strong` f5: CRUZA_CELULA
- `hurt` f2: CRUZA_CELULA
- `land` f3: CRUZA_CELULA

| anim | f | aéreo | h | cor | cor⚓ | dx | dy | área | ilhas | flags |
|---|---|---|---|---|---|---|---|---|---|---|
| idle | 1 |  | 1.00 | 0.00 | 0.21 | 0.01 | 0.03 | 1.00 | 0 |  |
| idle | 2 |  | 1.01 | 0.04 | 0.21 | 0.03 | 0.03 | 1.00 | 0 |  |
| idle | 3 |  | 1.03 | 0.06 | 0.23 | 0.04 | 0.03 | 1.00 | 0 |  |
| idle | 4 |  | 0.99 | 0.04 | 0.20 | 0.04 | 0.03 | 1.00 | 0 |  |
| idle | 5 |  | 0.93 | 0.04 | 0.20 | 0.02 | -0.03 | 1.00 | 0 |  |
| idle | 6 |  | 1.00 | 0.03 | 0.20 | 0.03 | -0.03 | 0.99 | 0 |  |
| idle | 7 |  | 1.02 | 0.05 | 0.21 | 0.04 | -0.03 | 1.01 | 0 |  |
| idle | 8 |  | 0.96 | 0.04 | 0.20 | 0.02 | -0.03 | 0.97 | 0 |  |
| run | 1 |  | 0.95 | 0.17 | 0.12 | 0.09 | 0.04 | 1.00 | 0 | CRUZA_CELULA |
| run | 2 |  | 0.84 | 0.18 | 0.13 | 0.02 | 0.03 | 0.74 | 0 | ALTURA 0.84 |
| run | 3 |  | 0.94 | 0.19 | 0.12 | -0.07 | 0.03 | 0.78 | 0 |  |
| run | 4 |  | 0.94 | 0.18 | 0.11 | -0.19 | 0.03 | 0.92 | 0 |  |
| run | 5 |  | 0.94 | 0.19 | 0.12 | -0.08 | -0.03 | 0.96 | 0 |  |
| run | 6 |  | 0.76 | 0.19 | 0.12 | -0.05 | -0.12 | 0.72 | 0 | ALTURA 0.76 PES -0.12 |
| run | 7 |  | 0.94 | 0.20 | 0.14 | -0.07 | -0.03 | 0.78 | 0 |  |
| run | 8 |  | 0.93 | 0.17 | 0.12 | -0.16 | -0.03 | 0.88 | 0 |  |
| jump | 1 |  | 0.72 | 0.20 | 0.14 | 0.05 | -0.00 | 1.16 | 0 |  |
| jump | 2 | s | 0.97 | 0.21 | 0.14 | 0.00 | -0.01 | 1.09 | 0 |  |
| jump | 3 | s | 0.93 | 0.25 | 0.13 | 0.00 | -0.17 | 1.01 | 0 |  |
| jump | 4 | s | 0.86 | 0.26 | 0.14 | 0.01 | -0.22 | 1.02 | 0 |  |
| jump | 5 | s | 1.06 | 0.23 | 0.14 | 0.01 | -0.01 | 0.91 | 0 |  |
| jump | 6 |  | 0.71 | 0.20 | 0.11 | 0.07 | 0.00 | 0.99 | 0 |  |
| jab | 1 |  | 1.03 | 0.24 | 0.25 | 0.01 | 0.04 | 1.13 | 0 |  |
| jab | 2 |  | 0.98 | 0.21 | 0.21 | 0.00 | 0.04 | 1.14 | 0 |  |
| jab | 3 |  | 0.98 | 0.22 | 0.23 | -0.03 | 0.04 | 1.23 | 1 | CRUZA_CELULA |
| jab | 4 |  | 0.97 | 0.26 | 0.24 | 0.02 | -0.04 | 1.24 | 1 | CRUZA_CELULA |
| jab | 5 |  | 0.96 | 0.22 | 0.21 | 0.05 | -0.04 | 1.08 | 0 |  |
| jab | 6 |  | 0.99 | 0.22 | 0.22 | 0.02 | -0.04 | 1.12 | 0 |  |
| strong | 1 |  | 0.93 | 0.29 | 0.32 | -0.01 | 0.04 | 1.01 | 0 |  |
| strong | 2 |  | 0.92 | 0.28 | 0.31 | -0.04 | 0.04 | 0.98 | 1 | CRUZA_CELULA |
| strong | 3 |  | 0.91 | 0.23 | 0.27 | -0.05 | 0.04 | 0.98 | 6 | CRUZA_CELULA |
| strong | 4 |  | 0.88 | 0.27 | 0.34 | -0.06 | 0.04 | 1.02 | 4 | CRUZA_CELULA |
| strong | 5 |  | 0.92 | 0.27 | 0.30 | -0.02 | -0.05 | 1.04 | 7 | CRUZA_CELULA |
| strong | 6 |  | 0.93 | 0.25 | 0.26 | -0.04 | -0.05 | 1.01 | 0 |  |
| strong | 7 |  | 0.93 | 0.23 | 0.29 | -0.02 | -0.05 | 0.95 | 0 |  |
| strong | 8 |  | 0.95 | 0.24 | 0.29 | -0.03 | -0.04 | 0.98 | 0 |  |
| hurt | 1 | s | 1.03 | 0.26 | 0.16 | -0.03 | 0.03 | 1.17 | 0 |  |
| hurt | 2 | s | 1.04 | 0.29 | 0.18 | 0.02 | 0.02 | 1.22 | 0 | CRUZA_CELULA |
| hurt | 3 | s | 1.03 | 0.26 | 0.16 | -0.00 | -0.06 | 1.15 | 0 |  |
| hurt | 4 | s | 0.88 | 0.26 | 0.18 | 0.02 | -0.18 | 1.14 | 0 |  |
| hurt | 5 | s | 1.00 | 0.26 | 0.16 | -0.01 | -0.06 | 1.13 | 0 |  |
| hurt | 6 | s | 0.96 | 0.26 | 0.16 | 0.04 | -0.02 | 1.24 | 0 |  |
| fall | 1 | s | 1.12 | 0.36 | 0.38 | -0.03 | 0.04 | 0.97 | 0 |  |
| fall | 2 | s | 1.10 | 0.36 | 0.37 | -0.06 | 0.04 | 1.04 | 1 |  |
| fall | 3 | s | 1.07 | 0.35 | 0.37 | -0.06 | 0.02 | 0.99 | 0 |  |
| fall | 4 | s | 1.08 | 0.34 | 0.36 | -0.05 | -0.03 | 0.97 | 0 |  |
| fall | 5 | s | 1.08 | 0.35 | 0.35 | -0.03 | -0.01 | 0.98 | 0 |  |
| fall | 6 | s | 1.09 | 0.34 | 0.35 | -0.03 | -0.02 | 0.96 | 0 |  |
| land | 1 |  | 1.01 | 0.10 | 0.17 | 0.07 | 0.03 | 1.32 | 0 |  |
| land | 2 |  | 0.83 | 0.12 | 0.16 | 0.01 | 0.03 | 1.23 | 0 |  |
| land | 3 |  | 0.71 | 0.22 | 0.23 | -0.05 | 0.03 | 1.30 | 6 | CRUZA_CELULA |
| land | 4 |  | 0.90 | 0.10 | 0.17 | 0.02 | -0.03 | 1.26 | 0 |  |
| land | 5 |  | 1.04 | 0.10 | 0.18 | -0.02 | -0.03 | 1.19 | 0 |  |
| land | 6 |  | 1.06 | 0.09 | 0.18 | -0.01 | -0.03 | 1.15 | 0 |  |

## Outros assets

| asset | resultado |
|---|---|
| `bg_ceu` | 1280×720; opaco (mantido) |
| `bg_elementos_ceu` | 1280×853; alpha original (73% transparente) |
| `bg_rua_near` | 1280×640; alpha original (16% transparente) |
| `bg_skyline_far` | 1280×720; alpha original (59% transparente) |
| `bg_skyline_mid` | 1280×720; alpha original (29% transparente) |
| `chr_bloco_anchor` | anchor.png (alpha original (39% transparente); 0 ilhas removidas) |
| `chr_brasa_anchor` | anchor.png (alpha original (51% transparente); 1 ilhas removidas) |
| `chr_faisca_anchor` | anchor.png (alpha original (57% transparente); 0 ilhas removidas) |
| `fx_acerto_forte` | tira 8×390x304, loop=False; alpha original (89% transparente) |
| `fx_acerto_leve` | tira 8×394x354, loop=False; alpha original (95% transparente) |
| `fx_escudo` | tira 8×354x372, loop=True; alpha original (80% transparente) |
| `fx_escudo_quebra` | tira 8×386x372, loop=False; alpha original (88% transparente) |
| `mod_fachada_detalhes` | 8 recortes em escala da fonte; alpha original (62% transparente) |
| `mod_interior_escritorio` | 1024×512; opaco (mantido) |
| `mod_interior_loja` | 1024×512; opaco (mantido) |
| `mod_textura_concreto` | 256×256; costura x/y 0.61/0.70 (ok, sem blend) |
| `mod_textura_divisoria` | 256×256; costura x/y 0.33/0.71 (ok, sem blend) |
| `mod_textura_entulho` | 256×256; costura x/y 0.74/0.87 (ok, sem blend) |
| `mod_textura_nucleo` | 256×256; costura x/y 0.54/1.41 -> blend de borda aplicado -> 0.46/0.34 |
| `mod_textura_tijolo` | 256×256; costura x/y 0.71/0.14 (ok, sem blend) |
| `mod_textura_vidro` | 256×256; costura x/y 0.75/1.70 -> blend de borda aplicado -> 0.56/0.88 |
