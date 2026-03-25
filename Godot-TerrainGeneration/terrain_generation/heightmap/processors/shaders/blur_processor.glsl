#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;

layout(set = 1, binding = 2, std430) restrict readonly buffer ParamsAndWeights {
    int radius;
    int width;
    int height;
    int pass;
    float weights[];
} params;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    float sum = 0.0;
    int radius_int = params.radius;
    if (params.pass == 0) {
        for (int k = -radius_int; k <= radius_int; k++) {
            int sample_x = clamp(pixel_coords.x + k, 0, params.width - 1);
            float w = params.weights[k + radius_int];
            float value = imageLoad(input_image, ivec2(sample_x, pixel_coords.y)).r;
            sum += value * w;
        }
    } else {
        for (int k = -radius_int; k <= radius_int; k++) {
            int sample_y = clamp(pixel_coords.y + k, 0, params.height - 1);
            float w = params.weights[k + radius_int];
            float value = imageLoad(input_image, ivec2(pixel_coords.x, sample_y)).r;
            sum += value * w;
        }
    }

    imageStore(output_image, pixel_coords, vec4(sum, 0.0, 0.0, 0.0));
}