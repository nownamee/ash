extends RefCounted
# Тема меню: темне дерево, золоті рамки, пергаментний текст (стиль середньовічної таверни).

const GameFonts = preload("res://game_fonts.gd")

const GOLD := Color(0.95, 0.78, 0.25)
const CREAM := Color(0.93, 0.87, 0.72)

static func _box(bg: Color, border: Color, bw: int = 2, radius: int = 5) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(bw)
    sb.set_corner_radius_all(radius)
    sb.content_margin_left = 12.0
    sb.content_margin_right = 12.0
    sb.content_margin_top = 6.0
    sb.content_margin_bottom = 6.0
    sb.shadow_color = Color(0, 0, 0, 0.5)
    sb.shadow_size = 3
    return sb

# Шрифти (див. game_fonts.gd): королівський — заголовки й кнопки, зловісний — локації, загроза, бій.
static func title_font() -> Font:
    return GameFonts.royal()

static func _nav_box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
    var sb := _box(bg, border, bw, 12)
    sb.content_margin_left = 6.0
    sb.content_margin_right = 16.0
    sb.content_margin_top = 3.0
    sb.content_margin_bottom = 3.0
    return sb

static func build() -> Theme:
    var th := Theme.new()
    th.default_font = GameFonts.body()
    th.default_font_size = 17
    var tf := title_font()

    # звичайні кнопки
    th.set_stylebox("normal", "Button", _box(Color(0.17, 0.10, 0.055, 0.96), Color(0.55, 0.38, 0.12)))
    th.set_stylebox("hover", "Button", _box(Color(0.28, 0.17, 0.08, 0.98), GOLD))
    th.set_stylebox("pressed", "Button", _box(Color(0.36, 0.21, 0.09, 1.0), Color(1.0, 0.9, 0.5)))
    th.set_stylebox("disabled", "Button", _box(Color(0.10, 0.08, 0.06, 0.9), Color(0.25, 0.20, 0.15)))
    th.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 2))
    th.set_color("font_color", "Button", CREAM)
    th.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.75))
    th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
    th.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.38))

    # великі кнопки розділів (зліва внизу): темна дощечка із золотою окантовкою, плитка-іконка, золотий напис
    th.set_type_variation("NavButton", "Button")
    th.set_stylebox("normal", "NavButton", _nav_box(Color(0.10, 0.06, 0.03, 0.62), Color(0.55, 0.38, 0.12, 0.9), 2))
    th.set_stylebox("hover", "NavButton", _nav_box(Color(0.30, 0.18, 0.07, 0.88), GOLD, 2))
    th.set_stylebox("pressed", "NavButton", _nav_box(Color(0.42, 0.25, 0.09, 0.95), Color(1.0, 0.92, 0.55), 2))
    th.set_stylebox("focus", "NavButton", _nav_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
    th.set_font("font", "NavButton", tf)
    th.set_color("font_color", "NavButton", GOLD)
    th.set_color("font_hover_color", "NavButton", Color(1.0, 0.95, 0.65))
    th.set_color("font_pressed_color", "NavButton", Color(1, 1, 1))
    th.set_color("font_outline_color", "NavButton", Color(0.10, 0.04, 0.01))
    th.set_constant("outline_size", "NavButton", 7)
    th.set_constant("h_separation", "NavButton", 12)
    th.set_font_size("font_size", "NavButton", 30)

    # кнопка «У БІЙ!»
    th.set_type_variation("PlayButton", "Button")
    th.set_stylebox("normal", "PlayButton", _box(Color(0.50, 0.09, 0.05, 0.98), GOLD, 3))
    th.set_stylebox("hover", "PlayButton", _box(Color(0.72, 0.14, 0.07, 1.0), Color(1.0, 0.9, 0.5), 3))
    th.set_stylebox("pressed", "PlayButton", _box(Color(0.85, 0.2, 0.1, 1.0), Color(1, 1, 1), 3))
    th.set_stylebox("disabled", "PlayButton", _box(Color(0.14, 0.11, 0.09, 0.95), Color(0.30, 0.25, 0.18), 2))
    th.set_color("font_color", "PlayButton", Color(1.0, 0.92, 0.65))
    th.set_color("font_outline_color", "PlayButton", Color(0, 0, 0))
    th.set_constant("outline_size", "PlayButton", 4)
    th.set_font("font", "PlayButton", tf)
    th.set_font_size("font_size", "PlayButton", 28)
    th.set_constant("h_separation", "PlayButton", 12)

    # кнопка «Скинути прогрес»: темно-червона
    th.set_type_variation("DangerButton", "Button")
    th.set_stylebox("normal", "DangerButton", _box(Color(0.24, 0.06, 0.05, 0.95), Color(0.55, 0.18, 0.12)))
    th.set_stylebox("hover", "DangerButton", _box(Color(0.40, 0.09, 0.06, 0.98), Color(0.95, 0.40, 0.25)))
    th.set_stylebox("pressed", "DangerButton", _box(Color(0.55, 0.12, 0.08, 1.0), Color(1.0, 0.7, 0.5)))
    th.set_color("font_color", "DangerButton", Color(1.0, 0.82, 0.75))

    # табличка-заголовок (ВІДВОЮВАННЯ) і напис-заголовок
    th.set_type_variation("Banner", "PanelContainer")
    var bn := _box(Color(0.15, 0.08, 0.04, 0.97), GOLD, 3, 12)
    bn.content_margin_left = 14.0
    bn.content_margin_right = 14.0
    bn.content_margin_top = 8.0
    bn.content_margin_bottom = 8.0
    bn.shadow_size = 6
    th.set_stylebox("panel", "Banner", bn)
    th.set_type_variation("TitleLabel", "Label")
    th.set_font("font", "TitleLabel", tf)
    # зловісний напис: назви локацій, загроза
    th.set_type_variation("DarkTitle", "Label")
    th.set_font("font", "DarkTitle", GameFonts.dark())
    th.set_color("font_color", "DarkTitle", Color(0.86, 0.80, 0.72))
    th.set_color("font_outline_color", "DarkTitle", Color(0.06, 0.0, 0.0))
    th.set_constant("outline_size", "DarkTitle", 6)
    th.set_color("font_shadow_color", "DarkTitle", Color(0.45, 0.0, 0.0, 0.7))
    th.set_constant("shadow_offset_x", "DarkTitle", 2)
    th.set_constant("shadow_offset_y", "DarkTitle", 3)

    # золота розділова лінія
    var sep := StyleBoxLine.new()
    sep.color = Color(0.80, 0.60, 0.20, 0.85)
    sep.thickness = 2
    th.set_stylebox("separator", "HSeparator", sep)
    th.set_constant("separation", "HSeparator", 8)

    # панелі
    th.set_stylebox("panel", "PanelContainer", _box(Color(0.08, 0.05, 0.03, 0.93), Color(0.55, 0.38, 0.12), 3, 6))
    th.set_type_variation("Plate", "PanelContainer")
    th.set_stylebox("panel", "Plate", _box(Color(0.11, 0.065, 0.035, 0.94), Color(0.90, 0.70, 0.18), 2, 8))

    th.set_color("font_color", "Label", CREAM)
    th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
    th.set_constant("outline_size", "Label", 2)
    return th
