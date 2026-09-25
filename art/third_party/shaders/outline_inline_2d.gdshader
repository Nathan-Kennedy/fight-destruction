// Nome: 2D outline/inline
// Autor: Juulpower
// Fonte: https://godotshaders.com/shader/2d-outline-inline/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação para Godot 4.7 (Opus 5.5, 2026-09-24):
//   - parâmetro `sampler2D texture` renomeado para `tex` (não sombrear a função embutida texture()).
//   - `pow(width + 0.5, 2)` → `pow(width + 0.5, 2.0)` (literal float explícito; o 4.7.2 aceita int, mas fica portável).
//   Lógica inalterada.
// Uso: material de Sprite2D. Outline externo (#15101C, width 2-4) para destacar o lutador no
//   caos; `inside=true` + cor de acento dá um "rim" interno barato para escudo/estado.
//   Custo cresce com width² — manter width pequeno nos sprites de alta resolução.
shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0);
uniform float width : hint_range(0, 10) = 1.0;
uniform int pattern : hint_range(0, 2) = 0; // diamond, circle, square
uniform bool inside = false;
uniform bool add_margins = true; // only useful when inside is false

void vertex() {
	if (add_margins) {
		VERTEX += (UV * 2.0 - 1.0) * width;
	}
}

bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D tex) {
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float x = abs(i) > width ? width * sign(i) : i;
		float offset;

		if (pattern == 0) {
			offset = width - abs(x);
		} else if (pattern == 1) {
			offset = floor(sqrt(pow(width + 0.5, 2.0) - x * x));
		} else if (pattern == 2) {
			offset = width;
		}

		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);

			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(tex, xy).a <= 0.0) == inside) {
				return true;
			}
		}
	}

	return false;
}

void fragment() {
	vec2 uv = UV;

	if (add_margins) {
		vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0));

		uv = (uv - texture_pixel_size * width) * TEXTURE_PIXEL_SIZE / texture_pixel_size;

		if (uv != clamp(uv, vec2(0.0), vec2(1.0))) {
			COLOR.a = 0.0;
		} else {
			COLOR = texture(TEXTURE, uv);
		}
	} else {
		COLOR = texture(TEXTURE, uv);
	}

	if ((COLOR.a > 0.0) == inside && hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE)) {
		COLOR.rgb = inside ? mix(COLOR.rgb, color.rgb, color.a) : color.rgb;
		COLOR.a += (1.0 - COLOR.a) * color.a;
	}
}
