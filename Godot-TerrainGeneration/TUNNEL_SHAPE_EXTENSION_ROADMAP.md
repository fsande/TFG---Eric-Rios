# Tunnel Shape Extension Roadmap

## Executive Summary

This roadmap outlines the architecture and implementation plan to extend the Tunnel Boring Agent from supporting only cylindrical tunnels to supporting multiple tunnel shapes (rectangular, elliptical, spline-based, natural cave-like) while improving type safety by replacing Dictionary-based configurations with proper typed classes.

---

## Current Architecture Analysis

### Component Overview

The tunnel system follows a well-structured pattern-based architecture:

```
TunnelBoringAgent (Orchestrator)
    ├── TunnelEntryPoint (Data: position, normal, direction)
    ├── TunnelDefinition (Config: shape_type: String, shape_parameters: Dictionary)
    ├── TunnelShapeFactory (Factory Pattern)
    │   └── Creates: TunnelShape implementations
    ├── TunnelShape (Abstract Base: extends CSGVolume)
    │   └── CylindricalTunnelShape (Concrete Implementation)
    ├── TunnelInteriorGenerator (Strategy Pattern)
    ├── TunnelSceneBuilder (Builder Pattern)
    └── CSGBooleanOperator (CSG Operations)
```

### Key Files & Responsibilities

1. **TunnelBoringAgent** (`tunnel_boring_agent.gd`)
   - Orchestrates tunnel creation pipeline
   - Finds entry points on cliffs
   - Delegates to specialized components
   - Handles debug visualization

2. **TunnelDefinition** (`tunnel/core/tunnel_definition.gd`)
   - **CURRENT ISSUE**: Uses `String` for `shape_type` and `Dictionary` for `shape_parameters`
   - Stores entry point, material, collision settings
   - Has hard-coded validation for "Cylindrical" type

3. **TunnelShapeFactory** (`tunnel/builders/tunnel_shape_factory.gd`)
   - **CURRENT ISSUE**: String-based type matching
   - Creates appropriate TunnelShape from TunnelDefinition
   - Currently only handles "Cylindrical"

4. **TunnelShape** (`csg/tunnel_shape.gd`)
   - Abstract base class extending CSGVolume
   - Defines interface: `generate_interior_mesh()`, `get_collision_shape()`, etc.
   - Subclasses: `CylindricalTunnelShape`

5. **CSGVolume** (`csg/csg_volume.gd`)
   - Provides `signed_distance()` for CSG operations
   - Used by CSGBooleanOperator for mesh subtraction

### Design Patterns Identified

✅ **Factory Pattern**: TunnelShapeFactory creates shapes
✅ **Strategy Pattern**: TunnelShape implementations as strategies
✅ **Builder Pattern**: TunnelSceneBuilder constructs scene nodes
✅ **Facade Pattern**: MeshModifierContext simplifies operations

---

## Problems with Current Implementation

### 1. **Type Safety Issues**

```gdscript
# ❌ Current approach - not type safe
var shape_type: String = "Cylindrical"  # Typos possible, no compile-time checking
var shape_parameters: Dictionary = {}   # No validation, arbitrary keys

# Hard-coded string matching
match definition.shape_type:
    "Cylindrical":  # String literal duplication
        return _create_cylindrical_from_definition(definition)
```

### 2. **Validation Fragmentation**

Validation logic scattered across multiple files:
- `TunnelDefinition.is_valid()` has hard-coded shape-specific checks
- Each creation method validates independently
- No centralized shape parameter schema

### 3. **Extensibility Limitations**

Adding a new shape requires:
1. Edit TunnelDefinition to add validation case
2. Edit TunnelShapeFactory to add factory method
3. Create new TunnelShape subclass
4. Update TunnelBoringAgent exports (hard-coded parameters)

This violates **Open/Closed Principle** (not open for extension, requires modification of existing code).

### 4. **Parameter Access Complexity**

```gdscript
# ❌ Current - runtime lookup, no IDE support
var radius = definition.get_shape_param("radius", DEFAULT_RADIUS) as float
```

---

## Proposed Architecture

### Phase 1: Type-Safe Shape Configuration System

#### 1.1 Shape Type Enum

Create `tunnel/core/tunnel_shape_type.gd`:

```gdscript
class_name TunnelShapeType extends RefCounted

enum Type {
    CYLINDRICAL,
    RECTANGULAR,
    ELLIPTICAL,
    SPLINE,
    NATURAL_CAVE
}

# Type metadata for UI and validation
static func get_display_name(type: Type) -> String:
    match type:
        Type.CYLINDRICAL: return "Cylindrical"
        Type.RECTANGULAR: return "Rectangular"
        Type.ELLIPTICAL: return "Elliptical"
        Type.SPLINE: return "Spline"
        Type.NATURAL_CAVE: return "Natural Cave"
    return "Unknown"

static func get_all_types() -> Array[Type]:
    return [Type.CYLINDRICAL, Type.RECTANGULAR, Type.ELLIPTICAL, 
            Type.SPLINE, Type.NATURAL_CAVE]
```

#### 1.2 Shape Parameter Base Class

Create `tunnel/core/shape_parameters/tunnel_shape_parameters.gd`:

```gdscript
## Abstract base class for type-safe shape parameters
class_name TunnelShapeParameters extends Resource

## Get the shape type this parameter set describes
func get_shape_type() -> TunnelShapeType.Type:
    push_error("Must override get_shape_type()")
    return TunnelShapeType.Type.CYLINDRICAL

## Validate parameters (called before shape creation)
func is_valid() -> bool:
    push_error("Must override is_valid()")
    return false

## Get parameter summary for debugging
func to_string() -> String:
    return "TunnelShapeParameters (override in subclass)"

## Convert to Dictionary for serialization (if needed)
func to_dict() -> Dictionary:
    return {}

## Create from Dictionary for deserialization
static func from_dict(data: Dictionary) -> TunnelShapeParameters:
    push_error("Must override from_dict() in subclass")
    return null
```

#### 1.3 Concrete Parameter Classes

**CylindricalShapeParameters** (`tunnel/core/shape_parameters/cylindrical_shape_parameters.gd`):

```gdscript
@tool
class_name CylindricalShapeParameters extends TunnelShapeParameters

@export_range(1.0, 50.0, 0.5) var radius: float = 3.0
@export_range(1.0, 100.0, 1.0) var length: float = 20.0
@export_range(6, 64, 1) var radial_segments: int = 16
@export_range(2, 50, 1) var length_segments: int = 8

func get_shape_type() -> TunnelShapeType.Type:
    return TunnelShapeType.Type.CYLINDRICAL

func is_valid() -> bool:
    if radius <= 0:
        push_error("CylindricalShapeParameters: radius must be positive")
        return false
    if length <= 0:
        push_error("CylindricalShapeParameters: length must be positive")
        return false
    return true

func to_string() -> String:
    return "Cylindrical(r=%.1f, l=%.1f, segs=%d/%d)" % [radius, length, radial_segments, length_segments]

func to_dict() -> Dictionary:
    return {
        "radius": radius,
        "length": length,
        "radial_segments": radial_segments,
        "length_segments": length_segments
    }

static func from_dict(data: Dictionary) -> CylindricalShapeParameters:
    var params = CylindricalShapeParameters.new()
    params.radius = data.get("radius", 3.0)
    params.length = data.get("length", 20.0)
    params.radial_segments = data.get("radial_segments", 16)
    params.length_segments = data.get("length_segments", 8)
    return params
```

**RectangularShapeParameters** (`tunnel/core/shape_parameters/rectangular_shape_parameters.gd`):

```gdscript
@tool
class_name RectangularShapeParameters extends TunnelShapeParameters

@export_range(1.0, 50.0, 0.5) var width: float = 4.0
@export_range(1.0, 50.0, 0.5) var height: float = 3.0
@export_range(1.0, 100.0, 1.0) var length: float = 20.0
@export_range(1, 20, 1) var width_segments: int = 2
@export_range(1, 20, 1) var height_segments: int = 2
@export_range(2, 50, 1) var length_segments: int = 8

func get_shape_type() -> TunnelShapeType.Type:
    return TunnelShapeType.Type.RECTANGULAR

func is_valid() -> bool:
    return width > 0 and height > 0 and length > 0
```

**EllipticalShapeParameters** (`tunnel/core/shape_parameters/elliptical_shape_parameters.gd`):

```gdscript
@tool
class_name EllipticalShapeParameters extends TunnelShapeParameters

@export_range(1.0, 50.0, 0.5) var radius_horizontal: float = 4.0
@export_range(1.0, 50.0, 0.5) var radius_vertical: float = 3.0
@export_range(1.0, 100.0, 1.0) var length: float = 20.0
@export_range(6, 64, 1) var radial_segments: int = 16
@export_range(2, 50, 1) var length_segments: int = 8

func get_shape_type() -> TunnelShapeType.Type:
    return TunnelShapeType.Type.ELLIPTICAL

func is_valid() -> bool:
    return radius_horizontal > 0 and radius_vertical > 0 and length > 0
```

**SplineShapeParameters** (`tunnel/core/shape_parameters/spline_shape_parameters.gd`):

```gdscript
@tool
class_name SplineShapeParameters extends TunnelShapeParameters

## Path curve defining tunnel centerline
@export var path_curve: Curve3D
@export_range(1.0, 50.0, 0.5) var radius: float = 3.0
@export_range(6, 64, 1) var radial_segments: int = 16
@export_range(5, 100, 1) var path_segments: int = 20

func get_shape_type() -> TunnelShapeType.Type:
    return TunnelShapeType.Type.SPLINE

func is_valid() -> bool:
    return path_curve != null and path_curve.point_count >= 2 and radius > 0
```

**NaturalCaveParameters** (`tunnel/core/shape_parameters/natural_cave_parameters.gd`):

```gdscript
@tool
class_name NaturalCaveParameters extends TunnelShapeParameters

## Base radius for cave variation
@export_range(2.0, 20.0, 0.5) var base_radius: float = 5.0
@export_range(0.0, 1.0, 0.1) var radius_variation: float = 0.3
@export_range(1.0, 100.0, 1.0) var length: float = 30.0
@export var noise_seed: int = 0
@export_range(0.5, 5.0, 0.1) var noise_frequency: float = 1.0
@export_range(6, 64, 1) var radial_segments: int = 24
@export_range(10, 100, 1) var length_segments: int = 30

func get_shape_type() -> TunnelShapeType.Type:
    return TunnelShapeType.Type.NATURAL_CAVE

func is_valid() -> bool:
    return base_radius > 0 and length > 0
```

#### 1.4 Updated TunnelDefinition

**Refactored** `tunnel/core/tunnel_definition.gd`:

```gdscript
class_name TunnelDefinition extends RefCounted

# ✅ Type-safe shape parameters (no more Dictionary!)
var entry_point: TunnelEntryPoint
var shape_parameters: TunnelShapeParameters  # Polymorphic type-safe parameter

var tunnel_material: Material = null
var cast_shadows: bool = true

var generate_collision: bool = true
var collision_layers: int = 1
var collision_mask: int = 1

var debug_visualization: bool = false
var debug_color: Color = Color(1.0, 0.0, 0.0, 0.3)

func _init(p_entry_point: TunnelEntryPoint, p_shape_params: TunnelShapeParameters) -> void:
    entry_point = p_entry_point
    shape_parameters = p_shape_params

func is_valid() -> bool:
    if not entry_point or not entry_point.has_valid_direction():
        push_error("TunnelDefinition: Invalid entry point")
        return false
    if not shape_parameters or not shape_parameters.is_valid():
        push_error("TunnelDefinition: Invalid shape parameters")
        return false
    return true

func get_shape_type() -> TunnelShapeType.Type:
    return shape_parameters.get_shape_type()

# Factory methods for each shape type
static func create_cylindrical(
    p_entry_point: TunnelEntryPoint,
    radius: float,
    length: float
) -> TunnelDefinition:
    var params = CylindricalShapeParameters.new()
    params.radius = radius
    params.length = length
    return TunnelDefinition.new(p_entry_point, params)

static func create_rectangular(
    p_entry_point: TunnelEntryPoint,
    width: float,
    height: float,
    length: float
) -> TunnelDefinition:
    var params = RectangularShapeParameters.new()
    params.width = width
    params.height = height
    params.length = length
    return TunnelDefinition.new(p_entry_point, params)

# ... similar factory methods for other shapes
```

#### 1.5 Updated TunnelShapeFactory

**Refactored** `tunnel/builders/tunnel_shape_factory.gd`:

```gdscript
class_name TunnelShapeFactory extends RefCounted

static func create_from_definition(definition: TunnelDefinition) -> TunnelShape:
    if not definition or not definition.is_valid():
        push_error("TunnelShapeFactory: Invalid definition")
        return null
    
    # ✅ Type-safe enum-based dispatch
    match definition.get_shape_type():
        TunnelShapeType.Type.CYLINDRICAL:
            return _create_cylindrical(definition)
        TunnelShapeType.Type.RECTANGULAR:
            return _create_rectangular(definition)
        TunnelShapeType.Type.ELLIPTICAL:
            return _create_elliptical(definition)
        TunnelShapeType.Type.SPLINE:
            return _create_spline(definition)
        TunnelShapeType.Type.NATURAL_CAVE:
            return _create_natural_cave(definition)
        _:
            push_error("TunnelShapeFactory: Unsupported shape type")
            return null

static func _create_cylindrical(definition: TunnelDefinition) -> CylindricalTunnelShape:
    # ✅ Type-safe parameter access
    var params = definition.shape_parameters as CylindricalShapeParameters
    
    var shape = CylindricalTunnelShape.new(
        definition.get_position(),
        definition.get_direction(),
        params.radius,
        params.length
    )
    shape.radial_segments = params.radial_segments
    shape.length_segments = params.length_segments
    return shape

static func _create_rectangular(definition: TunnelDefinition) -> RectangularTunnelShape:
    var params = definition.shape_parameters as RectangularShapeParameters
    return RectangularTunnelShape.new(
        definition.get_position(),
        definition.get_direction(),
        params.width,
        params.height,
        params.length,
        params.width_segments,
        params.height_segments,
        params.length_segments
    )

# ... similar for other shapes
```

---

### Phase 2: New TunnelShape Implementations

#### 2.1 RectangularTunnelShape

Create `csg/rectangular_tunnel_shape.gd`:

```gdscript
@tool
class_name RectangularTunnelShape extends TunnelShape

var origin: Vector3
var direction: Vector3
var width: float
var height: float
var length: float
var width_segments: int = 2
var height_segments: int = 2
var length_segments: int = 8

func _init(p_origin: Vector3, p_direction: Vector3, p_width: float, p_height: float, p_length: float, 
           p_width_segs: int = 2, p_height_segs: int = 2, p_length_segs: int = 8) -> void:
    origin = p_origin
    direction = p_direction.normalized()
    width = p_width
    height = p_height
    length = p_length
    width_segments = p_width_segs
    height_segments = p_height_segs
    length_segments = p_length_segs

func signed_distance(point: Vector3) -> float:
    # Box SDF implementation
    var to_point = point - origin
    var axis_distance = to_point.dot(direction)
    
    # Project point onto tunnel cross-section plane
    var basis = _create_tunnel_basis()
    var local_x = to_point.dot(basis.x)
    var local_y = to_point.dot(basis.y)
    
    # Distance to box in 3D (length along axis, width/height in cross-section)
    var dx = max(abs(local_x) - width * 0.5, 0.0)
    var dy = max(abs(local_y) - height * 0.5, 0.0)
    var dz = max(-axis_distance, axis_distance - length)
    
    var outside_dist = sqrt(dx*dx + dy*dy + max(dz, 0.0)*dz)
    var inside_dist = min(max(dx, dy, dz), 0.0)
    
    return outside_dist + inside_dist

func generate_interior_mesh(terrain_querier: TerrainHeightQuerier) -> MeshData:
    var mesh_data = MeshData.new()
    var basis = _create_tunnel_basis()
    
    # Generate rectangular cross-section at each length segment
    # Implementation similar to cylindrical but with box vertices
    # ... mesh generation code
    
    return mesh_data

func get_shape_type() -> String:
    return "Rectangular"

# ... implement other TunnelShape interface methods
```

#### 2.2 EllipticalTunnelShape

Similar to cylindrical but with separate horizontal/vertical radii.

#### 2.3 SplineTunnelShape

Follows a Curve3D path with varying cross-section.

#### 2.4 NaturalCaveTunnelShape

Uses procedural noise to vary radius along length for organic cave look.

---

### Phase 3: Updated TunnelBoringAgent with Shape Selection

**Refactored** `tunnel_boring_agent.gd`:

```gdscript
@tool
class_name TunnelBoringAgent extends MeshModifierAgent

# ✅ Shape type selection via enum
@export_enum("Cylindrical", "Rectangular", "Elliptical", "Spline", "Natural Cave") 
var tunnel_shape_type: int = 0  # Maps to TunnelShapeType.Type

@export_group("Cylindrical Parameters")
@export var cylindrical_params: CylindricalShapeParameters

@export_group("Rectangular Parameters")
@export var rectangular_params: RectangularShapeParameters

@export_group("Elliptical Parameters")
@export var elliptical_params: EllipticalShapeParameters

@export_group("Spline Parameters")
@export var spline_params: SplineShapeParameters

@export_group("Natural Cave Parameters")
@export var natural_cave_params: NaturalCaveParameters

@export_group("Placement")
@export var min_cliff_height: float = 15.0
@export_range(5.0, 90.0, 5.0) var min_cliff_angle: float = 10.0
@export_range(1, 10, 1) var tunnel_count: int = 1
@export var placement_seed: int = 0

# ... other export groups (Generation Settings, Visual, Debug)

func _init() -> void:
    agent_name = "Tunnel Boring Agent"
    _initialize_components()
    _initialize_default_parameters()

func _initialize_default_parameters() -> void:
    if not cylindrical_params:
        cylindrical_params = CylindricalShapeParameters.new()
    if not rectangular_params:
        rectangular_params = RectangularShapeParameters.new()
    if not elliptical_params:
        elliptical_params = EllipticalShapeParameters.new()
    if not spline_params:
        spline_params = SplineShapeParameters.new()
    if not natural_cave_params:
        natural_cave_params = NaturalCaveParameters.new()

func _create_tunnel_definitions(entry_points: Array[TunnelEntryPoint]) -> Array[TunnelDefinition]:
    var definitions: Array[TunnelDefinition] = []
    
    for entry in entry_points:
        # ✅ Get current shape parameters based on selected type
        var params = _get_current_shape_parameters()
        
        var definition = TunnelDefinition.new(entry, params)
        definition.generate_collision = enable_collision
        definition.debug_visualization = show_debug_visualization
        definition.debug_color = debug_color
        definition.tunnel_material = tunnel_material
        
        definitions.append(definition)
    
    return definitions

# ✅ Type-safe parameter selection
func _get_current_shape_parameters() -> TunnelShapeParameters:
    match tunnel_shape_type:
        0:  # Cylindrical
            return cylindrical_params.duplicate()
        1:  # Rectangular
            return rectangular_params.duplicate()
        2:  # Elliptical
            return elliptical_params.duplicate()
        3:  # Spline
            return spline_params.duplicate()
        4:  # Natural Cave
            return natural_cave_params.duplicate()
        _:
            push_warning("Unknown shape type, defaulting to cylindrical")
            return cylindrical_params.duplicate()
```

**Alternative UI Approach (Resource-based):**

```gdscript
@export var active_shape_parameters: TunnelShapeParameters

# In the editor, user creates a Resource of appropriate type
# (CylindricalShapeParameters, RectangularShapeParameters, etc.)
# and assigns it to active_shape_parameters
```

This is cleaner but requires more manual setup in the editor.

---

## Implementation Phases

### **Phase 1: Foundation (Type Safety)**
**Estimated Time: 2-3 days**

1. ✅ Create `TunnelShapeType` enum class
2. ✅ Create `TunnelShapeParameters` base class
3. ✅ Create `CylindricalShapeParameters` (migrate existing)
4. ✅ Refactor `TunnelDefinition` to use typed parameters
5. ✅ Update `TunnelShapeFactory` for enum-based dispatch
6. ✅ Update existing tests to use new API
7. ✅ Ensure backward compatibility (no visual changes yet)

**Deliverable**: Type-safe architecture with cylindrical tunnels working exactly as before.

---

### **Phase 2: Rectangular Tunnels**
**Estimated Time: 2-3 days**

1. ✅ Create `RectangularShapeParameters`
2. ✅ Implement `RectangularTunnelShape` (CSG + mesh generation)
3. ✅ Add factory method in `TunnelShapeFactory`
4. ✅ Update `TunnelBoringAgent` with rectangular parameters
5. ✅ Create unit tests for rectangular tunnels
6. ✅ Test CSG subtraction and interior generation

**Deliverable**: Functional rectangular tunnels selectable from agent.

---

### **Phase 3: Elliptical Tunnels**
**Estimated Time: 1-2 days**

1. ✅ Create `EllipticalShapeParameters`
2. ✅ Implement `EllipticalTunnelShape`
3. ✅ Add to factory and agent
4. ✅ Tests

**Deliverable**: Elliptical tunnel option.

---

### **Phase 4: Spline-Based Tunnels**
**Estimated Time: 3-4 days**

1. ✅ Create `SplineShapeParameters` (with Curve3D support)
2. ✅ Implement `SplineTunnelShape` (more complex - curved path)
3. ✅ Handle CSG for curved volumes
4. ✅ Interior mesh generation along spline
5. ✅ Tests

**Deliverable**: Curved tunnel paths following Curve3D.

---

### **Phase 5: Natural Cave-Like Tunnels**
**Estimated Time: 3-4 days**

1. ✅ Create `NaturalCaveParameters` (noise-based variation)
2. ✅ Implement `NaturalCaveTunnelShape` (procedural radius variation)
3. ✅ Add noise-based cross-section deformation
4. ✅ Tests

**Deliverable**: Organic, natural-looking cave tunnels.

---

### **Phase 6: Polish & Documentation**
**Estimated Time: 2 days**

1. ✅ Update all documentation
2. ✅ Create usage examples
3. ✅ Performance optimization
4. ✅ Final integration testing
5. ✅ Update roadmap with "completed" status

---

## Benefits of This Approach

### ✅ Type Safety
- Compile-time checking for parameter types
- IDE autocomplete for all parameters
- Impossible to typo parameter names

### ✅ Extensibility (Open/Closed Principle)
- Adding new shape = create new parameter class + shape class
- No modification of `TunnelDefinition` validation logic
- No modification of `TunnelBoringAgent` core logic

### ✅ Maintainability
- Each shape's parameters are self-contained
- Validation logic lives with the parameters
- Clear separation of concerns

### ✅ Usability
- Export parameters visible in Godot inspector
- Type-specific parameter groups in editor
- Visual feedback through `@export_range` annotations

### ✅ Testability
- Each parameter class can be unit tested independently
- Shape creation can be tested with mock parameters
- Clear contract via `TunnelShapeParameters` interface

---

## Backward Compatibility Strategy

### Migration Path

1. **Phase 1 maintains full backward compatibility**:
   - Old `TunnelDefinition.create_cylindrical()` still works
   - Internally converts to new parameter system
   - No changes to generated tunnels

2. **Deprecation warnings (optional)**:
   ```gdscript
   @deprecated("Use TunnelDefinition.new(entry_point, CylindricalShapeParameters.new()) instead")
   static func create_cylindrical(...)
   ```

3. **Gradual migration**:
   - Update tests incrementally
   - Keep old API as convenience methods
   - Eventually remove in major version update

---

## Testing Strategy

### Unit Tests Required

1. **Parameter Classes**:
   - `test_cylindrical_shape_parameters.gd`
   - `test_rectangular_shape_parameters.gd`
   - etc.

2. **Shape Implementations**:
   - `test_rectangular_tunnel_shape.gd` (SDF, mesh generation)
   - `test_elliptical_tunnel_shape.gd`
   - etc.

3. **Integration Tests**:
   - `test_tunnel_shape_factory.gd` (enum-based dispatch)
   - `test_tunnel_boring_agent_shapes.gd` (end-to-end for each shape)

### Visual Tests

Create test scenes for each shape type to verify:
- CSG subtraction correctness
- Interior mesh quality
- Collision shape accuracy
- Material application

---

## Risks & Mitigation

### Risk 1: Breaking Existing Scenes
**Mitigation**: Phase 1 maintains full backward compatibility. Test extensively before Phase 2.

### Risk 2: Complex SDF for Non-Cylindrical Shapes
**Mitigation**: Start with rectangular (simple box SDF). Research ellipse/spline SDFs before implementation.

### Risk 3: Performance Degradation
**Mitigation**: Profile each shape type. Use LOD techniques if needed. Consider caching SDF evaluations.

### Risk 4: UI Complexity (Too Many Parameter Groups)
**Mitigation**: Consider alternative UI (single Resource export). Provide preset resources for common configurations.

---

## File Structure After Implementation

```
terrain_generation/mesh_modifiers/
├── agents/
│   └── tunnel_boring_agent.gd (updated with shape selection)
├── tunnel/
│   ├── core/
│   │   ├── tunnel_shape_type.gd (NEW - enum)
│   │   ├── tunnel_definition.gd (refactored - uses TunnelShapeParameters)
│   │   ├── tunnel_entry_point.gd (unchanged)
│   │   └── shape_parameters/ (NEW FOLDER)
│   │       ├── tunnel_shape_parameters.gd (NEW - base class)
│   │       ├── cylindrical_shape_parameters.gd (NEW)
│   │       ├── rectangular_shape_parameters.gd (NEW)
│   │       ├── elliptical_shape_parameters.gd (NEW)
│   │       ├── spline_shape_parameters.gd (NEW)
│   │       └── natural_cave_parameters.gd (NEW)
│   ├── builders/
│   │   └── tunnel_shape_factory.gd (refactored - enum dispatch)
│   └── generation/
│       └── tunnel_interior_generator.gd (unchanged - uses TunnelShape interface)
├── csg/
│   ├── tunnel_shape.gd (unchanged - abstract base)
│   ├── cylindrical_tunnel_shape.gd (unchanged)
│   ├── rectangular_tunnel_shape.gd (NEW)
│   ├── elliptical_tunnel_shape.gd (NEW)
│   ├── spline_tunnel_shape.gd (NEW)
│   └── natural_cave_tunnel_shape.gd (NEW)
└── ...
```

---

## Conclusion

This roadmap provides a structured approach to extending the tunnel system from single-shape (cylindrical) to multi-shape support while dramatically improving type safety. The phased approach allows for incremental development and testing, with Phase 1 establishing the foundation without breaking existing functionality.

**Total Estimated Time: 13-18 days**

The architecture leverages existing design patterns (Factory, Strategy) and adds strong typing to eliminate Dictionary-based parameter passing, resulting in a more maintainable, extensible, and user-friendly system.

---

## Next Steps

1. **Review this roadmap** with the team
2. **Approve or adjust** the approach
3. **Begin Phase 1 implementation**
4. **Set up feature branch** for tunnel shape extension
5. **Create tracking issues** for each phase

---

**Document Version**: 1.0  
**Created**: 2026-01-22  
**Status**: Ready for Implementation  

