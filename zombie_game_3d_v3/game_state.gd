extends RefCounted
# Глобальний стан гри (живе між сценами меню та бою) і збереження прогресу в user://.

const Armor = preload("res://armor.gd")
const Weapons = preload("res://weapons.gd")
const Skills = preload("res://skills.gd")

const SAVE_PATH := "user://save_v3.json"
const MAX_LOADOUT := 5
# true — усі готові локації відкриті одразу (для перегляду й тестів). Прогрес не підроблюється: зброя, броня й навики,
# що відкриваються проходженням локацій (наприклад, ривок і стрибок), як і раніше потребують справжньої перемоги.
# Щоб повернути відкриття по черзі, поставте false.
const OPEN_ALL_LOCATIONS := true

static var loaded := false
static var coins := 0
static var weapon_levels := {"knife": 0}      # куплена зброя -> рівень прокачки
static var loadout: Array = ["knife"]         # зброя, яку беремо в бій (до 5)
static var weapon_kills := {}                 # зброя -> скільки зомбі вбито нею (майстерність)
static var revealed := {}                     # зброя, що вже «вистрибнула» у свою комірку в меню
static var armor := _empty_armor()   # ключ (Armor.key) -> куплений наскрізний рівень у цьому комплекті (0 — немає)
static var skills := {}
static var conquered := {}
static var selected_loc := "loc1"
static var last_result := ""

static func skill_level(id: String) -> int:
    return int(skills.get(id, 0))

# Навик відкритий, якщо пройдено локацію, що його відкриває (поле unlock у skills.gd); без поля — доступний одразу.
static func skill_unlocked(id: String) -> bool:
    var loc := String(Skills.DATA[id].get("unlock", ""))
    return loc == "" or conquered.has(loc)

static func _empty_armor() -> Dictionary:
    var d := {}
    for k in Armor.all_keys():
        d[k] = 0
    return d

# Найсильніша куплена частина в слоті серед усіх комплектів (наскрізний рівень; 0 — нічого немає). Саме її видно на герої й вона діє в бою.
static func armor_best(slot: String) -> int:
    var best := 0
    for si in range(Armor.SETS.size()):
        best = maxi(best, int(armor.get(Armor.key(slot, si), 0)))
    return best

static func armor_defense() -> float:
    var d := 0.0
    for slot in Armor.SLOTS:
        d += Armor.defense(slot, armor_best(String(slot)))
    return minf(d, 0.90)   # стеля сумарного захисту: повний набір «Броні привида» — 142%, «Магмової броні» — 203% (обидва обрізаються до 90%)

# Комплект з'являється в меню, коли пройдено його локацію.
static func armor_set_open(si: int) -> bool:
    var loc := String(Armor.SETS[si]["loc"])
    return loc == "" or conquered.has(loc)

# Рівні 5-8 відкриваються після «Мертвого мегаполіса», 9-10 («Броня привида») — після «Міста-привида», 11-13 («Магмова броня») — після «Магмового ядра».
static func armor_tier_unlocked(tier: int) -> bool:
    var loc := Armor.unlock_loc(tier)
    return loc == "" or conquered.has(loc)

static func armor_speed() -> float:
    return float(Armor.BOOTS_SPEED[armor_best("boots")])

static func is_unlocked(loc: Dictionary) -> bool:
    if bool(loc.get("wip", false)):
        return false      # рівень ще не зроблено: на карті він завжди закритий
    if OPEN_ALL_LOCATIONS:
        return true
    var req: Array = loc["req"]
    if req.is_empty():
        return true
    for r in req:
        if conquered.has(String(r)):
            return true
    return false

# Локацію, що відкриває цю зброю, пройдено (або зброя доступна з початку).
static func weapon_unlock_ready(id: String) -> bool:
    var loc := Weapons.unlock_loc(id)
    return loc == "" or conquered.has(loc)

# Зброя вже стоїть у своїй комірці (початкова, куплена, або гравець натиснув її іконку після проходження локації).
static func weapon_revealed(id: String) -> bool:
    return revealed.has(id) or weapon_levels.has(id) or Weapons.unlock_loc(id) == ""

static func weapon_mastery(id: String) -> int:
    return Weapons.mastery_level(int(weapon_kills.get(id, 0)), id)

# Одноразовий бонус: 1 000 000 монет і «Мертва тундра» (loc16) зарахована як пройдена.
# Видається один раз на збереження (прапорець bonus_v1 у save_v3.json), тож витрачені монети не повертаються при кожному запуску.
const BONUS_COINS := 1000000
const BONUS_LOC := "loc16"
static var bonus_given := false

static func load_game() -> void:
    if loaded:
        return
    loaded = true
    _read_save()
    if not bonus_given:
        bonus_given = true
        coins += BONUS_COINS
        conquered[BONUS_LOC] = true
        save_game()

static func _read_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    coins = int(parsed.get("coins", 0))
    bonus_given = bool(parsed.get("bonus_v1", false))
    weapon_levels = {}
    var wl: Dictionary = parsed.get("weapon_levels", {})
    for k in wl:
        weapon_levels[String(k)] = int(wl[k])
    if not weapon_levels.has("knife"):
        weapon_levels["knife"] = 0
    loadout = []
    for id in parsed.get("loadout", ["knife"]):
        if weapon_levels.has(String(id)) and loadout.size() < MAX_LOADOUT:
            loadout.append(String(id))
    if loadout.is_empty():
        loadout = ["knife"]
    var ar: Dictionary = parsed.get("armor", {})
    armor = _empty_armor()
    for s in armor.keys():
        armor[s] = int(ar.get(s, 0))
    # старе збереження: рівні 7-8 колись були примарною бронею в тих самих слотах → переносимо до комплекту «Броня привида» (рівні 9-10)
    for slot in Armor.SLOTS:
        var old_t := int(armor[String(slot)])
        if old_t > Armor.set_last(0):
            armor[Armor.key(String(slot), 2)] = old_t + 2
            armor[String(slot)] = Armor.set_last(0)
    skills = {}
    var sk: Dictionary = parsed.get("skills", {})
    for k in sk:
        skills[String(k)] = int(sk[k])
    conquered = {}
    var cq: Dictionary = parsed.get("conquered", {})
    for k in cq:
        conquered[String(k)] = true
    selected_loc = String(parsed.get("selected", "loc1"))
    weapon_kills = {}
    var wk: Dictionary = parsed.get("weapon_kills", {})
    for k in wk:
        weapon_kills[String(k)] = int(wk[k])
    revealed = {}
    var rv: Dictionary = parsed.get("revealed", {})
    for k in rv:
        revealed[String(k)] = true

static func save_game() -> void:
    var data := {
        "coins": coins,
        "weapon_levels": weapon_levels,
        "loadout": loadout,
        "armor": armor,
        "skills": skills,
        "conquered": conquered,
        "selected": selected_loc,
        "revealed": revealed,
        "weapon_kills": weapon_kills,
        "bonus_v1": bonus_given,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(data))

static func reset_progress() -> void:
    coins = 0
    weapon_levels = {"knife": 0}
    loadout = ["knife"]
    armor = _empty_armor()
    skills = {}
    conquered = {}
    revealed = {}
    weapon_kills = {}
    selected_loc = "loc1"
    last_result = ""
    save_game()
