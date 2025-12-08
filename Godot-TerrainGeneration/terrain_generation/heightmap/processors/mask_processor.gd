## @brief Applies a mask to a heightmap with optional edge transitions.
##
## @details Supports simple multiplication (height * mask) or more advanced
## edge transitions where a blurred mask defines transition zones. Transition
## strategies are selected via noise and a TransitionFactory.
@tool
class_name MaskProcessor extends HeightmapProcessor

## Image used as mask. Non-zero areas will keep the source height.
@export var mask_image: Image:
	set(value):
		if value:
			mask_image = ImageBinarizer.binarize_image(value, 0.01)
		else:
			mask_image = null
		changed.emit()

## Radius used to blur the mask for creating transition zones.
@export var blur_radius: float = 3.0:
	set(value):
		blur_radius = value
		changed.emit()

## Whether to use transition strategies at mask edges.
@export var use_transitions: bool = true:
	set(value):
		use_transitions = value
		changed.emit()

## Threshold to consider a pixel part of the transition zone (abs(mask - blur)).
@export var transition_threshold: float = 0.05:
	set(value):
		transition_threshold = value
		changed.emit()

@export_group("Transition Selection")
## Seed used for transition selection noise.
@export var transition_seed: int = 0:
	set(value):
		transition_seed = value
		_init_transition_noise()
		changed.emit()

## Frequency used by the transition selection noise.
@export var transition_noise_frequency: float = 0.01:
	set(value):
		transition_noise_frequency = value
		_init_transition_noise()
		changed.emit()

## Threshold (0..1) under which the noise picks cliff transitions.
@export_range(0.0, 1.0, 0.01) var cliff_threshold: float = 0.3:
	set(value):
		cliff_threshold = value
		changed.emit()

## Threshold (0..1) under which the noise picks rock transitions, otherwise beach.
@export_range(0.0, 1.0, 0.01) var beach_threshold: float = 0.7:
	set(value):
		beach_threshold = value
		changed.emit()

var _blur_processor: BlurProcessor
var _transition_noise: FastNoiseLite
var _transition_factory: TransitionFactory

func _init():
	_blur_processor = BlurProcessor.new()
	_init_transition_noise()

func _init_transition_noise() -> void:
	if not _transition_noise:
		_transition_noise = FastNoiseLite.new()
	_transition_noise.seed = transition_seed if transition_seed > 0 else randi()
	_transition_noise.frequency = transition_noise_frequency
	
	if not _transition_factory:
		_transition_factory = TransitionFactory.new(transition_seed)

func process_cpu(input: Image, context: ProcessingContext) -> Image:
	if not mask_image:
		push_warning("MaskProcessor: No mask image provided, returning input unchanged")
		return input
	var prepared_mask := _prepare_mask(input, mask_image)
	if not use_transitions:
		return _simple_mask_multiply(input, prepared_mask)
	else:
		return _advanced_mask_with_transitions(input, prepared_mask, context)

func get_processor_name() -> String:
	if use_transitions:
		return "Mask with Transitions (blur: %.1f)" % blur_radius
	else:
		return "Simple Mask"

## Prepare mask: binarize and resize to match input dimensions
func _prepare_mask(ref: Image, mask: Image) -> Image:
	var prepared := mask.duplicate()
	
	if prepared.get_width() != ref.get_width() or prepared.get_height() != ref.get_height():
		prepared.resize(ref.get_width(), ref.get_height(), Image.INTERPOLATE_NEAREST)
	
	return prepared

## Simple mask application: heightmap * mask
func _simple_mask_multiply(heightmap: Image, mask: Image) -> Image:
	var result := heightmap.duplicate()
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	
	for y in height:
		for x in width:
			var height_value := heightmap.get_pixel(x, y).r
			var mask_value := mask.get_pixel(x, y).r
			result.set_pixel(x, y, Color(height_value * mask_value, 0, 0))
	
	return result

## Advanced masking with edge transitions
func _advanced_mask_with_transitions(heightmap: Image, mask: Image, context: ProcessingContext) -> Image:
	if not _transition_noise or not _transition_factory:
		_init_transition_noise()
	
	_blur_processor.blur_radius = blur_radius
	var blurred_mask := _blur_processor.process(mask, context)
	
	var result := Image.create(heightmap.get_width(), heightmap.get_height(), false, Image.FORMAT_RF)
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	
	for y in height:
		for x in width:
			var base_height := heightmap.get_pixel(x, y).r
			var mask_value := mask.get_pixel(x, y).r
			var blur_value := blurred_mask.get_pixel(x, y).r
			
			var is_transition: bool = abs(mask_value - blur_value) > transition_threshold
			
			var final_height: float
			
			if is_transition:
				# Select and apply transition strategy
				var transition := _select_transition_for_point(Vector2(x, y))
				final_height = transition.calculate_height(
					base_height,
					mask_value,
					blur_value,
					Vector2(x, y)
				)
			else:
				# Simple multiply for non-edge pixels
				final_height = base_height * mask_value
			result.set_pixel(x, y, Color(final_height, 0, 0))
	
	return result

## Select transition type based on noise value at position
func _select_transition_for_point(position: Vector2) -> TransitionStrategy:
	var noise_val := _transition_noise.get_noise_2d(position.x, position.y) * 0.5 + 0.5
	
	if noise_val < cliff_threshold:
		return _transition_factory.create_transition(TransitionFactory.TransitionType.CLIFF)
	elif noise_val < beach_threshold:
		return _transition_factory.create_transition(TransitionFactory.TransitionType.CLIFF)
	else:
		return _transition_factory.create_transition(TransitionFactory.TransitionType.BEACH)
