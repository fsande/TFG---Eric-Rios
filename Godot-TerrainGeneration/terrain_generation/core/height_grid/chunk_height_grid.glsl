#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D base_heightmap;

layout(set = 0, binding = 1, std430) restrict writeonly buffer HeightGridBuffer {
    float height_grid[];
} output_buffer;

layout(set = 0, binding = 2, std430) restrict readonly buffer DeltaTextures {
    float delta_data[];
} delta_buffer;

layout(set = 0, binding = 3, std430) restrict readonly buffer DeltaParams {
    int delta_count;
    int delta_resolution;
    float delta_bounds_min_x;
    float delta_bounds_min_z;
    float delta_bounds_size_x;
    float delta_bounds_size_z;
    float delta_intensity;
    int blend_mode;
} delta_params;

layout(push_constant) uniform PushConstants {
    float chunk_bounds_min_x;
    float chunk_bounds_min_z;
    float chunk_bounds_size_x;
    float chunk_bounds_size_z;
    float terrain_size;
    float height_scale;
    int resolution;
    int padding;
} params;

float sample_delta_bilinear(vec2 world_pos) {
    if (delta_params.delta_count == 0) {
        return 0.0;
    }
    float u = (world_pos.x - delta_params.delta_bounds_min_x) / delta_params.delta_bounds_size_x;
    float v = (world_pos.y - delta_params.delta_bounds_min_z) / delta_params.delta_bounds_size_z;
    if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) {
        return 0.0;
    }
    int res = delta_params.delta_resolution;
    float px = u * float(res - 1);
    float py = v * float(res - 1);
    int x0 = int(floor(px));
    int y0 = int(floor(py));
    int x1 = min(x0 + 1, res - 1);
    int y1 = min(y0 + 1, res - 1);
    float fx = px - float(x0);
    float fy = py - float(y0);
    float h00 = delta_buffer.delta_data[y0 * res + x0];
    float h10 = delta_buffer.delta_data[y0 * res + x1];
    float h01 = delta_buffer.delta_data[y1 * res + x0];
    float h11 = delta_buffer.delta_data[y1 * res + x1];
    float h0 = mix(h00, h10, fx);
    float h1 = mix(h01, h11, fx);
    return mix(h0, h1, fy) * delta_params.delta_intensity;
}

float apply_blend(float existing, float delta, int mode) {
    if (mode == 0) {
        return existing + delta;
    } else if (mode == 1) {
        return existing * delta;
    } else if (mode == 2) {
        return max(existing, delta);
    } else if (mode == 3) {
        return min(existing, delta);
    } else if (mode == 4) {
        return delta;
    }
    return existing + delta;
}

void main() {
    uvec2 pixel_coord = gl_GlobalInvocationID.xy;
    if (pixel_coord.x >= params.resolution || pixel_coord.y >= params.resolution) {
        return;
    }
    float u = float(pixel_coord.x) / float(params.resolution - 1);
    float v = float(pixel_coord.y) / float(params.resolution - 1);
    float world_x = params.chunk_bounds_min_x + u * params.chunk_bounds_size_x;
    float world_z = params.chunk_bounds_min_z + v * params.chunk_bounds_size_z;
    float half_terrain = params.terrain_size / 2.0;
    float tex_u = (world_x + half_terrain) / params.terrain_size;
    float tex_v = (world_z + half_terrain) / params.terrain_size;
    tex_u = clamp(tex_u, 0.0, 1.0);
    tex_v = clamp(tex_v, 0.0, 1.0);
    float base_height = texture(base_heightmap, vec2(tex_u, tex_v)).r;
    float height = base_height * params.height_scale;
    float delta_value = sample_delta_bilinear(vec2(world_x, world_z));
    if (abs(delta_value) >= 0.0001) {
        height = apply_blend(height, delta_value, delta_params.blend_mode);
    }
    uint index = pixel_coord.y * params.resolution + pixel_coord.x;
    output_buffer.height_grid[index] = height;
}

