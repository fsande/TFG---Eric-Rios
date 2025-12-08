## This script defines a resource for configuring parameters used in terrain mesh generation.
@tool
class_name MeshGeneratorParameters extends Resource

## The scale factor applied to heightmap values to determine vertex heights.
@export var height_scale: float = 64.0

## The size of the generated mesh in world units (X and Z dimensions).
@export var mesh_size: Vector2 = Vector2(256.0, 256.0)

## The number of subdivisions (grid resolution) of the generated mesh.
@export var subdivisions: int = 32
