## @brief Configuration for RiverAgent.
##
## @details Contains all parameters for river generation including
## path generation, carving, and water placement settings.
@tool
class_name RiverAgentConfig extends Resource

@export_group("Path Generation")

## River width in world units
@export_range(1.0, 50.0, 0.5) var river_width: float = 5.0

## Minimum height for river origin (mountain base)
@export_range(0.0, 200.0, 5.0) var min_origin_height: float = 40.0

## Maximum altitude before stopping path generation
@export_range(50.0, 500.0, 10.0) var max_altitude: float = 100.0

## Maximum slope angle before stopping (degrees)
@export_range(30.0, 80.0, 5.0) var max_slope_degrees: float = 60.0

## Minimum distance from coast to mountain
@export_range(10.0, 500.0, 10.0) var min_coast_to_mountain_distance: float = 50.0

## Minimum river length to be valid
@export_range(20.0, 1000.0, 10.0) var min_river_length: float = 100.0

@export_group("Path Following")

## Step size when following gradient
@export_range(0.5, 10.0, 0.5) var step_size: float = 2.0

## Maximum path steps before giving up
@export_range(100, 5000, 100) var max_path_steps: int = 2000

## Weight for gradient following (0-1, higher = more gradient influence)
@export_range(0.0, 1.0, 0.05) var gradient_weight_start: float = 0.7

## Weight for gradient at end of path (typically lower)
@export_range(0.0, 1.0, 0.05) var gradient_weight_end: float = 0.3

## Number of steps to backoff from cliff edge
@export_range(1, 50) var backoff_distance: int = 5

@export_group("Path Smoothing")

## Enable path smoothing
@export var smooth_path: bool = true

## Number of smoothing iterations
@export_range(1, 5) var smoothing_iterations: int = 2

@export_group("Riverbed Carving")

## Resolution of height delta texture
@export_range(64, 1024, 64) var delta_resolution: int = 256

## Depth of river carving at origin
@export_range(0.5, 20.0, 0.5) var initial_depth: float = 2.0

## Depth increase per step downstream
@export_range(0.0, 0.5, 0.01) var depth_increase_rate: float = 0.05

## Maximum river depth
@export_range(5.0, 50.0, 1.0) var max_depth: float = 15.0

## Width increase multiplier downstream
@export_range(1.0, 3.0, 0.1) var width_multiplier_downstream: float = 1.5

## Falloff distance for riverbed edges
@export_range(1.0, 20.0, 0.5) var edge_falloff_distance: float = 5.0

@export_group("Water Placement")

## Place water in river
@export var place_water: bool = true

## Water surface offset above riverbed (for flow appearance)
@export_range(0.0, 2.0, 0.1) var water_surface_offset: float = 0.5

@export_group("Attempts")

## Maximum attempts to generate valid river
@export_range(1, 100) var max_attempts: int = 5

## Random seed offset for placement (0 = use context seed)
@export var placement_seed: int = 0

@export_group("Validation")

## Validator for checking if coast-mountain pairs are valid
## Can be swapped between heuristic (fast) and flood-fill (accurate)
@export var pair_validator: RiverPairValidator = null

## Enable pair validation (disable for testing/debugging)
@export var enable_pair_validation: bool = true
