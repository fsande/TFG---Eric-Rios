## @brief GPU-accelerated chunk generation strategy.
##
## @details Generates chunk meshes using compute shaders for parallel processing.
## Leverages GpuResourceManager for shared rendering device and shader caching.
## All GPU operations are routed through GpuWorkQueue for thread safety.
@tool
class_name GpuChunkGenerationStrategy extends ChunkGenerationStrategy

const HEIGHT_GRID_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_height_grid.glsl"
const MESH_BUILDER_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_mesh_builder.glsl"
const NORMAL_CALC_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_normal_calculator.glsl"

var _gpu_manager: GpuResourceManager = null
var _fallback_strategy: CpuChunkGenerationStrategy = null

func _init() -> void:
	_fallback_strategy = CpuChunkGenerationStrategy.new()

func get_processor_type() -> ProcessorType:
	return ProcessorType.GPU

func supports_async() -> bool:
	return true

func generate_chunk(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	lod_level: int,
	base_resolution: int
) -> ChunkMeshData:
	_gpu_manager = GpuResourceManager.get_singleton()
	if not _gpu_manager or not _gpu_manager.is_gpu_available():
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
		)
	var work_queue := GpuWorkQueue.get_singleton()
	if not work_queue:
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
		)
	var generation_callable := _create_gpu_generation_callable(
		terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
	)
	var result: ChunkMeshData = work_queue.execute_on_main_thread(generation_callable)
	if not result:
		push_warning("GpuChunkGenerationStrategy: GPU generation failed, falling back to CPU")
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
		)
	return result

func _create_gpu_generation_callable(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	lod_level: int,
	base_resolution: int
) -> Callable:
	return func() -> ChunkMeshData:
		return _generate_chunk_gpu(
			terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
		)

func _generate_chunk_gpu(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	lod_level: int,
	base_resolution: int
) -> ChunkMeshData:
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("GpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var rd := _gpu_manager.get_rendering_device()
	if not rd:
		return null
	var chunk_bounds := calculate_chunk_bounds(terrain_definition, chunk_coord, chunk_size)
	var resolution := calculate_resolution_for_lod(base_resolution, lod_level)
	var height_grid := _generate_height_grid_gpu(rd, terrain_definition, chunk_bounds, resolution)
	if height_grid.is_empty():
		return null
	var mesh_result := _build_mesh_gpu(rd, height_grid, chunk_bounds, resolution)
	if not mesh_result:
		return null
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if not volumes.is_empty():
		mesh_result = _apply_volumes_cpu(mesh_result, volumes, chunk_bounds, resolution)
	var world_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	return ChunkMeshData.new(chunk_coord, world_center, chunk_size, mesh_result)

func _generate_height_grid_gpu(
	rd: RenderingDevice,
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var base_heightmap := terrain_definition.get_base_heightmap()
	if not base_heightmap:
		push_error("GpuChunkGenerationStrategy: No base heightmap available")
		return PackedFloat32Array()
	var shader_rid := _gpu_manager.get_or_create_shader(HEIGHT_GRID_SHADER)
	if not shader_rid.is_valid():
		push_error("GpuChunkGenerationStrategy: Failed to load height grid shader")
		return PackedFloat32Array()
	var pipeline_rid := _gpu_manager.get_or_create_pipeline(shader_rid)
	if not pipeline_rid.is_valid():
		return PackedFloat32Array()
	var heightmap_texture := GpuTextureHelper.create_heightmap_texture(rd, base_heightmap)
	var sampler := GpuResourceHelper.create_linear_clamp_sampler(rd)
	var output_size := resolution * resolution * 4
	var output_buffer := rd.storage_buffer_create(output_size)
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	var delta_data := PackedFloat32Array()
	var delta_resolution := 0
	var delta_bounds := AABB()
	var delta_intensity := 1.0
	var blend_mode := 0
	if not deltas.is_empty():
		var first_delta := deltas[0]
		if first_delta.delta_texture:
			delta_resolution = first_delta.delta_texture.get_width()
			delta_bounds = first_delta.world_bounds
			delta_intensity = first_delta.intensity
			blend_mode = _get_blend_mode_int(first_delta.blend_strategy)
			for y in range(delta_resolution):
				for x in range(delta_resolution):
					delta_data.append(first_delta.delta_texture.get_pixel(x, y).r)
	if delta_data.is_empty():
		delta_data.resize(1)
		delta_data[0] = 0.0
		delta_resolution = 1
	var delta_buffer := rd.storage_buffer_create(delta_data.size() * 4, delta_data.to_byte_array())
	var delta_params := PackedByteArray()
	delta_params.append_array(PackedInt32Array([deltas.size()]).to_byte_array())
	delta_params.append_array(PackedInt32Array([delta_resolution]).to_byte_array())
	delta_params.append_array(PackedFloat32Array([delta_bounds.position.x]).to_byte_array())
	delta_params.append_array(PackedFloat32Array([delta_bounds.position.z]).to_byte_array())
	delta_params.append_array(PackedFloat32Array([delta_bounds.size.x]).to_byte_array())
	delta_params.append_array(PackedFloat32Array([delta_bounds.size.z]).to_byte_array())
	delta_params.append_array(PackedFloat32Array([delta_intensity]).to_byte_array())
	delta_params.append_array(PackedInt32Array([blend_mode]).to_byte_array())
	var delta_params_buffer := rd.storage_buffer_create(delta_params.size(), delta_params)
	var uniforms: Array[RDUniform] = []
	uniforms.append(GpuResourceHelper.create_sampler_texture_uniform(0, sampler, heightmap_texture))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, output_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, delta_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(3, delta_params_buffer))
	var uniform_set := rd.uniform_set_create(uniforms, shader_rid, 0)
	var push_constants := GpuResourceHelper.pack_push_constants([
		chunk_bounds.position.x,
		chunk_bounds.position.z,
		chunk_bounds.size.x,
		chunk_bounds.size.z,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale,
		resolution,
		0  # padding
	])
	GpuResourceHelper.dispatch_compute_2d(
		rd, pipeline_rid, uniform_set, shader_rid,
		push_constants, resolution, resolution, 8
	)
	var result_bytes := rd.buffer_get_data(output_buffer)
	var result := result_bytes.to_float32_array()
	GpuResourceHelper.free_rids(rd, [
		uniform_set, output_buffer, delta_buffer, delta_params_buffer,
		heightmap_texture, sampler
	])
	return result

func _build_mesh_gpu(
	rd: RenderingDevice,
	height_grid: PackedFloat32Array,
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
	var shader_rid := _gpu_manager.get_or_create_shader(MESH_BUILDER_SHADER)
	if not shader_rid.is_valid():
		return _build_mesh_cpu(height_grid, chunk_bounds, resolution)
	var pipeline_rid := _gpu_manager.get_or_create_pipeline(shader_rid)
	if not pipeline_rid.is_valid():
		return _build_mesh_cpu(height_grid, chunk_bounds, resolution)
	var height_buffer := rd.storage_buffer_create(
		height_grid.size() * 4, height_grid.to_byte_array()
	)
	var vertex_count := resolution * resolution
	var vertex_buffer := rd.storage_buffer_create(vertex_count * 3 * 4)
	var uv_buffer := rd.storage_buffer_create(vertex_count * 2 * 4)
	var index_count := (resolution - 1) * (resolution - 1) * 6
	var index_buffer := rd.storage_buffer_create(index_count * 4)
	var uniforms: Array[RDUniform] = []
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(0, height_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, vertex_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, uv_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(3, index_buffer))
	var uniform_set := rd.uniform_set_create(uniforms, shader_rid, 0)
	var push_constants := GpuResourceHelper.pack_push_constants([
		chunk_bounds.size.x,
		chunk_bounds.size.z,
		resolution,
		1  # padding
	])
	GpuResourceHelper.dispatch_compute_2d(
		rd, pipeline_rid, uniform_set, shader_rid,
		push_constants, resolution, resolution, 8
	)
	var vertices := GpuResourceHelper.read_vector3_buffer(rd, vertex_buffer, vertex_count)
	var uvs := GpuResourceHelper.read_vector2_buffer(rd, uv_buffer, vertex_count)
	var indices := rd.buffer_get_data(index_buffer).to_int32_array()
	GpuResourceHelper.free_rids(rd, [
		uniform_set, height_buffer, vertex_buffer, uv_buffer, index_buffer
	])
	var mesh_data := MeshData.new(vertices, indices, uvs)
	mesh_data.width = resolution
	mesh_data.height = resolution
	mesh_data.mesh_size = Vector2(chunk_bounds.size.x, chunk_bounds.size.z)
	return mesh_data

func _build_mesh_cpu(
	height_grid: PackedFloat32Array,
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
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
			vertices[index] = Vector3(local_x, height_grid[index], local_z)
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

func _apply_volumes_cpu(
	mesh_data: MeshData,
	volumes: Array[VolumeDefinition],
	chunk_bounds: AABB,
	resolution: int
) -> MeshData:
	return _fallback_strategy._apply_volumes(mesh_data, volumes, chunk_bounds, resolution)

func _get_blend_mode_int(strategy: HeightBlendStrategy) -> int:
	if strategy is AdditiveBlendStrategy:
		return 0
	elif strategy is MultiplicativeBlendStrategy:
		return 1
	elif strategy is MaxBlendStrategy:
		return 2
	elif strategy is MinBlendStrategy:
		return 3
	elif strategy is ReplaceBlendStrategy:
		return 4
	return 0

func dispose() -> void:
	_gpu_manager = null
	if _fallback_strategy:
		_fallback_strategy.dispose()

