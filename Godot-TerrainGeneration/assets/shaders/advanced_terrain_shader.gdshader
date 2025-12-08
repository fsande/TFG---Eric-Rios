shader_type spatial;

const int MAX_TEXTURES = 3;

uniform float height = 64.0;
uniform sampler2D albedo_textures[MAX_TEXTURES];
uniform sampler2D normal_textures[MAX_TEXTURES];
uniform sampler2D roughness_textures[MAX_TEXTURES];

uniform float blend_heights[MAX_TEXTURES - 1];
uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
	vec4 world_vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 model_vertex = (inverse(MODEL_MATRIX) * world_vertex).xyz;
	float height_percent = (model_vertex.y / height);
	int lower_index = 0;
	for (int i = 0; i < MAX_TEXTURES - 1; ++i) {
		if (blend_heights[i] < height_percent) {
			lower_index = i;
		} else {
			break;
		}
	}
	float blend = smoothstep(
		blend_heights[lower_index],
		blend_heights[lower_index] + 0.2,
		height_percent
	);
	ALBEDO = mix(
		texture(albedo_textures[lower_index], UV * uv_scale).rgb,
		texture(albedo_textures[lower_index + 1], UV * uv_scale).rgb,
		blend
	);
	NORMAL_MAP = mix(
		texture(normal_textures[lower_index], UV * uv_scale).xyz,
		texture(normal_textures[lower_index + 1], UV * uv_scale).xyz,
		blend
	);
	ROUGHNESS = mix(
		texture(roughness_textures[lower_index], UV * uv_scale).r,
		texture(roughness_textures[lower_index + 1], UV * uv_scale).r,
		blend
	);
}
