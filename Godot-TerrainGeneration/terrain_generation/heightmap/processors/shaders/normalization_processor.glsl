#[compute]
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;

layout(set = 1, binding = 0, std430) restrict readonly buffer Params {
    int width;
    int height;
    float min_value;
    float max_value;
    float min_input;
    float max_input;
} params;

void main() {
    ivec2 px = ivec2(gl_GlobalInvocationID.xy);
    if (px.x >= params.width || px.y >= params.height) return;
    float value = imageLoad(input_image, px).r;
    float range_input = params.max_input - params.min_input;
    float range_target = params.max_value - params.min_value;
    float result;
    if (range_input > 0.0001) {
        float normalized = (value - params.min_input) / range_input;
        result = normalized * range_target + params.min_value;
    } else {
        result = (params.min_value + params.max_value) * 0.5;
    }
    imageStore(output_image, px, vec4(result, 0.0, 0.0, 0.0));
}