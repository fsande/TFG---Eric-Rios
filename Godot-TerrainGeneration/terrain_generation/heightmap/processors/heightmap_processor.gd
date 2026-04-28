# Interface for heightmap processors used in terrain generation.
# Automatically dispatches to CPU or GPU implementation based on context.
@tool @abstract
class_name HeightmapProcessor extends Resource  

## Process the input heightmap image based on the provided context.
func process(input: Image, context: ProcessingContext) -> Image:
	var start_time := Time.get_ticks_msec()
	if context.heightmap_use_gpu():
		var result := process_gpu(input, context)
		var elapsed := Time.get_ticks_msec() - start_time
		context.heightmap_processor_completed.emit(get_processor_name(), elapsed)
		return result
	else:
		var result := process_cpu(input, context)
		var elapsed := Time.get_ticks_msec() - start_time
		context.heightmap_processor_completed.emit(get_processor_name(), elapsed)
		return result

## CPU implementation - must be overridden
@abstract func process_cpu(input: Image, context: ProcessingContext) -> Image

## GPU implementation - optional override
func process_gpu(input: Image, context: ProcessingContext) -> Image:
	push_warning("HeightmapProcessor: GPU processing not implemented, falling back to CPU")
	return process_cpu(input, context)

## Get the name of the processor
@abstract func get_processor_name() -> String
