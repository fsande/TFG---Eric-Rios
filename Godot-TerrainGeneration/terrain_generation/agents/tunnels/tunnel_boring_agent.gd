## @brief Agent that creates tunnels through terrain.
##
## @details Generates a TunnelVolumeDefinition (ADDITIVE tube) and one or two
## TunnelEntranceVolume instances (SUBTRACTIVE mouth carves) per tunnel.
## The path is clamped to the terrain interior — it terminates when it
## re-emerges through the terrain surface or exits the terrain bounds.
@tool
class_name TunnelBoringAgent extends TerrainModifierAgent

## Oversize factor applied to entrance carve radius relative to tunnel_radius.
## Compensates for triangle-removal only working on fully-enclosed triangles.
const CARVE_RADIUS_FACTOR := 1.35

@export_group("Tunnel Shape")

@export var tunnel_radius: float = 3.0
@export var tunnel_length: float = 30.0
@export var cross_section: TunnelVolumeDefinition.CrossSectionType = TunnelVolumeDefinition.CrossSectionType.ARCH
@export_range(4, 32) var radial_segments: int = 12

@export_group("Placement")

@export_range(1, 10) var tunnel_count: int = 1
@export var min_cliff_height: float = 15.0
@export_range(5.0, 90.0) var min_cliff_angle: float = 30.0
@export var placement_seed: int = 0

@export_group("Path")

@export var curved_path: bool = true
@export_range(0.0, 90.0) var max_curve_angle: float = 30.0
@export var radius_variation: Vector2 = Vector2(0.8, 1.2)

## Step size in world units when marching the path to find terrain exit.
const PATH_SAMPLE_STEP := 0.5

func _init() -> void:
	agent_name = "Tunnel Boring"

func get_modifier_type() -> ModifierType:
	return ModifierType.COMPOSITE

func get_agent_type() -> String:
	return "TunnelBoring"

func validate(_context: TerrainGenerationContext) -> bool:
	if tunnel_radius <= 0.0:
		push_error("TunnelBoringAgent: tunnel_radius must be positive")
		return false
	if tunnel_length <= 0.0:
		push_error("TunnelBoringAgent: tunnel_length must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding cliff faces")
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed if placement_seed != 0 else context.generation_seed + 9999
	var cliff_positions := context.find_cliff_positions(min_cliff_angle, tunnel_count * 5)
	if cliff_positions.is_empty():
		return TerrainModifierResult.create_failure(
			"No suitable cliff faces found (min angle: %.1f°)" % min_cliff_angle,
			Time.get_ticks_msec() - start_time
		)
	progress_updated.emit(0.3, "Selecting tunnel entry points")
	var valid_cliffs := cliff_positions.filter(func(c): return c["position"].y >= min_cliff_height)
	if valid_cliffs.is_empty():
		valid_cliffs = cliff_positions
	valid_cliffs.shuffle()
	var selected_count := mini(tunnel_count, valid_cliffs.size())
	var result := TerrainModifierResult.create_success()
	for i in range(selected_count):
		progress_updated.emit(
			0.4 + 0.5 * float(i) / float(selected_count),
			"Creating tunnel %d/%d" % [i + 1, selected_count]
		)
		var cliff: Dictionary = valid_cliffs[i]
		print("Adding tunnel at ", cliff["position"])
		_add_tunnel_to_result(result, cliff["position"], cliff["normal"], context, rng)
	progress_updated.emit(1.0, "Complete")
	result.elapsed_ms = Time.get_ticks_msec() - start_time
	result.error_message = "Created %d tunnel(s)" % (result.volumes.size() / 2)
	return result

## Build tunnel volumes for one cliff face and append them to result.
func _add_tunnel_to_result(
	result: TerrainModifierResult,
	entry_point: Vector3,
	cliff_normal: Vector3,
	context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> void:
	var inward_dir := _inward_direction(cliff_normal, rng)
	var raw_path := _generate_raw_path(entry_point, inward_dir, rng)
	var exit_info := _find_path_exit(raw_path, context)
	var clipped_path := _clip_path_to_offset(raw_path, exit_info["offset"])
	if clipped_path.get_baked_length() < tunnel_radius * 2.0:
		return
	var tube := _build_tube_volume(clipped_path, entry_point, inward_dir, rng)
	var entrance := _build_entrance_volume(entry_point, inward_dir)
	entrance.source_agent = get_display_name()
	tube.source_agent = get_display_name()
	result.add_volume(entrance)
	result.add_volume(tube)
	if exit_info["is_surface_exit"]:
		var exit_vol := _build_entrance_volume(exit_info["point"], -exit_info["direction"])
		exit_vol.source_agent = get_display_name()
		result.add_volume(exit_vol)

## Compute the inward tunnel direction from a cliff normal.
func _inward_direction(cliff_normal: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var dir := -Vector3(cliff_normal.x, 0.0, cliff_normal.z).normalized()
	dir.y = rng.randf_range(-0.1, 0.1)
	return dir.normalized()

## Generate the full-length candidate path before terrain clamping.
func _generate_raw_path(
	entry_point: Vector3,
	inward_dir: Vector3,
	rng: RandomNumberGenerator
) -> Curve3D:
	var path := Curve3D.new()
	var start_pos := entry_point + inward_dir * 2.0
	if curved_path:
		var num_points := 4
		var segment_length := tunnel_length / float(num_points - 1)
		var current_pos := start_pos
		var current_dir := inward_dir
		path.add_point(current_pos)
		for _i in range(1, num_points):
			var curve_rad := deg_to_rad(rng.randf_range(-max_curve_angle, max_curve_angle))
			var new_dir := Vector3(
				current_dir.x * cos(curve_rad) - current_dir.z * sin(curve_rad),
				current_dir.y,
				current_dir.x * sin(curve_rad) + current_dir.z * cos(curve_rad)
			)
			current_dir = new_dir.normalized()
			current_pos += current_dir * segment_length
			path.add_point(current_pos)
	else:
		path.add_point(start_pos)
		path.add_point(start_pos + inward_dir * tunnel_length)
	return path

## March along path to find where it exits the terrain.
## Returns: { offset: float, point: Vector3, direction: Vector3, is_surface_exit: bool }
func _find_path_exit(path: Curve3D, context: TerrainGenerationContext) -> Dictionary:
	var baked_length := path.get_baked_length()
	var terrain_bounds := context.get_terrain_bounds()
	var num_steps := int(baked_length / PATH_SAMPLE_STEP)
	for i in range(1, num_steps + 1):
		var offset := float(i) * PATH_SAMPLE_STEP
		var point := path.sample_baked(offset)
		var terrain_height := context.get_scaled_height_at(Vector2(point.x, point.z))
		var is_outside_bounds := not terrain_bounds.has_point(point)
		var is_above_surface := point.y >= terrain_height
		if is_outside_bounds or is_above_surface:
			var dir := _path_tangent_at(path, offset, baked_length)
			return {
				"offset": offset,
				"point": point,
				"direction": dir,
				"is_surface_exit": is_above_surface and not is_outside_bounds
			}
	return {
		"offset": baked_length,
		"point": path.sample_baked(baked_length),
		"direction": _path_tangent_at(path, baked_length, baked_length),
		"is_surface_exit": false
	}

## Rebuild path from the original, sampled up to max_offset.
func _clip_path_to_offset(source: Curve3D, max_offset: float) -> Curve3D:
	var clipped := Curve3D.new()
	var num_samples := 8
	for i in range(num_samples + 1):
		var offset := float(i) / float(num_samples) * max_offset
		clipped.add_point(source.sample_baked(offset))
	return clipped

func _build_tube_volume(
	path: Curve3D,
	entry_point: Vector3,
	entry_dir: Vector3,
	rng: RandomNumberGenerator
) -> TunnelVolumeDefinition:
	var tunnel := TunnelVolumeDefinition.new()
	tunnel.path = path
	tunnel.base_radius = tunnel_radius
	tunnel.cross_section = cross_section
	tunnel.radial_segments = radial_segments
	tunnel.entry_point = entry_point
	tunnel.entry_direction = entry_dir
	if radius_variation.x != 1.0 or radius_variation.y != 1.0:
		tunnel.radius_curve = _build_radius_curve(rng)
	tunnel.update_bounds()
	return tunnel

func _build_entrance_volume(center: Vector3, inward_dir: Vector3) -> TunnelEntranceVolume:
	var vol := TunnelEntranceVolume.new()
	vol.center = center
	vol.inward_direction = inward_dir.normalized()
	vol.carve_radius = tunnel_radius * CARVE_RADIUS_FACTOR
	vol.carve_depth = maxf(tunnel_radius, 3.0)
	vol.cross_section = cross_section
	vol.update_bounds()
	return vol

func _build_radius_curve(rng: RandomNumberGenerator) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, rng.randf_range(radius_variation.x, radius_variation.y)))
	c.add_point(Vector2(0.3, rng.randf_range(radius_variation.x, radius_variation.y)))
	c.add_point(Vector2(0.7, rng.randf_range(radius_variation.x, radius_variation.y)))
	c.add_point(Vector2(1.0, rng.randf_range(radius_variation.x, radius_variation.y) * 0.8))
	return c

func _path_tangent_at(path: Curve3D, offset: float, baked_length: float) -> Vector3:
	var epsilon := minf(1.0, baked_length * 0.01)
	var p1 := path.sample_baked(maxf(0.0, offset - epsilon))
	var p2 := path.sample_baked(minf(baked_length, offset + epsilon))
	return (p2 - p1).normalized()
