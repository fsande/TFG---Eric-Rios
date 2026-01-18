## This script defines a resource for configuring parameters used in terrain mesh generation.
@tool
class_name MeshGeneratorParameters extends Resource

## The scale factor applied to heightmap values to determine vertex heights.
@export var height_scale: float = 64.0:
	set(value):
		if value < 0.0:
			push_error("MeshGeneratorParameters: height_scale cannot be negative, got %f" % value)
			height_scale = 64.0
		else:
			height_scale = value

## The size of the generated mesh in world units (X and Z dimensions).
@export var mesh_size: Vector2 = Vector2(256.0, 256.0):
	set(value):
		if value.x <= 0.0 or value.y <= 0.0:
			push_error("MeshGeneratorParameters: mesh_size components must be positive, got %v" % value)
			mesh_size = Vector2(256.0, 256.0)
		else:
			mesh_size = value

## The number of subdivisions (grid resolution) of the generated mesh.
@export var subdivisions: int = 32:
	set(value):
		if value < 1:
			push_error("MeshGeneratorParameters: subdivisions must be at least 1, got %d" % value)
			subdivisions = 32
		else:
			subdivisions = value
			