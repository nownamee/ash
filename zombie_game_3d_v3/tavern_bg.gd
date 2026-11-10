extends Control
# Фон меню: похмура середньовічна таверна (як на референсі).
# Кам'яна стіна, дубовий каркас зі стовпом, балкою й розкосом, обвиті плющем; решітка з плющем,
# чоловік за столом зі свічкою, кухоль, табурет, бочки, ліхтар на ланцюгу, підлога з дошок,
# важкий стіл на передньому плані. Свічка й ліхтар миготять, у повітрі літає пил.
# Усе малюється кодом: стіна, підлога, решітка й балки — шейдером, предмети — у _draw_*.
#
# Координати сцени — частки екрана (0..1). Менш «чіпайте» константи нижче, якщо хочете зсунути предмети.

const GameState = preload("res://game_state.gd")

const POST_X := 0.545      # вертикальний стовп
const BEAM_Y := 0.30       # горизонтальна балка
const FLOOR_Y := 0.77      # де починається підлога
const TABLE_Y := 0.705     # стільниця (задній край)
const MAN_X := 0.705       # чоловік за столом
const CANDLE_X := 0.655    # свічка
const LANT_X := 0.80       # ліхтар на ланцюгу
const TROPHY_X := 0.872    # кубок на передньому столі (біля лицаря)
const TROPHY_Y := 0.928    # де кубок стоїть на столі
const TRAY_X := 0.820      # піднос із пивом на столі офіціанта

const SHADER := """
shader_type canvas_item;
uniform float time = 0.0;
uniform float aspect = 1.78;

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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}
float seg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void fragment() {
    vec2 uv = UV;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float floor_y = 0.77;
    float px = 0.545;
    float beam_y = 0.30;

    // --- кам'яна стіна ---
    vec2 g = vec2(p.x * 7.0, p.y * 13.0);
    float row = floor(g.y);
    g.x += mod(row, 2.0) * 0.5;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float edge = min(min(f.x, 1.0 - f.x) * 1.6, min(f.y, 1.0 - f.y) * 3.2);
    float mortar = 1.0 - smoothstep(0.04, 0.13, edge);
    vec3 stone = mix(vec3(0.19, 0.15, 0.11), vec3(0.37, 0.29, 0.21), hash(id));
    stone *= 0.70 + 0.55 * fbm(p * 14.0);
    stone *= 0.78 + 0.32 * smoothstep(0.0, 0.40, edge);
    vec3 col = mix(stone, vec3(0.045, 0.035, 0.028), mortar);

    // --- підлога з дощок у перспективі ---
    if (uv.y > floor_y) {
        float fy = uv.y - 0.69;
        float u = (uv.x - 0.5) / fy;
        float v = 1.0 / fy;
        float colw = 2.6;
        float bx = floor(u * colw);
        float off = hash(vec2(bx, 3.0)) * 3.0;
        float by = floor(v * 1.1 + off);
        vec3 wd = mix(vec3(0.07, 0.045, 0.028), vec3(0.19, 0.12, 0.065), hash(vec2(bx, by)));
        wd *= 0.62 + 0.55 * fbm(vec2(u * 9.0, v * 1.4));
        float fx = fract(u * colw);
        float gapx = smoothstep(0.0, 0.06, min(fx, 1.0 - fx));
        float gapy = smoothstep(0.0, 0.07, fract(v * 1.1 + off));
        col = wd * gapx * (0.45 + 0.55 * gapy);
        if (uv.y < floor_y + 0.012) {
            col = vec3(0.05, 0.035, 0.025);
        }
    }

    // --- решітка з дерева (справа) ---
    if (uv.x > 0.80 && uv.x < 0.975 && uv.y > 0.36 && uv.y < 0.765) {
        vec2 q = p * 14.0;
        float d1 = abs(fract(q.x + q.y) - 0.5);
        float d2 = abs(fract(q.x - q.y) - 0.5);
        float lat = 1.0 - step(0.10, min(d1, d2));
        vec3 lw = mix(vec3(0.10, 0.06, 0.035), vec3(0.28, 0.18, 0.10), fbm(p * 40.0));
        col = mix(vec3(0.02, 0.018, 0.015), lw, lat);
        float inx = min(uv.x - 0.80, 0.975 - uv.x);
        float iny = min(uv.y - 0.36, 0.765 - uv.y);
        if (min(inx, iny) < 0.012) {
            col = lw * 1.1;
        }
    }

    // --- вертикальний стовп ---
    if (abs(uv.x - px) < 0.020 && uv.y < floor_y) {
        float w = (uv.x - (px - 0.020)) / 0.040;
        vec3 wd2 = mix(vec3(0.09, 0.055, 0.03), vec3(0.27, 0.16, 0.085), fbm(vec2(uv.x * 90.0, uv.y * 4.0)));
        float shade = smoothstep(0.0, 0.5, w) * (1.0 - smoothstep(0.5, 1.0, w));
        col = wd2 * (0.45 + 0.7 * shade);
    }

    // --- горизонтальна балка й розкіс ---
    float inbeam = 0.0;
    float ebeam = 2.0;
    if (uv.x > px - 0.02 && abs(uv.y - beam_y) < 0.028) {
        inbeam = 1.0;
        ebeam = abs(uv.y - beam_y) / 0.028;
    }
    if (uv.x > px && seg(p, vec2((px + 0.01) * aspect, 0.52), vec2(0.80 * aspect, 0.33)) < 0.012) {
        inbeam = 1.0;
    }
    if (inbeam > 0.5) {
        vec3 bw = mix(vec3(0.09, 0.055, 0.03), vec3(0.29, 0.17, 0.085), fbm(vec2(uv.x * 6.0, uv.y * 80.0)));
        col = bw * (0.6 + 0.5 * clamp(1.0 - ebeam * ebeam, 0.0, 1.0));
    }

    // --- світло: свічка на столі, ліхтар, слабка холодна підсвітка зверху ---
    float flick = 1.0 + 0.10 * sin(time * 11.0) + 0.06 * sin(time * 23.0 + 1.0) + 0.04 * sin(time * 5.0);
    vec2 cpos = vec2(0.655 * aspect, 0.66);
    float dc = length(p - cpos);
    float light_c = exp(-dc * dc * 4.5) * flick;
    float flick2 = 1.0 + 0.05 * sin(time * 3.0) + 0.03 * sin(time * 7.3 + 2.0);
    vec2 lpos = vec2(0.80 * aspect, 0.42);
    float dl = length(p - lpos);
    float light_l = exp(-dl * dl * 6.0) * flick2;
    vec3 warm = vec3(1.0, 0.70, 0.36);
    vec3 amb = vec3(0.15, 0.13, 0.14);
    col *= amb + warm * (light_c * 1.45 + light_l * 0.95);

    // --- віньєтка й затемнення вгорі ---
    vec2 q2 = uv - 0.5;
    col *= 1.0 - 0.80 * smoothstep(0.22, 0.85, length(q2 * vec2(1.0, 1.1)));
    col *= 0.60 + 0.40 * smoothstep(0.0, 0.40, uv.y);
    COLOR = vec4(col, 1.0);
}
"""

var t := 0.0
var back: ColorRect
var stat: Control   # малюється один раз (плющ, меблі, чоловік)
var dyn: Control    # малюється щокадру (полум'я, світло, пил)
var kn: Control     # лицар у плащі: малюється щокадру (плащ погойдується), між меблями й переднім столом
var front: Control  # передній стіл (малюється поверх лицаря)
var _leaves: Array = []
var _strands: Array = []
var _motes: Array = []
var has_knight := false   # після «Мертвого мегаполіса»: лицар за столиком у правому куті
var has_bar := false      # після «Давнього форту»: барна стійка з фігуркою замка
var has_trophy := false   # після «Замку епіцентру»: золотий кубок переможця на столі біля лицаря
var has_ship_bell := false
var has_cracked_bell := false
var has_black_mirror := false
var has_mechanical_heart := false

func _refresh_progress() -> void:
    has_knight = GameState.conquered.has("loc13")
    has_bar = GameState.conquered.has("loc10")
    has_trophy = GameState.conquered.has("loc12")
    has_ship_bell = GameState.conquered.has("loc32")
    has_cracked_bell = GameState.conquered.has("loc37")
    has_black_mirror = GameState.conquered.has("loc42")
    has_mechanical_heart = GameState.conquered.has("loc47")

func _on_visibility() -> void:
    _refresh_progress()
    if stat != null:
        stat.queue_redraw()
    if front != null:
        front.queue_redraw()

func _ready() -> void:
    _refresh_progress()
    visibility_changed.connect(_on_visibility)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    back = ColorRect.new()
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    back.material = m
    add_child(back)

    stat = Control.new()
    stat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stat.draw.connect(_draw_static)
    add_child(stat)

    kn = Control.new()
    kn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    kn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    kn.draw.connect(_draw_knight_layer)
    add_child(kn)

    front = Control.new()
    front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    front.mouse_filter = Control.MOUSE_FILTER_IGNORE
    front.draw.connect(_draw_front_layer)
    add_child(front)

    dyn = Control.new()
    dyn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dyn.draw.connect(_draw_dynamic)
    add_child(dyn)

    resized.connect(func() -> void:
        stat.queue_redraw()
        front.queue_redraw())

    var rng := RandomNumberGenerator.new()
    rng.seed = 4242
    # плющ на стовпі
    for i in range(60):
        _leaves.append([Vector2(POST_X + rng.randf_range(-0.026, 0.026), rng.randf_range(0.0, 0.64)), rng.randf() * TAU, rng.randf_range(8.0, 14.0), rng.randf()])
    # плющ на балці
    for i in range(120):
        _leaves.append([Vector2(rng.randf_range(POST_X, 1.0), BEAM_Y + rng.randf_range(-0.038, 0.038)), rng.randf() * TAU, rng.randf_range(8.0, 14.0), rng.randf()])
    # плющ на розкосі
    for i in range(34):
        var u := rng.randf()
        var bp := Vector2(lerpf(POST_X + 0.01, 0.80, u), lerpf(0.52, 0.33, u))
        _leaves.append([bp + Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.02, 0.02)), rng.randf() * TAU, rng.randf_range(7.0, 12.0), rng.randf()])
    # густий плющ на решітці (більше внизу)
    for i in range(210):
        var ly := 0.775 - 0.40 * pow(rng.randf(), 1.7)
        _leaves.append([Vector2(rng.randf_range(0.795, 0.98), ly), rng.randf() * TAU, rng.randf_range(8.0, 15.0), rng.randf()])
    # ліани, що звисають із балки
    for i in range(11):
        _strands.append([rng.randf_range(0.57, 0.99), rng.randf_range(0.05, 0.20), rng.randf() * 6.0])
    for i in range(34):
        _motes.append([rng.randf(), rng.randf(), rng.randf_range(0.004, 0.012), rng.randf() * 6.0])

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    t += delta
    var sm := back.material as ShaderMaterial
    sm.set_shader_parameter("time", t)
    sm.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
    dyn.queue_redraw()
    if has_knight:
        kn.queue_redraw()

# ================= Допоміжне малювання =================
func _ell(c: Control, p: Vector2, rx: float, ry: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(18):
        var ang := TAU * float(i) / 18.0
        pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
    c.draw_colored_polygon(pts, col)

func _leaf(c: Control, p: Vector2, ang: float, ln: float, col: Color) -> void:
    var d := Vector2(cos(ang), sin(ang))
    var n := Vector2(-d.y, d.x)
    c.draw_colored_polygon(PackedVector2Array([p, p + d * ln * 0.5 + n * ln * 0.28, p + d * ln, p + d * ln * 0.5 - n * ln * 0.28]), col)
    c.draw_line(p, p + d * ln * 0.9, Color(col.r * 0.6, col.g * 0.7, col.b * 0.6, 0.7), 1.0)

func _quad(c: Control, a: Vector2, b: Vector2, cc: Vector2, d: Vector2, col: Color) -> void:
    c.draw_colored_polygon(PackedVector2Array([a, b, cc, d]), col)

# ================= Статична частина =================
func _draw_static() -> void:
    var c := stat
    var w := size.x
    var h := size.y
    var S := h / 720.0

    # ліани з балки (під листям)
    for s in _strands:
        var x: float = float(s[0]) * w
        var ln: float = float(s[1]) * h
        var y0 := (BEAM_Y + 0.025) * h
        c.draw_line(Vector2(x, y0), Vector2(x + 3.0 * sin(float(s[2])), y0 + ln), Color(0.10, 0.18, 0.07), 2.0)
        for i in range(5):
            var u := float(i + 1) / 5.0
            var p := Vector2(x + 3.0 * sin(float(s[2])) * u, y0 + ln * u)
            _leaf(c, p, 0.5 + 0.15 * float(i % 2), 9.0 * S, Color(0.17, 0.38, 0.12))
            _leaf(c, p, PI - 0.5 - 0.15 * float(i % 2), 9.0 * S, Color(0.13, 0.31, 0.10))

    # плющ по стовпу, балці, розкосу й решітці
    for lf in _leaves:
        var pos: Vector2 = lf[0]
        var ph: float = lf[3]
        var col := Color(0.10 + 0.11 * ph, 0.28 + 0.20 * ph, 0.08 + 0.05 * ph)
        _leaf(c, Vector2(pos.x * w, pos.y * h), float(lf[1]), float(lf[2]) * S, col)

    _draw_lantern(c, w, h, S)
    _draw_campaign_relics(c, w, h, S)
    _draw_man(c, w, h, S)
    _draw_table(c, w, h, S)
    _draw_barrels(c, w, h, S)
    # табурет посеред зали забирає лицар (сидить на ньому за столиком у правому куті)
    if not has_knight:
        _draw_stool(c, w, h, S)

func _draw_knight_layer() -> void:
    if has_knight:
        _draw_knight(kn, kn.size.x, kn.size.y, kn.size.y / 720.0)

func _draw_campaign_relics(c: Control, w: float, h: float, S: float) -> void:
    if not (has_ship_bell or has_cracked_bell or has_black_mirror or has_mechanical_heart):
        return
    var shelf_y := 0.625 * h
    var left := 0.095 * w
    var right := 0.535 * w
    c.draw_rect(Rect2(left, shelf_y, right - left, 7.0 * S), Color(0.075, 0.043, 0.022))
    c.draw_rect(Rect2(left, shelf_y, right - left, 2.0 * S), Color(0.48, 0.30, 0.14))
    for x in [0.12, 0.51]:
        c.draw_line(Vector2(x * w, shelf_y + 7.0 * S), Vector2(x * w, shelf_y + 17.0 * S), Color(0.18, 0.10, 0.05), 3.0 * S)
    if has_ship_bell:
        _draw_mini_relic(c, Vector2(0.16 * w, shelf_y), 0, S)
    if has_cracked_bell:
        _draw_mini_relic(c, Vector2(0.27 * w, shelf_y), 1, S)
    if has_black_mirror:
        _draw_mini_relic(c, Vector2(0.38 * w, shelf_y), 2, S)
    if has_mechanical_heart:
        _draw_mini_relic(c, Vector2(0.49 * w, shelf_y), 3, S)

func _draw_mini_relic(c: Control, org: Vector2, kind: int, S: float) -> void:
    match kind:
        0, 1:
            var bronze := Color(0.48, 0.32, 0.12) if kind == 0 else Color(0.38, 0.22, 0.13)
            c.draw_arc(org + Vector2(0, -23.0 * S), 3.0 * S, PI, TAU, 10, Color(0.25, 0.20, 0.12), 1.6 * S)
            var bell := PackedVector2Array([
                org + Vector2(-5.0, -20.0) * S, org + Vector2(-4.0, -29.0) * S,
                org + Vector2(-2.0, -32.0) * S, org + Vector2(2.0, -32.0) * S,
                org + Vector2(4.0, -29.0) * S, org + Vector2(5.0, -20.0) * S,
                org + Vector2(8.0, -17.0) * S, org + Vector2(-8.0, -17.0) * S,
            ])
            c.draw_colored_polygon(bell, bronze)
            bell.append(bell[0])
            c.draw_polyline(bell, Color(0.78, 0.58, 0.27), 1.0 * S)
            c.draw_line(org + Vector2(-9.0, -16.0) * S, org + Vector2(9.0, -16.0) * S, Color(0.69, 0.49, 0.22), 1.5 * S)
            c.draw_circle(org + Vector2(0, -15.0) * S, 1.5 * S, Color(0.24, 0.17, 0.08))
            if kind == 0:
                c.draw_line(org + Vector2(0, -29.0) * S, org + Vector2(1.5, -19.0) * S, Color(0.82, 0.70, 0.43), 1.0 * S)
                c.draw_circle(org + Vector2(0, -33.0) * S, 2.0 * S, Color(0.61, 0.44, 0.21))
            else:
                c.draw_line(org + Vector2(0, -29.0) * S, org + Vector2(-2.0, -25.0) * S, Color(0.14, 0.08, 0.055), 1.3 * S)
                c.draw_line(org + Vector2(-2.0, -25.0) * S, org + Vector2(1.0, -22.0) * S, Color(0.96, 0.65, 0.30), 1.0 * S)
                c.draw_line(org + Vector2(1.0, -22.0) * S, org + Vector2(-1.0, -18.0) * S, Color(0.14, 0.08, 0.055), 1.0 * S)
        2:
            c.draw_arc(org + Vector2(0, -23.0 * S), 9.0 * S, PI, TAU, 14, Color(0.39, 0.37, 0.49), 2.3 * S)
            c.draw_line(org + Vector2(-9.0, -23.0) * S, org + Vector2(-9.0, -2.0) * S, Color(0.39, 0.37, 0.49), 2.3 * S)
            c.draw_line(org + Vector2(9.0, -23.0) * S, org + Vector2(9.0, -2.0) * S, Color(0.39, 0.37, 0.49), 2.3 * S)
            c.draw_line(org + Vector2(-11.0, -2.0) * S, org + Vector2(11.0, -2.0) * S, Color(0.58, 0.55, 0.67), 2.0 * S)
            _ell(c, org + Vector2(0, -15.0 * S), 6.0 * S, 8.0 * S, Color(0.045, 0.035, 0.065))
            c.draw_line(org + Vector2(0, -20.0 * S), org + Vector2(-3.0 * S, -14.0 * S), Color(0.75, 0.77, 0.92), 1.0 * S)
            c.draw_line(org + Vector2(-3.0 * S, -14.0 * S), org + Vector2(2.0 * S, -11.0 * S), Color(0.75, 0.77, 0.92), 1.0 * S)
        3:
            var heart := PackedVector2Array([
                org + Vector2(0, -5) * S, org + Vector2(-9, -17) * S, org + Vector2(-8, -23) * S,
                org + Vector2(-3, -24) * S, org + Vector2(0, -20) * S, org + Vector2(4, -24) * S,
                org + Vector2(9, -22) * S, org + Vector2(8, -17) * S,
            ])
            c.draw_colored_polygon(heart, Color(0.43, 0.18, 0.12))
            heart.append(heart[0])
            c.draw_polyline(heart, Color(0.80, 0.48, 0.25), 1.3 * S)
            _ell(c, org + Vector2(0, -17.0 * S), 3.0 * S, 3.0 * S, Color(0.14, 0.10, 0.08))
            c.draw_arc(org + Vector2(0, -17.0 * S), 3.2 * S, 0.0, TAU, 10, Color(0.91, 0.60, 0.29), 1.0 * S)
            c.draw_line(org + Vector2(0, -21.0 * S), org + Vector2(0, -27.0 * S), Color(0.75, 0.44, 0.24), 1.4 * S)
            c.draw_line(org + Vector2(-6.0 * S, -11.0 * S), org + Vector2(-10.0 * S, -8.0 * S), Color(0.75, 0.44, 0.24), 1.4 * S)

func _draw_front_layer() -> void:
    _draw_front_table(front, front.size.x, front.size.y, front.size.y / 720.0)
    if has_trophy:
        _draw_trophy(front, front.size.x, front.size.y, front.size.y / 720.0)

# ліхтар на ланцюгу з балки
func _draw_lantern(c: Control, w: float, h: float, S: float) -> void:
    var x := LANT_X * w
    var y0 := (BEAM_Y + 0.028) * h
    var y1 := 0.395 * h
    # ланцюг
    var y := y0
    while y < y1:
        c.draw_arc(Vector2(x, y + 3.0 * S), 3.2 * S, 0.0, TAU, 8, Color(0.30, 0.28, 0.26), 1.6)
        y += 5.0 * S
    # дашок і корпус
    c.draw_colored_polygon(PackedVector2Array([Vector2(x - 15.0 * S, y1 + 8.0 * S), Vector2(x, y1 - 6.0 * S), Vector2(x + 15.0 * S, y1 + 8.0 * S)]), Color(0.09, 0.08, 0.08))
    c.draw_rect(Rect2(x - 12.0 * S, y1 + 8.0 * S, 24.0 * S, 32.0 * S), Color(0.55, 0.30, 0.08))
    c.draw_rect(Rect2(x - 12.0 * S, y1 + 8.0 * S, 24.0 * S, 32.0 * S), Color(0.07, 0.06, 0.06), false, 2.5)
    c.draw_line(Vector2(x, y1 + 8.0 * S), Vector2(x, y1 + 40.0 * S), Color(0.07, 0.06, 0.06), 2.0)
    c.draw_rect(Rect2(x - 14.0 * S, y1 + 40.0 * S, 28.0 * S, 4.0 * S), Color(0.09, 0.08, 0.08))

# чоловік за столом (3/4 спереду), підсвічений свічкою зліва
func _draw_man(c: Control, w: float, h: float, S: float) -> void:
    var cx := MAN_X * w
    var ty := TABLE_Y * h
    var hy := ty - 150.0 * S
    var skin := Color(0.62, 0.44, 0.32)
    var shirt := Color(0.24, 0.14, 0.08)
    var hair := Color(0.13, 0.08, 0.05)

    # спинка стільця за ним
    c.draw_rect(Rect2(cx - 54.0 * S, hy + 12.0 * S, 108.0 * S, ty - hy), Color(0.075, 0.045, 0.028))
    c.draw_rect(Rect2(cx - 54.0 * S, hy + 12.0 * S, 7.0 * S, ty - hy), Color(0.15, 0.09, 0.05))
    c.draw_rect(Rect2(cx + 47.0 * S, hy + 12.0 * S, 7.0 * S, ty - hy), Color(0.04, 0.025, 0.015))

    # --- похмурий, але дорогий одяг: майже чорний оксамитовий каптан, темно-бордова камізелька,
    #     потьмянілий золотий позумент, вицвілий комір, ланцюг зі старого золота ---
    var velvet := Color(0.085, 0.07, 0.095)
    var gold := Color(0.56, 0.43, 0.17)
    var gold_dk := Color(0.27, 0.19, 0.07)
    var lace := Color(0.60, 0.56, 0.50)
    var vest := Color(0.17, 0.035, 0.06)
    var tb := hy + 38.0 * S

    # рукави (зад): оксамит із золотою оздобою
    c.draw_line(Vector2(cx - 40.0 * S, hy + 50.0 * S), Vector2(cx - 30.0 * S, ty + 6.0 * S), velvet.lightened(0.08), 19.0 * S)
    c.draw_line(Vector2(cx - 40.0 * S, hy + 50.0 * S), Vector2(cx - 30.0 * S, ty + 6.0 * S), Color(gold.r, gold.g, gold.b, 0.55), 2.0 * S)
    c.draw_line(Vector2(cx + 40.0 * S, hy + 50.0 * S), Vector2(cx + 36.0 * S, ty + 4.0 * S), velvet.darkened(0.25), 19.0 * S)
    c.draw_line(Vector2(cx + 40.0 * S, hy + 50.0 * S), Vector2(cx + 36.0 * S, ty + 4.0 * S), Color(gold_dk.r, gold_dk.g, gold_dk.b, 0.7), 2.0 * S)
    # тулуб: каптан
    _quad(c, Vector2(cx - 44.0 * S, tb), Vector2(cx + 44.0 * S, tb), Vector2(cx + 52.0 * S, ty + 2.0), Vector2(cx - 52.0 * S, ty + 2.0), velvet)
    _quad(c, Vector2(cx - 44.0 * S, tb), Vector2(cx - 4.0 * S, tb), Vector2(cx - 4.0 * S, ty + 2.0), Vector2(cx - 52.0 * S, ty + 2.0), Color(0.60, 0.42, 0.34, 0.14))
    _quad(c, Vector2(cx + 8.0 * S, tb), Vector2(cx + 44.0 * S, tb), Vector2(cx + 52.0 * S, ty + 2.0), Vector2(cx + 8.0 * S, ty + 2.0), Color(0, 0, 0, 0.35))
    # камізелька з брокату по центру
    var vtop := 21.0 * S
    var vbot := 27.0 * S
    _quad(c, Vector2(cx - vtop, tb), Vector2(cx + vtop, tb), Vector2(cx + vbot, ty + 2.0), Vector2(cx - vbot, ty + 2.0), vest)
    _quad(c, Vector2(cx - vtop, tb), Vector2(cx - 4.0 * S, tb), Vector2(cx - 4.0 * S, ty + 2.0), Vector2(cx - vbot, ty + 2.0), Color(0.55, 0.22, 0.22, 0.16))
    c.draw_line(Vector2(cx - vtop, tb), Vector2(cx - vbot, ty + 2.0), gold, 2.2 * S)
    c.draw_line(Vector2(cx + vtop, tb), Vector2(cx + vbot, ty + 2.0), gold_dk, 2.2 * S)
    # візерунок брокату: золоті ромби
    var row := 0
    var vy := tb + 10.0 * S
    while vy < ty - 4.0 * S:
        for k in range(-1, 2):
            var rx := cx + (float(k) * 13.0 + (6.5 if row % 2 == 1 else 0.0)) * S
            if absf(rx - cx) < 20.0 * S:
                c.draw_colored_polygon(PackedVector2Array([Vector2(rx, vy - 4.0 * S), Vector2(rx + 3.0 * S, vy), Vector2(rx, vy + 4.0 * S), Vector2(rx - 3.0 * S, vy)]), Color(gold.r, gold.g, gold.b, 0.32))
        vy += 11.0 * S
        row += 1
    # золоті ґудзики
    var by2 := tb + 22.0 * S
    while by2 < ty - 6.0 * S:
        c.draw_circle(Vector2(cx, by2), 2.6 * S, gold_dk)
        c.draw_circle(Vector2(cx - 0.6 * S, by2 - 0.6 * S), 1.7 * S, gold)
        c.draw_circle(Vector2(cx - 1.0 * S, by2 - 1.0 * S), 0.7 * S, Color(0.80, 0.70, 0.48))
        by2 += 17.0 * S
    # золота облямівка каптана вздовж плеча й еполенти
    c.draw_line(Vector2(cx - 44.0 * S, tb), Vector2(cx - vtop, tb), gold, 2.0 * S)
    c.draw_line(Vector2(cx + vtop, tb), Vector2(cx + 44.0 * S, tb), gold_dk, 2.0 * S)
    for sd in [-1.0, 1.0]:
        var ex: float = cx + float(sd) * 43.0 * S
        _ell(c, Vector2(ex, tb + 2.0 * S), 11.0 * S, 5.5 * S, gold_dk)
        _ell(c, Vector2(ex - float(sd) * 1.0 * S, tb + 1.0 * S), 9.0 * S, 4.2 * S, gold)
        for fk in range(5):
            var fx: float = ex + (float(fk) - 2.0) * 3.8 * S
            c.draw_line(Vector2(fx, tb + 6.0 * S), Vector2(fx, tb + 13.0 * S), gold_dk, 1.4 * S)
    # шия
    c.draw_rect(Rect2(cx - 9.0 * S, hy + 14.0 * S, 18.0 * S, 24.0 * S), skin.darkened(0.35))
    # мереживний комір (жабо): хвилястий вінець навколо шиї
    for k in range(-5, 6):
        var lx2 := cx + float(k) * 4.6 * S
        var ly2 := hy + 33.0 * S + 8.0 * S * (1.0 - absf(float(k)) / 5.0) * 0.9
        _ell(c, Vector2(lx2, ly2), 5.4 * S, 4.6 * S, lace.darkened(0.12 if k % 2 == 0 else 0.0))
    _ell(c, Vector2(cx, hy + 32.0 * S), 21.0 * S, 7.0 * S, lace)
    c.draw_line(Vector2(cx - 17.0 * S, hy + 33.0 * S), Vector2(cx + 17.0 * S, hy + 33.0 * S), Color(0.55, 0.45, 0.30, 0.5), 1.0)
    # золотий ланцюг із рубіновим медальйоном
    var chain := PackedVector2Array()
    for k in range(15):
        var u2 := float(k) / 14.0
        var chx := lerpf(cx - 27.0 * S, cx + 27.0 * S, u2)
        var chy := hy + 41.0 * S + 38.0 * S * sin(u2 * PI)
        chain.append(Vector2(chx, chy))
    c.draw_polyline(chain, gold_dk, 3.4 * S)
    c.draw_polyline(chain, gold, 2.0 * S)
    for k in range(1, 14):
        c.draw_circle(chain[k], 1.5 * S, Color(0.78, 0.66, 0.40, 0.6))
    var md := Vector2(cx, hy + 79.0 * S)
    c.draw_circle(md, 8.5 * S, gold_dk)
    c.draw_circle(md, 7.0 * S, gold)
    c.draw_circle(md, 4.6 * S, Color(0.28, 0.02, 0.05))
    c.draw_circle(md + Vector2(-1.0, -1.2) * S, 2.3 * S, Color(0.62, 0.12, 0.14))
    c.draw_circle(md + Vector2(-1.6, -1.8) * S, 0.9 * S, Color(0.85, 0.7, 0.7))

    # голова
    _ell(c, Vector2(cx, hy), 21.0 * S, 24.0 * S, skin.darkened(0.28))
    _ell(c, Vector2(cx - 3.0 * S, hy - 1.0 * S), 18.0 * S, 21.0 * S, skin)
    _ell(c, Vector2(cx + 12.0 * S, hy + 2.0 * S), 10.0 * S, 20.0 * S, Color(0, 0, 0, 0.30))
    # волосся: півмісяць над чолом
    var hp := PackedVector2Array()
    for i in range(13):
        var a1 := PI + PI * float(i) / 12.0
        hp.append(Vector2(cx + cos(a1) * 23.0 * S, hy - 2.0 * S + sin(a1) * 27.0 * S))
    for i in range(12, -1, -1):
        var a2 := PI + PI * float(i) / 12.0
        hp.append(Vector2(cx + cos(a2) * 20.0 * S, hy - 9.0 * S + sin(a2) * 8.0 * S))
    c.draw_colored_polygon(hp, hair)
    # борода
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 19.0 * S, hy + 4.0 * S), Vector2(cx - 17.0 * S, hy + 22.0 * S), Vector2(cx, hy + 34.0 * S), Vector2(cx + 17.0 * S, hy + 22.0 * S), Vector2(cx + 19.0 * S, hy + 4.0 * S), Vector2(cx + 11.0 * S, hy + 13.0 * S), Vector2(cx, hy + 10.0 * S), Vector2(cx - 11.0 * S, hy + 13.0 * S)]), hair.lightened(0.04))
    # очі, брови, ніс
    _ell(c, Vector2(cx - 8.0 * S, hy - 2.0 * S), 3.2 * S, 1.8 * S, Color(0.04, 0.025, 0.02))
    _ell(c, Vector2(cx + 8.0 * S, hy - 2.0 * S), 3.2 * S, 1.8 * S, Color(0.04, 0.025, 0.02))
    c.draw_line(Vector2(cx - 12.0 * S, hy - 6.0 * S), Vector2(cx - 4.0 * S, hy - 5.0 * S), hair, 2.0 * S)
    c.draw_line(Vector2(cx + 4.0 * S, hy - 5.0 * S), Vector2(cx + 12.0 * S, hy - 6.0 * S), hair, 2.0 * S)
    c.draw_line(Vector2(cx - 1.0 * S, hy - 1.0 * S), Vector2(cx - 2.0 * S, hy + 6.0 * S), skin.darkened(0.3), 1.6 * S)

# стіл, свічка, кухоль, миска
func _draw_table(c: Control, w: float, h: float, S: float) -> void:
    var ty := TABLE_Y * h
    var x0 := 0.592 * w
    var x1 := 0.868 * w
    var depth := 18.0 * S
    var wood := Color(0.27, 0.16, 0.08)
    if has_bar:
        _draw_bar_body(c, w, h, S)
    else:
        # ніжки
        var fy := 0.80 * h
        c.draw_rect(Rect2(x0 + 8.0 * S, ty + depth + 12.0 * S, 14.0 * S, fy - (ty + depth + 12.0 * S)), Color(0.10, 0.06, 0.035))
        c.draw_rect(Rect2(x1 - 22.0 * S, ty + depth + 12.0 * S, 14.0 * S, fy - (ty + depth + 12.0 * S)), Color(0.07, 0.04, 0.025))
        # фартух і стільниця
        c.draw_rect(Rect2(x0, ty + depth, x1 - x0, 14.0 * S), Color(0.11, 0.065, 0.035))
        _quad(c, Vector2(x0 + 12.0 * S, ty), Vector2(x1 - 12.0 * S, ty), Vector2(x1, ty + depth), Vector2(x0, ty + depth), wood)
        for i in range(1, 7):
            var u := float(i) / 7.0
            c.draw_line(Vector2(lerpf(x0 + 12.0 * S, x1 - 12.0 * S, u), ty), Vector2(lerpf(x0, x1, u), ty + depth), Color(0.07, 0.04, 0.02, 0.8), 1.2)
        c.draw_line(Vector2(x0, ty + depth), Vector2(x1, ty + depth), Color(0.60, 0.40, 0.20, 0.55), 1.4)
    # руки лягають на стіл (мереживні манжети із золотою обшивкою)
    var cx := MAN_X * w
    for cf in [[-30.0, 0.0], [36.0, 0.18]]:
        var cfx: float = cx + float(cf[0]) * S
        var dk: float = float(cf[1])
        _ell(c, Vector2(cfx, ty - 1.0 * S), 13.0 * S, 7.0 * S, Color(0.58, 0.54, 0.48).darkened(dk))
        for k in range(-3, 4):
            _ell(c, Vector2(cfx + float(k) * 3.8 * S, ty + 4.0 * S), 3.6 * S, 3.2 * S, Color(0.54, 0.50, 0.44).darkened(dk))
        _ell(c, Vector2(cfx, ty - 3.0 * S), 11.0 * S, 4.5 * S, Color(0.48, 0.36, 0.13).darkened(dk))
    _ell(c, Vector2(cx - 30.0 * S, ty + 7.0 * S), 9.0 * S, 7.0 * S, Color(0.56, 0.40, 0.29))
    _ell(c, Vector2(cx + 36.0 * S, ty + 6.0 * S), 9.0 * S, 7.0 * S, Color(0.36, 0.25, 0.18))

    if has_bar:
        _draw_castle_figure(c, 0.742 * w, ty, S)
    else:
        # миска з хлібом
        var bx := 0.742 * w
        _ell(c, Vector2(bx, ty + 12.0 * S), 24.0 * S, 6.0 * S, Color(0.38, 0.36, 0.34))
        _ell(c, Vector2(bx, ty + 10.0 * S), 15.0 * S, 8.0 * S, Color(0.55, 0.36, 0.14))
        _ell(c, Vector2(bx - 3.0 * S, ty + 8.0 * S), 7.0 * S, 3.0 * S, Color(0.75, 0.52, 0.24, 0.8))
    # піднос із багатьма кухлями пива відкривається разом із кубком (після «Замку епіцентру»);
    # до того на столі лише один простий кухоль
    if has_trophy:
        _draw_tray(c, TRAY_X * w, ty, S)
    else:
        _draw_beer_mug(c, TRAY_X * w, ty + 12.0 * S, S, 1.0)
    # свічка (тіло; полум'я — у dyn)
    var cdx := CANDLE_X * w
    _ell(c, Vector2(cdx, ty + 10.0 * S), 13.0 * S, 4.0 * S, Color(0.30, 0.27, 0.22))
    c.draw_rect(Rect2(cdx - 5.0 * S, ty - 22.0 * S, 10.0 * S, 31.0 * S), Color(0.82, 0.76, 0.60))
    c.draw_rect(Rect2(cdx - 5.0 * S, ty - 22.0 * S, 3.0 * S, 31.0 * S), Color(1.0, 0.95, 0.80, 0.55))
    c.draw_rect(Rect2(cdx + 2.0 * S, ty - 22.0 * S, 3.0 * S, 31.0 * S), Color(0.35, 0.28, 0.18, 0.5))

# барна стійка замість простого столу: товста стільниця, суцільна дерев'яна панель, латунний поручень
func _draw_bar_body(c: Control, w: float, h: float, S: float) -> void:
    var ty := TABLE_Y * h
    var x0 := 0.578 * w
    var x1 := 0.880 * w
    var depth := 20.0 * S
    var fy := 0.842 * h
    # суцільна лицьова панель з филенками
    c.draw_rect(Rect2(x0, ty + depth, x1 - x0, fy - (ty + depth)), Color(0.115, 0.065, 0.035))
    var n := 8
    for i in range(n):
        var px := lerpf(x0 + 10.0 * S, x1 - 10.0 * S, float(i) / float(n))
        var pw := (x1 - x0 - 20.0 * S) / float(n) - 8.0 * S
        c.draw_rect(Rect2(px + 3.0 * S, ty + depth + 22.0 * S, pw, fy - (ty + depth) - 44.0 * S), Color(0.165, 0.095, 0.05))
        c.draw_rect(Rect2(px + 3.0 * S, ty + depth + 22.0 * S, 3.0 * S, fy - (ty + depth) - 44.0 * S), Color(0.40, 0.25, 0.12, 0.45))
        c.draw_rect(Rect2(px + pw, ty + depth + 22.0 * S, 3.0 * S, fy - (ty + depth) - 44.0 * S), Color(0, 0, 0, 0.35))
    # світло від свічки зліва, тінь справа
    c.draw_rect(Rect2(x0, ty + depth, (x1 - x0) * 0.35, fy - (ty + depth)), Color(1.0, 0.62, 0.25, 0.10))
    c.draw_rect(Rect2(x0 + (x1 - x0) * 0.72, ty + depth, (x1 - x0) * 0.28, fy - (ty + depth)), Color(0, 0, 0, 0.30))
    # цоколь
    c.draw_rect(Rect2(x0 - 4.0 * S, fy - 8.0 * S, x1 - x0 + 8.0 * S, 8.0 * S), Color(0.06, 0.035, 0.02))
    # латунний поручень для ніг
    var ry := fy - 22.0 * S
    c.draw_line(Vector2(x0 + 14.0 * S, ry), Vector2(x1 - 14.0 * S, ry), Color(0.55, 0.40, 0.15), 5.0 * S)
    c.draw_line(Vector2(x0 + 14.0 * S, ry - 1.6 * S), Vector2(x1 - 14.0 * S, ry - 1.6 * S), Color(0.95, 0.80, 0.42, 0.65), 1.4 * S)
    # товста стільниця: верх + лицьовий торець, що виступає
    var wood := Color(0.34, 0.20, 0.10)
    _quad(c, Vector2(x0 + 8.0 * S, ty), Vector2(x1 - 8.0 * S, ty), Vector2(x1 + 8.0 * S, ty + depth), Vector2(x0 - 8.0 * S, ty + depth), wood)
    for i in range(1, 9):
        var u := float(i) / 9.0
        c.draw_line(Vector2(lerpf(x0 + 8.0 * S, x1 - 8.0 * S, u), ty), Vector2(lerpf(x0 - 8.0 * S, x1 + 8.0 * S, u), ty + depth), Color(0.08, 0.045, 0.02, 0.7), 1.2)
    c.draw_rect(Rect2(x0 - 8.0 * S, ty + depth, x1 - x0 + 16.0 * S, 12.0 * S), Color(0.18, 0.10, 0.05))
    c.draw_line(Vector2(x0 - 8.0 * S, ty + depth), Vector2(x1 + 8.0 * S, ty + depth), Color(0.78, 0.52, 0.26, 0.75), 1.6)
    c.draw_line(Vector2(x0 - 8.0 * S, ty + depth + 12.0 * S), Vector2(x1 + 8.0 * S, ty + depth + 12.0 * S), Color(0.04, 0.02, 0.01, 0.8), 1.4)

# фігурка замка на стійці: цоколь, донжон із зубцями, дві вежі, брама, прапорець
func _draw_castle_figure(c: Control, fx: float, ty: float, S: float) -> void:
    var by := ty + 8.0 * S
    var stone := Color(0.50, 0.47, 0.43)
    var dark := Color(0.30, 0.28, 0.26)
    # тінь і цоколь
    _ell(c, Vector2(fx, by + 4.0 * S), 36.0 * S, 7.0 * S, Color(0, 0, 0, 0.35))
    _ell(c, Vector2(fx, by + 1.0 * S), 33.0 * S, 7.0 * S, Color(0.22, 0.20, 0.18))
    c.draw_rect(Rect2(fx - 33.0 * S, by - 6.0 * S, 66.0 * S, 7.0 * S), Color(0.22, 0.20, 0.18))
    _ell(c, Vector2(fx, by - 6.0 * S), 33.0 * S, 7.0 * S, Color(0.34, 0.31, 0.28))
    var gy := by - 6.0 * S
    # вежі з боків
    for sd in [-1.0, 1.0]:
        var tx: float = fx + sd * 23.0 * S
        c.draw_rect(Rect2(tx - 8.0 * S, gy - 34.0 * S, 16.0 * S, 34.0 * S), stone)
        c.draw_rect(Rect2(tx - 8.0 * S, gy - 34.0 * S, 4.0 * S, 34.0 * S), Color(1.0, 0.85, 0.6, 0.22))
        c.draw_rect(Rect2(tx + 3.0 * S, gy - 34.0 * S, 5.0 * S, 34.0 * S), Color(0, 0, 0, 0.30))
        for k in range(3):
            c.draw_rect(Rect2(tx - 8.0 * S + float(k) * 6.0 * S, gy - 40.0 * S, 4.0 * S, 6.0 * S), stone.darkened(0.08))
        c.draw_rect(Rect2(tx - 1.0 * S, gy - 26.0 * S, 2.5 * S, 7.0 * S), Color(0.05, 0.04, 0.03))
    # донжон
    c.draw_rect(Rect2(fx - 14.0 * S, gy - 46.0 * S, 28.0 * S, 46.0 * S), stone.lightened(0.04))
    c.draw_rect(Rect2(fx - 14.0 * S, gy - 46.0 * S, 6.0 * S, 46.0 * S), Color(1.0, 0.85, 0.6, 0.22))
    c.draw_rect(Rect2(fx + 7.0 * S, gy - 46.0 * S, 7.0 * S, 46.0 * S), Color(0, 0, 0, 0.32))
    for k in range(4):
        c.draw_rect(Rect2(fx - 14.0 * S + float(k) * 8.0 * S, gy - 52.0 * S, 5.0 * S, 7.0 * S), stone.lightened(0.02))
    for ry in [-34.0, -22.0]:
        c.draw_line(Vector2(fx - 14.0 * S, gy + ry * S), Vector2(fx + 14.0 * S, gy + ry * S), Color(0, 0, 0, 0.18), 1.0)
    c.draw_rect(Rect2(fx - 2.0 * S, gy - 40.0 * S, 4.0 * S, 9.0 * S), Color(0.05, 0.04, 0.03))
    # брама
    c.draw_rect(Rect2(fx - 5.0 * S, gy - 13.0 * S, 10.0 * S, 13.0 * S), Color(0.07, 0.045, 0.03))
    _ell(c, Vector2(fx, gy - 13.0 * S), 5.0 * S, 4.0 * S, Color(0.07, 0.045, 0.03))
    # прапорець
    c.draw_line(Vector2(fx, gy - 52.0 * S), Vector2(fx, gy - 68.0 * S), dark, 1.6 * S)
    c.draw_colored_polygon(PackedVector2Array([Vector2(fx, gy - 68.0 * S), Vector2(fx + 11.0 * S, gy - 64.0 * S), Vector2(fx, gy - 60.0 * S)]), Color(0.72, 0.16, 0.12))

# Деталь латного обладунку: товста лінія-кінцівка з відблиском свічки зліва й тінню справа.
func _plate_limb(c: Control, p0: Vector2, p1: Vector2, wd: float, base: Color) -> void:
    var d := (p1 - p0).normalized()
    var n := Vector2(-d.y, d.x)
    c.draw_line(p0, p1, base, wd)
    c.draw_line(p0 - n * wd * 0.28, p1 - n * wd * 0.28, Color(0.55, 0.50, 0.50, 0.30), wd * 0.16)
    c.draw_line(p0 + n * wd * 0.38, p1 + n * wd * 0.38, Color(0, 0, 0, 0.35), wd * 0.22)
    c.draw_line(p0 - n * wd * 0.5, p1 - n * wd * 0.5, Color(0.60, 0.40, 0.22, 0.30), 1.2)

# Наплічник із трьох накладних пластин, куполом і шипом. side: -1 — лівий (світліший), +1 — правий.
func _draw_pauldron(c: Control, p: Vector2, K: float, side: float) -> void:
    var tone := 1.0 if side < 0.0 else 0.62
    var plate := Color(0.115, 0.12, 0.138) * tone
    plate.a = 1.0
    for k in range(3):
        var yy := p.y + (12.0 - 6.0 * float(k)) * K
        var rx := (25.0 - 2.0 * float(k)) * K
        _ell(c, Vector2(p.x, yy), rx, 11.0 * K, Color(0.02, 0.02, 0.026))
        _ell(c, Vector2(p.x, yy - 1.2 * K), rx - 1.0 * K, 10.0 * K, plate.lightened(0.04 * float(k)))
        c.draw_arc(Vector2(p.x, yy - 1.2 * K), rx - 1.0 * K, PI * 1.05, PI * 1.95, 14, Color(0.60, 0.55, 0.55, 0.30 * tone), 1.3)
        c.draw_arc(Vector2(p.x, yy + 6.0 * K), rx - 2.0 * K, PI * 0.1, PI * 0.9, 10, Color(0.36, 0.28, 0.12, 0.45 * tone), 1.1)
    _ell(c, Vector2(p.x, p.y - 6.0 * K), 20.0 * K, 13.0 * K, plate.darkened(0.15))
    _ell(c, Vector2(p.x - side * 5.0 * K, p.y - 9.0 * K), 10.0 * K, 5.0 * K, Color(0.65, 0.58, 0.55, 0.22 * tone))
    c.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 4.0 * K, p.y - 15.0 * K), Vector2(p.x + side * 3.0 * K, p.y - 32.0 * K), Vector2(p.x + 5.0 * K, p.y - 15.0 * K)]), plate.darkened(0.1))
    c.draw_circle(Vector2(p.x - 9.0 * K, p.y + 3.0 * K), 1.5 * K, Color(0.40, 0.32, 0.16, 0.8))
    c.draw_circle(Vector2(p.x + 9.0 * K, p.y + 3.0 * K), 1.5 * K, Color(0.40, 0.32, 0.16, 0.8))

# Похмурий лицар у чорненому латному обладунку й закритому шоломі спартанського типу:
# обличчя не видно, лише ледь помітні червоні вогники в прорізах. За спиною звисає червоний плащ
# (ледь погойдується), а меч він носить, як колись:
# над правим плечем стирчить руків'я. Сидить у кріслі за передньою лавою, рука над монетами.
func _draw_knight(c: Control, w: float, h: float, S: float) -> void:
    var K := S * 1.12
    var cx := 0.918 * w
    var ty := (0.895 - 0.027 * ((0.918 - 0.725) / 0.275)) * h     # задній край переднього столу
    var hy := ty - 156.0 * K
    var sw2 := sin(t * 1.7 + 1.3) * 2.0 * K
    var plate := Color(0.105, 0.11, 0.128)
    var plate_lit := Color(0.19, 0.19, 0.22)
    var plate_dk := Color(0.055, 0.057, 0.07)
    var gold := Color(0.36, 0.28, 0.12, 0.6)
    var leather := Color(0.075, 0.048, 0.03)

    # високе чорне крісло за спиною
    c.draw_rect(Rect2(cx - 68.0 * K, hy - 40.0 * K, 136.0 * K, ty - (hy - 40.0 * K)), Color(0.04, 0.025, 0.018))
    c.draw_rect(Rect2(cx - 68.0 * K, hy - 40.0 * K, 7.0 * K, ty - (hy - 40.0 * K)), Color(0.10, 0.06, 0.035))
    c.draw_rect(Rect2(cx - 72.0 * K, hy - 52.0 * K, 144.0 * K, 14.0 * K), Color(0.07, 0.04, 0.025))

    # червоний плащ звисає зі спини: ледь помітно похитується (видно з обох боків від тулуба)
    var cl_top := hy + 40.0 * K
    var cl_len := ty - cl_top + 2.0
    var cl_l := PackedVector2Array()
    var cl_r := PackedVector2Array()
    var cl_hem := PackedVector2Array()
    for i in range(6):
        var cu := float(i) / 5.0
        var csw := (sin(t * 1.2 + cu * 1.6) * 3.2 + sin(t * 0.7 + 0.8) * 1.6) * K * cu
        var half := (58.0 + 30.0 * cu) * K
        cl_l.append(Vector2(cx - half + csw, cl_top + cl_len * cu))
        cl_r.append(Vector2(cx + half + csw, cl_top + cl_len * cu))
    for i in range(9):
        var hu := float(i) / 8.0
        var hx := cl_r[5].x - hu * (cl_r[5].x - cl_l[5].x)
        cl_hem.append(Vector2(hx, ty + 2.0 + sin(t * 1.8 + hu * 7.0) * 2.5 * K))
    var cl_poly := PackedVector2Array()
    for p in cl_l:
        cl_poly.append(p)
    for i in range(1, cl_hem.size() - 1):
        cl_poly.append(cl_hem[cl_hem.size() - 1 - i])
    for i in range(5, -1, -1):
        cl_poly.append(cl_r[i])
    c.draw_colored_polygon(cl_poly, Color(0.30, 0.035, 0.045))
    # світло від свічки зліва, густа тінь справа
    c.draw_colored_polygon(PackedVector2Array([cl_l[0], Vector2(cx - 20.0 * K, cl_top), Vector2(cx - 24.0 * K + (cl_l[5].x - (cx - 88.0 * K)) * 0.5, ty + 2.0), cl_l[5], cl_l[3], cl_l[1]]), Color(0.75, 0.22, 0.14, 0.18))
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 14.0 * K, cl_top), cl_r[0], cl_r[1], cl_r[2], cl_r[3], cl_r[4], cl_r[5], Vector2(cx + 20.0 * K + (cl_r[5].x - (cx + 88.0 * K)) * 0.5, ty + 2.0)]), Color(0, 0, 0, 0.38))
    # складки
    for fi in range(7):
        var fu := float(fi) / 6.0
        var x_top := cx - 56.0 * K + fu * 112.0 * K
        var x_bot := lerpf(cl_l[5].x, cl_r[5].x, fu)
        c.draw_line(Vector2(x_top, cl_top + 4.0), Vector2(x_bot, ty - 2.0), Color(0.06, 0.0, 0.01, 0.50), 2.2)
        c.draw_line(Vector2(x_top - 2.5 * K, cl_top + 6.0), Vector2(x_bot - 2.5 * K, ty - 4.0), Color(0.70, 0.18, 0.12, 0.16), 1.2)
    c.draw_polyline(cl_hem, Color(0.10, 0.01, 0.02, 0.9), 2.0)

    # меч за спиною: руків'я виглядає над правим плечем, клинок іде вниз за спину
    var sa := deg_to_rad(18.0)
    var sdir := Vector2(-sin(sa), cos(sa))          # від навершя вниз по мечу
    var sperp := Vector2(cos(sa), sin(sa))
    var pom := Vector2(cx + 62.0 * K, hy - 62.0 * K)
    var grip_end := pom + sdir * 30.0 * K
    var tip := grip_end + sdir * 170.0 * K
    c.draw_line(grip_end, tip, Color(0.15, 0.15, 0.18), 10.0 * K)
    c.draw_line(grip_end - sperp * 3.0 * K, tip - sperp * 3.0 * K, Color(0.42, 0.40, 0.45, 0.55), 1.6)
    c.draw_line(grip_end + sperp * 3.6 * K, tip + sperp * 3.6 * K, Color(0, 0, 0, 0.55), 2.0)
    c.draw_line(pom + sdir * 4.0 * K, grip_end, leather, 7.0 * K)
    for gi in range(5):
        var gp := pom + sdir * (7.0 + 5.0 * float(gi)) * K
        c.draw_line(gp - sperp * 3.6 * K, gp + sperp * 3.6 * K, Color(0.22, 0.14, 0.08, 0.85), 1.3)
    c.draw_line(grip_end - sperp * 18.0 * K, grip_end + sperp * 18.0 * K, Color(0.19, 0.19, 0.23), 6.0 * K)
    c.draw_line(grip_end - sperp * 18.0 * K - Vector2(0, 1.5 * K), grip_end + sperp * 18.0 * K - Vector2(0, 1.5 * K), Color(0.55, 0.50, 0.46, 0.30), 1.3)
    c.draw_circle(grip_end - sperp * 18.0 * K, 3.6 * K, Color(0.19, 0.19, 0.23))
    c.draw_circle(grip_end + sperp * 18.0 * K, 3.6 * K, Color(0.15, 0.15, 0.18))
    c.draw_circle(pom, 6.2 * K, Color(0.19, 0.19, 0.23))
    c.draw_circle(pom - Vector2(2.0 * K, 2.2 * K), 2.4 * K, Color(0.70, 0.60, 0.50, 0.35))
    c.draw_arc(pom, 6.2 * K, 0.2, PI - 0.2, 8, Color(0.36, 0.28, 0.12, 0.7), 1.2)

    # підкладка між пластинами — суцільна темрява
    _quad(c, Vector2(cx - 44.0 * K, hy + 38.0 * K), Vector2(cx + 44.0 * K, hy + 38.0 * K), Vector2(cx + 50.0 * K, ty + 2.0), Vector2(cx - 50.0 * K, ty + 2.0), Color(0.015, 0.015, 0.02))

    # фолд: чотири накладні смуги нижче пояса (нижня видна до столу)
    for k in range(4):
        var fy := hy + (118.0 + 10.0 * float(k)) * K
        var fw := (41.0 + 3.0 * float(k)) * K
        var fh := 12.0 * K if k < 3 else ty - fy + 2.0
        c.draw_rect(Rect2(cx - fw, fy, fw * 2.0, fh), Color(0.02, 0.02, 0.026))
        c.draw_rect(Rect2(cx - fw + 1.0, fy + 1.0, fw * 2.0 - 2.0, fh - 2.0), plate.darkened(0.05 * float(k)))
        c.draw_rect(Rect2(cx - fw + 1.0, fy + 1.0, fw * 0.9, fh - 2.0), Color(0.75, 0.55, 0.38, 0.09))
        c.draw_rect(Rect2(cx + fw * 0.35, fy + 1.0, fw * 0.65 - 1.0, fh - 2.0), Color(0, 0, 0, 0.30))
        c.draw_line(Vector2(cx - fw + 1.0, fy + 1.5), Vector2(cx + fw - 1.0, fy + 1.5), Color(0.55, 0.52, 0.55, 0.35), 1.2)
        c.draw_line(Vector2(cx - fw + 1.0, fy + 11.5 * K), Vector2(cx + fw - 1.0, fy + 11.5 * K), gold, 1.0)
        for rv in range(-3, 4):
            c.draw_circle(Vector2(cx + float(rv) * 11.0 * K, fy + 6.0 * K), 1.2 * K, Color(0.45, 0.40, 0.36, 0.5))

    # нагрудник: опуклі груди з ребром посередині, світлий зліва, темний справа
    var chest := PackedVector2Array([
        Vector2(cx - 34.0 * K, hy + 42.0 * K), Vector2(cx + 34.0 * K, hy + 42.0 * K),
        Vector2(cx + 51.0 * K, hy + 74.0 * K), Vector2(cx + 47.0 * K, hy + 98.0 * K),
        Vector2(cx + 41.0 * K, hy + 120.0 * K), Vector2(cx - 41.0 * K, hy + 120.0 * K),
        Vector2(cx - 47.0 * K, hy + 98.0 * K), Vector2(cx - 51.0 * K, hy + 74.0 * K)])
    c.draw_colored_polygon(chest, plate)
    c.draw_colored_polygon(PackedVector2Array([
        Vector2(cx - 34.0 * K, hy + 42.0 * K), Vector2(cx - 2.0 * K, hy + 42.0 * K), Vector2(cx - 2.0 * K, hy + 120.0 * K),
        Vector2(cx - 41.0 * K, hy + 120.0 * K), Vector2(cx - 47.0 * K, hy + 98.0 * K), Vector2(cx - 51.0 * K, hy + 74.0 * K)]), plate_lit * Color(1, 1, 1, 0.65))
    c.draw_colored_polygon(PackedVector2Array([
        Vector2(cx + 6.0 * K, hy + 42.0 * K), Vector2(cx + 34.0 * K, hy + 42.0 * K), Vector2(cx + 51.0 * K, hy + 74.0 * K),
        Vector2(cx + 47.0 * K, hy + 98.0 * K), Vector2(cx + 41.0 * K, hy + 120.0 * K), Vector2(cx + 6.0 * K, hy + 120.0 * K)]), plate_dk * Color(1, 1, 1, 0.85))
    # центральне ребро
    c.draw_line(Vector2(cx - 1.0, hy + 44.0 * K), Vector2(cx - 1.0, hy + 120.0 * K), Color(0.02, 0.02, 0.026), 3.0 * K)
    c.draw_line(Vector2(cx - 2.2 * K, hy + 46.0 * K), Vector2(cx - 2.2 * K, hy + 118.0 * K), Color(0.62, 0.58, 0.58, 0.40), 1.3)
    # контури грудних пластин
    c.draw_arc(Vector2(cx - 20.0 * K, hy + 78.0 * K), 20.0 * K, PI * 0.15, PI * 0.95, 14, Color(0.62, 0.58, 0.58, 0.28), 1.5)
    c.draw_arc(Vector2(cx + 20.0 * K, hy + 78.0 * K), 20.0 * K, PI * 0.05, PI * 0.85, 14, Color(0, 0, 0, 0.55), 1.6)
    c.draw_line(Vector2(cx - 40.0 * K, hy + 96.0 * K), Vector2(cx + 40.0 * K, hy + 96.0 * K), Color(0, 0, 0, 0.35), 1.2)
    # окантовка тьмяним золотом і заклепки
    c.draw_polyline(PackedVector2Array([Vector2(cx - 34.0 * K, hy + 42.0 * K), Vector2(cx - 51.0 * K, hy + 74.0 * K), Vector2(cx - 47.0 * K, hy + 98.0 * K), Vector2(cx - 41.0 * K, hy + 120.0 * K), Vector2(cx + 41.0 * K, hy + 120.0 * K), Vector2(cx + 47.0 * K, hy + 98.0 * K), Vector2(cx + 51.0 * K, hy + 74.0 * K), Vector2(cx + 34.0 * K, hy + 42.0 * K)]), gold, 1.5)
    for rv in range(-3, 4):
        c.draw_circle(Vector2(cx + float(rv) * 12.0 * K, hy + 115.0 * K), 1.3 * K, Color(0.48, 0.42, 0.36, 0.55))
    # пояс із пряжкою
    c.draw_rect(Rect2(cx - 44.0 * K, hy + 119.0 * K, 88.0 * K, 7.0 * K), leather)
    c.draw_line(Vector2(cx - 44.0 * K, hy + 120.0 * K), Vector2(cx + 44.0 * K, hy + 120.0 * K), Color(0.3, 0.2, 0.12, 0.4), 1.0)
    c.draw_rect(Rect2(cx - 6.0 * K, hy + 117.0 * K, 12.0 * K, 11.0 * K), Color(0.30, 0.24, 0.12))
    c.draw_rect(Rect2(cx - 3.0 * K, hy + 120.0 * K, 6.0 * K, 5.0 * K), Color(0.04, 0.03, 0.02))
    # перев'язь, що тримає меч за спиною: шкіряний ремінь через груди
    var s0 := Vector2(cx - 30.0 * K, hy + 42.0 * K)
    var s1 := Vector2(cx + 44.0 * K, hy + 112.0 * K)
    c.draw_line(s0, s1, leather, 8.0 * K)
    c.draw_line(s0 + Vector2(0, -3.0 * K), s1 + Vector2(0, -3.0 * K), Color(0.30, 0.20, 0.12, 0.35), 1.2)
    for si in range(9):
        var sp := s0.lerp(s1, (float(si) + 0.5) / 9.0)
        c.draw_circle(sp, 1.1 * K, Color(0.55, 0.42, 0.22, 0.55))
    var bp := s0.lerp(s1, 0.45)
    c.draw_rect(Rect2(bp.x - 5.0 * K, bp.y - 6.0 * K, 10.0 * K, 12.0 * K), Color(0.30, 0.24, 0.12))
    c.draw_rect(Rect2(bp.x - 2.5 * K, bp.y - 3.5 * K, 5.0 * K, 7.0 * K), Color(0.04, 0.03, 0.02))

    # ліва рука (для глядача) лежить на столі: плече, лікоть із шипом, наруч, рукавиця
    var sh_l := Vector2(cx - 56.0 * K, hy + 48.0 * K)
    var el_l := Vector2(cx - 74.0 * K, hy + 108.0 * K)
    var hd_l := Vector2(cx - 44.0 * K, ty + 4.0 * K)
    _plate_limb(c, sh_l, el_l, 21.0 * K, plate)
    _plate_limb(c, el_l, hd_l, 18.0 * K, plate)
    _ell(c, el_l, 11.0 * K, 10.0 * K, plate_lit * Color(1, 1, 1, 0.8))
    c.draw_arc(el_l, 11.0 * K, PI * 1.0, PI * 1.9, 10, Color(0.65, 0.58, 0.55, 0.3), 1.3)
    c.draw_colored_polygon(PackedVector2Array([el_l + Vector2(-5.0 * K, -3.0 * K), el_l + Vector2(-17.0 * K, 3.0 * K), el_l + Vector2(-5.0 * K, 6.0 * K)]), plate)
    _ell(c, hd_l + Vector2(2.0 * K, 2.0 * K), 12.0 * K, 8.5 * K, plate_dk)
    for gk in range(3):
        c.draw_line(hd_l + Vector2((-6.0 + 6.0 * float(gk)) * K, -3.0 * K), hd_l + Vector2((-6.0 + 6.0 * float(gk)) * K, 6.0 * K), Color(0, 0, 0, 0.6), 1.2)

    # права рука простягнута до монет
    var sh_r := Vector2(cx + 56.0 * K, hy + 48.0 * K)
    var el_r := Vector2(cx + 70.0 * K, hy + 106.0 * K)
    var hd_r := Vector2(cx + 34.0 * K, ty - 2.0 * K)
    _plate_limb(c, sh_r, el_r, 21.0 * K, plate_dk * Color(1, 1, 1, 1))
    _plate_limb(c, el_r, hd_r, 18.0 * K, plate_dk * Color(1, 1, 1, 1))
    _ell(c, el_r, 11.0 * K, 10.0 * K, plate.darkened(0.2))
    c.draw_colored_polygon(PackedVector2Array([el_r + Vector2(5.0 * K, -3.0 * K), el_r + Vector2(17.0 * K, 3.0 * K), el_r + Vector2(5.0 * K, 6.0 * K)]), plate_dk)
    _ell(c, hd_r + Vector2(-2.0 * K, 0), 12.0 * K, 8.5 * K, plate_dk.darkened(0.2))
    _ell(c, hd_r + Vector2(-5.0 * K, -7.0 * K), 8.0 * K, 3.0 * K, Color(0.75, 0.56, 0.16))
    _ell(c, hd_r + Vector2(-5.0 * K, -8.0 * K), 8.0 * K, 3.0 * K, Color(0.90, 0.70, 0.26))

    # наплічники
    _draw_pauldron(c, Vector2(cx - 54.0 * K, hy + 42.0 * K), K, -1.0)
    _draw_pauldron(c, Vector2(cx + 54.0 * K, hy + 42.0 * K), K, 1.0)

    # горжет: дві накладні пластини навколо шиї
    _ell(c, Vector2(cx, hy + 40.0 * K), 32.0 * K, 12.0 * K, Color(0.02, 0.02, 0.026))
    _ell(c, Vector2(cx, hy + 38.0 * K), 30.0 * K, 10.5 * K, plate.darkened(0.1))
    _ell(c, Vector2(cx, hy + 34.0 * K), 26.0 * K, 9.0 * K, plate)
    c.draw_arc(Vector2(cx, hy + 34.0 * K), 26.0 * K, PI * 0.1, PI * 0.9, 14, Color(0.40, 0.32, 0.14, 0.5), 1.2)
    c.draw_arc(Vector2(cx, hy + 33.0 * K), 26.0 * K, PI * 1.05, PI * 1.5, 8, Color(0.62, 0.58, 0.58, 0.28), 1.3)

    # гребінь із кінського волосу: чорно-багряний, ледь хитається
    for bi in range(15):
        var bu := float(bi) / 14.0
        var bx := cx - 26.0 * K + bu * 52.0 * K
        var by0 := hy - 24.0 * K - sin(bu * PI) * 6.0 * K
        var topy := hy - 52.0 * K - sin(bu * PI) * 22.0 * K
        var bsw := sin(t * 1.6 + bu * 5.0) * 2.6 * K + sw2 * 0.8
        c.draw_line(Vector2(bx, by0), Vector2(bx + bsw, topy), Color(0.12 + 0.07 * float(bi % 2), 0.02, 0.03), 4.0 * K)
    c.draw_line(Vector2(cx - 20.0 * K, hy - 28.0 * K), Vector2(cx + 20.0 * K, hy - 28.0 * K), Color(0.03, 0.02, 0.02), 6.0 * K)

    # шолом (коринфський, повністю закриває обличчя): темна сталь
    var shell := PackedVector2Array()
    for i in range(15):
        var ha := PI + PI * float(i) / 14.0
        shell.append(Vector2(cx + cos(ha) * 28.0 * K, hy - 6.0 * K + sin(ha) * 34.0 * K))
    shell.append(Vector2(cx + 28.0 * K, hy + 6.0 * K))
    shell.append(Vector2(cx + 26.0 * K, hy + 20.0 * K))
    shell.append(Vector2(cx + 18.0 * K, hy + 35.0 * K))
    shell.append(Vector2(cx + 6.0 * K, hy + 42.0 * K))
    shell.append(Vector2(cx - 6.0 * K, hy + 42.0 * K))
    shell.append(Vector2(cx - 18.0 * K, hy + 35.0 * K))
    shell.append(Vector2(cx - 26.0 * K, hy + 20.0 * K))
    shell.append(Vector2(cx - 28.0 * K, hy + 6.0 * K))
    c.draw_colored_polygon(shell, Color(0.075, 0.075, 0.09))
    var lit := PackedVector2Array()
    for i in range(9):
        var la := PI + PI * 0.55 * float(i) / 8.0
        lit.append(Vector2(cx + cos(la) * 28.0 * K, hy - 6.0 * K + sin(la) * 34.0 * K))
    lit.append(Vector2(cx - 12.0 * K, hy + 6.0 * K))
    lit.append(Vector2(cx - 26.0 * K, hy + 20.0 * K))
    lit.append(Vector2(cx - 28.0 * K, hy + 6.0 * K))
    c.draw_colored_polygon(lit, Color(0.75, 0.50, 0.30, 0.16))
    c.draw_polyline(PackedVector2Array([Vector2(cx - 28.0 * K, hy + 6.0 * K), Vector2(cx - 26.0 * K, hy + 20.0 * K), Vector2(cx - 18.0 * K, hy + 35.0 * K), Vector2(cx - 6.0 * K, hy + 42.0 * K)]), Color(0.55, 0.36, 0.20, 0.35), 1.6)
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 12.0 * K, hy - 36.0 * K), Vector2(cx + 28.0 * K, hy - 6.0 * K), Vector2(cx + 26.0 * K, hy + 20.0 * K), Vector2(cx + 18.0 * K, hy + 35.0 * K), Vector2(cx + 8.0 * K, hy + 40.0 * K), Vector2(cx + 12.0 * K, hy + 6.0 * K)]), Color(0, 0, 0, 0.40))
    c.draw_arc(Vector2(cx, hy - 6.0 * K), 28.0 * K, PI * 1.02, PI * 1.98, 24, Color(0.28, 0.28, 0.34, 0.45), 1.6)
    c.draw_line(Vector2(cx - 26.0 * K, hy - 7.0 * K), Vector2(cx + 26.0 * K, hy - 7.0 * K), Color(0.02, 0.02, 0.025), 3.0 * K)
    c.draw_line(Vector2(cx - 26.0 * K, hy - 9.0 * K), Vector2(cx + 26.0 * K, hy - 9.0 * K), Color(0.30, 0.30, 0.36, 0.30), 1.0)
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 22.0 * K, hy - 1.0 * K), Vector2(cx - 5.0 * K, hy + 1.0 * K), Vector2(cx - 6.0 * K, hy + 7.0 * K), Vector2(cx - 20.0 * K, hy + 5.0 * K)]), Color(0, 0, 0))
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 22.0 * K, hy - 1.0 * K), Vector2(cx + 5.0 * K, hy + 1.0 * K), Vector2(cx + 6.0 * K, hy + 7.0 * K), Vector2(cx + 20.0 * K, hy + 5.0 * K)]), Color(0, 0, 0))
    c.draw_rect(Rect2(cx - 4.0 * K, hy - 7.0 * K, 8.0 * K, 36.0 * K), Color(0.10, 0.10, 0.12))
    c.draw_line(Vector2(cx - 2.0 * K, hy - 6.0 * K), Vector2(cx - 2.0 * K, hy + 27.0 * K), Color(0.40, 0.40, 0.46, 0.35), 1.2)
    c.draw_line(Vector2(cx + 4.0 * K, hy - 6.0 * K), Vector2(cx + 4.0 * K, hy + 28.0 * K), Color(0, 0, 0, 0.6), 1.4)
    for vi in range(4):
        var vy := hy + (20.0 + 5.0 * float(vi)) * K
        c.draw_line(Vector2(cx - 13.0 * K, vy), Vector2(cx - 7.0 * K, vy), Color(0, 0, 0), 1.8)
        c.draw_line(Vector2(cx + 7.0 * K, vy), Vector2(cx + 13.0 * K, vy), Color(0, 0, 0), 1.8)
    c.draw_line(Vector2(cx - 21.0 * K, hy + 8.0 * K), Vector2(cx - 14.0 * K, hy + 32.0 * K), Color(0.02, 0.02, 0.025, 0.8), 1.4)
    c.draw_line(Vector2(cx + 21.0 * K, hy + 8.0 * K), Vector2(cx + 14.0 * K, hy + 32.0 * K), Color(0.02, 0.02, 0.025, 0.8), 1.4)
    var gl := 0.45 + 0.22 * sin(t * 1.3) + 0.08 * sin(t * 7.0)
    for sd in [-1.0, 1.0]:
        var ep := Vector2(cx + sd * 12.0 * K, hy + 3.5 * K)
        c.draw_circle(ep, 6.0 * K, Color(0.9, 0.05, 0.04, 0.10 * gl))
        c.draw_circle(ep, 2.0 * K, Color(0.95, 0.10, 0.06, gl))

# кухоль пива: бурштинове скло, пінна шапка, ручка
func _draw_beer_mug(c: Control, x: float, yb: float, S: float, foam_k: float) -> void:
    _ell(c, Vector2(x + 2.0 * S, yb + 1.0 * S), 12.0 * S, 3.0 * S, Color(0, 0, 0, 0.35))
    # ручка
    c.draw_arc(Vector2(x + 10.5 * S, yb - 14.0 * S), 7.0 * S, -PI * 0.5, PI * 0.5, 10, Color(0.55, 0.30, 0.05), 3.2 * S)
    c.draw_arc(Vector2(x + 10.5 * S, yb - 14.0 * S), 7.0 * S, -PI * 0.5, PI * 0.5, 10, Color(0.95, 0.68, 0.22, 0.6), 1.2 * S)
    # корпус
    _quad(c, Vector2(x - 8.5 * S, yb), Vector2(x + 8.5 * S, yb), Vector2(x + 10.5 * S, yb - 27.0 * S), Vector2(x - 10.5 * S, yb - 27.0 * S), Color(0.80, 0.47, 0.07))
    _quad(c, Vector2(x + 1.0 * S, yb), Vector2(x + 8.5 * S, yb), Vector2(x + 10.5 * S, yb - 27.0 * S), Vector2(x + 2.0 * S, yb - 27.0 * S), Color(0.50, 0.25, 0.03, 0.65))
    _quad(c, Vector2(x - 7.0 * S, yb - 3.0 * S), Vector2(x - 4.5 * S, yb - 3.0 * S), Vector2(x - 6.0 * S, yb - 24.0 * S), Vector2(x - 9.0 * S, yb - 24.0 * S), Color(1.0, 0.88, 0.45, 0.55))
    c.draw_rect(Rect2(x - 8.5 * S, yb - 4.0 * S, 17.0 * S, 4.0 * S), Color(0.35, 0.19, 0.04, 0.85))
    for k in range(3):
        c.draw_circle(Vector2(x + (float(k) - 1.0) * 3.5 * S, yb - (9.0 + 5.0 * float(k)) * S), 0.9 * S, Color(1.0, 0.92, 0.6, 0.6))
    # піна
    var fy := yb - 27.0 * S
    _ell(c, Vector2(x, fy), 10.8 * S, 3.2 * S, Color(0.90, 0.85, 0.70))
    c.draw_circle(Vector2(x - 5.5 * S, fy - 1.5 * S), 4.6 * S * foam_k, Color(0.96, 0.92, 0.80))
    c.draw_circle(Vector2(x + 0.5 * S, fy - 3.4 * S * foam_k), 5.2 * S * foam_k, Color(0.99, 0.96, 0.86))
    c.draw_circle(Vector2(x + 6.0 * S, fy - 1.2 * S), 4.4 * S * foam_k, Color(0.94, 0.89, 0.76))
    c.draw_circle(Vector2(x - 1.5 * S, fy - 5.0 * S * foam_k), 2.0 * S, Color(1.0, 1.0, 0.95, 0.8))
    c.draw_polygon(PackedVector2Array([Vector2(x - 9.0 * S, fy), Vector2(x - 6.0 * S, fy), Vector2(x - 7.0 * S, fy + 6.0 * S)]), PackedColorArray([Color(0.96, 0.92, 0.80), Color(0.96, 0.92, 0.80), Color(0.96, 0.92, 0.80)]))

# латунний піднос з кухлями пива (7 штук у два ряди)
func _draw_tray(c: Control, x: float, ty: float, S: float) -> void:
    var y := ty + 10.0 * S
    _ell(c, Vector2(x + 3.0 * S, y + 5.0 * S), 66.0 * S, 10.0 * S, Color(0, 0, 0, 0.38))
    # ручки-вушка
    for sd in [-1.0, 1.0]:
        _ell(c, Vector2(x + float(sd) * 62.0 * S, y), 8.0 * S, 4.2 * S, Color(0.45, 0.30, 0.08))
        _ell(c, Vector2(x + float(sd) * 62.0 * S, y - 0.8 * S), 5.2 * S, 2.4 * S, Color(0.20, 0.12, 0.04))
    _ell(c, Vector2(x, y + 3.0 * S), 60.0 * S, 10.0 * S, Color(0.34, 0.22, 0.07))
    _ell(c, Vector2(x, y), 60.0 * S, 10.0 * S, Color(0.80, 0.60, 0.22))
    _ell(c, Vector2(x, y + 0.8 * S), 54.0 * S, 8.2 * S, Color(0.52, 0.36, 0.12))
    c.draw_arc(Vector2(x, y), 57.0 * S, PI * 1.05, PI * 1.55, 12, Color(1.0, 0.92, 0.55, 0.65), 1.6 * S)
    # мечені вирізьбленням ромби по краю
    for k in range(9):
        var ax := x + (float(k) - 4.0) * 12.5 * S
        c.draw_circle(Vector2(ax, y + 7.4 * S * (1.0 - absf(float(k) - 4.0) / 6.0) + 1.0 * S), 1.3 * S, Color(0.95, 0.78, 0.35, 0.6))
    # задній ряд (4), потім передній (3): так нижні кухлі перекривають верхні
    for k in range(4):
        _draw_beer_mug(c, x + (float(k) - 1.5) * 28.0 * S, y - 1.0 * S, S, 0.95 + 0.1 * float(k % 2))
    for k in range(3):
        _draw_beer_mug(c, x + (float(k) - 1.0) * 28.0 * S, y + 5.0 * S, S, 1.0 + 0.1 * float((k + 1) % 2))
    # калюжка пива, що розлилась
    _ell(c, Vector2(x + 44.0 * S, y + 7.0 * S), 9.0 * S, 2.0 * S, Color(0.60, 0.33, 0.06, 0.55))

# ---------- Кубок переможця ----------
# профіль тіла обертання: ключі Vector2(y, радіус) згори вниз, згладжені між собою
func _profile(keys: Array, steps: int = 6) -> Array:
    var out: Array = []
    for i in range(keys.size() - 1):
        var a: Vector2 = keys[i]
        var b: Vector2 = keys[i + 1]
        for k in range(steps):
            var u := float(k) / float(steps)
            var e := u * u * (3.0 - 2.0 * u)
            out.append(Vector2(lerpf(a.x, b.x, u), lerpf(a.y, b.y, e)))
    out.append(keys[keys.size() - 1])
    return out

# смуга тіла обертання між частками радіуса a..b (-1 — лівий край, +1 — правий)
func _lathe_band(c: Control, org: Vector2, S: float, prof: Array, a: float, b: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for p in prof:
        var pv: Vector2 = p
        pts.append(Vector2(org.x + a * pv.y * S, org.y + pv.x * S))
    for i in range(prof.size() - 1, -1, -1):
        var pv2: Vector2 = prof[i]
        pts.append(Vector2(org.x + b * pv2.y * S, org.y + pv2.x * S))
    c.draw_colored_polygon(pts, col)

# чорне тіло обертання із золотою окантовкою: глянцевий чорний з відблиском зліва (світло від свічки),
# тонкий золотий контур по краях і золотий блиск на виступах
func _lathe(c: Control, org: Vector2, S: float, prof: Array, col: Color) -> void:
    _lathe_band(c, org, S, prof, -1.0, 1.0, Color(0.025, 0.022, 0.025))
    _lathe_band(c, org, S, prof, -1.0, 0.35, Color(0.075, 0.065, 0.07))
    _lathe_band(c, org, S, prof, -0.94, -0.40, Color(0.15, 0.13, 0.13))
    _lathe_band(c, org, S, prof, -0.80, -0.58, Color(0.72, 0.58, 0.28, 0.55))
    _lathe_band(c, org, S, prof, 0.55, 1.0, Color(0.0, 0.0, 0.0, 0.50))
    # золота окантовка: ліва й права межа профілю
    for edge in [-1.0, 1.0]:
        var ln := PackedVector2Array()
        for p in prof:
            var pv: Vector2 = p
            ln.append(Vector2(org.x + float(edge) * pv.y * S, org.y + pv.x * S))
        c.draw_polyline(ln, Color(col.r, col.g, col.b, 0.95) if edge < 0.0 else Color(col.r, col.g, col.b, 0.95).darkened(0.35), 1.4 * S)

func _gem(c: Control, p: Vector2, r: float, col: Color) -> void:
    c.draw_circle(p, r * 1.35, Color(0.30, 0.20, 0.04))
    c.draw_circle(p, r, col.darkened(0.30))
    c.draw_circle(p + Vector2(-0.12, -0.12) * r, r * 0.72, col)
    c.draw_circle(p + Vector2(-0.35, -0.38) * r, r * 0.30, Color(1, 1, 1, 0.9))

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> PackedVector2Array:
    var out := PackedVector2Array()
    for i in range(n + 1):
        var u := float(i) / float(n)
        var q := 1.0 - u
        out.append(p0 * q * q * q + p1 * 3.0 * q * q * u + p2 * 3.0 * q * u * u + p3 * u * u * u)
    return out

# Золотий кубок на чорному постаменті: ручки-завитки, лавровий вінок, рубін, самоцвіти. Розмір ~110 px при висоті екрана 720.
func _draw_trophy(c: Control, w: float, h: float, S: float) -> void:
    var org := Vector2(TROPHY_X * w, TROPHY_Y * h)
    var gold := Color(0.80, 0.57, 0.12)
    var gold_hi := Color(1.0, 0.90, 0.50)
    var gold_dk := Color(0.42, 0.27, 0.05)
    # тінь на столі
    _ell(c, org + Vector2(5.0 * S, 3.0 * S), 44.0 * S, 7.0 * S, Color(0, 0, 0, 0.42))
    # постамент: чорне дерево із золотою облямівкою й табличкою
    var pl := 38.0 * S
    _ell(c, org + Vector2(0, -1.0 * S), pl, 6.0 * S, Color(0.05, 0.03, 0.02))
    c.draw_rect(Rect2(org.x - pl, org.y - 13.0 * S, 2.0 * pl, 13.0 * S), Color(0.075, 0.045, 0.03))
    c.draw_rect(Rect2(org.x - pl, org.y - 13.0 * S, 9.0 * S, 13.0 * S), Color(0.20, 0.12, 0.07))
    c.draw_rect(Rect2(org.x + pl - 10.0 * S, org.y - 13.0 * S, 10.0 * S, 13.0 * S), Color(0, 0, 0, 0.35))
    _ell(c, org + Vector2(0, -13.0 * S), pl, 6.0 * S, Color(0.14, 0.085, 0.05))
    _ell(c, org + Vector2(0, -13.6 * S), pl - 4.0 * S, 4.6 * S, Color(0.22, 0.13, 0.07))
    c.draw_line(org + Vector2(-pl, -12.5 * S), org + Vector2(pl, -12.5 * S), Color(gold.r, gold.g, gold.b, 0.9), 1.6 * S)
    c.draw_line(org + Vector2(-pl, -0.8 * S), org + Vector2(pl, -0.8 * S), gold_dk, 1.4 * S)
    c.draw_rect(Rect2(org.x - 17.0 * S, org.y - 9.5 * S, 34.0 * S, 6.5 * S), gold_dk)
    c.draw_rect(Rect2(org.x - 16.0 * S, org.y - 8.8 * S, 32.0 * S, 5.1 * S), gold)
    for k in range(5):
        c.draw_line(org + Vector2((-11.0 + float(k) * 5.5) * S, -6.2 * S), org + Vector2((-8.0 + float(k) * 5.5) * S, -6.2 * S), gold_dk, 1.0)
    c.draw_line(org + Vector2(-15.0 * S, -9.0 * S), org + Vector2(-2.0 * S, -9.0 * S), Color(1.0, 0.95, 0.7, 0.8), 1.0)
    # ніжка зі стопою й двома вузлами
    var stem_o := org + Vector2(0, -13.0 * S)
    var stem := _profile([Vector2(-35, 4.5), Vector2(-31, 4.5), Vector2(-28, 8.5), Vector2(-24, 8.5), Vector2(-21, 4.5), Vector2(-17, 4.5), Vector2(-13, 9.0), Vector2(-8, 16.0), Vector2(-3, 24.0), Vector2(0, 28.0)], 7)
    # ручки: ліва й права (завитки)
    var top := org.y - 13.0 * S - 90.0 * S
    for sd in [-1.0, 1.0]:
        var hx: float = float(sd)
        var pts := _bezier(Vector2(org.x + hx * 25.0 * S, top + 14.0 * S), Vector2(org.x + hx * 58.0 * S, top - 8.0 * S), Vector2(org.x + hx * 52.0 * S, top + 50.0 * S), Vector2(org.x + hx * 7.0 * S, top + 50.0 * S), 18)
        c.draw_polyline(pts, gold if sd < 0.0 else gold_dk.lightened(0.25), 7.0 * S)
        c.draw_polyline(pts, Color(0.05, 0.045, 0.05), 4.4 * S)
        c.draw_polyline(pts, Color(0.16, 0.14, 0.14) if sd < 0.0 else Color(0.09, 0.08, 0.08), 1.6 * S)
        # завиток на кінці й самоцвіт
        _gem(c, Vector2(org.x + hx * 45.0 * S, top + 13.0 * S), 2.6 * S, Color(0.15, 0.62, 0.30))
    _lathe(c, stem_o, S, stem, gold)
    # самоцвіти на вузлах і на стопі
    _gem(c, stem_o + Vector2(0, -26.0 * S), 3.0 * S, Color(0.15, 0.62, 0.30))
    _gem(c, stem_o + Vector2(0, -10.5 * S), 2.6 * S, Color(0.20, 0.35, 0.85))
    for k in range(5):
        var gx := (float(k) - 2.0) * 9.0 * S
        var gy := -3.0 * S + 1.2 * S * (1.0 - absf(float(k) - 2.0) / 2.0)
        _gem(c, stem_o + Vector2(gx, gy), 1.9 * S, Color(0.85, 0.12, 0.18) if k % 2 == 0 else Color(0.20, 0.38, 0.90))
    # чаша: розтруб із плавним звуженням до шийки
    var bowl_o := Vector2(org.x, top)
    var bowl := _profile([Vector2(0, 33), Vector2(6, 33), Vector2(20, 31), Vector2(32, 25), Vector2(42, 16), Vector2(50, 8), Vector2(54, 7), Vector2(56, 10), Vector2(58, 10), Vector2(60, 6)], 6)
    _lathe(c, bowl_o, S, bowl, gold)
    # вузька смуга з ромбів під вінцем
    var by := top + 11.0 * S
    var band := PackedVector2Array()
    for k in range(13):
        var an := PI * float(k) / 12.0
        band.append(Vector2(org.x - cos(an) * 32.0 * S, by + sin(an) * 4.5 * S))
    c.draw_polyline(band, gold_dk, 4.0 * S)
    c.draw_polyline(band, gold_hi, 2.0 * S)
    for k in range(5):
        var an2 := PI * (float(k) + 0.5) / 5.0
        var dp := Vector2(org.x - cos(an2) * 31.0 * S, by + sin(an2) * 4.5 * S)
        c.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -3.0 * S), dp + Vector2(2.5 * S, 0), dp + Vector2(0, 3.0 * S), dp + Vector2(-2.5 * S, 0)]), Color(0.75, 0.10, 0.16))
    # лавровий вінок знизу чаші
    for sd in [-1.0, 1.0]:
        var lh: float = float(sd)
        for k in range(7):
            var u := float(k) / 6.0
            var lp := Vector2(org.x + lh * (7.0 + 13.0 * u) * S, top + (46.0 - 24.0 * u) * S)
            _leaf(c, lp, -PI * 0.5 + lh * (0.9 - 0.4 * u), 9.0 * S, Color(0.52, 0.34, 0.06))
            _leaf(c, lp + Vector2(lh * 1.5 * S, 0), -PI * 0.5 + lh * (0.2 - 0.4 * u), 8.0 * S, Color(0.95, 0.76, 0.28, 0.85))
    # великий рубін по центру
    var rc := Vector2(org.x, top + 28.0 * S)
    c.draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -11.0 * S), rc + Vector2(8.0 * S, 0), rc + Vector2(0, 11.0 * S), rc + Vector2(-8.0 * S, 0)]), gold_dk)
    c.draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -9.0 * S), rc + Vector2(6.4 * S, 0), rc + Vector2(0, 9.0 * S), rc + Vector2(-6.4 * S, 0)]), Color(0.62, 0.04, 0.10))
    c.draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -9.0 * S), rc + Vector2(-6.4 * S, 0), rc + Vector2(0, 0)]), Color(0.95, 0.25, 0.30))
    c.draw_colored_polygon(PackedVector2Array([rc + Vector2(0, -9.0 * S), rc + Vector2(6.4 * S, 0), rc + Vector2(0, 0)]), Color(0.78, 0.08, 0.16))
    c.draw_colored_polygon(PackedVector2Array([rc + Vector2(0, 9.0 * S), rc + Vector2(6.4 * S, 0), rc + Vector2(0, 0)]), Color(0.40, 0.02, 0.07))
    c.draw_circle(rc + Vector2(-2.0 * S, -3.5 * S), 1.5 * S, Color(1, 0.92, 0.92, 0.9))
    # вінець: еліпс зверху — золотий обідок і темне вино
    _ell(c, Vector2(org.x, top), 35.0 * S, 7.5 * S, gold_dk)
    _ell(c, Vector2(org.x, top - 0.6 * S), 34.0 * S, 6.8 * S, gold_hi.darkened(0.12))
    _ell(c, Vector2(org.x, top + 0.8 * S), 31.0 * S, 5.4 * S, Color(0.13, 0.07, 0.02))
    _ell(c, Vector2(org.x + 1.0 * S, top + 1.4 * S), 28.0 * S, 4.2 * S, Color(0.34, 0.03, 0.07))
    c.draw_arc(Vector2(org.x, top), 33.0 * S, PI * 1.08, PI * 1.5, 12, Color(1.0, 1.0, 0.85, 0.85), 1.5 * S)
    # перлини по краю обідка
    for k in range(11):
        var an3 := PI * float(k) / 10.0
        c.draw_circle(Vector2(org.x - cos(an3) * 34.0 * S, top + sin(an3) * 7.2 * S), 1.3 * S, Color(1.0, 0.96, 0.80))

func _draw_barrel(c: Control, cx: float, base_y: float, k: float) -> void:
    var hgt := 96.0 * k
    var top_y := base_y - hgt
    var pts_l := PackedVector2Array()
    var pts_r := PackedVector2Array()
    for i in range(9):
        var u := float(i) / 8.0
        var bw := (32.0 + 8.0 * sin(PI * u)) * k
        pts_l.append(Vector2(cx - bw, top_y + hgt * u))
        pts_r.append(Vector2(cx + bw, top_y + hgt * u))
    var body := PackedVector2Array()
    for p in pts_l:
        body.append(p)
    for i in range(pts_r.size() - 1, -1, -1):
        body.append(pts_r[i])
    c.draw_colored_polygon(body, Color(0.20, 0.115, 0.06))
    # дошки
    for s in range(-3, 4):
        var u2 := float(s) / 3.5
        var line := PackedVector2Array()
        for i in range(9):
            var v := float(i) / 8.0
            var bw2 := (32.0 + 8.0 * sin(PI * v)) * k
            line.append(Vector2(cx + bw2 * u2, top_y + hgt * v))
        c.draw_polyline(line, Color(0.05, 0.03, 0.015, 0.75), 1.2)
    # світліше зліва (від свічки), темніше справа
    var lit := PackedVector2Array()
    for i in range(9):
        var v2 := float(i) / 8.0
        var bw3 := (32.0 + 8.0 * sin(PI * v2)) * k
        lit.append(Vector2(cx - bw3, top_y + hgt * v2))
    for i in range(8, -1, -1):
        var v3 := float(i) / 8.0
        var bw4 := (32.0 + 8.0 * sin(PI * v3)) * k
        lit.append(Vector2(cx - bw4 * 0.35, top_y + hgt * v3))
    c.draw_colored_polygon(lit, Color(0.62, 0.36, 0.16, 0.22))
    # обручі
    for u3 in [0.12, 0.5, 0.88]:
        var bw5 := (32.0 + 8.0 * sin(PI * float(u3))) * k
        var yy := top_y + hgt * float(u3)
        c.draw_line(Vector2(cx - bw5, yy), Vector2(cx + bw5, yy), Color(0.05, 0.045, 0.045), 5.0 * k)
        c.draw_line(Vector2(cx - bw5, yy - 1.5 * k), Vector2(cx + bw5, yy - 1.5 * k), Color(0.30, 0.28, 0.27, 0.6), 1.2)
    _ell(c, Vector2(cx, top_y), 32.0 * k, 8.0 * k, Color(0.30, 0.18, 0.09))
    _ell(c, Vector2(cx, top_y), 26.0 * k, 5.5 * k, Color(0.14, 0.08, 0.04))

func _draw_barrels(c: Control, w: float, h: float, S: float) -> void:
    _draw_barrel(c, 0.405 * w, 0.925 * h, S * 1.05)
    _draw_barrel(c, 0.462 * w, 0.962 * h, S * 0.78)

func _draw_stool(c: Control, w: float, h: float, S: float) -> void:
    var x := 0.595 * w
    var y := 0.855 * h
    var leg := Color(0.14, 0.08, 0.04)
    var fl := 0.975 * h
    c.draw_line(Vector2(x - 24.0 * S, y + 10.0 * S), Vector2(x - 38.0 * S, fl), leg, 8.0 * S)
    c.draw_line(Vector2(x + 24.0 * S, y + 10.0 * S), Vector2(x + 38.0 * S, fl), leg.darkened(0.3), 8.0 * S)
    c.draw_line(Vector2(x - 2.0 * S, y + 12.0 * S), Vector2(x + 2.0 * S, fl - 14.0 * S), leg.lightened(0.1), 8.0 * S)
    c.draw_line(Vector2(x - 31.0 * S, y + 56.0 * S), Vector2(x + 31.0 * S, y + 56.0 * S), leg.darkened(0.2), 4.0 * S)
    _ell(c, Vector2(x, y + 9.0 * S), 45.0 * S, 13.0 * S, Color(0.12, 0.07, 0.035))
    c.draw_rect(Rect2(x - 45.0 * S, y, 90.0 * S, 9.0 * S), Color(0.12, 0.07, 0.035))
    _ell(c, Vector2(x, y), 45.0 * S, 13.0 * S, Color(0.30, 0.18, 0.09))
    _ell(c, Vector2(x - 6.0 * S, y - 1.0 * S), 30.0 * S, 8.0 * S, Color(0.42, 0.26, 0.12, 0.55))
    c.draw_arc(Vector2(x, y), 45.0 * S, PI * 0.1, PI * 0.9, 12, Color(0.05, 0.03, 0.015, 0.8), 1.5)

# важкий стіл на передньому плані (праворуч унизу): дошки, глек і монети
func _draw_front_table(c: Control, w: float, h: float, S: float) -> void:
    var top := PackedVector2Array([Vector2(0.725 * w, 0.895 * h), Vector2(w, 0.868 * h), Vector2(w, 0.940 * h), Vector2(0.708 * w, 0.948 * h)])
    c.draw_colored_polygon(top, Color(0.17, 0.10, 0.052))
    for i in range(1, 5):
        var u := float(i) / 5.0
        c.draw_line(Vector2(lerpf(0.725 * w, w, u), lerpf(0.895 * h, 0.868 * h, u)), Vector2(lerpf(0.708 * w, w, u), lerpf(0.948 * h, 0.940 * h, u)), Color(0.05, 0.03, 0.015, 0.8), 1.5)
    c.draw_colored_polygon(PackedVector2Array([Vector2(0.708 * w, 0.948 * h), Vector2(w, 0.940 * h), Vector2(w, h), Vector2(0.700 * w, h)]), Color(0.075, 0.042, 0.022))
    c.draw_line(Vector2(0.708 * w, 0.948 * h), Vector2(w, 0.940 * h), Color(0.55, 0.36, 0.17, 0.55), 1.6)
    # глек
    var jx := 0.835 * w
    var jy := 0.925 * h
    _ell(c, Vector2(jx, jy), 22.0 * S, 5.0 * S, Color(0, 0, 0, 0.35))
    c.draw_colored_polygon(PackedVector2Array([Vector2(jx - 17.0 * S, jy - 2.0 * S), Vector2(jx - 21.0 * S, jy - 28.0 * S), Vector2(jx - 9.0 * S, jy - 44.0 * S), Vector2(jx + 9.0 * S, jy - 44.0 * S), Vector2(jx + 21.0 * S, jy - 28.0 * S), Vector2(jx + 17.0 * S, jy - 2.0 * S)]), Color(0.27, 0.19, 0.12))
    c.draw_colored_polygon(PackedVector2Array([Vector2(jx - 17.0 * S, jy - 2.0 * S), Vector2(jx - 21.0 * S, jy - 28.0 * S), Vector2(jx - 9.0 * S, jy - 44.0 * S), Vector2(jx - 4.0 * S, jy - 44.0 * S), Vector2(jx - 8.0 * S, jy - 2.0 * S)]), Color(0.60, 0.42, 0.24, 0.35))
    c.draw_arc(Vector2(jx + 22.0 * S, jy - 26.0 * S), 9.0 * S, -PI * 0.5, PI * 0.5, 10, Color(0.20, 0.13, 0.08), 3.5 * S)
    # монети
    for i in range(4):
        var cp := Vector2(0.925 * w + float(i % 2) * 5.0 * S, 0.915 * h - float(i) * 4.0 * S)
        _ell(c, cp + Vector2(0.0, 2.0 * S), 13.0 * S, 4.5 * S, Color(0.45, 0.30, 0.05))
        _ell(c, cp, 13.0 * S, 4.5 * S, Color(0.90, 0.68, 0.18))
    _ell(c, Vector2(0.955 * w, 0.925 * h), 12.0 * S, 4.0 * S, Color(0.95, 0.74, 0.22))

# ================= Динамічна частина =================
func _draw_dynamic() -> void:
    var c := dyn
    var w := size.x
    var h := size.y
    var S := h / 720.0
    var ty := TABLE_Y * h

    # свічка: полум'я й світловий ореол
    var cx := CANDLE_X * w
    var cy := ty - 22.0 * S
    var flick := 1.0 + 0.12 * sin(t * 11.0) + 0.07 * sin(t * 23.0)
    for g in range(5):
        c.draw_circle(Vector2(cx, cy - 8.0 * S), (22.0 + 24.0 * float(g)) * S * flick, Color(1.0, 0.62, 0.22, 0.045))
    var fh := 14.0 * S * flick
    var sway := sin(t * 9.0) * 1.6 * S
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 4.0 * S, cy), Vector2(cx + sway, cy - fh), Vector2(cx + 4.0 * S, cy), Vector2(cx, cy + 3.0 * S)]), Color(1.0, 0.55, 0.12, 0.95))
    c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 2.0 * S, cy), Vector2(cx + sway * 0.6, cy - fh * 0.6), Vector2(cx + 2.0 * S, cy), Vector2(cx, cy + 2.0 * S)]), Color(1.0, 0.93, 0.58, 0.95))

    # ліхтар: тепле сяйво
    var lx := LANT_X * w
    var ly := 0.395 * h + 24.0 * S
    var fl2 := 1.0 + 0.05 * sin(t * 3.0) + 0.03 * sin(t * 7.3 + 2.0)
    for g in range(4):
        c.draw_circle(Vector2(lx, ly), (16.0 + 22.0 * float(g)) * S * fl2, Color(1.0, 0.60, 0.20, 0.05))
    c.draw_rect(Rect2(lx - 8.0 * S, ly - 14.0 * S, 16.0 * S, 24.0 * S), Color(1.0, 0.78, 0.30, 0.55 + 0.15 * sin(t * 6.0)))

    # лицар «дає монети»: купка на столі подекуди виблискує
    if has_knight:
        var gl := maxf(0.0, sin(t * 2.2))
        var gp := Vector2(0.94 * w, 0.905 * h)
        var gs := 7.0 * S * gl
        c.draw_line(gp - Vector2(gs, 0), gp + Vector2(gs, 0), Color(1.0, 0.95, 0.7, 0.9 * gl), 1.6)
        c.draw_line(gp - Vector2(0, gs), gp + Vector2(0, gs), Color(1.0, 0.95, 0.7, 0.9 * gl), 1.6)

    # кубок переможця: тепле сяйво, виблиски на золоті, пульсація рубіна
    if has_trophy:
        var tx := TROPHY_X * w
        var tyy := TROPHY_Y * h
        var pulse := 0.5 + 0.5 * sin(t * 1.6)
        for g in range(4):
            c.draw_circle(Vector2(tx, tyy - 62.0 * S), (34.0 + 18.0 * float(g)) * S, Color(1.0, 0.74, 0.28, 0.028 + 0.012 * pulse))
        c.draw_circle(Vector2(tx, tyy - 75.0 * S), (14.0 + 3.0 * pulse) * S, Color(1.0, 0.15, 0.2, 0.10 + 0.07 * pulse))
        var sp := [Vector2(-24, -100), Vector2(26, -68), Vector2(-3, -77), Vector2(46, -92), Vector2(-45, -78), Vector2(8, -112), Vector2(18, -22), Vector2(-14, -48)]
        for i in range(sp.size()):
            var q: Vector2 = sp[i]
            var a := pow(maxf(0.0, sin(t * 1.5 + float(i) * 2.1)), 8.0)
            if a > 0.02:
                var cp := Vector2(tx + q.x * S, tyy + q.y * S)
                var L := (4.0 + 10.0 * a) * S
                var col := Color(1.0, 0.96, 0.75, 0.95 * a)
                c.draw_line(cp - Vector2(L, 0), cp + Vector2(L, 0), col, 1.6)
                c.draw_line(cp - Vector2(0, L), cp + Vector2(0, L), col, 1.6)
                c.draw_line(cp - Vector2(L, L) * 0.5, cp + Vector2(L, L) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)
                c.draw_line(cp - Vector2(L, -L) * 0.5, cp + Vector2(L, -L) * 0.5, Color(col.r, col.g, col.b, col.a * 0.6), 1.0)
                c.draw_circle(cp, 1.8 * S, Color(1, 1, 0.9, a))

    var relics := [
        [has_ship_bell, 0.16, Color(0.38, 0.72, 0.73)],
        [has_cracked_bell, 0.27, Color(0.93, 0.55, 0.25)],
        [has_black_mirror, 0.38, Color(0.70, 0.72, 0.96)],
        [has_mechanical_heart, 0.49, Color(0.90, 0.35, 0.22)],
    ]
    for i in range(relics.size()):
        var relic: Array = relics[i]
        if not bool(relic[0]):
            continue
        var rx := float(relic[1]) * w
        var ry := 0.625 * h - 23.0 * S
        var glow: Color = relic[2]
        var pulse := maxf(0.0, sin(t * 2.0 + float(i) * 1.4))
        c.draw_circle(Vector2(rx, ry), (7.0 + 4.0 * pulse) * S, Color(glow.r, glow.g, glow.b, 0.05 + 0.06 * pulse))
        var sparkle := Vector2(rx + 7.0 * S, ry - 4.0 * S)
        c.draw_line(sparkle - Vector2(3.0, 0) * S, sparkle + Vector2(3.0, 0) * S, Color(glow.r, glow.g, glow.b, 0.7 * pulse), 1.0 * S)
        c.draw_line(sparkle - Vector2(0, 3.0) * S, sparkle + Vector2(0, 3.0) * S, Color(glow.r, glow.g, glow.b, 0.7 * pulse), 1.0 * S)

    # пил у промені світла
    for m in _motes:
        var mx: float = fmod(float(m[0]) + t * float(m[2]), 1.0)
        var my: float = fmod(float(m[1]) - t * float(m[2]) * 0.6 + 1.0, 1.0)
        var a := 0.25 + 0.25 * sin(t * 2.0 + float(m[3]))
        c.draw_circle(Vector2(mx * w, my * h), 1.4, Color(1.0, 0.85, 0.55, a))
