#include "cpu_chunk_generator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>
#include <cstring>

/** @file cpu_chunk_generator.cpp
 *  @brief Implements CpuChunkGeneratorNative.
 */

namespace godot {

void CpuChunkGeneratorNative::_bind_methods() {
  ClassDB::bind_method(D_METHOD("bake_heightmap", "heightmap"), &CpuChunkGeneratorNative::bake_heightmap);
  ClassDB::bind_method(D_METHOD("is_baked"), &CpuChunkGeneratorNative::is_baked);
  ClassDB::bind_method(D_METHOD("generate_chunk", "chunk_bounds", "resolution", "terrain_size", "height_scale"),
                       &CpuChunkGeneratorNative::generate_chunk);
  ClassDB::bind_method(D_METHOD("generate_height_grid", "chunk_bounds", "resolution", "terrain_size", "height_scale"),
                       &CpuChunkGeneratorNative::generate_height_grid);
  ClassDB::bind_method(D_METHOD("generate_chunk_from_grid", "height_grid", "chunk_bounds", "resolution"),
                       &CpuChunkGeneratorNative::generate_chunk_from_grid);
  ClassDB::bind_method(
      D_METHOD("generate_height_grid_with_deltas", "chunk_bounds", "resolution", "terrain_size", "height_scale", "deltas"),
      &CpuChunkGeneratorNative::generate_height_grid_with_deltas);
}

void CpuChunkGeneratorNative::bake_heightmap(const Ref<Image> &heightmap) {
  if (heightmap.is_null()) {
    UtilityFunctions::push_error("CpuChunkGeneratorNative: null heightmap");
    return;
  }
  _heightmap_width = heightmap->get_width();
  _heightmap_height = heightmap->get_height();
  _heightmap_data.resize(_heightmap_width * _heightmap_height);
  float *dst = _heightmap_data.ptrw();
  for (int y = 0; y < _heightmap_height; ++y) {
    for (int x = 0; x < _heightmap_width; ++x) {
      dst[y * _heightmap_width + x] = heightmap->get_pixel(x, y).r;
    }
  }
}

inline float CpuChunkGeneratorNative::_sample_heightmap(float u, float v) const {
  u = u < 0.0f ? 0.0f : (u > 1.0f ? 1.0f : u);
  v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
  float px = u * float(_heightmap_width - 1);
  float pz = v * float(_heightmap_height - 1);
  int x0 = int(px);
  int z0 = int(pz);
  int x1 = x0 + 1 < _heightmap_width ? x0 + 1 : x0;
  int z1 = z0 + 1 < _heightmap_height ? z0 + 1 : z0;
  float fx = px - float(x0);
  float fz = pz - float(z0);
  const float *src = _heightmap_data.ptr();
  float h00 = src[z0 * _heightmap_width + x0];
  float h10 = src[z0 * _heightmap_width + x1];
  float h01 = src[z1 * _heightmap_width + x0];
  float h11 = src[z1 * _heightmap_width + x1];
  float hx0 = h00 + fx * (h10 - h00);
  float hx1 = h01 + fx * (h11 - h01);
  return hx0 + fz * (hx1 - hx0);
}

void CpuChunkGeneratorNative::_build_height_grid(float *dst,
                                                int resolution,
                                                float bx,
                                                float bz,
                                                float sx,
                                                float sz,
                                                float half_terrain,
                                                float inv_terrain,
                                                float height_scale) const {
  const float inv_res = resolution > 1 ? 1.0f / float(resolution - 1) : 0.0f;
  for (int z = 0; z < resolution; ++z) {
    const float v_local = resolution > 1 ? float(z) * inv_res : 0.5f;
    const float world_z = bz + v_local * sz;
    const float map_v = (world_z + half_terrain) * inv_terrain;
    for (int x = 0; x < resolution; ++x) {
      const float u_local = resolution > 1 ? float(x) * inv_res : 0.5f;
      const float world_x = bx + u_local * sx;
      const float map_u = (world_x + half_terrain) * inv_terrain;
      dst[z * resolution + x] = _sample_heightmap(map_u, map_v) * height_scale;
    }
  }
}

PackedFloat32Array CpuChunkGeneratorNative::generate_height_grid(AABB chunk_bounds,
                                                                 int resolution,
                                                                 float terrain_size,
                                                                 float height_scale) const {
  PackedFloat32Array result;
  if (_heightmap_width == 0) {
    UtilityFunctions::push_error("CpuChunkGeneratorNative: not baked");
    return result;
  }
  result.resize(resolution * resolution);
  _build_height_grid(result.ptrw(),
                     resolution,
                     chunk_bounds.position.x,
                     chunk_bounds.position.z,
                     chunk_bounds.size.x,
                     chunk_bounds.size.z,
                     terrain_size * 0.5f,
                     1.0f / terrain_size,
                     height_scale);
  return result;
}

// ---------------------------------------------------------------------------
// Mesh build from height grid
// ---------------------------------------------------------------------------

Ref<MeshData> CpuChunkGeneratorNative::_build_mesh(const float *height_grid, int resolution, AABB chunk_bounds) const {
  const int vert_count = resolution * resolution;
  const int quad_count = (resolution - 1) * (resolution - 1);
  PackedVector3Array vertices;
  PackedVector2Array uvs;
  PackedInt32Array indices;
  vertices.resize(vert_count);
  uvs.resize(vert_count);
  indices.resize(quad_count * 6);
  Vector3 *vptr = vertices.ptrw();
  Vector2 *uptr = uvs.ptrw();
  int *iptr = indices.ptrw();
  const float inv_res = resolution > 1 ? 1.0f / float(resolution - 1) : 0.0f;
  const float hsx = chunk_bounds.size.x;
  const float hsz = chunk_bounds.size.z;
  for (int z = 0; z < resolution; ++z) {
    const float v = resolution > 1 ? float(z) * inv_res : 0.5f;
    for (int x = 0; x < resolution; ++x) {
      const float u = resolution > 1 ? float(x) * inv_res : 0.5f;
      const int idx = z * resolution + x;
      const float height = height_grid[idx];
      vptr[idx] = Vector3((u - 0.5f) * hsx, height, (v - 0.5f) * hsz);
      uptr[idx] = Vector2(u, v);
    }
  }
  int i = 0;
  for (int z = 0; z < resolution - 1; ++z) {
    for (int x = 0; x < resolution - 1; ++x) {
      int v0 = z * resolution + x;
      int v1 = v0 + 1;
      int v2 = v0 + resolution;
      int v3 = v2 + 1;
      iptr[i++] = v0;
      iptr[i++] = v1;
      iptr[i++] = v2;
      iptr[i++] = v1;
      iptr[i++] = v3;
      iptr[i++] = v2;
    }
  }
  Ref<MeshData> mesh;
  mesh.instantiate();
  mesh->initialize(vertices, indices, uvs);
  mesh->width = resolution;
  mesh->height = resolution;
  mesh->mesh_size = Vector2(hsx, hsz);
  return mesh;
}

void CpuChunkGeneratorNative::_calculate_normals(PackedVector3Array &out_normals,
                                                const PackedVector3Array &vertices,
                                                const PackedInt32Array &indices) {
  const int vert_count = vertices.size();
  out_normals.resize(vert_count);
  Vector3 *nptr = out_normals.ptrw();
  for (int i = 0; i < vert_count; ++i) {
    nptr[i] = Vector3(0, 0, 0);
  }
  const Vector3 *vptr = vertices.ptr();
  const int *iptr = indices.ptr();
  const int tri_count = indices.size() / 3;
  for (int t = 0; t < tri_count; ++t) {
    int i0 = iptr[t * 3];
    int i1 = iptr[t * 3 + 1];
    int i2 = iptr[t * 3 + 2];
    Vector3 v0 = vptr[i0];
    Vector3 v1 = vptr[i1];
    Vector3 v2 = vptr[i2];
    Vector3 face_normal = (v2 - v0).cross(v1 - v0).normalized();
    nptr[i0] += face_normal;
    nptr[i1] += face_normal;
    nptr[i2] += face_normal;
  }
  for (int i = 0; i < vert_count; ++i) {
    nptr[i] = nptr[i].normalized();
  }
}

void CpuChunkGeneratorNative::_calculate_tangents(PackedVector4Array &out_tangents,
                                                 const PackedVector3Array &vertices,
                                                 const PackedInt32Array &indices,
                                                 const PackedVector2Array &uvs,
                                                 const PackedVector3Array &normals) {
  const int vert_count = vertices.size();
  out_tangents.resize(vert_count);
  std::vector<Vector3> tan1(vert_count, Vector3(0, 0, 0));
  std::vector<Vector3> tan2(vert_count, Vector3(0, 0, 0));
  const Vector3 *vptr = vertices.ptr();
  const int *iptr = indices.ptr();
  const Vector2 *uptr = uvs.ptr();
  const int tri_count = indices.size() / 3;
  for (int t = 0; t < tri_count; ++t) {
    int i0 = iptr[t * 3];
    int i1 = iptr[t * 3 + 1];
    int i2 = iptr[t * 3 + 2];
    Vector3 v0 = vptr[i0];
    Vector3 v1 = vptr[i1];
    Vector3 v2 = vptr[i2];
    Vector2 u0 = uptr[i0];
    Vector2 u1 = uptr[i1];
    Vector2 u2 = uptr[i2];
    Vector3 edge1 = v1 - v0;
    Vector3 edge2 = v2 - v0;
    Vector2 duv1 = u1 - u0;
    Vector2 duv2 = u2 - u0;
    float denom = duv1.x * duv2.y - duv2.x * duv1.y;
    float f = denom != 0.0f ? 1.0f / denom : 1.0f;
    Vector3 tangent(f * (duv2.y * edge1.x - duv1.y * edge2.x),
                    f * (duv2.y * edge1.y - duv1.y * edge2.y),
                    f * (duv2.y * edge1.z - duv1.y * edge2.z));
    tangent = tangent.normalized();
    Vector3 bitangent(f * (-duv2.x * edge1.x + duv1.x * edge2.x),
                      f * (-duv2.x * edge1.y + duv1.x * edge2.y),
                      f * (-duv2.x * edge1.z + duv1.x * edge2.z));
    bitangent = bitangent.normalized();
    tan1[i0] += tangent;
    tan1[i1] += tangent;
    tan1[i2] += tangent;
    tan2[i0] += bitangent;
    tan2[i1] += bitangent;
    tan2[i2] += bitangent;
  }
  const Vector3 *nptr = normals.ptr();
  Vector4 *tgptr = out_tangents.ptrw();
  for (int i = 0; i < vert_count; ++i) {
    Vector3 n = nptr[i];
    Vector3 t = tan1[i];
    t = (t - n * n.dot(t)).normalized();
    float handedness = n.cross(t).dot(tan2[i]) > 0.0f ? 1.0f : -1.0f;
    tgptr[i] = Vector4(t.x, t.y, t.z, handedness);
  }
}


Ref<MeshData> CpuChunkGeneratorNative::generate_chunk(AABB chunk_bounds,
                                                     int resolution,
                                                     float terrain_size,
                                                     float height_scale) const {
  if (_heightmap_width == 0) {
    UtilityFunctions::push_error("CpuChunkGeneratorNative: not baked");
    return Ref<MeshData>();
  }
  std::vector<float> grid(resolution * resolution);
  _build_height_grid(grid.data(),
                     resolution,
                     chunk_bounds.position.x,
                     chunk_bounds.position.z,
                     chunk_bounds.size.x,
                     chunk_bounds.size.z,
                     terrain_size * 0.5f,
                     1.0f / terrain_size,
                     height_scale);
  Ref<MeshData> mesh = _build_mesh(grid.data(), resolution, chunk_bounds);
  _calculate_normals(mesh->cached_normals, mesh->vertices, mesh->indices);
  _calculate_tangents(mesh->cached_tangents, mesh->vertices, mesh->indices, mesh->uvs, mesh->cached_normals);
  mesh->processor_type = "cpu_native";
  return mesh;
}

Ref<MeshData> CpuChunkGeneratorNative::generate_chunk_from_grid(const PackedFloat32Array &height_grid,
                                                                AABB chunk_bounds,
                                                                int resolution) const {
  Ref<MeshData> mesh = _build_mesh(height_grid.ptr(), resolution, chunk_bounds);
  _calculate_normals(mesh->cached_normals, mesh->vertices, mesh->indices);
  _calculate_tangents(mesh->cached_tangents, mesh->vertices, mesh->indices, mesh->uvs, mesh->cached_normals);
  mesh->processor_type = "cpu_native";
  return mesh;
}

static float _sample_delta(const DeltaInfo &delta, float world_x, float world_z) {
  float u = (world_x - delta.bounds_x) / delta.bounds_size_x;
  float v = (world_z - delta.bounds_z) / delta.bounds_size_z;
  u = u < 0.0f ? 0.0f : (u > 1.0f ? 1.0f : u);
  v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
 
  float px = u * float(delta.resolution - 1);
  float pz = v * float(delta.resolution - 1);
  int x0 = int(px);
  int z0 = int(pz);
  int x1 = x0 + 1 < delta.resolution ? x0 + 1 : x0;
  int z1 = z0 + 1 < delta.resolution ? z0 + 1 : z0;
  float fx = px - float(x0);
  float fz = pz - float(z0);
 
  int res = delta.resolution;
  float h00 = delta.pixels[z0 * res + x0];
  float h10 = delta.pixels[z0 * res + x1];
  float h01 = delta.pixels[z1 * res + x0];
  float h11 = delta.pixels[z1 * res + x1];
 
  float hx0 = h00 + fx * (h10 - h00);
  float hx1 = h01 + fx * (h11 - h01);
  return hx0 + fz * (hx1 - hx0);
}
 
static float _apply_blend(float base_height, float delta_value, BlendMode blend_mode, float intensity) {
  float scaled = delta_value * intensity;
  switch (blend_mode) {
    case BlendMode::kAdditive: return base_height + scaled;
    case BlendMode::kMultiplicative: return base_height * scaled;
    case BlendMode::kMax: return base_height > scaled ? base_height : scaled;
    case BlendMode::kMin: return base_height < scaled ? base_height : scaled;
    case BlendMode::kReplace: return scaled;
    default: return base_height + scaled;
  }
}
 
void CpuChunkGeneratorNative::_apply_deltas(float *grid,
                                            int resolution,
                                            float bx,
                                            float bz,
                                            float sx,
                                            float sz,
                                            const std::vector<DeltaInfo> &deltas) {
  const float inv_res = resolution > 1 ? 1.0f / float(resolution - 1) : 0.0f;
  for (int z = 0; z < resolution; ++z) {
    const float v_local = resolution > 1 ? float(z) * inv_res : 0.5f;
    const float world_z = bz + v_local * sz;
    for (int x = 0; x < resolution; ++x) {
      const float u_local = resolution > 1 ? float(x) * inv_res : 0.5f;
      const float world_x = bx + u_local * sx;
      float height = grid[z * resolution + x];
      for (const DeltaInfo &delta : deltas) {
        float delta_value = _sample_delta(delta, world_x, world_z);
        if (delta_value < -0.0001f || delta_value > 0.0001f)
          height = _apply_blend(height, delta_value, delta.blend_mode, delta.intensity);
      }
      grid[z * resolution + x] = height;
    }
  }
}
 
static std::vector<DeltaInfo> _unpack_delta_dicts(const TypedArray<Dictionary> &delta_dicts,
                                                  std::vector<std::vector<float>> &pixel_storage) {
  std::vector<DeltaInfo> deltas;
  deltas.reserve(delta_dicts.size());
  pixel_storage.reserve(delta_dicts.size());
 
  for (int i = 0; i < delta_dicts.size(); ++i) {
    Dictionary d = delta_dicts[i];
    Ref<Image> img = d.get("image", Variant());
    if (img.is_null()) continue;
 
    AABB bounds = d.get("bounds", AABB());
    float intensity = float(d.get("intensity", 1.0f));
    BlendMode blend_mode = static_cast<BlendMode>(int(d.get("blend_mode", 0)));
 
    int res = img->get_width();
    PackedByteArray raw = img->get_data();
    const float *src = reinterpret_cast<const float *>(raw.ptr());
    pixel_storage.emplace_back(src, src + res * res);
 
    DeltaInfo info;
    info.pixels = pixel_storage.back().data();
    info.resolution = res;
    info.bounds_x = bounds.position.x;
    info.bounds_z = bounds.position.z;
    info.bounds_size_x = bounds.size.x;
    info.bounds_size_z = bounds.size.z;
    info.intensity = intensity;
    info.blend_mode = blend_mode;
    deltas.push_back(info);
  }
  return deltas;
}
 
PackedFloat32Array CpuChunkGeneratorNative::generate_height_grid_with_deltas(
    AABB chunk_bounds,
    int resolution,
    float terrain_size,
    float height_scale,
    const TypedArray<Dictionary> &delta_dicts) const {
  PackedFloat32Array result = generate_height_grid(chunk_bounds, resolution, terrain_size, height_scale);
  if (result.is_empty() || delta_dicts.is_empty())
    return result;
  std::vector<std::vector<float>> pixel_storage;
  std::vector<DeltaInfo> deltas = _unpack_delta_dicts(delta_dicts, pixel_storage);
  _apply_deltas(result.ptrw(), resolution,
                chunk_bounds.position.x, chunk_bounds.position.z,
                chunk_bounds.size.x, chunk_bounds.size.z,
                deltas);
  return result;
}

} // namespace godot
