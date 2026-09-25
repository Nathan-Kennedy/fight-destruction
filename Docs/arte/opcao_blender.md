# Opção de pipeline: assets modelados no Blender (a testar)

Pedido do dono (24/09/2026): "alguns assets a gente deveria testar modelar pelo Blender e depois colocar
dentro do game; se ficar bom é uma outra opção legal para melhorar mais ainda o jogo."

Status: **ideia registrada, não testada.** Blender 5.1 instalado em `C:\Program Files\Blender Foundation\Blender 5.1`.
O briefing já previa isso (§9.2 opção B: modelo 3D com esqueleto → render pequeno sem antialiasing,
shader toon, snap de paleta, como em Dead Cells; §20.3 família "Lutador" com ações Blender e render em lote).

## Por que vale testar

- **Consistência entre frames garantida pela geometria:** o maior problema das folhas geradas por IA
  (escala, pés e detalhes variando entre frames; ver `art/lote02/_preview/relatorio_consistencia.md`)
  some com modelo 3D.
- **Parallax e profundidade de verdade (§8.6):** objetos 3D podem ser renderizados em camadas, de ângulos
  levemente diferentes, e com passes de normal/profundidade para luz 2D.
- **Estados de dano e rotação livres:** objetos (caixa, botijão, máquina, poste) podem tombar, girar e
  quebrar com renders de vários ângulos, sem gerar imagem nova.
- **Luz 2D:** normal map do render deixa o objeto reagir às luzes do jogo (postes, fogo, explosão).

## Candidatos para o primeiro teste (do mais simples ao mais caro)

1. **Objetos:** caixa, barril, botijão, extintor, máquina de venda — geometria simples, 4 estados de dano.
2. **Fixos:** poste (o ângulo de entortar vira rotação real), luminária pendente, hidrante, transformador.
3. **Móveis de interior** para as camadas da §8.6 (balcão, estante, sofá, mesa).
4. **Depois, se os anteriores ficarem bons:** um lutador (Bloco é o mais indicado: formas mecânicas, rig simples).

## Como fazer (proposta)

- Modelagem por script Python do Blender (CLI `blender -b -P script.py`), reproduzível e versionável em
  `tools/blender/`; ou modelagem manual pelo dono e só o render por script.
- Câmera ortográfica lateral, mesma luz do jogo (entardecer vindo da esquerda), shader toon de 2 tons,
  contorno escuro (Freestyle ou Solidify invertido), fundo transparente, render na densidade do jogo
  (4 px por px de mundo) e passe de normal opcional.
- Textura/cor puxada da arte gerada aprovada (a imagem gerada vira referência de cor e acabamento).
- Saída passa pelo mesmo `tools/art/process_sheets.py` e manifest (§20.2), com `provider: "blender"`.

## Critério de decisão (bake-off, §9.2)

Mesmo objeto feito pelas duas vias (imagem gerada vs Blender), lado a lado no jogo em movimento:
leitura a 1×, encaixe no estilo cel-shaded, consistência, tempo por asset e facilidade de variar estados.
O dono decide. Se o Blender ganhar para uma família, ela migra; as outras seguem por imagem gerada.
