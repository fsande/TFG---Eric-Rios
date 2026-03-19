@tool
class_name SplatmapTerrainMaterial extends ShaderMaterial

@export var layer_rules: Array[LayerRule] = []:
	set(value):
		layer_rules = value
		_rebuild()

## Resolution of the generated splatmap texture. Higher = better quality but more GPU memory. 256 should be good for most cases
@export var splatmap_resolution: int = 256

## Noise for edge variation
@export var blend_noise: FastNoiseLite

@export_tool_button("Rebuild") var rebuild_action := _rebuild

func _init() -> void:
	shader = preload("res://assets/shaders/advanced_terrain_shader.gdshader")

func generate_for_chunk(heightmap: Image) -> void:
	_rebuild_with_heightmap(heightmap)

func _rebuild() -> void:
	var test_hm := Image.create(splatmap_resolution, splatmap_resolution, false, Image.FORMAT_R8)
	for y in splatmap_resolution:
		for x in splatmap_resolution:
			test_hm.set_pixel(x, y, Color(float(y) / splatmap_resolution, 0, 0))
	_rebuild_with_heightmap(test_hm)

func _rebuild_with_heightmap(heightmap: Image) -> void:
	if layer_rules.is_empty():
		return
	var sorted: Array = layer_rules.duplicate()
	sorted.sort_custom(func(a, b): return a.blend_height < b.blend_height)
	var resolved: Array[ResolvedLayerRule] = []
	for i in sorted.size():
		var r := ResolvedLayerRule.new()
		r.rule = sorted[i]
		r.height_min = sorted[i - 1].blend_height if i > 0 else 0.0
		r.height_max = sorted[i + 1].blend_height if i < sorted.size() - 1 else 1.0
		resolved.append(r)
	var splatmap_images: Array[Image] = []
	var i := 0
	while i < resolved.size():
		var batch: Array = resolved.slice(i, i + 4)
		splatmap_images.append(
			SplatmapGenerator.generate(heightmap, splatmap_resolution, batch, blend_noise)
		)
		i += 4
	var splatmap_array := Texture2DArray.new()
	splatmap_array.create_from_images(splatmap_images)
	set_shader_parameter("splatmaps", splatmap_array)
	set_shader_parameter("splatmap_count", splatmap_images.size())
	_update_texture_arrays(sorted)

# In SplatmapTerrainMaterial
func generate_for_chunk_from_grid(height_grid: PackedFloat32Array, grid_resolution: int, terrain_height: float) -> void:
	var sorted := layer_rules.duplicate()
	sorted.sort_custom(func(a, b): return a.blend_height < b.blend_height)
	var resolved := _resolve_rules(sorted)
	var splatmap_images: Array[Image] = [] 
	var i := 0
	while i < resolved.size():
		var batch: Array = resolved.slice(i, i + 4)
		splatmap_images.append(
			SplatmapGenerator.generate_from_grid(
				height_grid, grid_resolution, terrain_height,
				splatmap_resolution, batch, blend_noise
			)
		)
		i += 4
	var splatmap_array := Texture2DArray.new()
	splatmap_array.create_from_images(splatmap_images)
	set_shader_parameter("splatmaps", splatmap_array)
	set_shader_parameter("splatmap_count", splatmap_images.size())
	_update_texture_arrays(sorted)

func _resolve_rules(sorted: Array) -> Array[ResolvedLayerRule]:
	var resolved: Array[ResolvedLayerRule] = []
	for i in sorted.size():
		var r := ResolvedLayerRule.new()
		r.rule = sorted[i]
		r.height_min = sorted[i - 1].blend_height if i > 0 else 0.0
		r.height_max = sorted[i + 1].blend_height if i < sorted.size() - 1 else 1.0
		resolved.append(r)
	return resolved

func _update_texture_arrays(sorted: Array) -> void:
	var albedo_imgs: Array[Image] = []
	var normal_imgs: Array[Image] = []
	var roughness_imgs: Array[Image] = []
	var metallic_imgs: Array[Image] = []
	var ao_imgs: Array[Image] = []
	for rule: LayerRule in sorted:
		var mat := rule.material
		albedo_imgs.append(_get_image_or_fallback(mat.albedo_texture, Image.FORMAT_RGBA8, Color.WHITE))
		normal_imgs.append(_get_image_or_fallback(mat.normal_texture, Image.FORMAT_RGBA8, Color(0.5, 0.5, 1.0)))
		roughness_imgs.append(_get_image_or_fallback(mat.roughness_texture, Image.FORMAT_R8, Color.WHITE))
		metallic_imgs.append(_get_image_or_fallback(mat.metallic_texture, Image.FORMAT_R8, Color.BLACK))
		ao_imgs.append(_get_image_or_fallback(mat.ao_texture, Image.FORMAT_R8, Color.WHITE))
	set_shader_parameter("albedo_array", _create_texture_array(albedo_imgs))
	set_shader_parameter("normal_array", _create_texture_array(normal_imgs))
	set_shader_parameter("roughness_array", _create_texture_array(roughness_imgs))
	set_shader_parameter("metallic_array", _create_texture_array(metallic_imgs))
	set_shader_parameter("ao_array", _create_texture_array(ao_imgs))
	set_shader_parameter("texture_count", sorted.size())

func _get_image_or_fallback(texture: Texture2D, format: int, fallback_color: Color) -> Image:
	if texture:
		return texture.get_image()
	var img := Image.create(4, 4, false, format)
	img.fill(fallback_color)
	return img

func _create_texture_array(images: Array[Image]) -> Texture2DArray:
	var base_size := Vector2i(images[0].get_width(), images[0].get_height())
	for img in images:
		if Vector2i(img.get_width(), img.get_height()) != base_size:
			img.resize(base_size.x, base_size.y)
	var array := Texture2DArray.new()
	array.create_from_images(images)
	return array
