@tool
class_name NormalizationProcessor extends HeightmapProcessor

## Normalizes heightmap values to a specified range.
##
## This processor analyzes the current min/max values in the heightmap and remaps
## all values to fit within the target range [min_value, max_value]. This is useful
## for ensuring heightmaps use the full dynamic range or for constraining values
## to specific bounds.
##
## Example:
## - Input heightmap with values [0.2, 0.8]
## - Target range [0.0, 1.0]
## - Output heightmap with values [0.0, 1.0] (stretched to full range)

#region Exported Properties

## Minimum value of the target range.
## All heightmap values will be remapped so the lowest value becomes this.
@export var min_value: float = 0.0:
	set(value):
		min_value = value
		changed.emit()

## Maximum value of the target range.
## All heightmap values will be remapped so the highest value becomes this.
@export var max_value: float = 1.0:
	set(value):
		max_value = value
		changed.emit()

#endregion

#region HeightmapProcessor Implementation

## Processes the heightmap using CPU normalization.
##
## Algorithm:
## 1. Find current min/max values in the input heightmap
## 2. Calculate normalization: normalized = (value - current_min) / (current_max - current_min)
## 3. Remap to target range: remapped = normalized * (max_value - min_value) + min_value
##
## @param input: The input heightmap image (FORMAT_RF)
## @param _context: Processing context (unused for this processor)
## @return: A new image with normalized values
func process_cpu(input: Image, _context: ProcessingContext) -> Image:
	var result := input.duplicate()
	
	# First pass: find the current min and max values in the heightmap
	var current_min := 1.0
	var current_max := 0.0
	for y in input.get_height():
		for x in input.get_width():
			var value := input.get_pixel(x, y).r
			current_min = min(current_min, value)
			current_max = max(current_max, value)
	
	# Calculate the ranges
	var range_current := current_max - current_min
	var range_target := max_value - min_value
	
	# Second pass: normalize and remap values
	# Only process if there's a meaningful range (avoid division by zero)
	if range_current > 0.0001:
		for y in input.get_height():
			for x in input.get_width():
				var value := input.get_pixel(x, y).r
				# Normalize to [0, 1]
				var normalized := (value - current_min) / range_current
				# Remap to target range [min_value, max_value]
				var remapped := normalized * range_target + min_value
				result.set_pixel(x, y, Color(remapped, 0, 0))
	
	return result

## Returns a human-readable name for this processor.
##
## @return: The processor name with current min/max range
func get_processor_name() -> String:
	return "Normalize [%.2f-%.2f]" % [min_value, max_value]

#endregion

