extends Node3D
# Живий вогонь («Пожежа») довільної форми: лінія, дуга, пляма або розсип. Форма задана ланцюжком кіл pts = [[x, z, r], ...]
# (локальні координати від вузла). Без підкладки й темних кіл: лише високі язики полум'я, що танцюють у шейдері,
# хмара вогняних частинок, іскри, м'яке тепле сяйво на землі й миготливе світло. Шкоду рахує level.gd (terrain.in_fire).
# Параметри (pts, seed_v) задайте до add_child().

const FlickerLight = preload("res://light_flicker.gd")

var pts: Array = []
var seed_v := 1

static var _ready_res := false
static var _tongue_mat: ShaderMaterial
static var _glow_mat: ShaderMaterial
static var _tongue_mesh: CylinderMesh
static var _glow_mesh: CylinderMesh
static var _flame_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D
static var _quad: QuadMesh
static var _blob: GradientTexture2D

const TONGUE_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
varying float h;
void vertex() {
    h = clamp(VERTEX.y + 0.5, 0.0, 1.0);
    vec3 wp = MODEL_MATRIX[3].xyz;
    float ph = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
    float t = TIME;
    float pulse = 1.0 + 0.32 * sin(t * 7.0 + ph) + 0.16 * sin(t * 13.0 + ph * 2.3);
    VERTEX.y = h * pulse - 0.5;
    float sway = h * h * 0.7;
    VERTEX.x += sin(t * 4.2 + ph + h * 3.0) * sway;
    VERTEX.z += cos(t * 3.6 + ph * 1.7 + h * 2.5) * sway;
    VERTEX.xz *= 1.0 + 0.2 * sin(t * 9.0 + ph * 0.7 + h * 4.0);
}
void fragment() {
    vec3 hot = vec3(1.0, 0.93, 0.5);
    vec3 mid = vec3(1.0, 0.42, 0.06);
    vec3 cold = vec3(0.6, 0.07, 0.0);
    vec3 c = mix(hot, mid, smoothstep(0.0, 0.5, h));
    c = mix(c, cold, smoothstep(0.45, 1.0, h));
    ALBEDO = c * 1.7;
    ALPHA = clamp((1.0 - h) * 0.9 + 0.04, 0.0, 1.0);
}
"

# Сяйво на землі: ДОДАЄ світло (blend_add), а не затемнює, тож жодної темної плями чи чіткого краю кола.
const GLOW_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
varying vec2 lp;
varying float ph;
void vertex() {
    lp = VERTEX.xz;
    ph = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
}
void fragment() {
    float d = length(lp);
    float f = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
    float fl = 0.6 + 0.25 * sin(TIME * 5.0 + ph) + 0.15 * sin(TIME * 8.3 + ph * 1.9);
    vec3 col = mix(vec3(0.9, 0.2, 0.02), vec3(1.0, 0.62, 0.14), f);
    ALBEDO = col * fl;
    ALPHA = f * 0.75;
}
"

static func _ensure_resources() -> void:
    if _ready_res:
        return
    _ready_res = true

    _tongue_mat = ShaderMaterial.new()
    var ts := Shader.new()
    ts.code = TONGUE_SHADER
    _tongue_mat.shader = ts
    _tongue_mesh = CylinderMesh.new()
    _tongue_mesh.top_radius = 0.0
    _tongue_mesh.bottom_radius = 0.5
    _tongue_mesh.height = 1.0
    _tongue_mesh.radial_segments = 8
    _tongue_mesh.rings = 6
    _tongue_mesh.cap_bottom = false
    _tongue_mesh.material = _tongue_mat

    _glow_mat = ShaderMaterial.new()
    var gs := Shader.new()
    gs.code = GLOW_SHADER
    _glow_mat.shader = gs
    _glow_mesh = CylinderMesh.new()
    _glow_mesh.top_radius = 1.0
    _glow_mesh.bottom_radius = 1.0
    _glow_mesh.height = 0.02
    _glow_mesh.radial_segments = 24
    _glow_mesh.rings = 1
    _glow_mesh.cap_bottom = false
    _glow_mesh.material = _glow_mat

    # м'яка кругла пляма для частинок
    var g := Gradient.new()
    g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
    g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
    _blob = GradientTexture2D.new()
    _blob.gradient = g
    _blob.fill = GradientTexture2D.FILL_RADIAL
    _blob.fill_from = Vector2(0.5, 0.5)
    _blob.fill_to = Vector2(1.0, 0.5)
    _blob.width = 64
    _blob.height = 64

    _flame_mat = _particle_mat()
    _spark_mat = _particle_mat()
    _quad = QuadMesh.new()
    _quad.size = Vector2(1.0, 1.0)

static func _particle_mat() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = _blob
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.billboard_keep_scale = true
    m.disable_receive_shadows = true
    m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    return m

func _ready() -> void:
    if pts.is_empty():
        return
    _ensure_resources()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v

    var total := 0.0
    var lo := Vector2(1.0e9, 1.0e9)
    var hi := Vector2(-1.0e9, -1.0e9)
    var cen := Vector2.ZERO
    for c in pts:
        var r := float(c[2])
        total += r * r
        cen += Vector2(float(c[0]), float(c[1]))
        lo = Vector2(minf(lo.x, float(c[0]) - r), minf(lo.y, float(c[1]) - r))
        hi = Vector2(maxf(hi.x, float(c[0]) + r), maxf(hi.y, float(c[1]) + r))
    cen /= float(pts.size())
    var box := AABB(Vector3(lo.x - 3.0, -1.0, lo.y - 3.0), Vector3(hi.x - lo.x + 6.0, 16.0, hi.y - lo.y + 6.0))
    var avg_r := sqrt(total / float(pts.size()))

    _add_glow()
    _add_tongues(rng, box)
    add_child(_make_particles(rng, box, true, total, avg_r))
    add_child(_make_particles(rng, box, false, total, avg_r))
    _add_lights(cen, hi - lo)

# Тепле сяйво на землі під кожним колом ланцюжка: одна MultiMesh, без темної підкладки.
func _add_glow() -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _glow_mesh
    mm.instance_count = pts.size()
    for i in range(pts.size()):
        var c: Array = pts[i]
        var r := float(c[2]) * 1.9
        mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), Vector3(float(c[0]), 0.08, float(c[1]))))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)

# Високі язики полум'я вздовж усієї форми: рух (пульсація, коливання) рахує шейдер, тож це майже безкоштовно.
func _add_tongues(rng: RandomNumberGenerator, box: AABB) -> void:
    var xfs: Array = []
    for c in pts:
        var r := float(c[2])
        var n := clampi(int(r * 1.5) + 1, 2, 6)
        for k in range(n):
            var ang := rng.randf() * TAU
            var rad := sqrt(rng.randf()) * r * 0.85
            var hgt := rng.randf_range(2.0, 4.4) * (0.75 + r * 0.12)
            var wid := rng.randf_range(0.8, 1.6) * (0.7 + r * 0.16)
            var b := Basis.from_scale(Vector3(wid, hgt, wid))
            xfs.append(Transform3D(b, Vector3(float(c[0]) + cos(ang) * rad, hgt * 0.5 + 0.06, float(c[1]) + sin(ang) * rad)))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _tongue_mesh
    mm.instance_count = xfs.size()
    for i in range(xfs.size()):
        mm.set_instance_transform(i, xfs[i])
    mm.custom_aabb = box
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)

# Точки появи частинок: випадкові місця всередині кіл форми (більші кола — частіше).
func _spawn_texture(rng: RandomNumberGenerator, n: int, total: float) -> ImageTexture:
    var img := Image.create_empty(n, 1, false, Image.FORMAT_RGBF)
    for k in range(n):
        var roll := rng.randf() * total
        var acc := 0.0
        var pick: Array = pts[0]
        for c in pts:
            acc += float(c[2]) * float(c[2])
            if roll <= acc:
                pick = c
                break
        var ang := rng.randf() * TAU
        var rd := sqrt(rng.randf()) * float(pick[2]) * 0.9
        img.set_pixel(k, 0, Color(float(pick[0]) + cos(ang) * rd, 0.1, float(pick[1]) + sin(ang) * rd))
    return ImageTexture.create_from_image(img)

# Частинки вогню (flames = true: м'які спалахи, що піднімаються й хвилюються) або іскор (дрібні яскраві точки).
func _make_particles(rng: RandomNumberGenerator, box: AABB, flames: bool, total: float, avg_r: float) -> GPUParticles3D:
    var p := GPUParticles3D.new()
    var n := 128
    if flames:
        p.amount = clampi(int(total * 1.6), 36, 170)
        p.lifetime = 1.35
    else:
        p.amount = clampi(int(total * 0.7), 12, 50)
        p.lifetime = 2.0
    p.preprocess = p.lifetime
    p.visibility_aabb = box
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var m := ParticleProcessMaterial.new()
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
    m.emission_point_texture = _spawn_texture(rng, n, total)
    m.emission_point_count = n
    m.direction = Vector3.UP
    m.angle_min = -180.0
    m.angle_max = 180.0
    var gr := Gradient.new()
    if flames:
        m.spread = 16.0
        m.initial_velocity_min = 1.8
        m.initial_velocity_max = 3.8 + avg_r * 0.3
        m.gravity = Vector3(0, 2.4, 0)
        m.damping_min = 0.2
        m.damping_max = 0.7
        m.scale_min = 1.3 + avg_r * 0.1
        m.scale_max = 2.6 + avg_r * 0.2
        var sc := Curve.new()
        sc.add_point(Vector2(0.0, 0.55))
        sc.add_point(Vector2(0.25, 1.0))
        sc.add_point(Vector2(1.0, 0.0))
        var sct := CurveTexture.new()
        sct.curve = sc
        m.scale_curve = sct
        gr.offsets = PackedFloat32Array([0.0, 0.1, 0.38, 0.72, 1.0])
        gr.colors = PackedColorArray([
            Color(1.0, 0.95, 0.55, 0.0), Color(1.0, 0.88, 0.38, 0.95), Color(1.0, 0.48, 0.07, 0.85),
            Color(0.85, 0.16, 0.02, 0.5), Color(0.25, 0.03, 0.0, 0.0)])
        m.turbulence_enabled = true
        m.turbulence_noise_strength = 1.8
        m.turbulence_noise_scale = 1.3
        m.turbulence_noise_speed = Vector3(0.0, -1.4, 0.0)
        m.turbulence_influence_min = 0.04
        m.turbulence_influence_max = 0.14
        p.material_override = _flame_mat
    else:
        m.spread = 38.0
        m.initial_velocity_min = 3.0
        m.initial_velocity_max = 7.5
        m.gravity = Vector3(0, 0.6, 0)
        m.damping_min = 0.4
        m.damping_max = 1.0
        m.scale_min = 0.10
        m.scale_max = 0.26
        gr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
        gr.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.6, 0.15, 1.0), Color(0.9, 0.2, 0.03, 0.0)])
        m.turbulence_enabled = true
        m.turbulence_noise_strength = 3.2
        m.turbulence_noise_scale = 2.0
        m.turbulence_noise_speed = Vector3(0.6, -1.0, 0.4)
        m.turbulence_influence_min = 0.1
        m.turbulence_influence_max = 0.3
        p.material_override = _spark_mat
    var grt := GradientTexture1D.new()
    grt.gradient = gr
    m.color_ramp = grt
    p.process_material = m
    p.draw_pass_1 = _quad
    return p

# Миготливе світло: одне на компактну форму, дві-три — вздовж довгої лінії.
func _add_lights(cen: Vector2, ext: Vector2) -> void:
    var spots: Array = []
    var longest := maxf(ext.x, ext.y)
    if longest < 14.0 or pts.size() < 6:
        spots.append(cen)
    else:
        var n := 2 if longest < 24.0 else 3
        for k in range(n):
            var c: Array = pts[int(float(pts.size() - 1) * (float(k) + 0.5) / float(n))]
            spots.append(Vector2(float(c[0]), float(c[1])))
    for sp in spots:
        var lamp: OmniLight3D = FlickerLight.new()
        lamp.light_color = Color(1.0, 0.48, 0.16)
        lamp.light_energy = 3.6
        lamp.omni_range = 11.0 + minf(longest, 24.0) * 0.25
        lamp.speed = 11.0
        lamp.amount = 0.38
        lamp.position = Vector3(sp.x, 2.2, sp.y)
        add_child(lamp)
