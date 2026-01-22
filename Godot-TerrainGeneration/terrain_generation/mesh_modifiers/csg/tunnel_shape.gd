## @brief Abstract interface for tunnel shapes that support CSG operations and interior mesh generation.
##
## @details Extends CSGVolume to add tunnel-specific capabilities:
## - Interior mesh generation (walls, ceiling, floor)
## - Collision shape creation
## - Terrain-aware clipping
@tool
class_name TunnelShape extends CSGVolume

## Generate the interior mesh for this tunnel shape.
## Only creates geometry that should be underground (above-ground parts excluded).
##
## @param terrain_querier Interface for terrain height queries
## @return MeshData containing the tunnel interior geometry (walls, ceiling, floor)
func generate_interior_mesh(terrain_querier: TerrainHeightQuerier) -> MeshData:
	push_error("TunnelShape.generate_interior_mesh() must be overridden by subclass")
	return MeshData.new()

## Get a collision shape for this tunnel's interior.
## Used for physics interactions inside the tunnel.
##
## @return Shape3D suitable for a CollisionShape3D node
func get_collision_shape() -> Shape3D:
	push_error("TunnelShape.get_collision_shape() must be overridden by subclass")
	return null

## Get the tunnel's origin point (entry position).
## Used for positioning and orientation calculations.
func get_origin() -> Vector3:
	push_error("TunnelShape.get_origin() must be overridden by subclass")
	return Vector3.ZERO

## Get the tunnel's primary direction vector (normalized).
## Used for orientation and length calculations.
func get_direction() -> Vector3:
	push_error("TunnelShape.get_direction() must be overridden by subclass")
	return Vector3.FORWARD

## Get the tunnel's total length along its primary axis.
func get_length() -> float:
	push_error("TunnelShape.get_length() must be overridden by subclass")
	return 0.0

## Get metadata about this tunnel shape (for debugging and serialization).
## Override to provide shape-specific information.
func get_shape_metadata() -> Dictionary:
	return {
		"type": get_shape_type(),
		"origin": get_origin(),
		"direction": get_direction(),
		"length": get_length()
	}

## Get the shape type identifier (e.g., "Cylindrical", "Spline", "Cave").
## MUST be overridden by subclasses.
func get_shape_type() -> String:
	push_error("TunnelShape.get_shape_type() must be overridden by subclass")
	return "Unknown"

