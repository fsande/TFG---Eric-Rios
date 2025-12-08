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
    vec3 surface_normal = vec3(0.0, 0.0, 0.0);
    int cross_count = 0;
    
    // Sample neighbors and compute face normals using cross products
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            
            int nx = col + dx;
            int ny = row + dy;
            
            // Check bounds
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            
            int nidx = ny * width + nx;
            if (nidx >= vertex_count) continue;
            
            vec3 neighbor1 = get_vertex(nidx);
            
            // Get second neighbor for cross product
            int dx2 = (dx >= 0) ? dx + 1 : dx - 1;
            int dy2 = dy;
            int nx2 = col + dx2;
            int ny2 = row + dy2;
            
            // If out of bounds, try vertical neighbor
            if (nx2 < 0 || nx2 >= width || ny2 < 0 || ny2 >= height) {
                dx2 = dx;
                dy2 = (dy >= 0) ? dy + 1 : dy - 1;
                nx2 = col + dx2;
                ny2 = row + dy2;
                
                if (nx2 < 0 || nx2 >= width || ny2 < 0 || ny2 >= height) continue;
            }
            
            int nidx2 = ny2 * width + nx2;
            if (nidx2 >= vertex_count) continue;
            
            vec3 neighbor2 = get_vertex(nidx2);
            
            // Compute face normal via cross product
            vec3 v1 = neighbor1 - center;
            vec3 v2 = neighbor2 - center;
            vec3 face_normal = cross(v1, v2);
            
            float len_sq = dot(face_normal, face_normal);
            if (len_sq > 0.0001) {
                surface_normal += normalize(face_normal);
                cross_count++;
            }
        }
    }
    
    if (cross_count > 0) {
        surface_normal /= float(cross_count);
        return normalize(surface_normal);
    }
    return vec3(0.0, 1.0, 0.0);
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
    
    // Check bounds
    if (pixel_coord.x >= width || pixel_coord.y >= height) {
        return;
    }
    
    int col = pixel_coord.x;
    int row = pixel_coord.y;
    int vertex_idx = row * width + col;
    
    // Compute normal and slope
    vec3 normal = compute_vertex_normal(vertex_idx, col, row);
    float slope_angle = compute_slope_angle(normal);
    
    // Store result (RGB=normal, A=slope_angle in radians)
    vec4 result = vec4(normal.x, normal.y, normal.z, slope_angle);
    imageStore(output_image, pixel_coord, result);
}

