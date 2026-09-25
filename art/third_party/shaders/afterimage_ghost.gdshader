// Nome: afterimage_ghost (autoria própria)
// Autor: Opus 5.5 para o projeto Fight Destruction, 2026-09-24
// Licença: CC0 (código original deste repositório; sem terceiros)
// Por que existe: não achamos shader de afterimage 2D com licença limpa e estilo não-pixel;
//   a técnica padrão (cópias do quadro atual que desbotam) é trivial e fica aqui.
// Uso: a apresentação instancia 3-5 Sprite2D "fantasma" que copiam textura/frame/flip do
//   lutador a cada 2-3 frames durante dash, lançamento forte ou especial; cada fantasma usa
//   este material com `age` 0→1 ao longo de ~10-16 frames e depois some. Blend aditivo
//   (CanvasItemMaterial não; aqui via render_mode blend_add).
//   ghost_color = acento do lutador (Faísca ciano, Brasa laranja, Bloco âmbar).
shader_type canvas_item;
render_mode blend_add;

uniform vec4 ghost_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;       // 0 = recém-criado, 1 = sumiu
uniform float start_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float edge_boost : hint_range(0.0, 4.0) = 1.5; // realça a borda (rim) do fantasma

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	// borda: alfa do centro menos a média de 4 vizinhos (1 texel)
	float n = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float edge = clamp(src.a - n * 0.25, 0.0, 1.0) * edge_boost;
	float fade = (1.0 - age) * (1.0 - age);
	float a = clamp(src.a * 0.6 + edge, 0.0, 1.0) * start_alpha * fade;
	COLOR = vec4(ghost_color.rgb * a, a);
}
