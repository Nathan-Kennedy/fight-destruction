# Revisão do prompt mestre — versão 3

Data: 23/09/2026. Escopo: revisão documental e pesquisa; sem implementação do jogo,
instalação de ferramentas ou geração paga de assets.

## Parecer

A visão é forte: combate responsivo e cidade transformada pela luta. O risco da versão 2 era
converter hipóteses em garantias — determinismo, custo de simulação, consistência de arte e
facilidade de rollback — antes de testá-las. A versão 3 preserva os pilares e estabelece critérios.

Recomendação: manter Godot e testar hi-bit pixel art com personagens renderizados de rigs 3D.
Concentrar o acabamento numa sequência jogável de 20–30 segundos que mostre combate, ruptura,
interior revelado, colapso e continuação da luta com o mesmo padrão visual.

## Correções principais

| Antes | Versão 3 |
|---|---|
| Inteiros e passo fixo como garantia | Ordem, arredondamento, RNG, snapshot e replay/restore explícitos |
| Colisão adiada por tempo de frame | Gameplay consulta grade atualizada; só derivados cosméticos atrasam |
| RigidBody para props de gameplay | Objetos que alteram resultado entram na simulação e snapshot |
| Ruptura sem espessura e ricochete invertendo toda velocidade | Resistência efetiva, varredura contínua e reflexão pela normal |
| Carga estrutural sem tratar ciclos | Conectividade primeiro; carga precisa de contrato próprio |
| Rotação de colapso e falling sand cedo | Translação primeiro e alternativa de escombro parametrizado |
| Rig 3D como garantia visual | Topologia, pesos, poses, silhueta e revisão temporal |
| Magenta e alpha binário universais | Alpha nativo quando disponível e validação por família |
| Zoom supostamente resolvido por filtro | Comparação em movimento e múltiplas resoluções |
| Arte final concentrada na Fase 8 | Sala de referência visual durante os primeiros protótipos |
| Preparação de rollback descrita como barata | Medir restauração, memória, ressimulação e eventos duplicados |
| Muitos documentos antes do primeiro código | Plano curto seguido de incremento executável quando autorizado |

## Novos blocos

- §19: identidade proposta, sequência de referência, animação, som e gates visuais.
- §20: fábrica de assets, manifest, fontes editáveis, custos e aprovação temporal.
- §21: Astra e Opus 5.5, revisão independente e retomada de contexto.
- §22: skills disponíveis, seis propostas locais e recursos comunitários pesquisados.
- §23: marcos executáveis e cortes de escopo que preservam a experiência.

A divisão Astra implementa/Opus revisa é organização inicial, não conclusão de benchmark.
Ambos podem alternar funções; medir a melhor divisão no próprio projeto.

## Pesquisa aplicada

O relato do artista de Dead Cells apoia o pipeline 3D para sprites e a importância de poses/timing,
incluindo limites como flicker. [Relato original](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-).

Godot documenta escala inteira e fracionária; a revisão pede comparação visual em movimento.
[Documentação](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

As páginas oficiais identificam [GPT-6 Astra](https://developers.openai.com/api/docs/guides/latest-model)
e [Claude Opus 5.5](https://www.anthropic.com/claude/opus). Acesso às contas não foi verificado.

OpenAI Docs orientou a consulta oficial e a distinção entre skill, capacidade e integração:
[skills Codex](https://learn.chatgpt.com/docs/build-skills) e
[skills Claude Code](https://code.claude.com/docs/en/skills).

Os catálogos Godot de §22 tiveram READMEs consultados, mas não foram instalados ou auditados
em código. São candidatos, não ferramentas comprovadas neste ambiente.

## Limites

Foram lidos o prompt e os READMEs locais de GodotGame e AssetPipeline do Gloamwick. O segundo
ainda descreve Unity, portanto a migração das ferramentas precisa de inspeção.
Foi encontrada a pasta Godot mencionada no histórico; o binário não foi executado.

Os números são metas propostas. Não houve benchmark, playtest ou avaliação visual de build.
Esta revisão não constitui auditoria completa do Gloamwick.

[Original preservado](Prompt_Mestre_Jogo_2D_Destrutivo_v2_original.md).
[Prompt mestre atualizado](../Prompt_Mestre_Jogo_2D_Destrutivo.md).
