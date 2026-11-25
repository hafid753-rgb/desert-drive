// Sheet water on the sebkha: very shallow, mirror-flat, sky-tinted, with
// wind ripples; only where the wet mask is set.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform sampler2D wet_mask : filter_linear;
uniform vec2 area_center;
uniform vec2 area_half;
uniform vec3 tint = vec3(0.52, 0.64, 0.72);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - (area_center - area_half)) / (area_half * 2.0);
	float wet = texture(wet_mask, uv).r;
	float a = smoothstep(0.45, 0.55, wet);
	if (a < 0.01) { discard; }
	float t = TIME;
	vec2 p = wpos.xz;
	float rx = sin(p.x * 1.7 + t * 2.1) * 0.5 + sin(p.y * 2.3 - t * 1.6 + p.x * 0.6) * 0.5;
	float rz = cos(p.y * 1.9 + t * 1.8) * 0.5 + sin(p.x * 2.9 + t * 2.4) * 0.5;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(rx * 0.05, 0.0, rz * 0.05, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * (0.55 + 0.45 * fres);
	METALLIC = 0.0;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	ALPHA = a * (0.8 + 0.2 * fres);
}
