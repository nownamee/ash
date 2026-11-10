extends Node3D
# Синє полум'я «Вогняної коси».
#  - статичні помічники: make_flame() — частинки синього вогню (на лезі коси й на палаючих зомбі), burn_flame() — вогонь для зомбі;
#  - сам вузол — вогняна ХВИЛЯ від удару коси: не навколо героя, а лише ВПЕРЕД по прямій від удару. Вогняний фронт динамічно
#    просувається на length (7 м) за WAVE_TIME секунд і по дорозі розростається вбік (клин: від вузького біля коси до широкого
#    на кінці). Кожен зомбі отримує шкоду один раз, коли фронт до нього доходить. Хвиля НЕ підпалює (підпалює лише сама коса).

const WEAPON_ID := "fire_scythe"
const WAVE_TIME := 0.55            # за скільки секунд фронт пробігає всю довжину
const FADE_TIME := 0.35            # скільки ще догорає після того, як фронт дійшов до кінця
const START_HALF := 0.45           # півширина вогню біля коси, м
const END_HALF := 3.8              # півширина вогню на кінці (на повній довжині), м
const COLS := 18                   # скільки «язиків» по ширині має рваний край вогню
const ROWS := 8                    # скільки поперечних поділок по довжині

static var _flame_mesh: QuadMesh
static var _flame_ramp: Gradient
static var _flame_curve: Curve
static var _ring_mat: StandardMaterial3D

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
    _flame_ramp.colors = PackedColorArray([Color(0.85, 0.97, 1.0, 0.0), Color(0.45, 0.85, 1.0, 0.9), Color(0.12, 0.4, 1.0, 0.6), Color(0.0, 0.05, 0.5, 0.0)])
    _flame_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
    _flame_curve = Curve.new()
    _flame_curve.add_point(Vector2(0.0, 1.0))
    _flame_curve.add_point(Vector2(1.0, 0.25))
    _ring_mat = StandardMaterial3D.new()
    _ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _ring_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.85)
    _ring_mat.disable_receive_shadows = true

# Частинки синього вогню. scale_f — розмір язиків; r — радіус зони появи.
static func make_flame(amount: int, life: float, r: float, scale_f: float = 1.0, one_shot: bool = false) -> CPUParticles3D:
    _ensure()
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.one_shot = one_shot
    p.local_coords = false
    p.mesh = _flame_mesh
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = r
    p.direction = Vector3.UP
    p.spread = 25.0
    p.initial_velocity_min = 0.3
    p.initial_velocity_max = 0.9
    p.gravity = Vector3(0.0, 1.1, 0.0)
    p.scale_amount_min = 0.8 * scale_f
    p.scale_amount_max = 1.4 * scale_f
    p.angle_min = -180.0
    p.angle_max = 180.0
    p.scale_amount_curve = _flame_curve
    p.color_ramp = _flame_ramp
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

# Вогонь на палаючому зомбі (розмір підганяється під зріст).
static func burn_flame(size: float) -> CPUParticles3D:
    var p := make_flame(9, 0.65, 0.32 * size, 1.5 * size)
    p.position = Vector3(0.0, 0.95 * size, 0.0)
    p.emitting = true
    return p

# ---------- Вогняна хвиля ----------
var player
var length := 7.0        # на скільки метрів вогонь просувається вперед
var dir := Vector3(0.0, 0.0, -1.0)
var dmg := 0.0
var knock := 8.0
var _t := 0.0
var _front := 0.0
var _hit: Array = []
var _mesh: ImmediateMesh
var _mesh_inst: MeshInstance3D
var _mesh_mat: StandardMaterial3D
var _body: CPUParticles3D     # вогонь, що заливає вже пройдену ділянку
var _head: CPUParticles3D     # язики на самому фронті
var _light: OmniLight3D
var _seed := 0.0

# півширина вогню на відстані s від початку: чим далі, тим ширше (трохи прискорюється)
func _half_at(s: float) -> float:
    var k := clampf(s / maxf(length, 0.01), 0.0, 1.0)
    return lerpf(START_HALF, END_HALF, pow(k, 1.15))

# Скільки «не дотягує» вогонь на поперечній позиції u (-1..1): рваний край з язиками; чим ближче кінець, тим рванiший.
func _jag(u: float) -> float:
    var amp := 0.38 * smoothstep(0.35, 1.0, _front / maxf(length, 0.01))
    var n := sin(u * 7.3 + _seed + _t * 9.0) * 0.5 + sin(u * 17.0 - _seed * 1.7 - _t * 13.0) * 0.3 + sin(u * 3.1 + _seed * 0.6 + _t * 5.0) * 0.2
    var tongue := absf(n)                           # 0..1: гострі язики
    var rim := pow(absf(u), 3.0) * 0.45             # крайні язики коротші — форма заокруглюється
    return clampf(amp * tongue + rim * smoothstep(0.2, 1.0, _front / maxf(length, 0.01)), 0.0, 0.85)

# довжина вогню на поперечній позиції u
func _front_at(u: float) -> float:
    return _front * (1.0 - _jag(u))

func _ready() -> void:
    _ensure()
    _seed = randf() * 100.0
    rotation.y = atan2(-dir.x, -dir.z)      # вісь -Z вузла дивиться в бік удару
    _mesh = ImmediateMesh.new()
    _mesh_inst = MeshInstance3D.new()
    _mesh_inst.mesh = _mesh
    _mesh_mat = StandardMaterial3D.new()
    _mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _mesh_mat.vertex_color_use_as_albedo = true
    _mesh_mat.disable_receive_shadows = true
    _mesh_inst.material_override = _mesh_mat
    _mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _mesh_inst.position = Vector3(0.0, 0.07, 0.0)
    add_child(_mesh_inst)
    # основний вогонь: багато язиків, що піднімаються й мерехтять
    _body = make_flame(260, 0.7, 0.5, 2.6)
    _body.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _body.emission_box_extents = Vector3(START_HALF, 0.05, 0.1)
    _body.direction = Vector3.UP
    _body.spread = 28.0
    _body.initial_velocity_min = 0.6
    _body.initial_velocity_max = 2.4
    _body.gravity = Vector3(0.0, 2.2, 0.0)
    _body.position = Vector3(0.0, 0.1, 0.0)
    add_child(_body)
    _body.emitting = true
    # язики й іскри на фронті — вищі й жвавіші
    _head = make_flame(110, 0.5, 0.5, 3.0)
    _head.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _head.emission_box_extents = Vector3(START_HALF, 0.05, 0.5)
    _head.direction = Vector3.UP
    _head.spread = 40.0
    _head.initial_velocity_min = 1.2
    _head.initial_velocity_max = 3.4
    _head.gravity = Vector3(0.0, 3.0, 0.0)
    _head.position = Vector3(0.0, 0.2, 0.0)
    add_child(_head)
    _head.emitting = true
    _light = OmniLight3D.new()
    _light.light_color = Color(0.35, 0.65, 1.0)
    _light.omni_range = 7.0
    _light.light_energy = 1.6
    _light.shadow_enabled = false
    _light.position = Vector3(0.0, 0.8, 0.0)
    add_child(_light)

# Сітка вогню: по ширині COLS стовпчиків, кожен має власну довжину (рваний край), у центрі яскравіше, до країв і до кінчиків прозоріше.
func _rebuild_mesh(alpha: float) -> void:
    _mesh.clear_surfaces()
    if _front <= 0.02:
        return
    _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for c in range(COLS):
        var u0 := -1.0 + 2.0 * float(c) / float(COLS)
        var u1 := -1.0 + 2.0 * float(c + 1) / float(COLS)
        var f0 := _front_at(u0)
        var f1 := _front_at(u1)
        for r in range(ROWS):
            var a0 := float(r) / float(ROWS)
            var a1 := float(r + 1) / float(ROWS)
            var s00 := f0 * a0
            var s01 := f0 * a1
            var s10 := f1 * a0
            var s11 := f1 * a1
            var p00 := Vector3(u0 * _half_at(s00), 0.0, -s00)
            var p01 := Vector3(u0 * _half_at(s01), 0.0, -s01)
            var p10 := Vector3(u1 * _half_at(s10), 0.0, -s10)
            var p11 := Vector3(u1 * _half_at(s11), 0.0, -s11)
            var c00 := _col(u0, a0, alpha)
            var c01 := _col(u0, a1, alpha)
            var c10 := _col(u1, a0, alpha)
            var c11 := _col(u1, a1, alpha)
            _tri(p00, c00, p01, c01, p10, c10)
            _tri(p10, c10, p01, c01, p11, c11)
    _mesh.surface_end()

func _col(u: float, a: float, alpha: float) -> Color:
    var centre := 1.0 - absf(u)
    var tip := 1.0 - pow(a, 2.2) * 0.85           # до кінчика язика тьмяніє
    var k := alpha * (0.15 + 0.85 * centre) * tip
    # біле-блакитне гаряче ядро в центрі, синій край
    var hot := Color(0.75, 0.95, 1.0, 0.6 * k)
    var cool := Color(0.1, 0.35, 1.0, 0.35 * k)
    return cool.lerp(hot, clampf(centre * 1.3 - a * 0.3, 0.0, 1.0))

func _tri(a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
    _mesh.surface_set_color(ca)
    _mesh.surface_add_vertex(a)
    _mesh.surface_set_color(cb)
    _mesh.surface_add_vertex(b)
    _mesh.surface_set_color(cc)
    _mesh.surface_add_vertex(c)

func _process(delta: float) -> void:
    _t += delta
    var k := clampf(_t / WAVE_TIME, 0.0, 1.0)
    var e := 1.0 - pow(1.0 - k, 1.6)            # рвучкий старт, до кінця трохи сповільнюється
    _front = length * e
    var fade := 1.0
    if _t > WAVE_TIME:
        fade = clampf(1.0 - (_t - WAVE_TIME) / FADE_TIME, 0.0, 1.0)
    _rebuild_mesh(fade)
    # вогонь заливає пройдену ділянку й розростається вбік разом із фронтом
    var h := _half_at(_front)
    _body.emission_box_extents = Vector3(h * 0.9, 0.05, maxf(_front * 0.45, 0.1))
    _body.position = Vector3(0.0, 0.1, -_front * 0.5)
    _head.emission_box_extents = Vector3(h * 0.85, 0.05, 0.6)
    _head.position = Vector3(0.0, 0.2, -maxf(_front - 0.6, 0.0))
    _light.position = Vector3(0.0, 0.8, -_front * 0.6)
    _light.light_energy = 1.6 * fade
    if _t >= WAVE_TIME:
        _body.emitting = false
        _head.emitting = false
    # шкода: хто опинився у зоні, яку фронт уже пройшов (з урахуванням рваного краю) — отримує удар (один раз)
    if _t <= WAVE_TIME + 0.02 and player != null and is_instance_valid(player):
        var fwd := Vector3(dir.x, 0.0, dir.z).normalized()
        var side := Vector3(-fwd.z, 0.0, fwd.x)
        var here := global_position
        for z in get_tree().get_nodes_in_group("zombies"):
            if not is_instance_valid(z) or _hit.has(z):
                continue
            var to: Vector3 = z.global_position - here
            to.y = 0.0
            var s := to.dot(fwd)
            var lat := to.dot(side)
            if s + z.radius < 0.0:
                continue
            var hw: float = _half_at(clampf(s, 0.0, length)) + z.radius
            if absf(lat) > hw:
                continue
            var u := clampf(lat / maxf(_half_at(clampf(s, 0.0, length)), 0.01), -1.0, 1.0)
            if s - z.radius <= _front_at(u):
                _hit.append(z)
                player.wave_hit(z, dmg, knock, fwd * maxf(to.length(), 0.1))
    if _t >= WAVE_TIME + FADE_TIME + 0.2:
        queue_free()
