#[compute]
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;

layout(set = 1, binding = 0, std430) restrict readonly buffer Params {
    int width;
    int height;
    float target_min;
    float target_max;
    float input_min;
    float input_max;
} params;

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    if (px.x >= params.width || px.y >= params.height) return;
    float value = imageLoad(input_image, px).r;
    float range_input = params.input_max - params.input_min;
    float range_target = params.target_max - params.target_min;
    float result;
    if (range_input > 0.0001) {
        float normalized = (value - params.input_min) / range_input;
        result = clamp(normalized * range_target + params.target_min, params.target_min, params.target_max);
    } else {
        result = (params.target_min + params.target_max) * 0.5;
    }
    imageStore(output_image, px, vec4(result, 0.0, 0.0, 0.0));
}