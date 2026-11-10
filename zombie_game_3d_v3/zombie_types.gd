extends RefCounted
# Типи зомбі. Щоб додати новий: додайте запис у DATA і (за бажанням) у POOLS біому.
# Поля: hp, speed, damage, reach, radius, reward, color, size (множник), ai (melee/ranged/charger),
# look (вигляд: skin, cloth, hat, weapon, armor, fat, extras, eyes), knock_resist, slow, explode, ghost, boss, campaign.

# Стрибок жирних зомбі: cd — перезарядка (с), min/max — на якій відстані від цілі стрибають (м),
# wind — час «присідання» перед стрибком, time — час у повітрі, height — висота дуги,
# radius — радіус ударної хвилі при приземленні (radius_mult — замість нього: радіус тіла зомбі × множник, тобто удар лише навколо самого тіла), dmg — множник шкоди від damage зомбі.
const JUMP_MEDIUM := {"cd": 15.0, "min": 5.0, "max": 11.0, "wind": 0.55, "time": 0.8, "height": 3.0, "radius": 3.0, "dmg": 1.2}
# Величезні (Колос, Король жиробасів): стрибають з будь-якої точки карти прямо на героя, дуже високо.
# time_per_m / height_per_m — скільки додається до часу й висоти за кожен метр відстані (time_max, height_max — межі);
# track — до якої частки польоту точка приземлення слідкує за героєм (потім завмирає, і можна відскочити); marker — тінь-мітка на землі.
const JUMP_HUGE := {"cd": 10.0, "min": 5.0, "max": 400.0, "wind": 0.9, "time": 1.2, "height": 14.0, "radius": 6.0, "radius_mult": 1.3, "dmg": 2.0,
    "time_per_m": 0.015, "time_max": 3.0, "height_per_m": 0.2, "height_max": 30.0, "track": 0.7, "marker": true}

const DATA := {
    # ---------- Луки ----------
    "walker": {"name": "Простий зомбі", "hp": 30, "speed": 2.2, "damage": 8, "reach": 0.9, "radius": 0.47, "reward": 5,
        "color": Color(0.45, 0.62, 0.35), "look": {}},
    "clothed": {"name": "Одягнений зомбі", "hp": 45, "speed": 2.4, "damage": 10, "reach": 0.9, "radius": 0.47, "reward": 7,
        "color": Color(0.5, 0.62, 0.4), "look": {"cloth": Color(0.5, 0.34, 0.2), "hat": "cap"}},
    "farmer": {"name": "Зомбі-селянин з вилами", "hp": 70, "speed": 1.7, "damage": 14, "reach": 1.5, "radius": 0.5, "reward": 12,
        "color": Color(0.58, 0.47, 0.30), "look": {"cloth": Color(0.45, 0.38, 0.22), "hat": "straw", "weapon": "pitchfork"}},
    "woodcutter": {"name": "Зомбі-дроворуб", "hp": 120, "speed": 1.9, "damage": 22, "reach": 1.5, "radius": 0.52, "reward": 20,
        "color": Color(0.5, 0.55, 0.35), "look": {"cloth": Color(0.62, 0.15, 0.1), "hat": "cap", "weapon": "axe"}},
    # ---------- Ліс ----------
    "hunter": {"name": "Лісовий мисливець", "hp": 50, "speed": 1.8, "damage": 9, "reach": 0.9, "radius": 0.45, "reward": 14,
        "color": Color(0.4, 0.55, 0.35), "ai": "ranged", "pref_range": 9.0, "shoot_cd": 2.0, "proj_speed": 14.0, "proj_color": Color(0.8, 0.7, 0.4),
        "look": {"cloth": Color(0.2, 0.35, 0.15), "hat": "hood", "weapon": "bow"}},
    "runner": {"name": "Лісовий бігун", "hp": 35, "speed": 4.4, "damage": 9, "reach": 0.9, "radius": 0.42, "reward": 10, "size": 0.92,
        "color": Color(0.55, 0.6, 0.45), "look": {"skin": Color(0.7, 0.75, 0.6), "cloth": Color(0.3, 0.3, 0.25)}},
    "mossy": {"name": "Мохистий зомбі", "hp": 190, "speed": 1.5, "damage": 18, "reach": 1.0, "radius": 0.55, "reward": 24, "size": 1.1,
        "color": Color(0.28, 0.42, 0.22), "look": {"cloth": Color(0.25, 0.38, 0.2), "extras": ["growth"]}},
    # ---------- Пустеля ----------
    "mummy": {"name": "Мумія", "hp": 85, "speed": 2.0, "damage": 14, "reach": 1.0, "radius": 0.47, "reward": 16,
        "color": Color(0.85, 0.8, 0.65), "look": {"extras": ["bandage"], "eyes": Color(0.3, 0.9, 0.9)}},
    "bandit": {"name": "Зомбі-розбійник", "hp": 95, "speed": 2.8, "damage": 17, "reach": 1.5, "radius": 0.48, "reward": 22,
        "color": Color(0.65, 0.5, 0.35), "ai": "charger",
        "look": {"cloth": Color(0.55, 0.15, 0.12), "hat": "turban", "weapon": "sword"}},
    "spitter": {"name": "Піщаний плювальник", "hp": 55, "speed": 1.9, "damage": 12, "reach": 0.9, "radius": 0.45, "reward": 18,
        "color": Color(0.7, 0.62, 0.3), "ai": "ranged", "pref_range": 8.0, "shoot_cd": 2.2, "proj_speed": 11.0, "proj_color": Color(0.6, 0.95, 0.2),
        "look": {"cloth": Color(0.6, 0.5, 0.25), "hat": "hood", "eyes": Color(0.6, 1.0, 0.1)}},
    # ---------- Сніги ----------
    "frozen": {"name": "Замерзлий зомбі", "hp": 105, "speed": 1.7, "damage": 12, "reach": 1.0, "radius": 0.5, "reward": 20, "slow": 1.8,
        "color": Color(0.6, 0.8, 0.9), "look": {"extras": ["icicles"], "eyes": Color(0.4, 0.8, 1.0)}},
    "northman": {"name": "Північний воїн", "hp": 160, "speed": 2.2, "damage": 22, "reach": 1.4, "radius": 0.52, "reward": 28,
        "color": Color(0.65, 0.62, 0.6), "look": {"cloth": Color(0.4, 0.3, 0.25), "hat": "horned", "armor": true, "weapon": "club"}},
    "icegiant": {"name": "Крижаний велетень", "hp": 300, "speed": 1.4, "damage": 30, "reach": 1.4, "radius": 0.6, "reward": 45, "size": 1.35,
        "color": Color(0.7, 0.85, 0.95), "knock_resist": 0.5, "look": {"extras": ["icicles"], "eyes": Color(0.4, 0.8, 1.0)}},
    # ---------- Цвинтар ----------
    "skeleton": {"name": "Кістяк", "hp": 42, "speed": 2.8, "damage": 11, "reach": 1.4, "radius": 0.42, "reward": 11,
        "color": Color(0.88, 0.86, 0.8), "look": {"cloth": Color(0.85, 0.83, 0.77), "skin": Color(0.86, 0.82, 0.70), "bare": true, "weapon": "sword", "eyes": Color(0.9, 0.5, 0.1)}},
    "gravedigger": {"name": "Гробокопач", "hp": 125, "speed": 1.8, "damage": 20, "reach": 1.6, "radius": 0.52, "reward": 22,
        "color": Color(0.5, 0.5, 0.45), "look": {"cloth": Color(0.25, 0.25, 0.3), "hat": "cap", "weapon": "shovel"}},
    "ghost": {"name": "Привид", "hp": 32, "speed": 3.0, "damage": 10, "reach": 1.0, "radius": 0.45, "reward": 15, "ghost": true,
        "color": Color(0.7, 0.8, 0.95), "look": {"eyes": Color(0.6, 0.9, 1.0)}},
    # ---------- Руїни ----------
    "marauder": {"name": "Мародер", "hp": 140, "speed": 2.3, "damage": 18, "reach": 1.5, "radius": 0.5, "reward": 24,
        "color": Color(0.55, 0.5, 0.45), "look": {"cloth": Color(0.35, 0.3, 0.28), "hat": "helmet", "armor": true, "weapon": "sword"}},
    "knight": {"name": "Лицар-зомбі", "hp": 280, "speed": 1.7, "damage": 28, "reach": 1.5, "radius": 0.55, "reward": 40, "size": 1.12,
        "color": Color(0.5, 0.55, 0.55), "look": {"cloth": Color(0.55, 0.58, 0.62), "hat": "helmet", "armor": true, "weapon": "sword", "eyes": Color(1.0, 0.3, 0.1)}},
    "mage": {"name": "Заражений маг", "hp": 70, "speed": 1.9, "damage": 16, "reach": 0.9, "radius": 0.45, "reward": 30,
        "color": Color(0.5, 0.45, 0.6), "ai": "ranged", "pref_range": 10.0, "shoot_cd": 2.4, "proj_speed": 12.0, "proj_color": Color(0.7, 0.3, 1.0),
        "look": {"cloth": Color(0.3, 0.15, 0.45), "hat": "hood", "weapon": "staff", "eyes": Color(0.8, 0.3, 1.0)}},
    # ---------- Місто ----------
    "infected": {"name": "Заражений городянин", "hp": 60, "speed": 2.7, "damage": 11, "reach": 0.9, "radius": 0.46, "reward": 12,
        "color": Color(0.5, 0.52, 0.45), "look": {"cloth": Color(0.33, 0.38, 0.48)}},
    "crawler": {"name": "Повзун", "hp": 45, "speed": 3.4, "damage": 10, "reach": 0.9, "radius": 0.4, "reward": 14, "size": 0.9,
        "color": Color(0.5, 0.5, 0.44), "look": {"crawl": true, "cloth": Color(0.3, 0.28, 0.26), "eyes": Color(1.0, 0.35, 0.1)}},
    "police": {"name": "Зомбі-поліцейський", "hp": 150, "speed": 2.0, "damage": 20, "reach": 1.5, "radius": 0.5, "reward": 24,
        "color": Color(0.5, 0.5, 0.46), "look": {"cloth": Color(0.12, 0.17, 0.3), "hat": "cap", "vest": true, "weapon": "baton"}},
    "hazmat": {"name": "Зомбі в хімзахисті", "hp": 105, "speed": 1.8, "damage": 14, "reach": 0.9, "radius": 0.48, "reward": 26,
        "color": Color(0.8, 0.7, 0.15), "ai": "ranged", "pref_range": 8.5, "shoot_cd": 2.3, "proj_speed": 11.0, "proj_color": Color(0.5, 1.0, 0.2),
        "look": {"cloth": Color(0.85, 0.74, 0.12), "suit": true, "hat": "gasmask", "extras": ["tank"], "eyes": Color(0.7, 1.0, 0.2)}},
    "soldier": {"name": "Зомбі-солдат", "hp": 190, "speed": 1.9, "damage": 22, "reach": 0.9, "radius": 0.5, "reward": 34,
        "color": Color(0.45, 0.5, 0.4), "ai": "ranged", "pref_range": 10.0, "shoot_cd": 1.7, "proj_speed": 20.0, "proj_color": Color(1.0, 0.85, 0.4),
        "look": {"cloth": Color(0.22, 0.27, 0.2), "hat": "helmet", "vest": true, "weapon": "rifle"}},
    # ---------- Попелясті пустища (нові, сильніші) ----------
    "ashen": {"name": "Попелястий вартовий", "hp": 210, "speed": 2.4, "damage": 26, "reach": 1.5, "radius": 0.5, "reward": 36,
        "color": Color(0.30, 0.25, 0.23), "look": {"skin": Color(0.30, 0.25, 0.23), "cloth": Color(0.15, 0.12, 0.11), "hat": "helmet", "armor": true, "weapon": "sword", "eyes": Color(1.0, 0.45, 0.1)}},
    "cinder_archer": {"name": "Вогняний лучник", "hp": 110, "speed": 2.0, "damage": 20, "reach": 0.9, "radius": 0.45, "reward": 40,
        "color": Color(0.35, 0.22, 0.18), "ai": "ranged", "pref_range": 11.0, "shoot_cd": 1.8, "proj_speed": 17.0, "proj_color": Color(1.0, 0.5, 0.1),
        "look": {"cloth": Color(0.42, 0.12, 0.08), "hat": "hood", "weapon": "bow", "eyes": Color(1.0, 0.55, 0.1)}},
    "magma": {"name": "Магмовий громило", "hp": 420, "speed": 1.5, "damage": 40, "reach": 1.4, "radius": 0.6, "reward": 60, "size": 1.4,
        "color": Color(0.42, 0.17, 0.10), "knock_resist": 0.6, "jump": JUMP_MEDIUM,
        "look": {"fat": 0.5, "cloth": Color(0.22, 0.1, 0.07), "extras": ["spikes"], "eyes": Color(1.0, 0.55, 0.1)}},
    "revenant": {"name": "Ревенант", "hp": 300, "speed": 2.9, "damage": 34, "reach": 1.5, "radius": 0.5, "reward": 55, "size": 1.15,
        "color": Color(0.80, 0.76, 0.68), "ai": "charger", "knock_resist": 0.3,
        "look": {"bare": true, "armor": true, "hat": "horned", "weapon": "sword", "cloth": Color(0.3, 0.12, 0.1), "skin": Color(0.78, 0.72, 0.62), "eyes": Color(1.0, 0.2, 0.1)}},
    # ---------- Токсичне болото ----------
    "bogger": {"name": "Болотяник", "hp": 190, "speed": 1.8, "damage": 24, "reach": 1.0, "radius": 0.5, "reward": 32, "slow": 1.2,
        "color": Color(0.25, 0.38, 0.20), "look": {"cloth": Color(0.18, 0.30, 0.14), "extras": ["growth"], "eyes": Color(0.8, 1.0, 0.2)}},
    "leech": {"name": "П'явка-повзун", "hp": 100, "speed": 4.2, "damage": 22, "reach": 0.9, "radius": 0.42, "reward": 30, "size": 0.95,
        "color": Color(0.30, 0.38, 0.22), "look": {"crawl": true, "cloth": Color(0.20, 0.25, 0.15), "eyes": Color(0.8, 1.0, 0.2)}},
    "toxic_spitter": {"name": "Токсичний плювальник", "hp": 130, "speed": 1.9, "damage": 24, "reach": 0.9, "radius": 0.47, "reward": 42,
        "color": Color(0.35, 0.50, 0.22), "ai": "ranged", "pref_range": 9.5, "shoot_cd": 1.7, "proj_speed": 13.0, "proj_color": Color(0.4, 1.0, 0.25),
        "look": {"cloth": Color(0.30, 0.45, 0.20), "suit": true, "hat": "gasmask", "extras": ["tank"], "eyes": Color(0.6, 1.0, 0.2)}},
    "swamp_hulk": {"name": "Болотний велетень", "hp": 520, "speed": 1.3, "damage": 42, "reach": 1.3, "radius": 0.6, "reward": 75, "size": 1.55,
        "color": Color(0.30, 0.42, 0.22), "knock_resist": 0.7, "explode": {"radius": 4.5, "damage": 45},
        "look": {"fat": 1.0, "cloth": Color(0.2, 0.3, 0.15), "extras": ["pustules", "growth"], "eyes": Color(0.9, 1.0, 0.2)}},
    # ---------- Мертва тундра ----------
    "frostbite": {"name": "Обмерзлий мисливець", "hp": 200, "speed": 2.5, "damage": 24, "reach": 1.4, "radius": 0.48, "reward": 34, "slow": 2.0,
        "color": Color(0.58, 0.72, 0.82), "look": {"cloth": Color(0.30, 0.38, 0.52), "hat": "hood", "weapon": "axe", "extras": ["icicles"], "eyes": Color(0.4, 0.85, 1.0)}},
    "ice_wraith": {"name": "Крижаний привид", "hp": 120, "speed": 3.4, "damage": 26, "reach": 1.0, "radius": 0.45, "reward": 40, "ghost": true, "slow": 2.0,
        "color": Color(0.70, 0.90, 1.0), "look": {"extras": ["icicles"], "eyes": Color(0.5, 0.95, 1.0)}},
    "frost_knight": {"name": "Лицар вічної зими", "hp": 380, "speed": 1.8, "damage": 38, "reach": 1.5, "radius": 0.55, "reward": 62, "size": 1.2, "slow": 2.2,
        "color": Color(0.55, 0.68, 0.82), "knock_resist": 0.6,
        "look": {"cloth": Color(0.45, 0.55, 0.70), "hat": "horned", "armor": true, "weapon": "sword", "extras": ["icicles"], "eyes": Color(0.4, 0.9, 1.0)}},
    "wendigo": {"name": "Вендіго", "hp": 340, "speed": 3.0, "damage": 36, "reach": 1.5, "radius": 0.5, "reward": 70, "size": 1.3,
        "color": Color(0.82, 0.88, 0.92), "ai": "charger", "knock_resist": 0.4,
        "look": {"bare": true, "hat": "horned", "extras": ["icicles"], "skin": Color(0.80, 0.86, 0.90), "cloth": Color(0.78, 0.84, 0.88), "eyes": Color(0.5, 0.9, 1.0)}},
    # ---------- Пожежа ----------
    "charred": {"name": "Обвуглений зомбі", "hp": 230, "speed": 2.6, "damage": 28, "reach": 1.0, "radius": 0.5, "reward": 38,
        "color": Color(0.14, 0.10, 0.09), "look": {"skin": Color(0.12, 0.09, 0.08), "cloth": Color(0.10, 0.07, 0.06), "extras": ["spikes"], "eyes": Color(1.0, 0.55, 0.1)}},
    "firefighter": {"name": "Зомбі-пожежник", "hp": 340, "speed": 1.9, "damage": 36, "reach": 1.5, "radius": 0.52, "reward": 58, "size": 1.1,
        "color": Color(0.35, 0.30, 0.25), "knock_resist": 0.4,
        "look": {"cloth": Color(0.55, 0.40, 0.08), "hat": "helmet", "vest": true, "weapon": "axe", "eyes": Color(1.0, 0.4, 0.1)}},
    "torch_zombie": {"name": "Живий факел", "hp": 140, "speed": 4.0, "damage": 24, "reach": 0.9, "radius": 0.45, "reward": 44, "explode": {"radius": 3.5, "damage": 35},
        "color": Color(0.35, 0.18, 0.08), "look": {"skin": Color(0.30, 0.14, 0.07), "cloth": Color(0.25, 0.10, 0.04), "extras": ["pustules"], "eyes": Color(1.0, 0.8, 0.2)}},
    "flame_spitter": {"name": "Вогнеплюй", "hp": 150, "speed": 1.9, "damage": 26, "reach": 0.9, "radius": 0.47, "reward": 48,
        "color": Color(0.30, 0.15, 0.08), "ai": "ranged", "pref_range": 9.0, "shoot_cd": 1.6, "proj_speed": 15.0, "proj_color": Color(1.0, 0.45, 0.08),
        "look": {"cloth": Color(0.20, 0.10, 0.06), "suit": true, "hat": "gasmask", "extras": ["tank"], "eyes": Color(1.0, 0.6, 0.1)}},
    "cinder_brute": {"name": "Тліючий велетень", "hp": 560, "speed": 1.4, "damage": 44, "reach": 1.3, "radius": 0.6, "reward": 80, "size": 1.5,
        "color": Color(0.25, 0.12, 0.08), "knock_resist": 0.7, "jump": JUMP_MEDIUM,
        "look": {"fat": 0.8, "cloth": Color(0.14, 0.07, 0.05), "extras": ["spikes", "pustules"], "eyes": Color(1.0, 0.5, 0.1)}},
    "fire_wraith": {"name": "Вогняний привид", "hp": 150, "speed": 3.4, "damage": 30, "reach": 1.0, "radius": 0.45, "reward": 46, "ghost": true,
        "color": Color(1.0, 0.55, 0.15), "look": {"eyes": Color(1.0, 0.9, 0.3)}},
    # ---------- ЖИРОБАСИ (з'являються на великих хвилях) ----------
    "fatty": {"name": "Жиробас", "hp": 450, "speed": 1.1, "damage": 30, "reach": 1.0, "radius": 0.6, "reward": 60, "size": 1.5,
        "color": Color(0.72, 0.66, 0.5), "knock_resist": 0.8, "jump": JUMP_MEDIUM, "look": {"fat": 1.0, "cloth": Color(0.6, 0.5, 0.4)}},
    "bloater": {"name": "Роздутий (вибухає)", "hp": 220, "speed": 1.3, "damage": 12, "reach": 0.9, "radius": 0.55, "reward": 45, "size": 1.4,
        "color": Color(0.55, 0.62, 0.28), "knock_resist": 0.5, "explode": {"radius": 4.0, "damage": 40}, "jump": JUMP_MEDIUM,
        "look": {"fat": 1.0, "extras": ["pustules"], "eyes": Color(1.0, 0.9, 0.2)}},
    "colossus": {"name": "Колос", "hp": 1400, "speed": 0.9, "damage": 55, "reach": 1.0, "radius": 0.6, "reward": 200, "size": 2.2,
        "color": Color(0.65, 0.55, 0.5), "knock_resist": 0.95, "jump": JUMP_HUGE, "look": {"fat": 1.0, "hat": "horned", "cloth": Color(0.45, 0.3, 0.25)}},
    # ---------- БОС ----------
    "plague_knight": {"name": "Заражений лицар (БОС)", "hp": 2200, "speed": 1.7, "damage": 45, "reach": 1.2, "radius": 0.55, "reward": 500, "size": 2.0,
        "color": Color(0.35, 0.4, 0.35), "ai": "charger", "knock_resist": 0.9, "boss": true,
        "look": {"cloth": Color(0.3, 0.33, 0.36), "hat": "horned", "armor": true, "weapon": "sword", "eyes": Color(0.3, 1.0, 0.2), "extras": ["growth"]}},
    "fat_king": {"name": "Король жиробасів (БОС)", "hp": 700, "speed": 1.2, "damage": 28, "reach": 1.0, "radius": 0.6, "reward": 150, "size": 2.4,
        "color": Color(0.75, 0.62, 0.45), "knock_resist": 0.9, "boss": true, "jump": JUMP_HUGE,
        "look": {"fat": 1.0, "hat": "horned", "cloth": Color(0.5, 0.2, 0.2), "weapon": "club"}},
    "forest_boss": {"name": "Лісовий жах (БОС)", "hp": 1000, "speed": 1.6, "damage": 32, "reach": 1.4, "radius": 0.55, "reward": 200, "size": 2.3,
        "color": Color(0.25, 0.4, 0.2), "ai": "charger", "knock_resist": 0.9, "boss": true,
        "look": {"cloth": Color(0.2, 0.35, 0.15), "extras": ["growth"], "weapon": "club", "eyes": Color(0.9, 1.0, 0.2)}},
    "desert_boss": {"name": "Фараон-мумія (БОС)", "hp": 1200, "speed": 2.0, "damage": 34, "reach": 1.2, "radius": 0.5, "reward": 250, "size": 2.1,
        "color": Color(0.85, 0.78, 0.5), "ai": "ranged", "pref_range": 9.0, "shoot_cd": 1.6, "proj_speed": 13.0, "proj_color": Color(0.3, 0.9, 0.9),
        "knock_resist": 0.9, "boss": true,
        "look": {"extras": ["bandage"], "hat": "turban", "weapon": "staff", "eyes": Color(0.3, 0.9, 0.9)}},
    "snow_boss": {"name": "Крижаний титан (БОС)", "hp": 1500, "speed": 1.5, "damage": 40, "reach": 1.4, "radius": 0.6, "reward": 300, "size": 2.6, "slow": 2.5,
        "color": Color(0.7, 0.88, 1.0), "knock_resist": 0.9, "boss": true,
        "look": {"extras": ["icicles"], "eyes": Color(0.4, 0.8, 1.0)}},
    "graveyard_boss": {"name": "Король кістяків (БОС)", "hp": 1800, "speed": 2.4, "damage": 38, "reach": 1.5, "radius": 0.5, "reward": 350, "size": 2.2,
        "color": Color(0.88, 0.86, 0.8), "ai": "charger", "knock_resist": 0.9, "boss": true,
        "look": {"cloth": Color(0.85, 0.83, 0.77), "skin": Color(0.86, 0.82, 0.70), "bare": true, "hat": "horned", "armor": true, "weapon": "sword", "eyes": Color(0.9, 0.5, 0.1)}},
    "abomination": {"name": "Мутант-тиран (БОС)", "hp": 2000, "speed": 1.7, "damage": 48, "reach": 1.3, "radius": 0.6, "reward": 450, "size": 2.5,
        "color": Color(0.5, 0.35, 0.36), "ai": "charger", "knock_resist": 0.9, "boss": true,
        "look": {"fat": 0.6, "cloth": Color(0.25, 0.2, 0.2), "extras": ["spikes", "tumor", "tentacles"], "eyes": Color(1.0, 0.15, 0.1)}},
    "epicenter_lord": {"name": "Володар епіцентру (БОС)", "hp": 5000, "speed": 1.9, "damage": 60, "reach": 1.4, "radius": 0.55, "reward": 1000, "size": 2.8,
        "color": Color(0.3, 0.45, 0.25), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"cloth": Color(0.2, 0.28, 0.2), "hat": "horned", "armor": true, "weapon": "sword", "extras": ["growth"], "eyes": Color(0.4, 1.0, 0.2)}},
    # ---------- Боси північних локацій (за епіцентром) ----------
    "ash_titan": {"name": "Попелястий титан (БОС)", "hp": 3200, "speed": 1.8, "damage": 52, "reach": 1.4, "radius": 0.6, "reward": 700, "size": 2.7,
        "color": Color(0.30, 0.20, 0.17), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"fat": 0.5, "cloth": Color(0.16, 0.10, 0.09), "hat": "horned", "weapon": "club", "extras": ["spikes"], "eyes": Color(1.0, 0.5, 0.1)}},
    "bog_horror": {"name": "Болотний жах (БОС)", "hp": 3600, "speed": 1.8, "damage": 46, "reach": 1.4, "radius": 0.6, "reward": 800, "size": 2.6,
        "color": Color(0.28, 0.42, 0.22), "ai": "ranged", "pref_range": 10.0, "shoot_cd": 1.4, "proj_speed": 15.0, "proj_color": Color(0.45, 1.0, 0.25),
        "knock_resist": 0.95, "boss": true,
        "look": {"fat": 0.6, "cloth": Color(0.18, 0.28, 0.14), "extras": ["tentacles", "pustules"], "eyes": Color(0.8, 1.0, 0.2)}},
    "frost_lich": {"name": "Крижаний лич (БОС)", "hp": 4000, "speed": 1.9, "damage": 50, "reach": 1.4, "radius": 0.55, "reward": 900, "size": 2.5, "slow": 2.5,
        "color": Color(0.70, 0.88, 1.0), "ai": "ranged", "pref_range": 9.0, "shoot_cd": 1.3, "proj_speed": 16.0, "proj_color": Color(0.5, 0.9, 1.0),
        "knock_resist": 0.95, "boss": true,
        "look": {"bare": true, "hat": "horned", "weapon": "staff", "cloth": Color(0.30, 0.40, 0.60), "skin": Color(0.78, 0.88, 0.95), "extras": ["icicles"], "eyes": Color(0.4, 0.9, 1.0)}},
    "citadel_lord": {"name": "Володар цитаделі (БОС)", "hp": 4600, "speed": 2.0, "damage": 56, "reach": 1.4, "radius": 0.55, "reward": 1100, "size": 2.7,
        "color": Color(0.28, 0.30, 0.38), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"cloth": Color(0.16, 0.17, 0.24), "hat": "horned", "armor": true, "weapon": "sword", "extras": ["spikes", "icicles"], "eyes": Color(1.0, 0.3, 0.2)}},
    "inferno_lord": {"name": "Володар пожежі (БОС)", "hp": 4800, "speed": 2.0, "damage": 58, "reach": 1.4, "radius": 0.55, "reward": 1200, "size": 2.8,
        "color": Color(0.20, 0.10, 0.07), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"fat": 0.4, "cloth": Color(0.12, 0.06, 0.05), "hat": "horned", "weapon": "club", "extras": ["spikes", "pustules"], "eyes": Color(1.0, 0.7, 0.15)}},
    "canyon_warden": {"name": "Страж каньйонів (БОС)", "hp": 5000, "speed": 2.0, "damage": 60, "reach": 1.4, "radius": 0.6, "reward": 1300, "size": 2.8,
        "color": Color(0.36, 0.14, 0.08), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"fat": 0.6, "cloth": Color(0.22, 0.09, 0.05), "hat": "horned", "weapon": "club", "extras": ["spikes"], "eyes": Color(1.0, 0.6, 0.12)}},
    "magma_titan": {"name": "Магмовий титан (БОС)", "hp": 5600, "speed": 2.0, "damage": 64, "reach": 1.5, "radius": 0.65, "reward": 1500, "size": 3.0,
        "color": Color(0.55, 0.13, 0.04), "ai": "charger", "knock_resist": 0.97, "boss": true,
        "look": {"fat": 0.8, "cloth": Color(0.40, 0.08, 0.03), "hat": "horned", "weapon": "club", "extras": ["spikes", "pustules"], "eyes": Color(1.0, 0.9, 0.35)}},
    # ---------- Боси кислотних трясовин (за «Серцем пожежі») ----------
    "mire_warden": {"name": "Страж трясовин (БОС)", "hp": 5200, "speed": 2.0, "damage": 62, "reach": 1.5, "radius": 0.62, "reward": 1400, "size": 2.9,
        "color": Color(0.22, 0.40, 0.16), "ai": "charger", "knock_resist": 0.96, "boss": true,
        "look": {"fat": 0.7, "cloth": Color(0.12, 0.24, 0.09), "hat": "horned", "weapon": "club", "extras": ["growth", "pustules"], "eyes": Color(0.7, 1.0, 0.15)}},
    "acid_queen": {"name": "Кислотна цариця (БОС)", "hp": 5400, "speed": 1.9, "damage": 58, "reach": 1.4, "radius": 0.6, "reward": 1600, "size": 2.8,
        "color": Color(0.35, 0.55, 0.12), "ai": "ranged", "pref_range": 10.5, "shoot_cd": 1.1, "proj_speed": 17.0, "proj_color": Color(0.55, 1.0, 0.10),
        "knock_resist": 0.96, "boss": true,
        "look": {"fat": 0.5, "cloth": Color(0.20, 0.34, 0.08), "extras": ["tentacles", "pustules"], "eyes": Color(0.85, 1.0, 0.1)}},
    "bog_leviathan": {"name": "Болотний левіафан (БОС)", "hp": 5800, "speed": 2.0, "damage": 66, "reach": 1.6, "radius": 0.68, "reward": 1800, "size": 3.1,
        "color": Color(0.16, 0.30, 0.14), "ai": "charger", "knock_resist": 0.97, "boss": true,
        "look": {"fat": 0.9, "cloth": Color(0.08, 0.18, 0.07), "extras": ["tentacles", "growth", "tumor"], "eyes": Color(0.9, 1.0, 0.2)}},
    # Фінальний бос ланцюжка: наполовину вогонь, наполовину кислота. Стріляє їдким полум'ям і б'є в ближньому бою.
    "toxic_inferno": {"name": "Вогняний трясовинник (БОС)", "hp": 7000, "speed": 2.1, "damage": 72, "reach": 1.6, "radius": 0.7, "reward": 2400, "size": 3.2,
        "color": Color(0.38, 0.30, 0.08), "ai": "ranged", "pref_range": 8.0, "shoot_cd": 0.95, "proj_speed": 18.0, "proj_color": Color(0.80, 0.90, 0.10),
        "knock_resist": 0.98, "boss": true,
        "look": {"fat": 0.8, "cloth": Color(0.30, 0.14, 0.04), "hat": "horned", "weapon": "club", "extras": ["spikes", "pustules", "tentacles"], "eyes": Color(1.0, 0.85, 0.15)}},
    # ---------- Кампанії ----------
    "tide_drowned": {"name": "Утопленик", "hp": 78, "speed": 2.5, "damage": 14, "reach": 1.0, "radius": 0.46, "reward": 20,
        "campaign": "tide", "color": Color(0.20, 0.48, 0.46), "look": {"cloth": Color(0.13, 0.30, 0.29), "extras": ["netting"], "eyes": Color(0.3, 0.9, 0.8)}},
    "tide_net": {"name": "Сіткомет", "hp": 66, "speed": 2.1, "damage": 12, "reach": 0.9, "radius": 0.43, "reward": 24,
        "campaign": "tide", "campaign_ability": "net", "campaign_ability_range": 5.8, "campaign_min_range": 2.0, "campaign_windup": 0.7, "campaign_ability_cd": 6.5, "campaign_hit_range": 4.8, "net_slow": 1.1,
        "color": Color(0.25, 0.58, 0.57),
        "look": {"cloth": Color(0.16, 0.36, 0.35), "weapon": "net", "extras": ["netting"], "eyes": Color(0.4, 1.0, 0.9)}},
    "tide_anchor": {"name": "Якірник", "hp": 190, "speed": 1.45, "damage": 26, "reach": 1.2, "radius": 0.54, "reward": 34, "size": 1.08, "knock_resist": 0.35,
        "campaign": "tide", "campaign_ability": "anchor_pull", "campaign_ability_range": 5.2, "campaign_min_range": 2.0, "campaign_windup": 0.85, "campaign_ability_cd": 8.0,
        "color": Color(0.26, 0.39, 0.38), "look": {"cloth": Color(0.22, 0.29, 0.28), "weapon": "anchor", "extras": ["netting"], "eyes": Color(0.35, 0.8, 0.75)}},
    "tide_shell": {"name": "Панцирний мерць", "hp": 260, "speed": 1.2, "damage": 24, "reach": 1.1, "radius": 0.58, "reward": 38, "size": 1.12, "knock_resist": 0.68,
        "campaign": "tide", "color": Color(0.33, 0.48, 0.42), "look": {"cloth": Color(0.26, 0.36, 0.30), "armor": true, "extras": ["shell_plates"], "eyes": Color(0.4, 0.9, 0.7)}},
    "tide_warden": {"name": "Припливний вартовий (БОС)", "hp": 900, "speed": 1.2, "damage": 36, "reach": 1.5, "radius": 0.62, "reward": 800, "size": 2.2,
        "campaign": "tide", "color": Color(0.16, 0.36, 0.36), "ai": "charger", "knock_resist": 0.92, "boss": true,
        "look": {"cloth": Color(0.12, 0.24, 0.26), "hat": "horned", "armor": true, "weapon": "anchor", "extras": ["netting", "shell_plates"], "eyes": Color(0.2, 0.95, 0.85)}},
    "drowned_admiral": {"name": "Адмірал утопленців (БОС)", "hp": 2100, "speed": 1.45, "damage": 48, "reach": 1.5, "radius": 0.68, "reward": 2200, "size": 2.7,
        "campaign": "tide", "color": Color(0.12, 0.30, 0.34), "ai": "charger", "knock_resist": 0.97, "boss": true,
        "look": {"cloth": Color(0.10, 0.20, 0.24), "hat": "horned", "armor": true, "weapon": "anchor", "extras": ["netting", "shell_plates"], "eyes": Color(0.15, 1.0, 0.9)}},
    "bell_acolyte": {"name": "Дзвонар-аколіт", "hp": 62, "speed": 2.2, "damage": 12, "reach": 1.0, "radius": 0.44, "reward": 20,
        "campaign": "bells", "color": Color(0.48, 0.39, 0.28), "look": {"cloth": Color(0.30, 0.24, 0.20), "weapon": "staff", "extras": ["bronze_bells"], "eyes": Color(0.95, 0.62, 0.18)}},
    "bell_carrier": {"name": "Носій передзвону", "hp": 112, "speed": 1.7, "damage": 16, "reach": 1.0, "radius": 0.49, "reward": 28,
        "campaign": "bells", "campaign_ability": "pulse", "campaign_ability_range": 6.3, "campaign_windup": 0.85, "campaign_ability_cd": 7.0, "pulse_radius": 4.0, "pulse_slow": 0.7, "pulse_damage_mult": 0.65,
        "color": Color(0.43, 0.32, 0.20), "look": {"cloth": Color(0.28, 0.20, 0.15), "armor": true, "extras": ["bronze_bells"], "eyes": Color(1.0, 0.62, 0.15)}},
    "bell_chorister": {"name": "Хорова мерниця", "hp": 78, "speed": 1.85, "damage": 12, "reach": 0.95, "radius": 0.43, "reward": 26,
        "campaign": "bells", "campaign_aura": true, "aura_radius": 7.0, "aura_speed_mult": 1.18, "aura_duration": 1.0, "aura_interval": 0.75,
        "color": Color(0.50, 0.43, 0.31), "ai": "ranged", "pref_range": 6.0, "shoot_cd": 3.0, "proj_speed": 8.0, "proj_color": Color(0.9, 0.62, 0.2),
        "look": {"cloth": Color(0.34, 0.27, 0.20), "weapon": "staff", "extras": ["bronze_bells"], "eyes": Color(1.0, 0.68, 0.2)}},
    "bell_executioner": {"name": "Дзвоновий кат", "hp": 170, "speed": 1.8, "damage": 30, "reach": 1.35, "radius": 0.53, "reward": 38, "size": 1.08, "knock_resist": 0.3, "melee_damage_mult": 1.25,
        "campaign": "bells", "color": Color(0.37, 0.29, 0.22), "ai": "charger", "look": {"cloth": Color(0.24, 0.18, 0.16), "hat": "helmet", "armor": true, "weapon": "axe", "extras": ["bronze_bells"], "eyes": Color(1.0, 0.42, 0.12)}},
    "bell_warden": {"name": "Вартовий дзвіниці (БОС)", "hp": 950, "speed": 1.25, "damage": 38, "reach": 1.5, "radius": 0.63, "reward": 850, "size": 2.25,
        "campaign": "bells", "color": Color(0.34, 0.27, 0.18), "ai": "charger", "knock_resist": 0.93, "boss": true,
        "look": {"cloth": Color(0.22, 0.17, 0.13), "hat": "horned", "armor": true, "weapon": "club", "extras": ["bronze_bells"], "eyes": Color(1.0, 0.58, 0.12)}},
    "tongueless_bellringer": {"name": "Німий дзвонар (БОС)", "hp": 2050, "speed": 1.55, "damage": 46, "reach": 1.5, "radius": 0.67, "reward": 2200, "size": 2.65,
        "campaign": "bells", "color": Color(0.30, 0.23, 0.17), "ai": "charger", "knock_resist": 0.97, "boss": true,
        "look": {"cloth": Color(0.18, 0.13, 0.11), "hat": "horned", "armor": true, "weapon": "club", "extras": ["bronze_bells"], "eyes": Color(1.0, 0.48, 0.08)}},
    "glass_dead": {"name": "Скляний мерць", "hp": 58, "speed": 2.35, "damage": 13, "reach": 0.95, "radius": 0.44, "reward": 20,
        "campaign": "glass", "color": Color(0.31, 0.62, 0.66), "look": {"cloth": Color(0.17, 0.36, 0.40), "extras": ["glass_shards"], "eyes": Color(0.4, 0.95, 1.0)}},
    "glass_thrower": {"name": "Осколочник", "hp": 60, "speed": 1.75, "damage": 12, "reach": 0.9, "radius": 0.43, "reward": 25,
        "campaign": "glass", "color": Color(0.30, 0.56, 0.64), "ai": "ranged", "pref_range": 8.0, "shoot_cd": 2.1, "proj_speed": 13.0, "proj_color": Color(0.35, 0.9, 1.0),
        "look": {"cloth": Color(0.16, 0.32, 0.38), "weapon": "staff", "extras": ["glass_shards"], "eyes": Color(0.3, 0.95, 1.0)}},
    "glass_double": {"name": "Скляний двійник", "hp": 34, "speed": 3.8, "damage": 9, "reach": 0.85, "radius": 0.37, "reward": 0, "size": 0.86,
        "campaign": "glass", "color": Color(0.32, 0.70, 0.72), "look": {"cloth": Color(0.18, 0.42, 0.45), "extras": ["glass_double", "glass_shards"], "eyes": Color(0.35, 1.0, 1.0)}},
    "glass_guard": {"name": "Скляний захисник", "hp": 220, "speed": 1.35, "damage": 27, "reach": 1.15, "radius": 0.54, "reward": 38, "size": 1.08, "knock_resist": 0.62,
        "campaign": "glass", "color": Color(0.28, 0.48, 0.54), "look": {"cloth": Color(0.16, 0.27, 0.33), "armor": true, "weapon": "sword", "extras": ["glass_shards"], "eyes": Color(0.3, 0.9, 1.0)}},
    "glass_warden": {"name": "Зерцальний вартовий (БОС)", "hp": 920, "speed": 1.3, "damage": 38, "reach": 1.5, "radius": 0.62, "reward": 850, "size": 2.2,
        "campaign": "glass", "color": Color(0.22, 0.46, 0.53), "ai": "charger", "knock_resist": 0.94, "boss": true,
        "look": {"cloth": Color(0.12, 0.25, 0.31), "hat": "horned", "armor": true, "weapon": "sword", "extras": ["glass_shards"], "eyes": Color(0.25, 0.95, 1.0)}},
    "mirror_king": {"name": "Король дзеркал (БОС)", "hp": 2000, "speed": 1.65, "damage": 46, "reach": 1.45, "radius": 0.66, "reward": 2200, "size": 2.65,
        "campaign": "glass", "color": Color(0.18, 0.38, 0.46), "ai": "ranged", "pref_range": 7.0, "shoot_cd": 1.9, "proj_speed": 14.0, "proj_color": Color(0.35, 0.9, 1.0), "knock_resist": 0.97, "boss": true,
        "look": {"cloth": Color(0.10, 0.22, 0.29), "hat": "horned", "armor": true, "weapon": "staff", "extras": ["glass_shards"], "eyes": Color(0.2, 0.95, 1.0)}},
    "iron_worker": {"name": "Залізний робітник", "hp": 125, "speed": 1.65, "damage": 20, "reach": 1.1, "radius": 0.5, "reward": 24, "knock_resist": 0.25,
        "campaign": "iron", "color": Color(0.42, 0.35, 0.29), "look": {"cloth": Color(0.27, 0.22, 0.18), "hat": "helmet", "weapon": "club", "extras": ["iron_plates"], "eyes": Color(1.0, 0.46, 0.12)}},
    "iron_chain": {"name": "Ланцюговий кат", "hp": 190, "speed": 1.25, "damage": 31, "reach": 1.3, "radius": 0.55, "reward": 34, "knock_resist": 0.55, "melee_damage_mult": 1.3, "attack_cd": 1.2,
        "campaign": "iron", "color": Color(0.36, 0.31, 0.27), "ai": "charger", "look": {"cloth": Color(0.23, 0.19, 0.16), "hat": "helmet", "weapon": "chain", "extras": ["iron_plates"], "eyes": Color(1.0, 0.4, 0.1)}},
    "iron_riveter": {"name": "Заклепник", "hp": 82, "speed": 1.8, "damage": 15, "reach": 0.9, "radius": 0.44, "reward": 26,
        "campaign": "iron", "color": Color(0.45, 0.37, 0.29), "ai": "ranged", "pref_range": 8.0, "shoot_cd": 2.25, "proj_speed": 13.0, "proj_color": Color(0.8, 0.48, 0.22),
        "look": {"cloth": Color(0.28, 0.22, 0.17), "hat": "helmet", "weapon": "rifle", "extras": ["iron_plates"], "eyes": Color(1.0, 0.48, 0.1)}},
    "iron_gear": {"name": "Шестеренний громила", "hp": 230, "speed": 1.45, "damage": 29, "reach": 1.25, "radius": 0.56, "reward": 40, "size": 1.1, "knock_resist": 0.62, "melee_damage_mult": 1.25,
        "campaign": "iron", "color": Color(0.39, 0.32, 0.26), "ai": "charger", "look": {"cloth": Color(0.25, 0.19, 0.15), "hat": "helmet", "armor": true, "weapon": "club", "extras": ["iron_plates", "rust_gears"], "eyes": Color(1.0, 0.42, 0.08)}},
    "iron_warden": {"name": "Залізний вартовий (БОС)", "hp": 1100, "speed": 1.25, "damage": 42, "reach": 1.5, "radius": 0.64, "reward": 950, "size": 2.3,
        "campaign": "iron", "color": Color(0.34, 0.28, 0.23), "ai": "charger", "knock_resist": 0.95, "boss": true,
        "look": {"cloth": Color(0.20, 0.16, 0.13), "hat": "horned", "armor": true, "weapon": "chain", "extras": ["iron_plates", "rust_gears"], "eyes": Color(1.0, 0.42, 0.08)}},
    "stitched_machinist": {"name": "Зшитий машиніст (БОС)", "hp": 2200, "speed": 1.5, "damage": 50, "reach": 1.5, "radius": 0.68, "reward": 2400, "size": 2.7,
        "campaign": "iron", "color": Color(0.31, 0.25, 0.21), "ai": "ranged", "pref_range": 7.5, "shoot_cd": 1.7, "proj_speed": 15.0, "proj_color": Color(0.85, 0.48, 0.19), "knock_resist": 0.98, "boss": true,
        "look": {"cloth": Color(0.18, 0.14, 0.12), "hat": "horned", "armor": true, "weapon": "rifle", "extras": ["iron_plates", "rust_gears"], "eyes": Color(1.0, 0.36, 0.06)}},
}

# Запис: [id, мін. хвиля, базова вага, приріст ваги за хвилю]
const POOLS := [
    # Луки
    [["walker", 1, 6.0, -0.3], ["clothed", 1, 3.0, 0.0], ["farmer", 2, 1.5, 0.3], ["woodcutter", 4, 0.5, 0.35]],
    # Ліс
    [["walker", 1, 3.0, -0.2], ["hunter", 1, 2.0, 0.3], ["runner", 1, 3.0, 0.0], ["mossy", 3, 0.8, 0.3]],
    # Пустеля
    [["walker", 1, 3.0, -0.2], ["mummy", 1, 3.0, 0.2], ["bandit", 2, 1.5, 0.3], ["spitter", 3, 1.0, 0.3]],
    # Сніги
    [["walker", 1, 2.0, -0.2], ["frozen", 1, 3.0, 0.2], ["northman", 2, 1.5, 0.3], ["icegiant", 5, 0.5, 0.3]],
    # Цвинтар
    [["walker", 1, 2.0, -0.2], ["skeleton", 1, 4.0, 0.0], ["ghost", 2, 2.0, 0.2], ["gravedigger", 3, 1.0, 0.3]],
    # Руїни
    [["walker", 1, 2.0, -0.2], ["marauder", 1, 3.0, 0.2], ["mage", 3, 1.0, 0.3], ["knight", 4, 0.8, 0.35]],
    # Заражене місто
    [["infected", 1, 5.0, -0.2], ["crawler", 1, 2.5, 0.1], ["police", 2, 2.0, 0.3], ["hazmat", 3, 1.2, 0.3], ["soldier", 4, 0.9, 0.35]],
    # Попелясті пустища: нові зомбі + старі (walker)
    [["walker", 1, 1.5, -0.1], ["ashen", 1, 3.0, 0.1], ["cinder_archer", 3, 1.5, 0.15], ["magma", 5, 1.0, 0.2], ["revenant", 8, 0.6, 0.2]],
    # Токсичне болото
    [["walker", 1, 1.5, -0.1], ["bogger", 1, 3.0, 0.1], ["leech", 1, 2.0, 0.1], ["toxic_spitter", 3, 1.5, 0.15], ["swamp_hulk", 6, 0.8, 0.2]],
    # Мертва тундра
    [["walker", 1, 1.5, -0.1], ["frostbite", 1, 3.0, 0.1], ["ice_wraith", 2, 1.8, 0.1], ["frost_knight", 5, 1.0, 0.2], ["wendigo", 8, 0.6, 0.2]],
    # Пожежа
    [["walker", 1, 1.2, -0.1], ["charred", 1, 3.0, 0.1], ["torch_zombie", 2, 2.0, 0.1], ["flame_spitter", 3, 1.5, 0.15], ["firefighter", 4, 1.5, 0.15], ["cinder_brute", 6, 1.0, 0.2], ["fire_wraith", 8, 0.7, 0.2]],
    # Приплив
    [["tide_drowned", 1, 3.0, -0.1], ["tide_net", 1, 1.8, 0.1], ["tide_anchor", 2, 1.1, 0.15], ["tide_shell", 3, 0.8, 0.15]],
    # Дзвони
    [["bell_acolyte", 1, 3.0, -0.1], ["bell_carrier", 1, 1.8, 0.1], ["bell_chorister", 2, 1.4, 0.1], ["bell_executioner", 3, 0.9, 0.15]],
    # Скло
    [["glass_dead", 1, 3.0, -0.1], ["glass_thrower", 1, 1.6, 0.1], ["glass_double", 2, 1.8, 0.1], ["glass_guard", 3, 0.8, 0.15]],
    # Залізо
    [["iron_worker", 1, 3.0, -0.1], ["iron_chain", 1, 1.5, 0.1], ["iron_riveter", 2, 1.5, 0.1], ["iron_gear", 3, 0.8, 0.15]],
]

# Жиробаси: вага швидко росте з номером хвилі
const FAT_POOL := [
    ["fatty", 4, 0.8, 0.5],
    ["bloater", 6, 0.6, 0.4],
    ["colossus", 10, 0.3, 0.3],
]

static func pick(biome: int, wave: int) -> String:
    var ids: Array = []
    var weights: Array = []
    var total := 0.0
    for e in POOLS[biome]:
        if wave >= int(e[1]):
            var w := maxf(0.4, float(e[2]) + float(e[3]) * float(wave - int(e[1])))
            ids.append(e[0])
            weights.append(w)
            total += w
    for e in FAT_POOL:
        if wave >= int(e[1]):
            var w := float(e[2]) + float(e[3]) * float(wave - int(e[1]))
            ids.append(e[0])
            weights.append(w)
            total += w
    var r := randf() * total
    for i in range(ids.size()):
        r -= float(weights[i])
        if r <= 0.0:
            return String(ids[i])
    return "walker"
