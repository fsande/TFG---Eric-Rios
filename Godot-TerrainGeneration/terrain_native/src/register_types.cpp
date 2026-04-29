#include "register_types.h"

#include "cpu_chunk_generator.h"
#include "heightmap_sampler.h"
#include "mesh_data.h"

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

/** @file register_types.cpp
 *  @brief Implements registration and entry points for the terrain_native GDExtension.
 */

void initialize_terrain_native(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
  godot::ClassDB::register_class<godot::MeshData>();
  godot::ClassDB::register_class<godot::HeightmapSamplerNative>();
  godot::ClassDB::register_class<godot::CpuChunkGeneratorNative>();
}

void uninitialize_terrain_native(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
}

extern "C" {

/** @brief Entry point that Godot calls when loading this GDExtension.
 *
 *  Wires up initializer/terminator callbacks and sets the minimum initialization
 *  level.
 */
GDExtensionBool GDE_EXPORT terrain_native_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                              const GDExtensionClassLibraryPtr p_library,
                                              GDExtensionInitialization *r_initialization) {
  godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
  init_obj.register_initializer(initialize_terrain_native);
  init_obj.register_terminator(uninitialize_terrain_native);
  init_obj.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
  return init_obj.init();
}

} // extern "C"
