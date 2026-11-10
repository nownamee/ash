Іконки гри (PNG 192x192, прозорий фон). Шлях у Godot: res://icons/<назва>.png

w_<id>.png        зброя, id як у weapons.gd (knife, sword, bow, ... epicenter_blade) — 22 шт.
a_<слот>_<рівень>.png  броня: слот head/body/boots, рівень 1..13 (шкіряний, залізний, сталевий, лицарський, ветеран, професійний лицар, міський вартовий, страж мегаполіса, серпанковий, саван привида, обпалений базальт, розпечена лава, рідка магма) — 39 шт.
s_<id>.png        навики, id як у skills.gd (vitality, swift, power, haste, crit, vampire, regen, greed) — 8 шт.
b_<біом>.png      медальйони біомів: meadow, forest, desert, snow, graveyard, ruins, city (індекси 0..6 у biomes.gd)
ui_*.png          інтерфейс: coin, heart, skull, lock, check, cross, star, play, flag, pause, home, retry,
                  map, pin, trophy, arrow_up, plus, trash, key, bolt, shield, boot, damage, cooldown, range,
                  knock, pierce, type_melee/aoe/proj/chain, tab_map/weapons/armor/skills/bestiary, logo
Приклад: $icon.texture = load("res://icons/w_%s.png" % weapon_id)
