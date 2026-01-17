@tool
class_name CompositeHeightmapSource extends HeightmapSource

## Sources to combine - max 8
@export var sources: Array[HeightmapSource] = []:
	set(value):
		for source in sources:
			if source and source.heightmap_changed.is_connected(_on_source_changed):
				source.heightmap_changed.disconnect(_on_source_changed)
		if value.size() > HeightmapCombiner.MAX_GPU_IMAGES:
			push_warning("CompositeHeightmapSource: Maximum %d sources supported. Using first %d." % [HeightmapCombiner.MAX_GPU_IMAGES, HeightmapCombiner.MAX_GPU_IMAGES])
			sources = value.slice(0, HeightmapCombiner.MAX_GPU_IMAGES)
		else:
			sources = value
		for source in sources:
			if source and not source.heightmap_changed.is_connected(_on_source_changed):
				source.heightmap_changed.connect(_on_source_changed)
		heightmap_changed.emit()

## Combiner to use
@export var combiner: HeightmapCombiner:
	set(value):
		if combiner and combiner.changed.is_connected(_on_source_changed):
			combiner.changed.disconnect(_on_source_changed)
		combiner = value
		if combiner:
			combiner.changed.connect(_on_source_changed)
		heightmap_changed.emit()

func generate(context: ProcessingContext) -> Image:
	if sources.is_empty():
		push_error("CompositeHeightmapSource: No sources provided")
		return null
	var images: Array[Image] = []
	for source in sources:
		var img := source.generate(context)
		if img:
			images.append(img)
	if images.is_empty():
		return null
	if combiner:
		return combiner.combine(images, context)
	else:
		return images[0]

func _on_source_changed():
	heightmap_changed.emit()

func get_metadata() -> Dictionary:
	return {
		"type": "composite",
		"source_count": sources.size(),
		"combiner": combiner.get_combiner_name() if combiner else "none"
	}
