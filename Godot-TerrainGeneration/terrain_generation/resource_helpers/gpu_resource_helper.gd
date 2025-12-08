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
