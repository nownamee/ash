extends Control
# Фон екрана зброї: темна моторошна кузня.
# Закопчена кам'яна стіна, велика піч із живим вогнем, ковач-силует за ковадлом: він заносить молот
# і б'є по розпеченому клинку, від кожного удару летять іскри, спалахує світло й лунає брязкіт.
# Під стелею тягнеться дим, на стіні висять ланцюги, зброя, обценьки й череп.
# Стіна, підлога й світло — шейдером; піч, інструменти — у _draw_static (раз); коваль, вогонь, іскри, дим — щокадру.
#
# Координати сцени — частки екрана (0..1).

const AX := 0.54          # ковадло: центр по X
const AY := 0.655         # верх ковадла по Y
const FURN_X := 0.17      # піч: центр по X
const FLOOR_Y := 0.80     # де починається підлога
const CYCLE := 1.3        # секунд на один удар
const IMPACT := 0.76      # момент удару в циклі (0..1)

const SHADER := """
shader_type canvas_item;
uniform float time = 0.0;
uniform float aspect = 1.78;
uniform float strike = 0.0;

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
    float floor_y = 0.80;

    // --- закопчена кам'яна стіна ---
    vec2 g = vec2(p.x * 6.0, p.y * 11.0);
    float rw = floor(g.y);
    g.x += mod(rw, 2.0) * 0.5;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float edge = min(min(f.x, 1.0 - f.x) * 1.5, min(f.y, 1.0 - f.y) * 3.0);
    float mortar = 1.0 - smoothstep(0.04, 0.14, edge);
    vec3 stone = mix(vec3(0.10, 0.085, 0.075), vec3(0.25, 0.20, 0.17), hash(id));
    stone *= 0.50 + 0.75 * fbm(p * 12.0);
    stone *= 0.72 + 0.38 * smoothstep(0.0, 0.4, edge);
    vec3 col = mix(stone, vec3(0.018, 0.014, 0.012), mortar);
    // кіптява: темніє до стелі
    col *= 0.55 + 0.45 * smoothstep(0.0, 0.55, uv.y);

    // --- кам'яна підлога у перспективі ---
    if (uv.y > floor_y) {
        float fy = uv.y - 0.70;
        float u = (uv.x - 0.5) / fy;
        float v = 1.0 / fy;
        float sx = floor(u * 2.0);
        float sy = floor(v * 1.3);
        vec3 fl = mix(vec3(0.06, 0.05, 0.045), vec3(0.17, 0.14, 0.12), hash(vec2(sx, sy)));
        fl *= 0.55 + 0.65 * fbm(vec2(u * 6.0, v * 2.0));
        float gx = smoothstep(0.0, 0.05, min(fract(u * 2.0), 1.0 - fract(u * 2.0)));
        float gy = smoothstep(0.0, 0.06, fract(v * 1.3));
        col = fl * gx * (0.4 + 0.6 * gy);
        if (uv.y < floor_y + 0.008) {
            col = vec3(0.03, 0.025, 0.02);
        }
    }

    // --- світло: піч (тремтить), розпечений метал на ковадлі (спалахує від удару), холодна темрява ---
    float fl1 = 1.0 + 0.16 * sin(time * 9.0) + 0.10 * sin(time * 17.0 + 1.0) + 0.07 * sin(time * 31.0 + 2.0);
    vec2 fpos = vec2(0.17 * aspect, 0.64);
    float df = length((p - fpos) * vec2(0.8, 1.0));
    float light_f = exp(-df * df * 3.2) * fl1;
    vec2 apos = vec2(0.54 * aspect, 0.62);
    float da = length(p - apos);
    float light_a = exp(-da * da * 9.0) * (0.55 + 1.7 * strike);
    vec3 warm = vec3(1.0, 0.52, 0.20);
    vec3 hot = vec3(1.0, 0.74, 0.38);
    vec3 amb = vec3(0.040, 0.046, 0.068);
    col *= amb + warm * light_f * 1.7 + hot * light_a * 1.3;

    // дим / серпанок, підсвічений вогнем
    float haze = fbm(vec2(p.x * 3.0 + time * 0.05, p.y * 2.0 - time * 0.08));
    col += vec3(0.30, 0.13, 0.05) * haze * (light_f * 0.10 + light_a * 0.07);

    // --- віньєтка ---
    vec2 q2 = uv - 0.5;
    col *= 1.0 - 0.85 * smoothstep(0.20, 0.80, length(q2 * vec2(1.0, 1.15)));
    col *= 0.45 + 0.55 * smoothstep(0.0, 0.30, uv.y);
    COLOR = vec4(col, 1.0);
}
"""

var t := 0.0
var back: ColorRect
var stat: Control   # малюється один раз (піч, інструменти, ланцюги)
var dyn: Control    # малюється щокадру (коваль, вогонь, іскри, дим)
var _sparks: Array = []   # [позиція, швидкість, життя, макс. життя, розмір, тип 0=іскра 1=жарина]
var _prev_u := 0.0
var _flash := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _rng.seed = 909
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

    # удар молота
    var u := fmod(t, CYCLE) / CYCLE
    if _prev_u < IMPACT and u >= IMPACT:
        _strike(w, h, S)
    _prev_u = u
    _flash = maxf(0.0, _flash - delta * 3.2)

    # жарини з печі
    if _rng.randf() < 0.55:
        var ex := _rng.randf_range(0.115, 0.235) * w
        var ey := 0.74 * h
        _sparks.append([Vector2(ex, ey), Vector2(_rng.randf_range(-20.0, 30.0) * S, _rng.randf_range(-130.0, -50.0) * S), 0.0, _rng.randf_range(1.6, 3.4), _rng.randf_range(1.2, 2.6), 1])
    # дрібні іскорки з розпеченого клинка
    if _rng.randf() < 0.06:
        _spawn_spark(Vector2(AX * w + _rng.randf_range(-80.0, 40.0) * S, AY * h - 10.0 * S), 0.35, S)

    # оновлення частинок
    var i := _sparks.size() - 1
    while i >= 0:
        var sp: Array = _sparks[i]
        var pos: Vector2 = sp[0]
        var vel: Vector2 = sp[1]
        var life: float = sp[2] + delta
        var kind: int = sp[5]
        if kind == 0:
            vel.y += 1150.0 * S * delta
            vel.x *= 1.0 - 0.6 * delta
        else:
            vel.x += sin(t * 3.0 + pos.y * 0.02) * 40.0 * S * delta
        pos += vel * delta
        sp[0] = pos
        sp[1] = vel
        sp[2] = life
        if life >= float(sp[3]) or pos.y > h or pos.y < -20.0:
            _sparks.remove_at(i)
        i -= 1
    if _sparks.size() > 420:
        _sparks = _sparks.slice(_sparks.size() - 420)

    var sm := back.material as ShaderMaterial
    sm.set_shader_parameter("time", t)
    sm.set_shader_parameter("aspect", w / maxf(h, 1.0))
    sm.set_shader_parameter("strike", _flash)
    dyn.queue_redraw()

func _spawn_spark(pos: Vector2, power: float, S: float) -> void:
    var ang := _rng.randf_range(-PI * 0.96, -PI * 0.04)
    var spd := _rng.randf_range(160.0, 680.0) * power * S
    _sparks.append([pos, Vector2(cos(ang), sin(ang)) * spd, 0.0, _rng.randf_range(0.5, 1.4), _rng.randf_range(1.2, 2.8), 0])

func _strike(w: float, h: float, S: float) -> void:
    _flash = 1.0
    var hit := Vector2(AX * w - 4.0 * S, AY * h - 12.0 * S)
    for k in range(64):
        _spawn_spark(hit + Vector2(_rng.randf_range(-30.0, 40.0) * S, 0.0), 1.0, S)
    Sfx.play("anvil", -6.0)

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

# Лікоть двосуглобової руки: з плеча sh до кисті tg, довжини ланок a й b, out_dir — куди «дивиться» лікоть по X.
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

func _flame(c: Control, b: Vector2, hgt: float, wd: float, sway: float, col: Color) -> void:
    _poly(c, [
        Vector2(b.x - wd, b.y),
        Vector2(b.x - wd * 0.75 + sway * 0.3, b.y - hgt * 0.45),
        Vector2(b.x + sway, b.y - hgt),
        Vector2(b.x + wd * 0.75 + sway * 0.3, b.y - hgt * 0.45),
        Vector2(b.x + wd, b.y),
    ], col)

# ================= Статична частина =================
func _draw_static() -> void:
    var c := stat
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_ceiling(c, w, h, S)
    _draw_furnace(c, w, h, S)
    _draw_rack(c, w, h, S)
    _draw_chains(c, w, h, S)
    _draw_shelf_skull(c, w, h, S)
    _draw_barrel(c, w, h, S)
    _draw_cobweb(c, w * 0.995, 0.0, S, -1.0)

func _draw_ceiling(c: Control, w: float, h: float, S: float) -> void:
    # важка балка під стелею
    c.draw_rect(Rect2(0.0, 0.0, w, 0.05 * h), Color(0.045, 0.03, 0.022))
    c.draw_rect(Rect2(0.0, 0.05 * h, w, 4.0 * S), Color(0.02, 0.014, 0.01))
    for i in range(7):
        c.draw_line(Vector2(0.0, (0.008 + 0.006 * float(i)) * h), Vector2(w, (0.008 + 0.006 * float(i)) * h), Color(0.0, 0.0, 0.0, 0.25), 1.0)

func _draw_furnace(c: Control, w: float, h: float, S: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    # витяжка-трапеція, димар, корпус
    _poly(c, [Vector2(0.040 * w, 0.42 * h), Vector2(0.305 * w, 0.42 * h), Vector2(0.215 * w, 0.07 * h), Vector2(0.125 * w, 0.07 * h)], Color(0.02, 0.016, 0.014))
    c.draw_rect(Rect2(0.125 * w, 0.0, 0.09 * w, 0.075 * h), Color(0.02, 0.016, 0.014))
    c.draw_rect(Rect2(0.040 * w, 0.42 * h, 0.265 * w, 0.38 * h), Color(0.02, 0.016, 0.014))
    # цегляна кладка
    var rows := 14
    for r in range(rows):
        var y0 := lerpf(0.07 * h, 0.80 * h, float(r) / float(rows))
        var y1 := lerpf(0.07 * h, 0.80 * h, float(r + 1) / float(rows))
        var ym := (y0 + y1) * 0.5 / h
        var xl := 0.040
        var xr := 0.305
        if ym < 0.42:
            var f := (ym - 0.07) / (0.42 - 0.07)
            xl = lerpf(0.125, 0.040, f)
            xr = lerpf(0.215, 0.305, f)
        var bw := 0.045 * w
        var x := xl * w - float(r % 2) * bw * 0.5
        while x < xr * w:
            var xa := maxf(x, xl * w)
            var xb := minf(x + bw, xr * w)
            if xb - xa > 3.0:
                var shade := rng.randf_range(0.05, 0.14)
                c.draw_rect(Rect2(xa + 1.0, y0 + 1.0, xb - xa - 2.0, y1 - y0 - 2.0), Color(shade * 1.1, shade * 0.92, shade * 0.80))
            x += bw
    # кіптява зверху
    for g in range(6):
        c.draw_rect(Rect2(0.04 * w, 0.07 * h + float(g) * 0.03 * h, 0.265 * w, 0.03 * h), Color(0, 0, 0, 0.10))
    # отвір печі з аркою
    var x0 := 0.095 * w
    var x1 := 0.255 * w
    var yb := 0.80 * h
    var yt := 0.60 * h
    var pts: Array = [Vector2(x0, yb), Vector2(x0, yt)]
    var cxx := (x0 + x1) * 0.5
    for i in range(1, 16):
        var a := PI + PI * float(i) / 16.0
        pts.append(Vector2(cxx + cos(a) * (x1 - x0) * 0.5, yt + sin(a) * 0.10 * h))
    pts.append(Vector2(x1, yt))
    pts.append(Vector2(x1, yb))
    _poly(c, pts, Color(0.16, 0.035, 0.01))
    # залізна окантовка й нижня плита
    c.draw_rect(Rect2(x0 - 8.0 * S, yb - 4.0 * S, x1 - x0 + 16.0 * S, 12.0 * S), Color(0.05, 0.045, 0.045))
    c.draw_line(Vector2(x0 - 4.0 * S, yb - 4.0 * S), Vector2(x1 + 4.0 * S, yb - 4.0 * S), Color(0.5, 0.25, 0.12, 0.6), 2.0)

func _hang_sword(c: Control, top: Vector2, ln: float, ang: float, S: float, col: Color) -> void:
    var d := Vector2(sin(ang), cos(ang))
    var n := Vector2(d.y, -d.x)
    var guard := top + d * ln * 0.22
    c.draw_line(top, guard, Color(0.09, 0.05, 0.035), 7.0 * S)
    c.draw_circle(top, 6.0 * S, col)
    c.draw_line(guard - n * 18.0 * S, guard + n * 18.0 * S, col, 6.0 * S)
    var tip := top + d * ln
    _poly(c, [guard + n * 8.0 * S, tip, guard - n * 8.0 * S], col.lightened(0.06))
    c.draw_line(guard, tip, Color(0.55, 0.38, 0.28, 0.5), 1.5)

func _hang_axe(c: Control, top: Vector2, ln: float, S: float, col: Color) -> void:
    var end := top + Vector2(0.0, ln)
    c.draw_line(top, end, Color(0.10, 0.06, 0.04), 7.0 * S)
    _poly(c, [top + Vector2(0.0, 10.0 * S), top + Vector2(30.0 * S, 0.0), top + Vector2(34.0 * S, 40.0 * S), top + Vector2(0.0, 32.0 * S)], col)
    c.draw_line(top + Vector2(30.0 * S, 0.0), top + Vector2(34.0 * S, 40.0 * S), Color(0.6, 0.42, 0.3, 0.55), 1.5)

func _hang_hammer(c: Control, top: Vector2, ln: float, S: float, col: Color) -> void:
    c.draw_line(top, top + Vector2(0.0, ln), Color(0.10, 0.06, 0.04), 7.0 * S)
    c.draw_rect(Rect2(top.x - 22.0 * S, top.y - 4.0 * S, 44.0 * S, 24.0 * S), col)
    c.draw_line(Vector2(top.x - 22.0 * S, top.y - 4.0 * S), Vector2(top.x + 22.0 * S, top.y - 4.0 * S), Color(0.6, 0.42, 0.3, 0.55), 1.5)

func _hang_tongs(c: Control, top: Vector2, ln: float, S: float, col: Color) -> void:
    c.draw_line(top, top + Vector2(-9.0 * S, ln), col, 5.0 * S)
    c.draw_line(top, top + Vector2(9.0 * S, ln), col, 5.0 * S)
    c.draw_circle(top, 5.0 * S, col)

func _draw_rack(c: Control, w: float, h: float, S: float) -> void:
    var py := 0.215 * h
    c.draw_rect(Rect2(0.69 * w, py, 0.30 * w, 14.0 * S), Color(0.07, 0.045, 0.03))
    c.draw_line(Vector2(0.69 * w, py), Vector2(0.99 * w, py), Color(0.5, 0.3, 0.15, 0.35), 1.5)
    var steel := Color(0.12, 0.12, 0.135)
    _hang_sword(c, Vector2(0.715 * w, py + 14.0 * S), 200.0 * S, 0.04, S, steel)
    _hang_axe(c, Vector2(0.765 * w, py + 14.0 * S), 120.0 * S, S, steel)
    _hang_sword(c, Vector2(0.825 * w, py + 14.0 * S), 150.0 * S, -0.05, S, steel)
    _hang_hammer(c, Vector2(0.875 * w, py + 18.0 * S), 110.0 * S, S, steel)
    _hang_tongs(c, Vector2(0.920 * w, py + 14.0 * S), 130.0 * S, S, steel)
    _hang_axe(c, Vector2(0.955 * w, py + 14.0 * S), 100.0 * S, S, steel)

func _chain(c: Control, top: Vector2, ln: float, S: float) -> void:
    var n := int(ln / (13.0 * S))
    for i in range(n):
        var p := top + Vector2(sin(float(i) * 0.15) * 2.0 * S, float(i) * 13.0 * S)
        if i % 2 == 0:
            _ell(c, p, 4.0 * S, 7.5 * S, Color(0.10, 0.09, 0.09))
            _ell(c, p, 2.0 * S, 5.0 * S, Color(0.02, 0.016, 0.014))
        else:
            _ell(c, p, 6.0 * S, 3.0 * S, Color(0.13, 0.115, 0.11))
    var end := top + Vector2(0.0, float(n) * 13.0 * S)
    # гак
    c.draw_arc(end + Vector2(5.0 * S, 8.0 * S), 9.0 * S, -PI * 0.5, PI * 0.8, 12, Color(0.14, 0.12, 0.11), 4.0 * S)

func _draw_chains(c: Control, w: float, h: float, S: float) -> void:
    _chain(c, Vector2(0.36 * w, 0.05 * h), 0.22 * h, S)
    _chain(c, Vector2(0.64 * w, 0.05 * h), 0.30 * h, S)
    _chain(c, Vector2(0.67 * w, 0.05 * h), 0.16 * h, S)
    # кайдани на довгому ланцюзі
    var lx := 0.605 * w
    _chain(c, Vector2(lx, 0.05 * h), 0.34 * h, S)
    var ey := 0.05 * h + float(int(0.34 * h / (13.0 * S))) * 13.0 * S + 10.0 * S
    c.draw_arc(Vector2(lx - 12.0 * S, ey + 12.0 * S), 14.0 * S, 0.0, TAU, 16, Color(0.14, 0.12, 0.11), 5.0 * S)
    c.draw_arc(Vector2(lx + 14.0 * S, ey + 12.0 * S), 14.0 * S, 0.0, TAU, 16, Color(0.14, 0.12, 0.11), 5.0 * S)

func _draw_shelf_skull(c: Control, w: float, h: float, S: float) -> void:
    var sx := 0.745 * w
    var sy := 0.50 * h
    c.draw_rect(Rect2(sx - 70.0 * S, sy, 140.0 * S, 12.0 * S), Color(0.07, 0.045, 0.03))
    c.draw_line(Vector2(sx - 70.0 * S, sy), Vector2(sx + 70.0 * S, sy), Color(0.5, 0.3, 0.15, 0.3), 1.5)
    # череп
    var bone := Color(0.46, 0.42, 0.35)
    _ell(c, Vector2(sx, sy - 26.0 * S), 24.0 * S, 24.0 * S, bone)
    c.draw_rect(Rect2(sx - 13.0 * S, sy - 12.0 * S, 26.0 * S, 12.0 * S), bone.darkened(0.1))
    _ell(c, Vector2(sx - 9.0 * S, sy - 28.0 * S), 6.5 * S, 7.5 * S, Color(0.02, 0.01, 0.01))
    _ell(c, Vector2(sx + 9.0 * S, sy - 28.0 * S), 6.5 * S, 7.5 * S, Color(0.02, 0.01, 0.01))
    _poly(c, [Vector2(sx, sy - 22.0 * S), Vector2(sx - 3.0 * S, sy - 14.0 * S), Vector2(sx + 3.0 * S, sy - 14.0 * S)], Color(0.02, 0.01, 0.01))
    for i in range(5):
        c.draw_line(Vector2(sx - 10.0 * S + float(i) * 5.0 * S, sy - 11.0 * S), Vector2(sx - 10.0 * S + float(i) * 5.0 * S, sy - 2.0 * S), Color(0.05, 0.03, 0.02), 1.5)
    c.draw_rect(Rect2(sx - 24.0 * S, sy - 30.0 * S, 48.0 * S, 48.0 * S), Color(0, 0, 0, 0.30))
    # кістки на полиці
    c.draw_line(Vector2(sx + 30.0 * S, sy - 4.0 * S), Vector2(sx + 62.0 * S, sy - 10.0 * S), bone.darkened(0.15), 5.0 * S)

func _draw_barrel(c: Control, w: float, h: float, S: float) -> void:
    var cx := 0.695 * w
    var by := 0.875 * h
    var bw := 56.0 * S
    var bh := 118.0 * S
    c.draw_rect(Rect2(cx - bw, by - bh, bw * 2.0, bh), Color(0.09, 0.055, 0.032))
    for i in range(7):
        c.draw_line(Vector2(cx - bw + float(i) * bw * 2.0 / 6.0, by - bh), Vector2(cx - bw + float(i) * bw * 2.0 / 6.0, by), Color(0.0, 0.0, 0.0, 0.35), 1.5)
    for yy in [0.18, 0.80]:
        c.draw_rect(Rect2(cx - bw - 2.0, by - bh + bh * float(yy) - 4.0 * S, bw * 2.0 + 4.0, 8.0 * S), Color(0.06, 0.055, 0.055))
    _ell(c, Vector2(cx, by - bh), bw, 14.0 * S, Color(0.02, 0.03, 0.04))
    _ell(c, Vector2(cx, by - bh), bw - 5.0 * S, 10.0 * S, Color(0.05, 0.07, 0.09))
    _ell(c, Vector2(cx, by), bw, 8.0 * S, Color(0, 0, 0, 0.5))

func _draw_cobweb(c: Control, ox: float, oy: float, S: float, dir: float) -> void:
    var col := Color(0.75, 0.75, 0.8, 0.22)
    var r := 150.0 * S
    for i in range(6):
        var a := PI * 0.5 + dir * 0.0 + float(i) * (PI * 0.5) / 5.0
        c.draw_line(Vector2(ox, oy), Vector2(ox + cos(a) * r, oy + sin(a) * r), col, 1.0)
    for k in range(1, 5):
        var rr := r * float(k) / 4.5
        var prev := Vector2(ox + cos(PI * 0.5) * rr, oy + sin(PI * 0.5) * rr)
        for i in range(1, 6):
            var a := PI * 0.5 + float(i) * (PI * 0.5) / 5.0
            var p := Vector2(ox + cos(a) * rr * 0.9, oy + sin(a) * rr * 0.9)
            c.draw_line(prev, p, col, 1.0)
            prev = p

# ================= Динамічна частина =================
func _draw_dynamic() -> void:
    var c := dyn
    var w := size.x
    var h := size.y
    var S := h / 720.0
    _draw_fire(c, w, h, S)
    _draw_smoke(c, w, h, S)
    _draw_smith(c, w, h, S)
    _draw_anvil(c, w, h, S)
    _draw_blade(c, w, h, S)
    _draw_right_arm(c, w, h, S)
    _draw_sparks(c, w, h, S)

func _draw_fire(c: Control, w: float, h: float, S: float) -> void:
    var x0 := 0.105 * w
    var x1 := 0.245 * w
    var base := 0.785 * h
    var fl := 1.0 + 0.14 * sin(t * 9.0) + 0.09 * sin(t * 17.0 + 1.0)
    var cx := FURN_X * w
    for g in range(6):
        c.draw_circle(Vector2(cx, 0.66 * h), (60.0 + 55.0 * float(g)) * S * fl, Color(1.0, 0.45, 0.12, 0.032))
    # жар на підлозі
    _ell(c, Vector2(cx, 0.83 * h), 150.0 * S * fl, 22.0 * S, Color(1.0, 0.4, 0.1, 0.10))
    # вугілля
    c.draw_rect(Rect2(x0, base - 14.0 * S, x1 - x0, 16.0 * S), Color(0.50, 0.10, 0.02))
    for i in range(14):
        var bx := x0 + (float(i) + 0.5) / 14.0 * (x1 - x0)
        var pulse := 0.5 + 0.5 * sin(t * 4.0 + float(i) * 1.9)
        _ell(c, Vector2(bx, base - 8.0 * S), 9.0 * S, 6.0 * S, Color(1.0, 0.35 + 0.3 * pulse, 0.05, 0.55 + 0.35 * pulse))
    # язики полум'я
    for i in range(9):
        var fx := lerpf(x0 + 16.0 * S, x1 - 16.0 * S, float(i) / 8.0)
        var ph := float(i) * 1.7
        var edge := 1.0 - 0.35 * absf(float(i) - 4.0) / 4.0
        var hgt := (95.0 + 65.0 * (0.5 + 0.5 * sin(t * 7.0 + ph))) * S * edge
        var sway := sin(t * 5.0 + ph) * 14.0 * S
        var b := Vector2(fx, base - 8.0 * S)
        _flame(c, b, hgt, 30.0 * S, sway, Color(0.9, 0.14, 0.03, 0.85))
        _flame(c, b, hgt * 0.72, 22.0 * S, sway * 0.8, Color(1.0, 0.48, 0.08, 0.9))
        _flame(c, b, hgt * 0.42, 13.0 * S, sway * 0.5, Color(1.0, 0.88, 0.40, 0.95))

func _draw_smoke(c: Control, w: float, h: float, S: float) -> void:
    # дим із димаря стелиться під стелею вправо
    for i in range(14):
        var ph := float(i) / 14.0
        var k := fmod(t * 0.05 + ph, 1.0)
        var sx := (0.17 + k * 0.50) * w
        var sy := (0.09 + 0.05 * sin(ph * 31.0 + t * 0.3)) * h
        c.draw_circle(Vector2(sx, sy), (50.0 + 130.0 * k) * S, Color(0.10, 0.09, 0.09, 0.055 * (1.0 - k)))
    # дим над ковадлом
    for i in range(10):
        var ph2 := float(i) / 10.0
        var k2 := fmod(t * 0.12 + ph2, 1.0)
        var sx2 := AX * w + sin(ph2 * 17.0 + t * 0.6) * 30.0 * S * k2 - 20.0 * S
        var sy2 := (AY - 0.06 - k2 * 0.40) * h
        c.draw_circle(Vector2(sx2, sy2), (14.0 + 60.0 * k2) * S, Color(0.14, 0.12, 0.11, 0.07 * (1.0 - k2)))

# Піднята/опущена поза молота: 0 — молот на ковадлі, 1 — високо над головою.
func _swing(u: float) -> float:
    var wv := fposmod(u - IMPACT, 1.0)
    if wv < 0.60:
        return smoothstep(0.0, 0.60, wv)
    if wv < 0.82:
        return 1.0 + 0.03 * sin((wv - 0.60) * 30.0)
    var k := (wv - 0.82) / 0.18
    return 1.0 - k * k

func _draw_smith(c: Control, w: float, h: float, S: float) -> void:
    var ax := AX * w
    var ay := AY * h
    var u := fmod(t, CYCLE) / CYCLE
    var r := _swing(u)
    var sy := ay - 232.0 * S
    var lean := r * -8.0 * S
    var glow := 0.30 + 0.45 * _flash

    var cloth := Color(0.075, 0.048, 0.035)
    var skin := Color(0.26, 0.16, 0.11)

    # тулуб
    _poly(c, [Vector2(ax - 72.0 * S + lean, sy), Vector2(ax + 72.0 * S + lean, sy), Vector2(ax + 58.0 * S, ay - 40.0 * S), Vector2(ax - 58.0 * S, ay - 40.0 * S)], cloth)
    # шкіряний фартух
    _poly(c, [Vector2(ax - 46.0 * S + lean, sy + 24.0 * S), Vector2(ax + 46.0 * S + lean, sy + 24.0 * S), Vector2(ax + 56.0 * S, ay - 40.0 * S), Vector2(ax - 56.0 * S, ay - 40.0 * S)], Color(0.14, 0.085, 0.05))
    c.draw_line(Vector2(ax - 46.0 * S + lean, sy + 24.0 * S), Vector2(ax - 56.0 * S, ay - 40.0 * S), Color(1.0, 0.5, 0.2, 0.30), 3.0 * S)
    # знизу тулуб підсвічує розпечений метал
    _poly(c, [Vector2(ax - 56.0 * S, ay - 130.0 * S), Vector2(ax + 56.0 * S, ay - 130.0 * S), Vector2(ax + 56.0 * S, ay - 40.0 * S), Vector2(ax - 56.0 * S, ay - 40.0 * S)], Color(1.0, 0.45, 0.12, 0.10 + 0.22 * _flash))
    # ліве плече вогнем піч підсвічує
    c.draw_line(Vector2(ax - 72.0 * S + lean, sy), Vector2(ax - 40.0 * S + lean, sy - 6.0 * S), Color(1.0, 0.5, 0.2, 0.35), 3.0 * S)

    # лівая рука з обценьками
    var lsh := Vector2(ax - 64.0 * S + lean, sy + 12.0 * S)
    var lh := Vector2(ax - 125.0 * S, ay - 75.0 * S)
    var le := _ik(lsh, lh, 105.0 * S, 105.0 * S, -1.0)
    c.draw_line(lsh, le, cloth.lightened(0.04), 38.0 * S)
    c.draw_circle(lsh, 19.0 * S, cloth.lightened(0.04))
    c.draw_circle(le, 19.0 * S, cloth.lightened(0.04))
    c.draw_line(le, lh, skin, 28.0 * S)
    c.draw_line(le + Vector2(-5.0 * S, -3.0 * S), lh + Vector2(-5.0 * S, -3.0 * S), Color(0.55, 0.30, 0.16, 0.55), 8.0 * S)
    c.draw_circle(lh, 15.0 * S, skin.darkened(0.1))
    # обценьки
    c.draw_line(lh, Vector2(ax - 116.0 * S, ay - 12.0 * S), Color(0.07, 0.07, 0.08), 5.0 * S)
    c.draw_line(lh + Vector2(6.0 * S, 0.0), Vector2(ax - 126.0 * S, ay - 10.0 * S), Color(0.07, 0.07, 0.08), 5.0 * S)

    # шия та голова
    var hy := sy - 66.0 * S + (1.0 - r) * 9.0 * S
    var hx := ax + lean * 0.8
    c.draw_rect(Rect2(hx - 15.0 * S, hy + 12.0 * S, 30.0 * S, sy - hy), skin.darkened(0.35))
    _ell(c, Vector2(hx, hy), 29.0 * S, 34.0 * S, skin.darkened(0.15))
    # тінь на правій половині обличчя, світло піч зліва
    _ell(c, Vector2(hx + 12.0 * S, hy + 2.0 * S), 18.0 * S, 32.0 * S, Color(0, 0, 0, 0.45))
    c.draw_arc(Vector2(hx, hy), 29.0 * S, PI * 0.62, PI * 1.38, 14, Color(1.0, 0.5, 0.2, 0.55), 3.0 * S)
    # лисина з пов'язкою, важкі брови, борода
    _poly(c, [Vector2(hx - 30.0 * S, hy - 12.0 * S), Vector2(hx + 30.0 * S, hy - 12.0 * S), Vector2(hx + 24.0 * S, hy - 28.0 * S), Vector2(hx, hy - 36.0 * S), Vector2(hx - 24.0 * S, hy - 28.0 * S)], Color(0.05, 0.03, 0.025))
    _poly(c, [Vector2(hx - 24.0 * S, hy - 4.0 * S), Vector2(hx + 24.0 * S, hy - 4.0 * S), Vector2(hx + 20.0 * S, hy + 2.0 * S), Vector2(hx - 20.0 * S, hy + 2.0 * S)], Color(0.03, 0.02, 0.015, 0.92))
    _poly(c, [Vector2(hx - 28.0 * S, hy + 6.0 * S), Vector2(hx - 24.0 * S, hy + 30.0 * S), Vector2(hx, hy + 52.0 * S), Vector2(hx + 24.0 * S, hy + 30.0 * S), Vector2(hx + 28.0 * S, hy + 6.0 * S), Vector2(hx + 14.0 * S, hy + 18.0 * S), Vector2(hx, hy + 14.0 * S), Vector2(hx - 14.0 * S, hy + 18.0 * S)], Color(0.045, 0.03, 0.025))
    # очі: тьмяно жевріють у тіні брів
    var eg := 0.35 + glow
    _ell(c, Vector2(hx - 10.0 * S, hy + 0.0), 4.2 * S, 2.0 * S, Color(1.0, 0.55, 0.15, minf(eg, 1.0)))
    _ell(c, Vector2(hx + 10.0 * S, hy + 0.0), 4.2 * S, 2.0 * S, Color(1.0, 0.55, 0.15, minf(eg * 0.8, 1.0)))

func _draw_anvil(c: Control, w: float, h: float, S: float) -> void:
    var ax := AX * w
    var ay := AY * h
    var steel := Color(0.085, 0.085, 0.10)
    var floor_y := 0.90 * h
    # дерев'яна колода
    c.draw_rect(Rect2(ax - 58.0 * S, ay + 82.0 * S, 116.0 * S, floor_y - ay - 82.0 * S), Color(0.075, 0.045, 0.028))
    c.draw_line(Vector2(ax - 58.0 * S, ay + 82.0 * S), Vector2(ax - 58.0 * S, floor_y), Color(1.0, 0.5, 0.2, 0.18), 2.0)
    for i in range(5):
        c.draw_line(Vector2(ax - 40.0 * S + float(i) * 20.0 * S, ay + 90.0 * S), Vector2(ax - 40.0 * S + float(i) * 20.0 * S, floor_y - 4.0), Color(0, 0, 0, 0.35), 1.5)
    _ell(c, Vector2(ax, floor_y), 62.0 * S, 9.0 * S, Color(0, 0, 0, 0.5))
    # основа, талія, верхня плита, ріг
    _poly(c, [Vector2(ax - 64.0 * S, ay + 84.0 * S), Vector2(ax + 64.0 * S, ay + 84.0 * S), Vector2(ax + 50.0 * S, ay + 62.0 * S), Vector2(ax - 50.0 * S, ay + 62.0 * S)], steel.darkened(0.2))
    _poly(c, [Vector2(ax - 34.0 * S, ay + 62.0 * S), Vector2(ax + 34.0 * S, ay + 62.0 * S), Vector2(ax + 40.0 * S, ay + 20.0 * S), Vector2(ax - 40.0 * S, ay + 20.0 * S)], steel)
    _poly(c, [Vector2(ax - 74.0 * S, ay - 2.0 * S), Vector2(ax + 66.0 * S, ay - 2.0 * S), Vector2(ax + 62.0 * S, ay + 22.0 * S), Vector2(ax - 40.0 * S, ay + 22.0 * S), Vector2(ax - 74.0 * S, ay + 16.0 * S), Vector2(ax - 138.0 * S, ay + 4.0 * S)], steel.lightened(0.06))
    # блиск верхньої грані: теплий відсвіт від металу
    c.draw_line(Vector2(ax - 130.0 * S, ay + 3.0 * S), Vector2(ax + 66.0 * S, ay - 2.0 * S), Color(1.0, 0.55, 0.2, 0.45 + 0.4 * _flash), 3.0 * S)
    c.draw_line(Vector2(ax - 74.0 * S, ay + 16.0 * S), Vector2(ax - 40.0 * S, ay + 22.0 * S), Color(1.0, 0.5, 0.2, 0.25), 2.0 * S)

func _draw_blade(c: Control, w: float, h: float, S: float) -> void:
    var ax := AX * w
    var ay := AY * h
    var heat := 0.75 + 0.25 * _flash + 0.06 * sin(t * 7.0)
    var cy := ay - 9.0 * S
    var xl := ax - 132.0 * S
    var xr := ax + 62.0 * S
    # ореол
    for g in range(4):
        c.draw_circle(Vector2(ax - 30.0 * S, cy), (36.0 + 34.0 * float(g)) * S, Color(1.0, 0.45, 0.1, (0.07 + 0.10 * _flash) * heat))
    # розпечена заготовка: загострена ліворуч
    _poly(c, [Vector2(xl, cy), Vector2(xl + 36.0 * S, cy - 8.0 * S), Vector2(xr, cy - 8.0 * S), Vector2(xr, cy + 1.0 * S), Vector2(xl + 36.0 * S, cy + 1.0 * S)], Color(0.95, 0.30, 0.04, 0.95))
    _poly(c, [Vector2(xl + 8.0 * S, cy - 1.0 * S), Vector2(xl + 40.0 * S, cy - 6.0 * S), Vector2(xr - 30.0 * S, cy - 6.0 * S), Vector2(xr - 30.0 * S, cy - 1.0 * S)], Color(1.0, 0.62, 0.15, 0.95 * heat))
    c.draw_line(Vector2(xl + 20.0 * S, cy - 3.5 * S), Vector2(xr - 50.0 * S, cy - 3.5 * S), Color(1.0, 0.95, 0.7, 0.9 * heat), 2.0 * S)

func _draw_right_arm(c: Control, w: float, h: float, S: float) -> void:
    var ax := AX * w
    var ay := AY * h
    var u := fmod(t, CYCLE) / CYCLE
    var r := _swing(u)
    var sy := ay - 232.0 * S
    var lean := r * -8.0 * S
    var hl := 82.0 * S
    # поза кисті: від удару до замаху
    var th := lerpf(deg_to_rad(60.0), deg_to_rad(-78.0), minf(r, 1.0))
    var d := Vector2.from_angle(th)
    var hand_hit := Vector2(ax, ay - 14.0 * S) - d * hl
    var hand_up := Vector2(ax + 42.0 * S, ay - 345.0 * S)
    var hand := hand_hit.lerp(hand_up, minf(r, 1.0))
    var sh := Vector2(ax + 64.0 * S + lean, sy + 12.0 * S)
    var el := _ik(sh, hand, 105.0 * S, 105.0 * S, 1.0)
    var cloth := Color(0.085, 0.055, 0.04)
    var skin := Color(0.28, 0.17, 0.11)
    c.draw_line(sh, el, cloth.lightened(0.04), 40.0 * S)
    c.draw_circle(sh, 20.0 * S, cloth.lightened(0.04))
    c.draw_line(el, hand, skin, 30.0 * S)
    c.draw_line(el + Vector2(-6.0 * S, -3.0 * S), hand + Vector2(-6.0 * S, -3.0 * S), Color(0.60, 0.32, 0.16, 0.5), 8.0 * S)
    c.draw_circle(el, 18.0 * S, cloth)
    # руків'я та головка молота
    var head := hand + d * hl
    c.draw_line(hand - d * 14.0 * S, head, Color(0.12, 0.07, 0.045), 9.0 * S)
    var n := Vector2(-d.y, d.x)
    var hc := head + d * 8.0 * S
    _poly(c, [hc + n * 26.0 * S + d * 15.0 * S, hc - n * 26.0 * S + d * 15.0 * S, hc - n * 26.0 * S - d * 15.0 * S, hc + n * 26.0 * S - d * 15.0 * S], Color(0.10, 0.10, 0.12))
    c.draw_line(hc - n * 26.0 * S + d * 15.0 * S, hc - n * 26.0 * S - d * 15.0 * S, Color(1.0, 0.5, 0.2, 0.5), 2.5 * S)
    c.draw_line(hc - n * 26.0 * S - d * 15.0 * S, hc + n * 26.0 * S - d * 15.0 * S, Color(1.0, 0.55, 0.25, 0.35 + 0.5 * _flash), 2.0 * S)
    c.draw_circle(hand, 16.0 * S, skin.darkened(0.1))
    # швидке розмиття під час замаху вниз
    var wv := fposmod(u - IMPACT, 1.0)
    if wv > 0.84:
        var k := (wv - 0.84) / 0.16
        for q in range(3):
            var back_r := minf(r + 0.12 * float(q + 1), 1.0)
            var th2 := lerpf(deg_to_rad(60.0), deg_to_rad(-78.0), back_r)
            var d2 := Vector2.from_angle(th2)
            var hnd2 := (Vector2(ax, ay - 14.0 * S) - d2 * hl).lerp(hand_up, back_r)
            c.draw_line(hnd2 + d2 * hl * 0.5, hnd2 + d2 * (hl + 18.0 * S), Color(0.6, 0.6, 0.65, 0.10 * k), 24.0 * S)

func _draw_sparks(c: Control, w: float, h: float, S: float) -> void:
    # спалах при ударі
    if _flash > 0.02:
        var hit := Vector2(AX * w - 4.0 * S, AY * h - 12.0 * S)
        for g in range(5):
            c.draw_circle(hit, (18.0 + 26.0 * float(g)) * S * (0.6 + _flash * 0.6), Color(1.0, 0.7, 0.3, 0.07 * _flash))
        c.draw_circle(hit, 20.0 * S * _flash, Color(1.0, 0.96, 0.8, 0.55 * _flash))
        # ударна зірка
        for i in range(8):
            var a := TAU * float(i) / 8.0 + 0.3
            c.draw_line(hit, hit + Vector2(cos(a), sin(a)) * (70.0 + 30.0 * float(i % 2)) * S * _flash, Color(1.0, 0.9, 0.55, 0.7 * _flash), 2.0)
    for sp in _sparks:
        var pos: Vector2 = sp[0]
        var vel: Vector2 = sp[1]
        var k: float = float(sp[2]) / float(sp[3])
        var sz: float = sp[4]
        if int(sp[5]) == 0:
            var col := Color(1.0, 0.95 - 0.55 * k, 0.55 - 0.5 * k, 1.0 - k * k)
            var tail := pos - vel * 0.018
            c.draw_line(tail, pos, col, sz)
            c.draw_circle(pos, sz * 2.4, Color(1.0, 0.5, 0.15, 0.20 * (1.0 - k)))
        else:
            var a := (1.0 - k) * (0.5 + 0.5 * sin(t * 9.0 + pos.x))
            c.draw_circle(pos, sz, Color(1.0, 0.5, 0.12, a))
            c.draw_circle(pos, sz * 3.0, Color(1.0, 0.35, 0.05, a * 0.12))
