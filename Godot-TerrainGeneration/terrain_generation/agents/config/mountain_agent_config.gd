class_name MountainAgentConfig extends Resource

@export_group("Mountain Parameters")

## Starting position of the mountain ridge (world coordinates)
@export var start_position: Vector2 = Vector2(0, 0)

## Initial direction angle in degrees (0 = North/+Z, 90 = East/+X)
@export_range(0.0, 360.0, 1.0) var initial_direction_degrees: float = 0.0

## Distance to move forward each token
@export var step_distance: float = 64.0

## Wedge width (perpendicular to direction)
@export var wedge_width: float = 190

## Wedge length (along direction)
@export var wedge_length: float = 100

## Height to elevate at wedge center
@export var elevation_height: float = 36.0

## Falloff strength for wedge elevation
@export_range(0.1, 5.0) var elevation_falloff: float = 1.0

@export_group("Randomization")

## Height variation per wedge
@export_range(0.0, 10.0) var height_variation: float = 1

## Noise used for height variation
@export var height_variation_noise: FastNoiseLite = FastNoiseLite.new():

## Width variation per wedge
@export_range(0.0, 10.0) var width_variation: float = 0.2

## Length variation per wedge
@export_range(0.0, 10.0) var length_variation: float = 0.2

@export_group("Direction Changes")

## Change direction every N tokens (0 = never)
@export_range(0, 100) var direction_change_interval: int = 2

## Angle change in degrees (+/-)
@export_range(0.0, 90.0) var direction_change_angle: float = 45.0

## Random seed for direction (0 = use context seed)
@export var direction_seed: int = 0

@export_group("Overhangs")

## Enable overhang volume generation
@export var enable_overhangs: bool = false

## Probability of overhang at each token
@export_range(0.0, 1.0) var overhang_probability: float = 0.15

## How far overhangs extend
@export var overhang_extent: float = 4.0

## Minimum slope to create overhang (degrees)
@export_range(0.0, 90.0) var overhang_min_slope: float = 45.0

@export_group("Output")

## Resolution of the generated delta texture
@export_range(64, 1024) var delta_resolution: int = 256

func _init() -> void:
	height_variation_noise.frequency = 0.1