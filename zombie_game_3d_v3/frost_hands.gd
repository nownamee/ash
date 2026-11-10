extends Node3D
# Рука в морозі («Стихія морозу»): у кулаці немає предмета. Над рукою висить і повільно клубочиться холодний туман,
# навколо кружляють дрібні крижинки. Прикріплюється до правої (у руці зі зброєю) і лівої руки героя.
# pulse() — сплеск туману й стрибок розміру в момент атаки.

static var _fog_mesh: QuadMesh
static var _fog_ramp: Gradient
static var _fog_curve: Curve
static var _flake_mesh: BoxMesh
static var _flake_ramp: Gradient

var _fog: CPUParticles3D
var _burst: CPUParticles3D
var _flakes: Array = []
var _phase: Array = []
var _speed: Array = []
var _t := 0.0
var _kick := 0.0
var radius := 0.22
var count := 4

static func _ensure() -> void:
    if _fog_mesh != null:
        return
    # м'яка кругла плямка (без чітких країв), щоб туман виглядав димчастим
    var tex := GradientTexture2D.new()
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
    tex.gradient = g
    tex.width = 64
    tex.height = 64
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = tex
    m.no_depth_test = false
    m.disable_receive_shadows = true
    _fog_mesh = QuadMesh.new()
    _fog_mesh.size = Vector2(0.5, 0.5)
    _fog_mesh.material = m
    _fog_ramp = Gradient.new()
    _fog_ramp.colors = PackedColorArray([Color(0.85, 0.96, 1.0, 0.0), Color(0.78, 0.93, 1.0, 0.55), Color(0.55, 0.82, 1.0, 0.3), Color(0.45, 0.75, 1.0, 0.0)])
    _fog_ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.65, 1.0])
    _fog_curve = Curve.new()
    _fog_curve.add_point(Vector2(0.0, 0.5))
    _fog_curve.add_point(Vector2(1.0, 1.4))
    _flake_mesh = BoxMesh.new()
    _flake_mesh.size = Vector3(0.035, 0.035, 0.11)
    var fm := StandardMaterial3D.new()
    fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fm.albedo_color = Color(0.85, 0.97, 1.0)
    fm.emission_enabled = true
    fm.emission = Color(0.6, 0.9, 1.0)
    fm.emission_energy_multiplier = 1.6
    _flake_mesh.material = fm

func _make_fog(amount: int, life: float, one_shot: bool) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.one_shot = one_shot
    p.local_coords = false
    p.mesh = _fog_mesh
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.11
    p.direction = Vector3.UP
    p.spread = 60.0
    p.initial_velocity_min = 0.05
    p.initial_velocity_max = 0.28
    p.gravity = Vector3(0.0, 0.18, 0.0)         # туман повільно здіймається над рукою
    p.damping_min = 0.15
    p.damping_max = 0.4
    p.angle_min = -180.0
    p.angle_max = 180.0
    p.angular_velocity_min = -30.0
    p.angular_velocity_max = 30.0
    p.scale_amount_min = 0.7
    p.scale_amount_max = 1.3
    p.scale_amount_curve = _fog_curve
    p.color_ramp = _fog_ramp
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

func _ready() -> void:
    _ensure()
    # постійний туман над кулаком
    _fog = _make_fog(16, 1.6, false)
    _fog.position = Vector3(0.0, 0.1, 0.0)
    add_child(_fog)
    _fog.emitting = true
    # сплеск при атаці
    _burst = _make_fog(10, 0.9, true)
    _burst.explosiveness = 0.9
    _burst.initial_velocity_min = 0.3
    _burst.initial_velocity_max = 0.9
    _burst.spread = 120.0
    _burst.position = Vector3(0.0, 0.12, 0.0)
    add_child(_burst)
    # дрібні крижинки, що кружляють над рукою
    for i in range(count):
        var m := MeshInstance3D.new()
        m.mesh = _flake_mesh
        m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(m)
        _flakes.append(m)
        _phase.append(TAU * float(i) / float(count))
        _speed.append(2.2 + 0.7 * float(i % 3))

func pulse() -> void:
    _kick = 1.0
    if _burst != null:
        _burst.restart()
        _burst.emitting = true

func _process(delta: float) -> void:
    _t += delta
    _kick = maxf(0.0, _kick - delta * 6.0)
    scale = Vector3.ONE * (1.0 + 0.35 * _kick)
    for i in range(_flakes.size()):
        var a: float = float(_phase[i]) + _t * float(_speed[i])
        var r := radius * (1.0 + 0.2 * sin(_t * 3.0 + float(i)))
        var p := Vector3(cos(a) * r, 0.12 + 0.07 * sin(a * 1.7 + float(i)), sin(a) * r)
        var f := _flakes[i] as Node3D
        f.position = p
        f.rotation = Vector3(_t * 2.0 + float(i), _t * 1.5, float(i))
