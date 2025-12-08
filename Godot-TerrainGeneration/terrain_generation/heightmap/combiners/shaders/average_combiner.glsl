#[compute]
#version 450

// Average combiner for heightmaps
// Averages multiple input images into a single output
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform writeonly image2D output_image;
layout(set = 0, binding = 1, r32f) uniform readonly image2D input_images[8]; // Max 8 images

layout(set = 1, binding = 2, std430) restrict readonly buffer Parameters {
    int width;         // Image width
    int height;        // Image height
    int num_images;    // Number of images to average
} params;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    
    float sum = 0.0;
    
    // Sum all input images
    for (int i = 0; i < params.num_images; i++) {
        float value = imageLoad(input_images[i], pixel_coords).r;
        sum += value;
    }
    
    float result = sum / float(params.num_images);
    imageStore(output_image, pixel_coords, vec4(result, 0.0, 0.0, 0.0));
}

