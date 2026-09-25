shader_type canvas_item;
// Grade de matéria texturizada (§4.2, nível fino → visual). TEXTURE é a grade 160×60 com
// R = material/255, G = fração de HP, A = 1 se sólido. Cada material amostra sua textura em espaço
// de mundo (tile de `tile_px` px), racha com o dano e ganha contorno onde encosta em vazio.
// Rachadura: `tex_cracks` (ruído "Cracks 1", Screaming Brain Studios, CC0) em espaço de mundo; o limiar
// cai conforme o HP cai, então primeiro aparecem as trincas principais e depois a malha fina (§5.2:
// "rachadura visível comunica" que o segundo impacto rompe).

uniform sampler2D tex_glass : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_drywall : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_brick : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_concrete : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_core : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_rubble : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_street : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_cracks : repeat_enable, filter_linear;
uniform bool has_cracks = false;
uniform float crack_px = 80.0;    // tamanho do tile da rachadura no mundo, em px
uniform int has_tex = 0;          // bit m = textura do material m carregada; bit 7 = rua
uniform vec4 pal[7];              // cor de reserva por material
uniform vec2 grid = vec2(160.0, 60.0);
uniform float cell_px = 8.0;
uniform float tile_px = 64.0;
uniform float street_row = 52.0;

float solid_at(sampler2D g, vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid.x || cell.y >= grid.y) return 0.0;
	return texture(g, (cell + 0.5) / grid).a;
}

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	if (d.a < 0.5) {
		COLOR = vec4(0.0);
	} else {
		int m = int(round(d.r * 255.0));
		vec2 wp = UV * grid * cell_px;
		vec2 tuv = wp / tile_px;
		vec2 cell = floor(UV * grid);
		vec4 col = pal[m];
		if (m == 1 && (has_tex & 2) != 0) col = texture(tex_glass, tuv);
		else if (m == 2 && (has_tex & 4) != 0) col = texture(tex_drywall, tuv);
		else if (m == 3 && (has_tex & 8) != 0) col = texture(tex_brick, tuv);
		else if (m == 4 && cell.y >= street_row && (has_tex & 128) != 0) col = texture(tex_street, tuv);
		else if (m == 4 && (has_tex & 16) != 0) col = texture(tex_concrete, tuv);
		else if (m == 5 && (has_tex & 32) != 0) col = texture(tex_core, tuv);
		else if (m == 6 && (has_tex & 64) != 0) col = texture(tex_rubble, tuv);
		// Dano visível: rachaduras que crescem conforme perde HP (núcleo não sofre dano).
		if (m != 5) {
			float dmg = 1.0 - d.g;
			if (has_cracks) {
				// 0 = sem trinca, 1 = trinca principal. Offset por material para não alinhar tudo.
				float cr = 1.0 - texture(tex_cracks, wp / crack_px + vec2(0.37, 0.61) * float(m)).r;
				// Limiar calibrado pelos percentis da textura: ~1% da área trincada com 10% de dano,
				// ~4% com 50%, ~11% com 85% e ~18% à beira de romper.
				float thr = mix(0.45, 0.14, dmg);
				float line = smoothstep(thr, thr + 0.05, cr) * step(0.03, dmg);
				// Vidro trinca claro (estilhaço); o resto trinca escuro com um lábio claro embaixo.
				vec3 ink = (m == 1) ? vec3(0.92, 0.98, 1.0) : vec3(0.10, 0.07, 0.10);
				float lip = (m == 1) ? 0.0 : smoothstep(thr, thr + 0.05,
					1.0 - texture(tex_cracks, (wp + vec2(0.0, -1.0)) / crack_px + vec2(0.37, 0.61) * float(m)).r) * (1.0 - line);
				col.rgb = mix(col.rgb, col.rgb * 1.25 + 0.06, lip * 0.5 * step(0.03, dmg));
				col.rgb = mix(col.rgb, ink, line);
				col.rgb *= mix(0.8, 1.0, d.g);
			} else {
				col.rgb *= mix(0.45, 1.0, d.g);
			}
		}
		// Contorno de borda quebrada: faixa escura de ~1,5 px onde a célula encosta em vazio.
		vec2 f = fract(UV * grid) * cell_px;
		float edge = 0.0;
		if (solid_at(TEXTURE, cell + vec2(-1.0, 0.0)) < 0.5) edge = max(edge, 1.0 - smoothstep(0.0, 1.5, f.x));
		if (solid_at(TEXTURE, cell + vec2(1.0, 0.0)) < 0.5) edge = max(edge, 1.0 - smoothstep(0.0, 1.5, cell_px - f.x));
		if (solid_at(TEXTURE, cell + vec2(0.0, -1.0)) < 0.5) edge = max(edge, 1.0 - smoothstep(0.0, 1.5, f.y));
		if (solid_at(TEXTURE, cell + vec2(0.0, 1.0)) < 0.5) edge = max(edge, 1.0 - smoothstep(0.0, 1.5, cell_px - f.y));
		col.rgb = mix(col.rgb, vec3(0.08, 0.06, 0.11), edge * 0.85);
		if (m == 1) col.a = 0.78;   // vidro deixa ver o interior
		COLOR = col;
	}
}
