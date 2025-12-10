## @brief Computes slope and normal data for terrain meshes.
##
## @details Calculates slope angles and surface normals for each vertex in a mesh grid,
## storing the results in an Image for efficient GPU-friendly access. Supports both CPU
## and GPU computation paths.
@tool
class_name SlopeComputer

## Path to the shader used for GPU slope computation
const SHADER_PATH := "res://terrain_generation/mesh/calculators/shaders/slope_computer.glsl"

## Compute slope normal map for a mesh result.
## Returns an Image with FORMAT_RGBAF (RGB=normal, A=slope_angle in radians).
static func compute_slope_normal_map(mesh_result: MeshGenerationResult, context: ProcessingContext) -> Image:
	if not mesh_result:
		push_error("SlopeComputer: mesh_result is null")
		return null
	if mesh_result.width == 0 or mesh_result.height == 0:
		push_error("SlopeComputer: mesh_result has invalid dimensions (%sx%s)" % [str(mesh_result.width), str(mesh_result.height)])
		return null
	if context.use_gpu():
		return _compute_gpu(mesh_result, context)
	else:
		return _compute_cpu(mesh_result)

## CPU implementation: Iterate all vertices and calculate slope from neighbors.
static func _compute_cpu(mesh_result: MeshGenerationResult) -> Image:
	var start_time := Time.get_ticks_usec()
	var width := mesh_result.width
	var height := mesh_result.height
	var vertices := mesh_result.vertices
	var img := Image.create(width, height, false, Image.FORMAT_RGBAF)
	for row in range(height):
		for col in range(width):
			var vertex_idx := row * width + col
			if vertex_idx >= vertices.size():
				img.set_pixel(col, row, Color(0.0, 1.0, 0.0, 0.0))  # Up normal, 0 slope
				continue
			var normal := _compute_vertex_normal(vertex_idx, col, row, width, height, vertices)
			var slope_angle := _compute_slope_angle(normal)
			img.set_pixel(col, row, Color(normal.x, normal.y, normal.z, slope_angle))
	var elapsed_time := Time.get_ticks_usec() - start_time
	print("SlopeComputer (CPU): Computed %sx%s slope map in %.2f ms" % [str(width), str(height), elapsed_time * 0.001])
	return img

## GPU implementation: Use compute shader to calculate slope in parallel.
static func _compute_gpu(mesh_result: MeshGenerationResult, context: ProcessingContext) -> Image:
	var start_time := Time.get_ticks_usec()
	var rd := context.get_rendering_device()
	if not rd:
		push_warning("SlopeComputer: No RenderingDevice available, falling back to CPU")
		return _compute_cpu(mesh_result)
	var shader := context.get_or_create_shader(SHADER_PATH)
	if not shader.is_valid():
		push_warning("SlopeComputer: GPU shader not available, falling back to CPU")
		return _compute_cpu(mesh_result)
	var pipeline := rd.compute_pipeline_create(shader)
	var width := mesh_result.width
	var height := mesh_result.height
	var vertices := mesh_result.vertices
	var vertex_data := PackedFloat32Array()
	for vertex_position in vertices:
		vertex_data.append(vertex_position.x)
		vertex_data.append(vertex_position.y)
		vertex_data.append(vertex_position.z)
	var vertex_buffer := rd.storage_buffer_create(vertex_data.size() * 4, vertex_data.to_byte_array())
	var texture_format := RDTextureFormat.new()
	texture_format.width = width
	texture_format.height = height
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var output_texture := rd.texture_create(texture_format, RDTextureView.new(), [])
	var params := PackedByteArray()
	params.resize(16)
	params.encode_s32(0, width)
	params.encode_s32(4, height)
	params.encode_s32(8, vertices.size())
	var params_buffer := rd.storage_buffer_create(params.size(), params)
	var uniforms := [
		GpuResourceHelper.create_storage_buffer_uniform(0, vertex_buffer),
		GpuResourceHelper.create_image_uniform(1, output_texture),
		GpuResourceHelper.create_storage_buffer_uniform(2, params_buffer),
	]
	var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
	var workgroups_x := ceili(float(width) / 8.0)
	var workgroups_y := ceili(float(height) / 8.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, workgroups_x, workgroups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var byte_data := rd.texture_get_data(output_texture, 0)
	var result_image := Image.create_from_data(width, height, false, Image.FORMAT_RGBAF, byte_data)
	GpuResourceHelper.free_rids(rd, [uniform_set, pipeline, vertex_buffer, output_texture, params_buffer])
	var elapsed_time := Time.get_ticks_usec() - start_time
	print("SlopeComputer (GPU): Computed %sx%s slope map in %.2f ms" % [str(width), str(height), elapsed_time * 0.001])
	return result_image

## Calculate vertex normal from Moore neighbors (8-connected).
static func _compute_vertex_normal(vertex_idx: int, col: int, row: int, width: int, height: int, vertices: PackedVector3Array) -> Vector3:
	var center := vertices[vertex_idx]
	var accumulated_normal := Vector3.ZERO
	var neighbor_count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor_col := col + dx
			var neighbor_row := row + dy
			if neighbor_col < 0 or neighbor_col >= width or neighbor_row < 0 or neighbor_row >= height:
				continue
			var neighbor_idx := neighbor_row * width + neighbor_col
			if neighbor_idx >= vertices.size():
				continue
			var neighbor := vertices[neighbor_idx]
			var edge := neighbor - center
			accumulated_normal += edge
			neighbor_count += 1
	if neighbor_count == 0:
		return Vector3.UP  # Default to up if no neighbors
	accumulated_normal /= float(neighbor_count)
	var surface_normal := Vector3.ZERO
	var cross_count := 0
	# Should refactor this into a function
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := col + dx
			var ny := row + dy
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			var nidx := ny * width + nx
			if nidx >= vertices.size():
				continue
			var dx2 := dx + 1 if dx >= 0 else dx - 1
			var dy2 := dy
			var nx2 := col + dx2
			var ny2 := row + dy2
			if nx2 < 0 or nx2 >= width or ny2 < 0 or ny2 >= height:
				dx2 = dx
				dy2 = dy + 1 if dy >= 0 else dy - 1
				nx2 = col + dx2
				ny2 = row + dy2
				if nx2 < 0 or nx2 >= width or ny2 < 0 or ny2 >= height:
					continue
			var nidx2 := ny2 * width + nx2
			if nidx2 >= vertices.size():
				continue
			var v1 := vertices[nidx] - center
			var v2 := vertices[nidx2] - center
			var face_normal := v1.cross(v2)
			if face_normal.length_squared() > 0.0001:
				surface_normal += face_normal.normalized()
				cross_count += 1
	if cross_count > 0:
		surface_normal /= float(cross_count)
		return surface_normal.normalized()
	if accumulated_normal.length_squared() > 0.0001:
		var horizontal := Vector2(accumulated_normal.x, accumulated_normal.z)
		if horizontal.length_squared() > 0.0001:
			var perpendicular := Vector3(-horizontal.y, 0, horizontal.x).normalized()
			var up_component := Vector3.UP
			return (perpendicular + up_component).normalized()
	return Vector3.UP

## Calculate slope angle from normal vector.
## Returns angle in radians (0 = flat, PI/2 = vertical).
static func _compute_slope_angle(normal: Vector3) -> float:
	# Flat: normal = (0,1,0), angle = 0
	# Vertical: normal = (1,0,0), angle = PI/2
	var up_dot := normal.dot(Vector3.UP)
	up_dot = clamp(up_dot, -1.0, 1.0)
	var angle := acos(up_dot)
	return angle
