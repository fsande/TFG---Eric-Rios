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
		if noise:
			noise.changed.connect(_on_noise_changed)
		heightmap_changed.emit()

func generate(context: ProcessingContext) -> Image:
	if not noise:
		push_error("NoiseHeightmapSource: No noise configured")
		context.complete_substep("Noise Source", 0)
		return null
	var start_time := Time.get_ticks_msec()
	var new_noise: FastNoiseLite = noise.duplicate()
	new_noise.frequency = frequency / context.terrain_size
	if context.generation_seed != 0:
		new_noise.seed = context.generation_seed
	var pixel_count := resolution * resolution
	var data := PackedFloat32Array()
	data.resize(pixel_count)
	var terrain_size := context.terrain_size
	var inv_resolution := 1.0 / resolution
	for y in resolution:
		var row_offset := y * resolution
		var ny := y * inv_resolution * terrain_size
		for x in resolution:
			data[row_offset + x] = (new_noise.get_noise_2d(x * inv_resolution * terrain_size, ny) + 1.0) * 0.5
	var elapsed := Time.get_ticks_msec() - start_time
	var noise_label := "Noise Source [type=%d seed=%d freq=%.2f]" % [
		new_noise.noise_type, new_noise.seed, new_noise.frequency
	]
	context.complete_substep(noise_label, elapsed)
	return Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, data.to_byte_array())

func _on_noise_changed():
	heightmap_changed.emit()

func get_metadata() -> Dictionary:
	return {
		"type": "noise",
		"resolution": resolution,
		"noise_type": noise.noise_type if noise else FastNoiseLite.NoiseType.TYPE_SIMPLEX
	}
