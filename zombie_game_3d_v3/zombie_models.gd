extends RefCounted
# Процедурні 3D-моделі зомбі: тулуб, голова з щелепою, руки й ноги на окремих "суглобах",
# рвана одяг, рани, оголені ребра, зуби, запалі очі. Тип береться з "look" у zombie_types.gd.
# build() повертає масив [MeshInstance3D, колір] (для спалаху при ударі), а "скелет" для анімації
# кладе у visual.set_meta("rig", {...}) — його рухає zombie.gd.
#
# look: skin, cloth, hat, weapon, armor, vest, suit, fat, extras, eyes, bare (скелет), crawl (повзун)

static var _tex_skin: ImageTexture
static var _tex_cloth: ImageTexture

# ---------- текстури ----------
static func _tex(kind: String) -> ImageTexture:
    if kind == "skin":
        if _tex_skin == null:
            _tex_skin = _make_tex(31, 0.09, 0.62, 1.0, true)
        return _tex_skin
    if _tex_cloth == null:
        _tex_cloth = _make_tex(57, 0.22, 0.5, 1.0, false)
    return _tex_cloth

static func _make_tex(seed_v: int, freq: float, lo: float, hi: float, veins: bool) -> ImageTexture:
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.seed = seed_v
    n.frequency = freq
    n.fractal_octaves = 3
    var n2 := FastNoiseLite.new()
    n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n2.seed = seed_v + 9
    n2.frequency = freq * 1.8
    var sz := 96
    var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
    for x in range(sz):
        for y in range(sz):
            var v := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
            var g := lerpf(lo, hi, v)
            var c := Color(g, g, g, 1.0)
            if veins:
                var vn := absf(n2.get_noise_2d(float(x), float(y)))
                if vn < 0.05:
                    c = Color(g * 0.62, g * 0.5, g * 0.62, 1.0)
                elif n2.get_noise_2d(float(x) + 40.0, float(y)) > 0.45:
                    c = Color(g * 0.82, g * 0.58, g * 0.52, 1.0)
            else:
                if n2.get_noise_2d(float(x), float(y)) > 0.4:
                    c = Color(g * 0.7, g * 0.62, g * 0.58, 1.0)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

# ---------- матеріали й меші ----------
static func _material(ctx: Dictionary, kind: String, color: Color) -> StandardMaterial3D:
    var key := kind + color.to_html(true)
    var mats: Dictionary = ctx["mats"]
    if mats.has(key):
        return mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.8
    match kind:
        "skin":
            m.albedo_texture = _tex("skin")
            m.roughness = 0.55
        "cloth":
            m.albedo_texture = _tex("cloth")
            m.roughness = 0.95
        "flesh":
            m.roughness = 0.2
        "bone":
            m.roughness = 0.5
        "metal":
            m.metallic = 0.6
            m.roughness = 0.4
        "plastic":
            m.roughness = 0.25
        "ice":
            m.roughness = 0.1
            m.emission_enabled = true
            m.emission = Color(0.5, 0.8, 1.0)
            m.emission_energy_multiplier = 0.5
            m.set_meta("em", true)
        "glow":
            m.roughness = 0.4
            m.emission_enabled = true
            m.emission = Color(color.r, color.g, color.b)
            m.emission_energy_multiplier = 3.0
    if color.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mats[key] = m
    return m

# Кеш мешів: однакові примітиви діляться одним ресурсом (швидший спавн, менше пам'яті).
static var _mesh_cache := {}
# Деталі менші за цей розмір (м) пропускаємо: з камери 26 м вони менші за 5 пікселів.
# Поставте 0.0, щоб повернути всі дрібні деталі (зуби, рани тощо).
const DETAIL_MIN := 0.16

static func _sph(r: float) -> SphereMesh:
    var key := "s%.4f" % r
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 14
    s.rings = 8
    _mesh_cache[key] = s
    return s

static func _cap(r: float, h: float) -> CapsuleMesh:
    var key := "c%.4f_%.4f" % [r, h]
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    var c := CapsuleMesh.new()
    c.radius = r
    c.height = maxf(h, r * 2.0 + 0.01)
    c.radial_segments = 10
    c.rings = 3
    _mesh_cache[key] = c
    return c

static func _cyl(top_r: float, bottom_r: float, h: float) -> CylinderMesh:
    var key := "y%.4f_%.4f_%.4f" % [top_r, bottom_r, h]
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    var c := CylinderMesh.new()
    c.top_radius = top_r
    c.bottom_radius = bottom_r
    c.height = h
    c.radial_segments = 10
    c.rings = 1
    _mesh_cache[key] = c
    return c

static func _box(v: Vector3) -> BoxMesh:
    var key := "b%.4f_%.4f_%.4f" % [v.x, v.y, v.z]
    if _mesh_cache.has(key):
        return _mesh_cache[key]
    var b := BoxMesh.new()
    b.size = v
    _mesh_cache[key] = b
    return b

static func _jit(c: Color, amt: float) -> Color:
    var j := randf_range(-amt, amt)
    return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), c.a)

# Додає меш до батьківського вузла. shadow=false — для дрібниць (економить відмальовування тіней).
static func _mi(ctx: Dictionary, parent: Node3D, mesh: Mesh, kind: String, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadow: bool = true) -> MeshInstance3D:
    var a: float = ctx["a"]
    var col := Color(color.r, color.g, color.b, color.a * a)
    if kind != "glow" and DETAIL_MIN > 0.0 and not shadow:
        var ext := mesh.get_aabb().size * scl
        if maxf(ext.x, maxf(ext.y, ext.z)) < DETAIL_MIN:
            return null
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = _material(ctx, kind, col)
    mi.position = pos
    mi.rotation_degrees = rot_deg
    mi.scale = scl
    if not shadow:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    if kind != "glow":
        var parts: Array = ctx["parts"]
        parts.append([mi, col])
    return mi

static func _node(parent: Node3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    n.rotation_degrees = rot_deg
    parent.add_child(n)
    return n

# ---------- збірка ----------
static func build(visual: Node3D, d: Dictionary) -> Array:
    var parts: Array = []
    var look: Dictionary = d["look"]
    var base: Color = d["color"]
    var ghost: bool = d.get("ghost", false)
    var a := 1.0
    if ghost:
        a = 0.5
    var fat: float = look.get("fat", 0.0)
    var bare: bool = look.get("bare", false)
    var crawl: bool = look.get("crawl", false)
    var suit: bool = look.get("suit", false)
    var eyes: Color = look.get("eyes", Color(1.0, 0.1, 0.1))
    var cloth: Color = look.get("cloth", base)
    var weapon := String(look.get("weapon", ""))
    var hat := String(look.get("hat", ""))
    var skin: Color
    if look.has("skin"):
        skin = look["skin"]
    else:
        skin = base.lerp(Color(0.52, 0.54, 0.47), 0.5).lightened(0.05)
    skin = _jit(skin, 0.05)
    var ctx := {"parts": parts, "mats": {}, "a": a}
    var rig := {"crawl": crawl}

    var steel := Color(0.55, 0.58, 0.63)
    var blood := Color(0.22, 0.015, 0.015)
    var blood_wet := Color(0.36, 0.02, 0.02)
    var bone_c := Color(0.86, 0.82, 0.7)
    var tooth_c := Color(0.78, 0.74, 0.52)
    var skin_kind := "skin"
    if bare:
        skin_kind = "bone"
    var limb_c := skin.darkened(0.12)
    var pants := cloth.darkened(0.3)
    if suit:
        pants = cloth
    var cloth_kind := "cloth"
    if suit:
        cloth_kind = "plastic"

    var w := 0.50 + 0.34 * fat
    var dep := 0.30 + 0.30 * fat
    var hip_y := 0.92
    var lean := randf_range(-22.0, -10.0) * (1.0 - 0.4 * fat)
    if crawl:
        hip_y = 0.34
        lean = -78.0

    # ---------- ноги ----------
    for i in range(2):
        var sd := -1.0 + 2.0 * float(i)
        var key := "l"
        if i == 1:
            key = "r"
        var leg := _node(visual, Vector3(sd * w * 0.28, hip_y, 0.0))
        var knee := _node(leg, Vector3(0.0, -0.46, 0.0))
        rig["leg_" + key] = leg
        rig["knee_" + key] = knee
        rig["leg_base_" + key] = 0.0
        var thick := 0.115 + 0.05 * fat
        var leg_kind := cloth_kind
        var leg_col := pants
        if bare:
            thick = 0.05
            leg_kind = "bone"
            leg_col = skin
        if crawl and i == 0:
            # відірвана нога: куксa з кісткою
            _mi(ctx, leg, _cap(thick, 0.34), leg_kind, leg_col, Vector3(0.0, -0.12, 0.0))
            _mi(ctx, leg, _sph(thick * 0.95), "flesh", blood_wet, Vector3(0.0, -0.27, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), false)
            _mi(ctx, leg, _cyl(0.03, 0.03, 0.12), "bone", bone_c, Vector3(0.0, -0.31, 0.0), Vector3.ZERO, Vector3.ONE, false)
            continue
        if crawl:
            rig["leg_base_" + key] = deg_to_rad(-78.0)
        var torn := randf() < 0.5 and not suit
        _mi(ctx, leg, _cap(thick, 0.52), leg_kind, leg_col, Vector3(0.0, -0.22, 0.0))
        var shin_kind := leg_kind
        var shin_col := leg_col
        if torn and not bare:
            shin_kind = "skin"
            shin_col = limb_c
        _mi(ctx, knee, _cap(thick * 0.82, 0.48), shin_kind, shin_col, Vector3(0.0, -0.21, 0.0))
        if torn and not bare:
            _mi(ctx, knee, _box(Vector3(0.1, 0.13, 0.03)), "flesh", blood_wet, Vector3(0.0, -0.2, -0.085), Vector3.ZERO, Vector3.ONE, false)
        var foot_c := Color(0.12, 0.1, 0.09)
        var foot_kind := "plain"
        if bare:
            foot_c = skin
            foot_kind = "bone"
        elif torn:
            foot_c = skin.darkened(0.25)
            foot_kind = "skin"
        _mi(ctx, knee, _box(Vector3(0.15, 0.07, 0.3)), foot_kind, foot_c, Vector3(0.0, -0.43, -0.07), Vector3.ZERO, Vector3.ONE, false)

    # ---------- тулуб ----------
    var torso := _node(visual, Vector3(0.0, hip_y, 0.0), Vector3(lean, 0.0, 0.0))
    rig["torso"] = torso
    rig["torso_x"] = deg_to_rad(lean)
    if bare:
        _mi(ctx, torso, _sph(0.5), "bone", skin.darkened(0.1), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3(w * 0.8, 0.22, dep * 0.9))
        _mi(ctx, torso, _cyl(0.025, 0.025, 0.6), "bone", skin, Vector3(0.0, 0.32, dep * 0.32), Vector3.ZERO, Vector3.ONE, false)
        _mi(ctx, torso, _box(Vector3(0.05, 0.4, 0.03)), "bone", skin, Vector3(0.0, 0.32, -dep * 0.4), Vector3.ZERO, Vector3.ONE, false)
        for k in range(5):
            var ry := 0.12 + 0.1 * float(k)
            var rs := 1.0 - 0.07 * float(k)
            _mi(ctx, torso, _sph(0.5), "bone", skin, Vector3(0.0, ry, 0.0), Vector3.ZERO, Vector3(w * 0.85 * rs, 0.03, dep * 0.8 * rs), false)
    else:
        _mi(ctx, torso, _cap(0.5, 1.2), cloth_kind, cloth, Vector3(0.0, 0.3, 0.0), Vector3.ZERO, Vector3(w, 0.62, dep))
        if fat > 0.0:
            var belly := _mi(ctx, torso, _sph(0.5), cloth_kind, cloth.lightened(0.05), Vector3(0.0, 0.1, -dep * 0.3), Vector3.ZERO, Vector3(w * 0.9, 0.62, dep * 0.95))
            belly.name = "belly"
            _mi(ctx, torso, _sph(0.5), "skin", skin, Vector3(0.0, 0.0, -dep * 0.55), Vector3.ZERO, Vector3(w * 0.5, 0.22, 0.12), false)
        # відкриті ребра в рані
        if randf() < 0.55 and not suit:
            var wx := randf_range(-0.2, 0.2) * w
            _mi(ctx, torso, _sph(0.5), "flesh", blood, Vector3(wx, 0.3, -dep * 0.46), Vector3.ZERO, Vector3(0.24, 0.3, 0.1), false)
            for k in range(3):
                _mi(ctx, torso, _cyl(0.012, 0.012, 0.19), "bone", bone_c, Vector3(wx, 0.2 + 0.08 * float(k), -dep * 0.5 - 0.02), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
        # плями крові на одязі
        for k in range(3):
            var bx := randf_range(-0.3, 0.3) * w
            _mi(ctx, torso, _sph(0.5), "flesh", blood, Vector3(bx, randf_range(0.1, 0.45), -dep * 0.44), Vector3.ZERO, Vector3(randf_range(0.12, 0.26), randf_range(0.1, 0.2), 0.05), false)
    # таз
    if not bare:
        _mi(ctx, torso, _sph(0.5), cloth_kind, pants, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(w * 0.92, 0.28, dep * 1.0))

    # лахміття
    if not bare and not suit:
        for i in range(6):
            var ang := TAU * float(i) / 6.0 + randf() * 0.5
            var seg_len := randf_range(0.14, 0.34)
            _mi(ctx, torso, _box(Vector3(0.08, seg_len, 0.015)), "cloth", cloth.darkened(0.15), Vector3(cos(ang) * w * 0.46, -0.04 - seg_len * 0.5, sin(ang) * dep * 0.46), Vector3(randf_range(-10.0, 10.0), rad_to_deg(-ang) - 90.0, randf_range(-12.0, 12.0)), Vector3.ONE, false)

    # ---------- голова ----------
    var head := _node(torso, Vector3(0.0, 0.66, -0.02))
    var head_x := randf_range(-4.0, 14.0)
    var head_z := randf_range(10.0, 24.0)
    if randf() < 0.5:
        head_z = -head_z
    if crawl:
        head_x = 65.0
    head.rotation_degrees = Vector3(head_x, randf_range(-10.0, 10.0), head_z)
    rig["head"] = head
    rig["head_x"] = deg_to_rad(head_x)
    rig["head_z"] = deg_to_rad(head_z)
    _mi(ctx, head, _cyl(0.07, 0.085, 0.16), skin_kind, skin, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, Vector3.ONE, false)
    _mi(ctx, head, _sph(0.5), skin_kind, skin, Vector3(0.0, 0.25, 0.0), Vector3.ZERO, Vector3(0.31, 0.36, 0.34))
    # щелепа (висить відкритою)
    var jaw := _node(head, Vector3(0.0, 0.13, -0.02))
    var jaw_open := randf_range(18.0, 40.0)
    jaw.rotation_degrees = Vector3(-jaw_open, 0.0, 0.0)
    rig["jaw"] = jaw
    rig["jaw_x"] = deg_to_rad(-jaw_open)
    _mi(ctx, jaw, _box(Vector3(0.2, 0.06, 0.17)), skin_kind, skin.darkened(0.1), Vector3(0.0, -0.03, -0.075))
    for i in range(4):
        _mi(ctx, jaw, _box(Vector3(0.025, 0.04, 0.02)), "bone", tooth_c, Vector3(-0.07 + 0.047 * float(i), 0.01, -0.16), Vector3.ZERO, Vector3.ONE, false)
        _mi(ctx, head, _box(Vector3(0.025, 0.04, 0.02)), "bone", tooth_c, Vector3(-0.07 + 0.047 * float(i), 0.135, -0.158), Vector3.ZERO, Vector3.ONE, false)
    _mi(ctx, head, _box(Vector3(0.17, 0.05, 0.06)), "flesh", Color(0.07, 0.0, 0.0), Vector3(0.0, 0.14, -0.13), Vector3.ZERO, Vector3.ONE, false)
    if not bare and randf() < 0.6:
        _mi(ctx, jaw, _box(Vector3(0.05, 0.16, 0.012)), "flesh", blood_wet, Vector3(randf_range(-0.05, 0.05), -0.1, -0.15), Vector3.ZERO, Vector3.ONE, false)
    # очі: запалі очниці + світіння
    var sock := Vector3(0.1, 0.09, 0.06)
    if bare:
        sock = Vector3(0.12, 0.12, 0.08)
    var missing := -1
    if not bare and randf() < 0.25:
        missing = randi() % 2
    for i in range(2):
        var sx := -1.0 + 2.0 * float(i)
        _mi(ctx, head, _sph(0.5), "plain", Color(0.03, 0.01, 0.01), Vector3(sx * 0.085, 0.29, -0.15), Vector3.ZERO, sock, false)
        if i == missing:
            _mi(ctx, head, _sph(0.5), "flesh", blood, Vector3(sx * 0.085, 0.27, -0.165), Vector3.ZERO, Vector3(0.05, 0.12, 0.03), false)
        elif not (hat == "gasmask"):
            _mi(ctx, head, _sph(0.5), "glow", eyes, Vector3(sx * 0.085, 0.29, -0.16), Vector3.ZERO, Vector3(0.05, 0.05, 0.05), false)
    _mi(ctx, head, _box(Vector3(0.035, 0.05, 0.03)), "plain", Color(0.04, 0.01, 0.01), Vector3(0.0, 0.2, -0.168), Vector3.ZERO, Vector3.ONE, false)
    if not bare:
        for i in range(2):
            var ex := -1.0 + 2.0 * float(i)
            _mi(ctx, head, _sph(0.5), "skin", skin.darkened(0.05), Vector3(ex * 0.16, 0.25, 0.01), Vector3.ZERO, Vector3(0.04, 0.09, 0.07), false)
        if hat == "" and randf() < 0.55:
            var hair := Color(0.13, 0.1, 0.08)
            for i in range(4):
                _mi(ctx, head, _sph(0.5), "plain", hair, Vector3(randf_range(-0.09, 0.09), 0.4, randf_range(-0.05, 0.09)), Vector3.ZERO, Vector3(0.12, 0.07, 0.12), false)
        if randf() < 0.4:
            var hs := -1.0 + 2.0 * float(randi() % 2)
            _mi(ctx, head, _sph(0.5), "flesh", blood, Vector3(hs * 0.12, 0.33, -0.07), Vector3(0.0, 0.0, hs * 20.0), Vector3(0.1, 0.09, 0.06), false)
        if randf() < 0.35:
            var cs := -1.0 + 2.0 * float(randi() % 2)
            _mi(ctx, head, _sph(0.5), "flesh", blood_wet, Vector3(cs * 0.13, 0.17, -0.1), Vector3.ZERO, Vector3(0.05, 0.1, 0.1), false)

    # ---------- головні убори ----------
    var hc := cloth.darkened(0.3)
    match hat:
        "straw":
            _mi(ctx, head, _cyl(0.3, 0.3, 0.04), "cloth", Color(0.8, 0.7, 0.3), Vector3(0.0, 0.41, 0.0), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, head, _cyl(0.15, 0.2, 0.14), "cloth", Color(0.75, 0.65, 0.28), Vector3(0.0, 0.49, 0.0), Vector3.ZERO, Vector3.ONE, false)
        "cap":
            var cap_c := Color(0.35, 0.25, 0.15)
            if weapon == "baton":
                cap_c = Color(0.08, 0.1, 0.2)
            _mi(ctx, head, _cyl(0.2, 0.21, 0.1), "cloth", cap_c, Vector3(0.0, 0.43, 0.0), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, head, _box(Vector3(0.22, 0.02, 0.14)), "cloth", cap_c.darkened(0.2), Vector3(0.0, 0.4, -0.2), Vector3.ZERO, Vector3.ONE, false)
        "hood":
            _mi(ctx, head, _sph(0.5), "cloth", hc, Vector3(0.0, 0.27, 0.07), Vector3.ZERO, Vector3(0.4, 0.4, 0.38), false)
        "helmet", "horned":
            _mi(ctx, head, _sph(0.5), "metal", steel, Vector3(0.0, 0.34, 0.0), Vector3.ZERO, Vector3(0.36, 0.3, 0.37))
            _mi(ctx, head, _box(Vector3(0.05, 0.2, 0.04)), "metal", steel, Vector3(0.0, 0.26, -0.18), Vector3.ZERO, Vector3.ONE, false)
            if hat == "horned":
                var horn_c := Color(0.9, 0.88, 0.8)
                _mi(ctx, head, _cyl(0.0, 0.07, 0.4), "bone", horn_c, Vector3(-0.2, 0.46, 0.0), Vector3(0.0, 0.0, 55.0), Vector3.ONE, false)
                _mi(ctx, head, _cyl(0.0, 0.07, 0.4), "bone", horn_c, Vector3(0.2, 0.46, 0.0), Vector3(0.0, 0.0, -55.0), Vector3.ONE, false)
        "turban":
            _mi(ctx, head, _sph(0.5), "cloth", Color(0.85, 0.8, 0.7), Vector3(0.0, 0.4, 0.0), Vector3.ZERO, Vector3(0.38, 0.28, 0.38), false)
            _mi(ctx, head, _sph(0.5), "glow", Color(0.85, 0.12, 0.12), Vector3(0.0, 0.42, -0.17), Vector3.ZERO, Vector3(0.06, 0.06, 0.06), false)
        "gasmask":
            _mi(ctx, head, _sph(0.5), "cloth", cloth, Vector3(0.0, 0.3, 0.05), Vector3.ZERO, Vector3(0.38, 0.4, 0.36), false)
            _mi(ctx, head, _sph(0.5), "plastic", Color(0.12, 0.13, 0.12), Vector3(0.0, 0.2, -0.07), Vector3.ZERO, Vector3(0.3, 0.3, 0.28))
            _mi(ctx, head, _cyl(0.07, 0.07, 0.12), "metal", Color(0.25, 0.27, 0.25), Vector3(0.0, 0.14, -0.22), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
            for i in range(2):
                var lx := -1.0 + 2.0 * float(i)
                _mi(ctx, head, _sph(0.5), "glow", eyes, Vector3(lx * 0.085, 0.29, -0.18), Vector3.ZERO, Vector3(0.09, 0.09, 0.05), false)

    # ---------- руки ----------
    var arm_base := randf_range(72.0, 92.0)
    if crawl:
        arm_base = 140.0
    var wx_shoulder := w * 0.5 + 0.02
    for i in range(2):
        var sd := -1.0 + 2.0 * float(i)
        var key := "l"
        if i == 1:
            key = "r"
        var holds := (i == 1 and weapon != "")
        var stump := false
        var limp := false
        if not holds and not suit and not crawl:
            var rr := randf()
            if rr < 0.1:
                stump = true
            elif rr < 0.28:
                limp = true
        var base_deg := arm_base + randf_range(-6.0, 6.0)
        if limp:
            base_deg = randf_range(5.0, 25.0)
        var arm := _node(torso, Vector3(sd * wx_shoulder, 0.56, 0.0), Vector3(base_deg, 0.0, sd * 5.0))
        rig["arm_" + key] = arm
        rig["arm_base_" + key] = deg_to_rad(base_deg)
        var thick := 0.07 + 0.03 * fat
        var up_kind := cloth_kind
        var up_col := cloth
        var sleeve_torn := randf() < 0.5 and not suit
        if bare:
            thick = 0.03
            up_kind = "bone"
            up_col = skin
        elif sleeve_torn:
            up_kind = "skin"
            up_col = limb_c
        if stump:
            _mi(ctx, arm, _cap(thick, 0.28), up_kind, up_col, Vector3(0.0, -0.1, 0.0))
            _mi(ctx, arm, _sph(thick * 1.05), "flesh", blood_wet, Vector3(0.0, -0.24, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0), false)
            _mi(ctx, arm, _cyl(0.025, 0.025, 0.1), "bone", bone_c, Vector3(0.0, -0.27, 0.0), Vector3.ZERO, Vector3.ONE, false)
            rig["fore_" + key] = null
            rig["fore_base_" + key] = 0.0
            continue
        _mi(ctx, arm, _cap(thick, 0.4), up_kind, up_col, Vector3(0.0, -0.18, 0.0))
        var bend := randf_range(12.0, 32.0)
        if limp:
            bend = randf_range(15.0, 40.0)
        if crawl:
            bend = 10.0
        var fore := _node(arm, Vector3(0.0, -0.35, 0.0), Vector3(bend, 0.0, 0.0))
        rig["fore_" + key] = fore
        rig["fore_base_" + key] = deg_to_rad(bend)
        var fore_kind := "skin"
        var fore_col := limb_c
        if bare:
            fore_kind = "bone"
            fore_col = skin
        elif suit:
            fore_kind = cloth_kind
            fore_col = cloth
        _mi(ctx, fore, _cap(thick * 0.85, 0.38), fore_kind, fore_col, Vector3(0.0, -0.17, 0.0))
        if randf() < 0.4 and not bare and not suit:
            _mi(ctx, fore, _box(Vector3(0.09, 0.11, 0.03)), "flesh", blood_wet, Vector3(0.0, -0.15, -0.065), Vector3.ZERO, Vector3.ONE, false)
        var hand_kind := fore_kind
        var hand_col := fore_col
        if suit:
            hand_kind = "plastic"
            hand_col = Color(0.1, 0.1, 0.1)
        _mi(ctx, fore, _sph(0.5), hand_kind, hand_col, Vector3(0.0, -0.37, 0.0), Vector3.ZERO, Vector3(0.1, 0.14, 0.07), false)
        for k in range(3):
            _mi(ctx, fore, _box(Vector3(0.018, 0.1, 0.018)), "bone", bone_c.darkened(0.2), Vector3(-0.035 + 0.035 * float(k), -0.46, 0.0), Vector3(-12.0, 0.0, (float(k) - 1.0) * 10.0), Vector3.ONE, false)

    # ---------- броня, жилет ----------
    if look.get("armor", false):
        _mi(ctx, torso, _box(Vector3(w * 0.95, 0.45, 0.1)), "metal", steel, Vector3(0.0, 0.34, -dep * 0.5), Vector3.ZERO, Vector3.ONE, false)
        _mi(ctx, torso, _sph(0.5), "metal", steel, Vector3(-wx_shoulder - 0.06, 0.58, 0.0), Vector3.ZERO, Vector3(0.28, 0.24, 0.28), false)
        _mi(ctx, torso, _sph(0.5), "metal", steel, Vector3(wx_shoulder + 0.06, 0.58, 0.0), Vector3.ZERO, Vector3(0.28, 0.24, 0.28), false)
    if look.get("vest", false):
        var vest_c := Color(0.1, 0.1, 0.12)
        _mi(ctx, torso, _box(Vector3(w * 0.88, 0.42, 0.09)), "cloth", vest_c, Vector3(0.0, 0.34, -dep * 0.5), Vector3.ZERO, Vector3.ONE, false)
        _mi(ctx, torso, _box(Vector3(w * 0.88, 0.4, 0.07)), "cloth", vest_c, Vector3(0.0, 0.34, dep * 0.5), Vector3.ZERO, Vector3.ONE, false)
        _mi(ctx, torso, _box(Vector3(0.12, 0.08, 0.04)), "plain", Color(0.35, 0.3, 0.1), Vector3(-w * 0.2, 0.42, -dep * 0.56), Vector3.ZERO, Vector3.ONE, false)

    # ---------- зброя в правій руці ----------
    if weapon != "":
        var wm := _node(torso, Vector3(wx_shoulder, 0.56, 0.0))
        rig["wmount"] = wm
        _build_weapon(ctx, wm, weapon)

    # ---------- особливості ----------
    var extras: Array = look.get("extras", [])
    for ex in extras:
        match String(ex):
            "bandage":
                var wrap := Color(0.82, 0.76, 0.6)
                for k in range(6):
                    _mi(ctx, torso, _cyl(0.5, 0.5, 0.07), "cloth", _jit(wrap, 0.06), Vector3(0.0, -0.02 + 0.12 * float(k), 0.0), Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0)), Vector3(w * 1.02, 1.0, dep * 1.05), false)
                for k in range(3):
                    _mi(ctx, head, _cyl(0.5, 0.5, 0.05), "cloth", _jit(wrap, 0.06), Vector3(0.0, 0.15 + 0.06 * float(k) + (0.07 if k == 2 else 0.0), 0.0), Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0)), Vector3(0.3, 1.0, 0.33), false)
                for k in range(2):
                    var strip_s := -1.0 + 2.0 * float(k)
                    _mi(ctx, torso, _box(Vector3(0.05, 0.4, 0.01)), "cloth", wrap.darkened(0.1), Vector3(strip_s * w * 0.3, -0.25, -dep * 0.4), Vector3(randf_range(-10.0, 10.0), 0.0, strip_s * 8.0), Vector3.ONE, false)
            "icicles":
                for k in range(6):
                    var ang := TAU * float(k) / 6.0
                    _mi(ctx, head, _cyl(0.0, 0.05, 0.3), "ice", Color(0.7, 0.9, 1.0, 0.85), Vector3(cos(ang) * 0.17, 0.46, sin(ang) * 0.17), Vector3(sin(ang) * 35.0, 0.0, -cos(ang) * 35.0), Vector3.ONE, false)
                for k in range(2):
                    var sh := -1.0 + 2.0 * float(k)
                    _mi(ctx, torso, _cyl(0.0, 0.07, 0.4), "ice", Color(0.7, 0.9, 1.0, 0.85), Vector3(sh * (wx_shoulder + 0.05), 0.76, 0.0), Vector3(0.0, 0.0, -sh * 25.0), Vector3.ONE, false)
                _mi(ctx, torso, _sph(0.5), "ice", Color(0.85, 0.95, 1.0, 0.8), Vector3(0.0, 0.3, -dep * 0.4), Vector3.ZERO, Vector3(w * 0.6, 0.35, 0.1), false)
            "growth":
                var moss := Color(0.2, 0.42, 0.15)
                for k in range(7):
                    var ang := TAU * float(k) / 7.0
                    _mi(ctx, torso, _sph(0.5), "plain", _jit(moss, 0.06), Vector3(cos(ang) * w * 0.45, 0.1 + 0.07 * float(k), sin(ang) * dep * 0.45), Vector3.ZERO, Vector3.ONE * randf_range(0.14, 0.26), false)
                _mi(ctx, head, _sph(0.5), "plain", moss, Vector3(0.1, 0.45, 0.05), Vector3.ZERO, Vector3(0.22, 0.16, 0.22), false)
                for k in range(2):
                    var ms := -1.0 + 2.0 * float(k)
                    _mi(ctx, torso, _cyl(0.02, 0.025, 0.14), "bone", Color(0.8, 0.75, 0.6), Vector3(ms * wx_shoulder, 0.68, 0.03), Vector3.ZERO, Vector3.ONE, false)
                    _mi(ctx, torso, _sph(0.5), "plain", Color(0.7, 0.2, 0.15), Vector3(ms * wx_shoulder, 0.76, 0.03), Vector3.ZERO, Vector3(0.18, 0.1, 0.18), false)
            "pustules":
                for k in range(7):
                    var ang := TAU * float(k) / 7.0 + 0.5
                    _mi(ctx, torso, _sph(0.5), "glow", Color(0.85, 0.9, 0.3), Vector3(cos(ang) * w * 0.5, 0.05 + 0.1 * float(k), -dep * 0.2 - sin(ang) * dep * 0.4), Vector3.ZERO, Vector3.ONE * randf_range(0.12, 0.26), false)
                _mi(ctx, head, _sph(0.5), "glow", Color(0.85, 0.9, 0.3), Vector3(-0.12, 0.38, -0.05), Vector3.ZERO, Vector3.ONE * 0.1, false)
            "spikes":
                for k in range(6):
                    var sy := 0.05 + 0.11 * float(k)
                    var sl := 0.3 - 0.02 * float(k)
                    _mi(ctx, torso, _cyl(0.0, 0.045, sl), "bone", bone_c.darkened(0.1), Vector3(0.0, sy, dep * 0.55), Vector3(70.0, 0.0, 0.0), Vector3.ONE, false)
                for k in range(2):
                    var ss := -1.0 + 2.0 * float(k)
                    _mi(ctx, torso, _cyl(0.0, 0.06, 0.45), "bone", bone_c, Vector3(ss * (wx_shoulder + 0.08), 0.7, 0.0), Vector3(0.0, 0.0, -ss * 35.0), Vector3.ONE, false)
            "tumor":
                var tum := Color(0.55, 0.22, 0.25)
                _mi(ctx, torso, _sph(0.5), "flesh", tum, Vector3(-w * 0.35, 0.5, dep * 0.35), Vector3.ZERO, Vector3(0.4, 0.34, 0.36), false)
                _mi(ctx, torso, _sph(0.5), "flesh", tum.darkened(0.1), Vector3(w * 0.3, 0.15, -dep * 0.4), Vector3.ZERO, Vector3(0.3, 0.26, 0.28), false)
                _mi(ctx, torso, _sph(0.5), "glow", Color(0.9, 0.2, 0.15), Vector3(-w * 0.35, 0.55, dep * 0.6), Vector3.ZERO, Vector3(0.12, 0.12, 0.12), false)
            "tank":
                _mi(ctx, torso, _box(Vector3(0.36, 0.42, 0.14)), "plastic", Color(0.25, 0.27, 0.22), Vector3(0.0, 0.34, dep * 0.62), Vector3.ZERO, Vector3.ONE, false)
                _mi(ctx, torso, _cyl(0.09, 0.09, 0.5), "metal", Color(0.6, 0.15, 0.1), Vector3(-0.1, 0.36, dep * 0.8), Vector3.ZERO, Vector3.ONE, false)
                _mi(ctx, torso, _cyl(0.09, 0.09, 0.5), "metal", Color(0.6, 0.15, 0.1), Vector3(0.1, 0.36, dep * 0.8), Vector3.ZERO, Vector3.ONE, false)
            "tentacles":
                var tents: Array = []
                for k in range(4):
                    var side := -1.0 + 2.0 * float(k % 2)
                    var root := _node(torso, Vector3(side * w * 0.3, 0.4 + 0.1 * float(k >> 1), dep * 0.5), Vector3(40.0, 0.0, side * 30.0))
                    var cur: Node3D = root
                    for sg in range(4):
                        var rr := 0.07 - 0.012 * float(sg)
                        _mi(ctx, cur, _cap(rr, 0.32), "flesh", Color(0.5, 0.2, 0.25), Vector3(0.0, 0.14, 0.0), Vector3.ZERO, Vector3.ONE, false)
                        tents.append([cur, cur.rotation.x, cur.rotation.z, float(k * 4 + sg)])
                        cur = _node(cur, Vector3(0.0, 0.28, 0.0), Vector3(12.0, 0.0, 0.0))
                rig["tentacles"] = tents

    visual.set_meta("rig", rig)
    return parts

# ---------- зброя ----------
# Початок координат вузла wm — плече; руку (хват) умовно ставимо в точку g.
static func _build_weapon(ctx: Dictionary, wm: Node3D, weapon: String) -> void:
    var g := Vector3(0.0, -0.12, -0.58)
    var wood := Color(0.42, 0.28, 0.14)
    var metal := Color(0.7, 0.7, 0.74)
    var rust := Color(0.45, 0.3, 0.2)
    match weapon:
        "pitchfork":
            _mi(ctx, wm, _cyl(0.035, 0.035, 2.0), "plain", wood, g + Vector3(0, 0, -0.4), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.45, 0.04, 0.04)), "metal", rust, g + Vector3(0, 0, -1.4), Vector3.ZERO, Vector3.ONE, false)
            for off in [-0.2, 0.0, 0.2]:
                _mi(ctx, wm, _box(Vector3(0.04, 0.04, 0.4)), "metal", rust, g + Vector3(float(off), 0.0, -1.6), Vector3.ZERO, Vector3.ONE, false)
        "axe":
            _mi(ctx, wm, _box(Vector3(0.06, 0.06, 1.4)), "plain", wood, g + Vector3(0, 0, -0.3), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.06, 0.5, 0.36)), "metal", metal.darkened(0.2), g + Vector3(0, 0.05, -0.95), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.065, 0.2, 0.12)), "flesh", Color(0.3, 0.02, 0.02), g + Vector3(0, -0.12, -1.0), Vector3.ZERO, Vector3.ONE, false)
        "sword":
            _mi(ctx, wm, _box(Vector3(0.09, 0.03, 1.1)), "metal", metal.darkened(0.15), g + Vector3(0, 0, -0.8), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.4, 0.05, 0.07)), "metal", Color(0.7, 0.55, 0.2), g + Vector3(0, 0, -0.22), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.05, 0.05, 0.28)), "plain", wood.darkened(0.3), g + Vector3(0, 0, -0.04), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.03, 0.035, 0.4)), "flesh", Color(0.28, 0.02, 0.02), g + Vector3(0, 0.0, -1.0), Vector3.ZERO, Vector3.ONE, false)
        "club":
            _mi(ctx, wm, _cyl(0.12, 0.05, 1.3), "plain", wood, g + Vector3(0, 0, -0.45), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
            for k in range(3):
                _mi(ctx, wm, _cyl(0.0, 0.025, 0.1), "metal", metal, g + Vector3(0.1, 0.0, -0.85 - 0.12 * float(k)), Vector3(0.0, 0.0, -90.0), Vector3.ONE, false)
        "baton":
            _mi(ctx, wm, _cyl(0.04, 0.04, 0.7), "plain", Color(0.05, 0.05, 0.06), g + Vector3(0, 0, -0.2), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
        "rifle":
            _mi(ctx, wm, _box(Vector3(0.07, 0.12, 0.5)), "plain", Color(0.15, 0.15, 0.14), g + Vector3(0, 0.0, 0.12), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.06, 0.09, 0.45)), "metal", Color(0.12, 0.12, 0.13), g + Vector3(0, 0.02, -0.4), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _cyl(0.02, 0.02, 0.6), "metal", Color(0.1, 0.1, 0.1), g + Vector3(0, 0.03, -0.9), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.05, 0.2, 0.08)), "plain", Color(0.1, 0.1, 0.1), g + Vector3(0, -0.14, -0.35), Vector3(10.0, 0.0, 0.0), Vector3.ONE, false)
        "shovel":
            _mi(ctx, wm, _box(Vector3(0.06, 0.06, 1.7)), "plain", wood, g + Vector3(0, 0, -0.4), Vector3.ZERO, Vector3.ONE, false)
            _mi(ctx, wm, _box(Vector3(0.36, 0.04, 0.45)), "metal", metal.darkened(0.3), g + Vector3(0, 0, -1.4), Vector3.ZERO, Vector3.ONE, false)
        "bow":
            for i in range(5):
                var t := lerpf(-1.0, 1.0, float(i) / 4.0)
                _mi(ctx, wm, _box(Vector3(0.05, 0.28, 0.05)), "plain", wood, g + Vector3(0, sin(t) * 0.55, -0.3 + (1.0 - cos(t)) * 0.5), Vector3(rad_to_deg(t), 0.0, 0.0), Vector3.ONE, false)
        "staff":
            _mi(ctx, wm, _cyl(0.04, 0.04, 1.9), "plain", wood, g + Vector3(0, 0.0, -0.3), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
            _mi(ctx, wm, _sph(0.5), "glow", Color(0.7, 0.3, 1.0), g + Vector3(0, 0.05, -1.3), Vector3.ZERO, Vector3.ONE * 0.3, false)
