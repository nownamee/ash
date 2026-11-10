extends Node3D
# Вулкани «Магмового ядра» (loc23). На карті розкидано багато невеликих вулканів із кам'яної породи; по схилах від жерла стікає магма.
# Вулкани різної висоти (від HEIGHT_MIN до HEIGHT_MAX) стоять не ближче MIN_DIST один до одного (див. layout).
# Кожен вулкан окремо: коли герой ближче за RANGE метрів, раз на PERIOD секунд він вивергається:
#  1) на землі навколо героя (де він був) з'являється ЧЕРВОНА ЗОНА (радіус ZONE_R) — це попередження;
#  2) із жерла злітають магмові бомби й падають у випадкові точки зони; кожна має свій маркер на землі та летить FLIGHT секунд;
#  3) бомба, що впала, вибухає (радіус BOMB_R) і б'є героя, якщо він у вибуху. Зомбі магма не шкодить (як і вогонь на землі).
# Урон бомби = максимальне здоров'я героя × dmg_pct (до броні). Level виставляє dmg_pct = FIRE_DMG_PCT × MAGMA_DMG_MULT
# (магма в 5 разів сильніша за опік від вогняних полів). Гора має колізію (шар 4), тож гравець і зомбі її обходять.
# Розмір вулкана (height, base_r, top_r, collide_r) виставляє level.gd із layout() ДО add_child.

const MagmaMaterial = preload("res://magma_material.gd")
const Util = preload("res://util.gd")
const Fx = preload("res://effects.gd")

signal erupting

const HEIGHT_MIN := 5.0            # найнижчий вулкан, м
const HEIGHT_MAX := 12.0           # найвищий вулкан, м
const COUNT := 10                  # скільки вулканів на карті
const MIN_DIST := 42.0             # мінімальна відстань між вулканами, м (не менше 40)
const START_CLEAR := 52.0          # біля замку (центр карти) вулканів немає
const EDGE_GAP := 14.0             # відступ від краю арени

const RANGE := 40.0               # у цьому радіусі вулкан стріляє по герою, м
const PERIOD := 15.0               # пауза між пострілами одного вулкана, с
const FIRST_MIN := 3.0             # перший постріл після початку бою: у кожного свій, щоб не вивергались хором
const FIRST_MAX := 11.0
const ZONE_R := 8.0                # радіус червоної зони, у яку падають бомби
const BOMB_COUNT := 7
const BOMB_R := 2.6                # радіус вибуху однієї бомби
const LAUNCH_DELAY := 0.9          # коли злітає перша бомба після появи зони
const LAUNCH_STEP := 0.12          # інтервал між бомбами
const FLIGHT := 1.7                # політ бомби, с
const SEGS := 24                   # граней по колу
const ROWS := 9                    # ярусів по висоті

var height := 12.0                 # висота гори, м
var base_r := 8.0                  # радіус підніжжя, м
var top_r := 2.4                   # радіус жерла, м
var collide_r := 5.5               # радіус колізії (гора конічна, тож менший за підніжжя)
var shape_seed := 1
var player
var level
var dmg_pct := 1.0                 # частка максимального здоров'я за влучання (виставляє level.gd)

var _timer := 10.0
var _zone_t := -1.0                # скільки триває поточне виверження (-1: немає)
var _zone: Node3D
var _zone_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _bombs: Array = []
var _light: OmniLight3D
var _t := 0.0
var _blast: CPUParticles3D

static var _flame_mesh: QuadMesh
static var _flame_ramp: Gradient
static var _flame_curve: Curve
static var _smoke_mesh: QuadMesh
static var _smoke_ramp: Gradient

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
    _flame_mesh.size = Vector2(2.4, 2.4)
    _flame_mesh.material = m
    _flame_ramp = Gradient.new()
    _flame_ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.8, 0.3, 0.9), Color(1.0, 0.35, 0.05, 0.6), Color(0.5, 0.05, 0.0, 0.0)])
    _flame_ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
    _flame_curve = Curve.new()
    _flame_curve.add_point(Vector2(0.0, 0.7))
    _flame_curve.add_point(Vector2(1.0, 1.4))
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    sm.vertex_color_use_as_albedo = true
    sm.albedo_texture = tex
    sm.disable_receive_shadows = true
    _smoke_mesh = QuadMesh.new()
    _smoke_mesh.size = Vector2(5.0, 5.0)
    _smoke_mesh.material = sm
    _smoke_ramp = Gradient.new()
    _smoke_ramp.colors = PackedColorArray([Color(0.25, 0.1, 0.05, 0.0), Color(0.18, 0.14, 0.13, 0.55), Color(0.08, 0.07, 0.07, 0.0)])
    _smoke_ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])

# Розставляє вулкани по всій арені: «найкраща з кількох кандидатів» дає рівномірний розсип, відстань між центрами >= MIN_DIST.
# Висоти різні: вони розтягнуті від HEIGHT_MIN до HEIGHT_MAX і перемішані. Повертає [{pos: Vector3, height, base_r, top_r, collide_r, seed}].
static func layout(arena_r: float, count: int = COUNT) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var out: Array = []
    var heights: Array = []
    for i in range(count):
        heights.append(lerpf(HEIGHT_MIN, HEIGHT_MAX, float(i) / maxf(1.0, float(count - 1))) + rng.randf_range(-0.4, 0.4))
    # перемішуємо, щоб високі й низькі чергувались по карті
    for i in range(heights.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = heights[i]
        heights[i] = heights[j]
        heights[j] = tmp
    var max_r := arena_r - EDGE_GAP
    for i in range(count):
        var best := Vector2.ZERO
        var best_d := -1.0
        var found := false
        for k in range(40):
            var ang := rng.randf() * TAU
            var rr := sqrt(rng.randf_range(START_CLEAR * START_CLEAR, max_r * max_r))
            var c := Vector2(cos(ang), sin(ang)) * rr
            var md := 100000.0
            for o in out:
                var op: Vector3 = o["pos"]
                md = minf(md, c.distance_to(Vector2(op.x, op.z)))
            if md < MIN_DIST:
                continue
            if md > best_d:
                best_d = md
                best = c
                found = true
        if not found:
            continue
        var h: float = float(heights[i])
        var br := h * 0.62 + 1.0
        out.append({"pos": Vector3(best.x, 0.0, best.y), "height": h, "base_r": br, "top_r": br * rng.randf_range(0.27, 0.34), "collide_r": br * 0.66, "seed": rng.randi()})
    return out

# Точка всередині підніжжя будь-якого вулкана виштовхується за його межу (щоб зомбі не з'являлись у горі).
static func push_out(list: Array, pos: Vector3) -> Vector3:
    for v in list:
        var vp: Vector3 = (v as Node3D).position
        var vr: float = float(v.base_r) + 1.0
        var d := Vector2(pos.x - vp.x, pos.z - vp.z)
        if d.length() < vr:
            var dir := Vector2.RIGHT
            if d.length() > 0.01:
                dir = d.normalized()
            return Vector3(vp.x + dir.x * (vr + 1.0), pos.y, vp.z + dir.y * (vr + 1.0))
    return pos

func _particles(amount: int, life: float, smoke: bool, one_shot: bool = false) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.one_shot = one_shot
    p.local_coords = false
    p.mesh = _smoke_mesh if smoke else _flame_mesh
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    p.emission_sphere_radius = top_r * 0.6
    p.direction = Vector3.UP
    p.spread = 18.0 if not one_shot else 35.0
    p.initial_velocity_min = 2.5 if smoke else 3.0
    p.initial_velocity_max = 5.0 if smoke else 7.0
    p.gravity = Vector3(0.0, 1.2 if smoke else 0.5, 0.0)
    p.angle_min = -180.0
    p.angle_max = 180.0
    p.scale_amount_curve = _flame_curve
    p.color_ramp = _smoke_ramp if smoke else _flame_ramp
    var ps := clampf(top_r / 4.5, 0.35, 1.0)
    p.scale_amount_min = ps
    p.scale_amount_max = ps
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p

# --- Кам'яна гора ---
var _noise: FastNoiseLite
var _pts: Array = []               # вершини схилу: _pts[ярус][грань]

# Радіус схилу на висоті t (0 — підніжжя, 1 — жерло): розлогий низ і крутіший верх.
func _prof(t: float) -> float:
    return top_r + (base_r - top_r) * pow(1.0 - t, 1.55)

func _surface(seg: int, row: int) -> Vector3:
    var t := float(row) / float(ROWS)
    var a := TAU * float(seg) / float(SEGS)
    var n := _noise.get_noise_3d(cos(a) * 3.0, sin(a) * 3.0, t * 4.0)
    var r := _prof(t) * (1.0 + 0.20 * n * (1.0 - 0.55 * t))
    var y := t * height - (0.25 if row == 0 else 0.0) + _noise.get_noise_3d(cos(a) * 7.0 + 40.0, sin(a) * 7.0, t * 9.0) * height * 0.025
    return Vector3(cos(a) * r, y, sin(a) * r)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, out_dir: Vector3) -> void:
    var n := (b - a).cross(c - a)
    if n.length() < 0.00001:
        return
    n = n.normalized()
    var nn := n
    if n.dot(out_dir) < 0.0:
        nn = -n
    # у Godot лицьова сторона — за годинниковою стрілкою: нормаль, що дивиться назовні, відповідає (b-a)x(c-a), спрямованому всередину
    if n.dot(nn) > 0.0:
        var tmp := b
        b = c
        c = tmp
    for v in [a, b, c]:
        st.set_normal(nn)
        st.set_color(col)
        st.add_vertex(v)

func _rock_color(seg: int, row: int) -> Color:
    var t := float(row) / float(ROWS)
    var n := _noise.get_noise_3d(float(seg) * 1.7, float(row) * 2.3, 11.0)
    var base := Color(0.20, 0.17, 0.15).lerp(Color(0.31, 0.26, 0.22), clampf(0.5 + n, 0.0, 1.0))
    # біля підніжжя породу присипає темний попіл; біля жерла вона обпалена до чорного з червонуватим відблиском
    base = base.lerp(Color(0.09, 0.07, 0.06), clampf(t - 0.55, 0.0, 1.0) * 1.4)
    if t > 0.8:
        base = base.lerp(Color(0.34, 0.11, 0.05), (t - 0.8) * 2.0)
    return base

func _build_rock() -> void:
    _noise = FastNoiseLite.new()
    _noise.seed = shape_seed
    _noise.frequency = 1.0
    _noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _pts = []
    for row in range(ROWS + 1):
        var ring: Array = []
        for seg in range(SEGS):
            ring.append(_surface(seg, row))
        _pts.append(ring)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in range(ROWS):
        for seg in range(SEGS):
            var s2 := (seg + 1) % SEGS
            var p00: Vector3 = _pts[row][seg]
            var p01: Vector3 = _pts[row][s2]
            var p10: Vector3 = _pts[row + 1][seg]
            var p11: Vector3 = _pts[row + 1][s2]
            var mid := (p00 + p11) * 0.5
            var od := Vector3(mid.x, 0.35 * base_r, mid.z)
            var col := _rock_color(seg, row)
            _tri(st, p00, p10, p11, col, od)
            _tri(st, p00, p11, p01, col.darkened(0.08), od)
    # стіни жерла: кільце верхнього краю → нижче всередину
    var inner: Array = []
    for seg in range(SEGS):
        var top: Vector3 = _pts[ROWS][seg]
        inner.append(Vector3(top.x * 0.72, height - 0.18 * base_r - 0.3, top.z * 0.72))
    for seg in range(SEGS):
        var s3 := (seg + 1) % SEGS
        var a1: Vector3 = _pts[ROWS][seg]
        var b1: Vector3 = _pts[ROWS][s3]
        var a2: Vector3 = inner[seg]
        var b2: Vector3 = inner[s3]
        var m := (a1 + b2) * 0.5
        var idir := Vector3(-m.x, 0.7 * base_r, -m.z)
        var col2 := Color(0.12, 0.05, 0.03)
        _tri(st, a1, a2, b2, col2, idir)
        _tri(st, a1, b2, b1, col2, idir)
    var mesh := st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.96
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    add_child(mi)
    # розпечена магма в жерлі
    var lava := Util.cylinder(top_r * 0.70, top_r * 0.70, 0.12)
    var lm := Util.add_mesh(self, lava, Color(1.0, 0.42, 0.06), Vector3(0.0, height - 0.18 * base_r - 0.22, 0.0), Vector3.ZERO, 0.3, 4.0)
    lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _lava_nodes.append(lm)

var _lava_nodes: Array = []
var _lava_mat: StandardMaterial3D

# Потоки магми: смужки, що стікають із краю жерла вниз по схилу, кожна по своєму ряду граней (тож лежать точно на скелі).
func _build_streams() -> void:
    _lava_mat = StandardMaterial3D.new()
    _lava_mat.albedo_color = Color(1.0, 0.38, 0.04)
    _lava_mat.emission_enabled = true
    _lava_mat.emission = Color(1.0, 0.36, 0.03)
    _lava_mat.emission_energy_multiplier = 2.6
    _lava_mat.roughness = 0.35
    _lava_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var rng := RandomNumberGenerator.new()
    rng.seed = shape_seed + 17
    var n_streams := clampi(int(round(base_r * 0.55)), 3, 6)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var ends: Array = []
    for k in range(n_streams):
        var s0 := (int(float(SEGS) * float(k) / float(n_streams)) + rng.randi_range(0, 2)) % SEGS
        var row_end := rng.randi_range(2, ROWS - 3)
        var seg := s0
        var prev_l := Vector3.ZERO
        var prev_r := Vector3.ZERO
        var have_prev := false
        var last_c := Vector3.ZERO
        for row in range(ROWS, row_end - 1, -1):
            if row < ROWS:
                seg = (seg + [-1, 0, 0, 1][rng.randi_range(0, 3)] + SEGS) % SEGS
            var s2 := (seg + 1) % SEGS
            var pa: Vector3 = _pts[row][seg]
            var pb: Vector3 = _pts[row][s2]
            var c := (pa + pb) * 0.5
            var out := Vector3(c.x, 0.0, c.z).normalized()
            c += out * 0.09 + Vector3(0.0, 0.03, 0.0)
            # ширина потоку: від розливу біля краю жерла, звужується донизу
            var f := float(row - row_end) / float(maxi(1, ROWS - row_end))
            var wf := lerpf(0.22, 0.62, f) * (1.0 if row < ROWS else 1.15)
            var half := (pb - pa) * 0.5 * wf
            var l := c - half
            var r := c + half
            if have_prev:
                var md := (prev_l + prev_r + l + r) * 0.25
                var od := Vector3(md.x, 0.35 * base_r, md.z)
                _tri(st, prev_l, prev_r, r, Color.WHITE, od)
                _tri(st, prev_l, r, l, Color.WHITE, od)
            prev_l = l
            prev_r = r
            have_prev = true
            last_c = c
        ends.append(last_c)
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _lava_mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    # застиглі краплі на кінцях потоків
    for e in ends:
        var g := Util.add_mesh(self, Util.sphere(clampf(base_r * 0.07, 0.25, 0.55)), Color(1.0, 0.4, 0.05), e, Vector3.ZERO, 0.3, 3.0)
        g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        g.scale = Vector3(1.0, 0.6, 1.0)

func _ready() -> void:
    _ensure()
    _timer = randf_range(FIRST_MIN, FIRST_MAX)
    _build_rock()
    _build_streams()
    # уламки скелі біля підніжжя
    var rr := RandomNumberGenerator.new()
    rr.seed = shape_seed + 5
    for i in range(6):
        var a := TAU * float(i) / 6.0 + rr.randf() * 0.5
        var r := base_r * rr.randf_range(0.95, 1.2)
        var sz := rr.randf_range(0.5, 1.0) * clampf(base_r * 0.16, 0.7, 1.5)
        Util.add_mesh(self, Util.box(Vector3(sz, sz * 0.8, sz * 1.2)), Color(0.14, 0.11, 0.10), Vector3(cos(a) * r, sz * 0.3, sin(a) * r), Vector3(rr.randf() * 30.0, rr.randf() * 180.0, rr.randf() * 30.0), 0.95, 0.0)
    # колізія (шар 4 — перешкоди)
    var body := StaticBody3D.new()
    body.collision_layer = 4
    body.collision_mask = 0
    var cs := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = collide_r
    cyl.height = height
    cs.shape = cyl
    cs.position = Vector3(0.0, height * 0.5, 0.0)
    body.add_child(cs)
    add_child(body)
    # вогонь і дим із жерла
    var fl := _particles(18, 1.4, false)
    fl.position = Vector3(0.0, height + 0.3, 0.0)
    add_child(fl)
    fl.emitting = true
    var sk := _particles(10, 3.5, true)
    sk.position = Vector3(0.0, height + 1.0, 0.0)
    add_child(sk)
    sk.emitting = true
    # викид при виверженні
    _blast = _particles(50, 1.3, false, true)
    _blast.explosiveness = 0.95
    _blast.initial_velocity_min = 7.0
    _blast.initial_velocity_max = 15.0
    _blast.position = Vector3(0.0, height + 0.3, 0.0)
    add_child(_blast)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.45, 0.12)
    _light.light_energy = 1.4
    _light.omni_range = 12.0 + height * 1.4
    _light.shadow_enabled = false
    _light.position = Vector3(0.0, height + 2.0, 0.0)
    add_child(_light)

func _process(delta: float) -> void:
    _t += delta
    var boost := 0.0
    if _zone_t >= 0.0:
        boost = 1.2
    _light.light_energy = 1.4 + 0.3 * sin(_t * 9.0 + float(shape_seed % 7)) + boost
    if _lava_mat != null:
        _lava_mat.emission_energy_multiplier = 2.4 + 0.7 * sin(_t * 2.2 + float(shape_seed % 5))
    _update_bombs(delta)
    if _zone_t >= 0.0:
        _update_zone(delta)
    # таймер іде лише в живому бою: не під час очікування біля замку, не після смерті
    if level == null or player == null or not is_instance_valid(player) or player.dead:
        return
    if level.castle_wait or level.state != "playing":
        return
    _timer = maxf(0.0, _timer - delta)
    if _zone_t >= 0.0 or _timer > 0.0:
        return
    # вулкан стріляє лише коли герой ближче за RANGE метрів; зарядившись, чекає на нього
    var pp: Vector3 = player.global_position
    if Vector2(pp.x - global_position.x, pp.z - global_position.z).length() > RANGE:
        return
    _erupt()
    _timer = PERIOD

func _erupt() -> void:
    var tp: Vector3 = player.global_position + player.velocity * 1.2    # трохи на випередження
    tp.y = 0.0
    _zone_t = 0.0
    _make_zone(tp)
    # бомби
    for i in range(BOMB_COUNT):
        var ang := randf() * TAU
        var rr := sqrt(randf()) * (ZONE_R - 1.2)
        var land := tp + Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
        _bombs.append({"delay": LAUNCH_DELAY + float(i) * LAUNCH_STEP + randf() * 0.08, "t": -1.0, "to": land, "node": null, "marker": null})
    if _blast != null:
        _blast.restart()
        _blast.emitting = true
    Sfx.play("boss_roar", -6.0, 0.6)
    erupting.emit()

func _disc_mat(col: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.albedo_color = col
    m.disable_receive_shadows = true
    return m

func _make_zone(center: Vector3) -> void:
    _zone = Node3D.new()
    get_parent().add_child(_zone)
    _zone.global_position = center
    var cm := CylinderMesh.new()
    cm.top_radius = ZONE_R
    cm.bottom_radius = ZONE_R
    cm.height = 0.05
    cm.radial_segments = 40
    var disc := MeshInstance3D.new()
    disc.mesh = cm
    _zone_mat = _disc_mat(Color(1.0, 0.12, 0.04, 0.2))
    disc.material_override = _zone_mat
    disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    disc.position = Vector3(0.0, 0.1, 0.0)
    _zone.add_child(disc)
    var tm := TorusMesh.new()
    tm.inner_radius = ZONE_R - 0.35
    tm.outer_radius = ZONE_R
    tm.rings = 40
    tm.ring_segments = 6
    var ring := MeshInstance3D.new()
    ring.mesh = tm
    _ring_mat = _disc_mat(Color(1.0, 0.3, 0.05, 0.9))
    ring.material_override = _ring_mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ring.position = Vector3(0.0, 0.12, 0.0)
    ring.scale = Vector3(1.0, 0.4, 1.0)
    _zone.add_child(ring)

func _update_zone(delta: float) -> void:
    _zone_t += delta
    var pulse := 0.5 + 0.5 * sin(_zone_t * 14.0)
    if _zone_mat != null:
        _zone_mat.albedo_color.a = 0.12 + 0.16 * pulse
    if _ring_mat != null:
        _ring_mat.albedo_color.a = 0.55 + 0.4 * pulse
    # виверження закінчується, коли всі бомби впали
    if _bombs.is_empty():
        _zone_t = -1.0
        if _zone != null and is_instance_valid(_zone):
            _zone.queue_free()
        _zone = null

func _marker(pos: Vector3) -> MeshInstance3D:
    var cm := CylinderMesh.new()
    cm.top_radius = BOMB_R
    cm.bottom_radius = BOMB_R
    cm.height = 0.05
    cm.radial_segments = 24
    var m := MeshInstance3D.new()
    m.mesh = cm
    m.material_override = _disc_mat(Color(1.0, 0.25, 0.05, 0.45))
    m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    get_parent().add_child(m)
    m.global_position = pos + Vector3(0.0, 0.14, 0.0)
    return m

func _update_bombs(delta: float) -> void:
    var i := _bombs.size() - 1
    while i >= 0:
        var b: Dictionary = _bombs[i]
        if b["t"] < 0.0:
            b["delay"] = float(b["delay"]) - delta
            if float(b["delay"]) <= 0.0:
                b["t"] = 0.0
                var sph := Util.add_mesh(self, Util.sphere(0.8), Color(1.0, 0.5, 0.1), Vector3(0.0, height + 0.3, 0.0), Vector3.ZERO, 0.3, 5.0)
                sph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                b["node"] = sph
                b["marker"] = _marker(b["to"])
                var tr := _particles(8, 0.6, false)
                tr.emission_sphere_radius = 0.4
                tr.initial_velocity_min = 0.3
                tr.initial_velocity_max = 1.0
                tr.scale_amount_min = 0.4
                tr.scale_amount_max = 0.7
                sph.add_child(tr)
                tr.emitting = true
        else:
            b["t"] = float(b["t"]) + delta
            var k := clampf(float(b["t"]) / FLIGHT, 0.0, 1.0)
            var from := Vector3(global_position.x, height + 0.3, global_position.z)
            var to: Vector3 = b["to"]
            var flat := Vector2(to.x - from.x, to.z - from.z).length()
            var apex := 10.0 + flat * 0.12
            var pos := from.lerp(to, k)
            pos.y = lerpf(from.y, 0.3, k) + 4.0 * apex * k * (1.0 - k)
            var sph2: MeshInstance3D = b["node"]
            if sph2 != null and is_instance_valid(sph2):
                sph2.global_position = pos
            var mk: MeshInstance3D = b["marker"]
            if mk != null and is_instance_valid(mk):
                var s := 0.55 + 0.45 * k
                mk.scale = Vector3(s, 1.0, s)
            if k >= 1.0:
                _land(to)
                if sph2 != null and is_instance_valid(sph2):
                    sph2.queue_free()
                if mk != null and is_instance_valid(mk):
                    mk.queue_free()
                _bombs.remove_at(i)
        i -= 1

# Бомба впала: вибух, а якщо герой у радіусі вибуху (і не в польоті) — удар магмою.
func _land(pos: Vector3) -> void:
    var par := get_parent()
    Fx.explosion(par, pos + Vector3(0.0, 0.3, 0.0), BOMB_R, Color(1.0, 0.45, 0.1))
    Fx.burst(par, pos + Vector3(0.0, 0.6, 0.0), Color(1.0, 0.7, 0.2), 16, 7.0, 0.14)
    Sfx.play_at("explosion", pos, -3.0)
    if player == null or not is_instance_valid(player) or player.dead:
        return
    var pp: Vector3 = player.global_position
    if pp.y > 2.5:
        return          # герой у стрибку — над вибухом
    if Vector2(pp.x - pos.x, pp.z - pos.z).length() <= BOMB_R + 0.5:
        player.take_damage(maxi(1, int(float(player.max_hp) * dmg_pct)), 0.8)
