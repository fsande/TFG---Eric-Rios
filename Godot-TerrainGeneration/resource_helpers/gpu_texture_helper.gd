# Helper class for converting between Godot Images and GPU textures
class_name GpuTextureHelper

## Creates a GPU texture from a heightmap Image (FORMAT_RF)
static func create_texture_from_image(rd: RenderingDevice, img: Image) -> RID:
	var format := RDTextureFormat.new()
	format.width = img.get_width()
	format.height = img.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return rd.texture_create(format, RDTextureView.new(), [img.get_data()])

## Creates a GPU texture from the heightmap Image.
static func create_heightmap_texture(rd: RenderingDevice, heightmap: Image) -> RID:
	var image_data := PackedByteArray()
	if heightmap.get_format() == Image.FORMAT_RF:
		image_data = heightmap.get_data()
	else:
		var converted_image := heightmap.duplicate()
		if converted_image.get_format() != Image.FORMAT_RF:
			converted_image.convert(Image.FORMAT_RF)
		image_data = converted_image.get_data()
	var format := RDTextureFormat.new()
	format.width = heightmap.get_width()
	format.height = heightmap.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var view := RDTextureView.new()
	var texture := rd.texture_create(format, view, [image_data])
	return texture
	

## Creates an empty GPU texture with the specified dimensions
static func create_empty_texture(rd: RenderingDevice, width: int, height: int) -> RID:
	var format := RDTextureFormat.new()
	format.width = width
	format.height = height
	format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return rd.texture_create(format, RDTextureView.new())

## Reads a GPU texture back into a heightmap Image (FORMAT_RF)
static func read_texture_to_image(rd: RenderingDevice, texture: RID, width: int, height: int) -> Image:
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, rd.texture_get_data(texture, 0))

## Creates a uniform set for passing parameters buffer to the shader
static func create_params_uniform_set(rd: RenderingDevice, params_buffer: RID, shader: RID, binding: int = 0, set_index: int = 1) -> RID:
	var uniform := GpuResourceHelper.create_storage_buffer_uniform(binding, params_buffer)
	return rd.uniform_set_create([uniform], shader, set_index)

## Creates a uniform set for input and output image textures
static func create_image_uniform_set(rd: RenderingDevice, input_tex: RID, output_tex: RID, shader: RID, bindings: Array[int] = [0, 1]) -> RID:
	var uniform_input := GpuResourceHelper.create_image_uniform(bindings[0], input_tex)
	var uniform_output := GpuResourceHelper.create_image_uniform(bindings[1], output_tex)
	return rd.uniform_set_create([uniform_input, uniform_output], shader, 0)
