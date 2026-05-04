#ifndef HEIGHTMAP_SAMPLER_H
#define HEIGHTMAP_SAMPLER_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

/** @file heightmap_sampler.h
 *  @brief Native (C++) heightmap sampler used by terrain generation.
 */

namespace godot {

/** @class HeightmapSamplerNative
 *  @brief Native implementation of heightmap grid sampling.
 *
 *  Drop-in replacement for the GDScript height grid hot loop.
 *
 *  Thread-safety:
 *  - Call bake_heightmap() once (typically on the main thread) to copy data out
 *    of a Godot Image.
 *  - After baking, generate_height_grid() is read-only and can be called from
 *    worker threads.
 */
class HeightmapSamplerNative : public RefCounted {
  GDCLASS(HeightmapSamplerNative, RefCounted)

public:
  HeightmapSamplerNative() = default;
  ~HeightmapSamplerNative() = default;

  /** @brief Pre-bakes a heightmap Image into a flat float array owned by this object.
   *
   *  Reads the red channel (".r") of every pixel in @p heightmap and stores it
   *  as a row-major array of floats in the range [0, 1].
   *
   *  @warning Image pixel access is not safe to do concurrently. Call this once
   *  before starting multi-threaded sampling.
   *
   *  @param heightmap Source image to bake. If null, an error is pushed and the
   *  sampler remains unbaked.
   */
  void bake_heightmap(const Ref<Image> &heightmap);

  /** @brief Generates a height grid for a chunk by sampling the baked heightmap.
   *
   *  The resulting array is a regular grid in XZ over @p chunk_bounds. Values
   *  are bilinearly interpolated from the baked heightmap and scaled by
   *  @p height_scale.
   *
   *  @param chunk_bounds World-space AABB of the chunk (XZ extents are used).
   *  @param resolution Number of samples along X and Z. Returned array size is
   *  `resolution * resolution`.
   *  @param terrain_size Total terrain width in world units. Used to map world
   *  positions into normalized heightmap UVs.
   *  @param height_scale Multiplier applied to raw [0,1] height values.
   *
   *  @return PackedFloat32Array containing sampled heights. If the sampler is
   *  not baked, an empty array is returned and an error is pushed.
   */
  PackedFloat32Array generate_height_grid(AABB chunk_bounds,
                                         int resolution,
                                         float terrain_size,
                                         float height_scale) const;

  /** @brief Returns whether a heightmap has been baked into this sampler. */
  bool is_baked() const { return _width > 0; }

protected:
  /** @brief Binds methods for exposure to Godot scripting APIs. */
  static void _bind_methods();

private:
  /// Row-major baked height values in [0, 1]. Index = z * width + x.
  PackedFloat32Array _data;
  int _width = 0;
  int _height = 0;

  /** @brief Samples the baked heightmap using clamped bilinear filtering.
   *
   *  @param u Normalized X coordinate in [0,1] (clamped internally).
   *  @param v Normalized Z coordinate in [0,1] (clamped internally).
   *  @return Height in [0,1] from the baked data.
   */
  inline float _sample(float u, float v) const;
};

} // namespace godot

#endif // HEIGHTMAP_SAMPLER_H
