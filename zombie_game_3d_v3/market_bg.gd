extends Control
# Фон екрана броні: моторошний нічний середньовічний базар.
# Крива вуличка з фахверковими будинками, туман, калюжі на брукові. Під драною маркізою — прилавок
# крамаря в каптурі зі світними очима: на рейці висять кольчуга, лати, щит і прапор із черепом,
# на прилавку — шоломи, рукавиці, чоботи та череп зі свічкою, ліворуч стоїть манекен у кольчузі.
# Гойдаються ліхтарі (один — болотно-зелений), крутиться ворон, повзе туман, мерехтять відблиски на кільцях.
# Раз на кілька секунд крамар піднімає шолом, вищиряється, брязкає броня й лунає його сміх.
# Стіна, брук і світло — шейдером; нерухоме — у _draw_static / _draw_front (раз); живе — у _draw_dynamic / _draw_fx.
#
# Координати сцени — частки екрана (0..1). Змінюйте константи нижче, якщо хочете зсунути предмети.

const FLOOR_Y := 0.83      # де стоять предмети на підлозі
const CTR_Y := 0.735       # верх прилавка
const CTR_X0 := 0.150      # прилавок: лівий край
const CTR_X1 := 0.530      # прилавок: правий край
const MER_X := 0.375       # крамар
const POLE_L := 0.105      # стовпи навісу
const POLE_R := 0.555
const AWN_Y := 0.355       # верх драпірування навісу (низ — на 0.075 нижче)
const RAIL_Y := 0.485      # рейка, на якій висить броня
const CALL_LEN := 3.2      # скільки секунд триває «показ товару»

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
float flick(float s) {
    return 1.0 + 0.12 * sin(time * 8.0 + s) + 0.08 * sin(time * 15.0 + s * 2.3) + 0.05 * sin(time * 27.0 + s * 4.1);
}
float lamp(vec2 p, vec2 pos, float k, float s) {
    vec2 d = (p - pos) * vec2(1.0, 1.15);
    return exp(-dot(d, d) * k) * flick(s);
}

void fragment() {
    vec2 uv = UV;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float floor_y = 0.80;
    vec3 col = vec3(0.0);
    float pud = 0.0;

    // --- дахи й небо ---
    float cell = floor(p.x * 1.6);
    float gx = fract(p.x * 1.6);
    float roof_y = 0.10 + 0.07 * hash(vec2(cell, 3.0)) + 0.06 * abs(gx - 0.5) * 2.0;

    if (uv.y < roof_y) {
        col = mix(vec3(0.012, 0.016, 0.035), vec3(0.08, 0.095, 0.13), clamp(uv.y / 0.18, 0.0, 1.0));
        float cl = fbm(vec2(p.x * 1.6 + time * 0.02, uv.y * 4.0));
        col += vec3(0.04, 0.05, 0.07) * smoothstep(0.45, 0.8, cl);
        vec2 mp = vec2(0.80 * aspect, 0.055);
        float dm = length(p - mp);
        col += vec3(0.78, 0.84, 0.70) * (1.0 - smoothstep(0.026, 0.030, dm));
        col += vec3(0.30, 0.38, 0.30) * exp(-dm * dm * 140.0) * 0.5;
    } else if (uv.y < floor_y) {
        // --- фахверкова стіна ---
        float wx = p.x * 2.2;
        float wy = (uv.y - 0.08) / 0.20;
        vec2 wid = vec2(floor(wx), floor(wy));
        float cx = fract(wx);
        float cy = fract(wy);
        float hh = hash(wid);
        vec3 plaster = mix(vec3(0.13, 0.11, 0.09), vec3(0.22, 0.19, 0.15), hh);
        plaster *= 0.55 + 0.75 * fbm(p * 8.0 + wid);
        float vb = min(cx, 1.0 - cx);
        float beam = 1.0 - smoothstep(0.035, 0.055, vb);
        beam = max(beam, 1.0 - smoothstep(0.05, 0.075, cy));
        float dg = abs(cx - cy);
        if (hash(wid + 3.0) > 0.5) {
            dg = abs(cx - (1.0 - cy));
        }
        beam = max(beam, 1.0 - smoothstep(0.035, 0.06, dg));
        vec3 wood = vec3(0.055, 0.037, 0.026) * (0.6 + 0.9 * fbm(vec2(p.x * 30.0, p.y * 4.0)));
        col = mix(plaster, wood, beam);
        float wnd = step(0.58, hash(wid + 7.0)) * step(0.30, cx) * step(cx, 0.70) * step(0.30, cy) * step(cy, 0.72);
        float lit = step(0.80, hash(wid + 11.0));
        vec3 glass = mix(vec3(0.01, 0.012, 0.02), vec3(1.0, 0.62, 0.25) * (0.5 + 0.2 * sin(time * 2.0 + wid.x * 5.0)), lit);
        col = mix(col, glass * 0.9, wnd * (1.0 - beam));
        col *= 0.6 + 0.4 * smoothstep(0.08, 0.45, uv.y);
    } else {
        // --- брук у перспективі, з калюжами ---
        float fy = uv.y - 0.72;
        float u = (uv.x - 0.5) / fy;
        float v = 1.0 / fy;
        vec2 cg = vec2(u * 2.2, v * 1.4);
        float rw = floor(cg.y);
        cg.x += mod(rw, 2.0) * 0.5;
        vec2 sid = floor(cg);
        vec2 sf = fract(cg) - 0.5;
        float rr = pow(pow(abs(sf.x) * 2.0, 4.0) + pow(abs(sf.y) * 2.0, 4.0), 0.25);
        float stone = 1.0 - smoothstep(0.78, 0.95, rr);
        vec3 sc = mix(vec3(0.06, 0.06, 0.065), vec3(0.17, 0.165, 0.16), hash(sid));
        sc *= 0.6 + 0.7 * fbm(vec2(u * 7.0, v * 3.0));
        col = mix(vec3(0.012, 0.012, 0.014), sc, stone);
        pud = smoothstep(0.52, 0.60, fbm(vec2(u * 0.9 + 5.0, v * 0.6)));
        col = mix(col, vec3(0.025, 0.03, 0.045), pud * 0.85);
        if (uv.y < floor_y + 0.006) {
            col = vec3(0.02);
        }
    }

    // --- світло: ліхтар біля крамаря, свічка на черепі, зелений ліхтар, далекий ліхтар ---
    vec2 L1 = vec2(0.27 * aspect, 0.545);
    vec2 LC = vec2(0.478 * aspect, 0.70);
    vec2 L2 = vec2(0.575 * aspect, 0.47);
    vec2 L3 = vec2(0.80 * aspect, 0.36);
    float l1 = lamp(p, L1, 5.0, 0.0);
    float lc = lamp(p, LC, 28.0, 3.0);
    float l2 = lamp(p, L2, 9.0, 1.7);
    float l3 = lamp(p, L3, 6.0, 5.2);
    vec3 warm = vec3(1.0, 0.56, 0.24);
    vec3 sick = vec3(0.50, 0.95, 0.40);
    vec3 amb = vec3(0.045, 0.052, 0.080);
    col *= amb + warm * (l1 * 1.7 + lc * 1.0) + sick * (l2 * 1.1 + l3 * 0.8);
    col += (warm * (l1 + lc * 0.5) + sick * (l2 + l3)) * pud * 0.30;

    // --- туман, підсвічений ліхтарями ---
    float haze = fbm(vec2(p.x * 2.2 + time * 0.04, p.y * 3.0 - time * 0.015));
    float fogk = 0.10 + 0.55 * smoothstep(0.55, 0.90, uv.y);
    col += (vec3(0.07, 0.085, 0.095) + warm * (l1 + lc) * 0.10 + sick * (l2 + l3) * 0.10) * haze * fogk;

    // --- віньєтка ---
    vec2 q2 = uv - 0.5;
    col *= 1.0 - 0.85 * smoothstep(0.20, 0.80, length(q2 * vec2(1.0, 1.15)));
    COLOR = vec4(col, 1.0);
}
"""

var t := 0.0
var back: ColorRect
var stat: Control    # позаду крамаря: стовпи, рейка, броня, манекен (раз)
var dyn: Control     # крамар, ліхтарі, ворон (щокадру)
var front: Control   # перед крамарем: драпірування навісу, прилавок і товар (раз)
var fx: Control      # туман, відблиски, пил, вогник свічки, очі в ящику (щокадру)
var _rng := RandomNumberGenerator.new()
var _call := -1.0
var _next_call := 4.0
var _prev_call := -1.0
var _fly := -1.0
var _next_fly := 12.0
var _dust: Array = []   # [позиція (частки екрана), фаза, розмір]
var _fog: Array = []    # [x0, y, швидкість, радіус, фаза]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _rng.seed = 4242
    back = ColorRect.new()
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sh := Shader.new()
    sh.code = SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    back.material = m
    add_child(back)

    stat = _layer(_draw_static)
    dyn = _layer(_draw_dynamic)
    front = _layer(_draw_front)
    fx = _layer(_draw_fx)

    for i in range(40):
        _dust.append([Vector2(_rng.randf_range(0.0, 1.0), _rng.randf_range(0.30, 0.92)), _rng.randf_range(0.0, TAU), _rng.randf_range(0.8, 2.0)])
    for i in range(18):
        _fog.append([_rng.randf_range(-0.2, 1.2), _rng.randf_range(0.76, 0.96), _rng.randf_range(0.004, 0.012), _rng.randf_range(90.0, 190.0), _rng.randf_range(0.0, TAU)])

    resized.connect(func() -> void:
        stat.queue_redraw()
        front.queue_redraw())

func _layer(cb: Callable) -> Control:
    var c := Control.new()
    c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.draw.connect(cb)
    add_child(c)
    return c

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    delta = minf(delta, 0.05)
    t += delta
    var w := size.x
    var h := size.y

    # «показ товару»: крамар піднімає шолом, брязкає броня, лунає сміх
    if _call < 0.0:
        if t >= _next_call:
            _call = 0.0
            _prev_call = 0.0
            Sfx.play("merchant_laugh", -15.0)
    else:
        _prev_call = _call
        _call += delta
        if _prev_call < 0.45 and _call >= 0.45:
            Sfx.play("armor_clink", -17.0)
        if _call >= CALL_LEN:
            _call = -1.0
            _next_call = t + _rng.randf_range(7.0, 13.0)

    # ворон, що перелітає через дахи
    if _fly < 0.0:
        if t >= _next_fly:
            _fly = 0.0
            Sfx.play("raven", -21.0)
    else:
        _fly += delta
        if _fly > 9.0:
            _fly = -1.0
            _next_fly = t + _rng.randf_range(16.0, 30.0)

    # пилюка в повітрі
    for d in _dust:
        var pos: Vector2 = d[0]
        pos.x += sin(t * 0.35 + float(d[1])) * 0.0006 + 0.0004
        pos.y -= 0.0011 * (0.4 + float(d[2]) * 0.3) * delta * 60.0 * 0.1
        if pos.y < 0.28:
            pos.y = 0.92
        if pos.x > 1.02:
            pos.x = -0.02
        d[0] = pos

    var sm := back.material as ShaderMaterial
    sm.set_shader_parameter("time", t)
    sm.set_shader_parameter("aspect", w / maxf(h, 1.0))
    dyn.queue_redraw()
    fx.queue_redraw()

# ================= Допоміжне малювання =================
func _ell(c: Control, p: Vector2, rx: float, ry: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(20):
        var ang := TAU * float(i) / 20.0
        pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
    c.draw_colored_polygon(pts, col)

func _poly(c: Control, pts: Array, col: Color) -> void:
    var pa := PackedVector2Array()
    for q in pts:
        var v: Vector2 = q
        pa.append(v)
    c.draw_colored_polygon(pa, col)

# Багатокутник у «відносних» координатах: base + точка * S.
func _rp(c: Control, base: Vector2, S: float, rel: Array, col: Color) -> void:
    var pa := PackedVector2Array()
    for q in rel:
        var v: Vector2 = q
        pa.append(base + v * S)
    c.draw_colored_polygon(pa, col)

func _rl(c: Control, base: Vector2, S: float, a: Vector2, b: Vector2, col: Color, wd: float) -> void:
    c.draw_line(base + a * S, base + b * S, col, wd)

func _ik(sh: Vector2, tg: Vector2, a: float, b: float, out_dir: float) -> Vector2:
    var d := clampf(sh.distance_to(tg), 1.0, a + b - 1.0)
    var base := (tg - sh).angle()
    var cosv := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
    var al := acos(cosv)
    var e1 := sh + Vector2.from_angle(base + al) * a
    var e2 := sh + Vector2.from_angle(base - al) * a
    if (e1.x - e2.x) * out_dir > 0.0:
        return e1
    return e2

func _glow(c: Control, p: Vector2, r: float, col: Color, k: float) -> void:
    for g in range(5):
        var rr := r * (0.25 + 0.2 * float(g))
        c.draw_circle(p, rr, Color(col.r, col.g, col.b, col.a * k))

func _skull(c: Control, p: Vector2, r: float, bone: Color) -> void:
    _ell(c, p + Vector2(0.0, -r * 0.1), r, r * 0.95, bone)
    c.draw_rect(Rect2(p.x - r * 0.55, p.y + r * 0.45, r * 1.1, r * 0.6), bone.darkened(0.1))
    _ell(c, p + Vector2(-r * 0.38, -r * 0.1), r * 0.26, r * 0.30, Color(0.015, 0.008, 0.008))
    _ell(c, p + Vector2(r * 0.38, -r * 0.1), r * 0.26, r * 0.30, Color(0.015, 0.008, 0.008))
    _poly(c, [p + Vector2(0.0, r * 0.18), p + Vector2(-r * 0.12, r * 0.44), p + Vector2(r * 0.12, r * 0.44)], Color(0.015, 0.008, 0.008))
    for i in range(5):
        var tx := p.x - r * 0.4 + float(i) * r * 0.2
        c.draw_line(Vector2(tx, p.y + r * 0.55), Vector2(tx, p.y + r * 1.0), Color(0.06, 0.04, 0.03), maxf(1.0, r * 0.07))

func _pole(c: Control, x: float, y0: float, y1: float, S: float) -> void:
    var wd := 14.0 * S
    c.draw_rect(Rect2(x - wd * 0.5, y0, wd, y1 - y0), Color(0.095, 0.060, 0.038))
    c.draw_rect(Rect2(x + wd * 0.1, y0, wd * 0.4, y1 - y0), Color(0.0, 0.0, 0.0, 0.30))
    c.draw_line(Vector2(x - wd * 0.5, y0), Vector2(x - wd * 0.5, y1), Color(1.0, 0.6, 0.25, 0.22), 2.0)
    for k in range(5):
        var ky := lerpf(y0, y1, 0.15 + 0.18 * float(k))
        _ell(c, Vector2(x - wd * 0.1 + float(k % 2) * 3.0 * S, ky), 2.5 * S, 3.5 * S, Color(0.03, 0.02, 0.012))

# ----- кольчуга -----
func _mail_hw(dy: float, hh: float) -> float:
    if dy < 8.0:
        return lerpf(14.0, 62.0, dy / 8.0)
    if dy < 36.0:
        return 62.0
    if dy < 44.0:
        return lerpf(62.0, 36.0, (dy - 36.0) / 8.0)
    if dy < hh * 0.75:
        return 36.0
    return lerpf(36.0, 42.0, (dy - hh * 0.75) / (hh * 0.25))

# top — центр верху (шия), hh — висота в «одиницях» (множиться на S), tint — яскравість.
func _mail(c: Control, top: Vector2, hh: float, S: float, tint: float) -> void:
    var left := PackedVector2Array()
    var right := PackedVector2Array()
    var dy := 0.0
    while dy < hh - 3.0:
        var hw := _mail_hw(dy, hh)
        left.append(top + Vector2(-hw, dy) * S)
        right.append(top + Vector2(hw, dy) * S)
        dy += 4.0
    var hwb := _mail_hw(hh, hh)
    var pts := PackedVector2Array()
    for q in left:
        pts.append(q)
    for k in range(11):
        var fx_ := lerpf(-hwb, hwb, float(k) / 10.0)
        var jag := 0.0
        if k % 2 == 1:
            jag = -4.0
        pts.append(top + Vector2(fx_, hh + jag) * S)
    var ri := right.size() - 1
    while ri >= 0:
        pts.append(right[ri])
        ri -= 1
    var base := Color(0.17, 0.18, 0.20) * tint
    base.a = 1.0
    c.draw_colored_polygon(pts, base)
    # кільця
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var row := 0
    var yy := 6.0
    while yy < hh - 4.0:
        var hw2 := _mail_hw(yy, hh) - 3.0
        var off := 0.0
        if row % 2 == 0:
            off = 2.5
        var xx := -hw2 + off
        while xx < hw2:
            var br := 0.25 + 0.55 * rng.randf()
            c.draw_arc(top + Vector2(xx, yy) * S, 2.3 * S, 0.0, TAU, 6, Color(0.55, 0.58, 0.62, br * tint), 1.0)
            xx += 5.0
        yy += 4.0
        row += 1
    # тінь на правій половині, ґудзуваті складки, отвір для шиї
    var shade := PackedVector2Array()
    shade.append(top + Vector2(0.0, 0.0))
    for q2 in right:
        shade.append(q2)
    shade.append(top + Vector2(hwb, hh) * S)
    shade.append(top + Vector2(0.0, hh) * S)
    c.draw_colored_polygon(shade, Color(0.0, 0.0, 0.0, 0.28))
    _ell(c, top + Vector2(0.0, 2.0 * S), 12.0 * S, 5.0 * S, Color(0.01, 0.008, 0.008))
    c.draw_line(top + Vector2(-62.0, 8.0) * S, top + Vector2(-34.0, -2.0) * S, Color(1.0, 0.6, 0.3, 0.30 * tint), 2.0)

# ----- лати -----
func _plate(c: Control, top: Vector2, S: float, tint: float) -> void:
    var pts: Array = [Vector2(-26, 0), Vector2(-46, 10), Vector2(-50, 34), Vector2(-40, 64), Vector2(-34, 86), Vector2(-42, 104), Vector2(42, 104), Vector2(34, 86), Vector2(40, 64), Vector2(50, 34), Vector2(46, 10), Vector2(26, 0), Vector2(0, 6)]
    var steel := Color(0.27, 0.29, 0.33) * tint
    steel.a = 1.0
    _rp(c, top, S, pts, steel)
    _rp(c, top, S, [Vector2(0, 6), Vector2(26, 0), Vector2(46, 10), Vector2(50, 34), Vector2(40, 64), Vector2(34, 86), Vector2(42, 104), Vector2(0, 104)], Color(0, 0, 0, 0.30))
    _rl(c, top, S, Vector2(0, 8), Vector2(0, 100), Color(0.04, 0.04, 0.05, 0.8), 2.0)
    _rl(c, top, S, Vector2(-2, 8), Vector2(-2, 90), Color(0.7, 0.72, 0.78, 0.35 * tint), 1.5)
    for ly in [64.0, 80.0, 94.0]:
        _rl(c, top, S, Vector2(-40.0 + (ly - 64.0) * 0.1, ly), Vector2(40.0 - (ly - 64.0) * 0.1, ly), Color(0.03, 0.03, 0.04, 0.75), 2.0)
        _rl(c, top, S, Vector2(-38.0, ly + 2.0), Vector2(38.0, ly + 2.0), Color(0.6, 0.62, 0.68, 0.22 * tint), 1.0)
    _rl(c, top, S, Vector2(-26, 0), Vector2(-46, 10), Color(1.0, 0.62, 0.3, 0.55 * tint), 2.5)
    _rl(c, top, S, Vector2(-46, 10), Vector2(-50, 34), Color(1.0, 0.62, 0.3, 0.45 * tint), 2.5)
    for rv in [Vector2(-36, 30), Vector2(36, 30), Vector2(-30, 56), Vector2(30, 56)]:
        c.draw_circle(top + rv * S, 2.2 * S, Color(0.55, 0.56, 0.6, 0.8 * tint))
    # подряпини й іржа
    _rl(c, top, S, Vector2(14, 40), Vector2(24, 52), Color(0.3, 0.12, 0.05, 0.6), 1.5)
    _rl(c, top, S, Vector2(-20, 20), Vector2(-10, 30), Color(0.3, 0.12, 0.05, 0.5), 1.5)

# ----- шоломи -----
func _kettle(c: Control, ctr: Vector2, S: float, tint: float) -> void:
    var steel := Color(0.30, 0.31, 0.35) * tint
    steel.a = 1.0
    _ell(c, ctr + Vector2(0.0, 11.0) * S, 36.0 * S, 8.0 * S, steel.darkened(0.3))
    var pts := PackedVector2Array()
    for i in range(13):
        var a := PI + PI * float(i) / 12.0
        pts.append(ctr + Vector2(cos(a) * 21.0, 10.0 + sin(a) * 26.0) * S)
    c.draw_colored_polygon(pts, steel)
    c.draw_colored_polygon(pts, Color(0, 0, 0, 0.18))
    c.draw_arc(ctr + Vector2(0.0, 10.0) * S, 22.0 * S, PI * 1.12, PI * 1.55, 10, Color(1.0, 0.7, 0.4, 0.55 * tint), 2.5 * S)
    _ell(c, ctr + Vector2(0.0, 11.0) * S, 36.0 * S, 8.0 * S, Color(0, 0, 0, 0.0))
    c.draw_arc(ctr + Vector2(0.0, 11.0) * S, 36.0 * S, 0.1, PI - 0.1, 14, Color(0.7, 0.72, 0.78, 0.35 * tint), 1.5 * S)
    for k in range(5):
        c.draw_circle(ctr + Vector2(-16.0 + float(k) * 8.0, 8.0) * S, 1.5 * S, Color(0.6, 0.6, 0.65, 0.7 * tint))

func _great_helm(c: Control, ctr: Vector2, S: float, tint: float) -> void:
    var steel := Color(0.26, 0.28, 0.32) * tint
    steel.a = 1.0
    # подерте червоне пір'я
    for k in range(5):
        var a := -PI * 0.5 + (float(k) - 2.0) * 0.28
        var tip := ctr + Vector2(0.0, -30.0) * S + Vector2.from_angle(a) * 40.0 * S
        _poly(c, [ctr + Vector2(-4.0, -28.0) * S, tip, ctr + Vector2(4.0, -28.0) * S], Color(0.28, 0.04, 0.035) * tint)
    _rp(c, ctr, S, [Vector2(-21, 24), Vector2(-23, -6), Vector2(-15, -26), Vector2(0, -32), Vector2(15, -26), Vector2(23, -6), Vector2(21, 24)], steel)
    _rp(c, ctr, S, [Vector2(0, -32), Vector2(15, -26), Vector2(23, -6), Vector2(21, 24), Vector2(0, 24)], Color(0, 0, 0, 0.32))
    c.draw_rect(Rect2(ctr.x - 17.0 * S, ctr.y - 7.0 * S, 34.0 * S, 5.0 * S), Color(0.005, 0.004, 0.004))
    c.draw_rect(Rect2(ctr.x - 1.5 * S, ctr.y - 24.0 * S, 3.0 * S, 46.0 * S), steel.lightened(0.08))
    for k in range(6):
        c.draw_circle(ctr + Vector2(5.0 + float(k % 3) * 5.0, 8.0 + float(k / 3) * 6.0) * S, 1.3 * S, Color(0.0, 0.0, 0.0, 0.85))
    c.draw_line(ctr + Vector2(-21.0, 20.0) * S, ctr + Vector2(-23.0, -6.0) * S, Color(1.0, 0.62, 0.3, 0.5 * tint), 2.5)

func _round_shield(c: Control, ctr: Vector2, r: float) -> void:
    c.draw_circle(ctr, r, Color(0.13, 0.045, 0.035))
    c.draw_circle(ctr + Vector2(r * 0.12, r * 0.1), r * 0.9, Color(0.0, 0.0, 0.0, 0.25))
    for k in range(-2, 3):
        c.draw_line(ctr + Vector2(float(k) * r * 0.34, -r * 0.92), ctr + Vector2(float(k) * r * 0.34, r * 0.92), Color(0.0, 0.0, 0.0, 0.4), 1.5)
    c.draw_arc(ctr, r - 2.0, 0.0, TAU, 28, Color(0.20, 0.20, 0.22), 5.0)
    c.draw_arc(ctr, r - 2.0, PI * 0.95, PI * 1.45, 10, Color(1.0, 0.62, 0.3, 0.45), 3.0)
    _skull(c, ctr + Vector2(0.0, -r * 0.05), r * 0.34, Color(0.52, 0.46, 0.36))
    c.draw_circle(ctr, r * 0.16, Color(0.30, 0.30, 0.33))
    c.draw_circle(ctr + Vector2(-r * 0.04, -r * 0.05), r * 0.07, Color(0.65, 0.65, 0.7, 0.7))
    c.draw_line(ctr + Vector2(-r * 0.7, r * 0.1), ctr + Vector2(-r * 0.2, r * 0.6), Color(0.0, 0.0, 0.0, 0.7), 2.0)

func _banner(c: Control, top: Vector2, S: float) -> void:
    var pts: Array = [Vector2(-17, 0), Vector2(17, 0), Vector2(17, 92), Vector2(10, 84), Vector2(6, 104), Vector2(0, 88), Vector2(-5, 108), Vector2(-10, 90), Vector2(-17, 100)]
    _rp(c, top, S, pts, Color(0.20, 0.035, 0.03))
    _rp(c, top, S, [Vector2(0, 0), Vector2(17, 0), Vector2(17, 92), Vector2(10, 84), Vector2(6, 104), Vector2(0, 88)], Color(0, 0, 0, 0.30))
    _skull(c, top + Vector2(0.0, 38.0) * S, 10.0 * S, Color(0.06, 0.035, 0.03))
    c.draw_line(top + Vector2(-12.0, 6.0) * S, top + Vector2(12.0, 6.0), Color(0.5, 0.35, 0.2, 0.5), 1.5)
    c.draw_rect(Rect2(top.x - 24.0 * S, top.y - 4.0 * S, 48.0 * S, 5.0 * S), Color(0.08, 0.05, 0.03))

func _boot(c: Control, base: Vector2, S: float, flip: float, tint: float) -> void:
    var leather := Color(0.20, 0.12, 0.075) * tint
    leather.a = 1.0
    var pts: Array = [Vector2(-9.0 * flip, -38), Vector2(9.0 * flip, -38), Vector2(10.0 * flip, -8), Vector2(26.0 * flip, -6), Vector2(28.0 * flip, 0), Vector2(-11.0 * flip, 0)]
    _rp(c, base, S, pts, leather)
    _rp(c, base, S, [Vector2(0, -38), Vector2(9.0 * flip, -38), Vector2(10.0 * flip, -8), Vector2(26.0 * flip, -6), Vector2(28.0 * flip, 0), Vector2(0, 0)], Color(0, 0, 0, 0.28))
    _rp(c, base, S, [Vector2(-11.0 * flip, -4), Vector2(29.0 * flip, -4), Vector2(29.0 * flip, 1), Vector2(-11.0 * flip, 1)], Color(0.03, 0.02, 0.015))
    _rl(c, base, S, Vector2(-9.0 * flip, -30), Vector2(9.0 * flip, -30), Color(0.35, 0.22, 0.12), 3.0)
    _rl(c, base, S, Vector2(-9.0 * flip, -20), Vector2(10.0 * flip, -20), Color(0.05, 0.03, 0.02), 2.0)
    c.draw_circle(base + Vector2(0.0, -20.0) * S, 2.0 * S, Color(0.6, 0.55, 0.3, 0.8 * tint))

func _gauntlet(c: Control, base: Vector2, S: float, tint: float) -> void:
    var steel := Color(0.27, 0.29, 0.33) * tint
    steel.a = 1.0
    _rp(c, base, S, [Vector2(-11, 0), Vector2(-8, -14), Vector2(8, -14), Vector2(11, 0), Vector2(14, 0), Vector2(14, 8), Vector2(-14, 8), Vector2(-14, 0)], steel.darkened(0.15))
    c.draw_rect(Rect2(base.x - 9.0 * S, base.y - 34.0 * S, 18.0 * S, 22.0 * S), steel)
    for k in range(4):
        var fx_ := base.x - 7.0 * S + float(k) * 4.6 * S
        c.draw_line(Vector2(fx_, base.y - 34.0 * S), Vector2(fx_, base.y - 54.0 * S + abs(float(k) - 1.5) * 4.0 * S), steel.lightened(0.04), 4.0 * S)
    c.draw_line(Vector2(base.x - 9.0 * S, base.y - 34.0 * S), Vector2(base.x - 9.0 * S, base.y - 12.0 * S), Color(1.0, 0.62, 0.3, 0.45 * tint), 2.0)

# Манекен-стійка: дерев'яна жердина з перекладиною, шолом, кольчуга.
func _mannequin(c: Control, x: float, fy: float, S: float, tint: float) -> void:
    var wood := Color(0.11, 0.07, 0.042) * tint
    wood.a = 1.0
    _ell(c, Vector2(x, fy), 46.0 * S, 7.0 * S, Color(0, 0, 0, 0.5))
    c.draw_rect(Rect2(x - 5.0 * S, fy - 222.0 * S, 10.0 * S, 222.0 * S), wood)
    c.draw_rect(Rect2(x + 1.0 * S, fy - 222.0 * S, 4.0 * S, 222.0 * S), Color(0, 0, 0, 0.3))
    _poly(c, [Vector2(x - 44.0 * S, fy), Vector2(x + 44.0 * S, fy), Vector2(x + 30.0 * S, fy - 10.0 * S), Vector2(x - 30.0 * S, fy - 10.0 * S)], wood.darkened(0.2))
    c.draw_rect(Rect2(x - 72.0 * S, fy - 218.0 * S, 144.0 * S, 8.0 * S), wood.lightened(0.05))
    _mail(c, Vector2(x, fy - 222.0 * S), 130.0, S, tint)
    # потертий пояс і шкіряна торбина
    c.draw_rect(Rect2(x - 38.0 * S, fy - 150.0 * S, 76.0 * S, 7.0 * S), Color(0.14, 0.08, 0.05) * tint)
    c.draw_rect(Rect2(x - 5.0 * S, fy - 152.0 * S, 10.0 * S, 11.0 * S), Color(0.55, 0.45, 0.2, tint))
    _great_helm(c, Vector2(x, fy - 248.0 * S), S, tint)

# ----- ворон -----
func _raven_perched(c: Control, p: Vector2, S: float) -> void:
    var bob := sin(t * 1.3) * 1.5 * S
    var tilt := sin(t * 0.7) * 3.0 * S
    var ink := Color(0.025, 0.025, 0.035)
    _poly(c, [p + Vector2(-6.0, 4.0) * S, p + Vector2(-20.0, 22.0) * S, p + Vector2(-12.0, 24.0) * S, p + Vector2(2.0, 8.0) * S], ink)
    _ell(c, p + Vector2(0.0, -4.0 * S), 10.0 * S, 14.0 * S, ink)
    _ell(c, p + Vector2(4.0 * S + tilt, -19.0 * S + bob), 6.0 * S, 6.0 * S, ink)
    _poly(c, [p + Vector2(8.0 * S + tilt, -21.0 * S + bob), p + Vector2(20.0 * S + tilt, -17.0 * S + bob), p + Vector2(8.0 * S + tilt, -16.0 * S + bob)], Color(0.07, 0.06, 0.06))
    c.draw_circle(p + Vector2(6.0 * S + tilt, -21.0 * S + bob), 1.4 * S, Color(1.0, 0.25, 0.15, 0.9))
    c.draw_line(p + Vector2(-5.0, -14.0) * S, p + Vector2(-8.0, -6.0) * S, Color(0.4, 0.5, 0.6, 0.18), 1.5)

func _raven_flying(c: Control, p: Vector2, S: float, dir: float, ph: float) -> void:
    var flap := sin(ph * 12.0)
    var ink := Color(0.015, 0.015, 0.022)
    _ell(c, p, 13.0 * S, 5.5 * S, ink)
    _ell(c, p + Vector2(11.0 * S * dir, -2.0 * S), 4.5 * S, 4.0 * S, ink)
    _poly(c, [p + Vector2(14.0 * S * dir, -2.0 * S), p + Vector2(21.0 * S * dir, -1.0 * S), p + Vector2(14.0 * S * dir, 0.0)], ink)
    _poly(c, [p + Vector2(-12.0 * S * dir, 0.0), p + Vector2(-24.0 * S * dir, 3.0 * S), p + Vector2(-12.0 * S * dir, 3.0 * S)], ink)
    var wy := -18.0 * S * flap
    _poly(c, [p + Vector2(-5.0 * S, -2.0 * S), p + Vector2(-20.0 * S * dir, wy), p + Vector2(-26.0 * S * dir, wy * 0.6 + 4.0 * S), p + Vector2(6.0 * S, 0.0)], ink)
    _poly(c, [p + Vector2(0.0, -2.0 * S), p + Vector2(14.0 * S * dir, wy * 0.9), p + Vector2(22.0 * S * dir, wy * 0.5 + 5.0 * S), p + Vector2(8.0 * S, 1.0 * S)], ink)

# ----- ліхтар -----
# Положення гойдаючогося ліхтаря: i = 0 (біля крамаря), 1 (зелений біля стовпа), 2 (далекий).
func _lamp_pos(i: int, w: float, h: float, S: float) -> Vector2:
    var ox: float = [0.27, 0.575, 0.80][i]
    var oy: float = [0.45, 0.36, 0.28][i]
    var ln: float = [66.0, 90.0, 70.0][i] * S
    var a := sin(t * (1.05 + 0.2 * float(i)) + float(i) * 2.0) * 0.045 + sin(t * 2.3 + float(i)) * 0.012
    return Vector2(ox * w + sin(a) * ln, oy * h + cos(a) * ln)

func _draw_lantern(c: Control, i: int, w: float, h: float, S: float) -> void:
    var ox: float = [0.27, 0.575, 0.80][i]
    var oy: float = [0.45, 0.36, 0.28][i]
    var top := Vector2(ox * w, oy * h)
    var p := _lamp_pos(i, w, h, S)
    var flame_col := Color(1.0, 0.62, 0.20)
    if i >= 1:
        flame_col = Color(0.55, 1.0, 0.45)
    var fl := 1.0 + 0.12 * sin(t * 8.0 + float(i)) + 0.08 * sin(t * 15.0 + float(i) * 2.3)
    # ланка ланцюга
    var n := 9
    for k in range(n):
        var q0 := top.lerp(p - Vector2(0.0, 16.0 * S), float(k) / float(n))
        c.draw_circle(q0, 1.8 * S, Color(0.15, 0.14, 0.14))
        c.draw_line(q0, top.lerp(p - Vector2(0.0, 16.0 * S), float(k + 1) / float(n)), Color(0.14, 0.13, 0.13), 2.0 * S)
    # корпус
    c.draw_rect(Rect2(p.x - 9.0 * S, p.y - 16.0 * S, 18.0 * S, 5.0 * S), Color(0.08, 0.07, 0.07))
    _poly(c, [p + Vector2(-8.0 * S, -11.0 * S), p + Vector2(8.0 * S, -11.0 * S), p + Vector2(11.0 * S, 12.0 * S), p + Vector2(-11.0 * S, 12.0 * S)], Color(flame_col.r * 0.45, flame_col.g * 0.40, flame_col.b * 0.25, 0.92))
    _ell(c, p + Vector2(0.0, 2.0 * S), 5.0 * S * fl, 9.0 * S * fl, Color(flame_col.r, flame_col.g, flame_col.b, 0.95))
    _ell(c, p + Vector2(0.0, 3.0 * S), 2.5 * S, 5.0 * S, Color(1.0, 1.0, 0.85, 0.95))
    c.draw_line(p + Vector2(-8.0 * S, -11.0 * S), p + Vector2(-11.0 * S, 12.0 * S), Color(0.06, 0.05, 0.05), 2.0 * S)
    c.draw_line(p + Vector2(8.0 * S, -11.0 * S), p + Vector2(11.0 * S, 12.0 * S), Color(0.06, 0.05, 0.05), 2.0 * S)
    c.draw_rect(Rect2(p.x - 12.0 * S, p.y + 12.0 * S, 24.0 * S, 4.0 * S), Color(0.08, 0.07, 0.07))

# ================= Статична частина (позаду крамаря) =================
func _draw_static() -> void:
    var c := stat
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_far_stall(c, w, h, S)
    _draw_alley_junk(c, w, h, S)
    # манекен у кольчузі ліворуч
    _mannequin(c, 0.052 * w, FLOOR_Y * h, S, 1.0)
    # стовпи навісу
    _pole(c, POLE_L * w, (AWN_Y - 0.055) * h, FLOOR_Y * h, S)
    _pole(c, POLE_R * w, (AWN_Y - 0.055) * h, FLOOR_Y * h, S)
    # скат даху навісу
    var rf := Color(0.13, 0.032, 0.028)
    _poly(c, [Vector2(0.080 * w, AWN_Y * h), Vector2(0.580 * w, AWN_Y * h), Vector2(0.552 * w, (AWN_Y - 0.058) * h), Vector2(0.108 * w, (AWN_Y - 0.058) * h)], rf)
    for k in range(1, 9):
        var fk := float(k) / 9.0
        c.draw_line(Vector2(lerpf(0.108, 0.552, fk) * w, (AWN_Y - 0.058) * h), Vector2(lerpf(0.080, 0.580, fk) * w, AWN_Y * h), Color(0, 0, 0, 0.35), 2.0)
    c.draw_rect(Rect2(0.100 * w, (AWN_Y - 0.064) * h, 0.460 * w, 6.0 * S), Color(0.07, 0.045, 0.03))
    # рейка з гачками
    var ry := RAIL_Y * h
    c.draw_rect(Rect2(POLE_L * w, ry - 3.0 * S, (POLE_R - POLE_L) * w, 6.0 * S), Color(0.075, 0.05, 0.034))
    c.draw_line(Vector2(POLE_L * w, ry - 3.0 * S), Vector2(POLE_R * w, ry - 3.0 * S), Color(1.0, 0.6, 0.25, 0.25), 1.5)
    # товар на рейці: кольчуга, лати, прапор, щит
    var hang := Color(0.12, 0.11, 0.11)
    for hx in [0.165, 0.228, 0.468, 0.526]:
        c.draw_line(Vector2(float(hx) * w, ry), Vector2(float(hx) * w, ry + 16.0 * S), hang, 2.5 * S)
    c.draw_line(Vector2(0.165 * w - 66.0 * S, ry + 16.0 * S), Vector2(0.165 * w + 66.0 * S, ry + 16.0 * S), Color(0.10, 0.065, 0.04), 5.0 * S)
    _mail(c, Vector2(0.165 * w, ry + 18.0 * S), 124.0, S, 1.0)
    _plate(c, Vector2(0.228 * w, ry + 18.0 * S), S, 1.0)
    _banner(c, Vector2(0.468 * w, ry + 16.0 * S), S)
    _round_shield(c, Vector2(0.526 * w, ry + 16.0 * S + 46.0 * S), 46.0 * S)
    # кістяні підвіски по краях навісу
    _bone_strand(c, Vector2(0.092 * w, (AWN_Y + 0.070) * h), 58.0 * S, S)
    _bone_strand(c, Vector2(0.566 * w, (AWN_Y + 0.070) * h), 74.0 * S, S)

func _bone_strand(c: Control, top: Vector2, ln: float, S: float) -> void:
    c.draw_line(top, top + Vector2(0.0, ln), Color(0.12, 0.09, 0.06), 1.5)
    var bone := Color(0.50, 0.46, 0.38)
    var k := 0
    var yy := 10.0 * S
    while yy < ln:
        if k % 3 == 2:
            _ell(c, top + Vector2(0.0, yy), 3.5 * S, 4.5 * S, bone)
        else:
            c.draw_line(top + Vector2(-2.0 * S, yy - 5.0 * S), top + Vector2(2.0 * S, yy + 5.0 * S), bone.darkened(0.1), 3.0 * S)
        yy += 14.0 * S
        k += 1

# Дальній ряд: ще один навіс, ледь видний у тумані.
func _draw_far_stall(c: Control, w: float, h: float, S: float) -> void:
    var s2 := S * 0.82
    var fy := (FLOOR_Y - 0.01) * h
    _pole(c, 0.665 * w, 0.36 * h, fy, s2)
    _pole(c, 0.965 * w, 0.36 * h, fy, s2)
    _poly(c, [Vector2(0.64 * w, 0.40 * h), Vector2(0.99 * w, 0.40 * h), Vector2(0.97 * w, 0.355 * h), Vector2(0.66 * w, 0.355 * h)], Color(0.09, 0.022, 0.02))
    for k in range(7):
        var x0 := lerpf(0.64, 0.99, float(k) / 7.0) * w
        var x1 := lerpf(0.64, 0.99, float(k + 1) / 7.0) * w
        var col := Color(0.15, 0.035, 0.03)
        if k % 2 == 1:
            col = Color(0.13, 0.10, 0.07)
        var pts := PackedVector2Array()
        pts.append(Vector2(x0, 0.40 * h))
        pts.append(Vector2(x1, 0.40 * h))
        for j in range(7):
            var a := float(j) / 6.0 * PI
            pts.append(Vector2((x0 + x1) * 0.5 + cos(a) * (x1 - x0) * 0.5, 0.40 * h + sin(a) * 14.0 * S))
        c.draw_colored_polygon(pts, col)
    c.draw_line(Vector2(0.665 * w, 0.52 * h), Vector2(0.965 * w, 0.52 * h), Color(0.06, 0.04, 0.03), 4.0 * s2)
    _mannequin(c, 0.735 * w, fy, s2, 0.42)
    _mail(c, Vector2(0.86 * w, 0.535 * h), 110.0, s2, 0.42)
    _plate(c, Vector2(0.925 * w, 0.535 * h), s2, 0.42)

# Ящик із чимось живим, мішки та купа кілець на підлозі.
func _draw_alley_junk(c: Control, w: float, h: float, S: float) -> void:
    var fy := (FLOOR_Y + 0.012) * h
    var cx := 0.118 * w
    var top := fy - 64.0 * S
    var wd := 36.0 * S
    _ell(c, Vector2(cx, fy), wd * 1.2, 7.0 * S, Color(0, 0, 0, 0.5))
    for k in range(4):
        var y0 := top + float(k) * 16.0 * S
        c.draw_rect(Rect2(cx - wd, y0, wd * 2.0, 14.0 * S), Color(0.10 + 0.01 * float(k), 0.062, 0.036))
        c.draw_line(Vector2(cx - wd, y0 + 1.0), Vector2(cx + wd, y0 + 1.0), Color(1.0, 0.6, 0.25, 0.14), 1.5)
    # тінь-щілина між дошками, де блимають очі
    c.draw_rect(Rect2(cx - wd + 4.0 * S, top + 22.0 * S, wd * 2.0 - 8.0 * S, 10.0 * S), Color(0.0, 0.0, 0.0, 0.95))
    c.draw_rect(Rect2(cx - wd - 2.0, top - 3.0 * S, wd * 2.0 + 4.0, 5.0 * S), Color(0.05, 0.035, 0.024))
    for k in range(7):
        c.draw_line(Vector2(cx - wd + 6.0 * S + float(k) * 11.0 * S, top - 2.0 * S), Vector2(cx - wd + float(k) * 12.0 * S, top - 14.0 * S - float(k % 3) * 4.0 * S), Color(0.35, 0.28, 0.12, 0.8), 2.0 * S)
    # купа кілець (розсипана кольчуга) і калюжа крові перед прилавком
    var mx := 0.325 * w
    var my := (FLOOR_Y + 0.045) * h
    _ell(c, Vector2(mx, my + 4.0 * S), 62.0 * S, 9.0 * S, Color(0, 0, 0, 0.4))
    _ell(c, Vector2(mx, my), 50.0 * S, 14.0 * S, Color(0.12, 0.125, 0.14))
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    for k in range(46):
        var a := rng.randf_range(0.0, TAU)
        var rr := rng.randf_range(0.0, 1.0)
        c.draw_arc(Vector2(mx + cos(a) * rr * 46.0 * S, my - 2.0 * S + sin(a) * rr * 10.0 * S), 3.0 * S, 0.0, TAU, 6, Color(0.55, 0.58, 0.62, 0.35 + 0.4 * rng.randf()), 1.0)
    var bx := 0.405 * w
    var by := (FLOOR_Y + 0.062) * h
    _ell(c, Vector2(bx, by), 54.0 * S, 8.0 * S, Color(0.20, 0.015, 0.012, 0.85))
    _ell(c, Vector2(bx - 10.0 * S, by - 1.0 * S), 28.0 * S, 4.0 * S, Color(0.45, 0.06, 0.04, 0.35))

# ================= Передній план (перед крамарем): навіс і прилавок =================
func _draw_front() -> void:
    var c := front
    var w := size.x
    var h := size.y
    var S := h / 720.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 91

    # --- драпірування навісу: смуги з рваним краєм ---
    var n := 12
    var xa := 0.080 * w
    var xb := 0.580 * w
    var ytop := AWN_Y * h
    var ybot := (AWN_Y + 0.062) * h
    for k in range(n):
        var x0 := lerpf(xa, xb, float(k) / float(n))
        var x1 := lerpf(xa, xb, float(k + 1) / float(n))
        var col := Color(0.26, 0.052, 0.042)
        if k % 2 == 1:
            col = Color(0.20, 0.155, 0.105)
        var depth := rng.randf_range(10.0, 24.0) * S
        var pts := PackedVector2Array()
        pts.append(Vector2(x0, ytop))
        pts.append(Vector2(x1, ytop))
        for j in range(7):
            var a := float(j) / 6.0 * PI
            pts.append(Vector2((x0 + x1) * 0.5 + cos(a) * (x1 - x0) * 0.5, ybot + sin(a) * depth))
        c.draw_colored_polygon(pts, col)
        c.draw_line(Vector2(x0, ytop), Vector2(x0, ybot), Color(0, 0, 0, 0.35), 1.5)
        # тіні від складок і потерті плями
        c.draw_rect(Rect2(x0, ytop, (x1 - x0) * 0.5, ybot - ytop), Color(0, 0, 0, 0.10))
    c.draw_rect(Rect2(xa, ytop, xb - xa, 7.0 * S), Color(0, 0, 0, 0.45))
    c.draw_rect(Rect2(xa, ytop + 8.0 * S, xb - xa, (ybot - ytop) * 0.55), Color(0, 0, 0, 0.14))
    # павутина в лівому куті
    var wc := Color(0.75, 0.75, 0.8, 0.20)
    var ox := xa + 6.0 * S
    var oy := ytop + 2.0 * S
    for k in range(6):
        var a2 := float(k) * (PI * 0.5) / 5.0
        c.draw_line(Vector2(ox, oy), Vector2(ox + cos(a2) * 80.0 * S, oy + sin(a2) * 80.0 * S), wc, 1.0)
    for k in range(1, 5):
        var rr := 80.0 * S * float(k) / 4.5
        var prev := Vector2(ox + rr, oy)
        for j in range(1, 6):
            var a3 := float(j) * (PI * 0.5) / 5.0
            var pp := Vector2(ox + cos(a3) * rr * 0.92, oy + sin(a3) * rr * 0.92)
            c.draw_line(prev, pp, wc, 1.0)
            prev = pp

    # --- прилавок ---
    var cx0 := CTR_X0 * w
    var cx1 := CTR_X1 * w
    var cy := CTR_Y * h
    var fy := (FLOOR_Y + 0.004) * h
    c.draw_rect(Rect2(cx0, cy, cx1 - cx0, fy - cy), Color(0.085, 0.052, 0.032))
    var px := cx0
    while px < cx1:
        c.draw_line(Vector2(px, cy), Vector2(px, fy), Color(0, 0, 0, 0.38), 1.5)
        px += 34.0 * S
    c.draw_line(Vector2(cx0, cy + 12.0 * S), Vector2(cx0, fy), Color(1.0, 0.6, 0.25, 0.20), 2.0)
    # рвана червона тканина, перекинута через прилавок, зі слідами крові
    var cl0 := 0.205 * w
    var cl1 := 0.445 * w
    var clp := PackedVector2Array()
    clp.append(Vector2(cl0, cy))
    clp.append(Vector2(cl1, cy))
    var steps := 12
    for k in range(steps + 1):
        var fk := float(k) / float(steps)
        var xx := lerpf(cl1, cl0, fk)
        var yy := cy + (50.0 + 26.0 * sin(fk * 11.0) + 14.0 * rng.randf()) * S
        clp.append(Vector2(xx, yy))
    c.draw_colored_polygon(clp, Color(0.17, 0.03, 0.025))
    for k in range(1, 12):
        var fk2 := float(k) / 12.0
        c.draw_line(Vector2(lerpf(cl0, cl1, fk2), cy), Vector2(lerpf(cl0, cl1, fk2) + sin(fk2 * 20.0) * 4.0 * S, cy + 58.0 * S), Color(0, 0, 0, 0.30), 1.5)
    for k in range(7):
        var bxp := lerpf(cl0 + 14.0 * S, cl1 - 14.0 * S, rng.randf())
        var byp := cy + rng.randf_range(14.0, 40.0) * S
        _ell(c, Vector2(bxp, byp), rng.randf_range(4.0, 9.0) * S, rng.randf_range(3.0, 6.0) * S, Color(0.30, 0.02, 0.015, 0.85))
        c.draw_line(Vector2(bxp, byp), Vector2(bxp, byp + rng.randf_range(10.0, 26.0) * S), Color(0.30, 0.02, 0.015, 0.8), 2.0 * S)
    # стільниця
    c.draw_rect(Rect2(cx0 - 10.0 * S, cy - 7.0 * S, cx1 - cx0 + 20.0 * S, 14.0 * S), Color(0.13, 0.082, 0.05))
    c.draw_line(Vector2(cx0 - 10.0 * S, cy - 7.0 * S), Vector2(cx1 + 10.0 * S, cy - 7.0 * S), Color(1.0, 0.65, 0.3, 0.38), 1.5)
    c.draw_rect(Rect2(cx0 - 10.0 * S, cy + 7.0 * S, cx1 - cx0 + 20.0 * S, 5.0 * S), Color(0, 0, 0, 0.5))

    # --- товар на прилавку ---
    var top := cy - 7.0 * S
    _kettle(c, Vector2(0.200 * w, top - 23.0 * S), S, 1.0)
    _gauntlet(c, Vector2(0.250 * w, top), S, 1.0)
    _gauntlet(c, Vector2(0.272 * w, top - 2.0 * S), S * 0.95, 0.9)
    # мішечок із монетами
    _ell(c, Vector2(0.300 * w, top - 10.0 * S), 14.0 * S, 12.0 * S, Color(0.16, 0.10, 0.06))
    c.draw_line(Vector2(0.300 * w - 7.0 * S, top - 20.0 * S), Vector2(0.300 * w + 7.0 * S, top - 20.0 * S), Color(0.3, 0.2, 0.1), 3.0 * S)
    for k in range(3):
        _ell(c, Vector2(0.318 * w + float(k) * 7.0 * S, top - 2.0 * S), 5.0 * S, 1.8 * S, Color(0.75, 0.6, 0.18))
    # череп зі свічкою
    var sx := 0.478 * w
    _skull(c, Vector2(sx, top - 17.0 * S), 15.0 * S, Color(0.50, 0.46, 0.38))
    c.draw_rect(Rect2(sx - 4.0 * S, top - 55.0 * S, 8.0 * S, 24.0 * S), Color(0.62, 0.56, 0.42))
    c.draw_line(Vector2(sx - 4.0 * S, top - 55.0 * S), Vector2(sx - 4.0 * S, top - 31.0 * S), Color(1.0, 0.8, 0.4, 0.4), 1.5)
    _ell(c, Vector2(sx - 6.0 * S, top - 33.0 * S), 3.0 * S, 7.0 * S, Color(0.62, 0.56, 0.42))
    # чоботи
    _boot(c, Vector2(0.510 * w, top), S, 1.0, 1.0)
    _boot(c, Vector2(0.522 * w, top - 1.0 * S), S * 0.95, -1.0, 0.9)

# ================= Динамічна частина =================
func _lift() -> float:
    if _call < 0.0:
        return 0.0
    var k := _call / CALL_LEN
    if k < 0.18:
        return smoothstep(0.0, 0.18, k)
    if k < 0.78:
        return 1.0
    return 1.0 - smoothstep(0.78, 1.0, k)

func _draw_dynamic() -> void:
    var c := dyn
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_far_zombie(c, w, h, S)
    _raven_perched(c, Vector2(0.50 * w, (AWN_Y - 0.064) * h), S)
    _draw_merchant(c, w, h, S)
    for i in range(3):
        _draw_lantern(c, i, w, h, S)

func _draw_far_zombie(c: Control, w: float, h: float, S: float) -> void:
    var zx := 0.875 * w
    var zy := (FLOOR_Y - 0.012) * h
    var sway := sin(t * 0.55) * 3.0 * S
    var ink := Color(0.012, 0.014, 0.02, 0.92)
    var s2 := S * 0.95
    _poly(c, [Vector2(zx - 14.0 * s2, zy), Vector2(zx - 18.0 * s2 + sway * 0.4, zy - 70.0 * s2), Vector2(zx - 12.0 * s2 + sway, zy - 118.0 * s2), Vector2(zx + 14.0 * s2 + sway, zy - 118.0 * s2), Vector2(zx + 17.0 * s2 + sway * 0.4, zy - 70.0 * s2), Vector2(zx + 12.0 * s2, zy)], ink)
    c.draw_line(Vector2(zx + sway, zy - 108.0 * s2), Vector2(zx - 40.0 * s2 + sway, zy - 100.0 * s2 + sin(t * 0.8) * 4.0 * S), ink, 7.0 * s2)
    c.draw_line(Vector2(zx + sway, zy - 108.0 * s2), Vector2(zx + 36.0 * s2 + sway, zy - 82.0 * s2), ink, 7.0 * s2)
    _ell(c, Vector2(zx + 3.0 * s2 + sway * 1.3, zy - 132.0 * s2), 11.0 * s2, 13.0 * s2, ink)
    var eg := 0.35 + 0.5 * maxf(0.0, sin(t * 1.7 + 1.0))
    c.draw_circle(Vector2(zx - 1.0 * s2 + sway * 1.3, zy - 134.0 * s2), 1.8 * s2, Color(1.0, 0.15, 0.1, eg))
    c.draw_circle(Vector2(zx + 7.0 * s2 + sway * 1.3, zy - 134.0 * s2), 1.8 * s2, Color(1.0, 0.15, 0.1, eg))

func _draw_merchant(c: Control, w: float, h: float, S: float) -> void:
    var ax := MER_X * w
    var cy := CTR_Y * h
    var lift := _lift()
    var br := sin(t * 1.5) * 2.0 * S
    var sy := cy - 118.0 * S + br + lift * 4.0 * S
    var cloak := Color(0.075, 0.060, 0.055)
    var skin := Color(0.42, 0.38, 0.32)

    # плащ
    _poly(c, [Vector2(ax - 90.0 * S, cy + 6.0 * S), Vector2(ax - 76.0 * S, sy + 22.0 * S), Vector2(ax - 48.0 * S, sy - 4.0 * S), Vector2(ax + 48.0 * S, sy - 4.0 * S), Vector2(ax + 76.0 * S, sy + 22.0 * S), Vector2(ax + 90.0 * S, cy + 6.0 * S)], cloak)
    for k in range(-3, 4):
        c.draw_line(Vector2(ax + float(k) * 22.0 * S, sy + 6.0 * S), Vector2(ax + float(k) * 30.0 * S, cy), Color(0, 0, 0, 0.30), 2.0 * S)
    # відблиск ліхтаря на лівому плечі
    c.draw_line(Vector2(ax - 48.0 * S, sy - 4.0 * S), Vector2(ax - 76.0 * S, sy + 22.0 * S), Color(1.0, 0.55, 0.22, 0.40), 3.0 * S)
    # шкіряний ремінь
    c.draw_line(Vector2(ax - 44.0 * S, sy + 2.0 * S), Vector2(ax + 52.0 * S, cy - 40.0 * S), Color(0.13, 0.075, 0.04), 8.0 * S)
    c.draw_rect(Rect2(ax + 4.0 * S, sy + 28.0 * S, 9.0 * S, 9.0 * S), Color(0.55, 0.45, 0.2, 0.8))

    # каптур: гострий верх, глибока тінь, світні очі
    var hx := ax + sin(t * 0.5) * 6.0 * S
    var hy := sy - 40.0 * S + lift * 8.0 * S
    _poly(c, [Vector2(hx - 40.0 * S, hy - 10.0 * S), Vector2(hx - 18.0 * S, hy - 96.0 * S), Vector2(hx + 34.0 * S, hy - 20.0 * S)], cloak.lightened(0.02))
    _ell(c, Vector2(hx, hy), 47.0 * S, 54.0 * S, cloak.lightened(0.04))
    c.draw_arc(Vector2(hx, hy), 49.0 * S, PI * 0.66, PI * 1.28, 14, Color(1.0, 0.55, 0.22, 0.50), 3.0 * S)
    _ell(c, Vector2(hx + 3.0 * S, hy + 6.0 * S), 29.0 * S, 37.0 * S, Color(0.006, 0.005, 0.005))
    # очі (блимають раз на кілька секунд)
    var ph := fmod(t, 4.3)
    var ey := 2.6 * S
    if ph > 4.15:
        ey = 0.5 * S
    var eg := 0.80 + 0.20 * sin(t * 3.0) + 0.5 * lift
    var ec := Color(0.95, 0.98, 0.45, minf(eg, 1.0))
    var e1 := Vector2(hx - 10.0 * S, hy - 2.0 * S)
    var e2 := Vector2(hx + 13.0 * S, hy - 1.0 * S)
    c.draw_circle(e1, 15.0 * S, Color(0.6, 0.9, 0.3, 0.10 + 0.12 * lift))
    c.draw_circle(e2, 15.0 * S, Color(0.6, 0.9, 0.3, 0.10 + 0.12 * lift))
    _ell(c, e1, 5.2 * S, ey, ec)
    _ell(c, e2, 4.4 * S, ey * 0.9, ec)
    # вищир: майже невидимий у спокої, широкий і білий, коли показує товар
    var ga := 0.10 + 0.90 * lift
    var gc := Vector2(hx + 2.0 * S, hy + 11.0 * S)
    c.draw_arc(gc, 15.0 * S, PI * 0.12, PI * 0.88, 16, Color(0.88, 0.82, 0.66, ga), 3.0 * S)
    for k in range(7):
        var a := PI * 0.18 + float(k) * (PI * 0.64) / 6.0
        c.draw_line(gc + Vector2.from_angle(a) * 12.5 * S, gc + Vector2.from_angle(a) * 17.5 * S, Color(0.1, 0.06, 0.05, ga), 1.5)

    # ліва рука (у кадрі ліворуч): лежить на прилавку, пальці постукують
    var lsh := Vector2(ax - 64.0 * S, sy + 18.0 * S)
    var lhand := Vector2(ax - 84.0 * S, cy - 12.0 * S)
    var lel := _ik(lsh, lhand, 92.0 * S, 86.0 * S, -1.0)
    c.draw_line(lsh, lel, cloak.lightened(0.05), 34.0 * S)
    c.draw_circle(lel, 17.0 * S, cloak.lightened(0.05))
    c.draw_line(lel, lhand, skin.darkened(0.25), 11.0 * S)
    var tap := maxf(0.0, sin(t * 6.0)) * (1.0 - lift) * 3.0 * S
    for k in range(4):
        var fa := -0.3 + float(k) * 0.22
        c.draw_line(lhand, lhand + Vector2(cos(fa + PI) * 24.0 * S, sin(fa) * 5.0 * S - tap * float(k % 2)), skin.darkened(0.15), 4.0 * S)
    c.draw_circle(lhand, 7.0 * S, skin.darkened(0.2))

    # права рука з шоломом: піднімає його до глядача
    var rsh := Vector2(ax + 64.0 * S, sy + 18.0 * S)
    var rest := Vector2(ax + 80.0 * S, cy - 14.0 * S)
    var up := Vector2(ax + 104.0 * S, sy + 4.0 * S)
    var rhand := rest.lerp(up, lift)
    var rel := _ik(rsh, rhand, 92.0 * S, 86.0 * S, 1.0)
    c.draw_line(rsh, rel, cloak.lightened(0.05), 34.0 * S)
    c.draw_circle(rel, 17.0 * S, cloak.lightened(0.05))
    c.draw_line(rel, rhand, skin.darkened(0.2), 11.0 * S)
    var helm_c := rhand + Vector2(0.0, -22.0 * S) + Vector2(sin(t * 9.0) * lift * 1.2 * S, 0.0)
    _kettle(c, helm_c, S * 1.05, 1.15)
    for k in range(4):
        c.draw_line(rhand + Vector2(float(k) * 3.0 * S - 4.0 * S, 0.0), rhand + Vector2(float(k) * 3.0 * S - 6.0 * S, -14.0 * S), skin.darkened(0.1), 3.5 * S)
    c.draw_circle(rhand, 6.5 * S, skin.darkened(0.15))

func _draw_fx() -> void:
    var c := fx
    var w := size.x
    var h := size.y
    var S := h / 720.0

    # відблиски на кільцях кольчуги
    for gl in [[0.052, 0.60, 0.0], [0.045, 0.66, 2.1], [0.165, 0.60, 1.0], [0.158, 0.66, 3.3]]:
        var gp := Vector2(float(gl[0]) * w, float(gl[1]) * h)
        var ga := pow(maxf(0.0, sin(t * 1.2 + float(gl[2]))), 10.0)
        if ga > 0.02:
            c.draw_line(gp - Vector2(10.0 * S, 0.0), gp + Vector2(10.0 * S, 0.0), Color(1.0, 0.95, 0.8, ga * 0.9), 1.5)
            c.draw_line(gp - Vector2(0.0, 10.0 * S), gp + Vector2(0.0, 10.0 * S), Color(1.0, 0.95, 0.8, ga * 0.9), 1.5)
            c.draw_circle(gp, 2.5 * S, Color(1.0, 1.0, 0.9, ga))

    # відсвіти ліхтарів
    for i in range(3):
        var lp := _lamp_pos(i, w, h, S)
        var gc := Color(1.0, 0.55, 0.2, 0.035)
        var rad := 210.0 * S
        if i >= 1:
            gc = Color(0.45, 0.95, 0.35, 0.03)
            rad = 180.0 * S
        _glow(c, lp, rad, gc, 1.0 + 0.1 * sin(t * 9.0 + float(i)))

    # свічка на черепі
    var cp := Vector2(0.478 * w, (CTR_Y - 0.092) * h - 4.0 * S)
    var fl := 1.0 + 0.2 * sin(t * 10.0) + 0.1 * sin(t * 23.0)
    _glow(c, cp, 70.0 * S, Color(1.0, 0.6, 0.2, 0.06), fl)
    _ell(c, cp, 4.0 * S * fl, 9.0 * S * fl, Color(1.0, 0.55, 0.12, 0.92))
    _ell(c, cp + Vector2(0.0, 2.0 * S), 2.0 * S, 5.0 * S, Color(1.0, 0.95, 0.7, 0.95))

    # очі в ящику
    var ep := sin(t * 0.45) + 0.3 * sin(t * 1.9)
    var ea := smoothstep(0.25, 0.55, ep)
    if fmod(t, 5.7) > 5.55:
        ea = 0.0
    if ea > 0.01:
        var cx := 0.118 * w
        var ey := (FLOOR_Y + 0.012) * h - 64.0 * S + 27.0 * S
        for sgn in [-1.0, 1.0]:
            var epos := Vector2(cx + float(sgn) * 10.0 * S, ey)
            c.draw_circle(epos, 8.0 * S, Color(1.0, 0.8, 0.15, 0.10 * ea))
            _ell(c, epos, 3.4 * S, 2.2 * S, Color(1.0, 0.85, 0.2, ea))

    # ворон-прибулець над дахами
    if _fly >= 0.0:
        var k := _fly / 9.0
        var fx_ := lerpf(1.1, -0.1, k) * w
        var fy := (0.10 + 0.05 * sin(k * 5.0)) * h
        _raven_flying(c, Vector2(fx_, fy), S * 1.1, -1.0, t)

    # туман над бруківкою
    for f in _fog:
        var fx0: float = f[0]
        var fxp := fposmod(fx0 + t * float(f[2]), 1.4) - 0.2
        var fyp: float = f[1]
        var r: float = f[3]
        var al := 0.030 + 0.012 * sin(t * 0.4 + float(f[4]))
        c.draw_circle(Vector2(fxp * w, fyp * h + sin(t * 0.3 + float(f[4])) * 4.0 * S), r * S, Color(0.55, 0.60, 0.66, al))
        c.draw_circle(Vector2(fxp * w, fyp * h), r * S * 0.6, Color(0.55, 0.60, 0.66, al * 0.8))

    # пил і попіл у повітрі
    for d in _dust:
        var dp: Vector2 = d[0]
        var tw := 0.25 + 0.25 * sin(t * 1.5 + float(d[1]))
        c.draw_circle(Vector2(dp.x * w, dp.y * h), float(d[2]) * S, Color(1.0, 0.8, 0.5, tw * 0.6))
