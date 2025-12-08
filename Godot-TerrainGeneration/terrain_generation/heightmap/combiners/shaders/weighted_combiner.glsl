#[compute]
#version 450

// Weighted combiner for heightmaps
// Combines multiple input images with configurable weights
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform writeonly image2D output_image;
layout(set = 0, binding = 1, r32f) uniform readonly image2D input_images[8]; // Max 8 images

layout(set = 1, binding = 2, std430) restrict readonly buffer Parameters {
    int width;         // Image width
    int height;        // Image height
    int num_images;    // Number of images to combine
    float weights[8];  // Weight for each image
    float total_weight; // Sum of all weights (for normalization)
} params;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    
    float weighted_sum = 0.0;
    
    // Sum all input images with their weights
    for (int i = 0; i < params.num_images; i++) {
        float value = imageLoad(input_images[i], pixel_coords).r;
        weighted_sum += value * params.weights[i];
    }
    
    // Normalize by total weight
    float result = weighted_sum / params.total_weight;
    imageStore(output_image, pixel_coords, vec4(result, 0.0, 0.0, 0.0));
}

