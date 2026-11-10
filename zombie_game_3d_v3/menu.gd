extends Control
# Головне меню: карта локацій, зброя, броня, навики. Усе купується й прокачується тільки тут.

const GameState = preload("res://game_state.gd")
const Weapons = preload("res://weapons.gd")
const Armor = preload("res://armor.gd")
const Skills = preload("res://skills.gd")
const Locations = preload("res://locations.gd")
const Biomes = preload("res://biomes.gd")
const ZombieTypes = preload("res://zombie_types.gd")
const WorldMapScript = preload("res://world_map.gd")
const MenuTheme = preload("res://menu_theme.gd")
const TavernBg = preload("res://tavern_bg.gd")
const ForgeBg = preload("res://forge_bg.gd")
const MarketBg = preload("res://market_bg.gd")
const TrainerBg = preload("res://trainer_bg.gd")
const TAB_TITLES := {"weapons": "Зброя", "armor": "Броня", "skills": "Навики"}
const TAB_ICONS := {"weapons": "res://icons/ui_menu_weapons.png", "armor": "res://icons/ui_menu_armor.png", "skills": "res://icons/ui_menu_skills.png"}
const BIOME_ICONS := ["b_meadow.png", "b_forest.png", "b_desert.png", "b_snow.png", "b_graveyard.png", "b_ruins.png", "b_city.png", "b_ash.png", "b_swamp.png", "b_tundra.png", "b_fire.png", "b_tide.svg", "b_bells.svg", "b_glass.svg", "b_iron.svg"]
const CREAM := Color(0.93, 0.87, 0.72)

const TYPE_NAMES := {"melee": "ближній бій", "aoe": "удар по колу", "proj": "снаряд", "chain": "блискавка", "water": "водна стихія", "ice": "льодяна стихія", "fire": "вогняна стихія"}

var coins_label: Label
var progress_label: Label
var music_button: Button
var back_button: Button
var page_title: Label
var result_label: Label
var pages := {}
var world_map
var sel_id := ""
var info_name: Label
var info_icon: TextureRect
var info_rows: VBoxContainer
var page_icon: TextureRect
var play_button: Button
var info_panel: PanelContainer   # велике вікно з інформацією про район (ховається, коли нічого не вибрано)
var hint_panel: PanelContainer   # підказка «оберіть район» (видно, коли нічого не вибрано)
var reset_button: Button
var reset_armed := false
var loadout_label: Label
var weapon_slots := {}       # id -> вузли комірки зброї (рамка, іконка, «+», ціна)
var unlock_icons := {}       # id -> іконка у правій панелі «Відкриття зброї»
var unlock_rows: Array = []
var loadout_slots: Array = []
var fly_layer: Control       # шар, де летить іконка зброї
var weapon_scroll: ScrollContainer   # прокрутка стійки зі зброєю
var fly_busy := false
var weapon_overlay: ColorRect  # затемнення за вікном з інформацією
var popup_card: PanelContainer
var popup_box: VBoxContainer
var popup_id := ""
var forge_bg: Control
var market_bg: Control
var trainer_bg: Control
var armor_label: Label

func _ready() -> void:
    GameState.load_game()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    theme = MenuTheme.build()
    get_tree().node_added.connect(_hook_sfx)
    Sfx.music("menu")

    add_child(TavernBg.new())
    # фон екрана зброї: темна кузня з ковачем (видно тільки на вкладці «Зброя», під верхньою панеллю)
    forge_bg = ForgeBg.new()
    forge_bg.visible = false
    add_child(forge_bg)
    # фон екрана броні: моторошний нічний базар із крамарем (видно тільки на вкладці «Броня»)
    market_bg = MarketBg.new()
    market_bg.visible = false
    add_child(market_bg)
    # фон екрана навиків: похмурий тренувальний зал із тренером, що мовчки чекає (тільки на вкладці «Навики»)
    trainer_bg = TrainerBg.new()
    trainer_bg.visible = false
    add_child(trainer_bg)

    # --- верхня панель: музика | прогрес | монети ---
    var top := HBoxContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 14.0
    top.offset_right = -14.0
    top.offset_top = 8.0
    top.offset_bottom = 54.0
    top.add_theme_constant_override("separation", 10)
    add_child(top)

    music_button = Button.new()
    music_button.custom_minimum_size = Vector2(170, 40)
    music_button.pressed.connect(_toggle_music)
    top.add_child(music_button)
    var sp1 := Control.new()
    sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(sp1)

    var prog_panel := PanelContainer.new()
    prog_panel.theme_type_variation = "Plate"
    var prog_box := HBoxContainer.new()
    prog_box.add_theme_constant_override("separation", 8)
    prog_panel.add_child(prog_box)
    prog_box.add_child(_icon("res://icons/ui_flag.png", 28.0))
    progress_label = Label.new()
    progress_label.add_theme_font_size_override("font_size", 22)
    progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    prog_box.add_child(progress_label)
    top.add_child(prog_panel)

    var sp2 := Control.new()
    sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(sp2)

    var coin_panel := PanelContainer.new()
    coin_panel.theme_type_variation = "Plate"
    var coin_box := HBoxContainer.new()
    coin_box.add_theme_constant_override("separation", 8)
    coin_panel.add_child(coin_box)
    var coin_icon := TextureRect.new()
    coin_icon.texture = load("res://icons/ui_coin.png")
    coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin_icon.custom_minimum_size = Vector2(30, 30)
    coin_box.add_child(coin_icon)
    coins_label = Label.new()
    coins_label.add_theme_font_size_override("font_size", 24)
    coins_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    coin_box.add_child(coins_label)
    top.add_child(coin_panel)

    result_label = Label.new()
    result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result_label.visible = false

    var holder := Control.new()
    holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.offset_top = 60.0
    add_child(holder)

    pages["map"] = _build_map_page(holder)
    pages["weapons"] = _build_weapons_page(holder)
    pages["armor"] = _build_armor_page(holder)
    pages["skills"] = _build_skills_page(holder)

    back_button = Button.new()
    back_button.text = "« До мапи"
    back_button.position = Vector2(14, 4)
    back_button.size = Vector2(190, 36)
    back_button.pressed.connect(_show_tab.bind("map"))
    holder.add_child(back_button)
    page_icon = _icon("res://icons/ui_menu_weapons.png", 44.0)
    page_icon.position = Vector2(222, -2)
    holder.add_child(page_icon)
    page_title = Label.new()
    page_title.theme_type_variation = "TitleLabel"
    page_title.position = Vector2(274, 2)
    page_title.add_theme_font_size_override("font_size", 28)
    page_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    page_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    page_title.add_theme_constant_override("outline_size", 6)
    holder.add_child(page_title)

    if GameState.last_result != "":
        result_label.text = GameState.last_result
        result_label.visible = true
        GameState.last_result = ""

    sel_id = ""
    _show_tab("map")
    _refresh_all()

func _exit_tree() -> void:
    Sfx.ambience("")

func _process(_delta: float) -> void:
    if music_button != null:
        if Sfx.music_on:
            music_button.text = "Музика: лунає"
        else:
            music_button.text = "Музика: змовкла"

func _toggle_music() -> void:
    Sfx.toggle_music()

# Звуки для всіх кнопок меню (карта має власні).
func _hook_sfx(n: Node) -> void:
    if n is Button and not n.has_meta("own_sfx"):
        n.pressed.connect(Sfx.play.bind("click"))
        n.mouse_entered.connect(Sfx.play.bind("hover"))

func _show_tab(name_: String) -> void:
    _close_weapon_popup()
    _close_armor_popup()
    _close_skill_popup()
    if forge_bg != null:
        forge_bg.visible = (name_ == "weapons")
    if market_bg != null:
        market_bg.visible = (name_ == "armor")
    if trainer_bg != null:
        trainer_bg.visible = (name_ == "skills")
    if name_ == "armor":
        Sfx.ambience("market")
    else:
        Sfx.ambience("")
    for k in pages:
        pages[k].visible = (k == name_)
    back_button.visible = (name_ != "map")
    page_title.visible = (name_ != "map")
    page_title.text = String(TAB_TITLES.get(name_, ""))
    page_icon.visible = (name_ != "map")
    if TAB_ICONS.has(name_):
        page_icon.texture = load(String(TAB_ICONS[name_]))

# Сторінка зі списком: темна дерев'яна панель + прокрутка.
func _scroll_page(holder: Control) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14.0
    panel.offset_top = 46.0
    panel.offset_right = -14.0
    panel.offset_bottom = -10.0
    holder.add_child(panel)
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(sc)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 6)
    sc.add_child(list)
    return list

func _nav_button(text: String, icon_path: String, tab: String) -> Button:
    var b := Button.new()
    b.theme_type_variation = "NavButton"
    b.text = "  " + text
    b.icon = load(icon_path)
    b.expand_icon = true
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(0, 56)
    b.add_theme_constant_override("icon_max_width", 52)
    b.pressed.connect(_show_tab.bind(tab))
    return b

# ================= Карта =================
func _build_map_page(holder: Control) -> Control:
    var page := Control.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.mouse_filter = Control.MOUSE_FILTER_IGNORE   # клік повз елементи доходить до меню й знімає вибір
    holder.add_child(page)

    # карта зліва вгорі
    world_map = WorldMapScript.new()
    world_map.anchor_left = 0.0
    world_map.anchor_top = 0.0
    world_map.anchor_right = 0.50
    world_map.anchor_bottom = 0.67
    world_map.offset_left = 10.0
    world_map.offset_top = 2.0
    world_map.offset_right = 0.0
    world_map.offset_bottom = 0.0
    world_map.selected = ""   # на старті нічого не вибрано — видно таверну
    world_map.picked.connect(_on_location_picked)
    world_map.cleared.connect(_on_map_cleared)
    page.add_child(world_map)

    # кнопки розділів знизу зліва
    var nav := VBoxContainer.new()
    nav.anchor_left = 0.0
    nav.anchor_top = 0.69
    nav.anchor_right = 0.0
    nav.anchor_bottom = 1.0
    nav.offset_left = 18.0
    nav.offset_right = 330.0
    nav.offset_top = 0.0
    nav.offset_bottom = -4.0
    nav.add_theme_constant_override("separation", 3)
    page.add_child(nav)
    nav.add_child(_nav_button("Зброя", "res://icons/ui_menu_weapons.png", "weapons"))
    nav.add_child(_nav_button("Броня", "res://icons/ui_menu_armor.png", "armor"))
    nav.add_child(_nav_button("Навики", "res://icons/ui_menu_skills.png", "skills"))

    # права колонка: назва гри, підказка, інформація про район
    var right := VBoxContainer.new()
    right.anchor_left = 0.60
    right.anchor_top = 0.0
    right.anchor_right = 1.0
    right.anchor_bottom = 1.0
    right.offset_left = 4.0
    right.offset_right = -16.0
    right.offset_top = 0.0
    right.offset_bottom = -10.0
    right.add_theme_constant_override("separation", 8)
    page.add_child(right)

    var banner := PanelContainer.new()
    banner.theme_type_variation = "Banner"
    banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var brow := HBoxContainer.new()
    brow.alignment = BoxContainer.ALIGNMENT_CENTER
    brow.add_theme_constant_override("separation", 12)
    banner.add_child(brow)
    brow.add_child(_icon("res://icons/ui_tab_weapons.png", 36.0))
    var title := Label.new()
    title.theme_type_variation = "TitleLabel"
    title.text = "ВІДВОЮВАННЯ"
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
    title.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
    title.add_theme_constant_override("outline_size", 9)
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
    title.add_theme_constant_override("shadow_offset_x", 2)
    title.add_theme_constant_override("shadow_offset_y", 3)
    brow.add_child(title)
    var flip_icon := _icon("res://icons/ui_tab_weapons.png", 36.0)
    flip_icon.flip_h = true
    brow.add_child(flip_icon)
    right.add_child(banner)

    hint_panel = PanelContainer.new()
    hint_panel.theme_type_variation = "Plate"
    hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    hint_panel.custom_minimum_size = Vector2(400, 0)
    var hint_row := HBoxContainer.new()
    hint_row.add_theme_constant_override("separation", 10)
    hint_panel.add_child(hint_row)
    hint_row.add_child(_icon("res://icons/ui_pin.png", 26.0))
    var hint := Label.new()
    hint.text = "Торкнись будь-якого вогнища на мапі — і відкриється, що чигає на тебе."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color(1.0, 0.80, 0.25))
    hint_row.add_child(hint)
    right.add_child(hint_panel)

    right.add_child(result_label)

    var panel := PanelContainer.new()
    info_panel = panel
    panel.theme_type_variation = "Plate"
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 12)
    box.add_child(head)
    info_icon = _icon("res://icons/ui_map.png", 58.0)
    head.add_child(info_icon)
    info_name = Label.new()
    info_name.theme_type_variation = "DarkTitle"          # назви локацій — темним зловісним шрифтом
    info_name.add_theme_font_size_override("font_size", 30)
    info_name.add_theme_color_override("font_color", Color(0.90, 0.80, 0.66))
    info_name.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.0))
    info_name.add_theme_constant_override("outline_size", 8)
    info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(info_name)
    box.add_child(HSeparator.new())

    var info_scroll := ScrollContainer.new()
    info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(info_scroll)
    info_rows = VBoxContainer.new()
    info_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info_rows.add_theme_constant_override("separation", 9)
    info_scroll.add_child(info_rows)

    play_button = Button.new()
    play_button.theme_type_variation = "PlayButton"
    play_button.custom_minimum_size = Vector2(0, 58)
    play_button.expand_icon = true
    play_button.add_theme_constant_override("icon_max_width", 32)
    play_button.pressed.connect(_on_play)
    box.add_child(play_button)

    reset_button = Button.new()
    reset_button.theme_type_variation = "DangerButton"
    reset_button.icon = load("res://icons/ui_trash.png")
    reset_button.expand_icon = true
    reset_button.add_theme_constant_override("icon_max_width", 22)
    reset_button.text = "Спалити літопис"
    reset_button.pressed.connect(_on_reset)
    box.add_child(reset_button)
    return page

func _on_location_picked(id: String) -> void:
    sel_id = id
    reset_armed = false
    _refresh_info()

# Клік повз карту й повз вікна (на таверні, рамці карти) — прибрати вибір і вікно справа.
func _on_map_cleared() -> void:
    if sel_id == "":
        return
    sel_id = ""
    reset_armed = false
    world_map.selected = ""
    _refresh_info()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and pages.has("map") and pages["map"].visible:
            _on_map_cleared()

func _on_play() -> void:
    if sel_id == "":
        return
    var loc := Locations.by_id(sel_id)
    if not GameState.is_unlocked(loc):
        return
    var brief := Locations.briefing(loc)
    if not brief.is_empty():
        _show_briefing(brief)
        return
    _start_level()

func _start_level() -> void:
    GameState.selected_loc = sel_id
    GameState.save_game()
    Sfx.play("start")
    get_tree().change_scene_to_file("res://level.tscn")

# Вікно з повідомленням солдата перед входом на особливий рівень.
func _show_briefing(brief: Dictionary) -> void:
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 0)
    center.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 22)
    panel.add_child(margin)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 14)
    margin.add_child(vb)
    var head := Label.new()
    head.text = "⚔ " + String(brief["who"])
    head.add_theme_font_size_override("font_size", 22)
    head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    vb.add_child(head)
    vb.add_child(HSeparator.new())
    var body := Label.new()
    body.text = String(brief["text"])
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.custom_minimum_size = Vector2(500, 0)
    vb.add_child(body)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    vb.add_child(row)
    var back := Button.new()
    back.text = "Ще не час"
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.custom_minimum_size = Vector2(0, 48)
    back.pressed.connect(shade.queue_free)
    row.add_child(back)
    var go := Button.new()
    go.text = "ДО ЗБРОЇ!"
    go.theme_type_variation = "PlayButton"
    go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    go.custom_minimum_size = Vector2(0, 48)
    go.pressed.connect(_start_level)
    row.add_child(go)

func _on_reset() -> void:
    if not reset_armed:
        reset_armed = true
        reset_button.text = "Спалити? Торкни ще раз"
        return
    reset_armed = false
    GameState.reset_progress()
    sel_id = ""
    world_map.selected = sel_id
    _refresh_all()

func _clear_rows() -> void:
    for ch in info_rows.get_children():
        info_rows.remove_child(ch)
        ch.queue_free()

func _icon(path: String, px: float, tint: Color = Color(1, 1, 1, 1)) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = load(path)
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.custom_minimum_size = Vector2(px, px)
    rect.modulate = tint
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect

# рядок інформації: іконка + текст (текст переноситься)
func _info_row(icon_path: String, text: String, col: Color = CREAM, tint: Color = Color(1, 1, 1, 1)) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var ic := _icon(icon_path, 28.0, tint)
    ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    row.add_child(ic)
    var lb := Label.new()
    lb.text = text
    lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lb.add_theme_color_override("font_color", col)
    row.add_child(lb)
    info_rows.add_child(row)

# складність: ряд черепів, зайняті яскраві, решта тьмяні; «кривава» складність — перші red черепів стають червоними
func _difficulty_row(tier: int, red: int = 0) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var ic := _icon("res://icons/ui_damage.png", 28.0)
    row.add_child(ic)
    var lb := Label.new()
    lb.text = "Лютість"
    lb.theme_type_variation = "DarkTitle"                  # загроза — зловісним шрифтом
    lb.add_theme_font_size_override("font_size", 20)
    lb.add_theme_color_override("font_color", Color(1.0, 0.18, 0.12) if red > 0 else Color(0.92, 0.45, 0.35))
    row.add_child(lb)
    var sk := HBoxContainer.new()
    sk.add_theme_constant_override("separation", 1)
    sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    for n in range(10):
        if n < red:
            sk.add_child(_icon("res://icons/ui_skull.png", 20.0, Color(1.0, 0.07, 0.04, 1.0)))     # червоний череп
        elif n < tier:
            sk.add_child(_icon("res://icons/ui_skull.png", 20.0, Color(1.0, 0.75, 0.70, 1.0)))
        else:
            sk.add_child(_icon("res://icons/ui_skull.png", 20.0, Color(1, 1, 1, 0.16)))
    row.add_child(sk)
    info_rows.add_child(row)

func _refresh_info() -> void:
    info_panel.visible = (sel_id != "")
    hint_panel.visible = (sel_id == "")
    reset_button.text = "Спалити літопис"
    if reset_armed:
        reset_button.text = "Спалити? Торкни ще раз"
    _clear_rows()
    if sel_id == "":
        info_name.text = "Оберіть землі на мапі"
        info_icon.texture = load("res://icons/ui_map.png")
        _info_row("res://icons/ui_skull.png", "Що глибше в пітьму, то лютіші мерці та хвилі.")
        _info_row("res://icons/ui_tab_weapons.png", "Клинки, лати й уміння здобуваються тут, у кузні та на подвір’ї.")
        play_button.text = "—"
        play_button.icon = null
        play_button.disabled = true
        return
    var loc := Locations.by_id(sel_id)
    var unlocked := GameState.is_unlocked(loc)
    var done := GameState.conquered.has(sel_id)
    info_name.text = String(loc["name"])
    info_icon.texture = load("res://icons/%s" % String(BIOME_ICONS[int(loc["biome"])]))

    var desc := Label.new()
    desc.text = String(loc["desc"])
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_color_override("font_color", Color(0.86, 0.78, 0.60))
    info_rows.add_child(desc)

    var bio := String(Biomes.DATA[int(loc["biome"])]["name"])
    if int(loc["second"]) >= 0:
        bio += " + " + String(Biomes.DATA[int(loc["second"])]["name"])
    _info_row("res://icons/%s" % String(BIOME_ICONS[int(loc["biome"])]), "Край: " + bio)
    if loc.has("campaign"):
        var campaign_brief := Locations.briefing(loc)
        _info_row("res://icons/ui_map.png", "%s · стадія %d/5" % [String(campaign_brief.get("who", "Кампанія")), int(loc.get("stage", 1))], Color(0.72, 0.82, 0.84))
    var red_n := Locations.red_skulls(loc)
    _difficulty_row(int(loc["tier"]), red_n)
    if red_n > 0:
        _info_row("res://icons/ui_skull.png", "Кривава лють %d/10: живучість мерців ×%.2f." % [red_n, Locations.red_hp_mult(loc)], Color(1.0, 0.25, 0.2), Color(1.0, 0.1, 0.06, 1.0))
    if bool(loc.get("wip", false)):
        info_rows.add_child(HSeparator.new())
        _info_row("res://icons/ui_lock.png", "Ці землі ще тонуть у диму. Невдовзі шлях туди відкриється.", Color(1.0, 0.70, 0.60))
        play_button.disabled = true
        play_button.icon = load("res://icons/ui_lock.png")
        play_button.text = "ЗГОДОМ"
        return
    if bool(loc.get("burning", false)):
        _info_row("res://icons/ui_flag.png", "ОБОРОНА ПАЛАЮЧОЇ ТВЕРДИНІ: замок палає й щосекунди втрачає міць, а мертві б’ють по ньому лютіше. Розбий орду, доки він не обернувся на попіл.", Color(1.0, 0.55, 0.3))
        _info_row("res://icons/ui_pin.png", "Довкола лютує вогонь: він пече лише тебе (20% HP за опік). Мертві його не бояться.", Color(1.0, 0.62, 0.3))
    elif bool(loc.get("defend", false)):
        _info_row("res://icons/ui_flag.png", "ОБОРОНА: на мури суне одна нескінченна орда. Не впусти її: впаде замок — і все втрачено.", Color(1.0, 0.62, 0.52))
    elif bool(loc.get("escort", false)):
        _info_row("res://icons/ui_flag.png", "ПОРЯТУНОК: проби собі шлях крізь натовпи, відшукай пораненого лицаря й живим доведи до воріт замку.", Color(1.0, 0.85, 0.4))
    elif bool(loc.get("clear", false)):
        _info_row("res://icons/ui_flag.png", "ЗАЧИСТКА: хвиль не буде. %d мерців завмерли по всій окрузі; підступай тихо — вони прокидаються, щойно ступиш надто близько." % int(loc["clear_count"]), Color(1.0, 0.85, 0.4))
    elif bool(loc.get("horde", false)):
        _info_row("res://icons/ui_flag.png", "ОРДА: одна велетенська хвиля, що вартує трьох звичайних. Перепочинку не буде.", Color(1.0, 0.62, 0.52))
    else:
        _info_row("res://icons/ui_flag.png", "Хвиль до розв’язки: %d" % int(loc["waves"]))
        if loc.has("wave_plan"):
            if int(loc["waves"]) >= 5:
                _info_row("res://icons/ui_skull.png", "Мерці тут лютіші, ніж деінде, а остання хвиля — справжня різанина: кілька грізних почвар вийдуть разом.", Color(1.0, 0.45, 0.4))
            else:
                _info_row("res://icons/ui_skull.png", "Мерців тут більше, вони живучіші й прудкіші. Про спокій забудь.", Color(1.0, 0.62, 0.52))
    _info_row("res://icons/ui_skull.png", "Ватажок: %s" % String(ZombieTypes.DATA[String(loc["boss"])]["name"]), Color(1.0, 0.62, 0.52))
    var names := PackedStringArray()
    for b in [int(loc["biome"]), int(loc["second"])]:
        if int(b) < 0:
            continue
        for e in ZombieTypes.POOLS[int(b)]:
            if String(e[0]) == "walker":
                continue
            var zn := String(ZombieTypes.DATA[String(e[0])]["name"])
            if not names.has(zn):
                names.append(zn)
    _info_row("res://icons/ui_tab_bestiary.png", "Хто тут блукає: простий мрець, " + ", ".join(names))
    if int(loc["biome"]) == 8 or int(loc["second"]) == 8:
        _info_row("res://icons/ui_pin.png", "Під ногами кислотні калюжі: вони роз'їдають і сповільнюють лише тебе. Мерцям вони байдужі, тож заманюй їх у кислоту.", Color(0.6, 1.0, 0.4))
    _info_row("res://icons/ui_pin.png", "Чим жорсткіша бійня, тим раніше з'являються жиробаси. Готуйся до важких гостей.", Color(0.78, 0.72, 0.60))
    info_rows.add_child(HSeparator.new())
    if done:
        _info_row("res://icons/ui_check.png", "ПЕРЕМОГА! Ця земля знову наша. За повторний прохід: %d монет" % Locations.repeat_reward(loc), Color(0.62, 0.92, 0.58))
    elif unlocked:
        _info_row("res://icons/ui_coin.png", "Здобич за першу перемогу: %d монет" % Locations.first_reward(loc), Color(1.0, 0.85, 0.35))
    else:
        var req_names := PackedStringArray()
        for r in loc["req"]:
            req_names.append(String(Locations.by_id(String(r))["name"]))
        _info_row("res://icons/ui_lock.png", "Шлях перекрито. Спершу здобудь перемогу в одній із локацій: " + ", ".join(req_names), Color(1.0, 0.70, 0.60))
    if unlocked:
        play_button.disabled = false
        play_button.icon = load("res://icons/ui_play.png")
        if done:
            play_button.text = "ЗНОВУ В ПОХІД"
        else:
            play_button.text = "ДО ЗБРОЇ!"
    else:
        play_button.disabled = true
        play_button.icon = load("res://icons/ui_lock.png")
        play_button.text = "ШЛЯХ ЗАКРИТО"

# ================= Зброя =================
# Ліворуч — стійка з порожніми комірками (по одній на кожну зброю). Праворуч — «Відкриття зброї»:
# іконки за локаціями. Пройшов локацію → натискаєш іконку → зброя вистрибує у свою комірку.
# Натиснув зброю в комірці → гарне вікно з усією інформацією, купівлею, прокачкою та набором у бій.
const SLOT_PX := 80.0
const PLUS_W := 28.0
const GRID_COLS := 6
const GOLD_C := Color(0.95, 0.78, 0.25)

func _sb(bg: Color, border: Color, bw: int = 2, radius: int = 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 2.0
    s.content_margin_right = 2.0
    s.content_margin_top = 2.0
    s.content_margin_bottom = 2.0
    return s

func _style_button(b: Button, normal: StyleBoxFlat, disabled: StyleBoxFlat) -> void:
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = normal.bg_color.lightened(0.18)
    hover.border_color = normal.border_color.lightened(0.35)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", hover)
    b.add_theme_stylebox_override("disabled", disabled)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _wicon(id: String) -> String:
    return "res://icons/w_%s.png" % id

func _fill_rect(c: Control, margin: float = 0.0) -> void:
    c.anchor_left = 0.0
    c.anchor_top = 0.0
    c.anchor_right = 1.0
    c.anchor_bottom = 1.0
    c.offset_left = margin
    c.offset_top = margin
    c.offset_right = -margin
    c.offset_bottom = -margin

func _build_weapons_page(holder: Control) -> Control:
    var page := Control.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(page)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14.0
    panel.offset_top = 46.0
    panel.offset_right = -14.0
    panel.offset_bottom = -10.0
    # панель майже прозора, щоб було видно кузню
    panel.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.10), Color(0.55, 0.38, 0.12, 0.55), 2, 8))
    page.add_child(panel)

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 14)
    panel.add_child(cols)

    # ---------- ліворуч: стійка зі зброєю ----------
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(GRID_COLS * (SLOT_PX + PLUS_W + 4.0) + (GRID_COLS - 1) * 14.0 + 18.0, 0)   # +18 — місце під смугу прокрутки
    left.add_theme_constant_override("separation", 8)
    cols.add_child(left)

    var hint := Label.new()
    hint.text = "Торкнись зброї, щоб роздивитись її уважніше. Кнопка «+» — швидке здобуття й загартування."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    left.add_child(hint)

    var grid := GridContainer.new()
    grid.columns = GRID_COLS
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 8)
    # зброї багато, тож стійка гортається; набір у бій внизу лишається на місці
    var grid_scroll := ScrollContainer.new()
    grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    weapon_scroll = grid_scroll
    left.add_child(grid_scroll)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_scroll.add_child(grid)
    weapon_slots = {}
    for id in Weapons.all_ids():
        grid.add_child(_make_weapon_cell(String(id)))

    # набір у бій
    loadout_label = Label.new()
    loadout_label.add_theme_font_size_override("font_size", 16)
    loadout_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    left.add_child(loadout_label)
    var lrow := HBoxContainer.new()
    lrow.add_theme_constant_override("separation", 10)
    left.add_child(lrow)
    loadout_slots = []
    for i in range(GameState.MAX_LOADOUT):
        lrow.add_child(_make_loadout_slot(i))

    # ---------- праворуч: відкриття зброї за локаціями ----------
    cols.add_child(_build_unlock_panel())

    # ---------- шар для польоту іконки та вікно з інформацією ----------
    fly_layer = Control.new()
    fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fill_rect(fly_layer)
    page.add_child(fly_layer)

    weapon_overlay = ColorRect.new()
    weapon_overlay.color = Color(0, 0, 0, 0.66)
    weapon_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _fill_rect(weapon_overlay)
    weapon_overlay.visible = false
    weapon_overlay.gui_input.connect(_on_overlay_input)
    page.add_child(weapon_overlay)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fill_rect(center)
    weapon_overlay.add_child(center)
    popup_card = PanelContainer.new()
    popup_card.custom_minimum_size = Vector2(580, 0)
    var cs := _sb(Color(0.10, 0.06, 0.035, 0.99), GOLD_C, 3, 14)
    cs.content_margin_left = 22.0
    cs.content_margin_right = 22.0
    cs.content_margin_top = 16.0
    cs.content_margin_bottom = 18.0
    cs.shadow_color = Color(0, 0, 0, 0.7)
    cs.shadow_size = 14
    popup_card.add_theme_stylebox_override("panel", cs)
    center.add_child(popup_card)
    popup_box = VBoxContainer.new()
    popup_box.add_theme_constant_override("separation", 10)
    popup_card.add_child(popup_box)
    return page

# Веселкова рамка для зброї фінального (11) рівня: кольори переливаються по периметру.
const RAINBOW_SHADER_CODE := """
shader_type canvas_item;
uniform vec2 box_size = vec2(80.0, 80.0);
uniform float radius = 10.0;
uniform float width = 3.5;
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
    vec2 p = UV * box_size - box_size * 0.5;
    vec2 q = abs(p) - (box_size * 0.5 - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float edge = smoothstep(-width - 0.7, -width + 0.3, d) * (1.0 - smoothstep(-0.7, 0.3, d));
    float glow = exp(d / 5.0) * step(d, 0.0) * 0.30;
    float ang = atan(p.y, p.x) / 6.28318;
    float hue = fract(ang + TIME * 0.35);
    float pulse = 0.82 + 0.18 * sin(TIME * 3.0 + ang * 12.566);
    vec3 col = hsv2rgb(vec3(hue, 0.85, 1.0)) * pulse;
    float sweep = pow(max(0.0, sin((ang - TIME * 0.5) * 6.28318)), 14.0);
    col = mix(col, vec3(1.0), sweep * 0.65);
    COLOR = vec4(col, clamp(edge + glow, 0.0, 1.0));
}
"""
const STAR_SHADER_CODE := """
shader_type canvas_item;
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
    vec4 t = texture(TEXTURE, UV);
    float lum = clamp(dot(t.rgb, vec3(0.45, 0.45, 0.2)) + 0.45, 0.4, 1.15);
    COLOR = vec4(hsv2rgb(vec3(fract(TIME * 0.4 + UV.x * 0.7 + UV.y * 0.3), 0.8, 1.0)) * lum, t.a);
}
"""
static var _rainbow_shader: Shader
static var _star_shader: Shader

func _make_rainbow_frame(radius: float, width: float) -> ColorRect:
    if _rainbow_shader == null:
        _rainbow_shader = Shader.new()
        _rainbow_shader.code = RAINBOW_SHADER_CODE
    var r := ColorRect.new()
    r.color = Color(1, 1, 1, 1)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var mat := ShaderMaterial.new()
    mat.shader = _rainbow_shader
    mat.set_shader_parameter("radius", radius)
    mat.set_shader_parameter("width", width)
    r.material = mat
    r.resized.connect(func() -> void: mat.set_shader_parameter("box_size", r.size))
    return r

func _star_rainbow_material() -> ShaderMaterial:
    if _star_shader == null:
        _star_shader = Shader.new()
        _star_shader.code = STAR_SHADER_CODE
    var m := ShaderMaterial.new()
    m.shader = _star_shader
    return m

# Одна комірка: рамка-«вікно» зі зброєю, кнопка «+» і ціна під нею.
func _make_weapon_cell(id: String) -> Control:
    var cell := VBoxContainer.new()
    cell.add_theme_constant_override("separation", 3)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 4)
    cell.add_child(top)

    var slot := Button.new()
    slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
    slot.focus_mode = Control.FOCUS_NONE
    slot.pressed.connect(_on_slot_pressed.bind(id))
    top.add_child(slot)

    var lock := _icon("res://icons/ui_lock.png", 30.0, Color(1, 1, 1, 0.22))
    _fill_rect(lock)
    lock.offset_left = 25.0
    lock.offset_right = -25.0
    lock.offset_top = 25.0
    lock.offset_bottom = -25.0
    slot.add_child(lock)

    var icon := _icon(_wicon(id), 68.0)
    _fill_rect(icon, 6.0)
    slot.add_child(icon)

    var rainbow := _make_rainbow_frame(10.0, 4.0)
    _fill_rect(rainbow)
    rainbow.visible = false
    slot.add_child(rainbow)

    var lvl_lb := Label.new()
    _fill_rect(lvl_lb, 4.0)
    lvl_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lvl_lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    lvl_lb.add_theme_font_size_override("font_size", 14)
    lvl_lb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
    lvl_lb.add_theme_constant_override("outline_size", 5)
    lvl_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slot.add_child(lvl_lb)

    var ld := _icon("res://icons/ui_check.png", 20.0)
    ld.position = Vector2(3, 3)
    ld.size = Vector2(20, 20)
    slot.add_child(ld)

    var sp := _icon("res://icons/ui_star.png", 18.0)
    sp.position = Vector2(SLOT_PX - 21.0, 3)
    sp.size = Vector2(18, 18)
    slot.add_child(sp)

    var plus := Button.new()
    plus.custom_minimum_size = Vector2(PLUS_W, SLOT_PX)
    plus.focus_mode = Control.FOCUS_NONE
    plus.expand_icon = true
    plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    plus.add_theme_constant_override("icon_max_width", 20)
    plus.pressed.connect(_on_weapon_plus.bind(id))
    _style_button(plus, _sb(Color(0.42, 0.28, 0.07), GOLD_C, 2, 8), _sb(Color(0.10, 0.08, 0.06, 0.8), Color(0.28, 0.22, 0.14), 2, 8))
    top.add_child(plus)

    var prow := HBoxContainer.new()
    prow.alignment = BoxContainer.ALIGNMENT_CENTER
    prow.custom_minimum_size = Vector2(0, 20)
    prow.add_theme_constant_override("separation", 4)
    cell.add_child(prow)
    var coin := _icon("res://icons/ui_coin.png", 16.0)
    prow.add_child(coin)
    var price := Label.new()
    price.add_theme_font_size_override("font_size", 15)
    prow.add_child(price)

    weapon_slots[id] = {"slot": slot, "icon": icon, "lock": lock, "rb": rainbow, "lvl": lvl_lb, "ld": ld, "sp": sp, "plus": plus, "price": price, "coin": coin}
    return cell

func _make_loadout_slot(i: int) -> Control:
    var b := Button.new()
    b.custom_minimum_size = Vector2(60, 60)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(_on_loadout_slot_pressed.bind(i))
    var icon := _icon("res://icons/w_knife.png", 48.0)
    _fill_rect(icon, 6.0)
    b.add_child(icon)
    var num := Label.new()
    num.text = str(i + 1)
    num.position = Vector2(5, 1)
    num.add_theme_font_size_override("font_size", 14)
    num.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    num.add_theme_constant_override("outline_size", 5)
    num.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(num)
    loadout_slots.append({"btn": b, "icon": icon})
    return b

# Права панель: за кожною локацією — іконки зброї, яку вона відкриває.
func _build_unlock_panel() -> Control:
    var pn := PanelContainer.new()
    pn.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.03, 0.02, 0.72), Color(0.90, 0.70, 0.18, 0.85), 2, 8))
    pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    pn.add_child(v)

    var title := Label.new()
    title.text = "Відкриті клинки"
    title.theme_type_variation = "TitleLabel"
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 5)
    v.add_child(title)
    var sub := Label.new()
    sub.text = "Здобудь звитягу в землях і торкнись сяючого знака: клинок сам скочить у свою комірку."
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", 14)
    sub.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
    v.add_child(sub)

    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(sc)
    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 4)
    sc.add_child(rows)

    unlock_icons = {}
    unlock_rows = []
    # перший рядок — зброя, доступна з початку; далі — за локаціями у порядку карти
    var groups: Array = [{"loc": "", "name": "З початку літопису"}]
    for loc in Locations.DATA:
        groups.append({"loc": String(loc["id"]), "name": String(loc["name"])})
    for g in groups:
        var ids: Array = []
        for id in Weapons.all_ids():
            if Weapons.unlock_loc(String(id)) == String(g["loc"]):
                ids.append(String(id))
        if ids.is_empty():
            continue
        rows.add_child(_make_unlock_row(String(g["loc"]), String(g["name"]), ids))
    return pn

func _make_unlock_row(loc_id: String, loc_name: String, ids: Array) -> Control:
    var row := PanelContainer.new()
    row.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.045, 0.03, 0.85), Color(0.38, 0.27, 0.12), 2, 8))
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 8)
    row.add_child(h)
    var st := _icon("res://icons/ui_lock.png", 22.0)
    st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    h.add_child(st)
    var nm := Label.new()
    nm.text = loc_name
    nm.custom_minimum_size = Vector2(190, 0)
    nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    nm.clip_text = true
    nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    nm.add_theme_font_size_override("font_size", 15)
    h.add_child(nm)
    unlock_rows.append({"loc": loc_id, "status": st, "name": nm})
    for id in ids:
        var b := Button.new()
        b.custom_minimum_size = Vector2(44, 44)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_on_unlock_pressed.bind(String(id)))
        var ic := _icon(_wicon(String(id)), 36.0)
        _fill_rect(ic, 4.0)
        b.add_child(ic)
        var ck := _icon("res://icons/ui_check.png", 16.0)
        ck.position = Vector2(26, 26)
        ck.size = Vector2(16, 16)
        b.add_child(ck)
        h.add_child(b)
        unlock_icons[String(id)] = {"btn": b, "icon": ic, "check": ck, "tw": null}
    return row

# ---------- натискання ----------
func _on_slot_pressed(id: String) -> void:
    if GameState.weapon_revealed(id):
        _open_weapon_popup(id)

func _on_loadout_slot_pressed(i: int) -> void:
    if i < GameState.loadout.size():
        _open_weapon_popup(String(GameState.loadout[i]))

func _on_weapon_plus(id: String) -> void:
    if not GameState.weapon_revealed(id):
        return
    if GameState.weapon_levels.has(id):
        _on_weapon_upgrade(id)
    else:
        _on_weapon_buy(id)

func _on_unlock_pressed(id: String) -> void:
    if fly_busy:
        return
    if GameState.weapon_revealed(id):
        _open_weapon_popup(id)
        return
    if not GameState.weapon_unlock_ready(id):
        return
    _fly_to_slot(id)

# Іконка зброї «вистрибує» з правої панелі у свою порожню комірку.
func _fly_to_slot(id: String) -> void:
    fly_busy = true
    var src: Control = unlock_icons[id]["btn"]
    var dst: Control = weapon_slots[id]["slot"]
    if weapon_scroll != null:
        # комірка може бути за межами видимої частини стійки: прокручуємо до неї, інакше іконка полетить повз
        weapon_scroll.ensure_control_visible(dst)
        await get_tree().process_frame
    var ghost := TextureRect.new()
    ghost.texture = load(_wicon(id))
    ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ghost.custom_minimum_size = Vector2(40, 40)
    ghost.size = Vector2(40, 40)
    ghost.pivot_offset = Vector2(20, 20)
    fly_layer.add_child(ghost)
    var from := src.global_position + src.size * 0.5 - Vector2(20, 20)
    var to := dst.global_position + dst.size * 0.5 - Vector2(20, 20)
    ghost.global_position = from
    Sfx.play("click", 0.0, 1.4)
    var tw := create_tween()
    tw.tween_method(_fly_step.bind(ghost, from, to), 0.0, 1.0, 0.75)
    tw.tween_callback(_on_fly_done.bind(id, ghost))

func _fly_step(t: float, ghost: Control, from: Vector2, to: Vector2) -> void:
    if not is_instance_valid(ghost):
        return
    var p := from.lerp(to, t)
    p.y -= sin(t * PI) * 120.0
    ghost.global_position = p
    var s := 1.0 + 0.7 * t + sin(t * PI) * 0.25
    ghost.scale = Vector2(s, s)
    ghost.rotation = sin(t * PI * 2.0) * 0.3

func _on_fly_done(id: String, ghost: Control) -> void:
    if is_instance_valid(ghost):
        ghost.queue_free()
    GameState.revealed[id] = true
    GameState.save_game()
    fly_busy = false
    Sfx.play("buy")
    _refresh_all()
    var slot: Control = weapon_slots[id]["slot"]
    slot.pivot_offset = slot.size * 0.5
    slot.scale = Vector2(1.35, 1.35)
    var tw := slot.create_tween()
    tw.tween_property(slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_overlay_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
            _close_weapon_popup()

func _input(event: InputEvent) -> void:
    if (popup_id != "" or armor_popup_key != "" or skill_popup_id != "") and event is InputEventKey:
        var k := event as InputEventKey
        if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
            _close_weapon_popup()
            _close_armor_popup()
            _close_skill_popup()
            get_viewport().set_input_as_handled()

# ---------- купівля, прокачка, набір ----------
func _on_weapon_buy(id: String) -> void:
    if GameState.weapon_levels.has(id):
        return
    if not GameState.weapon_revealed(id):
        return
    var w: Dictionary = Weapons.DATA[id]
    var price := int(w["price"])
    if GameState.coins < price:
        return
    GameState.coins -= price
    GameState.weapon_levels[id] = 0
    GameState.revealed[id] = true
    if GameState.loadout.size() < GameState.MAX_LOADOUT:
        GameState.loadout.append(id)
    Sfx.play("buy")
    GameState.save_game()
    _refresh_all()

func _on_weapon_upgrade(id: String) -> void:
    if not GameState.weapon_levels.has(id):
        return
    var lvl := int(GameState.weapon_levels[id])
    if lvl >= Weapons.FINAL_LEVEL:
        return
    var cost := Weapons.upgrade_cost(id, lvl)
    if GameState.coins < cost:
        return
    GameState.coins -= cost
    GameState.weapon_levels[id] = lvl + 1
    Sfx.play("buy")
    GameState.save_game()
    _refresh_all()

func _on_weapon_loadout(id: String) -> void:
    if not GameState.weapon_levels.has(id):
        return
    if GameState.loadout.has(id):
        if GameState.loadout.size() > 1:
            GameState.loadout.erase(id)
    elif GameState.loadout.size() < GameState.MAX_LOADOUT:
        GameState.loadout.append(id)
    GameState.save_game()
    _refresh_all()

# ---------- оновлення вигляду ----------
func _refresh_weapons() -> void:
    loadout_label.text = "Спорядження: %d/%d  (клавіші 1-5 у битві)" % [GameState.loadout.size(), GameState.MAX_LOADOUT]

    # комірки зі зброєю
    for id in Weapons.all_ids():
        var sid := String(id)
        var w: Dictionary = Weapons.DATA[sid]
        var d: Dictionary = weapon_slots[sid]
        var slot: Button = d["slot"]
        var plus: Button = d["plus"]
        var price: Label = d["price"]
        var coin: TextureRect = d["coin"]
        var revealed := GameState.weapon_revealed(sid)
        var owned := GameState.weapon_levels.has(sid)
        var lvl := int(GameState.weapon_levels.get(sid, 0))
        var special := bool(w.get("special", false))
        var in_set := GameState.loadout.has(sid)

        (d["icon"] as TextureRect).visible = revealed
        (d["lock"] as TextureRect).visible = not revealed
        (d["ld"] as TextureRect).visible = in_set
        (d["sp"] as TextureRect).visible = special and revealed
        var lvl_lb: Label = d["lvl"]
        var is_final := owned and Weapons.is_final(lvl)
        lvl_lb.text = ""
        if owned:
            lvl_lb.text = "★ МАКС" if is_final else ("ур.%d" % lvl)
        lvl_lb.add_theme_color_override("font_color", Color(1.0, 0.8, 1.0) if is_final else Color(1.0, 0.95, 0.6))
        (d["rb"] as Control).visible = is_final
        (d["icon"] as TextureRect).modulate = Color(1, 1, 1, 1) if owned else Color(0.42, 0.40, 0.38, 1)

        slot.disabled = not revealed
        var bg := Color(0.0, 0.0, 0.0, 0.34)
        var border := Color(0.80, 0.62, 0.35, 0.28)
        var bw := 2
        if revealed:
            bg = Color(0.13, 0.085, 0.05, 0.86)
            border = Color(0.55, 0.40, 0.15)
        if owned:
            bg = Color(0.20, 0.13, 0.07, 0.98)
            border = GOLD_C
            if special:
                border = Color(1.0, 0.62, 0.2)
        if is_final:
            bg = Color(0.17, 0.10, 0.20, 0.98)
            border = Color(1, 1, 1, 0.0)
        if in_set and not is_final:
            border = Color(0.45, 1.0, 0.45)
            bw = 3
        _style_button(slot, _sb(bg, border, bw, 10), _sb(bg, border, bw, 10))
        if revealed:
            slot.tooltip_text = String(w["name"])
        else:
            var ul := Locations.by_id(Weapons.unlock_loc(sid))
            slot.tooltip_text = "Відкриється по звитязі в «%s»" % String(ul["name"])

        # кнопка «+» і ціна під нею
        plus.tooltip_text = ""
        var cost := 0
        var show_cost := false
        var plus_ok := false
        if not revealed:
            plus.icon = load("res://icons/ui_plus.png")
        elif not owned:
            plus.icon = load("res://icons/ui_plus.png")
            cost = int(w["price"])
            show_cost = true
            plus_ok = GameState.coins >= cost
            plus.tooltip_text = "Здобути"
        elif lvl < Weapons.FINAL_LEVEL:
            var last := lvl >= Weapons.MAX_LEVEL
            plus.icon = load("res://icons/ui_star.png" if last else "res://icons/ui_arrow_up.png")
            cost = Weapons.upgrade_cost(sid, lvl)
            show_cost = true
            plus_ok = GameState.coins >= cost
            plus.tooltip_text = "ОСТАННЄ ЗАГАРТУВАННЯ: урон ×3 від звичайного" if last else "Загартувати"
        else:
            plus.icon = load("res://icons/ui_star.png")
            plus.tooltip_text = "Вершина майстерності"
        plus.disabled = not plus_ok
        coin.visible = show_cost
        if show_cost:
            price.text = str(cost)
            price.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if plus_ok else Color(0.95, 0.45, 0.38))
        elif revealed and owned:
            price.text = "МАКС"
            price.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
        else:
            price.text = ""

    # набір у бій
    for i in range(loadout_slots.size()):
        var ld: Dictionary = loadout_slots[i]
        var lb: Button = ld["btn"]
        var lic: TextureRect = ld["icon"]
        if i < GameState.loadout.size():
            var lid := String(GameState.loadout[i])
            lic.texture = load(_wicon(lid))
            lic.visible = true
            lb.tooltip_text = String(Weapons.DATA[lid]["name"])
            _style_button(lb, _sb(Color(0.20, 0.13, 0.07), Color(0.45, 1.0, 0.45), 3, 10), _sb(Color(0.1, 0.08, 0.06), Color(0.3, 0.3, 0.3), 2, 10))
            lb.disabled = false
        else:
            lic.visible = false
            lb.tooltip_text = ""
            _style_button(lb, _sb(Color(0.05, 0.035, 0.025, 0.55), Color(0.30, 0.22, 0.12, 0.6), 2, 10), _sb(Color(0.05, 0.035, 0.025, 0.55), Color(0.30, 0.22, 0.12, 0.6), 2, 10))
            lb.disabled = true

    # права панель: що вже відкрито
    for r in unlock_rows:
        var loc_id := String(r["loc"])
        var done := (loc_id == "") or GameState.conquered.has(loc_id)
        (r["status"] as TextureRect).texture = load("res://icons/ui_check.png" if done else "res://icons/ui_lock.png")
        (r["name"] as Label).add_theme_color_override("font_color", CREAM if done else Color(0.55, 0.5, 0.42))
    for id in Weapons.all_ids():
        var sid := String(id)
        var u: Dictionary = unlock_icons[sid]
        var btn: Button = u["btn"]
        var ic: TextureRect = u["icon"]
        var revealed2 := GameState.weapon_revealed(sid)
        var is_ready := (not revealed2) and GameState.weapon_unlock_ready(sid)
        (u["check"] as TextureRect).visible = revealed2
        var wname := String(Weapons.DATA[sid]["name"])
        if revealed2:
            ic.modulate = Color(0.55, 0.55, 0.55, 1)
            btn.tooltip_text = wname + " — уже в комірці (торкнись, щоб розглянути)"
            _style_button(btn, _sb(Color(0.10, 0.07, 0.045), Color(0.40, 0.30, 0.14), 2, 8), _sb(Color(0.10, 0.07, 0.045), Color(0.40, 0.30, 0.14), 2, 8))
            btn.disabled = false
        elif is_ready:
            ic.modulate = Color(1, 1, 1, 1)
            btn.tooltip_text = wname + " — торкнись, і клинок скочить у свою комірку!"
            _style_button(btn, _sb(Color(0.30, 0.20, 0.06), Color(1.0, 0.9, 0.3), 3, 8), _sb(Color(0.30, 0.20, 0.06), Color(1.0, 0.9, 0.3), 3, 8))
            btn.disabled = false
        else:
            ic.modulate = Color(0.25, 0.25, 0.25, 1)
            var ul := Locations.by_id(Weapons.unlock_loc(sid))
            btn.tooltip_text = "%s — відкриється по звитязі в «%s»" % [wname, String(ul["name"])]
            _style_button(btn, _sb(Color(0.05, 0.035, 0.025), Color(0.25, 0.19, 0.11), 2, 8), _sb(Color(0.05, 0.035, 0.025), Color(0.25, 0.19, 0.11), 2, 8))
            btn.disabled = true
        _set_pulse(sid, is_ready)

    if popup_id != "":
        _fill_weapon_popup()

func _set_pulse(id: String, on: bool) -> void:
    var d: Dictionary = unlock_icons[id]
    var btn: Button = d["btn"]
    var tw = d["tw"]
    if on and tw == null:
        var t := btn.create_tween()
        t.set_loops()
        t.tween_property(btn, "modulate", Color(1.4, 1.25, 0.7), 0.55).set_trans(Tween.TRANS_SINE)
        t.tween_property(btn, "modulate", Color(1, 1, 1), 0.55).set_trans(Tween.TRANS_SINE)
        d["tw"] = t
    elif (not on) and tw != null:
        (tw as Tween).kill()
        d["tw"] = null
        btn.modulate = Color(1, 1, 1)

# ---------- вікно з інформацією про зброю ----------
func _open_weapon_popup(id: String) -> void:
    if not GameState.weapon_revealed(id):
        return
    popup_id = id
    _fill_weapon_popup()
    weapon_overlay.visible = true

func _close_weapon_popup() -> void:
    popup_id = ""
    if weapon_overlay != null:
        weapon_overlay.visible = false

func _stat(icon_path: String, label: String, cur: String, nxt: String = "") -> Dictionary:
    return {"icon": icon_path, "label": label, "cur": cur, "next": nxt}

# Характеристики зброї на рівні lvl (і на наступному, якщо його можна прокачати).
func _weapon_stats(id: String, lvl: int) -> Array:
    var w: Dictionary = Weapons.DATA[id]
    var type_s := String(w["type"])
    var has_next := lvl < Weapons.FINAL_LEVEL
    var n := lvl + 1
    var cnt := int(w.get("count", 1))
    var mm := Weapons.mastery_mult(GameState.weapon_mastery(id))
    var mult := ""
    if cnt > 1:
        mult = " ×%d" % cnt
    var out: Array = []

    var dmg_c := "%d%s" % [int(Weapons.damage(id, lvl) * mm), mult]
    var dmg_n := ""
    if has_next:
        dmg_n = "%d%s" % [int(Weapons.damage(id, n) * mm), mult]
    out.append(_stat("res://icons/ui_damage.png", "Урон", dmg_c, dmg_n))

    var cd_c := "%.2f с" % Weapons.cooldown(id, lvl)
    var cd_n := ""
    if has_next:
        cd_n = "%.2f с" % Weapons.cooldown(id, n)
    out.append(_stat("res://icons/ui_cooldown.png", "Відновлення", cd_c, cd_n))

    var dps_c := "%d" % int(Weapons.damage(id, lvl) * mm * float(cnt) / Weapons.cooldown(id, lvl))
    var dps_n := ""
    if has_next:
        dps_n = "%d" % int(Weapons.damage(id, n) * mm * float(cnt) / Weapons.cooldown(id, n))
    out.append(_stat("res://icons/ui_bolt.png", "Урон за секунду", dps_c, dps_n))

    if float(w.get("range", 0.0)) > 0.0:
        var r_n := ""
        if has_next:
            r_n = "%.1f м" % Weapons.range_of(id, n)
        out.append(_stat("res://icons/ui_range.png", "Влучність", "%.1f м" % Weapons.range_of(id, lvl), r_n))
    if type_s == "proj":
        var p_n := ""
        if has_next:
            p_n = "%d" % Weapons.pierce(id, n)
        out.append(_stat("res://icons/ui_pierce.png", "Пробиття (цілей)", "%d" % Weapons.pierce(id, lvl), p_n))
    if type_s == "chain":
        var c_n := ""
        if has_next:
            c_n = "%d" % Weapons.chain_count(id, n)
        out.append(_stat("res://icons/ui_type_chain.png", "Ланцюг (цілей)", "%d" % Weapons.chain_count(id, lvl), c_n))
    if w.has("slow"):
        out.append(_stat("res://icons/ui_cooldown.png", "Сповільнення ворога", "%d%% на %.0f с" % [int(round((1.0 - float(w.get("slow_mult", 0.5))) * 100.0)), float(w["slow"])]))
    if w.has("freeze"):
        out.append(_stat("res://icons/ui_cooldown.png", "Заморозка ворога", "на %.0f с, шанс %d%% (на боса %d%%)" % [float(w["freeze"]), int(round(float(w.get("freeze_chance", 1.0)) * 100.0)), int(round(float(w.get("freeze_chance_boss", w.get("freeze_chance", 1.0))) * 100.0))]))
    if w.has("burn"):
        var b_n := ""
        if has_next:
            b_n = "%d / с" % int(Weapons.burn_dps(id, n) * mm)
        out.append(_stat("res://icons/ui_type_fire.png", "Горіння (синій вогонь, до смерті)", "%d / с" % int(Weapons.burn_dps(id, lvl) * mm), b_n))
    if w.has("wave"):
        var wv_n := ""
        if has_next:
            wv_n = "%d" % int(Weapons.wave_damage(id, n) * mm)
        out.append(_stat("res://icons/ui_type_aoe.png", "Вогняна хвиля вперед (%.0f м, не підпалює)" % float(w.get("wave_r", 7.0)), "%d" % int(Weapons.wave_damage(id, lvl) * mm), wv_n))
    if w.has("aoe"):
        out.append(_stat("res://icons/ui_type_aoe.png", "Радіус вибуху", "%.1f м" % float(w["aoe"])))
    out.append(_stat("res://icons/ui_knock.png", "Відкидання", "%d" % int(float(w["knock"]))))
    if w.has("lifesteal"):
        out.append(_stat("res://icons/ui_heart.png", "Вампіризм", "%d%% від урону" % int(round(float(w["lifesteal"]) * 100.0))))
    return out

func _fill_weapon_popup() -> void:
    for ch in popup_box.get_children():
        popup_box.remove_child(ch)
        ch.queue_free()
    var id := popup_id
    var w: Dictionary = Weapons.DATA[id]
    var owned := GameState.weapon_levels.has(id)
    var lvl := int(GameState.weapon_levels.get(id, 0))
    var special := bool(w.get("special", false))

    # --- шапка: велика іконка, назва, тип, зірки рівня, хрестик ---
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 16)
    popup_box.add_child(head)

    var frame := PanelContainer.new()
    var fcol := GOLD_C
    if special:
        fcol = Color(1.0, 0.62, 0.2)
    frame.add_theme_stylebox_override("panel", _sb(Color(0.19, 0.12, 0.065), fcol, 3, 12))
    var big := _icon(_wicon(id), 104.0)
    if not owned:
        big.modulate = Color(0.6, 0.58, 0.55)
    frame.add_child(big)
    if owned and Weapons.is_final(lvl):
        var prb := _make_rainbow_frame(12.0, 5.0)
        _fill_rect(prb)
        frame.add_child(prb)
    head.add_child(frame)

    var tv := VBoxContainer.new()
    tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tv.add_theme_constant_override("separation", 4)
    head.add_child(tv)
    var nm := Label.new()
    nm.text = String(w["name"])
    nm.theme_type_variation = "TitleLabel"
    nm.add_theme_font_size_override("font_size", 32)
    nm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    nm.add_theme_constant_override("outline_size", 6)
    tv.add_child(nm)

    var trow := HBoxContainer.new()
    trow.add_theme_constant_override("separation", 8)
    tv.add_child(trow)
    var type_s := String(w["type"])
    trow.add_child(_icon("res://icons/ui_type_%s.png" % type_s, 24.0))
    var tl := Label.new()
    var tname := String(TYPE_NAMES.get(type_s, ""))
    tl.text = tname.substr(0, 1).to_upper() + tname.substr(1)
    tl.add_theme_font_size_override("font_size", 17)
    trow.add_child(tl)
    if special:
        var spl := Label.new()
        spl.text = "★ ОСОБЛИВА"
        spl.add_theme_font_size_override("font_size", 15)
        spl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.2))
        trow.add_child(spl)

    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 3)
    tv.add_child(srow)
    for i in range(Weapons.MAX_LEVEL):
        var tint := Color(1, 1, 1, 1)
        if not (owned and lvl > i):
            tint = Color(0.28, 0.25, 0.22, 0.9)
        srow.add_child(_icon("res://icons/ui_star.png", 19.0, tint))
    # 11-та зірка — фінальна прокачка (веселкова, коли отримана)
    var fin_on := owned and Weapons.is_final(lvl)
    var fin_star := _icon("res://icons/ui_star.png", 26.0, Color(1, 1, 1, 1) if fin_on else Color(0.28, 0.25, 0.22, 0.9))
    if fin_on:
        fin_star.material = _star_rainbow_material()
    srow.add_child(fin_star)
    var lvl_l := Label.new()
    if fin_on:
        lvl_l.text = "  ФІНАЛЬНИЙ рівень"
    elif owned:
        lvl_l.text = "  Рівень %d/%d" % [lvl, Weapons.MAX_LEVEL]
    else:
        lvl_l.text = "  Ще не здобуто"
    lvl_l.add_theme_font_size_override("font_size", 15)
    lvl_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
    srow.add_child(lvl_l)

    var close := Button.new()
    close.custom_minimum_size = Vector2(38, 38)
    close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    close.focus_mode = Control.FOCUS_NONE
    close.icon = load("res://icons/ui_cross.png")
    close.expand_icon = true
    close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    close.add_theme_constant_override("icon_max_width", 22)
    close.tooltip_text = "Закрити (Esc)"
    _style_button(close, _sb(Color(0.25, 0.07, 0.05), Color(0.7, 0.25, 0.15), 2, 8), _sb(Color(0.1, 0.08, 0.06), Color(0.3, 0.3, 0.3), 2, 8))
    close.pressed.connect(_close_weapon_popup)
    head.add_child(close)

    popup_box.add_child(HSeparator.new())

    # --- майстерність (рівні за вбивства в бою) ---
    if owned:
        var kills := int(GameState.weapon_kills.get(id, 0))
        var ml := Weapons.mastery_level(kills, String(id))
        var nk := Weapons.mastery_next_kills(kills, String(id))
        var mrow := HBoxContainer.new()
        mrow.add_theme_constant_override("separation", 3)
        popup_box.add_child(mrow)
        for i in range(Weapons.MASTERY_MAX):
            var mt := Color(0.55, 0.95, 0.55, 1) if ml > i else Color(0.25, 0.30, 0.25, 0.9)
            var pip := ColorRect.new()
            pip.custom_minimum_size = Vector2(18, 10)
            pip.color = mt
            pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
            mrow.add_child(pip)
        var ml_l := Label.new()
        ml_l.add_theme_font_size_override("font_size", 15)
        ml_l.add_theme_color_override("font_color", Color(0.65, 1.0, 0.65))
        if nk < 0:
            ml_l.text = "Майстерність %d/%d (МАКС) · вбито: %d · +%d%% урону" % [ml, Weapons.MASTERY_MAX, kills, int(round(Weapons.MASTERY_DMG_PER_LEVEL * float(ml) * 100.0))]
        else:
            ml_l.text = "Майстерність %d/%d · вбито: %d/%d · +%d%% урону" % [ml, Weapons.MASTERY_MAX, kills, nk, int(round(Weapons.MASTERY_DMG_PER_LEVEL * float(ml) * 100.0))]
        popup_box.add_child(ml_l)
        ml_l.tooltip_text = "Майстерність росте, коли ви вбиваєте зомбі цією зброєю в бою."
        ml_l.mouse_filter = Control.MOUSE_FILTER_PASS

    # --- опис ---
    var desc := Label.new()
    desc.text = String(w["desc"])
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", 18)
    desc.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
    popup_box.add_child(desc)

    # --- характеристики (зелена стрілка — що буде після прокачки) ---
    var stats := VBoxContainer.new()
    stats.add_theme_constant_override("separation", 3)
    popup_box.add_child(stats)
    for st in _weapon_stats(id, lvl):
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        var ic := _icon(String(st["icon"]), 26.0)
        row.add_child(ic)
        var ln := Label.new()
        ln.text = String(st["label"])
        ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(ln)
        var lv := Label.new()
        lv.text = String(st["cur"])
        lv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
        row.add_child(lv)
        if String(st["next"]) != "" and String(st["next"]) != String(st["cur"]):
            var ln2 := Label.new()
            ln2.text = "→ " + String(st["next"])
            ln2.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
            row.add_child(ln2)
        stats.add_child(row)

    # --- звідки зброя ---
    var uloc := Weapons.unlock_loc(id)
    if uloc != "":
        var urow := HBoxContainer.new()
        urow.add_theme_constant_override("separation", 8)
        urow.add_child(_icon("res://icons/ui_flag.png", 22.0))
        var ul := Label.new()
        ul.text = "Відкрито після проходження: «%s»" % String(Locations.by_id(uloc)["name"])
        ul.add_theme_font_size_override("font_size", 14)
        ul.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
        urow.add_child(ul)
        popup_box.add_child(urow)

    if owned and lvl >= Weapons.MAX_LEVEL:
        var fn := Label.new()
        fn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        fn.add_theme_font_size_override("font_size", 15)
        if Weapons.is_final(lvl):
            fn.text = "★ Фінальна прокачка отримана: приріст урону в 3 рази більше, ніж від звичайної."
            fn.add_theme_color_override("font_color", Color(1.0, 0.8, 1.0))
        else:
            fn.text = "★ Фінальна прокачка: коштує половину суми всіх попередніх і дає втричі більше урону, ніж звичайна."
            fn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
        popup_box.add_child(fn)

    popup_box.add_child(HSeparator.new())

    # --- кнопки ---
    var brow := HBoxContainer.new()
    brow.alignment = BoxContainer.ALIGNMENT_CENTER
    brow.add_theme_constant_override("separation", 12)
    popup_box.add_child(brow)
    if not owned:
        var price := int(w["price"])
        var bb := _popup_button("Здобути (%d)" % price, "res://icons/ui_coin.png")
        bb.disabled = GameState.coins < price
        bb.pressed.connect(_on_weapon_buy.bind(id))
        brow.add_child(bb)
    else:
        if lvl >= Weapons.FINAL_LEVEL:
            var mb := _popup_button("Вершина", "res://icons/ui_star.png")
            mb.disabled = true
            brow.add_child(mb)
        else:
            var cost := Weapons.upgrade_cost(id, lvl)
            var last := lvl >= Weapons.MAX_LEVEL
            var ub := _popup_button(("ФІНАЛ (%d)" if last else "Загартувати (%d)") % cost, "res://icons/ui_star.png" if last else "res://icons/ui_arrow_up.png")
            ub.disabled = GameState.coins < cost
            ub.pressed.connect(_on_weapon_upgrade.bind(id))
            brow.add_child(ub)
        var in_set := GameState.loadout.has(id)
        var lb: Button
        if in_set:
            lb = _popup_button("З набору", "res://icons/ui_cross.png")
            lb.disabled = GameState.loadout.size() <= 1
        else:
            lb = _popup_button("У набір", "res://icons/ui_check.png")
            lb.disabled = GameState.loadout.size() >= GameState.MAX_LOADOUT
        lb.pressed.connect(_on_weapon_loadout.bind(id))
        brow.add_child(lb)

func _popup_button(text: String, icon_path: String) -> Button:
    var b := Button.new()
    b.text = " " + text
    b.icon = load(icon_path)
    b.expand_icon = true
    b.add_theme_constant_override("icon_max_width", 24)
    b.add_theme_font_size_override("font_size", 19)
    b.custom_minimum_size = Vector2(200, 46)
    b.focus_mode = Control.FOCUS_NONE
    return b

# ================= Броня =================
# Той самий вигляд, що й у зброї: комірка-«вікно», кнопка «+», ціна під нею,
# праворуч — рівні броні, по кліку — вікно з інформацією. Фону кузні тут немає.
var armor_slots := {}          # ключ (Armor.key) -> вузли комірки
var armor_key_info := {}       # ключ -> {"slot": слот, "set": номер комплекту}
var armor_set_boxes: Array = []   # комплект -> блок із комірками (ховається, поки комплект не відкрито)
var armor_tier_btns := {}      # слот -> [кнопки рівнів у правій панелі]
var armor_overlay: ColorRect
var armor_popup_box: VBoxContainer
var armor_popup_key := ""      # ключ комірки, яка відкрита у вікні

func _aicon(slot: String, tier: int) -> String:
    # рівень 0 («немає») показуємо силуетом першого рівня
    return "res://icons/a_%s_%d.png" % [slot, maxi(tier, 1)]

func _build_armor_page(holder: Control) -> Control:
    var page := Control.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(page)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14.0
    panel.offset_top = 46.0
    panel.offset_right = -14.0
    panel.offset_bottom = -10.0
    panel.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.10), Color(0.55, 0.38, 0.12, 0.55), 2, 8))
    page.add_child(panel)

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 14)
    panel.add_child(cols)

    # ---------- ліворуч: комірки броні ----------
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(3.0 * (SLOT_PX + PLUS_W + 4.0) + 2.0 * 14.0 + 16.0, 0)
    left.add_theme_constant_override("separation", 8)
    cols.add_child(left)

    var hint := Label.new()
    hint.text = "Кожен новий комплект броні має власні комірки, а стара не прокачується. У бою діє найкраща частина з тих, що ти придбав. Торкнись броні, щоб роздивитись її, а «+» — швидка купівля."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    left.add_child(hint)

    # комплекти броні: кожен — окремий блок комірок; нові з'являються, коли пройдено потрібну локацію
    var sets_scroll := ScrollContainer.new()
    sets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left.add_child(sets_scroll)
    var sets_v := VBoxContainer.new()
    sets_v.add_theme_constant_override("separation", 12)
    sets_scroll.add_child(sets_v)
    armor_slots = {}
    armor_key_info = {}
    armor_set_boxes = []
    for si in range(Armor.SETS.size()):
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 4)
        var ttl := Label.new()
        ttl.text = String(Armor.SETS[si]["name"])
        ttl.add_theme_font_size_override("font_size", 18)
        ttl.add_theme_color_override("font_color", Armor.TIER_COLORS[Armor.set_last(si)].lightened(0.2))
        box.add_child(ttl)
        var grid := GridContainer.new()
        grid.columns = 3
        grid.add_theme_constant_override("h_separation", 14)
        grid.add_theme_constant_override("v_separation", 8)
        box.add_child(grid)
        for slot in Armor.SLOTS:
            grid.add_child(_make_armor_cell(String(slot), si))
        sets_v.add_child(box)
        armor_set_boxes.append(box)

    armor_label = Label.new()
    armor_label.add_theme_font_size_override("font_size", 16)
    armor_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    left.add_child(armor_label)

    # ---------- праворуч: рівні броні ----------
    var armor_spacer := Control.new()                  # відсуває панель рівнів у правий кут
    armor_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    armor_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cols.add_child(armor_spacer)
    cols.add_child(_build_armor_tiers_panel())

    # ---------- вікно з інформацією ----------
    armor_overlay = ColorRect.new()
    armor_overlay.color = Color(0, 0, 0, 0.66)
    armor_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _fill_rect(armor_overlay)
    armor_overlay.visible = false
    armor_overlay.gui_input.connect(_on_armor_overlay_input)
    page.add_child(armor_overlay)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fill_rect(center)
    armor_overlay.add_child(center)
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(580, 0)
    var cs := _sb(Color(0.10, 0.06, 0.035, 0.99), GOLD_C, 3, 14)
    cs.content_margin_left = 22.0
    cs.content_margin_right = 22.0
    cs.content_margin_top = 16.0
    cs.content_margin_bottom = 18.0
    cs.shadow_color = Color(0, 0, 0, 0.7)
    cs.shadow_size = 14
    card.add_theme_stylebox_override("panel", cs)
    center.add_child(card)
    armor_popup_box = VBoxContainer.new()
    armor_popup_box.add_theme_constant_override("separation", 10)
    card.add_child(armor_popup_box)
    return page

func _make_armor_cell(slot: String, si: int) -> Control:
    var k := Armor.key(slot, si)
    var cell := VBoxContainer.new()
    cell.add_theme_constant_override("separation", 3)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 4)
    cell.add_child(top)

    var btn := Button.new()
    btn.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(_open_armor_popup.bind(k))
    top.add_child(btn)

    var icon := _icon(_aicon(slot, Armor.set_first(si)), 68.0)
    _fill_rect(icon, 6.0)
    btn.add_child(icon)

    var lvl_lb := Label.new()
    _fill_rect(lvl_lb, 4.0)
    lvl_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lvl_lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    lvl_lb.add_theme_font_size_override("font_size", 14)
    lvl_lb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
    lvl_lb.add_theme_constant_override("outline_size", 5)
    lvl_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(lvl_lb)

    var plus := Button.new()
    plus.custom_minimum_size = Vector2(PLUS_W, SLOT_PX)
    plus.focus_mode = Control.FOCUS_NONE
    plus.expand_icon = true
    plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    plus.add_theme_constant_override("icon_max_width", 20)
    plus.pressed.connect(_on_armor_buy.bind(k))
    _style_button(plus, _sb(Color(0.42, 0.28, 0.07), GOLD_C, 2, 8), _sb(Color(0.10, 0.08, 0.06, 0.8), Color(0.28, 0.22, 0.14), 2, 8))
    top.add_child(plus)

    var nm := Label.new()
    nm.text = String(Armor.SLOT_NAMES[slot])
    nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nm.add_theme_font_size_override("font_size", 14)
    nm.add_theme_color_override("font_color", CREAM)
    cell.add_child(nm)

    var prow := HBoxContainer.new()
    prow.alignment = BoxContainer.ALIGNMENT_CENTER
    prow.custom_minimum_size = Vector2(0, 20)
    prow.add_theme_constant_override("separation", 4)
    cell.add_child(prow)
    var coin := _icon("res://icons/ui_coin.png", 16.0)
    prow.add_child(coin)
    var price := Label.new()
    price.add_theme_font_size_override("font_size", 15)
    prow.add_child(price)

    armor_slots[k] = {"btn": btn, "icon": icon, "lvl": lvl_lb, "plus": plus, "price": price, "coin": coin}
    armor_key_info[k] = {"slot": slot, "set": si}
    return cell

# Права панель: усі рівні кожної частини броні, комплект за комплектом.
# Вузька панель «Рівні броні» у правому куті: три стовпці (шолом / нагрудник / чоботи), рівні йдуть ВНИЗ,
# панель прокручується вертикально. Фон (нічний базар) лишається видимим.
func _build_armor_tiers_panel() -> Control:
    var pn := PanelContainer.new()
    var ps := _sb(Color(0.05, 0.03, 0.02, 0.55), Color(0.90, 0.70, 0.18, 0.85), 2, 8)
    pn.add_theme_stylebox_override("panel", ps)
    pn.custom_minimum_size = Vector2(190, 0)
    pn.size_flags_horizontal = Control.SIZE_SHRINK_END
    pn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 4)
    pn.add_child(v)

    var title := Label.new()
    title.text = "Рівні броні"
    title.theme_type_variation = "TitleLabel"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 5)
    title.mouse_filter = Control.MOUSE_FILTER_STOP
    title.tooltip_text = "Звичайна броня (шкіряна → професійний лицар) — одразу. Після «Мертвого мегаполіса» з'являється «Броня мегаполіса», після «Міста-привида» — «Броня привида», після «Магмового ядра» — «Магмова броня». Кожен комплект — окремі слоти зліва."
    v.add_child(title)

    # заголовки стовпців (іконки слотів) — поза прокруткою, щоб завжди було видно
    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 4)
    var hsp := Control.new()
    hsp.custom_minimum_size = Vector2(22, 0)
    head.add_child(hsp)
    for slot in Armor.SLOTS:
        var hs := String(slot)
        var hic := _icon(_aicon(hs, 1), 30.0)
        hic.custom_minimum_size = Vector2(36, 30)
        hic.mouse_filter = Control.MOUSE_FILTER_STOP
        hic.tooltip_text = String(Armor.SLOT_NAMES[hs])
        head.add_child(hic)
    v.add_child(head)

    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(sc)
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    sc.add_child(grid)

    armor_tier_btns = {}
    for slot in Armor.SLOTS:
        armor_tier_btns[String(slot)] = []
    for t in range(1, Armor.MAX_TIER + 1):
        var si := Armor.set_of_tier(t)
        if t == Armor.set_first(si) and si > 0:
            for c in range(4):                       # проміжок між комплектами
                var gap := Control.new()
                gap.custom_minimum_size = Vector2(0, 8)
                grid.add_child(gap)
        var num := Label.new()
        num.text = str(t)
        num.custom_minimum_size = Vector2(22, 36)
        num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        num.add_theme_font_size_override("font_size", 14)
        num.add_theme_color_override("font_color", Armor.TIER_COLORS[t])
        grid.add_child(num)
        for slot in Armor.SLOTS:
            var s := String(slot)
            var b := Button.new()
            b.custom_minimum_size = Vector2(36, 36)
            b.focus_mode = Control.FOCUS_NONE
            b.pressed.connect(_open_armor_popup.bind(Armor.key(s, si)))
            var ic := _icon(_aicon(s, t), 30.0)
            _fill_rect(ic, 4.0)
            b.add_child(ic)
            var ck := _icon("res://icons/ui_check.png", 16.0)
            ck.position = Vector2(20, 20)
            ck.size = Vector2(14, 14)
            b.add_child(ck)
            grid.add_child(b)
            (armor_tier_btns[s] as Array).append({"btn": b, "icon": ic, "check": ck, "tier": t, "set": si})
    return pn

func _armor_lock_text(tier: int = 5) -> String:
    var l: Dictionary = Locations.by_id(Armor.unlock_loc(tier))
    return "Відкриється після проходження локації «%s»" % String(l["name"])

# наступний наскрізний рівень у комплекті для комірки (0 — комплект повністю куплений)
func _armor_next_tier(k: String) -> int:
    var info: Dictionary = armor_key_info[k]
    var si := int(info["set"])
    var tier := int(GameState.armor.get(k, 0))
    if tier >= Armor.set_last(si):
        return 0
    return Armor.set_first(si) if tier == 0 else tier + 1

func _on_armor_buy(k: String) -> void:
    var nt := _armor_next_tier(k)
    if nt == 0:
        return
    if not GameState.armor_tier_unlocked(nt):
        return          # цей рівень броні ще закритий
    var slot := String((armor_key_info[k] as Dictionary)["slot"])
    var price := Armor.price(slot, nt)
    if GameState.coins < price:
        return
    GameState.coins -= price
    GameState.armor[k] = nt
    Sfx.play("buy")
    GameState.save_game()
    _refresh_all()
    # маленька «пружинка» на комірці, коли броня змінила вигляд
    var b: Control = armor_slots[k]["btn"]
    b.pivot_offset = b.size * 0.5
    b.scale = Vector2(1.25, 1.25)
    var tw := b.create_tween()
    tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_armor() -> void:
    armor_label.text = "Загальний захист: %d%%    Швидкість від чобіт: +%d%%" % [int(GameState.armor_defense() * 100.0), int(GameState.armor_speed() * 100.0)]
    for si in range(armor_set_boxes.size()):
        (armor_set_boxes[si] as Control).visible = GameState.armor_set_open(si)
    for k in armor_key_info:
        var info: Dictionary = armor_key_info[k]
        var s := String(info["slot"])
        var si := int(info["set"])
        var first := Armor.set_first(si)
        var last := Armor.set_last(si)
        var tier := int(GameState.armor.get(k, 0))
        var d: Dictionary = armor_slots[k]
        var btn: Button = d["btn"]
        var plus: Button = d["plus"]
        var price: Label = d["price"]
        var coin: TextureRect = d["coin"]
        var icon: TextureRect = d["icon"]
        icon.texture = load(_aicon(s, tier if tier > 0 else first))
        icon.modulate = Color(1, 1, 1, 1) if tier > 0 else Color(0.42, 0.40, 0.38, 1)
        (d["lvl"] as Label).text = ("ур.%d" % (tier - first + 1)) if tier > 0 else ""

        var bg := Color(0.13, 0.085, 0.05, 0.86)
        var border := Color(0.55, 0.40, 0.15)
        if tier > 0:
            bg = Color(0.20, 0.13, 0.07, 0.98)
            border = GOLD_C
        if tier >= last:
            border = Color(1.0, 0.62, 0.2)
        _style_button(btn, _sb(bg, border, 2, 10), _sb(bg, border, 2, 10))
        btn.tooltip_text = "%s: %s" % [String(Armor.SLOT_NAMES[s]), String(Armor.TIER_NAMES[tier if tier > 0 else first])]

        var plus_ok := false
        var nt := _armor_next_tier(k)
        if nt == 0:
            plus.icon = load("res://icons/ui_star.png")
            plus.tooltip_text = "Максимальний рівень комплекту"
            coin.visible = false
            price.text = "МАКС"
            price.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
        elif not GameState.armor_tier_unlocked(nt):
            plus.icon = load("res://icons/ui_lock.png")
            plus.tooltip_text = _armor_lock_text(nt)
            coin.visible = false
            price.text = "Замкнено"
            price.add_theme_color_override("font_color", Color(0.75, 0.6, 0.55))
        else:
            var cost := Armor.price(s, nt)
            plus_ok = GameState.coins >= cost
            plus.icon = load("res://icons/ui_plus.png" if tier == 0 else "res://icons/ui_arrow_up.png")
            plus.tooltip_text = "Здобути" if tier == 0 else "Загартувати"
            coin.visible = true
            price.text = str(cost)
            price.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if plus_ok else Color(0.95, 0.45, 0.38))
        plus.disabled = not plus_ok

    # права панель
    for slot in Armor.SLOTS:
        var s2 := String(slot)
        var list: Array = armor_tier_btns[s2]
        for u in list:
            var t := int(u["tier"])
            var usi := int(u["set"])
            var owned := int(GameState.armor.get(Armor.key(s2, usi), 0))
            var tb: Button = u["btn"]
            var reached := owned >= t
            var is_next := (owned == 0 and t == Armor.set_first(usi)) or (owned > 0 and t == owned + 1)
            var t_locked := not GameState.armor_tier_unlocked(t)
            (u["check"] as TextureRect).visible = reached
            (u["icon"] as TextureRect).modulate = Color(1, 1, 1, 1) if reached else (Color(0.45, 0.45, 0.45, 1) if (is_next and not t_locked) else Color(0.25, 0.25, 0.25, 1))
            tb.tooltip_text = "%s — %s (захист %d%%)" % [String(Armor.SETS[usi]["name"]), String(Armor.TIER_NAMES[t]), int(Armor.defense(s2, t) * 100.0)]
            if s2 == "boots":
                tb.tooltip_text += ", швидкість +%d%%" % int(float(Armor.BOOTS_SPEED[t]) * 100.0)
            if t_locked:
                tb.tooltip_text += "\n" + _armor_lock_text(t)
            var tbg := Color(0.10, 0.07, 0.045)
            var tbd := Color(0.40, 0.30, 0.14)
            if reached:
                tbd = Armor.TIER_COLORS[t]
            elif not is_next or t_locked:
                tbg = Color(0.05, 0.035, 0.025)
                tbd = Color(0.25, 0.19, 0.11)
            _style_button(tb, _sb(tbg, tbd, 2, 8), _sb(tbg, tbd, 2, 8))

    if armor_popup_key != "":
        _fill_armor_popup()

# ---------- вікно з інформацією про броню ----------
func _open_armor_popup(k: String) -> void:
    armor_popup_key = k
    _fill_armor_popup()
    armor_overlay.visible = true

func _close_armor_popup() -> void:
    armor_popup_key = ""
    if armor_overlay != null:
        armor_overlay.visible = false

func _on_armor_overlay_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
            _close_armor_popup()

func _fill_armor_popup() -> void:
    for ch in armor_popup_box.get_children():
        armor_popup_box.remove_child(ch)
        ch.queue_free()
    var k := armor_popup_key
    var info: Dictionary = armor_key_info[k]
    var s := String(info["slot"])
    var si := int(info["set"])
    var first := Armor.set_first(si)
    var last := Armor.set_last(si)
    var tier := int(GameState.armor.get(k, 0))

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 16)
    armor_popup_box.add_child(head)

    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", _sb(Color(0.19, 0.12, 0.065), GOLD_C if tier < last else Color(1.0, 0.62, 0.2), 3, 12))
    var big := _icon(_aicon(s, tier if tier > 0 else first), 104.0)
    if tier == 0:
        big.modulate = Color(0.6, 0.58, 0.55)
    frame.add_child(big)
    head.add_child(frame)

    var tv := VBoxContainer.new()
    tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tv.add_theme_constant_override("separation", 4)
    head.add_child(tv)
    var nm := Label.new()
    nm.text = String(Armor.SLOT_NAMES[s])
    nm.theme_type_variation = "TitleLabel"
    nm.add_theme_font_size_override("font_size", 32)
    nm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    nm.add_theme_constant_override("outline_size", 6)
    tv.add_child(nm)

    var tl := Label.new()
    tl.text = "%s — %s" % [String(Armor.SETS[si]["name"]), String(Armor.TIER_NAMES[tier if tier > 0 else first])]
    tl.add_theme_font_size_override("font_size", 17)
    tl.add_theme_color_override("font_color", Armor.TIER_COLORS[tier if tier > 0 else first].lightened(0.25))
    tv.add_child(tl)

    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 3)
    tv.add_child(srow)
    for i in range(last - first + 1):
        var tint := Color(1, 1, 1, 1)
        if tier < first + i:
            tint = Color(0.28, 0.25, 0.22, 0.9)
        srow.add_child(_icon("res://icons/ui_star.png", 24.0, tint))
    var lvl_l := Label.new()
    lvl_l.text = ("  Рівень %d/%d" % [tier - first + 1, last - first + 1]) if tier > 0 else "  Ще не здобуто"
    lvl_l.add_theme_font_size_override("font_size", 15)
    lvl_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
    srow.add_child(lvl_l)

    var close := Button.new()
    close.custom_minimum_size = Vector2(38, 38)
    close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    close.focus_mode = Control.FOCUS_NONE
    close.icon = load("res://icons/ui_cross.png")
    close.expand_icon = true
    close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    close.add_theme_constant_override("icon_max_width", 22)
    close.tooltip_text = "Закрити (Esc)"
    _style_button(close, _sb(Color(0.25, 0.07, 0.05), Color(0.7, 0.25, 0.15), 2, 8), _sb(Color(0.1, 0.08, 0.06), Color(0.3, 0.3, 0.3), 2, 8))
    close.pressed.connect(_close_armor_popup)
    head.add_child(close)

    armor_popup_box.add_child(HSeparator.new())

    var desc := Label.new()
    desc.text = "%s\n%s" % [String(Armor.SLOT_DESC[s]), String(Armor.SETS[si]["desc"])]
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", 18)
    desc.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
    armor_popup_box.add_child(desc)

    # характеристики (зелена стрілка — що буде після покупки / прокачки)
    var stats := VBoxContainer.new()
    stats.add_theme_constant_override("separation", 3)
    armor_popup_box.add_child(stats)
    var next := _armor_next_tier(k)
    var has_next := next != 0
    stats.add_child(_armor_stat_row("res://icons/ui_shield.png", "Оборона", "%d%%" % int(Armor.defense(s, tier) * 100.0), ("%d%%" % int(Armor.defense(s, next) * 100.0)) if has_next else ""))
    if s == "boots":
        stats.add_child(_armor_stat_row("res://icons/ui_boot.png", "Швидкість", "+%d%%" % int(float(Armor.BOOTS_SPEED[tier]) * 100.0), ("+%d%%" % int(float(Armor.BOOTS_SPEED[next]) * 100.0)) if has_next else ""))
    if tier > 0 and GameState.armor_best(s) > tier:
        var bt := Label.new()
        bt.text = "Нині тебе береже міцніша броня з іншого комплекту."
        bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        bt.add_theme_font_size_override("font_size", 14)
        bt.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
        armor_popup_box.add_child(bt)

    var next_locked := has_next and not GameState.armor_tier_unlocked(next)
    if next_locked:
        var lk := Label.new()
        lk.text = _armor_lock_text(next)
        lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        lk.add_theme_font_size_override("font_size", 15)
        lk.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
        armor_popup_box.add_child(lk)
    if has_next and tier > 0:
        var nrow := HBoxContainer.new()
        nrow.add_theme_constant_override("separation", 8)
        nrow.add_child(_icon(_aicon(s, next), 40.0))
        var nl := Label.new()
        nl.text = "Далі: %s" % String(Armor.TIER_NAMES[next])
        nl.add_theme_font_size_override("font_size", 15)
        nl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
        nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        nrow.add_child(nl)
        armor_popup_box.add_child(nrow)

    armor_popup_box.add_child(HSeparator.new())

    var brow := HBoxContainer.new()
    brow.alignment = BoxContainer.ALIGNMENT_CENTER
    armor_popup_box.add_child(brow)
    if not has_next:
        var mb := _popup_button("Вершина", "res://icons/ui_star.png")
        mb.disabled = true
        brow.add_child(mb)
    else:
        var cost := Armor.price(s, next)
        var bb := _popup_button(("Здобути (%d)" if tier == 0 else "Загартувати (%d)") % cost, "res://icons/ui_coin.png" if tier == 0 else "res://icons/ui_arrow_up.png")
        if next_locked:
            bb = _popup_button("Замкнено", "res://icons/ui_lock.png")
        bb.disabled = next_locked or GameState.coins < cost
        bb.pressed.connect(_on_armor_buy.bind(k))
        brow.add_child(bb)

func _armor_stat_row(icon_path: String, label: String, cur: String, nxt: String) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.add_child(_icon(icon_path, 26.0))
    var ln := Label.new()
    ln.text = label
    ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(ln)
    var lv := Label.new()
    lv.text = cur
    lv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    row.add_child(lv)
    if nxt != "" and nxt != cur:
        var l2 := Label.new()
        l2.text = "→ " + nxt
        l2.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
        row.add_child(l2)
    return row

# ================= Навики =================
# Той самий вигляд, що й у зброї та броні: комірка, «+», ціна, вікно з інформацією.
var skill_slots := {}
var skill_side_rows := {}
var skill_overlay: ColorRect
var skill_popup_box: VBoxContainer
var skill_popup_id := ""

func _sicon(id: String) -> String:
    return "res://icons/s_%s.png" % id

func _build_skills_page(holder: Control) -> Control:
    var page := Control.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder.add_child(page)

    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14.0
    panel.offset_top = 46.0
    panel.offset_right = -14.0
    panel.offset_bottom = -10.0
    panel.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.10), Color(0.55, 0.38, 0.12, 0.55), 2, 8))
    page.add_child(panel)

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 14)
    panel.add_child(cols)

    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(GRID_COLS * (SLOT_PX + PLUS_W + 4.0) + (GRID_COLS - 1) * 14.0, 0)
    left.add_theme_constant_override("separation", 8)
    cols.add_child(left)

    var hint := Label.new()
    hint.text = "Торкнись навика, щоб дізнатися більше, а «+» — швидке загартування. Уміння діють у кожному бою."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    left.add_child(hint)

    var grid := GridContainer.new()
    grid.columns = GRID_COLS
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 8)
    left.add_child(grid)
    skill_slots = {}
    for id in Skills.ORDER:
        grid.add_child(_make_skill_cell(String(id)))

    cols.add_child(_build_skills_side_panel())

    skill_overlay = ColorRect.new()
    skill_overlay.color = Color(0, 0, 0, 0.66)
    skill_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _fill_rect(skill_overlay)
    skill_overlay.visible = false
    skill_overlay.gui_input.connect(_on_skill_overlay_input)
    page.add_child(skill_overlay)
    var center := CenterContainer.new()
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fill_rect(center)
    skill_overlay.add_child(center)
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(580, 0)
    var cs := _sb(Color(0.10, 0.06, 0.035, 0.99), GOLD_C, 3, 14)
    cs.content_margin_left = 22.0
    cs.content_margin_right = 22.0
    cs.content_margin_top = 16.0
    cs.content_margin_bottom = 18.0
    cs.shadow_color = Color(0, 0, 0, 0.7)
    cs.shadow_size = 14
    card.add_theme_stylebox_override("panel", cs)
    center.add_child(card)
    skill_popup_box = VBoxContainer.new()
    skill_popup_box.add_theme_constant_override("separation", 10)
    card.add_child(skill_popup_box)
    return page

func _make_skill_cell(id: String) -> Control:
    var cell := VBoxContainer.new()
    cell.add_theme_constant_override("separation", 3)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 4)
    cell.add_child(top)

    var btn := Button.new()
    btn.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(_open_skill_popup.bind(id))
    top.add_child(btn)

    var icon := _icon(_sicon(id), 68.0)
    _fill_rect(icon, 6.0)
    btn.add_child(icon)

    var lvl_lb := Label.new()
    _fill_rect(lvl_lb, 4.0)
    lvl_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    lvl_lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    lvl_lb.add_theme_font_size_override("font_size", 14)
    lvl_lb.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
    lvl_lb.add_theme_constant_override("outline_size", 5)
    lvl_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(lvl_lb)

    var plus := Button.new()
    plus.custom_minimum_size = Vector2(PLUS_W, SLOT_PX)
    plus.focus_mode = Control.FOCUS_NONE
    plus.expand_icon = true
    plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    plus.add_theme_constant_override("icon_max_width", 20)
    plus.pressed.connect(_on_skill_buy.bind(id))
    _style_button(plus, _sb(Color(0.42, 0.28, 0.07), GOLD_C, 2, 8), _sb(Color(0.10, 0.08, 0.06, 0.8), Color(0.28, 0.22, 0.14), 2, 8))
    top.add_child(plus)

    var nm := Label.new()
    nm.text = String(Skills.DATA[id]["name"])
    nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nm.clip_text = true
    nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    nm.custom_minimum_size = Vector2(SLOT_PX + PLUS_W + 4.0, 0)
    nm.add_theme_font_size_override("font_size", 13)
    nm.add_theme_color_override("font_color", CREAM)
    cell.add_child(nm)

    var prow := HBoxContainer.new()
    prow.alignment = BoxContainer.ALIGNMENT_CENTER
    prow.custom_minimum_size = Vector2(0, 20)
    prow.add_theme_constant_override("separation", 4)
    cell.add_child(prow)
    var coin := _icon("res://icons/ui_coin.png", 16.0)
    prow.add_child(coin)
    var price := Label.new()
    price.add_theme_font_size_override("font_size", 15)
    prow.add_child(price)

    skill_slots[id] = {"btn": btn, "icon": icon, "lvl": lvl_lb, "plus": plus, "price": price, "coin": coin}
    return cell

# Права панель: список навиків із рівнями.
func _build_skills_side_panel() -> Control:
    var pn := PanelContainer.new()
    pn.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.03, 0.02, 0.58), Color(0.90, 0.70, 0.18, 0.85), 2, 8))
    pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    pn.add_child(v)

    var title := Label.new()
    title.text = "Твої уміння"
    title.theme_type_variation = "TitleLabel"
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 5)
    v.add_child(title)
    var sub := Label.new()
    sub.text = "Кожен щабель уміння назавжди робить тебе трохи грізнішим."
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", 14)
    sub.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
    v.add_child(sub)

    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(sc)
    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 4)
    sc.add_child(rows)
    skill_side_rows = {}
    for id in Skills.ORDER:
        var sid := String(id)
        var b := Button.new()
        b.custom_minimum_size = Vector2(0, 48)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_open_skill_popup.bind(sid))
        var h := HBoxContainer.new()
        _fill_rect(h, 4.0)
        h.add_theme_constant_override("separation", 8)
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(h)
        h.add_child(_icon(_sicon(sid), 38.0))
        var nm := Label.new()
        nm.text = String(Skills.DATA[sid]["name"])
        nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        nm.clip_text = true
        nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        nm.add_theme_font_size_override("font_size", 15)
        nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.add_child(nm)
        var lv := Label.new()
        lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        lv.add_theme_font_size_override("font_size", 15)
        lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.add_child(lv)
        rows.add_child(b)
        skill_side_rows[sid] = {"btn": b, "lvl": lv}
    return pn

func _on_skill_buy(id: String) -> void:
    if not GameState.skill_unlocked(id):
        return
    var lvl := GameState.skill_level(id)
    if lvl >= int(Skills.DATA[id]["max"]):
        return
    var cost := Skills.cost(id, lvl)
    if GameState.coins < cost:
        return
    GameState.coins -= cost
    GameState.skills[id] = lvl + 1
    Sfx.play("buy")
    GameState.save_game()
    _refresh_all()
    var b: Control = skill_slots[id]["btn"]
    b.pivot_offset = b.size * 0.5
    b.scale = Vector2(1.25, 1.25)
    var tw := b.create_tween()
    tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_skills() -> void:
    for id in Skills.ORDER:
        var sid := String(id)
        var dt: Dictionary = Skills.DATA[sid]
        var d: Dictionary = skill_slots[sid]
        var btn: Button = d["btn"]
        var plus: Button = d["plus"]
        var price: Label = d["price"]
        var coin: TextureRect = d["coin"]
        var lvl := GameState.skill_level(sid)
        var mx := int(dt["max"])
        var locked := not GameState.skill_unlocked(sid)
        (d["icon"] as TextureRect).modulate = Color(1, 1, 1, 1) if lvl > 0 else Color(0.42, 0.40, 0.38, 1)
        (d["lvl"] as Label).text = ("ур.%d" % lvl) if lvl > 0 else ""

        var bg := Color(0.13, 0.085, 0.05, 0.86)
        var border := Color(0.55, 0.40, 0.15)
        if lvl > 0:
            bg = Color(0.20, 0.13, 0.07, 0.98)
            border = GOLD_C
        if lvl >= mx:
            border = Color(1.0, 0.62, 0.2)
        _style_button(btn, _sb(bg, border, 2, 10), _sb(bg, border, 2, 10))
        btn.tooltip_text = "%s — %s" % [String(dt["name"]), String(dt["desc"])]

        var plus_ok := false
        if locked:
            plus.icon = load("res://icons/ui_lock.png")
            plus.tooltip_text = "Закрито: %s" % _skill_lock_text(sid)
            coin.visible = false
            price.text = "Замкнено"
            price.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
        elif lvl >= mx:
            plus.icon = load("res://icons/ui_star.png")
            plus.tooltip_text = "Вершина майстерності"
            coin.visible = false
            price.text = "МАКС"
            price.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
        else:
            var cost := Skills.cost(sid, lvl)
            plus_ok = GameState.coins >= cost
            plus.icon = load("res://icons/ui_plus.png" if lvl == 0 else "res://icons/ui_arrow_up.png")
            plus.tooltip_text = "Здобути" if lvl == 0 else "Загартувати"
            coin.visible = true
            price.text = str(cost)
            price.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if plus_ok else Color(0.95, 0.45, 0.38))
        plus.disabled = not plus_ok

        var sr: Dictionary = skill_side_rows[sid]
        var lv: Label = sr["lvl"]
        lv.text = "закрито" if locked else "%d/%d" % [lvl, mx]
        lv.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if lvl >= mx else (Color(1.0, 0.9, 0.5) if lvl > 0 else Color(0.6, 0.55, 0.45)))
        var sb := Color(0.07, 0.045, 0.03, 0.85) if lvl > 0 else Color(0.05, 0.035, 0.025, 0.85)
        var sbd := Color(0.55, 0.40, 0.15) if lvl > 0 else Color(0.25, 0.19, 0.11)
        _style_button(sr["btn"], _sb(sb, sbd, 2, 8), _sb(sb, sbd, 2, 8))

    if skill_popup_id != "":
        _fill_skill_popup()

func _skill_lock_text(id: String) -> String:
    var loc := Locations.by_id(String(Skills.DATA[id].get("unlock", "")))
    return "пройди «%s»" % String(loc.get("name", "?"))

# ---------- вікно з інформацією про навик ----------
func _open_skill_popup(id: String) -> void:
    skill_popup_id = id
    _fill_skill_popup()
    skill_overlay.visible = true

func _close_skill_popup() -> void:
    skill_popup_id = ""
    if skill_overlay != null:
        skill_overlay.visible = false

func _on_skill_overlay_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
            _close_skill_popup()

func _fill_skill_popup() -> void:
    for ch in skill_popup_box.get_children():
        skill_popup_box.remove_child(ch)
        ch.queue_free()
    var id := skill_popup_id
    var dt: Dictionary = Skills.DATA[id]
    var lvl := GameState.skill_level(id)
    var mx := int(dt["max"])

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 16)
    skill_popup_box.add_child(head)

    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", _sb(Color(0.19, 0.12, 0.065), GOLD_C if lvl < mx else Color(1.0, 0.62, 0.2), 3, 12))
    var big := _icon(_sicon(id), 104.0)
    if lvl == 0:
        big.modulate = Color(0.6, 0.58, 0.55)
    frame.add_child(big)
    head.add_child(frame)

    var tv := VBoxContainer.new()
    tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tv.add_theme_constant_override("separation", 4)
    head.add_child(tv)
    var nm := Label.new()
    nm.text = String(dt["name"])
    nm.theme_type_variation = "TitleLabel"
    nm.add_theme_font_size_override("font_size", 30)
    nm.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    nm.add_theme_constant_override("outline_size", 6)
    nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tv.add_child(nm)

    var srow := HBoxContainer.new()
    srow.add_theme_constant_override("separation", 2)
    tv.add_child(srow)
    for i in range(mx):
        var tint := Color(1, 1, 1, 1)
        if lvl <= i:
            tint = Color(0.28, 0.25, 0.22, 0.9)
        srow.add_child(_icon("res://icons/ui_star.png", 18.0, tint))
    var lvl_l := Label.new()
    lvl_l.text = ("Рівень %d/%d" % [lvl, mx]) if lvl > 0 else "Ще не загартовано"
    lvl_l.add_theme_font_size_override("font_size", 15)
    lvl_l.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
    tv.add_child(lvl_l)

    var close := Button.new()
    close.custom_minimum_size = Vector2(38, 38)
    close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    close.focus_mode = Control.FOCUS_NONE
    close.icon = load("res://icons/ui_cross.png")
    close.expand_icon = true
    close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    close.add_theme_constant_override("icon_max_width", 22)
    close.tooltip_text = "Закрити (Esc)"
    _style_button(close, _sb(Color(0.25, 0.07, 0.05), Color(0.7, 0.25, 0.15), 2, 8), _sb(Color(0.1, 0.08, 0.06), Color(0.3, 0.3, 0.3), 2, 8))
    close.pressed.connect(_close_skill_popup)
    head.add_child(close)

    skill_popup_box.add_child(HSeparator.new())

    var desc := Label.new()
    desc.text = String(dt["desc"])
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", 18)
    desc.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
    skill_popup_box.add_child(desc)

    if id == "dash" or id == "jump":
        var st := Label.new()
        st.text = "Зараз: %s" % Skills.stat_line(id, lvl)
        if lvl < mx:
            st.text += "\nДалі: %s" % Skills.stat_line(id, lvl + 1)
        st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        st.add_theme_font_size_override("font_size", 16)
        st.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
        skill_popup_box.add_child(st)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    row.add_child(_icon("res://icons/ui_arrow_up.png", 26.0))
    var ln := Label.new()
    ln.text = "Рівень"
    ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(ln)
    var lv := Label.new()
    lv.text = "%d" % lvl
    lv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    row.add_child(lv)
    if lvl < mx:
        var l2 := Label.new()
        l2.text = "→ %d" % (lvl + 1)
        l2.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
        row.add_child(l2)
    skill_popup_box.add_child(row)

    skill_popup_box.add_child(HSeparator.new())

    var brow := HBoxContainer.new()
    brow.alignment = BoxContainer.ALIGNMENT_CENTER
    skill_popup_box.add_child(brow)
    if not GameState.skill_unlocked(id):
        var lb := _popup_button("Закрито: %s" % _skill_lock_text(id), "res://icons/ui_lock.png")
        lb.disabled = true
        brow.add_child(lb)
    elif lvl >= mx:
        var mb := _popup_button("Вершина", "res://icons/ui_star.png")
        mb.disabled = true
        brow.add_child(mb)
    else:
        var cost := Skills.cost(id, lvl)
        var bb := _popup_button(("Здобути (%d)" if lvl == 0 else "Загартувати (%d)") % cost, "res://icons/ui_coin.png" if lvl == 0 else "res://icons/ui_arrow_up.png")
        bb.disabled = GameState.coins < cost
        bb.pressed.connect(_on_skill_buy.bind(id))
        brow.add_child(bb)

# ================= Загальне =================
func _refresh_all() -> void:
    coins_label.text = "%d" % GameState.coins
    var playable := 0
    for l in Locations.DATA:
        if not bool(l.get("wip", false)):
            playable += 1
    progress_label.text = "Літопис: %d/%d" % [GameState.conquered.size(), playable]
    world_map.selected = sel_id
    world_map.refresh()
    _refresh_info()
    _refresh_weapons()
    _refresh_armor()
    _refresh_skills()
