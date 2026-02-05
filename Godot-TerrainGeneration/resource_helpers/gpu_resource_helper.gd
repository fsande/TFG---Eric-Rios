class_name GpuResourceHelper

static func free_rids(rd: RenderingDevice, rids: Array[RID]) -> void:
	for rid in rids:
		rd.free_rid(rid)

## Creates a GPU storage buffer for Vector3 arrays
static func create_vector3_buffer(rd: RenderingDevice, vectors: PackedVector3Array) -> RID:
	var data := PackedFloat32Array()
	for v in vectors:
		data.append(v.x)
		data.append(v.y)
		data.append(v.z)
	return rd.storage_buffer_create(data.size() * 4, data.to_byte_array())
	
static func read_vector3_buffer(rd: RenderingDevice, buffer: RID, count: int) -> PackedVector3Array:
	var byte_data := rd.buffer_get_data(buffer)
	var float_data := byte_data.to_float32_array()
	var vertices := PackedVector3Array()
	vertices.resize(count)
	for i in range(count):
		var base := i * 3
		vertices[i] = Vector3(float_data[base], float_data[base + 1], float_data[base + 2])
	return vertices

## Creates a GPU storage buffer for Int32 arrays
static func create_int32_buffer(rd: RenderingDevice, indices: PackedInt32Array) -> RID:
	return rd.storage_buffer_create(indices.size() * 4, indices.to_byte_array())

## Creates a GPU storage buffer for Vector2 arrays
static func create_vector2_buffer(rd: RenderingDevice, uvs: PackedVector2Array) -> RID:
	var data := PackedFloat32Array()
	for uv in uvs:
		data.append(uv.x)
		data.append(uv.y)
	return rd.storage_buffer_create(data.size() * 4, data.to_byte_array())

## Creates a zero-initialized GPU storage buffer for vectors of specified size
static func create_zeroed_vector_buffer(rd: RenderingDevice, vector_size: int, count: int) -> RID:
	var data := PackedFloat32Array()
	for i in range(count * vector_size):
		data.append(0.0)
	return rd.storage_buffer_create(data.size() * 4, data.to_byte_array())

## Creates a storage buffer uniform for a given binding
static func create_storage_buffer_uniform(binding: int, buffer_rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer_rid)
	return uniform

## Creates a sampler with texture uniform for a given binding
static func create_sampler_texture_uniform(binding: int, sampler_rid: RID, texture_rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler_rid)
	uniform.add_id(texture_rid)
	return uniform

## Creates an image uniform for a given binding
static func create_image_uniform(binding: int, texture_rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture_rid)
	return uniform

## Creates a linear sampler with clamp-to-edge wrapping (common for heightmaps)
static func create_linear_clamp_sampler(rd: RenderingDevice) -> RID:
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	return rd.sampler_create(sampler_state)

## Packs mixed float and int values into push constants byte array
static func pack_push_constants(values: Array) -> PackedByteArray:
	var byte_array := PackedByteArray()
	for value in values:
		if value is float:
			byte_array.append_array(PackedFloat32Array([value]).to_byte_array())
		elif value is int:
			byte_array.append_array(PackedInt32Array([value]).to_byte_array())
		elif value is Vector2:
			byte_array.append_array(PackedFloat32Array([value.x, value.y]).to_byte_array())
		elif value is Vector3:
			byte_array.append_array(PackedFloat32Array([value.x, value.y, value.z]).to_byte_array())
	return byte_array

## Executes a compute dispatch with automatic workgroup calculation
static func dispatch_compute(
	rd: RenderingDevice,
	pipeline: RID,
	uniform_set: RID,
	shader_rid: RID,
	push_constants: PackedByteArray,
	dispatch_size: int,
	workgroup_size: int = 64
) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if push_constants.size() > 0:
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	var groups := ceili(float(dispatch_size) / float(workgroup_size))
	rd.compute_list_dispatch(compute_list, groups, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()

## Executes a 2D compute dispatch with automatic workgroup calculation
static func dispatch_compute_2d(
	rd: RenderingDevice,
	pipeline: RID,
	uniform_set: RID,
	shader_rid: RID,
	push_constants: PackedByteArray,
	width: int,
	height: int,
	workgroup_size: int = 8
) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if push_constants.size() > 0:
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	var groups_x := ceili(float(width) / float(workgroup_size))
	var groups_y := ceili(float(height) / float(workgroup_size))
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()

## Reads a storage buffer and converts to Vector2 array
static func read_vector2_buffer(rd: RenderingDevice, buffer: RID, count: int) -> PackedVector2Array:
	var byte_data := rd.buffer_get_data(buffer)
	var float_data := byte_data.to_float32_array()
	var result := PackedVector2Array()
	result.resize(count)
	for i in range(count):
		var base := i * 2
		result[i] = Vector2(float_data[base], float_data[base + 1])
	return result
