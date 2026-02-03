@tool
class_name NodeCreationHelper extends RefCounted

static func get_or_create_node(parent: Node, node_name: String, node_type: Variant = Node) -> Node:
	if parent == null:
		push_error("NodeCreationHelper.get_or_create_node: parent is null")
		return null
	var node := parent.get_node_or_null(node_name)
	if node != null:
		if Engine.is_editor_hint():
			_ensure_owner(node)
		return node
	node = node_type.new()
	node.name = node_name
	parent.add_child(node)
	if Engine.is_editor_hint():
		_ensure_owner(node)
	return node

static func _ensure_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		var owner_node = node.get_owner()
		if owner_node == null and node.is_inside_tree():
			var tree = node.get_tree()
			if tree and tree.edited_scene_root:
				node.owner = tree.edited_scene_root

static func remove_all_children(node: Node) -> void:
	if node == null:
		push_error("NodeCreationHelper.remove_all_children: node is null")
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

## Recursively set owner for node and all descendants (needed for editor visibility)
## @param node The node to set ownership for
## @param owner_node The owner to assign (typically scene root)
static func set_node_owner_recursive(node: Node, owner_node: Node) -> void:
	if not node or not owner_node:
		return
	node.owner = owner_node
	for child in node.get_children():
		set_node_owner_recursive(child, owner_node)