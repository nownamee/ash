extends Node3D
# Бурулька «Посоху зими».
# Фаза 1 (ріст): над героєм поступово «виростає» бурулька вістрям униз, а в кінці розвертається до цілі.
# Фаза 2 (постріл): стрімко летить у найближчого ворога перед героєм.
# Влучання: урон + повна заморожувальна «шкаралупа» на freeze_secs, осколки льоду.

const Util = preload("res://util.gd")

# ---- параметри, які задає player.gd ----
var damage := 220.0
var knock := 2.0
var weapon_id := ""
var crit_chance := 0.0
var freeze_secs := 1.0
var freeze_chance := 1.0          # шанс заморозити при влучанні
var freeze_chance_boss := 1.0     # шанс заморозити боса
var speed := 34.0
var aim_dir := Vector3(0, 0, -1)
var reach := 18.0             # дальність пошуку цілі
var grow_time := 0.5
var owner_player = null       # бурулька висить над героєм, поки росте
var hover := Vector3(0.0, 2.5, 0.0)   # зсув над героєм (у світових координатах)

var _t := 0.0
var _phase := 0               # 0 — ріст, 1 — політ
var _dir := Vector3(0, 0, -1)
var _target = null
var _life := 1.4
var _body: Node3D
var _perp := Vector3.RIGHT
var _glint := 0.0

static var _ice_mat: ShaderMaterial
static var _shell_mat: ShaderMaterial
static var _shard_mat: StandardMaterial3D
static var _shard_mesh: BoxMesh
static var _shard_ramp: Gradient

const ICE_SHADER := "
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform vec4 deep_col : source_color = vec4(0.30, 0.66, 0.95, 1.0);
uniform vec4 light_col : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float alpha_base = 0.62;
void fragment() {
	// плоскі грані: нормаль береться з похідних позиції, тож лід виглядає гранчастим кристалом
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, normalize(VIEW)) < 0.0) { n = -n; }
	float f = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 1.8);
	vec3 c = mix(deep_col.rgb, light_col.rgb, f);
	float sp = 0.5 + 0.5 * sin(TIME * 5.0 + VERTEX.y * 28.0 + VERTEX.x * 17.0);
	ALBEDO = c;
	ALPHA = clamp(alpha_base + f * 0.35, 0.0, 0.96);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	NORMAL = n;
	EMISSION = c * 0.35 + vec3(0.5, 0.85, 1.0) * f * 0.7 + vec3(0.6, 0.9, 1.0) * sp * 0.06;
}
"

static func _make_ice(alpha: float) -> ShaderMaterial:
    var sh := Shader.new()
    sh.code = ICE_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    m.set_shader_parameter("alpha_base", alpha)
    return m

# Спільний матеріал льоду (бурульки, посох).
static func ice_material() -> ShaderMaterial:
    if _ice_mat == null:
        _ice_mat = _make_ice(0.62)
    return _ice_mat

# Прозоріша «крижана шкаралупа» для замороженого ворога.
static func shell_material() -> ShaderMaterial:
    if _shell_mat == null:
        _shell_mat = _make_ice(0.34)
    return _shell_mat

static func _ensure_shards() -> void:
    if _shard_mat != null:
        return
    _shard_mat = StandardMaterial3D.new()
    _shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _shard_mat.vertex_color_use_as_albedo = true
    _shard_mesh = BoxMesh.new()
    _shard_mesh.size = Vector3(0.05, 0.05, 0.16)
    _shard_mesh.material = _shard_mat
    _shard_ramp = Gradient.new()
    _shard_ramp.colors = PackedColorArray([Color(0.95, 1.0, 1.0, 1.0), Color(0.60, 0.88, 1.0, 0.85), Color(0.35, 0.7, 1.0, 0.0)])
    _shard_ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])

static func _shrink_curve() -> Curve:
    var c := Curve.new()
    c.add_point(Vector2(0.0, 1.0))
    c.add_point(Vector2(1.0, 0.2))
    return c

# Один гранчастий кристал: конус, повернутий вістрям уздовж -Z.
static func _crystal(parent: Node3D, r: float, len_: float, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = r
    cm.height = len_
    cm.radial_segments = 6
    cm.rings = 1
    var mi := MeshInstance3D.new()
    mi.mesh = cm
    mi.material_override = ice_material()
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = pos
    mi.rotation_degrees = rot_deg + Vector3(-90.0, 0.0, 0.0)
    parent.add_child(mi)
    return mi

func _ready() -> void:
    _ensure_shards()
    _perp = Vector3(-aim_dir.z, 0.0, aim_dir.x).normalized()
    if _perp.length() < 0.1:
        _perp = Vector3.RIGHT
    _body = Node3D.new()
    add_child(_body)
    # головна бурулька + дві менші, що ростуть поруч (кластер кристалів)
    _crystal(_body, 0.10, 1.0, Vector3(0, 0, -0.5), Vector3.ZERO)
    _crystal(_body, 0.055, 0.6, Vector3(0.09, 0.03, -0.3), Vector3(0, 6, 0))
    _crystal(_body, 0.05, 0.5, Vector3(-0.08, -0.03, -0.25), Vector3(0, -7, 0))
    # світний серцевинний промінь усередині
    var core := MeshInstance3D.new()
    var km := CylinderMesh.new()
    km.top_radius = 0.0
    km.bottom_radius = 0.03
    km.height = 0.85
    km.radial_segments = 5
    core.mesh = km
    var cmat := StandardMaterial3D.new()
    cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    cmat.albedo_color = Color(0.85, 0.97, 1.0, 0.55)
    core.material_override = cmat
    core.position = Vector3(0, 0, -0.45)
    core.rotation_degrees = Vector3(-90, 0, 0)
    core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _body.add_child(core)

    var l := OmniLight3D.new()
    l.light_color = Color(0.55, 0.85, 1.0)
    l.omni_range = 3.5
    l.light_energy = 0.8
    l.shadow_enabled = false
    add_child(l)

    # іскри-крижинки навколо
    var tr := CPUParticles3D.new()
    tr.amount = 18
    tr.lifetime = 0.45
    tr.local_coords = false
    tr.mesh = _shard_mesh
    tr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    tr.emission_sphere_radius = 0.18
    tr.direction = Vector3.ZERO
    tr.spread = 180.0
    tr.initial_velocity_min = 0.1
    tr.initial_velocity_max = 0.6
    tr.gravity = Vector3(0.0, -2.0, 0.0)
    tr.scale_amount_min = 0.4
    tr.scale_amount_max = 0.9
    tr.scale_amount_curve = _shrink_curve()
    tr.color_ramp = _shard_ramp
    tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(tr)
    tr.emitting = true

    _body.scale = Vector3.ONE * 0.05
    _place_hover()
    _orient(_hang_dir())

func _hang_dir() -> Vector3:
    return (aim_dir * 0.3 + Vector3(0.0, -1.0, 0.0)).normalized()

func _place_hover() -> void:
    var base := global_position
    if owner_player != null and is_instance_valid(owner_player):
        base = owner_player.global_position
    global_position = base + hover

func _orient(d: Vector3) -> void:
    if d.length() < 0.001:
        return
    look_at(global_position + d, _perp)

func _physics_process(delta: float) -> void:
    _t += delta
    if _phase == 0:
        _place_hover()
        var k := clampf(_t / grow_time, 0.0, 1.0)
        # ріст із невеликим «пружинним» перельотом
        var g := 1.0 - pow(1.0 - minf(k * 1.25, 1.0), 3.0)
        var s := g * (1.0 + 0.08 * sin(minf(k * 1.25, 1.0) * PI))
        _body.scale = Vector3.ONE * maxf(0.05, s)
        # легке погойдування й розворот до прицілу наприкінці
        var turn := clampf((k - 0.65) / 0.35, 0.0, 1.0)
        turn = turn * turn * (3.0 - 2.0 * turn)
        var d := _hang_dir().lerp(aim_dir, turn).normalized()
        d = (d + _perp * sin(_t * 9.0) * 0.04 * (1.0 - turn)).normalized()
        _orient(d)
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
        _dir = (aim_dir + Vector3(0.0, -0.3, 0.0)).normalized()
    Sfx.play_at("throw", global_position, -10.0, 1.7 + randf() * 0.3)

func _target_point() -> Vector3:
    var z = _target
    return z.global_position + Vector3(0.0, 1.0 * float(z.size), 0.0)

func _fly(delta: float) -> void:
    if _target != null:
        if not is_instance_valid(_target) or not _target.is_in_group("attackable"):
            _target = null
        else:
            var want: Vector3 = (_target_point() - global_position).normalized()
            _dir = _dir.lerp(want, 1.0 - exp(-14.0 * delta)).normalized()
    elif position.y > 1.0:
        _dir = (_dir + Vector3(0.0, -0.9 * delta, 0.0)).normalized()
    position += _dir * speed * delta
    _orient(_dir)
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
    if _life <= 0.0 or position.y <= 0.3:
        shatter(get_parent(), Vector3(global_position.x, maxf(global_position.y, 0.15), global_position.z), 0.6)
        queue_free()

func _hit(z, flat_dir: Vector3) -> void:
    var d := damage
    var crit := randf() < crit_chance
    if crit:
        d *= 2.0
    z.take_damage(d, flat_dir, knock, crit, weapon_id)
    if z.has_method("apply_freeze"):
        # заморожує лише з шансом (на босів шанс значно менший)
        var is_boss := false
        var zd: Variant = z.get("data")
        if zd is Dictionary:
            is_boss = bool(zd.get("boss", false))
        var chance := freeze_chance_boss if is_boss else freeze_chance
        if randf() < chance:
            z.apply_freeze(freeze_secs)
    shatter(get_parent(), global_position, 1.0)
    Sfx.play_at("freeze", global_position, -4.0)
    queue_free()

# Розліт крижаних осколків і холодна хмарка.
static func shatter(parent: Node, pos: Vector3, size_f: float) -> void:
    _ensure_shards()
    var p := CPUParticles3D.new()
    p.amount = int(22.0 * size_f) + 6
    p.lifetime = 0.65
    p.one_shot = true
    p.explosiveness = 1.0
    p.mesh = _shard_mesh
    p.direction = Vector3.UP
    p.spread = 120.0
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 6.5 * size_f
    p.gravity = Vector3(0.0, -13.0, 0.0)
    p.angular_velocity_min = -540.0
    p.angular_velocity_max = 540.0
    p.scale_amount_min = 0.7
    p.scale_amount_max = 1.8
    p.scale_amount_curve = _shrink_curve()
    p.color_ramp = _shard_ramp
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = pos
    parent.add_child(p)
    p.emitting = true
    parent.get_tree().create_timer(1.1).timeout.connect(p.queue_free)
