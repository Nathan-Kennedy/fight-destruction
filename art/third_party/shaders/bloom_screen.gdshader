// Nome: Bloom
// Autor: VEGAMETA
// Fonte: https://godotshaders.com/shader/bloom/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação (Opus 5.5, 2026-09-24): defaults `= 1` / `= 2` viraram `= 1.0` / `= 2.0`
//   (uniform float com literal float). Lógica inalterada.
// Uso: ColorRect em tela cheia. Caro (81 texelFetch por pixel); preferir o glow nativo do
//   WorldEnvironment (Godot 4 suporta glow em 2D com HDR 2D ligado) e usar este só como
//   fallback ou em viewport reduzido. Bom para "estouro" momentâneo (pulsar bloom_intensity).
shader_type canvas_item;

uniform sampler2D t0 : hint_screen_texture;
uniform float bloom_spread = 1.0;
uniform float bloom_intensity = 2.0;

void fragment() {
	ivec2 size = textureSize(t0, 0);

    float uv_x = SCREEN_UV.x * float(size.x);
    float uv_y = SCREEN_UV.y * float(size.y);

    vec4 sum = vec4(0.0);
    for (int n = 0; n < 9; ++n) {
        uv_y = (SCREEN_UV.y * float(size.y)) + float(bloom_spread * float(n - 4));
        vec4 h_sum = vec4(0.0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) - int(4.0 * bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) - int(3.0 * bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) - int(2.0 * bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) - int(bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) + int(bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) + int(2.0 * bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) + int(3.0 * bloom_spread), int(uv_y)), 0);
        h_sum += texelFetch(t0, ivec2(int(uv_x) + int(4.0 * bloom_spread), int(uv_y)), 0);
        sum += h_sum / 9.0;
    }

    COLOR = texture(t0, SCREEN_UV) + ((sum / 9.0) * bloom_intensity);
}
