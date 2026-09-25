# Sons: licenças e origem

Todos os arquivos desta pasta são **CC0 1.0** (domínio público) ou foram **gerados por síntese
procedural** em `tools/audio/build_sfx.py` (ruído filtrado e envelopes, semente fixa, sem material
de terceiros). Atribuição não é obrigatória. Crédito recomendado: Kenney Vleugels (Kenney.nl),
rubberduck, tinyworlds, starninjas, eXpl0it3r, isaiah658, ignasd, artisticdude, faxcorp,
themightyglider, Bart K., pagdev (OpenGameArt).

Os pacotes originais, com `LICENSE.txt`, `origem.json` e a página da fonte, estão em
`art/third_party/` (ver `art/third_party/CATALOGO.md`). Para refazer esta pasta:
`python tools/audio/build_sfx.py` (precisa de numpy, scipy e ffmpeg com libvorbis).

Processamento: mono 44,1 kHz, silêncio aparado, fade curto, pico em -1 dBFS (one-shots); loops com
emenda em crossfade e RMS alvo. "×0,8" = altura/velocidade de fita (0,8 = mais grave).

| Grupo | Origem (pasta em `art/third_party/`) |
|---|---|
| sfx_hit_leve / sfx_hit_forte | kenney_impact-sounds: impactPunch_medium / impactPunch_heavy |
| sfx_hit_grave | síntese (baque senoidal descendente + clique) |
| sfx_whoosh_leve / sfx_whoosh_forte / sfx_esquiva | oga_artisticdude_swishes (swish-N, ×0,7–1,25); whoosh_forte_05 = oga_rubberduck_100-cc0-sfx-2 air_03 |
| sfx_grab / sfx_throw | kenney_rpg-audio: cloth1-3 / clothBelt, clothBelt2 |
| sfx_land / sfx_corpo_impacto | kenney_impact-sounds: footstep_concrete / impactSoft_heavy |
| sfx_escudo_hit | kenney_sci-fi-sounds forceField_000-001; oga_faxcorp_electricity shieldhit |
| sfx_escudo_quebra | oga_tinyworlds_glass-break + kenney_sci-fi-sounds forceField_003 (×0,6) |
| sfx_explosao_carga / sfx_respawn | kenney_sci-fi-sounds forceField_004 / forceField_002 |
| sfx_explosao / sfx_explosao_grave | kenney_sci-fi-sounds explosionCrunch_000-004 / lowFrequency_explosion_000-001 |
| sfx_ko | kenney_sci-fi-sounds lowFrequency_explosion + explosionCrunch (mixados) |
| brk_vidro_impacto / _lasca | kenney_impact-sounds impactGlass_heavy / impactGlass_light |
| brk_vidro_ruptura | oga_rubberduck_75-breaking-falling-hit glass_breaking_01-06; oga_rubberduck_100-cc0-sfx-2 glass_02/03/05 |
| brk_vidro_grande | oga_tinyworlds_glass-break; oga_rubberduck_100-cc0-sfx glass_04/05 |
| brk_vidro_cauda | oga_rubberduck_75-breaking-falling-hit glass_falling_01-04 |
| brk_divisoria_* | kenney_impact-sounds impactPlank_medium / impactWood_light; 75-breaking wood_breaking, breaking_02/03, wood_falling, falling_05/06 |
| brk_tijolo_* | kenney_impact-sounds impactMining (lasca ×1,35); 75-breaking rock_breaking, breaking_01, rock_falling |
| brk_concreto_impacto | 75-breaking hit_02/06/07/12 (×0,8) + síntese sfx_hit_grave |
| brk_concreto_ruptura | 75-breaking rock_breaking (×0,82) + síntese de estalos de pedra |
| brk_concreto_grande | síntese (baque + estalos + ronco de entulho) + 75-breaking rock_falling |
| brk_concreto_cauda / _lasca | 75-breaking rock_falling (×0,85) / kenney_impact-sounds impactMining |
| brk_nucleo_* | kenney_impact-sounds impactMetal_heavy / impactMetal_light |
| brk_entulho_* | oga_rubberduck_100-cc0-sfx-2 stones_01-03 |
| sfx_rangido | síntese (pulsos de atrito em ressonadores, crescendo) + kenney_rpg-audio creak1-3 (×0,55) |
| sfx_desmoronamento | síntese (ronco grave + estalos crescentes) |
| prop_madeira/metal/lata_impacto | kenney_impact-sounds impactWood_heavy / impactMetal_medium / impactTin_medium |
| prop_metal_quebra / prop_metal_hit | 75-breaking metal_falling / metal_hit |
| prop_extintor_jato | oga_rubberduck_100-cc0-sfx-2 air_01/02 |
| fix_vapor_jato / fix_vapor_loop / fix_gas_loop / fix_pavio_loop | oga_bart_steam-release (Marker 1-5; gás ×1,5, pavio ×1,7) |
| fix_agua_loop / fix_hidrante_loop | oga_rubberduck_100-cc0-sfx-2 loop_water_01 / loop_water_03 |
| fix_agua_jorro | oga_rubberduck_40-water-splash splash_03/07/11 |
| fix_extingue | oga_rubberduck_100-cc0-sfx splash_01/02 + oga_bart_steam-release |
| fix_fogo_loop | oga_pagdev_fireplace-loop (trecho de 10 s) |
| fix_fogo_ignicao / fix_queima | kenney_sci-fi-sounds explosionCrunch_002 (×0,6) + thrusterFire |
| fix_eletrico_loop / fix_fiacao_loop | oga_faxcorp_electricity snaploop / crackleelectricityloop |
| fix_neon_loop | oga_themightyglider_electric-buzz |
| fix_faisca | síntese (estalos agudos + zumbido de 120 Hz) |
| fix_choque | síntese (onda quadrada modulada + estalos) + oga_themightyglider_electric-buzz |
| fix_entorta / fix_poste_queda | kenney_impact-sounds impactMetal + kenney_rpg-audio creak3; 75-breaking metal_falling |
| fix_neon_estalo | 75-breaking glass_hit_01/02 |
| sfx_passaros_revoada | síntese (bater de asas: rajadas de ruído em banda) |
| amb_cidade_loop | oga_ignasd_high-traffic-road (rua com trânsito, 57 s em loop) |
| amb_passaros_loop | oga_isaiah658_ambient-birds (29 s em loop) |
| amb_publico_susto | oga_starninjas_crowd-shouting (3 recortes de 2,6 s) |
| amb_publico_aplauso | oga_expl0it3r_applause (3 recortes de 3,5 s) |
