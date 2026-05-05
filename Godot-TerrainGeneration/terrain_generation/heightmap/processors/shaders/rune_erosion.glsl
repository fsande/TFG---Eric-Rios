#[compute]
#version 450
/*
=====================================================================================

Advanced terrain erosion filter based on stacked faded gullies.
Ported from the Shadertoy implementation by Runevision to a Godot compute shader.

For more on the technique, see:
  https://www.youtube.com/watch?v=gsJHzBTPG0Y
  https://blog.runevision.com/2026/03/fast-and-gorgeous-erosion-filter.html

Phacelle Noise function copyright (c) 2025 Rune Skovbo Johansen
Advanced Terrain Erosion Filter copyright (c) 2025 Rune Skovbo Johansen
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

=====================================================================================
*/

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform readonly image2D input_image;
layout(set = 0, binding = 1, r32f) uniform writeonly image2D output_image;

layout(set = 1, binding = 2, std430) restrict readonly buffer Params {
    int width;
    int height;
    int octaves;
    int _pad;
    float strength;
    float gully_weight;
    float detail;
    float rounding_ridge;
    float rounding_crease;
    float rounding_initial_mult;
    float rounding_octave_mult;
    float onset_initial;
    float onset_octave;
    float onset_ridge_initial;
    float onset_ridge_octave;
    float assumed_slope_value;
    float assumed_slope_amount;
    float scale;
    float lacunarity;
    float gain;
    float cell_scale;
    float normalization;
    float height_offset;
    float height_offset_fade_blend;
} parameters;


// -----------------------------------------------------------------------------
// UTILITY
// -----------------------------------------------------------------------------

#define TAU 6.28318530717959

float clamp01(float t) { return clamp(t, 0.0, 1.0); }

float pow_inv(float t, float power) {
    // Flip, raise to the specified power, and flip back.
    return 1.0 - pow(1.0 - clamp01(t), power);
}

float ease_out(float t) {
    // Flip by subtracting from one.
    float v = 1.0 - clamp01(t);
    // Raise to a power of two and flip back.
    return 1.0 - v * v;
}

float smooth_start(float t, float smoothing) {
    if (t >= smoothing)
    return t - 0.5 * smoothing;
    return 0.5 * t * t / smoothing;
}

vec2 safe_normalize(vec2 n) {
    // A div-by-zero-safe replacement for normalize.
    float length_n = length(n);
    return (abs(length_n) > 1e-10) ? (n / length_n) : n;
}

vec2 hash(in vec2 integer_pos) {
    const vec2 k = vec2(0.3183099, 0.3678794);
    integer_pos = integer_pos * k + k.yx;
    return -1.0 + 2.0 * fract(16.0 * k * fract(integer_pos.x * integer_pos.y * (integer_pos.x + integer_pos.y)));
}

// -----------------------------------------------------------------------------
// PHACELLE NOISE FUNCTION
// -----------------------------------------------------------------------------

// The Simple Phacelle Noise function produces a stripe pattern aligned with the input vector.
// The name Phacelle is a portmanteau of phase and cell, since the function produces a phase by
// interpolating cosine and sine waves from multiple cells.
//  - pos: the input point being evaluated.
//  - stripe_direction: direction of the stripes at this point. It must be a normalized vector.
//  - stripe_frequency: frequency of the stripes within each cell. It's best to keep it close to
//    1.0, as high values will produce distortions and other artifacts.
//  - phase_offset: phase offset of the stripes, where 1.0 is a full cycle.
//  - normalization: degree of normalization applied, between 0 and 1. With e.g. a value of
//    0.4, raw output with a magnitude below 0.6 won't get fully normalized to a magnitude of 1.0.
// Phacelle Noise function copyright (c) 2025 Rune Skovbo Johansen
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
vec4 PhacelleNoise(in vec2 pos, vec2 stripe_direction, float stripe_frequency, float phase_offset, float normalization) {
    // Get a vector orthogonal to the stripe direction, with a
    // magnitude proportional to the frequency of the stripes.
    vec2 perpendicular_dir = stripe_direction.yx * vec2(-1.0, 1.0) * stripe_frequency * TAU;
    phase_offset *= TAU;
    // Iterate over 4x4 cells, calculating a stripe pattern for each and blending between them.
    // pos_integer is the integer part of the current coordinate pos, pos_fraction is the remainder.
    //
    // o   o   o   o
    //
    // o   o   o   o
    //       pos
    // o   i   o   o
    //
    // o   o   o   o
    //
    // pos: current coordinate    i: integer part of pos    o: grid points for 4x4 cells
    //
    vec2 pos_integer = floor(pos);
    vec2 pos_fraction = fract(pos);
    vec2 weighted_phase = vec2(0.0); // Accumulates weighted cosine (x) and sine (y) contributions.
    float total_weight = 0.0;
    for (int i = -1; i <= 2; i++) {
        for (int j = -1; j <= 2; j++) {
            vec2 cell_offset = vec2(i, j);
            // Calculate a cell point by starting off with a point in the integer grid.
            vec2 cell_grid_point = pos_integer + cell_offset;
            // Calculate a random jitter for the cell point, between -0.5 and 0.5 on each axis.
            vec2 cell_jitter = hash(cell_grid_point) * 0.5;
            // The final cell point (we don't store it) is cell_grid_point plus cell_jitter.
            // Calculate a vector representing the input point relative to this cell point:
            // pos - (cell_grid_point + cell_jitter)
            // = (pos_fraction + pos_integer) - ((pos_integer + cell_offset) + cell_jitter)
            // = pos_fraction + pos_integer - pos_integer - cell_offset - cell_jitter
            // = pos_fraction - cell_offset - cell_jitter
            vec2 cell_to_pos = pos_fraction - cell_offset - cell_jitter;
            // Bell-shaped weight function which is 1 at dist 0 and nearly 0 at dist 1.5.
            // Due to the random jitter of up to 0.5, the closest a cell point not in the 4x4
            // grid can be to the current point pos is 1.5 units away.
            float sq_distance = dot(cell_to_pos, cell_to_pos);
            float cell_weight = exp(-sq_distance * 2.0);
            // Subtract 0.01111 to make the function actually 0 at distance 1.5, which avoids
            // some (very subtle) grid line artefacts.
            cell_weight = max(0.0, cell_weight - 0.01111);
            // Keep track of the total sum of weights.
            total_weight += cell_weight;
            // The wave_phase is a gradient which increases in value along perpendicular_dir. Its
            // rate of change is stripe_frequency times tau, due to the multiplier pre-applied to
            // perpendicular_dir.
            float wave_phase = dot(cell_to_pos, perpendicular_dir) + phase_offset;
            // Add this cell's cosine and sine wave contributions to the blended result.
            weighted_phase += vec2(cos(wave_phase), sin(wave_phase)) * cell_weight;
        }
    }
    // Get the raw blended value (x = cosine blend, y = sine blend).
    vec2 blended_wave = weighted_phase / total_weight;
    // Interpret the blended wave as a 2D vector; its length is the magnitude of the output.
    float wave_magnitude = sqrt(dot(blended_wave, blended_wave));
    // Apply a lower threshold to preserve small magnitudes we're going to fully normalize.
    wave_magnitude = max(1.0 - normalization, wave_magnitude);
    // Return:
    //   xy: normalized cosine (x) and sine (y) — used as height offset and slope indicator.
    //   zw: perpendicular_dir — multiply with sine to get the spatial derivative of the cosine.
    return vec4(blended_wave / wave_magnitude, perpendicular_dir);
}


// Advanced Terrain Erosion Filter copyright (c) 2025 Rune Skovbo Johansen
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
vec4 ErosionFilter(
    in vec2 pos, vec3 height_and_slope, float fade_target,
    float erosion_strength, float gully_weight, float detail_level,
    vec4 rounding_params, vec4 onset_params, vec2 assumed_slope,
    float erosion_scale, int octaves, float lacunarity,
    float gain, float cell_scale, float normalization,
    out float ridge_map
) {
    erosion_strength *= erosion_scale;
    fade_target = clamp(fade_target, -1.0, 1.0);
    vec3 input_height_and_slope = height_and_slope;
    // Current frequency, starting at one cell per (erosion_scale * cell_scale) UV units.
    float current_freq = 1.0 / (erosion_scale * cell_scale);
    float slope_magnitude = max(length(height_and_slope.yz), 1e-10);
    float accumulated_magnitude = 0.0;
    float rounding_multiplier = 1.0;
    // Initial rounding blends between crease rounding (y) and ridge rounding (x) based on
    // fade_target, then is scaled by rounding_params.z to compensate for frequency mismatch
    // between the input height function and the erosion.
    float initial_rounding = mix(rounding_params.y, rounding_params.x, clamp01(fade_target + 0.5)) * rounding_params.z;
    // The combined accumulating erosion mask. Starts based on initial slope and is updated
    // each octave. Controls where erosion is allowed to take effect (flat areas are masked out).
    float erosion_mask = ease_out(smooth_start(slope_magnitude * onset_params.x, initial_rounding * onset_params.x));
    // Initialize the ridge map tracking variables.
    float ridge_mask = ease_out(slope_magnitude * onset_params.z);
    float ridge_fade_target = fade_target;
    // Determine the initial gully direction from a blend of the actual terrain slope and an
    // assumed slope. A fixed assumed slope can produce more natural gully directions when the
    // final eroded terrain differs significantly from the input.
    vec2 gully_direction = mix(
    height_and_slope.yz,
    height_and_slope.yz / slope_magnitude * assumed_slope.x,
    assumed_slope.y
    );
    for (int i = 0; i < octaves; i++) {
        // Calculate and add gullies to the height and slope.
        vec4 noise_sample = PhacelleNoise(pos * current_freq, safe_normalize(gully_direction), cell_scale, 0.25, normalization);
        // Multiply with freq since p was multiplied with freq.
        // Negate since we use slope directions that point down.
        noise_sample.zw *= -current_freq;
        // Amount of slope as value from 0 to 1.
        float slope_amount = abs(noise_sample.y);
        // Add non-masked, normalized slope to gully_direction, for use by subsequent octaves.
        // It's normalized to use the steepest part of the sine wave everywhere.
        gully_direction += sign(noise_sample.y) * noise_sample.zw * erosion_strength * gully_weight;
        // noise_sample.x is the cosine: the height offset contribution of this gully (-1 to 1).
        // noise_sample.y * noise_sample.zw is the spatial derivative of that cosine (slope delta).
        vec3 gully_offset = vec3(noise_sample.x, noise_sample.y * noise_sample.zw);
        // Fade the gully offset toward fade_target in areas where erosion_mask is low
        // (i.e. flat terrain, ridge tops, valley floors), leaving them unmodified by gully shape.
        vec3 masked_gully_offset = mix(vec3(fade_target, 0.0, 0.0), gully_offset * gully_weight, erosion_mask);
        height_and_slope += masked_gully_offset * erosion_strength;
        accumulated_magnitude += erosion_strength;
        fade_target = masked_gully_offset.x;
        // Compute rounding for this octave: blends between crease/ridge rounding based on
        // the cosine output (positive = ridge-like, negative = crease-like).
        float octave_rounding = mix(rounding_params.y, rounding_params.x, clamp01(noise_sample.x + 0.5)) * rounding_multiplier;
        float octave_mask = ease_out(smooth_start(slope_amount * onset_params.y, octave_rounding * onset_params.y));
        // Raise erosion_mask to detail_level power (inverted via pow_inv), causing it to fall
        // off faster on flat areas when detail_level is high (more octaves restricted to slopes).
        erosion_mask = pow_inv(erosion_mask, detail_level) * octave_mask;
        // Update the ridge map accumulation
        ridge_fade_target = mix(ridge_fade_target, gully_offset.x, ridge_mask);
        float ridge_octave_mask = ease_out(slope_amount * onset_params.w);
        ridge_mask = ridge_mask * ridge_octave_mask;
        // Prepare next octave
        erosion_strength *= gain;
        current_freq *= lacunarity;
        rounding_multiplier *= rounding_params.w;
    }
    // The ridge_map is the accumulated gully cosine value, attenuated where ridge_mask never
    // fell to zero (i.e. flat terrain where gully classification was ambiguous).
    ridge_map = ridge_fade_target * (1.0 - ridge_mask);
    // Return the total delta applied to height_and_slope, plus the accumulated magnitude.
    vec3 height_slope_delta = height_and_slope - input_height_and_slope;
    return vec4(height_slope_delta, accumulated_magnitude);
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    if (pixel_coord.x >= parameters.width || pixel_coord.y >= parameters.height) return;
    // Sample height and compute UV-space slope via central differences
    ivec2 left = ivec2(max(pixel_coord.x - 1, 0), pixel_coord.y);
    ivec2 right = ivec2(min(pixel_coord.x + 1, parameters.width - 1), pixel_coord.y);
    ivec2 down = ivec2(pixel_coord.x, max(pixel_coord.y - 1, 0));
    ivec2 up = ivec2(pixel_coord.x, min(pixel_coord.y + 1, parameters.height - 1));
    float center_height = imageLoad(input_image, pixel_coord).r;
    float left_height = imageLoad(input_image, left).r;
    float right_height = imageLoad(input_image, right).r;
    float down_height = imageLoad(input_image, down).r;
    float up_height = imageLoad(input_image, up).r;
    // Convert pixel-space central differences to UV-space derivatives (dHeight/dUV),
    // so that the erosion scale parameter is meaningful in the same coordinate space
    // as the UV position passed to the filter below.
    float dheight_dx = (right_height - left_height) * 0.5 * float(parameters.width);
    float dheight_dy = (up_height - down_height) * 0.5 * float(parameters.height);
    vec3 height_and_slope = vec3(center_height, dheight_dx, dheight_dy);
    vec2 uv_pos = (vec2(pixel_coord) + 0.5) / vec2(float(parameters.width), float(parameters.height));
    // The height is in [0, 1]; remap to [-1, 1].
    float fade_target = clamp(center_height * 2.0 - 1.0, -1.0, 1.0);
    // Apply erosion filter
    float ridge_map;
    vec4 erosion_result = ErosionFilter(
        uv_pos, height_and_slope, fade_target,
        parameters.strength, parameters.gully_weight, parameters.detail,
        vec4(parameters.rounding_ridge, parameters.rounding_crease, parameters.rounding_initial_mult, parameters.rounding_octave_mult),
        vec4(parameters.onset_initial, parameters.onset_octave, parameters.onset_ridge_initial, parameters.onset_ridge_octave),
        vec2(parameters.assumed_slope_value, parameters.assumed_slope_amount),
        parameters.scale, parameters.octaves, parameters.lacunarity,
        parameters.gain, parameters.cell_scale, parameters.normalization,
        ridge_map
    );
    // Apply height offset
    float vertical_offset = mix(parameters.height_offset, -fade_target, parameters.height_offset_fade_blend) * erosion_result.w;
    float eroded_height = center_height + erosion_result.x + vertical_offset;
    imageStore(output_image, pixel_coord, vec4(eroded_height, 0.0, 0.0, 0.0));
}
