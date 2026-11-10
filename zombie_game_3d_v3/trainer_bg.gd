extends Control
# Фон екрана «Навики»: похмурий середньовічний тренувальний зал.
# Кам'яна стіна й земляно-кам'яна підлога, два смолоскипи, що тремтять, у глибині мовчки стоїть тренер:
# рогатий важкий шолом із тліючими очима, плащ у лахмітті, обидві руки на руків'ї меча, встромленого в землю.
# Він нікуди не поспішає — просто чекає на тебе (дихає, ледь повертає голову, очі іноді спалахують).
# Навколо мінімум спорядження: манекен із порубаною соломою, стійка з навчальною зброєю, щит,
# кам'яна штанга й гиря, підвішений мішок на ланцюзі, кістки й плями крові на землі.
# Стіна, підлога й світло — шейдером; предмети — у _draw_static (раз); тренер, вогонь, мішок, туман, жарини — щокадру.
#
# Координати сцени — частки екрана (0..1). Ліва нижня частина екрана лишається вільною від карток навиків,
# тож усе головне (тренер, манекен, стійка) стоїть саме там.

const TR_X := 0.285        # тренер: центр по X
const TR_Y := 0.915        # тренер: де стоять ноги
const TORCH1_X := 0.165    # смолоскипи
const TORCH2_X := 0.455
const TORCH_Y := 0.575
const BAG_X := 0.405       # підвішений мішок
const FLOOR_Y := 0.74

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

void fragment() {
    vec2 uv = UV;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float floor_y = 0.74;

    // --- стародавня кам'яна стіна ---
    vec2 g = vec2(p.x * 5.0, p.y * 9.0);
    float rw = floor(g.y);
    g.x += mod(rw, 2.0) * 0.5;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float edge = min(min(f.x, 1.0 - f.x) * 1.5, min(f.y, 1.0 - f.y) * 3.0);
    float mortar = 1.0 - smoothstep(0.04, 0.15, edge);
    vec3 stone = mix(vec3(0.11, 0.10, 0.095), vec3(0.26, 0.23, 0.20), hash(id));
    stone *= 0.50 + 0.80 * fbm(p * 11.0);
    stone *= 0.70 + 0.40 * smoothstep(0.0, 0.4, edge);
    // сирі патьоки й мох унизу стіни
    float damp = smoothstep(0.35, 0.95, fbm(vec2(p.x * 7.0, p.y * 1.5 + 4.0))) * smoothstep(0.30, 0.74, uv.y);
    stone = mix(stone, vec3(0.05, 0.075, 0.05), damp * 0.55);
    vec3 col = mix(stone, vec3(0.02, 0.016, 0.014), mortar);
    col *= 0.45 + 0.55 * smoothstep(0.0, 0.5, uv.y);

    // --- підлога: плити, засипані землею й соломою ---
    if (uv.y > floor_y) {
        float fy = uv.y - (floor_y - 0.14);
        float u = (uv.x - 0.5) / fy;
        float v = 1.0 / fy;
        float sx = floor(u * 1.6);
        float sy = floor(v * 1.1);
        vec3 fl = mix(vec3(0.075, 0.062, 0.05), vec3(0.19, 0.155, 0.12), hash(vec2(sx, sy)));
        fl *= 0.60 + 0.65 * fbm(vec2(u * 6.0, v * 2.5));
        float gx = smoothstep(0.0, 0.05, min(fract(u * 1.6), 1.0 - fract(u * 1.6)));
        float gy = smoothstep(0.0, 0.07, fract(v * 1.1));
        fl *= 0.30 + 0.70 * gx * gy;
        float dirt = smoothstep(0.42, 0.72, fbm(vec2(u * 2.2 + 3.0, v * 1.4)));
        vec3 sand = vec3(0.17, 0.125, 0.08) * (0.65 + 0.7 * fbm(vec2(u * 18.0, v * 7.0)));
        fl = mix(fl, sand, dirt * 0.85);
        col = fl;
        if (uv.y < floor_y + 0.006) {
            col = vec3(0.03, 0.025, 0.02);
        }
    }

    // --- світло: два смолоскипи (тремтять), ледь помітний холодний місяць зверху ---
    float f1 = 1.0 + 0.16 * sin(time * 9.0) + 0.10 * sin(time * 17.0 + 1.0) + 0.07 * sin(time * 31.0 + 2.0);
    float f2 = 1.0 + 0.15 * sin(time * 8.0 + 2.0) + 0.10 * sin(time * 19.0 + 0.5) + 0.07 * sin(time * 27.0);
    vec2 t1 = vec2(0.165 * aspect, 0.57);
    vec2 t2 = vec2(0.455 * aspect, 0.57);
    float d1 = length((p - t1) * vec2(0.9, 1.0));
    float d2 = length((p - t2) * vec2(0.9, 1.0));
    float l1 = exp(-d1 * d1 * 4.2) * f1;
    float l2 = exp(-d2 * d2 * 4.2) * f2;
    float dm = length((p - vec2(0.62 * aspect, 0.02)) * vec2(1.0, 0.8));
    float moon = exp(-dm * dm * 2.0);
    vec3 warm = vec3(1.0, 0.54, 0.21);
    vec3 amb = vec3(0.045, 0.050, 0.075);
    col *= amb + warm * (l1 + l2) * 1.75 + vec3(0.10, 0.14, 0.22) * moon * 0.40;

    // дим і низький холодний туман
    float haze = fbm(vec2(p.x * 3.0 + time * 0.04, p.y * 2.0 - time * 0.06));
    col += vec3(0.30, 0.13, 0.05) * haze * (l1 + l2) * 0.09;
    col += vec3(0.05, 0.07, 0.10) * haze * 0.07 * smoothstep(0.55, 0.95, uv.y);

    // --- віньєтка ---
    vec2 q2 = uv - 0.5;
    col *= 1.0 - 0.85 * smoothstep(0.20, 0.80, length(q2 * vec2(1.0, 1.15)));
    col *= 0.45 + 0.55 * smoothstep(0.0, 0.28, uv.y);
    COLOR = vec4(col, 1.0);
}
"""

var t := 0.0
var back: ColorRect
var stat: Control   # малюється один раз (стійка, манекен, ланцюги, підлога)
var dyn: Control    # малюється щокадру (тренер, вогонь, мішок, туман, жарини)
var _parts: Array = []   # [позиція, швидкість, життя, макс. життя, розмір, тип 1=жарина 2=пилинка]
var _rng := RandomNumberGenerator.new()
var _o := Vector2.ZERO   # початок координат фігури тренера (ноги)
var _k := 1.0            # масштаб фігури

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

    stat = Control.new()
    stat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stat.draw.connect(_draw_static)
    add_child(stat)

    dyn = Control.new()
    dyn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dyn.draw.connect(_draw_dynamic)
    add_child(dyn)

    resized.connect(func() -> void: stat.queue_redraw())

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    delta = minf(delta, 0.05)
    t += delta
    var w := size.x
    var h := size.y
    var S := h / 720.0

    # жарини з обох смолоскипів
    for tx in [TORCH1_X, TORCH2_X]:
        if _rng.randf() < 0.25:
            var ex: float = float(tx) * w + _rng.randf_range(-8.0, 8.0) * S
            var ey := TORCH_Y * h - 20.0 * S
            _parts.append([Vector2(ex, ey), Vector2(_rng.randf_range(-12.0, 14.0) * S, _rng.randf_range(-90.0, -40.0) * S), 0.0, _rng.randf_range(1.2, 2.6), _rng.randf_range(1.1, 2.2), 1])
    # пил у повітрі
    if _rng.randf() < 0.10:
        _parts.append([Vector2(_rng.randf_range(0.0, w), _rng.randf_range(0.25, 0.90) * h), Vector2(_rng.randf_range(-6.0, 6.0) * S, _rng.randf_range(-5.0, 2.0) * S), 0.0, _rng.randf_range(6.0, 12.0), _rng.randf_range(0.9, 1.7), 2])

    var i := _parts.size() - 1
    while i >= 0:
        var sp: Array = _parts[i]
        var pos: Vector2 = sp[0]
        var vel: Vector2 = sp[1]
        var life: float = sp[2] + delta
        vel.x += sin(t * 2.3 + pos.y * 0.02) * 22.0 * S * delta
        pos += vel * delta
        sp[0] = pos
        sp[1] = vel
        sp[2] = life
        if life >= float(sp[3]) or pos.y < -20.0 or pos.y > h + 20.0:
            _parts.remove_at(i)
        i -= 1
    if _parts.size() > 320:
        _parts = _parts.slice(_parts.size() - 320)

    var sm := back.material as ShaderMaterial
    sm.set_shader_parameter("time", t)
    sm.set_shader_parameter("aspect", w / maxf(h, 1.0))
    dyn.queue_redraw()

# ================= Допоміжне малювання =================
func _ell(c: Control, p: Vector2, rx: float, ry: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(20):
        var ang := TAU * float(i) / 20.0
        pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
    c.draw_colored_polygon(pts, col)

func _poly(c: Control, pts: Array, col: Color) -> void:
    var pa := PackedVector2Array()
    for p in pts:
        pa.append(p)
    c.draw_colored_polygon(pa, col)

func _flame(c: Control, b: Vector2, hgt: float, wd: float, sway: float, col: Color) -> void:
    _poly(c, [
        Vector2(b.x - wd, b.y),
        Vector2(b.x - wd * 0.75 + sway * 0.3, b.y - hgt * 0.45),
        Vector2(b.x + sway, b.y - hgt),
        Vector2(b.x + wd * 0.75 + sway * 0.3, b.y - hgt * 0.45),
        Vector2(b.x + wd, b.y),
    ], col)

# Точка в системі координат тренера: x вправо, y вгору (мінус), одиниці «проєктні», множаться на масштаб.
func _q(x: float, y: float) -> Vector2:
    return Vector2(_o.x + x * _k, _o.y + y * _k)

# ================= Статична частина =================
func _draw_static() -> void:
    var c := stat
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_ceiling(c, w, h, S)
    _draw_banner(c, 0.70 * w, 0.045 * h, 118.0 * S, 0.34 * h, S)
    _draw_banner(c, 0.915 * w, 0.045 * h, 100.0 * S, 0.26 * h, S)
    _draw_wall_shackles(c, w, h, S)
    _draw_floor_stuff(c, w, h, S)
    _draw_dummy(c, w, h, S)
    _draw_rack(c, w, h, S)
    _draw_weights(c, w, h, S)
    _draw_torch_brackets(c, w, h, S)
    _draw_skull_bones(c, w, h, S)
    _draw_cobweb(c, 0.0, 0.0, S, 1.0)

func _draw_ceiling(c: Control, w: float, h: float, S: float) -> void:
    # важка балка під стелею та поперечні крокви
    c.draw_rect(Rect2(0.0, 0.0, w, 0.05 * h), Color(0.045, 0.03, 0.022))
    c.draw_rect(Rect2(0.0, 0.05 * h, w, 4.0 * S), Color(0.02, 0.014, 0.01))
    for i in range(7):
        c.draw_line(Vector2(0.0, (0.008 + 0.006 * float(i)) * h), Vector2(w, (0.008 + 0.006 * float(i)) * h), Color(0.0, 0.0, 0.0, 0.25), 1.0)
    for rx in [0.12, 0.38, 0.62, 0.88]:
        c.draw_rect(Rect2(float(rx) * w - 9.0 * S, 0.0, 18.0 * S, 0.075 * h), Color(0.035, 0.024, 0.018))

# Подерта стяжна з черепом.
func _draw_banner(c: Control, x: float, y: float, bw: float, bh: float, S: float) -> void:
    c.draw_rect(Rect2(x - bw * 0.5 - 6.0 * S, y, bw + 12.0 * S, 7.0 * S), Color(0.06, 0.04, 0.03))
    var pts: Array = [Vector2(x - bw * 0.5, y + 7.0 * S), Vector2(x + bw * 0.5, y + 7.0 * S)]
    var n := 6
    for i in range(n + 1):
        var k := float(i) / float(n)
        var bx := lerpf(bw * 0.5, -bw * 0.5, k)
        var dy := 0.0
        if i % 2 == 1:
            dy = -bh * 0.10 - float(i % 3) * 6.0 * S
        pts.append(Vector2(x + bx, y + bh + dy))
    _poly(c, pts, Color(0.16, 0.025, 0.03))
    c.draw_line(Vector2(x - bw * 0.5 + 6.0 * S, y + 10.0 * S), Vector2(x - bw * 0.5 + 6.0 * S, y + bh * 0.8), Color(0, 0, 0, 0.35), 3.0 * S)
    c.draw_line(Vector2(x + bw * 0.5 - 6.0 * S, y + 10.0 * S), Vector2(x + bw * 0.5 - 6.0 * S, y + bh * 0.8), Color(0, 0, 0, 0.35), 3.0 * S)
    # емблема: череп
    var ey := y + bh * 0.38
    var bone := Color(0.40, 0.36, 0.28)
    _ell(c, Vector2(x, ey), 17.0 * S, 18.0 * S, bone)
    c.draw_rect(Rect2(x - 9.0 * S, ey + 8.0 * S, 18.0 * S, 10.0 * S), bone.darkened(0.1))
    _ell(c, Vector2(x - 6.5 * S, ey - 1.0 * S), 4.5 * S, 5.5 * S, Color(0.02, 0.01, 0.01))
    _ell(c, Vector2(x + 6.5 * S, ey - 1.0 * S), 4.5 * S, 5.5 * S, Color(0.02, 0.01, 0.01))
    c.draw_line(Vector2(x - 24.0 * S, ey + 26.0 * S), Vector2(x + 24.0 * S, ey - 22.0 * S), bone.darkened(0.2), 3.0 * S)
    c.draw_line(Vector2(x + 24.0 * S, ey + 26.0 * S), Vector2(x - 24.0 * S, ey - 22.0 * S), bone.darkened(0.2), 3.0 * S)

func _chain(c: Control, top: Vector2, ln: float, S: float) -> void:
    var n := int(ln / (13.0 * S))
    for i in range(n):
        var p := top + Vector2(sin(float(i) * 0.15) * 2.0 * S, float(i) * 13.0 * S)
        if i % 2 == 0:
            _ell(c, p, 4.0 * S, 7.5 * S, Color(0.10, 0.09, 0.09))
            _ell(c, p, 2.0 * S, 5.0 * S, Color(0.02, 0.016, 0.014))
        else:
            _ell(c, p, 6.0 * S, 3.0 * S, Color(0.13, 0.115, 0.11))

# Кайдани на стіні — «для тих, хто не витримав навчання».
func _draw_wall_shackles(c: Control, w: float, h: float, S: float) -> void:
    var iron := Color(0.14, 0.12, 0.11)
    for sx in [0.605, 0.625]:
        var x := float(sx) * w
        c.draw_rect(Rect2(x - 8.0 * S, 0.30 * h, 16.0 * S, 7.0 * S), Color(0.07, 0.06, 0.06))
        _chain(c, Vector2(x, 0.30 * h + 6.0 * S), 0.20 * h, S)
        var ey := 0.30 * h + 6.0 * S + float(int(0.20 * h / (13.0 * S))) * 13.0 * S + 8.0 * S
        c.draw_arc(Vector2(x, ey + 12.0 * S), 13.0 * S, 0.0, TAU, 16, iron, 5.0 * S)
        c.draw_rect(Rect2(x - 4.0 * S, ey - 4.0 * S, 8.0 * S, 8.0 * S), iron)

func _draw_floor_stuff(c: Control, w: float, h: float, S: float) -> void:
    # плями крові на землі
    var bl := Color(0.20, 0.015, 0.015, 0.50)
    _ell(c, Vector2(0.115 * w, 0.955 * h), 58.0 * S, 7.0 * S, bl)
    _ell(c, Vector2(0.285 * w, 0.935 * h), 90.0 * S, 9.0 * S, Color(0.20, 0.015, 0.015, 0.34))
    _ell(c, Vector2(0.50 * w, 0.965 * h), 48.0 * S, 6.0 * S, bl)
    _ell(c, Vector2(0.62 * w, 0.90 * h), 34.0 * S, 5.0 * S, bl)
    # волочіння по землі
    c.draw_line(Vector2(0.115 * w, 0.955 * h), Vector2(0.20 * w, 0.985 * h), Color(0.18, 0.015, 0.015, 0.35), 4.0 * S)
    # розсипана солома
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    for i in range(110):
        var px := rng.randf_range(0.02, 0.72) * w
        var py := rng.randf_range(0.80, 0.995) * h
        var a := rng.randf_range(-0.5, 0.5)
        var ln := rng.randf_range(6.0, 16.0) * S
        c.draw_line(Vector2(px, py), Vector2(px + cos(a) * ln, py + sin(a) * ln * 0.4), Color(0.34, 0.27, 0.12, rng.randf_range(0.25, 0.6)), 1.4)

# Тренувальний манекен: стовп, соломʼяний тулуб, мішок-голова, порубаний і з вогнем у тілі.
func _draw_dummy(c: Control, w: float, h: float, S: float) -> void:
    var x := 0.085 * w
    var by := 0.935 * h
    var wood := Color(0.11, 0.07, 0.042)
    var straw := Color(0.22, 0.165, 0.085)
    _ell(c, Vector2(x, by), 62.0 * S, 8.0 * S, Color(0, 0, 0, 0.5))
    # хрестовина-основа й стовп
    c.draw_rect(Rect2(x - 46.0 * S, by - 12.0 * S, 92.0 * S, 12.0 * S), wood.darkened(0.15))
    c.draw_rect(Rect2(x - 8.0 * S, by - 218.0 * S, 16.0 * S, 210.0 * S), wood)
    c.draw_line(Vector2(x - 8.0 * S, by - 215.0 * S), Vector2(x - 8.0 * S, by - 10.0 * S), Color(1.0, 0.5, 0.2, 0.22), 2.0)
    # поперечка-руки
    c.draw_line(Vector2(x - 64.0 * S, by - 150.0 * S), Vector2(x + 64.0 * S, by - 150.0 * S), wood.lightened(0.04), 11.0 * S)
    # соломʼяний тулуб
    _ell(c, Vector2(x, by - 118.0 * S), 33.0 * S, 52.0 * S, straw.darkened(0.25))
    _ell(c, Vector2(x - 6.0 * S, by - 122.0 * S), 22.0 * S, 40.0 * S, straw.darkened(0.12))
    for i in range(4):
        c.draw_arc(Vector2(x, by - 160.0 * S + float(i) * 22.0 * S), 33.0 * S, PI * 0.15, PI * 0.85, 10, Color(0.08, 0.05, 0.03, 0.8), 2.0 * S)
    # глибокі рубані порізи й кров
    for i in range(3):
        var sx := x - 22.0 * S + float(i) * 16.0 * S
        c.draw_line(Vector2(sx, by - 150.0 * S + float(i) * 6.0 * S), Vector2(sx + 22.0 * S, by - 98.0 * S - float(i) * 4.0 * S), Color(0.04, 0.025, 0.015), 3.0 * S)
    _ell(c, Vector2(x + 8.0 * S, by - 116.0 * S), 12.0 * S, 18.0 * S, Color(0.22, 0.02, 0.02, 0.5))
    # голова-мішок
    _ell(c, Vector2(x, by - 196.0 * S), 23.0 * S, 24.0 * S, straw.darkened(0.2))
    c.draw_line(Vector2(x - 8.0 * S, by - 177.0 * S), Vector2(x + 8.0 * S, by - 177.0 * S), Color(0.07, 0.045, 0.03), 4.0 * S)
    _ell(c, Vector2(x - 8.0 * S, by - 199.0 * S), 3.5 * S, 4.5 * S, Color(0.02, 0.01, 0.01))
    _ell(c, Vector2(x + 8.0 * S, by - 199.0 * S), 3.5 * S, 4.5 * S, Color(0.02, 0.01, 0.01))
    for i in range(5):
        var mx := x - 10.0 * S + float(i) * 5.0 * S
        c.draw_line(Vector2(mx, by - 188.0 * S), Vector2(mx, by - 182.0 * S), Color(0.03, 0.02, 0.01), 1.5)
    c.draw_line(Vector2(x - 11.0 * S, by - 185.0 * S), Vector2(x + 11.0 * S, by - 185.0 * S), Color(0.03, 0.02, 0.01), 1.5)
    # іржавий меч, застряглий у тулубі
    var steel := Color(0.15, 0.14, 0.14)
    c.draw_line(Vector2(x + 14.0 * S, by - 126.0 * S), Vector2(x + 78.0 * S, by - 160.0 * S), steel, 5.0 * S)
    c.draw_line(Vector2(x + 76.0 * S, by - 175.0 * S), Vector2(x + 88.0 * S, by - 142.0 * S), Color(0.10, 0.07, 0.05), 5.0 * S)
    c.draw_circle(Vector2(x + 92.0 * S, by - 138.0 * S), 5.0 * S, Color(0.12, 0.10, 0.09))
    # зламана стріла в плечі
    c.draw_line(Vector2(x - 24.0 * S, by - 150.0 * S), Vector2(x - 56.0 * S, by - 188.0 * S), Color(0.16, 0.11, 0.07), 2.5 * S)
    _poly(c, [Vector2(x - 56.0 * S, by - 188.0 * S), Vector2(x - 62.0 * S, by - 200.0 * S), Vector2(x - 50.0 * S, by - 196.0 * S)], Color(0.22, 0.22, 0.20))

# Стійка з навчальною зброєю + щит.
func _draw_rack(c: Control, w: float, h: float, S: float) -> void:
    var rx := 0.545 * w
    var by := 0.935 * h
    var wood := Color(0.10, 0.063, 0.038)
    _ell(c, Vector2(rx, by), 96.0 * S, 9.0 * S, Color(0, 0, 0, 0.5))
    # зброя спирається на стійку
    var steel := Color(0.16, 0.16, 0.18)
    var haft := Color(0.13, 0.085, 0.05)
    for i in range(5):
        var bx := rx - 58.0 * S + float(i) * 29.0 * S
        var tilt := 0.03 * float((i % 2) * 2 - 1)
        var ln := (190.0 - 20.0 * float(i % 3)) * S
        var top := Vector2(bx + sin(tilt) * ln, by - 8.0 * S - cos(tilt) * ln)
        var bot := Vector2(bx, by - 8.0 * S)
        c.draw_line(bot, top, haft, 7.0 * S)
        c.draw_line(bot + Vector2(-2.0, 0.0), top + Vector2(-2.0, 0.0), Color(1.0, 0.5, 0.2, 0.15), 1.5)
        if i == 0 or i == 3:
            # спис / гелепарта
            _poly(c, [top + Vector2(-7.0 * S, 4.0 * S), top + Vector2(0.0, -30.0 * S), top + Vector2(7.0 * S, 4.0 * S)], steel)
            if i == 3:
                _poly(c, [top + Vector2(5.0 * S, 0.0), top + Vector2(30.0 * S, -8.0 * S), top + Vector2(30.0 * S, 24.0 * S), top + Vector2(5.0 * S, 20.0 * S)], steel.darkened(0.1))
        elif i == 1 or i == 4:
            # навчальний меч
            c.draw_line(top + Vector2(-14.0 * S, 12.0 * S), top + Vector2(14.0 * S, 12.0 * S), haft.lightened(0.05), 5.0 * S)
        else:
            # булава
            c.draw_circle(top, 13.0 * S, steel.darkened(0.15))
            for q in range(6):
                var a := TAU * float(q) / 6.0
                c.draw_line(top + Vector2(cos(a), sin(a)) * 11.0 * S, top + Vector2(cos(a), sin(a)) * 19.0 * S, steel, 3.0 * S)
    # рейки стійки
    c.draw_rect(Rect2(rx - 82.0 * S, by - 112.0 * S, 164.0 * S, 9.0 * S), wood)
    c.draw_rect(Rect2(rx - 82.0 * S, by - 62.0 * S, 164.0 * S, 9.0 * S), wood)
    c.draw_rect(Rect2(rx - 84.0 * S, by - 130.0 * S, 10.0 * S, 130.0 * S), wood.darkened(0.1))
    c.draw_rect(Rect2(rx + 74.0 * S, by - 130.0 * S, 10.0 * S, 130.0 * S), wood.darkened(0.1))
    c.draw_line(Vector2(rx - 82.0 * S, by - 112.0 * S), Vector2(rx + 82.0 * S, by - 112.0 * S), Color(1.0, 0.5, 0.2, 0.18), 1.5)
    # круглий щит, що стоїть збоку
    var sc := Vector2(rx - 124.0 * S, by - 38.0 * S)
    c.draw_circle(sc, 40.0 * S, Color(0.09, 0.055, 0.035))
    c.draw_arc(sc, 40.0 * S, 0.0, TAU, 28, Color(0.13, 0.12, 0.12), 4.0 * S)
    for q in range(4):
        var a2 := TAU * float(q) / 8.0
        c.draw_line(sc - Vector2(cos(a2), sin(a2)) * 38.0 * S, sc + Vector2(cos(a2), sin(a2)) * 38.0 * S, Color(0.0, 0.0, 0.0, 0.30), 2.0)
    c.draw_circle(sc, 10.0 * S, Color(0.16, 0.15, 0.15))
    c.draw_line(sc + Vector2(-34.0 * S, -10.0 * S), sc + Vector2(30.0 * S, 18.0 * S), Color(0.04, 0.02, 0.015), 3.5 * S)
    c.draw_line(sc + Vector2(-20.0 * S, -28.0 * S), sc + Vector2(16.0 * S, 8.0 * S), Color(0.04, 0.02, 0.015), 2.5 * S)

# Кам'яна штанга й гиря.
func _draw_weights(c: Control, w: float, h: float, S: float) -> void:
    var x := 0.175 * w
    var by := 0.962 * h
    var stone := Color(0.13, 0.12, 0.115)
    _ell(c, Vector2(x, by + 2.0 * S), 78.0 * S, 7.0 * S, Color(0, 0, 0, 0.45))
    c.draw_line(Vector2(x - 66.0 * S, by - 22.0 * S), Vector2(x + 66.0 * S, by - 22.0 * S), Color(0.10, 0.10, 0.11), 6.0 * S)
    for sg in [-1.0, 1.0]:
        var s: float = sg
        var dx := x + s * 54.0 * S
        _ell(c, Vector2(dx, by - 22.0 * S), 13.0 * S, 28.0 * S, stone.darkened(0.2))
        _ell(c, Vector2(dx - s * 4.0 * S, by - 22.0 * S), 10.0 * S, 24.0 * S, stone)
        c.draw_line(Vector2(dx - s * 12.0 * S, by - 40.0 * S), Vector2(dx - s * 12.0 * S, by - 6.0 * S), Color(1.0, 0.5, 0.2, 0.15), 2.0)
    # гиря
    var gx := x + 120.0 * S
    c.draw_circle(Vector2(gx, by - 14.0 * S), 17.0 * S, Color(0.07, 0.065, 0.07))
    c.draw_arc(Vector2(gx, by - 32.0 * S), 11.0 * S, PI, TAU, 10, Color(0.07, 0.065, 0.07), 5.0 * S)
    c.draw_arc(Vector2(gx, by - 14.0 * S), 17.0 * S, PI * 1.05, PI * 1.45, 6, Color(1.0, 0.5, 0.2, 0.3), 2.0)

func _draw_torch_brackets(c: Control, w: float, h: float, S: float) -> void:
    for tx in [TORCH1_X, TORCH2_X]:
        var x := float(tx) * w
        var y := TORCH_Y * h
        # настінна скоба й держак
        c.draw_rect(Rect2(x - 12.0 * S, y + 30.0 * S, 24.0 * S, 7.0 * S), Color(0.07, 0.06, 0.06))
        c.draw_line(Vector2(x, y), Vector2(x, y + 92.0 * S), Color(0.10, 0.06, 0.04), 9.0 * S)
        c.draw_arc(Vector2(x, y + 34.0 * S), 11.0 * S, 0.0, TAU, 12, Color(0.15, 0.13, 0.12), 3.5 * S)
        # промаслена ганчірка на навершші
        _poly(c, [Vector2(x - 9.0 * S, y + 4.0 * S), Vector2(x + 9.0 * S, y + 4.0 * S), Vector2(x + 12.0 * S, y - 12.0 * S), Vector2(x - 12.0 * S, y - 12.0 * S)], Color(0.06, 0.04, 0.03))
        c.draw_line(Vector2(x - 10.0 * S, y - 4.0 * S), Vector2(x + 10.0 * S, y - 4.0 * S), Color(1.0, 0.45, 0.1, 0.5), 2.0)

func _draw_skull_bones(c: Control, w: float, h: float, S: float) -> void:
    var bone := Color(0.46, 0.42, 0.35)
    var sx := 0.395 * w
    var sy := 0.962 * h
    _ell(c, Vector2(sx, sy + 3.0 * S), 22.0 * S, 5.0 * S, Color(0, 0, 0, 0.45))
    _ell(c, Vector2(sx, sy - 12.0 * S), 15.0 * S, 14.0 * S, bone)
    c.draw_rect(Rect2(sx - 8.0 * S, sy - 4.0 * S, 16.0 * S, 7.0 * S), bone.darkened(0.12))
    _ell(c, Vector2(sx - 5.5 * S, sy - 13.0 * S), 4.0 * S, 4.6 * S, Color(0.02, 0.01, 0.01))
    _ell(c, Vector2(sx + 5.5 * S, sy - 13.0 * S), 4.0 * S, 4.6 * S, Color(0.02, 0.01, 0.01))
    _poly(c, [Vector2(sx, sy - 9.0 * S), Vector2(sx - 2.0 * S, sy - 4.0 * S), Vector2(sx + 2.0 * S, sy - 4.0 * S)], Color(0.02, 0.01, 0.01))
    # кістки
    c.draw_line(Vector2(sx + 26.0 * S, sy - 1.0 * S), Vector2(sx + 62.0 * S, sy - 6.0 * S), bone.darkened(0.15), 5.0 * S)
    c.draw_circle(Vector2(sx + 26.0 * S, sy - 1.0 * S), 4.0 * S, bone.darkened(0.15))
    c.draw_circle(Vector2(sx + 63.0 * S, sy - 7.0 * S), 4.0 * S, bone.darkened(0.15))
    c.draw_line(Vector2(sx - 56.0 * S, sy - 3.0 * S), Vector2(sx - 30.0 * S, sy + 6.0 * S), bone.darkened(0.25), 4.0 * S)

func _draw_cobweb(c: Control, ox: float, oy: float, S: float, dir: float) -> void:
    var col := Color(0.75, 0.75, 0.8, 0.22)
    var r := 150.0 * S
    for i in range(6):
        var a := dir * (PI * 0.5 * float(i) / 5.0)
        c.draw_line(Vector2(ox, oy), Vector2(ox + cos(a) * r, oy + sin(a) * r), col, 1.0)
    for k in range(1, 5):
        var rr := r * float(k) / 4.5
        var prev := Vector2(ox + rr, oy)
        for i in range(1, 6):
            var a2 := PI * 0.5 * float(i) / 5.0
            var p := Vector2(ox + cos(a2) * rr * 0.9, oy + sin(a2) * rr * 0.9)
            c.draw_line(prev, p, col, 1.0)
            prev = p

# ================= Динамічна частина =================
func _draw_dynamic() -> void:
    var c := dyn
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_bag(c, w, h, S)
    _draw_trainer(c, w, h, S)
    _draw_torches(c, w, h, S)
    _draw_fog(c, w, h, S)
    _draw_particles(c, w, h, S)

# Підвішений на ланцюзі мішок із піском — ледь погойдується.
func _draw_bag(c: Control, w: float, h: float, S: float) -> void:
    var top := Vector2(BAG_X * w, 0.05 * h)
    var ln := 0.50 * h
    var a := 0.055 * sin(t * 0.8 + 1.0)
    var dir := Vector2(sin(a), cos(a))
    var n := int(ln / (11.0 * S))
    for i in range(n):
        var p := top + dir * float(i) * 11.0 * S
        if i % 2 == 0:
            _ell(c, p, 3.5 * S, 6.5 * S, Color(0.11, 0.10, 0.10))
        else:
            _ell(c, p, 5.0 * S, 2.8 * S, Color(0.14, 0.125, 0.12))
    var bc := top + dir * (ln + 62.0 * S)
    var sack := PackedVector2Array()
    for i in range(24):
        var ang := TAU * float(i) / 24.0
        var v := Vector2(cos(ang) * 33.0 * S, sin(ang) * 66.0 * S)
        sack.append(bc + v.rotated(a))
    c.draw_colored_polygon(sack, Color(0.17, 0.115, 0.07))
    var sack2 := PackedVector2Array()
    for i in range(24):
        var ang2 := TAU * float(i) / 24.0
        var v2 := Vector2(cos(ang2) * 20.0 * S - 6.0 * S, sin(ang2) * 52.0 * S)
        sack2.append(bc + v2.rotated(a))
    c.draw_colored_polygon(sack2, Color(0.22, 0.15, 0.09, 0.55))
    # мотузяні обручі, шви, латки
    for yy in [-34.0, 0.0, 34.0]:
        var yv: float = yy
        var p1 := bc + Vector2(-32.0 * S, yv * S).rotated(a)
        var p2 := bc + Vector2(32.0 * S, yv * S).rotated(a)
        c.draw_line(p1, p2, Color(0.07, 0.045, 0.03), 3.0 * S)
    c.draw_line(bc + Vector2(-8.0 * S, -52.0 * S).rotated(a), bc + Vector2(14.0 * S, 40.0 * S).rotated(a), Color(0.05, 0.03, 0.02), 2.0 * S)
    _ell(c, bc + Vector2(10.0 * S, 14.0 * S).rotated(a), 9.0 * S, 12.0 * S, Color(0.22, 0.02, 0.02, 0.45))
    # пісок, що сиплеться з пробоїни
    var leak := bc + Vector2(-12.0 * S, 58.0 * S).rotated(a)
    c.draw_line(leak, Vector2(leak.x, 0.935 * h), Color(0.38, 0.30, 0.16, 0.30), 1.5)
    _ell(c, Vector2(leak.x, 0.945 * h), 20.0 * S, 4.0 * S, Color(0.30, 0.23, 0.12, 0.6))

func _draw_torches(c: Control, w: float, h: float, S: float) -> void:
    var ids := [TORCH1_X, TORCH2_X]
    for n in range(2):
        var x: float = float(ids[n]) * w
        var b := Vector2(x, TORCH_Y * h - 8.0 * S)
        var ph := float(n) * 2.3
        var fl := 1.0 + 0.14 * sin(t * 9.0 + ph) + 0.09 * sin(t * 17.0 + 1.0 + ph)
        for g in range(5):
            c.draw_circle(b + Vector2(0.0, -26.0 * S), (34.0 + 40.0 * float(g)) * S * fl, Color(1.0, 0.45, 0.12, 0.034))
        var hgt := (62.0 + 20.0 * (0.5 + 0.5 * sin(t * 7.0 + ph))) * S
        var sway := sin(t * 5.0 + ph) * 7.0 * S
        _flame(c, b, hgt, 17.0 * S, sway, Color(0.9, 0.14, 0.03, 0.85))
        _flame(c, b, hgt * 0.72, 12.0 * S, sway * 0.8, Color(1.0, 0.48, 0.08, 0.9))
        _flame(c, b, hgt * 0.42, 7.0 * S, sway * 0.5, Color(1.0, 0.88, 0.40, 0.95))

# Тренер. Малюється в «проєктних» одиницях (_q), висота фігури ≈ 300.
func _draw_trainer(c: Control, w: float, h: float, S: float) -> void:
    _k = S * 0.80
    _o = Vector2(TR_X * w, TR_Y * h)
    var K := _k
    var br := sin(t * 1.5)                # дихання
    var bz := br * 1.6                    # підйом грудей
    var sway := sin(t * 0.55) * 2.0       # плащ колишеться
    var look := sin(t * 0.33) * 5.0       # повільний поворот голови
    var iron := Color(0.095, 0.095, 0.115)
    var iron_l := Color(0.20, 0.20, 0.23)
    var leather := Color(0.075, 0.05, 0.036)
    var cloak := Color(0.03, 0.018, 0.022)
    var warm := Color(1.0, 0.52, 0.20)

    _ell(c, _q(0.0, 2.0), 92.0 * K, 11.0 * K, Color(0, 0, 0, 0.6))

    # --- плащ у лахмітті ---
    var cp: Array = [_q(-66.0 + sway * 0.4, -232.0 + bz), _q(66.0 + sway * 0.4, -232.0 + bz)]
    var n := 10
    for i in range(n + 1):
        var kk := float(i) / float(n)
        var bx := lerpf(112.0, -112.0, kk)
        var by := -4.0
        if i % 2 == 1:
            by = -4.0 - 16.0 - float(i % 3) * 5.0
        by += sin(t * 1.1 + float(i) * 1.3) * 3.5
        cp.append(_q(bx + sway, by))
    _poly(c, cp, cloak)
    # складки плаща
    for f in range(5):
        var fx := -80.0 + float(f) * 40.0
        c.draw_line(_q(fx * 0.55, -226.0 + bz), _q(fx * 1.2 + sway, -30.0), Color(0, 0, 0, 0.5), 3.0 * K)
    c.draw_line(_q(-66.0, -232.0 + bz), _q(-110.0 + sway, -10.0), warm * Color(1, 1, 1, 0.20), 2.0)

    # --- ноги ---
    for sg in [-1.0, 1.0]:
        var s: float = sg
        var lx := s * 23.0
        _poly(c, [_q(lx - 18.0, -130.0), _q(lx + 18.0, -130.0), _q(lx + 14.0, -26.0), _q(lx - 14.0, -26.0)], leather.darkened(0.25))
        _poly(c, [_q(lx - 16.0, -84.0), _q(lx + 16.0, -84.0), _q(lx + 13.0, -24.0), _q(lx - 13.0, -24.0)], iron)
        c.draw_line(_q(lx - s * 15.0, -82.0), _q(lx - s * 12.0, -26.0), warm * Color(1, 1, 1, 0.28), 2.0)
        c.draw_circle(_q(lx, -86.0), 11.0 * K, iron_l)
        _ell(c, _q(lx + s * 5.0, -9.0), 24.0 * K, 10.5 * K, leather.darkened(0.1))
        c.draw_rect(Rect2(_q(lx - 14.0, -22.0), Vector2(28.0 * K, 5.0 * K)), iron_l.darkened(0.2))

    # --- подертий каптан ---
    _poly(c, [_q(-50.0, -134.0), _q(50.0, -134.0), _q(56.0, -76.0), _q(38.0, -86.0), _q(26.0, -64.0), _q(8.0, -82.0), _q(-6.0, -62.0), _q(-22.0, -80.0), _q(-38.0, -66.0), _q(-56.0, -78.0)], leather)
    c.draw_line(_q(0.0, -134.0), _q(1.0, -70.0), Color(0, 0, 0, 0.4), 2.0)

    # --- тулуб: кольчуга + нагрудна пластина ---
    _poly(c, [_q(-64.0, -232.0 + bz), _q(64.0, -232.0 + bz), _q(52.0, -130.0), _q(-52.0, -130.0)], Color(0.07, 0.075, 0.085))
    for i in range(6):
        var ry := -214.0 + float(i) * 14.0
        c.draw_line(_q(-54.0 + float(i) * 1.5, ry + bz * 0.5), _q(54.0 - float(i) * 1.5, ry + bz * 0.5), Color(0.0, 0.0, 0.0, 0.25), 1.5)
    _poly(c, [_q(-46.0, -226.0 + bz), _q(46.0, -226.0 + bz), _q(38.0, -158.0), _q(-38.0, -158.0)], iron)
    c.draw_line(_q(0.0, -226.0 + bz), _q(0.0, -158.0), iron_l, 2.5 * K)
    c.draw_line(_q(-44.0, -224.0 + bz), _q(-37.0, -160.0), warm * Color(1, 1, 1, 0.38), 3.0 * K)
    c.draw_line(_q(44.0, -224.0 + bz), _q(37.0, -160.0), warm * Color(1, 1, 1, 0.26), 3.0 * K)
    # шкіряний пояс із пряжкою
    c.draw_rect(Rect2(_q(-52.0, -142.0), Vector2(104.0 * K, 11.0 * K)), Color(0.10, 0.06, 0.04))
    c.draw_rect(Rect2(_q(-8.0, -144.0), Vector2(16.0 * K, 15.0 * K)), iron_l)
    # трофей: клаптик із черепом на поясі
    c.draw_circle(_q(34.0, -118.0), 6.5 * K, Color(0.42, 0.38, 0.30))
    c.draw_circle(_q(32.0, -119.0), 1.6 * K, Color(0.02, 0.01, 0.01))
    c.draw_circle(_q(36.0, -119.0), 1.6 * K, Color(0.02, 0.01, 0.01))

    # --- великий меч, встромлений у землю ---
    var steel := Color(0.27, 0.28, 0.32)
    _poly(c, [_q(-10.0, -178.0), _q(10.0, -178.0), _q(8.0, -22.0), _q(0.0, -2.0), _q(-8.0, -22.0)], steel)
    c.draw_line(_q(0.0, -176.0), _q(0.0, -10.0), steel.darkened(0.45), 2.5 * K)
    c.draw_line(_q(-9.0, -176.0), _q(-7.0, -24.0), Color(1.0, 0.7, 0.4, 0.45), 1.8)
    c.draw_line(_q(9.0, -176.0), _q(7.0, -24.0), Color(0.5, 0.6, 0.8, 0.30), 1.5)
    # іржа й зарубки на клинку
    c.draw_circle(_q(3.0, -110.0), 2.2 * K, Color(0.30, 0.12, 0.05, 0.7))
    c.draw_circle(_q(-4.0, -70.0), 2.8 * K, Color(0.30, 0.12, 0.05, 0.7))
    c.draw_circle(_q(2.0, -140.0), 2.0 * K, Color(0.30, 0.12, 0.05, 0.7))
    # хрестовина, руків'я, навершя
    c.draw_rect(Rect2(_q(-46.0, -186.0), Vector2(92.0 * K, 9.0 * K)), iron_l)
    c.draw_circle(_q(-46.0, -181.5), 5.5 * K, iron_l)
    c.draw_circle(_q(46.0, -181.5), 5.5 * K, iron_l)
    c.draw_line(_q(-46.0, -186.0), _q(46.0, -186.0), warm * Color(1, 1, 1, 0.35), 1.5)
    c.draw_line(_q(0.0, -186.0), _q(0.0, -212.0 + bz * 0.4), Color(0.06, 0.04, 0.03), 9.0 * K)
    c.draw_circle(_q(0.0, -216.0 + bz * 0.4), 9.5 * K, iron_l)

    # --- руки: обидві на навершші ---
    for sg in [-1.0, 1.0]:
        var s2: float = sg
        var sh := _q(s2 * 62.0, -224.0 + bz)
        var hd := _q(s2 * 7.0, -208.0 + bz * 0.4 - (6.0 if s2 > 0.0 else 0.0))
        var el := sh.lerp(hd, 0.5) + Vector2(s2 * 20.0 * K, 30.0 * K)
        c.draw_line(sh, el, Color(0.07, 0.07, 0.085), 27.0 * K)
        c.draw_line(el, hd, iron, 22.0 * K)
        c.draw_line(el + Vector2(-s2 * 8.0 * K, 0.0), hd + Vector2(-s2 * 6.0 * K, 0.0), warm * Color(1, 1, 1, 0.22), 2.0)
        c.draw_circle(el, 14.0 * K, iron_l.darkened(0.15))
        c.draw_circle(hd, 12.0 * K, Color(0.05, 0.04, 0.035))
        for fng in range(3):
            c.draw_line(hd + Vector2(-5.0 * K + float(fng) * 5.0 * K, -3.0 * K), hd + Vector2(-5.0 * K + float(fng) * 5.0 * K, 6.0 * K), Color(0, 0, 0, 0.55), 1.5)

    # --- наплічники зі шпичаками ---
    for sg in [-1.0, 1.0]:
        var s3: float = sg
        _poly(c, [_q(s3 * 56.0, -242.0 + bz), _q(s3 * 80.0, -246.0 + bz), _q(s3 * 92.0, -268.0 + bz), _q(s3 * 70.0, -250.0 + bz)], iron_l.darkened(0.1))
        _ell(c, _q(s3 * 70.0, -226.0 + bz), 30.0 * K, 21.0 * K, iron)
        c.draw_arc(_q(s3 * 70.0, -226.0 + bz), 30.0 * K, PI * 1.05, PI * 1.9, 12, warm * Color(1, 1, 1, 0.38 if s3 < 0.0 else 0.28), 2.5 * K)
        c.draw_circle(_q(s3 * 70.0, -226.0 + bz), 3.0 * K, iron_l)

    # --- шия ---
    c.draw_rect(Rect2(_q(-16.0, -246.0 + bz), Vector2(32.0 * K, 20.0 * K)), Color(0.045, 0.045, 0.055))

    # --- голова: важкий рогатий шолом ---
    var hz := bz * 1.3
    var hx := look
    var bone := Color(0.30, 0.27, 0.22)
    for sg in [-1.0, 1.0]:
        var s4: float = sg
        _poly(c, [_q(hx + s4 * 20.0, -284.0 + hz), _q(hx + s4 * 38.0, -278.0 + hz), _q(hx + s4 * 54.0, -298.0 + hz), _q(hx + s4 * 52.0, -334.0 + hz), _q(hx + s4 * 41.0, -306.0 + hz), _q(hx + s4 * 22.0, -298.0 + hz)], bone)
        c.draw_line(_q(hx + s4 * 38.0, -280.0 + hz), _q(hx + s4 * 51.0, -330.0 + hz), Color(0, 0, 0, 0.35), 1.5)
    _poly(c, [_q(hx - 25.0, -238.0 + hz), _q(hx + 25.0, -238.0 + hz), _q(hx + 27.0, -272.0 + hz), _q(hx + 21.0, -294.0 + hz), _q(hx, -302.0 + hz), _q(hx - 21.0, -294.0 + hz), _q(hx - 27.0, -272.0 + hz)], iron)
    # відблиск смолоскипів на шоломі
    c.draw_arc(_q(hx, -268.0 + hz), 27.0 * K, PI * 0.78, PI * 1.28, 8, warm * Color(1, 1, 1, 0.55), 3.0 * K)
    c.draw_arc(_q(hx, -268.0 + hz), 27.0 * K, -PI * 0.28, PI * 0.20, 8, warm * Color(1, 1, 1, 0.34), 3.0 * K)
    c.draw_line(_q(hx, -300.0 + hz), _q(hx, -238.0 + hz), iron_l.darkened(0.1), 2.5 * K)
    # проріз для очей і вентиляційні щілини
    _poly(c, [_q(hx - 21.0, -271.0 + hz), _q(hx + 21.0, -271.0 + hz), _q(hx + 19.0, -259.0 + hz), _q(hx - 19.0, -259.0 + hz)], Color(0.0, 0.0, 0.0))
    for q in range(4):
        c.draw_line(_q(hx - 8.0 + float(q) * 5.5, -252.0 + hz), _q(hx - 8.0 + float(q) * 5.5, -243.0 + hz), Color(0.0, 0.0, 0.0), 1.8)
    # тліючі очі
    var eg := 0.60 + 0.22 * sin(t * 1.7)
    if fmod(t, 7.0) < 0.35:
        eg += 0.35
    eg = clampf(eg, 0.0, 1.0)
    var e1 := _q(hx - 9.0 + look * 0.5, -265.0 + hz)
    var e2 := _q(hx + 9.0 + look * 0.5, -265.0 + hz)
    c.draw_circle(e1, 13.0 * K, Color(1.0, 0.22, 0.05, 0.10 * eg))
    c.draw_circle(e2, 13.0 * K, Color(1.0, 0.22, 0.05, 0.10 * eg))
    _ell(c, e1, 4.6 * K, 2.3 * K, Color(1.0, 0.38, 0.10, eg))
    _ell(c, e2, 4.6 * K, 2.3 * K, Color(1.0, 0.38, 0.10, eg))
    _ell(c, e1, 2.0 * K, 1.1 * K, Color(1.0, 0.9, 0.55, eg))
    _ell(c, e2, 2.0 * K, 1.1 * K, Color(1.0, 0.9, 0.55, eg))
    # холодна пара з-під шолома
    for q in range(3):
        var pk := fmod(t * 0.22 + float(q) / 3.0, 1.0)
        c.draw_circle(_q(hx + sin(t + float(q)) * 6.0, -246.0 - pk * 36.0 + hz), (4.0 + 10.0 * pk) * K, Color(0.7, 0.75, 0.85, 0.07 * (1.0 - pk)))

    # --- тінь від нижнього світла: тренер лишається силуетом, а не яскравою фігурою ---
    c.draw_rect(Rect2(_q(-120.0, -310.0), Vector2(240.0 * K, 310.0 * K)), Color(0.0, 0.0, 0.0, 0.12))

func _draw_fog(c: Control, w: float, h: float, S: float) -> void:
    for i in range(8):
        var fx := fmod(float(i) * 0.17 + t * 0.008 * float(1 + i % 3), 1.25) - 0.12
        var fy := (0.89 + 0.035 * float(i % 3)) * h
        _ell(c, Vector2(fx * w, fy), 210.0 * S, 26.0 * S, Color(0.55, 0.60, 0.70, 0.045))

func _draw_particles(c: Control, w: float, h: float, S: float) -> void:
    for sp in _parts:
        var pos: Vector2 = sp[0]
        var k: float = float(sp[2]) / float(sp[3])
        var sz: float = sp[4]
        if int(sp[5]) == 1:
            var a := (1.0 - k) * (0.5 + 0.5 * sin(t * 9.0 + pos.x))
            c.draw_circle(pos, sz, Color(1.0, 0.5, 0.12, a))
            c.draw_circle(pos, sz * 3.0, Color(1.0, 0.35, 0.05, a * 0.12))
        else:
            var a2 := sin(k * PI) * 0.35
            c.draw_circle(pos, sz, Color(0.85, 0.80, 0.70, a2))
