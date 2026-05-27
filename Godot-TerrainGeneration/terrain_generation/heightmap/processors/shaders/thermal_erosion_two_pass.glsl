#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_heightmap;
layout(set = 0, binding = 1, r32f) uniform coherent image2D erosion_map;
layout(set = 0, binding = 2, r32f) uniform writeonly image2D output_heightmap;

layout(set = 1, binding = 0, std430) restrict readonly buffer ParamsBuffer {
    int width;
    int height;
    float talus_threshold;
    float erosion_factor;
    float min_height_difference;
    float max_height_difference;
    int pass_number;
    int neighbourhood_type;
} params;

const ivec2 OFFSETS_8[8] = ivec2[](
    ivec2(-1, -1),
    ivec2( 0, -1),
    ivec2( 1, -1),
    ivec2(-1,  0),
    ivec2( 1,  0),
    ivec2(-1,  1),
    ivec2( 0,  1),
    ivec2( 1,  1)
);

const ivec2 OFFSETS_4[4] = ivec2[](
    ivec2( 0, -1),
    ivec2(-1,  0),
    ivec2( 1,  0),
    ivec2( 0,  1)
);

bool is_inside(ivec2 p) {
    return p.x >= 0 &&
           p.y >= 0 &&
           p.x < params.width &&
           p.y < params.height;
}

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    if (!is_inside(coord)) {
        return;
    }
    // PASS 0 - Compute erosion delta
    if (params.pass_number == 0) {
        float current_height = imageLoad(input_heightmap, coord).r;
        float total_height_diff = 0.0;
        float max_height_diff = 0.0;
        float neighbour_diffs[8];
        int valid_count = 0;
        int neighbour_count =
            params.neighbourhood_type == 8 ? 8 : 4;
        for (int i = 0; i < neighbour_count; i++) {
            ivec2 offset =
                params.neighbourhood_type == 8
                ? OFFSETS_8[i]
                : OFFSETS_4[i];
            ivec2 neighbour_coord = coord + offset;
            if (!is_inside(neighbour_coord)) {
                continue;
            }
            float neighbour_height = imageLoad(input_heightmap, neighbour_coord).r;
            float diff = current_height - neighbour_height;
            if (diff > params.talus_threshold) {
                neighbour_diffs[valid_count] = diff;
                total_height_diff += diff;
                max_height_diff = max(max_height_diff, diff);
                valid_count++;
            }
        }
        float delta = 0.0;
        if (valid_count > 0 &&
            total_height_diff > 0.0) {
            float move_amount = params.erosion_factor * (max_height_diff - params.talus_threshold);
            move_amount = clamp(
                move_amount,
                params.min_height_difference,
                params.max_height_difference
            );
            delta = -move_amount;
        }
        imageStore(
            erosion_map,
            coord,
            vec4(delta, 0.0, 0.0, 0.0)
        );
        return;
    }
    // PASS 1 - Apply accumulated erosion/deposition
    float current_height = imageLoad(input_heightmap, coord).r;
    float delta = imageLoad(erosion_map, coord).r;
    float deposited = 0.0;
    int neighbour_count = params.neighbourhood_type == 8 ? 8 : 4;
    for (int i = 0; i < neighbour_count; i++) {
        ivec2 offset =
            params.neighbourhood_type == 8
            ? OFFSETS_8[i]
            : OFFSETS_4[i];
        ivec2 neighbour_coord = coord + offset;
        if (!is_inside(neighbour_coord)) {
            continue;
        }
        float neighbour_height = imageLoad(input_heightmap, neighbour_coord).r;
        float current_diff = neighbour_height - current_height;
        if (current_diff <= params.talus_threshold) {
            continue;
        }
        float neighbour_delta = imageLoad(erosion_map, neighbour_coord).r;
        if (neighbour_delta >= 0.0) {
            continue;
        }
        deposited += (-neighbour_delta) / float(neighbour_count);
    }
    float final_height = clamp(
            current_height + delta + deposited,
            0.0,
            1.0
        );
    imageStore(
        output_heightmap,
        coord,
        vec4(final_height, 0.0, 0.0, 0.0)
    );
}