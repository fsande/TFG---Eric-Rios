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

## Minimum distance from coast to mountain (pairs closer than this are rejected)
@export_range(10.0, 500.0, 10.0) var min_coast_to_mountain_distance: float = 50.0

## Maximum distance from coast to mountain (pairs farther than this are rejected).
## Set to 0 to disable the check.
@export_range(0.0, 2000.0, 10.0) var max_coast_to_mountain_distance: float = 0.0

## Minimum river length to be valid
@export_range(20.0, 1000.0, 10.0) var min_river_length: float = 100.0

@export_group("Path Following")

## Step size when following gradient
@export_range(0.5, 10.0, 0.5) var step_size: float = 2.0

## Maximum path steps before giving up
@export_range(100, 5000, 100) var max_path_steps: int = 2000

## Gradient weight near the coast (start of uphill walk).
## Low values let the target direction dominate on flat terrain.
@export_range(0.0, 1.0, 0.05) var gradient_weight_start: float = 0.3

## Gradient weight near the mountain (end of uphill walk).
## High values let the terrain guide the path up ridges.
@export_range(0.0, 1.0, 0.05) var gradient_weight_end: float = 0.7

## Number of steps to backoff from cliff edge
@export_range(1, 50) var backoff_distance: int = 5

## Number of consecutive downhill steps allowed before terminating the path.
## Higher values tolerate small dips across ridges / saddle points.
@export_range(1, 30) var max_consecutive_downhill_steps: int = 5

## Height tolerance (world units) below which a step is not counted as downhill.
## Prevents noise-level height differences from triggering the downhill detector.
@export_range(0.0, 5.0, 0.1) var downhill_tolerance: float = 0.1

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

## Number of extra vertices across the river width for the ribbon mesh
## 0 = only left+right edges, 1 = left+centre+right, etc.
@export_range(0, 8) var ribbon_cross_subdivisions: int = 2

## Resample the river path to this spacing (world units) for uniform mesh density.
## 0 = use the raw (smoothed) path points as-is.
@export_range(0.0, 10.0, 0.5) var ribbon_resample_spacing: float = 2.0

## Optional per-river material override. When null the presenter uses
## the global river material from TerrainConfigurationV2.
@export var water_material: Material = null

@export_group("Attempts")

## Maximum attempts to generate valid river (top-N scored pairs to try)
@export_range(1, 100) var max_attempts: int = 20

## Random seed offset for placement (0 = use context seed)
@export var placement_seed: int = 0
