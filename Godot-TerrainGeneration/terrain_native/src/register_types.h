#pragma once

#include <godot_cpp/core/class_db.hpp>

/** @file register_types.h
 *  @brief Declares GDExtension module initialization/termination entry points.
 */

/** @brief Registers classes provided by this GDExtension.
 *
 *  Called by Godot during engine startup.
 *
 *  @param p_level Current initialization level.
 */
void initialize_terrain_native(godot::ModuleInitializationLevel p_level);

/** @brief Unregisters / tears down anything created in initialize_terrain_native().
 *
 *  Called by Godot during engine shutdown.
 *
 *  @param p_level Current initialization level.
 */
void uninitialize_terrain_native(godot::ModuleInitializationLevel p_level);
