@tool
class_name NoiseHeightmapSource extends HeightmapSource

## The resolution of the generated heightmap.
## Higher resolutions yield more detailed heightmaps but increase computation time.
@export var resolution: int = 1024:
	set(value):
		resolution = value
		heightmap_changed.emit()

## The frequency of the noise. Higher frequencies produce more rapid changes in height.
@export var frequency: float = 5.0:
	set(value):
		frequency = value
		heightmap_changed.emit()

## The FastNoiseLite instance used to generate the heightmap.
@export var noise: FastNoiseLite = FastNoiseLite.new():
	set(value):
		noise = value
		if noise and not noise.changed.is_connected(_on_noise_changed()):
			noise.changed.connect(_on_noise_changed)
		heightmap_changed.emit()

func generate(context: ProcessingContext) -> Image:
	if not noise:
		push_error("NoiseHeightmapSource: No noise configured")
		return null
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RF)
	var new_noise: FastNoiseLite = noise.duplicate()
	new_noise.frequency = frequency / context.terrain_size
	if context.generation_seed != 0:
		new_noise.seed = context.generation_seed
	for y in resolution:
		for x in resolution:
			var nx := float(x) / resolution * context.terrain_size
			var ny := float(y) / resolution * context.terrain_size
			var h := (new_noise.get_noise_2d(nx, ny) + 1.0) / 2.0
			img.set_pixel(x, y, Color(h, 0, 0))
	return img

func _on_noise_changed():
	heightmap_changed.emit()

func get_metadata() -> Dictionary:
	return {
		"type": "noise",
		"resolution": resolution,
		"noise_type": noise.noise_type if noise else FastNoiseLite.NoiseType.TYPE_SIMPLEX
	}
