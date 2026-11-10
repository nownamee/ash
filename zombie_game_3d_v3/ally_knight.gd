extends Node3D
# Лицар застави (союзник у місії оборони). Стоїть перед замком, а коли до замку підходять зомбі,
# іде їм назустріч і б'є мечем. Допомагає «в міру»: урон невеликий, замах повільний.
# Фізики немає (складається з примітивів), зомбі його не чіпають. Налаштування: damage, attack_cd, move_speed.

const Util = preload("res://util.gd")

const THREAT_R := 26.0      # лицар реагує на зомбі, що підійшли ближче цього до муру замку

var keep                    # замок (defend_post.gd)
var player: Node3D
var commander := false
var damage := 55.0
var attack_cd := 1.15
var move_speed := 4.2
var home_yaw := PI
var tabard := Color(0.15, 0.26, 0.58)

var home := Vector3.ZERO
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D
var head: Node3D

var t := 0.0
var phase := 0.0
var yaw := 0.0
var cd := 0.0
var swing := 0.0
var scan_t := 0.0
var foe = null

func _ready() -> void:
    home = global_position
    t = randf() * 10.0
    yaw = home_yaw
    rotation.y = yaw
    scan_t = randf() * 0.3
    if commander:
        damage = 110.0
        attack_cd = 0.95
        tabard = Color(0.55, 0.12, 0.12)
    _build()
    if commander:
        scale = Vector3.ONE * 1.18
        var tag := Label3D.new()
        tag.text = "Командор Айвор"
        tag.font_size = 48
        tag.pixel_size = 0.008
        tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        tag.no_depth_test = true
        tag.modulate = Color(1.0, 0.85, 0.35)
        tag.outline_size = 10
        tag.position = Vector3(0.0, 2.55, 0.0)
        add_child(tag)

func _build() -> void:
    var skin := Color(0.8, 0.62, 0.48)
    var plate := Color(0.58, 0.6, 0.64)
    var boot := Color(0.2, 0.13, 0.08)
    var steel := Color(0.72, 0.74, 0.78)
    var gold := Color(0.85, 0.7, 0.25)
    var trim := gold if commander else Color(0.7, 0.7, 0.74)

    leg_l = _limb(Vector3(-0.14, 0.9, 0.0), Vector3(0.22, 0.9, 0.24), Color(0.4, 0.42, 0.46))
    leg_r = _limb(Vector3(0.14, 0.9, 0.0), Vector3(0.22, 0.9, 0.24), Color(0.4, 0.42, 0.46))
    Util.add_mesh(leg_l, Util.box(Vector3(0.26, 0.22, 0.36)), boot, Vector3(0, -0.84, -0.05))
    Util.add_mesh(leg_r, Util.box(Vector3(0.26, 0.22, 0.36)), boot, Vector3(0, -0.84, -0.05))

    torso = Node3D.new()
    torso.position = Vector3(0, 1.2, 0)
    add_child(torso)
    Util.add_mesh(torso, Util.box(Vector3(0.6, 0.66, 0.34)), plate, Vector3.ZERO, Vector3.ZERO, 0.4)
    Util.add_mesh(torso, Util.box(Vector3(0.5, 0.52, 0.37)), tabard, Vector3(0, -0.06, 0))
    Util.add_mesh(torso, Util.box(Vector3(0.12, 0.54, 0.38)), trim, Vector3(0, -0.06, 0))
    Util.add_mesh(torso, Util.box(Vector3(0.64, 0.08, 0.38)), Color(0.25, 0.15, 0.08), Vector3(0, -0.32, 0))
    # наплічники
    Util.add_mesh(torso, Util.sphere(0.17), plate, Vector3(-0.36, 0.28, 0), Vector3.ZERO, 0.4)
    Util.add_mesh(torso, Util.sphere(0.17), plate, Vector3(0.36, 0.28, 0), Vector3.ZERO, 0.4)
    if commander:
        # плащ
        var cape := Util.add_mesh(torso, Util.box(Vector3(0.62, 0.95, 0.05)), Color(0.5, 0.1, 0.1), Vector3(0, -0.3, 0.22))
        cape.rotation_degrees.x = -6.0

    head = Node3D.new()
    head.position = Vector3(0, 1.72, 0)
    add_child(head)
    Util.add_mesh(head, Util.sphere(0.17), skin, Vector3.ZERO)
    var helm := Util.add_mesh(head, Util.sphere(0.23), steel, Vector3(0, 0.03, 0.0), Vector3.ZERO, 0.35)
    helm.scale = Vector3(1.0, 0.95, 1.0)
    Util.add_mesh(head, Util.box(Vector3(0.3, 0.05, 0.05)), Color(0.05, 0.05, 0.06), Vector3(0, 0.02, -0.21))   # прорізь забрала
    Util.add_mesh(head, Util.box(Vector3(0.05, 0.2, 0.05)), steel, Vector3(0, -0.03, -0.22))
    var plume_col := Color(0.85, 0.7, 0.25) if commander else Color(0.7, 0.12, 0.12)
    var plume := Util.add_mesh(head, Util.box(Vector3(0.06, 0.22, 0.34)), plume_col, Vector3(0, 0.3, 0.02))
    plume.rotation_degrees.x = 12.0

    arm_l = _limb(Vector3(-0.4, 1.45, 0.0), Vector3(0.15, 0.62, 0.15), plate)
    arm_r = _limb(Vector3(0.4, 1.45, 0.0), Vector3(0.15, 0.62, 0.15), plate)
    Util.add_mesh(arm_l, Util.sphere(0.09), steel, Vector3(0, -0.64, 0))
    Util.add_mesh(arm_r, Util.sphere(0.09), steel, Vector3(0, -0.64, 0))

    # щит із гербом на лівій руці
    var shield := Util.add_mesh(arm_l, Util.box(Vector3(0.5, 0.7, 0.07)), tabard.lightened(0.1), Vector3(-0.1, -0.42, -0.16))
    Util.add_mesh(arm_l, Util.box(Vector3(0.1, 0.62, 0.09)), gold, Vector3(-0.1, -0.42, -0.16))
    Util.add_mesh(arm_l, Util.box(Vector3(0.4, 0.1, 0.09)), gold, Vector3(-0.1, -0.35, -0.16))
    shield.rotation_degrees.y = 12.0

    # меч у правій руці
    Util.add_mesh(arm_r, Util.box(Vector3(0.08, 1.05, 0.03)), steel, Vector3(0, -1.2, 0), Vector3.ZERO, 0.3)
    Util.add_mesh(arm_r, Util.box(Vector3(0.3, 0.06, 0.06)), gold, Vector3(0, -0.7, 0))

func _limb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    add_child(n)
    Util.add_mesh(n, Util.box(size), color, Vector3(0, -size.y * 0.5, 0), Vector3.ZERO, 0.4)
    return n

# ---------- Поведінка ----------
func _physics_process(delta: float) -> void:
    t += delta
    cd = maxf(0.0, cd - delta)
    swing = maxf(0.0, swing - delta)
    scan_t -= delta
    if scan_t <= 0.0 or not _foe_ok():
        scan_t = 0.3
        foe = _find_foe()
    var moving := 0.0
    if foe != null:
        moving = _fight(delta)
    else:
        moving = _idle(delta)
    _animate(delta, moving)

func _foe_ok() -> bool:
    if foe == null or not is_instance_valid(foe):
        return false
    return not foe.dying

# Найближчий до лицаря зомбі серед тих, що біля замку. Невеликий випадковий зсув розводить лицарів по різних цілях.
func _find_foe():
    var best = null
    var best_score := 1.0e9
    var my_pos := global_position
    for n in get_tree().get_nodes_in_group("zombies"):
        var z = n
        if z.dying:
            continue
        var zp: Vector3 = z.global_position
        var wall: Vector3 = keep.attack_point(zp)
        if Vector2(zp.x - wall.x, zp.z - wall.z).length() > THREAT_R:
            continue
        var score := Vector2(zp.x - my_pos.x, zp.z - my_pos.z).length() + randf() * 5.0
        if score < best_score:
            best_score = score
            best = z
    return best

func _turn_to(dir: Vector3, delta: float, rate: float) -> void:
    if dir.length() < 0.01:
        return
    var want := atan2(-dir.x, -dir.z)
    yaw = lerp_angle(yaw, want, 1.0 - exp(-rate * delta))
    rotation.y = yaw

func _fight(delta: float) -> float:
    var fp: Vector3 = foe.global_position
    var to := fp - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := Vector3.ZERO
    if dist > 0.01:
        dir = to / dist
        _turn_to(dir, delta, 9.0)
    var reach := 1.8 * scale.x + float(foe.radius)
    if dist > reach:
        var goal: Vector3 = keep.route_point(global_position, fp)
        var gto := goal - global_position
        gto.y = 0.0
        var mdir := dir
        if gto.length() > 0.01:
            mdir = gto.normalized()
        _turn_to(mdir, delta, 9.0)
        var np := global_position + mdir * move_speed * delta
        np = keep.push_out(np, 0.9)
        global_position = np
        return 1.0
    if cd <= 0.0:
        cd = attack_cd
        swing = 0.35
        var dmg := damage * randf_range(0.85, 1.15)
        foe.take_damage(dmg, dir, 5.0, false, "")
        Sfx.play_at("swing", global_position, -4.0)
    return 0.0

func _idle(delta: float) -> float:
    var to := home - global_position
    to.y = 0.0
    if to.length() > 0.8:
        var goal: Vector3 = keep.route_point(global_position, home)
        var gto := goal - global_position
        gto.y = 0.0
        var dir := to.normalized()
        if gto.length() > 0.01:
            dir = gto.normalized()
        _turn_to(dir, delta, 6.0)
        global_position = keep.push_out(global_position + dir * move_speed * 0.7 * delta, 0.9)
        return 0.7
    var face := Vector3(-sin(home_yaw), 0.0, -cos(home_yaw))
    if player != null and is_instance_valid(player):
        var pt := player.global_position - global_position
        pt.y = 0.0
        if pt.length() < 8.0:
            face = pt.normalized()
    _turn_to(face, delta, 3.0)
    return 0.0

func _animate(delta: float, moving: float) -> void:
    if moving > 0.0:
        phase += delta * move_speed * 3.4 * moving
    var sw := sin(phase) * 0.6 * minf(moving, 1.0)
    leg_l.rotation.x = sw
    leg_r.rotation.x = -sw
    var breathe := sin(t * 1.8) * 0.012
    torso.scale = Vector3(1.0, 1.0 + breathe, 1.0)
    head.position.y = 1.72 + breathe * 1.5
    arm_l.rotation.x = -sw * 0.6
    if swing > 0.0:
        # замах над плечем і удар зверху вниз
        var k := 1.0 - swing / 0.35
        arm_r.rotation.x = lerpf(-2.5, 0.5, k * k)
        torso.rotation.x = lerpf(0.0, -0.25, sin(k * PI))
    else:
        arm_r.rotation.x = sw * 0.6
        torso.rotation.x = 0.0
