#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer HeightGridBuffer {
    float height_grid[];
} height_buffer;

layout(set = 0, binding = 1, std430) restrict writeonly buffer NormalBuffer {
    float normals[];
} normal_buffer;

layout(push_constant) uniform PushConstants {
    float cell_size_x;
    float cell_size_z;
    int resolution;
    int padding;
} params;

float get_height(int x, int z) {
    x = clamp(x, 0, params.resolution - 1);
    z = clamp(z, 0, params.resolution - 1);
    return height_buffer.height_grid[z * params.resolution + x];
}

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    if (coord.x >= params.resolution || coord.y >= params.resolution) {
        return;
    }
    float h_left = get_height(coord.x - 1, coord.y);
    float h_right = get_height(coord.x + 1, coord.y);
    float h_down = get_height(coord.x, coord.y - 1);
    float h_up = get_height(coord.x, coord.y + 1);
    vec3 normal = normalize(vec3(
        (h_left - h_right) / (2.0 * params.cell_size_x),
        1.0,
        (h_down - h_up) / (2.0 * params.cell_size_z)
    ));
    uint index = coord.y * params.resolution + coord.x;
    uint base = index * 3;
    normal_buffer.normals[base + 0] = normal.x;
    normal_buffer.normals[base + 1] = normal.y;
    normal_buffer.normals[base + 2] = normal.z;
}

