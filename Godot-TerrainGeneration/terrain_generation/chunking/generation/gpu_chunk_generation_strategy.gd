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

func _init() -> void:
	_fallback_strategy = CpuChunkGenerationStrategy.new()

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
	_gpu_manager = GpuResourceManager.get_singleton()
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
	if not terrain_definition or not terrain_definition.is_valid():
		push_error("GpuChunkGenerationStrategy: Invalid terrain definition")
		return null
	var rd := _gpu_manager.get_rendering_device()
	if not rd:
		return null
	var t := Time.get_ticks_usec()
	_emit_substep("height_grid", (Time.get_ticks_usec() - t) / 1000.0)
	if height_grid.is_empty():
		return null
	t = Time.get_ticks_usec()
	var mesh_data := _build_mesh_gpu(rd, height_grid, chunk_bounds, resolution)
	_emit_substep("mesh_build", (Time.get_ticks_usec() - t) / 1000.0)
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
		_emit_substep("normals", (Time.get_ticks_usec() - t) / 1000.0)
	if mesh_data.cached_tangents.is_empty():
		t = Time.get_ticks_usec()
		mesh_data.cached_tangents = MeshTangentCalculator.calculate_tangents(mesh_data, mesh_data.cached_normals)
		_emit_substep("tangents", (Time.get_ticks_usec() - t) / 1000.0)
	return mesh_data

func generate_height_grid(
	terrain_definition: TerrainDefinition,
	sampler: HeightmapSamplerNative,
	chunk_bounds: AABB,
	resolution: int
) -> PackedFloat32Array:
	return sampler.generate_height_grid(
		chunk_bounds,
		resolution,
		terrain_definition.terrain_size.x,
		terrain_definition.height_scale
	)

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
	var mesh_data := MeshData.new(vertices, indices, uvs)
	mesh_data.width = resolution
	mesh_data.height = resolution
	mesh_data.mesh_size = Vector2(chunk_bounds.size.x, chunk_bounds.size.z)
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
