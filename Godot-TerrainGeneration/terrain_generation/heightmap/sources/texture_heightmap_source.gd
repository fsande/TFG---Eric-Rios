@tool
class_name TextureHeightmapSource extends HeightmapSource

@export var heightmap_texture: Texture2D:
	set(value):
		heightmap_texture = value
		heightmap_changed.emit()

func generate(context: ProcessingContext) -> Image:
	if heightmap_texture:
		var image := heightmap_texture.get_image()
		image.convert(Image.FORMAT_RF)
		return image
	else:
		return null

func get_metadata() -> Dictionary:
	return {
		"type": "texture",
		"width": heightmap_texture.get_width() if heightmap_texture else 0,
		"height": heightmap_texture.get_height() if heightmap_texture else 0
	}
