## @brief Base class for CSG volumes (shapes that can be used in boolean operations).
##
## @details Defines the interface for CSG volumes. Subclasses implement specific shapes
## (cylinders, spheres, boxes, etc.) by providing signed distance and surface queries.
@tool
class_name CSGVolume extends RefCounted

## Classification of a point relative to the volume
enum Classification {
	INSIDE,      ## Point is inside the volume (signed_distance < -epsilon)
	OUTSIDE,     ## Point is outside the volume (signed_distance > epsilon)
	ON_SURFACE   ## Point is on the surface (abs(signed_distance) <= epsilon)
}

## Epsilon for surface distance testing
const SURFACE_EPSILON := 0.01

## Iterations to refine intersection tests
const INTERSECTION_ITERATIONS := 20

## Returns signed distance from point to surface.
## Negative = inside, Positive = outside, Zero = on surface
func signed_distance(point: Vector3) -> float:
	push_error("CSGVolume.signed_distance() must be overridden")
	return 0.0

## Classify a point relative to this volume
func classify_point(point: Vector3) -> Classification:
	var dist := signed_distance(point)
	if abs(dist) <= SURFACE_EPSILON:
		return Classification.ON_SURFACE
	return Classification.INSIDE if dist < 0.0 else Classification.OUTSIDE

## Get a debug mesh representation of this volume for visualization.
## Returns an array [mesh: Mesh, transform: Transform3D]
func get_debug_mesh() -> Array:
	push_error("CSGVolume.get_debug_mesh() must be overridden")
	return [null, Transform3D.IDENTITY]

## Check if a line segment intersects the volume surface.
## Returns the intersection parameter t (0-1) or -1 if no intersection.
func intersect_segment(p0: Vector3, p1: Vector3) -> float:
	var d0 := signed_distance(p0)
	var d1 := signed_distance(p1)
	if (d0 < 0.0 and d1 < 0.0) or (d0 > 0.0 and d1 > 0.0):
		return -1.0
	var t0 := 0.0
	var t1 := 1.0
	var t := 0.5
	for _i in range(INTERSECTION_ITERATIONS):
		t = (t0 + t1) * 0.5
		var p := p0.lerp(p1, t)
		var d := signed_distance(p)
		if abs(d) < SURFACE_EPSILON:
			return t
		if d < 0.0:
			if d0 < 0.0:
				t0 = t
			else:
				t1 = t
		else:
			if d0 > 0.0:
				t0 = t
			else:
				t1 = t
	return t
