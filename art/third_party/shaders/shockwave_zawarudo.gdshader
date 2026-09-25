// Nome: ZA WARUDO shockwave effect
// Autor: IceTeea
// Fonte: https://godotshaders.com/shader/za-warudo-shockwave-effect/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação: nenhuma na lógica; código transcrito da página. Já usa sintaxe Godot 4
//   (hint_screen_texture). Uso: ColorRect em tela cheia numa CanvasLayer acima do jogo;
//   animar `progress` 0→1 (~12-20 frames) e `center` em UV de tela (x em 0..1; y corrigido
//   pelo aspecto como no código). O miolo invertido (inner_mask) dá o "impact frame" de
//   inversão; remova o mix final se quiser só a onda.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float strength: hint_range(0.0, 0.1) = 0.08;
uniform vec2 center = vec2(0.5, 0.5);

uniform float max_radius = 1.5;

uniform float aberration: hint_range(0.0, 1.0) = 0.425;
uniform float width: hint_range(0.0, 0.1) = 0.04;
uniform float feather: hint_range(0.0, 1.0) = 0.135;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {

	vec2 st = SCREEN_UV;

	float radius = progress * max_radius;

	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	vec2 scaled_st = (st - vec2(0.0, 0.5)) / vec2(1.0, aspect_ratio) + vec2(0.0, 0.5);

	vec2 dist_center = scaled_st - center;

	float dist = length(dist_center);

	float mask = (1.0 - smoothstep(radius - feather, radius, dist)) *
				 smoothstep(radius - width - feather, radius - width, dist);

	// prevent ring appearing when progress = 0
	float activation = smoothstep(0.001, 0.02, progress);
	mask *= activation;

	vec2 offset = normalize(dist_center) * strength * mask;

	vec2 biased_st = scaled_st - offset;

	vec2 abber_vec = offset * aberration * mask;

	vec2 final_st = st * (1.0 - mask) + biased_st * mask;

	vec4 red = texture(SCREEN_TEXTURE, final_st + abber_vec);
	vec4 blue = texture(SCREEN_TEXTURE, final_st - abber_vec);
	vec4 ori = texture(SCREEN_TEXTURE, final_st);

	vec4 distorted = vec4(red.r, ori.g, blue.b, 1.0);

	// inner invert mask
	float inner_mask = (1.0 - smoothstep(radius, radius + feather, dist)) * activation;

	vec4 inverted = vec4(1.0 - ori.rgb, 1.0);

	COLOR = mix(distorted, inverted, inner_mask);
}
