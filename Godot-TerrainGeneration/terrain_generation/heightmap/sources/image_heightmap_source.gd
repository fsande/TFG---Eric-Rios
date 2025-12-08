@tool
class_name ImageHeightmapSource extends HeightmapSource

@export var heightmap_image: Image:
	set(value):
		heightmap_image = value
		heightmap_changed.emit()

func generate(context: ProcessingContext) -> Image:
	return heightmap_image.duplicate() if heightmap_image else null

func get_metadata() -> Dictionary:
	return {
		"type": "image",
		"width": heightmap_image.get_width() if heightmap_image else 0,
		"height": heightmap_image.get_height() if heightmap_image else 0
	}
