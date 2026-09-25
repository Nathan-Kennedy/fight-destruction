shader_type canvas_item;
// Pós-processo de tela para impacto (§19.3): ondas de choque com distorção, aberração cromática,
// "impact frame" de anime (inversão/alto contraste por 1–3 quadros), speed lines radiais e vinheta.
// Só visual; controlado por vfx_director.gd. Intensidades 0 desligam cada efeito.
// Também: "Finish Zoom" (zoom de tela + tinta vermelha no golpe de KO, só apresentação) e impact
// frame estilo mangá, portado de "Screen-Sampled Black-and-White Manga Hit Impact Post-Process
// Shader" de hailyn (godotshaders.com, CC0; original em art/third_party/shaders/impact_frame_manga).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 waves[4];            // x, y (UV de tela), raio (em altura de tela), força
uniform float aspect = 1.7778;
uniform float chroma = 0.0;       // deslocamento RGB em UV
uniform float impact = 0.0;       // 0..1: mistura com a imagem invertida/contrastada
uniform vec2 impact_center = vec2(0.5);
uniform float lines = 0.0;        // 0..1: speed lines
uniform vec2 lines_center = vec2(0.5);
uniform float time = 0.0;
uniform float vignette = 0.25;
uniform float zoom = 0.0;         // 0..0.3: aproxima a tela em volta de zoom_center (Finish Zoom)
uniform vec2 zoom_center = vec2(0.5);
uniform vec4 tint = vec4(1.0, 0.25, 0.2, 0.0);   // rgb + força (Finish Zoom)
uniform float manga = 0.0;        // 0..1: impact frame mangá centrado em impact_center
const vec3 INK = vec3(0.082, 0.063, 0.110);      // #15101C, contorno dos sprites
const vec3 PAPER = vec3(1.0, 0.95, 0.84);

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (zoom > 0.0) uv = zoom_center + (uv - zoom_center) * (1.0 - zoom);
	if (manga > 0.0) {
		// Zoom curto e tremor do impact frame (mangá).
		vec2 shake = vec2(hash21(vec2(time * 48.0, 1.7)) - 0.5, hash21(vec2(2.3, time * 51.0)) - 0.5) * 0.012 * manga;
		uv = impact_center + (uv - impact_center) * (1.0 - 0.045 * manga) + shake;
	}
	// Ondas de choque: anel que empurra os pixels para fora do centro.
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) continue;
		vec2 d = uv - w.xy;
		d.x *= aspect;
		float dist = length(d);
		float band = 0.035;
		float k = 1.0 - smoothstep(0.0, band, abs(dist - w.z));
		if (dist > 0.0001) uv -= normalize(d) / vec2(aspect, 1.0) * k * w.w * 0.03;
	}
	vec3 col;
	if (chroma > 0.0) {
		vec2 dir = (uv - impact_center) * chroma;
		col.r = texture(screen_tex, uv + dir).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - dir).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	// Brilho no anel da onda (luz âmbar sobre a distorção).
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) continue;
		vec2 d = SCREEN_UV - w.xy;
		d.x *= aspect;
		float k = 1.0 - smoothstep(0.0, 0.012, abs(length(d) - w.z));
		col += vec3(1.0, 0.8, 0.45) * k * w.w * 0.5;
	}
	// Speed lines: raios finos partindo do centro, com ruído por ângulo e tempo.
	if (lines > 0.0) {
		vec2 d = SCREEN_UV - lines_center;
		d.x *= aspect;
		float ang = atan(d.y, d.x);
		float seg = floor((ang + 3.14159) / 6.28318 * 220.0);
		float on = step(0.86, hash(seg + floor(time * 24.0)));
		float r = length(d);
		float fade = smoothstep(0.32, 0.75, r);
		col = mix(col, vec3(1.0), on * fade * lines * 0.25);
	}
	// Impact frame: negativo de alto contraste, com o centro do impacto em branco puro.
	if (impact > 0.0) {
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 inv = vec3(step(0.45, 1.0 - l));
		vec2 d = SCREEN_UV - impact_center;
		d.x *= aspect;
		inv = max(inv, vec3(1.0 - smoothstep(0.0, 0.08, length(d))));
		col = mix(col, inv, impact);
	}
	// Finish Zoom: tinta vermelha por cima, mais forte nas bordas (o centro fica legível).
	if (tint.a > 0.0) {
		vec2 d = SCREEN_UV - zoom_center;
		d.x *= aspect;
		float edge = smoothstep(0.05, 0.6, length(d));
		float l = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, tint.rgb * (0.6 + 0.9 * l), tint.a * (0.35 + 0.65 * edge));
	}
	// Impact frame mangá: P&B posterizado, linhas radiais quebradas, trincas e flash no centro.
	if (manga > 0.0) {
		vec2 dir = SCREEN_UV - impact_center;
		dir.x *= aspect;
		float dist = length(dir);
		float g = dot(col, vec3(0.299, 0.587, 0.114));
		// Original: (g - 0.5) × 2,6. A cena do entardecer é escura; centrar em 0,3 deixa mais "papel".
		g = clamp((g - 0.3) * 2.4 + 0.5, 0.0, 1.0);
		vec3 ink = mix(INK, PAPER, floor(g * 3.0) / 3.0);
		float ang = atan(dir.y, dir.x);
		float raw = abs(sin(ang * 72.0 + dist * 24.0 - time * 18.0));
		float mask = smoothstep(0.08, 0.30, dist) * (1.0 - smoothstep(0.78, 1.05, dist));
		float broken = step(0.18, hash21(vec2(floor(ang * 24.0), floor(dist * 18.0))));
		float sl = smoothstep(0.82, 1.0, raw) * mask * broken;
		float crack = step(0.91, hash21(vec2(floor(ang * 18.0), floor(dist * 32.0))))
			* smoothstep(0.12, 0.5, dist) * (1.0 - smoothstep(0.5, 0.9, dist));
		ink = mix(ink, INK, clamp(sl + crack, 0.0, 1.0));
		ink = mix(ink, vec3(1.0), (1.0 - smoothstep(0.0, 0.38, dist)) * 0.35);
		ink *= 1.0 - smoothstep(0.18, 0.95, dist) * 0.55;
		col = mix(col, ink, manga);
	}
	// Vinheta suave para enquadrar a ação.
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - vignette * dot(v, v) * 1.6;
	COLOR = vec4(col, 1.0);
}
