class_name SplatmapGenerator

static func generate(
	heightmap: Image,
	size: int,
	rules: Array[ResolvedLayerRule],
	noise: FastNoiseLite
) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var height := heightmap.get_pixel(x, y).r
			var slope := _sample_slope(heightmap, x, y, size)
			var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			for i in min(rules.size(), 4):
				var rule := rules[i]
				var h_weight := _range_weight(height, rule.get_slope_min(), rule.get_slope_min())
				var s_weight := _range_weight(slope, rule.get_slope_min(), rule.get_slope_min())
				var w := h_weight * s_weight
				if noise and rule.get_noise_influence() > 0.0:
					var n := (noise.get_noise_2d(
						float(x) * rule.get_noise_scale(),
						float(y) * rule.get_noise_scale()
					) + 1.0) * 0.5 
					w *= lerp(1.0, n, rule.get_noise_influence())
				weights[i] = max(w, 0.0)
			var total := weights[0] + weights[1] + weights[2] + weights[3]
			if total > 0.0:
				for i in 4:
					weights[i] /= total
			img.set_pixel(x, y, Color(weights[0], weights[1], weights[2], weights[3]))
	return img

static func generate_from_grid(
	height_grid: PackedFloat32Array,
	grid_resolution: int,
	height_scale: float,
	splat_res: int,
	rules: Array[ResolvedLayerRule],
	noise: FastNoiseLite
) -> Image:
	var img := Image.create(splat_res, splat_res, false, Image.FORMAT_RGBA8)
	for z in splat_res:
		for x in splat_res:
			var grid_x := clampi(int(float(x) / float(splat_res - 1) * float(grid_resolution - 1)), 0, grid_resolution - 1)
			var grid_z := clampi(int(float(z) / float(splat_res - 1) * float(grid_resolution - 1)), 0, grid_resolution - 1)
			var height := height_grid[grid_z * grid_resolution + grid_x] / height_scale
			var slope := _sample_slope_from_grid(height_grid, grid_x, grid_z, grid_resolution, height_scale)
			var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			for i in min(rules.size(), 4):
				var rule := rules[i]
				var h_weight := _range_weight(height, rule.height_min, rule.height_max)
				var s_weight := _range_weight(slope, rule.get_slope_min(), rule.get_slope_max())
				var w := h_weight * s_weight
				if noise and rule.get_noise_influence() > 0.0:
					var n := (noise.get_noise_2d(
						float(x) * rule.get_noise_scale(),
						float(z) * rule.get_noise_scale()
					) + 1.0) * 0.5
					w *= lerp(1.0, n, rule.get_noise_influence())
				weights[i] = max(w, 0.0)
			var total := weights[0] + weights[1] + weights[2] + weights[3]
			if total > 0.0:
				for i in 4:
					weights[i] /= total
			img.set_pixel(x, z, Color(weights[0], weights[1], weights[2], weights[3]))
	return img

static func _sample_slope_from_grid(height_grid: PackedFloat32Array, x: int, z: int, resolution: int, height_scale: float) -> float:
	var left  := height_grid[z * resolution + max(x - 1, 0)] / height_scale
	var right := height_grid[z * resolution + min(x + 1, resolution - 1)] / height_scale
	var up	:= height_grid[max(z - 1, 0) * resolution + x] / height_scale
	var down  := height_grid[min(z + 1, resolution - 1) * resolution + x] / height_scale
	var dx := (right - left) * 0.5
	var dz := (down - up) * 0.5
	return clamp(sqrt(dx * dx + dz * dz) * 8.0, 0.0, 1.0)

static func _range_weight(value: float, min_val: float, max_val: float) -> float:
	var margin := (max_val - min_val) * 0.2
	var lower := smoothstep(min_val, min_val + margin, value)
	var upper := 1.0 - smoothstep(max_val - margin, max_val, value)
	return lower * upper

static func _sample_slope(heightmap: Image, x: int, y: int, size: int) -> float:
	var left := heightmap.get_pixel(max(x - 1, 0), y).r
	var right := heightmap.get_pixel(min(x + 1, size-1),  y).r
	var up := heightmap.get_pixel(x, max(y - 1, 0)).r
	var down  := heightmap.get_pixel(x,	min(y + 1, size-1)).r
	var dx := (right - left) * 0.5
	var dy := (down - up)* 0.5
	return clamp(sqrt(dx*dx + dy*dy) * 8.0, 0.0, 1.0)
