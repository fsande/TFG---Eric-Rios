#ifndef CPU_CHUNK_GENERATOR_H
#define CPU_CHUNK_GENERATOR_H

#include "heightmap_sampler.h"
#include "mesh_data.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>

/** @file cpu_chunk_generator.h
 *  @brief Declares CpuChunkGeneratorNative, a full CPU chunk meshing pipeline.
 */

namespace godot {

/** @class CpuChunkGeneratorNative
 *  @brief Full CPU chunk generation pipeline in native C++.
 *
 *  Replaces CpuChunkGenerationStrategy's hot path entirely.
 *
 *  Thread-safety:
 *  - Call bake_heightmap() once to bake the Image into a private float buffer.
 *  - After baking, generate_chunk*() methods are read-only and can be called
 *    concurrently from worker threads.
 *
 *  GDScript usage:
 *  @code{.gdscript}
 *  var gen := CpuChunkGeneratorNative.new()
 *  gen.bake_heightmap(image)
 *  var mesh_data := gen.generate_chunk(chunk_bounds, resolution, terrain_size, height_scale)
 *  @endcode
 */
class CpuChunkGeneratorNative : public RefCounted {
  GDCLASS(CpuChunkGeneratorNative, RefCounted)

public:
  CpuChunkGeneratorNative() = default;
  ~CpuChunkGeneratorNative() = default;

  /** @brief Bake heightmap image into a private float array.
   *
   *  Reads the red channel (".r") of the input Image and stores it as a
   *  row-major array of floats in [0,1].
   *
   *  @warning Call once on the main thread before any generate_* calls.
   *
   *  @param heightmap Heightmap image to bake.
   */
  void bake_heightmap(const Ref<Image> &heightmap);

  /** @brief Returns whether a heightmap has been baked. */
  bool is_baked() const { return _heightmap_width > 0; }

  /** @brief Generate a complete MeshData for one chunk.
   *
   *  Runs height grid sampling, mesh build, normals, and tangents entirely in C++.
   *
   *  @param chunk_bounds World-space AABB of the chunk.
   *  @param resolution Grid resolution (e.g. 64 for LOD0).
   *  @param terrain_size Total terrain width in world units.
   *  @param height_scale Multiplier on raw [0,1] height values.
   *
   *  @return A MeshData Ref containing vertices/indices/uvs and cached normals/tangents.
   */
  Ref<MeshData> generate_chunk(AABB chunk_bounds, int resolution, float terrain_size, float height_scale) const;

  /** @brief Generate only the height grid for a chunk.
   *
   *  Exposed so scripts can apply delta maps before calling generate_chunk_from_grid().
   */
  PackedFloat32Array generate_height_grid(AABB chunk_bounds,
                                         int resolution,
                                         float terrain_size,
                                         float height_scale) const;

  /** @brief Build mesh + normals + tangents from a pre-built height grid.
   *
   *  Use this when GDScript has already applied delta maps to the grid.
   */
  Ref<MeshData> generate_chunk_from_grid(const PackedFloat32Array &height_grid,
                                        AABB chunk_bounds,
                                        int resolution) const;

protected:
  static void _bind_methods();

private:
  // Baked heightmap data - read-only after bake_heightmap().
  PackedFloat32Array _heightmap_data;
  int _heightmap_width = 0;
  int _heightmap_height = 0;

  inline float _sample_heightmap(float u, float v) const;

  void _build_height_grid(float *dst,
                          int resolution,
                          float bx,
                          float bz,
                          float sx,
                          float sz,
                          float half_terrain,
                          float inv_terrain,
                          float height_scale) const;

  Ref<MeshData> _build_mesh(const float *height_grid, int resolution, AABB chunk_bounds) const;

  static void _calculate_normals(PackedVector3Array &out_normals,
                                 const PackedVector3Array &vertices,
                                 const PackedInt32Array &indices);

  static void _calculate_tangents(PackedVector4Array &out_tangents,
                                  const PackedVector3Array &vertices,
                                  const PackedInt32Array &indices,
                                  const PackedVector2Array &uvs,
                                  const PackedVector3Array &normals);
};

} // namespace godot
#endif // CPU_CHUNK_GENERATOR_H