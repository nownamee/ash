extends RefCounted
# Матеріал «рідка магма» для останнього (13-го) рівня магмової броні.
# Шейдер малює темну кірку з розпеченими жилами лави, які повільно течуть і пульсують: броня ніби вилита з магми, що переливається.
# Візерунок рахується з локальних координат меша + TIME, тому не потребує текстур. Параметр variation зсуває візерунок,
# щоб сусідні деталі броні не виглядали копіями одна одної.

const SHADER_CODE := """
shader_type spatial;

uniform vec4 crust_color : source_color = vec4(0.07, 0.02, 0.012, 1.0);
uniform vec4 lava_color : source_color = vec4(1.0, 0.32, 0.03, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.86, 0.30, 1.0);
uniform float flow_speed = 0.42;
uniform float pattern_scale = 8.0;
uniform float glow = 2.4;
uniform float variation = 0.0;

varying vec3 lpos;

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i + vec3(0.0, 0.0, 0.0)), hash13(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float t = TIME * flow_speed;
	vec3 p = lpos * pattern_scale + vec3(variation * 7.3, variation * 3.1, variation * 5.7);
	// лава «стікає» вниз і трохи закручується (деформація координат шумом)
	vec3 q = vec3(
		fbm(p + vec3(0.0, -t, 0.0)),
		fbm(p + vec3(5.2, 1.3, -t * 0.7)),
		fbm(p + vec3(2.1, -t * 0.5, 7.7)));
	float n = fbm(p + 1.9 * q + vec3(0.0, -t * 1.3, 0.0));
	// жили розпеченої лави там, де шум проходить крізь середину діапазону
	float vein = 1.0 - abs(n * 2.0 - 1.0);
	float lava = smoothstep(0.58, 0.92, vein);
	float core = smoothstep(0.86, 0.99, vein);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2 + n * 9.0 + variation * 3.0);
	vec3 col = mix(crust_color.rgb, lava_color.rgb, lava);
	col = mix(col, hot_color.rgb, core);
	ALBEDO = mix(crust_color.rgb, col, 0.55);
	ROUGHNESS = mix(0.85, 0.35, lava);
	EMISSION = col * (lava * 0.9 + 0.08) * glow * pulse + hot_color.rgb * core * 0.9;
}
"""

static var _shader: Shader

static func make(variation: float = 0.0, glow: float = 2.4) -> ShaderMaterial:
    if _shader == null:
        _shader = Shader.new()
        _shader.code = SHADER_CODE
    var m := ShaderMaterial.new()
    m.shader = _shader
    m.set_shader_parameter("variation", variation)
    m.set_shader_parameter("glow", glow)
    return m
