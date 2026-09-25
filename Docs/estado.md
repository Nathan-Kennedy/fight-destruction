# Estado

- **Data:** 24/09/2026
- **Build:** projeto Godot 4.7.2 em `game/`, sem export. Repositório privado https://github.com/Nathan-Kennedy/fight-destruction (branch `main`); primeiro commit `e628931` em 24/09/2026.
- **Última tarefa concluída:** M2 técnico em greybox, em paralelo por três agentes:
  - Estrutura, colapso anunciado e entulho: `game/sim/structure.gd` (subagente Claude).
  - Objetos arremessáveis: `game/sim/props.gd` (GPT-6 Astra via Codex).
  - Combate e integração: todo golpe lasca o cenário, escudo, rolamento, esquiva parada e aérea,
    agarrão com 4 arremessos, pegar e arremessar objetos, esmagamento e KO ambiental (soterrado),
    views, entrada e bot (Opus 5.5).
  - Revisão cruzada: Claude revisou `props.gd` (5 achados reproduzidos, corrigidos pelo Astra
    com 8 testes). Astra revisou `structure.gd` e a integração (8 hipóteses por leitura): corrigidos
    desenterrar sempre achar espaço, esmagamento no tick do assentamento, KO só no chão, ilha
    atingindo objetos, entulho parado por vizinho, hash com arquétipo e medidas. Mantidos: marquise
    como âncora (limitação) e custo de muitas ilhas pequenas (hipótese sem medição).
- **Elementos reativos (24/09, Opus):** `game/sim/fixtures.gd` (canos de água/vapor/gás, botijão,
  transformador, fiação, hidrante, postes, luminárias, neon), botijão e extintor em `props.gd`,
  integração no tick de `match_sim.gd` (replay `versao` 3), `game/view/fixtures_view.gd` com
  placeholders vetoriais e luz 2D (F7). 7 testes novos em `sim_tests.gd`; captura `--scene fixos`.
  Números são hipóteses para playtest; arte final pendente (§5 do design).
- **Verificação:** `Testar.bat` roda 19 testes de integração, a suíte `structure` (8), a suíte
  `props` e o autotest com bots nas 4 sementes (os bots usam escudo, esquiva, agarrão e objetos).
  Análise estrutural completa em cerca de 0,45 ms. Nas rodadas curtas o pior tick do autotest
  ficou abaixo de 1 ms (orçamento: 4 ms). Capturas: `Capturar.bat` (vitrine) e
  `--capture ../captures/colapso --scene colapso`. Abri as imagens do colapso: aviso em laranja com
  poeira, queda da frente da laje e da fachada, entulho assentado, J2 soterrado a 110%.
- **Depois do primeiro playtest do dono:** ele ficou preso nos destroços. Adicionada a explosão
  (especial radial, recarga 4 s) e subida automática de degrau de até 2 células; testes novos para
  os dois. Arte: prompts do lote 01 em [arte/prompts_arte_lote01.md](arte/prompts_arte_lote01.md),
  geração pelo Astra em `art/concept/lote01/`: 11 imagens (inclui tela de gameplay com HUD e prancha
  do HUD), todas candidatas. Triagem e lista de validação em [arte/validacao_lote01.md](arte/validacao_lote01.md).
- **Arte de produção (lote 02) e VFX, em andamento:** progresso detalhado e atualizado em
  [arte/progresso_lote02.md](arte/progresso_lote02.md). Resumo: 35 de ~110 imagens geradas (limite
  do Codex até 17:38; retomada agendada), pipeline `tools/art/process_sheets.py` pronto, sprites já
  aparecem no jogo, VFX procedural integrado. Decisão: alvo visual = tela ilustrada do lote 01
  (§9.2 em revisão), Faísca = rapaz de cabelo branco/ciano.
- **Elementos reativos e estágio vivo (24/09 tarde):** `game/sim/fixtures.gd` (+7 testes, replay versão 3),
  `fixtures_view.gd` com luz 2D, `ambient_view.gd`/`ambient_figures.gd`/`ambient_sky.gd` (só apresentação).
  Design em [design_elementos_reativos.md](design_elementos_reativos.md). Bateria de 60 s passa; pior
  tick 1,8 ms. Teclas novas: F6 flashes, F7 luzes, F8 ambiente.
- **24/09 noite, pronto para playtest:** HUD no estilo do conceito (`view/hud.gd`), som CC0 em camadas
  (`view/audio_director.gd`, 235 sons em `game/assets/sfx/`, F9), sensação de combate (hitstop por dano com teto
  14, buffer de input 5 ticks, coyote 4 ticks; replay versão 4), teste de navegabilidade passando, cacos por
  fratura e rachaduras por dano, impact frame mangá e Finish Zoom, profundidade 2.5D nos interiores e calçada.
  Bateria de 60 s passa (pior tick 1,5 ms). Roteiro da captura `fixos` reajustado ao hitstop novo.
- **Decisões tomadas nesta rodada (hipóteses para playtest):**
  - Vão estrutural `SPAN = 45` células. Com 40, o prédio intacto já não se sustentaria. Sem o
    pilar, a frente (x 44–56) cai; sem a divisória, nada cai.
  - Vidro e divisória sob ilha caindo rompem só com `E ≥ R`, sem velocidade mínima.
  - Objeto arremessado decide a ruptura pela energia da componente normal ao contato; com a
    energia total, qualquer arremesso furava a laje da rua.
  - KO ambiental: ilha caindo sobre lutador no chão com percentual ≥ 100. Abaixo disso é
    esmagamento (dano de 10 a 30 e lançamento).
- **Falhas conhecidas:**
  - A marquise flutuante do mapa de teste é tratada como âncora (`pins`).
  - Toda mudança na grade dispara a análise completa (sem análise incremental).
  - A ilha cai rígida e inteira; rotação ficou fora (§23.2).
  - Um corpo lançado para baixo com força costuma abrir cratera na laje da rua. Decidir no playtest.
- **Gates pendentes:**
  1. Playtest humano do M1 e do M2 (dono do projeto): sensação de escudo, esquiva, agarrão,
     arremesso e se o colapso é legível e evitável.
  2. Revisão do Astra do M1 ([pacote_revisao_M1.md](pacote_revisao_M1.md)) continua pendente.
  3. Validação das 11 imagens do lote 01 pelo dono, incluindo a identidade da Faísca e da Brasa e a
     escolha entre pixel art (§9.2) e o acabamento ilustrado da tela de gameplay.
- **Ideia a testar:** assets modelados no Blender (objetos e fixos primeiro), ver [arte/opcao_blender.md](arte/opcao_blender.md).
- **Visão do dono (24/09 noite):** cenário 3D-no-2D via Blender, combos profundos (FighterZ/Sparking Zero/SF) e herói voador de super força com golpes de arrasto e golpe-cena cinematográfico. Registrado em [visao_dono_proximas_prioridades.md](visao_dono_proximas_prioridades.md); ordem a combinar.
- **Plano aprovado (24/09 noite):** [plano_desenvolvimento.md](plano_desenvolvimento.md) — commit e playtest; golpes em dados + combos + knockdown + modo treino; bake-off Blender com o herói; herói completo; grade em chunks e mapa largo; estudo Guilty Gear; depois elenco e gigantes. Repositório privado no GitHub do dono.
- **Próxima ação:** playtest; depois teste de navegabilidade por bot após destruição máxima (§4.6),
  input buffer e coyote time (§5.5) e o bake-off visual do M3 (§19).
