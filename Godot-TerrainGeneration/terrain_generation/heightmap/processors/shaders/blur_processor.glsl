#[compute]
#version 450

// Separable box blur for heightmaps
// Uses two-pass approach: horizontal then vertical
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;
layout(set = 1, binding = 2, std430) restrict readonly buffer Parameters {
    float radius;      // Blur radius
    int width;         // Image width
    int height;        // Image height
    int pass;          // 0 = horizontal, 1 = vertical
} params;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    
    int half_size = int(params.radius);
    float sum = 0.0;
    int count = 0;
    
    if (params.pass == 0) {
        for (int offset_x = -half_size; offset_x <= half_size; offset_x++) {
            int sample_x = clamp(pixel_coords.x + offset_x, 0, params.width - 1);
            float value = imageLoad(input_image, ivec2(sample_x, pixel_coords.y)).r;
            sum += value;
            count++;
        }
    } else {
        for (int offset_y = -half_size; offset_y <= half_size; offset_y++) {
            int sample_y = clamp(pixel_coords.y + offset_y, 0, params.height - 1);
            float value = imageLoad(input_image, ivec2(pixel_coords.x, sample_y)).r;
            sum += value;
            count++;
        }
    }
    
    float result = sum / float(count);
    imageStore(output_image, pixel_coords, vec4(result, 0.0, 0.0, 0.0));
}