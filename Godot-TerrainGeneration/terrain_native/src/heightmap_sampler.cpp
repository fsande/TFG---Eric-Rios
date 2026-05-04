#include "heightmap_sampler.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

/** @file heightmap_sampler.cpp
 *  @brief Implements HeightmapSamplerNative.
 */

namespace godot {

void HeightmapSamplerNative::_bind_methods() {
  ClassDB::bind_method(D_METHOD("bake_heightmap", "heightmap"), &HeightmapSamplerNative::bake_heightmap);
  ClassDB::bind_method(
      D_METHOD("generate_height_grid", "chunk_bounds", "resolution", "terrain_size", "height_scale"),
      &HeightmapSamplerNative::generate_height_grid);
  ClassDB::bind_method(D_METHOD("is_baked"), &HeightmapSamplerNative::is_baked);
}

void HeightmapSamplerNative::bake_heightmap(const Ref<Image> &heightmap) {
  if (heightmap.is_null()) {
    UtilityFunctions::push_error("HeightmapSamplerNative: null heightmap passed to bake_heightmap");
    return;
  }
  _width = heightmap->get_width();
  _height = heightmap->get_height();
  _data.resize(_width * _height);
  float *dst = _data.ptrw();
  for (int y = 0; y < _height; ++y) {
    for (int x = 0; x < _width; ++x) {
      dst[y * _width + x] = heightmap->get_pixel(x, y).r;
    }
  }
}

inline float HeightmapSamplerNative::_sample(float u, float v) const {
  u = u < 0.0f ? 0.0f : (u > 1.0f ? 1.0f : u);
  v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
  float px = u * float(_width - 1);
  float pz = v * float(_height - 1);
  int x0 = int(px);
  int z0 = int(pz);
  int x1 = x0 + 1 < _width ? x0 + 1 : x0;
  int z1 = z0 + 1 < _height ? z0 + 1 : z0;
  float fx = px - float(x0);
  float fz = pz - float(z0);
  const float *src = _data.ptr();
  float h00 = src[z0 * _width + x0];
  float h10 = src[z0 * _width + x1];
  float h01 = src[z1 * _width + x0];
  float h11 = src[z1 * _width + x1];
  float h0 = h00 + fx * (h10 - h00);
  float h1 = h01 + fx * (h11 - h01);
  return h0 + fz * (h1 - h0);
}

PackedFloat32Array HeightmapSamplerNative::generate_height_grid(AABB chunk_bounds,
                                                                int resolution,
                                                                float terrain_size,
                                                                float height_scale) const {
  PackedFloat32Array result;
  if (_width == 0 || _height == 0) {
    UtilityFunctions::push_error("HeightmapSamplerNative: not baked — call bake_heightmap first");
    return result;
  }
  result.resize(resolution * resolution);
  float *dst = result.ptrw();
  const float half_size = terrain_size * 0.5f;
  const float inv_res_1 = resolution > 1 ? 1.0f / float(resolution - 1) : 0.0f;
  const float bx = chunk_bounds.position.x;
  const float bz = chunk_bounds.position.z;
  const float sx = chunk_bounds.size.x;
  const float sz = chunk_bounds.size.z;
  const float inv_terrain = 1.0f / terrain_size;
  for (int z = 0; z < resolution; ++z) {
    const float v_local = resolution > 1 ? float(z) * inv_res_1 : 0.5f;
    const float world_z = bz + v_local * sz;
    const float map_v = (world_z + half_size) * inv_terrain;
    for (int x = 0; x < resolution; ++x) {
      const float u_local = resolution > 1 ? float(x) * inv_res_1 : 0.5f;
      const float world_x = bx + u_local * sx;
      const float map_u = (world_x + half_size) * inv_terrain;
      dst[z * resolution + x] = _sample(map_u, map_v) * height_scale;
    }
  }
  return result;
}

} // namespace godot
