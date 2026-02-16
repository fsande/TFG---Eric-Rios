shader_type spatial;

render_mode
    specular_schlick_ggx,
    depth_draw_opaque,
    cull_back,
    diffuse_burley;

uniform float terrain_height = 64.0;
uniform float blend_width = 0.2;
uniform int texture_count;

uniform sampler2DArray albedo_array;
uniform sampler2DArray normal_array;
uniform sampler2DArray roughness_array;
uniform sampler2DArray metallic_array;
uniform sampler2DArray ao_array;
uniform float blend_heights[32]; // supports up to 32 layers
uniform vec2 uv_scale = vec2(1.0);


vec3 blend_normals_rnm(vec3 n1, vec3 n2, float factor) {
    n1 = n1 * 2.0 - 1.0;
    n2 = n2 * 2.0 - 1.0;
    vec3 blended = normalize(mix(n1, n2, factor));
    return blended * 0.5 + 0.5;
}

void fragment() {
    vec4 world_vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 model_vertex = (inverse(MODEL_MATRIX) * world_vertex).xyz;
    float height_percent = model_vertex.y / terrain_height;
    int lower_index = 0;
    for (int i = 0; i < texture_count - 1; i++) {
        if (height_percent >= blend_heights[i]) {
            lower_index = i;
        } else {
            break;
        }
    }
    int upper_index = min(lower_index + 1, texture_count - 1);
    float blend = smoothstep(
        blend_heights[lower_index],
        blend_heights[lower_index] + blend_width,
        height_percent
    );
    vec2 scaled_uv = UV * uv_scale;
    vec3 albedo1 = texture(albedo_array, vec3(scaled_uv.x, scaled_uv.y, float(lower_index))).rgb;
    vec3 albedo2 = texture(albedo_array, vec3(scaled_uv.x, scaled_uv.y, float(upper_index))).rgb;
    ALBEDO = mix(albedo1, albedo2, blend);
    vec3 normal1 = texture(normal_array, vec3(scaled_uv.x, scaled_uv.y, float(lower_index))).rgb;
    vec3 normal2 = texture(normal_array, vec3(scaled_uv.x, scaled_uv.y, float(upper_index))).rgb;
    NORMAL_MAP = blend_normals_rnm(normal1, normal2, blend);
    float rough1 = texture(roughness_array, vec3(scaled_uv.x, scaled_uv.y, float(lower_index))).r;
    float rough2 = texture(roughness_array, vec3(scaled_uv.x, scaled_uv.y, float(upper_index))).r;
    ROUGHNESS = mix(rough1, rough2, blend);
    float metal1 = texture(metallic_array, vec3(scaled_uv.x, scaled_uv.y, float(lower_index))).r;
    float metal2 = texture(metallic_array, vec3(scaled_uv.x, scaled_uv.y, float(upper_index))).r;
    METALLIC = mix(metal1, metal2, blend);
    float ao1 = texture(ao_array, vec3(scaled_uv.x, scaled_uv.y, float(lower_index))).r;
    float ao2 = texture(ao_array, vec3(scaled_uv.x, scaled_uv.y, float(upper_index))).r;
    AO = mix(ao1, ao2, blend);
}
