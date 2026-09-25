// Nome: Hit Flash Effect Shader (estendido)
// Autor original: triangledevv
// Fonte: https://godotshaders.com/shader/hit-flash-effect-shader/
// Licença: MIT (godotshaders.com, conferido em 2026-09-24). Copyright (c) triangledevv.
//   Texto completo da MIT em art/third_party/shaders/LICENSE.txt (manter com o código).
// Adaptação (Opus 5.5, 2026-09-24):
//   - o original não compilava (faltava `;` após `white_color`).
//   - `bool active` virou `flash_amount` (0..1) + `flash_color`, para rampa e cor por tipo de
//     golpe; `active` mantido por compatibilidade (força amount=1).
//   - multiplica por COLOR (preserva modulate do nó).
// Uso: material do Sprite2D do lutador. No acerto: flash_amount=1 durante o hitstop
//   (ou 2-4 frames), depois 0. Branco para golpe normal, cor de acento para golpe forte.
shader_type canvas_item;

uniform bool active = false;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 previous_color = texture(TEXTURE, UV) * COLOR;
	float amount = active ? 1.0 : flash_amount;
	vec3 flashed = mix(previous_color.rgb, flash_color.rgb, amount * flash_color.a);
	COLOR = vec4(flashed, previous_color.a);
}
