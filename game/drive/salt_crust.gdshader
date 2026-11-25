// Sebkha salt crust: off-white salt polygons with raised ridges along the
// voronoi cell edges, darker damp mud showing near the water sheets.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D wet_mask : filter_linear;
uniform vec2 area_center;
uniform vec2 area_half;
uniform vec3 salt = vec3(0.93, 0.9, 0.84);
uniform vec3 ridge = vec3(1.0, 0.98, 0.95);
uniform vec3 mud = vec3(0.56, 0.5, 0.44);

varying vec3 wpos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// distance to the nearest voronoi edge
float voronoi_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg, mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++)
	for (int i = -2; i <= 2; i++) {
		vec2 g = mg + vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return md;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - (area_center - area_half)) / (area_half * 2.0);
	float wet = texture(wet_mask, uv).r;
	float e = voronoi_edge(wpos.xz / 1.6);
	float r = 1.0 - smoothstep(0.02, 0.09, e);
	vec3 c = mix(salt, ridge, r);
	// salt thins to damp mud towards the water and at the basin rim
	float damp = smoothstep(0.15, 0.5, wet);
	vec2 edge = abs(uv - 0.5) * 2.0;
	float rim = smoothstep(0.82, 1.0, max(edge.x, edge.y));
	c = mix(c, mud, max(damp * 0.75, rim * 0.6) * (1.0 - r * 0.5));
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// fade the crust edge into the sand around it
	ALPHA = 1.0 - smoothstep(0.86, 1.0, max(edge.x, edge.y));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
