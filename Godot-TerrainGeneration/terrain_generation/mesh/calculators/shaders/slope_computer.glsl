#[compute]
#version 450

// Compute slope and normal data for terrain meshes on GPU
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Input: vertex buffer (vec3 positions)
layout(set = 0, binding = 0, std430) restrict readonly buffer VertexBuffer {
    float vertices[];
};

// Output: slope/normal image (RGBA32F: RGB=normal, A=slope_angle)
layout(set = 0, binding = 1, rgba32f) uniform restrict writeonly image2D output_image;

// Parameters
layout(set = 0, binding = 2, std430) restrict readonly buffer Params {
    int width;
    int height;
    int vertex_count;
    int padding;
};

// Get vertex position from buffer
vec3 get_vertex(int idx) {
    if (idx < 0 || idx >= vertex_count) {
        return vec3(0.0, 0.0, 0.0);
    }
    int base = idx * 3;
    return vec3(vertices[base], vertices[base + 1], vertices[base + 2]);
}

// Compute surface normal from Moore neighborhood (8-connected neighbors)
vec3 compute_vertex_normal(int vertex_idx, int col, int row) {
    vec3 center = get_vertex(vertex_idx);
    vec3 accumulated_normal = vec3(0.0, 0.0, 0.0);
    int face_count = 0;
    ivec2 neighbor_offsets[8];
    neighbor_offsets[0] = ivec2(1, 0);  
    neighbor_offsets[1] = ivec2(1, -1); 
    neighbor_offsets[2] = ivec2(0, -1); 
    neighbor_offsets[3] = ivec2(-1, -1);  
    neighbor_offsets[4] = ivec2(-1, 0);  
    neighbor_offsets[5] = ivec2(-1, 1);  
    neighbor_offsets[6] = ivec2(0, 1);  
    neighbor_offsets[7] = ivec2(1, 1);    
    for (int i = 0; i < 8; i++) {
        int next_i = (i + 1) % 8;
        ivec2 offset1 = neighbor_offsets[i];
        ivec2 offset2 = neighbor_offsets[next_i];
        int n1_col = col + offset1.x;
        int n1_row = row + offset1.y;
        int n2_col = col + offset2.x;
        int n2_row = row + offset2.y;
        if (n1_col < 0 || n1_col >= width || n1_row < 0 || n1_row >= height) continue;
        if (n2_col < 0 || n2_col >= width || n2_row < 0 || n2_row >= height) continue;
        // Use inverted indexing to match the vertex_index calculation
        int n1_idx = (height - 1 - n1_row) * width + (width - 1 - n1_col);
        int n2_idx = (height - 1 - n2_row) * width + (width - 1 - n2_col);
        if (n1_idx >= vertex_count || n2_idx >= vertex_count) continue;
        vec3 neighbor1 = get_vertex(n1_idx);
        vec3 neighbor2 = get_vertex(n2_idx);
        vec3 v1 = neighbor1 - center;
        vec3 v2 = neighbor2 - center;
        vec3 face_normal = cross(v1, v2);
        float len_sq = dot(face_normal, face_normal);
        if (len_sq > 0.0001) {
            accumulated_normal += normalize(face_normal);
            face_count++;
        }
    }
    if (face_count > 0) {
        return normalize(accumulated_normal);
    }
    return vec3(0.0, 1.0, 0.0);  // Default to up if no valid triangles
}

// Compute slope angle from normal (angle between normal and up vector)
float compute_slope_angle(vec3 normal) {
    // Flat: normal = (0,1,0), angle = 0
    // Vertical: normal = (1,0,0) or (0,0,1), angle = PI/2    
    float up_dot = dot(normal, vec3(0.0, 1.0, 0.0));
    up_dot = clamp(up_dot, -1.0, 1.0);
    float angle = acos(up_dot);
    return angle;
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coord.x >= width || pixel_coord.y >= height) {
        return;
    }
    int col = pixel_coord.x;
    int row = pixel_coord.y;
    int vertex_idx = (height - 1 - row) * width + (width - 1 - col);
    vec3 normal = compute_vertex_normal(vertex_idx, col, row);
    float slope_angle = compute_slope_angle(normal);
    vec4 result = vec4(normal.x, normal.y, normal.z, slope_angle);
    imageStore(output_image, pixel_coord, result);
}

