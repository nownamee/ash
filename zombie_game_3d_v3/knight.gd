extends CharacterBody3D
# Пораненний лицар, якого треба провести до замку (місія з ескортом).
# Чекає в таборі; коли герой підходить — іде за ним, відбивається від зомбі поруч.
# Зомбі нападають і на нього (див. zombie.gd). Якщо hp впаде до нуля — місія провалена.

const Util = preload("res://util.gd")
const GuardScript = preload("res://castle_guard.gd")
const Fx = preload("res://effects.gd")

signal joined
signal died
signal hp_changed

var player: Node3D
var state := "waiting"          # waiting -> following -> dead
var max_hp := 320
var hp := 320
var armor := 0.35
var atk_cd := 0.0
var flash := 0.0
var look
var bar_fg: MeshInstance3D
var bar_bg: MeshInstance3D
const BAR_W := 1.4

func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 8
    collision_mask = 4
    add_to_group("knight")
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.42
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)
    look = GuardScript.new()
    look.mode = "ext"
    look.weapon = "sword"
    look.tabard = Color(0.72, 0.55, 0.12)
    add_child(look)
    _build_bar()

func _bar_mat(color: Color, prio: int) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.no_depth_test = true
    m.render_priority = prio
    return m

func _build_bar() -> void:
    var q1 := QuadMesh.new()
    q1.size = Vector2(BAR_W, 0.18)
    bar_bg = MeshInstance3D.new()
    bar_bg.mesh = q1
    bar_bg.material_override = _bar_mat(Color(0, 0, 0, 0.75), 0)
    bar_bg.position = Vector3(0, 2.4, 0)
    bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_bg)
    var q2 := QuadMesh.new()
    q2.size = Vector2(BAR_W, 0.13)
    bar_fg = MeshInstance3D.new()
    bar_fg.mesh = q2
    bar_fg.material_override = _bar_mat(Color(0.3, 0.85, 0.3, 1.0), 1)
    bar_fg.position = Vector3(0, 2.4, 0)
    bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_fg)

func _update_bar() -> void:
    var r := clampf(float(hp) / float(max_hp), 0.0, 1.0)
    var w := maxf(0.001, BAR_W * r)
    (bar_fg.mesh as QuadMesh).size = Vector2(w, 0.13)
    bar_fg.position.x = -(BAR_W - w) * 0.5
    var c := Color(0.3, 0.85, 0.3)
    if r < 0.5:
        c = Color(0.95, 0.75, 0.2)
    if r < 0.25:
        c = Color(0.9, 0.2, 0.15)
    (bar_fg.material_override as StandardMaterial3D).albedo_color = c

func is_active() -> bool:
    return state == "following"

func _physics_process(delta: float) -> void:
    if state == "dead" or player == null or not is_instance_valid(player):
        return
    atk_cd = maxf(0.0, atk_cd - delta)
    var to: Vector3 = player.global_position - global_position
    to.y = 0.0
    var d := to.length()
    if state == "waiting":
        look.ext_moving = 0.0
        if d < 14.0:
            look.turn_toward(to, delta, 4.0)
        if d < 6.5:
            state = "following"
            joined.emit()
        return
    var moving := 0.0
    var dir := to / maxf(d, 0.01)
    if d > 3.2:
        var spd := 6.4
        if d > 9.0:
            spd = 8.6
        velocity = dir * spd
        velocity.y = 0.0
        move_and_slide()
        moving = 1.0
        look.turn_toward(dir, delta, 8.0)
    # б'є найближчого зомбі поруч
    var best: Node3D = null
    var bd := 2.6
    for z in get_tree().get_nodes_in_group("zombies"):
        var zd := Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z).length()
        if zd < bd:
            bd = zd
            best = z
    if best != null:
        var zdir: Vector3 = best.global_position - global_position
        zdir.y = 0.0
        look.turn_toward(zdir, delta, 10.0)
        if atk_cd <= 0.0:
            atk_cd = 1.0
            best.take_damage(16.0, zdir, 6.0, false, "")
            look.arm_r.rotation.x = -1.2
    look.ext_moving = moving

func take_damage(amount: int, _slow_secs: float = 0.0) -> void:
    if state == "dead":
        return
    var dmg := maxi(1, int(ceil(float(amount) * (1.0 - armor))))
    hp -= dmg
    Fx.burst(get_parent(), global_position + Vector3(0, 1.1, 0), Color(0.8, 0.1, 0.1), 6, 3.5, 0.08)
    _update_bar()
    hp_changed.emit()
    if hp <= 0:
        hp = 0
        state = "dead"
        remove_from_group("knight")
        bar_bg.visible = false
        bar_fg.visible = false
        var tw := create_tween()
        tw.tween_property(look, "rotation:x", -PI * 0.5, 0.5)
        died.emit()
