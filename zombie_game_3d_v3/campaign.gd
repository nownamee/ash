extends Node3D
# Кампанійні цілі й небезпеки не входять до лічильника хвиль.

const Util = preload("res://util.gd")
const Target = preload("res://campaign_target.gd")
const COLORS := {"tide": Color(0.12, 0.66, 0.62), "bells": Color(0.72, 0.56, 0.25), "glass": Color(0.58, 0.32, 0.76), "iron": Color(0.76, 0.30, 0.12)}
const TITLES := {"tide": "ЧОРНИЙ ПРИПЛИВ", "bells": "ХОР ПОРОЖНІХ ДЗВОНІВ", "glass": "СКЛЯНА НІЧ", "iron": "ЗАЛІЗНИЙ МОР"}
const TIDE_LOW := 20.0
const TIDE_WARNING := 4.0
const TIDE_HIGH := 12.0
const HOLD_SECONDS := 45.0

var level
var theme := ""
var stage := 1
var elapsed := 0.0
var targets: Array = []
var hazards: Array = []
var gates: Array = []
var waters: Array = []
var water_rects: Array[Rect2] = []
var conveyors: Array[Rect2] = []
var presses: Array[Vector3] = []
var hold := 0.0
var hold_point := Vector3(0.0, 0.0, -64.0)
var hold_ring: MeshInstance3D
var lighthouse: MeshInstance3D
var tide_phase := "ВІДЛИВ"
var environment_timer := 6.0
var echo_timer := 0.0
var boss_timer := 5.0
var boss_summons := 0
var last_boss: int = 0
var label: Label
var stopped := false

static func clear_zones() -> Array:
    return [[Vector2(0, -22), Vector2(0, -94), 11.0], [Vector2(-32, -48), Vector2(32, -48), 8.0], [Vector2(-32, -68), Vector2(32, -68), 8.0]]

func _ready() -> void:
    theme = String(level.loc["campaign"])
    stage = int(level.loc["stage"])
    _build_hud()
    match theme:
        "tide": _build_tide()
        "bells": _build_bells()
        "glass": _build_glass()
        "iron": _build_iron()
    _refresh_markers()
    _update_hud()

func _build_hud() -> void:
    var panel := PanelContainer.new()
    panel.position = Vector2(16, 92)
    panel.custom_minimum_size = Vector2(600, 0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.022, 0.03, 0.92)
    style.border_color = COLORS[theme].darkened(0.25)
    style.set_border_width_all(1)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    panel.add_theme_stylebox_override("panel", style)
    label = Label.new()
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", COLORS[theme].lightened(0.4))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)
    level.ui.add_child(panel)

func _target(kind: String, pos: Vector3, title: String, required: bool = false):
    var target = Target.new()
    target.kind = kind
    target.label_text = title
    target.color = COLORS[theme]
    target.max_hp = 140.0 + float(stage) * 20.0
    target.hp = target.max_hp
    target.position = pos
    target.set_meta("required", required)
    target.set_meta("released", false)
    target.set_meta("copies", 0)
    target.destroyed.connect(_on_target_destroyed)
    add_child(target)
    targets.append(target)
    return target

func _floor(pos: Vector3, extent: Vector2, color: Color) -> MeshInstance3D:
    return Util.add_mesh(self, Util.box(Vector3(extent.x, 0.07, extent.y)), color, pos + Vector3(0, 0.08, 0))

func _circle(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
    return Util.add_mesh(self, Util.cylinder(radius, radius, 0.035), color, pos + Vector3(0, 0.12, 0), Vector3.ZERO, 0.7, 0.4)

func _ring(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
    var torus := TorusMesh.new()
    torus.inner_radius = maxf(0.01, radius - 0.16)
    torus.outer_radius = radius + 0.16
    torus.rings = 48
    torus.ring_segments = 6
    return Util.add_mesh(self, torus, color, pos + Vector3(0, 0.22, 0), Vector3.ZERO, 0.7, 0.6)

func _gate(target, extent: Vector2) -> void:
    var body := StaticBody3D.new()
    body.position = target.position
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(extent.x, 2.6, extent.y)
    shape.shape = box
    shape.position.y = 1.3
    body.add_child(shape)
    Util.add_mesh(body, Util.box(box.size), COLORS[theme].darkened(0.6), Vector3(0, 1.3, 0))
    add_child(body)
    gates.append({"target": target, "body": body})

func _build_tide() -> void:
    for x in [-22.0, 22.0]:
        var rect := Rect2(Vector2(x - 9.0, -94.0), Vector2(18.0, 66.0))
        water_rects.append(rect)
        waters.append(_floor(Vector3(x, 0.02, -61), rect.size, Color(0.025, 0.19, 0.21, 0.5)))
        for z in [-38.0, -60.0, -82.0]:
            _floor(Vector3(x, 0.17, z), Vector2(19, 2.5), Color(0.16, 0.12, 0.075))
    if stage == 2:
        for x in [-10.0, 10.0]:
            var wreck = _target("drive", Vector3(x, 0, -48), "РОЗБИЙ УЛАМОК")
            _gate(wreck, Vector2(5, 1.0))
    if stage == 3:
        for pos in [Vector3(-25, 0, -48), Vector3(25, 0, -68), Vector3(0, 0, -84)]:
            _target("nest", pos, "ОСЕРЕДОК ПОТОПЕЛЬНИКІВ", true)
    if stage == 4:
        hold_ring = _circle(hold_point, 10.0, Color(0.15, 0.65, 0.58, 0.12))
        Util.add_mesh(self, Util.cylinder(1.2, 2.0, 11), Color(0.24, 0.25, 0.24), hold_point + Vector3(0, 5.5, 0))
        lighthouse = Util.add_mesh(self, Util.sphere(1.2), Color(0.15, 0.25, 0.24), hold_point + Vector3(0, 11.5, 0))
        level.minimap.goal = hold_point
    if stage == 5:
        for x in [-18.0, 18.0]:
            for z in [-45.0, -78.0]:
                Util.add_mesh(self, Util.cylinder(0.9, 1.2, 9), Color(0.19, 0.23, 0.24), Vector3(x, 4.5, z))

func _build_bells() -> void:
    var positions: Array = [Vector3(0, 0, -48)] if stage == 1 else [Vector3(-25, 0, -48), Vector3(25, 0, -68), Vector3(0, 0, -84)]
    for pos in positions:
        _target("bell", pos, "ПРОКЛЯТИЙ ДЗВІН" if stage != 4 else "РЕЗОНАТОР", stage < 5)
    if stage == 5:
        for x in [-8.0, 8.0]:
            Util.add_mesh(self, Util.box(Vector3(3, 14, 3)), Color(0.22, 0.21, 0.22), Vector3(x, 7, -88))
        Util.add_mesh(self, Util.box(Vector3(19, 3, 5)), Color(0.17, 0.16, 0.18), Vector3(0, 14, -88))

func _build_glass() -> void:
    if stage >= 2:
        for pos in [Vector3(-25, 0, -48), Vector3(25, 0, -68), Vector3(0, 0, -84)]:
            var mirror = _target("mirror", pos, "ДЗЕРКАЛЬНИЙ ВУЗОЛ", stage == 3 or stage == 4)
            if stage == 2:
                _gate(mirror, Vector2(7, 0.6))
    for x in [-12.0, 12.0]:
        for z in [-38.0, -62.0, -86.0]:
            Util.add_mesh(self, Util.cylinder(0, 0.7, 5), Color(0.13, 0.065, 0.19), Vector3(x, 2.5, z), Vector3(0, 0, x))

func _build_iron() -> void:
    for i in range(3):
        var p := Vector3(-20.0 + 20.0 * float(i), 0, -48.0 - 10.0 * float(i))
        presses.append(p)
        for x in [-3.8, 3.8]:
            Util.add_mesh(self, Util.box(Vector3(0.6, 5, 0.6)), Color(0.22, 0.10, 0.04), p + Vector3(x, 2.5, 0))
        Util.add_mesh(self, Util.box(Vector3(8.5, 0.7, 2)), Color(0.30, 0.14, 0.06), p + Vector3(0, 5, 0))
        if stage >= 2:
            _target("drive", p + Vector3(0, 0, 5), "ПРИВІД %d" % (i + 1), stage == 4)
    if stage == 3:
        for x in [-20.0, 20.0]:
            var rect := Rect2(Vector2(x - 3, -87), Vector2(6, 42))
            conveyors.append(rect)
            _floor(Vector3(x, 0, -66), rect.size, Color(0.13, 0.12, 0.09))
            for z in range(-85, -43, 4):
                _floor(Vector3(x, 0.04, z), Vector2(5.8, 0.25), Color(0.45, 0.26, 0.12))
    if stage == 5:
        Util.add_mesh(self, Util.sphere(3), Color(0.32, 0.09, 0.035), Vector3(0, 4, -85))
        for x in [-4.0, 4.0]:
            Util.add_mesh(self, Util.cylinder(0.4, 0.4, 8), Color(0.20, 0.11, 0.07), Vector3(x, 4, -85))

func _process(delta: float) -> void:
    if level.state != "playing" or level.player.dead:
        if not stopped:
            stopped = true
            for h in hazards:
                h["mesh"].queue_free()
            hazards.clear()
        return
    if level.castle_wait:
        _update_hud()
        return
    elapsed += delta
    _update_hazards(delta)
    match theme:
        "tide": _update_tide(delta)
        "bells": _update_bells(delta)
        "glass": _update_glass(delta)
        "iron": _update_iron(delta)
    _update_boss(delta)
    _refresh_markers()
    _update_hud()

func _update_tide(delta: float) -> void:
    var cycle := TIDE_LOW + TIDE_WARNING + TIDE_HIGH
    var t := fmod(elapsed, cycle)
    var previous := tide_phase
    tide_phase = "ВІДЛИВ" if t < TIDE_LOW else ("ПРИПЛИВ ЧЕРЕЗ %d с" % int(ceilf(TIDE_LOW + TIDE_WARNING - t)) if t < TIDE_LOW + TIDE_WARNING else "ПРИПЛИВ")
    var high := t >= TIDE_LOW + TIDE_WARNING
    if high and previous != "ПРИПЛИВ":
        Sfx.play("tide_surge", -8)
    for water in waters:
        water.position.y = 0.18 if high else 0.035
        water.material_override.albedo_color = Color(0.025, 0.24, 0.27, 0.72 if high else 0.20)
    if high and _in_tide_water(level.player.global_position):
        level.player.slow_time = maxf(level.player.slow_time, 0.15)
    for z in get_tree().get_nodes_in_group("zombies"):
        if z.dying or String(z.data.get("campaign", "")) != "tide":
            continue
        if stage == 4 and hold >= HOLD_SECONDS and _flat_distance(z.global_position, hold_point) < 18.0:
            z.campaign_speed_mult = 1.0
            z.campaign_speed_buff_t = 0.0
        elif high and _in_tide_water(z.global_position):
            z.receive_campaign_speed_buff(1.12, 0.25)
    if stage == 4:
        var nearby := _flat_distance(level.player.global_position, hold_point) < 10.0
        if nearby:
            hold = minf(HOLD_SECONDS, hold + delta)
        if hold >= HOLD_SECONDS:
            lighthouse.material_override = Util.mat(Color(0.6, 0.95, 0.78), 0.6, 2)
            # Світло знімає припливне сповільнення в подвір'ї маяка.
            if nearby:
                level.player.slow_time = 0.0

func _update_bells(delta: float) -> void:
    environment_timer -= delta
    if environment_timer <= 0:
        environment_timer = 8.0
        for target in _living_targets():
            var h := _hazard(target.global_position, 10.0, 15, "ring", 1.4)
            h["source"] = target
            for z in get_tree().get_nodes_in_group("zombies"):
                if not z.dying and _flat_distance(z.global_position, target.global_position) < 10.0:
                    z.receive_campaign_speed_buff(1.18, 6.0)
        if not _living_targets().is_empty():
            Sfx.play("bell_pulse", -9)
    if stage >= 3:
        _echo_attacks(delta)

func _update_glass(delta: float) -> void:
    if stage >= 3:
        _echo_attacks(delta)
        environment_timer -= delta
        if environment_timer <= 0:
            environment_timer = 16.0
            for target in _living_targets():
                var count := int(target.get_meta("copies", 0))
                if count < 2:
                    var z = level._spawn_zombie("glass_double")
                    z.reward = 0
                    z.global_position = level._free_spot(target.global_position + Vector3(3, 0, 3))
                    target.set_meta("copies", count + 1)

func _update_iron(delta: float) -> void:
    environment_timer -= delta
    if environment_timer <= 0:
        environment_timer = 5.0 if stage < 4 else 3.6
        for i in range(presses.size()):
            if stage >= 2 and targets[i].dying:
                continue
            var h := _hazard(presses[i], 3.3, 28, "circle", 1.5 + 0.35 * float(i), true)
            h["press"] = true
            if stage >= 2:
                h["source"] = targets[i]
    for rect in conveyors:
        _convey(level.player, rect, delta)
        for z in get_tree().get_nodes_in_group("zombies"):
            if not z.dying:
                _convey(z, rect, delta)

func _convey(body, rect: Rect2, delta: float) -> void:
    if rect.has_point(Vector2(body.global_position.x, body.global_position.z)):
        body.move_and_collide(Vector3(0, 0, 1.8 * delta))

func on_enemy_spawned(z) -> void:
    if z.has_signal("campaign_attack"):
        z.campaign_attack.connect(_on_enemy_attack)

func _echo_attacks(delta: float) -> void:
    echo_timer = maxf(0.0, echo_timer - delta)

func _on_enemy_attack(origin: Vector3, target_position: Vector3) -> void:
    if theme not in ["glass", "bells"] or stage < 3 or echo_timer > 0.0:
        return
    if level.state != "playing" or _living_targets().is_empty():
        return
    if _flat_distance(origin, level.player.global_position) > 18.0:
        return
    echo_timer = 7.0
    _hazard(target_position, 2.4, 18, "circle", 1.2)
    Sfx.play_at("glass_echo" if theme == "glass" else "bell_pulse", origin, -12)

func _update_boss(delta: float) -> void:
    if stage != 5:
        return
    var boss = null
    for z in get_tree().get_nodes_in_group("zombies"):
        if z.dying:
            continue
        if z.kind in ["drowned_admiral", "tongueless_bellringer", "mirror_king", "stitched_machinist"]:
            boss = z
            break
    if boss == null:
        return
    if last_boss != boss.get_instance_id():
        last_boss = boss.get_instance_id()
        if theme == "glass":
            var truth := Label3D.new()
            truth.text = "СПРАВЖНІЙ"
            truth.font_size = 46
            truth.modulate = Color(1, 0.8, 0.25)
            truth.position.y = 4.6
            truth.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            boss.add_child(truth)
    boss_timer -= delta
    if boss_timer > 0:
        return
    boss_timer = 7.0 + float(3 - _living_targets().size()) * 0.7
    var at: Vector3 = level.player.global_position
    match theme:
        "tide":
            var anchor := _hazard(at, 3.5, 26, "circle", 1.5)
            anchor["pull"] = boss.global_position
            _hazard(at + Vector3(6, 0, -3), 3.0, 22, "circle", 1.9)
            if boss_summons < 4:
                _summon("tide_drowned", 2)
        "bells":
            _hazard(boss.global_position, 18.0, 24, "ring", 1.5)
            if not _living_targets().is_empty():
                var h := _hazard(at, 3.0, 20, "circle", 1.5)
                h["delay"] = 1.2
        "glass":
            _hazard(at, 3.0, 24, "circle", 1.2)
            var h := _hazard(at, 3.0, 24, "circle", 1.2)
            h["delay"] = 1.2
            if boss_summons < 4:
                _summon("glass_double", 2)
        "iron":
            var attacks := maxi(1, _living_targets().size())
            for i in range(attacks):
                _hazard(at + Vector3(5.0 * float(i - 1), 0, 0), 3.0, 30, "circle", 1.4 + 0.25 * float(i), true)

func _summon(kind: String, count: int) -> void:
    for i in range(count):
        var z = level._spawn_zombie(kind)
        z.reward = 0
        boss_summons += 1

func _hazard(pos: Vector3, radius: float, damage: int, shape: String = "circle", warning: float = 1.2, enemies: bool = false) -> Dictionary:
    var mesh := _ring(Vector3(pos.x, 0, pos.z), radius, Color(1.0, 0.68, 0.12, 0.7)) if shape == "ring" else _circle(Vector3(pos.x, 0, pos.z), radius, Color(1.0, 0.68, 0.12, 0.22))
    var h := {"pos": Vector3(pos.x, 0, pos.z), "radius": radius, "damage": damage, "shape": shape, "warning": warning, "time": 0.0, "delay": 0.0, "enemies": enemies, "mesh": mesh, "hit": {}, "sounded": false}
    hazards.append(h)
    return h

func _update_hazards(delta: float) -> void:
    for i in range(hazards.size() - 1, -1, -1):
        var h: Dictionary = hazards[i]
        if float(h["delay"]) > 0:
            h["delay"] = float(h["delay"]) - delta
            h["mesh"].visible = false
            continue
        h["mesh"].visible = true
        h["time"] = float(h["time"]) + delta
        var active := float(h["time"]) >= float(h["warning"])
        var life := 1.8 if h["shape"] == "ring" else 0.35
        var age := float(h["time"]) - float(h["warning"])
        if active:
            h["mesh"].material_override.albedo_color = Color(0.95, 0.16, 0.10, 0.40)
            if h["shape"] == "ring":
                var scale_now := clampf(age / life, 0.03, 1.0)
                h["mesh"].scale = Vector3(scale_now, 1, scale_now)
            if not bool(h["sounded"]):
                h["sounded"] = true
                if bool(h.get("press", false)):
                    Sfx.play_at("iron_press", h["pos"], -10)
            _hazard_hit(h, level.player, true, age / life)
            if bool(h["enemies"]):
                for z in get_tree().get_nodes_in_group("zombies"):
                    if not z.dying:
                        _hazard_hit(h, z, false, age / life)
        else:
            h["mesh"].material_override.albedo_color.a = 0.15 + 0.12 * sin(float(h["time"]) * 12.0)
        if age > life:
            h["mesh"].queue_free()
            hazards.remove_at(i)

func _hazard_hit(h: Dictionary, body, hero: bool, progress: float) -> void:
    var id: int = body.get_instance_id()
    if h["hit"].has(id):
        return
    var distance := _flat_distance(body.global_position, h["pos"])
    var inside := distance <= float(h["radius"])
    if h["shape"] == "ring":
        inside = absf(distance - float(h["radius"]) * clampf(progress, 0.0, 1.0)) < 1.2
    if not inside:
        return
    h["hit"][id] = true
    if hero:
        var can_pull: bool = body.invuln <= 0.0 and not body.jump_active
        body.take_damage(int(h["damage"]), 0.0)
        if h.has("pull") and can_pull:
            var pull: Vector3 = h["pull"] - body.global_position
            pull.y = 0.0
            body.move_and_collide(pull.normalized() * minf(2.5, pull.length()))
    else:
        body.take_damage(float(h["damage"]) * 12.0, body.global_position - h["pos"], 2.0, false, "")

func _on_target_destroyed(target) -> void:
    for gate in gates:
        if gate["target"] == target and is_instance_valid(gate["body"]):
            gate["body"].queue_free()
    if theme == "bells":
        for z in get_tree().get_nodes_in_group("zombies"):
            var supported := false
            for source in _living_targets():
                if _flat_distance(z.global_position, source.global_position) < 10.0:
                    supported = true
            if not supported:
                z.campaign_speed_mult = 1.0
                z.campaign_speed_buff_t = 0.0
    if theme == "iron" and stage >= 2 and not bool(target.get_meta("released")) and level.state == "playing":
        target.set_meta("released", true)
        for i in range(2):
            var z = level._spawn_zombie("iron_worker")
            z.reward = 0
    Sfx.play_at("glass_echo" if theme == "glass" else ("iron_press" if theme == "iron" else "bell_pulse"), target.global_position, -12)
    for i in range(hazards.size() - 1, -1, -1):
        if hazards[i].get("source") == target:
            hazards[i]["mesh"].queue_free()
            hazards.remove_at(i)
    _refresh_markers()
    _update_hud()

func _living_targets() -> Array:
    var result: Array = []
    for target in targets:
        if is_instance_valid(target) and not target.dying:
            result.append(target)
    return result

func objectives_complete() -> bool:
    for target in _living_targets():
        if bool(target.get_meta("required", false)):
            return false
    return theme != "tide" or stage != 4 or hold >= HOLD_SECONDS

func _refresh_markers() -> void:
    level.minimap.markers = _living_targets()
    if theme == "tide" and stage == 4:
        level.minimap.goal = hold_point if hold < HOLD_SECONDS else Vector3.ZERO

func _update_hud() -> void:
    var detail := ""
    if level.castle_wait:
        detail = "Вийди за браму. Жовті ромби — цілі; бий їх своєю зброєю."
    elif theme == "tide":
        detail = tide_phase + " · Центральна стежка завжди суха"
        if stage == 3:
            detail += "\nОсередки: %d/3 — знищ їх і заверши бій" % (3 - _living_targets().size())
        if stage == 4:
            detail += "\nУтримуй двір маяка: %d/%d с" % [int(hold), int(HOLD_SECONDS)]
    elif theme == "bells":
        detail = "Дзвони: %d · Знищ їх, щоб прибрати хвилі резонансу" % _living_targets().size()
    elif theme == "glass":
        if stage == 1:
            detail = "Слабкі двійники мають світні тріщини. Не дай їм оточити себе."
        elif stage == 2:
            detail = "Розбий скляні пластини, щоб відкрити короткі проходи."
        else:
            detail = "Вузли: %d · Відлуння удару через 1,2 с" % _living_targets().size()
    else:
        detail = ("Преси: 3" if stage == 1 else "Приводи: %d" % _living_targets().size()) + " · Пастки шкодять також мерцям"
    if not level.castle_wait and not objectives_complete():
        detail += "\nДля перемоги виконай цілі та здолай усі хвилі."
    label.text = "%s · %d/5\n%s" % [TITLES[theme], stage, detail]

func _flat_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()

func _in_rects(pos: Vector3, rects: Array[Rect2]) -> bool:
    for rect in rects:
        if rect.has_point(Vector2(pos.x, pos.z)):
            return true
    return false

func _in_tide_water(pos: Vector3) -> bool:
    if not _in_rects(pos, water_rects):
        return false
    for z in [-38.0, -60.0, -82.0]:
        if absf(pos.z - z) < 1.25:
            return false
    return true
