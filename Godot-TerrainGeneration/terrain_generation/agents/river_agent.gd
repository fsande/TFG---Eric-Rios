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
## The agent follows the gradient uphill (coast → mountain) for natural meandering,
## then carves the riverbed downhill (mountain → coast) with proper flow dynamics.
@tool
class_name RiverAgent extends TerrainModifierAgent

@export var config: RiverAgentConfig = RiverAgentConfig.new()

func _init() -> void:
	agent_name = "River"
	tokens = 25

func get_modifier_type() -> ModifierType:
	return ModifierType.COMPOSITE  # Carves riverbed (height delta) and places water (props)

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
	var rng := RandomNumberGenerator.new()
	rng.seed = config.placement_seed if config.placement_seed != 0 else context.generation_seed
	progress_updated.emit(0.0, "Finding coastline points")
	var coastline_points := context.find_coastline_points(10, 1000)
	if coastline_points.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure("No coastline found", elapsed)
	progress_updated.emit(0.1, "Finding mountain points")
	var min_height_norm := config.min_origin_height / context.height_scale
	var mountain_points := context.find_points_above_height(min_height_norm, 10, 2000)
	if mountain_points.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure(
			"No mountain points above %.1fm" % config.min_origin_height, 
			elapsed
		)
	progress_updated.emit(0.2, "Generating river path")
	var validator := config.pair_validator
	if not validator:
		validator = HeuristicRiverPairValidator.new()
		print("Using default validator: %s" % validator.get_strategy_name())
	else:
		print("Using configured validator: %s" % validator.get_strategy_name())
	var path: Array[Vector2] = []
	var coast_point: Vector2
	var mountain_point: Vector2
	var validation_rejections := 0
	for attempt in range(config.max_attempts):
		var coast_idx := rng.randi_range(0, coastline_points.size() - 1)
		var mountain_idx := rng.randi_range(0, mountain_points.size() - 1)
		coast_point = coastline_points[coast_idx]
		mountain_point = mountain_points[mountain_idx]
		if coast_point.distance_to(mountain_point) < config.min_coast_to_mountain_distance:
			continue
		if config.enable_pair_validation:
			if not validator.is_pair_valid(coast_point, mountain_point, context):
				validation_rejections += 1
				continue
		path = _generate_river_path_uphill(coast_point, mountain_point, context)
		if not path.is_empty():
			progress_updated.emit(0.5, "Valid path found on attempt %d" % (attempt + 1))
			break
	if path.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		var msg := "Failed to generate valid river after %d attempts" % config.max_attempts
		if validation_rejections > 0:
			msg += " (%d rejected by pair validation - possibly different landmasses)" % validation_rejections
		return TerrainModifierResult.create_failure(msg, elapsed)
	if config.smooth_path:
		progress_updated.emit(0.6, "Smoothing river path")
		path = _smooth_path(path, config.smoothing_iterations)
	progress_updated.emit(0.7, "Carving riverbed")
	var riverbed_delta := _carve_riverbed_downstream(path, context)
	var result := TerrainModifierResult.create_success()
	result.add_height_delta(riverbed_delta)
	progress_updated.emit(0.95, "Creating debug spheres")
#	_spawn_debug_trail(path, context)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created river with %d path points (%.1fm length)" % [
		path.size(),
		_calculate_path_length(path)
	]
	return result

## Generate river path from coast to mountain following uphill gradient.
## Based on Doran & Parberry algorithm (lines #3-#7 of pseudo-code).
func _generate_river_path_uphill(
	start_pos: Vector2,
	target_pos: Vector2,
	context: TerrainGenerationContext
) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current_pos := start_pos
	path.append(current_pos)
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
		var to_target := (target_pos - current_pos).normalized()
		var uphill := context.calculate_uphill_direction(current_pos)
		if uphill.length_squared() < 0.0001:
			uphill = to_target
		var progress := float(step) / float(config.max_path_steps)
		var gradient_weight := lerpf(config.gradient_weight_start, config.gradient_weight_end, progress)
		var target_weight := 1.0 - gradient_weight
		var move_dir := (uphill * gradient_weight + to_target * target_weight)
		if move_dir.length_squared() < 0.0001:
			break
		move_dir = move_dir.normalized()
		current_pos += move_dir * config.step_size
		var half_size := context.terrain_size / 2.0
		current_pos.x = clampf(current_pos.x, -half_size.x, half_size.x)
		current_pos.y = clampf(current_pos.y, -half_size.y, half_size.y)
		var new_height := context.sample_height_at(current_pos)
		var new_height_scaled := new_height * context.height_scale
		if new_height_scaled + 0.2 < current_height_scaled:
			break
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
## Implements lines #8-#11 of Doran & Parberry pseudo-code.
func _carve_riverbed_downstream(path: Array[Vector2], context: TerrainGenerationContext) -> HeightDeltaMap:
	var bounds := _calculate_river_bounds(path)
	print("River bounds: %s" % bounds)
	var delta := HeightDeltaMap.create(config.delta_resolution, config.delta_resolution, bounds)
	delta.blend_strategy = AdditiveBlendStrategy.new()
	delta.intensity = 1.0
	delta.source_agent = get_display_name()
	print("Created delta map with resolution %d x %d" % [config.delta_resolution, config.delta_resolution])
	var path_downstream: Array[Vector2] = path.duplicate()
	path_downstream.reverse()
	print("Carving river with %d path points" % path_downstream.size())
	for i in range(path_downstream.size()):
		var position := path_downstream[i]
		var progress := float(i) / float(path_downstream.size())
		var depth := minf(
			config.initial_depth + progress * config.depth_increase_rate * path_downstream.size(),
			config.max_depth
		)
		var width := config.river_width * lerpf(1.0, config.width_multiplier_downstream, progress)
		var downhill := context.calculate_downhill_direction(position)
		if downhill.length_squared() < 0.0001:
			downhill = Vector2(0, 1)
		else:
			downhill = downhill.normalized()
		_apply_river_carving(delta, bounds, position, downhill, width, depth)
		if i < 3 or i >= path_downstream.size() - 3:
			print("Carved point %d at %s with depth %.2f and width %.2f" % [i, position, depth, width])
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
	var max_distance := width / 2.0 + config.edge_falloff_distance
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
