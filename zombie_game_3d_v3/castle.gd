extends Node3D
# Замок на кам'яній площі першої локації: мур навколо площі, кутові вежі, одні ворота (північ, -Z)
# і союзні солдати всередині. Ворота відчиняються, коли герой підходить, а щойно він виходить —
# зачиняються назавжди (level.gd викликає lock_gate()). Солдати допомоги не надають, просто живуть.

const Util = preload("res://util.gd")
const FlickerLight = preload("res://light_flicker.gd")
const GuardScript = preload("res://castle_guard.gd")

const HALF := 16.5          # половина розміру муру (площа 32x32 => внутрішня грань ~15.8)
const WALL_T := 1.4
const WALL_H := 3.4
const GATE_W := 6.0         # ширина проходу
const GATE_H := 3.0
const TOWER := 3.8
const TOWER_H := 5.6

signal gate_changed(open: bool)

var gate_open := false
var locked := false
var body: StaticBody3D
var gate_shape: CollisionShape3D
var door_l: Node3D
var door_r: Node3D
var tween: Tween
var player: Node3D
var stone_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D

func gate_center() -> Vector3:
    return Vector3(0.0, 0.0, -HALF)

# true, якщо точка (x, z) лежить усередині муру або впритул до нього (для спавну зомбі)
static func inside_rect(p: Vector3, margin: float = 2.5) -> bool:
    return absf(p.x) < HALF + margin and absf(p.z) < HALF + margin

func _ready() -> void:
    stone_mat = StandardMaterial3D.new()
    stone_mat.albedo_texture = _brick_texture()
    stone_mat.albedo_color = Color(1.0, 0.97, 0.94)
    stone_mat.uv1_triplanar = true
    stone_mat.uv1_world_triplanar = true
    stone_mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
    stone_mat.roughness = 0.95
    dark_mat = StandardMaterial3D.new()
    dark_mat.albedo_texture = stone_mat.albedo_texture
    dark_mat.albedo_color = Color(0.72, 0.7, 0.68)
    dark_mat.uv1_triplanar = true
    dark_mat.uv1_world_triplanar = true
    dark_mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
    dark_mat.roughness = 0.95
    wood_mat = Util.mat(Color(0.33, 0.2, 0.1), 0.9)

    body = StaticBody3D.new()
    body.collision_layer = 4
    body.collision_mask = 0
    add_child(body)

    _build_walls()
    _build_towers()
    _build_gate()
    _build_decor()
    _build_wall_details()
    _build_props()
    _build_floor_decals()
    _spawn_soldiers()

# ---------- Будівництво ----------
func _box(pos: Vector3, size: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    add_child(mi)
    if collide:
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        cs.position = pos
        body.add_child(cs)
    return mi

# Відрізок муру з зубцями. along_x — тягнеться вздовж X.
func _wall(cx: float, cz: float, length: float, along_x: bool) -> void:
    var size := Vector3(length, WALL_H, WALL_T)
    if not along_x:
        size = Vector3(WALL_T, WALL_H, length)
    _box(Vector3(cx, WALL_H * 0.5, cz), size, stone_mat)
    # зубці (мерлони)
    var n := maxi(1, int(length / 1.5))
    var seg := length / float(n)
    for i in range(n):
        if i % 2 == 1:
            continue
        var off := -length * 0.5 + (float(i) + 0.5) * seg
        var msize := Vector3(seg * 0.85, 0.6, WALL_T * 0.9)
        var mpos := Vector3(cx + off, WALL_H + 0.3, cz)
        if not along_x:
            msize = Vector3(WALL_T * 0.9, 0.6, seg * 0.85)
            mpos = Vector3(cx, WALL_H + 0.3, cz + off)
        _box(mpos, msize, dark_mat, false)

func _build_walls() -> void:
    var inner_t := HALF - TOWER * 0.5              # від центру до краю вежі
    # північний мур: дві половини між вежею та стовпом воріт
    var pillar_out := GATE_W * 0.5 + 1.1            # зовнішній край стовпа
    var gl := inner_t - pillar_out
    var cx := -(pillar_out + gl * 0.5)
    _wall(cx, -HALF, gl, true)
    _wall(-cx, -HALF, gl, true)
    # південний, західний, східний
    var full := 2.0 * inner_t
    _wall(0.0, HALF, full, true)
    _wall(-HALF, 0.0, full, false)
    _wall(HALF, 0.0, full, false)

func _build_towers() -> void:
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var p := Vector3(float(sx) * HALF, 0.0, float(sz) * HALF)
            _box(p + Vector3(0, TOWER_H * 0.5, 0), Vector3(TOWER, TOWER_H, TOWER), stone_mat)
            # пояс і зубці
            _box(p + Vector3(0, TOWER_H - 0.15, 0), Vector3(TOWER + 0.4, 0.3, TOWER + 0.4), dark_mat, false)
            _tower_roof(p)
            # прапор на шпилі
            var pole := Util.add_mesh(self, Util.cylinder(0.05, 0.05, 1.8), Color(0.3, 0.2, 0.1), p + Vector3(0, TOWER_H + 3.4, 0))
            pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var flag := Util.add_mesh(self, Util.box(Vector3(1.1, 0.7, 0.05)), Color(0.15, 0.26, 0.58), p + Vector3(0.6, TOWER_H + 3.9, 0))
            flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # ліхтарі на вежах теж горять
    for sx in [-1.0, 1.0]:
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.62, 0.3)
        l.light_energy = 1.4
        l.omni_range = 10.0
        l.position = Vector3(float(sx) * (HALF - 3.0), 3.4, HALF - 3.0)
        add_child(l)

func _build_gate() -> void:
    var px := GATE_W * 0.5 + 0.55
    # стовпи воріт
    for sx in [-1.0, 1.0]:
        _box(Vector3(float(sx) * px, 2.4, -HALF), Vector3(1.1, 4.8, 1.8), stone_mat)
        _box(Vector3(float(sx) * px, 4.95, -HALF), Vector3(1.4, 0.3, 2.1), dark_mat, false)
    # арка над проходом (колізія нижче 3 м вільна)
    _box(Vector3(0.0, GATE_H + 0.9, -HALF), Vector3(GATE_W + 1.2, 1.8, WALL_T + 0.2), stone_mat)
    for i in range(5):
        _box(Vector3(-2.4 + 1.2 * float(i), GATE_H + 2.05, -HALF), Vector3(0.8, 0.5, WALL_T * 0.9), dark_mat, false)

    # блокуюча колізія воріт (коли зачинені)
    gate_shape = CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(GATE_W, GATE_H + 1.0, 0.5)
    gate_shape.shape = sh
    gate_shape.position = Vector3(0.0, (GATE_H + 1.0) * 0.5, -HALF)
    body.add_child(gate_shape)

    # стулки: петлі по краях проходу
    door_l = _make_door(-GATE_W * 0.5, 1.0)
    door_r = _make_door(GATE_W * 0.5, -1.0)
    _gate_studs(door_l, 1.0)
    _gate_studs(door_r, -1.0)

    # смолоскипи біля воріт зсередини й зовні
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var tp := Vector3(float(sx) * (px + 1.0), 0.0, -HALF + float(sz) * 1.5)
            Util.add_mesh(self, Util.cylinder(0.06, 0.08, 2.2), Color(0.4, 0.26, 0.13), tp + Vector3(0, 1.1, 0))
            Util.add_mesh(self, Util.sphere(0.18), Color(1.0, 0.55, 0.1), tp + Vector3(0, 2.3, 0), Vector3.ZERO, 0.4, 4.0)
            if sz > 0.0:
                var l: OmniLight3D = FlickerLight.new()
                l.light_color = Color(1.0, 0.6, 0.25)
                l.light_energy = 1.8
                l.omni_range = 9.0
                l.position = tp + Vector3(0, 2.3, 0)
                add_child(l)

func _make_door(hinge_x: float, dir: float) -> Node3D:
    # dir = +1: стулка йде від петлі в бік +X (ліва), -1: у бік -X (права)
    var pivot := Node3D.new()
    pivot.position = Vector3(hinge_x, 0.0, -HALF)
    add_child(pivot)
    var w := GATE_W * 0.5
    var leaf := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(w, GATE_H, 0.3)
    leaf.mesh = bm
    leaf.material_override = wood_mat
    leaf.position = Vector3(dir * w * 0.5, GATE_H * 0.5, 0.0)
    pivot.add_child(leaf)
    # залізні смуги
    for y in [0.7, 1.5, 2.3]:
        var band := MeshInstance3D.new()
        var bb := BoxMesh.new()
        bb.size = Vector3(w, 0.14, 0.36)
        band.mesh = bb
        band.material_override = Util.mat(Color(0.14, 0.14, 0.16), 0.6)
        band.position = Vector3(dir * w * 0.5, float(y), 0.0)
        pivot.add_child(band)
    return pivot

func _build_decor() -> void:
    # навіси/стійки зі зброєю, лавка й тренувальні опудала біля стін — щоб замок виглядав жилим
    var wood := Color(0.4, 0.26, 0.13)
    # стійка зі списами біля західного муру
    var rack := Node3D.new()
    rack.position = Vector3(-14.2, 0.0, 2.0)
    add_child(rack)
    Util.add_mesh(rack, Util.box(Vector3(0.2, 1.2, 2.6)), wood, Vector3(0, 0.6, 0))
    for i in range(5):
        Util.add_mesh(rack, Util.cylinder(0.025, 0.025, 2.0), Color(0.45, 0.32, 0.18), Vector3(0.25, 1.0, -1.0 + 0.5 * float(i)), Vector3(0, 0, -8))
        Util.add_mesh(rack, Util.cylinder(0.0, 0.05, 0.2), Color(0.62, 0.64, 0.68), Vector3(0.1, 2.05, -1.0 + 0.5 * float(i)))
    _col_static(Vector3(-14.2, 0.0, 2.0), Vector3(0.8, 1.2, 2.6))
    # навчальне опудало
    var dummy := Node3D.new()
    dummy.position = Vector3(12.5, 0.0, 6.0)
    add_child(dummy)
    Util.add_mesh(dummy, Util.cylinder(0.07, 0.07, 1.8), wood, Vector3(0, 0.9, 0))
    Util.add_mesh(dummy, Util.box(Vector3(1.0, 0.1, 0.1)), wood, Vector3(0, 1.45, 0))
    Util.add_mesh(dummy, Util.cylinder(0.3, 0.35, 0.7), Color(0.55, 0.45, 0.25), Vector3(0, 1.25, 0))
    Util.add_mesh(dummy, Util.sphere(0.22), Color(0.55, 0.45, 0.25), Vector3(0, 1.85, 0))
    _col_static(Vector3(12.5, 0.0, 6.0), Vector3(0.9, 1.8, 0.9))
    # намети-«казарма»: лише дерев'яна лавка
    var bench := Node3D.new()
    bench.position = Vector3(-12.0, 0.0, -11.0)
    add_child(bench)
    Util.add_mesh(bench, Util.box(Vector3(2.4, 0.12, 0.55)), wood, Vector3(0, 0.5, 0))
    Util.add_mesh(bench, Util.box(Vector3(0.12, 0.5, 0.5)), wood, Vector3(-1.0, 0.25, 0))
    Util.add_mesh(bench, Util.box(Vector3(0.12, 0.5, 0.5)), wood, Vector3(1.0, 0.25, 0))
    _col_static(Vector3(-12.0, 0.0, -11.0), Vector3(2.4, 0.6, 0.6))

func _col_static(pos: Vector3, size: Vector3) -> void:
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    cs.position = Vector3(pos.x, size.y * 0.5, pos.z)
    body.add_child(cs)

# ---------- Союзні солдати ----------
func _spawn_soldiers() -> void:
    # перешкоди двору (див. terrain._build_start_area і _build_decor): [центр, радіус обходу]
    var obstacles := [
        [Vector3(-8.0, 0, -7.0), 2.0],            # колодязь
        [Vector3(7.6, 0, -8.7), 2.3],             # ящики
        [Vector3(9.5, 0, -6.0), 1.0],             # бочка
        [Vector3(-9.5, 0, 6.0), 1.0],             # бочка
        [Vector3(-6.0, 0, 9.0), 0.8],             # смолоскипи
        [Vector3(6.0, 0, 9.0), 0.8],
        [Vector3(-14.2, 0, 2.0), 1.6],            # стійка зі списами
        [Vector3(12.5, 0, 6.0), 1.3],             # опудало
        [Vector3(-12.0, 0, -11.0), 1.8],          # лавка
        [Vector3(0.0, 0, 0.0), 1.6],              # місце старту героя
    ]
    # двоє вартових біля воріт
    _add_guard("stand", "spear", Vector3(-4.6, 0.0, -14.3), PI, [], obstacles)
    _add_guard("stand", "spear", Vector3(4.6, 0.0, -14.3), PI, [], obstacles)
    # патрульні ходять по двору
    var routes := [
        [Vector3(-11, 0, 3), Vector3(-11, 0, 12), Vector3(-3, 0, 13), Vector3(-4, 0, 6)],
        [Vector3(11, 0, -2), Vector3(12, 0, 11), Vector3(5, 0, 13), Vector3(4, 0, 4)],
        [Vector3(-4, 0, -4), Vector3(4, 0, -3), Vector3(3, 0, -11), Vector3(-3, 0, -10)],
        [Vector3(-13, 0, -4), Vector3(-9, 0, -12), Vector3(-5, 0, -13), Vector3(-13, 0, 8)],
    ]
    for r in routes:
        var g = _add_guard("patrol", "spear", r[0], randf() * TAU, r, obstacles)
        g.speed = randf_range(1.4, 1.9)
    # двоє тренуються на мечах
    var a = _add_guard("spar", "sword", Vector3(9.0, 0.0, 11.5), PI * 0.5, [], obstacles)
    var b = _add_guard("spar", "sword", Vector3(10.7, 0.0, 11.5), -PI * 0.5, [], obstacles)
    a.partner = b
    b.partner = a

func _add_guard(mode: String, weapon: String, pos: Vector3, yaw: float, route: Array, obstacles: Array):
    var g = GuardScript.new()
    g.mode = mode
    g.weapon = weapon
    g.points = route
    g.obstacles = obstacles
    g.home_yaw = yaw
    g.player = player
    g.position = pos
    add_child(g)
    return g

# ---------- Ворота ----------
func open_gate() -> void:
    if gate_open or locked:
        return
    gate_open = true
    gate_shape.set_deferred("disabled", true)
    _animate_doors(true)
    Sfx.play("equip", -2.0, 0.6)
    gate_changed.emit(true)

func close_gate() -> void:
    if not gate_open:
        return
    gate_open = false
    gate_shape.set_deferred("disabled", false)
    _animate_doors(false)
    Sfx.play("swing_heavy", 0.0, 0.5)
    gate_changed.emit(false)

# Остаточно зачиняє ворота: назад зайти не можна.
func lock_gate() -> void:
    if locked:
        return
    close_gate()
    locked = true
    gate_shape.set_deferred("disabled", false)

func _animate_doors(open: bool) -> void:
    if tween != null and tween.is_valid():
        tween.kill()
    tween = create_tween().set_parallel(true)
    var a := 100.0 if open else 0.0
    tween.tween_property(door_l, "rotation_degrees:y", a, 0.7).set_trans(Tween.TRANS_SINE)
    tween.tween_property(door_r, "rotation_degrees:y", -a, 0.7).set_trans(Tween.TRANS_SINE)

# ---------- Текстура цегли ----------
func _brick_texture() -> ImageTexture:
    var n := 256
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.2, 0.19, 0.18))
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 31
    noise.frequency = 0.09
    noise.fractal_octaves = 3
    var bh := 32
    var bw := 64
    for row in range(n / bh):
        var xoff := 0 if row % 2 == 0 else bw / 2
        for col in range(n / bw + 1):
            var s := 0.4 + rng.randf() * 0.18
            var warm := rng.randf_range(-0.05, 0.05)
            var x0 := col * bw + xoff
            for y in range(2, bh - 2):
                # фаска: верх світліший, низ темніший
                var bevel := 1.0 + (0.5 - float(y) / float(bh)) * 0.25
                for x in range(2, bw - 2):
                    var px := (x0 + x) % n
                    var py := row * bh + y
                    var edge := minf(minf(float(x), float(bw - x)), minf(float(y), float(bh - y)))
                    var k := 0.9 + noise.get_noise_2d(float(px), float(py)) * 0.22 + rng.randf() * 0.06
                    k *= bevel * clampf(0.82 + edge * 0.06, 0.82, 1.0)
                    img.set_pixel(px, py, Color(s * k * (1.0 + warm), s * k * 0.97, s * k * (0.92 - warm), 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

# ---------- Додаткові деталі замку ----------
# Конічні дахи веж замість голих зубців: червоно-коричнева черепиця, флюгер-прапор на шпилі.
func _tower_roof(p: Vector3) -> void:
    var roof_mat := Util.mat(Color(0.5, 0.17, 0.12), 0.8)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = TOWER * 0.88
    cone.height = 2.6
    cone.radial_segments = 4
    cone.rings = 1
    var mi := MeshInstance3D.new()
    mi.mesh = cone
    mi.material_override = roof_mat
    mi.position = p + Vector3(0, TOWER_H + 1.3, 0)
    mi.rotation_degrees.y = 45.0
    add_child(mi)
    var trim := Util.add_mesh(self, Util.box(Vector3(TOWER + 0.5, 0.18, TOWER + 0.5)), Color(0.26, 0.2, 0.16), p + Vector3(0, TOWER_H + 0.05, 0))
    trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # вузька бійниця на кожній грані
    for k in range(4):
        var a := TAU * float(k) / 4.0
        var d := Vector3(cos(a), 0.0, sin(a))
        var slit := Util.add_mesh(self, Util.box(Vector3(0.12, 0.8, 0.12)), Color(0.02, 0.02, 0.03), p + d * (TOWER * 0.5 + 0.02) + Vector3(0, TOWER_H * 0.65, 0))
        slit.rotation.y = -a
        slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Настінний смолоскип: кронштейн, вогник і (за потреби) тепле світло.
func _wall_torch(pos: Vector3, yaw: float, with_light: bool) -> void:
    var n := Node3D.new()
    n.position = pos
    n.rotation.y = yaw
    add_child(n)
    var iron := Color(0.12, 0.12, 0.13)
    Util.add_mesh(n, Util.box(Vector3(0.1, 0.1, 0.5)), iron, Vector3(0, 0, 0.25), Vector3.ZERO, 0.5)
    Util.add_mesh(n, Util.cylinder(0.08, 0.05, 0.5), Color(0.35, 0.22, 0.1), Vector3(0, 0.2, 0.5))
    var fl := Util.add_mesh(n, Util.sphere(0.15), Color(1.0, 0.55, 0.12), Vector3(0, 0.55, 0.5), Vector3.ZERO, 0.4, 5.0)
    fl.scale = Vector3(1.0, 1.5, 1.0)
    fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if with_light:
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.6, 0.28)
        l.light_energy = 1.5
        l.omni_range = 7.5
        l.position = Vector3(0, 0.7, 0.7)
        n.add_child(l)

# Полотнище на внутрішній грані муру. yaw повертає його лицем у двір.
func _banner(pos: Vector3, yaw: float, col: Color) -> void:
    var n := Node3D.new()
    n.position = pos
    n.rotation.y = yaw
    add_child(n)
    Util.add_mesh(n, Util.cylinder(0.04, 0.04, 1.3), Color(0.3, 0.2, 0.1), Vector3(0, 0.95, 0.05), Vector3(0, 0, 90))
    var cloth := Util.add_mesh(n, Util.box(Vector3(1.0, 1.9, 0.04)), col, Vector3(0, 0.0, 0.05), Vector3.ZERO, 0.95)
    cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var tip := Util.add_mesh(n, Util.box(Vector3(0.5, 0.5, 0.04)), col, Vector3(0, -1.1, 0.05), Vector3(0, 0, 45), 0.95)
    tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    Util.add_mesh(n, Util.box(Vector3(0.36, 0.5, 0.045)), Color(0.9, 0.78, 0.3), Vector3(0, 0.15, 0.065), Vector3.ZERO, 0.6)

func _build_wall_details() -> void:
    var inner := HALF - WALL_T * 0.5 - 0.02      # внутрішня грань муру
    var red := Color(0.55, 0.1, 0.1)
    var blue := Color(0.15, 0.26, 0.58)
    # південний мур: погляд у -Z (yaw=PI)
    _banner(Vector3(-8.0, 2.0, inner), PI, red)
    _banner(Vector3(8.0, 2.0, inner), PI, blue)
    _wall_torch(Vector3(0.0, 2.2, inner), PI, true)
    # західний (дивиться на +X) і східний (на -X)
    _banner(Vector3(-inner, 2.0, -6.0), PI * 0.5, blue)
    _banner(Vector3(-inner, 2.0, 9.0), PI * 0.5, red)
    _banner(Vector3(inner, 2.0, -7.0), -PI * 0.5, red)
    _banner(Vector3(inner, 2.0, 6.5), -PI * 0.5, blue)
    _wall_torch(Vector3(-inner, 2.2, -12.0), PI * 0.5, false)
    _wall_torch(Vector3(-inner, 2.2, 6.0), PI * 0.5, true)
    _wall_torch(Vector3(inner, 2.2, -12.0), -PI * 0.5, false)
    _wall_torch(Vector3(inner, 2.2, 8.0), -PI * 0.5, true)
    # контрфорси вздовж муру
    for z in [-8.0, 0.0, 8.0]:
        for sx in [-1.0, 1.0]:
            var b := _box(Vector3(float(sx) * (inner - 0.25), 1.6, z + 3.0), Vector3(0.5, 3.2, 0.6), dark_mat, false)
            b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    # цоколь знизу муру: ширший нижній пояс
    for sx in [-1.0, 1.0]:
        _box(Vector3(float(sx) * (HALF - 0.1), 0.25, 0.0), Vector3(WALL_T + 0.3, 0.5, 2.0 * (HALF - TOWER * 0.5)), dark_mat, false)
    _box(Vector3(0.0, 0.25, HALF - 0.1), Vector3(2.0 * (HALF - TOWER * 0.5), 0.5, WALL_T + 0.3), dark_mat, false)

# Залізні заклепки й кільця на стулках воріт.
func _gate_studs(pivot: Node3D, dir: float) -> void:
    var w := GATE_W * 0.5
    var iron := Util.mat(Color(0.2, 0.2, 0.22), 0.45)
    var sm := SphereMesh.new()
    sm.radius = 0.05
    sm.height = 0.1
    sm.radial_segments = 6
    sm.rings = 3
    for i in range(6):
        for y in [0.35, 1.1, 1.9, 2.65]:
            for side in [-1.0, 1.0]:
                var s := MeshInstance3D.new()
                s.mesh = sm
                s.material_override = iron
                s.position = Vector3(dir * (0.25 + 0.5 * float(i)), float(y), float(side) * 0.17)
                pivot.add_child(s)
    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.12
    tm.outer_radius = 0.18
    tm.rings = 12
    tm.ring_segments = 6
    ring.mesh = tm
    ring.material_override = iron
    ring.position = Vector3(dir * (w - 0.35), 1.5, 0.19)
    ring.rotation_degrees.x = 90.0
    pivot.add_child(ring)

# Плями бруду й різнокольорові плити на підлозі двору (над текстурою площі, нижче за кров).
func _build_floor_decals() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    var quad := PlaneMesh.new()
    quad.size = Vector2(1.0, 1.0)
    var inner := HALF - 1.0
    # стежка від воріт до центру: світліші плити
    var path_mat := Util.mat(Color(0.62, 0.58, 0.5, 0.08), 1.0)
    path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    for i in range(14):
        var z := -inner + float(i) * 1.1
        var w := 3.6 + rng.randf() * 0.8
        _decal(quad, Vector3(rng.randf_range(-0.3, 0.3), 0.034, z), Vector2(w, 1.0), rng.randf_range(-0.03, 0.03), path_mat)
    # випадкові темні та світлі плити
    var mats: Array[StandardMaterial3D] = []
    for c in [Color(0.1, 0.09, 0.08, 0.12), Color(0.2, 0.25, 0.14, 0.1)]:
        var mm := Util.mat(c, 1.0)
        mm.cull_mode = BaseMaterial3D.CULL_DISABLED
        mats.append(mm)
    for i in range(30):
        var p := Vector3(rng.randf_range(-inner, inner), 0.036, rng.randf_range(-inner, inner))
        var s := Vector2(rng.randf_range(0.8, 2.0), rng.randf_range(0.8, 2.0))
        _decal(quad, p, s, rng.randf() * TAU, mats[rng.randi() % mats.size()])
    # брудні смуги вздовж стін
    var dirt := Util.mat(Color(0.1, 0.08, 0.06, 0.35), 1.0)
    dirt.cull_mode = BaseMaterial3D.CULL_DISABLED
    var edge := HALF - WALL_T * 0.5
    _decal(quad, Vector3(0, 0.038, edge - 0.5), Vector2(2.0 * edge, 1.0), 0.0, dirt)
    _decal(quad, Vector3(0, 0.038, -edge + 0.5), Vector2(2.0 * edge, 1.0), 0.0, dirt)
    _decal(quad, Vector3(edge - 0.5, 0.038, 0), Vector2(1.0, 2.0 * edge), 0.0, dirt)
    _decal(quad, Vector3(-edge + 0.5, 0.038, 0), Vector2(1.0, 2.0 * edge), 0.0, dirt)

func _decal(mesh: Mesh, pos: Vector3, size: Vector2, yaw: float, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.rotation.y = yaw
    mi.scale = Vector3(size.x, 1.0, size.y)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

# Пропи вздовж стін, що не заважають проходу: ящики, бочки, стійка зі зброєю, жаровня, сінні тюки.
func _build_props() -> void:
    var wood := Color(0.42, 0.28, 0.14)
    var dark_wood := Color(0.3, 0.19, 0.1)
    var iron := Color(0.16, 0.16, 0.18)
    # східна стійка зі списами (дзеркально до західної)
    var rack := Node3D.new()
    rack.position = Vector3(14.4, 0.0, -2.0)
    add_child(rack)
    Util.add_mesh(rack, Util.box(Vector3(0.2, 1.2, 2.6)), wood, Vector3(0, 0.6, 0))
    for i in range(4):
        Util.add_mesh(rack, Util.cylinder(0.025, 0.025, 1.9), Color(0.45, 0.32, 0.18), Vector3(-0.25, 1.0, -0.9 + 0.55 * float(i)), Vector3(0, 0, 8))
        Util.add_mesh(rack, Util.cylinder(0.0, 0.05, 0.2), Color(0.62, 0.64, 0.68), Vector3(-0.13, 1.98, -0.9 + 0.55 * float(i)), Vector3(0, 0, 8), 0.4)
    for i in range(3):
        Util.add_mesh(rack, Util.cylinder(0.3, 0.3, 0.06), Color(0.55, 0.12, 0.1), Vector3(-0.25, 0.9, -0.8 + 0.8 * float(i)), Vector3(0, 0, 90))
    _col_static(Vector3(14.4, 0.0, -2.0), Vector3(0.8, 1.2, 2.6))
    # ящики й бочки в південно-західному куті
    _crate(Vector3(-14.0, 0.0, 14.0), 1.0, 0.2, wood)
    _crate(Vector3(-12.7, 0.0, 14.2), 0.8, -0.3, dark_wood)
    _crate(Vector3(-13.8, 1.0, 14.0), 0.7, 0.6, wood, false)
    _barrel(Vector3(-14.2, 0.0, 12.6), wood, iron)
    _col_static(Vector3(-13.4, 0.0, 13.9), Vector3(3.0, 1.0, 1.6))
    # бочки й тюки в північно-східному куті
    _barrel(Vector3(14.0, 0.0, -13.4), wood, iron)
    _barrel(Vector3(14.1, 0.0, -11.9), dark_wood, iron)
    _barrel(Vector3(12.7, 0.0, -13.7), wood, iron)
    _col_static(Vector3(13.6, 0.0, -12.9), Vector3(2.4, 1.0, 2.4))
    # сінні тюки біля південної стіни
    for i in range(2):
        var hb := Util.add_mesh(self, Util.box(Vector3(1.3, 0.7, 0.8)), Color(0.72, 0.6, 0.28), Vector3(5.0 + 1.4 * float(i), 0.35 + 0.0, 14.7), Vector3(0, 6.0 * float(i), 0), 1.0)
        hb.scale = Vector3(1.0, 1.0, 1.0)
    _col_static(Vector3(5.7, 0.0, 14.7), Vector3(2.8, 0.7, 0.9))
    # жаровня біля східної стіни
    var br := Node3D.new()
    br.position = Vector3(14.6, 0.0, 12.0)
    add_child(br)
    Util.add_mesh(br, Util.cylinder(0.06, 0.08, 0.9), iron, Vector3(0, 0.45, 0), Vector3.ZERO, 0.5)
    Util.add_mesh(br, Util.cylinder(0.4, 0.2, 0.25), iron, Vector3(0, 0.95, 0), Vector3.ZERO, 0.5)
    var fire := Util.add_mesh(br, Util.sphere(0.28), Color(1.0, 0.5, 0.1), Vector3(0, 1.15, 0), Vector3.ZERO, 0.4, 5.0)
    fire.scale = Vector3(1.0, 1.3, 1.0)
    fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var l: OmniLight3D = FlickerLight.new()
    l.light_color = Color(1.0, 0.55, 0.25)
    l.light_energy = 1.6
    l.omni_range = 8.0
    l.position = Vector3(0, 1.6, 0)
    br.add_child(l)
    _col_static(Vector3(14.6, 0.0, 12.0), Vector3(0.9, 1.2, 0.9))

func _crate(pos: Vector3, s: float, yaw: float, col: Color, collide: bool = false) -> void:
    var c := Util.add_mesh(self, Util.box(Vector3(s, s, s)), col, pos + Vector3(0, s * 0.5, 0), Vector3(0, rad_to_deg(yaw), 0), 0.9)
    for sy in [-1.0, 1.0]:
        var band := Util.add_mesh(c, Util.box(Vector3(s * 1.04, s * 0.1, s * 1.04)), Color(0.2, 0.13, 0.07), Vector3(0, float(sy) * s * 0.4, 0), Vector3.ZERO, 0.9)
        band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _barrel(pos: Vector3, col: Color, iron: Color) -> void:
    var b := Util.add_mesh(self, Util.cylinder(0.45, 0.4, 0.9), col, pos + Vector3(0, 0.45, 0), Vector3.ZERO, 0.9)
    for y in [-0.28, 0.28]:
        var hoop := Util.add_mesh(b, Util.cylinder(0.47, 0.47, 0.06), iron, Vector3(0, float(y), 0), Vector3.ZERO, 0.5)
        hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
