extends RefCounted
# Допоміжні функції для побудови 3D-моделей з примітивів.

static func mat(color: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    if color.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if emit > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emit
    return m

static func add_mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, rough: float = 0.85, emit: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat(color, rough, emit)
    mi.position = pos
    mi.rotation_degrees = rot_deg
    parent.add_child(mi)
    return mi

static func box(size: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    return b

static func sphere(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    return s

static func capsule(r: float, h: float) -> CapsuleMesh:
    var c := CapsuleMesh.new()
    c.radius = r
    c.height = h
    return c

static func cylinder(top_r: float, bottom_r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = top_r
    c.bottom_radius = bottom_r
    c.height = h
    return c
