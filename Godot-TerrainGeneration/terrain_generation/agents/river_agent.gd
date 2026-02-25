## @brief River agent responsible for carving riverbeds and placing water.
##
## @details Implements Doran and Parberry's river generation algorithm:
## https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=5454273
##
## Algorithm:
## 1. Select random coastline point (river endpoint)
## 2. Select random mountain base point (river source)
## 3. Generate path from coast to mountain following uphill gradient
## 4. Validate path (length, altitude, obstacles)
## 5. Carve riverbed downstream (mountain → coast) with increasing width
## 6. Place water volume/props
##
## The agent follows the gradient uphill (coast -> mountain) for natural meandering,
## then carves the riverbed downhill (mountain -> coast) with proper flow dynamics.
@tool
class_name RiverAgent extends TerrainModifierAgent

@export var config: RiverAgentConfig = RiverAgentConfig.new()

func _init() -> void:
	agent_name = "River"
	tokens = 25

func get_modifier_type() -> ModifierType:
	return ModifierType.COMPOSITE

func get_agent_type() -> String:
	return "River"

func validate(context: TerrainGenerationContext) -> bool:
	if not enabled:
		return false
	if config.river_width <= 0:
		push_error("RiverAgent: river_width must be positive")
		return false
	if config.step_size <= 0:
		push_error("RiverAgent: step_size must be positive")
		return false
	if config.min_river_length <= 0:
		push_error("RiverAgent: min_river_length must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding coastline points")
	var coastline_points := context.find_coastline_points(20, 1000)
	if coastline_points.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure("No coastline found", elapsed)
	progress_updated.emit(0.1, "Finding mountain points")
	var min_height_norm := config.min_origin_height / context.height_scale
	var mountain_points := context.find_points_above_height(min_height_norm, 20, 2000)
	if mountain_points.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure(
			"No mountain points above %.1fm" % config.min_origin_height,
			elapsed
		)
	progress_updated.emit(0.2, "Scoring coast-mountain pairs")
	var scored_pairs := RiverPairSelector.select_pairs(
		coastline_points,
		mountain_points,
		context,
		config.min_coast_to_mountain_distance,
		config.max_coast_to_mountain_distance,
		config.max_attempts
	)
	if scored_pairs.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure(
			"No feasible coast-mountain pairs found (tried %d×%d candidates)" % [
				coastline_points.size(), mountain_points.size()
			], elapsed
		)
	progress_updated.emit(0.3, "Generating river path (%d candidate pairs)" % scored_pairs.size())
	var path: Array[Vector2] = []
	for attempt in range(scored_pairs.size()):
		var pair := scored_pairs[attempt]
		path = _generate_river_path_uphill(pair.coast_point, pair.mountain_point, context)
		if not path.is_empty():
			progress_updated.emit(0.5, "Valid path found on pair %d (score %.2f)" % [attempt + 1, pair.score])
			break
	if path.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure(
			"Failed to generate valid river from %d scored pairs" % scored_pairs.size(),
			elapsed
		)
	if config.smooth_path:
		progress_updated.emit(0.6, "Smoothing river path")
		path = _smooth_path(path, config.smoothing_iterations)
	progress_updated.emit(0.7, "Carving riverbed")
	var riverbed_delta := _carve_riverbed_downstream(path, context)
	var result := TerrainModifierResult.create_success()
	result.add_height_delta(riverbed_delta)
	if config.place_water:
		progress_updated.emit(0.85, "Building river water mesh")
		var downstream_path: Array[Vector2] = path.duplicate()
		downstream_path.reverse()
		var visual := RiverMeshBuilder.build(
			downstream_path,
			context,
			config.river_width,
			config.width_multiplier_downstream,
			config.water_surface_offset,
			config.ribbon_cross_subdivisions,
			config.ribbon_resample_spacing
		)
		if visual:
			visual.display_name = get_display_name()
			visual.material_override = config.water_material
			result.add_river_visual(visual)
		else:
			push_warning("RiverAgent: Failed to build river water mesh")
	progress_updated.emit(0.95, "Creating debug spheres")
	_spawn_debug_trail(path, context)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created river with %d path points (%.1fm length)" % [
		path.size(),
		_calculate_path_length(path)
	]
	return result

## Generate river path from coast to mountain following uphill gradient.
func _generate_river_path_uphill(
	start_pos: Vector2,
	target_pos: Vector2,
	context: TerrainGenerationContext
) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current_pos := start_pos
	path.append(current_pos)
	var start_height_scaled := context.sample_height_at(start_pos) * context.height_scale
	var consecutive_downhill := 0
	for step in range(config.max_path_steps):
		var current_height := context.sample_height_at(current_pos)
		var current_height_scaled := current_height * context.height_scale
		if current_height_scaled > config.max_altitude:
			var backoff_steps := mini(config.backoff_distance, path.size() - 1)
			if backoff_steps > 0:
				path.resize(path.size() - backoff_steps)
			break
		var slope := context.calculate_slope_at(current_pos)
		if slope > config.max_slope_degrees:
			var backoff_steps := mini(config.backoff_distance, path.size() - 1)
			if backoff_steps > 0:
				path.resize(path.size() - backoff_steps)
			break
		if current_pos.distance_to(target_pos) < config.step_size * 2:
			break
		var height_range := config.max_altitude - start_height_scaled
		var height_progress: float
		if height_range > 0.01:
			height_progress = clampf(
				(current_height_scaled - start_height_scaled) / height_range, 0.0, 1.0
			)
		else:
			height_progress = 0.0
		var gradient_weight := lerpf(config.gradient_weight_start, config.gradient_weight_end, height_progress)
		var target_weight := 1.0 - gradient_weight
		var to_target := (target_pos - current_pos).normalized()
		var uphill := context.calculate_uphill_direction(current_pos)
		if uphill.length_squared() < 0.0001:
			uphill = to_target
		var move_dir := (uphill * gradient_weight + to_target * target_weight)
		if move_dir.length_squared() < 0.0001:
			break
		move_dir = move_dir.normalized()
		var next_pos := current_pos + move_dir * config.step_size
		var half_size := context.terrain_size / 2.0
		next_pos.x = clampf(next_pos.x, -half_size.x, half_size.x)
		next_pos.y = clampf(next_pos.y, -half_size.y, half_size.y)
		var next_height_scaled := context.sample_height_at(next_pos) * context.height_scale
		var height_drop := current_height_scaled - next_height_scaled
		if height_drop > config.downhill_tolerance:
			consecutive_downhill += 1
			if consecutive_downhill >= config.max_consecutive_downhill_steps:
				var backoff := mini(consecutive_downhill, path.size() - 1)
				if backoff > 0:
					path.resize(path.size() - backoff)
				break
		else:
			consecutive_downhill = 0
		current_pos = next_pos
		path.append(current_pos)
	var path_length := _calculate_path_length(path)
	if path_length < config.min_river_length:
		return []
	return path

## Smooth path to reduce jaggedness.
func _smooth_path(path: Array[Vector2], iterations: int = 2) -> Array[Vector2]:
	if path.size() < 3:
		return path
	var smoothed: Array[Vector2] = path.duplicate()
	for _iter in range(iterations):
		var temp: Array[Vector2] = []
		temp.append(smoothed[0])
		for i in range(1, smoothed.size() - 1):
			var prev := smoothed[i - 1]
			var curr := smoothed[i]
			var next := smoothed[i + 1]
			var avg := (prev + curr + next) / 3.0
			temp.append(avg)
		temp.append(smoothed[smoothed.size() - 1])
		smoothed = temp
	return smoothed

## Calculate total path length.
func _calculate_path_length(path: Array[Vector2]) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	return length

## Carve riverbed downstream (mountain → coast) with increasing width and depth.
func _carve_riverbed_downstream(path: Array[Vector2], _context: TerrainGenerationContext) -> HeightDeltaMap:
	var bounds := _calculate_river_bounds(path)
	var delta := HeightDeltaMap.create(config.delta_resolution, config.delta_resolution, bounds)
	delta.blend_strategy = AdditiveBlendStrategy.new()
	delta.intensity = 1.0
	delta.source_agent = get_display_name()
	var path_downstream: Array[Vector2] = path.duplicate()
	path_downstream.reverse()
	for i in range(path_downstream.size()):
		var position := path_downstream[i]
		var progress := float(i) / float(path_downstream.size())
		var depth := minf(
			config.initial_depth + progress * config.depth_increase_rate * path_downstream.size(),
			config.max_depth
		)
		var width := config.river_width * lerpf(1.0, config.width_multiplier_downstream, progress)
		var flow_dir: Vector2
		if i < path_downstream.size() - 1:
			flow_dir = (path_downstream[i + 1] - path_downstream[i]).normalized()
		elif i > 0:
			flow_dir = (path_downstream[i] - path_downstream[i - 1]).normalized()
		else:
			flow_dir = Vector2(0, 1)
		_apply_river_carving(delta, bounds, position, flow_dir, width, depth)
	return delta

## Apply river carving at a specific position (optimized version).
## Instead of iterating the entire delta map, only process pixels near the river.
func _apply_river_carving(
	delta: HeightDeltaMap,
	bounds: AABB,
	position: Vector2,
	flow_direction: Vector2,
	width: float,
	depth: float
) -> void:
	var perpendicular := Vector2(-flow_direction.y, flow_direction.x)
	var max_distance := width / 2.0 #+ config.edge_falloff_distance
	var center_local_x := (position.x - bounds.position.x) / bounds.size.x
	var center_local_z := (position.y - bounds.position.z) / bounds.size.z
	var pixel_size_x := bounds.size.x / float(config.delta_resolution)
	var pixel_size_z := bounds.size.z / float(config.delta_resolution)
	var pixel_radius := int(ceil(max_distance / min(pixel_size_x, pixel_size_z))) + 1
	var center_pixel_x := int(center_local_x * config.delta_resolution)
	var center_pixel_y := int(center_local_z * config.delta_resolution)
	var min_x := maxi(0, center_pixel_x - pixel_radius)
	var max_x := mini(config.delta_resolution - 1, center_pixel_x + pixel_radius)
	var min_y := maxi(0, center_pixel_y - pixel_radius)
	var max_y := mini(config.delta_resolution - 1, center_pixel_y + pixel_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var u := float(x) / float(config.delta_resolution - 1)
			var v := float(y) / float(config.delta_resolution - 1)
			var world_x := bounds.position.x + u * bounds.size.x
			var world_z := bounds.position.z + v * bounds.size.z
			var pixel_pos := Vector2(world_x, world_z)
			var relative := pixel_pos - position
			var dist_perp: float = abs(relative.dot(perpendicular))
			if dist_perp < width / 2.0:
				var current_value := delta.sample_at_uv(Vector2(u, v))
				var new_depth := -depth
				if current_value > new_depth:
					delta.set_at_uv(Vector2(u, v), new_depth)
			elif dist_perp < width / 2.0 + config.edge_falloff_distance:
				var falloff_dist: float = dist_perp - width / 2.0
				var falloff_factor := 1.0 - (falloff_dist / config.edge_falloff_distance)
				var current_value := delta.sample_at_uv(Vector2(u, v))
				var new_depth := -depth * falloff_factor
				if current_value > new_depth:
					delta.set_at_uv(Vector2(u, v), new_depth)

## Calculate bounds encompassing entire river path.
func _calculate_river_bounds(path: Array[Vector2]) -> AABB:
	if path.is_empty():
		return AABB()
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for point in path:
		min_pos.x = minf(min_pos.x, point.x)
		min_pos.y = minf(min_pos.y, point.y)
		max_pos.x = maxf(max_pos.x, point.x)
		max_pos.y = maxf(max_pos.y, point.y)
	var padding := config.river_width * config.width_multiplier_downstream + config.edge_falloff_distance * 2
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)
	return AABB(
		Vector3(min_pos.x, -config.max_depth * 2, min_pos.y),
		Vector3(max_pos.x - min_pos.x, config.max_depth * 4, max_pos.y - min_pos.y)
	)

## DEBUG: Spawn red cones at each path point showing direction
func _spawn_debug_trail(path: Array[Vector2], context: TerrainGenerationContext) -> void:
	var scene_root = Engine.get_main_loop().root
	if not scene_root:
		push_warning("RiverAgent: Could not get scene root for debug cones")
		return
	var debug_container: Node3D = null
	for child in scene_root.get_children():
		if child.name == "RiverDebugSpheres":
			debug_container = child
			break
	if not debug_container:
		debug_container = Node3D.new()
		debug_container.name = "RiverDebugSpheres"
		scene_root.add_child(debug_container)
	var red_material := StandardMaterial3D.new()
	red_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	red_material.emission_enabled = true
	red_material.emission = Color(1.0, 0.0, 0.0, 1.0)
	red_material.emission_energy_multiplier = 0.5
	for i in range(path.size()):
		var point_2d := path[i]
		var height := context.get_scaled_height_at(point_2d)
		var cone_pos := Vector3(point_2d.x, height, point_2d.y)
		var direction := Vector3.ZERO
		if i < path.size() - 1:
			var next_point_2d := path[i + 1]
			var next_height := context.get_scaled_height_at(next_point_2d)
			var next_pos := Vector3(next_point_2d.x, next_height, next_point_2d.y)
			direction = (next_pos - cone_pos).normalized()
		elif i > 0:
			var prev_point_2d := path[i - 1]
			var prev_height := context.get_scaled_height_at(prev_point_2d)
			var prev_pos := Vector3(prev_point_2d.x, prev_height, prev_point_2d.y)
			direction = (cone_pos - prev_pos).normalized()
		else:
			direction = Vector3.UP
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "RiverPathPoint_%d" % i
		mesh_instance.position = cone_pos
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = 0.5
		cone_mesh.height = 2.0
		cone_mesh.radial_segments = 8
		cone_mesh.rings = 1
		mesh_instance.mesh = cone_mesh
		mesh_instance.material_override = red_material
		if direction.length_squared() > 0.01:
			var up := Vector3.UP
			var rotation_axis := up.cross(direction)
			if rotation_axis.length_squared() > 0.0001:
				var angle := up.angle_to(direction)
				mesh_instance.rotate(rotation_axis.normalized(), angle)
			elif direction.dot(up) < 0:
				mesh_instance.rotate(Vector3.RIGHT, PI)
		debug_container.add_child(mesh_instance)
		if i < 3 or i >= path.size() - 3:
			print("Debug cone %d at position: %s (height: %.2f, direction: %s)" % [i, cone_pos, height, direction])
