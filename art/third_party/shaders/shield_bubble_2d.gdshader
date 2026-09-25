// Nome: Hexagon Shield
// Autor: Pan
// Fonte: https://godotshaders.com/shader/hexagon-shield/
// Licença: CC0 (godotshaders.com, conferido em 2026-09-24)
// Adaptação para Godot 4.7 (Opus 5.5, 2026-09-24):
//   - `hint_color` (Godot 3) → `source_color`.
//   - `n_out39p0` era usado sem inicializar (lixo de registrador em alguns drivers):
//     inicializado com vec3(0.0).
//   - `Texture` recebeu `: repeat_enable`. Lógica inalterada (código gerado por VisualShader).
// Uso: ColorRect quadrado centrado no lutador (bolha = círculo inscrito no UV).
//   `Texture` = padrão tileável (hexágonos, ou NoiseTexture2D/abstract noise para uma bolha
//   "elétrica"); `Step` 0.4-0.6 recorta o padrão; `Speed` (x,y) faz o padrão girar na esfera;
//   `Size_Inner` ~0.35, `Size_Outer` ~0.46 dão o aro; `Opaticy` 0.3-0.6.
//   Cor: acento do lutador; ao receber golpe, pulsar Opaticy e escalar o nó 1.0→1.08→1.0.
shader_type canvas_item;
uniform vec4 Color_Shield : source_color;
uniform float Step;
uniform vec3 Speed;
uniform sampler2D Texture : repeat_enable;
uniform float Size_Inner;
uniform float Opaticy;
uniform float Size_Outer;


// SphericalUV

vec2 sphericalFunc(vec2 _uv_shprc1, vec2 _p0s_shprc1, vec2 _rad_shprc1, vec2 _sp1n_shprc1, vec2 _l0c_p0s_shprc1){
	vec2 _temp_p = (_uv_shprc1 - _p0s_shprc1) * 2.0;
	float _temp_rad = length((_temp_p - _l0c_p0s_shprc1) * _rad_shprc1) + 0.0001;
	float _temp_f = (1.0 - sqrt(1.0 - _temp_rad)) / _temp_rad;
	return mod(vec2((_temp_p.x * 0.5 * _temp_f + _sp1n_shprc1.x) + 0.5,
				(_temp_p.y * 0.5 * _temp_f + _sp1n_shprc1.y) + 0.5), vec2(1.0));
}

// TilingAndOffsetUVAnimated

vec2 tilingNoffsetAnimatedFunc(vec2 _uv_tN0A, float _t1me_tN0A, vec2 _offset_tN0A){
	return vec2(mod((_uv_tN0A.x + _offset_tN0A.x * _t1me_tN0A), 1.0), mod((_uv_tN0A.y + _offset_tN0A.y * _t1me_tN0A), 1.0));
}


void vertex() {
// Output:0

}

void fragment() {
// ColorUniform:8
	vec3 n_out8p0 = Color_Shield.rgb;
	float n_out8p1 = Color_Shield.a;

// ScalarUniform:49
	float n_out49p0 = Step;

// SphericalUV:40
	vec3 n_in40p1 = vec3(1.00000, 1.00000, 0.00000);
	vec3 n_in40p2 = vec3(0.00000, 0.00000, 0.00000);
	vec3 n_in40p3 = vec3(0.50000, 0.50000, 0.00000);
	vec3 n_in40p4 = vec3(0.00000, 0.00000, 0.00000);
	vec3 n_out40p0 = vec3(0.0);
	{
		n_out40p0.xy = sphericalFunc(UV.xy, n_in40p3.xy, n_in40p1.xy, n_in40p2.xy, n_in40p4.xy);
	}

// VectorUniform:42
	vec3 n_out42p0 = Speed;

// Input:44
	float n_out44p0 = TIME;

// TilingAndOffsetUVAnimated:39
	vec3 n_out39p0 = vec3(0.0);
	{
		n_out39p0.xy = n_out39p0.xy + tilingNoffsetAnimatedFunc(n_out40p0.xy, n_out44p0, n_out42p0.xy);
	}

// Input:3
	vec3 n_out3p0 = vec3(UV, 0.0);

// Vector:2
	vec3 n_out2p0 = vec3(0.500000, 0.500000, 0.000000);

// Distance:4
	float n_out4p0 = distance(n_out3p0, n_out2p0);

// ScalarOp:5
	float n_in5p0 = 0.50000;
	float n_out5p0 = step(n_in5p0, n_out4p0);

// ScalarOp:9
	float n_in9p0 = 1.00000;
	float n_out9p0 = n_in9p0 - n_out5p0;

// VectorOp:41
	vec3 n_out41p0 = n_out39p0 * vec3(n_out9p0);

// TextureUniform:47
	vec3 n_out47p0;
	float n_out47p1;
	{
		vec4 n_tex_read = texture(Texture, n_out41p0.xy);
		n_out47p0 = n_tex_read.rgb;
		n_out47p1 = n_tex_read.a;
	}

// ScalarOp:28
	float n_out28p0 = step(n_out49p0, dot(n_out47p0, vec3(0.333333, 0.333333, 0.333333)));

// ScalarUniform:11
	float n_out11p0 = Size_Inner;

// ScalarSmoothStep:6
	float n_in6p1 = 0.50000;
	float n_out6p0 = smoothstep(n_out11p0, n_in6p1, n_out4p0);

// ScalarOp:10
	float n_out10p0 = n_out9p0 * n_out6p0;

// ScalarOp:29
	float n_out29p0 = n_out28p0 * n_out10p0;

// ScalarUniform:12
	float n_out12p0 = Opaticy;

// ScalarOp:13
	float n_out13p0 = n_out29p0 * n_out12p0;

// ScalarOp:17
	float n_in17p0 = 0.50000;
	float n_out17p0 = step(n_in17p0, n_out4p0);

// ScalarOp:19
	float n_in19p0 = 1.00000;
	float n_out19p0 = n_in19p0 - n_out17p0;

// ScalarUniform:21
	float n_out21p0 = Size_Outer;

// ScalarSmoothStep:18
	float n_in18p1 = 0.50000;
	float n_out18p0 = smoothstep(n_out21p0, n_in18p1, n_out4p0);

// ScalarOp:20
	float n_out20p0 = n_out19p0 * n_out18p0;

// Scalar:26
	float n_out26p0 = 0.500000;

// ScalarOp:25
	float n_out25p0 = n_out12p0 + n_out26p0;

// ScalarOp:23
	float n_out23p0 = n_out20p0 * n_out25p0;

// ScalarOp:24
	float n_out24p0 = n_out13p0 + n_out23p0;

// ScalarOp:46
	float n_out46p0 = n_out8p1 * n_out24p0;

// ScalarOp:48
	float n_in48p0 = 1.20000;
	float n_out48p0 = n_in48p0 * n_out46p0;

// Output:0
	COLOR.rgb = n_out8p0;
	COLOR.a = n_out48p0;

}
