# AGENTS.md

Fonte de regras para qualquer agente (Claude Code lê via CLAUDE.md).

- Briefing: `Prompt_Mestre_Jogo_2D_Destrutivo.md` (decisões fechadas em §0.1). Estado: `README.md` e `Docs/estado.md`.
- Godot 4.7.2 em `C:\deps\godot-4.7.2\`. Projeto em `game/`.
- Testes: `Testar.bat` ou
  `C:\deps\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path game -- --test --seconds 60`.
  Rodar antes de declarar qualquer mudança em `game/sim/` como pronta.
- Capturas: `Capturar.bat` → `captures/demo/*.png`. Abrir as imagens antes de afirmar algo visual.

Invariantes:
- `game/sim/` só usa inteiros, não usa nós, física do Godot, tempo real ou RNG global. Contrato em `Docs/contrato_sim.md`.
- A apresentação (`game/view/`, `main.gd`) lê estado e escuta `events`; nunca escreve na simulação.
- Scripts são carregados por `preload` (sem `class_name`) para rodar sem importação do editor.
- Mudança que altera hash/replay: registrar e atualizar os testes.
- Atualizar `Docs/estado.md` e o "Estado atual" do README ao fim de cada rodada.
- Não declarar playtest humano a partir de bot, nem arte final a partir de placeholder.
