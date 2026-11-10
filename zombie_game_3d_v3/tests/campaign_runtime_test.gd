extends Node

const State = preload("res://game_state.gd")
const Locations = preload("res://locations.gd")
const Level = preload("res://level.gd")
const Types = preload("res://zombie_types.gd")
var failures := 0
var checks := 0

func _ready() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func _run() -> void:
    State.loaded = true
    State.coins = 1234
    State.conquered = {"loc1": true, "loc27": true}
    State.weapon_levels = {"knife": 3}
    State.loadout = ["knife"]
    State.save_game()
    State.coins = 0
    State.conquered = {}
    State._read_save()
    check(State.coins == 1234 and State.conquered.has("loc1"), "Old save progress must survive")
    check(State.weapon_levels.get("knife") == 3, "Old weapon purchases must survive")
    var ids: Array = []
    for i in range(28, 48):
        ids.append("loc%d" % i)
    for id in ids:
        State.selected_loc = id
        var level = Level.new()
        get_tree().root.add_child(level)
        get_tree().current_scene = level
        await get_tree().process_frame
        level.set_process(false)
        level.player.set_physics_process(false)
        var c = level.campaign
        check(c != null, "%s controller exists" % id)
        if c == null:
            level.queue_free()
            await get_tree().process_frame
            continue
        c.set_process(false)
        check(c.theme == String(level.loc["campaign"]), "%s theme matches" % id)
        check(int(level.terrain.forced_biome) == int(level.loc["biome"]), "%s biome" % id)
        check(c.label.text.contains("/5"), "%s campaign HUD" % id)
        for target in c.targets:
            check(target.is_in_group("attackable") and not target.is_in_group("zombies"), "%s props must not count as enemies" % id)
        var strength: Dictionary = level._strength().duplicate()
        for wave in range(1, level.max_waves + 1):
            level.wave = wave
            check(level._strength() == strength, "%s stable enemy stats across waves" % id)
        level.castle_wait = false
        var elapsed_before: float = c.elapsed
        get_tree().paused = true
        c.set_process(true)
        await get_tree().process_frame
        await get_tree().process_frame
        check(c.elapsed == elapsed_before, "%s pause stops campaign clock" % id)
        c.set_process(false)
        get_tree().paused = false
        if not c.targets.is_empty():
            var target = c.targets[0]
            var before: float = target.hp
            level.player.current = "knife"
            level.player._hit(target, 12.0, 0.0, Vector3.FORWARD)
            check(target.hp < before, "%s ordinary weapon hits objectives" % id)
        if id == "loc28":
            level.player.global_position = Vector3(-22, 0, -54)
            level.player.slow_time = 0
            c.elapsed = 25.0
            c._update_tide(0)
            check(level.player.slow_time > 0 and c.tide_phase == "ПРИПЛИВ", "High tide slows flooded lane")
            level.player.global_position = Vector3(0, 0, -60)
            level.player.slow_time = 0
            c._update_tide(0)
            check(level.player.slow_time == 0, "Central dry bypass remains usable")
            c.elapsed = 21.0
            c._update_tide(0)
            check(c.tide_phase.begins_with("ПРИПЛИВ ЧЕРЕЗ"), "Tide warning phase exists")
        if id == "loc31":
            level.player.global_position = c.hold_point
            c._update_tide(45)
            check(c.hold >= 45, "Lighthouse hold progresses in courtyard")
        if id == "loc40":
            c.environment_timer = 0
            c._update_glass(0.1)
            var first_count := get_tree().get_nodes_in_group("zombies").size()
            for repeat in range(5):
                c.environment_timer = 0
                c._update_glass(0.1)
            check(first_count == 3 and get_tree().get_nodes_in_group("zombies").size() == 6, "Mirror summons are finite")
        if id == "loc43":
            level.player.global_position = Vector3(0, 0, -40)
            level.player.invuln = 0
            var z = level._spawn_zombie("iron_worker")
            z.set_physics_process(false)
            z.global_position = level.player.global_position
            var hp_before: float = z.hp
            var player_before: int = level.player.hp
            c._hazard(z.global_position, 3.0, 15, "circle", 1.0, true)
            c._update_hazards(0.5)
            check(level.player.hp == player_before and z.hp == hp_before, "Trap telegraph deals no premature damage")
            c._update_hazards(0.6)
            check(level.player.hp < player_before and z.hp < hp_before, "Trap damages hero and enemies")
        if int(level.loc["stage"]) == 5:
            var boss = level._spawn_zombie(String(level.loc["boss"]))
            boss.set_physics_process(false)
            boss.global_position = Vector3(0, 0, -56)
            level.player.global_position = Vector3(0, 0, -50)
            c.boss_timer = 0
            c._update_boss(0.1)
            check(not c.hazards.is_empty(), "%s boss special is active" % id)
            check(bool(boss.data.get("boss", false)), "%s boss flag" % id)
        for z in get_tree().get_nodes_in_group("zombies"):
            z.remove_from_group("zombies")
            z.remove_from_group("attackable")
            z.queue_free()
        await get_tree().process_frame
        if not c.objectives_complete():
            level._victory()
            check(level.state == "playing", "%s objectives gate victory" % id)
        for target in c.targets:
            target.take_damage(100000.0, Vector3.FORWARD)
        # Destroying iron drives releases finite guards; defeat them before victory.
        for z in get_tree().get_nodes_in_group("zombies"):
            z.remove_from_group("zombies")
            z.remove_from_group("attackable")
            z.queue_free()
        if c.theme == "tide" and c.stage == 4:
            c.hold = 45.0
        check(c.objectives_complete(), "%s objectives can be completed" % id)
        level._victory()
        check(level.state == "won" and State.conquered.has(id), "%s victory saves conquest" % id)
        var awarded: int = State.coins
        level._victory()
        check(State.coins == awarded, "%s victory cannot award twice" % id)
        get_tree().paused = false
        level.queue_free()
        await get_tree().process_frame
        await get_tree().process_frame
        State.selected_loc = id
        var retry = Level.new()
        get_tree().root.add_child(retry)
        get_tree().current_scene = retry
        await get_tree().process_frame
        check(retry.campaign.elapsed == 0 and retry.campaign.hazards.is_empty(), "%s reentry resets hazards" % id)
        retry._on_died()
        check(retry.state == "lost" and retry.end_panel.visible, "%s defeat works" % id)
        get_tree().paused = false
        retry.queue_free()
        await get_tree().process_frame
        await get_tree().process_frame
        print("SCENE PASS ", id)
    State.conquered = {}
    State._read_save()
    check(State.conquered.has("loc1") and State.conquered.has("loc47"), "Save round-trip preserves old and new conquests")
    print("CAMPAIGN RUNTIME: %d checks, %d failures" % [checks, failures])
    get_tree().quit(1 if failures else 0)
