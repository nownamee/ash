extends Node3D
# Великий світ: нескінченна карта з біомами, що генерується шматками (чанками) навколо гравця.
# Кожен чанк: земля з кольором біому + дерева, камені, руїни, будівлі, цвинтарі тощо.
# Дрібні об'єкти малюються через MultiMesh (швидко), колізії — одним StaticBody на чанк.

const Biomes = preload("res://biomes.gd")
const Util = preload("res://util.gd")
const FlickerLight = preload("res://light_flicker.gd")
const FireField = preload("res://fire_field.gd")
const AcidPool = preload("res://acid_pool.gd")

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
]

# Частка заповнення по біомах (луки, ліс, пустеля, сніги, цвинтар, руїни, місто)
const DENSITY := [0.55, 1.0, 0.5, 0.6, 0.75, 0.65, 0.7, 0.7, 0.9, 0.65, 0.78]

# Об'єкти біому: [назва, вага]
const PROPS := [
    # луки: окремі підроблені ділянки, садиби, стежки паркану; кров і трупи — рідко (вони живуть біля боїв, див. CLUSTER)
    [["tree_oak", 2.0], ["bush", 3.0], ["flowers", 4.0], ["tuft", 8.0], ["rock", 1.0], ["haystack", 0.25], ["fence", 0.5], ["stump", 0.5], ["farmstead", 0.08], ["well", 0.08], ["scarecrow", 0.14], ["crops", 0.25], ["beehive", 0.1], ["woodpile", 0.12], ["cart", 0.1], ["fallen_tree", 0.2], ["blood", 0.12], ["corpse", 0.03]],
    # ліс
    [["tree_oak", 5.0], ["tree_pine", 4.0], ["bush", 3.0], ["tuft", 5.0], ["log", 1.2], ["stump", 1.2], ["mushroom", 1.5], ["rock", 1.0], ["fallen_tree", 0.5], ["bramble", 0.8], ["mushroom_ring", 0.25], ["camp", 0.06], ["tent", 0.04], ["woodpile", 0.1], ["blood", 0.1], ["corpse", 0.03]],
    # пустеля
    [["cactus", 3.0], ["rock", 2.0], ["bones", 1.5], ["dead_tree", 0.7], ["dune", 2.5], ["obelisk", 0.4], ["dry_tuft", 4.0], ["skull_pile", 0.3], ["ribcage", 0.25], ["broken_cart", 0.15], ["dry_well", 0.1], ["caravan", 0.07], ["blood", 0.08], ["corpse", 0.05]],
    # сніг
    [["tree_pine_snow", 4.0], ["rock_ice", 1.5], ["snow_mound", 3.0], ["dead_tree", 0.7], ["ice_crystal", 1.2], ["frozen_statue", 0.12], ["sled", 0.15], ["igloo", 0.1], ["ice_camp", 0.04], ["blood", 0.1], ["corpse", 0.06]],
    # цвинтар
    [["tombstone", 5.0], ["cross", 2.0], ["dead_tree", 2.5], ["crypt", 0.15], ["mausoleum", 0.1], ["grave_plot", 0.35], ["iron_fence", 0.4], ["open_grave", 0.3], ["coffin", 0.15], ["angel_statue", 0.25], ["lantern_post", 0.25], ["bones", 1.0], ["blood", 0.12], ["corpse", 0.08]],
    # руїни
    [["ruin_wall", 3.0], ["pillar", 2.5], ["rubble", 3.0], ["broken_house", 0.45], ["arch", 0.5], ["rock", 1.0], ["fallen_column", 0.9], ["statue", 0.4], ["broken_stairs", 0.3], ["blood", 0.12], ["corpse", 0.08]],
    # місто (розставляється _spawn_city за вулицями; тут — резерв)
    [["car", 1.4], ["rubble", 2.0], ["crack", 3.0], ["road_mark", 2.0], ["streetlamp", 0.9], ["dumpster", 0.7], ["ruined_building", 0.5], ["fire_barrel", 0.25], ["manhole", 0.6], ["sign", 0.5]],
    # Попелясті пустища
    [["rock", 3.0], ["dead_tree", 1.8], ["rubble", 2.5], ["crack", 3.5], ["bones", 1.5], ["ruin_wall", 0.9], ["pillar", 0.5], ["broken_house", 0.2], ["fire_barrel", 0.15], ["dry_tuft", 1.5], ["collapsed_chimney", 0.25], ["charred_cart", 0.12], ["burned_farm", 0.05], ["blood", 0.1], ["corpse", 0.1]],
    # Токсичне болото
    [["dead_tree", 3.0], ["tree_oak", 2.0], ["bush", 3.0], ["mushroom", 3.5], ["log", 1.5], ["stump", 1.5], ["tuft", 4.0], ["rock", 0.8], ["bones", 0.8], ["bramble", 1.0], ["mushroom_ring", 0.4], ["fallen_tree", 0.6], ["swamp_homestead", 0.05], ["blood", 0.1], ["corpse", 0.06]],
    # Мертва тундра
    [["tree_pine_snow", 2.5], ["dead_tree", 1.8], ["rock_ice", 2.0], ["snow_mound", 3.0], ["ice_crystal", 1.8], ["bones", 0.9], ["frozen_statue", 0.1], ["sled", 0.1], ["igloo", 0.06], ["blood", 0.1], ["corpse", 0.08]],
    # Пожежа: вогнища, горять дерева, тліють жарини, обгорілі балки й колоди
    [["flames", 5.0], ["embers", 4.0], ["burning_tree", 1.2], ["dead_tree", 2.0], ["charred_log", 1.5], ["burnt_beams", 1.2], ["rubble", 2.5], ["crack", 2.5], ["rock", 1.5], ["bones", 1.0], ["broken_house", 0.25], ["fire_barrel", 0.2], ["collapsed_chimney", 0.3], ["charred_cart", 0.15], ["burned_farm", 0.05], ["blood", 0.1], ["corpse", 0.1]],
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
const TALL := ["tree_oak", "tree_pine", "tree_pine_snow", "dead_tree", "pillar", "ruin_wall", "broken_house", "tombstone", "cross", "crypt", "cactus", "arch", "iron_fence", "burning_tree", "mausoleum", "angel_statue", "statue", "grave_plot", "lantern_post"]
# колір втоптаної стежки по біомах (луки, ліс, пустеля, сніги, цвинтар, руїни, місто)
const TRAIL_COL := [Color(0.30, 0.23, 0.13), Color(0.17, 0.12, 0.07), Color(0.74, 0.62, 0.40), Color(0.62, 0.66, 0.72), Color(0.30, 0.27, 0.27), Color(0.42, 0.38, 0.33), Color(0.08, 0.08, 0.09), Color(0.22, 0.18, 0.16), Color(0.14, 0.13, 0.07), Color(0.52, 0.57, 0.66), Color(0.16, 0.10, 0.07)]
# що стоїть уздовж стежки
const TRAIL_PROPS := [
    [["flowers", 3.0], ["rock", 1.5], ["stump", 1.0], ["fence", 1.4], ["bush", 1.5], ["woodpile", 0.3]],
    [["mushroom", 2.0], ["log", 1.2], ["stump", 1.2], ["bush", 2.0], ["rock", 1.0], ["fallen_tree", 0.5], ["bramble", 0.5]],
    [["bones", 2.0], ["rock", 2.0], ["dry_tuft", 2.0], ["cactus", 1.0], ["skull_pile", 0.4]],
    [["snow_mound", 2.0], ["rock_ice", 2.0], ["ice_crystal", 1.0], ["sled", 0.3]],
    [["cross", 2.0], ["tombstone", 1.5], ["iron_fence", 1.2], ["bones", 0.8], ["lantern_post", 1.0]],
    [["rubble", 2.5], ["pillar", 1.0], ["ruin_wall", 1.0], ["rock", 1.0], ["fallen_column", 0.6]],
    [["streetlamp", 1.0], ["barricade", 0.8], ["dumpster", 0.5], ["fire_barrel", 0.5], ["sign", 0.5], ["bench", 0.5], ["hydrant", 0.4], ["traffic_cone", 0.5]],
    [["rubble", 2.0], ["rock", 1.5], ["bones", 1.0], ["fire_barrel", 0.5], ["dead_tree", 0.8]],
    [["mushroom", 2.5], ["log", 1.5], ["stump", 1.2], ["bush", 1.5], ["bones", 0.6], ["bramble", 1.0]],
    [["snow_mound", 2.0], ["rock_ice", 1.8], ["ice_crystal", 1.4], ["bones", 0.8]],
    [["flames", 1.5], ["embers", 2.0], ["charred_log", 1.5], ["rubble", 1.5], ["burnt_beams", 1.0]],
]
# розвилка: покажчик і два сигнальні вогні по краях стежки (лицем до замку)
const HUB_SET := [["sign", 3.6, 0.6], ["fire_barrel", -4.0, -2.4], ["fire_barrel", 4.6, -4.2], ["rock", -6.5, 4.0], ["stump", 6.0, 5.0]]
# пам'ятні місця в кінці стежок: [вид, зсув x, зсув z, поворот у градусах або "c" — лицем до центру].
# Локальна рамка: -Z дивиться туди, звідки приходить стежка, тож входи й фасади повернуті до гравця.
const LANDMARKS := [
    # луки: садиба з двором, навколо поле, віз і стіг
    [["farmstead", 0, 0], ["crops", -9.8, 3.0], ["scarecrow", -9.8, -0.6, "c"], ["cart", 9.8, 4.2, 35], ["haystack", 10.2, -0.5], ["flowers", 8.5, -6.5], ["corpse", -2.6, -9.2, 70], ["blood", -2.6, -9.2], ["beehive", -7.0, 8.0, "c"]],
    # ліс: табір (намети й колоди навколо багаття), дрова, повалене дерево
    [["camp", 0, 0], ["woodpile", 10.0, 4.5, "c"], ["fallen_tree", -10.5, 2.0, 95], ["mushroom_ring", 9.5, -5.5], ["bush", -8.5, 8.0], ["corpse", -1.5, -10.0, 20], ["blood", -1.5, -10.0], ["bramble", 6.5, 9.0]],
    # пустеля: обеліск, кістки, караван, що зламався біля сухого колодязя
    [["obelisk", 0, 0], ["skull_pile", -5.6, -3.8], ["ribcage", 6.0, -3.4, 30], ["broken_cart", -7.4, 5.2, 35], ["dry_well", 6.8, 6.8], ["bones", 3.4, -6.6], ["bones", -3.4, 7.2], ["cactus", 9.2, 0.6], ["cactus", -9.2, -2.2], ["rock", 8.4, -7.0]],
    # сніг: стоянка біля іглу, замерзла статуя, крижані кристали
    [["ice_camp", 0, 0], ["ice_crystal", -8.4, -5.4], ["ice_crystal", 8.6, 3.2], ["rock_ice", 0.0, 9.6], ["rock_ice", -9.0, 4.4], ["snow_mound", 8.4, -6.4], ["corpse", -0.6, -9.0, 50]],
    # цвинтар: огороджена ділянка з могилами, мавзолей позаду, ліхтарі біля брами
    [["grave_plot", 0, 0], ["mausoleum", 0, 11.6, 0], ["lantern_post", -2.6, -7.0, "c"], ["lantern_post", 2.6, -7.0, "c"], ["dead_tree", -9.2, 2.4], ["cross", 8.8, -1.0, 0], ["cross", 8.8, 2.2, 0], ["tombstone", -8.8, -2.0, 0], ["tombstone", -8.8, 1.2, 0], ["bones", 5.6, -8.4]],
    # руїни: арка перед площею зі статуєю, колони, зруйновані сходи позаду
    [["arch", 0, -7.4], ["statue", 0, -0.8], ["pillar", -5.4, -3.2], ["pillar", 5.4, -3.2], ["fallen_column", -5.6, 4.8, 20], ["fallen_column", 5.2, 5.6, -30], ["broken_stairs", 0, 9.0, 0], ["rubble", -8.0, -6.4], ["rubble", 7.8, -6.8], ["corpse", -1.6, -9.6, 20], ["blood", -1.6, -9.6]],
    # місто: блокпост поліції впоперек дороги, автобус позаду, покинуті речі
    [["road_block", 0, -4.6], ["bus", 0, 8.6, 0], ["car", -8.8, 0.4, 8], ["streetlamp", 8.8, -6.0, "c"], ["dumpster", -8.6, 5.8, 0], ["fire_barrel", -3.2, -0.2], ["fire_barrel", 3.0, 0.2], ["bench", 9.0, 3.4, 90]],
    # попіл: зруйнований будинок, комин, обгорілий віз
    [["broken_house", 0, 0], ["collapsed_chimney", -8.6, 3.4, 0], ["charred_cart", 8.2, 4.6, 30], ["burnt_beams", 7.0, -6.4], ["rubble", 6.0, 2.0], ["fire_barrel", -3.4, 6.2], ["fire_barrel", 3.6, 6.6], ["bones", 5.0, -7.0], ["dead_tree", -7.4, -6.0], ["corpse", -2.4, 8.4]],
    # болото: хата на палях з човном
    [["swamp_homestead", 0, 0], ["log", -9.0, 5.4, 10], ["mushroom_ring", 9.4, -4.6], ["bush", -8.4, -5.4], ["dead_tree", -8.0, 8.0], ["bones", 3.6, 8.0], ["corpse", -2.4, -8.6, 40], ["blood", -2.4, -8.6]],
    # тундра: замерзлий воїн, іглу, сани
    [["frozen_statue", 0, 0], ["ice_crystal", 3.6, 1.4], ["ice_crystal", -3.4, 2.0], ["sled", 6.4, -3.8, 40], ["igloo", -7.8, -4.2, 0], ["rock_ice", 8.4, 3.4], ["rock_ice", -6.8, 6.4], ["snow_mound", 3.0, 8.0], ["corpse", -1.6, 5.6, 40]],
    # пожежа: будинок у вогні, комин, віз, палаючі дерева
    [["broken_house", 0, 0], ["collapsed_chimney", -8.6, 4.2, 0], ["charred_cart", 8.4, -3.6, 25], ["flames", 6.0, 3.6], ["flames", -6.2, 2.4], ["burning_tree", -7.0, -5.6], ["burning_tree", 7.4, -6.4], ["embers", 0.0, 7.4], ["charred_log", 3.0, -7.6], ["rubble", -3.5, 6.2]],
]
const CLUSTER := {
    "tree_oak": [["bush", 0.6, 2.5, 4.5], ["stump", 0.25, 3.0, 5.0], ["flowers", 0.5, 2.0, 4.5], ["fallen_tree", 0.06, 4.0, 6.0]],
    "tree_pine": [["mushroom", 0.35, 2.5, 4.5], ["stump", 0.2, 3.0, 5.0], ["bush", 0.3, 2.5, 4.5]],
    "tree_pine_snow": [["snow_mound", 0.6, 2.5, 4.5], ["rock_ice", 0.2, 3.0, 5.0]],
    "dead_tree": [["bones", 0.25, 2.0, 4.0], ["rock", 0.2, 2.5, 4.5]],
    "rock": [["rock", 0.35, 2.6, 4.0], ["tuft", 0.5, 2.0, 4.0]],
    "obelisk": [["bones", 0.9, 3.0, 5.0], ["bones", 0.6, 3.0, 5.0], ["rock", 0.5, 3.5, 6.0], ["skull_pile", 0.3, 4.0, 6.0]],
    "cactus": [["cactus", 0.6, 3.0, 4.5], ["bones", 0.25, 3.0, 5.0]],
    "ice_crystal": [["ice_crystal", 0.6, 2.8, 4.0], ["rock_ice", 0.4, 3.0, 5.0]],
    "crypt": [["lantern_post", 0.7, 4.0, 5.0], ["tombstone", 0.8, 5.5, 8.0], ["cross", 0.6, 5.5, 8.0], ["dead_tree", 0.5, 5.5, 8.0], ["angel_statue", 0.3, 5.0, 7.0]],
    "mausoleum": [["lantern_post", 0.8, 5.0, 6.0], ["cross", 0.5, 6.0, 8.0], ["dead_tree", 0.5, 6.0, 8.0], ["angel_statue", 0.4, 6.0, 8.0], ["tombstone", 0.7, 6.5, 9.0]],
    "broken_house": [["rubble", 0.9, 4.8, 7.0], ["rubble", 0.6, 4.8, 7.0], ["ruin_wall", 0.5, 5.5, 8.0], ["blood", 0.3, 3.0, 6.0], ["corpse", 0.15, 4.0, 7.0]],
    "arch": [["pillar", 0.7, 4.0, 6.0], ["rubble", 0.8, 3.0, 5.0]],
    "statue": [["rubble", 0.5, 3.0, 5.0], ["fallen_column", 0.3, 4.5, 6.5]],
    "fallen_column": [["rubble", 0.6, 3.0, 4.5]],
    "ruined_building": [["rubble", 0.9, 6.5, 9.0], ["rubble", 0.7, 6.5, 9.0], ["dumpster", 0.3, 6.5, 9.0], ["corpse", 0.35, 5.5, 8.0], ["blood", 0.4, 5.5, 8.0]],
    "barricade": [["fire_barrel", 0.35, 3.0, 4.5], ["corpse", 0.7, 2.5, 4.5], ["blood", 0.8, 2.0, 4.0], ["traffic_cone", 0.3, 3.0, 4.5]],
    "car": [["blood", 0.4, 2.5, 4.0], ["corpse", 0.2, 2.5, 4.0]],
    "police_car": [["traffic_cone", 0.8, 3.0, 4.5], ["corpse", 0.6, 2.5, 4.0], ["blood", 0.8, 2.0, 4.0]],
    "bus": [["corpse", 0.4, 5.0, 6.5], ["blood", 0.6, 5.0, 6.5], ["traffic_cone", 0.3, 5.0, 6.5]],
    "bus_stop": [["corpse", 0.25, 3.0, 4.5], ["blood", 0.35, 3.0, 4.5]],
    "burning_tree": [["embers", 0.6, 2.0, 4.0], ["charred_log", 0.25, 3.0, 5.0]],
    "camp": [["corpse", 0.5, 9.0, 11.0], ["blood", 0.6, 8.5, 10.5], ["woodpile", 0.4, 10.0, 12.0]],
    "tent": [["blood", 0.25, 2.5, 4.0]],
    "scarecrow": [["crops", 0.9, 2.5, 3.5]],
    "crops": [["scarecrow", 0.25, 2.8, 3.6], ["haystack", 0.2, 3.5, 5.0]],
    "beehive": [["flowers", 0.9, 1.8, 3.0], ["flowers", 0.7, 1.8, 3.0], ["beehive", 0.4, 1.6, 2.6]],
    "well": [["bush", 0.3, 2.5, 4.0], ["flowers", 0.4, 2.0, 3.5]],
    "woodpile": [["stump", 0.5, 2.5, 4.0]],
    "cart": [["haystack", 0.4, 3.5, 5.0], ["corpse", 0.1, 3.0, 4.5]],
    "broken_cart": [["bones", 0.6, 3.0, 4.5], ["corpse", 0.3, 3.0, 4.5], ["blood", 0.4, 2.5, 4.0]],
    "fallen_tree": [["mushroom", 0.5, 3.0, 4.5], ["bush", 0.3, 3.0, 4.5]],
    "skull_pile": [["bones", 0.6, 2.0, 3.5]],
    "ribcage": [["bones", 0.5, 3.0, 4.5], ["rock", 0.3, 3.5, 5.0]],
    "open_grave": [["tombstone", 0.5, 3.0, 4.5], ["dead_tree", 0.3, 4.0, 6.0]],
    "coffin": [["bones", 0.5, 2.0, 3.5], ["open_grave", 0.3, 4.0, 5.5]],
    "frozen_statue": [["ice_crystal", 0.6, 3.0, 4.5], ["snow_mound", 0.4, 3.0, 5.0]],
    "igloo": [["sled", 0.5, 4.0, 5.5], ["snow_mound", 0.5, 3.5, 5.0]],
    "sled": [["snow_mound", 0.3, 2.5, 4.0]],
    "sunken_boat": [["reeds", 0.8, 2.0, 3.0], ["bones", 0.2, 2.5, 3.5]],
    "collapsed_chimney": [["rubble", 0.8, 3.0, 4.5], ["burnt_beams", 0.5, 3.5, 5.5], ["embers", 0.6, 2.5, 4.0]],
    "charred_cart": [["embers", 0.5, 2.5, 4.0], ["bones", 0.3, 3.0, 4.5], ["corpse", 0.2, 3.0, 4.5]],
}
# ряди: [шанс ряду, крок, мін. ще, макс. ще]. Крок такий, щоб між об'єктами ряду лишався прохід (PASS_GAP);
# секції паркану стикаються торцями й утворюють суцільну лінію.
const ROWS := {"tombstone": [0.7, 3.6, 2, 4], "cross": [0.35, 3.6, 1, 2], "pillar": [0.5, 5.0, 1, 3], "fence": [0.9, 3.2, 1, 3], "iron_fence": [0.85, 3.3, 1, 2], "lantern_post": [0.6, 6.0, 1, 2]}
# Дрібні плоскі об'єкти: радіус, у межах якого не стоїть нічого твердого (квіти не потрапляють у каміння й під будинки)
const DECOR_R := {"flowers": 0.9, "tuft": 0.5, "dry_tuft": 0.5, "mushroom": 0.7, "bones": 0.8, "bush": 1.0, "corpse": 1.3, "crops": 1.8, "reeds": 0.8, "mushroom_ring": 1.4, "open_grave": 1.7, "traffic_cone": 0.8, "bramble": 1.0, "embers": 0.9, "flames": 1.0}
const WALLS := ["fence", "iron_fence"]                  # секції, що стикаються в одній групі
const ALIGN_TRAIL := ["fence", "iron_fence", "log", "fallen_tree", "woodpile"]   # біля стежки лягають вздовж неї
# Радіус складених сцен: стільки вільного місця потрібно навколо центру
const SCENE_R := {"farmstead": 8.0, "camp": 8.0, "grave_plot": 7.5, "road_block": 7.0, "swamp_homestead": 6.5, "ice_camp": 6.5, "caravan": 5.5, "burned_farm": 6.0, "mausoleum": 4.2, "crypt": 3.2, "ruined_building": 6.0, "broken_house": 5.5, "bus": 5.0, "igloo": 3.0, "dune": 3.0}
# біля води (кислотні водойми): тільки те, що росте на березі
const SHORE_ACID := [["reeds", 5.0], ["mushroom", 1.0], ["bramble", 0.6], ["dead_tree", 0.5], ["sunken_boat", 0.35], ["bones", 0.35]]
# біля вогняних плям: тліюче й обгоріле
const SHORE_FIRE := [["embers", 3.0], ["charred_log", 1.4], ["burnt_beams", 1.2], ["rock", 0.8], ["dead_tree", 0.8], ["bones", 0.5]]
# Місто: сітка вулиць із кроком CITY_P; смуга проїзду — CITY_ROAD від осі
const CITY_P := 46.0
const CITY_ROAD := 5.5
const CITY_ROAD_PROPS := [["car", 2.4], ["road_mark", 3.0], ["manhole", 0.8], ["crack", 1.5], ["blood", 0.5], ["corpse", 0.2], ["barricade", 0.25], ["crosswalk", 0.7], ["bus", 0.25], ["police_car", 0.2], ["road_block", 0.12], ["traffic_cone", 0.3]]
const CITY_CROSS_PROPS := [["car", 1.0], ["blood", 0.6], ["crack", 1.5], ["manhole", 1.0], ["corpse", 0.15]]
const CITY_WALK_PROPS := [["streetlamp", 2.2], ["dumpster", 0.8], ["sign", 0.6], ["fire_barrel", 0.4], ["bench", 0.8], ["hydrant", 0.6], ["mailbox", 0.5], ["newspaper_box", 0.4], ["bus_stop", 0.25], ["traffic_cone", 0.2], ["corpse", 0.12], ["blood", 0.3]]
const CITY_BLOCK_PROPS := [["ruined_building", 1.6], ["rubble", 2.0], ["dumpster", 0.15], ["corpse", 0.2], ["blood", 0.3], ["crack", 1.5]]
# Предмети тротуару: стоять на бордюрі лицем до проїзду
const CITY_SIDE_KINDS := ["streetlamp", "dumpster", "sign", "bench", "hydrant", "mailbox", "newspaper_box", "bus_stop"]

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
var _base_frame := Transform3D.IDENTITY   # рамка об'єкта (для вкладених піддекорацій _sub)
var _base_yaw := 0.0
var _decor: Array = []        # дрібні плоскі об'єкти чанка: {p, r} — щоб тверді предмети не ставали поверх них
var _grp := 0                 # номер групи (ряд, супутники): сусідні секції паркану не рахуються перешкодою одна одній
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
    _ground_mat.normal_scale = 0.4
    _ground_mat.roughness = 0.95
    _ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

    _prop_mat = StandardMaterial3D.new()
    _prop_mat.vertex_color_use_as_albedo = true
    _prop_mat.roughness = 0.9
    _prop_mat.albedo_texture = _make_detail_texture()
    _prop_mat.uv1_triplanar = true
    _prop_mat.uv1_world_triplanar = true
    _prop_mat.uv1_scale = Vector3(0.6, 0.6, 0.6)

    _make_unit_meshes()

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
                return secondary_biome
        return forced_biome
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

    _parts = {}
    for uk in _unit:
        _parts[uk] = [[], []]
    _decor = []
    _grp = 0
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
        var b := biome_at(x, z)
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

    if not _acid_chunk.is_empty():
        _shore_pass_acid(rng, x0, z0)
    if not _chunk_pools.is_empty():
        _shore_pass_fire(rng, x0, z0)

    if corridor:
        for i in range(BORDER_ATTEMPTS):
            var cx2 := x0 + rng.randf() * CHUNK
            var cz2 := z0 + rng.randf() * CHUNK
            var od := corridor_outside(cx2, cz2)
            if od < -1.0 or od > 20.0:
                continue
            _spawn_prop(_pick(BORDER_PROPS[biome_at(cx2, cz2)], rng), cx2, cz2, rng)
    elif arena_radius < 100000.0:
        for i in range(BORDER_ATTEMPTS):
            var bx := x0 + rng.randf() * CHUNK
            var bz := z0 + rng.randf() * CHUNK
            var bd := Vector2(bx, bz).length()
            if bd < arena_radius - 1.0 or bd > arena_radius + 20.0:
                continue
            _spawn_prop(_pick(BORDER_PROPS[biome_at(bx, bz)], rng), bx, bz, rng)

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
var _shore := false           # під час розстановки на березі: до води/вогню можна ближче

# Чи вільне місце: не в зоні (стежка, застава), не на дорозі коридору, не у вогні й не в кислоті.
# r > 3 — велика сцена: додатково перевіряємо 8 точок по колу.
func _site_ok(x: float, z: float, r: float = 0.0, zones: bool = true) -> bool:
    if zones and not _zl.is_empty() and _in_clear_zone(x, z):
        return false
    if corridor and _in_road_or_camp(x, z):
        return false
    var pad := 0.2 if _shore else 1.6
    if not _chunk_pools.is_empty() and _in_pools(_chunk_pools, x, z, pad):
        return false
    if not _acid_chunk.is_empty() and _acid_block(x, z, pad):
        return false
    if r > 3.0:
        for i in range(8):
            var a := TAU * float(i) / 8.0
            if not _site_ok(x + cos(a) * r, z + sin(a) * r, 0.0, zones):
                return false
    return true

# Чи не потрапляє плоский дрібний об'єкт (коло r) всередину вже поставленого твердого.
func _decor_blocked(x: float, z: float, r: float) -> bool:
    var p := Vector2(x, z)
    var dfp := {"pts": PackedVector2Array([p]), "r": r}
    for pl in _placed:
        if (pl["c"] as Vector2).distance_to(p) - float(pl["r"]) - r > 0.1:
            continue
        for b in (pl["fp"] as Array):
            if _fp_dist(dfp, b) < 0.1:
                return true
    return false

# Чи накриває новий твердий об'єкт якийсь дрібний (квіти, гриби, кістки).
func _solid_hits_decor(fp: Array, bd: Dictionary) -> bool:
    var bc: Vector2 = bd["c"]
    var br: float = bd["r"]
    for d in _decor:
        var dp: Vector2 = d["p"]
        var dr: float = d["r"]
        if dp.distance_to(bc) - dr - br > 0.0:
            continue
        var dfp := {"pts": PackedVector2Array([dp]), "r": dr}
        for f in fp:
            if _fp_dist(dfp, f) < 0.05:
                return true
    return false

# zones=false — предмети вздовж стежки: вони навмисно стоять на краю зони без дерев.
func _spawn_spaced(kind: String, x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float, zones: bool = true) -> bool:
    var sr: float = float(SCENE_R.get(kind, 0.0))
    if not _site_ok(x, z, sr, zones):
        return false
    if DECOR_R.has(kind):
        var dr: float = float(DECOR_R[kind])
        if _decor_blocked(x, z, dr):
            return false
        _spawn_prop(kind, x, z, rng)
        _decor.append({"p": Vector2(x, z), "r": dr})
        return true
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
    var skip_g := _grp if WALLS.has(kind) else -9
    if _spacing_ok(fp, bd, x0, z0, skip_g) and not _solid_hits_decor(fp, bd):
        _placed.append({"c": bd["c"], "r": bd["r"], "fp": fp, "g": _grp})
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
    if DECOR_R.has(kind):
        _decor.append({"p": Vector2(x, z), "r": float(DECOR_R[kind])})
    if _shapes.size() == n_shapes:
        return
    var fp: Array = []
    for i in range(n_shapes, _shapes.size()):
        fp.append(_footprint(_shapes[i]))
    var bd := _bound(fp)
    _placed.append({"c": bd["c"], "r": bd["r"], "fp": fp, "g": -2})

# Головний об'єкт із «супутниками»: надгробки, колони й паркан — рядами (однаково повернуті), супутники — навколо.
func _place_group(kind: String, x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    _grp += 1
    var row := false
    var row_a := 0.0
    var rw: Array = []
    if ROWS.has(kind):
        rw = ROWS[kind]
        row = rng.randf() < float(rw[0])
        if row:
            row_a = rng.randf() * TAU
            _yaw_force = -row_a      # усі об'єкти ряду дивляться в один бік, а паркан лягає вздовж ряду
    var ok := _spawn_spaced(kind, x, z, rng, x0, z0)
    if row and ok:
        var n := rng.randi_range(int(rw[2]), int(rw[3]))
        var sp := float(rw[1])
        for i in range(1, n + 1):
            var rx := x + cos(row_a) * sp * float(i)
            var rz := z + sin(row_a) * sp * float(i)
            _spawn_spaced(kind, rx, rz, rng, x0, z0)
    _yaw_force = -1000.0
    if not ok or not CLUSTER.has(kind):
        return
    for cs in CLUSTER[kind]:
        if rng.randf() > float(cs[1]):
            continue
        var ang := rng.randf() * TAU
        var r := rng.randf_range(float(cs[2]), float(cs[3]))
        _grp += 1
        _spawn_spaced(String(cs[0]), x + cos(ang) * r, z + sin(ang) * r, rng, x0, z0)

# Берег кислотних водойм: очерет, гриби, колючки, іноді затонулий човен — тільки поруч із водою.
func _shore_pass_acid(rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    _shore = true
    for i in range(22):
        var sh: Dictionary = _acid_chunk[rng.randi() % _acid_chunk.size()]
        var pts: PackedVector2Array = sh["pts"]
        if pts.is_empty():
            continue
        var q: Vector2 = pts[rng.randi() % pts.size()]
        var out: Vector2 = q - (sh["c"] as Vector2)
        if out.length() < 0.1:
            continue
        var kind := _pick(SHORE_ACID, rng)
        if kind == "sunken_boat" and float(sh["area"]) < 70.0:
            kind = "reeds"
        var dist := rng.randf_range(2.6, 3.3) if kind == "sunken_boat" else rng.randf_range(1.0, 1.9)
        var p := q + out.normalized() * dist
        if p.x < x0 or p.x >= x0 + CHUNK or p.y < z0 or p.y >= z0 + CHUNK:
            continue
        if Geometry2D.is_point_in_polygon(p, sh["poly"]):
            continue
        _place_group(kind, p.x, p.y, rng, x0, z0)
    _shore = false

# Край вогняних плям: жарини, обгорілі колоди й балки.
func _shore_pass_fire(rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    _shore = true
    for i in range(14):
        var pl: Array = _chunk_pools[rng.randi() % _chunk_pools.size()]
        var a := rng.randf() * TAU
        var rr := float(pl[2]) + rng.randf_range(1.0, 2.4)
        var px := float(pl[0]) + cos(a) * rr
        var pz := float(pl[1]) + sin(a) * rr
        if px < x0 or px >= x0 + CHUNK or pz < z0 or pz >= z0 + CHUNK:
            continue
        _place_group(_pick(SHORE_FIRE, rng), px, pz, rng, x0, z0)
    _shore = false

# Місто: вулиці по сітці. У смузі проїзду — машини по смугах уздовж руху, розмітка, люки, блокпости впоперек;
# на тротуарі — ліхтарі (через рівні проміжки), лавки, смітники лицем до проїзду; у кварталах — будинки фасадом до вулиці.
func _spawn_city(x: float, z: float, rng: RandomNumberGenerator, x0: float, z0: float) -> void:
    var xc := roundf(x / CITY_P) * CITY_P
    var zc := roundf(z / CITY_P) * CITY_P
    var dx := absf(x - xc)
    var dz := absf(z - zc)
    var d := minf(dx, dz)
    var along_z := dx < dz                    # найближча вулиця йде вздовж Z (її вісь x = xc)
    var px := x
    var pz := z
    var kind := ""
    var yaw := -1000.0
    if d < CITY_ROAD:
        if dx < CITY_ROAD and dz < CITY_ROAD:
            kind = _pick(CITY_CROSS_PROPS, rng)      # перехрестя: машини стоять як зупинилися — під довільним кутом
            if kind == "car":
                yaw = rng.randf() * TAU
        else:
            kind = _pick(CITY_ROAD_PROPS, rng)
            var lane_s := 1.0 if rng.randf() < 0.5 else -1.0
            var lane := 2.6 * lane_s
            var yaw_along := (PI * 0.5 if along_z else 0.0)
            match kind:
                "car", "police_car", "bus":
                    # смуги: з одного боку їдуть в один бік; іноді — розвернута аварійна
                    yaw = yaw_along + (PI if lane_s > 0.0 else 0.0) + deg_to_rad(rng.randf_range(-5.0, 5.0))
                    if rng.randf() < 0.15:
                        yaw += deg_to_rad(rng.randf_range(-35.0, 35.0))
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
                "crosswalk":
                    # біля перехрестя: зебра впоперек дороги, на відстані за межею поперечної вулиці
                    yaw = 0.0 if along_z else PI * 0.5
                    if along_z:
                        px = xc
                        pz = zc + (CITY_ROAD + 1.6) * (1.0 if z > zc else -1.0)
                    else:
                        pz = zc
                        px = xc + (CITY_ROAD + 1.6) * (1.0 if x > xc else -1.0)
                "barricade":
                    yaw = 0.0 if along_z else PI * 0.5
                    if along_z:
                        px = xc + lane * 0.4
                    else:
                        pz = zc + lane * 0.4
                "road_block":
                    yaw = yaw_along
                    if along_z:
                        px = xc
                    else:
                        pz = zc
    elif d < CITY_ROAD + 3.5:
        kind = _pick(CITY_WALK_PROPS, rng)
        if CITY_SIDE_KINDS.has(kind):
            var along := pz if along_z else px                      # координата вздовж вулиці
            var cross_c := zc if along_z else xc                    # вісь поперечної вулиці
            if kind == "streetlamp" or kind == "hydrant":
                along = roundf(along / 15.0) * 15.0                 # рівні проміжки
            var side := 1.0 if int(roundf(along / 15.0)) % 2 == 0 else -1.0
            if kind != "streetlamp":
                side = 1.0 if rng.randf() < 0.5 else -1.0
            if absf(along - cross_c) < CITY_ROAD + 1.6:
                return                                              # не на перехресті
            var to_road := Vector2.ZERO
            if along_z:
                px = xc + side * (CITY_ROAD + 1.3)
                pz = along
                to_road = Vector2(-side, 0.0)
            else:
                pz = zc + side * (CITY_ROAD + 1.3)
                px = along
                to_road = Vector2(0.0, -side)
            if kind == "streetlamp":
                yaw = atan2(-to_road.y, to_road.x)                  # виніс ліхтаря — над проїздом
            else:
                yaw = atan2(-to_road.x, -to_road.y)                 # передом до проїзду
    else:
        kind = _pick(CITY_BLOCK_PROPS, rng)
        if kind == "ruined_building":
            # фасад до найближчої вулиці, і будинок не залазить на проїзд
            var to_r := Vector2.ZERO
            var need := CITY_ROAD + 1.2 + 4.2
            if along_z:
                to_r = Vector2(signf(xc - x), 0.0)
                px = xc - to_r.x * maxf(dx, need)
            else:
                to_r = Vector2(0.0, signf(zc - z))
                pz = zc - to_r.y * maxf(dz, need)
            yaw = atan2(-to_r.x, -to_r.y)
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
            if not _chunk_pools.is_empty() and _in_pools(_chunk_pools, p.x, p.y, 1.0):
                continue
            if not _acid_chunk.is_empty() and _acid_block(p.x, p.y, 1.0):
                continue
            _yaw_force = float(d["yaw"])
            _spawn_fixed(String(d["kind"]), p.x, p.y, rng)
            _yaw_force = -1000.0
    for d in _trail_dress:
        var q: Vector2 = d["pos"]
        if q.x >= x0 and q.x < x0 + CHUNK and q.y >= z0 and q.y < z0 + CHUNK:
            var kind := String(d["kind"])
            _grp += 1
            if ALIGN_TRAIL.has(kind):
                _yaw_force = float(d["yaw"])
            var ok := _spawn_spaced(kind, q.x, q.y, rng, x0, z0, false)
            if ok and WALLS.has(kind):
                # паркан вздовж стежки: ще дві секції в ряд (секції стикаються)
                var dir: Vector2 = d["dir"]
                for i in range(1, 3):
                    var np := q + dir * 3.2 * float(i)
                    _spawn_spaced(kind, np.x, np.y, rng, x0, z0, false)
            _yaw_force = -1000.0

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

func _spacing_ok(fp: Array, bd: Dictionary, x0: float, z0: float, skip_g: int = -9) -> bool:
    var m := PASS_GAP * 0.5
    var lo: Vector2 = bd["lo"]
    var hi: Vector2 = bd["hi"]
    if lo.x < x0 + m or lo.y < z0 + m or hi.x > x0 + CHUNK - m or hi.y > z0 + CHUNK - m:
        return false
    var bc: Vector2 = bd["c"]
    var br: float = bd["r"]
    for pl in _placed:
        if skip_g != -9 and int(pl.get("g", -2)) == skip_g:
            continue
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
# Вершинний колір на сітці кроком 2 м: колір біому + плями (світла трава/суха земля, волога тінь, акцентні ділянки).
# Біом рахуємо на грубій сітці 4 м (з усередненням сусідів на межах біомів) і білінійно розтягуємо — це дешево.
const GCELLS := 16
const GROUND_UV := 0.14       # текстура повторюється раз на ~7 м: великі м'які плями замість «зім'ятого паперу»
# по біомах: [світла пляма, волога/темна пляма, акцент (суха земля, гравій, листя, бруд)]
const GROUND_ACC := [
    [Color(0.27, 0.37, 0.14), Color(0.11, 0.19, 0.08), Color(0.31, 0.25, 0.13)],
    [Color(0.13, 0.24, 0.10), Color(0.045, 0.10, 0.05), Color(0.20, 0.145, 0.08)],
    [Color(0.73, 0.61, 0.39), Color(0.47, 0.37, 0.22), Color(0.55, 0.45, 0.32)],
    [Color(0.93, 0.96, 1.00), Color(0.62, 0.70, 0.84), Color(0.72, 0.78, 0.88)],
    [Color(0.25, 0.24, 0.27), Color(0.10, 0.10, 0.12), Color(0.22, 0.18, 0.13)],
    [Color(0.41, 0.39, 0.34), Color(0.19, 0.18, 0.16), Color(0.26, 0.31, 0.18)],
    [Color(0.21, 0.21, 0.23), Color(0.09, 0.09, 0.10), Color(0.18, 0.17, 0.12)],
    [Color(0.27, 0.23, 0.21), Color(0.10, 0.085, 0.08), Color(0.31, 0.20, 0.15)],
    [Color(0.16, 0.25, 0.12), Color(0.05, 0.10, 0.07), Color(0.21, 0.18, 0.10)],
    [Color(0.62, 0.66, 0.74), Color(0.32, 0.37, 0.46), Color(0.43, 0.41, 0.37)],
    [Color(0.21, 0.12, 0.08), Color(0.055, 0.04, 0.035), Color(0.32, 0.10, 0.04)],
]

# Базовий колір біому з усередненням п'яти точок на межах біомів.
func _ground_base(x: float, z: float) -> Color:
    if forced_biome >= 0 and secondary_biome < 0:
        return Biomes.DATA[forced_biome]["ground"]
    var acc := Color(0, 0, 0, 0)
    var off := CHUNK / float(CELLS) * 0.5
    var pts := [Vector2(0, 0), Vector2(off, 0), Vector2(-off, 0), Vector2(0, off), Vector2(0, -off)]
    for p in pts:
        var b := biome_at(x + p.x, z + p.y)
        var c: Color = Biomes.DATA[b]["ground"]
        acc += c
    return acc / 5.0

# Дрібне різноманіття кольору: плями трави/землі, вологі темні ділянки, «акцентний» ґрунт; у місті — асфальт і тротуар.
func _ground_finish(x: float, z: float, base: Color, b: int) -> Color:
    var acc: Array = GROUND_ACC[b]
    var n1 := noise_g.get_noise_2d(x * 2.2, z * 2.2)
    var n2 := noise_m.get_noise_2d(x * 5.0 + 91.0, z * 5.0)
    var n3 := noise_d.get_noise_2d(x * 1.3, z * 1.3)
    var c := base
    c = c.lerp(acc[0], clampf(n1 * 1.7, 0.0, 1.0) * 0.55)
    c = c.lerp(acc[1], clampf(-n1 * 1.7, 0.0, 1.0) * 0.5)
    c = c.lerp(acc[2], clampf((n2 - 0.12) * 2.4, 0.0, 1.0) * 0.55)
    var k := n3 * 0.045
    c = Color(c.r + k, c.g + k, c.b + k, 1.0)
    if b == Biomes.CITY:
        # асфальт на вулицях сітки (див. _spawn_city), тротуар світліший, до кварталів — трава й бруд
        var dxr := absf(x - roundf(x / CITY_P) * CITY_P)
        var dzr := absf(z - roundf(z / CITY_P) * CITY_P)
        var dm := minf(dxr, dzr)
        var road_k := 1.0 - smoothstep(CITY_ROAD - 0.8, CITY_ROAD + 0.8, dm)
        var walk_k := smoothstep(CITY_ROAD - 0.4, CITY_ROAD + 0.6, dm) * (1.0 - smoothstep(CITY_ROAD + 3.0, CITY_ROAD + 3.8, dm))
        c = c.lerp(Color(0.055, 0.055, 0.065), road_k * 0.9)
        c = c.lerp(Color(0.26, 0.26, 0.27), walk_k * 0.8)
        var s := noise_w.get_noise_2d(x * 2.3, z * 2.3)
        if s > 0.3:
            c = c.lerp(Color(0.24, 0.03, 0.03), clampf((s - 0.3) * 3.0, 0.0, 0.6))
    return c

# Повний колір точки (для стежок і майданчиків, щоб їхні краї збігались із землею).
func _ground_color(x: float, z: float) -> Color:
    return _ground_finish(x, z, _ground_base(x, z), biome_at(x, z))

# Тангенти плоскої сітки однакові в усіх чанках (UV лінійні за світовими координатами),
# тому рахуємо їх SurfaceTool один раз, а далі лише підставляємо.
func _make_ground_tangents() -> PackedFloat32Array:
    var step := CHUNK / float(GCELLS)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(GCELLS):
        for j in range(GCELLS):
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
    var cstep := CHUNK / float(CELLS)
    var coarse: Array = []
    var bids := PackedInt32Array()
    for i in range(CELLS + 1):
        for j in range(CELLS + 1):
            var wx := x0 + float(i) * cstep
            var wz := z0 + float(j) * cstep
            coarse.append(_ground_base(wx, wz))
            bids.append(biome_at(wx, wz))
    var step := CHUNK / float(GCELLS)
    var ratio := float(CELLS) / float(GCELLS)
    var cols: Array = []
    for i in range(GCELLS + 1):
        for j in range(GCELLS + 1):
            var u := float(i) * ratio
            var v := float(j) * ratio
            var i0 := mini(int(u), CELLS - 1)
            var j0 := mini(int(v), CELLS - 1)
            var tu := u - float(i0)
            var tv := v - float(j0)
            var c00: Color = coarse[i0 * (CELLS + 1) + j0]
            var c10: Color = coarse[(i0 + 1) * (CELLS + 1) + j0]
            var c01: Color = coarse[i0 * (CELLS + 1) + j0 + 1]
            var c11: Color = coarse[(i0 + 1) * (CELLS + 1) + j0 + 1]
            var base := c00.lerp(c10, tu).lerp(c01.lerp(c11, tu), tv)
            var bi := bids[mini(roundi(u), CELLS) * (CELLS + 1) + mini(roundi(v), CELLS)]
            cols.append(_ground_finish(x0 + float(i) * step, z0 + float(j) * step, base, bi))
    var n := GCELLS * GCELLS * 6
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    verts.resize(n)
    norms.resize(n)
    colors.resize(n)
    uvs.resize(n)
    var k := 0
    for i in range(GCELLS):
        for j in range(GCELLS):
            var ax := x0 + float(i) * step
            var az := z0 + float(j) * step
            var ia := i * (GCELLS + 1) + j
            var ib := (i + 1) * (GCELLS + 1) + j
            var ic := (i + 1) * (GCELLS + 1) + j + 1
            var id := i * (GCELLS + 1) + j + 1
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
        uvs[v] = Vector2(verts[v].x, verts[v].z) * GROUND_UV
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
    st.set_uv(Vector2(p.x, p.z) * GROUND_UV)
    st.add_vertex(p)

# Зерно землі: низькочастотні плями + дрібна крупа, без різких контрастів (колір дає вершинний колір).
func _make_grain_texture() -> ImageTexture:
    var n := 128
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 4242
    noise.frequency = 0.012
    noise.fractal_octaves = 3
    var fine := FastNoiseLite.new()
    fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    fine.seed = 4243
    fine.frequency = 0.09
    fine.fractal_octaves = 2
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 777
    for x in range(n):
        for y in range(n):
            # шум без шва: беремо його на торі (4 вибірки по зсуву)
            var fx := float(x)
            var fy := float(y)
            var nf := float(n)
            var a := noise.get_noise_2d(fx, fy)
            var b := noise.get_noise_2d(fx - nf, fy)
            var c := noise.get_noise_2d(fx, fy - nf)
            var d := noise.get_noise_2d(fx - nf, fy - nf)
            var wx := fx / nf
            var wy := fy / nf
            var low := lerpf(lerpf(a, b, wx), lerpf(c, d, wx), wy)
            var fa := fine.get_noise_2d(fx, fy)
            var fb := fine.get_noise_2d(fx - nf, fy)
            var fc := fine.get_noise_2d(fx, fy - nf)
            var fd := fine.get_noise_2d(fx - nf, fy - nf)
            var hi := lerpf(lerpf(fa, fb, wx), lerpf(fc, fd, wx), wy)
            var v := 0.86 + low * 0.18 + hi * 0.06
            v += (rng.randf() - 0.5) * 0.04
            if rng.randf() < 0.012:
                v -= 0.1
            elif rng.randf() < 0.01:
                v += 0.06
            v = clampf(v, 0.0, 1.0)
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

# Нормалі: дуже м'які великі горби (бруд, дерен) без дрібного «шуму», яким картала земля.
func _make_normal_texture() -> ImageTexture:
    var n := 128
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.seed = 99
    noise.frequency = 0.022
    noise.fractal_octaves = 2
    var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
    for x in range(n):
        for y in range(n):
            var fx := float(x)
            var fy := float(y)
            var nf := float(n)
            var a := noise.get_noise_2d(fx, fy)
            var b := noise.get_noise_2d(fx - nf, fy)
            var c := noise.get_noise_2d(fx, fy - nf)
            var d := noise.get_noise_2d(fx - nf, fy - nf)
            var wx := fx / nf
            var wy := fy / nf
            var v := lerpf(lerpf(a, b, wx), lerpf(c, d, wx), wy) * 0.5 + 0.5
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.bump_map_to_normal_map(2.0)
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
            var v := 0.66 + (noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5) * 0.34
            v += (rng.randf() - 0.5) * 0.08
            img.set_pixel(x, y, Color(v, v, v, 1.0))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

# ---------- Допоміжне для об'єктів ----------
func _begin(x: float, z: float, yaw: float) -> void:
    if _yaw_force > -100.0:
        yaw = _yaw_force
    _yaw = yaw
    _frame = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))
    _base_frame = _frame
    _base_yaw = yaw

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

func _col_box(local_pos: Vector3, size: Vector3, ryaw: float = 0.0) -> void:
    var p: Vector3 = _frame * local_pos
    _shapes.append({"t": "box", "pos": Vector3(p.x, size.y * 0.5, p.z), "size": size, "yaw": _yaw + ryaw})

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
        # нові
        "well": _p_well(x, z, rng)
        "dry_well": _p_dry_well(x, z, rng)
        "cart": _p_cart(x, z, rng)
        "broken_cart": _p_broken_cart(x, z, rng)
        "scarecrow": _p_scarecrow(x, z, rng)
        "woodpile": _p_woodpile(x, z, rng)
        "crops": _p_crops(x, z, rng)
        "beehive": _p_beehive(x, z, rng)
        "fallen_tree": _p_fallen_tree(x, z, rng)
        "bramble": _p_bramble(x, z, rng)
        "mushroom_ring": _p_mushroom_ring(x, z, rng)
        "reeds": _p_reeds(x, z, rng)
        "tent": _p_tent(x, z, rng)
        "skull_pile": _p_skull_pile(x, z, rng)
        "ribcage": _p_ribcage(x, z, rng)
        "frozen_statue": _p_frozen_statue(x, z, rng)
        "sled": _p_sled(x, z, rng)
        "igloo": _p_igloo(x, z, rng)
        "angel_statue": _p_angel_statue(x, z, rng)
        "mausoleum": _p_mausoleum(x, z, rng)
        "open_grave": _p_open_grave(x, z, rng)
        "coffin": _p_coffin(x, z, rng)
        "lantern_post": _p_lantern_post(x, z, rng)
        "fallen_column": _p_fallen_column(x, z, rng)
        "statue": _p_statue(x, z, rng)
        "broken_stairs": _p_broken_stairs(x, z, rng)
        "bus": _p_bus(x, z, rng)
        "traffic_cone": _p_traffic_cone(x, z, rng)
        "bench": _p_bench(x, z, rng)
        "bus_stop": _p_bus_stop(x, z, rng)
        "mailbox": _p_mailbox(x, z, rng)
        "hydrant": _p_hydrant(x, z, rng)
        "newspaper_box": _p_newspaper_box(x, z, rng)
        "police_car": _p_police_car(x, z, rng)
        "crosswalk": _p_crosswalk(x, z, rng)
        "sunken_boat": _p_sunken_boat(x, z, rng)
        "collapsed_chimney": _p_collapsed_chimney(x, z, rng)
        "charred_cart": _p_charred_cart(x, z, rng)
        # композиції
        "farmstead": _p_farmstead(x, z, rng)
        "camp": _p_camp(x, z, rng)
        "grave_plot": _p_grave_plot(x, z, rng)
        "road_block": _p_road_block(x, z, rng)
        "swamp_homestead": _p_swamp_homestead(x, z, rng)
        "ice_camp": _p_ice_camp(x, z, rng)
        "caravan": _p_caravan(x, z, rng)
        "burned_farm": _p_burned_farm(x, z, rng)

func _p_dry_well(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_well(rng, true)

func _p_broken_cart(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_cart(rng, 1)

func _p_police_car(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_car(rng, 1)

# ---------- Власні меші: низькополігональні, з плоским затіненням ----------
func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    # Лицьова сторона в Godot — за годинниковою стрілкою; наші фігури опуклі й містять початок координат
    var n := (b - a).cross(c - a)
    if n.dot((a + b + c) / 3.0) > 0.0:
        var t := b
        b = c
        c = t
    for p in [a, b, c]:
        st.set_smooth_group(-1)
        st.add_vertex(p)

func _hash3(p: Vector3, s: float) -> float:
    var h := sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719 + s * 17.17) * 43758.5453
    return h - floorf(h)

# Нерівна «брила»: ікосфера з одним поділом, вершини зсунуто детерміновано; знизу зрізана, щоб стояла на землі.
func _make_blob_mesh(seed_v: float, rough: float, flat_bottom: float) -> ArrayMesh:
    var t := (1.0 + sqrt(5.0)) * 0.5
    var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
    var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tri in f:
        var a: Vector3 = (v[tri[0]] as Vector3).normalized()
        var b: Vector3 = (v[tri[1]] as Vector3).normalized()
        var c: Vector3 = (v[tri[2]] as Vector3).normalized()
        var ab := (a + b).normalized()
        var bc := (b + c).normalized()
        var ca := (c + a).normalized()
        for q in [[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]]:
            var pts: Array = []
            for d in q:
                var dir: Vector3 = d
                var r := 0.5 * (1.0 + rough * (_hash3(dir, seed_v) - 0.5) * 2.0)
                var p := dir * r
                p.y = maxf(p.y, -flat_bottom)
                pts.append(p)
            _tri_out(st, pts[0], pts[1], pts[2])
    st.generate_normals()
    return st.commit()

# Призма даху: гребінь уздовж X, ширина по Z, висота по Y (від -0.5 до 0.5).
func _make_wedge_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a0 := Vector3(-0.5, -0.5, -0.5)
    var a1 := Vector3(0.5, -0.5, -0.5)
    var b0 := Vector3(-0.5, -0.5, 0.5)
    var b1 := Vector3(0.5, -0.5, 0.5)
    var r0 := Vector3(-0.5, 0.5, 0.0)
    var r1 := Vector3(0.5, 0.5, 0.0)
    _tri_out(st, a0, a1, r1)
    _tri_out(st, a0, r1, r0)
    _tri_out(st, b0, r0, r1)
    _tri_out(st, b0, r1, b1)
    _tri_out(st, a0, r0, b0)
    _tri_out(st, a1, b1, r1)
    _tri_out(st, a0, b0, b1)
    _tri_out(st, a0, b1, a1)
    st.generate_normals()
    return st.commit()

# Шестигранний кристал зі шпилем (лід, самоцвіти, бурульки).
func _make_crystal_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var apex := Vector3(0, 0.5, 0)
    var bot := Vector3(0, -0.5, 0)
    for i in range(6):
        var a0 := TAU * float(i) / 6.0
        var a1 := TAU * float(i + 1) / 6.0
        var lo0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.42 + Vector3(0, -0.5, 0)
        var lo1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.42 + Vector3(0, -0.5, 0)
        var hi0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.5 + Vector3(0, 0.12, 0)
        var hi1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.5 + Vector3(0, 0.12, 0)
        _tri_out(st, lo0, lo1, hi1)
        _tri_out(st, lo0, hi1, hi0)
        _tri_out(st, hi0, hi1, apex)
        _tri_out(st, lo0, bot, lo1)
    st.generate_normals()
    return st.commit()

func _make_unit_meshes() -> void:
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
    var tm := TorusMesh.new()
    tm.inner_radius = 0.34
    tm.outer_radius = 0.5
    tm.rings = 16
    tm.ring_segments = 8
    _unit = {"box": bm, "sphere": sm, "cyl": cm, "cone": nm, "torus": tm}
    _unit["rock"] = _make_blob_mesh(1.7, 0.30, 0.34)
    _unit["leaf"] = _make_blob_mesh(4.1, 0.14, 0.5)
    _unit["wedge"] = _make_wedge_mesh()
    _unit["crystal"] = _make_crystal_mesh()
    for k in _unit:
        var m: Mesh = _unit[k]
        if m is PrimitiveMesh:
            (m as PrimitiveMesh).material = _prop_mat
        else:
            m.surface_set_material(0, _prop_mat)

# ---------- Допоміжне для моделей ----------
func _pc(shape: String, lpos: Vector3, size: Vector3, color: Color) -> void:
    _part(shape, lpos, size, Vector3.ZERO, color)

# Брус/циліндр/шип між двома точками (локальні координати); для "cone" основа в a, вершина в b.
func _pb(shape: String, a: Vector3, b: Vector3, thick: float, color: Color) -> void:
    var d := b - a
    var l := d.length()
    if l < 0.001:
        return
    var up := d / l
    var q := Quaternion(Vector3.RIGHT, PI) if up.y < -0.9999 else Quaternion(Vector3.UP, up)
    var bs := Basis(q) * Basis.from_scale(Vector3(thick, l, thick))
    var entry: Array = _parts[shape]
    entry[0].append(_frame * Transform3D(bs, (a + b) * 0.5))
    entry[1].append(color)

# Кущ листя/крона: випадковий поворот, щоб грані не повторювались.
func _clump(lpos: Vector3, size: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
    _part("leaf", lpos, size, Vector3(rng.randf_range(-10.0, 10.0), rng.randf() * 360.0, rng.randf_range(-10.0, 10.0)), color)

func _chunk_of_rock(lpos: Vector3, size: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
    _part("rock", lpos, size, Vector3(rng.randf_range(-12.0, 12.0), rng.randf() * 360.0, rng.randf_range(-12.0, 12.0)), color)

# Піддекорація: поточна рамка зміщується в локальну точку й повертається (композитні об'єкти).
func _sub(lx: float, lz: float, ryaw: float) -> void:
    _frame = _base_frame * Transform3D(Basis(Vector3.UP, ryaw), Vector3(lx, 0.0, lz))
    _yaw = _base_yaw + ryaw

func _sub_end() -> void:
    _frame = _base_frame
    _yaw = _base_yaw

func _light_local(y: float, energy: float, range_m: float, color: Color) -> void:
    if _lights.is_empty():
        var p: Vector3 = _frame * Vector3(0.0, y, 0.0)
        _lights.append({"pos": p, "color": color, "energy": energy, "range": range_m})

func _face_yaw(from: Vector2, to: Vector2) -> float:
    var d := to - from
    return atan2(-d.x, -d.y)

# Паркан: стовпи через ~1.5 м, дві-три жердини, іноді зламана. Ділянка між точками (локальні x,z), колізія — по секціях.
func _fence_run(x0: float, z0: float, x1: float, z1: float, wood: Color, rng: RandomNumberGenerator) -> void:
    var d := Vector2(x1 - x0, z1 - z0)
    var length := d.length()
    if length < 0.2:
        return
    var dir := d / length
    var ang := atan2(-dir.y, dir.x)
    var n := maxi(1, int(ceil(length / 3.0)))
    var seg := length / float(n)
    for s in range(n):
        var a := Vector2(x0, z0) + dir * seg * float(s)
        var b := a + dir * seg
        var m := (a + b) * 0.5
        for k in range(3):
            var pp := a.lerp(b, float(k) / 2.0)
            var ph := 1.0 + rng.randf_range(-0.08, 0.08)
            _part("box", Vector3(pp.x, ph * 0.5, pp.y), Vector3(0.14, ph, 0.14), Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), wood.darkened(0.1))
            _pc("box", Vector3(pp.x, ph + 0.02, pp.y), Vector3(0.18, 0.05, 0.18), wood.lightened(0.15))
        for yy in [0.38, 0.72]:
            var broken := rng.randf() < 0.1
            _part("box", Vector3(m.x, float(yy) - (0.12 if broken else 0.0), m.y), Vector3(seg, 0.09, 0.07), Vector3(0, rad_to_deg(ang), 14.0 if broken else 0.0), wood.lightened(rng.randf_range(-0.05, 0.1)))
        _col_box(Vector3(m.x, 0.0, m.y), Vector3(seg, 1.0, 0.25), ang)

# Кована решітка цвинтаря: прути з вістрями, кам'яні стовпи з кулями.
func _iron_run(x0: float, z0: float, x1: float, z1: float, rng: RandomNumberGenerator) -> void:
    var d := Vector2(x1 - x0, z1 - z0)
    var length := d.length()
    if length < 0.2:
        return
    var dir := d / length
    var ang := atan2(-dir.y, dir.x)
    var n := maxi(1, int(ceil(length / 3.0)))
    var seg := length / float(n)
    var iron := Color(0.10, 0.10, 0.12)
    var stone := Color(0.36, 0.35, 0.37)
    for s in range(n):
        var a := Vector2(x0, z0) + dir * seg * float(s)
        var b := a + dir * seg
        var m := (a + b) * 0.5
        _pc("box", Vector3(a.x, 0.8, a.y), Vector3(0.3, 1.6, 0.3), stone)
        _pc("sphere", Vector3(a.x, 1.7, a.y), Vector3(0.32, 0.32, 0.32), stone.lightened(0.08))
        var bars := maxi(3, int(seg / 0.6))
        for k in range(1, bars):
            var pp := a.lerp(b, float(k) / float(bars))
            var hh := 1.25 + (0.0 if rng.randf() > 0.12 else -0.35)
            _pc("cyl", Vector3(pp.x, hh * 0.5, pp.y), Vector3(0.05, hh, 0.05), iron)
            _pc("cone", Vector3(pp.x, hh + 0.1, pp.y), Vector3(0.1, 0.22, 0.1), iron.lightened(0.05))
        _part("box", Vector3(m.x, 0.3, m.y), Vector3(seg, 0.05, 0.05), Vector3(0, rad_to_deg(ang), 0), iron)
        _part("box", Vector3(m.x, 1.0, m.y), Vector3(seg, 0.05, 0.05), Vector3(0, rad_to_deg(ang), 0), iron)
        _col_box(Vector3(m.x, 0.0, m.y), Vector3(seg, 1.4, 0.25), ang)
    _pc("box", Vector3(x1, 0.8, z1), Vector3(0.3, 1.6, 0.3), stone)
    _pc("sphere", Vector3(x1, 1.7, z1), Vector3(0.32, 0.32, 0.32), stone.lightened(0.08))

# ---------- Дерева ----------
func _p_tree_oak(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.2, 3.4)
    var s := rng.randf_range(0.9, 1.3)
    var bark := _jit(Color(0.33, 0.21, 0.11), 0.04, rng)
    var leaf := _jit(Color(0.17, 0.46, 0.15), 0.05, rng)
    if rng.randf() < 0.18:
        leaf = leaf.lerp(Color(0.55, 0.42, 0.12), 0.45)     # осіннє дерево
    _pc("cone", Vector3(0, 0.5, 0), Vector3(1.05, 1.0, 1.05), bark.darkened(0.08))
    _pc("cyl", Vector3(0, h * 0.5, 0), Vector3(0.5, h, 0.5), bark)
    var ra := rng.randf() * TAU
    for i in range(3):
        var a := ra + TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
        _pb("cone", Vector3(cos(a) * 0.18, 0.28, sin(a) * 0.18), Vector3(cos(a) * 0.95, 0.03, sin(a) * 0.95), 0.3, bark.darkened(0.14))
    var ba := rng.randf() * TAU
    _pb("cyl", Vector3(0, h * 0.75, 0), Vector3(cos(ba) * 0.9 * s, h + 0.5, sin(ba) * 0.9 * s), 0.2, bark)
    _pb("cyl", Vector3(0, h * 0.8, 0), Vector3(-cos(ba) * 0.8 * s, h + 0.4, -sin(ba) * 0.8 * s), 0.17, bark)
    # крона: темніший низ, світліший верх, кілька клаптів світла
    for i in range(4):
        var a := TAU * float(i) / 4.0 + rng.randf_range(-0.4, 0.4)
        var r := rng.randf_range(0.95, 1.25) * s
        _clump(Vector3(cos(a) * r, h + rng.randf_range(-0.1, 0.2), sin(a) * r), Vector3(1.9, 1.35, 1.9) * s * rng.randf_range(0.9, 1.15), leaf.darkened(0.26), rng)
    for i in range(3):
        var a := TAU * (float(i) + 0.5) / 3.0 + rng.randf_range(-0.4, 0.4)
        var r := rng.randf_range(0.55, 0.85) * s
        _clump(Vector3(cos(a) * r, h + 0.8 + rng.randf_range(-0.1, 0.2), sin(a) * r), Vector3(1.9, 1.4, 1.9) * s * rng.randf_range(0.9, 1.1), leaf, rng)
    _clump(Vector3(rng.randf_range(-0.2, 0.2), h + 1.45 * s, rng.randf_range(-0.2, 0.2)), Vector3(1.8, 1.25, 1.8) * s, leaf.lightened(0.14), rng)
    _clump(Vector3(0.5 * s, h + 1.5 * s, -0.4 * s), Vector3(0.9, 0.6, 0.9) * s, leaf.lerp(Color(0.6, 0.75, 0.2), 0.35), rng)
    _col_cyl(Vector3.ZERO, 0.38, 3.0)

func _p_pine(x: float, z: float, rng: RandomNumberGenerator, snowy: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(3.2, 5.2)
    var bark := _jit(Color(0.30, 0.19, 0.1), 0.04, rng)
    var leaf := _jit(Color(0.09, 0.30, 0.15), 0.05, rng)
    var white := Color(0.94, 0.96, 1.0)
    _pc("cone", Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), bark.darkened(0.08))
    _pc("cyl", Vector3(0, 0.9, 0), Vector3(0.42, 1.8, 0.42), bark)
    var tiers := 4 if h > 4.0 else 3
    for i in range(tiers):
        var t := float(i) / float(tiers - 1)
        var w := lerpf(3.1, 1.1, t) * rng.randf_range(0.94, 1.06)
        var th := lerpf(1.6, 1.25, t)
        var y := 1.5 + t * (h - 2.5) + th * 0.5
        var c := leaf.darkened(0.16 * (1.0 - t)).lightened(0.05 * t)
        if snowy:
            c = c.lerp(white, 0.2 + 0.25 * t)
        _part("cone", Vector3(0, y, 0), Vector3(w, th, w), Vector3(0, rng.randf() * 60.0, 0), c)
        # нижній край ярусу трохи темніший: «тінь» під лапами
        _part("cone", Vector3(0, y - th * 0.32, 0), Vector3(w * 1.04, th * 0.4, w * 1.04), Vector3(0, rng.randf() * 60.0, 0), c.darkened(0.2))
        if snowy:
            _pc("cone", Vector3(0, y + th * 0.18, 0), Vector3(w * 0.8, th * 0.62, w * 0.8), white)
    var top := 1.5 + (h - 2.5) + 1.5
    _pc("cone", Vector3(0, top + 0.2, 0), Vector3(0.6, 1.0, 0.6), (white if snowy else leaf.lightened(0.1)))
    _col_cyl(Vector3.ZERO, 0.4, 3.0)

func _p_dead_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.2, 3.4)
    var bark := _jit(Color(0.30, 0.26, 0.22), 0.04, rng)
    _pc("cone", Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95), bark.darkened(0.08))
    _pc("cyl", Vector3(0, h * 0.35, 0), Vector3(0.38, h * 0.7, 0.38), bark)
    _pb("cone", Vector3(0, h * 0.65, 0), Vector3(rng.randf_range(-0.2, 0.2), h + 0.35, rng.randf_range(-0.2, 0.2)), 0.3, bark)
    var a0 := rng.randf() * TAU
    for i in range(4):
        var a := a0 + TAU * float(i) / 4.0 + rng.randf_range(-0.5, 0.5)
        var y0 := h * rng.randf_range(0.5, 0.85)
        var reach := rng.randf_range(0.8, 1.4)
        var p0 := Vector3(0, y0, 0)
        var p1 := Vector3(cos(a) * reach, y0 + rng.randf_range(0.4, 0.9), sin(a) * reach)
        _pb("cone", p0, p1, 0.16, bark)
        # розгалуження гілки
        var a2 := a + rng.randf_range(0.5, 0.9) * (1.0 if i % 2 == 0 else -1.0)
        var p2 := p1 + Vector3(cos(a2) * 0.55, rng.randf_range(0.25, 0.55), sin(a2) * 0.55)
        _pb("cone", p0.lerp(p1, 0.7), p2, 0.09, bark.darkened(0.05))
        _pb("cone", p1, p1 + Vector3(cos(a) * 0.4, 0.4, sin(a) * 0.4), 0.07, bark.darkened(0.05))
    _col_cyl(Vector3.ZERO, 0.3, 3.0)

# ---------- Рослинність ----------
func _p_bush(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := _jit(Color(0.2, 0.46, 0.15), 0.06, rng)
    var s := rng.randf_range(0.8, 1.4)
    for i in range(rng.randi_range(3, 5)):
        var a := rng.randf() * TAU
        var r := rng.randf_range(0.0, 0.55) * s
        var k := rng.randf_range(0.7, 1.1) * s
        _clump(Vector3(cos(a) * r, 0.3 * k + 0.05, sin(a) * r), Vector3(0.95, 0.75, 0.95) * k, c.darkened(0.12).lerp(c.lightened(0.1), rng.randf()), rng)
    var kind := rng.randf()
    if kind < 0.35:
        for i in range(rng.randi_range(4, 7)):
            var a := rng.randf() * TAU
            var r := rng.randf_range(0.35, 0.7) * s
            _pc("sphere", Vector3(cos(a) * r, rng.randf_range(0.35, 0.6) * s, sin(a) * r), Vector3(0.1, 0.1, 0.1), Color(0.78, 0.1, 0.12))
    elif kind < 0.5:
        for i in range(rng.randi_range(4, 6)):
            var a := rng.randf() * TAU
            var r := rng.randf_range(0.3, 0.7) * s
            _pc("sphere", Vector3(cos(a) * r, rng.randf_range(0.4, 0.65) * s, sin(a) * r), Vector3(0.13, 0.1, 0.13), Color(0.96, 0.9, 0.95))

func _p_flowers(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    var cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2), Color(0.95, 0.95, 0.95), Color(0.7, 0.3, 0.9), Color(0.95, 0.5, 0.15)]
    var main: Color = cols[rng.randi() % cols.size()]
    var green := Color(0.2, 0.5, 0.15)
    for i in range(7):
        var ox := rng.randf_range(-0.7, 0.7)
        var oz := rng.randf_range(-0.7, 0.7)
        var c: Color = main if rng.randf() < 0.7 else cols[rng.randi() % cols.size()]
        var fh := rng.randf_range(0.28, 0.46)
        _pb("cyl", Vector3(ox, 0.0, oz), Vector3(ox + rng.randf_range(-0.05, 0.05), fh, oz + rng.randf_range(-0.05, 0.05)), 0.03, green)
        _pc("sphere", Vector3(ox, fh, oz), Vector3(0.17, 0.09, 0.17), c)
        _pc("sphere", Vector3(ox, fh + 0.03, oz), Vector3(0.07, 0.07, 0.07), Color(0.95, 0.8, 0.2))
    for i in range(4):
        var a := rng.randf() * TAU
        _pb("cone", Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2), Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5), 0.1, green.darkened(0.1))

func _p_tuft(x: float, z: float, rng: RandomNumberGenerator, dry: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.25, 0.5, 0.15)
    if dry:
        c = Color(0.7, 0.6, 0.3)
    for i in range(7):
        var a := rng.randf() * TAU
        var r := rng.randf_range(0.0, 0.3)
        var hh := rng.randf_range(0.35, 0.7)
        var lean := rng.randf_range(0.05, 0.25)
        var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
        _pb("cone", base, base + Vector3(cos(a) * lean, hh, sin(a) * lean), 0.1, _jit(c, 0.07, rng).lerp(c.lightened(0.15), float(i) / 7.0))

func _p_reeds(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.30, 0.42, 0.18)
    for i in range(rng.randi_range(7, 11)):
        var a := rng.randf() * TAU
        var r := rng.randf_range(0.0, 0.6)
        var hh := rng.randf_range(0.9, 1.6)
        var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
        var tip := base + Vector3(rng.randf_range(-0.15, 0.15), hh, rng.randf_range(-0.15, 0.15))
        _pb("cyl", base, tip, 0.04, _jit(c, 0.06, rng))
        if rng.randf() < 0.5:
            _pb("cyl", tip - Vector3(0, 0.3, 0), tip + Vector3(0, 0.12, 0), 0.09, Color(0.32, 0.2, 0.1))

func _p_bramble(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.22, 0.17, 0.1)
    for i in range(rng.randi_range(6, 9)):
        var a := rng.randf() * TAU
        var p0 := Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
        var p1 := Vector3(cos(a) * rng.randf_range(0.7, 1.2), rng.randf_range(0.4, 0.9), sin(a) * rng.randf_range(0.7, 1.2))
        _pb("cone", p0, p1, 0.1, _jit(c, 0.04, rng))
        _pb("cone", p1, p1 + Vector3(cos(a + 0.8) * 0.35, 0.2, sin(a + 0.8) * 0.35), 0.06, c)
    for i in range(3):
        _clump(Vector3(rng.randf_range(-0.5, 0.5), 0.45, rng.randf_range(-0.5, 0.5)), Vector3(0.7, 0.4, 0.7), Color(0.18, 0.34, 0.12), rng)
    for i in range(rng.randi_range(2, 5)):
        _pc("sphere", Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.3, 0.7), rng.randf_range(-0.7, 0.7)), Vector3(0.09, 0.09, 0.09), Color(0.35, 0.1, 0.35))

func _p_mushroom(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    for i in range(rng.randi_range(3, 5)):
        var a := rng.randf() * TAU
        var r := rng.randf_range(0.0, 0.55)
        var ox := cos(a) * r
        var oz := sin(a) * r
        var s := rng.randf_range(0.6, 1.4)
        var cap := Color(0.8, 0.15, 0.12)
        var spots := true
        if rng.randf() < 0.4:
            cap = Color(0.65, 0.5, 0.3)
            spots = false
        _pc("cyl", Vector3(ox, 0.12 * s, oz), Vector3(0.1, 0.25 * s, 0.1), Color(0.9, 0.88, 0.8))
        _pc("sphere", Vector3(ox, 0.27 * s, oz), Vector3(0.36, 0.2, 0.36) * s, cap)
        if spots:
            for k in range(3):
                var sa := rng.randf() * TAU
                _pc("sphere", Vector3(ox + cos(sa) * 0.09 * s, 0.34 * s, oz + sin(sa) * 0.09 * s), Vector3(0.05, 0.03, 0.05) * s, Color(0.96, 0.94, 0.88))

# Ведьмине кільце: гриби по колу.
func _p_mushroom_ring(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    var n := rng.randi_range(9, 13)
    for i in range(n):
        var a := TAU * float(i) / float(n) + rng.randf_range(-0.1, 0.1)
        var r := 1.25 + rng.randf_range(-0.1, 0.1)
        var s := rng.randf_range(0.7, 1.2)
        _pc("cyl", Vector3(cos(a) * r, 0.12 * s, sin(a) * r), Vector3(0.09, 0.24 * s, 0.09), Color(0.9, 0.88, 0.8))
        _pc("sphere", Vector3(cos(a) * r, 0.27 * s, sin(a) * r), Vector3(0.3, 0.17, 0.3) * s, Color(0.85, 0.3, 0.2).lerp(Color(0.8, 0.75, 0.9), rng.randf() * 0.3))
    _pc("cyl", Vector3(0, 0.015, 0), Vector3(2.0, 0.02, 2.0), Color(0.14, 0.26, 0.1))

# ---------- Каміння ----------
func _p_rock(x: float, z: float, rng: RandomNumberGenerator, icy: bool) -> void:
    _begin(x, z, rng.randf() * TAU)
    var s := rng.randf_range(0.7, 1.8)
    var c := _stone(rng)
    if icy:
        c = Color(0.62, 0.8, 0.92).lerp(_stone(rng), 0.15)
    var top := 0.9 * s
    _chunk_of_rock(Vector3(0, s * 0.3, 0), Vector3(s * 1.35, s * 0.95, s * 1.15), c, rng)
    for i in range(rng.randi_range(1, 3)):
        var a := rng.randf() * TAU
        var k := rng.randf_range(0.4, 0.7)
        _chunk_of_rock(Vector3(cos(a) * s * 0.7, s * k * 0.2, sin(a) * s * 0.65), Vector3(s * k * 1.2, s * k * 0.8, s * k), c.darkened(rng.randf_range(0.04, 0.16)), rng)
    for i in range(rng.randi_range(1, 3)):
        var a := rng.randf() * TAU
        _chunk_of_rock(Vector3(cos(a) * s * 1.05, 0.06, sin(a) * s * 1.0), Vector3(0.22, 0.14, 0.2), c.darkened(0.1), rng)
    if icy:
        _chunk_of_rock(Vector3(0, s * 0.62, 0), Vector3(s * 0.95, s * 0.35, s * 0.8), Color(0.95, 0.97, 1.0), rng)
        for i in range(2):
            var a := rng.randf() * TAU
            _pb("cone", Vector3(cos(a) * s * 0.35, s * 0.4, sin(a) * s * 0.35), Vector3(cos(a) * s * 0.5, s * rng.randf_range(1.0, 1.4), sin(a) * s * 0.5), 0.22, Color(0.7, 0.88, 1.0))
    elif rng.randf() < 0.45:
        _chunk_of_rock(Vector3(rng.randf_range(-0.2, 0.2) * s, s * 0.62, rng.randf_range(-0.2, 0.2) * s), Vector3(s * 0.75, s * 0.22, s * 0.65), Color(0.22, 0.4, 0.14).lerp(c, 0.1), rng)
    _col_cyl(Vector3.ZERO, s * 0.62, 1.2)

func _p_stump(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_stump(rng)

func _m_stump(rng: RandomNumberGenerator) -> void:
    var bark := _jit(Color(0.38, 0.25, 0.14), 0.04, rng)
    _pc("cone", Vector3(0, 0.3, 0), Vector3(0.95, 0.6, 0.95), bark.darkened(0.06))
    _pc("cyl", Vector3(0, 0.27, 0), Vector3(0.62, 0.54, 0.62), bark)
    _pc("cyl", Vector3(0, 0.545, 0), Vector3(0.56, 0.03, 0.56), Color(0.66, 0.5, 0.31))
    _pc("cyl", Vector3(0, 0.56, 0), Vector3(0.4, 0.03, 0.4), Color(0.55, 0.4, 0.24))
    _pc("cyl", Vector3(0, 0.575, 0), Vector3(0.2, 0.03, 0.2), Color(0.66, 0.5, 0.31))
    for i in range(2):
        var a := rng.randf() * TAU
        _pb("cone", Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2), Vector3(cos(a) * 0.65, 0.02, sin(a) * 0.65), 0.2, bark.darkened(0.12))
    if rng.randf() < 0.3:
        var a := rng.randf() * TAU
        _pc("sphere", Vector3(cos(a) * 0.32, 0.3, sin(a) * 0.32), Vector3(0.18, 0.1, 0.18), Color(0.85, 0.5, 0.2))

func _p_log(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    _m_log(rng, true)

# Колода уздовж X: кора, торці з кільцями, пеньки гілок, мох. solid=false — лавка біля вогнища теж тверда, тож завжди true.
func _m_log(rng: RandomNumberGenerator, solid: bool) -> void:
    var bark := _jit(Color(0.35, 0.23, 0.12), 0.04, rng)
    _pb("cyl", Vector3(-1.2, 0.3, 0), Vector3(1.2, 0.3, 0), 0.6, bark)
    for sx in [-1.0, 1.0]:
        var e := float(sx) * 1.2
        _pb("cyl", Vector3(e - float(sx) * 0.01, 0.3, 0), Vector3(e + float(sx) * 0.02, 0.3, 0), 0.5, Color(0.66, 0.5, 0.31))
        _pb("cyl", Vector3(e, 0.3, 0), Vector3(e + float(sx) * 0.035, 0.3, 0), 0.3, Color(0.52, 0.38, 0.22))
    var bx := rng.randf_range(-0.6, 0.6)
    _pb("cyl", Vector3(bx, 0.45, 0.2), Vector3(bx + 0.1, 0.78, 0.3), 0.14, bark.darkened(0.1))
    if rng.randf() < 0.5:
        _chunk_of_rock(Vector3(rng.randf_range(-0.7, 0.7), 0.58, 0), Vector3(0.9, 0.18, 0.4), Color(0.22, 0.4, 0.14), rng)
    if solid:
        _col_box(Vector3.ZERO, Vector3(2.4, 0.6, 0.6))

func _p_fallen_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    var bark := _jit(Color(0.31, 0.2, 0.11), 0.04, rng)
    _pb("cyl", Vector3(-2.2, 0.4, 0), Vector3(2.0, 0.4, 0.1), 0.8, bark)
    _pb("cyl", Vector3(2.0, 0.4, 0.1), Vector3(3.2, 0.42, 0.25), 0.55, bark.darkened(0.04))
    _pb("cone", Vector3(-2.2, 0.4, 0), Vector3(-2.35, 0.95, 0.15), 0.8, Color(0.55, 0.42, 0.26))
    for k in range(4):
        var t := rng.randf_range(-1.6, 2.6)
        var sd := 1.0 if k % 2 == 0 else -1.0
        _pb("cone", Vector3(t, 0.55, 0.05 * sd), Vector3(t + 0.3, 1.0 + rng.randf() * 0.5, 0.7 * sd), 0.14, bark.darkened(0.1))
    for i in range(3):
        _clump(Vector3(rng.randf_range(0.6, 3.0), 0.7, rng.randf_range(-0.5, 0.6)), Vector3(0.9, 0.55, 0.9), Color(0.17, 0.4, 0.14), rng)
    _pc("cone", Vector3(-2.25, 0.3, 0), Vector3(1.3, 0.6, 1.3), bark.darkened(0.12))
    _col_box(Vector3(0.3, 0, 0), Vector3(5.2, 0.8, 0.8))

# ---------- Ферма ----------
func _p_haystack(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_haystack(rng)

func _m_haystack(rng: RandomNumberGenerator) -> void:
    var straw := _jit(Color(0.82, 0.7, 0.27), 0.04, rng)
    if rng.randf() < 0.4:
        # круглий тюк на боці
        _pb("cyl", Vector3(0, 0.7, -0.6), Vector3(0, 0.7, 0.6), 1.4, straw)
        for sz in [-1.0, 1.0]:
            _pb("cyl", Vector3(0, 0.7, float(sz) * 0.601), Vector3(0, 0.7, float(sz) * 0.62), 1.1, straw.darkened(0.12))
            _pb("cyl", Vector3(0, 0.7, float(sz) * 0.62), Vector3(0, 0.7, float(sz) * 0.64), 0.6, straw.lightened(0.05))
        _part("torus", Vector3(0, 0.7, -0.15), Vector3(1.45, 0.25, 1.45), Vector3(90, 0, 0), Color(0.4, 0.3, 0.12))
        _col_cyl(Vector3.ZERO, 0.85, 1.4)
        return
    _pc("cyl", Vector3(0, 0.6, 0), Vector3(1.5, 1.2, 1.5), straw)
    _pc("cone", Vector3(0, 1.55, 0), Vector3(1.65, 1.0, 1.65), straw.darkened(0.08))
    _pc("torus", Vector3(0, 1.15, 0), Vector3(1.52, 0.5, 1.52), straw.darkened(0.25))
    for i in range(6):
        var a := rng.randf() * TAU
        _pb("cyl", Vector3(cos(a) * 0.9, 0.04, sin(a) * 0.9), Vector3(cos(a) * 1.25, 0.05, sin(a) * 1.25), 0.05, straw.lightened(0.1))
    _col_cyl(Vector3.ZERO, 0.8, 1.9)

func _p_fence(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _fence_run(-1.6, 0.0, 1.6, 0.0, _jit(Color(0.42, 0.28, 0.14), 0.04, rng), rng)

func _p_hut(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_hut(rng)

func _m_hut(rng: RandomNumberGenerator) -> void:
    var wall := _jit(Color(0.74, 0.64, 0.46), 0.03, rng)
    var timber := Color(0.30, 0.19, 0.10)
    var roof := Color(0.66, 0.52, 0.2) if rng.randf() < 0.55 else Color(0.52, 0.22, 0.15)
    _pc("box", Vector3(0, 0.12, 0), Vector3(3.6, 0.24, 3.4), Color(0.42, 0.4, 0.37))
    _pc("box", Vector3(0, 1.15, 0), Vector3(3.2, 1.9, 3.0), wall)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _pc("box", Vector3(float(sx) * 1.6, 1.15, float(sz) * 1.5), Vector3(0.22, 1.95, 0.22), timber)
    for sz in [-1.0, 1.0]:
        _pc("box", Vector3(0, 2.0, float(sz) * 1.52), Vector3(3.2, 0.14, 0.1), timber)
        _pc("box", Vector3(0, 0.45, float(sz) * 1.52), Vector3(3.2, 0.1, 0.1), timber)
    _pc("wedge", Vector3(0, 2.6, 0), Vector3(3.95, 1.5, 4.1), roof)
    _pc("box", Vector3(0, 3.36, 0), Vector3(4.0, 0.12, 0.22), roof.darkened(0.3))
    for i in range(5):
        _pc("box", Vector3(-1.5 + 0.75 * float(i), 2.12, -2.06), Vector3(0.06, 0.1, 0.1), timber)
    # комин
    _pc("box", Vector3(1.0, 2.9, 0.75), Vector3(0.6, 1.8, 0.6), Color(0.45, 0.42, 0.4))
    _pc("box", Vector3(1.0, 3.84, 0.75), Vector3(0.78, 0.12, 0.78), Color(0.3, 0.28, 0.27))
    # двері й вікна (перед — у бік -Z)
    _pc("box", Vector3(0, 0.82, -1.52), Vector3(1.05, 1.6, 0.06), timber)
    _pc("box", Vector3(0, 0.75, -1.55), Vector3(0.82, 1.45, 0.08), Color(0.24, 0.14, 0.08))
    _pc("sphere", Vector3(0.3, 0.8, -1.6), Vector3(0.08, 0.08, 0.06), Color(0.8, 0.65, 0.2))
    _pc("box", Vector3(0, 0.07, -1.95), Vector3(1.4, 0.14, 0.7), Color(0.46, 0.44, 0.4))
    _pc("box", Vector3(1.0, 1.4, -1.52), Vector3(0.72, 0.62, 0.06), timber)
    _pc("box", Vector3(1.0, 1.4, -1.55), Vector3(0.52, 0.42, 0.08), Color(0.2, 0.28, 0.36))
    _pc("box", Vector3(1.0, 1.4, -1.57), Vector3(0.52, 0.05, 0.08), timber)
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(1.0 + float(sx) * 0.42, 1.4, -1.56), Vector3(0.18, 0.56, 0.05), timber.lightened(0.1))
    _pc("box", Vector3(1.62, 1.35, 0.2), Vector3(0.08, 0.42, 0.52), Color(0.2, 0.28, 0.36))
    _col_box(Vector3.ZERO, Vector3(3.4, 2.4, 3.2))

func _p_well(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_well(rng, false)

func _m_well(rng: RandomNumberGenerator, dry: bool) -> void:
    var st := _stone(rng).lightened(0.05)
    _pc("cyl", Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.6), st)
    _pc("torus", Vector3(0, 0.9, 0), Vector3(1.55, 0.3, 1.55), st.lightened(0.1))
    _pc("cyl", Vector3(0, 0.86, 0), Vector3(1.15, 0.05, 1.15), Color(0.03, 0.04, 0.05) if dry else Color(0.08, 0.16, 0.22))
    for i in range(8):
        var a := TAU * float(i) / 8.0
        _pc("box", Vector3(cos(a) * 0.8, 0.45 + 0.1 * float(i % 2), sin(a) * 0.8), Vector3(0.1, 0.9, 0.3), st.darkened(0.08 * float(i % 3)))
    var wood := Color(0.36, 0.24, 0.12)
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(float(sx) * 0.75, 1.4, 0), Vector3(0.14, 1.6, 0.14), wood)
    _pb("cyl", Vector3(-0.75, 1.55, 0), Vector3(0.75, 1.55, 0), 0.12, wood.lightened(0.05))
    _pc("wedge", Vector3(0, 2.4, 0), Vector3(2.0, 0.7, 1.6), Color(0.5, 0.25, 0.15))
    if not dry:
        _pb("cyl", Vector3(0, 1.5, 0), Vector3(0, 1.0, 0), 0.03, Color(0.5, 0.4, 0.25))
        _pc("cyl", Vector3(0, 0.88, 0.0), Vector3(0.26, 0.24, 0.26), wood.darkened(0.1))
    _col_cyl(Vector3.ZERO, 0.9, 2.0)

func _p_cart(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_cart(rng, 0)

# variant: 0 — з сіном, 1 — зламаний (без колеса, нахилений), 2 — обгорілий
func _m_cart(rng: RandomNumberGenerator, variant: int) -> void:
    var wood := _jit(Color(0.42, 0.28, 0.14), 0.04, rng)
    if variant == 2:
        wood = Color(0.09, 0.07, 0.06)
    var tilt := 0.0 if variant != 1 else 9.0
    _part("box", Vector3(0, 0.78, 0), Vector3(2.4, 0.12, 1.3), Vector3(0, 0, tilt), wood.darkened(0.1))
    for sz in [-1.0, 1.0]:
        _part("box", Vector3(0, 1.08, float(sz) * 0.64), Vector3(2.4, 0.5, 0.08), Vector3(0, 0, tilt), wood)
    for sx in [-1.0, 1.0]:
        _part("box", Vector3(float(sx) * 1.18, 1.08, 0), Vector3(0.08, 0.5, 1.3), Vector3(0, 0, tilt), wood)
    _pb("box", Vector3(1.1, 0.75, -0.4), Vector3(3.2, 0.5, -0.4), 0.1, wood.lightened(0.05))
    _pb("box", Vector3(1.1, 0.75, 0.4), Vector3(3.2, 0.5, 0.4), 0.1, wood.lightened(0.05))
    for sz in [-1.0, 1.0]:
        if variant == 1 and sz > 0.0:
            _part("torus", Vector3(-1.4, 0.07, 1.9), Vector3(1.0, 0.18, 1.0), Vector3(0, 0, 0), wood.darkened(0.2))
            continue
        var wy := 0.5
        _part("torus", Vector3(0, wy, float(sz) * 0.82), Vector3(1.0, 0.2, 1.0), Vector3(90, 0, 0), wood.darkened(0.2))
        _part("box", Vector3(0, wy, float(sz) * 0.82), Vector3(0.9, 0.07, 0.05), Vector3(0, 0, 0), wood.darkened(0.1))
        _part("box", Vector3(0, wy, float(sz) * 0.82), Vector3(0.07, 0.9, 0.05), Vector3(0, 0, 0), wood.darkened(0.1))
        _pc("cyl", Vector3(0, wy, float(sz) * 0.82), Vector3(0.12, 0.12, 0.12), wood.darkened(0.3))
    if variant == 0:
        _pc("leaf", Vector3(0, 1.3, 0), Vector3(2.0, 0.8, 1.1), Color(0.82, 0.7, 0.27))
        _pc("leaf", Vector3(-0.3, 1.5, 0.1), Vector3(1.2, 0.5, 0.8), Color(0.75, 0.62, 0.22))
    _col_box(Vector3(0.2, 0, 0), Vector3(3.4, 1.0, 1.4))

func _p_scarecrow(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_scarecrow(rng)

func _m_scarecrow(rng: RandomNumberGenerator) -> void:
    var wood := Color(0.36, 0.24, 0.12)
    var cloth := Color.from_hsv(rng.randf_range(0.0, 0.12), 0.45, 0.45)
    _pb("cyl", Vector3(0, 0, 0), Vector3(0, 2.3, 0), 0.1, wood)
    _pb("cyl", Vector3(-0.95, 1.7, 0), Vector3(0.95, 1.55, 0), 0.08, wood)
    _pc("box", Vector3(0, 1.55, 0), Vector3(0.62, 0.8, 0.34), cloth)
    _pc("box", Vector3(0, 1.1, 0), Vector3(0.7, 0.18, 0.4), cloth.darkened(0.2))
    _pc("sphere", Vector3(0, 2.05, 0), Vector3(0.42, 0.44, 0.42), Color(0.78, 0.66, 0.4))
    _pc("cyl", Vector3(0, 2.28, 0), Vector3(0.78, 0.04, 0.78), Color(0.36, 0.25, 0.12))
    _pc("cyl", Vector3(0, 2.42, 0), Vector3(0.4, 0.28, 0.4), Color(0.36, 0.25, 0.12))
    for sx in [-1.0, 1.0]:
        for k in range(3):
            _pb("cone", Vector3(float(sx) * (0.7 + 0.1 * float(k)), 1.6, 0), Vector3(float(sx) * (0.9 + 0.1 * float(k)), 1.3 - 0.06 * float(k), 0.02 * float(k)), 0.07, Color(0.85, 0.72, 0.3))
    _col_cyl(Vector3.ZERO, 0.3, 2.2)

func _p_crops(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    _m_crops(rng)

# Грядки: ґрунтові борозни з рядами пшениці, капусти або гарбузів.
func _m_crops(rng: RandomNumberGenerator) -> void:
    var kind := rng.randi_range(0, 2)
    var soil := Color(0.2, 0.13, 0.08)
    for r in range(3):
        var zz := (float(r) - 1.0) * 0.85
        _pc("box", Vector3(0, 0.07, zz), Vector3(3.0, 0.14, 0.5), soil.lightened(0.04 * float(r)))
        for k in range(7):
            var xx := -1.35 + 0.45 * float(k) + rng.randf_range(-0.04, 0.04)
            match kind:
                0:
                    _pb("cone", Vector3(xx, 0.1, zz), Vector3(xx + 0.05, 0.85 + rng.randf() * 0.2, zz), 0.16, _jit(Color(0.85, 0.7, 0.25), 0.05, rng))
                    _pb("cone", Vector3(xx, 0.1, zz + 0.12), Vector3(xx - 0.05, 0.7, zz + 0.2), 0.1, Color(0.6, 0.6, 0.2))
                1:
                    _clump(Vector3(xx, 0.28, zz), Vector3(0.4, 0.32, 0.4), _jit(Color(0.34, 0.55, 0.22), 0.05, rng), rng)
                _:
                    _pc("sphere", Vector3(xx, 0.24, zz), Vector3(0.36, 0.28, 0.36), _jit(Color(0.9, 0.45, 0.1), 0.05, rng))
                    _pc("cyl", Vector3(xx, 0.42, zz), Vector3(0.05, 0.1, 0.05), Color(0.25, 0.4, 0.15))

func _p_beehive(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var wood := Color(0.55, 0.42, 0.22)
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(float(sx) * 0.45, 0.2, 0), Vector3(0.1, 0.4, 0.5), Color(0.34, 0.22, 0.12))
    for i in range(3):
        _pc("box", Vector3(0, 0.55 + 0.2 * float(i), 0), Vector3(0.85, 0.2, 0.7), wood.lightened(0.04 * float(i % 2)))
    _pc("wedge", Vector3(0, 1.25, 0), Vector3(1.0, 0.35, 0.85), Color(0.7, 0.68, 0.62))
    _pc("box", Vector3(0, 0.55, -0.355), Vector3(0.2, 0.05, 0.02), Color(0.08, 0.06, 0.04))
    _col_cyl(Vector3.ZERO, 0.55, 1.3)

func _p_woodpile(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var bark := Color(0.38, 0.25, 0.13)
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(float(sx) * 1.3, 0.5, 0), Vector3(0.12, 1.0, 0.7), Color(0.3, 0.2, 0.1))
    for row in range(3):
        var n := 4 - (1 if row == 2 else 0)
        for k in range(n):
            var zz := -0.27 + 0.18 * float(k) + (0.09 if row == 1 else 0.0) - (0.09 if row == 2 else 0.0) * 0.0
            var yy := 0.12 + 0.22 * float(row)
            var c := _jit(bark, 0.05, rng)
            _pb("cyl", Vector3(-1.2, yy, zz * 1.6), Vector3(1.2, yy, zz * 1.6), 0.24, c)
            _pb("cyl", Vector3(1.2, yy, zz * 1.6), Vector3(1.215, yy, zz * 1.6), 0.18, Color(0.7, 0.55, 0.35))
    _pb("cyl", Vector3(-1.5, 0.12, 1.1), Vector3(-0.4, 0.12, 1.2), 0.22, bark)
    _col_box(Vector3.ZERO, Vector3(2.7, 0.9, 0.9))
# ---------- Пустеля ----------
func _p_cactus(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := _jit(Color(0.2, 0.5, 0.22), 0.04, rng)
    if rng.randf() < 0.3:
        # бочкоподібний кактус із квіткою
        var s := rng.randf_range(0.8, 1.3)
        _pc("sphere", Vector3(0, 0.4 * s, 0), Vector3(0.9, 0.85, 0.9) * s, c.darkened(0.05))
        for i in range(8):
            var a := TAU * float(i) / 8.0
            _pb("cyl", Vector3(cos(a) * 0.2 * s, 0.1, sin(a) * 0.2 * s), Vector3(cos(a) * 0.28 * s, 0.65 * s, sin(a) * 0.28 * s), 0.05, c.lightened(0.15))
        _pc("sphere", Vector3(0, 0.82 * s, 0), Vector3(0.22, 0.12, 0.22), Color(0.95, 0.4, 0.55))
        _col_cyl(Vector3.ZERO, 0.45 * s, 1.0)
        return
    var h := rng.randf_range(1.8, 2.8)
    _pc("cyl", Vector3(0, h * 0.5, 0), Vector3(0.5, h, 0.5), c)
    _pc("sphere", Vector3(0, h, 0), Vector3(0.5, 0.45, 0.5), c.lightened(0.04))
    for i in range(6):
        var a := TAU * float(i) / 6.0
        _pb("cyl", Vector3(cos(a) * 0.24, 0.2, sin(a) * 0.24), Vector3(cos(a) * 0.25, h - 0.1, sin(a) * 0.25), 0.04, c.lightened(0.14))
    var a0 := rng.randf() * TAU
    for i in range(rng.randi_range(1, 2)):
        var sd := 1.0 if i == 0 else -1.0
        var ya := h * rng.randf_range(0.4, 0.65)
        var dir := Vector3(cos(a0), 0, sin(a0)) * sd
        _pb("cyl", Vector3(0, ya, 0) + dir * 0.1, Vector3(0, ya, 0) + dir * 0.7, 0.28, c)
        _pb("cyl", Vector3(0, ya, 0) + dir * 0.7, Vector3(0, ya + rng.randf_range(0.6, 0.95), 0) + dir * 0.7, 0.26, c)
        _pc("sphere", Vector3(0, ya + 0.8, 0) + dir * 0.7, Vector3(0.26, 0.2, 0.26), c.lightened(0.05))
    if rng.randf() < 0.35:
        _pc("sphere", Vector3(0, h + 0.2, 0), Vector3(0.2, 0.12, 0.2), Color(0.95, 0.35, 0.5))
    _col_cyl(Vector3.ZERO, 0.4, 2.0)

func _p_bones(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_bones(rng)

func _m_skull(lpos: Vector3, s: float, yaw: float, b: Color) -> void:
    _part("sphere", lpos + Vector3(0, 0.13 * s, 0), Vector3(0.3, 0.26, 0.32) * s, Vector3(0, yaw, 0), b)
    _part("box", lpos + Vector3(0, 0.04 * s, -0.12 * s), Vector3(0.18, 0.08, 0.14) * s, Vector3(0, yaw, 0), b.darkened(0.08))
    for sx in [-1.0, 1.0]:
        var o := Vector3(float(sx) * 0.07 * s, 0.15 * s, -0.12 * s).rotated(Vector3.UP, deg_to_rad(yaw))
        _pc("sphere", lpos + o, Vector3(0.07, 0.08, 0.05) * s, Color(0.04, 0.03, 0.03))

func _m_bones(rng: RandomNumberGenerator) -> void:
    var b := _jit(Color(0.9, 0.87, 0.78), 0.04, rng)
    _m_skull(Vector3(0, 0, -0.1), 1.0, rng.randf_range(-40, 40), b)
    for i in range(rng.randi_range(3, 5)):
        var a := rng.randf_range(-0.9, 0.9)
        var p0 := Vector3(0.1 * float(i) - 0.15, 0.05, 0.2)
        var p1 := p0 + Vector3(sin(a) * 0.35, 0.0, cos(a) * 0.55)
        _pb("cyl", p0, p1, 0.06, b)
        _pb("cyl", p1, p1 + (p1 - p0).normalized() * 0.04, 0.1, b.lightened(0.05))
    var la := rng.randf() * TAU
    var q0 := Vector3(0.5, 0.05, 0.5)
    _pb("cyl", q0, q0 + Vector3(cos(la), 0, sin(la)) * 0.7, 0.07, b.darkened(0.04))

func _p_skull_pile(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var b := Color(0.88, 0.84, 0.74)
    _pc("cyl", Vector3(0, 0.05, 0), Vector3(2.0, 0.1, 2.0), Color(0.5, 0.4, 0.26))
    var n := rng.randi_range(6, 9)
    for i in range(n):
        var ring := 0 if i < 5 else 1
        var a := TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
        var r := 0.55 if ring == 0 else 0.0
        _m_skull(Vector3(cos(a) * r, 0.0 if ring == 0 else 0.22, sin(a) * r), rng.randf_range(0.85, 1.15), rad_to_deg(a) + 90.0, _jit(b, 0.05, rng))
    for i in range(5):
        var a := rng.randf() * TAU
        var p0 := Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5)
        _pb("cyl", p0, p0 + Vector3(cos(a + 0.4), rng.randf_range(0.0, 0.4), sin(a + 0.4)) * 0.8, 0.06, b)
    _col_cyl(Vector3.ZERO, 0.8, 0.5)

func _p_ribcage(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var b := Color(0.86, 0.82, 0.72)
    _pb("cyl", Vector3(-2.0, 0.55, 0), Vector3(2.0, 0.4, 0), 0.16, b)
    for i in range(7):
        var xx := -1.4 + 0.5 * float(i)
        var hh := 1.15 - 0.09 * absf(float(i) - 3.0)
        for sz in [-1.0, 1.0]:
            var p0 := Vector3(xx, 0.5, 0)
            var p1 := Vector3(xx, 0.5 + hh * 0.7, float(sz) * 0.8)
            var p2 := Vector3(xx + 0.05, 0.08, float(sz) * 1.0)
            _pb("cyl", p0, p1, 0.07, b)
            _pb("cyl", p1, p2, 0.065, b.darkened(0.04))
    _m_skull(Vector3(2.4, 0.0, 0.3), 2.2, 20.0, b)
    for i in range(4):
        _pb("cyl", Vector3(2.0 + 0.0, 0.2, 0.1 * float(i)), Vector3(2.6, 0.06, -0.6 + 0.5 * float(i)), 0.07, b)
    _col_box(Vector3(0, 0, 0), Vector3(3.2, 0.5, 0.5))

func _p_dune(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var sand := _jit(Color(0.82, 0.7, 0.42), 0.03, rng)
    var w := rng.randf_range(5.0, 9.0)
    var d := rng.randf_range(4.0, 7.0)
    var h := rng.randf_range(1.6, 2.6)
    _pc("sphere", Vector3(0, 0.0, 0), Vector3(w, h, d), sand)
    _pc("sphere", Vector3(w * 0.28, -0.1, d * 0.12), Vector3(w * 0.55, h * 0.7, d * 0.6), sand.lightened(0.05))
    _pc("sphere", Vector3(-w * 0.3, -0.1, -d * 0.15), Vector3(w * 0.5, h * 0.6, d * 0.5), sand.darkened(0.05))
    # гребінь — тонка світла смуга
    _part("sphere", Vector3(0, h * 0.35, 0), Vector3(w * 0.7, h * 0.18, d * 0.12), Vector3(0, 0, 0), sand.lightened(0.12))

func _p_obelisk(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(3.2, 5.0)
    var c := Color(0.75, 0.65, 0.45)
    _pc("box", Vector3(0, 0.15, 0), Vector3(2.2, 0.3, 2.2), c.darkened(0.15))
    _pc("box", Vector3(0, 0.4, 0), Vector3(1.8, 0.25, 1.8), c.darkened(0.1))
    _pc("box", Vector3(0, 0.65, 0), Vector3(1.4, 0.25, 1.4), c.darkened(0.05))
    _pc("box", Vector3(0, 0.65 + h * 0.5, 0), Vector3(0.95, h, 0.95), c)
    for i in range(4):
        _pc("box", Vector3(0, 1.3 + h * 0.18 * float(i), 0), Vector3(1.0, 0.1, 1.0), c.darkened(0.2))
        for sx in [-1.0, 1.0]:
            _pc("box", Vector3(float(sx) * 0.21, 1.5 + h * 0.18 * float(i), -0.48), Vector3(0.1, 0.22, 0.03), c.darkened(0.35))
    _pc("wedge", Vector3(0, 0.65 + h + 0.15, 0), Vector3(1.0, 0.7, 1.0), Color(0.9, 0.75, 0.3))
    _pc("cone", Vector3(0, 0.65 + h + 0.4, 0), Vector3(0.9, 0.7, 0.9), Color(0.9, 0.75, 0.3))
    _chunk_of_rock(Vector3(1.6, 0.15, 1.0), Vector3(0.5, 0.3, 0.45), c.darkened(0.12), rng)
    _col_box(Vector3.ZERO, Vector3(2.0, h, 2.0))

# ---------- Сніг і лід ----------
func _p_snow_mound(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var w := rng.randf_range(2.0, 4.0)
    var d := rng.randf_range(2.0, 3.5)
    var h := rng.randf_range(0.8, 1.4)
    _pc("sphere", Vector3(0, 0.0, 0), Vector3(w, h, d), Color(0.96, 0.97, 1.0))
    _pc("sphere", Vector3(w * 0.28, -0.05, d * 0.18), Vector3(w * 0.55, h * 0.75, d * 0.6), Color(0.9, 0.94, 1.0))
    _pc("sphere", Vector3(-w * 0.3, -0.05, -d * 0.2), Vector3(w * 0.5, h * 0.6, d * 0.5), Color(0.84, 0.9, 0.99))
    if rng.randf() < 0.4:
        _pb("cone", Vector3(0.2, h * 0.3, 0.2), Vector3(0.5, h * 0.3 + 0.8, 0.4), 0.05, Color(0.3, 0.2, 0.12))

func _p_ice_crystal(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.55, 0.84, 1.0)
    _chunk_of_rock(Vector3(0, 0.15, 0), Vector3(1.4, 0.5, 1.3), Color(0.6, 0.78, 0.9), rng)
    _part("crystal", Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.7), Vector3(0, rng.randf() * 60.0, rng.randf_range(-6, 6)), c)
    for i in range(rng.randi_range(3, 5)):
        var a := rng.randf() * TAU
        var k := rng.randf_range(0.5, 1.0)
        var lean := rng.randf_range(12.0, 30.0)
        _part("crystal", Vector3(cos(a) * 0.5, 0.55 * k + 0.1, sin(a) * 0.5), Vector3(0.4, 1.2 * k, 0.4), Vector3(sin(a) * lean, rng.randf() * 60.0, -cos(a) * lean), c.lightened(rng.randf_range(-0.08, 0.14)))
    _col_cyl(Vector3.ZERO, 0.55, 1.6)

func _p_frozen_statue(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_frozen_statue(rng)

func _m_frozen_statue(rng: RandomNumberGenerator) -> void:
    var ice := Color(0.62, 0.84, 0.96)
    var fig := Color(0.35, 0.4, 0.5)
    _chunk_of_rock(Vector3(0, 0.3, 0), Vector3(1.8, 0.9, 1.6), ice.lightened(0.05), rng)
    _pc("cyl", Vector3(0, 1.0, 0), Vector3(0.5, 1.1, 0.4), fig)
    _pc("sphere", Vector3(0, 1.75, 0), Vector3(0.38, 0.4, 0.38), fig.lightened(0.1))
    _pb("cyl", Vector3(0.22, 1.5, 0), Vector3(0.55, 2.1, -0.1), 0.14, fig)
    _pb("cyl", Vector3(-0.22, 1.5, 0), Vector3(-0.35, 0.95, 0.0), 0.14, fig)
    _part("crystal", Vector3(0, 1.4, 0), Vector3(1.4, 2.5, 1.2), Vector3(0, rng.randf() * 60.0, 0), Color(0.7, 0.9, 1.0))
    for i in range(3):
        var a := rng.randf() * TAU
        _part("crystal", Vector3(cos(a) * 0.9, 0.35, sin(a) * 0.9), Vector3(0.35, 0.9, 0.35), Vector3(sin(a) * 20.0, 0.0, -cos(a) * 20.0), ice)
    _col_cyl(Vector3.ZERO, 0.9, 2.2)

func _p_sled(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var wood := Color(0.4, 0.27, 0.14)
    for sz in [-1.0, 1.0]:
        _pc("box", Vector3(0, 0.16, float(sz) * 0.45), Vector3(2.0, 0.07, 0.1), Color(0.2, 0.2, 0.22))
        _pb("cyl", Vector3(1.0, 0.16, float(sz) * 0.45), Vector3(1.28, 0.38, float(sz) * 0.45), 0.07, Color(0.2, 0.2, 0.22))
        for k in range(3):
            _pc("box", Vector3(-0.7 + 0.7 * float(k), 0.28, float(sz) * 0.45), Vector3(0.08, 0.2, 0.08), wood.darkened(0.1))
    for k in range(7):
        _pc("box", Vector3(-0.8 + 0.27 * float(k), 0.4, 0), Vector3(0.22, 0.05, 1.1), wood.lightened(0.04 * float(k % 2)))
    _pc("box", Vector3(-0.3, 0.65, 0.05), Vector3(0.8, 0.45, 0.6), Color(0.35, 0.3, 0.2))
    _pc("leaf", Vector3(-0.3, 0.9, 0.05), Vector3(1.0, 0.35, 0.8), Color(0.92, 0.95, 1.0))
    _pb("cyl", Vector3(1.28, 0.38, 0.45), Vector3(2.6, 0.1, 0.1), 0.03, Color(0.5, 0.4, 0.25))
    _col_box(Vector3.ZERO, Vector3(2.2, 0.8, 1.2))

func _p_igloo(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_igloo(rng)

func _m_igloo(rng: RandomNumberGenerator) -> void:
    var snow := Color(0.94, 0.96, 1.0)
    _pc("sphere", Vector3(0, 0.0, 0), Vector3(3.6, 3.8, 3.6), snow)
    for i in range(3):
        _pc("torus", Vector3(0, 0.35 + 0.55 * float(i), 0), Vector3(3.3 - 0.9 * float(i), 0.06, 3.3 - 0.9 * float(i)), snow.darkened(0.12))
    _pc("sphere", Vector3(0, 0.0, -1.7), Vector3(1.5, 1.5, 1.9), snow.darkened(0.03))
    _pc("box", Vector3(0, 0.45, -2.5), Vector3(0.7, 0.8, 0.1), Color(0.06, 0.07, 0.1))
    _pc("sphere", Vector3(0, 0.6, -2.35), Vector3(0.9, 0.4, 0.3), snow.darkened(0.08))
    for i in range(3):
        var a := rng.randf() * TAU
        _chunk_of_rock(Vector3(cos(a) * 2.1, 0.1, sin(a) * 2.1 + 0.4), Vector3(0.6, 0.4, 0.5), Color(0.9, 0.94, 1.0), rng)
    _col_cyl(Vector3(0, 0, 0.2), 1.75, 1.8)

# ---------- Цвинтар ----------
func _p_tombstone(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_tombstone(rng)

func _m_tombstone(rng: RandomNumberGenerator) -> void:
    var c := _stone(rng)
    var tilt := rng.randf_range(-6.0, 6.0)
    var v := rng.randi_range(0, 3)
    _pc("sphere", Vector3(0, 0.05, 0.75), Vector3(0.8, 0.28, 1.3), Color(0.2, 0.15, 0.11))
    _pc("box", Vector3(0, 0.07, 0), Vector3(0.9, 0.14, 0.36), c.darkened(0.12))
    match v:
        0:
            _part("box", Vector3(0, 0.55, 0), Vector3(0.7, 0.9, 0.18), Vector3(0, 0, tilt), c)
            _part("sphere", Vector3(0, 1.0, 0), Vector3(0.7, 0.5, 0.18), Vector3(0, 0, tilt), c)
        1:
            _part("box", Vector3(0, 0.5, 0), Vector3(0.8, 0.75, 0.16), Vector3(0, 0, tilt), c.lightened(0.04))
            _part("box", Vector3(0, 0.95, 0), Vector3(0.88, 0.1, 0.2), Vector3(0, 0, tilt), c.darkened(0.06))
        2:
            _part("box", Vector3(0, 0.75, 0), Vector3(0.45, 1.4, 0.18), Vector3(0, 0, tilt), c)
            _part("box", Vector3(0, 1.05, 0), Vector3(0.8, 0.14, 0.2), Vector3(0, 0, tilt), c.lightened(0.05))
        _:
            _part("box", Vector3(0, 0.35, 0), Vector3(0.7, 0.5, 0.2), Vector3(0, 0, tilt), c)
            _chunk_of_rock(Vector3(0.7, 0.14, -0.3), Vector3(0.45, 0.28, 0.3), c.darkened(0.08), rng)
    if rng.randf() < 0.35:
        _clump(Vector3(rng.randf_range(-0.2, 0.2), 0.1, -0.12), Vector3(0.5, 0.18, 0.2), Color(0.2, 0.34, 0.14), rng)
    if rng.randf() < 0.25:
        _pc("sphere", Vector3(0.0, 0.2, -0.3), Vector3(0.14, 0.1, 0.14), Color(0.8, 0.8, 0.85))
    _col_box(Vector3.ZERO, Vector3(0.8, 1.2, 0.35))

func _p_cross(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_cross(rng)

func _m_cross(rng: RandomNumberGenerator) -> void:
    var tilt := rng.randf_range(-6.0, 6.0)
    var v := rng.randi_range(0, 2)
    _pc("sphere", Vector3(0, 0.05, 0.7), Vector3(0.7, 0.25, 1.2), Color(0.2, 0.15, 0.11))
    if v == 0:
        var c := _stone(rng)
        _pc("box", Vector3(0, 0.1, 0), Vector3(0.7, 0.2, 0.7), c.darkened(0.1))
        _part("box", Vector3(0, 0.2 + 0.6, 0), Vector3(0.17, 1.2, 0.17), Vector3(0, 0, tilt), c)
        _part("box", Vector3(0, 0.2 + 0.95, 0), Vector3(0.8, 0.17, 0.17), Vector3(0, 0, tilt), c)
    elif v == 1:
        var w := Color(0.3, 0.2, 0.11)
        _part("box", Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.1), Vector3(0, 0, tilt), w)
        _part("box", Vector3(0, 0.95, 0), Vector3(0.7, 0.12, 0.1), Vector3(0, 0, tilt + 4.0), w.lightened(0.05))
        _pc("box", Vector3(0, 0.1, 0.0), Vector3(0.4, 0.2, 0.3), Color(0.35, 0.33, 0.3))
    else:
        var c2 := _stone(rng).lightened(0.05)
        _pc("box", Vector3(0, 0.15, 0), Vector3(0.6, 0.3, 0.6), c2.darkened(0.1))
        _part("box", Vector3(0, 0.3 + 0.55, 0), Vector3(0.14, 1.1, 0.14), Vector3(0, 0, tilt), c2)
        _part("box", Vector3(0, 0.3 + 0.8, 0), Vector3(0.6, 0.14, 0.14), Vector3(0, 0, tilt), c2)
        _part("torus", Vector3(0, 0.3 + 0.8, 0), Vector3(0.5, 0.1, 0.5), Vector3(90, 0, tilt), c2.lightened(0.05))
    _col_cyl(Vector3.ZERO, 0.28, 1.4)

func _p_angel_statue(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_angel(rng)

func _m_angel(rng: RandomNumberGenerator) -> void:
    var c := Color(0.7, 0.72, 0.74).darkened(rng.randf_range(0.0, 0.15))
    _pc("box", Vector3(0, 0.2, 0), Vector3(1.4, 0.4, 1.4), c.darkened(0.15))
    _pc("box", Vector3(0, 0.8, 0), Vector3(1.0, 0.8, 1.0), c.darkened(0.08))
    _pc("box", Vector3(0, 1.28, 0), Vector3(1.2, 0.16, 1.2), c.darkened(0.12))
    _pc("cone", Vector3(0, 2.0, 0), Vector3(0.85, 1.4, 0.85), c)
    _pc("sphere", Vector3(0, 2.85, 0), Vector3(0.38, 0.42, 0.38), c.lightened(0.05))
    _pb("cyl", Vector3(0.2, 2.5, 0), Vector3(0.12, 2.0, -0.35), 0.14, c)
    _pb("cyl", Vector3(-0.2, 2.5, 0), Vector3(-0.12, 2.0, -0.35), 0.14, c)
    for sx in [-1.0, 1.0]:
        _part("box", Vector3(float(sx) * 0.55, 2.55, 0.28), Vector3(0.07, 1.5, 0.5), Vector3(0, float(sx) * 25.0, float(sx) * -22.0), c.lightened(0.08))
        _part("box", Vector3(float(sx) * 0.85, 2.0, 0.42), Vector3(0.06, 0.8, 0.4), Vector3(0, float(sx) * 25.0, float(sx) * -30.0), c)
    if rng.randf() < 0.5:
        _clump(Vector3(0.3, 0.5, -0.5), Vector3(0.5, 0.35, 0.3), Color(0.2, 0.36, 0.14), rng)
    _col_cyl(Vector3.ZERO, 0.75, 3.0)

func _p_crypt(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := Color(0.34, 0.33, 0.36)
    _pc("box", Vector3(0, 0.15, 0), Vector3(3.8, 0.3, 4.2), c.darkened(0.15))
    _pc("box", Vector3(0, 1.3, 0), Vector3(3.0, 2.2, 3.4), c)
    _pc("box", Vector3(0, 2.5, 0), Vector3(3.4, 0.3, 3.8), c.darkened(0.1))
    _pc("wedge", Vector3(0, 3.0, 0), Vector3(3.4, 0.9, 3.8), c.darkened(0.05))
    _pc("box", Vector3(0, 3.5, -1.95), Vector3(0.08, 0.08, 0.08), c)
    _pc("box", Vector3(0, 3.7, 0), Vector3(0.16, 0.9, 0.16), c.lightened(0.05))
    _pc("box", Vector3(0, 3.8, 0), Vector3(0.6, 0.14, 0.16), c.lightened(0.05))
    for sx in [-1.0, 1.0]:
        _pc("cyl", Vector3(float(sx) * 1.0, 1.35, -1.95), Vector3(0.4, 2.2, 0.4), c.lightened(0.06))
        _pc("box", Vector3(float(sx) * 1.0, 0.45, -1.95), Vector3(0.55, 0.2, 0.55), c.darkened(0.08))
        _pc("box", Vector3(float(sx) * 1.0, 2.45, -1.95), Vector3(0.55, 0.2, 0.55), c.darkened(0.08))
    _pc("box", Vector3(0, 0.95, -1.74), Vector3(1.2, 1.7, 0.12), c.darkened(0.2))
    _pc("box", Vector3(0, 0.85, -1.8), Vector3(0.9, 1.5, 0.08), Color(0.05, 0.04, 0.05))
    for k in range(4):
        _pc("box", Vector3(-0.3 + 0.2 * float(k), 0.85, -1.84), Vector3(0.04, 1.4, 0.03), Color(0.14, 0.14, 0.16))
    _pc("box", Vector3(0, 0.1, -2.3), Vector3(2.2, 0.2, 0.7), c.darkened(0.2))
    for i in range(3):
        _clump(Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(0.5, 2.0), 1.72), Vector3(0.7, 0.6, 0.2), Color(0.18, 0.3, 0.14), rng)
    _col_box(Vector3.ZERO, Vector3(3.8, 2.8, 4.0))

func _p_mausoleum(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := Color(0.52, 0.5, 0.5)
    _pc("box", Vector3(0, 0.15, 0), Vector3(5.6, 0.3, 5.4), c.darkened(0.2))
    _pc("box", Vector3(0, 0.45, 0), Vector3(5.0, 0.3, 5.0), c.darkened(0.12))
    _pc("box", Vector3(0, 1.9, 0.3), Vector3(4.0, 2.6, 4.2), c)
    _pc("box", Vector3(0, 3.3, 0.3), Vector3(4.4, 0.3, 4.6), c.darkened(0.1))
    _pc("wedge", Vector3(0, 3.9, 0.3), Vector3(4.4, 1.0, 4.6), c.darkened(0.06))
    _pc("wedge", Vector3(0, 3.8, -2.1), Vector3(0.1, 1.0, 4.4), c.lightened(0.04))
    for sx in [-1.5, -0.5, 0.5, 1.5]:
        _pc("cyl", Vector3(float(sx), 1.85, -2.05), Vector3(0.45, 2.7, 0.45), c.lightened(0.1))
        _pc("box", Vector3(float(sx), 0.65, -2.05), Vector3(0.6, 0.2, 0.6), c.darkened(0.05))
        _pc("box", Vector3(float(sx), 3.25, -2.05), Vector3(0.6, 0.2, 0.6), c.darkened(0.05))
    _pc("box", Vector3(0, 1.4, -1.8), Vector3(1.0, 2.0, 0.1), Color(0.05, 0.04, 0.05))
    _pc("box", Vector3(0, 4.55, -0.2), Vector3(0.2, 1.0, 0.2), c.lightened(0.1))
    _pc("box", Vector3(0, 4.7, -0.2), Vector3(0.7, 0.16, 0.2), c.lightened(0.1))
    _pc("box", Vector3(0, 0.1, -3.2), Vector3(3.6, 0.2, 1.0), c.darkened(0.2))
    for sx in [-1.0, 1.0]:
        _pc("cone", Vector3(float(sx) * 2.3, 0.7, -2.2), Vector3(0.7, 1.4, 0.7), Color(0.12, 0.2, 0.1))
    _col_box(Vector3(0, 0, 0.2), Vector3(5.0, 3.5, 4.8))

func _p_iron_fence(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _iron_run(-1.65, 0.0, 1.65, 0.0, rng)

func _p_open_grave(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_open_grave(rng)

func _m_open_grave(rng: RandomNumberGenerator) -> void:
    var dirt := Color(0.24, 0.17, 0.11)
    _pc("box", Vector3(0, 0.022, 0), Vector3(1.0, 0.04, 2.1), Color(0.03, 0.02, 0.02))
    _pc("box", Vector3(0, 0.05, -1.1), Vector3(1.2, 0.1, 0.18), dirt.darkened(0.1))
    _pc("box", Vector3(0, 0.05, 1.1), Vector3(1.2, 0.1, 0.18), dirt.darkened(0.1))
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(float(sx) * 0.58, 0.05, 0), Vector3(0.18, 0.1, 2.3), dirt.darkened(0.1))
    _pc("sphere", Vector3(1.5, 0.0, 0.2), Vector3(1.6, 0.9, 2.0), dirt)
    _pc("sphere", Vector3(1.7, -0.05, -0.5), Vector3(0.9, 0.6, 0.9), dirt.lightened(0.05))
    _pb("cyl", Vector3(1.0, 0.7, -0.8), Vector3(1.35, 0.15, -0.5), 0.05, Color(0.4, 0.28, 0.14))
    _pc("box", Vector3(1.38, 0.1, -0.46), Vector3(0.22, 0.04, 0.26), Color(0.35, 0.35, 0.38))
    _pc("box", Vector3(0, 0.45, 1.5), Vector3(0.6, 0.9, 0.16), _stone(rng))
    _pb("cyl", Vector3(-0.2, 0.08, -0.3), Vector3(0.3, 0.06, 0.6), 0.06, Color(0.4, 0.3, 0.16))

func _p_coffin(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var w := Color(0.28, 0.17, 0.1)
    _part("box", Vector3(0, 0.3, 0), Vector3(0.8, 0.5, 2.0), Vector3(0, 0, 0), w)
    _pc("wedge", Vector3(0, 0.62, 0), Vector3(2.0, 0.28, 0.82), w.lightened(0.05))
    _part("wedge", Vector3(0, 0.62, 0), Vector3(2.0, 0.28, 0.82), Vector3(0, 90, 0), w.lightened(0.05))
    _pc("box", Vector3(0, 0.78, -0.3), Vector3(0.1, 0.03, 0.5), Color(0.7, 0.6, 0.3))
    _pc("box", Vector3(0, 0.78, -0.4), Vector3(0.35, 0.03, 0.1), Color(0.7, 0.6, 0.3))
    for i in range(rng.randi_range(1, 2)):
        _pc("sphere", Vector3(rng.randf_range(-0.4, 0.4), 0.05, 1.3 + 0.0), Vector3(0.5, 0.18, 0.5), Color(0.2, 0.15, 0.11))
    _col_box(Vector3.ZERO, Vector3(0.9, 0.9, 2.1))

func _p_lantern_post(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var iron := Color(0.1, 0.1, 0.12)
    _pc("cyl", Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.4), iron.lightened(0.05))
    _pc("cyl", Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.1), iron)
    _pb("cyl", Vector3(0, 2.0, 0), Vector3(0.45, 2.15, 0), 0.06, iron)
    _pc("box", Vector3(0.45, 1.9, 0), Vector3(0.28, 0.34, 0.28), Color(1.0, 0.8, 0.4))
    _pc("cone", Vector3(0.45, 2.17, 0), Vector3(0.4, 0.2, 0.4), iron)
    _pc("cone", Vector3(0.45, 1.68, 0), Vector3(0.3, 0.12, 0.3), iron)
    _col_cyl(Vector3.ZERO, 0.2, 2.3)
    _light_local(1.9, 1.3, 8.0, Color(1.0, 0.75, 0.4))

# Огороджена ділянка цвинтаря: решітка з брамою спереду (-Z), ряди надгробків лицем до брами, статуя ззаду, дерево збоку.
func _p_grave_plot(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var hw := 5.0
    var hd := 5.4
    _iron_run(-hw, -hd, -1.5, -hd, rng)
    _iron_run(1.5, -hd, hw, -hd, rng)
    _iron_run(-hw, hd, hw, hd, rng)
    _iron_run(-hw, -hd, -hw, hd, rng)
    _iron_run(hw, -hd, hw, hd, rng)
    _pc("box", Vector3(0, 0.02, -hd + 0.2), Vector3(3.0, 0.04, 1.2), Color(0.3, 0.28, 0.27))
    _sub(0.0, -hd - 0.2, 0.0)
    _pc("box", Vector3(0, 0.02, 0), Vector3(1.6, 0.04, 1.6), Color(0.3, 0.28, 0.27))
    _sub_end()
    for row in range(2):
        for k in range(3):
            var tx := -3.0 + 3.0 * float(k) + rng.randf_range(-0.2, 0.2)
            var tz := -2.2 + 3.2 * float(row)
            _sub(tx, tz, rng.randf_range(-0.05, 0.05))
            if rng.randf() < 0.15:
                _m_open_grave(rng)
            elif rng.randf() < 0.25:
                _m_cross(rng)
            else:
                _m_tombstone(rng)
            _sub_end()
    _sub(0.0, hd - 1.1, 0.0)
    _m_angel(rng)
    _sub_end()

# ---------- Руїни ----------
func _p_ruin_wall(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var length := rng.randf_range(3.2, 8.0)
    var c := _stone(rng)
    _wall_line(-length * 0.5, 0.0, length * 0.5, 0.0, rng, 0.8, 3.0, c)
    for i in range(rng.randi_range(2, 4)):
        _chunk_of_rock(Vector3(rng.randf_range(-length * 0.5, length * 0.5), 0.2, rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)), Vector3(0.5, 0.35, 0.5), c.darkened(0.08), rng)
    for i in range(rng.randi_range(1, 3)):
        _clump(Vector3(rng.randf_range(-length * 0.45, length * 0.45), rng.randf_range(0.5, 1.6), 0.28), Vector3(0.7, 0.5, 0.24), Color(0.2, 0.36, 0.14), rng)

func _p_pillar(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.2, 4.0)
    var c := _stone(rng).lightened(0.1)
    _pc("box", Vector3(0, 0.15, 0), Vector3(1.2, 0.3, 1.2), c.darkened(0.1))
    _pc("cyl", Vector3(0, 0.38, 0), Vector3(0.95, 0.16, 0.95), c.darkened(0.04))
    _pc("cyl", Vector3(0, 0.3 + h * 0.5, 0), Vector3(0.7, h, 0.7), c)
    for i in range(3):
        _pc("torus", Vector3(0, 0.9 + (h - 0.9) * float(i) / 2.0, 0), Vector3(0.78, 0.07, 0.78), c.darkened(0.1))
    if rng.randf() < 0.65:
        _pc("cyl", Vector3(0, 0.3 + h + 0.08, 0), Vector3(0.95, 0.18, 0.95), c.darkened(0.04))
        _pc("box", Vector3(0, 0.3 + h + 0.25, 0), Vector3(1.1, 0.16, 1.1), c.darkened(0.08))
    else:
        _chunk_of_rock(Vector3(0, 0.3 + h, 0), Vector3(0.9, 0.35, 0.8), c.darkened(0.05), rng)
        _pb("cyl", Vector3(1.4, 0.35, 0.5), Vector3(2.4, 0.35, 0.1), 0.7, c.darkened(0.05))
    _chunk_of_rock(Vector3(0.7, 0.12, -0.8), Vector3(0.5, 0.25, 0.4), c.darkened(0.12), rng)
    _col_cyl(Vector3.ZERO, 0.5, 2.5)

func _p_rubble(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := _stone(rng)
    for i in range(rng.randi_range(2, 3)):
        var s := rng.randf_range(0.4, 0.8)
        _chunk_of_rock(Vector3(rng.randf_range(-0.9, 0.9), s * 0.2, rng.randf_range(-0.9, 0.9)), Vector3(s, s * 0.7, s * 0.9), _jit(c, 0.05, rng), rng)
    for i in range(rng.randi_range(4, 7)):
        var s := rng.randf_range(0.2, 0.5)
        _part("box", Vector3(rng.randf_range(-1.3, 1.3), s * 0.35, rng.randf_range(-1.3, 1.3)), Vector3(s, s * 0.6, s * 1.3), Vector3(rng.randf_range(-8, 8), rng.randf() * 180.0, rng.randf_range(-20, 20)), _jit(Color(0.45, 0.28, 0.2) if rng.randf() < 0.3 else c, 0.05, rng))
    if rng.randf() < 0.4:
        _pb("cyl", Vector3(-0.3, 0.05, 0.2), Vector3(0.9, 0.7, 0.5), 0.04, Color(0.3, 0.15, 0.1))

func _p_fallen_column(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * PI)
    var c := _stone(rng).lightened(0.1)
    _pb("cyl", Vector3(-1.9, 0.38, 0), Vector3(0.5, 0.38, 0.1), 0.76, c)
    _pb("cyl", Vector3(0.75, 0.36, 0.2), Vector3(1.9, 0.36, 0.45), 0.7, c.darkened(0.05))
    _pb("cyl", Vector3(-1.92, 0.38, 0), Vector3(-1.99, 0.38, 0), 0.9, c.darkened(0.08))
    _pc("box", Vector3(-2.4, 0.15, 0.1), Vector3(1.1, 0.3, 1.1), c.darkened(0.1))
    _chunk_of_rock(Vector3(2.3, 0.15, -0.4), Vector3(0.5, 0.3, 0.4), c.darkened(0.1), rng)
    _col_box(Vector3(-0.4, 0, 0.05), Vector3(4.2, 0.8, 0.9))

func _p_statue(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _m_statue(rng)

func _m_statue(rng: RandomNumberGenerator) -> void:
    var c := _stone(rng).lightened(0.08)
    _pc("box", Vector3(0, 0.15, 0), Vector3(1.9, 0.3, 1.9), c.darkened(0.12))
    _pc("box", Vector3(0, 0.5, 0), Vector3(1.5, 0.4, 1.5), c.darkened(0.06))
    _pc("box", Vector3(0, 1.1, 0), Vector3(1.0, 0.9, 1.0), c)
    _pc("box", Vector3(0, 1.62, 0), Vector3(1.2, 0.14, 1.2), c.darkened(0.08))
    # лицар: ноги, тулуб, голова зі шоломом, меч і щит
    _pc("cyl", Vector3(-0.17, 2.05, 0), Vector3(0.28, 0.9, 0.28), c)
    _pc("cyl", Vector3(0.17, 2.05, 0), Vector3(0.28, 0.9, 0.28), c)
    _pc("box", Vector3(0, 2.8, 0), Vector3(0.7, 0.9, 0.4), c.lightened(0.04))
    _pc("sphere", Vector3(0, 3.45, 0), Vector3(0.4, 0.44, 0.4), c.lightened(0.06))
    _pc("cone", Vector3(0, 3.78, 0), Vector3(0.3, 0.3, 0.3), c.darkened(0.04))
    _pb("cyl", Vector3(0.45, 3.0, -0.1), Vector3(0.45, 1.8, -0.25), 0.1, c)
    _pb("cyl", Vector3(0.45, 1.7, -0.25), Vector3(0.45, 3.9, -0.3), 0.07, c.darkened(0.1))
    _pc("box", Vector3(-0.5, 2.8, -0.25), Vector3(0.12, 0.8, 0.5), c.darkened(0.06))
    if rng.randf() < 0.5:
        _clump(Vector3(0.3, 0.35, -0.5), Vector3(0.6, 0.4, 0.4), Color(0.2, 0.36, 0.14), rng)
    _col_cyl(Vector3.ZERO, 0.85, 3.8)

func _p_broken_stairs(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng).lightened(0.05)
    for i in range(4):
        var w := 3.4 - (0.3 if i == 3 else 0.0)
        var hh := 0.28 * float(i + 1)
        var zz := -0.9 + 0.8 * float(i)
        _pc("box", Vector3(0, hh * 0.5, zz), Vector3(w, hh, 0.8), c.darkened(0.04 * float(i)))
    _pc("box", Vector3(1.7, 0.4, 0.2), Vector3(0.3, 0.8, 2.6), c.darkened(0.1))
    _chunk_of_rock(Vector3(-1.2, 0.15, -1.5), Vector3(0.6, 0.3, 0.5), c.darkened(0.1), rng)
    _chunk_of_rock(Vector3(0.6, 0.12, -1.7), Vector3(0.4, 0.24, 0.4), c.darkened(0.12), rng)
    _col_box(Vector3(0, 0, -0.1), Vector3(3.6, 1.1, 3.0))

func _p_arch(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng).lightened(0.08)
    for sx in [-1.0, 1.0]:
        var px := float(sx) * 1.6
        _pc("box", Vector3(px, 0.2, 0), Vector3(1.2, 0.4, 1.2), c.darkened(0.12))
        _pc("box", Vector3(px, 1.9, 0), Vector3(0.8, 3.4, 0.8), c)
        _pc("box", Vector3(px, 3.65, 0), Vector3(1.0, 0.22, 1.0), c.darkened(0.06))
    _pc("box", Vector3(0, 4.1, 0), Vector3(4.4, 0.7, 0.9), c.darkened(0.05))
    _pc("box", Vector3(0, 4.55, 0), Vector3(1.0, 0.3, 1.0), c.lightened(0.04))
    _pc("box", Vector3(1.2, 3.65, 0), Vector3(0.7, 0.45, 0.8), c.darkened(0.04))
    for i in range(3):
        _clump(Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(0.8, 3.4), 0.46), Vector3(0.5, 0.6, 0.2), Color(0.2, 0.36, 0.14), rng)
    _chunk_of_rock(Vector3(0.6, 0.15, 0.2), Vector3(0.5, 0.3, 0.4), c.darkened(0.1), rng)
    _col_box(Vector3(-1.6, 0, 0), Vector3(1.0, 3.8, 1.0))
    _col_box(Vector3(1.6, 0, 0), Vector3(1.0, 3.8, 1.0))

func _p_broken_house(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _stone(rng).lightened(0.05)
    var wood := Color(0.33, 0.21, 0.11)
    _pc("box", Vector3(0, 0.05, 0), Vector3(7.0, 0.1, 6.0), Color(0.28, 0.25, 0.22))
    _wall_line(-3.5, -3.0, 3.5, -3.0, rng, 1.2, 2.8, c, 1, 2)
    _wall_line(-3.5, 3.0, 3.5, 3.0, rng, 0.8, 2.6, c, 2, 2)
    _wall_line(-3.5, -3.0, -3.5, 3.0, rng, 0.8, 2.4, c)
    _wall_line(3.5, -3.0, 3.5, 3.0, rng, 0.6, 2.2, c, 1, 2)
    # залишки даху: крокви й уламок покрівлі
    _pb("box", Vector3(-3.4, 2.4, -2.8), Vector3(0.0, 3.4, 0.2), 0.18, wood)
    _pb("box", Vector3(-3.4, 2.3, 0.4), Vector3(-0.4, 3.2, 0.3), 0.16, wood)
    _pb("box", Vector3(-3.3, 2.2, 2.9), Vector3(1.4, 2.9, 1.0), 0.16, wood)
    _part("wedge", Vector3(-2.0, 2.7, 1.6), Vector3(3.2, 0.9, 2.4), Vector3(0, 8, 0), Color(0.5, 0.22, 0.15))
    _pc("box", Vector3(2.6, 2.1, -2.4), Vector3(0.7, 3.2, 0.7), c.darkened(0.1))      # комин
    _pc("box", Vector3(1.4, 0.9, 1.7), Vector3(0.6, 0.9, 0.5), Color(0.25, 0.14, 0.1))   # шафа
    for i in range(7):
        var s := rng.randf_range(0.2, 0.45)
        _chunk_of_rock(Vector3(rng.randf_range(-2.8, 2.8), s * 0.25, rng.randf_range(-2.4, 2.4)), Vector3(s, s * 0.7, s), _stone(rng), rng)
    _pb("box", Vector3(-1.0, 0.1, -1.0), Vector3(0.4, 0.5, 0.2), 0.16, wood)
# ---------- Кров, трупи ----------
func _p_blood(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_blood(rng)

func _m_blood(rng: RandomNumberGenerator) -> void:
    var c := Color(rng.randf_range(0.2, 0.32), 0.015, 0.015)
    var s := rng.randf_range(0.8, 2.0)
    _pc("sphere", Vector3(0, 0.02, 0), Vector3(s * 1.4, 0.03, s), c)
    _pc("sphere", Vector3(s * 0.15, 0.026, 0), Vector3(s * 0.8, 0.03, s * 0.6), c.darkened(0.25))
    for i in range(rng.randi_range(3, 6)):
        var r := rng.randf_range(0.1, 0.5)
        var a := rng.randf() * TAU
        var d := rng.randf_range(0.6, 1.5) * s
        _pc("sphere", Vector3(cos(a) * d, 0.022, sin(a) * d * 0.8), Vector3(r, 0.03, r * 0.8), c.darkened(0.1))
    if rng.randf() < 0.5:
        _pc("box", Vector3(s * 1.3, 0.021, 0), Vector3(s * 1.2, 0.025, 0.14), c.darkened(0.05))

func _p_corpse(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_corpse(rng)

func _m_corpse(rng: RandomNumberGenerator) -> void:
    var skin := _jit(Color(0.55, 0.5, 0.42), 0.05, rng)
    var cloth := Color.from_hsv(rng.randf(), 0.3, 0.32)
    _pc("sphere", Vector3(0, 0.02, 0), Vector3(2.4, 0.03, 1.7), Color(0.24, 0.015, 0.015))
    _pc("box", Vector3(0, 0.14, 0), Vector3(0.55, 0.26, 0.9), cloth)
    _pc("box", Vector3(0, 0.11, 0.38), Vector3(0.58, 0.14, 0.08), Color(0.12, 0.09, 0.06))
    _pc("sphere", Vector3(0, 0.15, -0.62), Vector3(0.32, 0.3, 0.34), skin)
    _pc("sphere", Vector3(0, 0.2, -0.7), Vector3(0.34, 0.2, 0.2), Color(0.18, 0.12, 0.08))
    for sx in [-1.0, 1.0]:
        _part("box", Vector3(float(sx) * 0.16, 0.08, 0.85), Vector3(0.18, 0.16, 0.85), Vector3(0, rng.randf_range(-12, 12), 0), cloth.darkened(0.25))
        _part("box", Vector3(float(sx) * 0.17, 0.07, 1.34), Vector3(0.2, 0.12, 0.25), Vector3(0, rng.randf_range(-20, 20), 0), Color(0.1, 0.08, 0.06))
        _part("box", Vector3(float(sx) * 0.42, 0.1, -0.2), Vector3(0.14, 0.14, 0.7), Vector3(0, float(sx) * rng.randf_range(10, 40), 0), skin.darkened(0.15))
        _pc("sphere", Vector3(float(sx) * 0.5, 0.09, -0.52), Vector3(0.13, 0.1, 0.13), skin.darkened(0.1))
    _pc("sphere", Vector3(0.1, 0.27, -0.1), Vector3(0.3, 0.06, 0.3), Color(0.3, 0.02, 0.02))

# ---------- Місто ----------
func _p_car(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_car(rng, 0)

# variant: 0 — легковик, 1 — поліцейський, 2 — фургон. Довга вісь — X, капот у +X.
func _m_car(rng: RandomNumberGenerator, variant: int) -> void:
    var paint := Color.from_hsv(rng.randf(), 0.45, 0.4)
    if rng.randf() < 0.3:
        paint = Color(0.12, 0.115, 0.115)
    if variant == 1:
        paint = Color(0.08, 0.1, 0.16)
    var glass := Color(0.07, 0.1, 0.13)
    var dark := Color(0.05, 0.05, 0.05)
    var clen := 4.2 if variant != 2 else 4.8
    _pc("box", Vector3(0, 0.62, 0), Vector3(clen, 0.62, 1.82), paint)
    _pc("box", Vector3(0, 0.3, 0), Vector3(clen - 0.4, 0.3, 1.7), dark)
    if variant == 2:
        _pc("box", Vector3(-0.5, 1.4, 0), Vector3(3.2, 1.0, 1.74), paint.lightened(0.05))
        _pc("box", Vector3(1.6, 1.1, 0), Vector3(1.0, 0.5, 1.6), glass)
        _pc("box", Vector3(1.0, 1.55, 0), Vector3(0.12, 0.7, 1.6), paint.darkened(0.2))
    else:
        _pc("box", Vector3(-0.15, 1.22, 0), Vector3(2.3, 0.55, 1.66), paint.darkened(0.05))
        for sz in [-1.0, 1.0]:
            _pc("box", Vector3(-0.15, 1.24, float(sz) * 0.835), Vector3(1.9, 0.4, 0.04), glass)
        _pc("box", Vector3(1.0, 1.1, 0), Vector3(0.1, 0.4, 1.5), glass)
        _pc("box", Vector3(-1.3, 1.1, 0), Vector3(0.1, 0.4, 1.5), glass)
        _pc("box", Vector3(-0.15, 1.52, 0), Vector3(2.1, 0.07, 1.6), paint.lightened(0.06))
        _part("box", Vector3(1.55, 0.98, 0), Vector3(1.4, 0.08, 1.7), Vector3(0, 0, rng.randf_range(0, 6)), paint.lightened(0.04))
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var wx := float(sx) * (clen * 0.5 - 0.85)
            var wz := float(sz) * 0.9
            _part("torus", Vector3(wx, 0.34, wz), Vector3(0.7, 1.8, 0.7), Vector3(90, 0, 0), dark)
            _part("cyl", Vector3(wx, 0.34, wz), Vector3(0.38, 0.2, 0.38), Vector3(90, 0, 0), Color(0.45, 0.45, 0.48))
    for sz in [-1.0, 1.0]:
        _pc("box", Vector3(clen * 0.5, 0.7, float(sz) * 0.6), Vector3(0.05, 0.14, 0.3), Color(1.0, 0.95, 0.7))
        _pc("box", Vector3(-clen * 0.5, 0.7, float(sz) * 0.6), Vector3(0.05, 0.14, 0.3), Color(0.55, 0.05, 0.05))
    _pc("box", Vector3(clen * 0.5 + 0.03, 0.4, 0), Vector3(0.12, 0.16, 1.7), Color(0.12, 0.12, 0.13))
    _pc("box", Vector3(-clen * 0.5 - 0.03, 0.4, 0), Vector3(0.12, 0.16, 1.7), Color(0.12, 0.12, 0.13))
    if variant == 1:
        _pc("box", Vector3(-0.15, 1.62, 0), Vector3(0.3, 0.14, 1.2), Color(0.1, 0.1, 0.1))
        _pc("box", Vector3(-0.15, 1.72, -0.35), Vector3(0.25, 0.1, 0.4), Color(0.9, 0.1, 0.1))
        _pc("box", Vector3(-0.15, 1.72, 0.35), Vector3(0.25, 0.1, 0.4), Color(0.15, 0.25, 0.9))
        for sz in [-1.0, 1.0]:
            _pc("box", Vector3(0.1, 0.72, float(sz) * 0.915), Vector3(1.6, 0.32, 0.03), Color(0.9, 0.9, 0.92))
    elif rng.randf() < 0.5:
        _pc("box", Vector3(0.2, 0.7, 0.92), Vector3(1.5, 0.3, 0.04), Color(0.38, 0.2, 0.1))
    _col_box(Vector3.ZERO, Vector3(clen, 1.5, 1.85))

func _p_bus(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var paint := Color(0.78, 0.62, 0.12) if rng.randf() < 0.6 else Color(0.25, 0.4, 0.55)
    var glass := Color(0.08, 0.11, 0.14)
    _pc("box", Vector3(0, 1.45, 0), Vector3(9.0, 2.3, 2.6), paint.darkened(0.15))
    _pc("box", Vector3(0, 0.55, 0), Vector3(8.6, 0.5, 2.5), Color(0.08, 0.08, 0.08))
    _pc("box", Vector3(0, 1.95, 0), Vector3(9.05, 0.9, 2.62), glass)
    for k in range(7):
        _pc("box", Vector3(-3.6 + 1.2 * float(k), 1.95, 0), Vector3(0.1, 0.95, 2.66), paint.darkened(0.25))
    _pc("box", Vector3(0, 2.62, 0), Vector3(9.0, 0.12, 2.5), paint.lightened(0.05))
    _pc("box", Vector3(4.52, 1.8, 0), Vector3(0.06, 1.1, 2.4), glass)
    _pc("box", Vector3(4.53, 2.45, 0), Vector3(0.05, 0.3, 1.5), Color(0.9, 0.6, 0.1))
    _pc("box", Vector3(0, 1.2, 1.31), Vector3(9.0, 0.12, 0.04), paint.lightened(0.15))
    for sx in [-3.0, 3.0]:
        for sz in [-1.1, 1.1]:
            _part("torus", Vector3(float(sx), 0.5, float(sz)), Vector3(1.0, 2.0, 1.0), Vector3(90, 0, 0), Color(0.04, 0.04, 0.04))
            _part("cyl", Vector3(float(sx), 0.5, float(sz)), Vector3(0.55, 0.2, 0.55), Vector3(90, 0, 0), Color(0.5, 0.5, 0.52))
    _pc("box", Vector3(4.5, 0.75, -0.9), Vector3(0.06, 0.2, 0.4), Color(1.0, 0.95, 0.7))
    _pc("box", Vector3(4.5, 0.75, 0.9), Vector3(0.06, 0.2, 0.4), Color(1.0, 0.95, 0.7))
    _col_box(Vector3.ZERO, Vector3(9.0, 2.7, 2.6))

func _m_cone(rng: RandomNumberGenerator) -> void:
    _pc("box", Vector3(0, 0.025, 0), Vector3(0.42, 0.05, 0.42), Color(0.08, 0.08, 0.08))
    _pc("cone", Vector3(0, 0.3, 0), Vector3(0.34, 0.5, 0.34), Color(0.9, 0.38, 0.08))
    _pc("cyl", Vector3(0, 0.27, 0), Vector3(0.26, 0.1, 0.26), Color(0.92, 0.92, 0.9))

func _p_traffic_cone(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var n := rng.randi_range(1, 3)
    for i in range(n):
        _sub(float(i) * 0.7 * rng.randf_range(0.8, 1.2), rng.randf_range(-0.3, 0.3), 0.0)
        if i > 0 and rng.randf() < 0.3:
            _part("cone", Vector3(0, 0.1, 0), Vector3(0.34, 0.5, 0.34), Vector3(0, 0, 90), Color(0.9, 0.38, 0.08))
        else:
            _m_cone(rng)
        _sub_end()

func _p_bench(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_bench(rng)

# Лавка: сидіння дивиться в -Z (спинка в +Z).
func _m_bench(rng: RandomNumberGenerator) -> void:
    var wood := Color(0.4, 0.26, 0.13)
    var iron := Color(0.1, 0.1, 0.11)
    for sx in [-0.8, 0.8]:
        _pc("box", Vector3(float(sx), 0.22, 0), Vector3(0.1, 0.44, 0.5), iron)
        _pc("box", Vector3(float(sx), 0.55, 0.22), Vector3(0.1, 0.5, 0.08), iron)
    for k in range(3):
        _pc("box", Vector3(0, 0.46, -0.16 + 0.16 * float(k)), Vector3(1.8, 0.05, 0.13), wood.lightened(0.03 * float(k)))
    for k in range(2):
        _pc("box", Vector3(0, 0.62 + 0.18 * float(k), 0.24), Vector3(1.8, 0.12, 0.05), wood)
    _col_box(Vector3.ZERO, Vector3(1.9, 0.9, 0.7))

func _p_bus_stop(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var metal := Color(0.18, 0.2, 0.22)
    _pc("box", Vector3(0, 0.03, 0), Vector3(3.4, 0.06, 1.6), Color(0.3, 0.3, 0.3))
    for sx in [-1.5, 1.5]:
        _pc("box", Vector3(float(sx), 1.2, 0.6), Vector3(0.12, 2.4, 0.12), metal)
        _pc("box", Vector3(float(sx), 1.2, -0.6), Vector3(0.12, 2.4, 0.12), metal)
    _pc("box", Vector3(0, 2.45, 0), Vector3(3.5, 0.12, 1.5), metal.lightened(0.1))
    _pc("box", Vector3(0, 1.3, 0.62), Vector3(2.9, 1.9, 0.05), Color(0.2, 0.3, 0.34))
    _pc("box", Vector3(1.0, 1.4, 0.58), Vector3(0.8, 1.2, 0.04), Color(0.6, 0.55, 0.2))
    _sub(0.0, 0.2, 0.0)
    _m_bench(rng)
    _sub_end()
    _pc("cyl", Vector3(2.2, 1.2, -0.7), Vector3(0.1, 2.4, 0.1), metal)
    _pc("box", Vector3(2.2, 2.2, -0.7), Vector3(0.6, 0.6, 0.05), Color(0.1, 0.3, 0.6))
    _col_box(Vector3(0, 0, 0.2), Vector3(3.5, 2.4, 1.4))

func _p_mailbox(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.12, 0.25, 0.55)
    _pc("box", Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.4), c)
    _part("cyl", Vector3(0, 0.95, 0), Vector3(0.4, 0.5, 0.4), Vector3(0, 0, 90), c.lightened(0.05))
    _pc("box", Vector3(0, 0.55, -0.205), Vector3(0.36, 0.05, 0.02), Color(0.04, 0.04, 0.05))
    _pc("box", Vector3(0, 0.08, 0), Vector3(0.55, 0.16, 0.45), c.darkened(0.3))
    _col_cyl(Vector3.ZERO, 0.28, 1.2)

func _p_hydrant(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.7, 0.1, 0.08)
    _pc("cyl", Vector3(0, 0.1, 0), Vector3(0.42, 0.2, 0.42), c.darkened(0.2))
    _pc("cyl", Vector3(0, 0.45, 0), Vector3(0.3, 0.7, 0.3), c)
    _pc("sphere", Vector3(0, 0.82, 0), Vector3(0.36, 0.3, 0.36), c.lightened(0.05))
    _pc("cyl", Vector3(0, 0.98, 0), Vector3(0.1, 0.1, 0.1), c.darkened(0.1))
    _part("cyl", Vector3(0, 0.55, 0), Vector3(0.18, 0.62, 0.18), Vector3(0, 0, 90), c.darkened(0.08))
    _part("cyl", Vector3(0.2, 0.55, 0), Vector3(0.16, 0.1, 0.16), Vector3(0, 0, 90), Color(0.5, 0.5, 0.5))
    _col_cyl(Vector3.ZERO, 0.3, 1.0)

func _p_newspaper_box(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color.from_hsv(rng.randf(), 0.6, 0.45)
    _pc("box", Vector3(0, 0.5, 0), Vector3(0.5, 0.9, 0.45), c)
    _pc("box", Vector3(0, 0.62, -0.23), Vector3(0.32, 0.4, 0.03), Color(0.12, 0.16, 0.2))
    _pc("box", Vector3(0, 0.98, 0), Vector3(0.54, 0.06, 0.49), c.darkened(0.2))
    _pc("box", Vector3(0, 0.12, 0), Vector3(0.45, 0.24, 0.4), Color(0.12, 0.12, 0.13))
    _col_cyl(Vector3.ZERO, 0.3, 1.0)

func _p_streetlamp(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var metal := Color(0.16, 0.17, 0.18)
    if rng.randf() < 0.22:
        # лежить упалий
        _pb("cyl", Vector3(-2.2, 0.14, 0), Vector3(2.2, 0.14, 0.15), 0.2, metal)
        _pc("cyl", Vector3(-2.2, 0.14, 0), Vector3(0.36, 0.1, 0.36), metal.lightened(0.05))
        _pb("cyl", Vector3(2.2, 0.14, 0.15), Vector3(2.9, 0.2, 0.6), 0.1, metal)
        _pc("box", Vector3(3.15, 0.15, 0.7), Vector3(0.5, 0.12, 0.25), Color(0.35, 0.34, 0.3))
        _col_box(Vector3(0.2, 0, 0.05), Vector3(5.6, 0.3, 0.3))
        return
    _pc("cyl", Vector3(0, 0.18, 0), Vector3(0.4, 0.36, 0.4), metal.lightened(0.05))
    _pc("cyl", Vector3(0, 1.4, 0), Vector3(0.2, 2.4, 0.2), metal)
    _pc("cyl", Vector3(0, 3.5, 0), Vector3(0.15, 2.0, 0.15), metal)
    _pb("cyl", Vector3(0, 4.45, 0), Vector3(0.45, 4.7, 0), 0.12, metal)
    _pb("cyl", Vector3(0.4, 4.7, 0), Vector3(1.05, 4.6, 0), 0.1, metal)
    _pc("box", Vector3(1.15, 4.5, 0), Vector3(0.6, 0.12, 0.3), Color(0.3, 0.3, 0.28))
    _pc("box", Vector3(1.15, 4.42, 0), Vector3(0.46, 0.05, 0.22), Color(1.0, 0.92, 0.65))
    _col_cyl(Vector3.ZERO, 0.22, 4.0)
    _light_local(4.3, 1.4, 9.0, Color(1.0, 0.85, 0.55))

func _p_dumpster(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var c := Color(0.1, 0.22, 0.14).darkened(rng.randf_range(0.0, 0.3))
    _pc("box", Vector3(0, 0.6, 0), Vector3(1.9, 1.0, 0.95), c)
    _pc("box", Vector3(0, 0.1, 0), Vector3(1.8, 0.2, 0.85), Color(0.06, 0.06, 0.07))
    _pc("box", Vector3(0, 1.12, 0.0), Vector3(1.96, 0.07, 1.02), c.darkened(0.12))
    for k in range(3):
        _pc("box", Vector3(-0.6 + 0.6 * float(k), 0.6, -0.49), Vector3(0.06, 0.9, 0.03), c.lightened(0.1))
    _part("box", Vector3(0.0, 1.25, 0.58), Vector3(1.9, 0.07, 0.6), Vector3(rng.randf_range(-70, -40), 0, 0), c.darkened(0.2))
    for sx in [-0.8, 0.8]:
        _pc("cyl", Vector3(float(sx), 0.1, 0.5), Vector3(0.2, 0.2, 0.2), Color(0.05, 0.05, 0.05))
    for i in range(rng.randi_range(1, 3)):
        _clump(Vector3(rng.randf_range(-0.7, 0.7), 1.2, rng.randf_range(-0.2, 0.2)), Vector3(0.5, 0.35, 0.45), Color(0.06, 0.06, 0.07), rng)
    _col_box(Vector3.ZERO, Vector3(1.9, 1.2, 0.95))

func _p_barricade(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_barricade(rng)

func _m_barricade(rng: RandomNumberGenerator) -> void:
    var conc := Color(0.45, 0.45, 0.42)
    for sx in [-1.2, 1.2]:
        var yw := rng.randf_range(-6.0, 6.0)
        _part("box", Vector3(float(sx), 0.18, 0.0), Vector3(2.2, 0.36, 0.7), Vector3(0, yw, 0), _jit(conc, 0.04, rng))
        _part("box", Vector3(float(sx), 0.6, 0.0), Vector3(2.2, 0.5, 0.42), Vector3(0, yw, 0), _jit(conc, 0.04, rng))
        _part("box", Vector3(float(sx) - 0.8, 0.9, 0.0), Vector3(0.5, 0.12, 0.38), Vector3(0, yw, 0), Color(0.85, 0.15, 0.1))
        _part("box", Vector3(float(sx) + 0.3, 0.9, 0.0), Vector3(0.5, 0.12, 0.38), Vector3(0, yw, 0), Color(0.9, 0.9, 0.9))
    for i in range(5):
        _clump(Vector3(-1.8 + 0.9 * float(i), 1.1, rng.randf_range(-0.08, 0.1)), Vector3(0.8, 0.4, 0.5), Color(0.5, 0.42, 0.28).darkened(rng.randf_range(0.0, 0.15)), rng)
    _pb("cyl", Vector3(-1.8, 0.1, -0.6), Vector3(-1.8, 0.95, -0.6), 0.06, Color(0.18, 0.18, 0.2))
    _col_box(Vector3(0, 0, 0.0), Vector3(4.8, 1.2, 0.8))

func _p_fire_barrel(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _m_fire_barrel(rng)

func _m_fire_barrel(rng: RandomNumberGenerator) -> void:
    var steel := Color(0.22, 0.14, 0.1)
    _pc("cyl", Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), steel)
    for yy in [0.2, 0.8]:
        _pc("torus", Vector3(0, float(yy), 0), Vector3(0.74, 0.7, 0.74), steel.darkened(0.3))
    _pc("cyl", Vector3(0, 1.0, 0), Vector3(0.62, 0.06, 0.62), Color(0.1, 0.06, 0.05))
    _pc("cone", Vector3(0, 1.4, 0), Vector3(0.5, 0.8, 0.5), Color(1.0, 0.5, 0.1))
    _pc("cone", Vector3(0.1, 1.3, 0.05), Vector3(0.3, 0.6, 0.3), Color(1.0, 0.75, 0.2))
    _pc("sphere", Vector3(0.05, 1.08, 0), Vector3(0.4, 0.2, 0.4), Color(1.0, 0.8, 0.25))
    _col_cyl(Vector3.ZERO, 0.4, 1.0)
    _light_local(1.7, 2.4, 11.0, Color(1.0, 0.5, 0.2))

func _p_sign(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var metal := Color(0.2, 0.2, 0.22)
    _pc("cyl", Vector3(0, 1.2, 0), Vector3(0.08, 2.4, 0.08), metal)
    _pc("cyl", Vector3(0, 0.08, 0), Vector3(0.3, 0.16, 0.3), metal.lightened(0.04))
    var tilt := rng.randf_range(-12, 12)
    if rng.randf() < 0.5:
        _part("cyl", Vector3(0, 2.3, -0.06), Vector3(0.85, 0.05, 0.85), Vector3(90, 0, tilt), Color(0.6, 0.1, 0.08))
        _part("cyl", Vector3(0, 2.3, -0.09), Vector3(0.62, 0.03, 0.62), Vector3(90, 0, tilt), Color(0.62, 0.15, 0.12))
        _part("box", Vector3(0, 2.3, -0.1), Vector3(0.6, 0.12, 0.03), Vector3(0, 0, tilt), Color(0.92, 0.92, 0.9))
    else:
        _part("box", Vector3(0, 2.3, -0.06), Vector3(0.9, 0.7, 0.05), Vector3(0, 0, tilt), Color(0.8, 0.68, 0.12))
        _part("box", Vector3(0, 2.3, -0.1), Vector3(0.72, 0.52, 0.03), Vector3(0, 0, tilt), Color(0.08, 0.08, 0.08))
        _part("box", Vector3(0, 2.3, -0.12), Vector3(0.1, 0.34, 0.03), Vector3(0, 0, tilt), Color(0.8, 0.68, 0.12))
    _col_cyl(Vector3.ZERO, 0.15, 2.4)

func _p_crosswalk(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    for k in range(9):
        _pc("box", Vector3(-3.6 + 0.9 * float(k), 0.02, 0), Vector3(0.45, 0.02, 2.0), Color(0.55, 0.55, 0.5))

# Блокпост: дві поліцейські машини «ялинкою» впоперек дороги (дорога вздовж X), конуси, ящики, тіла. Фасад (-Z) — до гравця.
func _p_road_block(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _sub(-1.6, -2.3, deg_to_rad(rng.randf_range(10, 25)))
    _m_car(rng, 1)
    _sub_end()
    _sub(1.8, 2.5, deg_to_rad(rng.randf_range(160, 175)))
    _m_car(rng, 1)
    _sub_end()
    for k in range(4):
        _sub(-6.0 + 3.6 * float(k), -5.0 + rng.randf_range(-0.3, 0.3), 0.0)
        _m_cone(rng)
        _sub_end()
    _sub(0.0, -0.1, 0.0)
    _m_barricade(rng)
    _sub_end()
    _sub(-0.6, 4.5, 0.0)
    _m_corpse(rng)
    _sub_end()
    _sub(4.2, -0.6, 0.5)
    _m_blood(rng)
    _sub_end()

# Колишній склад: уламки будівлі з рештками стін, плитами й арматурою.
func _p_ruined_building(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var c := _jit(Color(0.32, 0.24, 0.21), 0.04, rng)
    var w := rng.randf_range(8.0, 11.0)
    var d := rng.randf_range(6.0, 8.0)
    _pc("box", Vector3(0, 0.05, 0), Vector3(w, 0.1, d), Color(0.14, 0.13, 0.13))
    _wall_line(-w * 0.5, -d * 0.5, w * 0.5, -d * 0.5, rng, 3.0, 7.0, c, 2, 2)
    _wall_line(-w * 0.5, d * 0.5, w * 0.5, d * 0.5, rng, 2.5, 6.0, c, 3, 2)
    _wall_line(-w * 0.5, -d * 0.5, -w * 0.5, d * 0.5, rng, 2.0, 6.5, c)
    _wall_line(w * 0.5, -d * 0.5, w * 0.5, d * 0.5, rng, 1.0, 5.0, c, 1, 2)
    _part("box", Vector3(1.0, 2.2, 0.5), Vector3(3.5, 0.25, 2.5), Vector3(0, 10, 18), Color(0.28, 0.27, 0.27))
    _part("box", Vector3(-1.8, 1.4, -0.5), Vector3(3.0, 0.22, 2.2), Vector3(0, -15, -10), Color(0.26, 0.26, 0.27))
    # вікна: темні прорізи на фасаді
    for k in range(4):
        _pc("box", Vector3(-w * 0.5 + 1.2 + (w - 2.4) * float(k) / 3.0, 2.0, -d * 0.5 - 0.31), Vector3(0.9, 1.1, 0.04), Color(0.03, 0.03, 0.04))
    for i in range(5):
        var a := rng.randf() * TAU
        _pb("cyl", Vector3(cos(a) * w * 0.4, 0.2, sin(a) * d * 0.4), Vector3(cos(a) * w * 0.4 + 0.2, 1.6 + rng.randf() * 0.8, sin(a) * d * 0.4), 0.04, Color(0.3, 0.14, 0.1))
    for i in range(6):
        var s := rng.randf_range(0.2, 0.5)
        _chunk_of_rock(Vector3(rng.randf_range(-w * 0.4, w * 0.4), s * 0.3, rng.randf_range(-d * 0.4, d * 0.4)), Vector3(s, s * 0.7, s), _stone(rng), rng)

func _p_crack(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    for i in range(3):
        _part("box", Vector3(rng.randf_range(-1.0, 1.0), 0.015, rng.randf_range(-1.0, 1.0)), Vector3(rng.randf_range(1.0, 3.5), 0.02, 0.06), Vector3(0, rng.randf() * 180.0, 0), Color(0.04, 0.04, 0.045))

func _p_road_mark(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    for i in range(4):
        _pc("box", Vector3(-3.0 + 2.0 * float(i), 0.02, 0), Vector3(1.0, 0.02, 0.16), Color(0.6, 0.55, 0.22))

func _p_manhole(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, 0.0)
    _pc("cyl", Vector3(0, 0.02, 0), Vector3(0.9, 0.03, 0.9), Color(0.08, 0.08, 0.09))
    _pc("cyl", Vector3(0, 0.035, 0), Vector3(0.7, 0.02, 0.7), Color(0.12, 0.12, 0.13))

# ---------- Болото ----------
func _p_sunken_boat(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var wood := Color(0.3, 0.2, 0.11)
    _part("sphere", Vector3(0, 0.1, 0), Vector3(3.6, 1.0, 1.4), Vector3(0, 0, rng.randf_range(-8, 8)), wood)
    _pc("sphere", Vector3(0, 0.34, 0), Vector3(3.2, 0.5, 1.0), wood.darkened(0.55))
    for k in range(4):
        _pc("box", Vector3(-1.1 + 0.75 * float(k), 0.4, 0), Vector3(0.1, 0.12, 1.3), wood.lightened(0.05))
    _pb("cyl", Vector3(0.6, 0.4, 0.2), Vector3(2.4, 1.1, 0.9), 0.07, wood.lightened(0.08))
    _pc("sphere", Vector3(1.0, 0.45, -0.1), Vector3(0.6, 0.2, 0.5), Color(0.14, 0.26, 0.1))
    _col_box(Vector3.ZERO, Vector3(3.6, 0.8, 1.5))

func _p_swamp_hut_body(rng: RandomNumberGenerator) -> void:
    var wood := Color(0.34, 0.24, 0.14)
    for sx in [-1.3, 1.3]:
        for sz in [-1.1, 1.1]:
            _pb("cyl", Vector3(float(sx), 0.0, float(sz)), Vector3(float(sx), 1.35, float(sz)), 0.22, wood.darkened(0.2))
    _pc("box", Vector3(0, 1.4, 0), Vector3(3.2, 0.14, 2.8), wood)
    _pc("box", Vector3(0, 2.2, 0.1), Vector3(2.8, 1.5, 2.4), wood.lightened(0.04))
    for k in range(5):
        _pc("box", Vector3(-1.2 + 0.6 * float(k), 2.2, -1.12), Vector3(0.05, 1.5, 0.05), wood.darkened(0.2))
    _pc("wedge", Vector3(0, 3.3, 0.1), Vector3(3.3, 1.1, 3.0), Color(0.3, 0.38, 0.16))
    _pc("box", Vector3(0, 1.9, -1.12), Vector3(0.8, 1.2, 0.06), Color(0.14, 0.09, 0.05))
    _pc("box", Vector3(0.9, 2.4, -1.12), Vector3(0.5, 0.45, 0.06), Color(1.0, 0.8, 0.4))
    _pb("box", Vector3(-0.4, 0.0, -2.1), Vector3(-0.4, 1.45, -1.2), 0.1, wood.darkened(0.1))
    _pb("box", Vector3(0.4, 0.0, -2.1), Vector3(0.4, 1.45, -1.2), 0.1, wood.darkened(0.1))
    for k in range(4):
        _pc("box", Vector3(0, 0.25 + 0.3 * float(k), -1.9 + 0.2 * float(k)), Vector3(0.9, 0.06, 0.08), wood)
    _col_box(Vector3(0, 0, 0), Vector3(3.2, 3.0, 2.9))

# Болотна садиба: хата на палях, човен біля сходів, очерет.
func _p_swamp_homestead(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _p_swamp_hut_body(rng)
    _sub(4.2, -1.0, rng.randf_range(0.2, 0.8))
    var wood := Color(0.3, 0.2, 0.11)
    _part("sphere", Vector3(0, 0.1, 0), Vector3(3.4, 0.9, 1.3), Vector3.ZERO, wood)
    _pc("sphere", Vector3(0, 0.3, 0), Vector3(3.0, 0.5, 0.95), wood.darkened(0.55))
    _col_box(Vector3.ZERO, Vector3(3.4, 0.7, 1.4), 0.0)
    _sub_end()
    for i in range(3):
        _sub(rng.randf_range(-3.6, 3.6), rng.randf_range(2.6, 3.8), 0.0)
        _p_reeds_body(rng)
        _sub_end()
    _sub(-3.0, -2.6, 0.0)
    _m_barrel(rng)
    _sub_end()

func _p_reeds_body(rng: RandomNumberGenerator) -> void:
    var c := Color(0.30, 0.42, 0.18)
    for i in range(rng.randi_range(6, 9)):
        var a := rng.randf() * TAU
        var r := rng.randf_range(0.0, 0.5)
        var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
        var tip := base + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.9, 1.6), rng.randf_range(-0.15, 0.15))
        _pb("cyl", base, tip, 0.04, _jit(c, 0.06, rng))
        if rng.randf() < 0.5:
            _pb("cyl", tip - Vector3(0, 0.3, 0), tip + Vector3(0, 0.12, 0), 0.09, Color(0.32, 0.2, 0.1))

func _m_barrel(rng: RandomNumberGenerator) -> void:
    var w := Color(0.4, 0.27, 0.14)
    _pc("cyl", Vector3(0, 0.45, 0), Vector3(0.65, 0.9, 0.65), w)
    for yy in [0.2, 0.7]:
        _pc("torus", Vector3(0, float(yy), 0), Vector3(0.68, 0.6, 0.68), Color(0.14, 0.12, 0.1))
    _pc("cyl", Vector3(0, 0.9, 0), Vector3(0.55, 0.03, 0.55), w.lightened(0.1))
    _col_cyl(Vector3.ZERO, 0.36, 0.9)

func _m_crate(rng: RandomNumberGenerator) -> void:
    var w := _jit(Color(0.45, 0.32, 0.17), 0.04, rng)
    _pc("box", Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), w)
    for sx in [-1.0, 1.0]:
        _pc("box", Vector3(float(sx) * 0.34, 0.35, 0), Vector3(0.06, 0.74, 0.74), w.darkened(0.25))
    _pc("box", Vector3(0, 0.72, 0), Vector3(0.74, 0.06, 0.74), w.darkened(0.15))
    _col_box(Vector3.ZERO, Vector3(0.72, 0.7, 0.72))

# ---------- Пожежа, попіл ----------
func _p_collapsed_chimney(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var br := Color(0.32, 0.2, 0.16)
    var soot := Color(0.08, 0.07, 0.07)
    _pc("box", Vector3(0, 0.15, 0), Vector3(2.4, 0.3, 1.8), Color(0.2, 0.17, 0.15))
    _pc("box", Vector3(0, 1.4, 0.25), Vector3(1.9, 2.5, 0.9), br)
    _pc("box", Vector3(0, 0.85, -0.2), Vector3(1.1, 1.4, 0.15), soot)
    _pc("box", Vector3(0, 1.0, 0.0), Vector3(1.4, 1.6, 0.05), soot.lightened(0.04))
    _pc("box", Vector3(0, 2.8, 0.3), Vector3(1.1, 1.5, 0.75), br.darkened(0.05))
    _part("box", Vector3(0.2, 3.7, 0.3), Vector3(0.75, 0.9, 0.7), Vector3(0, 0, 14), br.darkened(0.1))
    _pc("box", Vector3(0, 2.35, -0.3), Vector3(1.8, 0.12, 0.4), br.darkened(0.2))
    for i in range(8):
        var s := rng.randf_range(0.2, 0.45)
        _part("box", Vector3(rng.randf_range(-1.6, 1.6), s * 0.35, rng.randf_range(-1.6, 0.3) - 0.8), Vector3(s, s * 0.6, s * 1.2), Vector3(rng.randf_range(-8, 8), rng.randf() * 180.0, rng.randf_range(-15, 15)), _jit(br, 0.05, rng))
    _pb("box", Vector3(-1.4, 0.1, -1.0), Vector3(-0.6, 1.5, -0.3), 0.18, soot)
    _pc("sphere", Vector3(0.2, 0.12, -0.8), Vector3(0.4, 0.2, 0.4), Color(1.0, 0.4, 0.08))
    _col_box(Vector3(0, 0, 0.1), Vector3(2.4, 3.0, 1.6))

func _p_charred_cart(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_cart(rng, 2)
    _pc("sphere", Vector3(0.1, 1.0, 0.0), Vector3(0.5, 0.25, 0.4), Color(1.0, 0.38, 0.06))
    _pc("sphere", Vector3(-0.6, 0.95, 0.1), Vector3(0.35, 0.2, 0.3), Color(1.0, 0.55, 0.12))

func _p_burning_tree(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var h := rng.randf_range(2.6, 3.8)
    var char_c := _jit(Color(0.08, 0.06, 0.05), 0.02, rng)
    _pc("cone", Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95), char_c.darkened(0.1))
    _pc("cyl", Vector3(0, h * 0.5, 0), Vector3(0.45, h, 0.45), char_c)
    for i in range(4):
        var a := rng.randf() * TAU
        var y0 := h * rng.randf_range(0.5, 0.85)
        var p1 := Vector3(cos(a) * 1.0, y0 + rng.randf_range(0.4, 0.9), sin(a) * 1.0)
        _pb("cone", Vector3(0, y0, 0), p1, 0.15, char_c)
        _pc("cone", p1 + Vector3(0, 0.3, 0), Vector3(0.4, 0.8, 0.4), Color(1.0, 0.5, 0.08))
    _pc("cone", Vector3(0, h + 0.5, 0), Vector3(1.5, 2.1, 1.5), Color(1.0, 0.36, 0.05))
    _pc("cone", Vector3(0, h + 0.3, 0), Vector3(0.9, 1.4, 0.9), Color(1.0, 0.72, 0.18))
    _pc("cone", Vector3(0.7, h * 0.7, 0.2), Vector3(0.6, 1.0, 0.6), Color(1.0, 0.45, 0.08))
    for i in range(4):
        _pc("sphere", Vector3(rng.randf_range(-0.8, 0.8), 0.04, rng.randf_range(-0.8, 0.8)), Vector3(0.25, 0.1, 0.25), Color(1.0, 0.4, 0.08))
    _col_cyl(Vector3.ZERO, 0.35, 3.0)
    _light_local(h + 0.6, 2.6, 13.0, Color(1.0, 0.45, 0.15))

# ---------- Складені сцени ----------
func _p_farmstead(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    var wood := _jit(Color(0.42, 0.28, 0.14), 0.04, rng)
    var hw := 6.4
    var d0 := -5.6
    var d1 := 5.6
    _fence_run(-hw, d0, -1.7, d0, wood, rng)
    _fence_run(1.7, d0, hw, d0, wood, rng)
    _fence_run(-hw, d1, hw, d1, wood, rng)
    _fence_run(-hw, d0, -hw, d1, wood, rng)
    _fence_run(hw, d0, hw, d1, wood, rng)
    for sx in [-1.7, 1.7]:
        _pc("box", Vector3(float(sx), 0.85, d0), Vector3(0.2, 1.7, 0.2), wood.darkened(0.15))
    _pc("box", Vector3(0, 0.02, -2.3), Vector3(1.5, 0.03, 6.2), Color(0.34, 0.27, 0.16))
    _sub(0.0, 1.8, 0.0)
    _m_hut(rng)
    _sub_end()
    _sub(-4.1, -2.5, rng.randf() * TAU)
    _m_well(rng, false)
    _sub_end()
    _sub(4.3, 3.2, rng.randf() * TAU)
    _m_haystack(rng)
    _sub_end()
    _sub(-3.9, 3.4, 0.0)
    _m_crops(rng)
    _sub_end()
    _sub(4.2, -3.0, rng.randf_range(-0.6, 0.6))
    _m_scarecrow(rng)
    _sub_end()
    _sub(4.6, 0.3, PI * 0.5)
    _m_log(rng, true)
    _sub_end()

func _m_tent(rng: RandomNumberGenerator) -> void:
    var canvas := Color.from_hsv(rng.randf_range(0.05, 0.14), 0.25, rng.randf_range(0.5, 0.62))
    if rng.randf() < 0.4:
        canvas = Color(0.28, 0.4, 0.3)
    _part("wedge", Vector3(0, 0.85, 0), Vector3(2.8, 1.7, 2.2), Vector3(0, 90, 0), canvas)
    _pc("box", Vector3(0, 0.55, -1.42), Vector3(0.75, 1.1, 0.05), Color(0.08, 0.07, 0.06))
    _pc("wedge", Vector3(0, 1.1, -1.4), Vector3(0.05, 0.6, 0.05), canvas.darkened(0.3))
    _pb("cyl", Vector3(0, 0.0, -1.55), Vector3(0, 1.8, -1.55), 0.06, Color(0.35, 0.24, 0.12))
    for sx in [-1.0, 1.0]:
        _pb("cyl", Vector3(float(sx) * 0.9, 0.9, -1.3), Vector3(float(sx) * 1.6, 0.0, -1.9), 0.02, Color(0.7, 0.65, 0.5))
        _pb("cyl", Vector3(float(sx) * 1.55, 0.0, -1.9), Vector3(float(sx) * 1.6, 0.18, -1.95), 0.05, Color(0.4, 0.3, 0.2))
    _col_box(Vector3.ZERO, Vector3(2.3, 1.6, 2.9))

func _p_tent(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_tent(rng)

func _m_campfire(rng: RandomNumberGenerator) -> void:
    _pc("cyl", Vector3(0, 0.015, 0), Vector3(1.9, 0.03, 1.9), Color(0.08, 0.06, 0.05))
    for i in range(9):
        var a := TAU * float(i) / 9.0
        _chunk_of_rock(Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), Vector3(0.38, 0.26, 0.34), _stone(rng).darkened(0.1), rng)
    for i in range(3):
        var a := TAU * float(i) / 3.0 + 0.4
        _pb("cyl", Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(-cos(a) * 0.1, 0.5, -sin(a) * 0.1), 0.14, Color(0.28, 0.18, 0.1))
    _pc("cone", Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 0.6), Color(1.0, 0.45, 0.08))
    _pc("cone", Vector3(0, 0.45, 0), Vector3(0.36, 0.8, 0.36), Color(1.0, 0.8, 0.25))
    _pc("sphere", Vector3(0, 0.15, 0), Vector3(0.7, 0.2, 0.7), Color(1.0, 0.55, 0.12))
    # триніжок із казанком
    for i in range(3):
        var a := TAU * float(i) / 3.0 + 1.0
        _pb("cyl", Vector3(cos(a) * 1.1, 0.0, sin(a) * 1.1), Vector3(0, 1.9, 0), 0.06, Color(0.2, 0.15, 0.1))
    _pc("sphere", Vector3(0, 1.25, 0), Vector3(0.55, 0.45, 0.55), Color(0.08, 0.08, 0.09))
    _col_cyl(Vector3.ZERO, 0.95, 0.6)
    _light_local(1.1, 2.6, 12.0, Color(1.0, 0.55, 0.2))

# Табір: вогнище, колоди-лавки навколо (лицем до вогню), намети входом до вогню, ящики.
func _p_camp(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _m_campfire(rng)
    var a0 := rng.randf() * TAU
    for i in range(3):
        var a := a0 + TAU * float(i) / 3.0 + rng.randf_range(-0.2, 0.2)
        _sub(cos(a) * 6.6, sin(a) * 6.6, atan2(cos(a), sin(a)))
        _m_tent(rng)
        _sub_end()
        var b := a + TAU / 6.0
        _sub(cos(b) * 2.9, sin(b) * 2.9, atan2(cos(b), sin(b)))
        _m_log(rng, true)
        _sub_end()
    var cb := a0 + TAU / 6.0 + 0.5
    _sub(cos(cb) * 4.6, sin(cb) * 4.6, rng.randf() * TAU)
    _m_crate(rng)
    _sub_end()
    _sub(cos(cb) * 4.6 + 0.9, sin(cb) * 4.6 + 0.3, rng.randf() * TAU)
    _m_barrel(rng)
    _sub_end()

func _p_ice_camp(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, float(rng.randi_range(0, 3)) * PI * 0.5)
    _sub(0.0, 1.5, 0.0)
    _m_igloo(rng)
    _sub_end()
    _sub(-4.6, -1.6, rng.randf_range(-0.5, 0.5))
    _m_cart(rng, 1)
    _sub_end()
    _sub(4.4, -1.8, rng.randf() * TAU)
    _m_frozen_statue(rng)
    _sub_end()
    _sub(3.2, 3.6, 0.0)
    _m_fire_barrel(rng)
    _sub_end()
    _sub(-3.0, 4.4, rng.randf() * TAU)
    _m_crate(rng)
    _sub_end()

func _p_caravan(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    _sub(0.0, 0.0, 0.0)
    _m_cart(rng, 1)
    _sub_end()
    _sub(3.4, -2.2, rng.randf() * TAU)
    _m_crate(rng)
    _sub_end()
    _sub(3.8, -0.9, rng.randf() * TAU)
    _m_barrel(rng)
    _sub_end()
    _sub(-3.0, 3.0, rng.randf() * TAU)
    _m_bones(rng)
    _sub_end()
    _sub(-1.6, -3.4, rng.randf() * TAU)
    _m_corpse(rng)
    _sub_end()
    _sub(2.2, 3.2, rng.randf() * TAU)
    _m_bones(rng)
    _sub_end()

func _p_burned_farm(x: float, z: float, rng: RandomNumberGenerator) -> void:
    _begin(x, z, rng.randf() * TAU)
    var soot := Color(0.09, 0.07, 0.06)
    for i in range(3):
        _pb("box", Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-2.5, 2.5)), Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.8, 2.2), rng.randf_range(-2.5, 2.5)), 0.26, soot)
    _pc("cyl", Vector3(0, 0.03, 0), Vector3(5.0, 0.04, 4.4), Color(0.12, 0.05, 0.03))
    for i in range(5):
        _pc("sphere", Vector3(rng.randf_range(-2.2, 2.2), 0.12, rng.randf_range(-2.0, 2.0)), Vector3(0.35, 0.22, 0.35), Color(1.0, rng.randf_range(0.3, 0.5), 0.07))
    _col_cyl(Vector3.ZERO, 0.9, 1.5)
    _sub(4.8, 1.2, rng.randf() * TAU)
    _m_cart(rng, 2)
    _sub_end()
    _sub(-4.6, -1.6, rng.randf() * TAU)
    _m_well(rng, true)
    _sub_end()
    _light_local(1.2, 2.6, 13.0, Color(1.0, 0.45, 0.15))


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
            _trail_dress.append({"pos": pos, "kind": _pick(TRAIL_PROPS[biome_at(pos.x, pos.y)], drng), "dir": dir, "yaw": -atan2(dir.y, dir.x)})

    # розвилка й пам'ятні місця
    landmarks = ends.duplicate()
    _add_set(hub, HUB_SET, _face_yaw(hub, start), 7.0)
    for e3 in ends:
        var ep: Vector2 = e3
        _add_set(ep, LANDMARKS[biome_at(ep.x, ep.y)], _face_yaw(ep, hub), 6.5)
    _build_trail_mesh()

func _add_set(o: Vector2, items: Array, frame_yaw: float, disc_r: float) -> void:
    clear_zones.append([o, o, 11.0])
    _discs.append([o, disc_r])
    var fb := Basis(Vector3.UP, frame_yaw)
    for it in items:
        var w: Vector3 = fb * Vector3(float(it[1]), 0.0, float(it[2]))
        var pos := o + Vector2(w.x, w.z)
        var yaw := frame_yaw
        if it.size() > 3:
            if typeof(it[3]) == TYPE_STRING:
                yaw = _face_yaw(pos, o)           # лицем до центру сцени
            else:
                yaw = frame_yaw + deg_to_rad(float(it[3]))
        _set_props.append({"pos": pos, "kind": String(it[0]), "yaw": yaw})

# Стежка й майданчики — одна сітка з вершинними кольорами: посередині втоптана земля, до країв — колір землі біому.
func _tv(st: SurfaceTool, p: Vector2, c: Color) -> void:
    st.set_color(c)
    st.set_normal(Vector3.UP)
    st.set_uv(p * GROUND_UV)
    st.add_vertex(Vector3(p.x, TRAIL_Y, p.y))

func _dirt_at(p: Vector2) -> Color:
    var c: Color = TRAIL_COL[biome_at(p.x, p.y)]
    var j := noise_d.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.04
    return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), 1.0)

func _build_trail_mesh() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tp in _trails:
        var pts: PackedVector2Array = tp
        var rows: Array = []     # на кожну точку: [PackedVector2Array(6), PackedColorArray(6)]
        for i in range(pts.size()):
            var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
            var nn := Vector2(-d.y, d.x)
            var hw := TRAIL_HALF + 0.35 * noise_d.get_noise_2d(pts[i].x * 3.0, pts[i].y * 3.0)
            var dirt := _dirt_at(pts[i])
            var rut := dirt.darkened(0.1)
            var offs := [-(hw + 1.5), -(hw + 0.5), -hw * 0.45, hw * 0.45, hw + 0.5, hw + 1.5]
            var rp := PackedVector2Array()
            var rc := PackedColorArray()
            for k in range(6):
                var pp: Vector2 = pts[i] + nn * float(offs[k])
                rp.append(pp)
                var ground := _ground_color(pp.x, pp.y)
                if k == 0 or k == 5:
                    rc.append(ground)                            # край — рівно колір землі, шва немає
                elif k == 1 or k == 4:
                    rc.append(ground.lerp(dirt, 0.55))           # м'який перехід у втоптану землю
                else:
                    rc.append(rut)
            rows.append([rp, rc])
        for i in range(rows.size() - 1):
            var ra: Array = rows[i]
            var rb: Array = rows[i + 1]
            var pa: PackedVector2Array = ra[0]
            var ca: PackedColorArray = ra[1]
            var pb: PackedVector2Array = rb[0]
            var cb: PackedColorArray = rb[1]
            for k in range(5):
                _tv(st, pa[k + 1], ca[k + 1])
                _tv(st, pa[k], ca[k])
                _tv(st, pb[k], cb[k])
                _tv(st, pa[k + 1], ca[k + 1])
                _tv(st, pb[k], cb[k])
                _tv(st, pb[k + 1], cb[k + 1])
    # майданчики на розвилці й у пам'ятних місцях: центр — втоптана земля, до краю плавно в колір землі
    for ds in _discs:
        var o: Vector2 = ds[0]
        var rad := float(ds[1])
        var dirt_c := _dirt_at(o)
        var segs := 24
        for s in range(segs):
            var a0 := TAU * float(s) / float(segs)
            var a1 := TAU * float(s + 1) / float(segs)
            var d0 := Vector2(cos(a0), sin(a0))
            var d1 := Vector2(cos(a1), sin(a1))
            var r0 := rad * (0.85 + 0.15 * noise_d.get_noise_2d(o.x + d0.x * 9.0, o.y + d0.y * 9.0))
            var r1 := rad * (0.85 + 0.15 * noise_d.get_noise_2d(o.x + d1.x * 9.0, o.y + d1.y * 9.0))
            var m0 := o + d0 * r0 * 0.62
            var m1 := o + d1 * r1 * 0.62
            var e0 := o + d0 * r0 * 1.12
            var e1 := o + d1 * r1 * 1.12
            var g0 := _ground_color(e0.x, e0.y)
            var g1 := _ground_color(e1.x, e1.y)
            var mc0 := _ground_color(m0.x, m0.y).lerp(dirt_c, 0.8)
            var mc1 := _ground_color(m1.x, m1.y).lerp(dirt_c, 0.8)
            _tv(st, o, dirt_c)
            _tv(st, m0, mc0)
            _tv(st, m1, mc1)
            _tv(st, m0, mc0)
            _tv(st, e0, g0)
            _tv(st, e1, g1)
            _tv(st, m0, mc0)
            _tv(st, e1, g1)
            _tv(st, m1, mc1)
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
