#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer HeightGridBuffer {
    float height_grid[];
} input_buffer;

layout(set = 0, binding = 1, std430) restrict writeonly buffer VertexBuffer {
    float vertices[];
} vertex_buffer;

layout(set = 0, binding = 2, std430) restrict writeonly buffer UvBuffer {
    float uvs[];
} uv_buffer;

layout(set = 0, binding = 3, std430) restrict writeonly buffer IndexBuffer {
    int indices[];
} index_buffer;

layout(push_constant) uniform PushConstants {
    float chunk_size_x;
    float chunk_size_z;
    int resolution;
    int generate_indices;
} params;

void main() {
    uvec2 pixel_coord = gl_GlobalInvocationID.xy;
    if (pixel_coord.x >= params.resolution || pixel_coord.y >= params.resolution) {
        return;
    }
    float u = float(pixel_coord.x) / float(params.resolution - 1);
    float v = float(pixel_coord.y) / float(params.resolution - 1);
    float local_x = (u - 0.5) * params.chunk_size_x;
    float local_z = (v - 0.5) * params.chunk_size_z;
    uint grid_index = pixel_coord.y * params.resolution + pixel_coord.x;
    float height = input_buffer.height_grid[grid_index];
    uint vertex_base = grid_index * 3;
    vertex_buffer.vertices[vertex_base + 0] = local_x;
    vertex_buffer.vertices[vertex_base + 1] = height;
    vertex_buffer.vertices[vertex_base + 2] = local_z;
    uint uv_base = grid_index * 2;
    uv_buffer.uvs[uv_base + 0] = u;
    uv_buffer.uvs[uv_base + 1] = v;
    if (params.generate_indices == 1 && 
        pixel_coord.x < params.resolution - 1 && 
        pixel_coord.y < params.resolution - 1) {
        uint v0 = pixel_coord.y * params.resolution + pixel_coord.x;
        uint v1 = v0 + 1;
        uint v2 = v0 + params.resolution;
        uint v3 = v2 + 1;
        uint quad_index = pixel_coord.y * (params.resolution - 1) + pixel_coord.x;
        uint index_base = quad_index * 6;
        index_buffer.indices[index_base + 0] = int(v0);
        index_buffer.indices[index_base + 1] = int(v1);
        index_buffer.indices[index_base + 2] = int(v2);
        index_buffer.indices[index_base + 3] = int(v1);
        index_buffer.indices[index_base + 4] = int(v3);
        index_buffer.indices[index_base + 5] = int(v2);
    }
}

