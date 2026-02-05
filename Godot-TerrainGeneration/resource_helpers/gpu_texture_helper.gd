# Helper class for converting between Godot Images and GPU textures
class_name GpuTextureHelper

## Creates a GPU texture from a heightmap Image (FORMAT_RF)
static func create_texture_from_image(rd: RenderingDevice, img: Image) -> RID:
	var fmt := RDTextureFormat.new()
	fmt.width = img.get_width()
	fmt.height = img.get_height()
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var data := PackedFloat32Array()
	for y in img.get_height():
		for x in img.get_width():
			data.append(img.get_pixel(x, y).r)
	return rd.texture_create(fmt, RDTextureView.new(), [data.to_byte_array()])

## Creates a GPU texture from the heightmap Image.
static func create_heightmap_texture(rd: RenderingDevice, heightmap: Image) -> RID:
	var converted_image := heightmap.duplicate()
	if converted_image.get_format() != Image.FORMAT_RF:
		converted_image.convert(Image.FORMAT_RF)
	var fmt := RDTextureFormat.new()
	fmt.width = converted_image.get_width()
	fmt.height = converted_image.get_height()
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var view := RDTextureView.new()
	var image_data: PackedByteArray = converted_image.get_data()
#	print("GPU: Creating heightmap texture, data size: %d bytes" % image_data.size())
	var texture := rd.texture_create(fmt, view, [image_data])
	return texture
	


## Creates an empty GPU texture with the specified dimensions
static func create_empty_texture(rd: RenderingDevice, width: int, height: int) -> RID:
	var fmt := RDTextureFormat.new()
	fmt.width = width
	fmt.height = height
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	return rd.texture_create(fmt, RDTextureView.new())

## Reads a GPU texture back into a heightmap Image (FORMAT_RF)
static func read_texture_to_image(rd: RenderingDevice, texture: RID, width: int, height: int) -> Image:
	var data := rd.texture_get_data(texture, 0)
	var float_data := data.to_float32_array()
	var result := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var index := y * width + x
			result.set_pixel(x, y, Color(float_data[index], 0, 0))
	return result

## Creates a uniform set for passing parameters buffer to the shader
static func create_params_uniform_set(rd: RenderingDevice, params_buffer: RID, shader: RID, binding: int = 2) -> RID:
	var uniform_params := GpuResourceHelper.create_storage_buffer_uniform(binding, params_buffer)
	return rd.uniform_set_create([uniform_params], shader, 1)
	
## Creates a uniform set for input and output image textures
static func create_image_uniform_set(rd: RenderingDevice, input_tex: RID, output_tex: RID, shader: RID, bindings: Array[int] = [0, 1]) -> RID:
	var uniform_input := GpuResourceHelper.create_image_uniform(bindings[0], input_tex)
	var uniform_output := GpuResourceHelper.create_image_uniform(bindings[1], output_tex)
	return rd.uniform_set_create([uniform_input, uniform_output], shader, 0)
