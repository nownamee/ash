extends RefCounted
class_name OrnateFrame
# Орнаментальні рамки (9-patch, ui/frame_*.png; генерує scripts/generate-frames.py). Без текстури — запасна плоска рамка.

const GOLD := Color(0.95, 0.78, 0.25)

static func _tex(name: String) -> Texture2D:
    var p := "res://ui/" + name
    if ResourceLoader.exists(p):
        return load(p) as Texture2D
    return null

static func _flat(border: Color, bg: Color, mx: float, my: float, bw: int, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(bw)
    s.set_corner_radius_all(radius)
    s.content_margin_left = mx
    s.content_margin_right = mx
    s.content_margin_top = my
    s.content_margin_bottom = my
    return s

static func _tinted(name: String, accent: Color, alpha: float, margin: int, mx: float, my: float) -> StyleBox:
    var t := _tex(name)
    if t == null:
        return _flat(accent, Color(0.07, 0.045, 0.03, alpha), mx, my, 2, 6)
    var s := StyleBoxTexture.new()
    s.texture = t
    s.set_texture_margin_all(margin)
    s.content_margin_left = mx
    s.content_margin_right = mx
    s.content_margin_top = my
    s.content_margin_bottom = my
    s.modulate_color = Color(minf(accent.r / GOLD.r, 1.0), minf(accent.g / GOLD.g, 1.0), minf(accent.b / GOLD.b, 1.0), alpha)
    return s

static func panel(accent: Color = Color(0.95, 0.78, 0.25), bg: Color = Color(0.07, 0.045, 0.03, 0.94)) -> StyleBox:
    return _tinted("frame_panel.png", accent, clampf(bg.a / 0.94, 0.0, 1.0), 28, 18, 14)

static func plate(accent: Color = Color(0.95, 0.78, 0.25)) -> StyleBox:
    return _tinted("frame_plate.png", accent, 1.0, 14, 10, 4)

static func ribbon(accent: Color = Color(0.95, 0.78, 0.25)) -> StyleBox:
    return _tinted("frame_ribbon.png", accent, 1.0, 20, 22, 6)
