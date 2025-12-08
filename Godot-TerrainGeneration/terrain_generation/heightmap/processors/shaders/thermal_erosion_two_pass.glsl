#[compute]
#version 450

// Required extensions for atomic operations on floats
#extension GL_EXT_shader_atomic_float : require

// Two-pass thermal erosion for heightmaps using atomic operations
// Pass 0: Calculate erosion, atomically deposit to neighbours, store outgoing erosion
// Pass 1: Apply stored erosion/deposition values

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_heightmap;
layout(set = 0, binding = 1, r32f) uniform coherent image2D intermediate_buffer;  // For atomic operations
layout(set = 0, binding = 2, r32f) uniform coherent image2D output_heightmap;

layout(set = 1, binding = 3, std430) restrict readonly buffer Parameters {
    int width;
    int height;
    float talus_threshold;
    float erosion_factor;
    float min_height_difference;
    float max_height_difference;
    int pass;  // 0 = calculate erosion, 1 = apply erosion and deposition
    int neighbourhood_type;  // Unused on GPU, always uses 8
} params;

const int neighbour_count = 8;

// 8-neighbour offsets (matching CPU implementation)
const ivec2 neighbour_offsets[8] = ivec2[8](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1,  0),                ivec2(1,  0),
    ivec2(-1,  1), ivec2(0,  1), ivec2(1,  1)
);


void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    
    if (params.pass == 0) {
        // ========== PASS 0: Calculate and Distribute Erosion ==========
        float current_height = imageLoad(input_heightmap, pixel_coords).r;
        float total_delta = 0.0;
        float deltas[neighbour_count];
        
        // Calculate height differences to neighbours that exceed talus threshold
        for (int i = 0; i < neighbour_count; i++) {
            ivec2 neighbour_pos = pixel_coords + neighbour_offsets[i];
            neighbour_pos.x = clamp(neighbour_pos.x, 0, params.width - 1);
            neighbour_pos.y = clamp(neighbour_pos.y, 0, params.height - 1);
            
            float neighbour_height = imageLoad(input_heightmap, neighbour_pos).r;
            float height_diff = current_height - neighbour_height;
            
            // Only consider neighbours lower than current pixel beyond talus threshold
            if (height_diff > params.talus_threshold) {
                deltas[i] = height_diff - params.talus_threshold;
                total_delta += deltas[i];
            } else {
                deltas[i] = 0.0;
            }
        }
        
        // Calculate total erosion amount to distribute
        float erosion_amount = 0.0;
        if (total_delta > 0.0) {
            // Use max delta approach (matching CPU implementation)
            float summed_deltas = 0.0;
            for (int i = 0; i < neighbour_count; i++) {
                summed_deltas += deltas[i];
            }
            erosion_amount = params.erosion_factor * summed_deltas;
        }
        
        float new_height = current_height - erosion_amount;
        new_height = clamp(new_height, 0.0, 1.0);
        //imageStore(output_heightmap, pixel_coords, vec4(0.0, 0.0, 0.0, 0.0));
                
        // Now atomically distribute erosion to neighbours as deposits
        if (erosion_amount > 0.0) {
            for (int i = 0; i < neighbour_count; i++) {
                if (deltas[i] > 0.0) {
                    ivec2 neighbour_pos = pixel_coords + neighbour_offsets[i];
                    neighbour_pos.x = clamp(neighbour_pos.x, 0, params.width - 1);
                    neighbour_pos.y = clamp(neighbour_pos.y, 0, params.height - 1);
                    
                    float deposit_amount = (deltas[i] / total_delta) * erosion_amount;
                    
                    // Atomically add deposit to neighbour
                    imageAtomicAdd(intermediate_buffer, neighbour_pos, deposit_amount);
                }
            }
        }
        
    } else if (params.pass == 1) {
        // ========== PASS 1: Apply Deposition ==========
        float current_height = imageLoad(input_heightmap, pixel_coords).r;
        
        float height_change = imageLoad(intermediate_buffer, pixel_coords).r;        
        // Apply the change
        float new_height = current_height + height_change;
        new_height = clamp(new_height, 0.0, 1.0);
        
        imageStore(output_heightmap, pixel_coords, vec4(new_height, 0.0, 0.0, 0.0));
    }
}
