## @brief Agent that raises terrain in a circular region (new architecture).
##
## @details Generates a HeightDeltaMap instead of modifying mesh vertices directly.
## This allows the modification to be applied at any resolution during chunk generation.
@tool
class_name TerrainRaiseAgentV2 extends TerrainModifierAgent

@export_group("Raise Parameters")

## Center position of the raise effect (world coordinates)
@export var center_position: Vector2 = Vector2(0, 0)

## Radius of effect in world units
@export var radius: float = 50.0

## Height to raise at center
@export var height: float = 10.0

## Falloff type
enum FalloffType { LINEAR, SMOOTH, EXPONENTIAL }
@export var falloff_type: FalloffType = FalloffType.SMOOTH

## Falloff strength (higher = sharper edge)
@export_range(0.1, 5.0) var falloff_strength: float = 1.0

@export_group("Output")

## Resolution of the generated delta texture
@export_range(32, 512) var delta_resolution: int = 128

func _init() -> void:
	agent_name = "Terrain Raise V2"

func get_modifier_type() -> ModifierType:
	return ModifierType.HEIGHT_DELTA

func get_agent_type() -> String:
	return "TerrainRaiseV2"

func validate(context: TerrainGenerationContext) -> bool:
	if radius <= 0:
		push_error("TerrainRaiseAgentV2: radius must be positive")
		return false
	return true

func generate(context: TerrainGenerationContext) -> TerrainModifierResult:
	var start_time := Time.get_ticks_msec()
	progress_updated.emit(0.0, "Creating height delta map")
	var bounds := AABB(
		Vector3(center_position.x - radius, 0, center_position.y - radius),
		Vector3(radius * 2, height * 2, radius * 2)
	)
	var delta := HeightDeltaMap.create(delta_resolution, delta_resolution, bounds)
	delta.blend_strategy = AdditiveBlendStrategy.new()
	delta.intensity = 1.0
	delta.source_agent = get_display_name()
	progress_updated.emit(0.3, "Generating raise pattern")
	var center := Vector2(center_position.x, center_position.y)
	for y in range(delta_resolution):
		for x in range(delta_resolution):
			var u := float(x) / float(delta_resolution - 1)
			var v := float(y) / float(delta_resolution - 1)
			var world_x := bounds.position.x + u * bounds.size.x
			var world_z := bounds.position.z + v * bounds.size.z
			var world_pos := Vector2(world_x, world_z)
			var distance := world_pos.distance_to(center)
			if distance >= radius:
				continue
			var t := distance / radius
			var strength := _calculate_falloff(t)
			var delta_value := height * strength
			delta.set_at_uv(Vector2(u, v), delta_value)
	progress_updated.emit(1.0, "Complete")
	var elapsed := Time.get_ticks_msec() - start_time
	var result := TerrainModifierResult.create_success(elapsed, 
		"Raised terrain at %s (radius: %.1f, height: %.1f)" % [center_position, radius, height])
	result.add_height_delta(delta)
	return result

## Calculate falloff value based on type.
func _calculate_falloff(t: float) -> float:
	var inverted := 1.0 - t
	match falloff_type:
		FalloffType.LINEAR:
			return pow(inverted, falloff_strength)
		FalloffType.SMOOTH:
			var s := inverted * inverted * (3.0 - 2.0 * inverted)
			return pow(s, falloff_strength)
		FalloffType.EXPONENTIAL:
			return pow(inverted, falloff_strength + 1.0)
		_:
			return inverted
