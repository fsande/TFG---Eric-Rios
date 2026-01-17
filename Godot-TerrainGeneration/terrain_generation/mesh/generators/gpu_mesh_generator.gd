## @brief GPU-accelerated mesh generator that uses compute shaders to create meshes from heightmaps.
##
## @details Uses ProcessingContext's shared RenderingDevice and shader caching for optimal performance.
## Uploads mesh data to GPU buffers, runs compute passes to modify vertices, accumulate normals/tangents,
## and finalize tangent space. Results are read back into CPU arrays.
@tool
class_name GpuMeshGenerator extends HeightmapMeshGenerator

const SHADER_PATH := "res://terrain_generation/mesh/generators/shaders/mesh_processor.glsl"

## Generate mesh using GPU compute shaders via ProcessingContext.
func generate_mesh(mesh_array: Array, heightmap: Image, context: ProcessingContext) -> MeshGenerationResult:
	var rd := context.get_rendering_device()
	if not rd:
		push_error("GPUMeshGenerator: RenderingDevice not available")
		return null
	var shader := context.get_or_create_shader(SHADER_PATH)
	if not shader.is_valid():
		push_error("GPUMeshGenerator: Failed to load shader, falling back to CPU")
		return null
	var pipeline := rd.compute_pipeline_create(shader)
	var start_time := Time.get_ticks_usec()
	var arrays := mesh_array
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertex_count := vertices.size()
	var index_count := indices.size()
	var mesh_params := context.mesh_parameters
	var height_scale: float = mesh_params.height_scale
	var mesh_size: Vector2 = mesh_params.mesh_size
	var subdivisions: int = mesh_params.subdivisions
	print("GPUMeshGenerator: Generating mesh with %d vertices" % vertex_count)
	var vertex_buffer := GpuResourceHelper.create_vector3_buffer(rd, vertices)
	var index_buffer := GpuResourceHelper.create_int32_buffer(rd, indices)
	var uv_buffer := GpuResourceHelper.create_vector2_buffer(rd, uvs)
	var normal_buffer := GpuResourceHelper.create_zeroed_vector_buffer(rd, 3, vertex_count)
	var tangent_buffer := GpuResourceHelper.create_zeroed_vector_buffer(rd, 4, vertex_count)
	var tan1_buffer := GpuResourceHelper.create_zeroed_vector_buffer(rd, 3, vertex_count)
	var tan2_buffer := GpuResourceHelper.create_zeroed_vector_buffer(rd, 3, vertex_count)
	var heightmap_texture := GpuTextureHelper.create_heightmap_texture(rd, heightmap)
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	var sampler := rd.sampler_create(sampler_state)
	# Pass 0: Modify vertex heights
	_execute_pass(rd, pipeline, shader, vertex_buffer, index_buffer, uv_buffer, normal_buffer, tangent_buffer,
		tan1_buffer, tan2_buffer, heightmap_texture, sampler,
		height_scale, mesh_size, vertex_count, index_count, 0)
	# Pass 1: Accumulate normals and tangents
	_execute_pass(rd, pipeline, shader, vertex_buffer, index_buffer, uv_buffer, normal_buffer, tangent_buffer,
		tan1_buffer, tan2_buffer, heightmap_texture, sampler,
		height_scale, mesh_size, vertex_count, index_count, 1)
	# Pass 2: Finalize normals and tangents
	_execute_pass(rd, pipeline, shader, vertex_buffer, index_buffer, uv_buffer, normal_buffer, tangent_buffer,
		tan1_buffer, tan2_buffer, heightmap_texture, sampler,
		height_scale, mesh_size, vertex_count, index_count, 2)
	var modified_vertices := GpuResourceHelper.read_vector3_buffer(rd, vertex_buffer, vertex_count)
	var rids: Array[RID] = [vertex_buffer, index_buffer, uv_buffer, normal_buffer, tangent_buffer, tan1_buffer, tan2_buffer, heightmap_texture, sampler, pipeline]
	GpuResourceHelper.free_rids(rd, rids)
	var elapsed_time := Time.get_ticks_usec() - start_time
	var result := MeshGenerationResult.new(modified_vertices, indices, uvs, elapsed_time * 0.001, "GPU")
	result.width = subdivisions + 1
	result.height = subdivisions + 1
	result.mesh_size = mesh_size
	print("GPUMeshGenerator: subdivisions=%s, grid=%sx%s, actual vertices=%s, mesh_size=%s" % [
		str(subdivisions), str(result.width), str(result.height), str(modified_vertices.size()), str(mesh_size)
	])
	result.slope_normal_map = SlopeComputer.compute_slope_normal_map(result, context)
#	var slope_as_red := Image.create(result.slope_normal_map.get_width(), result.slope_normal_map.get_height(), false, Image.FORMAT_RGB8)
#	for y in range(slope_as_red.get_height()):
#		for x in range(slope_as_red.get_width()):
#			var slope_value := result.slope_normal_map.get_pixel(x, y).a
#			slope_as_red.set_pixel(x, y, Color(slope_value, slope_value, slope_value))		
	DebugImageExporter.export_image(result.slope_normal_map, "res://slope_map_gpu.png")
	return result

## Executes a compute shader pass for the specified operation type.
func _execute_pass(
	rd: RenderingDevice, pipeline: RID, shader: RID,
	vertex_buffer: RID, index_buffer: RID, uv_buffer: RID,
	normal_buffer: RID, tangent_buffer: RID, tan1_buffer: RID,
	tan2_buffer: RID, heightmap_texture: RID, sampler: RID,
	height_scale: float, mesh_size: Vector2, vertex_count: int,
	index_count: int, pass_type: int
) -> void:
	var params_buffer := _create_params_buffer_with_pass(
		rd, height_scale, mesh_size, vertex_count, index_count, pass_type
	)
	var uniform_set := _create_unified_uniform_set(
		rd, shader, vertex_buffer, index_buffer, uv_buffer, normal_buffer,
		tangent_buffer, tan1_buffer, tan2_buffer,
		heightmap_texture, sampler, params_buffer
	)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var groups: int
	if pass_type == 0 or pass_type == 2:
		groups = ceili(float(vertex_count) / 64.0)
	else:
		groups = ceili(float(index_count) / 3.0 / 64.0)
	rd.compute_list_dispatch(compute_list, groups, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	GpuResourceHelper.free_rids(rd, [uniform_set, params_buffer])

## Creates a parameters buffer including the pass type.
func _create_params_buffer_with_pass(
	rd: RenderingDevice, height_scale: float, mesh_size: Vector2, vertex_count: int, 
	index_count: int, pass_type: int
) -> RID:
	var byte_array := PackedByteArray()
	
	byte_array.append_array(PackedFloat32Array([height_scale]).to_byte_array())
	byte_array.append_array(PackedFloat32Array([mesh_size.x]).to_byte_array())
	byte_array.append_array(PackedFloat32Array([mesh_size.y]).to_byte_array())
	byte_array.append_array(PackedInt32Array([vertex_count]).to_byte_array())
	byte_array.append_array(PackedInt32Array([index_count]).to_byte_array())
	byte_array.append_array(PackedInt32Array([pass_type]).to_byte_array())
	
	print("GPUMeshGenerator: Pass %d - params buffer size: %d bytes" % [pass_type, byte_array.size()])
	
	return rd.storage_buffer_create(byte_array.size(), byte_array)

## Creates a unified uniform set for all required buffers and textures.
func _create_unified_uniform_set(
	rd: RenderingDevice, shader: RID, vertex_buffer: RID, index_buffer: RID, uv_buffer: RID,
	normal_buffer: RID, tangent_buffer: RID, tan1_buffer: RID,
	tan2_buffer: RID, heightmap_texture: RID, sampler: RID,
	params_buffer: RID
) -> RID:
	var uniforms := [
		GpuResourceHelper.create_storage_buffer_uniform(0, vertex_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(1, index_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(2, normal_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(3, tangent_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(4, uv_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(5, tan1_buffer),
		GpuResourceHelper.create_storage_buffer_uniform(6, tan2_buffer),
		GpuResourceHelper.create_sampler_texture_uniform(7, sampler, heightmap_texture),
		GpuResourceHelper.create_storage_buffer_uniform(8, params_buffer),
	]
	
	return rd.uniform_set_create(uniforms, shader, 0)

## Reads back the tangent buffer data into a PackedVector4Array.
func _read_tangent_buffer(rd: RenderingDevice, buffer: RID, count: int) -> PackedVector4Array:
	var byte_data := rd.buffer_get_data(buffer)
	var float_data := byte_data.to_float32_array()
	var tangents := PackedVector4Array()
	tangents.resize(count)
	for i in range(count):
		var base := i * 4
		tangents[i] = Vector4(float_data[base], float_data[base + 1], float_data[base + 2], float_data[base + 3])
	return tangents
