extends Node3D
const ZM = preload("res://zombie_models.gd")
const ZT = preload("res://zombie_types.gd")
const HeroScript = preload("res://hero.gd")
const GuardScript = preload("res://castle_guard.gd")
const AllyScript = preload("res://ally_knight.gd")
var view := "close"
var set_name := "a"
var out := "/tmp/shots/models_a.png"
var n := 0
func _ready() -> void:
    for a in OS.get_cmdline_user_args():
        var kv := a.split("=")
        if kv[0] == "view": view = kv[1]
        elif kv[0] == "set": set_name = kv[1]
        elif kv[0] == "out": out = kv[1]
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.3, 0.4, 0.5)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.58, 0.65)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(80, 80)
    ground.mesh = pm
    var gm := StandardMaterial3D.new()
    gm.albedo_color = Color(0.32, 0.38, 0.22)
    ground.material_override = gm
    add_child(ground)
    var keys: Array = ZT.DATA.keys()
    var bosses: Array = []
    var normal: Array = []
    for k in keys:
        if ZT.DATA[k].get("boss", false):
            bosses.append(k)
        else:
            normal.append(k)
    var list: Array = []
    var cols := 8
    match set_name:
        "a": list = normal.slice(0, 24)
        "b": list = normal.slice(24, 48)
        "c": list = normal.slice(48)
        "boss": list = bosses.slice(0, 16)
        "boss2": list = bosses.slice(16)
        "crowd":
            for i in range(24):
                list.append(["walker", "infected", "clothed", "farmer", "runner", "crawler"][i % 6])
    var i := 0
    for k in list:
        var d: Dictionary = ZT.DATA[k]
        var v := Node3D.new()
        v.scale = Vector3.ONE * float(d.get("size", 1.0))
        var gap := 2.0
        if set_name.begins_with("boss"):
            gap = 4.2
        v.position = Vector3((i % cols) * gap - cols * gap * 0.5, 0, int(i / cols) * gap * 1.1)
        v.rotation.y = randf_range(-0.4, 0.4)
        add_child(v)
        ZM.build(v, d)
        i += 1
    if set_name == "c" or set_name == "hero":
        var hero = HeroScript.new()
        hero.position = Vector3(-6, 0, 9)
        hero.rotation.y = 0.0
        add_child(hero)
        hero.set_weapon("sword")
        var g = GuardScript.new()
        g.weapon = "sword"
        g.position = Vector3(-3, 0, 9)
        add_child(g)
        var g2 = GuardScript.new()
        g2.weapon = "spear"
        g2.position = Vector3(-1.5, 0, 9)
        add_child(g2)
        var ak = AllyScript.new()
        ak.position = Vector3(0, 0, 9)
        add_child(ak)
        var ak2 = AllyScript.new()
        ak2.commander = true
        ak2.position = Vector3(1.5, 0, 9)
        add_child(ak2)
    var cam := Camera3D.new()
    add_child(cam)
    var center := Vector3(0, 1, 3.0)
    if view == "close":
        var tgt := Vector3(0, 1.2, 3.5)
        if set_name.begins_with("boss"):
            tgt = Vector3(0, 2.0, 5)
        cam.fov = 45
        cam.position = tgt + Vector3(0, 5, -12) if not set_name.begins_with("boss") else tgt + Vector3(0, 10, -24)
        cam.look_at(tgt)
    else:
        cam.fov = 40
        var tgt := Vector3(0, 0.5, 3.0)
        var tilt := deg_to_rad(68.0)
        cam.position = tgt + Vector3(0, sin(tilt), cos(tilt)) * 26.0 * Vector3(1, 1, -1)
        cam.look_at(tgt)
func _process(_d: float) -> void:
    n += 1
    if n == 40:
        var img = get_viewport().get_texture().get_image()
        img.save_png(out)
        print("PREVIEW_DONE")
        get_tree().quit()
