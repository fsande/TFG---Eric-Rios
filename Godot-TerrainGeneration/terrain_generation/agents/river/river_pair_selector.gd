## @brief Selects coast-mountain pairs ranked by river feasibility.
##
## @details Replaces blind random pairing with a scored, proximity-aware
## selection strategy. For each candidate pair, computes a feasibility score
## based on distance, uphill direction alignment, height difference, and
## a straight-line land ratio. Pairs are returned sorted best-first so the
## river agent tries the most promising ones first.
class_name RiverPairSelector extends RefCounted

## A scored coast-mountain pair.
class ScoredPair:
	var coast_point: Vector2
	var mountain_point: Vector2
	var score: float

	func _init(p_coast: Vector2, p_mountain: Vector2, p_score: float) -> void:
		coast_point = p_coast
		mountain_point = p_mountain
		score = p_score

## Select and rank pairs from the given candidate pools.
##
## @param coast_points      Array of coastline world positions.
## @param mountain_points   Array of mountain world positions.
## @param context           Terrain generation context for height/gradient queries.
## @param min_distance      Minimum allowed pair distance (world units).
## @param max_distance      Maximum allowed pair distance (0 = unlimited).
## @param max_pairs         Maximum number of pairs to return.
## @return Array of ScoredPair sorted by descending score.
static func select_pairs(
	coast_points: Array[Vector2],
	mountain_points: Array[Vector2],
	context: TerrainGenerationContext,
	min_distance: float,
	max_distance: float,
	max_pairs: int = 20
) -> Array[ScoredPair]:
	var pairs: Array[ScoredPair] = []
	for coast in coast_points:
		for mountain in mountain_points:
			var dist := coast.distance_to(mountain)
			if dist < min_distance:
				continue
			if max_distance > 0.0 and dist > max_distance:
				continue
			var score := _score_pair(coast, mountain, dist, context)
			if score > 0.0:
				pairs.append(ScoredPair.new(coast, mountain, score))
	pairs.sort_custom(func(a: ScoredPair, b: ScoredPair) -> bool: return a.score > b.score)
	if pairs.size() > max_pairs:
		pairs.resize(max_pairs)
	return pairs

## Score a single coast-mountain pair.
##
## Components (all in 0-1, weighted and summed):
##   1. Distance score — prefer medium distances, penalise extremes.
##   2. Uphill alignment — the uphill gradient at the coast should point
##      roughly toward the mountain (dot product).
##   3. Height difference — prefer meaningful elevation gain.
##   4. Land ratio — fraction of straight-line samples that are above sea level
##      (cheap same-landmass proxy).
static func _score_pair(
	coast: Vector2,
	mountain: Vector2,
	dist: float,
	context: TerrainGenerationContext
) -> float:
	const DIST_WEIGHT := 0.20
	const ALIGNMENT_WEIGHT := 0.30
	const HEIGHT_WEIGHT := 0.20
	const LAND_WEIGHT := 0.30
	var terrain_diagonal := context.terrain_size.length()
	var normalised_dist := dist / terrain_diagonal 
	var dist_score: float
	if normalised_dist < 0.05:
		dist_score = 0.0
	elif normalised_dist < 0.10:
		dist_score = (normalised_dist - 0.05) / 0.05 
	elif normalised_dist < 0.40:
		dist_score = 1.0 
	elif normalised_dist < 0.60:
		dist_score = 1.0 - (normalised_dist - 0.40) / 0.20 
	else:
		dist_score = 0.0  
	var to_mountain := (mountain - coast).normalized()
	var uphill := context.calculate_uphill_direction(coast)
	var alignment_score: float
	if uphill.length_squared() < 0.0001:
		alignment_score = 0.5
	else:
		alignment_score = clampf(uphill.dot(to_mountain) * 0.5 + 0.5, 0.0, 1.0)
	var coast_height := context.get_scaled_height_at(coast)
	var mountain_height := context.get_scaled_height_at(mountain)
	var height_diff := mountain_height - coast_height
	var height_score: float
	if height_diff <= 0.0:
		height_score = 0.0
	else:
		height_score = clampf(height_diff / (context.height_scale * 0.5), 0.0, 1.0)
	if height_score <= 0.0:
		return 0.0
	var land_score := _compute_land_ratio(coast, mountain, context)
	var score := (
		dist_score * DIST_WEIGHT
		+ alignment_score * ALIGNMENT_WEIGHT
		+ height_score * HEIGHT_WEIGHT
		+ land_score * LAND_WEIGHT
	)
	return score

## Compute the fraction of straight-line samples above sea level,
## skipping the first 15% (coast is always near water).
static func _compute_land_ratio(
	coast: Vector2,
	mountain: Vector2,
	context: TerrainGenerationContext
) -> float:
	if not context.reference_heightmap or not context.terrain_definition:
		return 1.0 
	var sea_level_norm := context.terrain_definition.sea_level / context.height_scale
	var land_threshold := sea_level_norm + 0.5 / context.height_scale
	const SAMPLE_COUNT := 15
	const SKIP_RATIO := 0.15
	var land_count := 0
	var tested := 0
	for i in range(SAMPLE_COUNT):
		var t := float(i) / float(SAMPLE_COUNT - 1)
		if t < SKIP_RATIO:
			continue
		var sample_pos := coast.lerp(mountain, t)
		var height_norm := context.sample_height_at(sample_pos)
		tested += 1
		if height_norm >= land_threshold:
			land_count += 1
	if tested == 0:
		return 1.0
	return float(land_count) / float(tested)
