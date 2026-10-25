// Island ground: tiling sand and grass (CC0 ambientCG Ground080, Grass004) in the island's
// own space, so the texture rides along when it drifts. COLOR.r = grass, COLOR.g = wet.
shader_type spatial;

uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scale = 0.3;

varying vec2 uv_local;

void vertex() {
	uv_local = VERTEX.xz * scale;
}

void fragment() {
	vec3 sand = texture(sand_tex, uv_local).rgb;
	vec3 grass = texture(grass_tex, uv_local * 1.4).rgb * vec3(0.95, 1.05, 0.85);
	vec3 c = mix(sand, grass, smoothstep(0.0, 1.0, COLOR.r));
	c *= mix(1.0, 0.6, COLOR.g);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, COLOR.g);
}
