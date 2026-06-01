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
    float current_freq = 1.0 / (erosion_scale * cell_scale);
    float slope_magnitude = max(length(height_and_slope.yz), 1e-10);
    float accumulated_magnitude = 0.0;
    float rounding_multiplier = 1.0;
    float initial_rounding = mix(rounding_params.y, rounding_params.x, clamp01(fade_target + 0.5)) * rounding_params.z;
    float erosion_mask = ease_out(smooth_start(slope_magnitude * onset_params.x, initial_rounding * onset_params.x));
    float ridge_mask = ease_out(slope_magnitude * onset_params.z);
    float ridge_fade_target = fade_target;
    vec2 gully_direction = mix(
    height_and_slope.yz,
    height_and_slope.yz / slope_magnitude * assumed_slope.x,
    assumed_slope.y
    );
    for (int i = 0; i < octaves; i++) {
        vec4 noise_sample = PhacelleNoise(pos * current_freq, safe_normalize(gully_direction), cell_scale, 0.25, normalization);
        noise_sample.zw *= -current_freq;
        float slope_amount = abs(noise_sample.y);
        gully_direction += sign(noise_sample.y) * noise_sample.zw * erosion_strength * gully_weight;
        vec3 gully_offset = vec3(noise_sample.x, noise_sample.y * noise_sample.zw);
        vec3 masked_gully_offset = mix(vec3(fade_target, 0.0, 0.0), gully_offset * gully_weight, erosion_mask);
        height_and_slope += masked_gully_offset * erosion_strength;
        accumulated_magnitude += erosion_strength;
        fade_target = masked_gully_offset.x;
        float octave_rounding = mix(rounding_params.y, rounding_params.x, clamp01(noise_sample.x + 0.5)) * rounding_multiplier;
        float octave_mask = ease_out(smooth_start(slope_amount * onset_params.y, octave_rounding * onset_params.y));
        erosion_mask = pow_inv(erosion_mask, detail_level) * octave_mask;
        ridge_fade_target = mix(ridge_fade_target, gully_offset.x, ridge_mask);
        float ridge_octave_mask = ease_out(slope_amount * onset_params.w);
        ridge_mask = ridge_mask * ridge_octave_mask;
        erosion_strength *= gain;
        current_freq *= lacunarity;
        rounding_multiplier *= rounding_params.w;
    }
    ridge_map = ridge_fade_target * (1.0 - ridge_mask);
    vec3 height_slope_delta = height_and_slope - input_height_and_slope;
    return vec4(height_slope_delta, accumulated_magnitude);
}
