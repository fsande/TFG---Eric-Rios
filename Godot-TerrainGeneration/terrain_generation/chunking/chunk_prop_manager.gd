## @brief Manages prop spawning and despawning for terrain chunks.
##
## @details Spawns props based on placement rules when chunks load,
## and cleans them up when chunks unload. Supports both regular node instancing
## and MultiMesh batching for better performance.
class_name ChunkPropManager extends RefCounted

## Distance for normal calculation as a fraction of terrain size (0.1% of terrain size)
const NORMAL_SAMPLE_DISTANCE_FRACTION: float = 0.001

## Minimum delta value to consider for height blending (avoids floating point noise)
const DELTA_EPSILON: float = 0.0001

var _terrain_definition: TerrainDefinition
## Dictionary[String, Array[PropPlacement]] - Maps chunk key to array of prop placements
var _spawned_props: Dictionary = {}
## Dictionary[String, Dictionary] - Maps chunk key to dict of rule_id -> PropMultiMeshGroup
var _spawned_multimesh_groups: Dictionary = {}
## Dictionary[String, Node3D] - Maps chunk key to prop container node
var _prop_containers: Dictionary = {}
var _parent_node: Node3D

func _init(terrain_def: TerrainDefinition, parent: Node3D) -> void:
	_terrain_definition = terrain_def
	_parent_node = parent

func spawn_props_for_chunk(chunk: ChunkMeshData, lod_level: int) -> int:
	if not _terrain_definition or not chunk:
		return 0
	var coord := chunk.chunk_coord
	var key := _make_key(coord)
	if _spawned_props.has(key):
		return 0
	var rules := _terrain_definition.get_prop_rules_for_lod(lod_level)
	if rules.is_empty():
		return 0
	var container := Node3D.new()
	container.name = "Props_%d_%d" % [coord.x, coord.y]
	container.position = chunk.world_position
	_parent_node.add_child(container)
	_prop_containers[key] = container
	var volumes := _terrain_definition.volume_definitions
	var chunk_bounds := chunk.aabb
	var terrain_sampler := _create_terrain_sampler(chunk_bounds)
	var all_placements: Array[PropPlacement] = []
	var multimesh_groups: Dictionary[String, PropMultiMeshGroup] = {}
	var spawned_count := 0
	for rule in rules:
		var rule_placements := rule.get_placements_for_chunk(
			chunk_bounds,
			terrain_sampler,
			volumes,
			_terrain_definition.generation_seed
		)
		if rule_placements.is_empty():
			continue
		for placement in rule_placements:
			var local_pos := placement.position - chunk.world_position
			placement.position = local_pos
		if rule.use_multimesh:
			var multimesh_group := PropMultiMeshGroup.new()
			var success := multimesh_group.spawn(
				container,
				rule_placements,
				rule.prop_scene,
				rule.rule_id
			)
			if success:
				multimesh_groups[rule.rule_id] = multimesh_group
				spawned_count += rule_placements.size()
			else:
				push_warning("Failed to create MultiMesh group for rule '%s'" % rule.rule_id)
		else:
			for placement in rule_placements:
				var node := placement.spawn(container)
				if node:
					spawned_count += 1
		all_placements.append_array(rule_placements)
	_spawned_props[key] = all_placements
	if not multimesh_groups.is_empty():
		_spawned_multimesh_groups[key] = multimesh_groups
	return spawned_count

func despawn_props_for_chunk(chunk_coord: Vector2i) -> void:
	var key := _make_key(chunk_coord)
	
	if not _spawned_props.has(key):
		return
	
	# Despawn regular props (only if they were not in a MultiMesh)
	var placements: Array = _spawned_props[key]
	for placement in placements:
		if placement is PropPlacement:
			# Only despawn if it has a spawned_node (wasn't in MultiMesh)
			if placement.spawned_node:
				placement.despawn()
	
	_spawned_props.erase(key)
	
	# Despawn MultiMesh groups
	if _spawned_multimesh_groups.has(key):
		var groups: Dictionary = _spawned_multimesh_groups[key]
		for group in groups.values():
			if group is PropMultiMeshGroup:
				group.despawn()
		_spawned_multimesh_groups.erase(key)
	
	# Remove container
	if _prop_containers.has(key):
		var container: Node3D = _prop_containers[key]
		if is_instance_valid(container):
			container.queue_free()
		_prop_containers.erase(key)

func despawn_all_props() -> void:
	for key in _spawned_props.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() >= 2:
			despawn_props_for_chunk(Vector2i(int(parts[0]), int(parts[1])))

func get_prop_count_for_chunk(chunk_coord: Vector2i) -> int:
	var key := _make_key(chunk_coord)
	if not _spawned_props.has(key):
		return 0
	return _spawned_props[key].size()

func get_total_prop_count() -> int:
	var total := 0
	for placements in _spawned_props.values():
		total += placements.size()
	return total

func has_props_for_chunk(chunk_coord: Vector2i) -> bool:
	return _spawned_props.has(_make_key(chunk_coord))

func _make_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

## Create a heightmap-based terrain sampler for prop placement.
## Samples directly from the terrain heightmap, ensuring consistent results across all LOD levels.
## @param chunk_bounds The world-space bounds of the chunk
## @return Callable that takes Vector2 world position and returns TerrainSample
func _create_terrain_sampler(chunk_bounds: AABB) -> Callable:
	var base_heightmap := _terrain_definition.get_base_heightmap()
	if not base_heightmap:
		push_error("ChunkPropManager: Failed to get base heightmap for terrain sampling")
		return func(_pos: Vector2) -> TerrainSample: return TerrainSample.invalid()
	var terrain_size := _terrain_definition.terrain_size.x
	var height_scale := _terrain_definition.height_scale
	var deltas := _terrain_definition.get_deltas_for_chunk(chunk_bounds)
	var normal_sample_distance := terrain_size * NORMAL_SAMPLE_DISTANCE_FRACTION
	return func(world_pos: Vector2) -> TerrainSample:
		var base_height := HeightmapSampler.sample_height_at(base_heightmap, world_pos, terrain_size)
		var height := base_height * height_scale
		for delta_map in deltas:
			var delta_value := delta_map.sample_at(world_pos)
			if absf(delta_value) >= DELTA_EPSILON:
				height = delta_map.apply_blend(height, delta_value)
		var pos_x_plus := world_pos + Vector2(normal_sample_distance, 0)
		var pos_x_minus := world_pos - Vector2(normal_sample_distance, 0)
		var pos_z_plus := world_pos + Vector2(0, normal_sample_distance)
		var pos_z_minus := world_pos - Vector2(0, normal_sample_distance)
		var h_x_plus := HeightmapSampler.sample_height_at(base_heightmap, pos_x_plus, terrain_size) * height_scale
		var h_x_minus := HeightmapSampler.sample_height_at(base_heightmap, pos_x_minus, terrain_size) * height_scale
		var h_z_plus := HeightmapSampler.sample_height_at(base_heightmap, pos_z_plus, terrain_size) * height_scale
		var h_z_minus := HeightmapSampler.sample_height_at(base_heightmap, pos_z_minus, terrain_size) * height_scale
		for delta_map in deltas:
			var delta_x_plus := delta_map.sample_at(pos_x_plus)
			if absf(delta_x_plus) >= DELTA_EPSILON:
				h_x_plus = delta_map.apply_blend(h_x_plus, delta_x_plus)
			var delta_x_minus := delta_map.sample_at(pos_x_minus)
			if absf(delta_x_minus) >= DELTA_EPSILON:
				h_x_minus = delta_map.apply_blend(h_x_minus, delta_x_minus)
			var delta_z_plus := delta_map.sample_at(pos_z_plus)
			if absf(delta_z_plus) >= DELTA_EPSILON:
				h_z_plus = delta_map.apply_blend(h_z_plus, delta_z_plus)
			var delta_z_minus := delta_map.sample_at(pos_z_minus)
			if absf(delta_z_minus) >= DELTA_EPSILON:
				h_z_minus = delta_map.apply_blend(h_z_minus, delta_z_minus)
		var dx := (h_x_plus - h_x_minus) / (2.0 * normal_sample_distance)
		var dz := (h_z_plus - h_z_minus) / (2.0 * normal_sample_distance)
		var tangent_x := Vector3(1, dx, 0).normalized()
		var tangent_z := Vector3(0, dz, 1).normalized()
		var normal := tangent_z.cross(tangent_x).normalized()
		return TerrainSample.new(height, normal, true)
		
