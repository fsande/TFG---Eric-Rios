## @brief GPU-accelerated chunk generation strategy (synchronous only).
##
## @details Generates chunk meshes using compute shaders for parallel processing.
## Leverages GpuResourceManager for shared rendering device and shader caching.
## MUST run on main thread - does not support async/multithreaded generation.
@tool
class_name GpuChunkGenerationStrategy extends ChunkGenerationStrategy

const HEIGHT_GRID_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_height_grid.glsl"
const MESH_BUILDER_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_mesh_builder.glsl"
const NORMALS_TANGENTS_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_normals_tangents.glsl"

var _gpu_manager: GpuResourceManager = null
var _fallback_strategy: CpuChunkGenerationStrategy = null
var _heightmap: Image

var _heightmap_texture: RID
var _sampler: RID

func _init(heightmap: Image) -> void:
	_heightmap = heightmap
	_fallback_strategy = CpuChunkGenerationStrategy.new(heightmap)
	_gpu_manager = GpuResourceManager.get_singleton()
	var rd := _gpu_manager.get_rendering_device()
	if rd:
		_heightmap_texture = GpuTextureHelper.create_heightmap_texture(rd, _heightmap)
		_sampler = GpuResourceHelper.create_linear_clamp_sampler(rd)

func get_processor_type() -> ProcessorType:
	return ProcessorType.GPU

func supports_async() -> bool:
	return false

func generate_chunk(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	lod_level: int,
	resolution: int,
	height_grid: PackedFloat32Array
) -> MeshData:
	if not _gpu_manager or not _gpu_manager.is_gpu_available():
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_bounds, lod_level, resolution, height_grid
		)
	var result := _generate_chunk_gpu(terrain_definition, chunk_bounds, lod_level, resolution)
	if not result:
		push_warning("GpuChunkGenerationStrategy: GPU generation failed, falling back to CPU")
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_bounds, lod_level, resolution, height_grid
		)
	return result

## Runs height grid, mesh build, and normals+tangents in a single batched compute list.
func _generate_chunk_gpu(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	lod_level: int,
	resolution: int
) -> MeshData:
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("GpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var rd := _gpu_manager.get_rendering_device()
	if not rd:
		push_error("GpuChunkGenerationStrategy: No RenderingDevice found")
		return null
	var height_shader := _gpu_manager.get_or_create_shader(HEIGHT_GRID_SHADER)
	var height_pipeline := _gpu_manager.get_or_create_pipeline(height_shader)
	var mesh_shader := _gpu_manager.get_or_create_shader(MESH_BUILDER_SHADER)
	var mesh_pipeline := _gpu_manager.get_or_create_pipeline(mesh_shader)
	var nt_shader := _gpu_manager.get_or_create_shader(NORMALS_TANGENTS_SHADER)
	var nt_pipeline := _gpu_manager.get_or_create_pipeline(nt_shader)
	if not height_pipeline.is_valid() or not mesh_pipeline.is_valid() or not nt_pipeline.is_valid():
		return null
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	var vertex_count := resolution * resolution
	var index_count := (resolution - 1) * (resolution - 1) * 6
	var height_output_buffer := rd.storage_buffer_create(vertex_count * 4)
	var delta_data_buffer := _create_delta_data_buffer(rd, deltas)
	var delta_params_buffer := _create_delta_params_buffer(rd, deltas)
	var height_uniforms: Array[RDUniform] = []
	height_uniforms.append(GpuResourceHelper.create_sampler_texture_uniform(0, _sampler, _heightmap_texture))
	height_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, height_output_buffer))
	height_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, delta_data_buffer))
	height_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(3, delta_params_buffer))
	var height_uniform_set := rd.uniform_set_create(height_uniforms, height_shader, 0)
	var height_push_constants := GpuResourceHelper.pack_push_constants([
		chunk_bounds.position.x,
		chunk_bounds.position.z,
		chunk_bounds.size.x,
		chunk_bounds.size.z,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale,
		resolution,
		0
	])
	var vertex_buffer := rd.storage_buffer_create(vertex_count * 3 * 4)
	var uv_buffer := rd.storage_buffer_create(vertex_count * 2 * 4)
	var index_buffer := rd.storage_buffer_create(index_count * 4)
	var mesh_uniforms: Array[RDUniform] = []
	mesh_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(0, height_output_buffer))
	mesh_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, vertex_buffer))
	mesh_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, uv_buffer))
	mesh_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(3, index_buffer))
	var mesh_uniform_set := rd.uniform_set_create(mesh_uniforms, mesh_shader, 0)
	var mesh_push_constants := GpuResourceHelper.pack_push_constants([
		chunk_bounds.size.x,
		chunk_bounds.size.z,
		resolution,
		1
	])
	var normal_buffer := rd.storage_buffer_create(vertex_count * 3 * 4)
	var tangent_buffer := rd.storage_buffer_create(vertex_count * 4 * 4)
	var nt_uniforms: Array[RDUniform] = []
	nt_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(0, height_output_buffer))
	nt_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, normal_buffer))
	nt_uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, tangent_buffer))
	var nt_uniform_set := rd.uniform_set_create(nt_uniforms, nt_shader, 0)
	var cell_size_x := chunk_bounds.size.x / float(resolution - 1)
	var cell_size_z := chunk_bounds.size.z / float(resolution - 1)
	var nt_push_constants := GpuResourceHelper.pack_push_constants([
		cell_size_x,
		cell_size_z,
		resolution,
		0
	])
	var compute_list := GpuResourceHelper.begin_compute_list(rd)
	GpuResourceHelper.dispatch_compute_2d_batched(
		rd, compute_list, height_pipeline, height_uniform_set,
		height_push_constants, resolution, resolution, 16
	)
	GpuResourceHelper.dispatch_compute_2d_batched(
		rd, compute_list, mesh_pipeline, mesh_uniform_set,
		mesh_push_constants, resolution, resolution, 16
	)
	GpuResourceHelper.dispatch_compute_2d_batched(
		rd, compute_list, nt_pipeline, nt_uniform_set,
		nt_push_constants, resolution, resolution, 16
	)
	GpuResourceHelper.end_and_sync(rd, compute_list)
	var raw_vertices := rd.buffer_get_data(vertex_buffer).to_float32_array()
	var raw_uvs := rd.buffer_get_data(uv_buffer).to_float32_array()
	var indices := rd.buffer_get_data(index_buffer).to_int32_array()
	var raw_normals := rd.buffer_get_data(normal_buffer).to_float32_array()
	var raw_tangents := rd.buffer_get_data(tangent_buffer).to_float32_array()
	GpuResourceHelper.free_rids(rd, [
		height_uniform_set, mesh_uniform_set, nt_uniform_set,
		height_output_buffer, delta_data_buffer, delta_params_buffer,
		vertex_buffer, uv_buffer, index_buffer, normal_buffer, tangent_buffer
	])
	var mesh_data := MeshData.create_from_raw(raw_vertices, indices, raw_uvs, raw_normals, raw_tangents)
	if not mesh_data:
		return null
	mesh_data.width = resolution
	mesh_data.height = resolution
	mesh_data.mesh_size = Vector2(chunk_bounds.size.x, chunk_bounds.size.z)
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if not volumes.is_empty():
		var t := Time.get_ticks_usec()
		mesh_data = _fallback_strategy.apply_volumes(mesh_data, volumes, chunk_bounds, lod_level)
		_emit_substep("volumes", (Time.get_ticks_usec() - t) / 1000.0)
	return mesh_data

## Used by ChunkGenerator
func generate_height_grid(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var rd := _gpu_manager.get_rendering_device()
	if not rd:
		push_error("GpuChunkGenerationStrategy: No RenderingDevice found")
		return PackedFloat32Array()
	if not _heightmap_texture.is_valid() or not _sampler.is_valid():
		push_error("GpuChunkGenerationStrategy: Heightmap texture not initialized")
		return PackedFloat32Array()
	var shader_rid := _gpu_manager.get_or_create_shader(HEIGHT_GRID_SHADER)
	if not shader_rid.is_valid():
		push_error("GpuChunkGenerationStrategy: Failed to load height grid shader")
		return PackedFloat32Array()
	var pipeline_rid := _gpu_manager.get_or_create_pipeline(shader_rid)
	if not pipeline_rid.is_valid():
		return PackedFloat32Array()
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
	var output_buffer := rd.storage_buffer_create(resolution * resolution * 4)
	var delta_data_buffer := _create_delta_data_buffer(rd, deltas)
	var delta_params_buffer := _create_delta_params_buffer(rd, deltas)
	var uniforms: Array[RDUniform] = []
	uniforms.append(GpuResourceHelper.create_sampler_texture_uniform(0, _sampler, _heightmap_texture))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(1, output_buffer))
	uniforms.append(GpuResourceHelper.create_storage_buffer_uniform(2, delta_data_buffer))
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
		0
	])
	var compute_list := GpuResourceHelper.begin_compute_list(rd)
	GpuResourceHelper.dispatch_compute_2d_batched(
		rd, compute_list, pipeline_rid, uniform_set,
		push_constants, resolution, resolution, 16
	)
	GpuResourceHelper.end_and_sync(rd, compute_list)
	var result := rd.buffer_get_data(output_buffer).to_float32_array()
	GpuResourceHelper.free_rids(rd, [uniform_set, output_buffer, delta_data_buffer, delta_params_buffer])
	return result

func _create_delta_data_buffer(rd: RenderingDevice, deltas: Array) -> RID:
	var delta_pixel_data := PackedFloat32Array()
	for delta in deltas:
		if delta.delta_texture:
			if delta.delta_texture.get_format() != Image.FORMAT_RF:
				push_warning("GpuChunkGenerationStrategy: delta texture is not FORMAT_RF, skipping")
				continue
			delta_pixel_data.append_array(delta.delta_texture.get_data().to_float32_array())
		else:
			delta_pixel_data.append(0.0)
	if delta_pixel_data.is_empty():
		delta_pixel_data.append(0.0)
	return rd.storage_buffer_create(delta_pixel_data.size() * 4, delta_pixel_data.to_byte_array())

func _create_delta_params_buffer(rd: RenderingDevice, deltas: Array) -> RID:
	var params_bytes := PackedByteArray()
	params_bytes.append_array(PackedInt32Array([deltas.size(), 0, 0, 0]).to_byte_array())
	var data_offset := 0
	for delta in deltas:
		var delta_res := 1
		if delta.delta_texture:
			delta_res = delta.delta_texture.get_width()
		var world_bounds: AABB = delta.world_bounds
		params_bytes.append_array(PackedInt32Array([delta_res]).to_byte_array())
		params_bytes.append_array(PackedInt32Array([data_offset]).to_byte_array())
		params_bytes.append_array(PackedInt32Array([delta.blend_mode_int]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([delta.intensity]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.position.x]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.position.z]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.size.x]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.size.z]).to_byte_array())
		data_offset += delta_res * delta_res
	if params_bytes.size() == 16:
		params_bytes.resize(16 + 32)
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)

func dispose() -> void:
	var rd := _gpu_manager.get_rendering_device() if _gpu_manager else null
	if rd:
		GpuResourceHelper.free_rids(rd, [_heightmap_texture, _sampler])
	_heightmap_texture = RID()
	_sampler = RID()
	_gpu_manager = null
	if _fallback_strategy:
		_fallback_strategy.dispose()
