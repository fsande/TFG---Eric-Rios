#ifndef MESH_DATA_H
#define MESH_DATA_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector4_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

/** @file mesh_data.h
 *  @brief Declares MeshData, a native mirror of the project’s GDScript MeshData.
 */

namespace godot {

/** @class MeshData
 *  @brief Native mirror of GDScript MeshData.
 *
 *  Field names and types match the script version so existing code can keep
 *  using `.vertices`, `.indices`, `.uvs`, etc.
 */
class MeshData : public RefCounted {
  GDCLASS(MeshData, RefCounted)

public:
  PackedVector3Array vertices;
  PackedInt32Array indices;
  PackedVector2Array uvs;

  PackedVector3Array cached_normals;
  PackedVector4Array cached_tangents;

  int width = 0;
  int height = 0;
  Vector2 mesh_size = Vector2(0, 0);

  double elapsed_time_ms = 0.0;
  String processor_type = "";

  MeshData() = default;
  ~MeshData() = default;

  /** @brief Initializes the mesh data (legacy/script-friendly initializer).
   *
   *  This remains for GDScript compatibility.
   */
  void initialize(const PackedVector3Array &p_vertices,
                  const PackedInt32Array &p_indices,
                  const PackedVector2Array &p_uvs);

  /** @brief Returns number of vertices. */
  int get_vertex_count() const { return vertices.size(); }

  /** @brief Returns number of triangles (indices/3). */
  int get_triangle_count() const { return indices.size() / 3; }

  /** @brief Returns true if @p i is a valid vertex index. */
  bool is_valid_index(int i) const { return i >= 0 && i < vertices.size(); }

  /** @brief Returns the vertex at @p index (or (0,0,0) if out of range). */
  Vector3 get_vertex(int index) const;

  /** @brief Returns the Y component of the vertex at @p index. */
  float get_height(int index) const;

  PackedVector3Array get_vertices() const { return vertices; }
  void set_vertices(const PackedVector3Array &v) { vertices = v; }
  PackedInt32Array get_indices() const { return indices; }
  void set_indices(const PackedInt32Array &i) { indices = i; }
  PackedVector2Array get_uvs() const { return uvs; }
  void set_uvs(const PackedVector2Array &u) { uvs = u; }
  PackedVector3Array get_cached_normals() const { return cached_normals; }
  void set_cached_normals(const PackedVector3Array &n) { cached_normals = n; }
  PackedVector4Array get_cached_tangents() const { return cached_tangents; }
  void set_cached_tangents(const PackedVector4Array &t) { cached_tangents = t; }
  int get_width() const { return width; }
  void set_width(int w) { width = w; }
  int get_height_val() const { return height; }
  void set_height_val(int h) { height = h; }
  Vector2 get_mesh_size() const { return mesh_size; }
  void set_mesh_size(Vector2 s) { mesh_size = s; }
  double get_elapsed_time_ms() const { return elapsed_time_ms; }
  void set_elapsed_time_ms(double t) { elapsed_time_ms = t; }
  String get_processor_type() const { return processor_type; }
  void set_processor_type(const String &s) { processor_type = s; }

  /** @brief Factory that creates and initializes a MeshData instance.
   *
   *  Exposed to GDScript as `MeshData.create(vertices, indices, uvs)`.
   */
  static Ref<MeshData> create(const PackedVector3Array &p_vertices,
                              const PackedInt32Array &p_indices,
                              const PackedVector2Array &p_uvs);

protected:
  static void _bind_methods();
};

} // namespace godot
#endif // MESH_DATA_H