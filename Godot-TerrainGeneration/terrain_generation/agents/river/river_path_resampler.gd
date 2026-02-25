## @brief Resamples a polyline path to equidistant points.
##
## @details Follows SRP — only responsible for path resampling math.
## Used by RiverMeshBuilder to ensure uniform vertex density along the ribbon.
class_name RiverPathResampler extends RefCounted

## Resample a polyline so consecutive points are approximately `spacing` apart.
## @param path          Original polyline (ordered Array[Vector2]).
## @param spacing       Desired distance between consecutive output points.
## @return              New polyline with equidistant points. First and last
##                      points of the original path are always preserved.
static func resample(path: Array[Vector2], spacing: float) -> Array[Vector2]:
	if path.size() < 2 or spacing <= 0.0:
		return path.duplicate()
	var result: Array[Vector2] = []
	result.append(path[0])
	var leftover := 0.0
	var prev := path[0]
	for i in range(1, path.size()):
		var curr := path[i]
		var seg_remaining := prev.distance_to(curr)
		var direction := (curr - prev).normalized()
		var walked := 0.0
		var distance_to_next := spacing - leftover
		while distance_to_next <= seg_remaining - walked:
			walked += distance_to_next
			var point := prev + direction * walked
			result.append(point)
			leftover = 0.0
			distance_to_next = spacing
		leftover += seg_remaining - walked
		prev = curr
	if result[result.size() - 1].distance_to(path[path.size() - 1]) > spacing * 0.1:
		result.append(path[path.size() - 1])
	return result

