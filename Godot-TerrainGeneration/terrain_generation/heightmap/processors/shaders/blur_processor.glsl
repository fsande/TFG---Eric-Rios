#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;

layout(set = 1, binding = 0, std430) restrict readonly buffer ParamsBuffer {
    int radius;
    int width;
    int height;
    int pass;
} params;

layout(set = 2, binding = 0, std430) restrict readonly buffer WeightsBuffer {
    float weights[];
} weights_buf;

shared float shared_weights[33];

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 local_id = ivec2(gl_LocalInvocationID.xy);
    int linear_local_id = local_id.y * 16 + local_id.x;
    int radius = params.radius;
    int kernel_size = radius * 2 + 1;
    if (linear_local_id < kernel_size) {
        shared_weights[linear_local_id] = weights_buf.weights[linear_local_id];
    }
    barrier();
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    float sum = 0.0;
    if (params.pass == 0) {
        for (int k = -radius; k <= radius; k++) {
            int sample_x = clamp(pixel_coords.x + k, 0, params.width - 1);
            sum += imageLoad(input_image, ivec2(sample_x, pixel_coords.y)).r * shared_weights[k + radius];
        }
    } else {
        for (int k = -radius; k <= radius; k++) {
            int sample_y = clamp(pixel_coords.y + k, 0, params.height - 1);
            sum += imageLoad(input_image, ivec2(pixel_coords.x, sample_y)).r * shared_weights[k + radius];
        }
    }
    imageStore(output_image, pixel_coords, vec4(sum, 0.0, 0.0, 0.0));
}