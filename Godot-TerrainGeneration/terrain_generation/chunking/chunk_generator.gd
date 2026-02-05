## @brief Generates terrain chunks from TerrainDefinition at any resolution.
##
## @details Creates chunk meshes on-demand by sampling the heightmap and
## applying height deltas and volume operations at LOD-appropriate resolution.
## Uses the Strategy pattern to support CPU, GPU, or hybrid generation.
class_name ChunkGenerator extends RefCounted

const MIN_RESOLUTION := 4
const MAX_RESOLUTION := 256

var _terrain_definition: TerrainDefinition
var _base_resolution: int = 64
var _generation_strategy: ChunkGenerationStrategy

func _init(terrain_def: TerrainDefinition, base_resolution: int, use_gpu: bool) -> void:
	_terrain_definition = terrain_def
	_base_resolution = clampi(base_resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	if use_gpu:
		_generation_strategy = GpuChunkGenerationStrategy.new()
	else:
		_generation_strategy = CpuChunkGenerationStrategy.new()

func generate_chunk(chunk_coord: Vector2i, chunk_size: Vector2, lod_level: int = 0) -> ChunkMeshData:
	if not _terrain_definition or not _terrain_definition.is_valid():
		push_error("ChunkGenerator: Invalid terrain definition")
		return null
	if _generation_strategy:
		return _generation_strategy.generate_chunk(
			_terrain_definition, chunk_coord, chunk_size, lod_level, _base_resolution
		)
	return _generate_chunk_legacy(chunk_coord, chunk_size, lod_level)

func _generate_chunk_legacy(chunk_coord: Vector2i, chunk_size: Vector2, lod_level: int = 0) -> ChunkMeshData:
	var chunk_bounds := _calculate_chunk_bounds(chunk_coord, chunk_size)
	var resolution := _calculate_resolution_for_lod(lod_level)
	var height_grid := _generate_height_grid(chunk_bounds, resolution)
	if height_grid.is_empty():
		return null
	var mesh_data := _build_mesh_from_height_grid(height_grid, chunk_bounds, resolution)
	if not mesh_data:
		return null
	var volumes := _terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if not volumes.is_empty():
		mesh_data = _apply_volumes(mesh_data, volumes, chunk_bounds, resolution)
	var world_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	return ChunkMeshData.new(chunk_coord, world_center, chunk_size, mesh_data)

func _calculate_chunk_bounds(chunk_coord: Vector2i, chunk_size: Vector2) -> AABB:
	var terrain_size := _terrain_definition.terrain_size
	var half_terrain := terrain_size / 2.0
	var chunk_origin := Vector3(
		chunk_coord.x * chunk_size.x - half_terrain.x,
		0,
		chunk_coord.y * chunk_size.y - half_terrain.y
	)
	var height_range := _terrain_definition.height_scale * 2.0
	return AABB(
		Vector3(chunk_origin.x, -height_range, chunk_origin.z),
		Vector3(chunk_size.x, height_range * 2.0, chunk_size.y)
	)

func _calculate_resolution_for_lod(lod_level: int) -> int:
	var divisor := 1 << lod_level
	var resolution := maxi(int(float(_base_resolution) / float(divisor)), MIN_RESOLUTION)
	return resolution

func _generate_height_grid(chunk_bounds: AABB, resolution: int) -> PackedFloat32Array:
	var base_heightmap := _terrain_definition.get_base_heightmap()
	if not base_heightmap:
		push_error("ChunkGenerator: Failed to get base heightmap")
		return PackedFloat32Array()
	var height_grid := PackedFloat32Array()
	height_grid.resize(resolution * resolution)
	var terrain_size := _terrain_definition.terrain_size.x
	var height_scale := _terrain_definition.height_scale
	var deltas := _terrain_definition.get_deltas_for_chunk(chunk_bounds)
	for z in range(resolution):
		for x in range(resolution):
			var u := float(x) / float(resolution - 1) if resolution > 1 else 0.5
			var v := float(z) / float(resolution - 1) if resolution > 1 else 0.5
			var world_x := chunk_bounds.position.x + u * chunk_bounds.size.x
			var world_z := chunk_bounds.position.z + v * chunk_bounds.size.z
			var world_pos := Vector2(world_x, world_z)
			var base_height := HeightmapSampler.sample_height_at(base_heightmap, world_pos, terrain_size)
			var height := base_height * height_scale
			for delta in deltas:
				var delta_value := delta.sample_at(world_pos)
				if absf(delta_value) >= 0.0001:
					height = delta.apply_blend(height, delta_value)
			var index := z * resolution + x
			height_grid[index] = height
	return height_grid

func _build_mesh_from_height_grid(height_grid: PackedFloat32Array, chunk_bounds: AABB, resolution: int) -> MeshData:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(resolution * resolution)
	uvs.resize(resolution * resolution)
	for z in range(resolution):
		for x in range(resolution):
			var u := float(x) / float(resolution - 1) if resolution > 1 else 0.5
			var v := float(z) / float(resolution - 1) if resolution > 1 else 0.5
			var local_x := (u - 0.5) * chunk_bounds.size.x
			var local_z := (v - 0.5) * chunk_bounds.size.z
			var index := z * resolution + x
			var height := height_grid[index]
			vertices[index] = Vector3(local_x, height, local_z)
			uvs[index] = Vector2(u, v)
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var v0 := z * resolution + x
			var v1 := v0 + 1
			var v2 := v0 + resolution
			var v3 := v2 + 1
			indices.append(v0)
			indices.append(v1)
			indices.append(v2)
			indices.append(v1)
			indices.append(v3)
			indices.append(v2)
	var mesh_data := MeshData.new(vertices, indices, uvs)
	mesh_data.width = resolution
	mesh_data.height = resolution
	mesh_data.mesh_size = Vector2(chunk_bounds.size.x, chunk_bounds.size.z)
	return mesh_data

func _apply_volumes(mesh_data: MeshData, volumes: Array[VolumeDefinition], chunk_bounds: AABB, resolution: int) -> MeshData:
	var result := mesh_data
	for volume in volumes:
		if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE:
			result = _apply_subtractive_volume(result, volume, chunk_bounds, resolution)
		elif volume.volume_type == VolumeDefinition.VolumeType.ADDITIVE:
			result = _apply_additive_volume(result, volume, chunk_bounds, resolution)
	return result

func _apply_subtractive_volume(mesh_data: MeshData, volume: VolumeDefinition, chunk_bounds: AABB, _resolution: int) -> MeshData:
	var chunk_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	var removed_count := 0
	var new_indices := PackedInt32Array()
	for i in range(0, mesh_data.indices.size(), 3):
		var idx0 := mesh_data.indices[i]
		var idx1 := mesh_data.indices[i + 1]
		var idx2 := mesh_data.indices[i + 2]
		var v0 := mesh_data.vertices[idx0] + chunk_center
		var v1 := mesh_data.vertices[idx1] + chunk_center
		var v2 := mesh_data.vertices[idx2] + chunk_center
		var all_inside := volume.point_is_inside(v0) and volume.point_is_inside(v1) and volume.point_is_inside(v2)
		if all_inside:
			removed_count += 1
			continue
		new_indices.append(idx0)
		new_indices.append(idx1)
		new_indices.append(idx2)
	if removed_count > 0:
		var result := MeshData.new(mesh_data.vertices, new_indices, mesh_data.uvs)
		result.width = mesh_data.width
		result.height = mesh_data.height
		result.mesh_size = mesh_data.mesh_size
		return result
	return mesh_data

func _apply_additive_volume(mesh_data: MeshData, volume: VolumeDefinition, chunk_bounds: AABB, resolution: int) -> MeshData:
	var volume_mesh := volume.generate_mesh(chunk_bounds, resolution)
	if not volume_mesh or volume_mesh.vertices.is_empty():
		return mesh_data
	var chunk_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	var base_vertex_count := mesh_data.vertices.size()
	var new_vertices := mesh_data.vertices.duplicate()
	var new_uvs := mesh_data.uvs.duplicate()
	var new_indices := mesh_data.indices.duplicate()
	for vertex in volume_mesh.vertices:
		new_vertices.append(vertex - chunk_center)
	for uv in volume_mesh.uvs:
		new_uvs.append(uv)
	for idx in volume_mesh.indices:
		new_indices.append(idx + base_vertex_count)
	var result := MeshData.new(new_vertices, new_indices, new_uvs)
	result.width = mesh_data.width
	result.height = mesh_data.height
	result.mesh_size = mesh_data.mesh_size
	return result
