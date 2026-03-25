shader_type spatial;

uniform float blend_width = 0.2;
uniform int texture_count;
uniform sampler2DArray albedo_array : source_color;
uniform sampler2DArray normal_array : hint_normal;
uniform sampler2DArray orm_array : hint_default_white; // Packed AO (R), Roughness (G), Metallic (B)
uniform sampler2D height_noise: hint_default_white;
uniform float height_noise_strength = 3.0;
uniform float blend_heights[32];
uniform vec2 uv_scale = vec2(1.0);
uniform float triplanar_sharpness = 4.0;
uniform float slope_start = 0.2;
uniform float slope_end = 0.5;
uniform float height_noise_scale = 0.01;
//uniform int cliff_layer_index;
//uniform float cliff_slope_start = 0.4;
//uniform float cliff_slope_end = 0.7;

vec3 blend_normals_rnm(vec3 n1, vec3 n2, float factor) {
	n1 = n1 * 2.0 - 1.0;
	n2 = n2 * 2.0 - 1.0;
	vec3 blended = normalize(mix(n1, n2, factor));
	return blended * 0.5 + 0.5;
}

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
	vec3 uv_result;
	if (blend_factor < 0.01) {
		uv_result = sample1_uv;
	} else if (blend_factor > 0.99) {
		uv_result = texture(tex_array, vec3(uv, float(upper))).rgb;
	} else {
		uv_result = mix(sample1_uv, texture(tex_array, vec3(uv, float(upper))).rgb, blend_factor);
	}
	if (tri_factor < 0.01) {
		return uv_result;
	}
	vec3 sample1_tri = sample_triplanar_vec3(tex_array, lower, tri_weights);
	vec3 tri_result;
	if (blend_factor < 0.01) {
		tri_result = sample1_tri;
	} else if (blend_factor > 0.99) {
		tri_result = sample_triplanar_vec3(tex_array, upper, tri_weights);
	} else {
		tri_result = mix(sample1_tri, sample_triplanar_vec3(tex_array, upper, tri_weights), blend_factor);
	}
	return mix(uv_result, tri_result, tri_factor);
}

vec3 blend_layer_orm(sampler2DArray tex_array, int lower, int upper, float blend_factor, vec2 uv, TriplanarWeights tri_weights, float tri_factor) {
	vec3 sample1_uv = texture(tex_array, vec3(uv, float(lower))).rgb;
	vec3 uv_result;
	if (blend_factor < 0.01) {
		uv_result = sample1_uv;
	} else if (blend_factor > 0.99) {
		uv_result = texture(tex_array, vec3(uv, float(upper))).rgb;
	} else {
		uv_result = mix(sample1_uv, texture(tex_array, vec3(uv, float(upper))).rgb, blend_factor);
	}
	if (tri_factor < 0.01) {
		return uv_result;
	}
	vec3 sample1_tri = sample_triplanar_vec3(tex_array, lower, tri_weights);
	vec3 tri_result;
	if (blend_factor < 0.01) {
		tri_result = sample1_tri;
	} else if (blend_factor > 0.99) {
		tri_result = sample_triplanar_vec3(tex_array, upper, tri_weights);
	} else {
		tri_result = mix(sample1_tri, sample_triplanar_vec3(tex_array, upper, tri_weights), blend_factor);
	}
	return mix(uv_result, tri_result, tri_factor);
}

void fragment() {
	vec4 world_vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 model_vertex = (inverse(MODEL_MATRIX) * world_vertex).xyz;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - abs(dot(world_normal, vec3(0.0, 1.0, 0.0)));
	float triplanar_factor = smoothstep(slope_start, slope_end, slope);
	float noise = texture(height_noise, vec2(world_vertex.x, world_vertex.z) * height_noise_scale).r;
	float effective_height = model_vertex.y + (noise * 2.0 - 1.0) * height_noise_strength;
	int lower_index = 0;
	for (int i = 0; i < texture_count - 1; i++) {
	    if (effective_height >= blend_heights[i]) {
	        lower_index = i;
	    } else {
	        break;
	    }
	}
	int upper_index = min(lower_index + 1, texture_count - 1);
	float blend = smoothstep(
	    blend_heights[lower_index],
	    blend_heights[lower_index] + blend_width,
	    effective_height
	);
	float avg_uv_scale = (uv_scale.x + uv_scale.y) * 0.5;
	float triplanar_scale = avg_uv_scale;
	vec2 scaled_uv = UV * uv_scale;
	TriplanarWeights tri_weights = calculate_triplanar_weights(model_vertex, world_normal, triplanar_scale);
	ALBEDO = blend_layer_vec3(albedo_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
	vec3 normal1_uv = texture(normal_array, vec3(scaled_uv, float(lower_index))).rgb;
	vec3 normal_uv;
	if (blend < 0.01) {
		normal_uv = normal1_uv;
	} else if (blend > 0.99) {
		normal_uv = texture(normal_array, vec3(scaled_uv, float(upper_index))).rgb;
	} else {
		normal_uv = blend_normals_rnm(normal1_uv, texture(normal_array, vec3(scaled_uv, float(upper_index))).rgb, blend);
	}
	if (triplanar_factor < 0.01) {
		NORMAL_MAP = normal_uv;
	} else {
		vec3 normal1_tri = sample_triplanar_vec3(normal_array, lower_index, tri_weights);
		vec3 normal_tri;
		if (blend < 0.01) {
			normal_tri = normal1_tri;
		} else if (blend > 0.99) {
			normal_tri = sample_triplanar_vec3(normal_array, upper_index, tri_weights);
		} else {
			normal_tri = blend_normals_rnm(normal1_tri, sample_triplanar_vec3(normal_array, upper_index, tri_weights), blend);
		}
		NORMAL_MAP = mix(normal_uv, normal_tri, triplanar_factor);
	}
	vec3 orm = blend_layer_orm(orm_array, lower_index, upper_index, blend, scaled_uv, tri_weights, triplanar_factor);
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;

	//float cliff_blend = smoothstep(cliff_slope_start, cliff_slope_end, slope);
	//if (cliff_blend > 0.01) {
	    //vec3 cliff_albedo = sample_triplanar_vec3(albedo_array, cliff_layer_index, tri_weights);
	    //ALBEDO = mix(ALBEDO, cliff_albedo, cliff_blend);
	    //vec3 cliff_normal = sample_triplanar_vec3(normal_array, cliff_layer_index, tri_weights);
	    //NORMAL_MAP = mix(NORMAL_MAP, blend_normals_rnm(NORMAL_MAP, cliff_normal, 1.0), cliff_blend);
	    //vec3 cliff_orm = sample_triplanar_vec3(orm_array, cliff_layer_index, tri_weights);
	    //AO = mix(AO, cliff_orm.r, cliff_blend);
	    //ROUGHNESS = mix(ROUGHNESS, cliff_orm.g, cliff_blend);
	    //METALLIC = mix(METALLIC,  cliff_orm.b, cliff_blend);
	//}
}
