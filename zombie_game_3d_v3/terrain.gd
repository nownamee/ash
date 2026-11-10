extends Node3D
# Великий світ: нескінченна карта з біомами, що генерується шматками (чанками) навколо гравця.
# Кожен чанк: земля з кольором біому + дерева, камені, руїни, будівлі, цвинтарі тощо.
# Дрібні об'єкти малюються через MultiMesh (швидко), колізії — одним StaticBody на чанк.

const Biomes = preload("res://biomes.gd")
const Util = preload("res://util.gd")
const FlickerLight = preload("res://light_flicker.gd")
const FireField = preload("res://fire_field.gd")
const AcidPool = preload("res://acid_pool.gd")
const CampaignProps = preload("res://campaign_props.gd")

const CHUNK := 32.0
const CELLS := 8
const VIEW_R := 2
const START_R := 45.0       # навколо старту завжди луки
const ATTEMPTS := 130       # спроб розмістити об'єкт на чанк (частина відсіюється правилом проходів, тож спроб більше)
# Мінімальний вільний прохід між двома твердими об'єктами (дерево, камінь, стіна, машина).
# Зомбі має колізійний радіус до 0.8 м, тож проліз завширшки 2.4 м вільний і для найбільших.
const PASS_GAP := 2.4

const BORDER_ATTEMPTS := 140
# Об'єкти меж арени (по біомах)
const BORDER_PROPS := [
    [["tree_oak", 4.0], ["rock", 1.0]],
    [["tree_pine", 4.0], ["tree_oak", 3.0]],
    [["rock", 3.0], ["obelisk", 1.0], ["cactus", 2.0]],
    [["tree_pine_snow", 4.0], ["rock_ice", 3.0]],
    [["dead_tree", 4.0], ["crypt", 0.3], ["tombstone", 1.0]],
    [["ruin_wall", 3.0], ["pillar", 1.0], ["rock", 2.0]],
    [["ruined_building", 2.0], ["car", 2.0], ["barricade", 2.0], ["rubble", 1.0]],
    [["dead_tree", 3.0], ["rock", 2.0], ["ruin_wall", 1.0]],
    [["dead_tree", 3.0], ["tree_oak", 3.0], ["rock", 1.0]],
    [["tree_pine_snow", 3.0], ["rock_ice", 3.0], ["dead_tree", 1.5]],
    [["burning_tree", 2.0], ["dead_tree", 3.0], ["rock", 2.0], ["burnt_beams", 1.0]],
    [["tide_stone", 3.0], ["wreck_boat", 1.0], ["tide_piling", 2.0], ["tide_driftwood", 2.0]],
    [["abbey_stone", 3.0], ["abbey_arch", 1.0], ["bell_frame", 1.0], ["torn_banner", 1.2]],
    [["obsidian", 3.0], ["glass_spire", 2.0], ["glass_shards", 2.0], ["glass_pillar", 1.0]],
    [["iron_workshop", 1.0], ["iron_gear", 2.0], ["anvil", 1.0], ["oil_barrel", 2.0]],
]

# Частка заповнення по біомах (луки, ліс, пустеля, сніги, цвинтар, руїни, місто)
const DENSITY := [0.55, 1.0, 0.5, 0.6, 0.75, 0.65, 0.7, 0.7, 0.9, 0.65, 0.78, 0.78, 0.72, 0.72, 0.75]

# Об'єкти біому: [назва, вага]
const PROPS := [
    [["tree_oak", 2.0], ["bush", 3.0], ["flowers", 4.0], ["tuft", 8.0], ["rock", 1.0], ["haystack", 0.35], ["fence", 0.35], ["stump", 0.5], ["hut", 0.12], ["blood", 0.5], ["corpse", 0.18]],
    [["tree_oak", 5.0], ["tree_pine", 4.0], ["bush", 3.0], ["tuft", 5.0], ["log", 1.2], ["stump", 1.2], ["mushroom", 1.5], ["rock", 1.0], ["blood", 0.6], ["corpse", 0.25]],
    [["cactus", 3.0], ["rock", 2.0], ["bones", 1.5], ["dead_tree", 0.7], ["dune", 2.5], ["obelisk", 0.4], ["dry_tuft", 4.0], ["blood", 0.4], ["corpse", 0.2]],
    [["tree_pine_snow", 4.0], ["rock_ice", 1.5], ["snow_mound", 3.0], ["dead_tree", 0.7], ["ice_crystal", 1.2], ["blood", 0.6], ["corpse", 0.25]],
    [["tombstone", 6.0], ["cross", 2.0], ["dead_tree", 2.5], ["crypt", 0.2], ["iron_fence", 0.8], ["bones", 1.0], ["blood", 0.8], ["corpse", 0.4]],
    [["ruin_wall", 3.0], ["pillar", 2.5], ["rubble", 3.0], ["broken_house", 0.45], ["arch", 0.5], ["rock", 1.0], ["blood", 0.7], ["corpse", 0.35]],
    [["car", 1.4], ["rubble", 2.0], ["blood", 2.5], ["crack", 3.0], ["road_mark", 2.0], ["streetlamp", 0.9], ["dumpster", 0.7], ["barricade", 0.6], ["ruined_building", 0.5], ["fire_barrel", 0.25], ["corpse", 1.0], ["manhole", 0.6], ["sign", 0.5]],
    # Попелясті пустища
    [["rock", 3.0], ["dead_tree", 1.8], ["rubble", 2.5], ["crack", 3.5], ["bones", 1.5], ["ruin_wall", 0.9], ["pillar", 0.5], ["broken_house", 0.2], ["fire_barrel", 0.25], ["dry_tuft", 1.5], ["blood", 0.8], ["corpse", 0.45]],
    # Токсичне болото
    [["dead_tree", 3.0], ["tree_oak", 2.0], ["bush", 3.0], ["mushroom", 3.5], ["log", 1.5], ["stump", 1.5], ["tuft", 4.0], ["rock", 0.8], ["bones", 0.8], ["blood", 0.6], ["corpse", 0.35]],
    # Мертва тундра
    [["tree_pine_snow", 2.5], ["dead_tree", 1.8], ["rock_ice", 2.0], ["snow_mound", 3.0], ["ice_crystal", 1.8], ["bones", 0.9], ["blood", 0.6], ["corpse", 0.35]],
    # Пожежа: вогнища, горять дерева, тліють жарини, обгорілі балки й колоди
    [["flames", 5.0], ["embers", 4.0], ["burning_tree", 1.2], ["dead_tree", 2.0], ["charred_log", 1.5], ["burnt_beams", 1.2], ["rubble", 2.5], ["crack", 2.5], ["rock", 1.5], ["bones", 1.0], ["broken_house", 0.25], ["fire_barrel", 0.2], ["blood", 0.6], ["corpse", 0.6]],
    [["tide_stone", 2.4], ["wreck_boat", 0.65], ["tide_chain", 0.8], ["tide_algae", 2.8], ["tide_piling", 1.1], ["tide_driftwood", 1.4], ["tide_buoy", 0.55]],
    [["abbey_stone", 2.0], ["bell_frame", 0.55], ["bell_shrine", 0.18], ["wax_candle", 1.3], ["torn_banner", 0.8], ["abbey_arch", 0.5]],
    [["obsidian", 2.2], ["glass_spire", 1.2], ["glass_shards", 3.0], ["glass_arch", 0.18], ["glass_pillar", 0.6], ["glass_crack", 1.8]],
    [["iron_workshop", 0.2], ["iron_gear", 1.4], ["iron_chain", 1.1], ["oil_barrel", 0.8], ["forge_hearth", 0.5], ["anvil", 0.7], ["iron_crate", 1.2]],
]

# ---------- Логіка розстановки ----------
# 1) Від воріт замку веде стежка до розвилки, звідти — три стежки до пам'ятних місць (хата, табір, обеліск…).
# 2) Поруч із замком майже порожньо; щільність об'єктів росте з відстанню (OPEN_FROM..OPEN_TO).
# 3) Високі об'єкти (дерева, надгробки, колони) тримаються гаями й ділянками, між ними — галявини.
# 4) Біля головного об'єкта ставляться «супутники» (хата — стіг і паркан, склеп — решітка й могили),
#    надгробки й колони стоять рядами.
# 5) Місто має сітку вулиць: машини в смугах, ліхтарі на бордюрі, будинки в кварталах.
const OPEN_FROM := 20.0       # до цієї відстані від замку щільність мінімальна
const OPEN_TO := 90.0         # з цієї відстані — повна
const OPEN_MIN := 0.2
const TRAIL_HALF := 1.5       # половина ширини стежки
const TRAIL_Y := 0.035
const TALL := ["tree_oak", "tree_pine", "tree_pine_snow", "dead_tree", "pillar", "ruin_wall", "broken_house", "tombstone", "cross", "crypt", "cactus", "arch", "iron_fence", "burning_tree", "wreck_boat", "tide_piling", "bell_frame", "bell_shrine", "torn_banner", "abbey_arch", "glass_spire", "glass_arch", "glass_pillar", "iron_workshop"]
# колір втоптаної стежки по біомах (луки, ліс, пустеля, сніги, цвинтар, руїни, місто)
const TRAIL_COL := [Color(0.30, 0.23, 0.13), Color(0.17, 0.12, 0.07), Color(0.74, 0.62, 0.40), Color(0.62, 0.66, 0.72), Color(0.30, 0.27, 0.27), Color(0.42, 0.38, 0.33), Color(0.08, 0.08, 0.09), Color(0.22, 0.18, 0.16), Color(0.14, 0.13, 0.07), Color(0.52, 0.57, 0.66), Color(0.16, 0.10, 0.07), Color(0.07, 0.11, 0.12), Color(0.25, 0.25, 0.24), Color(0.08, 0.055, 0.11), Color(0.19, 0.12, 0.085)]
# що стоїть уздовж стежки
const TRAIL_PROPS := [
    [["flowers", 3.0], ["rock", 1.5], ["stump", 1.0], ["fence", 1.0], ["bush", 1.5]],
    [["mushroom", 2.0], ["log", 1.2], ["stump", 1.2], ["bush", 2.0], ["rock", 1.0]],
    [["bones", 2.0], ["rock", 2.0], ["dry_tuft", 2.0], ["cactus", 1.0]],
    [["snow_mound", 2.0], ["rock_ice", 2.0], ["ice_crystal", 1.0]],
    [["cross", 2.0], ["tombstone", 1.5], ["iron_fence", 1.0], ["bones", 0.8]],
    [["rubble", 2.5], ["pillar", 1.0], ["ruin_wall", 1.0], ["rock", 1.0]],
    [["streetlamp", 1.0], ["barricade", 0.8], ["dumpster", 0.5], ["fire_barrel", 0.5], ["sign", 0.5]],
    [["rubble", 2.0], ["rock", 1.5], ["bones", 1.0], ["fire_barrel", 0.5], ["dead_tree", 0.8]],
    [["mushroom", 2.5], ["log", 1.5], ["stump", 1.2], ["bush", 1.5], ["bones", 0.6]],
    [["snow_mound", 2.0], ["rock_ice", 1.8], ["ice_crystal", 1.4], ["bones", 0.8]],
    [["flames", 1.5], ["embers", 2.0], ["charred_log", 1.5], ["rubble", 1.5], ["burnt_beams", 1.0]],
    [["tide_algae", 2.0], ["tide_stone", 1.5], ["tide_driftwood", 1.2], ["tide_buoy", 0.5]],
    [["abbey_stone", 2.0], ["wax_candle", 1.0], ["torn_banner", 0.8], ["abbey_arch", 0.5]],
    [["glass_shards", 2.2], ["obsidian", 1.5], ["glass_crack", 1.0], ["glass_spire", 0.6]],
    [["iron_chain", 1.0], ["iron_gear", 1.0], ["iron_crate", 0.8], ["oil_barrel", 0.6]],
]
# розвилка: покажчик і два сигнальні вогні
const HUB_SET := [["sign", 3.4, 0.6], ["fire_barrel", -4.0, -2.4], ["fire_barrel", 4.6, -4.2], ["rock", -6.5, 4.0], ["stump", 6.0, 5.0]]
# пам'ятні місця в кінці стежок: [вид, зсув x, зсув z] по біомах
const LANDMARKS := [
    [["hut", 0, 0], ["haystack", 5.5, 2.0], ["haystack", 6.8, -1.2], ["fence", -5.0, 3.5], ["fence", -5.0, -0.8], ["flowers", 3.0, 6.0], ["blood", 2.5, 3.6], ["corpse", -2.5, 5.0], ["stump", -6.5, -4.0]],
    [["fire_barrel", 0, 0], ["log", 2.8, 1.4], ["log", -2.6, 1.8], ["log", 0.4, -3.0], ["stump", 4.6, -2.6], ["mushroom", -4.2, -3.2], ["bush", 5.2, 4.2], ["corpse", -3.6, 4.8], ["blood", 1.5, 3.6]],
    [["obelisk", 0, 0], ["bones", 3.4, 2.2], ["bones", -3.2, 2.8], ["bones", 2.2, -3.6], ["bones", -4.2, -2.2], ["rock", 6.2, 0.4], ["rock", -6.4, 3.0], ["cactus", 5.2, -5.2], ["cactus", -6.0, -5.4]],
    [["ice_crystal", 0, 0], ["ice_crystal", 2.6, 1.6], ["ice_crystal", -2.4, 1.9], ["ice_crystal", 0.6, -2.8], ["rock_ice", 5.4, 0.2], ["rock_ice", -5.4, 1.2], ["rock_ice", 1.0, 5.8], ["snow_mound", -3.2, -4.2], ["snow_mound", 4.2, -4.4], ["corpse", 3.2, 4.2]],
    [["crypt", 0, 0], ["iron_fence", -5.6, 3.2], ["iron_fence", 5.6, 3.2], ["iron_fence", -5.6, -3.4], ["iron_fence", 5.6, -3.4], ["tombstone", -8.4, -3.0], ["tombstone", -8.4, 0.6], ["tombstone", 8.4, -3.0], ["tombstone", 8.4, 0.6], ["cross", 0.0, 7.4], ["cross", 3.6, 7.4], ["bones", 4.6, -5.0]],
    [["arch", 0, 0], ["pillar", -5.4, -5.0], ["pillar", 5.4, -5.0], ["pillar", -5.4, 5.0], ["pillar", 5.4, 5.0], ["rubble", 0.0, -4.4], ["rubble", 3.2, 3.2], ["rubble", -3.4, 3.8], ["broken_house", 11.0, 0.0], ["blood", 1.2, 4.6]],
    [["barricade", 0, -3.6], ["barricade", -4.6, 0.6], ["barricade", 4.6, 0.6], ["fire_barrel", -1.6, 1.2], ["fire_barrel", 1.8, 1.6], ["car", 7.0, 5.5], ["dumpster", -6.8, 4.4], ["sign", 0.0, 5.4], ["corpse", -2.2, -1.6], ["blood", 0.0, -1.2]],
    [["broken_house", 0, 0], ["rubble", 6.0, 2.0], ["rubble", -6.2, 2.8], ["fire_barrel", -3.4, 5.2], ["fire_barrel", 3.6, 5.6], ["bones", 5.0, -5.0], ["dead_tree", -7.0, -4.0], ["blood", 1.5, 6.0], ["corpse", -2.4, 7.2]],
    [["hut", 0, 0], ["log", 5.0, 2.4], ["log", -5.2, 2.0], ["mushroom", 3.0, -4.2], ["mushroom", -3.4, -4.6], ["bush", 6.0, -3.0], ["dead_tree", -7.0, 4.0], ["bones", 3.6, 5.0], ["corpse", -2.4, 6.0], ["blood", 1.0, 3.8]],
    [["ice_crystal", 0, 0], ["ice_crystal", 3.0, 1.4], ["ice_crystal", -2.8, 1.8], ["rock_ice", 5.8, -0.4], ["rock_ice", -5.6, 1.4], ["dead_tree", 1.0, 6.0], ["snow_mound", -3.4, -4.4], ["snow_mound", 4.2, -4.6], ["bones", 3.0, 4.4], ["corpse", -3.0, 5.0]],
    [["broken_house", 0, 0], ["flames", 5.5, 3.0], ["flames", -5.8, 2.6], ["burning_tree", -6.5, -4.5], ["burning_tree", 7.0, -4.0], ["embers", 0.0, 6.0], ["charred_log", 3.0, -5.5], ["rubble", -3.5, 5.0], ["corpse", 2.0, 5.0], ["blood", -1.0, -5.0]],
    [["wreck_boat", 0, 0], ["tide_piling", 6.0, 1.5], ["tide_piling", -6.0, 1.5], ["tide_chain", 0.0, -5.0], ["tide_algae", 4.0, -4.0], ["tide_stone", -4.5, -4.5], ["tide_buoy", 5.0, 6.0]],
    [["bell_shrine", 0, 0], ["torn_banner", -6.0, 1.5], ["torn_banner", 6.0, 1.5], ["abbey_stone", -5.0, -5.0], ["abbey_stone", 5.0, -5.0], ["wax_candle", -3.8, 5.2], ["wax_candle", 3.8, 5.2], ["abbey_arch", 0.0, 7.0]],
    [["glass_arch", 0, 0], ["glass_spire", -5.0, 3.0], ["glass_spire", 5.0, 3.0], ["glass_pillar", -6.0, -4.0], ["glass_pillar", 6.0, -4.0], ["glass_shards", 0.0, 6.0], ["glass_crack", 3.5, -5.0]],
    [["iron_workshop", 0, 0], ["iron_gear", -6.0, 4.0], ["iron_gear", 6.0, 4.0], ["forge_hearth", -5.0, -5.0], ["anvil", 5.5, -4.5], ["oil_barrel", -6.0, -1.0], ["iron_crate", 5.5, 0.5], ["iron_chain", 0.0, 6.5]],
]
# «супутники» головного об'єкта: [вид, шанс, відстань від, відстань до]
const CLUSTER := {
    "tree_oak": [["bush", 0.6, 2.5, 4.5], ["stump", 0.25, 3.0, 5.0], ["flowers", 0.5, 2.0, 4.5]],
    "tree_pine": [["mushroom", 0.35, 2.5, 4.5], ["stump", 0.2, 3.0, 5.0], ["bush", 0.3, 2.5, 4.5]],
    "tree_pine_snow": [["snow_mound", 0.6, 2.5, 4.5], ["rock_ice", 0.2, 3.0, 5.0]],
    "dead_tree": [["bones", 0.25, 2.0, 4.0], ["rock", 0.2, 2.5, 4.5]],
    "rock": [["rock", 0.35, 2.6, 4.0], ["tuft", 0.5, 2.0, 4.0]],
    "hut": [["haystack", 0.8, 4.0, 6.0], ["fence", 0.9, 3.8, 6.0], ["fence", 0.6, 3.8, 6.0], ["flowers", 0.6, 3.0, 6.0], ["stump", 0.4, 4.0, 6.0]],
    "obelisk": [["bones", 0.9, 3.0, 5.0], ["bones", 0.6, 3.0, 5.0], ["rock", 0.5, 3.5, 6.0]],
    "cactus": [["cactus", 0.6, 3.0, 4.5], ["bones", 0.25, 3.0, 5.0]],
    "ice_crystal": [["ice_crystal", 0.6, 2.8, 4.0], ["rock_ice", 0.4, 3.0, 5.0]],
    "crypt": [["iron_fence", 0.9, 4.5, 6.0], ["iron_fence", 0.7, 4.5, 6.0], ["tombstone", 0.8, 5.5, 8.0], ["cross", 0.6, 5.5, 8.0], ["dead_tree", 0.5, 5.5, 8.0]],
    "broken_house": [["rubble", 0.9, 4.8, 7.0], ["rubble", 0.6, 4.8, 7.0], ["ruin_wall", 0.5, 5.5, 8.0], ["blood", 0.5, 3.0, 6.0]],
    "arch": [["pillar", 0.7, 4.0, 6.0], ["rubble", 0.8, 3.0, 5.0]],
    "ruined_building": [["rubble", 0.9, 6.5, 9.0], ["rubble", 0.7, 6.5, 9.0], ["dumpster", 0.4, 6.5, 9.0], ["corpse", 0.4, 5.5, 8.0]],
    "barricade": [["fire_barrel", 0.35, 3.0, 4.5], ["corpse", 0.6, 2.5, 4.5], ["blood", 0.8, 2.0, 4.0]],
    "car": [["blood", 0.5, 2.5, 4.0], ["corpse", 0.3, 2.5, 4.0]],
    "burning_tree": [["embers", 0.6, 2.0, 4.0], ["charred_log", 0.25, 3.0, 5.0]],
    "wreck_boat": [["tide_chain", 0.45, 4.0, 6.0], ["tide_algae", 0.8, 2.5, 5.0], ["tide_stone", 0.4, 4.0, 6.0]],
    "bell_frame": [["wax_candle", 0.65, 3.0, 4.5], ["torn_banner", 0.35, 4.0, 6.0]],
    "bell_shrine": [["wax_candle", 0.75, 3.0, 5.0], ["abbey_stone", 0.5, 4.0, 6.0]],
    "glass_spire": [["glass_shards", 0.8, 3.0, 5.0], ["glass_crack", 0.5, 2.0, 4.0]],
    "iron_workshop": [["iron_gear", 0.45, 4.0, 6.0], ["iron_crate", 0.55, 3.5, 5.5], ["oil_barrel", 0.4, 4.0, 6.0]],
    "forge_hearth": [["anvil", 0.35, 3.0, 4.5], ["oil_barrel", 0.4, 3.0, 5.0]],
}
# ряди: [шанс ряду, крок, мін. ще, макс. ще]. Крок такий, щоб між об'єктами ряду лишався прохід (PASS_GAP).
const ROWS := {"tombstone": [0.7, 3.6, 2, 4], "cross": [0.35, 3.6, 1, 2], "pillar": [0.5, 5.0, 1, 3]}
# Місто: сітка вулиць із кроком CITY_P; смуга проїзду — CITY_ROAD від осі
const CITY_P := 46.0
const CITY_ROAD := 5.5
const CITY_ROAD_PROPS := [["car", 2.4], ["road_mark", 3.0], ["manhole", 0.8], ["crack", 1.5], ["blood", 1.2], ["corpse", 0.6], ["barricade", 0.3]]
const CITY_CROSS_PROPS := [["car", 1.0], ["blood", 1.5], ["crack", 1.5], ["manhole", 1.0], ["corpse", 0.6]]
const CITY_WALK_PROPS := [["streetlamp", 2.0], ["dumpster", 1.0], ["sign", 0.6], ["fire_barrel", 0.5], ["corpse", 0.6], ["blood", 0.8]]
const CITY_BLOCK_PROPS := [["ruined_building", 1.5], ["rubble", 2.0], ["dumpster", 0.5], ["corpse", 0.8], ["blood", 1.0], ["crack", 1.5], ["barricade", 0.3]]

var target
var trail := false            # стежка від воріт, розвилка й пам'ятні місця (звичайні локації; в обороні й ескорті є своя дорога)
# Кислотні болота (локації з біомом «Токсичне болото»): шкодять лише гравцеві, зомбі їх не відчувають.
# Форми водойм і правила їх розстановки — у розділі «Кислотні болота» нижче.
const ACID_CELL := 40.0           # розмір клітинки сітки, у якій живуть водойми
const ACID_INSET := 2.5           # відступ водойм від краю клітинки (сусідні клітинки тримають між водоймами 5+ м)
const ACID_GAP := 3.0             # мінімальна відстань між водоймами однієї клітинки
const ACID_START_SAFE := 24.0     # біля воріт замку кислоти немає
var acid := false
var acid_mult := 1.0              # множник кількості й розміру водойм (locations.gd → acid_mult); у «Чорній трясовині» їх удвічі більше
var _acid_chunk: Array = []       # водойми поблизу поточного чанка (для розстановки предметів); у «Палаючій трясовині» є і кислота, і вогонь
var _acid_cache := {}             # Vector2i клітинки -> її водойми

# Вогняні поля (локації з біомом «Пожежа»): живий вогонь різної форми, що палить усіх, хто в ньому стоїть.
# Форми: довгі звивисті лінії (з відгалуженнями), дуги, неправильні плями й розсип дрібних вогнищ.
# Кожна форма — ланцюжок кіл [x, z, r]; розстановка залежить лише від клітинки сітки й world_seed,
# тож чанки й перевірка шкоди (in_fire) завжди збігаються.
const FIRE_CELL := 24.0
const FIRE_CHANCE := 0.85         # шанс головної форми в клітинці
const FIRE_CHANCE_2 := 0.5        # шанс другої
const FIRE_START_SAFE := 28.0     # біля воріт замку вогню немає
const FIRE_REACH := 44.0          # максимальний виліт форми від її якоря (для пошуку сусідів)
var fire := false
var fire_safe: Array = []         # [початок Vector2, кінець Vector2, радіус]: тут вогню немає (дорога й площа застави в обороні)
var _fire_cache := {}
var forced_biome := -1        # якщо >= 0 — вся локація цього біому
var secondary_biome := -1     # додатковий біом (плямами)
var arena_radius := 1000000.0 # межа арени; поза нею — суцільна стіна з дерев/каміння
var world_seed := 1337
# Лінійна карта (місія з ескортом): дорога від замку (0,0) на північ (-Z) до табору лицаря.
var corridor := false
var corridor_len := 170.0
var corridor_half_w := 42.0
const ROAD_W := 9.0
var chunks := {}
var clear_zones: Array = []   # [початок Vector2, кінець Vector2, радіус]: тут не ставимо дерева й камені (дорога, застава)

var noise_t := FastNoiseLite.new()
var noise_m := FastNoiseLite.new()
var noise_w := FastNoiseLite.new()
var noise_d := FastNoiseLite.new()
var noise_g := FastNoiseLite.new()   # повільний шум: де гай, а де галявина

var landmarks: Array = []     # центри пам'ятних місць (Vector2): level.gd ставить там табори сплячих зомбі
var _trails: Array = []       # стежки: PackedVector2Array точок
var _trail_dress: Array = []  # придорожні предмети: {pos: Vector2, kind: String}
var _set_props: Array = []    # предмети розвилки й пам'ятних місць: {pos, kind}
var _discs: Array = []        # втоптані майданчики: [центр Vector2, радіус float]
var _zl: Array = []           # зони без природних об'єктів, що торкаються поточного чанка
var _yaw_force := -1000.0     # якщо > -100 — наступний об'єкт повертається саме так (ряди, вулиці)

var _ground_mat: StandardMaterial3D
var _prop_mat: StandardMaterial3D
var _unit := {}
var _parts := {}
var _shapes: Array = []
var _frame := Transform3D.IDENTITY
var _lights: Array = []
var _yaw := 0.0
var _chunk_pools: Array = []   # кола вогню поблизу поточного чанка: [x, z, r]
var _placed: Array = []       # тверді об'єкти поточного чанка: [{c, r, fp}] — для перевірки проходів

func _ready() -> void:
    world_seed = randi() % 1000000
    _setup_noise(noise_t, world_seed, 0.007)
    _setup_noise(noise_m, world_seed + 11, 0.007)
    _setup_noise(noise_w, world_seed + 23, 0.009)
    _setup_noise(noise_d, world_seed + 37, 0.12)
    _setup_noise(noise_g, world_seed + 51, 0.028)

    _ground_mat = StandardMaterial3D.new()
    _ground_mat.vertex_color_use_as_albedo = true
    _ground_mat.albedo_texture = _make_grain_texture()
    _ground_mat.normal_enabled = true
    _ground_mat.normal_texture = _make_normal_texture()
    _ground_mat.normal_scale = 1.3
    _ground_mat.roughness = 0.95
    _ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

    _prop_mat = StandardMaterial3D.new()
    _prop_mat.vertex_color_use_as_albedo = true
    _prop_mat.roughness = 0.9
    _prop_mat.albedo_texture = _make_detail_texture()
    _prop_mat.uv1_triplanar = true
    _prop_mat.uv1_world_triplanar = true
    _prop_mat.uv1_scale = Vector3(0.6, 0.6, 0.6)

    var bm := BoxMesh.new()
    bm.size = Vector3.ONE
    var sm := SphereMesh.new()
    sm.radius = 0.5
    sm.height = 1.0
    sm.radial_segments = 16
    sm.rings = 8
    var cm := CylinderMesh.new()
    cm.top_radius = 0.5
    cm.bottom_radius = 0.5
    cm.height = 1.0
    cm.radial_segments = 14
    var nm := CylinderMesh.new()
    nm.top_radius = 0.0
    nm.bottom_radius = 0.5
    nm.height = 1.0
    nm.radial_segments = 14
    _unit = {"box": bm, "sphere": sm, "cyl": cm, "cone": nm}
    for k in _unit:
        _unit[k].material = _prop_mat

    _build_start_area()
    if corridor:
        _build_road()
    elif trail:
        _build_trails()

func _setup_noise(n: FastNoiseLite, s: int, freq: float) -> void:
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.seed = s
    n.frequency = freq
    n.fractal_octaves = 2

# ---------- Біоми ----------
func biome_at(x: float, z: float) -> int:
    if forced_biome >= 0:
        if secondary_biome >= 0 and Vector2(x, z).length() > 22.0:
            if noise_w.get_noise_2d(x, z) > 0.12:
                return _biome_index(secondary_biome)
        return _biome_index(forced_biome)
    if Vector2(x, z).length() < START_R:
        return Biomes.MEADOW
    var t := noise_t.get_noise_2d(x, z)
    var m := noise_m.get_noise_2d(x, z)
    var w := noise_w.get_noise_2d(x, z)
    if t < -0.22:
        return Biomes.SNOW
    if t > 0.25 and m < 0.1:
        return Biomes.DESERT
    if w > 0.3:
        return Biomes.RUINS
    if w < -0.3:
        return Biomes.GRAVEYARD
    if m > 0.1:
        return Biomes.FOREST
    return Biomes.MEADOW

func _biome_index(index: int) -> int:
    var count := Biomes.DATA.size()
    for table in [DENSITY, BORDER_PROPS, PROPS, TRAIL_COL, TRAIL_PROPS, LANDMARKS]:
        count = mini(count, table.size())
    return clampi(index, 0, maxi(count - 1, 0))

# ---------- Керування чанками ----------
func _process(_delta: float) -> void:
    if target != null:
        update(target.global_position, 1)

var _last_chunk := Vector2i(1 << 30, 1 << 30)
var _pending := true          # є чанки, які ще треба добудувати
var _ground_tangents := PackedFloat32Array()

func update(center: Vector3, max_new: int) -> void:
    var cx := floori(center.x / CHUNK)
    var cz := floori(center.z / CHUNK)
    var cc := Vector2i(cx, cz)
    if cc == _last_chunk and not _pending:
        return
    _last_chunk = cc
    _pending = false
    for key in chunks.keys():
        if maxi(absi(key.x - cx), absi(key.y - cz)) > VIEW_R + 1:
            chunks[key].queue_free()
            chunks.erase(key)
    var made := 0
    for r in range(0, VIEW_R + 1):
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                if maxi(absi(dx), absi(dz)) != r:
                    continue
                var key := Vector2i(cx + dx, cz + dz)
                if chunks.has(key):
                    continue
                if made >= max_new:
                    _pending = true
                    return
                var node := _build_chunk(key)
                add_child(node)
                chunks[key] = node
                made += 1

func _build_chunk(c: Vector2i) -> Node3D:
    var root := Node3D.new()
    var x0 := float(c.x) * CHUNK
    var z0 := float(c.y) * CHUNK
    root.add_child(_build_ground(x0, z0))

    _parts = {"box": [[], []], "sphere": [[], []], "cyl": [[], []], "cone": [[], []]}
    _shapes = []
    _lights = []
    _placed = []
    _chunk_pools = []
    _acid_chunk = []
    if acid:
        _acid_chunk = _acid_shapes_near(x0, z0, 8.0)
    if fire:
        _chunk_pools = _fire_pools_near(x0, z0, 3.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = (c.x * 73856093) ^ (c.y * 19349663) ^ world_seed
    _zl = _zones_near(x0, z0)
    _yaw_force = -1000.0
    if trail:
        # спершу — задумані місця: розвилка, пам'ятні місця й предмети вздовж стежки
        _place_layout(x0, z0, rng)
    for i in range(ATTEMPTS):
        var x := x0 + rng.randf() * CHUNK
        var z := z0 + rng.randf() * CHUNK
        if absf(x) < 16.0 and absf(z) < 16.0:
            continue
        if (not _zl.is_empty() and _in_clear_zone(x, z)) or (corridor and _in_road_or_camp(x, z)):
            continue
        if not _chunk_pools.is_empty() and _in_pools(_chunk_pools, x, z, 1.6):
            continue
        if not _acid_chunk.is_empty() and _acid_block(x, z, 1.6):
            continue
        var b := _biome_index(biome_at(x, z))
        # поблизу замку майже порожньо, далі щільність поступово росте
        if rng.randf() > float(DENSITY[b]) * _open_factor(x, z):
            continue
        if b == Biomes.CITY:
            _spawn_city(x, z, rng, x0, z0)
            continue
        var kind := _pick(PROPS[b], rng)
        # високі об'єкти — гаями й ділянками, між ними галявини
        if TALL.has(kind) and rng.randf() > 0.10 + 0.90 * _grove(x, z):
            continue
        _place_group(kind, x, z, rng, x0, z0)

    if corridor:
        for i in range(BORDER_ATTEMPTS):
            var cx2 := x0 + rng.randf() * CHUNK
            var cz2 := z0 + rng.randf() * CHUNK
            var od := corridor_outside(cx2, cz2)
            if od < -1.0 or od > 20.0:
                continue
            _spawn_prop(_pick(BORDER_PROPS[_biome_index(biome_at(cx2, cz2))], rng), cx2, cz2, rng)
    elif arena_radius < 100000.0:
        for i in range(BORDER_ATTEMPTS):
            var bx := x0 + rng.randf() * CHUNK
            var bz := z0 + rng.randf() * CHUNK
            var bd := Vector2(bx, bz).length()
            if bd < arena_radius - 1.0 or bd > arena_radius + 20.0:
                continue
            _spawn_prop(_pick(BORDER_PROPS[_biome_index(biome_at(bx, bz))], rng), bx, bz, rng)

    if acid:
        _add_acid(root, x0, z0)
    if fire:
        _add_fire(root, x0, z0)

    for key in _parts:
        var entry: Array = _parts[key]
        var xfs: Array = entry[0]
        if xfs.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = _unit[key]
        mm.instance_count = xfs.size()
        for i in range(xfs.size()):
            mm.set_instance_transform(i, xfs[i])
            mm.set_instance_color(i, entry[1][i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        root.add_child(mmi)

    for ld in _lights:
        var lamp: OmniLight3D = FlickerLight.new()
        lamp.light_color = ld["color"]
        lamp.light_energy = float(ld["energy"])
        lamp.omni_range = float(ld["range"])
        lamp.position = ld["pos"]
        root.add_child(lamp)

    if not _shapes.is_empty():
        var sb := StaticBody3D.new()
        sb.collision_layer = 4
        sb.collision_mask = 0
        for s in _shapes:
            var cs := CollisionShape3D.new()
            if s["t"] == "cyl":
                var sh := CylinderShape3D.new()
                sh.radius = float(s["r"])
                sh.height = float(s["h"])
                cs.shape = sh
                cs.position = s["pos"]
            else:
                var bx := BoxShape3D.new()
                bx.size = s["size"]
                cs.shape = bx
                cs.transform = Transform3D(Basis(Vector3.UP, float(s["yaw"])), s["pos"])
            sb.add_child(cs)
        root.add_child(sb)
    return root

# ---------- Кислотні болота ----------
# Клітинка сітки ACID_CELL м містить кілька водойм РІЗНОЇ форми й розміру: довга звивиста річка, змійка з багатьма вигинами,
# велике озеро неправильної форми, затока з «пальцями» та дрібні калюжі. Кожна водойма лежить цілком у своїй клітинці
# (відступ ACID_INSET від краю) і не ближче ACID_GAP м до інших, тож вони ніколи не зливаються й не торкаються.
# Контур — многокутник; чанки, перевірка шкоди (in_acid) і розстановка предметів беруть одні й ті самі дані, що залежать
# лише від клітинки, world_seed і acid_mult. Форми обрізаються по межі біому «Токсичне болото», тож усе працює на кожній
# локації, де є болото (основний чи додатковий біом).

func _acid_circle(c: Vector2, r: float, n: int = 12) -> PackedVector2Array:
    var out := PackedVector2Array()
    for k in range(n):
        var a := TAU * float(k) / float(n)
        out.append(c + Vector2(cos(a), sin(a)) * r)
    return out

func _poly_area(p: PackedVector2Array) -> float:
    var s := 0.0
    var n := p.size()
    for k in range(n):
        var a := p[k]
        var b := p[(k + 1) % n]
        s += a.x * b.y - b.x * a.y
    return absf(s) * 0.5

func _poly_bbox(p: PackedVector2Array) -> Rect2:
    var lo := Vector2(1.0e9, 1.0e9)
    var hi := Vector2(-1.0e9, -1.0e9)
    for q in p:
        lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
        hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
    return Rect2(lo, hi - lo)

func _in_pools(pools: Array, x: float, z: float, margin: float) -> bool:
    for p in pools:
        var dx := x - float(p[0])
        var dz := z - float(p[1])
        var rr := float(p[2]) + margin
        if dx * dx + dz * dz < rr * rr:
            return true
    return false

# Найбільший із многокутників результату (решта — діри або випадкові уламки).
func _largest_poly(arr: Array) -> PackedVector2Array:
    var best := PackedVector2Array()
    var ba := -1.0
    for p in arr:
        var ar := _poly_area(p)
        if ar > ba:
            ba = ar
            best = p
    return best

func _poly_union(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
    var res: Array = Geometry2D.merge_polygons(a, b)
    if res.is_empty():
        return a
    return _largest_poly(res)

func _rand_in(rng: RandomNumberGenerator, r: Rect2) -> Vector2:
    return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))

# Неправильна пляма: еліпс, контур якого коливається трьома гармоніками (різні випуклості й затоки).
func _acid_blob(rng: RandomNumberGenerator, c: Vector2, rx: float, ry: float, yaw: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    var n := clampi(int(maxf(rx, ry) * 6.0), 20, 56)
    var a2 := rng.randf_range(0.03, 0.16)
    var a3 := rng.randf_range(0.03, 0.20)
    var a5 := rng.randf_range(0.0, 0.10)
    var p2 := rng.randf() * TAU
    var p3 := rng.randf() * TAU
    var p5 := rng.randf() * TAU
    var cs := cos(yaw)
    var sn := sin(yaw)
    for k in range(n):
        var th := TAU * float(k) / float(n)
        var f := 1.0 + a2 * cos(2.0 * th + p2) + a3 * cos(3.0 * th + p3) + a5 * cos(5.0 * th + p5)
        var lx := cos(th) * rx * f
        var ly := sin(th) * ry * f
        out.append(c + Vector2(lx * cs - ly * sn, lx * sn + ly * cs))
    return out

# Річка або змійка: ламана з плавними поворотами, що змінюється за шириною (звужується до кінців, роздувається плесами).
# Ламана не перетинає саму себе, не виходить за клітинку й за межі болота. Контур — об'єднання кіл уздовж ламаної.
func _acid_river(rng: RandomNumberGenerator, region: Rect2, serpent: bool, k: float) -> PackedVector2Array:
    var wbase := (rng.randf_range(0.7, 1.05) if serpent else rng.randf_range(1.1, 1.9)) * k
    var length := (rng.randf_range(34.0, 52.0) if serpent else rng.randf_range(18.0, 32.0)) * k
    var amp := rng.randf_range(0.26, 0.36) if serpent else rng.randf_range(0.08, 0.18)
    var freq := rng.randf_range(0.28, 0.46) if serpent else rng.randf_range(0.2, 0.38)
    var tmax := 0.34 if serpent else 0.2          # найбільший поворот за крок 1 м: тримає вигини плавними
    var ph := rng.randf() * TAU
    var ph2 := rng.randf() * TAU
    var safe := region.grow(-(wbase * 1.4 + 0.5))
    if safe.size.x < 6.0 or safe.size.y < 6.0:
        return PackedVector2Array()
    var pos := _rand_in(rng, safe)
    var centre := region.get_center()
    # починаємо в бік середини клітинки, щоб річка не впиралась у край одразу
    var h := (centre + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)) - pos).angle() + rng.randf_range(-0.9, 0.9)
    var sep := wbase * 2.6 + 0.8
    var sep2 := sep * sep
    var skip := int(sep * 1.5) + 2               # найближчі точки ламаної не рахуються: вони й так поруч
    var pts: Array = []
    for s in range(int(length)):
        pts.append(pos)
        var turn := amp * sin(freq * float(s) + ph) + rng.randf_range(-0.05, 0.05)
        # біля краю клітинки заздалегідь плавно повертаємо до середини
        var ahead := pos + Vector2(cos(h), sin(h)) * 10.0
        if not safe.has_point(ahead):
            turn += clampf(angle_difference(h, (centre - pos).angle()), -0.16, 0.16)
        turn = clampf(turn, -tmax, tmax)
        var moved := false
        for attempt in range(7):
            var hh := h + turn
            if attempt >= 1:
                var sg := 1.0 if (attempt % 2) == 1 else -1.0
                hh = h + clampf(turn + sg * 0.08 * floorf(float(attempt + 1) * 0.5), -tmax, tmax)
            var nxt := pos + Vector2(cos(hh), sin(hh))
            if not safe.has_point(nxt):
                continue
            if nxt.length() < ACID_START_SAFE + wbase:
                continue
            if biome_at(nxt.x, nxt.y) != Biomes.SWAMP:
                continue
            var clear := true
            for q in range(0, pts.size() - skip):
                if (pts[q] as Vector2).distance_squared_to(nxt) < sep2:
                    clear = false
                    break
            if not clear:
                continue
            h = hh
            pos = nxt
            moved = true
            break
        if not moved:
            break
    var n := pts.size()
    if n < 14:
        return PackedVector2Array()
    var poly := PackedVector2Array()
    for i in range(n):
        var t := float(i) / float(n - 1)
        var taper := clampf(pow(sin(PI * t), 0.6), 0.0, 1.0)
        var w := wbase * (0.35 + 0.65 * taper) * (1.0 + 0.3 * sin(float(i) * 0.5 + ph2))
        w = maxf(w, 0.45)
        var circ := _acid_circle(pts[i], w, 12)
        poly = circ if i == 0 else _poly_union(poly, circ)
    return poly

# Створює контур потрібного виду всередині region. Порожній результат — не вдалося (буде нова спроба).
func _acid_make(kind: String, rng: RandomNumberGenerator, region: Rect2, k: float) -> PackedVector2Array:
    if kind == "river":
        return _acid_river(rng, region, false, k)
    if kind == "serpent":
        return _acid_river(rng, region, true, k)
    if kind == "lake":
        var rx := rng.randf_range(4.5, 8.0) * k
        var ry := rx * rng.randf_range(0.45, 1.0)
        var r2 := region.grow(-rx * 1.45)
        if r2.size.x <= 0.0 or r2.size.y <= 0.0:
            return PackedVector2Array()
        return _acid_blob(rng, _rand_in(rng, r2), rx, ry, rng.randf() * TAU)
    if kind == "lagoon":
        # затока: головна пляма з 2-4 «пальцями»-відгалуженнями
        var rr := rng.randf_range(3.0, 4.6) * k
        var r3 := region.grow(-rr * 3.0)
        if r3.size.x <= 0.0 or r3.size.y <= 0.0:
            return PackedVector2Array()
        var c := _rand_in(rng, r3)
        var poly := _acid_blob(rng, c, rr, rr * rng.randf_range(0.6, 1.0), rng.randf() * TAU)
        for l in range(rng.randi_range(2, 4)):
            var ang := rng.randf() * TAU
            var lc := c + Vector2(cos(ang), sin(ang)) * rr * rng.randf_range(0.6, 0.95)
            var lr := rr * rng.randf_range(0.45, 0.8)
            poly = _poly_union(poly, _acid_blob(rng, lc, lr, lr * rng.randf_range(0.5, 1.0), rng.randf() * TAU))
        return poly
    # дрібна калюжа
    var sr := rng.randf_range(1.0, 2.3) * k
    var r4 := region.grow(-sr * 1.5)
    if r4.size.x <= 0.0 or r4.size.y <= 0.0:
        return PackedVector2Array()
    return _acid_blob(rng, _rand_in(rng, r4), sr, sr * rng.randf_range(0.45, 1.0), rng.randf() * TAU)

# Точки контуру приблизно через 1.2 м (для швидких перевірок відстані).
func _acid_sample(poly: PackedVector2Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    var last := poly[0]
    out.append(last)
    for k in range(1, poly.size()):
        if poly[k].distance_squared_to(last) >= 1.44:
            last = poly[k]
            out.append(last)
    return out

func _acid_touch(a: Dictionary, b: Dictionary, gap: float) -> bool:
    var ba: Rect2 = a["bb"]
    var bb: Rect2 = b["bb"]
    if not ba.grow(gap).intersects(bb):
        return false
    var pa: PackedVector2Array = a["pts"]
    var pb: PackedVector2Array = b["pts"]
    var g2 := gap * gap
    for p in pa:
        for q in pb:
            if p.distance_squared_to(q) < g2:
                return true
    if Geometry2D.is_point_in_polygon(pa[0], b["poly"]) or Geometry2D.is_point_in_polygon(pb[0], a["poly"]):
        return true
    return false

# Перевірка контуру: у межах клітинки, не біля воріт, не торкається вже поставлених, лежить у болоті, малюється без помилок.
func _acid_check(poly: PackedVector2Array, cell: Rect2, placed: Array) -> Dictionary:
    if poly.size() < 8:
        return {}
    var bb := _poly_bbox(poly)
    var inner := cell.grow(-1.0)
    if not (inner.has_point(bb.position) and inner.has_point(bb.end)):
        return {}
    if Geometry2D.is_point_in_polygon(Vector2.ZERO, poly):
        return {}
    var pts := _acid_sample(poly)
    for q in pts:
        if q.length() < ACID_START_SAFE:
            return {}
    var sh := {"poly": poly, "bb": bb, "pts": pts}
    for o in placed:
        if _acid_touch(sh, o, ACID_GAP):
            return {}
    var step := maxi(1, int(float(poly.size()) / 6.0))
    for k in range(0, poly.size(), step):
        if biome_at(poly[k].x, poly[k].y) != Biomes.SWAMP:
            return {}
    var tri := Geometry2D.triangulate_polygon(poly)
    if tri.is_empty():
        var alt := _largest_poly(Geometry2D.offset_polygon(poly, 0.05, Geometry2D.JOIN_ROUND))
        if alt.size() < 8:
            return {}
        var alt_bb := _poly_bbox(alt)
        if not (inner.has_point(alt_bb.position) and inner.has_point(alt_bb.end)):
            return {}
        tri = Geometry2D.triangulate_polygon(alt)
        if tri.is_empty():
            return {}
        poly = alt
        bb = alt_bb
        sh = {"poly": poly, "bb": bb, "pts": _acid_sample(poly)}
    sh["tri"] = tri
    sh["c"] = bb.get_center()
    sh["area"] = _poly_area(poly)
    return sh

func _acid_pick_kind(rng: RandomNumberGenerator) -> String:
    var r := rng.randf()
    if r < 0.30:
        return "river"
    if r < 0.50:
        return "serpent"
    if r < 0.75:
        return "lake"
    return "lagoon"

# Водойми однієї клітинки: [{poly, bb, pts, tri, c, area}]. Залежать лише від клітинки, world_seed і acid_mult.
func _acid_shapes_cell(i: int, j: int) -> Array:
    var key := Vector2i(i, j)
    if _acid_cache.has(key):
        return _acid_cache[key]
    var out: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = (i * 73856093) ^ (j * 19349663) ^ (world_seed + 4242)
    var cell := Rect2(float(i) * ACID_CELL, float(j) * ACID_CELL, ACID_CELL, ACID_CELL)
    var region := cell.grow(-ACID_INSET)
    var k := 1.0 + 0.25 * (acid_mult - 1.0)
    var plan: Array = []
    if rng.randf() < minf(0.95, 0.85 * acid_mult):
        plan.append(_acid_pick_kind(rng))
    if rng.randf() < minf(0.9, 0.5 * acid_mult):
        plan.append(_acid_pick_kind(rng))
    for n in range(rng.randi_range(2, 5)):
        if rng.randf() < minf(0.95, 0.75 * acid_mult):
            plan.append("small")
    for kind in plan:
        for attempt in range(5):
            var poly := _acid_make(String(kind), rng, region, k * (1.0 - 0.12 * float(attempt)))
            var sh := _acid_check(poly, cell, out)
            if not sh.is_empty():
                out.append(sh)
                break
    _acid_cache[key] = out
    return out

# Усі водойми клітинок, що зачіпають квадрат чанка, розширений на pad.
func _acid_shapes_near(x0: float, z0: float, pad: float) -> Array:
    var out: Array = []
    var i0 := int(floor((x0 - pad) / ACID_CELL))
    var i1 := int(floor((x0 + CHUNK + pad) / ACID_CELL))
    var j0 := int(floor((z0 - pad) / ACID_CELL))
    var j1 := int(floor((z0 + CHUNK + pad) / ACID_CELL))
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            out.append_array(_acid_shapes_cell(i, j))
    return out

# Чи потрапляє точка у водойму або ближче margin до її берега (щоб не ставити там дерева й каміння).
func _acid_block(x: float, z: float, margin: float) -> bool:
    var p := Vector2(x, z)
    var m2 := (margin + 0.6) * (margin + 0.6)
    for sh in _acid_chunk:
        var bb: Rect2 = sh["bb"]
        if not bb.grow(margin).has_point(p):
            continue
        var poly: PackedVector2Array = sh["poly"]
        if Geometry2D.is_point_in_polygon(p, poly):
            return true
        var pts: PackedVector2Array = sh["pts"]
        for q in pts:
            if p.distance_squared_to(q) < m2:
                return true
    return false

# Чи стоїть точка в кислоті (level.gd перевіряє це кожен кадр для гравця). Водойма завжди цілком у своїй клітинці,
# тож дивимось лише одну клітинку.
func in_acid(x: float, z: float) -> bool:
    if not acid:
        return false
    var p := Vector2(x, z)
    for sh in _acid_shapes_cell(int(floor(x / ACID_CELL)), int(floor(z / ACID_CELL))):
        var bb: Rect2 = sh["bb"]
        if not bb.has_point(p):
            continue
        var poly: PackedVector2Array = sh["poly"]
        if Geometry2D.is_point_in_polygon(p, poly):
            return true
    return false

# Водойми чанка: кожна — вузол acid_pool.gd (поверхня, край, бульбашки, випари). Водойма належить чанку свого центру.
func _add_acid(root: Node3D, x0: float, z0: float) -> void:
    var i0 := int(floor(x0 / ACID_CELL))
    var i1 := int(floor((x0 + CHUNK) / ACID_CELL))
    var j0 := int(floor(z0 / ACID_CELL))
    var j1 := int(floor((z0 + CHUNK) / ACID_CELL))
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            for sh in _acid_shapes_cell(i, j):
                var c: Vector2 = sh["c"]
                if c.x < x0 or c.x >= x0 + CHUNK or c.y < z0 or c.y >= z0 + CHUNK:
                    continue
                var ap := AcidPool.new()
                ap.poly = sh["poly"]
                ap.tri = sh["tri"]
                ap.area = float(sh["area"])
                ap.seed_v = int(c.x * 7.0) ^ int(c.y * 13.0)
                root.add_child(ap)

# ---------- Вогняні поля ----------
# Крок «ходьби» ланцюжка кіл: додає кола вздовж кривої (heading змінюється на кожному кроці).
func _fire_walk(pts: Array, start: Vector2, heading: float, length: float, curve: float, wobble: float, rmin: float, rmax: float, rng: RandomNumberGenerator) -> void:
    var pos := start
    var h := heading
    var walked := 0.0
    while walked < length:
        pts.append([pos.x, pos.y, rng.randf_range(rmin, rmax)])
        var step := rng.randf_range(1.6, 2.4)
        h += curve + rng.randf_range(-wobble, wobble)
        pos += Vector2(cos(h), sin(h)) * step
        walked += step

# Точки однієї форми (абсолютні координати).
func _fire_shape_points(kind: float, a: Vector2, yaw: float, sd: int) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = sd
    var pts: Array = []
    if kind < 0.45:
        # довга звивиста лінія вогню, іноді з відгалуженням
        var length := rng.randf_range(16.0, 36.0)
        _fire_walk(pts, a, yaw, length, 0.0, 0.26, 1.1, 2.3, rng)
        if rng.randf() < 0.55 and pts.size() > 4:
            var m: Array = pts[pts.size() / 2]
            var side := 1.0 if rng.randf() < 0.5 else -1.0
            _fire_walk(pts, Vector2(float(m[0]), float(m[1])), yaw + side * rng.randf_range(0.6, 1.1), rng.randf_range(7.0, 14.0), 0.0, 0.3, 0.9, 1.9, rng)
    elif kind < 0.70:
        # довга дуга (вигин в один бік)
        var sgn := 1.0 if rng.randf() < 0.5 else -1.0
        _fire_walk(pts, a, yaw, rng.randf_range(18.0, 34.0), sgn * rng.randf_range(0.05, 0.11), 0.07, 1.2, 2.4, rng)
    elif kind < 0.82:
        # витягнута неправильна пляма
        var dir := Vector2(cos(yaw), sin(yaw))
        var perp := Vector2(-dir.y, dir.x)
        for k in range(rng.randi_range(4, 7)):
            var q := a + dir * rng.randf_range(-5.5, 5.5) + perp * rng.randf_range(-2.2, 2.2)
            pts.append([q.x, q.y, rng.randf_range(2.0, 3.6)])
    else:
        # розсип дрібних вогнищ
        var dir2 := Vector2(cos(yaw), sin(yaw))
        var perp2 := Vector2(-dir2.y, dir2.x)
        for k in range(rng.randi_range(4, 8)):
            var q2 := a + dir2 * rng.randf_range(-8.0, 8.0) + perp2 * rng.randf_range(-5.0, 5.0)
            pts.append([q2.x, q2.y, rng.randf_range(0.9, 1.8)])
    return pts

# Форми однієї клітинки: [{a: Vector2, reach: float, pts: [[x, z, r], ...]}].
func _fire_shapes_cell(i: int, j: int) -> Array:
    var key := Vector2i(i, j)
    if _fire_cache.has(key):
        return _fire_cache[key]
    var out: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = (i * 83492791) ^ (j * 19349663) ^ (world_seed + 777)
    for n in range(2):
        var chance := FIRE_CHANCE if n == 0 else FIRE_CHANCE_2
        var ax := (float(i) + rng.randf_range(0.1, 0.9)) * FIRE_CELL
        var az := (float(j) + rng.randf_range(0.1, 0.9)) * FIRE_CELL
        var roll := rng.randf()
        var kind := rng.randf()
        var yaw := rng.randf() * TAU
        var sd := rng.randi()
        if roll > chance:
            continue
        if biome_at(ax, az) != Biomes.FIRE:
            continue
        var raw := _fire_shape_points(kind, Vector2(ax, az), yaw, sd)
        var pts: Array = []
        var reach := 0.0
        for c in raw:
            if Vector2(float(c[0]), float(c[1])).length() < FIRE_START_SAFE:
                continue
            if _fire_in_safe(float(c[0]), float(c[1]), float(c[2])):
                continue
            pts.append(c)
            reach = maxf(reach, Vector2(float(c[0]) - ax, float(c[1]) - az).length() + float(c[2]))
        if pts.is_empty():
            continue
        out.append({"a": Vector2(ax, az), "reach": reach, "pts": pts})
    _fire_cache[key] = out
    return out

func _fire_in_safe(x: float, z: float, r: float) -> bool:
    for zn in fire_safe:
        var a: Vector2 = zn[0]
        var b: Vector2 = zn[1]
        var ab := b - a
        var l2 := ab.length_squared()
        var t := 0.0 if l2 < 0.0001 else clampf((Vector2(x, z) - a).dot(ab) / l2, 0.0, 1.0)
        if Vector2(x, z).distance_to(a + ab * t) < float(zn[2]) + r:
            return true
    return false

# Усі кола вогню поблизу чанка (для того, щоб не ставити там дерева й камені).
func _fire_pools_near(x0: float, z0: float, pad: float) -> Array:
    var out: Array = []
    var reach := FIRE_REACH + pad
    var i0 := int(floor((x0 - reach) / FIRE_CELL))
    var i1 := int(floor((x0 + CHUNK + reach) / FIRE_CELL))
    var j0 := int(floor((z0 - reach) / FIRE_CELL))
    var j1 := int(floor((z0 + CHUNK + reach) / FIRE_CELL))
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            for sh in _fire_shapes_cell(i, j):
                for c in sh["pts"]:
                    if float(c[0]) > x0 - 12.0 and float(c[0]) < x0 + CHUNK + 12.0 and float(c[1]) > z0 - 12.0 and float(c[1]) < z0 + CHUNK + 12.0:
                        out.append(c)
    return out

# Чи стоїть точка у вогні (level.gd перевіряє це кожен кадр для гравця й раз на пів секунди для зомбі).
func in_fire(x: float, z: float) -> bool:
    if not fire:
        return false
    var i := int(floor(x / FIRE_CELL))
    var j := int(floor(z / FIRE_CELL))
    var p := Vector2(x, z)
    for di in range(-2, 3):
        for dj in range(-2, 3):
            for sh in _fire_shapes_cell(i + di, j + dj):
                if p.distance_to(sh["a"]) > float(sh["reach"]) + 0.5:
                    continue
                for c in sh["pts"]:
                    var dx := x - float(c[0])
                    var dz := z - float(c[1])
                    var rr := float(c[2]) * 0.9
                    if dx * dx + dz * dz < rr * rr:
                        return true
    return false

# Живий вогонь чанка: кожна форма — один вузол fire_field.gd (язики, частинки, іскри, світло). Форма належить чанку свого якоря.
func _add_fire(root: Node3D, x0: float, z0: float) -> void:
    var i0 := int(floor(x0 / FIRE_CELL))
    var i1 := int(floor((x0 + CHUNK) / FIRE_CELL))
    var j0 := int(floor(z0 / FIRE_CELL))
    var j1 := int(floor((z0 + CHUNK) / FIRE_CELL))
    for i in range(i0, i1 + 1):
        for j in range(j0, j1 + 1):
            for sh in _fire_shapes_cell(i, j):
                var a: Vector2 = sh["a"]
                if a.x < x0 or a.x >= x0 + CHUNK or a.y < z0 or a.y >= z0 + CHUNK:
                    continue
                var local: Array = []
                for c in sh["pts"]:
                    local.append([float(c[0]) - a.x, float(c[1]) - a.y, float(c[2])])
                var ff := FireField.new()
                ff.pts = local
                ff.seed_v = int(a.x * 7.0) ^ int(a.y * 13.0)
                ff.position = Vector3(a.x, 0.0, a.y)
                root.add_child(ff)

# ---------- Розстановка з гарантованими проходами ----------
# Об'єкт з колізією ставимо лише якщо між ним і вже поставленими лишається вільний прохід
# не менше PASS_GAP, і він не впритул до краю чанка (сусідні чанки теж тримають відступ,
# тож на стиках теж є прохід). Інакше об'єкт скасовується: це прибирає суцільні стіни
# з дерев/каміння, кишені й глухі кути, де застрягали зомбі та гравець.
# Об'єкти без колізії (трава, квіти, кров) ставляться завжди.
func _spawn_spaced(kind: String, x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float) -> bool:
    var n_shapes := _shapes.size()
    var n_lights := _lights.size()
    var n_parts := {}
    for k in _parts:
        n_parts[k] = int((_parts[k][0] as Array).size())
    _spawn_prop(kind, x, z, rng)
    if _shapes.size() == n_shapes:
        return true
    var fp: Array = []
    for i in range(n_shapes, _shapes.size()):
        fp.append(_footprint(_shapes[i]))
    var bd := _bound(fp)
    if _spacing_ok(fp, bd, x0, z0):
        _placed.append({"c": bd["c"], "r": bd["r"], "fp": fp})
        return true
    # відкат: прибираємо колізії, меші та світло цього об'єкта
    _shapes.resize(n_shapes)
    _lights.resize(n_lights)
    for k in _parts:
        var e: Array = _parts[k]
        (e[0] as Array).resize(int(n_parts[k]))
        (e[1] as Array).resize(int(n_parts[k]))
    return false

# Задуманий об'єкт (розвилка, пам'ятне місце): ставиться завжди, але реєструється для перевірки проходів.
func _spawn_fixed(kind: String, x: float, z: float, rng: RandomNumberGenerator) -> void:
    var n_shapes := _shapes.size()
    _spawn_prop(kind, x, z, rng)
    if _shapes.size() == n_shapes:
        return
    var fp: Array = []
    for i in range(n_shapes, _shapes.size()):
        fp.append(_footprint(_shapes[i]))
    var bd := _bound(fp)
    _placed.append({"c": bd["c"], "r": bd["r"], "fp": fp})

# Головний об'єкт із «супутниками»: надгробки й колони — рядами, хата — зі стогом і парканом тощо.
func _place_group(kind: String, x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    var row := false
    var row_a := 0.0
    var rw: Array = []
    if ROWS.has(kind):
        rw = ROWS[kind]
        row = rng.randf() < float(rw[0])
        if row:
            row_a = rng.randf() * TAU
            _yaw_force = -row_a      # усі об'єкти ряду дивляться в один бік
    var ok := _spawn_spaced(kind, x, z, rng, x0, z0)
    if row and ok:
        var n := rng.randi_range(int(rw[2]), int(rw[3]))
        var sp := float(rw[1])
        for i in range(1, n + 1):
            var rx := x + cos(row_a) * sp * float(i)
            var rz := z + sin(row_a) * sp * float(i)
            if not _in_clear_zone(rx, rz):
                _spawn_spaced(kind, rx, rz, rng, x0, z0)
    _yaw_force = -1000.0
    if not ok or not CLUSTER.has(kind):
        return
    for cs in CLUSTER[kind]:
        if rng.randf() > float(cs[1]):
            continue
        var ang := rng.randf() * TAU
        var r := rng.randf_range(float(cs[2]), float(cs[3]))
        var cx := x + cos(ang) * r
        var cz := z + sin(ang) * r
        if _in_clear_zone(cx, cz):
            continue
        _spawn_spaced(String(cs[0]), cx, cz, rng, x0, z0)

# Місто: вулиці по сітці. У смузі проїзду — машини по смугах, розмітка, люки, барикади впоперек;
# на бордюрі — ліхтарі й смітники; у кварталах — будинки та уламки.
func _spawn_city(x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    var xc := roundf(x / CITY_P) * CITY_P
    var zc := roundf(z / CITY_P) * CITY_P
    var dx := absf(x - xc)
    var dz := absf(z - zc)
    var d := minf(dx, dz)
    var along_z := dx < dz                    # найближча вулиця йде вздовж Z
    var px := x
    var pz := z
    var kind := ""
    var yaw := -1000.0
    if d < CITY_ROAD:
        if dx < CITY_ROAD and dz < CITY_ROAD:
            kind = _pick(CITY_CROSS_PROPS, rng)      # перехрестя: без вирівнювання
        else:
            kind = _pick(CITY_ROAD_PROPS, rng)
            var lane := 2.6 if rng.randf() < 0.5 else -2.6
            var yaw_along := (PI * 0.5 if along_z else 0.0) + (PI if rng.randf() < 0.5 else 0.0)
            match kind:
                "car":
                    yaw = yaw_along
                    if along_z:
                        px = xc + lane
                    else:
                        pz = zc + lane
                "road_mark":
                    yaw = yaw_along
                    if along_z:
                        px = xc
                    else:
                        pz = zc
                "barricade":
                    yaw = 0.0 if along_z else PI * 0.5
                    if along_z:
                        px = xc + lane
                    else:
                        pz = zc + lane
    elif d < CITY_ROAD + 3.5:
        kind = _pick(CITY_WALK_PROPS, rng)
        var side := 1.0 if rng.randf() < 0.5 else -1.0
        if kind == "streetlamp" or kind == "sign" or kind == "dumpster":
            if along_z:
                px = xc + side * (CITY_ROAD + 1.3)
            else:
                pz = zc + side * (CITY_ROAD + 1.3)
    else:
        kind = _pick(CITY_BLOCK_PROPS, rng)
    if _in_clear_zone(px, pz):
        return
    _yaw_force = yaw
    _place_group(kind, px, pz, rng, x0, z0)
    _yaw_force = -1000.0

# Скільки «відкрито» простору на відстані від замку: поряд майже порожньо, далі — повна щільність.
func _open_factor(x: float, z: float) -> float:
    var d := Vector2(x, z).length()
    return lerpf(OPEN_MIN, 1.0, smoothstep(OPEN_FROM, OPEN_TO, d))

# 0 — галявина, 1 — гай (плавно).
func _grove(x: float, z: float) -> float:
    return smoothstep(-0.15, 0.2, noise_g.get_noise_2d(x, z))

# Зони (стежка, пам'ятні місця, оборона), що торкаються чанка: так перевірка швидка.
func _zones_near(x0: float, z0: float) -> Array:
    var out: Array = []
    for zn in clear_zones:
        var a: Vector2 = zn[0]
        var b: Vector2 = zn[1]
        var r := float(zn[2])
        if maxf(a.x, b.x) + r < x0 or minf(a.x, b.x) - r > x0 + CHUNK or maxf(a.y, b.y) + r < z0 or minf(a.y, b.y) - r > z0 + CHUNK:
            continue
        out.append(zn)
    return out

func _place_layout(x0: float, z0: float, rng: RandomNumberGenerator) -> void:
    for d in _set_props:
        var p: Vector2 = d["pos"]
        if p.x >= x0 and p.x < x0 + CHUNK and p.y >= z0 and p.y < z0 + CHUNK:
            _spawn_fixed(String(d["kind"]), p.x, p.y, rng)
    for d in _trail_dress:
        var q: Vector2 = d["pos"]
        if q.x >= x0 and q.x < x0 + CHUNK and q.y >= z0 and q.y < z0 + CHUNK:
            _spawn_spaced(String(d["kind"]), q.x, q.y, rng, x0, z0)

func _footprint(sh: Dictionary) -> Dictionary:
    var p: Vector3 = sh["pos"]
    if String(sh["t"]) == "cyl":
        return {"pts": PackedVector2Array([Vector2(p.x, p.z)]), "r": float(sh["r"])}
    var sz: Vector3 = sh["size"]
    var b := Basis(Vector3.UP, float(sh["yaw"]))
    var hx := sz.x * 0.5
    var hz := sz.z * 0.5
    var pts := PackedVector2Array()
    for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
        var cv: Vector2 = corner
        var w: Vector3 = b * Vector3(cv.x, 0.0, cv.y)
        pts.append(Vector2(p.x + w.x, p.z + w.z))
    return {"pts": pts, "r": 0.0}

# Охоплювальне коло й габарит усього об'єкта.
func _bound(fp: Array) -> Dictionary:
    var lo := Vector2(1e9, 1e9)
    var hi := Vector2(-1e9, -1e9)
    var sum := Vector2.ZERO
    var cnt := 0
    for f in fp:
        var rr := float(f["r"])
        for pt in (f["pts"] as PackedVector2Array):
            lo.x = minf(lo.x, pt.x - rr)
            lo.y = minf(lo.y, pt.y - rr)
            hi.x = maxf(hi.x, pt.x + rr)
            hi.y = maxf(hi.y, pt.y + rr)
            sum += pt
            cnt += 1
    var c := sum / float(maxi(cnt, 1))
    var r := 0.0
    for f in fp:
        var rr2 := float(f["r"])
        for pt in (f["pts"] as PackedVector2Array):
            r = maxf(r, pt.distance_to(c) + rr2)
    return {"c": c, "r": r, "lo": lo, "hi": hi}

func _spacing_ok(fp: Array, bd: Dictionary, x0: float, z0: float) -> bool:
    var m := PASS_GAP * 0.5
    var lo: Vector2 = bd["lo"]
    var hi: Vector2 = bd["hi"]
    if lo.x < x0 + m or lo.y < z0 + m or hi.x > x0 + CHUNK - m or hi.y > z0 + CHUNK - m:
        return false
    var bc: Vector2 = bd["c"]
    var br: float = bd["r"]
    for pl in _placed:
        var pc: Vector2 = pl["c"]
        if pc.distance_to(bc) - float(pl["r"]) - br >= PASS_GAP:
            continue
        for a in fp:
            for b in (pl["fp"] as Array):
                if _fp_dist(a, b) < PASS_GAP:
                    return false
    return true

func _fp_dist(a: Dictionary, b: Dictionary) -> float:
    return _poly_dist(a["pts"], b["pts"]) - float(a["r"]) - float(b["r"])

# Відстань між двома фігурами (точка = коло, чотирикутник = ящик) без урахування радіуса.
func _poly_dist(a: PackedVector2Array, b: PackedVector2Array) -> float:
    if a.size() == 1 and b.size() == 1:
        return a[0].distance_to(b[0])
    var best := 1e9
    if a.size() == 1 or b.size() == 1:
        var pt: Vector2 = a[0] if a.size() == 1 else b[0]
        var poly: PackedVector2Array = b if a.size() == 1 else a
        if _in_quad(pt, poly):
            return 0.0
        for i in range(4):
            best = minf(best, _pt_seg(pt, poly[i], poly[(i + 1) % 4]))
        return best
    if _in_quad(a[0], b) or _in_quad(b[0], a):
        return 0.0
    for i in range(4):
        var a0 := a[i]
        var a1 := a[(i + 1) % 4]
        for j in range(4):
            var b0 := b[j]
            var b1 := b[(j + 1) % 4]
            if _seg_cross(a0, a1, b0, b1):
                return 0.0
            best = minf(best, minf(_pt_seg(a0, b0, b1), _pt_seg(b0, a0, a1)))
    return best

func _in_quad(p: Vector2, poly: PackedVector2Array) -> bool:
    var pos := 0
    var neg := 0
    for i in range(4):
        var cr := (poly[(i + 1) % 4] - poly[i]).cross(p - poly[i])
        if cr > 0.0:
            pos += 1
        elif cr < 0.0:
            neg += 1
    return pos == 0 or neg == 0

func _pt_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var l2 := ab.length_squared()
    var k := 0.0
    if l2 > 0.0:
        k = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
    return p.distance_to(a + ab * k)

func _seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
    var d1 := (b - a).cross(c - a)
    var d2 := (b - a).cross(d - a)
    var d3 := (d - c).cross(a - c)
    var d4 := (d - c).cross(b - c)
    return d1 * d2 < 0.0 and d3 * d4 < 0.0

func _in_clear_zone(x: float, z: float) -> bool:
    var p := Vector2(x, z)
    for zn in _zl:
        var a: Vector2 = zn[0]
        var b: Vector2 = zn[1]
        var ab := b - a
        var l2 := ab.length_squared()
        var k := 0.0
        if l2 > 0.0:
            k = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
        if p.distance_to(a + ab * k) < float(zn[2]):
            return true
    return false

# Наскільки точка поза межами коридору (від'ємне — всередині).
func corridor_outside(x: float, z: float) -> float:
    return maxf(absf(x) - corridor_half_w, maxf(z - 30.0, -(corridor_len + 18.0) - z))

func _in_road_or_camp(x: float, z: float) -> bool:
    if absf(x) < ROAD_W * 0.5 + 0.8 and z < -16.0 and z > -corridor_len - 12.0:
        return true
    return absf(x) < 13.0 and absf(z + corridor_len) < 13.0

func _pick(table: Array, rng: RandomNumberGenerator) -> String:
    var total := 0.0
    for e in table:
        total += float(e[1])
    var r := rng.randf() * total
    for e in table:
        r -= float(e[1])
        if r <= 0.0:
            return String(e[0])
    return String(table[0][0])

# ---------- Земля ----------
func _ground_color(x: float, z: float) -> Color:
    var acc := Color(0, 0, 0, 0)
    if forced_biome >= 0 and secondary_biome < 0:
        # одна біом на всю локацію: усереднювати п'ять точок немає сенсу
        acc = Biomes.DATA[_biome_index(forced_biome)]["ground"]
    else:
        var off := CHUNK / float(CELLS) * 0.5
        var pts := [Vector2(0, 0), Vector2(off, 0), Vector2(-off, 0), Vector2(0, off), Vector2(0, -off)]
        for p in pts:
            var b := biome_at(x + p.x, z + p.y)
            var c: Color = Biomes.DATA[_biome_index(b)]["ground"]
            acc += c
        acc = acc / 5.0
    var n := noise_d.get_noise_2d(x, z) * 0.07
    if biome_at(x, z) == Biomes.CITY:
        # асфальт на вулицях сітки (див. _spawn_city)
        var dxr := absf(x - roundf(x / CITY_P) * CITY_P)
        var dzr := absf(z - roundf(z / CITY_P) * CITY_P)
        var road_k := 1.0 - smoothstep(CITY_ROAD - 1.5, CITY_ROAD + 2.0, minf(dxr, dzr))
        acc = acc.lerp(Color(0.06, 0.06, 0.07), road_k * 0.85)
        var s := noise_w.get_noise_2d(x * 2.3, z * 2.3)
        if s > 0.3:
            acc = acc.lerp(Color(0.24, 0.03, 0.03), clampf((s - 0.3) * 3.0, 0.0, 0.6))
    return Color(acc.r + n, acc.g + n, acc.b + n, 1.0)

# Тангенти плоскої сітки однакові в усіх чанках (UV лінійні за світовими координатами),
# тому рахуємо їх SurfaceTool один раз, а далі лише підставляємо.
func _make_ground_tangents() -> PackedFloat32Array:
    var step := CHUNK / float(CELLS)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(CELLS):
        for j in range(CELLS):
            var ax := float(i) * step
            var az := float(j) * step
            var pa := Vector3(ax, 0, az)
            var pb := Vector3(ax + step, 0, az)
            var pc := Vector3(ax + step, 0, az + step)
            var pd := Vector3(ax, 0, az + step)
            _gv(st, pa, Color.WHITE)
            _gv(st, pb, Color.WHITE)
            _gv(st, pc, Color.WHITE)
            _gv(st, pa, Color.WHITE)
            _gv(st, pc, Color.WHITE)
            _gv(st, pd, Color.WHITE)
    st.generate_tangents()
    var arr := st.commit().surface_get_arrays(0)
    return arr[Mesh.ARRAY_TANGENT]

func _build_ground(x0: float, z0: float) -> MeshInstance3D:
    if _ground_tangents.is_empty():
        _ground_tangents = _make_ground_tangents()
    var step := CHUNK / float(CELLS)
    var cols: Array = []
    for i in range(CELLS + 1):
        for j in range(CELLS + 1):
            cols.append(_ground_color(x0 + float(i) * step, z0 + float(j) * step))
    var n := CELLS * CELLS * 6
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    verts.resize(n)
    norms.resize(n)
    colors.resize(n)
    uvs.resize(n)
    var k := 0
    for i in range(CELLS):
        for j in range(CELLS):
            var ax := x0 + float(i) * step
            var az := z0 + float(j) * step
            var ia := i * (CELLS + 1) + j
            var ib := (i + 1) * (CELLS + 1) + j
            var ic := (i + 1) * (CELLS + 1) + j + 1
            var id := i * (CELLS + 1) + j + 1
            var pa := Vector3(ax, 0, az)
            var pb := Vector3(ax + step, 0, az)
            var pc := Vector3(ax + step, 0, az + step)
            var pd := Vector3(ax, 0, az + step)
            verts[k] = pa
            colors[k] = cols[ia]
            verts[k + 1] = pb
            colors[k + 1] = cols[ib]
            verts[k + 2] = pc
            colors[k + 2] = cols[ic]
            verts[k + 3] = pa
            colors[k + 3] = cols[ia]
            verts[k + 4] = pc
            colors[k + 4] = cols[ic]
            verts[k + 5] = pd
            colors[k + 5] = cols[id]
            k += 6
    for v in range(n):
        norms[v] = Vector3.UP
        uvs[v] = Vector2(verts[v].x, verts[v].z) / 4.0
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_TANGENT] = _ground_tangents
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = _ground_mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi

func _gv(st: SurfaceTool, p: Vector3, c: Color) -> void:
    st.set_color(c)
    st.set_normal(Vector3.UP)
    st.set_uv(Vector2(p.x, p.z) / 4.0)
    st.add_vertex(p)

func _make_grain_texture() -> ImageTexture:
    var n := 128
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 4242
    noise.frequency = 0.05
    noise.fractal_octaves = 4
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    for x in range(n):
        for y in range(n):
            var v := 0.78 + (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.22
            v += (rng.randf() - 0.5) * 0.08
            if rng.randf() < 0.05:
                v -= 0.14
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_normal_texture() -> ImageTexture:
    var n := 128
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 99
    noise.frequency = 0.09
    noise.fractal_octaves = 3
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    for x in range(n):
        for y in range(n):
            var v := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
            v = clampf(v + (rng.randf() - 0.5) * 0.25, 0.0, 1.0)
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.bump_map_to_normal_map(5.0)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_detail_texture() -> ImageTexture:
    var n := 128
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 555
    noise.frequency = 0.07
    noise.fractal_octaves = 4
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 12
    for x in range(n):
        for y in range(n):
            var v := 0.62 + (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.38
            v += (rng.randf() - 0.5) * 0.1
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

# ---------- Допоміжне для об'єктів ----------
func _begin(x: float, z: float, yaw: float) -> void:
    if _yaw_force > -100.0:
        yaw = _yaw_force
    _yaw = yaw
    _frame = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))

func _part(shape: String, lpos: Vector3, size: Vector3, lrot: Vector3, color: Color) -> void:
    var rot := Vector3(deg_to_rad(lrot.x), deg_to_rad(lrot.y), deg_to_rad(lrot.z))
    var b := Basis.from_euler(rot) * Basis.from_scale(size)
    var xf := _frame * Transform3D(b, lpos)
    var entry: Array = _parts[shape]
    entry[0].append(xf)
    entry[1].append(color)

func _col_cyl(local_pos: Vector3, r: float, h: float) -> void:
    var p: Vector3 = _frame * local_pos
    _shapes.append({"t": "cyl", "pos": Vector3(p.x, h * 0.5, p.z), "r": r, "h": h})

func _col_box(local_pos: Vector3, size: Vector3) -> void:
    var p: Vector3 = _frame * local_pos
    _shapes.append({"t": "box", "pos": Vector3(p.x, size.y * 0.5, p.z), "size": size, "yaw": _yaw})

func _jit(c: Color, amt: float, rng: RandomNumberGenerator) -> Color:
    var j := rng.randf_range(-amt, amt)
    return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), 1.0)

func _stone(rng: RandomNumberGenerator) -> Color:
    var g := rng.randf_range(0.42, 0.6)
    return Color(g, g * 0.97, g * 0.92)

func _wall_line(x0: float, z0: float, x1: float, z1: float, rng: RandomNumberGenerator, hmin: float, hmax: float, color: Color, gap: int = -1, gap_w: int = 1) -> void:
    var length := Vector2(x1 - x0, z1 - z0).length()
    var n := maxi(1, int(round(length / 1.6)))
    var seg := length / float(n)
    var along_x := absf(x1 - x0) >= absf(z1 - z0)
    for i in range(n):
        if gap >= 0 and i >= gap and i < gap + gap_w:
            continue
        var t := (float(i) + 0.5) / float(n)
        var cx := lerpf(x0, x1, t)
        var cz := lerpf(z0, z1, t)
        var h := rng.randf_range(hmin, hmax)
        var size := Vector3(seg, h, 0.55)
        if not along_x:
            size = Vector3(0.55, h, seg)
        _part("box", Vector3(cx, h * 0.5, cz), size, Vector3.ZERO, _jit(color, 0.04, rng))
        _col_box(Vector3(cx, 0.0, cz), size)

# ---------- Об'єкти ----------
func _spawn_prop(kind: String, x: float, z: float, rng: RandomNumberGenerator) -> void:
    match kind:
        "tree_oak": _p_tree_oak(x, z, rng)
        "tree_pine": _p_pine(x, z, rng, false)
        "tree_pine_snow": _p_pine(x, z, rng, true)
        "dead_tree": _p_dead_tree(x, z, rng)
        "bush": _p_bush(x, z, rng)
        "flowers": _p_flowers(x, z, rng)
        "tuft": _p_tuft(x, z, rng, false)
        "dry_tuft": _p_tuft(x, z, rng, true)
        "rock": _p_rock(x, z, rng, false)
        "rock_ice": _p_rock(x, z, rng, true)
        "stump": _p_stump(x, z, rng)
        "log": _p_log(x, z, rng)
        "mushroom": _p_mushroom(x, z, rng)
        "haystack": _p_haystack(x, z, rng)
        "fence": _p_fence(x, z, rng)
        "hut": _p_hut(x, z, rng)
        "cactus": _p_cactus(x, z, rng)
        "bones": _p_bones(x, z, rng)
        "dune": _p_dune(x, z, rng)
        "obelisk": _p_obelisk(x, z, rng)
        "snow_mound": _p_snow_mound(x, z, rng)
        "ice_crystal": _p_ice_crystal(x, z, rng)
        "tombstone": _p_tombstone(x, z, rng)
        "cross": _p_cross(x, z, rng)
        "crypt": _p_crypt(x, z, rng)
        "iron_fence": _p_iron_fence(x, z, rng)
        "ruin_wall": _p_ruin_wall(x, z, rng)
        "pillar": _p_pillar(x, z, rng)
        "rubble": _p_rubble(x, z, rng)
        "broken_house": _p_broken_house(x, z, rng)
        "arch": _p_arch(x, z, rng)
        "blood": _p_blood(x, z, rng)
        "corpse": _p_corpse(x, z, rng)
        "car": _p_car(x, z, rng)
        "streetlamp": _p_streetlamp(x, z, rng)
        "dumpster": _p_dumpster(x, z, rng)
        "barricade": _p_barricade(x, z, rng)
        "fire_barrel": _p_fire_barrel(x, z, rng)
        "ruined_building": _p_ruined_building(x, z, rng)
        "crack": _p_crack(x, z, rng)
        "road_mark": _p_road_mark(x, z, rng)
        "manhole": _p_manhole(x, z, rng)
        "sign": _p_sign(x, z, rng)
        "flames": _p_flames(x, z, rng)
        "embers": _p_embers(x, z, rng)
        "burning_tree": _p_burning_tree(x, z, rng)
        "charred_log": _p_charred_log(x, z, rng)
        "burnt_beams": _p_burnt_beams(x, z, rng)
        _: CampaignProps.spawn(self, kind, x, z, rng)

func _p_tree_oak(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.2, 3.6)
    var s := rng.randf_range(0.9, 1.3)
    var bark := _jit(Color(0.33, 0.21, 0.11), 0.04, rng)
    var leaf := _jit(Color(0.16, 0.45, 0.16), 0.06, rng)
    _part("cyl", Vector3(0, h * 0.5, 0), Vector3(0.5, h, 0.5), Vector3.ZERO, bark)
    _part("sphere", Vector3(0, h + 0.5, 0), Vector3(2.8, 2.3, 2.8) * s, Vector3.ZERO, leaf)
    _part("sphere", Vector3(0.9 * s, h - 0.1, 0.3), Vector3(1.9, 1.6, 1.9) * s, Vector3.ZERO, leaf.lightened(0.06))
    _part("sphere", Vector3(-0.8 * s, h, -0.5), Vector3(1.8, 1.5, 1.8) * s, Vector3.ZERO, leaf.darkened(0.06))
    _col_cyl(Vector3.ZERO, 0.38, 3.0)

func _p_pine(x: float, z: float, rng: RandomNumberGenerator, snowy: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(3.0, 5.0)
    var bark := _jit(Color(0.30, 0.19, 0.1), 0.04, rng)
    var leaf := _jit(Color(0.10, 0.32, 0.16), 0.05, rng)
    var white := Color(0.93, 0.95, 0.98)
    _part("cyl", Vector3(0, 0.7, 0), Vector3(0.45, 1.4, 0.45), Vector3.ZERO, bark)
    for i in range(3):
        var t := float(i) / 2.0
        var w := lerpf(2.8, 1.2, t)
        var y := 1.6 + t * (h - 2.6)
        var c := leaf
        if snowy:
            c = leaf.lerp(white, 0.35 + 0.3 * t)
        _part("cone", Vector3(0, y, 0), Vector3(w, 2.0, w), Vector3.ZERO, c)
    _col_cyl(Vector3.ZERO, 0.4, 3.0)

func _p_dead_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.0, 3.2)
    var bark := _jit(Color(0.30, 0.26, 0.22), 0.04, rng)
    _part("cyl", Vector3(0, h * 0.5, 0), Vector3(0.35, h, 0.35), Vector3.ZERO, bark)
    for i in range(3):
        var side := -1.0
        if i % 2 == 1:
            side = 1.0
        _part("cyl", Vector3(side * 0.35, h * (0.55 + 0.15 * float(i)), 0), Vector3(0.12, 1.1, 0.12), Vector3(0, 0, -side * 50.0), bark)
    _col_cyl(Vector3.ZERO, 0.3, 3.0)

func _p_bush(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := _jit(Color(0.2, 0.46, 0.15), 0.06, rng)
    var s := rng.randf_range(0.8, 1.4)
    _part("sphere", Vector3(0, 0.4 * s, 0), Vector3(1.3, 0.9, 1.2) * s, Vector3.ZERO, c)
    _part("sphere", Vector3(0.5 * s, 0.3 * s, 0.2), Vector3(0.9, 0.7, 0.9) * s, Vector3.ZERO, c.lightened(0.08))

func _p_flowers(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    var cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2), Color(0.95, 0.95, 0.95), Color(0.7, 0.3, 0.9)]
    for i in range(5):
        var ox := rng.randf_range(-0.7, 0.7)
        var oz := rng.randf_range(-0.7, 0.7)
        var c: Color = cols[rng.randi() % cols.size()]
        _part("cyl", Vector3(ox, 0.17, oz), Vector3(0.03, 0.35, 0.03), Vector3.ZERO, Color(0.2, 0.5, 0.15))
        _part("sphere", Vector3(ox, 0.38, oz), Vector3(0.16, 0.12, 0.16), Vector3.ZERO, c)

func _p_tuft(x: float, z: float, rng: RandomNumberGenerator, dry: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.25, 0.5, 0.15)
    if dry:
        c = Color(0.7, 0.6, 0.3)
    for i in range(4):
        var ox := rng.randf_range(-0.25, 0.25)
        var oz := rng.randf_range(-0.25, 0.25)
        var hh := rng.randf_range(0.35, 0.6)
        _part("cone", Vector3(ox, hh * 0.5, oz), Vector3(0.14, hh, 0.14), Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)), _jit(c, 0.06, rng))

func _p_rock(x: float, z: float, rng: RandomNumberGenerator, icy: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var s := rng.randf_range(0.7, 1.8)
    var c := _stone(rng)
    if icy:
        c = Color(0.7, 0.85, 0.95)
    _part("sphere", Vector3(0, s * 0.35, 0), Vector3(s * 1.3, s * 0.9, s * 1.1), Vector3(0, rng.randf() * 90.0, 0), c)
    _part("sphere", Vector3(s * 0.7, s * 0.2, s * 0.3), Vector3(s * 0.7, s * 0.5, s * 0.6), Vector3.ZERO, c.darkened(0.08))
    _col_cyl(Vector3.ZERO, s * 0.6, 1.2)

func _p_stump(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _part("cyl", Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.6), Vector3.ZERO, _jit(Color(0.38, 0.25, 0.14), 0.04, rng))
    _part("cyl", Vector3(0, 0.51, 0), Vector3(0.5, 0.03, 0.5), Vector3.ZERO, Color(0.6, 0.45, 0.28))
    _col_cyl(Vector3.ZERO, 0.32, 0.6)

func _p_log(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    _part("cyl", Vector3(0, 0.3, 0), Vector3(0.6, 2.4, 0.6), Vector3(0, 0, 90), _jit(Color(0.35, 0.23, 0.12), 0.04, rng))
    _col_box(Vector3.ZERO, Vector3(2.4, 0.6, 0.6))

func _p_mushroom(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    for i in range(3):
        var ox := rng.randf_range(-0.5, 0.5)
        var oz := rng.randf_range(-0.5, 0.5)
        var s := rng.randf_range(0.7, 1.4)
        var cap := Color(0.8, 0.15, 0.12)
        if rng.randf() < 0.4:
            cap = Color(0.65, 0.5, 0.3)
        _part("cyl", Vector3(ox, 0.12 * s, oz), Vector3(0.1, 0.25 * s, 0.1), Vector3.ZERO, Color(0.9, 0.88, 0.8))
        _part("sphere", Vector3(ox, 0.27 * s, oz), Vector3(0.34, 0.2, 0.34) * s, Vector3.ZERO, cap)

func _p_haystack(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _part("cyl", Vector3(0, 0.6, 0), Vector3(1.5, 1.2, 1.5), Vector3.ZERO, Color(0.8, 0.68, 0.25))
    _part("cone", Vector3(0, 1.5, 0), Vector3(1.6, 0.9, 1.6), Vector3.ZERO, Color(0.72, 0.6, 0.2))
    _col_cyl(Vector3.ZERO, 0.8, 1.8)

func _p_fence(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var wood := Color(0.42, 0.28, 0.14)
    for i in range(4):
        _part("cyl", Vector3(-1.5 + float(i), 0.5, 0), Vector3(0.14, 1.0, 0.14), Vector3.ZERO, wood)
    _part("box", Vector3(0, 0.4, 0), Vector3(3.2, 0.08, 0.08), Vector3.ZERO, wood.lightened(0.05))
    _part("box", Vector3(0, 0.8, 0), Vector3(3.2, 0.08, 0.08), Vector3.ZERO, wood.lightened(0.05))
    _col_box(Vector3.ZERO, Vector3(3.2, 1.0, 0.25))

func _p_hut(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _part("box", Vector3(0, 1.0, 0), Vector3(3.2, 2.0, 3.0), Vector3.ZERO, Color(0.72, 0.62, 0.45))
    _part("cone", Vector3(0, 2.7, 0), Vector3(4.4, 1.6, 4.4), Vector3.ZERO, Color(0.7, 0.58, 0.22))
    _part("box", Vector3(0, 0.7, -1.52), Vector3(0.8, 1.4, 0.08), Vector3.ZERO, Color(0.25, 0.15, 0.08))
    _part("box", Vector3(1.0, 1.3, -1.52), Vector3(0.5, 0.5, 0.08), Vector3.ZERO, Color(0.2, 0.25, 0.3))
    _col_box(Vector3(0, 0, 0), Vector3(3.2, 2.2, 3.0))

func _p_cactus(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(1.6, 2.8)
    var c := _jit(Color(0.2, 0.5, 0.22), 0.04, rng)
    _part("cyl", Vector3(0, h * 0.5, 0), Vector3(0.5, h, 0.5), Vector3.ZERO, c)
    var side := 1.0
    if rng.randf() < 0.5:
        side = -1.0
    _part("cyl", Vector3(side * 0.4, h * 0.5, 0), Vector3(0.28, 0.6, 0.28), Vector3(0, 0, 90), c)
    _part("cyl", Vector3(side * 0.7, h * 0.5 + 0.35, 0), Vector3(0.28, 0.75, 0.28), Vector3.ZERO, c)
    _col_cyl(Vector3.ZERO, 0.4, 2.0)

func _p_bones(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var b := Color(0.9, 0.87, 0.78)
    _part("sphere", Vector3(0, 0.15, 0), Vector3(0.3, 0.26, 0.3), Vector3.ZERO, b)
    for i in range(4):
        _part("box", Vector3(0.4 + 0.2 * float(i), 0.05, rng.randf_range(-0.2, 0.2)), Vector3(0.05, 0.05, 0.5), Vector3(0, rng.randf_range(-40, 40), 0), b)

func _p_dune(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _part("sphere", Vector3(0, 0.0, 0), Vector3(rng.randf_range(5.0, 9.0), rng.randf_range(1.6, 2.6), rng.randf_range(4.0, 7.0)), Vector3.ZERO, _jit(Color(0.82, 0.7, 0.42), 0.03, rng))

func _p_obelisk(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(3.0, 5.0)
    var c := Color(0.75, 0.65, 0.45)
    _part("box", Vector3(0, 0.2, 0), Vector3(1.4, 0.4, 1.4), Vector3.ZERO, c.darkened(0.1))
    _part("box", Vector3(0, h * 0.5, 0), Vector3(0.9, h, 0.9), Vector3.ZERO, c)
    _part("cone", Vector3(0, h + 0.3, 0), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, c.lightened(0.08))
    _col_box(Vector3.ZERO, Vector3(1.0, h, 1.0))

func _p_snow_mound(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _part("sphere", Vector3(0, 0.0, 0), Vector3(rng.randf_range(2.0, 4.0), rng.randf_range(0.8, 1.4), rng.randf_range(2.0, 3.5)), Vector3.ZERO, Color(0.97, 0.98, 1.0))

func _p_ice_crystal(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.6, 0.85, 1.0)
    _part("cone", Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6), Vector3.ZERO, c)
    _part("cone", Vector3(0.5, 0.5, 0.2), Vector3(0.4, 1.0, 0.4), Vector3(0, 0, -20), c.lightened(0.1))
    _part("cone", Vector3(-0.4, 0.55, -0.2), Vector3(0.4, 1.1, 0.4), Vector3(0, 0, 18), c.darkened(0.05))
    _col_cyl(Vector3.ZERO, 0.45, 1.5)

func _p_tombstone(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng)
    var tilt := rng.randf_range(-8.0, 8.0)
    _part("box", Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.2), Vector3(0, 0, tilt), c)
    _part("sphere", Vector3(0, 1.1, 0), Vector3(0.7, 0.5, 0.2), Vector3(0, 0, tilt), c)
    _part("box", Vector3(0, 0.05, 0.6), Vector3(0.6, 0.1, 1.0), Vector3.ZERO, Color(0.2, 0.17, 0.14))
    _col_box(Vector3.ZERO, Vector3(0.7, 1.2, 0.3))

func _p_cross(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := _stone(rng)
    var tilt := rng.randf_range(-6.0, 6.0)
    _part("box", Vector3(0, 0.7, 0), Vector3(0.15, 1.4, 0.15), Vector3(0, 0, tilt), c)
    _part("box", Vector3(0, 1.05, 0), Vector3(0.8, 0.15, 0.15), Vector3(0, 0, tilt), c)
    _col_cyl(Vector3.ZERO, 0.25, 1.4)

func _p_crypt(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := Color(0.32, 0.31, 0.34)
    _part("box", Vector3(0, 1.1, 0), Vector3(3.0, 2.2, 3.4), Vector3.ZERO, c)
    _part("box", Vector3(0, 2.35, 0), Vector3(3.4, 0.3, 3.8), Vector3.ZERO, c.darkened(0.1))
    _part("box", Vector3(0, 0.8, -1.72), Vector3(0.9, 1.6, 0.1), Vector3.ZERO, Color(0.05, 0.04, 0.05))
    _col_box(Vector3.ZERO, Vector3(3.2, 2.5, 3.6))

func _p_iron_fence(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := Color(0.12, 0.12, 0.14)
    for i in range(5):
        _part("cyl", Vector3(-1.6 + 0.8 * float(i), 0.65, 0), Vector3(0.07, 1.3, 0.07), Vector3.ZERO, c)
        _part("cone", Vector3(-1.6 + 0.8 * float(i), 1.4, 0), Vector3(0.14, 0.3, 0.14), Vector3.ZERO, c)
    _part("box", Vector3(0, 0.3, 0), Vector3(3.3, 0.06, 0.06), Vector3.ZERO, c)
    _part("box", Vector3(0, 1.0, 0), Vector3(3.3, 0.06, 0.06), Vector3.ZERO, c)
    _col_box(Vector3.ZERO, Vector3(3.3, 1.3, 0.2))

func _p_ruin_wall(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var length := rng.randf_range(3.2, 8.0)
    _wall_line(-length * 0.5, 0.0, length * 0.5, 0.0, rng, 0.8, 3.0, _stone(rng))

func _p_pillar(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.0, 4.0)
    var c := _stone(rng).lightened(0.1)
    _part("box", Vector3(0, 0.15, 0), Vector3(1.1, 0.3, 1.1), Vector3.ZERO, c.darkened(0.1))
    _part("cyl", Vector3(0, 0.3 + h * 0.5, 0), Vector3(0.7, h, 0.7), Vector3.ZERO, c)
    _part("cyl", Vector3(1.4, 0.35, 0.4), Vector3(0.7, 1.0, 0.7), Vector3(0, 0, 90), c.darkened(0.05))
    _part("box", Vector3(0.6, 0.12, -0.7), Vector3(0.4, 0.25, 0.3), Vector3(0, 30, 0), c.darkened(0.12))
    _col_cyl(Vector3.ZERO, 0.5, 2.5)

func _p_rubble(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    for i in range(rng.randi_range(4, 7)):
        var s := rng.randf_range(0.2, 0.5)
        _part("box", Vector3(rng.randf_range(-1.2, 1.2), s * 0.4, rng.randf_range(-1.2, 1.2)), Vector3(s, s * 0.7, s * 1.2), Vector3(0, rng.randf() * 180.0, rng.randf_range(-20, 20)), _stone(rng))

func _p_broken_house(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng).lightened(0.05)
    _part("box", Vector3(0, 0.05, 0), Vector3(7.0, 0.1, 6.0), Vector3.ZERO, Color(0.28, 0.25, 0.22))
    _wall_line(-3.5, -3.0, 3.5, -3.0, rng, 1.2, 2.8, c, 1, 2)  # фасад із широким проходом (3.5 м)
    _wall_line(-3.5, 3.0, 3.5, 3.0, rng, 0.8, 2.6, c, 2, 2)    # задня стіна з проломом: будинок наскрізний
    _wall_line(-3.5, -3.0, -3.5, 3.0, rng, 0.8, 2.4, c)
    _wall_line(3.5, -3.0, 3.5, 3.0, rng, 0.6, 2.2, c, 1, 2)    # бічний пролом
    var wood := Color(0.35, 0.22, 0.12)
    _part("box", Vector3(-1.0, 2.0, 0.5), Vector3(0.18, 0.18, 5.0), Vector3(0, 20, 12), wood)
    _part("box", Vector3(1.2, 1.4, -0.4), Vector3(0.18, 0.18, 4.0), Vector3(0, -30, -18), wood)
    for i in range(6):
        var s := rng.randf_range(0.2, 0.45)
        _part("box", Vector3(rng.randf_range(-2.8, 2.8), s * 0.4, rng.randf_range(-2.4, 2.4)), Vector3(s, s * 0.7, s), Vector3(0, rng.randf() * 180.0, 0), _stone(rng))

func _p_arch(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng).lightened(0.08)
    _part("box", Vector3(-1.6, 1.8, 0), Vector3(0.8, 3.6, 0.8), Vector3.ZERO, c)
    _part("box", Vector3(1.6, 1.8, 0), Vector3(0.8, 3.6, 0.8), Vector3.ZERO, c)
    _part("box", Vector3(0, 3.95, 0), Vector3(4.2, 0.7, 0.9), Vector3.ZERO, c.darkened(0.05))
    _col_box(Vector3(-1.6, 0, 0), Vector3(0.9, 3.6, 0.9))
    _col_box(Vector3(1.6, 0, 0), Vector3(0.9, 3.6, 0.9))

# ---------- Кров, трупи, місто ----------
func _p_blood(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(rng.randf_range(0.2, 0.32), 0.015, 0.015)
    var s := rng.randf_range(0.8, 2.2)
    _part("sphere", Vector3(0, 0.02, 0), Vector3(s * 1.4, 0.03, s), Vector3.ZERO, c)
    for i in range(rng.randi_range(2, 4)):
        var r := rng.randf_range(0.2, 0.6)
        _part("sphere", Vector3(rng.randf_range(-s, s), 0.022, rng.randf_range(-s, s) * 0.8), Vector3(r, 0.03, r * 0.8), Vector3.ZERO, c.darkened(0.1))

func _p_corpse(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var skin := _jit(Color(0.55, 0.5, 0.42), 0.05, rng)
    var cloth := Color.from_hsv(rng.randf(), 0.3, 0.32)
    _part("sphere", Vector3(0, 0.02, 0), Vector3(2.2, 0.03, 1.6), Vector3.ZERO, Color(0.24, 0.015, 0.015))
    _part("box", Vector3(0, 0.14, 0), Vector3(0.55, 0.26, 0.9), Vector3(0, 0, 0), cloth)
    _part("sphere", Vector3(0, 0.15, -0.62), Vector3(0.32, 0.3, 0.34), Vector3.ZERO, skin)
    _part("box", Vector3(-0.15, 0.08, 0.85), Vector3(0.18, 0.16, 0.85), Vector3(0, rng.randf_range(-12, 12), 0), cloth.darkened(0.25))
    _part("box", Vector3(0.17, 0.08, 0.8), Vector3(0.18, 0.16, 0.85), Vector3(0, rng.randf_range(-12, 12), 0), cloth.darkened(0.25))
    _part("box", Vector3(-0.42, 0.1, -0.2), Vector3(0.14, 0.14, 0.7), Vector3(0, rng.randf_range(-35, 35), 0), skin.darkened(0.15))
    _part("box", Vector3(0.42, 0.1, -0.1), Vector3(0.14, 0.14, 0.7), Vector3(0, rng.randf_range(-35, 35), 0), skin.darkened(0.15))
    _part("sphere", Vector3(0.1, 0.27, -0.1), Vector3(0.3, 0.06, 0.3), Vector3.ZERO, Color(0.3, 0.02, 0.02))

func _p_car(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var paint := Color.from_hsv(rng.randf(), 0.4, 0.34)
    if rng.randf() < 0.35:
        paint = Color(0.07, 0.065, 0.065)
    var glass := Color(0.05, 0.07, 0.09)
    _part("box", Vector3(0, 0.62, 0), Vector3(4.2, 0.7, 1.8), Vector3.ZERO, paint)
    _part("box", Vector3(-0.2, 1.17, 0), Vector3(2.2, 0.55, 1.6), Vector3.ZERO, glass)
    _part("box", Vector3(-0.2, 1.48, 0), Vector3(2.0, 0.08, 1.55), Vector3.ZERO, paint.darkened(0.1))
    for sx in [-1.3, 1.3]:
        for sz in [-0.9, 0.9]:
            _part("cyl", Vector3(float(sx), 0.32, float(sz)), Vector3(0.64, 0.3, 0.64), Vector3(90, 0, 0), Color(0.04, 0.04, 0.04))
    _part("box", Vector3(0.3, 0.7, 0.92), Vector3(1.6, 0.35, 0.04), Vector3.ZERO, Color(0.35, 0.18, 0.1))
    _part("box", Vector3(1.4, 1.0, 0.0), Vector3(0.5, 0.06, 1.6), Vector3(0, 0, rng.randf_range(10, 35)), paint.darkened(0.15))
    _part("sphere", Vector3(-0.3, 1.18, -0.86), Vector3(0.5, 0.4, 0.06), Vector3.ZERO, Color(0.25, 0.02, 0.02))
    _col_box(Vector3.ZERO, Vector3(4.2, 1.5, 1.8))

func _p_streetlamp(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var metal := Color(0.16, 0.17, 0.18)
    if rng.randf() < 0.3:
        _part("cyl", Vector3(0, 0.12, 0), Vector3(0.18, 4.5, 0.18), Vector3(90, 0, 0), metal)
        _part("box", Vector3(0, 0.1, -2.4), Vector3(0.5, 0.12, 0.25), Vector3.ZERO, Color(0.3, 0.3, 0.28))
    else:
        _part("cyl", Vector3(0, 2.3, 0), Vector3(0.18, 4.6, 0.18), Vector3.ZERO, metal)
        _part("box", Vector3(0.5, 4.55, 0), Vector3(1.1, 0.1, 0.1), Vector3.ZERO, metal)
        _part("box", Vector3(1.0, 4.45, 0), Vector3(0.5, 0.12, 0.25), Vector3.ZERO, Color(0.35, 0.34, 0.3))
        _col_cyl(Vector3.ZERO, 0.2, 4.0)

func _p_dumpster(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.1, 0.2, 0.13).darkened(rng.randf_range(0.0, 0.3))
    _part("box", Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 0.95), Vector3.ZERO, c)
    _part("box", Vector3(0.1, 1.14, -0.1), Vector3(1.95, 0.08, 1.0), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-6, 6)), c.darkened(0.15))
    _col_box(Vector3.ZERO, Vector3(1.9, 1.1, 0.95))

func _p_barricade(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var conc := Color(0.4, 0.4, 0.38)
    _part("box", Vector3(-1.2, 0.45, 0), Vector3(2.2, 0.9, 0.5), Vector3(0, rng.randf_range(-8, 8), 0), _jit(conc, 0.04, rng))
    _part("box", Vector3(1.2, 0.45, 0.1), Vector3(2.2, 0.9, 0.5), Vector3(0, rng.randf_range(-8, 8), 0), _jit(conc, 0.04, rng))
    for i in range(4):
        _part("sphere", Vector3(-1.5 + 0.9 * float(i), 1.0, 0.0), Vector3(0.7, 0.35, 0.45), Vector3(0, rng.randf_range(-20, 20), 0), Color(0.42, 0.36, 0.24))
    _col_box(Vector3(0, 0, 0.05), Vector3(4.6, 1.0, 0.6))

func _p_fire_barrel(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _part("cyl", Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), Vector3.ZERO, Color(0.2, 0.12, 0.08))
    _part("cone", Vector3(0, 1.3, 0), Vector3(0.5, 0.8, 0.5), Vector3.ZERO, Color(1.0, 0.5, 0.1))
    _part("sphere", Vector3(0.05, 1.1, 0), Vector3(0.4, 0.35, 0.4), Vector3.ZERO, Color(1.0, 0.8, 0.25))
    _col_cyl(Vector3.ZERO, 0.4, 1.0)
    if _lights.is_empty():
        _lights.append({"pos": Vector3(x, 1.7, z), "color": Color(1.0, 0.5, 0.2), "energy": 2.4, "range": 11.0})

# ---------- Пожежа: вогонь і спалені об'єкти ----------
func _fire_light(x: float, z: float, y: float) -> void:
    if _lights.is_empty():
        _lights.append({"pos": Vector3(x, y, z), "color": Color(1.0, 0.45, 0.15), "energy": 2.6, "range": 13.0})

# Вогнище на землі: кілька язиків полум'я над розжареним попелом (без колізії — можна пройти, шкоди немає).
func _p_flames(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    for i in range(rng.randi_range(2, 4)):
        var ox := rng.randf_range(-0.6, 0.6)
        var oz := rng.randf_range(-0.6, 0.6)
        var s := rng.randf_range(1.1, 2.2)
        _part("cone", Vector3(ox, 0.85 * s, oz), Vector3(0.75, 1.7, 0.75) * s, Vector3.ZERO, Color(1.0, 0.38, 0.06))
        _part("cone", Vector3(ox, 0.6 * s, oz), Vector3(0.45, 1.2, 0.45) * s, Vector3.ZERO, Color(1.0, 0.72, 0.18))
    _part("sphere", Vector3(0, 0.25, 0), Vector3(0.7, 0.4, 0.7), Vector3.ZERO, Color(1.0, 0.9, 0.4))
    _fire_light(x, z, 1.5)

# Жарини: розжарена земля з тліючими грудками.
func _p_embers(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    for i in range(rng.randi_range(3, 6)):
        var sz := rng.randf_range(0.18, 0.4)
        var heat := Color(1.0, rng.randf_range(0.25, 0.55), 0.05)
        _part("sphere", Vector3(rng.randf_range(-0.9, 0.9), sz * 0.3, rng.randf_range(-0.9, 0.9)), Vector3(sz, sz * 0.6, sz), Vector3.ZERO, heat)

# Палаюче дерево: почорнілий стовбур із полум'ям у кроні.
func _p_burning_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.6, 3.8)
    var char_c := _jit(Color(0.08, 0.06, 0.05), 0.02, rng)
    _part("cyl", Vector3(0, h * 0.5, 0), Vector3(0.45, h, 0.45), Vector3.ZERO, char_c)
    for i in range(3):
        var side := -1.0
        if i % 2 == 1:
            side = 1.0
        _part("cyl", Vector3(side * 0.4, h * (0.55 + 0.12 * float(i)), 0), Vector3(0.14, 1.2, 0.14), Vector3(0, 0, -side * 50.0), char_c)
    _part("cone", Vector3(0, h + 0.5, 0), Vector3(1.4, 2.0, 1.4), Vector3.ZERO, Color(1.0, 0.36, 0.05))
    _part("cone", Vector3(0, h + 0.3, 0), Vector3(0.8, 1.3, 0.8), Vector3.ZERO, Color(1.0, 0.72, 0.18))
    _part("cone", Vector3(0.7, h * 0.7, 0.2), Vector3(0.6, 1.0, 0.6), Vector3.ZERO, Color(1.0, 0.45, 0.08))
    _col_cyl(Vector3.ZERO, 0.35, 3.0)
    _fire_light(x, z, h + 0.6)

# Обвуглена колода з жариною на зламі.
func _p_charred_log(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    _part("cyl", Vector3(0, 0.3, 0), Vector3(0.6, 2.6, 0.6), Vector3(0, 0, 90), _jit(Color(0.07, 0.055, 0.045), 0.02, rng))
    _part("sphere", Vector3(1.0, 0.45, 0), Vector3(0.5, 0.25, 0.4), Vector3.ZERO, Color(1.0, 0.35, 0.06))
    _part("sphere", Vector3(-0.4, 0.5, 0.1), Vector3(0.3, 0.18, 0.3), Vector3.ZERO, Color(1.0, 0.5, 0.1))
    _col_box(Vector3.ZERO, Vector3(2.6, 0.6, 0.6))

# Обгорілі балки: кілька почорнілих брусів, що стирчать із попелу.
func _p_burnt_beams(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var dark := _jit(Color(0.09, 0.07, 0.06), 0.02, rng)
    for i in range(rng.randi_range(2, 4)):
        var bh := rng.randf_range(1.4, 3.0)
        _part("box", Vector3(rng.randf_range(-0.9, 0.9), bh * 0.5, rng.randf_range(-0.9, 0.9)), Vector3(0.28, bh, 0.28), Vector3(rng.randf_range(-14.0, 14.0), rng.randf() * 180.0, rng.randf_range(-18.0, 18.0)), dark)
    _part("cyl", Vector3(0, 0.03, 0), Vector3(2.2, 0.04, 2.2), Vector3.ZERO, Color(0.14, 0.05, 0.03))
    _part("sphere", Vector3(0.3, 0.15, 0.2), Vector3(0.3, 0.2, 0.3), Vector3.ZERO, Color(1.0, 0.4, 0.08))
    _col_cyl(Vector3.ZERO, 0.9, 1.5)

func _p_ruined_building(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _jit(Color(0.3, 0.22, 0.19), 0.04, rng)
    var w := rng.randf_range(8.0, 11.0)
    var d := rng.randf_range(6.0, 8.0)
    _part("box", Vector3(0, 0.05, 0), Vector3(w, 0.1, d), Vector3.ZERO, Color(0.14, 0.13, 0.13))
    _wall_line(-w * 0.5, -d * 0.5, w * 0.5, -d * 0.5, rng, 3.0, 7.0, c, 2, 2)
    _wall_line(-w * 0.5, d * 0.5, w * 0.5, d * 0.5, rng, 2.5, 6.0, c, 3, 2)   # задній пролом
    _wall_line(-w * 0.5, -d * 0.5, -w * 0.5, d * 0.5, rng, 2.0, 6.5, c)
    _wall_line(w * 0.5, -d * 0.5, w * 0.5, d * 0.5, rng, 1.0, 5.0, c, 1, 2)
    _part("box", Vector3(1.0, 2.2, 0.5), Vector3(3.5, 0.25, 2.5), Vector3(0, 10, 18), Color(0.28, 0.27, 0.27))
    for i in range(6):
        var s := rng.randf_range(0.2, 0.5)
        _part("box", Vector3(rng.randf_range(-w * 0.4, w * 0.4), s * 0.4, rng.randf_range(-d * 0.4, d * 0.4)), Vector3(s, s * 0.7, s), Vector3(0, rng.randf() * 180.0, 0), _stone(rng))

func _p_crack(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    for i in range(3):
        _part("box", Vector3(rng.randf_range(-1.0, 1.0), 0.015, rng.randf_range(-1.0, 1.0)), Vector3(rng.randf_range(1.0, 3.5), 0.02, 0.06), Vector3(0, rng.randf() * 180.0, 0), Color(0.04, 0.04, 0.045))

func _p_road_mark(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    for i in range(4):
        _part("box", Vector3(-3.0 + 2.0 * float(i), 0.02, 0), Vector3(1.0, 0.02, 0.16), Vector3.ZERO, Color(0.55, 0.5, 0.2))

func _p_manhole(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _part("cyl", Vector3(0, 0.02, 0), Vector3(0.9, 0.03, 0.9), Vector3.ZERO, Color(0.07, 0.07, 0.08))

func _p_sign(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _part("cyl", Vector3(0, 1.2, 0), Vector3(0.08, 2.4, 0.08), Vector3.ZERO, Color(0.2, 0.2, 0.22))
    _part("box", Vector3(0, 2.3, 0), Vector3(0.8, 0.8, 0.05), Vector3(0, 0, rng.randf_range(-15, 15)), Color(0.5, 0.1, 0.08))
    _col_cyl(Vector3.ZERO, 0.15, 2.4)

# ---------- Стежка від воріт, розвилка й пам'ятні місця ----------
# Головна стежка йде від воріт замку на північ (-Z) до розвилки, звідти — продовження вглиб карти
# і дві бокові стежки. Кожна закінчується пам'ятним місцем свого біому. Усе це дальніше за межі
# видимості, тож відкривається поступово — коли гравець іде стежкою.
func _trail_points(a: Vector2, b: Vector2, bend: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var ab := b - a
    var dist := ab.length()
    var nrm := Vector2(-ab.y, ab.x) / maxf(dist, 0.001)
    var n := maxi(4, int(dist / 2.5))
    for i in range(n + 1):
        var u := float(i) / float(n)
        pts.append(a + ab * u + nrm * bend * sin(u * PI) * sin(u * TAU))
    return pts

func _build_trails() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 777
    var hub_z := clampf(arena_radius * 0.42, 36.0, 70.0)
    var start := Vector2(0.0, -17.0)
    var hub := Vector2(rng.randf_range(-6.0, 6.0), -hub_z)
    var far := Vector2(rng.randf_range(-14.0, 14.0), -(arena_radius - 18.0))
    var sgn := 1.0 if rng.randf() < 0.5 else -1.0
    var routes: Array = [[start, hub, 7.0 * sgn], [hub, far, -8.0 * sgn]]
    var ends: Array = [far]
    for side in [-1.0, 1.0]:
        var ang := -PI * 0.5 + float(side) * rng.randf_range(0.95, 1.25)
        var e := Vector2(cos(ang), sin(ang)) * arena_radius * rng.randf_range(0.62, 0.74)
        routes.append([hub, e, 6.0 * float(side)])
        ends.append(e)
    for r in routes:
        var ra: Vector2 = r[0]
        var rb: Vector2 = r[1]
        _trails.append(_trail_points(ra, rb, float(r[2])))

    # зони без дерев і каміння: уздовж стежок
    for tp in _trails:
        var pts: PackedVector2Array = tp
        var i := 0
        while i < pts.size() - 1:
            var j := mini(i + 3, pts.size() - 1)
            clear_zones.append([pts[i], pts[j], 3.6])
            i += 3

    # предмети вздовж стежки: по одному кожні 7-11 м, з випадкового боку
    var drng := RandomNumberGenerator.new()
    drng.seed = world_seed + 4001
    for tp in _trails:
        var pts2: PackedVector2Array = tp
        var acc := 0.0
        var next := 6.0
        for i in range(1, pts2.size()):
            acc += pts2[i].distance_to(pts2[i - 1])
            if acc < next:
                continue
            acc = 0.0
            next = drng.randf_range(7.0, 11.0)
            var dir := (pts2[mini(i + 1, pts2.size() - 1)] - pts2[i - 1]).normalized()
            var nn := Vector2(-dir.y, dir.x)
            var side2 := 1.0 if drng.randf() < 0.5 else -1.0
            var pos := pts2[i] + nn * side2 * drng.randf_range(2.5, 3.6)
            if pos.length() > arena_radius - 6.0 or pos.distance_to(hub) < 11.0:
                continue
            var near_end := false
            for e2 in ends:
                if pos.distance_to(e2) < 11.0:
                    near_end = true
            if near_end:
                continue
            _trail_dress.append({"pos": pos, "kind": _pick(TRAIL_PROPS[_biome_index(biome_at(pos.x, pos.y))], drng)})

    # розвилка й пам'ятні місця
    landmarks = ends.duplicate()
    _add_set(hub, HUB_SET, rng.randf() * TAU, 7.0)
    for e3 in ends:
        var ep: Vector2 = e3
        _add_set(ep, LANDMARKS[_biome_index(biome_at(ep.x, ep.y))], rng.randf() * TAU, 6.5)
    _build_trail_mesh()

func _add_set(o: Vector2, items: Array, rot: float, disc_r: float) -> void:
    clear_zones.append([o, o, 11.0])
    _discs.append([o, disc_r])
    for it in items:
        var off := Vector2(float(it[1]), float(it[2])).rotated(rot)
        _set_props.append({"pos": o + off, "kind": String(it[0])})

# Стежка й майданчики — одна сітка з вершинними кольорами: посередині втоптана земля, до країв — колір землі біому.
func _tv(st: SurfaceTool, p: Vector2, c: Color) -> void:
    st.set_color(c)
    st.set_normal(Vector3.UP)
    st.set_uv(p / 4.0)
    st.add_vertex(Vector3(p.x, TRAIL_Y, p.y))

func _dirt_at(p: Vector2) -> Color:
    var c: Color = TRAIL_COL[_biome_index(biome_at(p.x, p.y))]
    var j := noise_d.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.04
    return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), 1.0)

func _build_trail_mesh() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tp in _trails:
        var pts: PackedVector2Array = tp
        var rows: Array = []     # на кожну точку: [PackedVector2Array(4), PackedColorArray(4)]
        for i in range(pts.size()):
            var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
            var nn := Vector2(-d.y, d.x)
            var hw := TRAIL_HALF + 0.35 * noise_d.get_noise_2d(pts[i].x * 3.0, pts[i].y * 3.0)
            var dirt := _dirt_at(pts[i])
            var edge: Color = Biomes.DATA[_biome_index(biome_at(pts[i].x, pts[i].y))]["ground"]
            var rp := PackedVector2Array([pts[i] - nn * (hw + 0.9), pts[i] - nn * hw * 0.55, pts[i] + nn * hw * 0.55, pts[i] + nn * (hw + 0.9)])
            var rc := PackedColorArray([edge, dirt, dirt, edge])
            rows.append([rp, rc])
        for i in range(rows.size() - 1):
            var ra: Array = rows[i]
            var rb: Array = rows[i + 1]
            var pa: PackedVector2Array = ra[0]
            var ca: PackedColorArray = ra[1]
            var pb: PackedVector2Array = rb[0]
            var cb: PackedColorArray = rb[1]
            for k in range(3):
                _tv(st, pa[k + 1], ca[k + 1])
                _tv(st, pa[k], ca[k])
                _tv(st, pb[k], cb[k])
                _tv(st, pa[k + 1], ca[k + 1])
                _tv(st, pb[k], cb[k])
                _tv(st, pb[k + 1], cb[k + 1])
    # майданчики на розвилці й у пам'ятних місцях
    for ds in _discs:
        var o: Vector2 = ds[0]
        var rad := float(ds[1])
        var dirt_c := _dirt_at(o)
        var edge_c: Color = Biomes.DATA[_biome_index(biome_at(o.x, o.y))]["ground"]
        var segs := 22
        for s in range(segs):
            var a0 := TAU * float(s) / float(segs)
            var a1 := TAU * float(s + 1) / float(segs)
            var r0 := rad * (0.85 + 0.15 * noise_d.get_noise_2d(o.x + cos(a0) * 9.0, o.y + sin(a0) * 9.0))
            var r1 := rad * (0.85 + 0.15 * noise_d.get_noise_2d(o.x + cos(a1) * 9.0, o.y + sin(a1) * 9.0))
            _tv(st, o, dirt_c)
            _tv(st, o + Vector2(cos(a0), sin(a0)) * r0, edge_c)
            _tv(st, o + Vector2(cos(a1), sin(a1)) * r1, edge_c)
    st.generate_tangents()
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _ground_mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)

# ---------- Стартова площа (кам'яна дорога) ----------
func _build_start_area() -> void:
    var plaza := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(32, 32)
    plaza.mesh = pm
    var m := StandardMaterial3D.new()
    m.albedo_texture = _make_stone_texture()
    m.uv1_scale = Vector3(4, 4, 1)
    m.roughness = 0.95
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    if forced_biome == Biomes.CITY:
        m.albedo_color = Color(0.42, 0.42, 0.46)
    plaza.material_override = m
    plaza.position.y = 0.03
    plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(plaza)

    # колодязь, ящики, бочки, смолоскипи
    var body := StaticBody3D.new()
    body.collision_layer = 4
    body.collision_mask = 0
    add_child(body)
    var stone := Color(0.5, 0.48, 0.45)
    var wood := Color(0.4, 0.26, 0.13)
    if forced_biome != Biomes.CITY:
        var well := Node3D.new()
        well.position = Vector3(-8.0, 0.0, -7.0)
        add_child(well)
        Util.add_mesh(well, Util.cylinder(1.0, 1.1, 0.9), stone, Vector3(0, 0.45, 0))
        Util.add_mesh(well, Util.cylinder(0.8, 0.8, 0.05), Color(0.05, 0.1, 0.2), Vector3(0, 0.88, 0))
        Util.add_mesh(well, Util.box(Vector3(0.12, 2.0, 0.12)), wood, Vector3(-0.95, 1.5, 0))
        Util.add_mesh(well, Util.box(Vector3(0.12, 2.0, 0.12)), wood, Vector3(0.95, 1.5, 0))
        Util.add_mesh(well, Util.cylinder(0.0, 1.5, 0.8), Color(0.55, 0.2, 0.15), Vector3(0, 2.8, 0))
        _static_cyl(body, Vector3(-8.0, 0.0, -7.0), 1.1, 1.0)
    else:
        # у місті замість колодязя — розбита машина
        var car := Node3D.new()
        car.position = Vector3(-8.0, 0.0, -7.0)
        car.rotation_degrees.y = 25.0
        add_child(car)
        var paint := Color(0.3, 0.08, 0.07)
        Util.add_mesh(car, Util.box(Vector3(4.2, 0.7, 1.8)), paint, Vector3(0, 0.62, 0))
        Util.add_mesh(car, Util.box(Vector3(2.2, 0.55, 1.6)), Color(0.05, 0.07, 0.09), Vector3(-0.2, 1.17, 0), Vector3.ZERO, 0.2)
        Util.add_mesh(car, Util.box(Vector3(2.0, 0.08, 1.55)), paint.darkened(0.1), Vector3(-0.2, 1.48, 0))
        for sx in [-1.3, 1.3]:
            for sz in [-0.9, 0.9]:
                Util.add_mesh(car, Util.cylinder(0.32, 0.32, 0.3), Color(0.04, 0.04, 0.04), Vector3(float(sx), 0.32, float(sz)), Vector3(90, 0, 0))
        _static_box(body, Vector3(-8.0, 0.0, -7.0), Vector3(3.6, 1.5, 3.0))
    for p in [Vector3(7.0, 0.0, -9.0), Vector3(8.4, 0.0, -9.2), Vector3(7.6, 0.0, -7.7)]:
        var crate := Node3D.new()
        crate.position = p
        add_child(crate)
        Util.add_mesh(crate, Util.box(Vector3(1.0, 1.0, 1.0)), wood.lightened(0.1), Vector3(0, 0.5, 0))
        Util.add_mesh(crate, Util.box(Vector3(1.05, 0.1, 1.05)), wood.darkened(0.2), Vector3(0, 0.95, 0))
        _static_box(body, p, Vector3(1.0, 1.0, 1.0))
    for p in [Vector3(9.5, 0.0, -6.0), Vector3(-9.5, 0.0, 6.0)]:
        var barrel := Node3D.new()
        barrel.position = p
        add_child(barrel)
        Util.add_mesh(barrel, Util.cylinder(0.45, 0.45, 1.0), wood, Vector3(0, 0.5, 0))
        Util.add_mesh(barrel, Util.cylinder(0.47, 0.47, 0.08), Color(0.2, 0.2, 0.22), Vector3(0, 0.25, 0))
        Util.add_mesh(barrel, Util.cylinder(0.47, 0.47, 0.08), Color(0.2, 0.2, 0.22), Vector3(0, 0.75, 0))
        _static_cyl(body, p, 0.5, 1.0)
    for p in [Vector3(-6.0, 0.0, 9.0), Vector3(6.0, 0.0, 9.0)]:
        var torch := Node3D.new()
        torch.position = p
        add_child(torch)
        Util.add_mesh(torch, Util.cylinder(0.06, 0.08, 2.2), wood, Vector3(0, 1.1, 0))
        Util.add_mesh(torch, Util.sphere(0.18), Color(1.0, 0.55, 0.1), Vector3(0, 2.3, 0), Vector3.ZERO, 0.4, 4.0)
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.6, 0.25)
        l.omni_range = 9.0
        l.light_energy = 1.6
        l.position = Vector3(0, 2.3, 0)
        torch.add_child(l)
        _static_cyl(body, p, 0.2, 2.2)

# Головна дорога до табору лицаря: земляна смуга, ліхтарі з обох боків, вогняні бочки, табір із багаттям і маяком.
func _build_road() -> void:
    # земляна промальована дорога з коліями, м'якими краями й пучками трави
    var m := StandardMaterial3D.new()
    m.albedo_texture = _make_dirt_texture(true)
    m.albedo_color = Color(1.0, 0.97, 0.93)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.uv1_scale = Vector3(1.0, corridor_len / 9.0, 1)
    m.roughness = 1.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var road := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(ROAD_W + 1.6, corridor_len)     # трохи ширша за смугу: краї розмиті
    road.mesh = pm
    road.material_override = m
    road.position = Vector3(0, 0.025, -16.0 - corridor_len * 0.5 + 0.0)
    road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(road)

    var body := StaticBody3D.new()
    body.collision_layer = 4
    body.collision_mask = 0
    add_child(body)
    var metal := Color(0.16, 0.17, 0.18)
    var z := -26.0
    var side := 1.0
    while z > -corridor_len + 8.0:
        var lamp := Node3D.new()
        lamp.position = Vector3(side * (ROAD_W * 0.5 + 0.6), 0.0, z)
        add_child(lamp)
        Util.add_mesh(lamp, Util.cylinder(0.09, 0.11, 4.4), metal, Vector3(0, 2.2, 0))
        Util.add_mesh(lamp, Util.sphere(0.28), Color(1.0, 0.7, 0.35), Vector3(0, 4.5, 0), Vector3.ZERO, 0.4, 3.0)
        var l: OmniLight3D = FlickerLight.new()
        l.light_color = Color(1.0, 0.68, 0.34)
        l.omni_range = 12.0
        l.light_energy = 1.4
        l.position = Vector3(0, 4.4, 0)
        lamp.add_child(l)
        _static_cyl(body, lamp.position, 0.2, 4.0)
        side = -side
        z -= 28.0

    # табір лицаря
    var cz := -corridor_len
    var camp := MeshInstance3D.new()
    var cpm := PlaneMesh.new()
    cpm.size = Vector2(28, 28)
    camp.mesh = cpm
    var camp_mat: StandardMaterial3D = m.duplicate()
    camp_mat.albedo_texture = _make_dirt_texture(false)
    camp_mat.uv1_scale = Vector3(1, 1, 1)
    camp.material_override = camp_mat
    camp.position = Vector3(0, 0.03, cz)
    camp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(camp)
    var wood := Color(0.4, 0.26, 0.13)
    for p in [Vector3(-8, 0, cz - 9), Vector3(-4, 0, cz - 10), Vector3(4, 0, cz - 10), Vector3(8, 0, cz - 9), Vector3(-10, 0, cz - 3), Vector3(10, 0, cz - 3)]:
        var bar := Node3D.new()
        bar.position = p
        bar.rotation_degrees.y = randf_range(-20, 20)
        add_child(bar)
        Util.add_mesh(bar, Util.box(Vector3(3.0, 1.1, 0.4)), wood, Vector3(0, 0.55, 0))
        Util.add_mesh(bar, Util.box(Vector3(0.3, 1.5, 0.3)), wood.darkened(0.2), Vector3(-1.2, 0.75, 0))
        Util.add_mesh(bar, Util.box(Vector3(0.3, 1.5, 0.3)), wood.darkened(0.2), Vector3(1.2, 0.75, 0))
        _static_box(body, p, Vector3(3.0, 1.1, 0.5))
    var fire := Node3D.new()
    fire.position = Vector3(3.0, 0, cz + 1.0)
    add_child(fire)
    Util.add_mesh(fire, Util.cylinder(0.6, 0.7, 0.3), Color(0.25, 0.23, 0.22), Vector3(0, 0.15, 0))
    Util.add_mesh(fire, Util.cylinder(0.0, 0.45, 0.9), Color(1.0, 0.5, 0.1), Vector3(0, 0.7, 0), Vector3.ZERO, 0.4, 4.0)
    var fl: OmniLight3D = FlickerLight.new()
    fl.light_color = Color(1.0, 0.55, 0.2)
    fl.omni_range = 14.0
    fl.light_energy = 2.2
    fl.position = Vector3(0, 1.5, 0)
    fire.add_child(fl)
    _static_cyl(body, fire.position, 0.7, 0.5)
    # маяк: високий стовп золотого світла, видно здалеку
    var beacon := Node3D.new()
    beacon.position = Vector3(0, 0, cz - 6.0)
    add_child(beacon)
    Util.add_mesh(beacon, Util.cylinder(0.25, 0.25, 40.0), Color(1.0, 0.82, 0.35), Vector3(0, 20.0, 0), Vector3.ZERO, 0.4, 3.5)
    Util.add_mesh(beacon, Util.cylinder(0.6, 0.9, 1.6), Color(0.3, 0.28, 0.26), Vector3(0, 0.8, 0))
    var bl: OmniLight3D = FlickerLight.new()
    bl.light_color = Color(1.0, 0.85, 0.5)
    bl.omni_range = 22.0
    bl.light_energy = 2.0
    bl.position = Vector3(0, 3.0, 0)
    beacon.add_child(bl)

func _static_cyl(body: StaticBody3D, pos: Vector3, r: float, h: float) -> void:
    var cs := CollisionShape3D.new()
    var sh := CylinderShape3D.new()
    sh.radius = r
    sh.height = h
    cs.shape = sh
    cs.position = Vector3(pos.x, h * 0.5, pos.z)
    body.add_child(cs)

func _static_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    cs.position = Vector3(pos.x, size.y * 0.5, pos.z)
    body.add_child(cs)

# Земляна текстура «від руки»: плями ґрунту, мазки пензля вздовж дороги, колії від возів, камінці й пучки трави.
# road = true — смуга дороги (тайлиться вздовж, м'які краї по боках); false — майданчик табору (м'які краї з усіх боків).
func _make_dirt_texture(road: bool) -> ImageTexture:
    var w := 256
    var h := 256
    var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 777 if road else 888
    var ph := PackedFloat32Array()
    for i in range(8):
        ph.append(rng.randf() * TAU)
    var dark := Color(0.30, 0.20, 0.12)
    var light := Color(0.55, 0.41, 0.26)
    for y in range(h):
        for x in range(w):
            var u := float(x) / float(w)
            var v := float(y) / float(h)
            # плями ґрунту (періодичні, щоб шви не було видно)
            var n := 0.5 + 0.22 * sin(TAU * (2.0 * u + 3.0 * v) + ph[0]) + 0.14 * sin(TAU * (5.0 * u - 2.0 * v) + ph[1]) + 0.09 * sin(TAU * (3.0 * u + 7.0 * v) + ph[2])
            var c: Color = dark.lerp(light, clampf(n, 0.0, 1.0))
            # мазки пензля вздовж дороги
            var streak := 0.5 + 0.5 * sin(TAU * 19.0 * u + 2.2 * sin(TAU * v + ph[3]) + 1.3 * sin(TAU * 3.0 * v + ph[4]))
            c = c.darkened(0.12 * streak)
            var d_edge := 1.0
            if road:
                # колії від возів і втоптаний гребінь посередині
                for cu: float in [0.31, 0.69]:
                    var dd := absf(u - cu + 0.012 * sin(TAU * 4.0 * v + ph[5]))
                    if dd < 0.075:
                        var k := 1.0 - dd / 0.075
                        c = c.darkened(0.34 * k * k)
                var mid := absf(u - 0.5)
                if mid < 0.09:
                    c = c.lightened(0.10 * (1.0 - mid / 0.09))
                var e := minf(u, 1.0 - u)
                var jag := 0.035 * sin(TAU * 9.0 * v + ph[6]) + 0.02 * sin(TAU * 21.0 * v + ph[7])
                d_edge = clampf((e - 0.03 - jag) / 0.13, 0.0, 1.0)
            else:
                var e2 := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
                var jag2 := 0.03 * sin(TAU * 7.0 * (u + v) + ph[6]) + 0.02 * sin(TAU * 13.0 * (u - v) + ph[7])
                d_edge = clampf((e2 - 0.05 - jag2) / 0.16, 0.0, 1.0)
            # біля краю земля темніша й вологіша — плавний перехід у траву
            c = c.lerp(Color(0.20, 0.17, 0.09), (1.0 - d_edge) * 0.55)
            var g := 0.93 + rng.randf() * 0.14
            img.set_pixel(x, y, Color(c.r * g, c.g * g, c.b * g, d_edge))
    # камінці з бліком і тінню
    for i in range(150 if road else 90):
        var px := rng.randi_range(0, w - 1)
        var py := rng.randi_range(0, h - 1)
        var r := rng.randi_range(1, 3)
        var tone := 0.38 + rng.randf() * 0.2
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy > r * r:
                    continue
                var q := Vector2i((px + dx + w) % w, (py + dy + h) % h)
                var base: Color = img.get_pixelv(q)
                if base.a < 0.6:
                    continue
                var shade := tone * (1.15 if (dx + dy) < 0 else 0.8)
                img.set_pixelv(q, Color(shade, shade * 0.94, shade * 0.86, base.a))
    # пучки трави, що пробиваються
    for i in range(110 if road else 70):
        var gx := rng.randi_range(0, w - 1)
        var gy := rng.randi_range(0, h - 1)
        var near_edge := road and (minf(float(gx) / float(w), 1.0 - float(gx) / float(w)) < 0.16)
        if road and not near_edge and rng.randf() > 0.15:
            continue
        for b in range(rng.randi_range(2, 4)):
            var bx := gx + rng.randi_range(-2, 2)
            var blen := rng.randi_range(3, 7)
            var lean := rng.randf_range(-0.4, 0.4)
            for k in range(blen):
                var q2 := Vector2i((bx + int(lean * float(k)) + w) % w, (gy - k + h) % h)
                var base2: Color = img.get_pixelv(q2)
                if base2.a < 0.3:
                    continue
                var gv := 0.30 + 0.25 * float(k) / float(blen) + rng.randf() * 0.06
                img.set_pixelv(q2, Color(gv * 0.62, gv, gv * 0.36, base2.a))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

func _make_stone_texture() -> ImageTexture:
    var tex := 256
    var img := Image.create_empty(tex, tex, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.12, 0.11, 0.10))
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var sw := 128
    var sh := 64
    for row in range(4):
        var xoff := 0
        if row % 2 == 1:
            xoff = 64
        for col in range(2):
            var s := 0.36 + rng.randf() * 0.16
            var base := Color(s, s * 0.98, s * 0.93)
            for y in range(2, sh - 2):
                for x in range(2, sw - 2):
                    var k := 0.92 + rng.randf() * 0.16
                    if x < 5 or y < 5:
                        k += 0.12
                    elif x > sw - 6 or y > sh - 6:
                        k -= 0.15
                    img.set_pixel((col * sw + xoff + x) % tex, (row * sh + y) % tex, Color(base.r * k, base.g * k, base.b * k, 1.0))
    for i in range(10):
        var cx := rng.randi_range(0, tex - 1)
        var cy := rng.randi_range(0, tex - 1)
        for step in range(rng.randi_range(8, 20)):
            img.set_pixel(cx % tex, cy % tex, Color(0.10, 0.09, 0.08))
            cx += rng.randi_range(0, 2)
            cy += rng.randi_range(0, 1)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)
