@tool
class_name HeightVariationMaterial extends ShaderMaterial

const ALBEDO_FORMAT = Image.FORMAT_RGBA8
const NORMAL_FORMAT = Image.FORMAT_RGBA8
const ROUGHNESS_FORMAT = Image.FORMAT_R8
const METALLIC_FORMAT = Image.FORMAT_R8
const AO_FORMAT = Image.FORMAT_R8

@export var height_layers: Array[HeightLayer] = []:
	set(value):
		height_layers = value
		_update_shader()

@export_tool_button("Update shader") var update_action := _update_shader

func _init():
	shader = preload("res://assets/shaders/advanced_terrain_shader.gdshader")

func _update_shader():
	if height_layers.is_empty():
		return
	height_layers.sort_custom(func(a, b):
		return a.blend_height < b.blend_height
	)
	var count := height_layers.size()
	var albedo_images = _get_validated_textures(height_layers, func(layer): return layer.material.albedo_texture, ALBEDO_FORMAT)
	var normal_images = _get_validated_textures(height_layers, func(layer): return layer.material.normal_texture, NORMAL_FORMAT)
	var roughness_images = _get_validated_textures(height_layers, func(layer): return layer.material.roughness_texture, ROUGHNESS_FORMAT)
	var metallic_images = _get_validated_textures(height_layers, func(layer): return layer.material.metallic_texture, METALLIC_FORMAT)
	var ao_images = _get_validated_textures(height_layers, func(layer): return layer.material.ao_texture, AO_FORMAT)
	var blend_heights = height_layers.map(func(layer): return layer.blend_height)
	count = albedo_images.size()
	if count == 0:
		return
	var albedo_array = _create_texture_array(albedo_images)
	print("albedo")
	var normal_array = _create_texture_array(normal_images)
	print("normal")
	var roughness_array = _create_texture_array(roughness_images)
	print("roughness")
	var metallic_array = _create_texture_array(metallic_images)
	print("metallic")
	var ao_array = _create_texture_array(ao_images)
	print("ao")
	set_shader_parameter("albedo_array", albedo_array)
	set_shader_parameter("normal_array", normal_array)
	set_shader_parameter("roughness_array", roughness_array)
	set_shader_parameter("metallic_array", metallic_array)
	set_shader_parameter("ao_array", ao_array)
	set_shader_parameter("blend_heights", blend_heights)
	set_shader_parameter("texture_count", count)

func _get_validated_textures(layers: Array, getter: Callable, format: int) -> Array[Image]:
	var base_size := Vector2i(1, 1)
	for layer in layers:
		var texture: Texture2D = getter.call(layer)
		if texture:
			base_size = Vector2i(texture.get_width(), texture.get_height())
			break
	var images: Array[Image] = []
	for layer in layers:
		var texture: Texture2D = getter.call(layer)
		if texture:
			var image := texture.get_image()
#			image.decompress()
			if image.get_width() != base_size.x or image.get_height() != base_size.y:
				image.resize(base_size.x, base_size.y)
			images.append(image)
		else:
			var fallback_img := Image.create(base_size.x, base_size.y, false, format)
			fallback_img.fill(Color(1, 1, 1, 1))
			images.append(fallback_img)
	return images


func _create_texture_array(images: Array[Image]) -> Texture2DArray:
	var array := Texture2DArray.new()
	array.resource_local_to_scene = false
	array.create_from_images(images)
	array.resource_local_to_scene = false
	return array
