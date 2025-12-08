## @brief Decorator source that applies a `HeightmapProcessor` to the output of another `HeightmapSource`.
@tool
class_name HeightmapProcessorDecorator extends HeightmapSource

## Source whose output will be processed. Connects to the `heightmap_changed` signal to propagate changes.
@export var source: HeightmapSource:
	set(value):
		if source and source.heightmap_changed.is_connected(_on_source_changed):
			source.heightmap_changed.disconnect(_on_source_changed)
		source = value
		if source:
			source.heightmap_changed.connect(_on_source_changed)
		heightmap_changed.emit()

## Processor applied to the source's output. Connects to the processor's `changed` signal to propagate updates.
@export var processor: HeightmapProcessor:
	set(value):
		if processor and processor.changed.is_connected(_on_source_changed):
			processor.changed.disconnect(_on_source_changed)
		processor = value
		if processor:
			processor.changed.connect(_on_source_changed)
		heightmap_changed.emit()

## Generate a heightmap by delegating to the `source` and then applying the `processor`.
func generate(context: ProcessingContext) -> Image:
	if not source or not processor:
		push_error("HeightmapProcessorDecorator: Missing source or processor")
		return null
	
	var base_image := source.generate(context)
	if not base_image:
		return null
	return processor.process(base_image, context)

func _on_source_changed():
	heightmap_changed.emit()

## Return a metadata dictionary describing the decorated source and processor.
func get_metadata() -> Dictionary:
	var meta := source.get_metadata() if source else {}
	meta["processor"] = processor.get_processor_name() if processor else "none"
	return meta
