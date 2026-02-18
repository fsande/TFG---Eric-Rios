@tool class_name PropPlacementContext extends RefCounted

var position_2d: Vector2
var terrain_sample: TerrainSample
var sea_level: float
var existing_placements: Array[PropPlacement] = []
var volumes: Array[VolumeDefinition] = []
var rng: RandomNumberGenerator

func _init(
	p_position_2d: Vector2,
	p_terrain_sample: TerrainSample,
	p_sea_level: float,
	p_existing_placements: Array[PropPlacement],
	p_volumes: Array[VolumeDefinition],
	p_rng: RandomNumberGenerator
) -> void:
	position_2d = p_position_2d
	terrain_sample = p_terrain_sample
	sea_level = p_sea_level
	existing_placements = p_existing_placements
	volumes = p_volumes
	rng = p_rng
