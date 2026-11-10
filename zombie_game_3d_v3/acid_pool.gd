extends Node3D
# Кислотна водойма довільної форми («Токсичне болото»): блискуча зелена поверхня з хвилями, темний вологий край,
# бульбашки, що наповнюються й лопаються, та рідкі їдкі випари над великими водоймами.
# Контур і трикутники дає terrain.gd; шкоду рахує level.gd (terrain.in_acid) за тим самим контуром.
# Параметри (poly, tri, area, seed_v) задайте до add_child(). Вузол стоїть у початку координат чанка, контур — у світових координатах.

var poly := PackedVector2Array()   # контур водойми (світові x, z)
var tri := PackedInt32Array()      # трикутники поверхні (індекси в poly)
var area := 10.0                   # площа, м² (від неї залежить кількість бульбашок і випарів)
var seed_v := 1

static var _ready_res := false
static var _surf_mat: ShaderMaterial
static var _rim_mat: StandardMaterial3D
static var _bub_mat: StandardMaterial3D
static var _fume_mat: StandardMaterial3D
static var _bub_mesh: SphereMesh
static var _fume_mesh: SphereMesh
static var _pop_curve: Curve
static var _fume_curve: Curve
static var _fume_ramp: Gradient

const SURF_SHADER := "
shader_type spatial;
render_mode blend_mix, cull_disabled;
varying vec3 wp;
void vertex() {
    wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float t = TIME;
    float w1 = sin(wp.x * 1.7 + t * 1.3) * sin(wp.z * 1.9 - t * 1.1);
    float w2 = sin((wp.x + wp.z) * 2.9 + t * 2.1);
    float w3 = sin(wp.x * 0.45 - wp.z * 0.6 + t * 0.7);
    float v = clamp(0.5 + 0.5 * (w1 * 0.45 + w2 * 0.3 + w3 * 0.25), 0.0, 1.0);
    vec3 deep = vec3(0.10, 0.40, 0.04);
    vec3 bright = vec3(0.50, 0.98, 0.14);
    vec3 c = mix(deep, bright, v);
    ALBEDO = c;
    ROUGHNESS = 0.08;
    SPECULAR = 0.8;
    EMISSION = c * (0.42 + 0.38 * v + 0.14 * sin(t * 1.4 + wp.x * 0.3 + wp.z * 0.2));
    ALPHA = 0.95;
}
"

static func _init_res() -> void:
    if _ready_res:
        return
    _ready_res = true
    var sh := Shader.new()
    sh.code = SURF_SHADER
    _surf_mat = ShaderMaterial.new()
    _surf_mat.shader = sh

    _rim_mat = StandardMaterial3D.new()
    _rim_mat.albedo_color = Color(0.06, 0.11, 0.045)
    _rim_mat.roughness = 0.35
    _rim_mat.metallic_specular = 0.6
    _rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

    _bub_mat = StandardMaterial3D.new()
    _bub_mat.albedo_color = Color(0.62, 1.0, 0.4, 0.78)
    _bub_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _bub_mat.roughness = 0.05
    _bub_mat.emission_enabled = true
    _bub_mat.emission = Color(0.5, 1.0, 0.18)
    _bub_mat.emission_energy_multiplier = 1.1
    _bub_mesh = SphereMesh.new()
    _bub_mesh.radius = 0.13
    _bub_mesh.height = 0.26
    _bub_mesh.radial_segments = 8
    _bub_mesh.rings = 4
    _bub_mesh.material = _bub_mat

    _fume_mat = StandardMaterial3D.new()
    _fume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _fume_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _fume_mat.vertex_color_use_as_albedo = true
    _fume_mat.albedo_color = Color(1, 1, 1, 1)
    _fume_mat.disable_receive_shadows = true
    _fume_mesh = SphereMesh.new()
    _fume_mesh.radius = 0.5
    _fume_mesh.height = 1.0
    _fume_mesh.radial_segments = 8
    _fume_mesh.rings = 4
    _fume_mesh.material = _fume_mat

    # бульбашка повільно надувається й різко лопається в кінці життя
    _pop_curve = Curve.new()
    _pop_curve.add_point(Vector2(0.0, 0.15))
    _pop_curve.add_point(Vector2(0.75, 1.0))
    _pop_curve.add_point(Vector2(0.93, 1.3))
    _pop_curve.add_point(Vector2(1.0, 0.0))
    _fume_curve = Curve.new()
    _fume_curve.add_point(Vector2(0.0, 0.4))
    _fume_curve.add_point(Vector2(1.0, 1.7))
    _fume_ramp = Gradient.new()
    _fume_ramp.set_color(0, Color(0.5, 1.0, 0.3, 0.0))
    _fume_ramp.set_color(1, Color(0.5, 1.0, 0.3, 0.0))
    _fume_ramp.add_point(0.3, Color(0.55, 1.0, 0.32, 0.17))

static func _poly_area(p: PackedVector2Array) -> float:
    var s := 0.0
    var n := p.size()
    for k in range(n):
        var a := p[k]
        var b := p[(k + 1) % n]
        s += a.x * b.y - b.x * a.y
    return absf(s) * 0.5

static func _mesh_from(verts2: PackedVector2Array, idx: PackedInt32Array, y: float) -> ArrayMesh:
    var v := PackedVector3Array()
    var nrm := PackedVector3Array()
    v.resize(verts2.size())
    nrm.resize(verts2.size())
    for k in range(verts2.size()):
        v[k] = Vector3(verts2[k].x, y, verts2[k].y)
        nrm[k] = Vector3.UP
    # Godot: лицьова сторона — за годинниковою стрілкою (дивлячись зверху), тож розвертаємо «неправильні» трикутники
    var ids := PackedInt32Array()
    ids.resize(idx.size())
    var t := 0
    while t + 2 < idx.size():
        var a := idx[t]
        var b := idx[t + 1]
        var c := idx[t + 2]
        var cr := (v[b] - v[a]).cross(v[c] - v[a])
        if cr.y > 0.0:
            var tmp := b
            b = c
            c = tmp
        ids[t] = a
        ids[t + 1] = b
        ids[t + 2] = c
        t += 3
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = v
    arr[Mesh.ARRAY_NORMAL] = nrm
    arr[Mesh.ARRAY_INDEX] = ids
    var m := ArrayMesh.new()
    m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return m

func _ready() -> void:
    _init_res()
    if poly.size() < 3 or tri.size() < 3:
        return

    # темний вологий край: той самий контур, трохи розширений, нижче поверхні
    var rims: Array = Geometry2D.offset_polygon(poly, 0.55, Geometry2D.JOIN_ROUND)
    var rim := PackedVector2Array()
    var best := -1.0
    for rp in rims:
        var ar := _poly_area(rp)
        if ar > best:
            best = ar
            rim = rp
    if rim.size() >= 3:
        var rtri := Geometry2D.triangulate_polygon(rim)
        if not rtri.is_empty():
            var rmi := MeshInstance3D.new()
            rmi.mesh = _mesh_from(rim, rtri, 0.045)
            rmi.material_override = _rim_mat
            rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(rmi)

    var mi := MeshInstance3D.new()
    mi.mesh = _mesh_from(poly, tri, 0.07)
    mi.material_override = _surf_mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

    # точки на поверхні, звідки йдуть бульбашки й випари
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var lo := Vector2(1.0e9, 1.0e9)
    var hi := Vector2(-1.0e9, -1.0e9)
    for p in poly:
        lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
        hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
    var c := (lo + hi) * 0.5
    var want := clampi(int(area * 0.45), 4, 30)
    var pts := PackedVector3Array()
    var tries := 0
    while pts.size() < want and tries < want * 14:
        tries += 1
        var q := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
        if Geometry2D.is_point_in_polygon(q, poly):
            pts.append(Vector3(q.x - c.x, 0.0, q.y - c.y))
    if pts.is_empty():
        return

    var b := CPUParticles3D.new()
    b.position = Vector3(c.x, 0.1, c.y)
    b.amount = pts.size()
    b.lifetime = 1.7
    b.preprocess = 1.7
    b.lifetime_randomness = 0.6
    b.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
    b.emission_points = pts
    b.direction = Vector3.UP
    b.spread = 25.0
    b.gravity = Vector3.ZERO
    b.initial_velocity_min = 0.08
    b.initial_velocity_max = 0.4
    b.scale_amount_min = 0.5
    b.scale_amount_max = 1.7
    b.scale_amount_curve = _pop_curve
    b.mesh = _bub_mesh
    b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(b)

    # великі водойми ще й димлять легкою їдкою хмаркою
    if area > 14.0:
        var f := CPUParticles3D.new()
        f.position = Vector3(c.x, 0.2, c.y)
        f.amount = clampi(int(area * 0.1), 3, 10)
        f.lifetime = 3.4
        f.preprocess = 3.4
        f.lifetime_randomness = 0.4
        f.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
        f.emission_points = pts
        f.direction = Vector3.UP
        f.spread = 14.0
        f.gravity = Vector3.ZERO
        f.initial_velocity_min = 0.3
        f.initial_velocity_max = 0.65
        f.scale_amount_min = 0.7
        f.scale_amount_max = 1.5
        f.scale_amount_curve = _fume_curve
        f.color_ramp = _fume_ramp
        f.mesh = _fume_mesh
        f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(f)
