@tool
## Modifies vertices of a mesh in real-time using the grid. Debugging purposes.
## Works like terrain presenter, but stores a reference to the mesh_modifier_context and allows real-time updates.
class_name DebugGridModifier extends TerrainPresenter

## Reference to the last mesh modifier context used.
var mesh_modifier_context: MeshModifierContext = null

@export_group("Debug")
@export var height_offset: float = 10.0
@export var wait_between_modifications: float = 0.1
@export_tool_button("DebugModify") var debug_modify_action := debug_modify

func regenerate() -> void:
  if not configuration:
    push_warning("DebugGridModifier: No configuration assigned")
    return
  if not configuration.is_valid():
    push_error("DebugGridModifier: Invalid configuration")
    return
  _generation_service.set_mesh_modifier_type(configuration.mesh_modifier_type)
  _current_terrain_data = _generation_service.generate(configuration)
  if not _current_terrain_data:
    push_error("DebugGridModifier: Failed to generate terrain")
    return
  _update_presentation()
  _is_dirty = false
  mesh_modifier_context = _generation_service.last_mesh_modifier_context

func debug_modify() -> void:
  if not mesh_modifier_context:
    push_warning("DebugGridModifier: No mesh modifier context available. Regenerate terrain first.")
    return
  # Modify each vertex in the grid one by one, moving it up by height_offset. Refresh each time to see changes.
  var size := configuration.terrain_size
  for y in range(size + 1):
    for x in range(size + 1):
      var index := y * (size + 1) + x
      var vertex := mesh_modifier_context.get_mesh_data().get_vertex(index)
      vertex.y += height_offset
      mesh_modifier_context.get_mesh_data().set_vertex(index, vertex)
      mesh_modifier_context.refresh_mesh_instance()
      await get_tree().create_timer(wait_between_modifications).timeout
