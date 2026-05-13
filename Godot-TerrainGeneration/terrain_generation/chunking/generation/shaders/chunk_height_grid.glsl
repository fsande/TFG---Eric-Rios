#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D heightmap_texture;

layout(set = 0, binding = 1, std430) restrict writeonly buffer OutputBuffer {
    float heights[];
} output_buffer;

layout(set = 0, binding = 2, std430) restrict readonly buffer DeltaDataBuffer {
    float data[];
} delta_data_buffer;

struct DeltaParams {
    int resolution;
    int data_offset;
    int blend_mode;
    float intensity;
    float bounds_x;
    float bounds_z;
    float bounds_size_x;
    float bounds_size_z;
};

layout(set = 0, binding = 3, std430) restrict readonly buffer DeltaParamsBuffer {
    int delta_count;
    int _pad0;
    int _pad1;
    int _pad2;
    DeltaParams deltas[];
} delta_params_buffer;

layout(push_constant) uniform PushConstants {
    float chunk_pos_x;
    float chunk_pos_z;
    float chunk_size_x;
    float chunk_size_z;
    float terrain_size;
    float height_scale;
    int resolution;
    int padding;
} params;

float sample_delta(int delta_index, float world_x, float world_z) {
    DeltaParams d = delta_params_buffer.deltas[delta_index];
    int res = d.resolution;

    float u = clamp((world_x - d.bounds_x) / d.bounds_size_x, 0.0, 1.0);
    float v = clamp((world_z - d.bounds_z) / d.bounds_size_z, 0.0, 1.0);

    float px = u * float(res - 1);
    float pz = v * float(res - 1);
    int x0 = int(px);
    int z0 = int(pz);
    int x1 = min(x0 + 1, res - 1);
    int z1 = min(z0 + 1, res - 1);
    float fx = px - float(x0);
    float fz = pz - float(z0);

    int base = d.data_offset;
    float h00 = delta_data_buffer.data[base + z0 * res + x0];
    float h10 = delta_data_buffer.data[base + z0 * res + x1];
    float h01 = delta_data_buffer.data[base + z1 * res + x0];
    float h11 = delta_data_buffer.data[base + z1 * res + x1];

    return mix(mix(h00, h10, fx), mix(h01, h11, fx), fz);
}

float apply_blend(float base_height, float delta_value, int blend_mode, float intensity) {
    float scaled = delta_value * intensity;
    switch (blend_mode) {
        case 0: return base_height + scaled;
        case 1: return base_height * scaled;
        case 2: return max(base_height, scaled);
        case 3: return min(base_height, scaled);
        case 4: return scaled;
        default: return base_height + scaled;
    }
}

void main() {
    uvec2 pixel_coord = gl_GlobalInvocationID.xy;
    if (pixel_coord.x >= uint(params.resolution) || pixel_coord.y >= uint(params.resolution)) {
        return;
    }
    float u_local = float(pixel_coord.x) / float(params.resolution - 1);
    float v_local = float(pixel_coord.y) / float(params.resolution - 1);
    float world_x = params.chunk_pos_x + u_local * params.chunk_size_x;
    float world_z = params.chunk_pos_z + v_local * params.chunk_size_z;
    float half_terrain = params.terrain_size * 0.5;
    float map_u = (world_x + half_terrain) / params.terrain_size;
    float map_v = (world_z + half_terrain) / params.terrain_size;
    float height = texture(heightmap_texture, vec2(map_u, map_v)).r * params.height_scale;
    for (int i = 0; i < delta_params_buffer.delta_count; i++) {
        float delta_value = sample_delta(i, world_x, world_z);
        if (abs(delta_value) >= 0.0001) {
            DeltaParams d = delta_params_buffer.deltas[i];
            height = apply_blend(height, delta_value, d.blend_mode, d.intensity);
        }
    }
    output_buffer.heights[pixel_coord.y * uint(params.resolution) + pixel_coord.x] = height;
}
