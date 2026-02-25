@tool @abstract
class_name ChunkFeature extends Resource

enum SpawnMode {
	PER_CHUNK, ## Spawn per chunk (default)
	SHARED ## Spawn whole feature across multiple chunks (e.g. rivers, roads)
}
## How this feature should be spawned across chunks. 
@export var spawn_mode: SpawnMode = SpawnMode.PER_CHUNK
## Maximum LOD level at which this feature should be generated.
## Higher LOD levels are less detailed and may skip certain features for performance.
@export_range(0, 5) var max_lod_level: int = 1

## Metadata
@export_group("Metadata")

## Unique identifier for this rule
@export var rule_id: String = ""

## Priority (higher = placed first, can block lower priority)
@export var priority: int = 0

## World-space bounds of this feature's content.
## Used for spatial intersection with chunk AABBs.
## For PER_CHUNK features this can be the full terrain bounds.
## For SHARED features this should be the tight AABB of the content.
@abstract
func get_bounds() -> AABB

## Determine if this feature intersects with a given chunk bounds.
func intersects_chunk(chunk_bounds: AABB) -> bool:
	var feature_bounds := get_bounds()
	return feature_bounds.intersects(chunk_bounds)

## Determine if this feature should be applied at a given LOD level.
func should_apply_at_lod(lod_level: int) -> bool:
	return lod_level <= max_lod_level

@abstract
func build_for_chunk(
	chunk_bounds: AABB,
	terrain_sampler: Callable,  # Callable[[Vector2], TerrainSample]
	volumes: Array[VolumeDefinition],
	terrain_definition: TerrainDefinition
) -> Array[ChunkFeatureInstance]



