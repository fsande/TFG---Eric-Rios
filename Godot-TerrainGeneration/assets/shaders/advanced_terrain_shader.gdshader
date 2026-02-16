shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_opaque, cull_back, diffuse_burley;

uniform float terrain_height = 64.0;
uniform float blend_width = 0.2;
uniform int texture_count;
uniform sampler2DArray albedo_array;
uniform sampler2DArray normal_array;
uniform sampler2DArray roughness_array;
uniform sampler2DArray metallic_array;
uniform sampler2DArray ao_array;
uniform float blend_heights[32];
uniform vec2 uv_scale = vec2(1.0);
uniform float triplanar_sharpness = 4.0;
uniform float slope_start = 0.2;
uniform float slope_end = 0.5;

vec3 blend_normals_rnm(vec3 n1, vec3 n2, float factor) {
    n1 = n1 * 2.0 - 1.0;
    n2 = n2 * 2.0 - 1.0;
    vec3 blended = normalize(mix(n1, n2, factor));
    return blended * 0.5 + 0.5;
}

// Unified triplanar sampling
struct TriplanarWeights {
    vec3 blend;
    vec2 uv_x;
    vec2 uv_y;
    vec2 uv_z;
};

TriplanarWeights calculate_triplanar_weights(vec3 position, vec3 normal, float scale) {
    TriplanarWeights result;
    result.blend = pow(abs(normal), vec3(triplanar_sharpness));
    result.blend /= (result.blend.x + result.blend.y + result.blend.z);
    vec3 scaled_pos = position * scale;
    result.uv_x = scaled_pos.zy;
    result.uv_y = scaled_pos.xz;
    result.uv_z = scaled_pos.xy;
    return result;
}

vec3 sample_triplanar_vec3(sampler2DArray tex_array, int layer, TriplanarWeights weights) {
    vec3 x = texture(tex_array, vec3(weights.uv_x, float(layer))).rgb;
    vec3 y = texture(tex_array, vec3(weights.uv_y, float(layer))).rgb;
    vec3 z = texture(tex_array, vec3(weights.uv_z, float(layer))).rgb;
    return x * weights.blend.x + y * weights.blend.y + z * weights.blend.z;
}

float sample_triplanar_scalar(sampler2DArray tex_array, int layer, TriplanarWeights weights) {
    float x = texture(tex_array, vec3(weights.uv_x, float(layer))).r;
    float y = texture(tex_array, vec3(weights.uv_y, float(layer))).r;
    float z = texture(tex_array, vec3(weights.uv_z, float(layer))).r;
    return x * weights.blend.x + y * weights.blend.y + z * weights.blend.z;
}

vec3 blend_layer_vec3(sampler2DArray tex_array, int lower, int upper, float blend_factor, vec2 uv, TriplanarWeights tri_weights, float tri_factor) {
    vec3 sample1_uv = texture(tex_array, vec3(uv, float(lower))).rgb;
    vec3 sample2_uv = texture(tex_array, vec3(uv, float(upper))).rgb;
    vec3 uv_result = mix(sample1_uv, sample2_uv, blend_factor);
    vec3 sample1_tri = sample_triplanar_vec3(tex_array, lower, tri_weights);
    vec3 sample2_tri = sample_triplanar_vec3(tex_array, upper, tri_weights);
    vec3 tri_result = mix(sample1_tri, sample2_tri, blend_factor);
    return mix(uv_result, tri_result, tri_factor);
}

float blend_layer_scalar(sampler2DArray tex_array, int lower, int upper, float blend_factor, vec2 uv, TriplanarWeights tri_weights, float tri_factor) {
    float sample1_uv = texture(tex_array, vec3(uv, float(lower))).r;
    float sample2_uv = texture(tex_array, vec3(uv, float(upper))).r;
    float uv_result = mix(sample1_uv, sample2_uv, blend_factor);
    float sample1_tri = sample_triplanar_scalar(tex_array, lower, tri_weights);
    float sample2_tri = sample_triplanar_scalar(tex_array, upper, tri_weights);
    float tri_result = mix(sample1_tri, sample2_tri, blend_factor);
    return mix(uv_result, tri_result, tri_factor);
}

void fragment() {
    vec4 world_vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 model_vertex = (inverse(MODEL_MATRIX) * world_vertex).xyz;
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    float slope = 1.0 - abs(dot(world_normal, vec3(0.0, 1.0, 0.0)));
    float triplanar_factor = smoothstep(slope_start, slope_end, slope);
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
    float blend = smoothstep(blend_heights[lower_index], blend_heights[lower_index] + blend_width, height_percent);
    float avg_uv_scale = (uv_scale.x + uv_scale.y) * 0.5;
    float triplanar_scale = avg_uv_scale / terrain_height;
    vec2 scaled_uv = UV * uv_scale;
    TriplanarWeights tri_weights = calculate_triplanar_weights(model_vertex, world_normal, triplanar_scale);
    ALBEDO = blend_layer_vec3(albedo_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
    vec3 normal1_uv = texture(normal_array, vec3(scaled_uv, float(lower_index))).rgb;
    vec3 normal2_uv = texture(normal_array, vec3(scaled_uv, float(upper_index))).rgb;
    vec3 normal_uv = blend_normals_rnm(normal1_uv, normal2_uv, blend);
    vec3 normal1_tri = sample_triplanar_vec3(normal_array, lower_index, tri_weights);
    vec3 normal2_tri = sample_triplanar_vec3(normal_array, upper_index, tri_weights);
    vec3 normal_tri = blend_normals_rnm(normal1_tri, normal2_tri, blend);
    NORMAL_MAP = mix(normal_uv, normal_tri, triplanar_factor);
    ROUGHNESS = blend_layer_scalar(roughness_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
    METALLIC = blend_layer_scalar(metallic_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
    AO = blend_layer_scalar(ao_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
}