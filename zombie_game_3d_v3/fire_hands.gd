extends Node3D
# Рука, що горить («Стихія вогню»): у кулаці немає предмета. Над ним танцює полум'я, злітають жарини.
# Прикріплюється до правої (у руці зі зброєю) і лівої руки героя. pulse() — спалах у момент атаки.

static var _flame_mesh: QuadMesh
static var _flame_ramp: Gradient
static var _flame_curve: Curve
static var _ember_mesh: BoxMesh
static var _ember_ramp: Gradient

var _flame: CPUParticles3D
var _embers: CPUParticles3D
var _burst: CPUParticles3D
var _light: OmniLight3D
var _kick := 0.0
var _t := 0.0

static func _ensure() -> void:
    if _flame_mesh != null:
        return
    var tex := GradientTexture2D.new()
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
    tex.gradient = g
    tex.width = 64
    tex.height = 64
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = tex
    m.disable_receive_shadows = true
    _flame_mesh = QuadMesh.new()
    _flame_mesh.size = Vector2(0.34, 0.34)
    _flame_mesh.material = m
    _flame_ramp = Gradient.new()
    _flame_ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.85, 0.35, 0.9), Color(1.0, 0.45, 0.08, 0.6), Color(0.6, 0.1, 0.0, 0.0)])
    _flame_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
    _flame_curve = Curve.new()
    _flame_curve.add_point(Vector2(0.0, 1.0))
    _flame_curve.add_point(Vector2(1.0, 0.25))
    _ember_mesh = BoxMesh.new()
    _ember_mesh.size = Vector3(0.03, 0.03, 0.03)
    var em := StandardMaterial3D.new()
    em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    em.vertex_color_use_as_albedo = true
    _ember_mesh.material = em
    _ember_ramp = Gradient.new()
    _ember_ramp.colors = PackedColorArray([Color(1.0, 0.9, 0.4, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.7, 0.1, 0.0, 0.0)])
    _ember_ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

func _make(amount: int, life: float, one_shot: bool, flame: bool) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.one_shot = one_shot
    p.local_coords = false
    p.mesh = _flame_mesh if flame else _ember_mesh
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = 0.09
    p.direction = Vector3.UP
    p.spread = 25.0 if flame else 55.0
    p.initial_velocity_min = 0.25 if flame else 0.4
    p.initial_velocity_max = 0.7 if flame else 1.1
    p.gravity = Vector3(0.0, 0.9 if flame else 0.3, 0.0)
    p.scale_amount_min = 0.8
    p.scale_amount_max = 1.4
    if flame:
        p.angle_min = -180.0
        p.angle_max = 180.0
        p.scale_amount_curve = _flame_curve
        p.color_ramp = _flame_ramp
    else:
        p.color_ramp = _ember_ramp
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

func _ready() -> void:
    _ensure()
    _flame = _make(22, 0.7, false, true)
    _flame.position = Vector3(0.0, 0.08, 0.0)
    add_child(_flame)
    _flame.emitting = true
    _embers = _make(8, 1.1, false, false)
    _embers.position = Vector3(0.0, 0.1, 0.0)
    add_child(_embers)
    _embers.emitting = true
    _burst = _make(14, 0.6, true, true)
    _burst.explosiveness = 0.95
    _burst.initial_velocity_min = 0.6
    _burst.initial_velocity_max = 1.6
    _burst.spread = 90.0
    _burst.position = Vector3(0.0, 0.1, 0.0)
    add_child(_burst)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.55, 0.2)
    _light.light_energy = 0.9
    _light.omni_range = 3.0
    _light.shadow_enabled = false
    _light.position = Vector3(0.0, 0.15, 0.0)
    add_child(_light)

func pulse() -> void:
    _kick = 1.0
    if _burst != null:
        _burst.restart()
        _burst.emitting = true

func _process(delta: float) -> void:
    _t += delta
    _kick = maxf(0.0, _kick - delta * 6.0)
    scale = Vector3.ONE * (1.0 + 0.45 * _kick)
    if _light != null:
        _light.light_energy = 0.9 + 0.25 * sin(_t * 17.0) + 1.2 * _kick
