extends Control
# Карта локацій у стилі середньовічної «карти міста».
# Земля поділена на райони (кожна локація — окремий район зі звивистими межами). Район вибирається кліком,
# підсвічується жовтою рамкою, на ньому стоїть меч. Кожен район має докладний малюнок свого біому згори.
# Карту можна наближати/віддаляти КОЛІЩАТКОМ миші (до курсора) і пересувати ПЕРЕТЯГУВАННЯМ мишею
# (ЛКМ / СКМ / ПКМ). У кутку є кнопки «+», «-» і «вся карта». Навколо карти — різьблена дерев'яна рамка
# із золотом, заклепками, завісами й табличкою-заголовком. Усе малюється кодом.
#
# Зовнішній інтерфейс (не змінився): selected, picked(id), refresh().

const Locations = preload("res://locations.gd")
const GameFonts = preload("res://game_fonts.gd")
const GameState = preload("res://game_state.gd")
const Biomes = preload("res://biomes.gd")

signal picked(id: String)
signal cleared  # клік повз райони (на рамці) — зняти вибір

const GOLD := Color(0.95, 0.78, 0.25)
const INK := Color(0.05, 0.03, 0.02)
const PARCH := Color(0.62, 0.57, 0.44)

# «Світ» карти в умовних одиницях. Локації розставлені не за старими координатами з locations.gd, а
# звивистою дорогою знизу вгору (layout_centers): спершу головний шлях змійкою, над ним — чотири
# кампанії окремими «провінціями», кожна в один ряд зі своїм гербовим прапором ліворуч.
const WORLD := Vector2(1600.0, 2440.0)
const ROW_BOTTOM := 2270.0     # висота першого (нижнього) ряду
const ROW_GAP := 265.0         # відстань між рядами
const TRUNK_X := 58.0          # «стовбур» дороги від Палаючої трясовини до всіх кампаній
const MAIN_ORDER := ["loc1", "loc2", "loc3", "loc4", "loc13", "loc5", "loc6", "loc7", "loc10", "loc8", "loc9",
    "loc11", "loc12", "loc14", "loc15", "loc16", "loc17", "loc18", "loc19", "loc20", "loc21", "loc22", "loc23",
    "loc24", "loc25", "loc26", "loc27"]
const MAIN_ROWS := [6, 6, 5, 5, 5]
const CAMPAIGNS := ["tide", "bells", "glass", "iron"]
const CAMPAIGN_TITLES := {"tide": "Чорний приплив", "bells": "Хор порожніх дзвонів", "glass": "Скляна ніч", "iron": "Залізний мор"}
const CAMPAIGN_COLORS := {"tide": Color(0.30, 0.72, 0.74), "bells": Color(0.86, 0.66, 0.32), "glass": Color(0.68, 0.52, 0.92), "iron": Color(0.86, 0.45, 0.22)}
const CAMPAIGN_X := Vector2(540.0, 1480.0)
# Обрис кордону району за головним біомом: 0 — м'які пагорби, 1 — дюни, 2 — скелі, 3 — гострі шпилі,
# 4 — зубчасті мури, 5 — хвилі прибою.
const EDGE_STYLE := [0, 0, 1, 2, 4, 4, 4, 3, 0, 2, 3, 5, 4, 3, 4]
# Пам'ятні місця, які видно на карті поверх малюнків біому.
const LANDMARKS := {"loc1": "village", "loc10": "castle", "loc12": "castle", "loc17": "castle", "loc20": "castle",
    "loc21": "volcano", "loc22": "volcano", "loc23": "volcano", "loc29": "ship", "loc31": "lighthouse",
    "loc32": "cathedral", "loc37": "cathedral", "loc42": "mirror", "loc47": "machine"}
# Поля навколо карти під рамку (чим більші — тим менша видима карта).
const MARGIN_L := 58.0
const MARGIN_R := 58.0
const MARGIN_T := 46.0
const MARGIN_B := 44.0
const ZOOM_RANGE := 4.5      # наскільки можна наблизити відносно «всієї карти»
const ZOOM_STEP := 1.18      # один «клік» колісика
const DRAG_THRESHOLD := 6.0  # скільки пікселів мишею вважається перетягуванням, а не кліком

const PAPER_SHADER := """
shader_type canvas_item;
uniform float aspect = 1.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}
void fragment() {
    vec2 p = UV * vec2(aspect, 1.0) * 5.0;
    float n = fbm(p);
    vec3 col = mix(vec3(0.44, 0.40, 0.31), vec3(0.72, 0.67, 0.53), n);
    col *= 0.82 + 0.36 * fbm(p * 3.0);
    float st = smoothstep(0.55, 0.9, fbm(p * 0.55 + vec2(3.0, 7.0)));
    col *= 1.0 - 0.28 * st;
    col *= 0.94 + 0.12 * hash(floor(UV * vec2(aspect, 1.0) * 400.0));
    COLOR = vec4(col, 1.0);
}
"""

var buttons := {}
var selected := ""
var hovered := ""
var t := 0.0
var map_rect := Rect2()     # видима частина карти (всередині рамки), у координатах цього вузла

var view: Control           # вікно, що обрізає карту
var paper: ColorRect
var terrain: Control
var markers: Control
var frame: Control
var btn_in: Button
var btn_out: Button
var btn_home: Button

var zoom := 1.0
var zoom_target := 1.0
var min_zoom := 0.5
var max_zoom := 2.0
var offset := Vector2.ZERO  # де у вікні лежить лівий верхній кут «світу»
var _anchor := Vector2.ZERO # точка вікна, до якої наближаємо
var _inited := false
var _pressing := false
var _dragging := false
var _press_btn: int = 0
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO

var _cells: Array = []      # район для кліку: повна клітинка без проміжків (координати світу)
var _shapes: Array = []     # видимий обрис району: з ущелинами між районами й власною формою кордону
var _meshes: Array = []     # заливка району з плавним переходом від світлого центру до темного краю
var _label_up: Array = []   # назва над значком (true) чи під ним — сусіди в ряду чергуються
var _banners: Array = []    # [кампанія, точка прапора]
var _grain: Texture2D
var _centers: Array = []    # позиція значка локації (координати світу)
var _doodles: Array = []
var _specks: Array = []
var _roads: Array = []
var _sb_open: StyleBoxFlat
var _sb_done: StyleBoxFlat
var _sb_lock: StyleBoxFlat
var _tex := {}

func _ready() -> void:
    custom_minimum_size = Vector2(600, 400)
    clip_contents = true
    for n in ["tab_weapons", "lock", "check", "skull"]:
        _tex[n] = load("res://icons/ui_%s.png" % n)
    _sb_open = _plate(Color(0.10, 0.06, 0.03, 0.92), Color(0.80, 0.60, 0.20))
    _sb_done = _plate(Color(0.04, 0.12, 0.05, 0.92), Color(0.40, 0.78, 0.40))
    _sb_lock = _plate(Color(0.07, 0.07, 0.08, 0.88), Color(0.32, 0.32, 0.36))

    view = Control.new()
    view.clip_contents = true
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(view)

    paper = ColorRect.new()
    paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
    paper.size = WORLD
    var sh := Shader.new()
    sh.code = PAPER_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    m.set_shader_parameter("aspect", WORLD.x / WORLD.y)
    paper.material = m
    view.add_child(paper)

    terrain = Control.new()
    terrain.size = WORLD
    terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
    terrain.draw.connect(_draw_terrain)
    terrain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    view.add_child(terrain)

    markers = Control.new()
    markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
    markers.draw.connect(_draw_markers)
    view.add_child(markers)

    frame = _layer(_draw_frame)
    _make_buttons()
    _build_geometry()

    mouse_exited.connect(func() -> void:
        if not _pressing:
            hovered = ""
            _update_cursor())
    resized.connect(_on_resized)
    _on_resized()

func _layer(cb: Callable) -> Control:
    var c := Control.new()
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(cb)
    add_child(c)
    return c

func _plate(fill: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = fill
    sb.border_color = border
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    return sb

func _make_buttons() -> void:
    btn_in = _zoom_button("+")
    btn_in.pressed.connect(func() -> void:
        Sfx.play("click")
        _zoom_by(ZOOM_STEP * ZOOM_STEP, view.size * 0.5))
    btn_out = _zoom_button("-")
    btn_out.pressed.connect(func() -> void:
        Sfx.play("click")
        _zoom_by(1.0 / (ZOOM_STEP * ZOOM_STEP), view.size * 0.5))
    btn_home = _zoom_button("")
    btn_home.icon = load("res://icons/ui_home.png")
    btn_home.expand_icon = true
    btn_home.add_theme_constant_override("icon_max_width", 20)
    btn_home.pressed.connect(func() -> void:
        Sfx.play("click")
        _zoom_by(0.0001, view.size * 0.5))

func _zoom_button(txt: String) -> Button:
    var b := Button.new()
    b.text = txt
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(30, 30)
    b.size = Vector2(30, 30)
    b.add_theme_font_size_override("font_size", 20)
    b.tooltip_text = "Коліщатко миші наближає й віддаляє мапу"
    add_child(b)
    return b

# ================= Розмір і вікно =================
func _on_resized() -> void:
    if size.x < 200.0 or size.y < 150.0:
        return
    map_rect = Rect2(Vector2(MARGIN_L, MARGIN_T), size - Vector2(MARGIN_L + MARGIN_R, MARGIN_T + MARGIN_B))
    view.position = map_rect.position
    view.size = map_rect.size
    min_zoom = maxf(view.size.x / WORLD.x, view.size.y / WORLD.y)
    max_zoom = min_zoom * ZOOM_RANGE
    if not _inited:
        _inited = true
        zoom = min_zoom
        zoom_target = min_zoom
        offset = (view.size - WORLD * zoom) * 0.5
        # на старті показуємо «фронт»: першу ще не відвойовану локацію
        offset.y = view.size.y * 0.5 - _frontier().y * zoom
    else:
        zoom = clampf(zoom, min_zoom, max_zoom)
        zoom_target = clampf(zoom_target, min_zoom, max_zoom)
    _clamp_offset()
    _update_view()
    # кнопки масштабу — у правому нижньому куті карти
    var bx := map_rect.end.x - 40.0
    var by := map_rect.end.y - 40.0
    btn_home.position = Vector2(bx, by)
    btn_out.position = Vector2(bx, by - 34.0)
    btn_in.position = Vector2(bx, by - 68.0)
    frame.queue_redraw()

func _clamp_offset() -> void:
    var ws := WORLD * zoom
    offset.x = clampf(offset.x, minf(view.size.x - ws.x, 0.0), 0.0)
    offset.y = clampf(offset.y, minf(view.size.y - ws.y, 0.0), 0.0)

func _update_view() -> void:
    paper.position = offset
    paper.scale = Vector2(zoom, zoom)
    terrain.position = offset
    terrain.scale = Vector2(zoom, zoom)

func _w2s(p: Vector2) -> Vector2:
    return p * zoom + offset

func _s2w(p: Vector2) -> Vector2:
    return (p - offset) / zoom

func _zoom_by(f: float, anchor: Vector2) -> void:
    zoom_target = clampf(zoom_target * f, min_zoom, max_zoom)
    _anchor = anchor

func _apply_zoom(nz: float) -> void:
    var wp := (_anchor - offset) / zoom
    zoom = nz
    offset = _anchor - wp * zoom
    _clamp_offset()
    _update_view()

# ================= Геометрія районів (координати світу) =================
func _clip_half(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
    var nrm := b - a
    var mid := (a + b) * 0.5
    var out := PackedVector2Array()
    var cnt := poly.size()
    for k in range(cnt):
        var p := poly[k]
        var q := poly[(k + 1) % cnt]
        var dp := (p - mid).dot(nrm)
        var dq := (q - mid).dot(nrm)
        if dp <= 0.0:
            out.append(p)
        if (dp <= 0.0) != (dq <= 0.0):
            out.append(p.lerp(q, dp / (dp - dq)))
    return out

static func _jitter(i: int) -> Vector2:
    return Vector2(sin(float(i) * 2.13 + 0.4) * 42.0, cos(float(i) * 1.37 + 1.1) * 13.0)

# Центри всіх локацій: id -> позиція у світі карти. Статична, щоб її могли перевірити тести.
static func layout_centers() -> Dictionary:
    var out := {}
    var idx := 0
    for r in range(MAIN_ROWS.size()):
        var n: int = MAIN_ROWS[r]
        var y := ROW_BOTTOM - ROW_GAP * float(r)
        var x0 := 190.0 if n == 6 else 250.0
        var x1 := 1420.0 if n == 6 else 1370.0
        for k in range(n):
            var u := float(k) / float(n - 1)
            if r % 2 == 0:
                u = 1.0 - u        # змійка: парні ряди йдуть справа наліво
            out[String(MAIN_ORDER[idx])] = Vector2(lerpf(x0, x1, u), y) + _jitter(idx)
            idx += 1
    for ci in range(CAMPAIGNS.size()):
        var y2 := campaign_row_y(ci)
        for loc in Locations.DATA:
            if String(loc.get("campaign", "")) != CAMPAIGNS[ci]:
                continue
            var st := int(loc.get("stage", 1))
            var x := lerpf(CAMPAIGN_X.x, CAMPAIGN_X.y, float(st - 1) / 4.0)
            out[String(loc["id"])] = Vector2(x, y2) + _jitter(40 + ci * 5 + st) * 0.8
    # локації, яких немає в жодному списку (на майбутнє), стають угорі праворуч
    var spare := 0
    for loc in Locations.DATA:
        if not out.has(String(loc["id"])):
            out[String(loc["id"])] = Vector2(WORLD.x - 120.0, 90.0 + 90.0 * float(spare))
            spare += 1
    return out

static func campaign_row_y(ci: int) -> float:
    return ROW_BOTTOM - ROW_GAP * float(MAIN_ROWS.size() + ci)

# Порядок проходження: головний шлях, далі кампанії етап за етапом.
static func route_order() -> Array:
    var ids: Array = MAIN_ORDER.duplicate()
    for camp in CAMPAIGNS:
        for st in range(1, 6):
            for loc in Locations.DATA:
                if String(loc.get("campaign", "")) == camp and int(loc.get("stage", 0)) == st:
                    ids.append(String(loc["id"]))
    return ids

func _frontier() -> Vector2:
    var lay := layout_centers()
    for idf in route_order():
        if not GameState.conquered.has(String(idf)) and lay.has(String(idf)):
            return lay[String(idf)]
    return Vector2(WORLD.x * 0.5, campaign_row_y(CAMPAIGNS.size() - 1))

func _chaikin(poly: PackedVector2Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    var n := poly.size()
    for i in range(n):
        var a := poly[i]
        var b := poly[(i + 1) % n]
        out.append(a.lerp(b, 0.25))
        out.append(a.lerp(b, 0.75))
    return out

# Видимий обрис району: клітинку трохи стискаємо (між районами лишаються темні ущелини),
# дрібнимо й відсуваємо точки від центру за «характером» біому.
func _shape_for(cell: PackedVector2Array, center: Vector2, style: int, seed_v: int) -> PackedVector2Array:
    var inset: Array = Geometry2D.offset_polygon(cell, -12.0, Geometry2D.JOIN_ROUND)
    var base := cell
    var best := -1.0
    for q in inset:
        var qp: PackedVector2Array = q
        if qp.size() < 3:
            continue
        var bb := Rect2(qp[0], Vector2.ZERO)
        for v in qp:
            bb = bb.expand(v)
        if bb.get_area() > best:
            best = bb.get_area()
            base = qp
    var pts := PackedVector2Array()
    var arc := PackedFloat32Array()
    var acc := 0.0
    var n := base.size()
    for i in range(n):
        var a := base[i]
        var b := base[(i + 1) % n]
        var len_ab := a.distance_to(b)
        var steps := maxi(1, int(len_ab / 7.0))
        for st in range(steps):
            pts.append(a.lerp(b, float(st) / float(steps)))
            arc.append(acc + len_ab * float(st) / float(steps))
        acc += len_ab
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var ph := rng.randf() * TAU
    var out := PackedVector2Array()
    var crag := 0.0
    for i in range(pts.size()):
        var p := pts[i]
        var sv := arc[i]
        var off := 0.0
        match style:
            0:
                off = 5.5 * sin(sv / 34.0 + ph) + 3.0 * sin(sv / 13.0 + ph * 2.0)
            1:
                off = 6.0 * sin(sv / 19.0 + ph) * (0.6 + 0.4 * sin(sv / 70.0))
            2:
                crag = lerpf(crag, rng.randf_range(-9.0, 8.0), 0.65)
                off = crag
            3:
                var tooth := fmod(sv + ph * 10.0, 26.0) / 26.0
                off = -5.0 + 15.0 * pow(1.0 - absf(tooth * 2.0 - 1.0), 2.2)
            4:
                off = 5.0 if int(floor((sv + ph * 10.0) / 17.0)) % 2 == 0 else -3.0
            5:
                off = 7.0 * sin(sv / 22.0 + ph) + 2.5 * sin(sv / 7.0)
        out.append(p + (p - center).normalized() * off)
    if style in [0, 1, 5]:
        out = _chaikin(_chaikin(out))
    return out

# Заливка району віялом трикутників: центр світлий, край темніший, а текстура дає зернистий рельєф.
func _fan_mesh(shape: PackedVector2Array, center: Vector2) -> ArrayMesh:
    var verts := PackedVector2Array()
    var cols := PackedColorArray()
    var uvs := PackedVector2Array()
    var mid := Color(1.0, 1.0, 1.0)
    var rim := Color(0.60, 0.58, 0.56)
    var n := shape.size()
    for i in range(n):
        var a := shape[i]
        var b := shape[(i + 1) % n]
        verts.append(center)
        verts.append(a)
        verts.append(b)
        uvs.append(center / 260.0)
        uvs.append(a / 260.0)
        uvs.append(b / 260.0)
        cols.append(mid)
        cols.append(rim)
        cols.append(rim)
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    arr[Mesh.ARRAY_COLOR] = cols
    arr[Mesh.ARRAY_TEX_UV] = uvs
    var m := ArrayMesh.new()
    m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return m

func _make_grain() -> Texture2D:
    var nz := FastNoiseLite.new()
    nz.seed = 77
    nz.frequency = 0.035
    nz.fractal_octaves = 4
    var img := nz.get_seamless_image(256, 256)
    img.convert(Image.FORMAT_RGBA8)
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var v := img.get_pixel(x, y).r
            var g := 0.80 + 0.28 * v
            img.set_pixel(x, y, Color(g, g, g * 0.97, 1.0))
    return ImageTexture.create_from_image(img)

func _road_curve(pts: Array) -> PackedVector2Array:
    var poly := PackedVector2Array(pts)
    for k in range(3):
        var sm := PackedVector2Array()
        sm.append(poly[0])
        for i in range(poly.size() - 1):
            sm.append(poly[i].lerp(poly[i + 1], 0.25))
            sm.append(poly[i].lerp(poly[i + 1], 0.75))
        sm.append(poly[poly.size() - 1])
        poly = sm
    return poly

func _build_geometry() -> void:
    _grain = _make_grain()
    var layout := layout_centers()
    _centers = []
    for loc in Locations.DATA:
        _centers.append(layout[String(loc["id"])])
    _cells = []
    var rect_poly := PackedVector2Array([Vector2.ZERO, Vector2(WORLD.x, 0.0), WORLD, Vector2(0.0, WORLD.y)])
    for i in range(_centers.size()):
        var poly := rect_poly
        for j in range(_centers.size()):
            if j != i:
                poly = _clip_half(poly, _centers[i], _centers[j])
        _cells.append(poly)

    _shapes = []
    _meshes = []
    for i in range(_cells.size()):
        var loc0: Dictionary = Locations.DATA[i]
        var style := int(EDGE_STYLE[clampi(int(loc0["biome"]), 0, EDGE_STYLE.size() - 1)])
        var shp := _shape_for(_cells[i], _centers[i], style, hash(String(loc0["id"])))
        _shapes.append(shp)
        _meshes.append(_fan_mesh(shp, _centers[i]))

    # назви: сусіди в одному ряду чергуються над/під значком, щоб написи не налазили один на одного
    _label_up = []
    _label_up.resize(_centers.size())
    var rows := {}
    for i in range(_centers.size()):
        var c0: Vector2 = _centers[i]
        var row_key := int(round((ROW_BOTTOM - c0.y) / ROW_GAP))
        if not rows.has(row_key):
            rows[row_key] = []
        rows[row_key].append(i)
    for row_key in rows:
        var members: Array = rows[row_key]
        members.sort_custom(func(x, y): return _centers[x].x < _centers[y].x)
        for rank in range(members.size()):
            _label_up[members[rank]] = rank % 2 == 1

    _banners = []
    for ci in range(CAMPAIGNS.size()):
        _banners.append([CAMPAIGNS[ci], Vector2(265.0, campaign_row_y(ci))])

    # малюнки й дрібні деталі в районах
    var rng := RandomNumberGenerator.new()
    _doodles = []
    _specks = []
    for i in range(_shapes.size()):
        var loc: Dictionary = Locations.DATA[i]
        rng.seed = hash(String(loc["id"]))
        var poly2: PackedVector2Array = _shapes[i]
        var items: Array = []
        var specks: Array = []
        var bb := Rect2(poly2[0], Vector2.ZERO)
        for p in poly2:
            bb = bb.expand(p)
        var want := clampi(int(bb.size.x * bb.size.y / 1500.0), 6, 34)
        var tries := 0
        while items.size() < want and tries < 400:
            tries += 1
            var pt := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
            if pt.distance_to(_centers[i]) < 58.0:
                continue
            var ok := true
            for off in [Vector2(16, 0), Vector2(-16, 0), Vector2(0, 16), Vector2(0, -16)]:
                if not Geometry2D.is_point_in_polygon(pt + off, poly2):
                    ok = false
                    break
            if not ok:
                continue
            for it in items:
                var q: Vector2 = it[1]
                if q.distance_to(pt) < 32.0:
                    ok = false
                    break
            if not ok:
                continue
            var kind := int(loc["biome"])
            if int(loc["second"]) >= 0 and rng.randf() < 0.3:
                kind = int(loc["second"])
            items.append([kind, pt, rng.randf_range(1.3, 1.85), rng.randf_range(-0.5, 0.5), int(rng.randi() % 3)])
        items.sort_custom(func(x, y): return x[1].y < y[1].y)
        _doodles.append(items)

        var want_s := clampi(int(bb.size.x * bb.size.y / 700.0), 24, 90)
        var tries2 := 0
        while specks.size() < want_s and tries2 < 500:
            tries2 += 1
            var pt2 := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
            if not Geometry2D.is_point_in_polygon(pt2, poly2):
                continue
            var kind2 := int(loc["biome"])
            if int(loc["second"]) >= 0 and rng.randf() < 0.25:
                kind2 = int(loc["second"])
            specks.append([kind2, pt2, rng.randf_range(0.9, 1.4), int(rng.randi() % 4)])
        _specks.append(specks)

    # дороги: за умовами відкриття (req). Перші етапи кампаній з'єднує «стовбур» уздовж лівого краю.
    _roads = []
    var index := {}
    for k in range(Locations.DATA.size()):
        index[String(Locations.DATA[k]["id"])] = k
    for i in range(Locations.DATA.size()):
        var loc3: Dictionary = Locations.DATA[i]
        for rid in loc3["req"]:
            if not index.has(String(rid)):
                continue
            var j: int = index[String(rid)]
            var p0: Vector2 = _centers[j]
            var p2: Vector2 = _centers[i]
            var pts: Array = []
            if loc3.has("campaign") and int(loc3.get("stage", 1)) == 1:
                pts = [p0, Vector2(TRUNK_X + 20.0, p0.y - 30.0), Vector2(TRUNK_X, p0.y - 90.0), Vector2(TRUNK_X, p2.y + 40.0), Vector2(TRUNK_X + 60.0, p2.y + 8.0), p2]
            else:
                rng.seed = hash(String(loc3["id"]) + String(rid))
                var dir := p2 - p0
                var perp := Vector2(-dir.y, dir.x).normalized()
                pts = [p0, (p0 + p2) * 0.5 + perp * rng.randf_range(-28.0, 28.0), p2]
            _roads.append([i, j, _road_curve(pts)])

func _id_at(wpos: Vector2) -> String:
    for i in range(_cells.size()):
        if _cells[i].size() >= 3 and Geometry2D.is_point_in_polygon(wpos, _cells[i]):
            return String(Locations.DATA[i]["id"])
    return ""

# ================= Ввід =================
func _in_view(vp: Vector2) -> bool:
    return Rect2(Vector2.ZERO, view.size).has_point(vp)

func _update_cursor() -> void:
    if _dragging:
        mouse_default_cursor_shape = Control.CURSOR_MOVE
    elif hovered != "":
        mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    else:
        mouse_default_cursor_shape = Control.CURSOR_ARROW

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        var vp := mb.position - view.position
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            if mb.pressed and _in_view(vp):
                _zoom_by(ZOOM_STEP, vp)
            accept_event()
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if mb.pressed and _in_view(vp):
                _zoom_by(1.0 / ZOOM_STEP, vp)
            accept_event()
        elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
            if mb.pressed:
                if not _in_view(vp):
                    if mb.button_index == MOUSE_BUTTON_LEFT:
                        cleared.emit()
                if _in_view(vp):
                    _pressing = true
                    _press_btn = mb.button_index
                    _press_pos = mb.position
                    _last_pos = mb.position
                    _dragging = mb.button_index != MOUSE_BUTTON_LEFT
                    _update_cursor()
            else:
                if _pressing and mb.button_index == _press_btn:
                    if mb.button_index == MOUSE_BUTTON_LEFT and not _dragging:
                        var id2 := _id_at(_s2w(vp))
                        if id2 != "":
                            _on_pressed(id2)
                    _pressing = false
                    _dragging = false
                    hovered = _id_at(_s2w(vp)) if _in_view(vp) else ""
                    _update_cursor()
    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        var vp2 := mm.position - view.position
        if _pressing:
            if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
                _dragging = true
                _last_pos = mm.position
                hovered = ""
                _update_cursor()
            elif _dragging:
                offset += mm.position - _last_pos
                _last_pos = mm.position
                _clamp_offset()
                _update_view()
        else:
            var id := ""
            if _in_view(vp2):
                id = _id_at(_s2w(vp2))
            if id != hovered:
                hovered = id
                if id != "":
                    Sfx.play("hover")
                _update_cursor()

func _on_pressed(id: String) -> void:
    if GameState.is_unlocked(Locations.by_id(id)):
        Sfx.play("click")
    else:
        Sfx.play("deny")
    selected = id
    picked.emit(id)

func refresh() -> void:
    terrain.queue_redraw()

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    t += delta
    if not is_equal_approx(zoom, zoom_target):
        var nz := lerpf(zoom, zoom_target, clampf(delta * 14.0, 0.0, 1.0))
        if absf(nz - zoom_target) < zoom_target * 0.002:
            nz = zoom_target
        _apply_zoom(nz)
    markers.queue_redraw()

# ================= Допоміжне малювання =================
func _ca(col: Color, a: float) -> Color:
    return Color(col.r, col.g, col.b, col.a * a)

func _ell(c: Control, p: Vector2, rx: float, ry: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(14):
        var ang := TAU * float(i) / 14.0
        pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
    c.draw_colored_polygon(pts, col)

func _rp(p: Vector2, ang: float, pts: Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    for q in pts:
        var qv: Vector2 = q
        out.append(p + qv.rotated(ang))
    return out

func _rect_poly(p: Vector2, ang: float, x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
    return _rp(p, ang, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

func _tpoly(poly: PackedVector2Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    for p in poly:
        out.append(_w2s(p))
    return out

# ================= Малюнки районів (вигляд згори) =================
func _house(c: Control, p: Vector2, w: float, h: float, ang: float, roof: Color, a: float) -> void:
    _ell(c, p + Vector2(w * 0.35, h * 0.95), w * 1.15, h * 0.7, Color(0, 0, 0, 0.30 * a))
    c.draw_colored_polygon(_rect_poly(p, ang, -w, -h, w, h), _ca(Color(0.74, 0.62, 0.44), a))
    var ov := 1.2
    c.draw_colored_polygon(_rect_poly(p, ang, -w - ov, -h - ov, 0.0, h + ov), _ca(roof.lightened(0.18), a))
    c.draw_colored_polygon(_rect_poly(p, ang, 0.0, -h - ov, w + ov, h + ov), _ca(roof.darkened(0.22), a))
    c.draw_line(p + Vector2(-w - ov, 0.0).rotated(ang), p + Vector2(w + ov, 0.0).rotated(ang), _ca(Color(1.0, 0.85, 0.65), 0.55 * a), 1.2)
    for k in range(1, 4):
        var yy := -h + (2.0 * h) * float(k) / 4.0
        c.draw_line(p + Vector2(-w - ov, yy).rotated(ang), p + Vector2(w + ov, yy).rotated(ang), _ca(Color(0, 0, 0), 0.18 * a), 0.8)
    var closed := _rect_poly(p, ang, -w - ov, -h - ov, w + ov, h + ov)
    closed.append(closed[0])
    c.draw_polyline(closed, _ca(INK, 0.85 * a), 1.2)
    c.draw_colored_polygon(_rect_poly(p, ang, w * 0.45, -h * 0.55, w * 0.45 + 2.2, -h * 0.55 + 2.2), _ca(Color(0.30, 0.25, 0.22), a))

func _tree(c: Control, p: Vector2, r: float, a: float, style: int) -> void:
    var dark := Color(0.12, 0.34, 0.12)
    var light := Color(0.36, 0.62, 0.22)
    if style == 1:
        dark = Color(0.05, 0.17, 0.08)
        light = Color(0.16, 0.36, 0.14)
    _ell(c, p + Vector2(r * 0.55, r * 0.95), r * 1.2, r * 0.55, Color(0, 0, 0, 0.30 * a))
    c.draw_line(p + Vector2(0.0, r * 0.1), p + Vector2(0.0, r * 1.05), _ca(Color(0.25, 0.14, 0.07), a), maxf(1.2, r * 0.3))
    c.draw_circle(p + Vector2(-r * 0.5, r * 0.2), r * 0.7, _ca(dark, a))
    c.draw_circle(p + Vector2(r * 0.5, r * 0.15), r * 0.7, _ca(dark, a))
    c.draw_circle(p + Vector2(0.0, -r * 0.35), r * 0.82, _ca(dark.lightened(0.08), a))
    c.draw_circle(p + Vector2(-r * 0.2, -r * 0.55), r * 0.5, _ca(light, a * 0.9))
    c.draw_circle(p + Vector2(-r * 0.62, -r * 0.05), r * 0.28, _ca(light, a * 0.8))
    c.draw_circle(p + Vector2(r * 0.15, -r * 0.8), r * 0.18, _ca(light.lightened(0.25), a * 0.7))

func _pine(c: Control, p: Vector2, r: float, a: float, snow: bool) -> void:
    _ell(c, p + Vector2(r * 0.6, r * 1.05), r * 1.1, r * 0.45, Color(0, 0, 0, 0.28 * a))
    c.draw_line(p + Vector2(0.0, r * 0.6), p + Vector2(0.0, r * 1.1), _ca(Color(0.25, 0.14, 0.07), a), maxf(1.2, r * 0.28))
    var g := Color(0.06, 0.24, 0.14)
    if snow:
        g = Color(0.10, 0.28, 0.24)
    for i in range(3):
        var top := -r * 1.5 + r * 0.8 * float(i)
        var w := r * (0.6 + 0.32 * float(i))
        var bot := top + r * 1.1
        c.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, top), p + Vector2(-w, bot), p + Vector2(w, bot)]), _ca(g.lightened(0.05 * float(i)), a))
        c.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, top), p + Vector2(-w, bot), p + Vector2(-w * 0.15, bot)]), _ca(g.lightened(0.25), a * 0.45))
        if snow:
            var my := top + (bot - top) * 0.62
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, top), p + Vector2(-w * 0.62, my), p + Vector2(w * 0.62, my)]), _ca(Color(0.92, 0.96, 1.0), a * 0.95))

func _rock(c: Control, p: Vector2, r: float, a: float, col: Color) -> void:
    _ell(c, p + Vector2(r * 0.3, r * 0.6), r * 1.1, r * 0.5, Color(0, 0, 0, 0.28 * a))
    var pts := PackedVector2Array([p + Vector2(-r, r * 0.4), p + Vector2(-r * 0.7, -r * 0.5), p + Vector2(-r * 0.1, -r * 0.9), p + Vector2(r * 0.7, -r * 0.5), p + Vector2(r, r * 0.3), p + Vector2(r * 0.2, r * 0.7)])
    c.draw_colored_polygon(pts, _ca(col, a))
    c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.7, -r * 0.5), p + Vector2(-r * 0.1, -r * 0.9), p + Vector2(r * 0.7, -r * 0.5), p + Vector2(0.0, -r * 0.1)]), _ca(col.lightened(0.3), a * 0.7))

func _fire(c: Control, p: Vector2, s: float, a: float) -> void:
    c.draw_circle(p, 9.0 * s, Color(1.0, 0.45, 0.1, 0.18 * a))
    c.draw_circle(p, 5.5 * s, Color(1.0, 0.55, 0.1, 0.35 * a))
    c.draw_circle(p, 3.0 * s, Color(1.0, 0.80, 0.25, 0.75 * a))
    c.draw_circle(p + Vector2(0.0, 0.5 * s), 1.4 * s, Color(1.0, 0.97, 0.7, 0.9 * a))

func _village(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    if v == 0:
        _house(c, p + Vector2(-8.0, 0.0) * s, 8.0 * s, 5.0 * s, ang, Color(0.62, 0.22, 0.13), a)
        _house(c, p + Vector2(9.0, 7.0) * s, 5.5 * s, 4.0 * s, ang + 0.35, Color(0.52, 0.19, 0.12), a)
        _tree(c, p + Vector2(4.0, -10.0) * s, 4.2 * s, a, 0)
    elif v == 1:
        # город: смужки поля і хата
        var rows := 5
        for k in range(rows):
            var y0 := -8.0 + 3.2 * float(k)
            var col := Color(0.46, 0.55, 0.20)
            if k % 2 == 1:
                col = Color(0.60, 0.50, 0.22)
            c.draw_colored_polygon(_rect_poly(p + Vector2(4.0, 5.0) * s, ang, -11.0 * s, y0 * s, 11.0 * s, (y0 + 3.0) * s), _ca(col, a))
        _house(c, p + Vector2(-9.0, -8.0) * s, 5.5 * s, 4.0 * s, ang, Color(0.58, 0.24, 0.14), a)
    else:
        # колодязь, паркан і дерева
        _tree(c, p + Vector2(-8.0, -3.0) * s, 4.4 * s, a, 0)
        _tree(c, p + Vector2(9.0, 4.0) * s, 3.8 * s, a, 0)
        _ell(c, p + Vector2(1.0, 3.0) * s, 4.5 * s, 2.2 * s, Color(0, 0, 0, 0.3 * a))
        c.draw_circle(p, 3.6 * s, _ca(Color(0.45, 0.42, 0.40), a))
        c.draw_circle(p, 2.3 * s, _ca(Color(0.05, 0.12, 0.2), a))
        for k in range(5):
            c.draw_line(p + Vector2(-9.0 + 3.0 * float(k), 9.0) * s, p + Vector2(-9.0 + 3.0 * float(k), 12.0) * s, _ca(Color(0.35, 0.22, 0.10), a), 1.3)
        c.draw_line(p + Vector2(-9.0, 10.0) * s, p + Vector2(3.0, 10.0) * s, _ca(Color(0.45, 0.30, 0.14), a), 1.2)

func _forest(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    var offs := [Vector2(-3.0, -8.0), Vector2(-10.0, -4.0), Vector2(6.0, -2.0), Vector2(-7.0, 3.0), Vector2(5.0, 8.0)]
    var n := 3 + v
    for i in range(n):
        var off: Vector2 = offs[i]
        var r := (3.8 + float((i * 7 + v) % 3) * 0.8) * s
        if (i + v) % 3 == 2:
            _pine(c, p + off * s * 0.9, r * 0.85, a, false)
        else:
            _tree(c, p + off * s * 0.9, r, a, 1)
    if v == 1:
        c.draw_circle(p + Vector2(0.0, 11.0) * s, 1.8 * s, _ca(Color(0.75, 0.15, 0.12), a))
        c.draw_line(p + Vector2(0.0, 11.0) * s, p + Vector2(0.0, 13.5) * s, _ca(Color(0.85, 0.8, 0.7), a), 1.0)

func _dune(c: Control, p: Vector2, s: float, a: float) -> void:
    var pts := PackedVector2Array()
    var n := 10
    for i in range(n + 1):
        var u := PI + PI * float(i) / float(n)
        pts.append(p + Vector2(cos(u) * 12.0 * s, sin(u) * 6.0 * s))
    var ridge := pts.duplicate()
    for i in range(n, -1, -1):
        var u2 := PI + PI * float(i) / float(n)
        pts.append(p + Vector2(cos(u2) * 12.0 * s, sin(u2) * 2.2 * s + 1.0 * s))
    c.draw_colored_polygon(pts, _ca(Color(0.62, 0.45, 0.20), a * 0.75))
    c.draw_polyline(ridge, _ca(Color(0.98, 0.88, 0.55), a), 1.4)

func _cactus(c: Control, p: Vector2, s: float, a: float) -> void:
    var g := _ca(Color(0.20, 0.45, 0.20), a)
    _ell(c, p + Vector2(2.0, 5.5) * s, 4.0 * s, 1.6 * s, Color(0, 0, 0, 0.28 * a))
    c.draw_line(p + Vector2(0.0, 5.0) * s, p + Vector2(0.0, -6.0) * s, g, 2.4 * s)
    c.draw_line(p + Vector2(0.0, 1.0) * s, p + Vector2(-4.0, 1.0) * s, g, 1.7 * s)
    c.draw_line(p + Vector2(-4.0, 1.0) * s, p + Vector2(-4.0, -3.0) * s, g, 1.7 * s)
    c.draw_line(p + Vector2(0.0, -1.0) * s, p + Vector2(4.0, -1.0) * s, g, 1.7 * s)
    c.draw_line(p + Vector2(4.0, -1.0) * s, p + Vector2(4.0, -4.5) * s, g, 1.7 * s)
    c.draw_line(p + Vector2(-0.6, 5.0) * s, p + Vector2(-0.6, -6.0) * s, _ca(Color(0.45, 0.72, 0.40), a * 0.6), 0.7 * s)

func _dunes(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    _dune(c, p + Vector2(-2.0, 3.0) * s, s, a)
    if v == 0:
        _dune(c, p + Vector2(7.0, -6.0) * s, s * 0.75, a)
        _rock(c, p + Vector2(-9.0, 7.0) * s, 2.4 * s, a, Color(0.50, 0.38, 0.24))
    elif v == 1:
        _cactus(c, p + Vector2(7.0, -4.0) * s, s * 0.9, a)
        _dune(c, p + Vector2(-8.0, -7.0) * s, s * 0.7, a)
    else:
        _dune(c, p + Vector2(8.0, 8.0) * s, s * 0.8, a)
        _rock(c, p + Vector2(8.0, -6.0) * s, 2.8 * s, a, Color(0.52, 0.40, 0.26))
        _rock(c, p + Vector2(11.0, -3.0) * s, 1.6 * s, a, Color(0.46, 0.35, 0.22))

func _snowland(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    # замет
    _ell(c, p + Vector2(0.0, 6.0) * s, 11.0 * s, 4.0 * s, Color(0.45, 0.55, 0.72, 0.45 * a))
    _ell(c, p + Vector2(-1.0, 5.0) * s, 10.0 * s, 3.4 * s, Color(0.96, 0.98, 1.0, 0.9 * a))
    if v == 2:
        _pine(c, p + Vector2(-5.0, -2.0) * s, 3.4 * s, a, true)
        _pine(c, p + Vector2(6.0, 0.0) * s, 3.0 * s, a, true)
        _pine(c, p + Vector2(1.0, -8.0) * s, 2.6 * s, a, true)
    elif v == 1:
        _pine(c, p + Vector2(-2.0, -2.0) * s, 4.0 * s, a, true)
        _rock(c, p + Vector2(8.0, 3.0) * s, 2.6 * s, a, Color(0.55, 0.60, 0.70))
    else:
        _pine(c, p + Vector2(-6.0, 0.0) * s, 3.6 * s, a, true)
        _pine(c, p + Vector2(5.0, -4.0) * s, 3.6 * s, a, true)
        c.draw_line(p + Vector2(-2.0, 8.0) * s, p + Vector2(4.0, 10.0) * s, _ca(Color(0.55, 0.72, 0.90), a * 0.8), 1.0)

func _tomb(c: Control, p: Vector2, s: float, a: float, cross: bool) -> void:
    var stone := Color(0.55, 0.54, 0.60)
    _ell(c, p + Vector2(1.5, 5.0) * s, 4.0 * s, 1.6 * s, Color(0, 0, 0, 0.35 * a))
    if cross:
        c.draw_line(p + Vector2(0.0, 5.0) * s, p + Vector2(0.0, -6.0) * s, _ca(INK, a), 3.2 * s)
        c.draw_line(p + Vector2(-3.5, -3.0) * s, p + Vector2(3.5, -3.0) * s, _ca(INK, a), 3.2 * s)
        c.draw_line(p + Vector2(0.0, 5.0) * s, p + Vector2(0.0, -6.0) * s, _ca(stone.lightened(0.2), a), 2.0 * s)
        c.draw_line(p + Vector2(-3.5, -3.0) * s, p + Vector2(3.5, -3.0) * s, _ca(stone.lightened(0.2), a), 2.0 * s)
    else:
        c.draw_colored_polygon(_rect_poly(p, 0.0, -2.8 * s, -3.0 * s, 2.8 * s, 5.0 * s), _ca(stone, a))
        c.draw_circle(p + Vector2(0.0, -3.0) * s, 2.8 * s, _ca(stone, a))
        c.draw_line(p + Vector2(-2.8, 5.0) * s, p + Vector2(-2.8, -3.0) * s, _ca(stone.lightened(0.3), a), 1.0)
        c.draw_line(p + Vector2(0.0, -4.0) * s, p + Vector2(0.0, 0.5) * s, _ca(INK, a * 0.7), 0.9)
        c.draw_line(p + Vector2(-1.4, -2.0) * s, p + Vector2(1.4, -2.0) * s, _ca(INK, a * 0.7), 0.9)

func _dead_tree(c: Control, p: Vector2, s: float, a: float) -> void:
    var col := _ca(Color(0.17, 0.13, 0.12), a)
    _ell(c, p + Vector2(2.0, 6.0) * s, 4.0 * s, 1.5 * s, Color(0, 0, 0, 0.3 * a))
    c.draw_line(p + Vector2(0.0, 6.0) * s, p + Vector2(0.0, -4.0) * s, col, 2.0 * s)
    c.draw_line(p + Vector2(0.0, -1.0) * s, p + Vector2(-5.0, -7.0) * s, col, 1.3 * s)
    c.draw_line(p + Vector2(0.0, -3.0) * s, p + Vector2(5.0, -8.0) * s, col, 1.3 * s)
    c.draw_line(p + Vector2(-3.0, -5.0) * s, p + Vector2(-6.5, -5.0) * s, col, 1.0 * s)
    c.draw_line(p + Vector2(3.0, -6.0) * s, p + Vector2(6.0, -4.5) * s, col, 1.0 * s)

func _graves(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    c.draw_circle(p, 15.0 * s, Color(0.55, 0.45, 0.75, 0.10 * a))
    if v == 0:
        _tomb(c, p + Vector2(-7.0, 2.0) * s, s, a, false)
        _tomb(c, p + Vector2(0.0, -3.0) * s, s, a, true)
        _tomb(c, p + Vector2(7.0, 3.0) * s, s, a, false)
    elif v == 1:
        _dead_tree(c, p + Vector2(-6.0, 0.0) * s, s, a)
        _tomb(c, p + Vector2(6.0, 3.0) * s, s, a, true)
        _tomb(c, p + Vector2(8.0, -5.0) * s, s * 0.9, a, false)
    else:
        # склеп
        _ell(c, p + Vector2(2.0, 8.0) * s, 10.0 * s, 3.0 * s, Color(0, 0, 0, 0.35 * a))
        c.draw_colored_polygon(_rect_poly(p, 0.0, -8.0 * s, -5.0 * s, 8.0 * s, 7.0 * s), _ca(Color(0.34, 0.33, 0.38), a))
        c.draw_colored_polygon(PackedVector2Array([p + Vector2(-9.0, -5.0) * s, p + Vector2(0.0, -11.0) * s, p + Vector2(9.0, -5.0) * s]), _ca(Color(0.25, 0.24, 0.30), a))
        c.draw_colored_polygon(_rect_poly(p, 0.0, -2.5 * s, 0.0, 2.5 * s, 7.0 * s), _ca(INK, a))
        c.draw_circle(p + Vector2(0.0, 0.0) * s, 2.5 * s, _ca(INK, a))
        _tomb(c, p + Vector2(-11.0, 6.0) * s, s * 0.8, a, true)

func _wall(c: Control, pts: PackedVector2Array, s: float, a: float) -> void:
    c.draw_polyline(pts, _ca(INK, a), 4.8 * s)
    c.draw_polyline(pts, _ca(Color(0.50, 0.46, 0.40), a), 3.4 * s)
    c.draw_polyline(pts, _ca(Color(0.72, 0.68, 0.60), a * 0.6), 1.0 * s)

func _pillar(c: Control, p: Vector2, r: float, a: float) -> void:
    _ell(c, p + Vector2(r * 0.5, r * 0.7), r * 1.2, r * 0.6, Color(0, 0, 0, 0.3 * a))
    c.draw_circle(p, r, _ca(INK, a))
    c.draw_circle(p, r * 0.82, _ca(Color(0.55, 0.51, 0.45), a))
    c.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.45, _ca(Color(0.74, 0.70, 0.62), a * 0.7))
    c.draw_line(p + Vector2(-r * 0.3, r * 0.1), p + Vector2(r * 0.5, r * 0.6), _ca(INK, a * 0.7), 1.0)

func _ruins(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    if v == 0:
        _wall(c, _rp(p, ang, [Vector2(-10, 4) * s, Vector2(-10, -5) * s, Vector2(-4, -6) * s, Vector2(-3, -2) * s, Vector2(3, -7) * s, Vector2(10, -3) * s]), s, a)
        _rock(c, p + Vector2(4.0, 6.0) * s, 2.2 * s, a, Color(0.46, 0.42, 0.37))
        _rock(c, p + Vector2(-2.0, 8.0) * s, 1.5 * s, a, Color(0.42, 0.38, 0.34))
    elif v == 1:
        _pillar(c, p + Vector2(-6.0, 0.0) * s, 3.6 * s, a)
        _pillar(c, p + Vector2(6.0, -2.0) * s, 3.0 * s, a)
        _wall(c, _rp(p, ang, [Vector2(-6, 8) * s, Vector2(2, 9) * s, Vector2(9, 7) * s]), s * 0.8, a)
    else:
        # зруйнована арка
        _wall(c, _rp(p, ang, [Vector2(-9, 6) * s, Vector2(-9, -3) * s, Vector2(-5, -8) * s]), s, a)
        _wall(c, _rp(p, ang, [Vector2(9, 6) * s, Vector2(9, -1) * s]), s, a)
        _rock(c, p + Vector2(0.0, 7.0) * s, 2.8 * s, a, Color(0.46, 0.42, 0.37))
        _rock(c, p + Vector2(4.0, 5.0) * s, 1.6 * s, a, Color(0.40, 0.37, 0.33))

func _ashland(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    # випалена земля: тріщини з жаром, почорнілі дерева, скелі, вогнище
    c.draw_circle(p, 14.0 * s, Color(1.0, 0.35, 0.1, 0.07 * a))
    var crack := _ca(Color(0.04, 0.02, 0.02), a)
    var glow := _ca(Color(1.0, 0.45, 0.1), 0.85 * a)
    if v == 0:
        var pts := _rp(p, ang, [Vector2(-9, 3) * s, Vector2(-3, 0) * s, Vector2(1, 4) * s, Vector2(6, 1) * s, Vector2(10, 5) * s])
        c.draw_polyline(pts, crack, 3.0 * s)
        c.draw_polyline(pts, glow, 1.2 * s)
        _rock(c, p + Vector2(-5.0, -6.0) * s, 2.4 * s, a, Color(0.22, 0.17, 0.15))
        _rock(c, p + Vector2(7.0, -5.0) * s, 1.6 * s, a, Color(0.19, 0.15, 0.13))
    elif v == 1:
        _dead_tree(c, p + Vector2(-6.0, 0.0) * s, s, a)
        _dead_tree(c, p + Vector2(6.0, 2.0) * s, s * 0.85, a)
        _fire(c, p + Vector2(0.0, 7.0) * s, s * 0.8, a)
    else:
        _wall(c, _rp(p, ang, [Vector2(-9, 5) * s, Vector2(-9, -4) * s, Vector2(-3, -6) * s]), s, a)
        _rock(c, p + Vector2(5.0, 5.0) * s, 2.6 * s, a, Color(0.22, 0.17, 0.15))
        _fire(c, p + Vector2(6.0, -4.0) * s, s * 0.9, a)

func _swamp(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    # болото: темна вода, кочки, очерет, болотні вогники
    _ell(c, p + Vector2(0.0, 2.0) * s, 12.0 * s, 6.0 * s, Color(0.04, 0.12, 0.08, 0.8 * a))
    _ell(c, p + Vector2(-1.0, 1.0) * s, 10.0 * s, 4.6 * s, Color(0.10, 0.26, 0.16, 0.7 * a))
    var reed := _ca(Color(0.22, 0.36, 0.14), a)
    if v == 0:
        _dead_tree(c, p + Vector2(-7.0, -2.0) * s, s * 0.9, a)
        for k in range(3):
            c.draw_line(p + Vector2(5.0 + float(k) * 1.6, 4.0) * s, p + Vector2(5.0 + float(k) * 1.6, -3.0 - float(k)) * s, reed, 1.0)
    elif v == 1:
        _tree(c, p + Vector2(-4.0, -3.0) * s, 4.0 * s, a, 1)
        _rock(c, p + Vector2(7.0, 4.0) * s, 2.0 * s, a, Color(0.20, 0.26, 0.18))
    else:
        for k in range(4):
            c.draw_line(p + Vector2(-6.0 + float(k) * 3.4, 4.0) * s, p + Vector2(-6.0 + float(k) * 3.4, -4.0 - float(k % 2) * 2.0) * s, reed, 1.0)
    # болотні вогники
    c.draw_circle(p + Vector2(3.0, -6.0) * s, 3.6 * s, Color(0.55, 1.0, 0.30, 0.18 * a))
    c.draw_circle(p + Vector2(3.0, -6.0) * s, 1.3 * s, Color(0.80, 1.0, 0.55, 0.9 * a))

func _tundra(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    # заметіль, пошарпані ялини й крижані шпилі
    _ell(c, p + Vector2(0.0, 6.0) * s, 12.0 * s, 4.0 * s, Color(0.40, 0.50, 0.70, 0.45 * a))
    _ell(c, p + Vector2(-1.0, 5.0) * s, 10.5 * s, 3.4 * s, Color(0.93, 0.97, 1.0, 0.9 * a))
    if v == 0:
        _pine(c, p + Vector2(-5.0, -1.0) * s, 3.2 * s, a, true)
        _dead_tree(c, p + Vector2(6.0, 0.0) * s, s * 0.9, a)
    elif v == 1:
        _pine(c, p + Vector2(-1.0, -2.0) * s, 3.8 * s, a, true)
        for k in range(3):
            var bx := p + Vector2(6.0 + float(k) * 2.2, 5.0) * s
            c.draw_colored_polygon(PackedVector2Array([bx + Vector2(0.0, -6.0 - float(k)) * s, bx + Vector2(-1.6, 0.0) * s, bx + Vector2(1.6, 0.0) * s]), _ca(Color(0.62, 0.88, 1.0), 0.9 * a))
    else:
        for k in range(3):
            var bx2 := p + Vector2(-6.0 + float(k) * 5.0, 3.0) * s
            c.draw_colored_polygon(PackedVector2Array([bx2 + Vector2(0.0, -8.0 + float(k % 2) * 2.0) * s, bx2 + Vector2(-2.2, 2.0) * s, bx2 + Vector2(2.2, 2.0) * s]), _ca(Color(0.60, 0.86, 1.0), 0.92 * a))
            c.draw_line(bx2 + Vector2(0.0, -8.0 + float(k % 2) * 2.0) * s, bx2 + Vector2(0.0, 2.0) * s, _ca(Color(0.95, 1.0, 1.0), 0.8 * a), 0.8)

func _burning(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    # пожежа: обвуглені руїни, язики полум'я, жарини
    c.draw_circle(p, 15.0 * s, Color(1.0, 0.30, 0.05, 0.10 * a))
    if v == 0:
        _wall(c, _rp(p, ang, [Vector2(-9, 5) * s, Vector2(-9, -4) * s, Vector2(-2, -6) * s, Vector2(3, -2) * s]), s, a)
        _fire(c, p + Vector2(3.0, 3.0) * s, s * 1.2, a)
        _fire(c, p + Vector2(-5.0, 0.0) * s, s * 0.8, a)
    elif v == 1:
        _dead_tree(c, p + Vector2(-5.0, 0.0) * s, s, a)
        _fire(c, p + Vector2(-5.0, -6.0) * s, s * 0.9, a)
        _fire(c, p + Vector2(6.0, 4.0) * s, s * 1.1, a)
        _rock(c, p + Vector2(8.0, -3.0) * s, 2.0 * s, a, Color(0.20, 0.14, 0.12))
    else:
        _ell(c, p + Vector2(0.0, 2.0) * s, 10.0 * s, 5.0 * s, Color(0.08, 0.04, 0.03, 0.75 * a))
        _fire(c, p + Vector2(-4.0, 1.0) * s, s * 1.0, a)
        _fire(c, p + Vector2(4.0, 3.0) * s, s * 1.2, a)
        _fire(c, p + Vector2(0.0, -4.0) * s, s * 0.8, a)

func _cityblock(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    var roofs := [Color(0.40, 0.18, 0.16), Color(0.32, 0.30, 0.32), Color(0.46, 0.26, 0.18), Color(0.28, 0.26, 0.30)]
    # дорога
    c.draw_colored_polygon(_rect_poly(p, ang, -13.0 * s, -1.8 * s, 13.0 * s, 1.8 * s), _ca(Color(0.13, 0.12, 0.12), a * 0.9))
    for k in range(-3, 4):
        c.draw_line(p + Vector2(float(k) * 3.6 * s, 0.0).rotated(ang), p + Vector2(float(k) * 3.6 * s + 1.6 * s, 0.0).rotated(ang), _ca(Color(0.75, 0.65, 0.25), a * 0.6), 0.8)
    var offs := [Vector2(-7.0, -6.5), Vector2(7.0, -6.5), Vector2(-7.0, 6.5), Vector2(7.0, 6.5)]
    for k in range(4):
        var off: Vector2 = offs[k]
        var rc: Color = roofs[(k + v) % 4]
        var bp := p + (off * s).rotated(ang)
        _ell(c, bp + Vector2(1.5, 3.5) * s, 5.0 * s, 3.6 * s, Color(0, 0, 0, 0.30 * a))
        c.draw_colored_polygon(_rect_poly(bp, ang, -4.6 * s, -3.4 * s, 4.6 * s, 3.4 * s), _ca(rc, a))
        c.draw_colored_polygon(_rect_poly(bp, ang, -4.6 * s, -3.4 * s, 4.6 * s, -0.6 * s), _ca(rc.lightened(0.15), a * 0.8))
        var cl := _rect_poly(bp, ang, -4.6 * s, -3.4 * s, 4.6 * s, 3.4 * s)
        cl.append(cl[0])
        c.draw_polyline(cl, _ca(INK, a * 0.85), 1.0)
    if v == 1:
        _fire(c, p + Vector2(-7.0, -6.5) * s, s * 0.9, a)
    elif v == 2:
        # згоріла машина й плями крові
        c.draw_colored_polygon(_rect_poly(p + Vector2(5.0, 0.0).rotated(ang) * s, ang, -3.0 * s, -1.4 * s, 3.0 * s, 1.4 * s), _ca(Color(0.18, 0.14, 0.12), a))
        c.draw_circle(p + Vector2(-4.0, 1.0).rotated(ang) * s, 1.8 * s, Color(0.45, 0.04, 0.04, 0.8 * a))
        c.draw_circle(p + Vector2(-2.5, 2.0).rotated(ang) * s, 1.0 * s, Color(0.45, 0.04, 0.04, 0.8 * a))

func _tide(c: Control, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    var hull := PackedVector2Array()
    for q in [Vector2(-11, -3), Vector2(10, -3), Vector2(5, 2), Vector2(-8, 2)]:
        hull.append(p + q.rotated(ang) * s)
    c.draw_colored_polygon(hull, _ca(Color(0.035, 0.09, 0.11), a))
    hull.append(hull[0])
    c.draw_polyline(hull, _ca(Color(0.40, 0.66, 0.67), 0.9 * a), 1.0 * s)
    var mast0 := p + Vector2(0, -3).rotated(ang) * s
    var mast1 := p + Vector2(0, -13).rotated(ang) * s
    c.draw_line(mast0, mast1, _ca(Color(0.22, 0.18, 0.13), a), 1.4 * s)
    c.draw_colored_polygon(PackedVector2Array([mast1, p + Vector2(0, -5).rotated(ang) * s, p + Vector2(7, -5).rotated(ang) * s]), _ca(Color(0.57, 0.54, 0.44), 0.78 * a))
    for row in range(2):
        var y := 5.0 + float(row) * 4.0
        c.draw_arc(p + Vector2(0, y).rotated(ang) * s, 11.0 * s, PI * 1.12, PI * 1.88, 10, _ca(Color(0.20, 0.47, 0.51), 0.7 * a), 1.0 * s)

func _bells(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    var metal := Color(0.48, 0.39, 0.25) if v == 2 else Color(0.31, 0.30, 0.27)
    var glint := _ca(Color(0.79, 0.68, 0.43), 0.8 * a)
    for i in range(3):
        var x := (float(i) - 1.0) * 8.0 * s
        var top := p + Vector2(x, -7.0 * s)
        c.draw_line(top, top + Vector2(0, 4.0 * s), _ca(Color(0.20, 0.18, 0.14), a), 1.0 * s)
        var bell := PackedVector2Array([
            top + Vector2(-2.5, 4.0) * s, top + Vector2(-2.2, 0.0) * s,
            top + Vector2(0, -2.5) * s, top + Vector2(2.2, 0.0) * s,
            top + Vector2(2.5, 4.0) * s, top + Vector2(4.0, 5.5) * s,
            top + Vector2(-4.0, 5.5) * s,
        ])
        c.draw_colored_polygon(bell, _ca(metal.lightened(0.10 * float(i == 1)), 0.85 * a))
        bell.append(bell[0])
        c.draw_polyline(bell, glint, 0.9 * s)
        c.draw_circle(top + Vector2(0, 5.5 * s), 1.0 * s, glint)

func _glass(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    var frame := _ca(Color(0.53, 0.48, 0.68), 0.8 * a)
    c.draw_arc(p + Vector2(0, -1.0 * s), 8.0 * s, PI, TAU, 14, frame, 2.0 * s)
    c.draw_line(p + Vector2(-8.0, -1.0) * s, p + Vector2(-8.0, 11.0) * s, frame, 2.0 * s)
    c.draw_line(p + Vector2(8.0, -1.0) * s, p + Vector2(8.0, 11.0) * s, frame, 2.0 * s)
    c.draw_line(p + Vector2(-10.0, 11.0) * s, p + Vector2(10.0, 11.0) * s, frame, 2.0 * s)
    c.draw_colored_polygon(PackedVector2Array([
        p + Vector2(-5.0, 1.0) * s, p + Vector2(0, -7.0) * s,
        p + Vector2(5.0, 1.0) * s, p + Vector2(2.0, 8.0) * s,
        p + Vector2(-4.0, 6.0) * s,
    ]), _ca(Color(0.12, 0.08, 0.20), 0.9 * a))
    var crack := PackedVector2Array([p + Vector2(0, -5) * s, p + Vector2(-2, 1) * s, p + Vector2(2, 3) * s, p + Vector2(-1, 8) * s])
    c.draw_polyline(crack, _ca(Color(0.84, 0.78, 1.0), 0.8 * a), 0.9 * s)

func _iron(c: Control, p: Vector2, s: float, a: float, v: int) -> void:
    var heart := PackedVector2Array([
        p + Vector2(0, 9) * s, p + Vector2(-11, -1) * s, p + Vector2(-10, -7) * s,
        p + Vector2(-5, -9) * s, p + Vector2(0, -4) * s, p + Vector2(5, -9) * s,
        p + Vector2(10, -7) * s, p + Vector2(11, -1) * s,
    ])
    c.draw_colored_polygon(heart, _ca(Color(0.42, 0.18, 0.12), 0.9 * a))
    heart.append(heart[0])
    c.draw_polyline(heart, _ca(Color(0.72, 0.47, 0.28), 0.85 * a), 1.0 * s)
    c.draw_circle(p, 3.2 * s, _ca(Color(0.13, 0.10, 0.09), a))
    c.draw_arc(p, 3.4 * s, 0, TAU, 10, _ca(Color(0.83, 0.57, 0.28), 0.9 * a), 1.1 * s)
    c.draw_line(p + Vector2(0, -3) * s, p + Vector2(0, -11) * s, _ca(Color(0.64, 0.43, 0.27), a), 1.2 * s)
    c.draw_line(p + Vector2(-6, 5) * s, p + Vector2(-12, 8) * s, _ca(Color(0.64, 0.43, 0.27), a), 1.2 * s)
    c.draw_line(p + Vector2(6, 5) * s, p + Vector2(12, 8) * s, _ca(Color(0.64, 0.43, 0.27), a), 1.2 * s)

func _doodle(c: Control, kind: int, p: Vector2, s: float, ang: float, a: float, v: int) -> void:
    match kind:
        0:
            _village(c, p, s, ang, a, v)
        1:
            _forest(c, p, s, a, v)
        2:
            _dunes(c, p, s, a, v)
        3:
            _snowland(c, p, s, a, v)
        4:
            _graves(c, p, s, a, v)
        5:
            _ruins(c, p, s, ang, a, v)
        7:
            _ashland(c, p, s, ang, a, v)
        8:
            _swamp(c, p, s, a, v)
        9:
            _tundra(c, p, s, a, v)
        10:
            _burning(c, p, s, ang, a, v)
        11:
            _tide(c, p, s, ang, a, v)
        12:
            _bells(c, p, s, a, v)
        13:
            _glass(c, p, s, a, v)
        14:
            _iron(c, p, s, a, v)
        _:
            _cityblock(c, p, s, ang, a, v)

# дрібні деталі землі: травинки, камінці, іскорки снігу, тріщини
func _speck(c: Control, kind: int, p: Vector2, s: float, v: int, a: float) -> void:
    match kind:
        0:
            if v == 3:
                var fc := [Color(0.98, 0.88, 0.30), Color(0.95, 0.95, 0.95), Color(0.92, 0.45, 0.60)]
                c.draw_circle(p, 1.1 * s, _ca(fc[v % 3], a))
            else:
                var g := _ca(Color(0.12, 0.34, 0.09), 0.8 * a)
                c.draw_line(p, p + Vector2(-1.6, -3.2) * s, g, 0.8)
                c.draw_line(p, p + Vector2(0.0, -3.8) * s, g, 0.8)
                c.draw_line(p, p + Vector2(1.6, -3.2) * s, g, 0.8)
        1:
            c.draw_circle(p, 1.2 * s, _ca(Color(0.03, 0.10, 0.05), 0.7 * a))
            if v == 3:
                c.draw_line(p, p + Vector2(3.0, -2.0) * s, _ca(Color(0.10, 0.30, 0.12), 0.8 * a), 0.9)
        2:
            if v == 3:
                c.draw_circle(p, 1.0 * s, _ca(Color(0.48, 0.36, 0.20), 0.8 * a))
            else:
                c.draw_arc(p, 3.0 * s, PI * 1.1, PI * 1.9, 6, _ca(Color(0.55, 0.40, 0.18), 0.55 * a), 0.9)
        3:
            if v == 2:
                c.draw_arc(p, 4.0 * s, PI * 1.1, PI * 1.9, 6, _ca(Color(0.50, 0.62, 0.82), 0.6 * a), 1.0)
            else:
                var wc := _ca(Color(1.0, 1.0, 1.0), 0.85 * a)
                c.draw_line(p + Vector2(-1.6, 0.0) * s, p + Vector2(1.6, 0.0) * s, wc, 0.8)
                c.draw_line(p + Vector2(0.0, -1.6) * s, p + Vector2(0.0, 1.6) * s, wc, 0.8)
        4:
            if v == 3:
                c.draw_circle(p, 1.0 * s, _ca(Color(0.62, 0.60, 0.66), 0.7 * a))
            else:
                var kc := _ca(Color(0.05, 0.04, 0.07), 0.7 * a)
                c.draw_line(p, p + Vector2(2.0, 1.5) * s, kc, 0.8)
                c.draw_line(p + Vector2(2.0, 1.5) * s, p + Vector2(3.0, 4.0) * s, kc, 0.8)
        5:
            c.draw_circle(p, 1.3 * s, _ca(Color(0.34, 0.31, 0.27), 0.85 * a))
            c.draw_circle(p + Vector2(-0.4, -0.4) * s, 0.6 * s, _ca(Color(0.62, 0.58, 0.50), 0.6 * a))
        7:
            # попіл: тріщини з жаром і жарини
            if v == 3:
                c.draw_circle(p, 0.9 * s, _ca(Color(1.0, 0.55, 0.15), 0.85 * a))
            else:
                var kc7 := _ca(Color(0.05, 0.03, 0.03), 0.75 * a)
                c.draw_line(p, p + Vector2(2.4, 1.2) * s, kc7, 0.9)
                c.draw_line(p + Vector2(2.4, 1.2) * s, p + Vector2(3.4, 3.8) * s, _ca(Color(1.0, 0.45, 0.1), 0.7 * a), 0.8)
        8:
            # болото: калюжки й очерет
            if v == 3:
                c.draw_circle(p, 0.9 * s, _ca(Color(0.62, 1.0, 0.35), 0.8 * a))
            else:
                _ell(c, p, 3.2 * s, 1.4 * s, Color(0.10, 0.22, 0.14, 0.7 * a))
                c.draw_line(p + Vector2(2.0, 0.0) * s, p + Vector2(2.4, -3.4) * s, _ca(Color(0.20, 0.34, 0.14), 0.8 * a), 0.8)
        9:
            # тундра: паморозь і крижинки
            if v == 2:
                c.draw_arc(p, 3.6 * s, PI * 1.1, PI * 1.9, 6, _ca(Color(0.42, 0.56, 0.80), 0.6 * a), 1.0)
            else:
                var tc := _ca(Color(0.88, 0.95, 1.0), 0.85 * a)
                c.draw_line(p + Vector2(-1.4, 0.0) * s, p + Vector2(1.4, 0.0) * s, tc, 0.8)
                c.draw_line(p + Vector2(0.0, -1.4) * s, p + Vector2(0.0, 1.4) * s, tc, 0.8)
        10:
            # жарини й сажа
            if v == 3:
                c.draw_circle(p, 1.0 * s, _ca(Color(1.0, 0.6, 0.15), 0.9 * a))
            else:
                c.draw_circle(p, 1.4 * s, _ca(Color(0.05, 0.03, 0.03), 0.6 * a))
        11:
            c.draw_arc(p, 3.0 * s, PI * 1.12, PI * 1.88, 8, _ca(Color(0.27, 0.58, 0.63), 0.8 * a), 0.9 * s)
            if v == 3:
                c.draw_circle(p + Vector2(3.0, -1.0) * s, 0.8 * s, _ca(Color(0.78, 0.86, 0.78), a))
        12:
            c.draw_arc(p, 2.6 * s, PI, TAU, 8, _ca(Color(0.63, 0.54, 0.37), 0.8 * a), 0.9 * s)
            c.draw_line(p + Vector2(-2.6, 0) * s, p + Vector2(2.6, 0) * s, _ca(Color(0.72, 0.63, 0.44), 0.8 * a), 0.8 * s)
        13:
            if v == 3:
                c.draw_line(p + Vector2(-2.0, 2.0) * s, p + Vector2(2.0, -2.0) * s, _ca(Color(0.91, 0.83, 1.0), 0.9 * a), 0.9 * s)
            else:
                c.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 1) * s, p + Vector2(1, -3) * s, p + Vector2(3, 2) * s]), _ca(Color(0.52, 0.40, 0.70), 0.65 * a))
        14:
            c.draw_circle(p, 1.3 * s, _ca(Color(0.48, 0.31, 0.20), 0.8 * a))
            if v == 3:
                c.draw_line(p + Vector2(-3, 0) * s, p + Vector2(3, 0) * s, _ca(Color(0.92, 0.57, 0.27), 0.9 * a), 0.9 * s)
        _:
            if v == 3:
                c.draw_line(p, p + Vector2(3.0, 1.0) * s, _ca(Color(0.04, 0.03, 0.03), 0.7 * a), 0.9)
            else:
                c.draw_circle(p, 1.3 * s, Color(0.40, 0.03, 0.03, 0.55 * a))

func _fill_color(loc: Dictionary) -> Color:
    var base: Color = Biomes.DATA[int(loc["biome"])]["map"]
    var col := PARCH.lerp(base, 0.62)
    if int(loc["second"]) >= 0:
        col = col.lerp(Biomes.DATA[int(loc["second"])]["map"], 0.12)
    if not GameState.is_unlocked(loc):
        col = col.lerp(Color(0.24, 0.23, 0.24), 0.58).darkened(0.12)
    return col

func _closed(poly: PackedVector2Array) -> PackedVector2Array:
    var e := poly.duplicate()
    if e.size() > 0:
        e.append(e[0])
    return e

func _draw_terrain() -> void:
    var c := terrain
    # ущелини між районами: темна земля, крізь яку ледь проступає пергамент
    c.draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.085, 0.06, 0.045, 0.80))
    # тіні: райони ніби трохи підняті над ущелинами
    for i in range(_meshes.size()):
        c.draw_mesh(_meshes[i], null, Transform2D(0.0, Vector2(7.0, 10.0)), Color(0, 0, 0, 0.55))
    # земля району з плавним світлом від центру й зернистою текстурою
    for i in range(_meshes.size()):
        c.draw_mesh(_meshes[i], _grain, Transform2D.IDENTITY, _fill_color(Locations.DATA[i]))
    for i in range(_specks.size()):
        var unl := GameState.is_unlocked(Locations.DATA[i])
        var a := 0.95 if unl else 0.40
        for sp in _specks[i]:
            _speck(c, int(sp[0]), sp[1], float(sp[2]), int(sp[3]), a)
    # дороги лежать на землі, під малюнками
    for r in _roads:
        var i1: int = r[0]
        var j1: int = r[1]
        var pts: PackedVector2Array = r[2]
        var open1 := GameState.is_unlocked(Locations.DATA[i1])
        var done_prev := GameState.conquered.has(String(Locations.DATA[j1]["id"]))
        var done_both := done_prev and GameState.conquered.has(String(Locations.DATA[i1]["id"]))
        var col := Color(0.80, 0.66, 0.42)
        if not open1:
            col = Color(0.38, 0.35, 0.32)
        elif done_both:
            col = Color(0.66, 0.10, 0.07)
        c.draw_polyline(pts, Color(0, 0, 0, 0.30), 11.0, true)
        c.draw_polyline(pts, Color(0.10, 0.06, 0.03, 0.95), 7.0, true)
        c.draw_polyline(pts, col, 4.2, true)
        if not open1:
            for k in range(0, pts.size() - 1, 3):
                c.draw_line(pts[k], pts[k + 1], Color(0.10, 0.06, 0.03, 0.9), 4.6)
        else:
            c.draw_polyline(pts, col.lightened(0.35) * Color(1, 1, 1, 0.35), 1.2, true)
    for i in range(_doodles.size()):
        var unl2 := GameState.is_unlocked(Locations.DATA[i])
        var a2 := 0.95 if unl2 else 0.42
        for it in _doodles[i]:
            _doodle(c, int(it[0]), it[1], float(it[2]), float(it[3]), a2, int(it[4]))
        var lid := String(Locations.DATA[i]["id"])
        if LANDMARKS.has(lid):
            var side := 1.0 if _label_up[i] else -1.0
            _landmark(c, String(LANDMARKS[lid]), _centers[i] + Vector2(0.0, 74.0 * side), 2.0, a2)
    # кордони: темний урвище-край, світла кромка всередині
    for i in range(_shapes.size()):
        var shp: PackedVector2Array = _shapes[i]
        var unl3 := GameState.is_unlocked(Locations.DATA[i])
        c.draw_polyline(_closed(shp), Color(0.04, 0.025, 0.015, 0.95), 2.6, true)
        var rim: Color = _fill_color(Locations.DATA[i]).lightened(0.45)
        rim.a = 0.38 if unl3 else 0.14
        for q in Geometry2D.offset_polygon(shp, -4.0, Geometry2D.JOIN_ROUND):
            var qp: PackedVector2Array = q
            if qp.size() >= 3:
                c.draw_polyline(_closed(qp), rim, 1.6, true)
    # туман над закритими землями
    for i in range(_meshes.size()):
        if not GameState.is_unlocked(Locations.DATA[i]):
            c.draw_mesh(_meshes[i], _grain, Transform2D.IDENTITY, Color(0.16, 0.15, 0.17, 0.38))

# ================= Пам'ятні місця (великі малюнки поверх району) =================
func _landmark(c: Control, kind: String, p: Vector2, s: float, a: float) -> void:
    _ell(c, p + Vector2(4.0, 9.0) * s, 15.0 * s, 6.0 * s, Color(0, 0, 0, 0.35 * a))
    match kind:
        "village":
            _village(c, p, s * 1.2, 0.15, a, 0)
        "castle":
            var stone := _ca(Color(0.55, 0.52, 0.48), a)
            var dark := _ca(Color(0.30, 0.28, 0.27), a)
            c.draw_rect(Rect2(p + Vector2(-13, -4) * s, Vector2(26, 11) * s), stone)
            for k in range(6):
                c.draw_rect(Rect2(p + Vector2(-13.0 + 4.6 * float(k), -6.5) * s, Vector2(2.6, 2.6) * s), stone)
            for tx in [-14.0, 0.0, 14.0]:
                var top := p + Vector2(tx, -9.0) * s
                c.draw_rect(Rect2(top + Vector2(-3.4, 0) * s, Vector2(6.8, 16) * s), stone.darkened(0.08))
                c.draw_colored_polygon(PackedVector2Array([top + Vector2(-4.4, 0) * s, top + Vector2(0, -9) * s, top + Vector2(4.4, 0) * s]), _ca(Color(0.42, 0.10, 0.08), a))
            c.draw_rect(Rect2(p + Vector2(-2.5, 1.5) * s, Vector2(5, 5.5) * s), dark)
            c.draw_line(p + Vector2(0, -18) * s, p + Vector2(0, -25) * s, _ca(INK, a), 1.0 * s)
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -25) * s, p + Vector2(6, -23) * s, p + Vector2(0, -21) * s]), _ca(Color(0.85, 0.12, 0.08), a))
        "volcano":
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-17, 8) * s, p + Vector2(-4, -11) * s, p + Vector2(4, -11) * s, p + Vector2(17, 8) * s]), _ca(Color(0.20, 0.12, 0.09), a))
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -11) * s, p + Vector2(4, -11) * s, p + Vector2(2, -8) * s, p + Vector2(-2, -8) * s]), _ca(Color(1.0, 0.55, 0.10), a))
            c.draw_polyline(PackedVector2Array([p + Vector2(-1, -9) * s, p + Vector2(-4, -3) * s, p + Vector2(-2, 2) * s, p + Vector2(-7, 7) * s]), _ca(Color(1.0, 0.40, 0.06), a), 1.4 * s, true)
            c.draw_polyline(PackedVector2Array([p + Vector2(2, -9) * s, p + Vector2(5, -2) * s, p + Vector2(9, 6) * s]), _ca(Color(1.0, 0.50, 0.08), a), 1.1 * s, true)
            for k in range(3):
                c.draw_circle(p + Vector2(2.0 + 3.0 * float(k), -15.0 - 5.0 * float(k)) * s, (3.0 + float(k)) * s, Color(0.15, 0.13, 0.13, 0.45 * a))
        "lighthouse":
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 8) * s, p + Vector2(-2.4, -12) * s, p + Vector2(2.4, -12) * s, p + Vector2(4, 8) * s]), _ca(Color(0.78, 0.76, 0.70), a))
            for k in range(3):
                var yy := 4.0 - 6.0 * float(k)
                c.draw_rect(Rect2(p + Vector2(-3.4 + 0.3 * float(k), yy - 1.4) * s, Vector2(6.8 - 0.6 * float(k), 2.4) * s), _ca(Color(0.62, 0.10, 0.08), a))
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14) * s, p + Vector2(24, -21) * s, p + Vector2(24, -8) * s]), Color(1.0, 0.92, 0.55, 0.22 * a))
            c.draw_circle(p + Vector2(0, -14) * s, 2.4 * s, _ca(Color(1.0, 0.85, 0.4), a))
        "ship":
            _tide(c, p, s * 1.5, -0.25, a, 0)
        "cathedral":
            var wall := _ca(Color(0.50, 0.48, 0.46), a)
            c.draw_rect(Rect2(p + Vector2(-12, -3) * s, Vector2(19, 10) * s), wall)
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -3) * s, p + Vector2(-2.5, -9) * s, p + Vector2(8, -3) * s]), _ca(Color(0.26, 0.24, 0.26), a))
            c.draw_rect(Rect2(p + Vector2(7, -12) * s, Vector2(7, 19) * s), wall.darkened(0.1))
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(6, -12) * s, p + Vector2(10.5, -25) * s, p + Vector2(15, -12) * s]), _ca(Color(0.22, 0.20, 0.22), a))
            c.draw_circle(p + Vector2(10.5, -7) * s, 1.8 * s, _ca(Color(0.85, 0.66, 0.30), a))
            c.draw_circle(p + Vector2(-3, 1.5) * s, 2.4 * s, _ca(Color(0.62, 0.20, 0.30), a))
        "mirror":
            c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 8) * s, p + Vector2(-3.5, -16) * s, p + Vector2(0, -22) * s, p + Vector2(3.5, -16) * s, p + Vector2(6, 8) * s]), _ca(Color(0.10, 0.06, 0.14), a))
            c.draw_polyline(PackedVector2Array([p + Vector2(-1, -17) * s, p + Vector2(1.5, -8) * s, p + Vector2(-1.5, -1) * s, p + Vector2(1, 6) * s]), _ca(Color(0.85, 0.75, 1.0), 0.8 * a), 0.9 * s, true)
            c.draw_circle(p + Vector2(0, -22) * s, 3.5 * s, Color(0.70, 0.50, 1.0, 0.28 * a))
        "machine":
            var gear := _ca(Color(0.48, 0.30, 0.18), a)
            for k in range(10):
                var ang := TAU * float(k) / 10.0
                c.draw_colored_polygon(_rect_poly(p, ang, -1.8 * s, -12.0 * s, 1.8 * s, -8.0 * s), gear)
            c.draw_circle(p, 9.0 * s, gear)
            c.draw_circle(p, 4.0 * s, _ca(Color(0.16, 0.10, 0.07), a))
            c.draw_rect(Rect2(p + Vector2(10, -16) * s, Vector2(4, 16) * s), _ca(Color(0.26, 0.17, 0.12), a))
            for k in range(3):
                c.draw_circle(p + Vector2(12.0 + 2.0 * float(k), -19.0 - 4.5 * float(k)) * s, (2.4 + float(k)) * s, Color(0.15, 0.13, 0.12, 0.40 * a))

# ================= Малювання: значки, виділення, назви (у координатах вікна) =================
func _sword(c: Control, base: Vector2, k: float) -> void:
    var bob := sin(t * 2.0) * 1.5
    var b := base + Vector2(0, bob)
    var steel := Color(0.80, 0.82, 0.88)
    c.draw_colored_polygon(PackedVector2Array([b + Vector2(-5, -10) * k, b + Vector2(5, -10) * k, b + Vector2(4, -66) * k, b + Vector2(0, -74) * k, b + Vector2(-4, -66) * k]), INK)
    c.draw_colored_polygon(PackedVector2Array([b + Vector2(-3.4, -11) * k, b + Vector2(3.4, -11) * k, b + Vector2(2.6, -65) * k, b + Vector2(0, -71) * k, b + Vector2(-2.6, -65) * k]), steel)
    c.draw_line(b + Vector2(-0.6, -12) * k, b + Vector2(-0.6, -66) * k, Color(1, 1, 1, 0.7), 1.2)
    c.draw_rect(Rect2(b + Vector2(-12, -11) * k, Vector2(24, 5) * k), Color(0.55, 0.40, 0.12))
    c.draw_rect(Rect2(b + Vector2(-12, -11) * k, Vector2(24, 5) * k), INK, false, 1.5)
    c.draw_rect(Rect2(b + Vector2(-2.5, -6) * k, Vector2(5, 14) * k), Color(0.30, 0.18, 0.08))
    c.draw_circle(b + Vector2(0, 10) * k, 3.5 * k, Color(0.70, 0.55, 0.18))

func _draw_markers() -> void:
    var c := markers
    var zr := zoom / maxf(min_zoom, 0.001)
    var base_k := clampf(minf(view.size.x / 700.0, view.size.y / 440.0), 0.8, 1.2)
    var k := base_k * clampf(1.0 + (zr - 1.0) * 0.12, 1.0, 1.4)
    var font: Font = GameFonts.dark()      # назви локацій — зловісним шрифтом
    var fs := 14
    var vr := Rect2(Vector2(-70.0, -90.0), view.size + Vector2(140.0, 180.0))
    for bn in _banners:
        _draw_banner(c, String(bn[0]), bn[1], k)

    # виділення районів
    for i in range(_cells.size()):
        var id := String(Locations.DATA[i]["id"])
        if _cells[i].size() < 3:
            continue
        if id != selected and id != hovered:
            continue
        var sp := _tpoly(_shapes[i])
        var edge := sp.duplicate()
        edge.append(edge[0])
        if id == selected:
            var pulse := 0.5 + 0.5 * sin(t * 3.0)
            c.draw_colored_polygon(sp, Color(0.98, 0.60, 0.50, 0.42 + 0.12 * pulse))
            c.draw_polyline(edge, Color(1.0, 0.85, 0.1, 0.22), 13.0)
            c.draw_polyline(edge, Color(0.98, 0.80, 0.05), 5.0)
            c.draw_polyline(edge, Color(1.0, 0.95, 0.55, 0.9), 1.5)
        else:
            c.draw_colored_polygon(sp, Color(1.0, 0.95, 0.7, 0.16))
            c.draw_polyline(edge, Color(1.0, 0.85, 0.3, 0.7), 3.0)

    # значки та назви
    for i in range(_centers.size()):
        var loc: Dictionary = Locations.DATA[i]
        var id2 := String(loc["id"])
        var p := _w2s(_centers[i])
        if not vr.has_point(p):
            continue
        var unlocked := GameState.is_unlocked(loc)
        var done := GameState.conquered.has(id2)
        var big := (String(loc["boss"]) == "epicenter_lord" or String(loc["boss"]) == "citadel_lord" or String(loc["boss"]) == "inferno_lord" or bool(loc.get("boss_loc", false)))
        var rad := 17.0 * k
        if big:
            rad = 21.0 * k
        var pulse2 := 0.5 + 0.5 * sin(t * 3.0 + float(i))

        c.draw_circle(p + Vector2(0, 3), rad + 2.0, Color(0, 0, 0, 0.45))
        var fill := Color(0.80, 0.08, 0.08)
        var icon: Texture2D = _tex["tab_weapons"]
        var ring := Color(0.98, 0.95, 0.9)
        if done:
            fill = Color(0.16, 0.55, 0.22)
            icon = _tex["check"]
        elif not unlocked:
            fill = Color(0.22, 0.22, 0.25)
            icon = _tex["lock"]
            ring = Color(0.55, 0.55, 0.6)
        elif big:
            icon = _tex["skull"]
        if unlocked and not done:
            c.draw_circle(p, rad + 6.0 + 3.0 * pulse2, Color(1.0, 0.25, 0.1, 0.16))
        c.draw_circle(p, rad, fill)
        c.draw_arc(p, rad, 0.0, TAU, 32, ring, 2.5)
        if big:
            for s in range(12):
                var ang := TAU * float(s) / 12.0
                var d := Vector2(cos(ang), sin(ang))
                c.draw_line(p + d * rad, p + d * (rad + 5.0 * k), Color(0.98, 0.8, 0.2), 2.0)
        var isz := rad * 1.45
        var mod := Color(1, 1, 1, 1)
        if not unlocked:
            mod = Color(0.7, 0.7, 0.75, 0.85)
        c.draw_texture_rect(icon, Rect2(p - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, mod)

        if id2 == selected:
            _sword(c, p + Vector2(rad + 10.0 * k, 4.0 * k), k)

        # табличка з назвою — стрічка з вирізаними кінцями; сусіди в ряду чергуються над/під значком
        var name_s := String(loc["name"])
        var fs2 := int(round(12.0 * k))
        var tw := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
        var pw := tw + 20.0 * k
        var ph := 19.0 * k
        var up: bool = _label_up[i]
        var px := clampf(p.x - pw * 0.5, 6.0, maxf(6.0, view.size.x - 6.0 - pw))
        var py := p.y - rad - 6.0 * k - ph if up else p.y + rad + 6.0 * k
        var fill2 := Color(0.08, 0.08, 0.09, 0.90)
        var edge2 := Color(0.40, 0.40, 0.44)
        var tcol := Color(0.66, 0.66, 0.70)
        if done:
            fill2 = Color(0.05, 0.13, 0.06, 0.93)
            edge2 = Color(0.45, 0.80, 0.42)
            tcol = Color(0.82, 0.97, 0.76)
        elif unlocked:
            fill2 = Color(0.13, 0.07, 0.03, 0.94)
            edge2 = GOLD
            tcol = Color(1.0, 0.90, 0.60)
        var notch := 6.0 * k
        var rib := PackedVector2Array([
            Vector2(px - notch, py), Vector2(px + pw + notch, py), Vector2(px + pw, py + ph * 0.5),
            Vector2(px + pw + notch, py + ph), Vector2(px - notch, py + ph), Vector2(px, py + ph * 0.5)])
        c.draw_colored_polygon(rib, fill2)
        c.draw_polyline(_closed(rib), Color(0, 0, 0, 0.8), 3.0, true)
        c.draw_polyline(_closed(rib), edge2, 1.3, true)
        c.draw_string(font, Vector2(px + 10.0 * k + 1.0, py + ph * 0.5 + fs2 * 0.36 + 1.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0, 0, 0, 0.85))
        c.draw_string(font, Vector2(px + 10.0 * k, py + ph * 0.5 + fs2 * 0.36), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tcol)

        # складність (черепи-крапки) — лише для вибраної чи наведеної локації, щоб карта не рябіла
        if id2 != selected and id2 != hovered:
            continue
        var tier := int(loc["tier"])
        var red := Locations.red_skulls(loc)
        var dy := py - 6.0 * k if up else py + ph + 6.0 * k
        var sx := px + pw * 0.5 - float(tier) * 3.5 * k + 1.75 * k
        for n in range(tier):
            var dc := Color(0.85, 0.15, 0.12)
            var dr := 2.2 * k
            if red > 0 and n < red:
                dr = 2.9 * k
                dc = Color(1.0, 0.05, 0.03)
                c.draw_circle(Vector2(sx + 7.0 * k * float(n), dy), dr + 1.3, Color(0.25, 0.0, 0.0, 0.9))
            elif red > 0:
                dc = Color(0.88, 0.80, 0.68)
            c.draw_circle(Vector2(sx + 7.0 * k * float(n), dy), dr, dc)

# Гербовий прапор кампанії ліворуч від її ряду: знак, назва й поступ.
func _draw_banner(c: Control, camp: String, wpos: Vector2, k: float) -> void:
    var p := _w2s(wpos)
    var w := 104.0 * k
    var h := 74.0 * k
    if p.y < -h or p.y > view.size.y + h:
        return
    var col: Color = CAMPAIGN_COLORS.get(camp, GOLD)
    var x0 := p.x - w * 0.5
    var y0 := p.y - h * 0.5
    var flag := PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, y0 + h),
        Vector2(x0 + w * 0.5, y0 + h - 14.0 * k), Vector2(x0, y0 + h)])
    var sh := PackedVector2Array()
    for q in flag:
        sh.append(q + Vector2(3.0, 4.0))
    c.draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
    c.draw_colored_polygon(flag, col.darkened(0.72))
    c.draw_polyline(_closed(flag), Color(0, 0, 0, 0.9), 3.4, true)
    c.draw_polyline(_closed(flag), col.lerp(GOLD, 0.5), 1.6, true)
    c.draw_line(Vector2(x0 - 4.0 * k, y0), Vector2(x0 + w + 4.0 * k, y0), Color(0.30, 0.18, 0.08), 4.0 * k)
    var done := 0
    for loc in Locations.DATA:
        if String(loc.get("campaign", "")) == camp and GameState.conquered.has(String(loc["id"])):
            done += 1
    # знак кампанії — медальйон із тим самим малюнком, що й на землях цієї кампанії
    var emblem := Vector2(p.x, y0 + 17.0 * k)
    c.draw_circle(emblem, 13.0 * k, Color(0.03, 0.02, 0.02, 0.9))
    c.draw_arc(emblem, 13.0 * k, 0.0, TAU, 28, col.lerp(GOLD, 0.5), 1.4, true)
    var kinds := {"tide": 11, "bells": 12, "glass": 13, "iron": 14}
    _doodle(c, int(kinds.get(camp, 11)), emblem + Vector2(0.0, 1.0 * k), 0.85 * k, 0.0, 1.0, 2)
    var font: Font = GameFonts.royal()
    var fs := int(round(10.5 * k))
    c.draw_multiline_string(font, Vector2(x0 + 4.0 * k, y0 + 33.0 * k + fs * 0.7), String(CAMPAIGN_TITLES.get(camp, camp)), HORIZONTAL_ALIGNMENT_CENTER, w - 8.0 * k, fs, 2, col.lerp(Color(1, 0.95, 0.8), 0.6))
    var prog := "%d / 5" % done
    var pf := int(round(9.0 * k))
    c.draw_string(font, Vector2(x0, y0 + h - 17.0 * k), prog, HORIZONTAL_ALIGNMENT_CENTER, w, pf, Color(0.95, 0.85, 0.6, 0.85))

# ================= Малювання: рамка, завіси, заголовок =================
func _curtain(c: Control, left: bool) -> void:
    var h := size.y
    var w := 46.0
    var ty := h * 0.55
    var inner := PackedVector2Array()
    var y := 0.0
    while y <= h:
        var pinch := 1.0 - 0.45 * exp(-pow((y - ty) / (h * 0.10), 2.0))
        var x := w * pinch + 3.0 * sin(y * 0.06)
        if not left:
            x = size.x - x
        inner.append(Vector2(x, y))
        y += 8.0
    var pts := PackedVector2Array()
    var edge_x := 0.0
    if not left:
        edge_x = size.x
    pts.append(Vector2(edge_x, 0.0))
    for p in inner:
        pts.append(p)
    pts.append(Vector2(edge_x, h))
    c.draw_colored_polygon(pts, Color(0.55, 0.07, 0.07))
    for f in range(1, 5):
        var u := float(f) / 5.0
        var line := PackedVector2Array()
        for p in inner:
            line.append(Vector2(lerpf(edge_x, p.x, u), p.y))
        var shade := Color(0.30, 0.02, 0.03, 0.55)
        if f % 2 == 0:
            shade = Color(0.85, 0.20, 0.18, 0.30)
        c.draw_polyline(line, shade, 3.0)
    c.draw_polyline(inner, Color(0.95, 0.75, 0.2), 2.5)
    var tx := w * 0.55 * 0.5 + 2.0
    if not left:
        tx = size.x - tx
    c.draw_circle(Vector2(tx, ty), 6.0, Color(0.95, 0.75, 0.2))
    c.draw_circle(Vector2(tx, ty), 3.0, Color(0.55, 0.38, 0.08))
    c.draw_line(Vector2(tx, ty), Vector2(tx, ty + 70.0), Color(0.95, 0.75, 0.2), 3.0)
    c.draw_rect(Rect2(tx - 4.0, ty + 62.0, 8.0, 20.0), Color(0.95, 0.75, 0.2))
    for s in range(-1, 2):
        c.draw_line(Vector2(tx + 2.5 * float(s), ty + 82.0), Vector2(tx + 3.5 * float(s), ty + 96.0), Color(0.85, 0.65, 0.15), 1.5)

# фасований «кант»: чотири трапеції зі своїм кольором (світло зверху/зліва, тінь знизу/справа)
func _bevel(c: Control, o: Rect2, i: Rect2, ct: Color, cl: Color, cb: Color, cr: Color) -> void:
    var otl := o.position
    var otr := Vector2(o.end.x, o.position.y)
    var obr := o.end
    var obl := Vector2(o.position.x, o.end.y)
    var itl := i.position
    var itr := Vector2(i.end.x, i.position.y)
    var ibr := i.end
    var ibl := Vector2(i.position.x, i.end.y)
    c.draw_colored_polygon(PackedVector2Array([otl, otr, itr, itl]), ct)
    c.draw_colored_polygon(PackedVector2Array([otl, itl, ibl, obl]), cl)
    c.draw_colored_polygon(PackedVector2Array([obl, ibl, ibr, obr]), cb)
    c.draw_colored_polygon(PackedVector2Array([otr, obr, ibr, itr]), cr)

func _stud(c: Control, p: Vector2, r: float) -> void:
    c.draw_circle(p + Vector2(0.8, 1.0), r, Color(0, 0, 0, 0.45))
    c.draw_circle(p, r, Color(0.45, 0.30, 0.08))
    c.draw_circle(p, r * 0.78, Color(0.92, 0.72, 0.22))
    c.draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color(1.0, 0.96, 0.7))

func _corner_ornament(c: Control, p: Vector2, outward: Vector2) -> void:
    var r := 19.0
    # золоті «листки» назовні по діагоналі
    for k in range(-1, 2):
        var d := outward.rotated(float(k) * 0.55).normalized()
        var tip := p + d * (r + 11.0)
        var side := Vector2(-d.y, d.x)
        c.draw_colored_polygon(PackedVector2Array([p + d * (r - 4.0) + side * 4.5, tip, p + d * (r - 4.0) - side * 4.5]), Color(0.05, 0.03, 0.02))
        c.draw_colored_polygon(PackedVector2Array([p + d * (r - 3.0) + side * 3.0, p + d * (r + 8.0), p + d * (r - 3.0) - side * 3.0]), Color(0.86, 0.66, 0.18))
    # восьмикутна пластина
    var oct_o := PackedVector2Array()
    var oct_i := PackedVector2Array()
    for k in range(8):
        var ang := TAU * (float(k) + 0.5) / 8.0
        oct_o.append(p + Vector2(cos(ang), sin(ang)) * r)
        oct_i.append(p + Vector2(cos(ang), sin(ang)) * (r - 3.0))
    c.draw_colored_polygon(oct_o, Color(0.05, 0.03, 0.02))
    c.draw_colored_polygon(oct_i, Color(0.88, 0.68, 0.20))
    c.draw_arc(p, r - 6.5, 0.0, TAU, 24, Color(0.45, 0.30, 0.08), 1.5)
    c.draw_circle(p, 8.0, Color(0.20, 0.10, 0.04))
    c.draw_circle(p, 6.0, Color(0.60, 0.07, 0.07))
    c.draw_circle(p + Vector2(-1.8, -1.8), 2.0, Color(1.0, 0.6, 0.55, 0.85))
    c.draw_arc(p, 8.0, 0.0, TAU, 20, Color(0.98, 0.84, 0.35), 1.5)

func _draw_frame() -> void:
    var c := frame
    var m := map_rect
    _curtain(c, true)
    _curtain(c, false)

    # м'яка внутрішня тінь на самій карті
    var d := 24.0
    var dark := Color(0.0, 0.0, 0.0, 0.55)
    var clear := Color(0.0, 0.0, 0.0, 0.0)
    var cols := PackedColorArray([dark, dark, clear, clear])
    c.draw_polygon(PackedVector2Array([m.position, Vector2(m.end.x, m.position.y), Vector2(m.end.x, m.position.y + d), Vector2(m.position.x, m.position.y + d)]), cols)
    c.draw_polygon(PackedVector2Array([Vector2(m.position.x, m.end.y), Vector2(m.end.x, m.end.y), Vector2(m.end.x, m.end.y - d), Vector2(m.position.x, m.end.y - d)]), cols)
    c.draw_polygon(PackedVector2Array([m.position, Vector2(m.position.x, m.end.y), Vector2(m.position.x + d, m.end.y), Vector2(m.position.x + d, m.position.y)]), cols)
    c.draw_polygon(PackedVector2Array([Vector2(m.end.x, m.position.y), Vector2(m.end.x, m.end.y), Vector2(m.end.x - d, m.end.y), Vector2(m.end.x - d, m.position.y)]), cols)

    # дерев'яна рамка: чорний контур, дерево, золота окантовка, темний внутрішній кант
    _bevel(c, m.grow(21.0), m.grow(19.0), Color(0.03, 0.02, 0.01), Color(0.03, 0.02, 0.01), Color(0.03, 0.02, 0.01), Color(0.03, 0.02, 0.01))
    _bevel(c, m.grow(19.0), m.grow(9.0), Color(0.46, 0.29, 0.13), Color(0.37, 0.22, 0.10), Color(0.17, 0.09, 0.04), Color(0.23, 0.13, 0.06))
    # прожилки дерева
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var o := m.grow(19.0)
    var inn := m.grow(9.0)
    for n in range(46):
        var gy := rng.randf_range(o.position.y + 1.5, inn.position.y - 1.5)
        var gx := rng.randf_range(o.position.x + 10.0, o.end.x - 70.0)
        var gl := rng.randf_range(20.0, 70.0)
        c.draw_line(Vector2(gx, gy), Vector2(gx + gl, gy), Color(0.10, 0.05, 0.02, 0.30), 1.0)
        var gy2 := rng.randf_range(inn.end.y + 1.5, o.end.y - 1.5)
        var gx2 := rng.randf_range(o.position.x + 10.0, o.end.x - 70.0)
        c.draw_line(Vector2(gx2, gy2), Vector2(gx2 + rng.randf_range(20.0, 70.0), gy2), Color(0.60, 0.40, 0.20, 0.18), 1.0)
    for n in range(32):
        var vx := rng.randf_range(o.position.x + 1.5, inn.position.x - 1.5)
        var vy := rng.randf_range(o.position.y + 10.0, o.end.y - 70.0)
        c.draw_line(Vector2(vx, vy), Vector2(vx, vy + rng.randf_range(20.0, 70.0)), Color(0.10, 0.05, 0.02, 0.30), 1.0)
        var vx2 := rng.randf_range(inn.end.x + 1.5, o.end.x - 1.5)
        var vy2 := rng.randf_range(o.position.y + 10.0, o.end.y - 70.0)
        c.draw_line(Vector2(vx2, vy2), Vector2(vx2, vy2 + rng.randf_range(20.0, 70.0)), Color(0.60, 0.40, 0.20, 0.16), 1.0)
    # золота окантовка і темний внутрішній кант
    _bevel(c, m.grow(9.0), m.grow(5.5), Color(1.0, 0.88, 0.40), Color(0.92, 0.72, 0.22), Color(0.50, 0.33, 0.07), Color(0.62, 0.42, 0.10))
    _bevel(c, m.grow(5.5), m.grow(0.0), Color(0.10, 0.06, 0.03), Color(0.10, 0.06, 0.03), Color(0.22, 0.14, 0.07), Color(0.18, 0.11, 0.05))
    # тонка світла лінія на краю карти
    c.draw_rect(m, Color(1.0, 0.85, 0.35, 0.55), false, 1.0)

    # заклепки по дереву
    var cx0 := m.position.x + 46.0
    while cx0 < m.end.x - 40.0:
        _stud(c, Vector2(cx0, m.position.y - 14.0), 2.6)
        _stud(c, Vector2(cx0, m.end.y + 14.0), 2.6)
        cx0 += 52.0
    var cy0 := m.position.y + 46.0
    while cy0 < m.end.y - 40.0:
        _stud(c, Vector2(m.position.x - 14.0, cy0), 2.6)
        _stud(c, Vector2(m.end.x + 14.0, cy0), 2.6)
        cy0 += 52.0

    # кутові прикраси
    _corner_ornament(c, Vector2(m.position.x - 14.0, m.position.y - 14.0), Vector2(-1.0, -1.0))
    _corner_ornament(c, Vector2(m.end.x + 14.0, m.position.y - 14.0), Vector2(1.0, -1.0))
    _corner_ornament(c, Vector2(m.end.x + 14.0, m.end.y + 14.0), Vector2(1.0, 1.0))
    _corner_ornament(c, Vector2(m.position.x - 14.0, m.end.y + 14.0), Vector2(-1.0, 1.0))

    # табличка-заголовок по центру зверху
    var font: Font = GameFonts.royal()     # заголовок карти — королівським
    var title := "Мапа відвойованих земель"
    var fs := 19
    var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
    var pw := tw + 56.0
    var ph := 30.0
    var cx := size.x * 0.5
    var r := Rect2(cx - pw * 0.5, 9.0, pw, ph)
    var hy := r.position.y + ph * 0.5
    var plate := PackedVector2Array([Vector2(r.position.x - 14.0, hy), Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x + 14.0, hy), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)])
    c.draw_colored_polygon(plate, Color(0.14, 0.08, 0.04))
    var closed := plate.duplicate()
    closed.append(plate[0])
    c.draw_polyline(closed, Color(0.03, 0.02, 0.01), 5.0)
    c.draw_polyline(closed, Color(0.90, 0.70, 0.18), 2.0)
    c.draw_line(Vector2(r.position.x + 4.0, r.position.y + 4.0), Vector2(r.end.x - 4.0, r.position.y + 4.0), Color(1.0, 0.85, 0.4, 0.25), 1.0)
    for sx in [r.position.x - 6.0, r.end.x + 6.0]:
        var dx: float = sx
        c.draw_colored_polygon(PackedVector2Array([Vector2(dx, hy - 4.0), Vector2(dx + 4.0, hy), Vector2(dx, hy + 4.0), Vector2(dx - 4.0, hy)]), Color(0.95, 0.75, 0.2))
    c.draw_string(font, Vector2(cx - tw * 0.5 + 1.0, r.position.y + 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
    c.draw_string(font, Vector2(cx - tw * 0.5, r.position.y + 21.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD)

    # маленька підказка знизу на рамці
    var hint := "Коліщатко — ближче чи далі   •   Затисни й тягни — мандруй мапою"
    var hfs := 12
    var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
    var hr := Rect2(cx - (hw + 24.0) * 0.5, m.end.y + 11.0, hw + 24.0, 20.0)
    c.draw_style_box(_plate(Color(0.12, 0.07, 0.04, 0.96), Color(0.80, 0.60, 0.20)), hr)
    c.draw_string(font, Vector2(hr.position.x + 13.0, hr.position.y + 15.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(0, 0, 0, 0.8))
    c.draw_string(font, Vector2(hr.position.x + 12.0, hr.position.y + 14.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(0.93, 0.87, 0.72))
