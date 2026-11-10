extends Node3D
# Вогняна куля «Стихії вогню».
# Фаза 1 (ріст): над героєм виростає куля (до діаметра 2 м), тримається в повітрі й розгойдується; триває grow_time (~1 с на 1-му рівні).
# Фаза 2 (постріл): летить у найближчого ворога перед героєм і вибухає: усі в радіусі blast_r (6 м) отримують повний урон.

const Util = preload("res://util.gd")
const Fx = preload("res://effects.gd")

# ---- параметри, які задає player.gd ----
var damage := 700.0
var knock := 14.0
var weapon_id := ""
var crit_chance := 0.0
var speed := 30.0
var blast_r := 6.0            # радіус вибуху, м
var orb_r := 1.0              # радіус кулі (діаметр 2 м)
var aim_dir := Vector3(0, 0, -1)
var reach := 18.0
var grow_time := 1.0
var owner_player = null
var hover := Vector3(0.0, 3.3, 0.0)

var _t := 0.0
var _phase := 0
var _dir := Vector3(0, 0, -1)
var _target = null
var _life := 1.6
var _body: Node3D
var _flames: CPUParticles3D
var _light: OmniLight3D

static var _glow_tex: GradientTexture2D

static func _ensure_tex() -> void:
    if _glow_tex != null:
        return
    _glow_tex = GradientTexture2D.new()
    _glow_tex.fill = GradientTexture2D.FILL_RADIAL
    _glow_tex.fill_from = Vector2(0.5, 0.5)
    _glow_tex.fill_to = Vector2(1.0, 0.5)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
    _glow_tex.gradient = g
    _glow_tex.width = 64
    _glow_tex.height = 64

func _sphere(r: float, col: Color, energy: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 20
    sm.rings = 10
    mi.mesh = sm
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, col.a)
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi

func _ready() -> void:
    _ensure_tex()
    _body = Node3D.new()
    add_child(_body)
    # розжарене ядро, помаранчева оболонка й широке сяйво (разом куля діаметром 2 м)
    _body.add_child(_sphere(orb_r * 0.55, Color(1.0, 0.97, 0.7, 1.0), 1.0))
    _body.add_child(_sphere(orb_r * 0.8, Color(1.0, 0.65, 0.15, 0.7), 1.0))
    _body.add_child(_sphere(orb_r, Color(1.0, 0.32, 0.05, 0.45), 1.0))
    # язики полум'я навколо кулі
    var fm := QuadMesh.new()
    fm.size = Vector2(0.9, 0.9) * (orb_r / 0.5)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    mat.vertex_color_use_as_albedo = true
    mat.albedo_texture = _glow_tex
    fm.material = mat
    _flames = CPUParticles3D.new()
    _flames.amount = 26
    _flames.lifetime = 0.55
    _flames.local_coords = false
    _flames.mesh = fm
    _flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    _flames.emission_sphere_radius = orb_r * 0.7
    _flames.direction = Vector3.UP
    _flames.spread = 70.0
    _flames.initial_velocity_min = 0.3
    _flames.initial_velocity_max = 1.1
    _flames.gravity = Vector3(0.0, 1.5, 0.0)
    _flames.angle_min = -180.0
    _flames.angle_max = 180.0
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 1.0))
    curve.add_point(Vector2(1.0, 0.2))
    _flames.scale_amount_curve = curve
    var ramp := Gradient.new()
    ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.55, 0.8), Color(1.0, 0.5, 0.1, 0.6), Color(0.5, 0.05, 0.0, 0.0)])
    ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    _flames.color_ramp = ramp
    _flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_flames)
    _flames.emitting = true
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.5, 0.15)
    _light.omni_range = 12.0
    _light.light_energy = 1.0
    _light.shadow_enabled = false
    add_child(_light)
    _body.scale = Vector3.ONE * 0.05
    _place_hover()

func _place_hover() -> void:
    var base := global_position
    if owner_player != null and is_instance_valid(owner_player):
        base = owner_player.global_position
    global_position = base + hover

func _physics_process(delta: float) -> void:
    _t += delta
    if _phase == 0:
        _place_hover()
        var k := clampf(_t / grow_time, 0.0, 1.0)
        var s := 1.0 - pow(1.0 - k, 2.0)
        var pulse := 1.0 + 0.06 * sin(_t * 18.0)
        _body.scale = Vector3.ONE * maxf(0.05, s * pulse)
        _light.light_energy = 0.4 + 1.6 * s
        if k >= 1.0:
            _begin_fly()
        return
    _fly(delta)

func _begin_fly() -> void:
    _phase = 1
    _body.scale = Vector3.ONE
    var best = null
    var best_d := 1.0e9
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z) or z.dying:
            continue
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        var d := to.length()
        if d > reach:
            continue
        if d > 0.6 and aim_dir.angle_to(to) > 0.65:
            continue
        if d < best_d:
            best_d = d
            best = z
    _target = best
    if _target != null:
        _dir = (_target_point() - global_position).normalized()
    else:
        _dir = (aim_dir + Vector3(0.0, -0.35, 0.0)).normalized()
    Sfx.play_at("fire", global_position, -4.0, 0.8)

func _target_point() -> Vector3:
    var z = _target
    return z.global_position + Vector3(0.0, 0.9 * float(z.size), 0.0)

func _fly(delta: float) -> void:
    if _target != null:
        if not is_instance_valid(_target) or not _target.is_in_group("attackable") or _target.dying:
            _target = null
        else:
            var want: Vector3 = (_target_point() - global_position).normalized()
            _dir = _dir.lerp(want, 1.0 - exp(-12.0 * delta)).normalized()
    elif position.y > 1.0:
        _dir = (_dir + Vector3(0.0, -1.2 * delta, 0.0)).normalized()
    position += _dir * speed * delta
    _life -= delta
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z) or z.dying:
            continue
        var dx: float = z.global_position.x - global_position.x
        var dz: float = z.global_position.z - global_position.z
        var rr: float = float(z.radius) + orb_r
        if dx * dx + dz * dz < rr * rr and global_position.y < 2.6 * float(z.size) + 0.4:
            _explode()
            return
    if _life <= 0.0 or position.y <= 0.35:
        _explode()

# Вибух: усі зомбі в радіусі blast_r (по землі) отримують повний урон і відлітають від центру.
func _explode() -> void:
    var parent := get_parent()
    var c := Vector3(global_position.x, maxf(global_position.y, 0.4), global_position.z)
    Fx.explosion(parent, c, blast_r, Color(1.0, 0.45, 0.08))
    Fx.explosion(parent, c, blast_r * 0.6, Color(1.0, 0.85, 0.3))
    Fx.burst(parent, c, Color(1.0, 0.6, 0.15), 40, 10.0, 0.16)
    Sfx.play_at("explosion", c, 0.0, 0.85)
    var lv = get_tree().current_scene
    if lv != null and "shake" in lv:
        lv.shake = maxf(float(lv.shake), 0.5)
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z) or z.dying:
            continue
        var to: Vector3 = z.global_position - c
        to.y = 0.0
        if to.length() <= blast_r + float(z.radius):
            var d := damage
            var crit := randf() < crit_chance
            if crit:
                d *= 2.0
            z.take_damage(d, to, knock, crit, weapon_id)
    queue_free()
