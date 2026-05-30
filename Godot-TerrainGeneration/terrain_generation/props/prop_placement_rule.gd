## @brief Rule for placing props/objects on terrain chunks.
##
## @details Defines how props should be distributed on terrain,
## including density, constraints, and variation parameters.
@tool
class_name PropPlacementRule extends ChunkFeature

## The scene to instantiate for this prop
@export var prop_scene: PackedScene = null

## Base density (props per square world unit)
@export_range(0.0, 1.0, 0.001) var density: float = 0.01

## Optional density map texture (multiplies base density)
## White = full density, Black = no props
@export var density_map: Texture2D = null

## Placement constraints
@export_group("Constraints")

@export var constraints: Array[PropPlacementConstraint] = [HeightRangeConstraint.new(), SlopeRangeConstraint.new(), SpacingConstraint.new(), VolumeExclusionConstraint.new()]

## Variation parameters
@export_group("Variation")

## Scale range (min, max)
@export var scale_range: Vector2 = Vector2(0.8, 1.2)

## Whether to randomize Y rotation
@export var random_rotation: bool = true

## Whether to align prop to terrain normal
@export var align_to_normal: bool = true

## Maximum tilt when aligning to normal (degrees)
@export_range(0.0, 90.0) var max_tilt: float = 30.0

## Sink props into ground by this amount
@export var ground_offset: float = 0.0

## Seed offset for variation
@export var seed_offset: int = 0

## LOD settings
@export_group("LOD")

## Distance at which to use billboard impostor (0 = no billboard)
@export var billboard_distance: float = 0.0

## Performance settings
@export_group("Performance")

## Use MultiMesh for rendering (better performance, no per-instance logic)
## When enabled, all props from this rule in a chunk will be batched into a single draw call
@export var use_multimesh: bool = false

## Density multiplier per LOD level increase.
## At LOD 0 density is full (1.0×). At LOD 1 density is multiplied by this factor,
## at LOD 2 by factor², etc. Set to 1.0 to keep full density at all LODs.
@export_range(0.0, 1.0, 0.05) var lod_density_factor: float = 0.5

## Current LOD level (set by ChunkFeatureManager before build_for_chunk)
var _current_lod: int = 0
var _density_data: DensityMapData

class DensityMapData:
	var bytes: PackedByteArray
	var width: int
	var height: int

	func is_empty() -> bool:
		return bytes.is_empty()

func get_bounds() -> AABB:
	return AABB(Vector3.INF, Vector3.INF)

func intersects_chunk(_chunk_bounds: AABB) -> bool:
	return true

func build_for_chunk(
	chunk_bounds: AABB,
	terrain_sampler: Callable,
	volumes: Array[VolumeDefinition],
	terrain_definition: TerrainDefinition,
	neighbour_placements: Array[ChunkFeatureInstance] = []
) -> Array[ChunkFeatureInstance]:
	if not prop_scene or density <= 0:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_definition.generation_seed + seed_offset + hash(rule_id)
	_load_density_data()
	var effective_density := density * pow(lod_density_factor, _current_lod)
	var base_count := int(chunk_bounds.size.x * chunk_bounds.size.z * effective_density)
	for constraint in constraints:
		constraint.reset()
		constraint.seed_from_neighbours(neighbour_placements)
	var placement_context := PropPlacementContext.new(
		terrain_definition.sea_level,
		[],
		volumes,
		rng,
		terrain_definition
	)
	var placements: Array[ChunkFeatureInstance] = []
	for _attempt in range(base_count * 3):
		if placements.size() >= base_count * 2:
			break
		var x := rng.randf_range(chunk_bounds.position.x, chunk_bounds.position.x + chunk_bounds.size.x)
		var z := rng.randf_range(chunk_bounds.position.z, chunk_bounds.position.z + chunk_bounds.size.z)
		var pos_2d := Vector2(x, z)
		var terrain_sample: TerrainSample = terrain_sampler.call(pos_2d)
		if not terrain_sample or not terrain_sample.is_valid:
			continue
		if density_map:
			var uv := _world_to_density_uv(pos_2d, chunk_bounds, terrain_definition.terrain_size)
			if rng.randf() > _sample_density_map(uv):
				continue
		placement_context.position_2d = pos_2d
		placement_context.terrain_sample = terrain_sample
		var valid := true
		for constraint in constraints:
			if not constraint.validate(placement_context):
				valid = false
				break
		if not valid:
			continue
		for constraint in constraints:
			constraint.on_placement_accepted(pos_2d)
		var placement := PropPlacement.new()
		placement.position = Vector3(x, terrain_sample.height + ground_offset, z)
		placement.prop_scene = prop_scene
		placement.rule_id = rule_id
		var slope := rad_to_deg(acos(terrain_sample.normal.dot(Vector3.UP)))
		if align_to_normal and max_tilt > 0:
			var tilt_angle := minf(slope, max_tilt)
			var tilt_axis := Vector3.UP.cross(terrain_sample.normal).normalized()
			if tilt_axis.length_squared() > 0.01:
				placement.rotation = Vector3(
					tilt_axis.x * deg_to_rad(tilt_angle),
					rng.randf() * TAU if random_rotation else 0.0,
					tilt_axis.z * deg_to_rad(tilt_angle)
				)
			else:
				placement.rotation = Vector3(0, rng.randf() * TAU if random_rotation else 0.0, 0)
		else:
			placement.rotation = Vector3(0, rng.randf() * TAU if random_rotation else 0.0, 0)
		placement.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		placements.append(placement)
	return placements

func _world_to_density_uv(world_pos: Vector2, chunk_bounds: AABB, terrain_size: Vector2) -> Vector2:
	var u := (world_pos.x + terrain_size.x / 2) / terrain_size.x
	var v := (world_pos.y + terrain_size.y / 2) / terrain_size.y
	return Vector2(clampf(u, 0, 1), clampf(v, 0, 1))

func _sample_density_map(uv: Vector2) -> float:
	if not _density_data or _density_data.is_empty():
		return 1.0
	var px := int(uv.x * (_density_data.width - 1))
	var py := int(uv.y * (_density_data.height - 1))
	return _density_data.bytes[py * _density_data.width + px] / 255.0

func _load_density_data() -> void:
	_density_data = DensityMapData.new()
	if not density_map:
		return
	var img := density_map.get_image()
	if not img:
		return
	img.convert(Image.FORMAT_L8)
	_density_data.bytes = img.get_data()
	_density_data.width = img.get_width()
	_density_data.height = img.get_height()
