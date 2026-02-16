## @brief Manages prop spawning and despawning for terrain chunks.
##
## @details Spawns props based on placement rules when chunks load,
## and cleans them up when chunks unload. Supports both regular node instancing
## and MultiMesh batching for better performance.
class_name ChunkPropManager extends RefCounted


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
	var terrain_sampler := _create_terrain_sampler(chunk)
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

func _create_terrain_sampler(chunk: ChunkMeshData) -> Callable:
	return func(world_pos: Vector2) -> TerrainSample:
		if not chunk.mesh_data or chunk.mesh_data.vertices.is_empty():
			return TerrainSample.invalid()
		var local_x := world_pos.x - chunk.world_position.x
		var local_z := world_pos.y - chunk.world_position.z
		var half_size := chunk.chunk_size / 2.0
		var u := (local_x + half_size.x) / chunk.chunk_size.x
		var v := (local_z + half_size.y) / chunk.chunk_size.y
		if u < 0 or u > 1 or v < 0 or v > 1:
			return TerrainSample.invalid()
		var grid_x := int(u * (chunk.mesh_data.width - 1))
		var grid_z := int(v * (chunk.mesh_data.height - 1))
		grid_x = clampi(grid_x, 0, chunk.mesh_data.width - 1)
		grid_z = clampi(grid_z, 0, chunk.mesh_data.height - 1)
		var idx := grid_z * chunk.mesh_data.width + grid_x
		if idx >= chunk.mesh_data.vertices.size():
			return TerrainSample.invalid()
		var vertex := chunk.mesh_data.vertices[idx]
		var normal := Vector3.UP
		if not chunk.mesh_data.cached_normals.is_empty() and idx < chunk.mesh_data.cached_normals.size():
			normal = chunk.mesh_data.cached_normals[idx]
		return TerrainSample.new(vertex.y + chunk.world_position.y, normal, true)
