shader_type canvas_item;
// Faixa de chão em perspectiva com parallax (só visual). Cobre a calçada atrás do plano de jogo:
// a borda de baixo (t = 1) é o plano dos lutadores e anda junto com o mundo; a de cima (t = 0) é o
// fundo da calçada, rola mais devagar e tem a textura mais estreita, dando sensação de profundidade.

uniform sampler2D floor_tex : repeat_enable, filter_linear_mipmap;
uniform float has_tex = 0.0;
uniform vec4 base_color : source_color = vec4(0.42, 0.40, 0.44, 1.0);
uniform vec2 rect_pos;          // canto superior esquerdo da faixa, em px de mundo
uniform vec2 rect_size;         // tamanho da faixa, em px de mundo
uniform float cam_x = 0.0;      // centro da câmera em px de mundo
uniform float tile_px = 64.0;   // tamanho do tile na borda da frente
uniform float far_scale = 0.45; // o tile no fundo tem esta fração do tamanho da frente
uniform float far_parallax = 0.55; // o fundo rola com esta fração da câmera a menos

void fragment() {
	float t = UV.y;                                  // 0 = fundo, 1 = frente
	float wx = rect_pos.x + UV.x * rect_size.x;
	float scale = mix(far_scale, 1.0, t);
	// Deslocamento de parallax: no fundo, o chão "fica para trás" em relação à câmera.
	float px = wx + (cam_x - wx) * far_parallax * (1.0 - t);
	// Linhas de profundidade: a coordenada vertical da textura acompanha a perspectiva.
	float depth = (1.0 - pow(1.0 - t, 1.6)) * rect_size.y;
	vec2 uv = vec2(px / (tile_px * scale), depth / (tile_px * scale * 0.6));
	vec4 col = has_tex > 0.5 ? texture(floor_tex, uv) : base_color;
	// Mais longe = mais escuro e mais puxado para a cor do céu ao entardecer.
	col.rgb = mix(col.rgb * 0.55 + vec3(0.10, 0.06, 0.12), col.rgb, 0.35 + 0.65 * t);
	// Meio-fio claro na frente e sombra suave no fundo.
	col.rgb += vec3(0.10) * smoothstep(0.9, 1.0, t);
	col.a = smoothstep(0.0, 0.18, t);
	COLOR = col;
}
