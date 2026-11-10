extends RefCounted
# Біоми: назви та кольори (земля, туман, амбієнтне світло, мінікарта).

const MEADOW := 0
const FOREST := 1
const DESERT := 2
const SNOW := 3
const GRAVEYARD := 4
const RUINS := 5
const CITY := 6
const ASH := 7
const SWAMP := 8
const TUNDRA := 9
const FIRE := 10

const DATA := [
    {"name": "Зелені луки", "ground": Color(0.17, 0.27, 0.11), "fog": Color(0.50, 0.58, 0.56), "ambient": Color(0.46, 0.52, 0.60), "map": Color(0.30, 0.60, 0.22)},
    {"name": "Темний ліс", "ground": Color(0.08, 0.17, 0.08), "fog": Color(0.20, 0.30, 0.28), "ambient": Color(0.30, 0.40, 0.42), "map": Color(0.10, 0.38, 0.14)},
    {"name": "Пустеля", "ground": Color(0.60, 0.49, 0.30), "fog": Color(0.72, 0.58, 0.40), "ambient": Color(0.62, 0.55, 0.46), "map": Color(0.88, 0.76, 0.42)},
    {"name": "Засніжені землі", "ground": Color(0.78, 0.82, 0.90), "fog": Color(0.62, 0.70, 0.82), "ambient": Color(0.50, 0.58, 0.72), "map": Color(0.92, 0.95, 1.00)},
    {"name": "Цвинтар", "ground": Color(0.18, 0.17, 0.20), "fog": Color(0.22, 0.20, 0.30), "ambient": Color(0.32, 0.30, 0.44), "map": Color(0.38, 0.34, 0.46)},
    {"name": "Давні руїни", "ground": Color(0.30, 0.28, 0.25), "fog": Color(0.42, 0.38, 0.35), "ambient": Color(0.46, 0.42, 0.42), "map": Color(0.55, 0.50, 0.44)},
    {"name": "Заражене місто", "ground": Color(0.15, 0.15, 0.17), "fog": Color(0.27, 0.13, 0.11), "ambient": Color(0.36, 0.28, 0.32), "map": Color(0.58, 0.20, 0.18)},
    {"name": "Попелясті пустища", "ground": Color(0.17, 0.145, 0.135), "fog": Color(0.36, 0.18, 0.12), "ambient": Color(0.50, 0.36, 0.32), "map": Color(0.42, 0.18, 0.12)},
    {"name": "Токсичне болото", "ground": Color(0.10, 0.17, 0.11), "fog": Color(0.18, 0.30, 0.20), "ambient": Color(0.32, 0.46, 0.38), "map": Color(0.20, 0.44, 0.24)},
    {"name": "Мертва тундра", "ground": Color(0.46, 0.50, 0.58), "fog": Color(0.40, 0.46, 0.58), "ambient": Color(0.40, 0.46, 0.62), "map": Color(0.62, 0.72, 0.86)},
    {"name": "Пожежа", "ground": Color(0.12, 0.085, 0.07), "fog": Color(0.42, 0.17, 0.08), "ambient": Color(0.58, 0.38, 0.28), "map": Color(0.60, 0.20, 0.05)},
]
