## @brief Agent that creates tunnels through terrain (new architecture).
##
## @details Generates TunnelVolumeDefinition instances that are applied
## during chunk generation via CSG subtraction.
@tool
class_name TunnelBoringAgentV2 extends TerrainModifierAgent

@export_group("Tunnel Shape")

## Tunnel radius
@export var tunnel_radius: float = 3.0

## Tunnel length
@export var tunnel_length: float = 30.0

## Cross-section type
@export var cross_section: TunnelVolumeDefinition.CrossSectionType = TunnelVolumeDefinition.CrossSectionType.ARCH

## Number of radial segments for mesh generation
@export_range(4, 32) var radial_segments: int = 12

@export_group("Placement")

## Number of tunnels to create
@export_range(1, 10) var tunnel_count: int = 1

## Minimum cliff height for tunnel placement
@export var min_cliff_height: float = 15.0

## Minimum slope angle for cliff detection (degrees)
@export_range(5.0, 90.0) var min_cliff_angle: float = 30.0

## Random seed for placement (0 = use context seed)
@export var placement_seed: int = 0

@export_group("Path")

## Enable curved tunnel paths
@export var curved_path: bool = true

## Maximum curve angle (degrees)
@export_range(0.0, 90.0) var max_curve_angle: float = 30.0

## Radius variation along path (min, max multipliers)
@export var radius_variation: Vector2 = Vector2(0.8, 1.2)

func _init() -> void:
	agent_name = "Tunnel Boring V2"

func get_modifier_type() -> ModifierType:
	return ModifierType.VOLUME_SUBTRACTIVE

func get_agent_type() -> String:
	return "TunnelBoringV2"

func validate(context: TerrainGenerationContext) -> bool:
	if tunnel_radius <= 0:
		push_error("TunnelBoringAgentV2: tunnel_radius must be positive")
		return false
	if tunnel_length <= 0:
		push_error("TunnelBoringAgentV2: tunnel_length must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Finding cliff faces")
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed if placement_seed != 0 else context.generation_seed + 9999
	var cliff_positions := context.find_cliff_positions(min_cliff_angle, tunnel_count * 5)
	if cliff_positions.is_empty():
		var elapsed := Time.get_ticks_msec() - start_time
		return TerrainModifierResult.create_failure(
			"No suitable cliff faces found (min angle: %.1f°)" % min_cliff_angle,
			elapsed
		)
	progress_updated.emit(0.3, "Selecting tunnel entry points")
	var valid_cliffs := cliff_positions.filter(func(c): 
		return c["position"].y >= min_cliff_height
	)
	if valid_cliffs.is_empty():
		valid_cliffs = cliff_positions
	valid_cliffs.shuffle()
	var selected_count := mini(tunnel_count, valid_cliffs.size())
	progress_updated.emit(0.4, "Generating tunnel volumes")
	var result := TerrainModifierResult.create_success()
	for i in range(selected_count):
		var cliff: Dictionary = valid_cliffs[i]
		var entry_point: Vector3 = cliff["position"]
		var cliff_normal: Vector3 = cliff["normal"]
		progress_updated.emit(0.4 + 0.5 * float(i) / float(selected_count),
			"Creating tunnel %d/%d" % [i + 1, selected_count])
		var tunnel := _create_tunnel_volume(entry_point, cliff_normal, context, rng)
		if tunnel:
			result.add_volume(tunnel)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	result.elapsed_time_ms = elapsed
	result.error_message = "Created %d tunnel(s)" % result.volumes.size()
	return result

## Create a tunnel volume definition.
func _create_tunnel_volume(
	entry_point: Vector3,
	cliff_normal: Vector3,
	context: TerrainGenerationContext,
	rng: RandomNumberGenerator
) -> TunnelVolumeDefinition:
	print("Creating tunnel at %s with normal %s" % [entry_point, cliff_normal])
	var tunnel := TunnelVolumeDefinition.new()
	var tunnel_direction := -Vector3(cliff_normal.x, 0, cliff_normal.z).normalized()
	tunnel_direction.y = rng.randf_range(-0.1, 0.1)
	tunnel_direction = tunnel_direction.normalized()
	var path := Curve3D.new()
	if curved_path:
		var num_points := 4
		var current_pos := entry_point + tunnel_direction * 2.0
		var current_dir := tunnel_direction
		path.add_point(current_pos)
		var segment_length := tunnel_length / float(num_points - 1)
		for i in range(1, num_points):
			var curve_amount := rng.randf_range(-max_curve_angle, max_curve_angle)
			var curve_rad := deg_to_rad(curve_amount)
			var new_dir := Vector3(
				current_dir.x * cos(curve_rad) - current_dir.z * sin(curve_rad),
				current_dir.y,
				current_dir.x * sin(curve_rad) + current_dir.z * cos(curve_rad)
			)
			current_dir = new_dir.normalized()
			current_pos += current_dir * segment_length
			path.add_point(current_pos)
	else:
		var start_pos := entry_point + tunnel_direction * 2.0
		var end_pos := start_pos + tunnel_direction * tunnel_length
		path.add_point(start_pos)
		path.add_point(end_pos)
	tunnel.path = path
	tunnel.base_radius = tunnel_radius
	tunnel.cross_section = cross_section
	tunnel.radial_segments = radial_segments
	tunnel.entry_point = entry_point
	tunnel.entry_direction = tunnel_direction
	if radius_variation.x != 1.0 or radius_variation.y != 1.0:
		var radius_curve := Curve.new()
		radius_curve.add_point(Vector2(0.0, rng.randf_range(radius_variation.x, radius_variation.y)))
		radius_curve.add_point(Vector2(0.3, rng.randf_range(radius_variation.x, radius_variation.y)))
		radius_curve.add_point(Vector2(0.7, rng.randf_range(radius_variation.x, radius_variation.y)))
		radius_curve.add_point(Vector2(1.0, rng.randf_range(radius_variation.x, radius_variation.y) * 0.8))
		tunnel.radius_curve = radius_curve
	tunnel.update_bounds()
	tunnel.source_agent = get_display_name()
	return tunnel
