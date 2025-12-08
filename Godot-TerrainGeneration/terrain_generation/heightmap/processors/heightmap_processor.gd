# Interface for heightmap processors used in terrain generation.
# Automatically dispatches to CPU or GPU implementation based on context.
@tool
class_name HeightmapProcessor extends Resource  

## Process the input heightmap image based on the provided context.
func process(input: Image, context: ProcessingContext) -> Image:
	if context.use_gpu():
		return process_gpu(input, context)
	else:
		return process_cpu(input, context)

## CPU implementation - must be overridden
func process_cpu(input: Image, context: ProcessingContext) -> Image:  
	push_error("process_cpu() must be implemented by subclass")    
	return null

## GPU implementation - optional override
func process_gpu(input: Image, context: ProcessingContext) -> Image:
	push_warning("%s: GPU processing not implemented, falling back to CPU" % get_processor_name())
	return process_cpu(input, context)

## Get the name of the processor
func get_processor_name() -> String:  
	return "Unknown Processor"
