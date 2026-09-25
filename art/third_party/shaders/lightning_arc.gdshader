// Nome: 2D Lightning, Electric Arc, plasma
// Autor: lumenfruit
// Fonte: https://godotshaders.com/shader/2d-lightning-electric-arc-plasma/
// Licença: MIT (godotshaders.com, conferido em 2026-09-24). Copyright (c) lumenfruit.
//   Texto completo da MIT em art/third_party/shaders/LICENSE.txt (manter com o código).
// Adaptação (Opus 5.5, 2026-09-24): `noiseTexture` recebeu `: repeat_enable` e
//   `color_gradient` recebeu `: repeat_disable` — em Godot 4 o padrão do sampler não repete
//   e o UV do ruído anda com TIME. Lógica inalterada.
// Uso: Sprite2D/ColorRect esticado entre dois pontos (arco horizontal no UV.x, varia em x
//   ao longo de y — girar o nó para alinhar). `color_gradient` = GradientTexture2D horizontal
//   transparente→ciano→branco→ciano→transparente (Faísca). `noiseTexture` = NoiseTexture2D.
shader_type canvas_item;

uniform sampler2D color_gradient : repeat_disable;
uniform sampler2D noiseTexture : repeat_enable;
uniform float speed: hint_range (0.0,5.0);
uniform float variation: hint_range (0.0,1.0);
uniform float width: hint_range (0.0,1.0);

void fragment(){

	vec2 noise_uv = vec2(UV.x+TIME*speed, UV.y-TIME*speed);
	float noise_sample = texture(noiseTexture, noise_uv).r;
	float x_offset = noise_sample*variation - variation/2.0;
	COLOR = texture(color_gradient, vec2((UV.x-0.5)/width + 0.5 + x_offset/width, UV.y));
}
