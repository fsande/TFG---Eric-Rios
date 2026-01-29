## @brief Tracks LOD state for a loaded chunk.
##
## @details Maintains runtime LOD information including current/target LOD levels,
## transition state, and distance tracking for hysteresis calculations.
class_name ChunkLODState

## Reference to the chunk's mesh instance in the scene
var mesh_instance: MeshInstance3D

## Current LOD level being displayed
var current_lod: int

## Target LOD level (may differ during transitions)
var target_lod: int

## Whether the chunk is currently transitioning between LOD levels
var is_transitioning: bool

## Distance from camera at last update (used for hysteresis)
var last_update_distance: float

