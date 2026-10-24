shader_type spatial;
// Faceted low-poly ocean. The wave sum must match Ocean.height_at() in ocean.gd.

uniform vec4 waves[4];          // dir.x, dir.z, amplitude, wavelength
uniform float t;
uniform vec3 deep = vec3(0.05, 0.38, 0.5);
uniform vec3 shallow = vec3(0.12, 0.6, 0.66);
uniform vec3 foam = vec3(0.9, 0.93, 0.88);
uniform vec3 sky = vec3(0.65, 0.86, 0.92);
uniform float foam_from = 0.42;

varying flat float h;
varying float hs;

float wave_h(vec2 p) {
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		float k = 6.2831853 / w.w;
		s += w.z * sin(k * dot(w.xy, p) - sqrt(9.8 * k) * t);
	}
	return s;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = wave_h(wp.xz);
	hs = h;
	VERTEX.y += h;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	vec3 col = mix(deep, shallow, smoothstep(-0.45, 0.45, h));
	col = mix(col, foam, smoothstep(foam_from, foam_from + 0.1, hs) * 0.7);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 5.0);
	col = mix(col, sky, fres * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.55;
	SPECULAR = 0.25;
}
