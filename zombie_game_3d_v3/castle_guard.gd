extends Node3D
# Союзний солдат у замку (перша локація). Не б'ється і не допомагає — просто живе:
# стоїть на варті, ходить по двору або тренується в парі. Складається з примітивів, без фізики.
#
# mode:  "stand" — вартовий (повертається до героя, коли той близько),
#        "patrol" — ходить між точками двору,
#        "spar" — тренувальний бій на мечах (задайте partner),
#        "ext" — керується зовні (лицар у бою: knight.gd сам повертає й рухає, задає ext_moving).

const Util = preload("res://util.gd")

var mode := "stand"
var weapon := "spear"            # "spear" або "sword"
var points: Array = []           # точки патрулювання
var obstacles: Array = []        # [Vector3(x, 0, z), радіус] — колодязь, ящики тощо
var player: Node3D
var partner: Node3D
var home_yaw := 0.0
var tabard := Color(0.15, 0.26, 0.58)

var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D
var head: Node3D

var t := 0.0
var phase := 0.0
var wait := 0.0
var target_i := 0
var yaw := 0.0
var spar_t := 0.0
var ext_moving := 0.0            # для режиму "ext": 1.0 — іде, 0.0 — стоїть
var speed := 1.7

func _ready() -> void:
    t = randf() * 10.0
    yaw = home_yaw
    rotation.y = yaw
    wait = randf_range(0.5, 3.0)
    if not points.is_empty():
        target_i = randi() % points.size()
    _build()

func _build() -> void:
    var skin := Color(0.8, 0.62, 0.48)
    var mail := Color(0.45, 0.47, 0.5)
    var boot := Color(0.2, 0.13, 0.08)
    var steel := Color(0.62, 0.64, 0.68)
    var wood := Color(0.4, 0.27, 0.14)

    leg_l = _limb(Vector3(-0.13, 0.9, 0.0), Vector3(0.2, 0.9, 0.22), Color(0.22, 0.2, 0.2))
    leg_r = _limb(Vector3(0.13, 0.9, 0.0), Vector3(0.2, 0.9, 0.22), Color(0.22, 0.2, 0.2))
    Util.add_mesh(leg_l, Util.box(Vector3(0.24, 0.22, 0.34)), boot, Vector3(0, -0.84, -0.05))
    Util.add_mesh(leg_r, Util.box(Vector3(0.24, 0.22, 0.34)), boot, Vector3(0, -0.84, -0.05))

    torso = Node3D.new()
    torso.position = Vector3(0, 1.2, 0)
    add_child(torso)
    Util.add_mesh(torso, Util.box(Vector3(0.52, 0.64, 0.3)), mail, Vector3.ZERO)
    Util.add_mesh(torso, Util.box(Vector3(0.46, 0.5, 0.33)), tabard, Vector3(0, -0.04, 0))      # накидка
    Util.add_mesh(torso, Util.box(Vector3(0.56, 0.08, 0.34)), Color(0.25, 0.15, 0.08), Vector3(0, -0.3, 0))  # пояс

    head = Node3D.new()
    head.position = Vector3(0, 1.7, 0)
    add_child(head)
    Util.add_mesh(head, Util.sphere(0.17), skin, Vector3.ZERO)
    var helm := Util.add_mesh(head, Util.sphere(0.2), steel, Vector3(0, 0.05, 0.0))
    helm.scale = Vector3(1.0, 0.75, 1.0)
    Util.add_mesh(head, Util.box(Vector3(0.05, 0.16, 0.05)), steel, Vector3(0, -0.02, -0.19))       # наносник

    arm_l = _limb(Vector3(-0.34, 1.45, 0.0), Vector3(0.14, 0.62, 0.14), mail)
    arm_r = _limb(Vector3(0.34, 1.45, 0.0), Vector3(0.14, 0.62, 0.14), mail)
    Util.add_mesh(arm_l, Util.sphere(0.08), skin, Vector3(0, -0.64, 0))
    Util.add_mesh(arm_r, Util.sphere(0.08), skin, Vector3(0, -0.64, 0))

    # щит на лівій руці
    var shield := Util.add_mesh(arm_l, Util.box(Vector3(0.46, 0.6, 0.06)), tabard.lightened(0.1), Vector3(-0.1, -0.42, -0.14))
    Util.add_mesh(arm_l, Util.box(Vector3(0.1, 0.5, 0.08)), Color(0.8, 0.7, 0.3), Vector3(-0.1, -0.42, -0.14))
    shield.rotation_degrees.y = 12.0

    if weapon == "spear":
        Util.add_mesh(arm_r, Util.cylinder(0.03, 0.03, 2.3), wood, Vector3(0.02, -0.38, -0.04))
        Util.add_mesh(arm_r, Util.cylinder(0.0, 0.06, 0.28), steel, Vector3(0.02, 0.9, -0.04))
    else:
        Util.add_mesh(arm_r, Util.box(Vector3(0.07, 0.95, 0.025)), steel, Vector3(0, -1.15, 0))
        Util.add_mesh(arm_r, Util.box(Vector3(0.26, 0.05, 0.05)), Color(0.5, 0.4, 0.15), Vector3(0, -0.7, 0))

func _limb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    add_child(n)
    Util.add_mesh(n, Util.box(size), color, Vector3(0, -size.y * 0.5, 0))
    return n

func _process(delta: float) -> void:
    t += delta
    var moving := 0.0
    match mode:
        "patrol":
            moving = _patrol(delta)
        "spar":
            _spar(delta)
        "ext":
            moving = ext_moving
        _:
            _guard(delta)
    _animate(delta, moving)

func _turn_to(dir: Vector3, delta: float, rate: float = 5.0) -> void:
    if dir.length() < 0.01:
        return
    var want := atan2(-dir.x, -dir.z)
    yaw = lerp_angle(yaw, want, 1.0 - exp(-rate * delta))
    rotation.y = yaw

# Плавно повернути солдата обличчям до напрямку (використовує knight.gd).
func turn_toward(dir: Vector3, delta: float, rate: float = 5.0) -> void:
    _turn_to(dir, delta, rate)

func _guard(delta: float) -> void:
    var face := Vector3(-sin(home_yaw), 0.0, -cos(home_yaw))
    if player != null and is_instance_valid(player):
        var to := player.global_position - global_position
        to.y = 0.0
        if to.length() < 6.0:
            face = to.normalized()
    _turn_to(face, delta, 3.0)

func _patrol(delta: float) -> float:
    if points.is_empty():
        return 0.0
    if wait > 0.0:
        wait -= delta
        _guard(delta)
        return 0.0
    var goal: Vector3 = points[target_i]
    var to := goal - position
    to.y = 0.0
    if to.length() < 0.35:
        target_i = randi() % points.size()
        wait = randf_range(2.0, 5.0)
        return 0.0
    var dir := to.normalized()
    _turn_to(dir, delta, 6.0)
    position += dir * speed * delta
    # обхід колодязя, ящиків і бочок
    for o in obstacles:
        var c: Vector3 = o[0]
        var r: float = float(o[1])
        var d := Vector3(position.x - c.x, 0.0, position.z - c.z)
        if d.length() < r:
            var push := d.normalized() if d.length() > 0.01 else Vector3.RIGHT
            position.x = c.x + push.x * r
            position.z = c.z + push.z * r
    return 1.0

func _spar(delta: float) -> void:
    spar_t += delta
    if partner != null and is_instance_valid(partner):
        var to := partner.global_position - global_position
        to.y = 0.0
        _turn_to(to, delta, 6.0)

func _animate(delta: float, moving: float) -> void:
    if moving > 0.0:
        phase += delta * speed * 4.2
    var sw := sin(phase) * 0.6 * moving
    leg_l.rotation.x = sw
    leg_r.rotation.x = -sw
    var breathe := sin(t * 1.8) * 0.012
    torso.scale = Vector3(1.0, 1.0 + breathe, 1.0)
    head.position.y = 1.7 + breathe * 1.5

    if mode == "spar":
        # по черзі: випад — парирування щитом
        var k := sin(spar_t * 3.2 + (0.0 if get_index() % 2 == 0 else PI))
        arm_r.rotation.x = 0.9 + maxf(k, 0.0) * 0.9
        arm_r.rotation.z = -0.15 + k * 0.25
        arm_l.rotation.x = 0.5 + maxf(-k, 0.0) * 0.5
        torso.rotation.x = -maxf(k, 0.0) * 0.12
    elif mode == "ext":
        # права рука повертається з пози удару (її виставляє knight.gd) до кроку
        arm_l.rotation.x = -sw * 0.6
        arm_r.rotation.x = lerpf(arm_r.rotation.x, sw * 0.6, 1.0 - exp(-8.0 * delta))
    else:
        arm_l.rotation.x = -sw * 0.6
        if weapon == "spear":
            arm_r.rotation.x = 0.0
        else:
            arm_r.rotation.x = sw * 0.6
