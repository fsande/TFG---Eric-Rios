## @brief Base class for parametric volume definitions.
##
## @details Volumes represent 3D modifications to terrain that cannot
## be expressed as simple height deltas (tunnels, caves, overhangs).
## Volumes are resolution-independent and generate meshes on demand.
@tool
class_name VolumeDefinition extends Resource

## Type of volume operation
enum VolumeType {
	SUBTRACTIVE,  ## Carves into terrain
	ADDITIVE  ## Adds geometry
}

## The type of volume operation
var volume_type: VolumeType = VolumeType.SUBTRACTIVE

## World-space bounding box of this volume
var bounds: AABB = AABB()

## Minimum LOD level to apply this volume (0 = always apply)
## Higher values mean only apply at detailed LODs
var lod_min: int = 0

## Maximum LOD level to apply this volume (-1 = always apply)
var lod_max: int = -1

## Priority for ordering volume operations (higher = applied later)
var priority: int = 0

## Whether this volume is enabled
var enabled: bool = true

## Metadata
var source_agent: String = ""
var creation_timestamp: int = 0

## Check if this volume should be applied at given LOD level.
## @param lod_level Current LOD level
## @return True if volume should be applied
func should_apply_at_lod(lod_level: int) -> bool:
	if not enabled:
		return false
	if lod_level < lod_min:
		return false
	if lod_max >= 0 and lod_level > lod_max:
		return false
	return true

## Check if this volume intersects with given chunk bounds.
## @param chunk_bounds Chunk AABB to check
## @return True if volume affects this chunk
func intersects_chunk(chunk_bounds: AABB) -> bool:
	return bounds.intersects(chunk_bounds)

## Check if a point is inside this volume.
## @param point World-space point to check
## @return True if point is inside the volume
func point_is_inside(_point: Vector3) -> bool:
	push_error("VolumeDefinition.point_is_inside() must be overridden")
	return false

## Returns t in [0,1] where the segment from `from` to `to` exits this volume.
##
## @details Assumes `from` is inside and `to` is outside — callers must
## guarantee this. Subclasses may override with an analytic solution.
## The default uses binary search, which is reliable under the inside→outside
## call contract because there is exactly one monotone crossing to find.
func exit_t(from: Vector3, to: Vector3) -> float:
	var lo := 0.0
	var hi := 1.0
	for _i in range(16):
		var mid := (lo + hi) * 0.5
		if point_is_inside(from.lerp(to, mid)):
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Generate mesh for this volume at specified resolution.
## @param chunk_bounds Bounds of the chunk being generated
## @param resolution LOD-appropriate resolution
## @return MeshData for this volume, or null if not applicable
func generate_mesh(_chunk_bounds: AABB, _resolution: int) -> MeshData:
	push_error("VolumeDefinition.generate_mesh() must be overridden")
	return null

## Get the volume type as string (for debugging).
func get_type_name() -> String:
	match volume_type:
		VolumeType.SUBTRACTIVE:
			return "Subtractive"
		VolumeType.ADDITIVE:
			return "Additive"
		_:
			return "Unknown"

## Get memory usage estimate in bytes.
func get_memory_usage() -> int:
	return 256  # Base overhead, subclasses override with actual data
