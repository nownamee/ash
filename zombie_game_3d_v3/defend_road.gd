extends Node3D
# Дорога від стартової бази до застави лицарів (місія оборони, «Давній форт»).
# Витоптана земляна стежка з плавним вигином, придорожнє каміння та кілька смолоскипів.
# Також віддає зони, де terrain.gd не ставить дерева й камені (дорога та площа застави).

const Util = preload("res://util.gd")
const FlickerLight = preload("res://light_flicker.gd")

const KEEP_POS := Vector3(0.0, 0.0, -112.0)   # центр замку
const START_Z := -17.0                         # дорога починається біля воріт стартової бази
const END_Z := -88.0                           # і закінчується в таборі лицарів перед замком
const HALF_W := 3.2                            # половина ширини дороги
const BEND := 6.0                              # наскільки дорога виляє вбік

# Вісь дороги: x залежно від z (на обох кінцях x = 0).
static func center_x(z: float) -> float:
    var u := clampf((START_Z - z) / (START_Z - END_Z), 0.0, 1.0)
    return BEND * sin(u * PI) * sin(u * TAU)

static func points(n: int) -> Array:
    var pts: Array = []
    for i in range(n + 1):
        var z := lerpf(START_Z, END_Z, float(i) / float(n))
        pts.append(Vector3(center_x(z), 0.0, z))
    return pts

# Зони, вільні від природних об'єктів: [початок Vector2, кінець Vector2, радіус].
static func clear_zones() -> Array:
    var zones: Array = []
    var pts: Array = points(18)
    for i in range(pts.size() - 1):
        var a: Vector3 = pts[i]
        var b: Vector3 = pts[i + 1]
        zones.append([Vector2(a.x, a.z), Vector2(b.x, b.z), 6.5])
    var c := Vector2(KEEP_POS.x, KEEP_POS.z + 8.0)
    zones.append([c, c, 34.0])
    return zones

# Зони без вогню для палаючого лісу: сама дорога (вузький коридор) і табір лицарів біля воріт замку.
static func fire_safe_zones() -> Array:
    var zones: Array = []
    var pts: Array = points(18)
    for i in range(pts.size() - 1):
        var a: Vector3 = pts[i]
        var b: Vector3 = pts[i + 1]
        zones.append([Vector2(a.x, a.z), Vector2(b.x, b.z), 5.0])
    var c := Vector2(KEEP_POS.x, KEEP_POS.z + 12.0)
    zones.append([c, c, 22.0])
    return zones

func _ready() -> void:
    _build_road()
    _build_stones()
    _build_torches()

func _build_road() -> void:
    var pts: Array = points(36)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(pts.size() - 1):
        var a: Vector3 = pts[i]
        var b: Vector3 = pts[i + 1]
        var da := _tangent(pts, i)
        var db := _tangent(pts, i + 1)
        var na := Vector3(-da.z, 0.0, da.x) * HALF_W
        var nb := Vector3(-db.z, 0.0, db.x) * HALF_W
        var p0 := a + na
        var p1 := a - na
        var p2 := b - nb
        var p3 := b + nb
        for v in [p0, p1, p2, p0, p2, p3]:
            st.set_normal(Vector3.UP)
            st.add_vertex(v)
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.30, 0.24, 0.17)
    m.roughness = 1.0
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.position.y = 0.035
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

func _tangent(pts: Array, i: int) -> Vector3:
    var i0 := maxi(0, i - 1)
    var i1 := mini(pts.size() - 1, i + 1)
    var pa: Vector3 = pts[i0]
    var pb: Vector3 = pts[i1]
    var d := pb - pa
    d.y = 0.0
    return d.normalized()

# Камінці по краях дороги.
func _build_stones() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    var n := 110
    var bm := BoxMesh.new()
    bm.size = Vector3.ONE
    bm.material = Util.mat(Color(0.42, 0.40, 0.37), 0.95)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = bm
    mm.instance_count = n
    for i in range(n):
        var z := lerpf(START_Z - 1.0, END_Z, rng.randf())
        var side := 1.0 if rng.randf() < 0.5 else -1.0
        var x := center_x(z) + side * (HALF_W + rng.randf_range(-0.4, 1.4))
        var s := rng.randf_range(0.25, 0.7)
        var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 0.6, s * rng.randf_range(0.8, 1.4)))
        mm.set_instance_transform(i, Transform3D(basis, Vector3(x, s * 0.2, z)))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    add_child(mmi)

# Смолоскипи вздовж дороги.
func _build_torches() -> void:
    for i in range(1, 4):
        var z := lerpf(START_Z, END_Z, float(i) / 4.0)
        var side := 1.0 if i % 2 == 0 else -1.0
        var x := center_x(z) + side * (HALF_W + 1.4)
        var post := Node3D.new()
        post.position = Vector3(x, 0.0, z)
        add_child(post)
        Util.add_mesh(post, Util.cylinder(0.07, 0.09, 2.4), Color(0.4, 0.26, 0.13), Vector3(0, 1.2, 0))
        Util.add_mesh(post, Util.sphere(0.2), Color(1.0, 0.55, 0.1), Vector3(0, 2.5, 0), Vector3.ZERO, 0.4, 4.0)
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.6, 0.25)
        l.light_energy = 1.5
        l.omni_range = 11.0
        l.position = Vector3(0, 2.5, 0)
        post.add_child(l)
