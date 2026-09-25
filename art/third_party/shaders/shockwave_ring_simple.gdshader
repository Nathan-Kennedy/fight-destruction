// Nome: impact shader (anel de distorção simples)
// Autor: snesmocha
// Fonte: https://godotshaders.com/shader/impact-shader/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação para Godot 4.x (Opus 5.5, 2026-09-24):
//   - SCREEN_TEXTURE embutido (Godot 3) trocado por uniform `screen_texture : hint_screen_texture`.
//   - `vec2(ratio, 1)` → `vec2(ratio, 1.0)` (literal float explícito; o 4.7.2 aceita int, mas fica portável).
// Uso: ColorRect em tela cheia; `center` no mesmo espaço de scaledUV (x ajustado pelo aspecto);
//   animar `size` 0→~0.6 e `force` ~0.03→0 em 10-18 frames. Mais barato que o zawarudo.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center;
uniform float force;
uniform float size;
uniform float thickness;

void fragment(){
	float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
	vec2 scaledUV = (SCREEN_UV - vec2(0.5,0.0)) / vec2(ratio, 1.0) + vec2(0.5,0.0);
	float mask = (1.0 - smoothstep(size-0.1,size, length(scaledUV - center))) *
	smoothstep(size-thickness-0.1,size-thickness, length(scaledUV - center));
	vec2 disp = normalize(scaledUV - center) * force * mask;
	COLOR = texture(screen_texture, SCREEN_UV - disp);
//	COLOR.rgb = vec3(mask);
}
