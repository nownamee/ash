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

# «Світ» карти в умовних одиницях. Усе (райони, малюнки, стежки) будується в цих координатах,
# а вікно показує його з масштабом zoom і зсувом offset.
# Зверху карти додано смугу EXTRA_TOP для локацій за «Серцем пожежі»: їхні pos.y від'ємні (див. locations.gd),
# а в усіх старих локацій позиція лишилась тією самою відносно нижньої частини карти.
const EXTRA_TOP := 360.0
const WORLD := Vector2(1000.0, 1360.0)
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

var _cells: Array = []      # багатокутник кожного району (координати світу)
var _rings: Array = []      # внутрішні «кільця» для об'ємного затінення районів
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
    b.tooltip_text = "Колесо миші — масштаб"
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

func _warp(p: Vector2) -> Vector2:
    var e := 0.6
    if p.x < e or p.x > WORLD.x - e or p.y < e or p.y > WORLD.y - e:
        return p
    return p + Vector2(sin(p.y * 0.045 + 1.3) + 0.7 * sin(p.y * 0.13 + p.x * 0.05), cos(p.x * 0.05 + 0.7) + 0.7 * sin(p.x * 0.11 - p.y * 0.04)) * 6.0

func _refine(poly: PackedVector2Array) -> PackedVector2Array:
    var out := PackedVector2Array()
    var n := poly.size()
    for i in range(n):
        var a := poly[i]
        var b := poly[(i + 1) % n]
        var steps := maxi(1, int(a.distance_to(b) / 12.0))
        for s in range(steps):
            var w := _warp(a.lerp(b, float(s) / float(steps)))
            if out.size() == 0 or out[out.size() - 1].distance_to(w) > 0.01:
                out.append(w)
    return out

func _build_geometry() -> void:
    _centers = []
    for loc in Locations.DATA:
        var v: Vector2 = loc["pos"]
        _centers.append(Vector2(v.x * WORLD.x, v.y * (WORLD.y - EXTRA_TOP) + EXTRA_TOP))
    _cells = []
    var rect_poly := PackedVector2Array([Vector2.ZERO, Vector2(WORLD.x, 0.0), WORLD, Vector2(0.0, WORLD.y)])
    for i in range(_centers.size()):
        var poly := rect_poly
        for j in range(_centers.size()):
            if j != i:
                poly = _clip_half(poly, _centers[i], _centers[j])
        _cells.append(_refine(poly))

    # внутрішні кільця: райони виглядають «випуклими», краї темніші, середина світліша
    _rings = []
    var deltas := [10.0, 22.0, 38.0]
    for i in range(_cells.size()):
        var rings: Array = []
        var cell: PackedVector2Array = _cells[i]
        if cell.size() >= 3:
            for k in range(deltas.size()):
                var d: float = deltas[k]
                var res: Array = Geometry2D.offset_polygon(cell, -d, Geometry2D.JOIN_ROUND)
                for rp in res:
                    var rpp: PackedVector2Array = rp
                    if rpp.size() >= 3:
                        rings.append(rpp)
        _rings.append(rings)

    # малюнки й дрібні деталі в районах
    var rng := RandomNumberGenerator.new()
    _doodles = []
    _specks = []
    for i in range(_cells.size()):
        var loc: Dictionary = Locations.DATA[i]
        rng.seed = hash(String(loc["id"]))
        var poly2: PackedVector2Array = _cells[i]
        var items: Array = []
        var specks: Array = []
        if poly2.size() < 3:
            _doodles.append(items)
            _specks.append(specks)
            continue
        var bb := Rect2(poly2[0], Vector2.ZERO)
        for p in poly2:
            bb = bb.expand(p)
        var want := clampi(int(bb.size.x * bb.size.y / 1100.0), 5, 30)
        var tries := 0
        while items.size() < want and tries < 300:
            tries += 1
            var pt := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
            if pt.distance_to(_centers[i]) < 52.0:
                continue
            var ok := true
            for off in [Vector2(12, 0), Vector2(-12, 0), Vector2(0, 12), Vector2(0, -12)]:
                if not Geometry2D.is_point_in_polygon(pt + off, poly2):
                    ok = false
                    break
            if not ok:
                continue
            for it in items:
                var q: Vector2 = it[1]
                if q.distance_to(pt) < 30.0:
                    ok = false
                    break
            if not ok:
                continue
            var kind := int(loc["biome"])
            if int(loc["second"]) >= 0 and rng.randf() < 0.3:
                kind = int(loc["second"])
            items.append([kind, pt, rng.randf_range(1.15, 1.6), rng.randf_range(-0.5, 0.5), int(rng.randi() % 3)])
        items.sort_custom(func(x, y): return x[1].y < y[1].y)
        _doodles.append(items)

        var want_s := clampi(int(bb.size.x * bb.size.y / 650.0), 24, 80)
        var tries2 := 0
        while specks.size() < want_s and tries2 < 400:
            tries2 += 1
            var pt2 := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
            if not Geometry2D.is_point_in_polygon(pt2, poly2):
                continue
            var kind2 := int(loc["biome"])
            if int(loc["second"]) >= 0 and rng.randf() < 0.25:
                kind2 = int(loc["second"])
            specks.append([kind2, pt2, rng.randf_range(0.9, 1.4), int(rng.randi() % 4)])
        _specks.append(specks)

    # стежки між пов'язаними локаціями
    _roads = []
    for i in range(Locations.DATA.size()):
        var loc3: Dictionary = Locations.DATA[i]
        for rid in loc3["req"]:
            var j := -1
            for k in range(Locations.DATA.size()):
                if String(Locations.DATA[k]["id"]) == String(rid):
                    j = k
            if j < 0:
                continue
            rng.seed = hash(String(loc3["id"]) + String(rid))
            var p0: Vector2 = _centers[j]
            var p2: Vector2 = _centers[i]
            var dir := (p2 - p0)
            var perp := Vector2(-dir.y, dir.x).normalized()
            var ctrl := (p0 + p2) * 0.5 + perp * rng.randf_range(-45.0, 45.0)
            var pts := PackedVector2Array()
            var steps := 24
            for s in range(steps + 1):
                var u := float(s) / float(steps)
                pts.append(p0 * (1.0 - u) * (1.0 - u) + ctrl * 2.0 * u * (1.0 - u) + p2 * u * u)
            _roads.append([i, j, pts])

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
        _:
            if v == 3:
                c.draw_line(p, p + Vector2(3.0, 1.0) * s, _ca(Color(0.04, 0.03, 0.03), 0.7 * a), 0.9)
            else:
                c.draw_circle(p, 1.3 * s, Color(0.40, 0.03, 0.03, 0.55 * a))

func _fill_color(loc: Dictionary) -> Color:
    var base: Color = Biomes.DATA[int(loc["biome"])]["map"]
    var col := PARCH.lerp(base, 0.30)
    if GameState.conquered.has(String(loc["id"])):
        col = col.lerp(Color(0.35, 0.60, 0.30), 0.22)
    elif not GameState.is_unlocked(loc):
        col = col.lerp(Color(0.20, 0.19, 0.19), 0.62)
    return col

func _draw_terrain() -> void:
    var c := terrain
    # землі районів: темніший край + світліші кільця всередині
    for i in range(_cells.size()):
        var loc: Dictionary = Locations.DATA[i]
        var unlocked := GameState.is_unlocked(loc)
        var base := _fill_color(loc)
        var edge_col := base.darkened(0.16)
        edge_col.a = 0.66 if unlocked else 0.82
        if _cells[i].size() >= 3:
            c.draw_colored_polygon(_cells[i], edge_col)
        var light := base.lightened(0.14)
        light.a = 0.11 if unlocked else 0.06
        for r in _rings[i]:
            c.draw_colored_polygon(r, light)
    # дрібні деталі землі, потім великі малюнки (за вертикаллю, щоб нижні перекривали верхні)
    for i in range(_cells.size()):
        var unl := GameState.is_unlocked(Locations.DATA[i])
        var a := 0.95 if unl else 0.45
        for sp in _specks[i]:
            _speck(c, int(sp[0]), sp[1], float(sp[2]), int(sp[3]), a)
    for i in range(_cells.size()):
        var unl2 := GameState.is_unlocked(Locations.DATA[i])
        var a2 := 0.95 if unl2 else 0.45
        for it in _doodles[i]:
            _doodle(c, int(it[0]), it[1], float(it[2]), float(it[3]), a2, int(it[4]))
    # стежки
    for r in _roads:
        var i1: int = r[0]
        var j1: int = r[1]
        var pts: PackedVector2Array = r[2]
        var open1 := GameState.is_unlocked(Locations.DATA[i1])
        var done_prev := GameState.conquered.has(String(Locations.DATA[j1]["id"]))
        var col := Color(0.62, 0.50, 0.30, 0.9)
        if not open1:
            col = Color(0.35, 0.33, 0.30, 0.6)
        elif done_prev:
            col = Color(0.75, 0.12, 0.10, 0.95)
        c.draw_polyline(pts, Color(0, 0, 0, 0.28), 5.0)
        for k in range(0, pts.size() - 1, 2):
            c.draw_line(pts[k], pts[k + 1], col, 2.4)
    # межі районів
    for i in range(_cells.size()):
        var edge: PackedVector2Array = _cells[i].duplicate()
        if edge.size() < 3:
            continue
        edge.append(edge[0])
        c.draw_polyline(edge, INK, 2.6)

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

    # виділення районів
    for i in range(_cells.size()):
        var id := String(Locations.DATA[i]["id"])
        if _cells[i].size() < 3:
            continue
        if id != selected and id != hovered:
            continue
        var sp := _tpoly(_cells[i])
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

        # табличка з назвою
        var name_s := String(loc["name"])
        var tw := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        var pw := tw + 14.0
        var px := clampf(p.x - pw * 0.5, 6.0, maxf(6.0, view.size.x - 6.0 - pw))
        var py := minf(p.y + rad + 4.0, view.size.y - 34.0)
        var sb := _sb_lock
        var tcol := Color(0.62, 0.62, 0.66)
        if done:
            sb = _sb_done
            tcol = Color(0.78, 0.96, 0.74)
        elif unlocked:
            sb = _sb_open
            tcol = Color(0.98, 0.88, 0.55)
        c.draw_style_box(sb, Rect2(px, py, pw, 20.0))
        c.draw_string(font, Vector2(px + 8.0, py + 15.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
        c.draw_string(font, Vector2(px + 7.0, py + 14.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)

        # складність (крапки); після Замку епіцентру перші red крапок — яскраво-червоні й більші («кривава» складність)
        var tier := int(loc["tier"])
        var red := Locations.red_skulls(loc)
        var sx := px + pw * 0.5 - float(tier) * 3.5 + 1.75
        for n in range(tier):
            var dc := Color(0.85, 0.15, 0.12)
            if not unlocked:
                dc = Color(0.35, 0.35, 0.38)
            elif done:
                dc = Color(0.35, 0.70, 0.35)
            var dr := 2.2
            if red > 0:
                if n < red:
                    dr = 3.0
                    dc = Color(1.0, 0.05, 0.03) if unlocked else Color(0.55, 0.18, 0.18)
                    c.draw_circle(Vector2(sx + 7.0 * float(n), py + 26.0), dr + 1.4, Color(0.25, 0.0, 0.0, 0.9))
                else:
                    dc = Color(0.88, 0.80, 0.68) if unlocked else Color(0.35, 0.35, 0.38)    # решта «білих» черепів
            c.draw_circle(Vector2(sx + 7.0 * float(n), py + 26.0), dr, dc)

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
    var title := "Карта локацій"
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
    var hint := "Колесо миші — масштаб   •   Перетягуйте мишею — рух карти"
    var hfs := 12
    var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
    var hr := Rect2(cx - (hw + 24.0) * 0.5, m.end.y + 11.0, hw + 24.0, 20.0)
    c.draw_style_box(_plate(Color(0.12, 0.07, 0.04, 0.96), Color(0.80, 0.60, 0.20)), hr)
    c.draw_string(font, Vector2(hr.position.x + 13.0, hr.position.y + 15.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(0, 0, 0, 0.8))
    c.draw_string(font, Vector2(hr.position.x + 12.0, hr.position.y + 14.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(0.93, 0.87, 0.72))
