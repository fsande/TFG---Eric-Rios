## @brief Configuration resource for OverhangAgent.
##
## @details Controls how candidate cliff positions are found and how
## overhang geometry is sized and randomised. Designed to work with any
## terrain that has steep slopes, not just MountainAgentV2 output.
@tool
class_name OverhangAgentConfig extends Resource

## -----------------------------------------------------------------------
## Search
## -----------------------------------------------------------------------

## How to find candidate positions for overhangs.
## ZONE_TAG — restrict search to delta maps tagged with `zone_tag`.
## Fast and precise; requires a prior agent to tag its deltas.
## FULL_TERRAIN — sample the whole terrain. Slower but works on any input,
## including pre-existing heightmaps.
enum SearchMode { ZONE_TAG, FULL_TERRAIN }

@export var search_mode: SearchMode = SearchMode.ZONE_TAG

## Zone tag to search within when search_mode is ZONE_TAG.
## Must match the tag set by the upstream height agent (e.g. &"mountain").
@export var zone_tag: StringName = &"mountain"

## Number of candidate sample points to evaluate across the search area.
## Higher values find more overhangs but cost more generation time.
@export_range(64, 4096, 64) var search_grid_resolution: int = 512

## Minimum slope in degrees for a position to be considered a cliff face.
@export_range(0.0, 89.0, 0.5) var min_slope_degrees: float = 40.0

## -----------------------------------------------------------------------
## Placement
## -----------------------------------------------------------------------

## Seed for all randomisation within this agent (0 = use generation seed).
@export var placement_seed: int = 0

## Probability [0, 1] that a candidate position that passes the slope test
## is actually turned into an overhang. Lower values produce sparser results.
@export_range(0.0, 1.0, 0.01) var overhang_probability: float = 0.3

## Maximum number of overhangs this agent will create per generate() call.
## Prevents runaway generation on large, very steep terrains.
@export_range(1, 256, 1) var max_overhangs: int = 32

## -----------------------------------------------------------------------
## Geometry
## -----------------------------------------------------------------------

## How far the overhang extends past its attachment point (world units).
@export_range(1.0, 50.0, 0.5) var extent_min: float = 3.0
@export_range(1.0, 50.0, 0.5) var extent_max: float = 8.0

## Width of the overhang slab perpendicular to its extension direction.
@export_range(1.0, 100.0, 0.5) var width_min: float = 5.0
@export_range(1.0, 100.0, 0.5) var width_max: float = 15.0

## Thickness of the overhang slab.
@export_range(0.5, 20.0, 0.25) var thickness_min: float = 1.5
@export_range(0.5, 20.0, 0.25) var thickness_max: float = 3.5

## How far the back of the slab is buried into the cliff to hide the seam.
@export_range(0.0, 10.0, 0.25) var cliff_embed_depth: float = 3.0

## Noise displacement applied to visible (non-embedded) vertices.
@export_range(0.0, 2.0, 0.05) var noise_strength: float = 0.25

## -----------------------------------------------------------------------
## LOD
## -----------------------------------------------------------------------

## Minimum LOD level at which overhangs are rendered (0 = always).
@export_range(0, 8) var lod_min: int = 0

## Maximum LOD level at which overhangs are rendered (-1 = always).
@export_range(-1, 8) var lod_max: int = 2
