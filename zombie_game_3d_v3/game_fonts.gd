extends RefCounted
# Шрифти гри. Один файл керує всім текстом: меню, карта, бій, підказки, написи над ворогами.
#
# ЯК ДОДАТИ СВІЙ ШРИФТ: покладіть .ttf / .otf (обов'язково з кирилицею) у папку res://fonts/ — з будь-якою назвою.
#   • один свій шрифт  -> він стає шрифтом УСІЄЇ гри (і королівським, і зловісним);
#   • є файли з «royal» і «dark» у назві (royal.ttf, dark.ttf) -> royal — королівський/золотий (заголовки, кнопки,
#     «ВІДВОЮВАННЯ», Зброя/Броня/Навики, ПЕРЕМОГА) і основний шрифт гри, dark — зловісний (назви локацій, складність,
#     повідомлення бою, ПОРАЗКА);
#   • старе ім'я title.ttf теж вважається королівським.
# Після того як поклали файл, відкрийте проєкт у Godot і зачекайте, поки редактор його імпортує (внизу праворуч).
# Якщо своїх шрифтів немає, працюють запасні: Lora Bold (королівський) і Arsenal SC (зловісний, потовщений).

const BUILTIN_PREFIXES := ["Lora-", "ArsenalSC-", "CormorantSC-", "CormorantGaramond-", "RuslanDisplay-"]
const EXTS := ["ttf", "otf", "woff", "woff2"]

static var _royal: Font
static var _dark: Font
static var _custom_cache: Array = []
static var _scanned := false

# Усі шрифти користувача в res://fonts/ (крім вбудованих). Працює і в редакторі, і в зібраній грі
# (там поруч із .ttf лежить .ttf.import, тож суфікс .import відкидаємо).
static func _customs() -> Array:
    if _scanned:
        return _custom_cache
    _scanned = true
    var seen := {}
    for f in DirAccess.get_files_at("res://fonts"):
        var fname := String(f)
        if fname.ends_with(".import"):
            fname = fname.trim_suffix(".import")
        if seen.has(fname) or _is_builtin(fname):
            continue
        if not EXTS.has(fname.get_extension().to_lower()):
            continue
        seen[fname] = true
        _custom_cache.append(fname)
    _custom_cache.sort()
    return _custom_cache

static func _is_builtin(fname: String) -> bool:
    for p in BUILTIN_PREFIXES:
        if fname.begins_with(p):
            return true
    return false

static func _variable(path: String, weight: int, embolden: float = 0.0, glyph_space: int = 0) -> Font:
    var fv := FontVariation.new()
    fv.base_font = load(path) as Font
    if path.find("-VF") >= 0:
        fv.variation_opentype = {"wght": weight}
    fv.variation_embolden = embolden
    fv.spacing_glyph = glyph_space
    return fv

static func _load(fname: String) -> Font:
    var p := "res://fonts/" + fname
    if ResourceLoader.exists(p):
        var r = load(p)
        if r is Font:
            return r
    # шрифт ще не імпортовано редактором — читаємо файл напряму (працює в редакторі)
    if FileAccess.file_exists(p):
        var ff := FontFile.new()
        if ff.load_dynamic_font(p) == OK:
            return ff
    return null

static func _pick(keys: Array, exclude: Array = []) -> String:
    for n in _customs():
        var low := String(n).to_lower()
        for k in keys:
            if low.find(String(k)) >= 0:
                return String(n)
    return ""

static func has_custom() -> bool:
    return not _customs().is_empty()

# Королівський (золотий) і основний шрифт усієї гри.
static func royal() -> Font:
    if _royal == null:
        var n := _pick(["royal", "title"])
        if n == "":
            # немає позначених файлів — беремо перший свій шрифт, який не «dark»
            for c in _customs():
                if String(c).to_lower().find("dark") < 0:
                    n = String(c)
                    break
        if n == "" and not _customs().is_empty():
            n = String(_customs()[0])
        if n != "":
            _royal = _load(n)
        if _royal == null:
            _royal = load("res://fonts/CormorantSC-Bold.ttf") as Font
    return _royal

# Зловісний (темний): назви локацій, складність, повідомлення бою, ПОРАЗКА.
static func dark() -> Font:
    if _dark == null:
        var n := _pick(["dark"])
        if n != "":
            _dark = _load(n)
        if _dark == null and has_custom():
            _dark = royal()           # один свій шрифт на всю гру
        if _dark == null:
            _dark = _variable("res://fonts/RuslanDisplay-Regular.ttf", 400, 0.3)
    return _dark

# Повідомлення в бою: курсив Cormorant Garamond Bold Italic.
static var _msg: Font
static func message() -> Font:
    if _msg == null:
        _msg = _variable("res://fonts/CormorantGaramond-Italic-VF.ttf", 700, 0.2)
    return _msg

# Маленький підпис (ХВИЛЯ, ВАТАЖОК...): Cormorant SC з розрідженими літерами.
static var _tag: Font
static func tag() -> Font:
    if _tag == null:
        _tag = _variable("res://fonts/CormorantSC-Bold.ttf", 700, 0.3, 3)
    return _tag

# Основний шрифт для всього тексту, де не задано окремий.
# Якщо є fonts/body.ttf — довгі тексти (описи, підказки) пишуться ним, щоб не були суцільною капітеллю.
static var _body: Font
static func body() -> Font:
    if _body == null:
        var n := _pick(["body"])
        if n != "":
            _body = _load(n)
        if _body == null and has_custom():
            _body = royal()
        if _body == null:
            _body = _variable("res://fonts/CormorantGaramond-VF.ttf", 600, 0.25)
    return _body

# Робить body() шрифтом за замовчуванням у всій грі: Control-елементи, Label3D (цифри урону) тощо.
static func install_global() -> void:
    var f := body()
    var dt := ThemeDB.get_default_theme()
    if dt != null:
        dt.default_font = f
    ThemeDB.fallback_font = f

static func apply(ctrl: Control, font: Font) -> void:
    ctrl.add_theme_font_override("font", font)
