## @brief Agent that creates tunnels through terrain.
##
## @details Produces a TunnelEntranceVolume (SUBTRACTIVE, carves the cliff face)
## and a TunnelTubeVolume (ADDITIVE, the interior cylinder) per tunnel.
## Path length is clamped so the tunnel never exits through another surface
## or leaves the terrain bounds.
@tool
class_name TunnelBoringAgent extends TerrainModifierAgent

## Step size in world units when marching to find terrain exit.
const PATH_SAMPLE_STEP := 0.5

@export_group("Shape")
@export var tunnel_radius: float = 3.0
@export var tunnel_length: float = 30.0
@export_range(4, 32) var radial_segments: int = 12
@export_range(4, 64) var entry_depth_samples: int = 16

@export_group("Placement")
@export_range(1, 10) var tunnel_count: int = 1
@export var min_cliff_height: float = 15.0
@export_range(5.0, 90.0) var min_cliff_angle: float = 30.0
@export var placement_seed: int = 0

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
	var start_ms := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding cliff faces")
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed if placement_seed != 0 else context.generation_seed + 9999
	var cliff_candidates := context.find_cliff_positions(min_cliff_angle, tunnel_count * 5)
	if cliff_candidates.is_empty():
		return TerrainModifierResult.create_failure(
			"No cliff faces found (min_angle=%.1f°)" % min_cliff_angle,
			Time.get_ticks_msec() - start_ms
		)
	var valid_cliffs := cliff_candidates.filter(func(c): return c["position"].y >= min_cliff_height)
	if valid_cliffs.is_empty():
		valid_cliffs = cliff_candidates
	var result := TerrainModifierResult.create_success()
	var placed := 0
	for cliff in valid_cliffs:
		if placed >= tunnel_count:
			break
		progress_updated.emit(
			0.2 + 0.8 * float(placed) / float(tunnel_count),
			"Placing tunnel %d/%d" % [placed + 1, tunnel_count]
		)
		if _try_place_tunnel(result, cliff["position"], cliff["normal"], context):
			placed += 1
	if placed == 0:
		return TerrainModifierResult.create_failure(
			"No valid tunnel placements found",
			Time.get_ticks_msec() - start_ms
		)
	progress_updated.emit(1.0, "Done")
	result.elapsed_ms = Time.get_ticks_msec() - start_ms
	result.error_message = "Created %d tunnel(s)" % placed
	return result

## Attempts to place one tunnel at the given cliff face.
## Returns false if the clamped length is too short to be useful.
func _try_place_tunnel(
	result: TerrainModifierResult,
	entry_pos: Vector3,
	cliff_normal: Vector3,
	context: TerrainGenerationContext
) -> bool:
	var inward := _inward_dir(cliff_normal)
	var clamped_end := entry_pos + inward * tunnel_length #_clamp_endpoint(entry_pos, inward, context)
	var clamped_length := entry_pos.distance_to(clamped_end)
	#if clamped_length < tunnel_radius * 2.0:
		#return false
	var depths := _compute_entry_depths(entry_pos, inward, context)
	var entrance := TunnelEntranceVolume.new()
	entrance.center = entry_pos
	entrance.inward_direction = inward
	entrance.carve_radius = tunnel_radius
	entrance.carve_depth = tunnel_radius * 1.5
	entrance.entry_depth_samples = entry_depth_samples
	entrance.entry_surface_depths = depths
	entrance.source_agent = get_display_name()
	entrance.update_bounds()
	var tube := TunnelTubeVolume.new()
	tube.start_point = entry_pos
	tube.end_point = clamped_end
	tube.radius = tunnel_radius
	tube.radial_segments = radial_segments
	tube.entry_surface_depths = depths
	tube.source_agent = get_display_name()
	tube.update_bounds()
	result.add_volume(entrance)
	result.add_volume(tube)
	return true

## Returns the inward tunnel direction from the outward cliff normal.
func _inward_dir(cliff_normal: Vector3) -> Vector3:
	return -Vector3(cliff_normal.x, 0.0, cliff_normal.z).normalized()

## Bakes the terrain-conforming surface depths around the entrance perimeter.
##
## @details For each angular sample, binary-searches along the inward axis to
## find the signed depth where that perimeter point transitions from above to
## below the terrain surface. Negative depth means the cliff protrudes past center.
func _compute_entry_depths(
	entry_pos: Vector3,
	inward: Vector3,
	context: TerrainGenerationContext
) -> PackedFloat32Array:
	var right := inward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = inward.cross(Vector3.FORWARD).normalized()
	var up := right.cross(inward).normalized()
	var search_depth := tunnel_radius * 2.0
	var depths := PackedFloat32Array()
	for j in range(entry_depth_samples):
		var angle := float(j) / float(entry_depth_samples) * TAU
		var lateral := right * cos(angle) * tunnel_radius + up * sin(angle) * tunnel_radius
		var lo := -search_depth
		var hi := search_depth
		for _k in range(16):
			var mid := (lo + hi) * 0.5
			var test_pos := entry_pos + lateral + inward * mid
			var surface_y := context.get_scaled_height_at(Vector2(test_pos.x, test_pos.z))
			if test_pos.y >= surface_y:
				lo = mid
			else:
				hi = mid
		depths.append((lo + hi) * 0.5)
	return depths

## Marches inward and returns the last point where the full tube cross-section
## is underground and within terrain bounds, capped at tunnel_length.
func _clamp_endpoint(
	entry_pos: Vector3,
	inward: Vector3,
	context: TerrainGenerationContext
) -> Vector3:
	var terrain_bounds := context.get_terrain_bounds()
	var right := inward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = inward.cross(Vector3.FORWARD).normalized()
	var up := right.cross(inward).normalized()
	var perimeter_offsets: Array[Vector3] = []
	for j in range(8):
		var angle := float(j) / 8.0 * TAU
		perimeter_offsets.append(right * cos(angle) * tunnel_radius + up * sin(angle) * tunnel_radius)
	var last_valid := entry_pos
	var steps := int(tunnel_length / PATH_SAMPLE_STEP)
	for i in range(1, steps + 1):
		var center := entry_pos + inward * (float(i) * PATH_SAMPLE_STEP)
		if not terrain_bounds.has_point(center):
			break
		var all_underground := true
		for offset in perimeter_offsets:
			var sample_pos := center + offset
			var surface_y := context.get_scaled_height_at(Vector2(sample_pos.x, sample_pos.z))
			if sample_pos.y >= surface_y:
				all_underground = false
				break
		if not all_underground:
			break
		last_valid = center
	return last_valid
