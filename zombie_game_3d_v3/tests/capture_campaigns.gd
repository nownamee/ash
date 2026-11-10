extends Node

const State = preload("res://game_state.gd")
const Level = preload("res://level.gd")
const Menu = preload("res://menu.gd")
var errors := 0

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    State.loaded = true
    State.coins = 1000
    State.weapon_levels = {"knife": 3, "sword": 3, "bow": 3}
    State.loadout = ["knife", "sword", "bow"]
    var args := OS.get_cmdline_user_args()
    var id := args[0] if not args.is_empty() else "loc30"
    if id == "map":
        await _capture_map()
        return
    State.selected_loc = id
    var level = Level.new()
    get_tree().root.add_child(level)
    get_tree().current_scene = level
    await get_tree().process_frame
    level.player.max_hp = 500
    level.player.hp = 500
    level.player.invuln = 0
    level.player.global_position = Vector3(0, 0, -55)
    level.terrain.update(level.player.global_position, 999)
    level.castle_wait = false
    level.castle.lock_gate()
    level._start_wave(1)
    var c = level.campaign
    if c.theme == "tide":
        c.elapsed = 25.0
    var kinds: Array = []
    match c.theme:
        "tide": kinds = ["tide_drowned", "tide_net", "tide_anchor", "tide_shell"]
        "bells": kinds = ["bell_acolyte", "bell_carrier", "bell_chorister", "bell_executioner"]
        "glass": kinds = ["glass_dead", "glass_thrower", "glass_double", "glass_guard"]
        "iron": kinds = ["iron_worker", "iron_chain", "iron_riveter", "iron_gear"]
    for i in range(kinds.size()):
        var z = level._spawn_zombie(kinds[i])
        z.global_position = Vector3(-9 + 6 * i, 0, -63)
    for frame in range(35):
        await get_tree().process_frame
    if not c.targets.is_empty():
        var target = c.targets[0]
        level.player.global_position = target.global_position + Vector3(0, 0, 1.5)
        level.terrain.update(level.player.global_position, 999)
        for frame in range(12):
            await get_tree().process_frame
        Input.warp_mouse(level.camera.unproject_position(target.global_position))
        for frame in range(3):
            await get_tree().process_frame
        level.player.aim = Vector3.FORWARD
        level.player.cooldown = 0
        var hp_before: float = target.hp
        Input.action_press("attack")
        for frame in range(65):
            Input.warp_mouse(level.camera.unproject_position(target.global_position))
            await get_tree().process_frame
        Input.action_release("attack")
        if target.hp >= hp_before:
            push_error("Visible weapon attack did not damage objective: " + id)
            errors += 1
        print("VISIBLE ATTACK ", id, ": ", hp_before, " -> ", target.hp)
    for frame in range(90):
        await get_tree().process_frame
    await _save(c.theme)
    var pause := InputEventKey.new()
    pause.physical_keycode = KEY_ESCAPE
    pause.pressed = true
    Input.parse_input_event(pause)
    await get_tree().process_frame
    if not level.pause_panel.visible or not get_tree().paused:
        errors += 1
        push_error("Escape did not pause gameplay")
    var before_pause: float = c.elapsed
    for frame in range(5):
        await get_tree().process_frame
    if c.elapsed != before_pause:
        errors += 1
        push_error("Campaign clock advanced during pause")
    level._set_pause(false)
    print("VISUAL SMOKE ", id, ": ", errors, " failures")
    await _finish()

func _capture_map() -> void:
    State.conquered = {"loc27": true, "loc32": true, "loc37": true, "loc42": true, "loc47": true}
    var menu = Menu.new()
    get_tree().root.add_child(menu)
    get_tree().current_scene = menu
    for frame in range(12):
        await get_tree().process_frame
    menu._on_location_picked("loc40")
    menu.world_map.selected = "loc40"
    menu.world_map.zoom = 0.33
    menu.world_map.zoom_target = 0.33
    menu.world_map.offset = Vector2(-20, -340)
    menu.world_map._clamp_offset()
    menu.world_map._update_view()
    for frame in range(10):
        await get_tree().process_frame
    await _save("map")
    print("MAP CAPTURE ", menu.world_map._centers.size(), " location centers")
    await _finish()

func _finish() -> void:
    get_tree().paused = false
    get_tree().current_scene.queue_free()
    await get_tree().process_frame
    Sfx.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    get_tree().quit(1 if errors else 0)

func _save(name_: String) -> void:
    await RenderingServer.frame_post_draw
    var path := "/tmp/verify/ash-screens/" + name_ + ".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var result := get_viewport().get_texture().get_image().save_png(path)
    if result != OK:
        errors += 1
        push_error("Screenshot failed: " + path)
    print("SCREENSHOT ", path)
