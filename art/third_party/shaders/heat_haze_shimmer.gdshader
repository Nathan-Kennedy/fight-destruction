// Nome: Yoshi's Island Shimmer - Heat Haze Distortion
// Autor: Gerardo LCDF
// Fonte: https://godotshaders.com/shader/yoshis-island-shimmer-heat-haze-distortion/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação: nenhuma; sintaxe Godot 4. Transcrito da página.
// Uso: ColorRect/Sprite2D sobre a área quente (fogo em prédio, explosão, escapamento do
//   Bloco). `noise_texture` = NoiseTexture2D seamless (RG). strength 0.003-0.01.
//   Um BackBufferCopy em modo Rect limita o custo à região do efeito.
shader_type canvas_item;

uniform sampler2D noise_texture : source_color, repeat_enable;
uniform float strength : hint_range(0.0, 0.05, 0.001) = 0.005;
uniform vec2 speed = vec2(0.1, 0.05);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


void fragment() {
    vec2 noise_uv = UV + TIME * speed;

    vec2 offset = (texture(noise_texture, noise_uv).xy * 2.0 - 1.0);

    offset *= strength;
    vec2 distorted_uv = SCREEN_UV + offset;

    COLOR = texture(SCREEN_TEXTURE, distorted_uv);
}
