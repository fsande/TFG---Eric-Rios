## @brief Simple vertex snapping to reduce tunnel entrance seams.
##
## @details Snaps nearby terrain vertices to tunnel entrance ring positions.
## This is a lightweight alternative to full vertex stitching that significantly
## reduces visible seams without complex mesh surgery.
##
## Design Pattern: Strategy Pattern - Simple geometric adjustment strategy
## SOLID: Single Responsibility - Only handles vertex position snapping
@tool
class_name SimpleVertexSnapper extends RefCounted

## Multiplier for snap radius (relative to tunnel radius)
const DEFAULT_SNAP_RADIUS_MULTIPLIER: float = 1.5

## Maximum distance for snapping (prevents snapping far vertices)
const MAX_SNAP_DISTANCE: float = 2.0

## Minimum distance to consider snapping (prevents snapping identical positions)
const MIN_SNAP_DISTANCE: float = 0.01

## Statistics
var _vertices_snapped: int = 0
var _vertices_examined: int = 0

## Snap terrain vertices near tunnel entrance to tunnel ring vertices.
##
## @param terrain_mesh MeshData of terrain (will be modified in-place)
## @param tunnel_shape TunnelShape defining the tunnel
## @param snap_radius_multiplier How far from entrance to search for vertices
## @return int Number of vertices snapped
func snap_entrance(
	terrain_mesh: MeshData,
	tunnel_shape: TunnelShape,
	snap_radius_multiplier: float = DEFAULT_SNAP_RADIUS_MULTIPLIER
) -> int:
	_vertices_snapped = 0
	_vertices_examined = 0
	var entrance_pos := tunnel_shape.get_origin()
	var tunnel_radius := _get_tunnel_radius(tunnel_shape)
	var snap_radius := tunnel_radius * snap_radius_multiplier
	var tunnel_ring := _get_tunnel_entrance_ring(tunnel_shape)
	if tunnel_ring.is_empty():
		push_warning("SimpleVertexSnapper: Failed to get tunnel entrance ring")
		return 0
	_snap_nearby_vertices(terrain_mesh, entrance_pos, snap_radius, tunnel_ring)
	
	# Log detailed summary
	if _vertices_snapped > 0:
		var snap_ratio: float = float(_vertices_snapped) / max(1, _vertices_examined) * 100.0
		print("  SimpleVertexSnapper: Examined %d vertices, snapped %d (%.1f%%) at radius %.2fm" % 
			[_vertices_examined, _vertices_snapped, snap_ratio, snap_radius])
	else:
		print("  SimpleVertexSnapper: No vertices snapped (examined %d, snap_radius=%.2fm)" % 
			[_vertices_examined, snap_radius])
	
	return _vertices_snapped

## Snap vertices in terrain mesh that are near the entrance
func _snap_nearby_vertices(
	mesh: MeshData,
	entrance_pos: Vector3,
	snap_radius: float,
	tunnel_ring: Array[Vector3]
) -> void:
	var snap_radius_sq := snap_radius * snap_radius
	var min_snap_dist := 999.0
	var max_snap_dist := 0.0
	var total_snap_dist := 0.0
	
	# Examine each vertex in terrain mesh
	for i in range(mesh.vertices.size()):
		var vertex := mesh.vertices[i]
		var dist_sq := vertex.distance_squared_to(entrance_pos)
		
		_vertices_examined += 1
		
		# Only consider vertices within snap radius
		if dist_sq > snap_radius_sq:
			continue
		
		# Find closest tunnel ring vertex
		var closest_tunnel_vertex := _find_closest_vertex(vertex, tunnel_ring)
		var snap_distance := vertex.distance_to(closest_tunnel_vertex)
		
		# Only snap if distance is reasonable
		if snap_distance < MIN_SNAP_DISTANCE or snap_distance > MAX_SNAP_DISTANCE:
			continue
		
		# Log detailed information about this snap
		if _vertices_snapped < 5:  # Log first 5 in detail
			print("    Vertex %d: (%.2f, %.2f, %.2f) → (%.2f, %.2f, %.2f) [distance: %.3fm]" % [
				i,
				vertex.x, vertex.y, vertex.z,
				closest_tunnel_vertex.x, closest_tunnel_vertex.y, closest_tunnel_vertex.z,
				snap_distance
			])
		
		# Track statistics
		min_snap_dist = min(min_snap_dist, snap_distance)
		max_snap_dist = max(max_snap_dist, snap_distance)
		total_snap_dist += snap_distance
		
		# Snap vertex to tunnel ring position
		mesh.vertices[i] = closest_tunnel_vertex
		_vertices_snapped += 1
	
	# Log summary statistics
	if _vertices_snapped > 0:
		var avg_snap_dist := total_snap_dist / _vertices_snapped
		print("    Snap stats: min=%.3fm, max=%.3fm, avg=%.3fm" % [min_snap_dist, max_snap_dist, avg_snap_dist])
		if _vertices_snapped > 5:
			print("    (Showing first 5 of %d snapped vertices)" % _vertices_snapped)

## Find the closest vertex in an array to a given position
func _find_closest_vertex(position: Vector3, vertices: Array[Vector3]) -> Vector3:
	if vertices.is_empty():
		return position
	
	var closest := vertices[0]
	var closest_dist_sq := position.distance_squared_to(closest)
	
	for i in range(1, vertices.size()):
		var dist_sq := position.distance_squared_to(vertices[i])
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = vertices[i]
	
	return closest

## Get tunnel entrance ring vertices from shape
func _get_tunnel_entrance_ring(tunnel_shape: TunnelShape) -> Array[Vector3]:
	var ring: Array[Vector3] = []
	if tunnel_shape is CylindricalTunnelShape:
		var cyl := tunnel_shape as CylindricalTunnelShape
		var origin := cyl.origin
		var direction := cyl.direction
		var radius := cyl.radius
		var radial_segments := cyl.radial_segments
		var forward := direction.normalized()
		var up := Vector3.UP
		if abs(forward.dot(up)) > 0.99:
			up = Vector3.RIGHT
		var right := forward.cross(up).normalized()
		up = right.cross(forward).normalized()
		for i in range(radial_segments):
			var angle := (float(i) / radial_segments) * TAU
			var offset := right * cos(angle) * radius + up * sin(angle) * radius
			ring.append(origin + offset)
	else:
		push_warning("SimpleVertexSnapper: Unknown tunnel shape type")
	
	return ring

## Get tunnel radius from shape
func _get_tunnel_radius(tunnel_shape: TunnelShape) -> float:
	if tunnel_shape is CylindricalTunnelShape:
		return (tunnel_shape as CylindricalTunnelShape).radius
	return 3.0

## Get statistics about last snapping operation
func get_statistics() -> Dictionary:
	return {
		"vertices_examined": _vertices_examined,
		"vertices_snapped": _vertices_snapped,
		"snap_ratio": float(_vertices_snapped) / max(1, _vertices_examined)
	}

## Reset statistics
func reset_statistics() -> void:
	_vertices_snapped = 0
	_vertices_examined = 0

