# Tunnel Boring Agent - Implementation Approaches

## Current Implementation Analysis

### Problems with Current Approach
1. **Crude triangle removal** - Uses centroid-only testing, missing edge cases
2. **Separate geometry addition** - Tunnel cylinder is added as independent mesh, not integrated
3. **Poor vertex displacement** - Simple radial push doesn't create clean boundaries
4. **No proper stitching** - Entrance portal uses basic triangle fan, leaves gaps
5. **Not extensible** - Hard to adapt for non-cylindrical shapes (ellipses, arbitrary volumes)
6. **Above-ground artifacts** - No terrain height awareness for visibility culling

### What We Actually Need
A **boolean subtraction operation** that:
- Removes volume from terrain mesh (like CSG subtract)
- Stitches cut edges to volume boundary cleanly
- Only renders geometry below terrain surface
- Supports arbitrary convex/concave volumes
- Creates watertight results

---

## Approach 1: **True CSG Boolean Operations** ⭐ RECOMMENDED

### Overview
Implement proper Constructive Solid Geometry (CSG) boolean subtraction using computational geometry algorithms.

### Algorithm Steps

#### 1. **Vertex Classification**
For each terrain vertex, classify as:
- `INSIDE` - within the tunnel volume
- `OUTSIDE` - outside the tunnel volume  
- `ON_SURFACE` - within epsilon distance of volume surface

```gdscript
enum VertexClassification { INSIDE, OUTSIDE, ON_SURFACE }

func classify_vertex(vertex: Vector3, volume: CSGVolume) -> VertexClassification:
    var distance = volume.signed_distance(vertex)
    if abs(distance) < EPSILON:
        return ON_SURFACE
    return INSIDE if distance < 0 else OUTSIDE
```

#### 2. **Triangle Classification**
For each terrain triangle, classify as:
- `FULLY_OUTSIDE` - all vertices outside (keep unchanged)
- `FULLY_INSIDE` - all vertices inside (remove completely)
- `INTERSECTING` - mixed vertices (requires clipping)

#### 3. **Edge-Surface Intersection**
For intersecting triangles, find where edges cross the volume surface:

```gdscript
func intersect_edge_with_volume(v0: Vector3, v1: Vector3, volume: CSGVolume) -> Variant:
    # Binary search or analytical solution
    var t = find_intersection_parameter(v0, v1, volume)
    if t >= 0.0 and t <= 1.0:
        return v0.lerp(v1, t)
    return null
```

#### 4. **Triangle Clipping & Subdivision**
For each intersecting triangle:
- Compute edge-surface intersection points
- Create new vertices at intersection points
- Subdivide into smaller triangles
- Keep triangles with centroids outside volume
- Remove triangles with centroids inside volume

#### 5. **Boundary Mesh Generation**
- Collect all intersection vertices and edges
- Project onto volume surface to ensure perfect alignment
- Triangulate the boundary curve (2D problem in local coordinates)
- Add interior volume geometry (tunnel walls) only where needed

#### 6. **Terrain-Aware Culling**
```gdscript
func should_render_tunnel_geometry(position: Vector3, context: MeshModifierContext) -> bool:
    var terrain_height = context.get_height_at_xz(position.x, position.z)
    return position.y < terrain_height  # Only render underground parts
```

### Advantages
✅ **Mathematically correct** - Produces watertight, manifold meshes  
✅ **Artifact-free** - No gaps, overlaps, or z-fighting  
✅ **General purpose** - Works for any convex/concave volume  
✅ **Extensible** - Easy to support complex shapes  
✅ **Clean boundaries** - Perfect stitching at intersection curves

### Disadvantages
❌ **Complex implementation** - Requires robust computational geometry  
❌ **Edge cases** - Degenerate triangles, numerical precision issues  
❌ **Performance** - More expensive than simple heuristics (but still fast)

### Implementation Strategy
1. Create `CSGVolume` base class with `signed_distance()` method
2. Implement `CylinderVolume`, `SphereVolume`, `BoxVolume` subclasses
3. Create `CSGBoolean` utility class with subtraction operation
4. Refactor `TunnelBoringAgent` to use CSG system
5. Add `CompoundVolume` for complex shapes (union of primitives)

### Extensibility for Complex Shapes
```gdscript
# Future shapes are trivial to add:
class_name EllipsoidVolume extends CSGVolume
class_name TorusVolume extends CSGVolume
class_name MeshVolume extends CSGVolume  # Use any arbitrary mesh as volume!

# Compound shapes:
var cave_volume = CompoundVolume.new()
cave_volume.add_sphere(Vector3(0, 0, 0), 5.0)
cave_volume.add_cylinder(Vector3(0, 0, 0), Vector3(1, 0, 0), 3.0, 10.0)
cave_volume.set_operation(CSGOperation.UNION)
```

---

## Approach 2: **Voxel-Based Boolean Operations**

### Overview
Convert terrain mesh to voxel grid, perform boolean ops in voxel space, then remesh using marching cubes.

### Algorithm Steps
1. **Voxelize terrain mesh** - Convert triangles to occupancy grid
2. **Voxelize tunnel volume** - Rasterize volume to same grid
3. **Boolean subtraction** - `terrain_voxels AND NOT tunnel_voxels`
4. **Surface extraction** - Marching cubes to generate new mesh
5. **Mesh simplification** - Reduce triangle count (optional)

### Advantages
✅ **Simple to implement** - Boolean ops are trivial on voxels  
✅ **Robust** - No edge cases or numerical issues  
✅ **Any shape support** - Volumes can be arbitrary  
✅ **Multi-material** - Easy to track material IDs per voxel

### Disadvantages
❌ **Resolution dependent** - Quality vs memory/performance tradeoff  
❌ **Loss of precision** - Original mesh detail lost in voxelization  
❌ **Expensive** - Voxelization + marching cubes can be slow  
❌ **Different topology** - Output mesh structure completely changes  
❌ **UV mapping issues** - Hard to preserve original UVs

### When to Use
- When terrain is already voxel-based
- When absolute robustness is critical
- When mesh topology doesn't matter
- For very complex boolean operations

---

## Approach 3: **Hybrid Vertex Snapping + Smart Triangle Removal**

### Overview
Enhanced version of current approach with better heuristics.

### Algorithm Steps
1. **Classify all vertices** - Distance to cylinder surface
2. **Snap boundary vertices** - Project vertices within threshold onto surface
3. **Smart triangle removal** - Check all 3 vertices, not just centroid
4. **Boundary edge detection** - Find edges with one inside/one outside vertex
5. **Cap generation** - Triangulate boundary polygon at entrance
6. **Interior mesh** - Add tunnel geometry only below terrain

### Advantages
✅ **Easier to implement** - Evolutionary improvement of current code  
✅ **Fast** - Simple geometric tests  
✅ **Preserves mesh structure** - Original topology mostly intact

### Disadvantages
❌ **Not watertight** - Gaps possible at boundaries  
❌ **Resolution dependent** - Needs fine mesh for good results  
❌ **Limited to simple shapes** - Hard to extend beyond cylinders/spheres  
❌ **Artifacts** - Jagged boundaries, T-junctions possible

### When to Use
- As a stepping stone toward full CSG
- When performance is absolutely critical
- For prototyping/testing
- When mesh is already very high resolution

---

## Approach 4: **GPU Compute Shader CSG**

### Overview
Implement CSG operations using compute shaders on GPU for massive parallelism.

### Algorithm Steps
1. **Upload mesh to GPU** - Vertices, indices, triangles
2. **Parallel classification** - Classify all triangles simultaneously
3. **Parallel intersection** - Compute edge intersections in parallel
4. **Atomic append** - Build output index buffer atomically
5. **Download results** - Read back modified mesh

### Advantages
✅ **Extreme performance** - 10-100x faster for large meshes  
✅ **Scalable** - Handles millions of triangles  
✅ **Modern** - Leverages GPU compute capabilities

### Disadvantages
❌ **Complex** - Requires GLSL/compute shader expertise  
❌ **Platform dependent** - GPU capability requirements  
❌ **Harder to debug** - GPU debugging is challenging  
❌ **Fixed pipeline** - Less flexible than CPU code

### When to Use
- For very large terrain meshes (>100k triangles)
- When real-time performance needed
- On platforms with guaranteed compute shader support
- After CPU prototype is working

---

## Approach 5: **Signed Distance Field (SDF) Based**

### Overview
Represent terrain and tunnel as SDFs, combine them, then extract mesh.

### Algorithm Steps
1. **Generate terrain SDF** - Sample signed distance on 3D grid
2. **Generate tunnel SDF** - Analytical or sampled SDF
3. **SDF subtraction** - `max(terrain_sdf, -tunnel_sdf)`
4. **Mesh extraction** - Dual contouring or marching cubes
5. **UV generation** - Project or use triplanar mapping

### Advantages
✅ **Clean results** - Smooth, artifact-free surfaces  
✅ **Blending support** - Smooth transitions with min/max operators  
✅ **Any shape** - SDFs support arbitrary geometry  
✅ **Multiple operations** - Easy to combine many volumes

### Disadvantages
❌ **Computational cost** - Sampling + extraction is expensive  
❌ **Memory intensive** - 3D grids require significant memory  
❌ **UV mapping hard** - Original UVs lost  
❌ **Resolution tradeoff** - Detail vs cost

### When to Use
- For organic, smooth tunnel shapes
- When blending multiple volumes
- For artistic control (smooth min, blending)
- In voxel-based terrain systems

---

## Recommended Implementation Plan

### Phase 1: Foundation (Week 1-2)
**Implement Approach 1 (True CSG)** with these components:

```
terrain_generation/mesh_modifiers/csg/
├── csg_volume.gd              # Base class for volumes
├── cylinder_volume.gd          # Cylinder implementation
├── sphere_volume.gd            # Sphere for testing
├── csg_boolean_operator.gd    # Core boolean logic
├── triangle_clipper.gd         # Triangle subdivision
└── boundary_triangulator.gd    # Cap generation
```

#### Key Classes

**`CSGVolume`** - Abstract base class
```gdscript
class_name CSGVolume extends RefCounted

## Returns signed distance (negative = inside, positive = outside)
func signed_distance(point: Vector3) -> float:
    assert(false, "Must override")
    return 0.0

## Project point onto surface
func project_to_surface(point: Vector3) -> Vector3:
    assert(false, "Must override")
    return point

## Get surface normal at point
func get_normal_at(point: Vector3) -> Vector3:
    assert(false, "Must override")
    return Vector3.UP
```

**`CylinderVolume`** - Specific implementation
```gdscript
class_name CylinderVolume extends CSGVolume

var origin: Vector3
var direction: Vector3  # Normalized
var radius: float
var length: float

func signed_distance(point: Vector3) -> float:
    var to_point = point - origin
    var axial_dist = to_point.dot(direction)
    
    # Outside length bounds
    if axial_dist < 0.0 or axial_dist > length:
        return # ... complex distance calculation
    
    # Within length, check radial
    var proj_point = origin + direction * axial_dist
    var radial_dist = point.distance_to(proj_point)
    return radial_dist - radius  # Negative if inside
```

**`CSGBooleanOperator`** - Core algorithm
```gdscript
class_name CSGBooleanOperator extends RefCounted

enum TriangleClass { FULLY_OUTSIDE, FULLY_INSIDE, INTERSECTING }

func subtract_volume_from_mesh(mesh_data: MeshData, volume: CSGVolume) -> MeshData:
    var result = MeshData.new()
    
    for tri_idx in range(mesh_data.get_triangle_count()):
        var tri = get_triangle_vertices(mesh_data, tri_idx)
        var classification = classify_triangle(tri, volume)
        
        match classification:
            TriangleClass.FULLY_OUTSIDE:
                # Keep triangle as-is
                add_triangle_to_result(result, tri)
            
            TriangleClass.FULLY_INSIDE:
                # Remove triangle (do nothing)
                pass
            
            TriangleClass.INTERSECTING:
                # Clip and subdivide
                var clipped = clip_triangle(tri, volume)
                add_triangles_to_result(result, clipped)
    
    # Generate boundary cap geometry
    var boundary_mesh = generate_boundary_cap(mesh_data, volume)
    merge_meshes(result, boundary_mesh)
    
    return result
```

### Phase 2: Tunnel Agent Refactor (Week 2-3)
Refactor `TunnelBoringAgent` to use CSG system:

```gdscript
func _create_tunnel_at(entry: Dictionary, context: MeshModifierContext) -> bool:
    var entry_pos: Vector3 = entry.position
    var tunnel_direction: Vector3 = entry.tunnel_normal
    
    # Define tunnel as CSG volume
    var tunnel_volume = CylinderVolume.new()
    tunnel_volume.origin = entry_pos
    tunnel_volume.direction = tunnel_direction
    tunnel_volume.radius = tunnel_radius
    tunnel_volume.length = tunnel_length
    
    # Apply terrain-aware culling (only underground parts)
    var culled_volume = TerrainAwareVolume.new(tunnel_volume, context)
    
    # Perform boolean subtraction
    var csg_operator = CSGBooleanOperator.new()
    var modified_mesh = csg_operator.subtract_volume_from_mesh(
        context.get_mesh_data().mesh_data,
        culled_volume
    )
    
    # Replace mesh data in context
    context.replace_mesh_data(modified_mesh)
    
    return true
```

### Phase 3: Extended Shapes (Week 4)
Add support for complex shapes:

```gdscript
# Elliptical tunnels
class_name EllipsoidVolume extends CSGVolume

# Square/rectangular tunnels  
class_name BoxVolume extends CSGVolume

# Natural cave shapes (compound volumes)
class_name CompoundVolume extends CSGVolume:
    var volumes: Array[CSGVolume]
    var operation: CSGOperation  # UNION, INTERSECTION, SUBTRACTION
    
    func signed_distance(point: Vector3) -> float:
        match operation:
            CSGOperation.UNION:
                return min_distance_to_any_volume(point)
            CSGOperation.INTERSECTION:
                return max_distance_to_any_volume(point)
            CSGOperation.SUBTRACTION:
                return # ... subtraction logic
```

### Phase 4: Optimization (Week 5+)
1. **Spatial acceleration** - BVH for triangle queries
2. **Parallel processing** - Multi-threaded CSG operations
3. **GPU compute** - Port critical paths to compute shaders
4. **Caching** - Reuse classification results when possible

---

## Comparison Matrix

| Approach | Quality | Performance | Complexity | Extensibility | Recommended |
|----------|---------|-------------|------------|---------------|-------------|
| **CSG Boolean** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ **YES** |
| Voxel-Based | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | For specific cases |
| Vertex Snapping | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Prototyping only |
| GPU Compute | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | After CSG works |
| SDF-Based | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | For organic shapes |

---

## Future Extensibility Examples

### Example 1: Natural Cave System
```gdscript
var cave = CompoundVolume.new()
cave.operation = CSGOperation.UNION

# Main chamber (sphere)
cave.add_volume(SphereVolume.new(Vector3(0, -5, 0), 8.0))

# Connecting tunnels (cylinders)
cave.add_volume(CylinderVolume.new(
    Vector3(0, -5, 0), Vector3(1, 0, 0), 3.0, 15.0
))
cave.add_volume(CylinderVolume.new(
    Vector3(0, -5, 0), Vector3(0, 0, 1), 2.5, 12.0
))

# Stalactites (inverted cones) - SUBTRACT from cave
var stalactite = ConeVolume.new(Vector3(0, 0, 0), Vector3(0, -1, 0), 1.0, 3.0)
cave.subtract_volume(stalactite)
```

### Example 2: Mining Operation
```gdscript
var mine_shaft = BoxVolume.new(
    center=Vector3(0, -10, 0),
    size=Vector3(3, 20, 3),
    rotation=Basis()  # Can be rotated
)
```

### Example 3: Organic Cave Blending
```gdscript
# Use SDF smooth operations for natural transitions
var volume1 = SphereVolume.new(pos1, radius1)
var volume2 = SphereVolume.new(pos2, radius2)

# Smooth union creates blob-like connection
var blended = SDFSmoothUnion.new([volume1, volume2], smoothing=2.0)
```

---

## Conclusion

**Approach 1 (True CSG Boolean Operations)** is the clear winner because it:

1. ✅ **Solves the stated problem** - Proper boolean subtraction with stitching
2. ✅ **Produces high-quality results** - Watertight, artifact-free meshes
3. ✅ **Is highly extensible** - Easy to add new volume types
4. ✅ **Fits the architecture** - Works with existing mesh modifier pipeline
5. ✅ **Future-proof** - Foundation for complex shapes and operations
6. ✅ **Reasonable complexity** - Not trivial, but well-understood algorithms

The implementation phases provide a clear path forward, starting with the foundational CSG system, then refactoring the tunnel agent, and finally extending to support arbitrary complex shapes.

The key insight is that **volumes are the abstraction** - once you have a robust CSG system that works with the `CSGVolume` interface, adding new shapes (ellipsoids, tori, arbitrary meshes, compound shapes) becomes trivial.
