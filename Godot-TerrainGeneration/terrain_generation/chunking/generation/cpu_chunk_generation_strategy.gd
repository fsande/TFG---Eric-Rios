## @brief CPU-based chunk generation strategy.
##
## @details Hot path (height grid, mesh build, normals, tangents) runs in
## CpuChunkGeneratorNative (GDExtension). Volume application stays in GDScript
## since VolumeDefinition is a GDScript type.
## Thread-safe for concurrent chunk generation.
@tool
class_name CpuChunkGenerationStrategy extends ChunkGenerationStrategy

var _native_generator := CpuChunkGeneratorNative.new() 

func _init(heightmap: Image) ->void:
	if heightmap:
		_native_generator.bake_heightmap(heightmap)

func get_processor_type() -> ProcessorType:
	return ProcessorType.CPU

func supports_async() -> bool:
	return true

## Generate a complete chunk. The native generator handles the full pipeline.
## If volumes are present, we generate the height grid first (GDScript applies
## deltas), then pass it back into the native mesh builder.
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
	var current_time := Time.get_ticks_usec()
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, 0)
	if volumes.is_empty():
		_emit_substep("height_grid", 0.0)
		var mesh_data: MeshData = _native_generator.generate_chunk(
			chunk_bounds, resolution,
			terrain_definition.terrain_size.x,
			terrain_definition.height_scale
		)
		_emit_substep("mesh_build", (Time.get_ticks_usec() - current_time) / 1000.0)
		return mesh_data
	_emit_substep("height_grid", (Time.get_ticks_usec() - current_time) / 1000.0)
	if height_grid.is_empty():
		return null
	current_time = Time.get_ticks_usec()
	var modified_grid := height_grid.duplicate()
	current_time = Time.get_ticks_usec()
	var mesh_data: MeshData = _native_generator.generate_chunk_from_grid(
		modified_grid, chunk_bounds, resolution
	)
	_emit_substep("mesh_build", (Time.get_ticks_usec() - current_time) / 1000.0)
	if not mesh_data:
		return null
	if not volumes.is_empty():
		current_time = Time.get_ticks_usec()
		mesh_data = apply_volumes(mesh_data, volumes, chunk_bounds, resolution)
		_emit_substep("volumes", (Time.get_ticks_usec() - current_time) / 1000.0)
	return mesh_data

## Generate height grid via native, then apply GDScript delta maps.
## Returns the modified grid ready for generate_chunk_from_grid.
func generate_height_grid(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var grid: PackedFloat32Array = _native_generator.generate_height_grid(
		chunk_bounds,
		resolution,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale
	)
	# Apply GDScript delta maps on top of the native height grid
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	if deltas.is_empty():
		return grid
	var terrain_size := terrain_definition.terrain_size.x
	var inv_res := 1.0 / float(resolution - 1) if resolution > 1 else 0.0
	for z in range(resolution):
		var v_local := float(z) * inv_res if resolution > 1 else 0.5
		var world_z := chunk_bounds.position.z + v_local * chunk_bounds.size.z
		for x in range(resolution):
			var u_local := float(x) * inv_res if resolution > 1 else 0.5
			var world_x := chunk_bounds.position.x + u_local * chunk_bounds.size.x
			var world_pos := Vector2(world_x, world_z)
			var idx := z * resolution + x
			var height := grid[idx]
			for delta in deltas:
				var delta_value := delta.sample_at(world_pos)
				if absf(delta_value) >= 0.0001:
					height = delta.apply_blend(height, delta_value)
			grid[idx] = height
	return grid

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
