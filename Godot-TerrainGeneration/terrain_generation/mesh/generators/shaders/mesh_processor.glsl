#[compute]
#version 450

// Required extensions for atomic operations on floats
#extension GL_EXT_shader_atomic_float : require

// Work group sizes
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Input/Output buffers
layout(set = 0, binding = 0, std430) restrict buffer VertexBuffer {
    float vertices[];
} vertex_buffer;

layout(set = 0, binding = 1, std430) restrict readonly buffer IndexBuffer {
    int indices[];
} index_buffer;

layout(set = 0, binding = 2, std430) restrict buffer NormalBuffer {
    float normals[];
} normal_buffer;

layout(set = 0, binding = 3, std430) restrict buffer TangentBuffer {
    float tangents[];
} tangent_buffer;

// NOTE: UVs are preserved for texture mapping in the final mesh.
// For heightmap sampling, we calculate UVs from vertex positions (vertex_to_uv)
// since the heightmap represents world space, not texture space.
layout(set = 0, binding = 4, std430) restrict readonly buffer UVBuffer {
    float uvs[];
} uv_buffer;

layout(set = 0, binding = 5, std430) restrict buffer Tan1Buffer {
    float tan1[];
} tan1_buffer;

layout(set = 0, binding = 6, std430) restrict buffer Tan2Buffer {
    float tan2[];
} tan2_buffer;

// Heightmap texture
layout(set = 0, binding = 7) uniform sampler2D heightmap;

// Parameters
layout(set = 0, binding = 8, std430) restrict readonly buffer Parameters {
    float height_scale;
    float mesh_size_x;
    float mesh_size_y;
    uint vertex_count;
    uint index_count;
    uint shader_pass; // 0 = heightmap, 1 = accumulate normals, 2 = finalize normals
} params;

// ============================================================================
// SHARED UTILITY FUNCTIONS
// ============================================================================

vec3 load_vertex(uint vertex_index) {
    uint vertex_base_offset = vertex_index * 3;
    return vec3(
        vertex_buffer.vertices[vertex_base_offset], 
        vertex_buffer.vertices[vertex_base_offset + 1], 
        vertex_buffer.vertices[vertex_base_offset + 2]
    );
}

void store_vertex(uint vertex_index, vec3 vertex_position) {
    uint vertex_base_offset = vertex_index * 3;
    vertex_buffer.vertices[vertex_base_offset] = vertex_position.x;
    vertex_buffer.vertices[vertex_base_offset + 1] = vertex_position.y;
    vertex_buffer.vertices[vertex_base_offset + 2] = vertex_position.z;
}

vec2 load_uv(uint vertex_index) {
    uint uv_base_offset = vertex_index * 2;
    return vec2(uv_buffer.uvs[uv_base_offset], uv_buffer.uvs[uv_base_offset + 1]);
}

vec3 load_normal(uint vertex_index) {
    uint normal_base_offset = vertex_index * 3;
    return vec3(
        normal_buffer.normals[normal_base_offset], 
        normal_buffer.normals[normal_base_offset + 1], 
        normal_buffer.normals[normal_base_offset + 2]
    );
}

void store_normal(uint vertex_index, vec3 normal_vector) {
    uint normal_base_offset = vertex_index * 3;
    normal_buffer.normals[normal_base_offset] = normal_vector.x;
    normal_buffer.normals[normal_base_offset + 1] = normal_vector.y;
    normal_buffer.normals[normal_base_offset + 2] = normal_vector.z;
}

void accumulate_normal(uint vertex_index, vec3 face_normal) {
    uint normal_base_offset = vertex_index * 3;
    atomicAdd(normal_buffer.normals[normal_base_offset], face_normal.x);
    atomicAdd(normal_buffer.normals[normal_base_offset + 1], face_normal.y);
    atomicAdd(normal_buffer.normals[normal_base_offset + 2], face_normal.z);
}

void accumulate_tan1(uint vertex_index, vec3 tangent_vector) {
    uint tangent_base_offset = vertex_index * 3;
    atomicAdd(tan1_buffer.tan1[tangent_base_offset], tangent_vector.x);
    atomicAdd(tan1_buffer.tan1[tangent_base_offset + 1], tangent_vector.y);
    atomicAdd(tan1_buffer.tan1[tangent_base_offset + 2], tangent_vector.z);
}

void accumulate_tan2(uint vertex_index, vec3 bitangent_vector) {
    uint bitangent_base_offset = vertex_index * 3;
    atomicAdd(tan2_buffer.tan2[bitangent_base_offset], bitangent_vector.x);
    atomicAdd(tan2_buffer.tan2[bitangent_base_offset + 1], bitangent_vector.y);
    atomicAdd(tan2_buffer.tan2[bitangent_base_offset + 2], bitangent_vector.z);
}

vec3 load_tan(uint vertex_index, bool is_tan1) {
    uint tangent_base_offset = vertex_index * 3;
    if (is_tan1) {
        return vec3(
            tan1_buffer.tan1[tangent_base_offset], 
            tan1_buffer.tan1[tangent_base_offset + 1], 
            tan1_buffer.tan1[tangent_base_offset + 2]
        );
    } else {
        return vec3(
            tan2_buffer.tan2[tangent_base_offset], 
            tan2_buffer.tan2[tangent_base_offset + 1], 
            tan2_buffer.tan2[tangent_base_offset + 2]
        );
    }
}

void store_tangent(uint vertex_index, vec3 tangent_vector, float handedness) {
    uint tangent_base_offset = vertex_index * 4;
    tangent_buffer.tangents[tangent_base_offset] = tangent_vector.x;
    tangent_buffer.tangents[tangent_base_offset + 1] = tangent_vector.y;
    tangent_buffer.tangents[tangent_base_offset + 2] = tangent_vector.z;
    tangent_buffer.tangents[tangent_base_offset + 3] = handedness;
}

// ============================================================================
// PASS 0: HEIGHTMAP MODIFICATION
// ============================================================================

vec2 vertex_to_uv(vec3 vertex_position) {
    return vec2(
        (vertex_position.x / params.mesh_size_x) + 0.5,
        (vertex_position.z / params.mesh_size_y) + 0.5
    );
}

void heightmap_pass() {
    uint vertex_id = gl_GlobalInvocationID.x;
    if (vertex_id >= params.vertex_count) {
        return;
    }
    vec3 vertex_position = load_vertex(vertex_id);
    vec2 uv_coordinates = vertex_to_uv(vertex_position);
    float sampled_height = texture(heightmap, uv_coordinates).r;
    vertex_position.y = sampled_height * params.height_scale;
    store_vertex(vertex_id, vertex_position);
}

// ============================================================================
// PASS 1: ACCUMULATE NORMALS AND TANGENTS (per-triangle)
// ============================================================================

void accumulate_pass() {
    uint triangle_id = gl_GlobalInvocationID.x;
    uint triangle_count = params.index_count / 3;
    if (triangle_id >= triangle_count) {
        return;
    }
    uint triangle_base_index = triangle_id * 3;
    uint vertex_index_0 = uint(index_buffer.indices[triangle_base_index]);
    uint vertex_index_1 = uint(index_buffer.indices[triangle_base_index + 1]);
    uint vertex_index_2 = uint(index_buffer.indices[triangle_base_index + 2]);
    vec3 vertex_position_0 = load_vertex(vertex_index_0);
    vec3 vertex_position_1 = load_vertex(vertex_index_1);
    vec3 vertex_position_2 = load_vertex(vertex_index_2);
    vec3 edge_vector_1 = vertex_position_1 - vertex_position_0;
    vec3 edge_vector_2 = vertex_position_2 - vertex_position_0;
    vec3 face_normal = normalize(cross(edge_vector_2, edge_vector_1));
    accumulate_normal(vertex_index_0, face_normal);
    accumulate_normal(vertex_index_1, face_normal);
    accumulate_normal(vertex_index_2, face_normal);
    vec2 uv_coord_0 = load_uv(vertex_index_0);
    vec2 uv_coord_1 = load_uv(vertex_index_1);
    vec2 uv_coord_2 = load_uv(vertex_index_2);
    vec2 delta_uv_1 = uv_coord_1 - uv_coord_0;
    vec2 delta_uv_2 = uv_coord_2 - uv_coord_0;
    float uv_determinant = (delta_uv_1.x * delta_uv_2.y - delta_uv_2.x * delta_uv_1.y);
    float tangent_scale_factor = (uv_determinant != 0.0) ? (1.0 / uv_determinant) : 0.0;
    vec3 tangent_vector = normalize(vec3(
        tangent_scale_factor * (delta_uv_2.y * edge_vector_1.x - delta_uv_1.y * edge_vector_2.x),
        tangent_scale_factor * (delta_uv_2.y * edge_vector_1.y - delta_uv_1.y * edge_vector_2.y),
        tangent_scale_factor * (delta_uv_2.y * edge_vector_1.z - delta_uv_1.y * edge_vector_2.z)
    ));
    vec3 bitangent_vector = normalize(vec3(
        tangent_scale_factor * (-delta_uv_2.x * edge_vector_1.x + delta_uv_1.x * edge_vector_2.x),
        tangent_scale_factor * (-delta_uv_2.x * edge_vector_1.y + delta_uv_1.x * edge_vector_2.y),
        tangent_scale_factor * (-delta_uv_2.x * edge_vector_1.z + delta_uv_1.x * edge_vector_2.z)
    ));
    accumulate_tan1(vertex_index_0, tangent_vector);
    accumulate_tan1(vertex_index_1, tangent_vector);
    accumulate_tan1(vertex_index_2, tangent_vector);
    accumulate_tan2(vertex_index_0, bitangent_vector);
    accumulate_tan2(vertex_index_1, bitangent_vector);
    accumulate_tan2(vertex_index_2, bitangent_vector);
}

// ============================================================================
// PASS 2: FINALIZE NORMALS AND TANGENTS (per-vertex)
// ============================================================================

void finalize_pass() {
    uint vertex_id = gl_GlobalInvocationID.x;
    if (vertex_id >= params.vertex_count) {
        return;
    }
    vec3 accumulated_normal = normalize(load_normal(vertex_id));
    vec3 accumulated_tangent = load_tan(vertex_id, true);
    vec3 accumulated_bitangent = load_tan(vertex_id, false);
    vec3 orthogonalized_tangent = normalize(accumulated_tangent - accumulated_normal * dot(accumulated_normal, accumulated_tangent));
    float tangent_handedness = (dot(cross(accumulated_normal, orthogonalized_tangent), accumulated_bitangent) > 0.0) ? 1.0 : -1.0;
    store_normal(vertex_id, accumulated_normal);
    store_tangent(vertex_id, orthogonalized_tangent, tangent_handedness);
}

// ============================================================================
// MAIN DISPATCH
// ============================================================================

void main() {
    if (params.shader_pass == 0) {
        heightmap_pass();
    } else if (params.shader_pass == 1) {
        accumulate_pass();
    } else if (params.shader_pass == 2) {
        finalize_pass();
    }
}
