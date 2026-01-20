## @brief Utility class to detect and clean up orphaned nodes (nodes not in the scene tree).
##
## @details Orphaned nodes are Node instances that exist in memory but are not part
## of any scene tree. They can cause memory leaks if not properly freed.
## This class provides tools to find and clean them up.
##
## Usage:
##   var orphans = OrphanNodeDetector.find_orphans_in(some_node)
##   OrphanNodeDetector.cleanup_orphans(orphans)
class_name OrphanNodeDetector extends RefCounted

## Find all orphaned child nodes (recursively) within a given node hierarchy.
## Returns an array of nodes that are NOT in the scene tree.
static func find_orphans_in(root: Node) -> Array[Node]:
	var orphans: Array[Node] = []
	if not root:
		return orphans
	if not root.is_inside_tree():
		orphans.append(root)
	_find_orphans_recursive(root, orphans)
	return orphans

## Internal recursive helper to find orphaned nodes.
static func _find_orphans_recursive(node: Node, orphans: Array[Node]) -> void:
	for child in node.get_children():
		if not child.is_inside_tree():
			orphans.append(child)
		_find_orphans_recursive(child, orphans)

## Free all orphaned nodes in the provided array.
## Returns the number of nodes freed.
static func cleanup_orphans(orphans: Array[Node]) -> int:
	var count := 0
	for orphan in orphans:
		if orphan and not orphan.is_inside_tree():
			orphan.queue_free()
			count += 1
	return count

## Find and cleanup orphans in one step.
## Returns the number of orphaned nodes that were freed.
static func cleanup_orphans_in(root: Node) -> int:
	var orphans := find_orphans_in(root)
	return cleanup_orphans(orphans)

## Check if a node is orphaned (not in scene tree).
static func is_orphaned(node: Node) -> bool:
	return node != null and not node.is_inside_tree()

## Generate a diagnostic report of orphaned nodes.
## Useful for debugging memory leaks.
static func generate_report(orphans: Array[Node]) -> String:
	if orphans.is_empty():
		return "No orphaned nodes found."
	var report := "Found %d orphaned nodes:\n" % orphans.size()
	for i in range(orphans.size()):
		var orphan := orphans[i]
		var node_name: String = orphan.name if orphan.name != "" else "<unnamed>"
		report += "  [%d] %s (type: %s, children: %d)\n" % [
			i + 1,
			node_name,
			orphan.get_class(),
			orphan.get_child_count()
		]
	return report

## Count total memory footprint (approximate) of orphaned nodes.
## Returns total child count as a rough metric.
static func count_orphan_descendants(orphans: Array[Node]) -> int:
	var total := 0
	for orphan in orphans:
		total += 1  # The orphan itself
		total += _count_descendants(orphan)
	return total

## Internal helper to count all descendants.
static func _count_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1
		count += _count_descendants(child)
	return count

## Scan for common orphan patterns and return warnings.
## Helps identify potential memory leak sources.
static func scan_for_leak_patterns(orphans: Array[Node]) -> Array[String]:
	var warnings: Array[String] = []
	for orphan in orphans:
		var child_count := orphan.get_child_count()
		if child_count > 10:
			warnings.append("Large orphaned container: '%s' has %d children" % [orphan.name, child_count])
	var mesh_instances := 0
	var node3d_containers := 0
	for orphan in orphans:
		if orphan is MeshInstance3D:
			mesh_instances += 1
		elif orphan is Node3D and orphan.get_child_count() > 0:
			node3d_containers += 1
	if mesh_instances > 5:
		warnings.append("%d orphaned MeshInstance3D nodes detected" % mesh_instances)
	if node3d_containers > 3:
		warnings.append("%d orphaned Node3D containers detected" % node3d_containers)
	return warnings

