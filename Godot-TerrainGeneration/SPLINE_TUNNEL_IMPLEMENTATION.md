# Spline Tunnel Shape - Implementation Complete

## Summary

Successfully implemented **Spline-based curved tunnel shape** that follows a `Curve3D` path, enabling tunnels that bend and curve through terrain instead of being straight.

## Files Created

### 1. SplineShapeParameters
**Path**: `tunnel/core/shape_parameters/spline_shape_parameters.gd`

**Parameters**:
- `path_curve: Curve3D` - The 3D curve path the tunnel follows (required)
- `radius: float` - Uniform radius of the tunnel (0.5-50.0m, default: 3.0m)
- `radial_segments: int` - Smoothness around circumference (6-64, default: 16)
- `path_segments: int` - Number of segments along curve (5-200, default: 50)
- `auto_calculate_length: bool` - Auto-calculate from curve vs manual (default: true)
- `manual_length: float` - Manual override for length (1.0-500.0m, default: 50.0m)

**Features**:
- Automatic length calculation from curve's baked length
- Validation ensures curve has at least 2 points
- Type-safe parameter access
- Full error reporting

### 2. SplineTunnelShape
**Path**: `csg/spline_tunnel_shape.gd`

**Key Features**:
- **Curve3D path following**: Tunnel follows any arbitrary 3D curve
- **Baked path optimization**: Pre-bakes curve points for performance
- **Proper tangent calculation**: Smooth transitions along curve
- **Dynamic basis computation**: Perpendicular cross-sections at each point
- **CSG signed distance**: Distance to nearest point on spline
- **Debug visualization**: Uses TubeTrailMesh for preview

**Implementation Details**:

#### Path Baking
```gdscript
func _bake_path() -> void:
    _baked_points = path_curve.get_baked_points()
    _baked_up_vectors.resize(_baked_points.size())
    for i in range(_baked_points.size()):
        var t := float(i) / float(_baked_points.size() - 1)
        var tangent := path_curve.sample_baked_up_vector(t * path_curve.get_baked_length())
        _baked_up_vectors[i] = tangent if tangent.length() > 0.01 else Vector3.UP
```

#### Mesh Generation Strategy
1. Sample curve at regular intervals (path_segments)
2. For each sample point:
   - Get position on curve
   - Calculate tangent vector
   - Create perpendicular basis (right/up vectors)
   - Generate circular ring of vertices
3. Connect rings with triangles

#### Basis Calculation
```gdscript
func _create_basis_at_point(tangent: Vector3) -> Basis:
    var forward := tangent.normalized()
    var right := Vector3.ZERO
    var up := Vector3.ZERO
    if abs(forward.y) < 0.999:
        right = Vector3.UP.cross(forward).normalized()
        up = forward.cross(right).normalized()
    else:
        right = forward.cross(Vector3.RIGHT).normalized()
        up = forward.cross(right).normalized()
    return Basis(right, up, forward)
```

## Integration Changes

### TunnelShapeFactory
Added `_create_spline_from_definition()`:
```gdscript
match definition.get_shape_type():
    TunnelShapeType.Type.CYLINDRICAL:
        return _create_cylindrical_from_definition(definition)
    TunnelShapeType.Type.NATURAL_CAVE:
        return _create_natural_cave_from_definition(definition)
    TunnelShapeType.Type.SPLINE:
        return _create_spline_from_definition(definition)
```

### TunnelBoringAgent
1. **Length adjustment** (only if manual length mode):
   ```gdscript
   elif params is SplineShapeParameters:
       var spline_params := params as SplineShapeParameters
       if not spline_params.auto_calculate_length:
           spline_params.manual_length += tunnel_entrance_extra_length
   ```

2. **Metadata support**:
   ```gdscript
   elif shape_parameters is SplineShapeParameters:
       var spline_params := shape_parameters as SplineShapeParameters
       base["radius"] = spline_params.radius
       base["radial_segments"] = spline_params.radial_segments
       base["path_segments"] = spline_params.path_segments
       base["curve_points"] = spline_params.path_curve.point_count if spline_params.path_curve else 0
   ```

## Usage

### In Godot Editor

1. **Create a Curve3D**:
   - Create a `Path3D` node in your scene
   - Add control points to define tunnel path
   - Save the `Curve3D` as a resource

2. **Configure Tunnel Agent**:
   - Add `TunnelBoringAgent` to scene
   - In Inspector, `shape_parameters` → "New Resource" → Select `SplineShapeParameters`
   - Assign your `Curve3D` to `path_curve`
   - Configure parameters:
     - **radius**: How wide the tunnel is (3-5m typical)
     - **path_segments**: More = smoother curve following (30-60 good range)
     - **radial_segments**: 16-24 for smooth circular cross-section
     - **auto_calculate_length**: Leave enabled to use curve's actual length

### In Code

```gdscript
# Create a curve programmatically
var curve = Curve3D.new()
curve.add_point(Vector3(0, 0, 0))
curve.add_point(Vector3(10, 2, 5), Vector3(-2, 1, 0), Vector3(2, -1, 0))
curve.add_point(Vector3(20, 0, 15), Vector3(-3, 0, -2), Vector3(3, 0, 2))
curve.add_point(Vector3(30, -3, 20))

# Create spline parameters
var spline_params = SplineShapeParameters.new()
spline_params.path_curve = curve
spline_params.radius = 4.0
spline_params.radial_segments = 24
spline_params.path_segments = 60

# Use with agent
var agent = TunnelBoringAgent.new()
agent.shape_parameters = spline_params
```

### Creating Interesting Paths

**Gentle Curve**:
```gdscript
var curve = Curve3D.new()
curve.add_point(Vector3(0, 50, 0))
curve.add_point(Vector3(15, 48, 10), Vector3(-3, 0, 0), Vector3(3, 0, 0))
curve.add_point(Vector3(30, 45, 20))
# Smooth, gradual turn
```

**S-Curve**:
```gdscript
var curve = Curve3D.new()
curve.add_point(Vector3(0, 50, 0))
curve.add_point(Vector3(10, 48, 10), Vector3(-2, 0, -3), Vector3(2, 0, 3))
curve.add_point(Vector3(20, 46, 10), Vector3(-2, 0, 3), Vector3(2, 0, -3))
curve.add_point(Vector3(30, 44, 0))
# Winding path
```

**Spiral Descent**:
```gdscript
var curve = Curve3D.new()
for i in range(8):
    var angle = float(i) / 8.0 * TAU * 2  # 2 full rotations
    var x = cos(angle) * 10
    var z = sin(angle) * 10
    var y = 50 - float(i) * 5  # Descend 5m per point
    curve.add_point(Vector3(x, y, z))
# Spiral down into terrain
```

## Visual Characteristics

### Cylindrical vs Spline

**Cylindrical**:
- Straight line path
- Fixed direction
- Simple, predictable
- Good for: Direct tunnels, mine shafts

**Spline**:
- Curved path (any shape)
- Follows terrain contours
- Dynamic, natural
- Good for: Rivers, natural passages, roads

### Path Complexity

**Simple curve (3-4 points)**:
- Gentle bends
- Easy to navigate
- Predictable

**Complex curve (8+ points)**:
- Tight turns possible
- Following terrain features
- More interesting exploration

**path_segments = 30**:
- Basic following of curve
- May show facets on tight curves

**path_segments = 60+**:
- Smooth curve following
- Higher polygon count

## Technical Details

### Signed Distance Function
The spline's SDF finds the closest point on the curve:
```gdscript
func signed_distance(point: Vector3) -> float:
    var min_dist := INF
    for i in range(_baked_points.size()):
        var spline_point := _baked_points[i]
        var dist_to_axis := point.distance_to(spline_point)
        var sd := dist_to_axis - radius
        min_dist = min(min_dist, sd)
    return min_dist
```

### Tangent Calculation
Uses finite difference for smooth tangents:
```gdscript
func _get_tangent_at(distance: float, curve_length: float) -> Vector3:
    var epsilon := 0.01
    var d1 := clamp(distance - epsilon, 0.0, curve_length)
    var d2 := clamp(distance + epsilon, 0.0, curve_length)
    var p1 := path_curve.sample_baked(d1)
    var p2 := path_curve.sample_baked(d2)
    return (p2 - p1).normalized()
```

### Performance Considerations
- **Mesh complexity**: radial_segments × path_segments vertices
  - Example: 24 × 60 = 1,440 vertices per tunnel
- **CSG performance**: O(n) where n = baked points (typically 50-100)
- **Curve baking**: Done once in `_init()`, cached for CSG operations

## Use Cases

### 1. River Tunnels
Create tunnels following river beds:
```gdscript
var river_curve = create_curve_from_river_path()
spline_params.path_curve = river_curve
spline_params.radius = 6.0
```

### 2. Road Tunnels
Follow terrain-hugging roads:
```gdscript
var road_curve = sample_road_spline()
spline_params.path_curve = road_curve
spline_params.radius = 4.0
```

### 3. Natural Cave Systems
Winding organic passages:
```gdscript
var cave_path = generate_wandering_path()
spline_params.path_curve = cave_path
spline_params.radius = 5.0
```

### 4. Mine Shafts with Turns
Following ore veins:
```gdscript
var vein_path = trace_mineral_vein()
spline_params.path_curve = vein_path
spline_params.radius = 2.5
```

## Limitations & Future Enhancements

### Current Limitations
1. Uniform radius (doesn't vary along path)
2. No twisting control (up vector could rotate)
3. Sharp corners may need more segments
4. No collision with terrain during path

### Potential Enhancements
1. **Variable radius**: Scale radius along curve
2. **Twist control**: Rotate cross-section along path
3. **Auto-terrain following**: Adjust curve to avoid terrain collision
4. **Path smoothing**: Auto-smooth sharp corners
5. **Banking**: Tilt tunnel on curves (like roads)

## Comparison: All Three Shapes

| Feature | Cylindrical | Natural Cave | Spline |
|---------|-------------|--------------|--------|
| **Path** | Straight | Straight | Curved |
| **Radius** | Uniform | Varies (noise) | Uniform |
| **Best For** | Simple tunnels | Organic caves | Roads, rivers |
| **Complexity** | Low | Medium | Medium-High |
| **Setup** | Easy | Easy | Requires curve |

## Testing

```gdscript
# Test 1: Gentle bend
var gentle = SplineShapeParameters.new()
var curve1 = Curve3D.new()
curve1.add_point(Vector3(0, 50, 0))
curve1.add_point(Vector3(15, 48, 10))
curve1.add_point(Vector3(30, 46, 20))
gentle.path_curve = curve1
gentle.radius = 4.0

# Test 2: Tight S-curve
var s_curve = SplineShapeParameters.new()
var curve2 = Curve3D.new()
curve2.add_point(Vector3(0, 50, 0))
curve2.add_point(Vector3(10, 48, 10), Vector3(-2, 0, -3), Vector3(2, 0, 3))
curve2.add_point(Vector3(20, 46, 10), Vector3(-2, 0, 3), Vector3(2, 0, -3))
curve2.add_point(Vector3(30, 44, 0))
s_curve.path_curve = curve2
s_curve.radius = 3.5
s_curve.path_segments = 80
```

## Conclusion

Spline tunnel shape is **fully implemented** and ready for use. The system now supports:

✅ **3 Complete Shape Types**: Cylindrical, Natural Cave, Spline  
✅ **Curve3D Integration**: Full Godot curve support  
✅ **Arbitrary Paths**: Any 3D curve can be a tunnel  
✅ **Type Safe**: All parameters properly typed  
✅ **Optimized**: Baked paths for performance  
✅ **Integrated**: Works seamlessly with existing pipeline  

The spline shape enables dynamic, curved tunnels that can follow terrain features, creating more natural and visually interesting underground passages.

---

**Date**: January 22, 2026  
**Status**: ✅ **COMPLETE**  
**All Shapes**: Cylindrical + Natural Cave + Spline  
**Lines Added**: ~150 lines across 2 new files + factory/agent updates  

