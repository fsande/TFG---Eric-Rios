@tool
class_name HeightVariationMaterial extends ShaderMaterial

const ALBEDO_FORMAT = Image.FORMAT_RGBA8
const NORMAL_FORMAT = Image.FORMAT_RGBA8
const ORM_FORMAT = Image.FORMAT_RGBA8

@export var height_layers: Array[HeightLayer] = []:
	set(value):
		height_layers = value
		_update_shader()

@export_tool_button("Update shader") var update_action := _update_shader

func _init():
	shader = preload("res://assets/shaders/advanced_terrain_shader.gdshader")
	_update_shader()
	
func _validate_property(property: Dictionary) -> void:
	if property.name in ["shader_parameter/albedo_array", "shader_parameter/normal_array", "shader_parameter/orm_array"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_INTERNAL

func _update_shader():
	if height_layers.is_empty():
		return
	height_layers.sort_custom(func(a, b):
		return a.blend_height < b.blend_height
	)
	var count := height_layers.size()
	var albedo_images = _get_validated_textures(height_layers, func(layer): return layer.material.albedo_texture, ALBEDO_FORMAT)
	var normal_images = _get_validated_textures(height_layers, func(layer): return layer.material.normal_texture, NORMAL_FORMAT)
	var orm_images = _get_orm_textures(height_layers)
	var blend_heights = height_layers.map(func(layer): return layer.blend_height)
	count = albedo_images.size()
	if count == 0:
		return
	set_shader_parameter("albedo_array", _create_texture_array(albedo_images))
	set_shader_parameter("normal_array", _create_texture_array(normal_images))
	set_shader_parameter("orm_array", _create_texture_array(orm_images))
	set_shader_parameter("blend_heights", blend_heights)
	set_shader_parameter("texture_count", count)

## Packs AO (R), Roughness (G), Metallic (B) from each layer's material into one image per layer
func _get_orm_textures(layers: Array[HeightLayer]) -> Array[Image]:
	var base_size := Vector2i(1, 1)
	for layer in layers:
		var t: Texture2D = layer.material.ao_texture
		if not t: t = layer.material.roughness_texture
		if not t: t = layer.material.metallic_texture
		if t:
			base_size = Vector2i(t.get_width(), t.get_height())
			break
	var images: Array[Image] = []
	for layer in layers:
		var ao_img := _get_single_channel(layer.material.ao_texture, base_size, 1.0)
		ao_img.decompress()
		var rough_img := _get_single_channel(layer.material.roughness_texture, base_size, 1.0)
		rough_img.decompress()
		var metal_img := _get_single_channel(layer.material.metallic_texture, base_size, 0.0)
		metal_img.decompress()
		var orm := Image.create(base_size.x, base_size.y, false, ORM_FORMAT)
		for y in base_size.y:
			for x in base_size.x:
				orm.set_pixel(x, y, Color(
					ao_img.get_pixel(x, y).r,
					rough_img.get_pixel(x, y).r,
					metal_img.get_pixel(x, y).r,
					1.0
				))
		images.append(orm)
	return images

## Extracts a single-channel image from a texture, or returns a flat fallback
func _get_single_channel(texture: Texture2D, size: Vector2i, fallback_value: float) -> Image:
	if texture:
		var texture_img := texture.get_image()
		if texture_img.get_width() != size.x or texture_img.get_height() != size.y:
			texture_img.resize(size.x, size.y)
		return texture_img
	var img := Image.create(size.x, size.y, false, Image.FORMAT_R8)
	img.fill(Color(fallback_value, fallback_value, fallback_value))
	return img

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
