#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer HeightGridBuffer {
    float height_grid[];
} height_buffer;

layout(set = 0, binding = 1, std430) restrict writeonly buffer NormalBuffer {
    float normals[];
} normal_buffer;

layout(set = 0, binding = 2, std430) restrict writeonly buffer TangentBuffer {
    float tangents[];
} tangent_buffer;

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
    float h_left  = get_height(coord.x - 1, coord.y);
    float h_right = get_height(coord.x + 1, coord.y);
    float h_down  = get_height(coord.x, coord.y - 1);
    float h_up    = get_height(coord.x, coord.y + 1);
    vec3 normal = normalize(vec3(
    (h_left - h_right) / (2.0 * params.cell_size_x),
    1.0,
    (h_down - h_up) / (2.0 * params.cell_size_z)
    ));
    vec3 world_x = vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(world_x - normal * dot(normal, world_x));
    float handedness = sign(dot(cross(normal, tangent), vec3(0.0, 0.0, 1.0)));
    if (handedness == 0.0) handedness = 1.0;
    uint index = uint(coord.y * params.resolution + coord.x);
    uint base3 = index * 3;
    normal_buffer.normals[base3 + 0] = normal.x;
    normal_buffer.normals[base3 + 1] = normal.y;
    normal_buffer.normals[base3 + 2] = normal.z;
    uint base4 = index * 4;
    tangent_buffer.tangents[base4 + 0] = tangent.x;
    tangent_buffer.tangents[base4 + 1] = tangent.y;
    tangent_buffer.tangents[base4 + 2] = tangent.z;
    tangent_buffer.tangents[base4 + 3] = handedness;
}
