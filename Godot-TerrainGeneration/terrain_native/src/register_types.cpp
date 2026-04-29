#include "register_types.h"
#include "heightmap_sampler.h"
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

/**
 * @file register_types.cpp
 * @brief Implements registration and entry points for the terrain_native GDExtension.
 */

void initialize_terrain_native(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
  // Expose native classes to GDScript/C#.
  godot::ClassDB::register_class<godot::HeightmapSamplerNative>();
}

void uninitialize_terrain_native(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
}

extern "C" {

/**
 * @brief Main entry point that Godot calls when loading this GDExtension.
 *
 * This function wires up the initializer/terminator callbacks and sets the
 * minimum initialization level at which the extension should be loaded.
 *
 * @param p_get_proc_address Function pointer resolver provided by Godot.
 * @param p_library      Library handle provided by Godot.
 * @param r_initialization   In/out initialization data provided by Godot.
 *
 * @return True on success.
 */
GDExtensionBool GDE_EXPORT terrain_native_init(
  GDExtensionInterfaceGetProcAddress p_get_proc_address,
  const GDExtensionClassLibraryPtr p_library,
  GDExtensionInitialization *r_initialization)
{
  godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
  init_obj.register_initializer(initialize_terrain_native);
  init_obj.register_terminator(uninitialize_terrain_native);
  init_obj.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
  return init_obj.init();
}
}
