shader_type spatial;

uniform float blend_width = 0.2;
uniform int texture_count;

uniform sampler2DArray albedo_array : source_color;
uniform sampler2DArray normal_array : hint_normal;
uniform sampler2DArray roughness_array : hint_default_white;
uniform sampler2DArray metallic_array : hint_default_white;
uniform sampler2DArray ao_array : hint_default_white;

uniform sampler2DArray splatmaps : hint_default_white;
uniform int splatmap_count; // = ceil(texture_count / 4)

uniform vec2 uv_scale = vec2(1.0);
uniform float triplanar_sharpness = 4.0;
uniform float slope_start = 0.2;
uniform float slope_end = 0.5;

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

vec4 sample_triplanar(sampler2DArray tex, int layer, TriplanarWeights w) {
 vec4 x = texture(tex, vec3(w.uv_x, float(layer)));
 vec4 y = texture(tex, vec3(w.uv_y, float(layer)));
 vec4 z = texture(tex, vec3(w.uv_z, float(layer)));
 return x * w.blend.x + y * w.blend.y + z * w.blend.z;
}

vec4 sample_layer(sampler2DArray tex, int layer, vec2 uv, TriplanarWeights tw, float tri_factor) {
 vec4 uv_s = texture(tex, vec3(uv, float(layer)));
 vec4 tri_s = sample_triplanar(tex, layer, tw);
 return mix(uv_s, tri_s, tri_factor);
}

vec3 blend_normals_rnm(vec3 n1, vec3 n2, float t) {
 n1 = n1 * 2.0 - 1.0;
 n2 = n2 * 2.0 - 1.0;
 return normalize(mix(n1, n2, t)) * 0.5 + 0.5;
}

void fragment() {
 vec4 world_vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
 vec3 model_vertex = (inverse(MODEL_MATRIX) * world_vertex).xyz;
 vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
 float slope = 1.0 - abs(dot(world_normal, vec3(0.0, 1.0, 0.0)));
 float tri_factor = smoothstep(slope_start, slope_end, slope);
 float avg_uv_scale = (uv_scale.x + uv_scale.y) * 0.5;
 vec2 scaled_uv = UV * uv_scale;
 TriplanarWeights tw = calculate_triplanar_weights(
 model_vertex, world_normal, avg_uv_scale / 64.0
 );
 vec3 out_albedo = vec3(0.0);
 vec3 out_normal = vec3(0.0);
 float out_rough = 0.0;
 float out_metal = 0.0;
 float out_ao = 0.0;
 float total_weight = 0.0;
 for (int s = 0; s < 8; s++) {
 if (s >= splatmap_count) break;
 vec4 w = texture(splatmaps, vec3(UV, float(s)));
 for (int c = 0; c < 4; c++) {
 int layer = s * 4 + c;
 if (layer >= texture_count) break;
 float weight = w[c];
 if (weight < 0.001) continue;
 out_albedo += sample_layer(albedo_array, layer, scaled_uv, tw, tri_factor).rgb * weight;
 out_normal += sample_layer(normal_array, layer, scaled_uv, tw, tri_factor).rgb * weight;
 out_rough += sample_layer(roughness_array, layer, scaled_uv, tw, tri_factor).r * weight;
 out_metal += sample_layer(metallic_array, layer, scaled_uv, tw, tri_factor).r * weight;
 out_ao += sample_layer(ao_array, layer, scaled_uv, tw, tri_factor).r * weight;
 total_weight += weight;
 }
 }

 if (total_weight > 0.001) {
 float inv = 1.0 / total_weight;
 out_albedo *= inv;
 out_normal *= inv;
 out_rough *= inv;
 out_metal *= inv;
 out_ao *= inv;
 }
 ALBEDO = out_albedo;
 NORMAL_MAP = out_normal;
 ROUGHNESS = out_rough;
 METALLIC = out_metal;
 AO = out_ao;
}