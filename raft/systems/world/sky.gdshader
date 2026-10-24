shader_type sky;
// Day/night sky: gradient, sun and moon discs, stars at night, drifting clouds.
// Colors and directions come from DayNight.

uniform vec3 top_color = vec3(0.25, 0.55, 0.85);
uniform vec3 horizon_color = vec3(0.7, 0.85, 0.92);
uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);
uniform vec3 sun_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.0, -0.7, 0.7);
uniform float night = 0.0;
uniform vec3 cloud_lit = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade = vec3(0.7, 0.75, 0.82);
uniform float cloud_cover = 0.48;
uniform float t;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float e = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(e, 0.0, 1.0), 0.5));
	col = mix(col, vec3(0.01, 0.07, 0.11) * (0.3 + 0.7 * (1.0 - night)), smoothstep(0.0, -0.06, e));
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color * (pow(sd, 900.0) * 14.0 + pow(sd, 12.0) * 0.28 + pow(sd, 3.0) * 0.06);
	if (night > 0.01) {
		vec3 cell = floor(d * 220.0);
		float h = hash(cell);
		float tw = 0.6 + 0.4 * sin(t * 2.0 + h * 40.0);
		col += vec3(step(0.9972, h) * night * tw * smoothstep(0.02, 0.25, e));
		float md = dot(d, normalize(moon_dir));
		col += vec3(0.85, 0.9, 1.0) * (smoothstep(0.99955, 0.9997, md) * 1.2 + pow(max(md, 0.0), 60.0) * 0.12) * night;
	}
	if (e > 0.0) {
		vec2 uv = d.xz / (e + 0.12) * 0.22 + t * vec2(0.0025, 0.0012);
		float n = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * 2.7 + 0.3).r * 0.35;
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n) * smoothstep(0.0, 0.12, e);
		float lit = clamp(0.5 + 0.5 * dot(d, normalize(sun_dir)), 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, lit * (1.0 - (n - 0.5)));
		col = mix(col, cc, c * 0.92);
	}
	COLOR = col;
}
