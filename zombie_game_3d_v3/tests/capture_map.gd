extends Node
# Знімки карти локацій у меню: стартовий вигляд, верх із кампаніями й наближення.
# Запуск: godot --path zombie_game_3d_v3 res://tests/capture_map.tscn -- /tmp/out-dir

const State = preload("res://game_state.gd")
const Menu = preload("res://menu.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out_dir := args[0] if not args.is_empty() else "/tmp/verify/map-shots"
    DirAccess.make_dir_recursive_absolute(out_dir)
    State.loaded = true
    State.conquered = {}
    for id in ["loc1", "loc2", "loc3", "loc4", "loc13", "loc5", "loc6", "loc7", "loc10", "loc8", "loc9", "loc11", "loc12", "loc28", "loc33"]:
        State.conquered[id] = true
    var menu = Menu.new()
    get_tree().root.add_child(menu)
    get_tree().current_scene = menu
    for frame in range(20):
        await get_tree().process_frame
    var wm = menu.world_map
    await _save(out_dir + "/map_start.png")
    wm.offset.y = 0.0
    wm._clamp_offset()
    wm._update_view()
    menu._on_location_picked("loc35")
    wm.selected = "loc35"
    for frame in range(6):
        await get_tree().process_frame
    await _save(out_dir + "/map_top.png")
    wm.offset.y = -100000.0
    wm._clamp_offset()
    wm._update_view()
    for frame in range(6):
        await get_tree().process_frame
    await _save(out_dir + "/map_bottom.png")
    wm._anchor = wm.view.size * 0.5
    wm._apply_zoom(wm.zoom * 2.4)
    wm.zoom_target = wm.zoom
    for frame in range(6):
        await get_tree().process_frame
    await _save(out_dir + "/map_zoom.png")
    print("MAP SHOTS OK ", wm._centers.size())
    get_tree().quit(0)

func _save(path: String) -> void:
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    img.save_png(path)
    print("SCREENSHOT ", path)
