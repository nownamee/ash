extends RefCounted
# Навики (пасивні бонуси). Прокачуються тільки в головному меню.

const ORDER := ["vitality", "swift", "power", "haste", "crit", "vampire", "regen", "greed", "dash", "jump"]

const DATA := {
    "vitality": {"name": "Міцне здоров'я", "desc": "Дужчий тілом: +15 макс. HP за рівень", "max": 10, "cost": 60},
    "swift": {"name": "Прудкі ноги", "desc": "Легка хода: +3% швидкості руху за рівень", "max": 10, "cost": 50},
    "power": {"name": "Сила", "desc": "Міць руки: +4% урону за рівень", "max": 10, "cost": 80},
    "haste": {"name": "Швидкі руки", "desc": "Спритна рука: -3% перезарядки зброї за рівень", "max": 10, "cost": 80},
    "crit": {"name": "Критичний удар", "desc": "Влучність долі: +2% шансу крита (x2 урон) за рівень", "max": 10, "cost": 70},
    "vampire": {"name": "Вампіризм", "desc": "Кров ворога живить: +1 HP за кожного вбитого за рівень", "max": 5, "cost": 120},
    "regen": {"name": "Регенерація", "desc": "Рани гояться самі: +0.3 HP/с за рівень", "max": 5, "cost": 120},
    "greed": {"name": "Грабіжник", "desc": "Здобич щедріша: +4% монет за рівень", "max": 10, "cost": 100},
    "dash": {"name": "Блискавичний ривок", "desc": "Права кнопка миші: стрімкий ривок уперед, туди, куди націлена миша. Усі вороги на шляху отримують урон. Відкривається після проходження «Замку епіцентру».", "max": 10, "cost": 800, "unlock": "loc12"},
    "jump": {"name": "Вибуховий стрибок", "desc": "Пробіл: герой злітає високо й перестрибує на відстань до 15 м, туди, куди націлена миша, а при приземленні довкола стається міні-вибух, що завдає урону всім ворогам поруч і відкидає їх. Увесь стрибок триває близько 1,5 с, і весь цей час герой невразливий: його не можна поранити. Приземлення завдає 5000 урону. Відкривається після проходження «Пожежі». Із цим навиком пробіл більше не б’є зброєю (атака — лівою кнопкою миші).", "max": 10, "cost": 1000, "unlock": "loc18"},
}

# Стрибок: урон приземлення завжди 5000 (JUMP_DMG_MIN / MAX — крайні значення за рівнями, зараз однакові); радіус: рівень 1 — 2 м, рівень 10 — 6 м (лінійно); перезарядка завжди 10 с.
# Під час польоту герой невразливий (player.gd → take_damage).
const JUMP_DMG_MIN := 5000.0
const JUMP_DMG_MAX := 5000.0
const JUMP_R_MIN := 2.0
const JUMP_R_MAX := 6.0
const JUMP_CD := 10.0
const JUMP_DIST := 15.0       # максимальна дальність стрибка, м (стрибок летить до курсора, але не далі)
const JUMP_DIST_MIN := 4.0    # якщо курсор ближче — усе одно стрибаємо щонайменше на стільки

static func jump_damage(lvl: int) -> float:
    var t := float(clampi(lvl, 1, 10) - 1) / 9.0
    return roundf(lerpf(JUMP_DMG_MIN, JUMP_DMG_MAX, t))

static func jump_radius(lvl: int) -> float:
    var t := float(clampi(lvl, 1, 10) - 1) / 9.0
    return lerpf(JUMP_R_MIN, JUMP_R_MAX, t)

static func jump_line(lvl: int) -> String:
    if lvl <= 0:
        return "—"
    return "урон %d · радіус %.1f м · перезарядка %.0f с" % [int(jump_damage(lvl)), jump_radius(lvl), JUMP_CD]

static func stat_line(id: String, lvl: int) -> String:
    if id == "dash":
        return dash_line(lvl)
    if id == "jump":
        return jump_line(lvl)
    return ""

# Ривок: рівень 1 — 3 м, 300 урону, перезарядка 5 с; рівень 10 — 10 м, 3000 урону, перезарядка 3 с (лінійно між ними).
const DASH_DIST_MIN := 3.0
const DASH_DIST_MAX := 10.0
const DASH_DMG_STEP := 300.0
const DASH_CD_MAX := 5.0
const DASH_CD_MIN := 3.0

static func dash_distance(lvl: int) -> float:
    var t := float(clampi(lvl, 1, 10) - 1) / 9.0
    return lerpf(DASH_DIST_MIN, DASH_DIST_MAX, t)

static func dash_damage(lvl: int) -> float:
    return DASH_DMG_STEP * float(clampi(lvl, 1, 10))

static func dash_cooldown(lvl: int) -> float:
    var t := float(clampi(lvl, 1, 10) - 1) / 9.0
    return lerpf(DASH_CD_MAX, DASH_CD_MIN, t)

static func dash_line(lvl: int) -> String:
    if lvl <= 0:
        return "—"
    return "дистанція %.1f м · урон %d · перезарядка %.1f с" % [dash_distance(lvl), int(dash_damage(lvl)), dash_cooldown(lvl)]

static func cost(id: String, lvl: int) -> int:
    return int(DATA[id]["cost"]) * (lvl + 1)
