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
			mask_image = ImageBinarizer.binarize_rgb(value, 0.01)
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

func _simple_mask_multiply(heightmap: Image, mask: Image) -> Image:
	var height_data := heightmap.get_data().to_float32_array()
	var mask_data := mask.get_data().to_float32_array()
	for i in height_data.size():
		height_data[i] *= mask_data[i]
	return Image.create_from_data(heightmap.get_width(), heightmap.get_height(), false, Image.FORMAT_RF, height_data.to_byte_array())

func _advanced_mask_with_transitions(heightmap: Image, mask: Image, context: ProcessingContext) -> Image:
	if not _transition_noise or not _transition_factory:
		_init_transition_noise()
	_blur_processor.blur_radius = blur_radius
	var blurred_mask := _blur_processor.process(mask, context)
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	var height_data := heightmap.get_data().to_float32_array()
	var mask_data := mask.get_data().to_float32_array()
	var blur_data := blurred_mask.get_data().to_float32_array()
	var output := PackedFloat32Array()
	output.resize(width * height)
	var cliff := _transition_factory.create_transition(TransitionFactory.TransitionType.CLIFF)
	var beach := _transition_factory.create_transition(TransitionFactory.TransitionType.BEACH)
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var mask_value := mask_data[i]
			var blur_value := blur_data[i]
			if abs(mask_value - blur_value) > transition_threshold:
				var noise_val := _transition_noise.get_noise_2d(x, y) * 0.5 + 0.5
				var transition := cliff if noise_val < beach_threshold else beach
				output[i] = transition.calculate_height(height_data[i], mask_value, blur_value, Vector2(x, y))
			else:
				output[i] = height_data[i] * mask_value
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, output.to_byte_array())
