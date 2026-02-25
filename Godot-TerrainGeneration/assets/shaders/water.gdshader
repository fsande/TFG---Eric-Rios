shader_type spatial;
render_mode blend_mix, depth_draw_never, specular_schlick_ggx;

uniform vec3 albedo : source_color;
uniform float metallic : hint_range(0.0, 1.0) = 0;
uniform float roughness : hint_range(0.0, 1.0) = 0.02;

uniform sampler2D texture_normal;
uniform sampler2D texture_normal2;
uniform vec2 wave_direction = vec2(2.0, 0.0);
uniform vec2 wave_direction2 = vec2(0.0, 1.0);
uniform float time_scale : hint_range(0.0, 0.2, 0.005);
uniform float uv_scale : hint_range(0.1, 100.0) = 1.0;

uniform sampler2D foam_noise_texture : hint_default_white;
uniform float foam_noise_scale : hint_range(0.01, 5.0) = 1.0;
uniform float foam_depth_threshold : hint_range(0.0, 10.0) = 1.5;
uniform float foam_noise_speed : hint_range(0.0, 1.0) = 0.05;
uniform vec3 foam_color : source_color = vec3(0.95, 0.97, 1.0);

uniform sampler2D depth_texture : hint_depth_texture;

varying vec2 world_pos;

float compute_depth_difference(vec2 screen_uv, float water_view_z, mat4 inv_proj) {
	float raw_depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	vec4 view_pos = inv_proj * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	return (-view_pos.z) - (-water_view_z);
}

float compute_edge_foam(float depth_diff, vec2 world_uv, vec2 movement) {
	float proximity = 1.0 - smoothstep(0.0, foam_depth_threshold, depth_diff);
	vec2 foam_uv = world_uv * foam_noise_scale + movement * foam_noise_speed;
	float noise = texture(foam_noise_texture, foam_uv).r;
	return proximity * noise;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 world_uv = UV / uv_scale;
	vec2 movement  = TIME * wave_direction  * time_scale;
	vec2 movement2 = TIME * wave_direction2 * time_scale;
	vec3 normal_blend = mix(
		texture(texture_normal,  world_uv + movement).rgb,
		texture(texture_normal2, world_uv + movement2).rgb,
		0.5
	);
	NORMAL_MAP = normal_blend;
	float depth_diff = max(compute_depth_difference(SCREEN_UV, VERTEX.z, INV_PROJECTION_MATRIX), 0.0);
	float foam_mask  = compute_edge_foam(depth_diff, world_uv, movement);
	ALBEDO    = mix(albedo, foam_color, foam_mask);
	METALLIC  = metallic;
	ROUGHNESS = mix(roughness, 0.5, foam_mask);
}
