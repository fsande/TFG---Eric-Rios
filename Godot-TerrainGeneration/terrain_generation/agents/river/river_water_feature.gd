## @brief Chunk feature that produces a river water surface mesh.
##
## @details Uses SpawnMode.SHARED — the full river ribbon mesh is built once
## (lazily on first spawn) and lives in the shared features container.
## It is reference-counted against overlapping loaded chunks and despawned
## only when the last overlapping chunk unloads.
##
## Uses Option B: the mesh is built from TerrainDefinition at spawn time
## rather than eagerly during generation, so there is no dependency on
## the short-lived TerrainGenerationContext.
@tool
class_name RiverWaterFeature extends ChunkFeature

## Downstream river path (mountain → coast) in world-space XZ.
var river_path: Array[Vector2] = []

## World-space AABB enclosing the river (with padding for width + falloff).
var river_bounds: AABB = AABB()

## Base river width in world units.
var river_width: float = 5.0

## Width multiplier at the downstream (coast) end.
var width_multiplier: float = 1.5

## Height offset above the carved riverbed surface.
var water_offset: float = 0.5

## Number of extra vertices across the river width for the ribbon mesh.
var cross_subdivisions: int = 2

## Resample the path to this spacing (world units) for uniform mesh density.
var resample_spacing: float = 2.0

## Material applied to the water surface mesh.
var water_material: Material = null

## Human-readable label for debugging.
var display_name: String = ""

## Cached ArrayMesh — built lazily on first build_for_chunk() call.
var _cached_mesh: ArrayMesh = null

func _init() -> void:
	rule_id = "river_water"
	priority = 100
	spawn_mode = SpawnMode.SHARED
	max_lod_level = 2

## Convenience factory used by RiverAgent to populate all fields at once.
static func create(
	p_downstream_path: Array[Vector2],
	p_bounds: AABB,
	p_river_width: float,
	p_width_multiplier: float,
	p_water_offset: float,
	p_cross_subdivisions: int,
	p_resample_spacing: float,
	p_material: Material,
	p_display_name: String
) -> RiverWaterFeature:
	var feature := RiverWaterFeature.new()
	feature.river_path = p_downstream_path
	feature.river_bounds = p_bounds
	feature.river_width = p_river_width
	feature.width_multiplier = p_width_multiplier
	feature.water_offset = p_water_offset
	feature.cross_subdivisions = p_cross_subdivisions
	feature.resample_spacing = p_resample_spacing
	feature.water_material = p_material
	feature.display_name = p_display_name
	feature.rule_id = "river_water_%s" % p_display_name
	return feature

func get_bounds() -> AABB:
	return river_bounds

func intersects_chunk(chunk_bounds: AABB) -> bool:
	return river_bounds.intersects(chunk_bounds)

## Build the river water mesh for the given chunk.
##
## For SHARED features the ChunkFeatureManager calls this once with the
## feature's own bounds. The mesh is built lazily and cached so repeated
## calls (which should not happen for SHARED) are free.
func build_for_chunk(
	_chunk_bounds: AABB,
	_terrain_sampler: Callable,
	_volumes: Array[VolumeDefinition],
	terrain_definition: TerrainDefinition
) -> Array[ChunkFeatureInstance]:
	if river_path.size() < 2:
		push_warning("RiverWaterFeature: Path has fewer than 2 points")
		return []
	if not _cached_mesh:
		_cached_mesh = RiverMeshBuilder.build_from_definition(
			river_path,
			terrain_definition,
			river_width,
			width_multiplier,
			water_offset,
			cross_subdivisions,
			resample_spacing
		)
	if not _cached_mesh:
		push_warning("RiverWaterFeature: Failed to build river mesh")
		return []
	var instance := RiverMeshInstance.new()
	instance.mesh = _cached_mesh
	instance.material = water_material
	instance.position = Vector3.ZERO
	return [instance]

## A ChunkFeatureInstance that spawns a MeshInstance3D from an ArrayMesh.
class RiverMeshInstance extends ChunkFeatureInstance:
	var mesh: ArrayMesh = null
	var material: Material = null

	func spawn(parent: Node3D) -> Node3D:
		if not mesh:
			push_error("RiverMeshInstance: No mesh set")
			return null
		if is_spawned and spawned_node and is_instance_valid(spawned_node):
			return spawned_node
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = position
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if material:
			mi.material_override = material
		parent.add_child(mi)
		is_spawned = true
		spawned_node = mi
		return mi
