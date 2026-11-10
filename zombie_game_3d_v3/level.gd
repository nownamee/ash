extends Node3D
# Бій на локації: хвилі зомбі, арена, інтерфейс. Локація береться з GameState.selected_loc.
# Перемога — пройти всі хвилі й убити боса. Зброя, броня та навики — з прогресу (купуються в меню).

const Weapons = preload("res://weapons.gd")
const Biomes = preload("res://biomes.gd")
const ZombieTypes = preload("res://zombie_types.gd")
const Locations = preload("res://locations.gd")
const GameState = preload("res://game_state.gd")
const Skills = preload("res://skills.gd")
const GameFonts = preload("res://game_fonts.gd")
const PlayerScript = preload("res://player.gd")
const ZombieScript = preload("res://zombie.gd")
const TerrainScript = preload("res://terrain.gd")
const MinimapScript = preload("res://minimap.gd")
const PickupScript = preload("res://pickup.gd")
const FlickerLight = preload("res://light_flicker.gd")
const CastleScript = preload("res://castle.gd")
const VolcanoScript = preload("res://volcano.gd")
const DefendRoadScript = preload("res://defend_road.gd")
const DefendPostScript = preload("res://defend_post.gd")

# --- Налаштування камери ---
const CAM_DISTANCE := 26.0   # відстань від гравця (більше = "плоскіше")
const CAM_TILT := 68.0       # нахил у градусах (90 = рівно зверху)
const CAM_FOV := 40.0

const KnightScript = preload("res://knight.gd")

const MAX_ALIVE := 45        # максимум зомбі одночасно

# --- Продуктивність (змінюйте тут) ---
const SSAO_ENABLED := false      # затемнення в закутках: дуже дороге, а з висоти камери майже не помітне
const GLOW_ENABLED := true       # світіння вогню й очей
const SHADOW_DISTANCE := 42.0    # до якої відстані від камери малюються тіні (було 60)
const RENDER_SCALE := 0.85       # внутрішня роздільність 3D (1.0 = рідна). 0.85 + FSR майже не видно, але значно швидше

var loc: Dictionary
var tier := 1
var max_waves := 5
var arena_r := 60.0
var coin_mult := 1.0
var state := "playing"

var world: Node3D
var terrain
var player
var camera: Camera3D
var env: Environment
var cam_offset := Vector3.ZERO

var biome_t := 0.0
var cur_biome := -1
var fog_target := Color.BLACK
var amb_target := Color.BLACK

var wave := 0
var to_spawn := 0
var wave_total := 0          # скільки зомбі в поточній хвилі за планом (для елітних «extras»)
var extras_done := 0         # скільки елітних вставок поточної хвилі вже з'явилось
var horde_boss := false
# місія з ескортом: лицаря треба довести до замку; зомбі з'являються постійно
var escort := false
var escort_len := 170.0
var escort_phase := "go"        # go — шлях до лицаря, back — ведемо його до замку
var knight
var escort_spawn := 3.0
const ESCORT_CAP_GO := 32          # скільки зомбі одночасно на шляху до лицаря (було 12)
const ESCORT_CAP_BACK := 44        # ...і на зворотному шляху (було 17)
var spawn_timer := 0.0
var intermission := -1.0
var boss_pending := false
var kills := 0
var earned := 0
var msg_time := 0.0
var shake := 0.0
var time_alive := 0.0
var groan_timer := 3.0
var heart_timer := 0.0
var low_hp_rect: ColorRect

# Місія зачистки («Мертве село»): без хвиль. Зомбі розкидані по всій карті й сплять (див. zombie.gd → idle).
# Щоб не будувати десятки моделей і не ставити їх у ще не створені дерева, зомбі «матеріалізуються»,
# коли герой підходить на CLEAR_SPAWN_R метрів (чанки місцевості на цей час уже побудовані).
const CLEAR_SPAWN_R := 52.0      # з якої відстані створюємо сплячого зомбі
const CLEAR_START_SAFE := 26.0   # навколо замку на старті зомбі немає
const CLEAR_HUNT_LEFT := 8       # скільки лишилось, щоб мінікарта показала всіх стрілками
const CLEAR_WAVE := 3            # «хвиля» для множників здоров'я/сили (як ранні хвилі локації)
var clear := false
var clear_pending: Array = []    # [{pos: Vector2, kind: String, boss: bool}]
var clear_total := 0
var clear_t := 0.0

# Замок на старті (тільки перша локація): поки герой не вийде за ворота, хвилі не починаються.
var castle
var castle_wait := false
var volcanoes: Array = []      # вулкани на «Магмовому ядрі» (volcano.gd), на інших локаціях порожньо
var volcano_specs: Array = []  # розкладка вулканів (VolcanoScript.layout), потрібна ще до побудови терену
var acid_t := 0.0             # пауза до наступного удару кислоти
var acid_msg_t := 0.0
var fire_t := 0.0             # пауза до наступного удару вогню
var fire_msg_t := 0.0

# Місія оборони («Давній форт»): дорога від бази до застави лицарів, замок із HP, одна велика хвиля.
# Фази: "base" (на стартовій базі) -> "march" (йдемо дорогою) -> "prep" (відлік перед хвилею) -> "siege" (хвиля).
var defend := false
var defend_phase := ""
var burning := false           # палаючий замок («Вогняний ліс»): вогонь точить HP сам, зомбі б'ють сильніше
var burn_dps := 0.0
var keep                       # замок лицарів (defend_post.gd)
var prep_time := 0.0
var trickle_t := 6.0
var hud_t := 0.0
var castle_bar_bg: ColorRect
var castle_fill: ColorRect
var castle_label: Label
var info_label: Label

var ui: CanvasLayer
var hp_text: Label
var kills_label: Label
var coins_label: Label
var goal_chip: PanelContainer
var goal_label: Label
var weapons_bar: HBoxContainer
var weapons_sig := ""
var cd_widgets: Array = []      # індикатори перезарядки навиків: {kind, shade, label}
var hp_fill: Panel
var msg_label: Label
var biome_label: Label
var flash_rect: ColorRect
var minimap
var pause_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_info: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    GameState.load_game()
    loc = Locations.by_id(GameState.selected_loc)
    tier = int(loc["tier"])
    max_waves = int(loc["waves"])
    arena_r = 95.0 + 10.0 * float(tier)     # карти майже вдвічі більші за колишні (було 55 + 3*tier)
    defend = bool(loc.get("defend", false))
    burning = defend and bool(loc.get("burning", false))
    burn_dps = float(loc.get("burn_dps", 0.0))
    clear = bool(loc.get("clear", false))
    if defend:
        arena_r = 190.0          # довга дорога до застави та простір для хвилі навколо замку
    coin_mult = (1.0 + 0.04 * float(GameState.skill_level("greed"))) * Locations.income_mult(loc)

    _setup_input()
    _setup_environment()
    if RENDER_SCALE < 0.999:
        var vp := get_viewport()
        vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
        vp.scaling_3d_scale = RENDER_SCALE

    world = Node3D.new()
    world.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(world)

    terrain = TerrainScript.new()
    terrain.forced_biome = int(loc["biome"])
    terrain.secondary_biome = int(loc["second"])
    terrain.acid = (int(loc["biome"]) == Biomes.SWAMP or int(loc["second"]) == Biomes.SWAMP) and not bool(loc.get("defend", false)) and not bool(loc.get("escort", false))
    terrain.acid_mult = float(loc.get("acid_mult", 1.0))
    terrain.fire = (int(loc["biome"]) == Biomes.FIRE or int(loc["second"]) == Biomes.FIRE) and (not bool(loc.get("defend", false)) or burning) and not bool(loc.get("escort", false))
    if burning:
        terrain.fire_safe = DefendRoadScript.fire_safe_zones()
    terrain.arena_radius = arena_r
    if String(loc["id"]) == VOLCANO_LOC:
        # вулкани розкидані по всій карті; під кожним не ростуть дерева й каміння, і там немає вогняних плям
        volcano_specs = VolcanoScript.layout(arena_r, VolcanoScript.COUNT)
        for sp in volcano_specs:
            var sp_pos: Vector3 = sp["pos"]
            var vz := Vector2(sp_pos.x, sp_pos.z)
            terrain.clear_zones.append([vz, vz, float(sp["base_r"]) + 3.0])
            terrain.fire_safe.append([vz, vz, float(sp["base_r"]) + 4.0])
    if defend:
        terrain.clear_zones = DefendRoadScript.clear_zones()
    escort = bool(loc.get("escort", false))
    terrain.trail = not defend and not escort    # стежка від воріт, розвилка й пам'ятні місця
    if escort:
        escort_len = float(loc["escort_len"])
        terrain.corridor = true
        terrain.corridor_len = escort_len
        terrain.arena_radius = 1000000.0
    world.add_child(terrain)

    player = PlayerScript.new()
    castle = CastleScript.new()
    castle.player = player
    world.add_child(castle)
    castle_wait = true
    world.add_child(player)
    if String(loc["id"]) == VOLCANO_LOC:
        for sp in volcano_specs:
            var vol = VolcanoScript.new()
            vol.height = float(sp["height"])
            vol.base_r = float(sp["base_r"])
            vol.top_r = float(sp["top_r"])
            vol.collide_r = float(sp["collide_r"])
            vol.shape_seed = int(sp["seed"])
            vol.player = player
            vol.level = self
            vol.dmg_pct = FIRE_DMG_PCT * MAGMA_DMG_MULT
            vol.position = sp["pos"]
            vol.erupting.connect(_on_volcano_erupting)
            world.add_child(vol)
            volcanoes.append(vol)
    if defend:
        defend_phase = "base"
        world.add_child(DefendRoadScript.new())
        keep = DefendPostScript.new()
        keep.max_hp = float(loc["castle_hp"])
        keep.burning = burning
        keep.siege_mult = float(loc.get("castle_siege_mult", keep.siege_mult))
        keep.player = player
        keep.position = DefendRoadScript.KEEP_POS
        world.add_child(keep)
        keep.destroyed.connect(_on_keep_destroyed)
    terrain.target = player
    terrain.update(Vector3.ZERO, 999)
    if clear:
        _plan_clear()
    player.stats_changed.connect(_refresh_hud)
    player.died.connect(_on_died)
    player.hurt.connect(_on_hurt)
    _add_player_lamp()
    if escort:
        knight = KnightScript.new()
        knight.player = player
        knight.position = Vector3(-1.5, 0.0, -escort_len)
        knight.joined.connect(_on_knight_joined)
        knight.died.connect(_on_knight_died)
        knight.hp_changed.connect(_refresh_hud)
        world.add_child(knight)

    _setup_camera()
    player.camera = camera

    _build_ui()
    _refresh_hud()
    Sfx.music("battle")
    Sfx.set_battle_state(0, 0, 1.0, 0.0, false)
    if castle_wait and defend:
        if burning:
            _show_message("Стіни бази позаду. Далеко на півночі над лісом стоїть зарево: це горить застава лицарів. Поспішай дорогою!", 6.0)
        else:
            _show_message("Стіни бази позаду. Дорога на північ веде до застави лицарів, і мертві там тримаються осторонь.", 6.0)
    elif escort:
        minimap.goal = Vector3(0.0, 0.0, -escort_len)
        _show_message("Година настала. Вирушай дорогою на північ: десь там тебе чекає поранений лицар.", 6.0)
    elif castle_wait and clear:
        _show_message("Замок лишився позаду. Щойно переступиш поріг, почнеться зачистка. Стежка веде на північ, до розвилки.", 6.0)
    elif castle_wait:
        _show_message("Брама відчинена, а мертві вже чують твої кроки. Стежка веде на північ, до розвилки.", 6.0)
    else:
        _start_wave(1)

func _exit_tree() -> void:
    # повертаємо рідну роздільність для меню
    var vp := get_viewport()
    if vp != null:
        vp.scaling_3d_scale = 1.0

# ---------- Світ ----------
func _setup_environment() -> void:
    var bio: Dictionary = Biomes.DATA[int(loc["biome"])]
    var b := int(loc["biome"])
    env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.06, 0.08)
    var amb: Color = bio["ambient"]
    var fog_c: Color = bio["fog"]
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = amb
    env.ambient_light_energy = 0.62
    env.fog_enabled = true
    env.fog_light_color = fog_c
    env.fog_density = 0.011
    env.fog_aerial_perspective = 0.35
    # м'яка висотна імла біля землі: глибина без важкого об'ємного туману
    env.fog_height = 0.0
    env.fog_height_density = 0.02
    # кіно-тонмеп AgX + контраст: об'єкти краще відділяються від землі
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    env.tonemap_exposure = 1.05
    env.tonemap_white = 6.0
    env.ssao_enabled = SSAO_ENABLED
    env.ssao_radius = 1.4
    env.ssao_intensity = 2.0
    env.ssao_power = 1.6
    env.glow_enabled = GLOW_ENABLED
    env.glow_intensity = 0.8
    env.glow_bloom = 0.04
    env.glow_hdr_threshold = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.14
    env.adjustment_saturation = 1.08
    # характер біома: тепліший луг, холодний сніг, фіолетове кладовище, червоний вогонь, зелене болото
    var sun_col := Color(0.78, 0.84, 1.0)
    var sun_e := 1.0
    match b:
        Biomes.MEADOW, Biomes.FOREST:
            sun_col = Color(1.0, 0.92, 0.76)
        Biomes.DESERT:
            sun_col = Color(1.0, 0.86, 0.66)
            env.adjustment_saturation = 1.0
        Biomes.SNOW, Biomes.TUNDRA:
            sun_col = Color(0.74, 0.86, 1.0)
            sun_e = 1.1
        Biomes.GRAVEYARD:
            sun_col = Color(0.72, 0.66, 1.0)
            sun_e = 0.9
        Biomes.FIRE:
            # вогняні поля й так яскраві: менше експозиції й насиченості, щоб полум'я не вигоряло в біле
            sun_col = Color(1.0, 0.72, 0.58)
            sun_e = 0.85
            env.tonemap_exposure = 0.88
            env.adjustment_saturation = 0.92
            env.glow_intensity = 0.6
            env.glow_hdr_threshold = 1.4
        Biomes.SWAMP:
            sun_col = Color(0.74, 1.0, 0.8)
            sun_e = 0.9
        Biomes.ASH, Biomes.RUINS, Biomes.CITY:
            sun_col = Color(0.88, 0.86, 0.92)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
    sun.light_color = sun_col
    sun.light_energy = sun_e
    sun.shadow_enabled = true
    sun.shadow_blur = 1.2
    sun.shadow_bias = 0.04
    sun.shadow_normal_bias = 1.2
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    sun.directional_shadow_split_1 = 0.3
    sun.directional_shadow_fade_start = 0.85
    sun.directional_shadow_max_distance = SHADOW_DISTANCE
    add_child(sun)
    _add_vignette()

# Легке затемнення кутів екрана під інтерфейсом.
func _add_vignette() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 0
    add_child(layer)
    var rect := ColorRect.new()
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = "shader_type canvas_item;\nvoid fragment() {\n    vec2 uv = UV - 0.5;\n    float d = dot(uv, uv) * 1.6;\n    COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.18, 0.85, d) * 0.5);\n}\n"
    var m := ShaderMaterial.new()
    m.shader = sh
    rect.material = m
    layer.add_child(rect)

# Ліхтар біля гравця: тепле миготливе світло в темряві.
func _add_player_lamp() -> void:
    var lamp: OmniLight3D = FlickerLight.new()
    lamp.light_color = Color(1.0, 0.82, 0.55)
    lamp.light_energy = 2.0
    lamp.omni_range = 13.0
    lamp.speed = 7.0
    lamp.amount = 0.08
    lamp.position = Vector3(0.0, 3.2, 0.0)
    player.add_child(lamp)

func _setup_camera() -> void:
    var tilt := deg_to_rad(CAM_TILT)
    cam_offset = Vector3(0.0, CAM_DISTANCE * sin(tilt), CAM_DISTANCE * cos(tilt))
    camera = Camera3D.new()
    camera.fov = CAM_FOV
    camera.near = 0.5
    camera.far = 200.0
    add_child(camera)
    camera.rotation_degrees = Vector3(-CAM_TILT, 0.0, 0.0)
    camera.position = player.global_position + cam_offset
    camera.current = true

# ---------- Керування ----------
func _setup_input() -> void:
    var keys := {
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "move_up": [KEY_W, KEY_UP],
        "move_down": [KEY_S, KEY_DOWN],
        "attack": [KEY_SPACE],
        "pause": [KEY_ESCAPE],
        "weapon_prev": [KEY_Q],
        "weapon_next": [KEY_E],
    }
    for action in keys:
        if InputMap.has_action(action):
            continue
        InputMap.add_action(action)
        for k in keys[action]:
            var ev := InputEventKey.new()
            ev.physical_keycode = k
            InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and state == "playing" and not player.dead:
        _set_pause(not pause_panel.visible)

# ---------- Хвилі ----------
func _is_horde() -> bool:
    return bool(loc.get("horde", false))

# Власний сценарій поточної хвилі (locations.gd → wave_plan). Порожній словник — хвиля за формулою за замовчуванням.
func _plan() -> Dictionary:
    var wp = loc.get("wave_plan", null)
    if wp is Array and wave >= 1 and wave <= (wp as Array).size():
        return (wp as Array)[wave - 1]
    return {}

# Сила зомбі не росте від хвилі до хвилі: усі хвилі локації беруть параметри сили (eff, w, hp, dmg, spd) з першої хвилі.
# Кількість зомбі, пауза між появами, ліміт одночасних і елітні вставки (extras) лишаються за поточною хвилею.
func _strength() -> Dictionary:
    var wp = loc.get("wave_plan", null)
    if wp is Array and (wp as Array).size() > 0:
        return (wp as Array)[0]
    return {}

# «Ефективна хвиля» старої формули — тепер лише для кількості зомбі й темпу появи (не для сили).
func _count_eff() -> int:
    return wave + 2 * (tier - 1)

func _eff_wave() -> int:
    if defend:
        if defend_phase == "siege":
            return int(loc["horde_eff"])
        return 2                 # по дорозі трапляються лише слабкі одинаки
    if escort:
        return 9 if escort_phase == "go" else 11
    if clear:
        return int(loc["clear_eff"])
    if _is_horde():
        return int(loc["horde_eff"])
    var st := _strength()
    if not st.is_empty():
        return int(st["eff"])
    # "ефективна" хвиля: залежить лише від складності локації (як на першій хвилі), а не від номера хвилі
    return 1 + 2 * (tier - 1)

func _start_wave(n: int) -> void:
    wave = n
    to_spawn = mini(6 + 3 * _count_eff(), 60)
    var pl := _plan()
    if not pl.is_empty():
        to_spawn = int(pl["count"])
    wave_total = to_spawn
    extras_done = 0
    spawn_timer = 1.0
    boss_pending = (n == max_waves)
    horde_boss = false
    if _is_horde():
        to_spawn = int(loc["horde_count"])
        boss_pending = false
        horde_boss = true
        _show_message("ОРДА! Вона не відступить, доки не впаде її ватажок!", 4.5)
        Sfx.play("boss_roar")
    elif boss_pending and n >= 5 and not _plan().is_empty():
        _show_message("ОСТАННЯ ХВИЛЯ! Земля дрижить: на арену виходить володар цих земель!", 4.5)
        Sfx.play("boss_roar")
    elif boss_pending:
        _show_message("Остання хвиля! З темряви виходить ватажок!", 3.5)
        Sfx.play("boss_roar")
    else:
        _show_message("Хвиля %d з %d: тримайся!" % [n, max_waves], 2.0)
        Sfx.play("wave")
    _refresh_hud()

func _process(delta: float) -> void:
    _update_camera(delta)
    _update_dash_hud()
    _update_biome(delta)
    _update_low_hp(delta)

    if msg_time > 0.0:
        msg_time -= delta
        if msg_time <= 0.0:
            _hide_message()
    if get_tree().paused or state != "playing":
        return

    _clamp_player()
    _update_acid(delta)
    _update_fire(delta)
    var alive: int = get_tree().get_nodes_in_group("zombies").size()
    var audio_alive := alive
    if clear:
        audio_alive = _count_awake()      # сплячі зомбі не нагнітають музику
    _update_battle_audio(audio_alive)
    _ambient_sounds(delta)
    if defend:
        _update_defend_ui()
    if castle_wait:
        _update_castle()
        return
    if defend:
        _update_defend(delta)
        return
    if escort:
        _update_escort(delta)
        return
    if clear:
        _update_clear(delta, alive)
        return
    if boss_pending:
        boss_pending = false
        _spawn_zombie(String(loc["boss"]))
    elif to_spawn > 0:
        if horde_boss and to_spawn <= int(loc["horde_count"]) / 2:
            horde_boss = false
            _spawn_zombie(String(loc["boss"]))
            _show_message("Пісок здригнувся: із бархана виходить ватажок пустелі!", 3.0)
            Sfx.play("boss_roar")
        var pl := _plan()
        var cap := MAX_ALIVE
        if not pl.is_empty():
            cap = int(pl.get("alive", MAX_ALIVE))
            _spawn_plan_extras(pl)
        spawn_timer -= delta
        if spawn_timer <= 0.0 and alive < cap:
            _spawn_zombie("")
            to_spawn -= 1
            if not pl.is_empty():
                spawn_timer = float(pl.get("interval", 0.4))
            else:
                spawn_timer = 0.45 if _is_horde() else maxf(0.2, 1.0 - float(_count_eff()) * 0.03)
    elif alive == 0:
        if wave >= max_waves:
            _victory()
            return
        if intermission < 0.0:
            intermission = 4.0
            player.heal(int(float(player.max_hp) * 0.25))
            _show_message("Хвилю %d відбито! Переведи подих: частину сил відновлено." % wave, 3.0)
            Sfx.play("clear")
        intermission -= delta
        if intermission <= 0.0:
            intermission = -1.0
            _start_wave(wave + 1)

# Елітні зомбі посеред хвилі за планом: коли з'явилась потрібна частка хвилі, виходить наступний «extras».
func _spawn_plan_extras(pl: Dictionary) -> void:
    var ex = pl.get("extras", null)
    if not (ex is Array) or extras_done >= (ex as Array).size() or wave_total <= 0:
        return
    var e: Dictionary = (ex as Array)[extras_done]
    var spawned := wave_total - to_spawn
    if float(spawned) / float(wave_total) >= float(e["at"]):
        extras_done += 1
        var z = _spawn_zombie(String(e["kind"]))
        if z != null and e.has("mult"):
            z.max_hp *= float(e["mult"])
            z.hp = z.max_hp
        if e.has("msg"):
            _show_message(String(e["msg"]), 3.5)
        Sfx.play("boss_roar")

# ---------- Місія оборони ----------
func _start_march() -> void:
    defend_phase = "march"
    wave = 1
    to_spawn = 0
    boss_pending = false
    _show_message("Тиха дорога на північ. Мертві тут рідкість, та пильності не втрачай.", 4.0)
    _refresh_hud()

func _update_defend(delta: float) -> void:
    hud_t -= delta
    if hud_t <= 0.0:
        hud_t = 0.3
        _refresh_hud()
    match defend_phase:
        "march":
            _trickle(delta)
            var wp: Vector3 = keep.attack_point(player.global_position)
            var d := Vector2(player.global_position.x - wp.x, player.global_position.z - wp.z).length()
            if d < 24.0:
                _begin_prep()
        "prep":
            if burning:
                keep.burn(burn_dps * delta)
            prep_time -= delta
            if prep_time <= 0.0:
                _begin_siege()
        "siege":
            if burning:
                keep.burn(burn_dps * delta)
            _siege_tick(delta)

# Кілька одинаків на дорозі: не більше трьох одночасно, раз на 10-16 секунд.
func _trickle(delta: float) -> void:
    trickle_t -= delta
    if trickle_t > 0.0:
        return
    trickle_t = randf_range(10.0, 16.0)
    if get_tree().get_nodes_in_group("zombies").size() < 3:
        _spawn_zombie("")

func _begin_prep() -> void:
    defend_phase = "prep"
    prep_time = 15.0
    if burning:
        prep_time = 12.0
        _show_message("Командор Айвор: «Замок горить! Кожна секунда на рахунку, а мертві вже йдуть крізь вогонь!»", 5.0)
    else:
        _show_message("Командор Айвор: «Без тебе нам мури не втримати. Тримайся поруч!»", 5.0)
    Sfx.play("wave")

func _begin_siege() -> void:
    defend_phase = "siege"
    wave = 1
    to_spawn = int(loc["horde_count"])
    horde_boss = true
    spawn_timer = 1.0
    if burning:
        _show_message("ОРДА КРІЗЬ ВОГОНЬ! Замок горить, і вони б'ють по ньому вдвічі дужче!", 4.5)
    else:
        _show_message("ОРДА ЙДЕ НА ЗАМОК! Не дай їм розбити мури!", 4.5)
    Sfx.play("boss_roar")
    _refresh_hud()

func _siege_tick(delta: float) -> void:
    var alive: int = get_tree().get_nodes_in_group("zombies").size()
    if to_spawn > 0:
        if horde_boss and to_spawn <= int(loc["horde_count"]) / 2:
            horde_boss = false
            _spawn_siege_zombie(String(loc["boss"]))
            _show_message("Із натовпу виходить ватажок: %s!" % String(ZombieTypes.DATA[String(loc["boss"])]["name"]).replace(" (БОС)", ""), 3.5)
            Sfx.play("boss_roar")
        spawn_timer -= delta
        if spawn_timer <= 0.0 and alive < MAX_ALIVE:
            _spawn_siege_zombie("")
            to_spawn -= 1
            spawn_timer = 0.5
    elif alive == 0:
        _victory()

# Кривава складність: здоров'я зомбі на локаціях після Замку епіцентру (див. Locations.red_hp_mult). Діє на всіх зомбі, босів теж.
func _apply_red_hp(z) -> void:
    var m := Locations.red_hp_mult(loc)
    if m != 1.0:
        z.max_hp *= m
        z.hp = z.max_hp

# Ворог з'являється далеко від замку: з півночі та з боків (з боку дороги не приходить).
func _spawn_siege_zombie(forced: String) -> void:
    var kp: Vector3 = keep.global_position
    var angle := randf_range(PI * 0.95, PI * 2.05)
    var dist := randf_range(48.0, 56.0)
    var pos := Vector3(kp.x + cos(angle) * dist, 0.0, kp.z + sin(angle) * dist)
    if pos.length() > arena_r - 2.0:
        pos = pos.normalized() * (arena_r - 2.0)
    pos = _free_spot(pos)
    pos = VolcanoScript.push_out(volcanoes, pos)
    var kind := forced
    if kind == "":
        var b: int = terrain.biome_at(pos.x, pos.z)
        kind = ZombieTypes.pick(b, _eff_wave())
    var z = ZombieScript.new()
    z.position = pos
    z.setup(kind, wave, tier)
    if burning:
        z.max_hp *= float(loc.get("z_hp", 1.0))
        z.hp = z.max_hp
        z.damage = int(float(z.damage) * float(loc.get("z_dmg", 1.0)))
        z.speed *= float(loc.get("z_spd", 1.0))
    _apply_red_hp(z)
    z.target = player
    z.siege = keep
    z.killed.connect(_on_zombie_killed)
    world.add_child(z)

func _update_defend_ui() -> void:
    var hp_now := float(keep.hp)
    var hp_max := float(keep.max_hp)
    var ratio := clampf(hp_now / hp_max, 0.0, 1.0)
    castle_fill.size.x = 414.0 * ratio
    castle_fill.color = Color(0.85, 0.15, 0.1).lerp(Color(0.25, 0.7, 0.3), ratio)
    castle_label.text = "ЗАМОК  %d / %d" % [int(ceilf(hp_now)), int(hp_max)]
    match defend_phase:
        "base":
            info_label.text = "Вийдіть за ворота й ідіть дорогою на північ"
        "march":
            var wp: Vector3 = keep.attack_point(player.global_position)
            var d := Vector2(player.global_position.x - wp.x, player.global_position.z - wp.z).length()
            info_label.text = "До застави: %d м" % int(d)
        "prep":
            info_label.text = "Хвиля через %d с. Готуйтеся!" % int(ceilf(prep_time))
            if burning:
                info_label.text += "   ЗАМОК ГОРИТЬ: -%d HP/с" % int(burn_dps)
        "siege":
            var left := to_spawn + get_tree().get_nodes_in_group("zombies").size()
            info_label.text = "Ворогів лишилось: %d" % left
            if burning:
                info_label.text += "   ЗАМОК ГОРИТЬ: -%d HP/с" % int(burn_dps)

func _on_keep_destroyed() -> void:
    if state != "playing":
        return
    state = "lost"
    var kept := earned / 2
    GameState.coins += kept
    GameState.last_result = "Замок на «%s» зруйновано. Збережено монет: %d" % [String(loc["name"]), kept]
    GameState.save_game()
    Sfx.music("")
    Sfx.play("defeat")
    if burning:
        _show_message("ЗАМОК ЗГОРІВ ДОТЛА!", 3.0)
    else:
        _show_message("МУРИ ПАЛИ! Замку більше немає.", 3.0)
    await get_tree().create_timer(2.6).timeout
    if burning:
        _show_end("ЗАМОК ЗГОРІВ", "Вогонь і мерці зруйнували замок.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [kills, kept])
        return
    _show_end("ЗАМОК ПАВ", "Хвиля зламала мури.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [kills, kept])

# Замок: ворота відчиняються, коли герой підходить, і зачиняються назавжди, щойно він вийшов.
func _update_castle() -> void:
    var p: Vector3 = player.global_position
    var gate: Vector3 = castle.gate_center()
    var near := Vector2(p.x - gate.x, p.z - gate.z).length() < 7.0
    if p.z < gate.z - 3.0:
        castle_wait = false
        if escort:
            return
        castle.lock_gate()
        if defend:
            _start_march()
        elif clear:
            _show_message("ЗАЧИСТКА: обійди все село й упокой кожного. Вони сплять, але чутливо: підходь обережно.", 5.0)
        else:
            _start_wave(1)
        return
    if near:
        castle.open_gate()
    else:
        castle.close_gate()

# Музика бою реагує на те, що відбувається саме на арені: натовп, хвиля,
# вороги поряд, поранення героя й бос. Меню та його фонова атмосфера сюди не входять.
func _update_battle_audio(alive: int) -> void:
    var nearest := 30.0
    var boss_here := false
    for z in get_tree().get_nodes_in_group("zombies"):
        if not is_instance_valid(z) or bool(z.get("idle")):
            continue
        var dz: Vector3 = z.global_position - player.global_position
        dz.y = 0.0
        nearest = minf(nearest, dz.length())
        var info: Variant = z.get("data")
        if info is Dictionary and bool(info.get("boss", false)):
            boss_here = true
    var nearby := 1.0 - clampf(nearest / 12.0, 0.0, 1.0)
    var hp_ratio := float(player.hp) / maxf(1.0, float(player.max_hp))
    Sfx.set_battle_state(alive, to_spawn, hp_ratio, nearby, boss_here)

# ---------- Місія з ескортом ----------
func _update_escort(delta: float) -> void:
    # ворота: відчиняються, коли героя або лицаря близько, інакше зачинені
    var gate: Vector3 = castle.gate_center()
    var near := false
    for n in [player, knight]:
        if n != null and is_instance_valid(n):
            if Vector2(n.global_position.x - gate.x, n.global_position.z - gate.z).length() < 8.0:
                near = true
    if near:
        castle.open_gate()
    else:
        castle.close_gate()
    # лицар дійшов до замку — перемога
    if escort_phase == "back" and knight.state == "following":
        var k: Vector3 = knight.global_position
        if absf(k.x) < 11.0 and k.z > -11.0 and k.z < 11.0:
            _show_message("Лицар у безпеці! Ворота замку зачинено за вами.", 3.0)
            _victory()
            return
    # постійний спавн: на шляху до лицаря рідше, на зворотному — трохи частіше
    var alive: int = get_tree().get_nodes_in_group("zombies").size()
    var cap := ESCORT_CAP_GO if escort_phase == "go" else ESCORT_CAP_BACK
    escort_spawn -= delta
    if escort_spawn <= 0.0 and alive < cap and player.global_position.z < -22.0:
        # зомбі йдуть купками: по 2-3 за раз
        var group := mini(randi_range(2, 3), cap - alive)
        for i in range(group):
            _spawn_zombie("")
        if escort_phase == "go":
            escort_spawn = randf_range(1.0, 1.6)
        else:
            escort_spawn = randf_range(0.7, 1.2)
    elif escort_spawn <= 0.0:
        escort_spawn = 0.5

func _on_knight_joined() -> void:
    escort_phase = "back"
    minimap.goal = Vector3(0.0, 0.0, 1.0)
    escort_spawn = 4.0
    _show_message("Лицар іде з тобою! Доведи його до замку живим і не підпускай до нього мертвих.", 5.0)
    Sfx.play("wave")

func _on_knight_died() -> void:
    if state != "playing":
        return
    state = "lost"
    var kept := earned / 2
    GameState.coins += kept
    GameState.last_result = "Лицар загинув на «%s». Збережено монет: %d" % [String(loc["name"]), kept]
    GameState.save_game()
    Sfx.music("")
    Sfx.play("defeat")
    _show_end("ПОРАЗКА", "Лицар загинув дорогою до замку.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [kills, kept])

# Фонові звуки бою: стогін зомбі десь поруч і серцебиття при малому здоров'ї.
func _ambient_sounds(delta: float) -> void:
    groan_timer -= delta
    if groan_timer <= 0.0:
        groan_timer = randf_range(2.5, 5.5)
        var zs := get_tree().get_nodes_in_group("zombies")
        if zs.size() > 0:
            var z: Node3D = zs[randi() % zs.size()] as Node3D
            if z != null and not bool(z.get("idle")):
                Sfx.groan_at(z.global_position)
    if not player.dead and float(player.hp) / float(player.max_hp) < 0.35:
        heart_timer -= delta
        if heart_timer <= 0.0:
            heart_timer = 0.85
            Sfx.play("heartbeat")

func _update_camera(delta: float) -> void:
    var target_pos: Vector3 = player.global_position + cam_offset
    camera.global_position = camera.global_position.lerp(target_pos, 1.0 - exp(-8.0 * delta))
    if shake > 0.0:
        shake = maxf(0.0, shake - delta * 1.8)
        camera.global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.5

# Червона пульсація по краях екрана, коли здоров'я майже закінчилось.
func _update_low_hp(delta: float) -> void:
    time_alive += delta
    var ratio := float(player.hp) / float(player.max_hp)
    var strength := 0.0
    if ratio < 0.35 and not player.dead:
        strength = (0.35 - ratio) / 0.35 * (0.55 + 0.45 * sin(time_alive * 6.0))
    (low_hp_rect.material as ShaderMaterial).set_shader_parameter("strength", strength)

func _update_biome(delta: float) -> void:
    biome_t -= delta
    if biome_t <= 0.0:
        biome_t = 0.25
        var b: int = terrain.biome_at(player.global_position.x, player.global_position.z)
        if b != cur_biome:
            cur_biome = b
            biome_label.text = String(loc["name"]) + " — " + String(Biomes.DATA[b]["name"])
            fog_target = Biomes.DATA[b]["fog"]
            amb_target = Biomes.DATA[b]["ambient"]
    var k := 1.0 - exp(-1.5 * delta)
    if not env.fog_light_color.is_equal_approx(fog_target):
        env.fog_light_color = env.fog_light_color.lerp(fog_target, k)
    if not env.ambient_light_color.is_equal_approx(amb_target):
        env.ambient_light_color = env.ambient_light_color.lerp(amb_target, k)

# Вулкани «Магмового ядра» (loc23): багато невеликих гір по всій карті, кожна раз на 15 с обстрілює героя магмою, якщо він ближче за 40 м.
const VOLCANO_LOC := "loc23"
const MAGMA_DMG_MULT := 5.0      # урон магми = урон опіку від вогню (FIRE_DMG_PCT, 20% здоров'я) × 5
# Зомбі не з'являються всередині вулканів: точку з гори виштовхуємо за підніжжя (VolcanoScript.push_out).

func _on_volcano_erupting() -> void:
    _show_message("ВУЛКАН СТРІЛЯЄ! Тікай із червоної зони!", 2.6)

# Кислотні калюжі («Токсичне болото»): гравця роз'їдає й сповільнює, поки він стоїть у калюжі. Зомбі кислота не шкодить.
const ACID_TICK := 0.45          # пауза між ударами, с
const ACID_DMG_PCT := 0.12       # частка максимального здоров'я за удар (до броні)
func _update_acid(delta: float) -> void:
    acid_msg_t = maxf(0.0, acid_msg_t - delta)
    if not terrain.acid or player.dead or castle_wait:
        return
    var pp: Vector3 = player.global_position
    if not terrain.in_acid(pp.x, pp.z):
        acid_t = minf(acid_t, 0.0)
        return
    if acid_msg_t <= 0.0:
        acid_msg_t = 5.0
        _show_message("Кислота пече! Геть із калюжі!", 1.8)
    acid_t -= delta
    if acid_t <= 0.0:
        acid_t = ACID_TICK
        player.take_damage(maxi(12, int(float(player.max_hp) * float(loc.get("acid_dmg", ACID_DMG_PCT)))), 0.7)

# Вогняні поля («Пожежа»): палять лише гравця (сильніше за кислоту). Зомбі вогонь не шкодить.
const FIRE_TICK := 0.45          # пауза між опіками гравця, с
const FIRE_DMG_PCT := 0.20       # частка максимального здоров'я за опік (до броні)
func _update_fire(delta: float) -> void:
    fire_msg_t = maxf(0.0, fire_msg_t - delta)
    if not terrain.fire or castle_wait:
        return
    if not player.dead:
        var pp: Vector3 = player.global_position
        if terrain.in_fire(pp.x, pp.z):
            if fire_msg_t <= 0.0:
                fire_msg_t = 5.0
                _show_message("Полум'я лиже чоботи! Тікай звідси!", 1.8)
            fire_t -= delta
            if fire_t <= 0.0:
                fire_t = FIRE_TICK
                player.take_damage(maxi(20, int(float(player.max_hp) * FIRE_DMG_PCT)), 0.5)
        else:
            fire_t = minf(fire_t, 0.0)

func _clamp_player() -> void:
    var p: Vector3 = player.global_position
    var flat := Vector2(p.x, p.z)
    if escort:
        var lim: float = terrain.corridor_half_w - 1.5
        flat = Vector2(clampf(p.x, -lim, lim), clampf(p.z, -escort_len - 14.0, 26.0))
        player.global_position = Vector3(flat.x, p.y, flat.y)
        return
    if flat.length() > arena_r:
        flat = flat.normalized() * arena_r
        player.global_position = Vector3(flat.x, p.y, flat.y)

# Чи вільна точка від дерев, стін і будівель (щоб зомбі не з'являвся всередині перешкоди й не застрягав одразу).
func _spot_free(pos: Vector3) -> bool:
    var q := PhysicsShapeQueryParameters3D.new()
    var sh := SphereShape3D.new()
    sh.radius = 0.9
    q.shape = sh
    q.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 0.95, pos.z))
    q.collision_mask = 4
    return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# Якщо точка зайнята перешкодою — шукаємо вільну поруч (кільцями навколо).
func _free_spot(pos: Vector3) -> Vector3:
    if _spot_free(pos):
        return pos
    for ring in range(1, 4):
        for k in range(8):
            var a := float(k) * TAU / 8.0
            var cand := pos + Vector3(cos(a), 0.0, sin(a)) * (2.5 * float(ring))
            if cand.length() > arena_r - 2.0:
                continue
            if _spot_free(cand):
                return cand
    return pos

func _spawn_zombie(forced: String):
    var angle := randf() * TAU
    var dist := randf_range(18.0, 22.0)
    var pos: Vector3 = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
    if castle != null:
        # зомбі не з'являються всередині замку й під його мурами
        for i in range(16):
            if not CastleScript.inside_rect(pos):
                break
            angle = randf() * TAU
            pos = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
    if escort:
        var lim2: float = terrain.corridor_half_w - 2.5
        pos.x = clampf(pos.x, -lim2, lim2)
        pos.z = clampf(pos.z, -escort_len - 12.0, 24.0)
    elif pos.length() > arena_r - 2.0:
        pos = pos.normalized() * (arena_r - 2.0)
    pos = _free_spot(pos)
    pos = VolcanoScript.push_out(volcanoes, pos)
    var kind := forced
    if kind == "":
        var b: int = terrain.biome_at(pos.x, pos.z)
        kind = ZombieTypes.pick(b, _eff_wave())
    var z = ZombieScript.new()
    z.position = pos
    # велика хвиля = 3 звичайні: множники беремо як для середньої з них
    var pl := _plan()
    if not pl.is_empty():
        # сценарій хвилі: свій номер для множників сили + додаткові множники hp / шкоди / швидкості
        var st := _strength()
        z.setup(kind, int(st["w"]), tier)
        var hm := float(st.get("hp", 1.0))
        if bool(ZombieTypes.DATA[kind].get("boss", false)):
            hm = 1.0 + (hm - 1.0) * 0.4      # босам множник здоров'я хвилі додається лише частково
        z.max_hp *= hm
        z.hp = z.max_hp
        z.damage = int(float(z.damage) * float(st.get("dmg", 1.0)))
        z.speed *= float(st.get("spd", 1.0))
    else:
        z.setup(kind, 2 if _is_horde() else 1, tier)
    _apply_red_hp(z)
    z.target = player
    z.killed.connect(_on_zombie_killed)
    world.add_child(z)
    return z

# ---------- Місія зачистки ----------
# Заздалегідь вибираємо, де й які зомбі стоятимуть (одинаки й купки по 2-4), плюс ватажок у глибині карти.
func _plan_clear() -> void:
    clear_total = int(loc["clear_count"])
    var lim := minf(arena_r - 6.0, 100.0)     # на великих картах зомбі не розпорошуємо далі 100 м від замку
    var spots: Array = []
    # біля кожного пам'ятного місця на стежці — табір із кількох сплячих зомбі
    for lm in terrain.landmarks:
        var lc: Vector2 = lm
        for i in range(randi_range(3, 5)):
            if spots.size() >= clear_total - 1:
                break
            var la := randf() * TAU
            var lq := lc + Vector2(cos(la), sin(la)) * randf_range(3.0, 8.0)
            if lq.length() >= CLEAR_START_SAFE and lq.length() <= lim:
                spots.append(lq)
    var tries := 0
    while spots.size() < clear_total - 1 and tries < 6000:
        tries += 1
        var a := randf() * TAU
        var c := Vector2(cos(a), sin(a)) * sqrt(randf()) * lim
        if c.length() < CLEAR_START_SAFE:
            continue
        var group := 1 if randf() < 0.45 else randi_range(2, 4)
        for i in range(group):
            if spots.size() >= clear_total - 1:
                break
            var q := c
            if i > 0:
                q = c + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
            if q.length() < CLEAR_START_SAFE or q.length() > lim:
                continue
            var ok := true
            for s in spots:
                if (s as Vector2).distance_to(q) < 2.2:
                    ok = false
                    break
            if ok:
                spots.append(q)
    for s in spots:
        var sp: Vector2 = s
        var b: int = terrain.biome_at(sp.x, sp.y)
        clear_pending.append({"pos": sp, "kind": ZombieTypes.pick(b, _eff_wave()), "boss": false})
    # ватажок спить далеко від старту
    var ba := randf() * TAU
    var bp := Vector2(cos(ba), sin(ba)) * lim * randf_range(0.65, 0.88)
    clear_pending.append({"pos": bp, "kind": String(loc["boss"]), "boss": true})

func _count_awake() -> int:
    var n := 0
    for z in get_tree().get_nodes_in_group("zombies"):
        if not bool(z.get("idle")):
            n += 1
    return n

func _clear_left(alive: int) -> int:
    return clear_pending.size() + alive

func _update_clear(delta: float, alive: int) -> void:
    clear_t -= delta
    if clear_t <= 0.0:
        clear_t = 0.25
        var pp: Vector3 = player.global_position
        var i := clear_pending.size() - 1
        while i >= 0:
            var e: Dictionary = clear_pending[i]
            var ep: Vector2 = e["pos"]
            if Vector2(ep.x - pp.x, ep.y - pp.z).length() < CLEAR_SPAWN_R:
                _spawn_sleeper(e)
                clear_pending.remove_at(i)
            i -= 1
        minimap.hunt = _clear_left(alive) <= CLEAR_HUNT_LEFT
    if clear_pending.is_empty() and alive == 0:
        _victory()

func _spawn_sleeper(e: Dictionary) -> void:
    var ep: Vector2 = e["pos"]
    var pos := _free_spot(Vector3(ep.x, 0.0, ep.y))
    var z = ZombieScript.new()
    z.position = pos
    z.setup(String(e["kind"]), CLEAR_WAVE, tier)
    _apply_red_hp(z)
    z.target = player
    z.idle = true
    z.aggro_r = 10.0 if bool(e["boss"]) else randf_range(5.0, 10.0)
    z.killed.connect(_on_zombie_killed)
    world.add_child(z)
    if z.visual != null:
        z.visual.rotation.y = randf() * TAU

func _on_zombie_killed(reward: int, pos: Vector3, weapon: String = "") -> void:
    earned += int(float(reward) * coin_mult)
    kills += 1
    player.on_kill()
    player.register_weapon_kill(weapon)
    if randf() < 0.08:
        var o = PickupScript.new()
        o.target = player
        o.amount = 15 + 2 * tier
        o.position = Vector3(pos.x, 0.0, pos.z)
        world.add_child(o)
    _refresh_hud()

func _on_hurt() -> void:
    shake = 0.35
    flash_rect.color.a = 0.35
    var tw := create_tween()
    tw.tween_property(flash_rect, "color:a", 0.0, 0.3)

# ---------- Завершення бою ----------
func _victory() -> void:
    state = "won"
    var first := not GameState.conquered.has(String(loc["id"]))
    var bonus := Locations.repeat_reward(loc)
    if first:
        bonus = Locations.first_reward(loc)
    GameState.coins += earned + bonus
    GameState.conquered[String(loc["id"])] = true
    GameState.last_result = "Локацію «%s» відвойовано! Отримано монет: %d" % [String(loc["name"]), earned + bonus]
    GameState.save_game()
    Sfx.music("")
    Sfx.play("victory")
    var extra := ""
    if first:
        extra = "\nВідкрито нові локації на карті!"
    if defend:
        _show_end("ЗАМОК ВРЯТОВАНО!" if burning else "ЗАМОК ВИСТОЯВ!", "Хвилю відбито, а замок лицарів цілий (%d з %d).\nЗа вбивства: %d монет\nНагорода: %d монет%s" % [int(ceilf(float(keep.hp))), int(keep.max_hp), earned, bonus, extra])
        return
    if clear:
        _show_end("СЕЛО ЗАЧИЩЕНО!" if String(loc["id"]) == "loc8" else "ЛОКАЦІЮ ЗАЧИЩЕНО!", "Жоден мертвий не лишився на ногах.\nЗа вбивства: %d монет\nНагорода: %d монет%s" % [earned, bonus, extra])
        return
    _show_end("ПЕРЕМОГА!", "Локацію «%s» відвойовано.\nЗа вбивства: %d монет\nНагорода: %d монет%s" % [String(loc["name"]), earned, bonus, extra])

func _on_died() -> void:
    if state != "playing":
        return
    state = "lost"
    var kept := earned / 2
    GameState.coins += kept
    GameState.last_result = "Поразка на «%s». Збережено монет: %d" % [String(loc["name"]), kept]
    GameState.save_game()
    Sfx.music("")
    Sfx.play("defeat")
    if defend:
        _show_end("ПОРАЗКА", "Вас убито, і замок лишився без захисника.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [kills, kept])
        return
    if clear:
        _show_end("ПОРАЗКА", "Вас розбудили надто багато.\nЗалишалось зомбі: %d\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [_clear_left(get_tree().get_nodes_in_group("zombies").size()), kills, kept])
        return
    if escort:
        _show_end("ПОРАЗКА", "Вас з'їли дорогою.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [kills, kept])
        return
    _show_end("ПОРАЗКА", "Вас з'їли на хвилі %d з %d.\nВбито: %d\nЗбережено монет: %d (половина здобичі)" % [wave, max_waves, kills, kept])

func _show_end(title: String, info: String) -> void:
    if pause_panel.visible:
        pause_panel.visible = false
    end_title.text = title
    if title.begins_with("ПЕРЕМОГА"):
        end_title.add_theme_font_override("font", GameFonts.royal())
        end_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    else:
        end_title.add_theme_font_override("font", GameFonts.dark())
        end_title.add_theme_color_override("font_color", Color(0.85, 0.18, 0.15))
    end_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    end_title.add_theme_constant_override("outline_size", 8)
    end_info.text = info
    end_panel.visible = true
    get_tree().paused = true

func _set_pause(open: bool) -> void:
    Sfx.play("click")
    pause_panel.visible = open
    get_tree().paused = open

func _retry() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _to_menu() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://menu.tscn")

func _quit_to_menu() -> void:
    # вихід посеред бою: половина здобичі зберігається
    GameState.save_game()
    if state == "playing":
        var kept := earned / 2
        GameState.coins += kept
        GameState.last_result = "Бій перервано. Збережено монет: %d" % kept
        GameState.save_game()
    _to_menu()

# ---------- Інтерфейс ----------
func _build_ui() -> void:
    ui = CanvasLayer.new()
    add_child(ui)

    flash_rect = ColorRect.new()
    flash_rect.color = Color(0.8, 0.0, 0.0, 0.0)
    flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(flash_rect)

    var vignette_shader := Shader.new()
    vignette_shader.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);\nuniform float strength = 0.7;\nuniform float inner = 0.35;\nvoid fragment() {\n    vec2 uv = UV - vec2(0.5);\n    float d = length(uv * vec2(1.0, 0.8));\n    float v = smoothstep(inner, 0.85, d);\n    COLOR = vec4(tint.rgb, v * strength);\n}\n"

    var vignette := ColorRect.new()
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var vmat := ShaderMaterial.new()
    vmat.shader = vignette_shader
    vmat.set_shader_parameter("strength", 0.7)
    vignette.material = vmat
    ui.add_child(vignette)

    low_hp_rect = ColorRect.new()
    low_hp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    low_hp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var lmat := ShaderMaterial.new()
    lmat.shader = vignette_shader
    lmat.set_shader_parameter("tint", Color(0.7, 0.0, 0.0, 1.0))
    lmat.set_shader_parameter("strength", 0.0)
    lmat.set_shader_parameter("inner", 0.15)
    low_hp_rect.material = lmat
    ui.add_child(low_hp_rect)

    _build_top_hud()

    biome_label = Label.new()
    biome_label.anchor_left = 1.0
    biome_label.anchor_right = 1.0
    biome_label.offset_left = -340.0
    biome_label.offset_right = -16.0
    biome_label.offset_top = 192.0
    biome_label.offset_bottom = 220.0
    biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    biome_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    biome_label.add_theme_constant_override("outline_size", 4)
    ui.add_child(biome_label)

    minimap = MinimapScript.new()
    minimap.terrain = terrain
    minimap.player = player
    minimap.anchor_left = 1.0
    minimap.anchor_right = 1.0
    minimap.offset_left = -192.0
    minimap.offset_right = -16.0
    minimap.offset_top = 12.0
    minimap.offset_bottom = 188.0
    ui.add_child(minimap)
    if defend:
        minimap.markers = [keep]
    if clear:
        minimap.pending = clear_pending

    if not volcanoes.is_empty():
        minimap.volcanoes = volcanoes   # вулкани видно на мінікарті
    if defend:
        _build_defend_ui()

    _build_message_ui()

    _build_bottom_hud()

    pause_panel = _make_center_panel()
    var pbox := VBoxContainer.new()
    pbox.add_theme_constant_override("separation", 10)
    pause_panel.add_child(pbox)
    var ptitle := Label.new()
    ptitle.text = "Пауза"
    ptitle.add_theme_font_override("font", GameFonts.royal())
    ptitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ptitle.add_theme_font_size_override("font_size", 30)
    pbox.add_child(ptitle)
    var b_resume := Button.new()
    b_resume.text = "Продовжити"
    b_resume.custom_minimum_size = Vector2(360, 44)
    b_resume.pressed.connect(_set_pause.bind(false))
    pbox.add_child(b_resume)
    var b_quit := Button.new()
    b_quit.text = "Вийти до карти (половина здобичі)"
    b_quit.pressed.connect(_quit_to_menu)
    pbox.add_child(b_quit)

    end_panel = _make_center_panel()
    var ebox := VBoxContainer.new()
    ebox.add_theme_constant_override("separation", 12)
    end_panel.add_child(ebox)
    end_title = Label.new()
    end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_title.add_theme_font_size_override("font_size", 46)
    ebox.add_child(end_title)
    end_info = Label.new()
    end_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_info.custom_minimum_size = Vector2(460, 0)
    ebox.add_child(end_info)
    var b_retry := Button.new()
    b_retry.text = "Спробувати ще раз"
    b_retry.pressed.connect(_retry)
    ebox.add_child(b_retry)
    var b_map := Button.new()
    b_map.text = "До карти"
    b_map.pressed.connect(_to_menu)
    ebox.add_child(b_map)

# Смуга здоров'я замку вгорі по центру й підказка про поточну фазу місії.
func _build_defend_ui() -> void:
    castle_bar_bg = ColorRect.new()
    castle_bar_bg.color = Color(0, 0, 0, 0.65)
    castle_bar_bg.anchor_left = 0.5
    castle_bar_bg.anchor_right = 0.5
    castle_bar_bg.offset_left = -210.0
    castle_bar_bg.offset_right = 210.0
    castle_bar_bg.offset_top = 10.0
    castle_bar_bg.offset_bottom = 36.0
    ui.add_child(castle_bar_bg)
    castle_fill = ColorRect.new()
    castle_fill.color = Color(0.25, 0.7, 0.3)
    castle_fill.position = Vector2(3, 3)
    castle_fill.size = Vector2(414, 20)
    castle_bar_bg.add_child(castle_fill)
    var castle_frame := Panel.new()
    castle_frame.add_theme_stylebox_override("panel", _frame_box(Color(0, 0, 0, 0), Color(0.80, 0.60, 0.20), 6, 2, false))
    castle_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    castle_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    castle_bar_bg.add_child(castle_frame)
    castle_label = Label.new()
    castle_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    castle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    castle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    castle_label.add_theme_font_size_override("font_size", 16)
    castle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    castle_label.add_theme_constant_override("outline_size", 4)
    castle_bar_bg.add_child(castle_label)
    info_label = Label.new()
    info_label.anchor_right = 1.0
    info_label.offset_top = 72.0
    info_label.offset_bottom = 100.0
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_font_size_override("font_size", 20)
    info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    info_label.add_theme_constant_override("outline_size", 5)
    ui.add_child(info_label)

func _make_center_panel() -> PanelContainer:
    var p := PanelContainer.new()
    p.anchor_left = 0.5
    p.anchor_right = 0.5
    p.anchor_top = 0.5
    p.anchor_bottom = 0.5
    p.grow_horizontal = Control.GROW_DIRECTION_BOTH
    p.grow_vertical = Control.GROW_DIRECTION_BOTH
    p.visible = false
    ui.add_child(p)
    return p

# ---------- Рамки та смужки інтерфейсу бою ----------
const HUD_GOLD := Color(0.95, 0.78, 0.25)
const HUD_CREAM := Color(0.93, 0.87, 0.72)
const HUD_BORDER := Color(0.62, 0.45, 0.14)
const HP_FILL_W := 250.0

# Темна дерев'яна табличка із золотою окантовкою (у стилі меню).
func _frame_box(border: Color = HUD_BORDER, bg: Color = Color(0.085, 0.05, 0.03, 0.86), radius: int = 8, bw: int = 2, shadow: bool = true) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(bw)
    sb.set_corner_radius_all(radius)
    if shadow:
        sb.shadow_color = Color(0, 0, 0, 0.5)
        sb.shadow_size = 3
    return sb

func _hud_icon(path: String, px: float) -> TextureRect:
    var ic := TextureRect.new()
    if ResourceLoader.exists(path):
        ic.texture = load(path)
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.custom_minimum_size = Vector2(px, px)
    ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return ic

# Рамка-«чіп»: іконка, маленький підпис (необов'язково) і значення. Повертає [рамка, мітка зі значенням].
func _make_chip(parent: Node, icon_path: String, caption: String, val_col: Color) -> Array:
    var chip := PanelContainer.new()
    chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := _frame_box()
    sb.content_margin_left = 8.0
    sb.content_margin_right = 12.0
    sb.content_margin_top = 3.0
    sb.content_margin_bottom = 3.0
    chip.add_theme_stylebox_override("panel", sb)
    parent.add_child(chip)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    chip.add_child(row)
    row.add_child(_hud_icon(icon_path, 24.0))
    if caption != "":
        var cap := Label.new()
        cap.text = caption.to_upper()
        cap.add_theme_font_override("font", GameFonts.tag())
        cap.add_theme_font_size_override("font_size", 11)
        cap.add_theme_color_override("font_color", Color(0.75, 0.62, 0.38))
        cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
        cap.add_theme_constant_override("outline_size", 3)
        cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(cap)
    var val := Label.new()
    val.add_theme_font_override("font", GameFonts.royal())
    val.add_theme_font_size_override("font_size", 17)
    val.add_theme_color_override("font_color", val_col)
    val.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    val.add_theme_constant_override("outline_size", 4)
    val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(val)
    return [chip, val]

# Лівий верхній кут: смужка ХП в рамці з серцем, під нею рамки «Вбито», «Монети» і поточна ціль.
func _build_top_hud() -> void:
    var frame := Panel.new()
    frame.position = Vector2(16, 10)
    frame.size = Vector2(300, 34)
    frame.add_theme_stylebox_override("panel", _frame_box(Color(0.80, 0.58, 0.18), Color(0.085, 0.05, 0.03, 0.9), 10, 2))
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(frame)
    var heart := _hud_icon("res://icons/ui_heart.png", 26.0)
    heart.position = Vector2(6, 4)
    heart.size = Vector2(26, 26)
    frame.add_child(heart)
    var trough := Panel.new()
    trough.position = Vector2(38, 8)
    trough.size = Vector2(252, 18)
    trough.add_theme_stylebox_override("panel", _frame_box(Color(0.38, 0.12, 0.08), Color(0.17, 0.03, 0.03, 0.95), 6, 1, false))
    trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(trough)
    hp_fill = Panel.new()
    hp_fill.position = Vector2(39, 9)
    hp_fill.size = Vector2(HP_FILL_W, 16)
    var fsb := _frame_box(Color(0, 0, 0, 0), Color(0.82, 0.16, 0.14), 5, 0, false)
    hp_fill.add_theme_stylebox_override("panel", fsb)
    hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(hp_fill)
    var gloss := ColorRect.new()
    gloss.color = Color(1, 1, 1, 0.16)
    gloss.anchor_right = 1.0
    gloss.offset_left = 4.0
    gloss.offset_right = -4.0
    gloss.offset_top = 2.0
    gloss.offset_bottom = 5.0
    gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_fill.add_child(gloss)
    hp_text = Label.new()
    hp_text.position = Vector2(38, 8)
    hp_text.size = Vector2(252, 18)
    hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hp_text.add_theme_font_override("font", GameFonts.royal())
    hp_text.add_theme_font_size_override("font_size", 13)
    hp_text.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
    hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    hp_text.add_theme_constant_override("outline_size", 4)
    hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(hp_text)

    var row := HBoxContainer.new()
    row.position = Vector2(16, 50)
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(row)
    var k := _make_chip(row, "res://icons/ui_skull.png", "Вбито", Color(1.0, 0.82, 0.75))
    kills_label = k[1]
    var c := _make_chip(row, "res://icons/ui_coin.png", "Монети", HUD_GOLD)
    coins_label = c[1]
    var g := _make_chip(row, "res://icons/ui_flag.png", "", HUD_CREAM)
    goal_chip = g[0]
    goal_label = g[1]
    goal_label.add_theme_font_size_override("font_size", 15)

# Низ екрана: рамки зі зброєю (дрібніші) і тонка рамка з підказками клавіш. Навики — праворуч (див. _build_cd_huds).
func _build_bottom_hud() -> void:
    weapons_bar = HBoxContainer.new()
    weapons_bar.anchor_left = 0.5
    weapons_bar.anchor_right = 0.5
    weapons_bar.anchor_top = 1.0
    weapons_bar.anchor_bottom = 1.0
    weapons_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
    weapons_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    weapons_bar.offset_top = -42.0
    weapons_bar.offset_bottom = -42.0
    weapons_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    weapons_bar.add_theme_constant_override("separation", 6)
    weapons_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(weapons_bar)

    var hint_panel := PanelContainer.new()
    hint_panel.anchor_left = 0.5
    hint_panel.anchor_right = 0.5
    hint_panel.anchor_top = 1.0
    hint_panel.anchor_bottom = 1.0
    hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    hint_panel.offset_top = -8.0
    hint_panel.offset_bottom = -8.0
    hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hsb := _frame_box(Color(0.5, 0.36, 0.12, 0.9), Color(0.06, 0.035, 0.02, 0.78), 7, 1)
    hsb.content_margin_left = 12.0
    hsb.content_margin_right = 12.0
    hsb.content_margin_top = 2.0
    hsb.content_margin_bottom = 3.0
    hint_panel.add_theme_stylebox_override("panel", hsb)
    ui.add_child(hint_panel)
    var hint := Label.new()
    var atk_txt := "ЛКМ / Пробіл — атака"
    if player.jump_level > 0:
        atk_txt = "ЛКМ — атака"
    var hint_parts: Array = ["WASD — рух", atk_txt]
    if player.dash_level > 0:
        hint_parts.append("ПКМ — ривок")
    if player.jump_level > 0:
        hint_parts.append("Пробіл — стрибок")
    hint_parts.append("1-5, Q/E, колесо — зброя")
    hint_parts.append("Esc — пауза")
    hint.text = "  ·  ".join(hint_parts)
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62))
    hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    hint.add_theme_constant_override("outline_size", 3)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_panel.add_child(hint)
    _build_cd_huds()

func _rebuild_weapons_bar(entries: Array) -> void:
    for ch in weapons_bar.get_children():
        weapons_bar.remove_child(ch)
        ch.queue_free()
    for e in entries:
        var cur: bool = e["cur"]
        var chip := PanelContainer.new()
        chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chip.size_flags_vertical = Control.SIZE_SHRINK_END
        var sb := _frame_box(HUD_GOLD if cur else Color(0.5, 0.36, 0.12, 0.9),
            Color(0.22, 0.13, 0.05, 0.94) if cur else Color(0.07, 0.04, 0.025, 0.8), 7, 2 if cur else 1)
        sb.content_margin_left = 7.0
        sb.content_margin_right = 10.0
        sb.content_margin_top = 2.0
        sb.content_margin_bottom = 2.0
        chip.add_theme_stylebox_override("panel", sb)
        weapons_bar.add_child(chip)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 5)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        chip.add_child(row)
        var num := Label.new()
        num.text = str(e["n"])
        num.add_theme_font_override("font", GameFonts.royal())
        num.add_theme_font_size_override("font_size", 12)
        num.add_theme_color_override("font_color", HUD_GOLD if cur else Color(0.7, 0.55, 0.25))
        num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
        num.add_theme_constant_override("outline_size", 3)
        num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(num)
        row.add_child(_hud_icon("res://icons/w_%s.png" % String(e["id"]), 22.0))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", -2)
        vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(vb)
        var nm := Label.new()
        nm.text = String(e["text"])
        nm.add_theme_font_override("font", GameFonts.royal())
        nm.add_theme_font_size_override("font_size", 13)
        nm.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7) if cur else Color(0.72, 0.66, 0.54))
        nm.add_theme_color_override("font_outline_color", Color(0, 0, 0))
        nm.add_theme_constant_override("outline_size", 3)
        vb.add_child(nm)
        if String(e["sub"]) != "":
            var sub := Label.new()
            sub.text = String(e["sub"])
            sub.add_theme_font_size_override("font_size", 10)
            sub.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))
            sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
            sub.add_theme_constant_override("outline_size", 3)
            vb.add_child(sub)

# Значок клавіші, намальований прямо на іконці навика: миша з підсвіченою правою кнопкою або клавіша «Пробіл».
class KeyGlyph extends Control:
    var kind := "rmb"

    func _draw() -> void:
        var plate := StyleBoxFlat.new()
        plate.bg_color = Color(0.03, 0.02, 0.02, 0.9)
        plate.border_color = Color(0.85, 0.66, 0.22)
        plate.set_border_width_all(1)
        plate.set_corner_radius_all(5)
        draw_style_box(plate, Rect2(Vector2.ZERO, size))
        var dark := Color(0.15, 0.1, 0.08)
        var c := size * 0.5
        if kind == "rmb":
            var mw := 12.0
            var mh := 18.0
            var r := Rect2(c - Vector2(mw, mh) * 0.5, Vector2(mw, mh))
            var body := StyleBoxFlat.new()
            body.bg_color = Color(0.86, 0.83, 0.76)
            body.set_corner_radius_all(6)
            draw_style_box(body, r)
            var btn := StyleBoxFlat.new()
            btn.bg_color = Color(0.92, 0.22, 0.16)
            btn.corner_radius_top_right = 6
            draw_style_box(btn, Rect2(r.position + Vector2(mw * 0.5, 0.0), Vector2(mw * 0.5, mh * 0.42)))
            draw_line(r.position + Vector2(mw * 0.5, 0.0), r.position + Vector2(mw * 0.5, mh * 0.42), dark, 1.0)
            draw_line(r.position + Vector2(0.0, mh * 0.42), r.position + Vector2(mw, mh * 0.42), dark, 1.0)
        else:
            var cap := StyleBoxFlat.new()
            cap.bg_color = Color(0.86, 0.83, 0.76)
            cap.set_corner_radius_all(3)
            var r2 := Rect2(Vector2(4, 4), size - Vector2(8, 8))
            draw_style_box(cap, r2)
            var x0 := c.x - 8.0
            var x1 := c.x + 8.0
            var y0 := c.y - 2.0
            var y1 := c.y + 2.0
            draw_polyline(PackedVector2Array([Vector2(x0, y0), Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y0)]), dark, 1.6)

# Індикатори перезарядки навиків (правий бік екрана, стовпчиком під мінікартою): ривок і стрибок, якщо прокачані.
func _build_cd_huds() -> void:
    var y := 236.0
    if player.dash_level > 0:
        _make_cd_widget("dash", "res://icons/s_dash.png", "rmb", y)
        y += 78.0
    if player.jump_level > 0:
        _make_cd_widget("jump", "res://icons/s_jump.png", "space", y)

func _make_cd_widget(kind: String, icon_path: String, key_kind: String, y: float) -> void:
    var box := Control.new()
    box.anchor_left = 1.0
    box.anchor_right = 1.0
    box.offset_left = -80.0
    box.offset_right = -16.0
    box.offset_top = y
    box.offset_bottom = y + 64.0
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(box)
    var bg := Panel.new()
    bg.size = Vector2(64, 64)
    bg.add_theme_stylebox_override("panel", _frame_box(Color(0, 0, 0, 0), Color(0.06, 0.04, 0.03, 0.9), 9, 0))
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(bg)
    var ic := _hud_icon(icon_path, 54.0)
    ic.position = Vector2(5, 5)
    ic.size = Vector2(54, 54)
    box.add_child(ic)
    var shade := Panel.new()
    shade.position = Vector2(5, 5)
    shade.size = Vector2(54, 0)
    shade.add_theme_stylebox_override("panel", _frame_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0.68), 6, 0, false))
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(shade)
    var frame := Panel.new()
    frame.size = Vector2(64, 64)
    var fsb := _frame_box(HUD_GOLD, Color(0, 0, 0, 0), 9, 2, false)
    frame.add_theme_stylebox_override("panel", fsb)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(frame)
    var lb := Label.new()
    lb.size = Vector2(64, 64)
    lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lb.add_theme_font_override("font", GameFonts.royal())
    lb.add_theme_font_size_override("font_size", 22)
    lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    lb.add_theme_constant_override("outline_size", 5)
    lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(lb)
    var key := KeyGlyph.new()
    key.kind = key_kind
    if key_kind == "rmb":
        key.size = Vector2(22, 28)
        key.position = Vector2(39, 33)
    else:
        key.size = Vector2(38, 22)
        key.position = Vector2(23, 39)
    key.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(key)
    cd_widgets.append({"kind": kind, "shade": shade, "label": lb, "sb": fsb})

func _update_dash_hud() -> void:
    if cd_widgets.is_empty() or player == null:
        return
    for w in cd_widgets:
        var cd: float = player.dash_cd if String(w["kind"]) == "dash" else player.jump_cd
        var cd_max: float = player.dash_cd_max if String(w["kind"]) == "dash" else Skills.JUMP_CD
        var shade: Panel = w["shade"]
        var lb: Label = w["label"]
        var sb: StyleBoxFlat = w["sb"]
        shade.size.y = 54.0 * clampf(cd / maxf(cd_max, 0.01), 0.0, 1.0)
        lb.text = ("%.1f" % cd) if cd > 0.0 else ""
        sb.border_color = HUD_BORDER.darkened(0.25) if cd > 0.0 else HUD_GOLD

func _refresh_hud() -> void:
    var goal := ""
    if defend:
        goal = ""
    elif clear:
        var left := clear_pending.size() + get_tree().get_nodes_in_group("zombies").size()
        goal = "Зачистка: лишилось %d з %d" % [left, clear_total]
    elif escort:
        goal = "Знайти лицаря" if escort_phase == "go" else "Довести лицаря до замку"
        if knight != null and knight.state != "waiting":
            goal += "  ·  Лицар: %d/%d" % [knight.hp, knight.max_hp]
    else:
        goal = "Хвиля %d/%d" % [wave, max_waves]
    hp_text.text = "%d / %d" % [player.hp, player.max_hp]
    kills_label.text = str(kills)
    coins_label.text = str(earned)
    goal_chip.visible = goal != ""
    goal_label.text = goal
    hp_fill.size.x = HP_FILL_W * clampf(float(player.hp) / maxf(float(player.max_hp), 1.0), 0.0, 1.0)
    var entries: Array = []
    var n := 0
    for id in player.loadout:
        n += 1
        var w: Dictionary = Weapons.DATA[id]
        var sid := String(id)
        var cur: bool = sid == player.current
        var sub := ""
        if cur:
            var wk := int(GameState.weapon_kills.get(sid, 0))
            var nxt := Weapons.mastery_next_kills(wk, sid)
            if nxt < 0:
                sub = "майстр. %d · МАКС" % GameState.weapon_mastery(sid)
            else:
                sub = "майстр. %d · %d/%d" % [GameState.weapon_mastery(sid), wk, nxt]
        entries.append({"id": sid, "n": n, "text": "%s  ур.%d" % [String(w["name"]), player.weapon_level(sid)], "sub": sub, "cur": cur})
    var sig := str(entries)
    if sig != weapons_sig:
        weapons_sig = sig
        _rebuild_weapons_bar(entries)

# ---------- Повідомлення в бою ----------
# Невелика стрічка під верхом екрана: маленький кольоровий підпис (ХВИЛЯ / ВАТАЖОК / ОРДА / НЕБЕЗПЕКА / ВІСТІ / ЗАВДАННЯ),
# під ним елегантний курсив (GameFonts.message). Текст «проявляється» літера за літерою, стрічка плавно з'являється й гасне.
# Вид (підпис, колір) підбирається за змістом тексту, тож усі виклики _show_message(текст, секунди) лишились як були.
const MSG_KINDS := {
    "wave": {"tag": "ХВИЛЯ", "col": Color(1.0, 0.8, 0.35)},
    "horde": {"tag": "ОРДА", "col": Color(1.0, 0.5, 0.2)},
    "boss": {"tag": "ВАТАЖОК", "col": Color(0.95, 0.3, 0.3)},
    "danger": {"tag": "НЕБЕЗПЕКА", "col": Color(1.0, 0.42, 0.15)},
    "ally": {"tag": "ВІСТІ", "col": Color(0.55, 0.8, 1.0)},
    "quest": {"tag": "ЗАВДАННЯ", "col": Color(0.6, 0.9, 0.55)},
    "info": {"tag": "", "col": Color(0.85, 0.78, 0.65)},
}
var msg_panel: PanelContainer
var msg_cap_row: HBoxContainer
var msg_cap: Label
var msg_rules: Array = []
var msg_sb: StyleBoxFlat
var msg_tw: Tween

func _build_message_ui() -> void:
    msg_panel = PanelContainer.new()
    msg_panel.anchor_left = 0.5
    msg_panel.anchor_right = 0.5
    msg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    msg_panel.offset_top = 92.0
    msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    msg_sb = StyleBoxFlat.new()
    msg_sb.bg_color = Color(0.04, 0.025, 0.03, 0.7)
    msg_sb.border_width_top = 1
    msg_sb.border_width_bottom = 2
    msg_sb.set_corner_radius_all(2)
    msg_sb.shadow_size = 10
    msg_sb.content_margin_left = 22.0
    msg_sb.content_margin_right = 22.0
    msg_sb.content_margin_top = 6.0
    msg_sb.content_margin_bottom = 8.0
    msg_panel.add_theme_stylebox_override("panel", msg_sb)
    msg_panel.visible = false
    ui.add_child(msg_panel)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 0)
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    msg_panel.add_child(vb)
    msg_cap_row = HBoxContainer.new()
    msg_cap_row.alignment = BoxContainer.ALIGNMENT_CENTER
    msg_cap_row.add_theme_constant_override("separation", 10)
    msg_cap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(msg_cap_row)
    msg_rules = []
    for side in range(2):
        var rule := ColorRect.new()
        rule.custom_minimum_size = Vector2(28.0, 1.0)
        rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
        msg_rules.append(rule)
        if side == 0:
            msg_cap_row.add_child(rule)
            msg_cap = Label.new()
            msg_cap.add_theme_font_override("font", GameFonts.tag())
            msg_cap.add_theme_font_size_override("font_size", 13)
            msg_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
            msg_cap_row.add_child(msg_cap)
        else:
            msg_cap_row.add_child(rule)
    msg_label = Label.new()
    msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    msg_label.add_theme_font_override("font", GameFonts.message())
    msg_label.add_theme_font_size_override("font_size", 19)
    msg_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.8))
    msg_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0))
    msg_label.add_theme_constant_override("outline_size", 4)
    msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(msg_label)

func _msg_kind(text: String) -> String:
    var l := text.to_lower()
    for k in ["кислот", "полум'я лиже", "вулкан", "згорів", "мури пали"]:
        if l.find(k) >= 0:
            return "danger"
    if l.begins_with("командор"):
        return "ally"
    if l.begins_with("орда") or l.begins_with("фінал"):
        return "horde"
    if l.begins_with("остання хвиля") or l.find("ватажок") >= 0 or l.find("володар") >= 0:
        return "boss"
    if l.begins_with("хвил"):
        return "wave"
    for k in ["зачистка", "лицар", "брама", "замок лишився", "стіни бази", "година настала"]:
        if l.find(k) >= 0:
            return "quest"
    return "info"

# [підпис, основний текст]: «ВУЛКАН ВИВЕРГАЄТЬСЯ! Тікай...» -> підпис = перша велика фраза; «Хвиля 2 з 5: тримайся!» -> підпис «ХВИЛЯ 2 З 5».
func _msg_split(text: String, kind: String) -> Array:
    var cap := String((MSG_KINDS[kind] as Dictionary)["tag"])
    var body := text
    var i := text.find("! ")
    var j := text.find(": ")
    if i > 0 and text.substr(0, i) == text.substr(0, i).to_upper():
        cap = text.substr(0, i).to_upper()
        body = text.substr(i + 2).strip_edges()
    elif j > 0 and (text.begins_with("ФІНАЛ") or kind == "wave" or kind == "ally"):
        cap = text.substr(0, j).to_upper()
        body = text.substr(j + 2).strip_edges()
        body = body.substr(0, 1).to_upper() + body.substr(1)
    elif text.ends_with("!") and text == text.to_upper():
        body = text.substr(0, 1) + text.substr(1).to_lower()
    return [cap, body]

func _show_message(text: String, seconds: float) -> void:
    var kind := _msg_kind(text)
    var parts := _msg_split(text, kind)
    var col: Color = (MSG_KINDS[kind] as Dictionary)["col"]
    msg_cap.text = String(parts[0])
    msg_cap_row.visible = String(parts[0]) != ""
    msg_cap.add_theme_color_override("font_color", col)
    for r in msg_rules:
        (r as ColorRect).color = Color(col.r, col.g, col.b, 0.6)
    msg_sb.border_color = Color(col.r, col.g, col.b, 0.75)
    msg_sb.shadow_color = Color(col.r, col.g, col.b, 0.22)
    msg_label.text = String(parts[1])
    msg_label.custom_minimum_size.x = clampf(float(String(parts[1]).length()) * 10.0, 150.0, 440.0)
    msg_label.visible_ratio = 0.0
    msg_panel.visible = true
    msg_panel.reset_size()
    msg_panel.modulate = Color(1, 1, 1, 0)
    msg_panel.offset_top = 80.0
    if msg_tw != null and msg_tw.is_valid():
        msg_tw.kill()
    msg_tw = create_tween()
    msg_tw.set_parallel(true)
    msg_tw.tween_property(msg_panel, "modulate:a", 1.0, 0.25)
    msg_tw.tween_property(msg_panel, "offset_top", 92.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    msg_tw.tween_property(msg_label, "visible_ratio", 1.0, clampf(float(String(parts[1]).length()) * 0.022, 0.3, 1.0))
    msg_time = seconds

func _hide_message() -> void:
    if msg_panel == null or not msg_panel.visible:
        return
    if msg_tw != null and msg_tw.is_valid():
        msg_tw.kill()
    msg_tw = create_tween()
    msg_tw.tween_property(msg_panel, "modulate:a", 0.0, 0.4)
    msg_tw.tween_callback(func(): msg_panel.visible = false)
