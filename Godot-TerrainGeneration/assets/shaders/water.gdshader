shader_type spatial;

uniform vec3 albedo: source_color;
uniform float metallic: hint_range(0.0, 1.0) = 0;
uniform float roughness: hint_range(0.0, 1.0) = 0.02;

uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;

uniform vec2 wave_direction = vec2(2.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.0, 1.0);
uniform float time_scale: hint_range(0.0, 0.2, 0.005);
uniform float uv_scale: hint_range(0.1, 100.0) = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 world_uv = world_pos / uv_scale;

	vec2 movement = (TIME * wave_direction) * time_scale;
	vec2 movement2 = (TIME * wave_direction2) * time_scale;

	vec3 normal_blend = mix(texture(texture_normal, world_uv + movement).rgb,
	texture(texture_normal2, world_uv + movement2).rgb, 0.5);

	NORMAL_MAP = normal_blend;
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
