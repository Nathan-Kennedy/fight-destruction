# Plano de desenvolvimento (aprovado pelo dono em 24/09/2026)

Revisão do plano depois da visão do dono ([visao_dono_proximas_prioridades.md](visao_dono_proximas_prioridades.md)):
combos profundos, herói voador de super força, golpes de arrasto e golpes-cena, lançamentos longos com
perseguição, gigantes no futuro, cenário "3D no 2D" com Blender e estudo de Guilty Gear. O dono concordou
com as mudanças abaixo ("mapa maior, testes em 3D e tudo mais são importantes").

## Mudanças de direção

1. **Ponto de controle e versionamento.** Repositório git privado no GitHub do dono; commit a cada
   rodada que passar nos testes. Playtest do dono sobre a versão atual antes de ampliar o combate.
2. **Personagens e objetos animados pelo Blender (toon 3D renderizado como 2D).** Com 40–80 animações por
   lutador (combos, voo, arrasto, cenas), folhas geradas por IA não escalam (variação de escala/pés entre
   frames, ~11 imagens/h, cota do Codex). IA de imagem passa a servir a conceitos, texturas, fundos e
   referências. O bake-off do Blender ([arte/opcao_blender.md](arte/opcao_blender.md)) é antecipado e
   feito com **um personagem completo** (o herói voador), não só com objetos.
3. **Golpes como dados.** Tabela de golpes sai do código para arquivos de dados: janelas de cancelamento,
   hitboxes por frame, propriedades (lançador, arrasto, wall/ground bounce, agarrão no chão), escalonamento
   de dano no combo; **modo treino** com frame data e contador. Proteção de knockdown por cansaço e opções
   de levantada entram junto (anti-infinito, §5.5).
4. **Mapa grande já na arquitetura.** A grade fixa 160×60 vira **grade em chunks** com mapa largo (vários
   quarteirões) e atualização só do trecho ativo; câmera que acompanha voo longo e reenquadra; regra de
   blast zone compatível com perseguição. Decidir agora, antes de haver conteúdo, porque mexe na sim, no
   hash e no desempenho.
5. **Um único sistema de cena determinística** para golpe-cena (estilo Mortal Kombat), especial-surpresa,
   agarrão no chão e super: roteiro por ticks com resultado fixo na simulação; câmera/VFX/cortes só na
   apresentação; opção de encurtar. Mantém replay e possibilidade de rollback online.
6. **Escopo por fatia.** Primeiro uma fatia jogável completa: 1 quarteirão bonito (cidade v2 em camadas),
   2 lutadores de filosofias opostas (herói voador + Bloco ou um rápido) e combate completo. Gigantes,
   telecinese, elenco maior e distritos extras só depois da fatia validada (§17, §23 do briefing).
7. **Desempenho medido a cada marco.** Hoje ~0,2 ms/tick. Com mapa grande, gigantes e mais física de
   cenário, migrar trechos pesados da sim para C#/GDExtension se as medições pedirem.

## Ordem de execução

| # | Etapa | Entrega verificável |
|---|---|---|
| 1 | Commit de ponto de controle + playtest do dono na versão atual | repositório privado; notas do playtest |
| 2 | Golpes em dados; cadeias e cancelamentos; lançador + perseguição curta + combo aéreo; escalonamento; knockdown com proteção e levantadas; modo treino | testes de determinismo e anti-infinito; modo treino jogável |
| 3 | Bake-off Blender com o herói voador (modelo, rig, 8–12 clips toon) vs folhas IA | lado a lado no jogo; decisão do dono registrada em ADR |
| 4 | Herói completo: voo com limite, super força, golpes de arrasto, golpe-cena | cena determinística com replay idêntico |
| 5 | Grade em chunks + mapa largo + lançamento longo e perseguição pela cidade | teste de navegabilidade no mapa largo; orçamento de tick |
| 6 | Estudo de Guilty Gear ([visão §3d](visao_dono_proximas_prioridades.md)) aplicado à cidade v2 em camadas (Blender + imagens) | `Docs/arte/estudo_guilty_gear.md` + estágio em camadas no jogo |
| 7 | Elenco adicional, telecinese/teleporte, gigantes | depois da fatia validada |

O lote 02 de arte em andamento (limite do Codex) segue para completar o que já foi pedido, mas novas
animações de lutador passam a esperar o resultado do bake-off do Blender.
