## @brief Manages chunk feature spawning and despawning for terrain chunks.
##
## @details Spawns chunk features based on rules when chunks load,
## and cleans them up when chunks unload.
##
## Supports two spawn modes:
## - PER_CHUNK: Features produce instances per chunk (props, grass).
##   Supports both regular node instancing and MultiMesh batching.
## - SHARED: Features spawn a single set of instances when the first
##   overlapping chunk loads, and despawn when the last one unloads.
##   Ideal for continuous geometry that spans multiple chunks (rivers, roads).
class_name ChunkFeatureManager extends RefCounted

var _terrain_definition: TerrainDefinition

## Dictionary[String, Array[ChunkFeatureInstance]] — chunk key  spawned instances
var _spawned_instances: Dictionary = {}
## Dictionary[String, Dictionary] — chunk key  { rule_id: PropMultiMeshGroup }
var _spawned_multimesh_groups: Dictionary = {}
## Dictionary[String, Node3D] — chunk key  per-chunk container node
var _chunk_containers: Dictionary = {}

## Container node for shared features (sibling to per-chunk containers)
var _shared_container: Node3D = null
## Dictionary[ChunkFeature, Array[Vector2i]] — feature  loaded chunk coords that overlap it
var _shared_feature_refs: Dictionary = {}
## Dictionary[ChunkFeature, Array[ChunkFeatureInstance]] — feature  spawned instances
var _shared_spawned_instances: Dictionary = {}
## Dictionary[ChunkFeature, Dictionary] — feature  { rule_id: PropMultiMeshGroup }
var _shared_multimesh_groups: Dictionary = {}

var _parent_node: Node3D

func _init(terrain_def: TerrainDefinition, parent: Node3D) -> void:
	_terrain_definition = terrain_def
	_parent_node = parent

## Spawn all applicable features for a loaded chunk.
## @param chunk The chunk that was just loaded.
## @param lod_level The LOD level of the loaded chunk.
## @return Total number of feature instances spawned.
func spawn_features_for_chunk(chunk: ChunkMeshData, lod_level: int) -> int:
	if not _terrain_definition or not chunk:
		return 0
	var features := _terrain_definition.get_chunk_features_for_lod(lod_level)
	if features.is_empty():
		return 0
	var spawned_count := 0
	for feature in features:
		match feature.spawn_mode:
			ChunkFeature.SpawnMode.PER_CHUNK:
				spawned_count += _spawn_per_chunk_feature(feature, chunk, lod_level)
			ChunkFeature.SpawnMode.SHARED:
				spawned_count += _spawn_shared_feature(feature, chunk, lod_level)
	return spawned_count

## Despawn all features associated with a chunk.
## @param chunk_coord The coordinate of the chunk being unloaded.
func despawn_features_for_chunk(chunk_coord: Vector2i) -> void:
	_despawn_per_chunk(chunk_coord)
	_release_shared_refs(chunk_coord)

## Despawn all features across all chunks.
func despawn_all_features() -> void:
	# Despawn PER_CHUNK
	for key in _spawned_instances.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() >= 2:
			_despawn_per_chunk(Vector2i(int(parts[0]), int(parts[1])))

	# Despawn SHARED
	for feature in _shared_spawned_instances.keys():
		_despawn_shared_feature(feature)
	_shared_feature_refs.clear()
	_shared_spawned_instances.clear()
	_shared_multimesh_groups.clear()

	if _shared_container and is_instance_valid(_shared_container):
		_shared_container.queue_free()
		_shared_container = null

## Get the number of per-chunk feature instances for a specific chunk.
func get_feature_count_for_chunk(chunk_coord: Vector2i) -> int:
	var key := _make_key(chunk_coord)
	if not _spawned_instances.has(key):
		return 0
	return _spawned_instances[key].size()

## Get the total number of spawned feature instances (per-chunk + shared).
func get_total_feature_count() -> int:
	var total := 0
	for placements in _spawned_instances.values():
		total += placements.size()
	for instances in _shared_spawned_instances.values():
		total += instances.size()
	return total

## Check whether any per-chunk features are spawned for a chunk.
func has_features_for_chunk(chunk_coord: Vector2i) -> bool:
	return _spawned_instances.has(_make_key(chunk_coord))

## Get the number of active shared features.
func get_shared_feature_count() -> int:
	return _shared_spawned_instances.size()


## Spawn a single PER_CHUNK feature for a chunk.
## @return Number of instances spawned.
func _spawn_per_chunk_feature(feature: ChunkFeature, chunk: ChunkMeshData, _lod_level: int) -> int:
	var coord := chunk.chunk_coord
	var key := _make_key(coord)
	var container: Node3D
	if _chunk_containers.has(key):
		container = _chunk_containers[key]
	else:
		container = Node3D.new()
		container.name = "Features_%d_%d" % [coord.x, coord.y]
		container.position = chunk.world_position
		_parent_node.add_child(container)
		_chunk_containers[key] = container
	var chunk_bounds := chunk.aabb
	var volumes := _terrain_definition.volume_definitions
	var terrain_sampler := _create_terrain_sampler(chunk_bounds)
	var prop_rule := feature as PropPlacementRule
	if prop_rule:
		prop_rule._current_lod = _lod_level
	var instances := feature.build_for_chunk(
		chunk_bounds,
		terrain_sampler,
		volumes,
		_terrain_definition
	)
	if instances.is_empty():
		return 0
	for instance in instances:
		instance.position = instance.position - chunk.world_position
	var spawned_count := 0
	if prop_rule and prop_rule.use_multimesh:
		var prop_placements: Array[PropPlacement] = []
		for instance in instances:
			if instance is PropPlacement:
				prop_placements.append(instance)
		if not prop_placements.is_empty():
			var multimesh_group := PropMultiMeshGroup.new()
			var success := multimesh_group.spawn(
				container,
				prop_placements,
				prop_rule.prop_scene,
				feature.rule_id
			)
			if success:
				if not _spawned_multimesh_groups.has(key):
					_spawned_multimesh_groups[key] = {}
				_spawned_multimesh_groups[key][feature.rule_id] = multimesh_group
				spawned_count += prop_placements.size()
			else:
				push_warning("ChunkFeatureManager: Failed to create MultiMesh group for rule '%s'" % feature.rule_id)
	else:
		for instance in instances:
			var node := instance.spawn(container)
			if node:
				spawned_count += 1
	if not _spawned_instances.has(key):
		_spawned_instances[key] = []
	_spawned_instances[key].append_array(instances)
	return spawned_count

## Despawn all PER_CHUNK instances for a chunk.
func _despawn_per_chunk(chunk_coord: Vector2i) -> void:
	var key := _make_key(chunk_coord)
	if _spawned_instances.has(key):
		var instances: Array = _spawned_instances[key]
		for instance in instances:
			if instance is ChunkFeatureInstance and instance.spawned_node:
				instance.despawn()
		_spawned_instances.erase(key)
	if _spawned_multimesh_groups.has(key):
		var groups: Dictionary = _spawned_multimesh_groups[key]
		for group in groups.values():
			if group is PropMultiMeshGroup:
				group.despawn()
		_spawned_multimesh_groups.erase(key)
	if _chunk_containers.has(key):
		var container: Node3D = _chunk_containers[key]
		if is_instance_valid(container):
			container.queue_free()
		_chunk_containers.erase(key)


## Handle a SHARED feature when a chunk loads.
## If the feature overlaps this chunk, add a reference. Spawn on first reference.
## @return Number of instances spawned (0 if already spawned).
func _spawn_shared_feature(feature: ChunkFeature, chunk: ChunkMeshData, _lod_level: int) -> int:
	if not feature.intersects_chunk(chunk.aabb):
		return 0
	var coord := chunk.chunk_coord
	if not _shared_feature_refs.has(feature):
		_shared_feature_refs[feature] = []
	var refs: Array = _shared_feature_refs[feature]
	if refs.has(coord):
		return 0
	refs.append(coord)
	if _shared_spawned_instances.has(feature):
		return 0
	return _do_spawn_shared(feature)

## Actually spawn a SHARED feature's content into the shared container.
## @return Number of instances spawned.
func _do_spawn_shared(feature: ChunkFeature) -> int:
	_ensure_shared_container()
	var feature_bounds := feature.get_bounds()
	var volumes := _terrain_definition.volume_definitions
	var terrain_sampler := _create_terrain_sampler(feature_bounds)
	var instances := feature.build_for_chunk(
		feature_bounds,
		terrain_sampler,
		volumes,
		_terrain_definition
	)
	var spawned_count := 0
	var prop_rule := feature as PropPlacementRule
	if prop_rule and prop_rule.use_multimesh:
		var prop_placements: Array[PropPlacement] = []
		for inst in instances:
			if inst is PropPlacement:
				prop_placements.append(inst)
		if not prop_placements.is_empty():
			var multimesh_group := PropMultiMeshGroup.new()
			var success := multimesh_group.spawn(
				_shared_container,
				prop_placements,
				prop_rule.prop_scene,
				feature.rule_id
			)
			if success:
				_shared_multimesh_groups[feature] = { feature.rule_id: multimesh_group }
				spawned_count += prop_placements.size()
			else:
				push_warning("ChunkFeatureManager: Failed to create shared MultiMesh for '%s'" % feature.rule_id)
	else:
		for instance in instances:
			var node := instance.spawn(_shared_container)
			if node:
				spawned_count += 1
	_shared_spawned_instances[feature] = instances
	return spawned_count

## Release shared feature references for an unloading chunk.
## Despawns any shared feature whose last reference is removed.
func _release_shared_refs(chunk_coord: Vector2i) -> void:
	var features_to_despawn: Array[ChunkFeature] = []
	for feature in _shared_feature_refs.keys():
		var refs: Array = _shared_feature_refs[feature]
		refs.erase(chunk_coord)
		if refs.is_empty():
			features_to_despawn.append(feature)
	for feature in features_to_despawn:
		_despawn_shared_feature(feature)
		_shared_feature_refs.erase(feature)

## Despawn all instances of a SHARED feature.
func _despawn_shared_feature(feature: ChunkFeature) -> void:
	if _shared_spawned_instances.has(feature):
		var instances: Array = _shared_spawned_instances[feature]
		for instance in instances:
			if instance is ChunkFeatureInstance and instance.spawned_node:
				instance.despawn()
		_shared_spawned_instances.erase(feature)
	if _shared_multimesh_groups.has(feature):
		var groups: Dictionary = _shared_multimesh_groups[feature]
		for group in groups.values():
			if group is PropMultiMeshGroup:
				group.despawn()
		_shared_multimesh_groups.erase(feature)

## Create the shared container node if it doesn't exist.
func _ensure_shared_container() -> void:
	if _shared_container and is_instance_valid(_shared_container):
		return
	_shared_container = Node3D.new()
	_shared_container.name = "SharedFeatures"
	_parent_node.add_child(_shared_container)


func _make_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

## Create a heightmap-based terrain sampler for feature placement.
## sampling across all consumers (feature manager, benchmarks, etc.).
## @param chunk_bounds The world-space bounds of the area to sample.
## @return Callable that takes Vector2 world position and returns TerrainSample.
func _create_terrain_sampler(chunk_bounds: AABB) -> Callable:
	return _terrain_definition.create_terrain_sampler(chunk_bounds)
