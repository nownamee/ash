extends Control
# Мінікарта: кольори біомів навколо гравця, зомбі (червоні точки) і гравець (біла точка).

const Biomes = preload("res://biomes.gd")

var terrain
var player
var markers: Array = []   # вузли, які показуємо жовтим ромбом (замок у місії оборони); поза мінікартою — на краю
var cells := 28
var cell_world := 6.0
var timer := 0.0
var _cache_cx := 1 << 30      # клітинка світу, для якої порахований кеш кольорів
var _cache_cz := 1 << 30
var _cols := PackedColorArray()
var _seen := {}               # відкриті клітинки (туман війни): Vector2i -> true; карта відкривається, коли герой іде
const SEEN_R := 7             # скільки клітинок навколо героя відкривається

func _ready() -> void:
    clip_contents = true      # карта зсувається плавно, тож краї обрізаємо
var goal := Vector3.ZERO     # мітка цілі (табір лицаря або замок); ZERO — немає
var pending: Array = []      # зачистка: зомбі, яких ще не створено, [{pos: Vector2, kind}] (x, z у світі)
var volcanoes: Array = []    # вулкани «Магмового ядра» (вузли): оранжеві трикутники; далекі в межах 90 м показані стрілкою на краю карти
var hunt := false            # зачистка: лишилось мало — усіх показуємо стрілками на краю карти

func _process(delta: float) -> void:
    timer -= delta
    if timer <= 0.0:
        timer = 0.1
        queue_redraw()

# Кольори біомів беремо з сітки, прив'язаної до світу, і перераховуємо лише коли гравець
# перейшов в іншу клітинку (раніше шум рахувався для всіх 784 клітинок кожен раз).
func _refresh_cache(gx: int, gz: int) -> void:
    _cache_cx = gx
    _cache_cz = gz
    var half := cells / 2
    var n := cells + 2
    _cols.resize(n * n)
    for i in range(-1, cells + 1):
        for j in range(-1, cells + 1):
            var wx := (float(gx + i - half) + 0.5) * cell_world
            var wz := (float(gz + j - half) + 0.5) * cell_world
            var b: int = terrain.biome_at(wx, wz)
            _cols[(i + 1) * n + (j + 1)] = Biomes.DATA[b]["map"]

func _draw() -> void:
    if terrain == null or player == null:
        return
    var px: float = player.global_position.x
    var pz: float = player.global_position.z
    var cs := size.x / float(cells)
    var n := cells + 2
    var gx := floori(px / cell_world)
    var gz := floori(pz / cell_world)
    if gx != _cache_cx or gz != _cache_cz or _cols.size() != n * n:
        _refresh_cache(gx, gz)
    # відкриваємо клітинки навколо героя (круг)
    for ox in range(-SEEN_R, SEEN_R + 1):
        for oz in range(-SEEN_R, SEEN_R + 1):
            if ox * ox + oz * oz <= SEEN_R * SEEN_R:
                _seen[Vector2i(gx + ox, gz + oz)] = true
    # зсув для плавного руху мапи всередині клітинки
    var fx := px / cell_world - float(gx)
    var fz := pz / cell_world - float(gz)
    var half := cells / 2
    var fog := Color(0.03, 0.03, 0.04)
    for i in range(-1, cells + 1):
        for j in range(-1, cells + 1):
            var col: Color = _cols[(i + 1) * n + (j + 1)]
            if not _seen.has(Vector2i(gx + i - half, gz + j - half)):
                col = col.lerp(fog, 0.82)      # ще не досліджено
            draw_rect(Rect2((float(i) - fx) * cs, (float(j) - fz) * cs, cs + 0.5, cs + 0.5), col)
    for z in get_tree().get_nodes_in_group("zombies"):
        var rel: Vector3 = (z.global_position - player.global_position) / cell_world
        var p := size * 0.5 + Vector2(rel.x, rel.z) * cs
        if p.x > 0.0 and p.y > 0.0 and p.x < size.x and p.y < size.y:
            draw_circle(p, 2.0, Color(0.9, 0.1, 0.1))
    for e in pending:
        var pw: Vector2 = e["pos"]
        var prel := Vector3(pw.x - player.global_position.x, 0.0, pw.y - player.global_position.z) / cell_world
        var pp := size * 0.5 + Vector2(prel.x, prel.z) * cs
        if pp.x > 0.0 and pp.y > 0.0 and pp.x < size.x and pp.y < size.y:
            draw_circle(pp, 2.0, Color(0.9, 0.1, 0.1))
    if hunt:
        for z in get_tree().get_nodes_in_group("zombies"):
            _draw_marker(z.global_position, Color(1.0, 0.25, 0.2), 3.0, cs)
        for e in pending:
            var hw: Vector2 = e["pos"]
            _draw_marker(Vector3(hw.x, 0.0, hw.y), Color(1.0, 0.25, 0.2), 3.0, cs)
    for m in markers:
        if m == null or not is_instance_valid(m):
            continue
        var mrel: Vector3 = ((m as Node3D).global_position - player.global_position) / cell_world
        var mp := size * 0.5 + Vector2(mrel.x, mrel.z) * cs
        mp = Vector2(clampf(mp.x, 7.0, size.x - 7.0), clampf(mp.y, 7.0, size.y - 7.0))
        draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -6), mp + Vector2(6, 0), mp + Vector2(0, 6), mp + Vector2(-6, 0)]), Color(1.0, 0.82, 0.2))
        draw_polyline(PackedVector2Array([mp + Vector2(0, -6), mp + Vector2(6, 0), mp + Vector2(0, 6), mp + Vector2(-6, 0), mp + Vector2(0, -6)]), Color(0, 0, 0), 1.5)
    for vol in volcanoes:
        if not is_instance_valid(vol):
            continue
        var vrel: Vector3 = ((vol as Node3D).global_position - player.global_position) / cell_world
        var vp := size * 0.5 + Vector2(vrel.x, vrel.z) * cs
        var inside := Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0)).has_point(vp)
        if not inside:
            if Vector2(vrel.x, vrel.z).length() * cell_world > 90.0:
                continue
            vp = Vector2(clampf(vp.x, 9.0, size.x - 9.0), clampf(vp.y, 9.0, size.y - 9.0))
        var tri := PackedVector2Array([vp + Vector2(0, -8), vp + Vector2(8, 6), vp + Vector2(-8, 6)])
        draw_colored_polygon(tri, Color(1.0, 0.4, 0.08))
        draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0), 1.5)
        draw_circle(vp + Vector2(0, -1), 2.0, Color(1.0, 0.9, 0.4))
    for k in get_tree().get_nodes_in_group("knight"):
        _draw_marker(k.global_position, Color(1.0, 0.85, 0.2), 4.5, cs)
    if goal != Vector3.ZERO:
        _draw_marker(goal, Color(0.3, 1.0, 0.4), 5.0, cs)
    draw_circle(size * 0.5, 3.5, Color(1, 1, 1))
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 2.0)

# Мітка на мінікарті; якщо ціль за межами карти — стрілка-точка на краю в її напрямку.
func _draw_marker(wpos: Vector3, col: Color, r: float, cs: float) -> void:
    var rel: Vector3 = (wpos - player.global_position) / cell_world
    var p := size * 0.5 + Vector2(rel.x, rel.z) * cs
    var c := size * 0.5
    var edge := c - Vector2(8, 8)
    if absf(p.x - c.x) > edge.x or absf(p.y - c.y) > edge.y:
        var v := p - c
        var k := minf(edge.x / maxf(absf(v.x), 0.001), edge.y / maxf(absf(v.y), 0.001))
        p = c + v * k
    draw_circle(p, r + 1.5, Color(0, 0, 0, 0.9))
    draw_circle(p, r, col)
