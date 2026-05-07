@tool
class_name MaskProcessor extends HeightmapProcessor

@export var mask_image: Image:
	set(value):
		mask_image = value
		changed.emit()

@export var blur_radius: int = 3:
	set(value):
		blur_radius = value
		changed.emit()

@export var use_transitions: bool = true:
	set(value):
		use_transitions = value
		changed.emit()

@export var transition_threshold: float = 0.05:
	set(value):
		transition_threshold = value
		changed.emit()

@export_group("Transition Selection")
@export var transition_seed: int = 0:
	set(value):
		transition_seed = value
		_init_transition_noise()
		changed.emit()

@export var transition_noise_frequency: float = 0.01:
	set(value):
		transition_noise_frequency = value
		_init_transition_noise()
		changed.emit()

@export_range(0.0, 1.0, 0.01) var cliff_threshold: float = 0.3:
	set(value):
		cliff_threshold = value
		changed.emit()

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

func get_processor_name() -> String:
	return "Mask with Transitions (blur: %d)" % blur_radius if use_transitions else "Simple Mask"

func process_cpu(input: Image, context: ProcessingContext) -> Image:
	if not mask_image:
		push_warning("MaskProcessor: No mask image provided, returning input unchanged")
		return input
	var mask := _prepare_mask(input, ImageBinarizer.binarize_rgb(mask_image, 0.01))
	if not use_transitions:
		return _simple_mask_multiply(input, mask)
	return _advanced_mask_with_transitions(input, mask, context)

## Resize and ensure FORMAT_RF to match input dimensions
func _prepare_mask(ref: Image, mask: Image) -> Image:
	var prepared := mask.duplicate()
	if prepared.get_width() != ref.get_width() or prepared.get_height() != ref.get_height():
		prepared.resize(ref.get_width(), ref.get_height(), Image.INTERPOLATE_NEAREST)
	if prepared.get_format() != Image.FORMAT_RF:
		prepared.convert(Image.FORMAT_RF)
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
	if not blurred_mask:
		push_error("MaskProcessor: blur failed, falling back to simple multiply")
		return _simple_mask_multiply(heightmap, mask)
	if blurred_mask.get_format() != Image.FORMAT_RF:
		blurred_mask.convert(Image.FORMAT_RF)
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	var expected := width * height
	var height_data := heightmap.get_data().to_float32_array()
	var mask_data := mask.get_data().to_float32_array()
	var blur_data := blurred_mask.get_data().to_float32_array()
	if mask_data.size() != expected or blur_data.size() != expected:
		push_error("MaskProcessor: size mismatch — expected %d, mask %d, blur %d" % [
			expected, mask_data.size(), blur_data.size()
		])
		return _simple_mask_multiply(heightmap, mask)
	var cliff := _transition_factory.create_transition(TransitionFactory.TransitionType.CLIFF)
	var beach := _transition_factory.create_transition(TransitionFactory.TransitionType.BEACH)
	var output := PackedFloat32Array()
	output.resize(expected)
	for y in height:
		var row := y * width
		for x in width:
			var i := row + x
			var mask_val := mask_data[i]
			var blur_val := blur_data[i]
			if absf(mask_val - blur_val) > transition_threshold:
				var noise_val := _transition_noise.get_noise_2d(x, y) * 0.5 + 0.5
				var transition := cliff if noise_val < beach_threshold else beach
				output[i] = transition.calculate_height(height_data[i], mask_val, blur_val, Vector2(x, y))
			else:
				output[i] = height_data[i] * mask_val
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, output.to_byte_array())
