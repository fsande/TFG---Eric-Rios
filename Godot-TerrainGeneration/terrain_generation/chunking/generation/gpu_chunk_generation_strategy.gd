## @brief GPU-accelerated chunk generation strategy (synchronous only).
##
## @details Generates chunk meshes using compute shaders for parallel processing.
## Leverages GpuResourceManager for shared rendering device and shader caching.
## MUST run on main thread - does not support async/multithreaded generation.
@tool
class_name GpuChunkGenerationStrategy extends ChunkGenerationStrategy

const HEIGHT_GRID_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_height_grid.glsl"
const MESH_BUILDER_SHADER := "res://terrain_generation/chunking/generation/shaders/chunk_mesh_builder.glsl"

var _gpu_manager: GpuResourceManager = null
var _fallback_strategy: CpuChunkGenerationStrategy = null

var _heightmap: Image

func _init(heightmap: Image) -> void:
	_heightmap = heightmap
	_fallback_strategy = CpuChunkGenerationStrategy.new(heightmap)
	_gpu_manager = GpuResourceManager.get_singleton()

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
	var result := _generate_chunk_gpu(
		terrain_definition, chunk_bounds, lod_level, resolution, height_grid
	)
	if not result:
		push_warning("GpuChunkGenerationStrategy: GPU generation failed, falling back to CPU")
		return _fallback_strategy.generate_chunk(
			terrain_definition, chunk_bounds, lod_level, resolution, height_grid
		)
	return result


func _generate_chunk_gpu(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	lod_level: int,
	resolution: int,
	height_grid: PackedFloat32Array
) -> MeshData:
	print("FUUUUU")
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("GpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var rd := _gpu_manager.get_rendering_device()
	if not rd:
		push_error("GpuChunkGenerationStrategy: No RenderingDevice found")
		return null
	var t := Time.get_ticks_usec()
	#_emit_substep("height_grid", (Time.get_ticks_usec() - t) / 1000.0)
	if height_grid.is_empty():
		return null
	t = Time.get_ticks_usec()
	var mesh_data := _build_mesh_gpu(rd, height_grid, chunk_bounds, resolution)
	#_emit_substep("mesh_build", (Time.get_ticks_usec() - t) / 1000.0)
	if not mesh_data:
		return null
	var volumes := terrain_definition.get_volumes_for_chunk(chunk_bounds, lod_level)
	if not volumes.is_empty():
		t = Time.get_ticks_usec()
		mesh_data = _fallback_strategy._apply_volumes(mesh_data, volumes, chunk_bounds, lod_level)
		_emit_substep("volumes", (Time.get_ticks_usec() - t) / 1000.0)
	if mesh_data.cached_normals.is_empty():
		t = Time.get_ticks_usec()
		mesh_data.cached_normals = MeshNormalCalculator.calculate_normals(mesh_data)
		#_emit_substep("normals", (Time.get_ticks_usec() - t) / 1000.0)
	if mesh_data.cached_tangents.is_empty():
		t = Time.get_ticks_usec()
		mesh_data.cached_tangents = MeshTangentCalculator.calculate_tangents(mesh_data, mesh_data.cached_normals)
		#_emit_substep("tangents", (Time.get_ticks_usec() - t) / 1000.0)
	return mesh_data

func generate_height_grid(
	terrain_definition: TerrainDefinition,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	var rd := _gpu_manager.get_rendering_device()
	if not _heightmap:
		push_error("GpuChunkGenerationStrategy: No base heightmap available")
		return PackedFloat32Array()
	var shader_rid := _gpu_manager.get_or_create_shader(HEIGHT_GRID_SHADER)
	if not shader_rid.is_valid():
		push_error("GpuChunkGenerationStrategy: Failed to load height grid shader")
		return PackedFloat32Array()
	var pipeline_rid := _gpu_manager.get_or_create_pipeline(shader_rid)
	if not pipeline_rid.is_valid():
		return PackedFloat32Array()
	var heightmap_texture := GpuTextureHelper.create_heightmap_texture(rd, _heightmap)
	var sampler := GpuResourceHelper.create_linear_clamp_sampler(rd)
	var output_buffer := rd.storage_buffer_create(resolution * resolution * 4)
	var deltas := terrain_definition.get_deltas_for_chunk(chunk_bounds)
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
	var delta_data_buffer := rd.storage_buffer_create(
		delta_pixel_data.size() * 4, delta_pixel_data.to_byte_array()
	)
	var params_bytes := PackedByteArray()
	params_bytes.append_array(PackedInt32Array([deltas.size(), 0, 0, 0]).to_byte_array())
	var data_offset := 0
	for delta in deltas:
		var delta_res := 1
		if delta.delta_texture:
			delta_res = delta.delta_texture.get_width()
		var world_bounds: AABB = delta.world_bounds
		var blend_mode := _get_blend_mode_int(delta.blend_strategy)
		params_bytes.append_array(PackedInt32Array([delta_res]).to_byte_array())
		params_bytes.append_array(PackedInt32Array([data_offset]).to_byte_array())
		params_bytes.append_array(PackedInt32Array([blend_mode]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([delta.intensity]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.position.x]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.position.z]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.size.x]).to_byte_array())
		params_bytes.append_array(PackedFloat32Array([world_bounds.size.z]).to_byte_array())
		data_offset += delta_res * delta_res
	if params_bytes.size() == 16:
		params_bytes.resize(16 + 32)
	var delta_params_buffer := rd.storage_buffer_create(params_bytes.size(), params_bytes)
	var uniforms: Array[RDUniform] = []
	uniforms.append(GpuResourceHelper.create_sampler_texture_uniform(0, sampler, heightmap_texture))
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
	GpuResourceHelper.dispatch_compute_2d(
		rd, pipeline_rid, uniform_set,
		push_constants, resolution, resolution, 8
	)
	var result := rd.buffer_get_data(output_buffer).to_float32_array()
	GpuResourceHelper.free_rids(rd, [
		uniform_set, output_buffer, delta_data_buffer, delta_params_buffer,
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
	var pipeline_rid := _gpu_manager.get_or_create_pipeline(shader_rid)
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
		rd, pipeline_rid, uniform_set,
		push_constants, resolution, resolution, 8
	)
	var vertices := GpuResourceHelper.read_vector3_buffer(rd, vertex_buffer, vertex_count)
	var uvs := GpuResourceHelper.read_vector2_buffer(rd, uv_buffer, vertex_count)
	var indices := rd.buffer_get_data(index_buffer).to_int32_array()
	GpuResourceHelper.free_rids(rd, [
		uniform_set, height_buffer, vertex_buffer, uv_buffer, index_buffer
	])
	var mesh_data := MeshData.create(vertices, indices, uvs)
	mesh_data.width = resolution
	mesh_data.height = resolution
	mesh_data.mesh_size = Vector2(chunk_bounds.size.x, chunk_bounds.size.z)
	print("FUUUkkkU")
	return mesh_data

func _get_blend_mode_int(strategy: HeightBlendStrategy) -> int:
	match strategy:
		AdditiveBlendStrategy:
			return 0
		MultiplicativeBlendStrategy:
			return 1
		MaxBlendStrategy:
			return 2
		MinBlendStrategy:
			return 3
		ReplaceBlendStrategy:
			return 4
		_:
			return 0

func dispose() -> void:
	_gpu_manager = null
	if _fallback_strategy:
		_fallback_strategy.dispose()
