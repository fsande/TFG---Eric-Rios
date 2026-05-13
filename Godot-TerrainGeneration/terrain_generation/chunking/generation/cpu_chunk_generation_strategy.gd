## @brief CPU-based chunk generation strategy.
##
## @details Hot path (height grid, mesh build, normals, tangents) runs in
## CpuChunkGeneratorNative (GDExtension). Volume application stays in GDScript
## since VolumeDefinition is a GDScript type.
## Thread-safe for concurrent chunk generation.
@tool
class_name CpuChunkGenerationStrategy extends ChunkGenerationStrategy

var _native_generator := CpuChunkGeneratorNative.new()

func _init(heightmap: Image) -> void:
	if heightmap:
		_native_generator.bake_heightmap(heightmap)

func get_processor_type() -> ProcessorType:
	return ProcessorType.CPU

func supports_async() -> bool:
	return true

## ChunkGenerator calls generate_height_grid first, then passes the result here.
## Deltas are already baked into height_grid by the time we receive it, so we
## only need to handle volumes on top of the pre-built grid.
func generate_chunk(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	lod_level: int,
	resolution: int,
	height_grid: PackedFloat32Array
) -> MeshData:
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("CpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if volumes.is_empty():
		return _native_generator.generate_chunk_from_grid(height_grid, chunk_bounds, resolution)
	if height_grid.is_empty():
		return null
	var current_time := Time.get_ticks_usec()
	var mesh_data: MeshData = _native_generator.generate_chunk_from_grid(
		height_grid, chunk_bounds, resolution
	)
	_emit_substep("mesh_build", (Time.get_ticks_usec() - current_time) / 1000.0)
	if not mesh_data:
		return null
	current_time = Time.get_ticks_usec()
	mesh_data = apply_volumes(mesh_data, volumes, chunk_bounds, resolution)
	_emit_substep("volumes", (Time.get_ticks_usec() - current_time) / 1000.0)
	return mesh_data

## Generates the height grid with delta maps applied entirely in native C++.
func generate_height_grid(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	if deltas.is_empty():
		return _native_generator.generate_height_grid(
			chunk_bounds, resolution,
			terrain_definition.terrain_size.x,
			terrain_definition.height_scale
		)
	var packed: Array[Dictionary] = []
	for delta in deltas:
		if not delta.delta_texture:
			continue
		if delta.delta_texture.get_format() != Image.FORMAT_RF:
			push_warning("CpuChunkGenerationStrategy: delta texture is not FORMAT_RF, skipping")
			continue
		packed.append({
			"image": delta.delta_texture,
			"bounds": delta.world_bounds,
			"intensity": delta.intensity,
			"blend_mode": delta.blend_mode_int(),
		})
	return _native_generator.generate_height_grid_with_deltas(
		chunk_bounds, resolution,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale,
		packed
	)

func apply_volumes(
	mesh_data: MeshData,
	volumes: Array[VolumeDefinition],
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
	var result := mesh_data
	for volume in volumes:
		if volume.volume_type == VolumeDefinition.VolumeType.SUBTRACTIVE:
			result = _apply_subtractive_volume(result, volume, chunk_bounds)
		elif volume.volume_type == VolumeDefinition.VolumeType.ADDITIVE:
			result = _apply_additive_volume(result, volume, chunk_bounds, resolution)
	return result

func _apply_subtractive_volume(
	mesh_data: MeshData,
	volume: VolumeDefinition,
	chunk_bounds: AABB
) -> MeshData:
	var chunk_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	var new_indices := PackedInt32Array()
	for i in range(0, mesh_data.indices.size(), 3):
		var idx0 := mesh_data.indices[i]
		var idx1 := mesh_data.indices[i + 1]
		var idx2 := mesh_data.indices[i + 2]
		var v0 := mesh_data.vertices[idx0] + chunk_center
		var v1 := mesh_data.vertices[idx1] + chunk_center
		var v2 := mesh_data.vertices[idx2] + chunk_center
		if volume.point_is_inside(v0) and volume.point_is_inside(v1) and volume.point_is_inside(v2):
			continue
		new_indices.append(idx0)
		new_indices.append(idx1)
		new_indices.append(idx2)
	if new_indices.size() < mesh_data.indices.size():
		var result := MeshData.new()
		result.initialize(mesh_data.vertices, new_indices, mesh_data.uvs)
		result.width = mesh_data.width
		result.height = mesh_data.height
		result.mesh_size = mesh_data.mesh_size
		result.cached_normals = mesh_data.cached_normals
		result.cached_tangents = mesh_data.cached_tangents
		return result
	return mesh_data

func _apply_additive_volume(
	mesh_data: MeshData,
	volume: VolumeDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
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
	var result := MeshData.new()
	result.initialize(new_vertices, new_indices, new_uvs)
	result.width = mesh_data.width
	result.height = mesh_data.height
	result.mesh_size = mesh_data.mesh_size
	return result
