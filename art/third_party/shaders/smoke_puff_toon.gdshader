// Nome: smoke_puff_toon (autoria própria)
// Autor: Opus 5.5 para o projeto Fight Destruction, 2026-09-24
// Licença: CC0 (código original deste repositório; sem terceiros)
// O que faz: nuvem de fumaça/poeira cel-shaded por ruído (2 tons + contorno escuro),
//   no estilo dos sprites (outline #15101C). Serve para poeira de pouso, fumaça de
//   colapso e rastro de lançamento sem flipbook.
// Uso: Sprite2D/ColorRect quadrado (ou partícula com textura branca quadrada). `noise` =
//   NoiseTexture2D seamless (FastNoiseLite Simplex, freq ~0.02) ou textura de
//   oga_sbs_abstract-noise-pack. Animar `life` 0→1 (cresce, depois se desfaz por erosão).
//   Em GPUParticles2D, ligar `use_particle_life` para usar a idade da partícula (COLOR.a do
//   processo de partícula deve começar em 1).
shader_type canvas_item;

uniform sampler2D noise : repeat_enable;
uniform vec4 light_color : source_color = vec4(0.93, 0.88, 0.84, 1.0);
uniform vec4 shade_color : source_color = vec4(0.62, 0.56, 0.60, 1.0);
uniform vec4 outline_color : source_color = vec4(0.082, 0.063, 0.110, 1.0); // #15101C
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform bool use_particle_life = false;
uniform float outline_width : hint_range(0.0, 0.2) = 0.05;
uniform float scroll_speed = 0.15;
uniform vec2 light_dir = vec2(-0.5, -0.7); // luz do entardecer vindo da esquerda-alto

void fragment() {
	float t = use_particle_life ? 1.0 - COLOR.a : life;
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float n = texture(noise, UV * 0.8 + vec2(0.0, -TIME * scroll_speed)).r;
	// forma: disco que cresce e é corroído pelo ruído com a idade
	float radius = mix(0.55, 0.95, sqrt(t));
	float erosion = mix(0.0, 0.75, t * t);
	float shape = radius - r + (n - 0.5) * 0.45 - erosion * n;
	float body = step(0.0, shape);
	float outline = step(-outline_width, shape) - body;
	// sombreamento em 2 tons: lado oposto à luz fica escuro
	float lit = dot(normalize(p + 1e-4), -normalize(light_dir)) * 0.5 + 0.5;
	float tone = step(0.55, lit + (n - 0.5) * 0.3);
	vec3 col = mix(light_color.rgb, shade_color.rgb, tone);
	col = mix(col, outline_color.rgb, outline);
	float a = max(body, outline) * (1.0 - smoothstep(0.85, 1.0, t));
	COLOR = vec4(col, a);
}
