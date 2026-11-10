extends Node3D
# Водяна кулька «Стихії води».
# Фаза 1 (підйом): кулька виринає з руки й швидко злітає вгору, злегка похитуючись.
# Фаза 2 (політ): на вершині вибирає ціль перед героєм і стрімко пікірує в неї (трохи самонаводиться).
# Влучання: урон + сповільнення ворога на slow_secs, бризки й водяне кільце.

const Util = preload("res://util.gd")

# ---- параметри, які задає player.gd ----
var damage := 110.0
var knock := 3.0
var weapon_id := ""
var crit_chance := 0.0
var slow_secs := 1.0
var slow_mult := 0.5          # швидкість ворога під сповільненням (0.5 = вдвічі повільніше)
var speed := 26.0
var aim_dir := Vector3(0, 0, -1)
var reach := 16.0             # дальність пошуку цілі
var rise_time := 0.16
var rise_height := 1.25
var side := 1.0               # з якої руки вилетіла (-1 ліва, +1 права)

var _t := 0.0
var _phase := 0               # 0 — підйом, 1 — політ
var _start := Vector3.ZERO
var _top := Vector3.ZERO
var _dir := Vector3(0, 0, -1)
var _target = null
var _life := 1.6
var _core: MeshInstance3D
var _orbit: Node3D
var _trail: CPUParticles3D
var _wob := 0.0

static var _water_mat: ShaderMaterial
static var _drop_mat: StandardMaterial3D
static var _drop_mesh: SphereMesh
static var _drop_ramp: Gradient

const WATER_SHADER := "
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform vec4 deep_col : source_color = vec4(0.02, 0.30, 0.78, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.60, 0.92, 1.0, 1.0);
uniform float wobble = 0.022;
uniform float alpha_base = 0.55;
varying float v_rip;
void vertex() {
	float r = sin(VERTEX.y * 11.0 + TIME * 13.0) * sin(VERTEX.x * 9.0 - TIME * 10.0 + VERTEX.z * 6.0);
	VERTEX += NORMAL * r * wobble;
	v_rip = r;
}
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 c = mix(deep_col.rgb, shallow_col.rgb, clamp(f * 0.9 + v_rip * 0.12, 0.0, 1.0));
	ALBEDO = c;
	ALPHA = clamp(alpha_base + f * 0.4, 0.0, 0.95);
	ROUGHNESS = 0.03;
	SPECULAR = 1.0;
	METALLIC = 0.15;
	EMISSION = c * 0.45 + vec3(0.7, 0.95, 1.0) * pow(f, 2.0) * 0.8;
}
"

# Спільний матеріал води (один на всю гру).
static func water_material() -> ShaderMaterial:
    if _water_mat == null:
        var sh := Shader.new()
        sh.code = WATER_SHADER
        _water_mat = ShaderMaterial.new()
        _water_mat.shader = sh
    return _water_mat

static func _ensure_drops() -> void:
    if _drop_mat != null:
        return
    _drop_mat = StandardMaterial3D.new()
    _drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _drop_mat.vertex_color_use_as_albedo = true
    _drop_mesh = SphereMesh.new()
    _drop_mesh.radius = 0.055
    _drop_mesh.height = 0.11
    _drop_mesh.radial_segments = 8
    _drop_mesh.rings = 4
    _drop_mesh.material = _drop_mat
    _drop_ramp = Gradient.new()
    _drop_ramp.colors = PackedColorArray([Color(0.80, 0.97, 1.0, 0.95), Color(0.30, 0.65, 1.0, 0.7), Color(0.10, 0.45, 1.0, 0.0)])
    _drop_ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])

static func _shrink_curve() -> Curve:
    var c := Curve.new()
    c.add_point(Vector2(0.0, 1.0))
    c.add_point(Vector2(1.0, 0.15))
    return c

func _ready() -> void:
    _ensure_drops()
    _start = position
    var perp := Vector3(-aim_dir.z, 0.0, aim_dir.x).normalized() * side
    _top = _start + Vector3(0.0, rise_height, 0.0) + perp * 0.22 + aim_dir * 0.15
    _wob = randf() * TAU

    # ядро — прозора хвиляста вода
    _core = MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.27
    sm.height = 0.54
    sm.radial_segments = 24
    sm.rings = 14
    _core.mesh = sm
    _core.material_override = water_material()
    _core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_core)

    # блік (відбиток світла на поверхні краплі)
    var hl := MeshInstance3D.new()
    var hm := SphereMesh.new()
    hm.radius = 0.06
    hm.height = 0.12
    hl.mesh = hm
    var hmat := StandardMaterial3D.new()
    hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hmat.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
    hl.material_override = hmat
    hl.position = Vector3(-0.1, 0.13, 0.1)
    hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _core.add_child(hl)

    # маленькі краплі, що кружляють навколо ядра
    _orbit = Node3D.new()
    add_child(_orbit)
    for i in range(3):
        var d := MeshInstance3D.new()
        var dm := SphereMesh.new()
        dm.radius = 0.07 - 0.012 * float(i)
        dm.height = dm.radius * 2.0
        dm.radial_segments = 12
        dm.rings = 6
        d.mesh = dm
        d.material_override = water_material()
        var a := TAU * float(i) / 3.0
        d.position = Vector3(cos(a) * 0.4, sin(a * 2.0) * 0.12, sin(a) * 0.4)
        d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _orbit.add_child(d)

    # прохолодне світло
    var l := OmniLight3D.new()
    l.light_color = Color(0.4, 0.75, 1.0)
    l.omni_range = 3.5
    l.light_energy = 0.9
    l.shadow_enabled = false
    add_child(l)

    # шлейф із крапель
    _trail = CPUParticles3D.new()
    _trail.amount = 22
    _trail.lifetime = 0.38
    _trail.local_coords = false
    _trail.mesh = _drop_mesh
    _trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    _trail.emission_sphere_radius = 0.16
    _trail.direction = Vector3.ZERO
    _trail.spread = 180.0
    _trail.initial_velocity_min = 0.2
    _trail.initial_velocity_max = 0.9
    _trail.gravity = Vector3(0.0, -5.0, 0.0)
    _trail.scale_amount_min = 0.6
    _trail.scale_amount_max = 1.3
    _trail.scale_amount_curve = _shrink_curve()
    _trail.color_ramp = _drop_ramp
    _trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_trail)
    _trail.emitting = true

    scale = Vector3.ONE * 0.25

func _physics_process(delta: float) -> void:
    _t += delta
    _orbit.rotation.y += 9.0 * delta
    _orbit.rotation.x = sin(_t * 7.0 + _wob) * 0.5
    # «жива» вода: ядро пульсує
    var pulse := 1.0 + 0.08 * sin(_t * 26.0 + _wob)
    _core.scale = Vector3(pulse, 1.0 / pulse, pulse)

    if _phase == 0:
        var k := clampf(_t / rise_time, 0.0, 1.0)
        var e := 1.0 - pow(1.0 - k, 3.0)          # швидкий старт, плавне гальмування нагорі
        var p := _start.lerp(_top, e)
        var perp := Vector3(-aim_dir.z, 0.0, aim_dir.x).normalized() * side
        p += perp * sin(k * PI) * 0.12
        position = p
        scale = Vector3.ONE * lerpf(0.25, 1.0, minf(1.0, k * 1.6))
        if k >= 1.0:
            _begin_fly()
        return

    _fly(delta)

func _begin_fly() -> void:
    _phase = 1
    scale = Vector3.ONE
    # ціль: найближчий ворог у конусі перед героєм
    var best = null
    var best_d := 1.0e9
    for z in get_tree().get_nodes_in_group("attackable"):
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        var d := to.length()
        if d > reach:
            continue
        if d > 0.6 and aim_dir.angle_to(to) > 0.6:
            continue
        if d < best_d:
            best_d = d
            best = z
    _target = best
    if _target != null:
        _dir = (_target_point() - global_position).normalized()
    else:
        _dir = (aim_dir + Vector3(0.0, -0.28, 0.0)).normalized()
    Sfx.play_at("throw", global_position, -12.0, 1.4 + randf() * 0.3)

func _target_point() -> Vector3:
    var z = _target
    return z.global_position + Vector3(0.0, 1.0 * float(z.size), 0.0)

func _fly(delta: float) -> void:
    if _target != null:
        if not is_instance_valid(_target) or not _target.is_in_group("attackable"):
            _target = null
        else:
            var want: Vector3 = (_target_point() - global_position).normalized()
            _dir = _dir.lerp(want, 1.0 - exp(-12.0 * delta)).normalized()
    elif position.y > 1.0:
        _dir = (_dir + Vector3(0.0, -0.9 * delta, 0.0)).normalized()
    position += _dir * speed * delta
    if position.y < 0.5:
        position.y = 0.5
    _life -= delta

    var flat_dir := Vector3(_dir.x, 0.0, _dir.z)
    if flat_dir.length() < 0.01:
        flat_dir = aim_dir
    for z in get_tree().get_nodes_in_group("attackable"):
        var dx: float = z.global_position.x - global_position.x
        var dz: float = z.global_position.z - global_position.z
        var reach_r: float = float(z.radius) + 0.4
        if dx * dx + dz * dz < reach_r * reach_r and global_position.y < 2.6 * float(z.size) + 0.4:
            _hit(z, flat_dir)
            return
    if _life <= 0.0 or position.y <= 0.52:
        splash(get_parent(), Vector3(global_position.x, 0.1, global_position.z), 0.6)
        queue_free()

func _hit(z, flat_dir: Vector3) -> void:
    var d := damage
    var crit := randf() < crit_chance
    if crit:
        d *= 2.0
    z.take_damage(d, flat_dir, knock, crit, weapon_id)
    if z.has_method("apply_slow"):
        z.apply_slow(slow_secs, slow_mult)
    splash(get_parent(), global_position, 1.0)
    Sfx.play_at("zhit", global_position, -6.0, 1.6)
    queue_free()

# Бризки + водяне кільце на землі.
static func splash(parent: Node, pos: Vector3, size_f: float) -> void:
    _ensure_drops()
    var p := CPUParticles3D.new()
    p.amount = int(20.0 * size_f) + 6
    p.lifetime = 0.55
    p.one_shot = true
    p.explosiveness = 1.0
    p.mesh = _drop_mesh
    p.direction = Vector3.UP
    p.spread = 70.0
    p.initial_velocity_min = 2.5
    p.initial_velocity_max = 6.0 * size_f
    p.gravity = Vector3(0.0, -15.0, 0.0)
    p.scale_amount_min = 0.7
    p.scale_amount_max = 1.5
    p.scale_amount_curve = _shrink_curve()
    p.color_ramp = _drop_ramp
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = pos
    parent.add_child(p)
    p.emitting = true
    parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.86
    tm.outer_radius = 1.0
    tm.rings = 20
    tm.ring_segments = 6
    ring.mesh = tm
    var rm := StandardMaterial3D.new()
    rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rm.albedo_color = Color(0.55, 0.88, 1.0, 0.85)
    ring.material_override = rm
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ring.position = Vector3(pos.x, 0.08, pos.z)
    ring.scale = Vector3(0.3, 0.3, 0.3)
    parent.add_child(ring)
    var tw := ring.create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(1.0, 0.5, 1.0) * 1.7 * size_f, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tw.tween_property(rm, "albedo_color:a", 0.0, 0.38)
    tw.chain().tween_callback(ring.queue_free)
