extends RefCounted
# Зброя. 1 одиниця = 1 метр.
# type: "melee" (удар по дузі), "aoe" (удар навколо себе), "proj" (снаряд), "chain" (ланцюгова блискавка), "fire" (вогняна куля: виростає над героєм ~1 с, летить у ворога й вибухає по площі 6 м), "water" (водяні кульки: злітають угору й пікірують у ворога, сповільнюють), "ice" (бурульки: ростуть над героєм і летять у ворога, заморожують)
# Прокачка: звичайні рівні 0..MAX_LEVEL (10). Кожен рівень: +25% урону, -5% перезарядки, +4% дальності, кожні 2 рівні +1 пробиття.
# ФІНАЛЬНА прокачка (рівень FINAL_LEVEL = 11): коштує половину суми всіх 10 попередніх прокачок
# і дає урону в FINAL_DMG_MULT (3) рази більше за звичайну прокачку (+75% замість +25%). Решта характеристик — як на рівні 10.

const MAX_LEVEL := 10
const FINAL_LEVEL := MAX_LEVEL + 1
const FINAL_DMG_MULT := 3.0

const ORDER := [
    "knife", "dagger", "sword", "spear", "axe", "mace", "greatsword", "warhammer",
    "bow", "throwing", "crossbow", "musket", "fire_staff", "lightning",
]

# Особлива зброя: відкривається після проходження певної локації і купується тільки в меню.
const SPECIAL := [
    "vamp_blade", "elven_bow", "blunderbuss", "thunder_hammer", "holy_spear", "dragon_staff", "storm_staff", "epicenter_blade", "water_element", "frost_staff", "fire_element", "fire_scythe",
]


# Після якої локації відкривається зброя. "" — доступна з початку гри.
# Для особливої зброї локація береться з поля "unlock" у DATA (див. unlock_loc).
const BASE_UNLOCK := {
    "knife": "", "dagger": "", "sword": "",
    "bow": "loc1", "spear": "loc1",
    "throwing": "loc2", "axe": "loc2",
    "mace": "loc3", "crossbow": "loc3",
    "greatsword": "loc5",
    "fire_staff": "loc6",
    "warhammer": "loc7",
    "lightning": "loc8",
    "musket": "loc13",
}

# ---------- Механіка ударів: ТІЛЬКИ ніж, кинджал, меч, двуручний меч ----------
# Інша зброя (спис, сокира, булава, молоти, особливі клинки) б'є по-старому.
# Удар більше не миттєвий: спочатку замах, потім «жива» фаза, коли клинок реально проходить крізь ворогів
# (кожен ворог отримує урон один раз за удар, у момент, коли клинок до нього дійшов), потім повернення.
#   style      — "slash" (замах по дузі), "stab" (випад уперед), "thrust" (спис: замах назад, довгий випад по лінії, наконечник пробиває всіх на лінії), "heavy" (важкий замах із замахом назад), "bash" (булава: замах над плечем і удар зверху, урон у момент влучання), "slam" (молот: підняти над головою й гримнути в землю, ударна хвиля в момент влучання)
#   t0, t1     — частки тривалості удару, між якими клинок небезпечний (до t0 — замах, після t1 — повернення)
#   alternate  — чергувати напрям замаху (зліва направо, потім назад)
#   move_mult  — множник швидкості героя під час удару
#   lunge      — поштовх героя вперед (м/с) у «живу» фазу
#   lock_aim   — у «живу» фазу приціл не довертається (герой вкладається в удар)
#   cone       — множник дуги для випаду (1.0 = дуга з DATA)
# Тривалість удару = 92% перезарядки, тож швидші удари при прокачці автоматично швидше й анімуються.
const BLADE := {
    "knife": {"style": "slash", "t0": 0.15, "t1": 0.55, "alternate": true, "move_mult": 1.0, "lunge": 2.5, "lock_aim": false},
    "dagger": {"style": "stab", "t0": 0.30, "t1": 0.55, "alternate": false, "move_mult": 1.0, "lunge": 3.5, "lock_aim": false, "cone": 1.0},
    "spear": {"style": "thrust", "t0": 0.32, "t1": 0.58, "alternate": false, "move_mult": 0.8, "lunge": 1.6, "lock_aim": true, "lane": 0.38},
    "holy_spear": {"style": "thrust", "t0": 0.32, "t1": 0.58, "alternate": false, "move_mult": 0.8, "lunge": 1.6, "lock_aim": true, "lane": 0.5},
    "mace": {"style": "bash", "t0": 0.40, "t1": 0.62, "alternate": false, "move_mult": 0.7, "lunge": 1.2, "lock_aim": true},
    "warhammer": {"style": "slam", "t0": 0.50, "t1": 0.66, "alternate": false, "move_mult": 0.4, "lunge": 0.0, "lock_aim": true},
    "thunder_hammer": {"style": "slam", "t0": 0.50, "t1": 0.66, "alternate": false, "move_mult": 0.4, "lunge": 0.0, "lock_aim": true},
    "sword": {"style": "slash", "t0": 0.22, "t1": 0.62, "alternate": true, "move_mult": 0.85, "lunge": 1.5, "lock_aim": false},
    # Вогняна коса: широкий швидкий замах; у момент «живої» фази від коси розходиться вогняна хвиля (wave у DATA).
    "fire_scythe": {"style": "slash", "t0": 0.25, "t1": 0.62, "alternate": true, "move_mult": 0.8, "lunge": 1.5, "lock_aim": false, "wave": true},
    "greatsword": {"style": "heavy", "t0": 0.40, "t1": 0.68, "alternate": false, "move_mult": 0.5, "lunge": 0.0, "lock_aim": true},
}

# ---------- Майстерність (окремо від прокачки за монети) ----------
# Зброя набуває майстерності, коли нею вбивають зомбі в бою. 11 рівнів; значення — СУМАРНА кількість вбивств цією зброєю,
# потрібна для рівня 1, 2, ... 11. Кожен рівень майстерності дає MASTERY_DMG_PER_LEVEL до урону цієї зброї.
# Початкова зброя (Ножик, Кинджал, Меч, Спис, Сокира, Лук, Метальні ножі) — базова шкала MASTERY_KILLS.
# Чим сильніша зброя (чим пізніше відкривається), тим більше вбивств треба: шкала плавно зсувається
# від базової (MASTERY_KILLS) до найважчої (MASTERY_KILLS_TOP — Клинок епіцентру: 2-й рівень за 100, 11-й за 3000 вбивств).
const MASTERY_KILLS := [10, 30, 55, 80, 105, 135, 165, 195, 230, 265, 300]
const MASTERY_KILLS_TOP := [30, 100, 200, 340, 520, 740, 1030, 1400, 1850, 2400, 3000]
# Ранг зброї для майстерності: 0 — базова шкала, MASTERY_RANK_MAX — найважча. Зброї, яких тут немає, мають ранг 0.
const MASTERY_RANK_MAX := 15
const MASTERY_RANK := {
    "mace": 1, "crossbow": 2, "vamp_blade": 3, "greatsword": 4, "elven_bow": 5, "fire_staff": 6, "warhammer": 7, "musket": 8,
    "blunderbuss": 9, "lightning": 10, "thunder_hammer": 11, "holy_spear": 12, "dragon_staff": 13, "storm_staff": 14, "epicenter_blade": 15, "water_element": 15, "frost_staff": 15, "fire_element": 15, "fire_scythe": 15,
}
const MASTERY_MAX := 11
const MASTERY_DMG_PER_LEVEL := 0.03

# Сумарні вбивства для рівнів 1..11 саме цієї зброї (округлено до 5).
static func mastery_table(id: String) -> Array:
    var f := float(int(MASTERY_RANK.get(id, 0))) / float(MASTERY_RANK_MAX)
    var out: Array = []
    for i in range(MASTERY_MAX):
        var v := float(MASTERY_KILLS[i]) + (float(MASTERY_KILLS_TOP[i]) - float(MASTERY_KILLS[i])) * f
        out.append(int(round(v / 5.0)) * 5)
    return out

static func mastery_level(kills: int, id: String = "") -> int:
    var l := 0
    for need in mastery_table(id):
        if kills >= int(need):
            l += 1
    return l

# Скільки вбивств сумарно потрібно для наступного рівня майстерності (-1, якщо рівень максимальний).
static func mastery_next_kills(kills: int, id: String = "") -> int:
    var l := mastery_level(kills, id)
    if l >= MASTERY_MAX:
        return -1
    return int(mastery_table(id)[l])

static func mastery_mult(mlvl: int) -> float:
    return 1.0 + MASTERY_DMG_PER_LEVEL * float(mlvl)

static func is_blade(id: String) -> bool:
    return BLADE.has(id)

const DATA := {
    "knife": {"name": "Ножик", "type": "melee", "damage": 9, "cooldown": 0.25, "range": 1.7, "arc": 1.4, "knock": 4.0, "price": 0, "upg": 30,
        "desc": "Меткий, мов жало, та кволий на силу"},
    "dagger": {"name": "Кинджал", "type": "melee", "damage": 7, "cooldown": 0.16, "range": 1.5, "arc": 1.2, "knock": 2.0, "price": 40, "upg": 35,
        "desc": "Зграя блискавичних випадів, що жалять без упину"},
    "sword": {"name": "Меч", "type": "melee", "damage": 24, "cooldown": 0.55, "range": 2.7, "arc": 2.1, "knock": 8.0, "price": 60, "upg": 50,
        "desc": "Вірний клинок лицаря: ні надто легкий, ні надто важкий"},
    "spear": {"name": "Спис", "type": "melee", "damage": 28, "cooldown": 0.7, "range": 4.2, "arc": 0.5, "knock": 6.0, "price": 100, "upg": 60,
        "desc": "Довгий вузький випад, що дістає ворога задалеко"},
    "axe": {"name": "Сокира", "type": "melee", "damage": 38, "cooldown": 0.85, "range": 2.6, "arc": 2.6, "knock": 8.0, "price": 160, "upg": 80,
        "desc": "Широкий могутній замах, що косить усе довкола"},
    "mace": {"name": "Булава", "type": "melee", "damage": 34, "cooldown": 0.8, "range": 2.4, "arc": 1.8, "knock": 18.0, "price": 200, "upg": 90,
        "desc": "Важкий удар, що відкидає ворогів геть"},
    "greatsword": {"name": "Двуручний меч", "type": "melee", "damage": 60, "cooldown": 1.1, "range": 3.4, "arc": 2.8, "knock": 12.0, "price": 380, "upg": 130,
        "desc": "Величезний урон і розлога дуга: клинок для тих, хто рубає навідліг"},
    "warhammer": {"name": "Бойовий молот", "type": "aoe", "damage": 80, "cooldown": 1.5, "range": 3.6, "arc": 6.28, "knock": 22.0, "price": 520, "upg": 170,
        "desc": "Молот, що б’є по всіх довкола, мов дзвін по склепінню"},
    "bow": {"name": "Лук", "type": "proj", "damage": 20, "cooldown": 0.7, "speed": 24.0, "pierce": 0, "style": "arrow", "knock": 6.0, "price": 90, "upg": 55,
        "desc": "Стріли, що вражають здалеку, ще до того, як ворог підійде"},
    "throwing": {"name": "Метальні ножі", "type": "proj", "damage": 10, "cooldown": 0.5, "speed": 28.0, "pierce": 0, "count": 3, "spread": 0.25, "style": "knife", "knock": 3.0, "price": 140, "upg": 70,
        "desc": "Віяло з трьох метальних ножів, що розлітаються в одну мить"},
    "crossbow": {"name": "Арбалет", "type": "proj", "damage": 55, "cooldown": 1.2, "speed": 36.0, "pierce": 2, "style": "bolt", "knock": 9.0, "price": 260, "upg": 100,
        "desc": "Важкий болт, що пронизує кількох ворогів поспіль"},
    "musket": {"name": "Аркебуза", "type": "proj", "damage": 120, "cooldown": 2.2, "speed": 50.0, "pierce": 3, "style": "bullet", "knock": 14.0, "price": 480, "upg": 160,
        "desc": "Постріли рідкісні, та кожен гримить, мов вирок"},
    "fire_staff": {"name": "Вогняний посох", "type": "proj", "damage": 35, "cooldown": 1.0, "speed": 14.0, "pierce": 0, "aoe": 3.2, "style": "fire", "knock": 10.0, "price": 420, "upg": 140,
        "desc": "Вогняна куля, що розквітає вибухом"},
    "lightning": {"name": "Посох блискавки", "type": "chain", "damage": 30, "cooldown": 0.9, "range": 9.0, "chain": 4, "knock": 4.0, "price": 600, "upg": 190,
        "desc": "Блискавка перестрибує поміж ворогами, мов іскра по стерні"},
    # ---------- ОСОБЛИВА ЗБРОЯ ----------
    "vamp_blade": {"name": "Кривавий клинок", "type": "melee", "damage": 55, "cooldown": 0.5, "range": 2.8, "arc": 2.2, "knock": 8.0, "lifesteal": 0.08, "price": 900, "upg": 200,
        "special": true, "unlock": "loc4", "desc": "Клинок спраглий: лікує господаря з кожної завданої рани"},
    "elven_bow": {"name": "Ельфійський лук", "type": "proj", "damage": 28, "cooldown": 0.35, "speed": 32.0, "pierce": 2, "count": 2, "spread": 0.12, "style": "arrow", "knock": 6.0, "price": 1100, "upg": 240,
        "special": true, "unlock": "loc5", "desc": "Пара прудких стріл, що пронизують ворогів наскрізь"},
    "blunderbuss": {"name": "Мушкетон", "type": "proj", "damage": 30, "cooldown": 1.4, "speed": 40.0, "pierce": 1, "count": 6, "spread": 0.35, "style": "bullet", "knock": 10.0, "price": 1500, "upg": 280,
        "special": true, "unlock": "loc7", "desc": "Картеч, що косить усе, що стоїть перед дулом, по площі"},
    "thunder_hammer": {"name": "Громовий молот", "type": "aoe", "damage": 150, "cooldown": 1.3, "range": 5.0, "arc": 6.28, "knock": 30.0, "price": 1400, "upg": 280,
        "special": true, "unlock": "loc8", "desc": "Грім, що спалахує по всьому колу довкола героя"},
    "holy_spear": {"name": "Святий спис", "type": "melee", "damage": 90, "cooldown": 0.75, "range": 5.0, "arc": 0.6, "knock": 10.0, "price": 1300, "upg": 260,
        "special": true, "unlock": "loc9", "desc": "Дуже довгий і нищівний, мов небесна кара"},
    "dragon_staff": {"name": "Посох дракона", "type": "proj", "damage": 70, "cooldown": 0.9, "speed": 16.0, "pierce": 0, "aoe": 4.8, "style": "fire", "knock": 14.0, "price": 1800, "upg": 320,
        "special": true, "unlock": "loc10", "desc": "Величезні вибухи, подих дракона на кінчику посоха"},
    "storm_staff": {"name": "Посох бурі", "type": "chain", "damage": 55, "cooldown": 0.6, "range": 11.0, "chain": 7, "knock": 6.0, "price": 2000, "upg": 350,
        "special": true, "unlock": "loc11", "desc": "Буря на посоху: блискавка вражає до 7 ворогів"},
    "epicenter_blade": {"name": "Клинок епіцентру", "type": "melee", "damage": 160, "cooldown": 0.7, "range": 3.6, "arc": 2.8, "knock": 14.0, "lifesteal": 0.12, "price": 5000, "upg": 600,
        "special": true, "unlock": "loc12", "desc": "Клинок, народжений із самого лона вірусу"},
    # Стихія води: відкривається після «Токсичного болота» (loc15). 3 кульки на секунду на 1-му рівні (кожна — 110 урону),
    # на 10-му рівні перезарядка вдвічі менша (6 на секунду). Кожне влучання сповільнює ворога на slow секунд до slow_mult швидкості.
    "water_element": {"name": "Стихія води", "type": "water", "damage": 110, "cooldown": 0.3333, "range": 16.0, "speed": 26.0, "knock": 3.0, "slow": 1.0, "slow_mult": 0.5, "price": 6500, "upg": 700,
        "special": true, "unlock": "loc15", "desc": "Водяні кулі здіймаються вгору й падають на ворога, стишуючи його ходу"},
    # Стихія морозу (id лишився frost_staff, щоб не зламати збереження): відкривається після «Мертвої тундри» (loc16). У руках немає предмета,
    # над кулаками висить холодний туман. Над героєм поступово виростають бурульки й летять у ворогів.
    # 2 бурульки на секунду на 1-му рівні (удвічі повільніше за воду, але урон удвічі більший). Влучання заморожує ворога повністю
    # на freeze секунд, але лише з шансом freeze_chance (10%); на босів шанс лише freeze_chance_boss (1%).
    "frost_staff": {"name": "Стихія морозу", "type": "ice", "damage": 220, "cooldown": 0.5, "range": 18.0, "speed": 34.0, "knock": 2.0, "freeze": 1.0, "freeze_chance": 0.10, "freeze_chance_boss": 0.01, "price": 8200, "upg": 850,
        "special": true, "unlock": "loc16", "desc": "Туман вкриває долоні, бурульки зависають над героєм. Влучання з шансом 10% заморожує ворога (на босів — 1%)"},
    # Стихія вогню: відкривається після «Серця пожежі» (loc22). У руках горить вогонь. Над героєм ~1 с (на 1-му рівні) виростає вогняна куля
    # діаметром 2 м, потім летить у ворога й вибухає: усі в радіусі aoe (6 м) отримують повний урон. Урон: базовий × (1 + 0.25 × рівень), на фінальному
    # (11-му) рівні множник 4.25, тож 705.882 × 4.25 = 3000 по площі. Перезарядка як у решти: −5% за рівень (на 10-му рівні вдвічі швидше), куля росте
    # половину перезарядки (1 с → 0.5 с).
    "fire_element": {"name": "Стихія вогню", "type": "fire", "damage": 705.8823529, "cooldown": 2.0, "range": 18.0, "speed": 30.0, "knock": 14.0, "aoe": 6.0, "price": 14000, "upg": 1400,
        "special": true, "unlock": "loc22", "desc": "У долонях палає полум’я. Над героєм наростає вогняна куля, летить до ворога й вибухає на 6 метрів довкола"},
    # Вогняна коса (синє полум'я): відкривається після «Магмового ядра» (loc23). Удар косою ПІДПАЛЮЄ зомбі: вони горять до смерті й
    # щосекунди отримують burn урону (на фінальному 11-му рівні 300). Від кожного удару від коси розходиться вогняна хвиля, що біжить по прямій вперед на wave_r (7 м)
    # з уроном wave (на фінальному рівні 1500), але хвиля НЕ підпалює. Усі числа множаться на рівень так само, як звичайний урон
    # (на фінальному — ×4.25): 705.88 × 4.25 = 3000 за удар, 70.59 × 4.25 = 300 горіння за секунду, 352.94 × 4.25 = 1500 хвиля.
    # Перезарядка 1.5 с → на 10-му й 11-му рівнях 0.75 с.
    "fire_scythe": {"name": "Вогняна коса", "type": "melee", "damage": 705.8823529411765, "cooldown": 1.5, "range": 3.0, "arc": 2.5, "knock": 10.0,
        "burn": 70.58823529411765, "wave": 352.94117647058823, "wave_r": 7.0, "price": 20000, "upg": 2000,
        "special": true, "unlock": "loc23", "desc": "Синє полум’я: удар підпалює зомбі навічно, а від коси вперед по прямій біжить вогняна хвиля на 7 метрів, що розширюється й має рваний край"},
}

# Зброя прокачана до фінального (11) рівня.
static func is_final(lvl: int) -> bool:
    return lvl >= FINAL_LEVEL

# Звичайні рівні (без фінального) — від них залежать усі характеристики, крім урону.
static func _base_lvl(lvl: int) -> int:
    return mini(lvl, MAX_LEVEL)

static func damage(id: String, lvl: int) -> float:
    var steps := float(_base_lvl(lvl))
    if is_final(lvl):
        steps += FINAL_DMG_MULT
    return float(DATA[id]["damage"]) * (1.0 + 0.25 * steps)

# Скільки урону за секунду завдає горіння (зброя з полем "burn") і скільки — вогняна хвиля (поле "wave") на рівні lvl.
# Множиться на рівень так само, як і основний урон.
static func _level_mult(lvl: int) -> float:
    var steps := float(_base_lvl(lvl))
    if is_final(lvl):
        steps += FINAL_DMG_MULT
    return 1.0 + 0.25 * steps

static func burn_dps(id: String, lvl: int) -> float:
    return float(DATA[id].get("burn", 0.0)) * _level_mult(lvl)

static func wave_damage(id: String, lvl: int) -> float:
    return float(DATA[id].get("wave", 0.0)) * _level_mult(lvl)

static func cooldown(id: String, lvl: int) -> float:
    return float(DATA[id]["cooldown"]) * maxf(0.5, 1.0 - 0.05 * float(_base_lvl(lvl)))

static func range_of(id: String, lvl: int) -> float:
    return float(DATA[id].get("range", 0.0)) * (1.0 + 0.04 * float(_base_lvl(lvl)))

static func pierce(id: String, lvl: int) -> int:
    return int(DATA[id].get("pierce", 0)) + int(floor(float(_base_lvl(lvl)) / 2.0))

static func chain_count(id: String, lvl: int) -> int:
    return int(DATA[id].get("chain", 0)) + int(floor(float(_base_lvl(lvl)) / 2.0))

# Ціна прокачки з рівня lvl на lvl+1. Фінальна (з 10 на 11) = половина суми всіх 10 попередніх прокачок.
static func upgrade_cost(id: String, lvl: int) -> int:
    var upg := int(DATA[id]["upg"])
    if lvl >= MAX_LEVEL:
        var total := 0
        for i in range(MAX_LEVEL):
            total += upg * (i + 1)
        return int(ceil(float(total) / 2.0))
    return upg * (lvl + 1)

static func all_ids() -> Array:
    return ORDER + SPECIAL

# id локації, після проходження якої відкривається ця зброя ("" — відкрита з початку).
static func unlock_loc(id: String) -> String:
    var w: Dictionary = DATA[id]
    if w.has("unlock"):
        return String(w["unlock"])
    return String(BASE_UNLOCK.get(id, ""))
