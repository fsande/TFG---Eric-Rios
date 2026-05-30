## This processor is based on the erosion filter implemented by Runevision.
## Recommended to be applied on low frequency, low variation heightmaps. Otherwise, the erosion may produce too much noise
## See https://blog.runevision.com/2026/03/fast-and-gorgeous-erosion-filter.html for details.
## Advanced Terrain Erosion Filter copyright (c) 2025 Rune Skovbo Johansen
## Mozilla Public License, v. 2.0 — https://mozilla.org/MPL/2.0/
@tool
class_name RuneErosion extends HeightmapProcessor

const SHADER_PATH := "res://terrain_generation/heightmap/processors/shaders/rune_erosion.glsl"

# Erosion parameters - see the shader for detailed explanations.
## The scale of the erosion effect, affecting it both horizontally and vertically.
@export var erosion_scale: float = 0.15:
	set(v):
		erosion_scale = v
		changed.emit()

## The strength of the erosion effect, affecting the magnitude of all octaves.
@export var erosion_strength: float = 0.22:
	set(v):
		erosion_strength = v
		changed.emit()

## Gully weight from 0 to 1. 0 = sharp peaks/valleys with no gullies.
## 1 = full gullies but rounded peaks/valleys.
@export_range(0.0, 1.0) var erosion_gully_weight: float = 0.5:
	set(v):
		erosion_gully_weight = v
		changed.emit()

## Overall detail. Lower values restrict higher-frequency gullies to steeper slopes.
@export var erosion_detail: float = 1.5:
	set(v):
		erosion_detail = v
		changed.emit()

## Rounding of ridges (peaks). Higher = smoother ridges.
@export_range(0.0, 1.0) var erosion_ridge_rounding: float = 0.1:
	set(v):
		erosion_ridge_rounding = v
		changed.emit()

## Rounding of creases (valleys). Higher = smoother valley floors.
@export_range(0.0, 1.0) var erosion_crease_rounding: float = 0.0:
	set(v):
		erosion_crease_rounding = v
		changed.emit()

## Rounding multiplier applied to the initial height function. E.g. if the
## height function has noise of 5x lower frequency than the largest gullies,
## a value of 0.2 can compensate.
@export var erosion_rounding_initial_mult: float = 0.1:
	set(v):
		erosion_rounding_initial_mult = v
		changed.emit()

## Rounding multiplier applied to each subsequent gully octave after the first.
## Setting it equal to erosion_lacunarity gives consistent rounding across octaves.
@export var erosion_rounding_octave_mult: float = 2.0:
	set(v):
		erosion_rounding_octave_mult = v
		changed.emit()

## Onset used on the initial height function — how far from ridges/creases
## the erosion takes effect.
@export var erosion_onset_initial: float = 1.25:
	set(v):
		erosion_onset_initial = v
		changed.emit()

## Onset used on each subsequent gully octave.
@export var erosion_onset_octave: float = 1.25:
	set(v):
		erosion_onset_octave = v
		changed.emit()

## Ridge-map-specific onset used on the initial height function.
@export var erosion_onset_ridge_initial: float = 2.8:
	set(v):
		erosion_onset_ridge_initial = v
		changed.emit()

## Ridge-map-specific onset used on each gully octave.
@export var erosion_onset_ridge_octave: float = 1.5:
	set(v):
		erosion_onset_ridge_octave = v
		changed.emit()

## An assumed slope value to partially override the actual terrain slope.
## In practice this can produce more natural-looking gully directions.
@export var erosion_assumed_slope_value: float = 0.7:
	set(v):
		erosion_assumed_slope_value = v
		changed.emit()

## Blend from actual slope (0) to the assumed slope (1).
@export_range(0.0, 1.0) var erosion_assumed_slope_amount: float = 1.0:
	set(v):
		erosion_assumed_slope_amount = v
		changed.emit()

## Number of stacked gully octaves. More octaves = finer detail, higher cost.
@export_range(1, 10) var erosion_octaves: int = 5:
	set(v):
		erosion_octaves = v
		changed.emit()

## Lacunarity: frequency multiplier between octaves.
@export var erosion_lacunarity: float = 2.0:
	set(v):
		erosion_lacunarity = v
		changed.emit()

## Gain: amplitude multiplier between octaves.
@export var erosion_gain: float = 0.5:
	set(v):
		erosion_gain = v
		changed.emit()

## Controls the Voronoi cell size relative to the erosion scale. Values near 1
## work best; too large produces chaotic curved gullies. Not suited for animation.
@export var erosion_cell_scale: float = 0.7:
	set(v):
		erosion_cell_scale = v
		changed.emit()

## Degree of normalization in the Phacelle noise (0–1). High values can
## produce unnatural loopy ridges/creases.
@export_range(0.0, 1.0) var erosion_normalization: float = 0.5:
	set(v):
		erosion_normalization = v
		changed.emit()

## Height offset direction: -1 = erosion only lowers, 1 = erosion only raises.
## The offset is proportional to erosion strength.
@export_range(-1.0, 1.0) var terrain_height_offset: float = -0.65:
	set(v):
		terrain_height_offset = v
		changed.emit()

## Blend from the fixed height_offset (0) to negated per-pixel fade target (1),
## which preserves minima and maxima of the terrain.
@export_range(0.0, 1.0) var terrain_height_offset_fade_blend: float = 0.0:
	set(v):
		terrain_height_offset_fade_blend = v
		changed.emit()

# Processing
func process_cpu(input: Image, _context: ProcessingContext) -> Image:
	push_warning("RuneErosion: CPU processing is not implemented; returning input unchanged")
	return input

func process_gpu(input: Image, context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return process_cpu(input, context)
	var shader := context.get_or_create_shader(SHADER_PATH)
	if not shader.is_valid():
		push_warning("RuneErosion: GPU shader not available; returning input unchanged")
		return process_cpu(input, context)
	var width := input.get_width()
	var height := input.get_height()
	var pipeline := rd.compute_pipeline_create(shader)
	var input_texture := GpuTextureHelper.create_texture_from_image(rd, input)
	var output_texture := GpuTextureHelper.create_empty_texture(rd, width, height)
	_execute_erosion_gpu(rd, pipeline, shader, input_texture, output_texture, width, height)
	var result := GpuTextureHelper.read_texture_to_image(rd, output_texture, width, height)
	GpuResourceHelper.free_rids(rd, [input_texture, output_texture, pipeline])
	return result

func _execute_erosion_gpu(
	rd: RenderingDevice,
	pipeline: RID,
	shader: RID,
	input_tex: RID,
	output_tex: RID,
	width: int,
	height: int,
) -> void:
	var uniform_set := GpuTextureHelper.create_image_uniform_set(rd, input_tex, output_tex, shader)
	var params_buffer := _create_params_buffer(rd, width, height)
	var params_uniform_set := GpuTextureHelper.create_params_uniform_set(rd, params_buffer, shader, 2)
	var groups_x := ceili(float(width) / 16.0)
	var groups_y := ceili(float(height) / 16.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, params_uniform_set, 1)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	GpuResourceHelper.free_rids(rd, [uniform_set, params_uniform_set, params_buffer])

## Get the name of the processor.
func get_processor_name() -> String:
	return "Rune Erosion (scale: %.2f, strength: %.2f, oct: %d)" % [
		erosion_scale, erosion_strength, erosion_octaves
	]

# ---------------------------------------------------------------------------
# Params buffer layout (must match the GLSL struct exactly):
#   int   width, height, octaves, _pad
#   float strength, gully_weight, detail,
#         rounding_ridge, rounding_crease, rounding_initial_mult, rounding_octave_mult,
#         onset_initial, onset_octave, onset_ridge_initial, onset_ridge_octave,
#         assumed_slope_value, assumed_slope_amount,
#         scale, lacunarity, gain, cell_scale, normalization,
#         height_offset, height_offset_fade_blend
# ---------------------------------------------------------------------------
func _create_params_buffer(rd: RenderingDevice, width: int, height: int) -> RID:
	const INT_COUNT := 4
	const FLOAT_COUNT := 22
	var bytes := PackedByteArray()
	bytes.resize((INT_COUNT + FLOAT_COUNT) * 4)
	var off := 0
	bytes.encode_s32(off, width); off += 4
	bytes.encode_s32(off, height); off += 4
	bytes.encode_s32(off, erosion_octaves); off += 4
	bytes.encode_s32(off, 0); off += 4  # padding
	bytes.encode_float(off, erosion_strength); off += 4
	bytes.encode_float(off, erosion_gully_weight); off += 4
	bytes.encode_float(off, erosion_detail); off += 4
	bytes.encode_float(off, erosion_ridge_rounding); off += 4
	bytes.encode_float(off, erosion_crease_rounding); off += 4
	bytes.encode_float(off, erosion_rounding_initial_mult); off += 4
	bytes.encode_float(off, erosion_rounding_octave_mult); off += 4
	bytes.encode_float(off, erosion_onset_initial); off += 4
	bytes.encode_float(off, erosion_onset_octave); off += 4
	bytes.encode_float(off, erosion_onset_ridge_initial); off += 4
	bytes.encode_float(off, erosion_onset_ridge_octave); off += 4
	bytes.encode_float(off, erosion_assumed_slope_value); off += 4
	bytes.encode_float(off, erosion_assumed_slope_amount); off += 4
	bytes.encode_float(off, erosion_scale); off += 4
	bytes.encode_float(off, erosion_lacunarity); off += 4
	bytes.encode_float(off, erosion_gain); off += 4
	bytes.encode_float(off, erosion_cell_scale); off += 4
	bytes.encode_float(off, erosion_normalization); off += 4
	bytes.encode_float(off, terrain_height_offset); off += 4
	bytes.encode_float(off, terrain_height_offset_fade_blend); off += 4
	return rd.storage_buffer_create(bytes.size(), bytes)
