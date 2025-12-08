#[compute]
#version 450

// Thermal erosion for heightmaps using neighbour-based material flow
// Algorithm:
// 1. Calculate height differences to neighbours
// 2. Material flows downhill when height_diff > talus threshold
// 3. Material is distributed proportionally to downhill neighbours
// 4. Calculate deposition from neighbours in the same pass
// 5. Uses ping-pong textures (handled externally)

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;
layout(set = 1, binding = 2, std430) restrict readonly buffer Parameters {
    int width;             // Image width
    int height;            // Image height
    float talus;           // Talus threshold (minimum slope for material flow)
    float erosion;         // Erosion factor (0.0-1.0)
    float min_diff;        // Minimum height difference (unused but kept for compatibility)
    float max_diff;        // Maximum height difference (unused but kept for compatibility)
    int neighbourhood;      // neighbourhood type (unused on GPU, always uses 8)
} params;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    
    if (pixel_coords.x >= params.width || pixel_coords.y >= params.height) {
        return;
    }
    
    float current_height = imageLoad(input_image, pixel_coords).r;
    
    // 8-neighbour offsets
    const ivec2 neighbour_offsets[8] = ivec2[8](
        ivec2(-1,  0), ivec2(1,  0), ivec2( 0, -1), ivec2( 0,  1),  // Cardinal
        ivec2(-1, -1), ivec2(-1, 1), ivec2( 1, -1), ivec2( 1,  1)   // Diagonal
    );
    
    // ========== PHASE 1: EROSION (material leaving this pixel) ==========
    float total_delta = 0.0;
    float deltas[8];
    
    for (int i = 0; i < 8; i++) {
        ivec2 neighbour_pos = pixel_coords + neighbour_offsets[i];
        neighbour_pos.x = clamp(neighbour_pos.x, 0, params.width - 1);
        neighbour_pos.y = clamp(neighbour_pos.y, 0, params.height - 1);
        
        float neighbour_height = imageLoad(input_image, neighbour_pos).r;
        float height_diff = current_height - neighbour_height;
        
        // Material flows downhill if difference exceeds talus
        if (height_diff > params.talus) {
            deltas[i] = height_diff - params.talus;
            total_delta += deltas[i];
        } else {
            deltas[i] = 0.0;
        }
    }
    
    // Calculate new height after erosion
    float new_height = current_height;
    
    if (total_delta > 0.0) {
        // Total amount of material to move is erosion_factor fraction of total_delta
        float total_material_to_move = params.erosion * total_delta;
        
        // Transfer material proportionally to downhill neighbours
        for (int i = 0; i < 8; i++) {
            if (deltas[i] > 0.0) {
                float transfer = (deltas[i] / total_delta) * total_material_to_move;
                transfer = min(transfer, new_height);  // Can't transfer more than we have left
                new_height -= transfer;
            }
        }
    }
    
    // ========== PHASE 2: DEPOSITION (material coming TO this pixel) ==========
    float accumulated_deposit = 0.0;
    
    for (int i = 0; i < 8; i++) {
        ivec2 neighbour_pos = pixel_coords + neighbour_offsets[i];
        neighbour_pos.x = clamp(neighbour_pos.x, 0, params.width - 1);
        neighbour_pos.y = clamp(neighbour_pos.y, 0, params.height - 1);
        
        float neighbour_height = imageLoad(input_image, neighbour_pos).r;
        float height_diff_from_neighbour = neighbour_height - current_height;
        
        // Check if material flows from neighbour to us
        if (height_diff_from_neighbour > params.talus) {
            // Calculate neighbour's total delta to all its neighbours
            float neighbour_total_delta = 0.0;
            float neighbour_delta_to_us = 0.0;
            
            for (int j = 0; j < 8; j++) {
                ivec2 nn_pos = neighbour_pos + neighbour_offsets[j];
                nn_pos.x = clamp(nn_pos.x, 0, params.width - 1);
                nn_pos.y = clamp(nn_pos.y, 0, params.height - 1);
                
                float nn_height = imageLoad(input_image, nn_pos).r;
                float neighbour_diff = neighbour_height - nn_height;
                
                if (neighbour_diff > params.talus) {
                        contribution_to_us = delta;
                    }
                }
            }

            // Calculate our share of the neighbour's erosion
            if (total_neighbour_delta > 0.0) {
                float transfer = (contribution_to_us / total_neighbour_delta) * params.erosion;
                accumulated_deposit += transfer;
            }
        }
    }

    // Add deposited material
    new_height += accumulated_deposit;

    // Write result
    imageStore(output_image, pixel_coords, vec4(new_height, 0.0, 0.0, 0.0));
}

