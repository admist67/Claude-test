shader_type spatial;
render_mode specular_schlick_ggx, cull_back, blend_mix, depth_draw_always;
// Smooth ocean: geometric waves (must match Ocean.height_at in ocean.gd), per-pixel analytic
// normals, two scrolling ripple normal maps, sky reflection by fresnel, crest foam.

uniform vec4 waves[4];          // dir.x, dir.z, amplitude, wavelength
uniform float t;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color = vec3(0.02, 0.12, 0.2);
uniform vec3 scatter_color = vec3(0.05, 0.34, 0.38);
uniform vec3 sky_top = vec3(0.25, 0.55, 0.85);
uniform vec3 sky_horizon = vec3(0.7, 0.85, 0.92);
uniform vec3 foam_color = vec3(0.9, 0.95, 0.95);
uniform float light_level = 1.0;    // 1 day, ~0.15 night (scales scattering and foam)
uniform float ripple_strength = 0.2;
uniform float foam_from = 0.17;

varying vec3 wpos;
varying float hgt;

vec3 wave_sum(vec2 p) {         // x: height, y: d/dx, z: d/dz
	vec3 s = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		float k = 6.2831853 / w.w;
		float ph = k * dot(w.xy, p) - sqrt(9.8 * k) * t;
		s.x += w.z * sin(ph);
		float c = w.z * k * cos(ph);
		s.y += c * w.x;
		s.z += c * w.y;
	}
	return s;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 s = wave_sum(wp.xz);
	VERTEX.y += s.x;
	NORMAL = normalize(vec3(-s.y, 1.0, -s.z));
	wpos = vec3(wp.x, wp.y + s.x, wp.z);
	hgt = s.x;
}

void fragment() {
	vec3 s = wave_sum(wpos.xz);
	vec3 n = normalize(vec3(-s.y, 1.0, -s.z));
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	float fade = clamp(1.0 - dist / 45.0, 0.0, 1.0);
	vec2 uv1 = wpos.xz * 0.032 + t * vec2(0.01, 0.025);
	vec2 uv2 = wpos.xz * 0.07 + t * vec2(-0.02, 0.015);
	vec3 r1 = texture(ripple, uv1).rgb * 2.0 - 1.0;
	vec3 r2 = texture(ripple, uv2).rgb * 2.0 - 1.0;
	vec2 rp = (r1.xy + r2.xy * 0.5) * ripple_strength * (0.15 + 0.85 * fade);
	n = normalize(n + vec3(rp.x, 0.0, -rp.y));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 refl = reflect(-v, n);
	vec3 sky = mix(sky_horizon, sky_top, pow(clamp(refl.y, 0.0, 1.0), 0.6));
	float crest = smoothstep(-0.12, 0.22, hgt);
	vec3 body = deep_color + scatter_color * crest * light_level;
	float nz = texture(noise_tex, wpos.xz * 0.08 + t * 0.01).r;
	float lace = texture(noise_tex, wpos.xz * 0.35 - t * 0.02).r;
	float foam = smoothstep(foam_from, foam_from + 0.1, hgt + (nz - 0.5) * 0.2) * smoothstep(0.55, 0.78, lace * 0.6 + nz * 0.4);
	vec3 col = mix(body, foam_color * light_level, foam * 0.6);
	ALBEDO = col * (1.0 - fres);
	// Slightly see-through: the shark, floats and debris show as shapes below the surface.
	ALPHA = clamp(0.8 + fres * 0.5 + foam * 0.3, 0.0, 1.0);
	EMISSION = sky * fres * (1.0 - foam * 0.8);
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	ROUGHNESS = mix(0.2, 0.5, foam);
	SPECULAR = 0.22;
}
