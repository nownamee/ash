extends Node3D
# Застава лицарів (місія оборони, «Давній форт»): замок із здоров'ям, який треба захистити,
# і табір лицарів перед ним (фронт замку дивиться на +Z, на дорогу).
# Зомбі штурмують замок: zombie.gd питає attack_point() (найближча точка муру) і викликає take_damage().
# Налаштування: SIEGE_MULT (скільки шкоди з удару зомбі отримує мур), knights — у _spawn_knights().

const Util = preload("res://util.gd")
const FlickerLight = preload("res://light_flicker.gd")
const Fx = preload("res://effects.gd")
const KnightScript = preload("res://ally_knight.gd")
const FireField = preload("res://fire_field.gd")

signal destroyed
signal hp_changed

const SIEGE_MULT := 0.3     # мур приймає лише частину шкоди зомбі (інакше замок падав би за секунди)
const KEEP_W := 18.0
const KEEP_D := 12.0
const WALL_H := 6.5
const TOWER := 4.2
const TOWER_H := 9.5
const HX := KEEP_W * 0.5 + TOWER * 0.5      # половина розміру основи по X
const HZ := KEEP_D * 0.5 + TOWER * 0.5      # половина розміру основи по Z

var max_hp := 6000.0
var hp := 6000.0
var player: Node3D

var vis: Node3D             # уся видима частина замку (щоб обвалити її при зруйнуванні)
var body: StaticBody3D
var stone_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var cloth_mat: StandardMaterial3D
var pending := 0.0          # накопичена шкода для плаваючого тексту
var text_t := 0.0
var hit_flash := 0.0
var fires := 0              # скільки рівнів пожеж уже запалено (0..2)
var tower_pos: Array = []
# Палаючий замок («Вогняний ліс»): вогонь їсть мури сам по собі (burn_dps HP за секунду), а зомбі б'ють сильніше (siege_mult).
var burning := false
var siege_mult := SIEGE_MULT
var burn_flames: Array = []

func _ready() -> void:
    add_to_group("defend_castle")
    hp = max_hp
    stone_mat = StandardMaterial3D.new()
    stone_mat.albedo_texture = _brick_texture()
    stone_mat.albedo_color = Color(0.78, 0.76, 0.74)
    stone_mat.uv1_triplanar = true
    stone_mat.uv1_world_triplanar = true
    stone_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
    stone_mat.roughness = 0.95
    stone_mat.emission = Color(1.0, 0.4, 0.2)
    dark_mat = StandardMaterial3D.new()
    dark_mat.albedo_texture = stone_mat.albedo_texture
    dark_mat.albedo_color = Color(0.55, 0.53, 0.51)
    dark_mat.uv1_triplanar = true
    dark_mat.uv1_world_triplanar = true
    dark_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
    dark_mat.roughness = 0.95
    wood_mat = Util.mat(Color(0.33, 0.2, 0.1), 0.9)
    cloth_mat = Util.mat(Color(0.15, 0.26, 0.58), 0.9)
    cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

    vis = Node3D.new()
    add_child(vis)
    body = StaticBody3D.new()
    body.collision_layer = 4
    body.collision_mask = 0
    add_child(body)

    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(HX * 2.0, 5.0, HZ * 2.0)
    cs.shape = sh
    cs.position = Vector3(0.0, 2.5, 0.0)
    body.add_child(cs)

    _build_keep()
    _build_towers()
    _build_gate()
    _build_camp()
    _spawn_knights()
    if burning:
        _ignite_castle()

# ---------- Цілі для зомбі ----------
# Найближча до точки from точка на периметрі замку (на землі).
func attack_point(from: Vector3) -> Vector3:
    var c := global_position
    var lx := clampf(from.x - c.x, -HX, HX)
    var lz := clampf(from.z - c.z, -HZ, HZ)
    return Vector3(c.x + lx, 0.0, c.z + lz)

# Виштовхує точку p з-під мурів (для лицарів, у яких немає фізики).
func push_out(p: Vector3, margin: float = 0.9) -> Vector3:
    var c := global_position
    var lx := p.x - c.x
    var lz := p.z - c.z
    var ex := HX + margin
    var ez := HZ + margin
    if absf(lx) >= ex or absf(lz) >= ez:
        return p
    if ex - absf(lx) < ez - absf(lz):
        lx = ex if lx >= 0.0 else -ex
    else:
        lz = ez if lz >= 0.0 else -ez
    return Vector3(c.x + lx, p.y, c.z + lz)

# Куди йти з from до to, щоб не впиратися в замок: якщо пряма проходить крізь нього, повертає кут муру
# (того боку, з яким шлях найкоротший). Для лицарів, у яких немає фізики.
func route_point(from: Vector3, to: Vector3) -> Vector3:
    if not _seg_hits(from, to, HX + 0.3, HZ + 0.3):
        return to
    var c := global_position
    var best := to
    var best_len := 1.0e9
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var corner := Vector3(c.x + float(sx) * (HX + 1.3), from.y, c.z + float(sz) * (HZ + 1.3))
            if _seg_hits(from, corner, HX + 0.3, HZ + 0.3):
                continue
            var l := from.distance_to(corner) + corner.distance_to(to)
            if l < best_len:
                best_len = l
                best = corner
    return best

# Чи перетинає відрізок a-b прямокутник замку (з половинами сторін ex, ez).
func _seg_hits(a: Vector3, b: Vector3, ex: float, ez: float) -> bool:
    var c := global_position
    var t0 := 0.0
    var t1 := 1.0
    for axis in range(2):
        var p := a.x - c.x
        var dd := b.x - a.x
        var e := ex
        if axis == 1:
            p = a.z - c.z
            dd = b.z - a.z
            e = ez
        if absf(dd) < 0.0001:
            if absf(p) > e:
                return false
        else:
            var ta := (-e - p) / dd
            var tb := (e - p) / dd
            if ta > tb:
                var tmp := ta
                ta = tb
                tb = tmp
            t0 = maxf(t0, ta)
            t1 = minf(t1, tb)
            if t0 > t1:
                return false
    return true

func is_alive() -> bool:
    return hp > 0.0

# ---------- Шкода ----------
func take_damage(amount: int, _slow: float = 0.0) -> void:
    if hp <= 0.0:
        return
    var d := float(amount) * siege_mult
    hp = maxf(0.0, hp - d)
    pending += d
    hit_flash = 0.12
    _update_fires()
    hp_changed.emit()
    if hp <= 0.0:
        _collapse()

# Вогонь точить мури: шкода без спалаху й звуку удару (викликає level.gd щокадру під час облоги).
func burn(amount: float) -> void:
    if hp <= 0.0 or amount <= 0.0:
        return
    hp = maxf(0.0, hp - amount)
    pending += amount
    _update_fires()
    hp_changed.emit()
    if hp <= 0.0:
        _collapse()

# Замок горить від самого початку: вогонь на вежах, донжоні й мурах, жар і розжарені тріщини в камені.
func _ignite_castle() -> void:
    fires = 2
    for tp in tower_pos:
        _add_fire(tp, false)
    _add_fire(Vector3(0.0, WALL_H + 7.5, 0.0), false)
    # довгі язики полум'я вздовж верху мурів і навколо підніжжя
    var rows := [
        [Vector3(0.0, WALL_H, KEEP_D * 0.5), 7.0, 0.0],
        [Vector3(0.0, WALL_H, -KEEP_D * 0.5), 7.0, 0.0],
        [Vector3(-KEEP_W * 0.5, WALL_H, 0.0), 4.0, PI * 0.5],
        [Vector3(KEEP_W * 0.5, WALL_H, 0.0), 4.0, PI * 0.5],
    ]
    for r in rows:
        _add_flame_row(r[0], float(r[1]), float(r[2]), 1.1)
    for gp in [Vector3(-HX - 2.5, 0.0, 0.0), Vector3(HX + 2.5, 0.0, 0.0), Vector3(0.0, 0.0, -HZ - 2.5), Vector3(-9.0, 0.0, HZ + 2.0), Vector3(9.0, 0.0, HZ + 2.0)]:
        _add_flame_row(gp, 5.0, randf() * TAU, 1.8)
    # розжарене світіння каменю
    stone_mat.emission_enabled = true
    stone_mat.emission = Color(1.0, 0.32, 0.1)
    stone_mat.emission_energy_multiplier = 0.35

func _add_flame_row(p: Vector3, half_len: float, yaw: float, r: float) -> void:
    var ff := FireField.new()
    var pts: Array = []
    var n := maxi(2, int(half_len * 2.0 / 2.2))
    for i in range(n + 1):
        var u := -half_len + 2.0 * half_len * float(i) / float(n)
        pts.append([cos(yaw) * u, -sin(yaw) * u, r])
    ff.pts = pts
    ff.seed_v = int(p.x * 7.0) ^ int(p.z * 13.0) ^ int(p.y * 3.0)
    ff.position = p
    vis.add_child(ff)
    burn_flames.append(ff)

func _process(delta: float) -> void:
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        stone_mat.emission_enabled = hit_flash > 0.0 or burning
        stone_mat.emission_energy_multiplier = hit_flash * 3.0 + (0.35 if burning else 0.0)
    text_t -= delta
    if text_t <= 0.0 and pending >= 1.0:
        text_t = 0.6
        var spot := global_position + Vector3(randf_range(-6.0, 6.0), 11.0, randf_range(-1.0, 7.0))
        Fx.damage_text(get_parent(), spot, "-%d" % int(pending), Color(1.0, 0.45, 0.2))
        pending = 0.0
        Sfx.play_at("swing_heavy", global_position, -6.0, 0.5)

func _update_fires() -> void:
    var ratio := hp / max_hp
    if fires < 1 and ratio < 0.66:
        fires = 1
        _add_fire(tower_pos[0])
        _add_fire(tower_pos[1])
    if fires < 2 and ratio < 0.33:
        fires = 2
        _add_fire(tower_pos[2])
        _add_fire(tower_pos[3])
        _add_fire(Vector3(0.0, WALL_H + 7.5, 0.0))

func _add_fire(p: Vector3, boom: bool = true) -> void:
    var f := Node3D.new()
    f.position = p
    vis.add_child(f)
    var blob := Util.add_mesh(f, Util.sphere(0.9), Color(1.0, 0.5, 0.1), Vector3(0, 0.3, 0), Vector3.ZERO, 0.4, 3.0)
    blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var l: OmniLight3D = FlickerLight.new()
    l.light_color = Color(1.0, 0.5, 0.2)
    l.light_energy = 3.0
    l.omni_range = 16.0
    l.position = Vector3(0, 1.0, 0)
    f.add_child(l)
    if boom:
        Fx.explosion(get_parent(), global_position + p, 4.0, Color(1.0, 0.5, 0.15))
        Sfx.play_at("explosion", global_position + p, -3.0, 0.8)

func _collapse() -> void:
    for off in [Vector3(-7, 4, 0), Vector3(7, 5, 2), Vector3(0, 8, -2), Vector3(0, 3, 6)]:
        Fx.explosion(get_parent(), global_position + off, 6.0, Color(1.0, 0.5, 0.15))
    Sfx.play("explosion")
    var tw := create_tween().set_parallel(true)
    tw.tween_property(vis, "position:y", -5.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(vis, "rotation_degrees:z", 5.0, 2.2)
    destroyed.emit()

# ---------- Будівництво ----------
func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    if parent == null:
        vis.add_child(mi)
    else:
        parent.add_child(mi)
    return mi

# Зубці вздовж верху муру. along_x: тягнеться вздовж X.
func _battlement(cx: float, cz: float, y: float, length: float, along_x: bool) -> void:
    var n := maxi(2, int(length / 1.6))
    var seg := length / float(n)
    for i in range(n):
        if i % 2 == 1:
            continue
        var off := -length * 0.5 + (float(i) + 0.5) * seg
        if along_x:
            _box(Vector3(cx + off, y + 0.35, cz), Vector3(seg * 0.85, 0.7, 1.0), dark_mat)
        else:
            _box(Vector3(cx, y + 0.35, cz + off), Vector3(1.0, 0.7, seg * 0.85), dark_mat)

func _build_keep() -> void:
    _box(Vector3(0.0, WALL_H * 0.5, 0.0), Vector3(KEEP_W + 0.4, WALL_H, KEEP_D + 0.4), stone_mat)
    _battlement(0.0, KEEP_D * 0.5, WALL_H, KEEP_W - TOWER, true)
    _battlement(0.0, -KEEP_D * 0.5, WALL_H, KEEP_W - TOWER, true)
    _battlement(-KEEP_W * 0.5, 0.0, WALL_H, KEEP_D - TOWER, false)
    _battlement(KEEP_W * 0.5, 0.0, WALL_H, KEEP_D - TOWER, false)
    # головна вежа-донжон над муром
    var top_y := WALL_H + 3.5
    _box(Vector3(0.0, top_y, 0.0), Vector3(7.0, 7.0, 6.0), stone_mat)
    _box(Vector3(0.0, WALL_H + 7.15, 0.0), Vector3(7.6, 0.3, 6.6), dark_mat)
    _battlement(0.0, 3.0, WALL_H + 7.0, 7.0, true)
    _battlement(0.0, -3.0, WALL_H + 7.0, 7.0, true)
    _battlement(3.5, 0.0, WALL_H + 7.0, 6.0, false)
    _battlement(-3.5, 0.0, WALL_H + 7.0, 6.0, false)
    # вузькі вікна-бійниці на фасаді
    for x in [-5.5, 5.5]:
        _box(Vector3(float(x), 4.2, KEEP_D * 0.5 + 0.22), Vector3(0.5, 1.4, 0.1), Util.mat(Color(0.03, 0.03, 0.04), 0.9))
    _box(Vector3(0.0, WALL_H + 4.5, 3.02), Vector3(0.6, 1.5, 0.1), Util.mat(Color(1.0, 0.7, 0.3), 0.5, 1.5))
    # великий прапор на донжоні
    var pole := Util.add_mesh(vis, Util.cylinder(0.07, 0.07, 4.0), Color(0.3, 0.2, 0.1), Vector3(0.0, WALL_H + 9.4, 0.0))
    pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var flag := _box(Vector3(1.3, WALL_H + 10.4, 0.0), Vector3(2.4, 1.4, 0.06), cloth_mat)
    flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_towers() -> void:
    tower_pos = []
    for sz in [-1.0, 1.0]:
        for sx in [-1.0, 1.0]:
            var p := Vector3(float(sx) * KEEP_W * 0.5, 0.0, float(sz) * KEEP_D * 0.5)
            _box(p + Vector3(0, TOWER_H * 0.5, 0), Vector3(TOWER, TOWER_H, TOWER), stone_mat)
            _box(p + Vector3(0, TOWER_H - 0.2, 0), Vector3(TOWER + 0.5, 0.4, TOWER + 0.5), dark_mat)
            for k in range(8):
                var a := TAU * float(k) / 8.0
                var off := Vector3(cos(a), 0.0, sin(a)) * (TOWER * 0.5 + 0.1)
                _box(p + off + Vector3(0, TOWER_H + 0.35, 0), Vector3(0.8, 0.7, 0.8), dark_mat)
            # конічний дах
            var roof := Util.add_mesh(vis, Util.cylinder(0.0, TOWER * 0.62, 3.0), Color(0.18, 0.24, 0.45), p + Vector3(0, TOWER_H + 1.9, 0))
            roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var pole := Util.add_mesh(vis, Util.cylinder(0.05, 0.05, 2.0), Color(0.3, 0.2, 0.1), p + Vector3(0, TOWER_H + 4.4, 0))
            pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            var fl := _box(p + Vector3(0.6, TOWER_H + 4.8, 0), Vector3(1.1, 0.7, 0.05), cloth_mat)
            fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            tower_pos.append(p + Vector3(0, TOWER_H + 1.0, 0))
    # порядок вогнів: спершу північні вежі (далі від дороги), потім південні
    # (tower_pos: [(-,-), (+,-), (-,+), (+,+)] — перші дві північні)

func _build_gate() -> void:
    var z := KEEP_D * 0.5 + 0.25
    # арка
    _box(Vector3(0.0, 2.2, z), Vector3(4.8, 4.4, 0.5), dark_mat)
    _box(Vector3(0.0, 2.0, z + 0.2), Vector3(3.6, 4.0, 0.3), wood_mat)
    for y in [0.9, 2.0, 3.1]:
        _box(Vector3(0.0, float(y), z + 0.38), Vector3(3.6, 0.16, 0.1), Util.mat(Color(0.14, 0.14, 0.16), 0.6))
    for x in [-1.2, 0.0, 1.2]:
        _box(Vector3(float(x), 2.0, z + 0.4), Vector3(0.12, 4.0, 0.08), Util.mat(Color(0.14, 0.14, 0.16), 0.6))
    # смолоскипи біля воріт
    for sx in [-1.0, 1.0]:
        var tp := Vector3(float(sx) * 3.6, 0.0, KEEP_D * 0.5 + 1.5)
        Util.add_mesh(vis, Util.cylinder(0.06, 0.08, 2.4), Color(0.4, 0.26, 0.13), tp + Vector3(0, 1.2, 0))
        Util.add_mesh(vis, Util.sphere(0.2), Color(1.0, 0.55, 0.1), tp + Vector3(0, 2.5, 0), Vector3.ZERO, 0.4, 4.0)
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.6, 0.25)
        l.light_energy = 2.0
        l.omni_range = 12.0
        l.position = tp + Vector3(0, 2.5, 0)
        vis.add_child(l)
    # полотнища-герби на фасаді
    for sx in [-1.0, 1.0]:
        _box(Vector3(float(sx) * 6.6, 4.3, KEEP_D * 0.5 + 0.25), Vector3(1.4, 2.8, 0.06), cloth_mat)
        _box(Vector3(float(sx) * 6.6, 4.3, KEEP_D * 0.5 + 0.3), Vector3(0.3, 1.8, 0.05), Util.mat(Color(0.85, 0.7, 0.25), 0.7))

func _col_cyl(p: Vector3, r: float, h: float) -> void:
    var cs := CollisionShape3D.new()
    var sh := CylinderShape3D.new()
    sh.radius = r
    sh.height = h
    cs.shape = sh
    cs.position = Vector3(p.x, h * 0.5, p.z)
    body.add_child(cs)

# Табір перед замком: намети, вогнище, зброя, бочки, прапори. Дорога (x ≈ 0) лишається вільною.
func _build_camp() -> void:
    var wood := Color(0.4, 0.26, 0.13)
    for sx in [-1.0, 1.0]:
        var tp := Vector3(float(sx) * 15.0, 0.0, 14.0)
        var tent := Util.add_mesh(vis, Util.cylinder(0.0, 2.8, 3.0), Color(0.72, 0.68, 0.55) if sx < 0.0 else Color(0.2, 0.28, 0.5), tp + Vector3(0, 1.5, 0))
        tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        Util.add_mesh(vis, Util.box(Vector3(1.0, 1.6, 0.1)), Color(0.08, 0.06, 0.05), tp + Vector3(0, 0.8, 2.15))
        _col_cyl(tp, 2.4, 3.0)
    # вогнище
    var fp := Vector3(-8.5, 0.0, 16.0)
    for k in range(8):
        var a := TAU * float(k) / 8.0
        Util.add_mesh(vis, Util.sphere(0.28), Color(0.4, 0.38, 0.36), fp + Vector3(cos(a) * 0.9, 0.2, sin(a) * 0.9))
    Util.add_mesh(vis, Util.cylinder(0.08, 0.1, 1.0), wood, fp + Vector3(0, 0.3, 0), Vector3(0, 0, 40))
    Util.add_mesh(vis, Util.cylinder(0.08, 0.1, 1.0), wood, fp + Vector3(0, 0.3, 0), Vector3(40, 0, 0))
    Util.add_mesh(vis, Util.sphere(0.4), Color(1.0, 0.5, 0.1), fp + Vector3(0, 0.6, 0), Vector3.ZERO, 0.4, 3.0)
    var fl: OmniLight3D = FlickerLight.new()
    fl.light_color = Color(1.0, 0.55, 0.25)
    fl.light_energy = 2.4
    fl.omni_range = 13.0
    fl.position = fp + Vector3(0, 1.4, 0)
    vis.add_child(fl)
    _col_cyl(fp, 1.0, 0.6)
    # стійка зі списами
    var rp := Vector3(11.5, 0.0, 20.0)
    Util.add_mesh(vis, Util.box(Vector3(2.6, 1.1, 0.2)), wood, rp + Vector3(0, 0.55, 0))
    for i in range(5):
        Util.add_mesh(vis, Util.cylinder(0.025, 0.025, 2.0), Color(0.45, 0.32, 0.18), rp + Vector3(-1.0 + 0.5 * float(i), 1.0, 0.2), Vector3(-8, 0, 0))
        Util.add_mesh(vis, Util.cylinder(0.0, 0.05, 0.2), Color(0.62, 0.64, 0.68), rp + Vector3(-1.0 + 0.5 * float(i), 2.05, 0.1))
    _col_cyl(rp, 1.4, 1.2)
    # бочки та ящики
    for bp in [Vector3(-12.0, 0.0, 19.0), Vector3(-10.8, 0.0, 19.4), Vector3(6.8, 0.0, 9.5)]:
        Util.add_mesh(vis, Util.cylinder(0.45, 0.45, 1.0), wood, bp + Vector3(0, 0.5, 0))
        Util.add_mesh(vis, Util.cylinder(0.47, 0.47, 0.08), Color(0.2, 0.2, 0.22), bp + Vector3(0, 0.25, 0))
        Util.add_mesh(vis, Util.cylinder(0.47, 0.47, 0.08), Color(0.2, 0.2, 0.22), bp + Vector3(0, 0.75, 0))
        _col_cyl(bp, 0.5, 1.0)
    # прапори-стовпи при вході в табір
    for sx in [-1.0, 1.0]:
        var pp := Vector3(float(sx) * 5.4, 0.0, 22.0)
        var pole := Util.add_mesh(vis, Util.cylinder(0.06, 0.07, 4.2), Color(0.3, 0.2, 0.1), pp + Vector3(0, 2.1, 0))
        pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var f := _box(pp + Vector3(float(sx) * 0.6, 3.5, 0), Vector3(1.1, 1.3, 0.05), cloth_mat)
        f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- Лицарі ----------
func _spawn_knights() -> void:
    # командор і шестеро лицарів перед воротами
    _add_knight(Vector3(0.0, 0.0, 12.5), true)
    for p in [Vector3(-7.0, 0.0, 10.5), Vector3(-3.6, 0.0, 12.0), Vector3(3.6, 0.0, 12.0), Vector3(7.0, 0.0, 10.5), Vector3(-10.5, 0.0, 16.5), Vector3(10.5, 0.0, 16.5)]:
        _add_knight(p, false)

func _add_knight(local_pos: Vector3, is_commander: bool) -> void:
    var k = KnightScript.new()
    k.keep = self
    k.player = player
    k.commander = is_commander
    k.home_yaw = PI
    k.position = local_pos
    add_child(k)

# ---------- Текстура цегли ----------
func _brick_texture() -> ImageTexture:
    var n := 128
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.18, 0.17, 0.16))
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    var bh := 16
    var bw := 32
    for row in range(n / bh):
        var xoff := 0 if row % 2 == 0 else bw / 2
        for col in range(n / bw + 1):
            var s := 0.42 + rng.randf() * 0.14
            var x0 := col * bw + xoff
            for y in range(1, bh - 1):
                for x in range(1, bw - 1):
                    var kk := 0.93 + rng.randf() * 0.14
                    img.set_pixel((x0 + x) % n, row * bh + y, Color(s * kk, s * kk * 0.97, s * kk * 0.92, 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)
