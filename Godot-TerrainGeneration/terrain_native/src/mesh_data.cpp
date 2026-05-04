#include "mesh_data.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

/** @file mesh_data.cpp
 *  @brief Implements MeshData.
 */

namespace godot {

void MeshData::_bind_methods() {
  ClassDB::bind_method(D_METHOD("get_vertices"), &MeshData::get_vertices);
  ClassDB::bind_method(D_METHOD("set_vertices", "v"), &MeshData::set_vertices);
  ClassDB::bind_method(D_METHOD("get_indices"), &MeshData::get_indices);
  ClassDB::bind_method(D_METHOD("set_indices", "i"), &MeshData::set_indices);
  ClassDB::bind_method(D_METHOD("get_uvs"), &MeshData::get_uvs);
  ClassDB::bind_method(D_METHOD("set_uvs", "u"), &MeshData::set_uvs);
  ClassDB::bind_method(D_METHOD("get_cached_normals"), &MeshData::get_cached_normals);
  ClassDB::bind_method(D_METHOD("set_cached_normals", "n"), &MeshData::set_cached_normals);
  ClassDB::bind_method(D_METHOD("get_cached_tangents"), &MeshData::get_cached_tangents);
  ClassDB::bind_method(D_METHOD("set_cached_tangents", "t"), &MeshData::set_cached_tangents);
  ClassDB::bind_method(D_METHOD("get_width"), &MeshData::get_width);
  ClassDB::bind_method(D_METHOD("set_width", "w"), &MeshData::set_width);
  ClassDB::bind_method(D_METHOD("get_height_val"), &MeshData::get_height_val);
  ClassDB::bind_method(D_METHOD("set_height_val", "h"), &MeshData::set_height_val);
  ClassDB::bind_method(D_METHOD("get_mesh_size"), &MeshData::get_mesh_size);
  ClassDB::bind_method(D_METHOD("set_mesh_size", "s"), &MeshData::set_mesh_size);
  ClassDB::bind_method(D_METHOD("get_elapsed_time_ms"), &MeshData::get_elapsed_time_ms);
  ClassDB::bind_method(D_METHOD("set_elapsed_time_ms", "t"), &MeshData::set_elapsed_time_ms);
  ClassDB::bind_method(D_METHOD("get_processor_type"), &MeshData::get_processor_type);
  ClassDB::bind_method(D_METHOD("set_processor_type", "s"), &MeshData::set_processor_type);
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "vertices"), "set_vertices", "get_vertices");
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "indices"), "set_indices", "get_indices");
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR2_ARRAY, "uvs"), "set_uvs", "get_uvs");
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR3_ARRAY, "cached_normals"), "set_cached_normals", "get_cached_normals");
  ADD_PROPERTY(PropertyInfo(Variant::PACKED_VECTOR4_ARRAY, "cached_tangents"), "set_cached_tangents", "get_cached_tangents");
  ADD_PROPERTY(PropertyInfo(Variant::INT, "width"), "set_width", "get_width");
  ADD_PROPERTY(PropertyInfo(Variant::INT, "height"), "set_height_val", "get_height_val");
  ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "mesh_size"), "set_mesh_size", "get_mesh_size");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "elapsed_time_ms"), "set_elapsed_time_ms", "get_elapsed_time_ms");
  ADD_PROPERTY(PropertyInfo(Variant::STRING, "processor_type"), "set_processor_type", "get_processor_type");
  ClassDB::bind_method(D_METHOD("initialize", "vertices", "indices", "uvs"), &MeshData::initialize);
  ClassDB::bind_static_method(get_class_static(), D_METHOD("create", "vertices", "indices", "uvs"), &MeshData::create);
  ClassDB::bind_method(D_METHOD("get_vertex_count"), &MeshData::get_vertex_count);
  ClassDB::bind_method(D_METHOD("get_triangle_count"), &MeshData::get_triangle_count);
  ClassDB::bind_method(D_METHOD("is_valid_index", "i"), &MeshData::is_valid_index);
  ClassDB::bind_method(D_METHOD("get_vertex", "index"), &MeshData::get_vertex);
  ClassDB::bind_method(D_METHOD("get_height", "index"), &MeshData::get_height);
}

void MeshData::initialize(const PackedVector3Array &p_vertices,
                          const PackedInt32Array &p_indices,
                          const PackedVector2Array &p_uvs) {
  if (p_vertices.size() != p_uvs.size()) {
    UtilityFunctions::push_warning(
        String("MeshData: Vertex count ({0}) does not match UV count ({1})")
            .format(Array::make(p_vertices.size(), p_uvs.size())));
  }
  vertices = p_vertices;
  indices = p_indices;
  uvs = p_uvs;
}

Vector3 MeshData::get_vertex(int index) const {
  if (!is_valid_index(index)) {
    UtilityFunctions::push_warning(String("MeshData: Invalid vertex index {0}").format(Array::make(index)));
    return Vector3(0, 0, 0);
  }
  return vertices[index];
}

float MeshData::get_height(int index) const {
  if (!is_valid_index(index)) {
    return 0.0f;
  }
  return vertices[index].y;
}

Ref<MeshData> MeshData::create(const PackedVector3Array &p_vertices,
                               const PackedInt32Array &p_indices,
                               const PackedVector2Array &p_uvs) {
  Ref<MeshData> mesh;
  mesh.instantiate();
  mesh->initialize(p_vertices, p_indices, p_uvs);
  return mesh;
}

} // namespace godot
