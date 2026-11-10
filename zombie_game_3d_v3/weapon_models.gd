extends RefCounted
# 3D-моделі зброї в руці гравця. Усі "вперед" вздовж -Z.

const Util = preload("res://util.gd")
const IceShard = preload("res://ice_shard.gd")
const BlueFire = preload("res://blue_fire.gd")

static func _b(h: Node3D, size: Vector3, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, rough: float = 0.6, emit: float = 0.0) -> void:
    Util.add_mesh(h, Util.box(size), color, pos, rot, rough, emit)

# Циліндр уздовж Z: fr — радіус переднього (−Z) кінця, br — заднього; zc — центр, y/x — зсув.
static func _cz(h: Node3D, fr: float, br: float, len: float, color: Color, zc: float, rough: float = 0.5, emit: float = 0.0, y: float = 0.0, x: float = 0.0) -> void:
    var c := CylinderMesh.new()
    c.top_radius = fr
    c.bottom_radius = br
    c.height = len
    c.radial_segments = 20
    c.rings = 1
    Util.add_mesh(h, c, color, Vector3(x, y, zc), Vector3(-90, 0, 0), rough, emit)

static func _sp(h: Node3D, r: float, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, rough: float = 0.4, emit: float = 0.0) -> void:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 24
    s.rings = 12
    var mi := Util.add_mesh(h, s, color, pos, Vector3.ZERO, rough, emit)
    mi.scale = scl

# Двосхила гостра полоса меча: центральне ребро + зужений кінчик (вістря на −Z).
static func _blade(h: Node3D, width: float, z0: float, z1: float, color: Color, rib: Color) -> void:
    var len := absf(z1 - z0)
    var body := len * 0.84
    var zb := z0 - body * 0.5
    _b(h, Vector3(width, 0.035, body), color, Vector3(0, 0, zb), Vector3.ZERO, 0.25)
    _b(h, Vector3(width * 0.28, 0.05, body), rib, Vector3(0, 0, zb), Vector3.ZERO, 0.3)
    var tip := PrismMesh.new()
    tip.size = Vector3(width, len * 0.16, 0.035)
    Util.add_mesh(h, tip, color, Vector3(0, 0, z0 - body - len * 0.08), Vector3(-90, 0, 0), 0.25)

static func build(h: Node3D, id: String) -> void:
    var steel := Color(0.85, 0.87, 0.93)
    var wood := Color(0.35, 0.22, 0.1)
    var gold := Color(0.75, 0.6, 0.2)
    var dark := Color(0.18, 0.18, 0.2)
    match id:
        "knife":
            _blade(h, 0.06, -0.08, -0.52, steel, steel.darkened(0.15))
            _b(h, Vector3(0.11, 0.045, 0.04), dark, Vector3(0, 0, -0.07))
            _cz(h, 0.034, 0.038, 0.17, wood, 0.02, 0.8)
            _sp(h, 0.04, dark, Vector3(0, 0, 0.11), Vector3.ONE, 0.5)
        "dagger":
            _blade(h, 0.055, -0.08, -0.5, steel, Color(0.6, 0.63, 0.72))
            _b(h, Vector3(0.26, 0.04, 0.05), gold, Vector3(0, 0, -0.07), Vector3.ZERO, 0.3)
            _sp(h, 0.03, gold, Vector3(0.13, 0, -0.07), Vector3.ONE, 0.3)
            _sp(h, 0.03, gold, Vector3(-0.13, 0, -0.07), Vector3.ONE, 0.3)
            _cz(h, 0.034, 0.036, 0.16, dark, 0.03, 0.8)
            _sp(h, 0.045, gold, Vector3(0, 0, 0.12), Vector3.ONE, 0.3)
        "sword":
            _blade(h, 0.1, -0.22, -1.75, steel, Color(0.62, 0.66, 0.78))
            _b(h, Vector3(0.52, 0.06, 0.09), gold, Vector3(0, 0, -0.2), Vector3.ZERO, 0.3)
            _sp(h, 0.045, gold, Vector3(0.26, 0, -0.2), Vector3.ONE, 0.3)
            _sp(h, 0.045, gold, Vector3(-0.26, 0, -0.2), Vector3.ONE, 0.3)
            _cz(h, 0.038, 0.042, 0.32, wood, 0.0, 0.85)
            for k in range(4):
                _cz(h, 0.045, 0.045, 0.025, dark, -0.1 + 0.07 * float(k), 0.9)
            _sp(h, 0.065, gold, Vector3(0, 0, 0.17), Vector3.ONE, 0.3)
        "spear":
            _cz(h, 0.03, 0.033, 3.1, wood, -1.3, 0.8)
            _cz(h, 0.0, 0.075, 0.55, steel, -3.1, 0.25)
            _b(h, Vector3(0.025, 0.03, 0.4), Color(0.62, 0.66, 0.78), Vector3(0, 0, -3.1), Vector3.ZERO, 0.3)
            _cz(h, 0.05, 0.05, 0.1, gold, -2.82, 0.3)
            _sp(h, 0.05, Color(0.7, 0.1, 0.1), Vector3(0, -0.05, -2.74), Vector3(1, 1.8, 1), 0.9)
            _cz(h, 0.035, 0.0, 0.14, steel, 0.3, 0.3)
        "axe":
            _cz(h, 0.034, 0.04, 1.4, wood, -0.55, 0.8)
            _b(h, Vector3(0.09, 0.15, 0.2), dark, Vector3(0, 0, -1.0), Vector3.ZERO, 0.4)
            _b(h, Vector3(0.05, 0.5, 0.28), steel, Vector3(0, 0.05, -1.2), Vector3.ZERO, 0.28)
            _b(h, Vector3(0.06, 0.52, 0.04), Color(0.95, 0.97, 1.0), Vector3(0, 0.05, -1.36), Vector3.ZERO, 0.2)
            _cz(h, 0.0, 0.04, 0.2, dark, -0.86, 0.4)
            _sp(h, 0.04, dark, Vector3(0, 0, 0.15), Vector3.ONE, 0.5)
        "mace":
            _cz(h, 0.035, 0.04, 1.05, wood, -0.45, 0.8)
            _sp(h, 0.21, dark, Vector3(0, 0, -1.05), Vector3.ONE, 0.35)
            for i in range(8):
                var a := TAU * float(i) / 8.0
                Util.add_mesh(h, Util.cylinder(0.0, 0.05, 0.2), steel, Vector3(cos(a) * 0.22, sin(a) * 0.22, -1.05), Vector3(0, 0, rad_to_deg(a) - 90.0), 0.3)
            for i in range(4):
                var a2 := TAU * float(i) / 4.0 + 0.4
                Util.add_mesh(h, Util.cylinder(0.0, 0.05, 0.2), steel, Vector3(cos(a2) * 0.15, sin(a2) * 0.15, -1.2), Vector3(-45.0 * sin(a2), 0, rad_to_deg(a2) - 90.0), 0.3)
            _cz(h, 0.0, 0.05, 0.2, steel, -1.35, 0.3)
            _cz(h, 0.05, 0.05, 0.06, gold, -0.8, 0.3)
        "greatsword":
            _blade(h, 0.17, -0.34, -2.6, steel, Color(0.6, 0.65, 0.78))
            _b(h, Vector3(0.74, 0.08, 0.11), gold, Vector3(0, 0, -0.3), Vector3.ZERO, 0.3)
            _sp(h, 0.06, gold, Vector3(0.37, 0, -0.3), Vector3.ONE, 0.3)
            _sp(h, 0.06, gold, Vector3(-0.37, 0, -0.3), Vector3.ONE, 0.3)
            _cz(h, 0.04, 0.045, 0.55, wood, 0.0, 0.85)
            _sp(h, 0.08, gold, Vector3(0, 0, 0.3), Vector3.ONE, 0.3)
        "warhammer":
            _cz(h, 0.035, 0.04, 1.5, wood, -0.6, 0.8)
            _b(h, Vector3(0.5, 0.32, 0.32), dark, Vector3(0, 0, -1.4), Vector3.ZERO, 0.35)
            _b(h, Vector3(0.56, 0.36, 0.1), steel, Vector3(0, 0, -1.4), Vector3.ZERO, 0.3)
            Util.add_mesh(h, Util.cylinder(0.0, 0.065, 0.36), steel, Vector3(0.42, 0, -1.4), Vector3(0, 0, -90), 0.3)
            Util.add_mesh(h, Util.cylinder(0.0, 0.065, 0.2), steel, Vector3(-0.35, 0, -1.4), Vector3(0, 0, 90), 0.3)
        "bow":
            for i in range(11):
                var t := lerpf(-1.1, 1.1, float(i) / 10.0)
                var thick := lerpf(0.06, 0.04, absf(t) / 1.1)
                _b(h, Vector3(thick, 0.22, thick), wood, Vector3(0, sin(t) * 0.6, 0.4 - cos(t) * 0.6), Vector3(rad_to_deg(t), 0, 0), 0.6)
            _cz(h, 0.04, 0.04, 0.2, dark, -0.2, 0.9)
            _sp(h, 0.03, gold, Vector3(0, 0.55, 0.13), Vector3.ONE, 0.4)
            _sp(h, 0.03, gold, Vector3(0, -0.55, 0.13), Vector3.ONE, 0.4)
            _b(h, Vector3(0.012, 1.1, 0.012), Color(0.9, 0.9, 0.9), Vector3(0, 0, 0.13))
        "throwing":
            _b(h, Vector3(0.04, 0.03, 0.34), steel, Vector3(0, 0, -0.22), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.06, 0.06, 0.12), dark, Vector3(0, 0, 0.0))
            _b(h, Vector3(0.04, 0.03, 0.34), steel, Vector3(0.1, 0.0, -0.18), Vector3(0, -12, 0), 0.3)
        "crossbow":
            _b(h, Vector3(0.1, 0.12, 0.9), wood, Vector3(0, 0, -0.3))
            _b(h, Vector3(0.07, 0.07, 0.3), wood.darkened(0.2), Vector3(0, -0.06, 0.2), Vector3(-8, 0, 0))
            _b(h, Vector3(1.0, 0.05, 0.07), dark, Vector3(0, 0.04, -0.7))
            for sx in [-1.0, 1.0]:
                _b(h, Vector3(0.3, 0.05, 0.07), dark, Vector3(float(sx) * 0.62, 0.04, -0.62), Vector3(0, float(sx) * 22.0, 0))
            _b(h, Vector3(1.0, 0.01, 0.01), Color(0.9, 0.9, 0.9), Vector3(0, 0.04, -0.5))
            _b(h, Vector3(0.04, 0.04, 0.5), steel, Vector3(0, 0.1, -0.5), Vector3.ZERO, 0.3)
            _cz(h, 0.0, 0.03, 0.14, steel, -0.82, 0.3, 0.0, 0.1)
            _b(h, Vector3(0.14, 0.03, 0.06), dark, Vector3(0, 0.0, -0.9))
        "musket":
            _cz(h, 0.04, 0.045, 1.5, dark, -0.9, 0.3, 0.0, 0.03)
            _b(h, Vector3(0.09, 0.15, 0.7), wood, Vector3(0, -0.02, 0.0))
            _b(h, Vector3(0.08, 0.1, 0.4), wood, Vector3(0, -0.01, -0.4))
            for k in range(3):
                _cz(h, 0.05, 0.05, 0.03, gold, -0.5 - 0.35 * float(k), 0.3, 0.0, 0.03)
            _b(h, Vector3(0.1, 0.05, 0.08), gold, Vector3(0, 0.03, -0.12))
            _b(h, Vector3(0.025, 0.06, 0.05), steel, Vector3(0, 0.08, -1.55))
            _b(h, Vector3(0.05, 0.14, 0.22), wood.darkened(0.15), Vector3(0, -0.1, 0.4), Vector3(-12, 0, 0))
        "fire_staff":
            _cz(h, 0.04, 0.045, 1.9, wood, -0.7, 0.8)
            _sp(h, 0.12, Color(1.0, 0.6, 0.12), Vector3(0, 0, -1.74), Vector3(1.0, 1.0, 1.4), 0.3, 3.5)
            _sp(h, 0.07, Color(1.0, 0.9, 0.5), Vector3(0, 0, -1.76), Vector3.ONE, 0.2, 4.0)
            for i in range(4):
                var a := TAU * float(i) / 4.0 + 0.4
                Util.add_mesh(h, Util.cylinder(0.0, 0.03, 0.34), gold, Vector3(cos(a) * 0.15, sin(a) * 0.15, -1.62), Vector3(-90, 0, 0), 0.3)
            _cz(h, 0.07, 0.07, 0.05, gold, -1.5, 0.3)
            _cz(h, 0.05, 0.05, 0.04, gold, -0.3, 0.3)
        "lightning":
            _cz(h, 0.04, 0.045, 1.9, wood, -0.7, 0.8)
            _sp(h, 0.11, Color(0.4, 0.8, 1.0), Vector3(0, 0, -1.74), Vector3(0.9, 0.9, 1.5), 0.3, 3.5)
            _sp(h, 0.06, Color(0.9, 1.0, 1.0), Vector3(0, 0, -1.76), Vector3.ONE, 0.2, 4.0)
            _b(h, Vector3(0.3, 0.04, 0.04), gold, Vector3(0, 0, -1.55))
            _b(h, Vector3(0.04, 0.3, 0.04), gold, Vector3(0, 0, -1.55))
            _cz(h, 0.07, 0.07, 0.05, gold, -1.5, 0.3)
            _cz(h, 0.0, 0.05, 0.3, Color(0.4, 0.8, 1.0), -1.98, 0.3, 2.0)
        "vamp_blade":
            _b(h, Vector3(0.1, 0.04, 1.6), Color(0.75, 0.1, 0.12), Vector3(0, 0, -1.0), Vector3.ZERO, 0.3, 1.5)
            _b(h, Vector3(0.55, 0.07, 0.09), dark, Vector3(0, 0, -0.2))
            _b(h, Vector3(0.07, 0.07, 0.3), dark, Vector3(0, 0, 0.0))
            Util.add_mesh(h, Util.sphere(0.07), Color(0.9, 0.1, 0.15), Vector3(0, 0.06, -0.2), Vector3.ZERO, 0.3, 3.0)
        "elven_bow":
            var leaf := Color(0.75, 0.9, 0.5)
            for i in range(11):
                var t := lerpf(-1.2, 1.2, float(i) / 10.0)
                var thick := lerpf(0.06, 0.035, absf(t) / 1.2)
                _b(h, Vector3(thick, 0.24, thick), leaf, Vector3(0, sin(t) * 0.65, 0.45 - cos(t) * 0.65), Vector3(rad_to_deg(t), 0, 0), 0.4, 1.0)
            _cz(h, 0.04, 0.04, 0.2, Color(0.35, 0.22, 0.12), -0.2, 0.9)
            for sy in [-1.0, 1.0]:
                _sp(h, 0.035, Color(1.0, 0.95, 0.6), Vector3(0, float(sy) * 0.6, 0.2), Vector3(1, 1.6, 1), 0.3, 2.0)
            _b(h, Vector3(0.01, 1.2, 0.01), Color(1, 1, 1), Vector3(0, 0, 0.18))
        "blunderbuss":
            Util.add_mesh(h, Util.cylinder(0.04, 0.12, 0.9), dark, Vector3(0, 0.02, -0.7), Vector3(90, 0, 0), 0.3)
            _b(h, Vector3(0.09, 0.15, 0.6), wood, Vector3(0, -0.02, -0.0))
            _b(h, Vector3(0.1, 0.05, 0.08), gold, Vector3(0, 0.03, -0.3))
        "thunder_hammer":
            _cz(h, 0.04, 0.045, 1.6, wood, -0.65, 0.8)
            _b(h, Vector3(0.9, 0.42, 0.42), Color(0.25, 0.3, 0.45), Vector3(0, 0, -1.5), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.94, 0.12, 0.12), Color(0.4, 0.8, 1.0), Vector3(0, 0, -1.5), Vector3.ZERO, 0.3, 3.0)
            for sx in [-1.0, 1.0]:
                _b(h, Vector3(0.06, 0.5, 0.5), steel, Vector3(float(sx) * 0.46, 0, -1.5), Vector3.ZERO, 0.3)
            _sp(h, 0.08, Color(0.5, 0.9, 1.0), Vector3(0, 0.23, -1.5), Vector3.ONE, 0.3, 3.5)
            _cz(h, 0.06, 0.06, 0.06, gold, -0.7, 0.3)
        "holy_spear":
            _cz(h, 0.035, 0.038, 3.6, Color(0.95, 0.92, 0.8), -1.6, 0.6)
            _cz(h, 0.0, 0.1, 0.6, Color(1.0, 0.9, 0.4), -3.7, 0.3, 2.5)
            for sx in [-1.0, 1.0]:
                _b(h, Vector3(0.1, 0.03, 0.3), gold, Vector3(float(sx) * 0.1, 0, -3.35), Vector3(0, float(sx) * 25.0, 0), 0.3, 1.5)
            _sp(h, 0.06, Color(1.0, 0.95, 0.7), Vector3(0, 0, -3.35), Vector3.ONE, 0.3, 3.0)
        "dragon_staff":
            _cz(h, 0.05, 0.055, 2.1, Color(0.2, 0.05, 0.05), -0.8, 0.7)
            _sp(h, 0.2, Color(1.0, 0.25, 0.05), Vector3(0, 0, -1.98), Vector3(1, 1, 1.15), 0.3, 4.0)
            _sp(h, 0.1, Color(1.0, 0.8, 0.3), Vector3(0, 0, -1.98), Vector3.ONE, 0.3, 4.5)
            for i in range(4):
                var a := TAU * float(i) / 4.0
                Util.add_mesh(h, Util.cylinder(0.0, 0.05, 0.42), gold, Vector3(cos(a) * 0.2, sin(a) * 0.2, -1.8), Vector3(-90, 0, 0), 0.3)
                _cz(h, 0.0, 0.04, 0.16, gold, -2.08, 0.3, 0.0, sin(a) * 0.12, cos(a) * 0.12)
            _cz(h, 0.08, 0.08, 0.06, gold, -1.6, 0.3)
        "storm_staff":
            _cz(h, 0.05, 0.055, 2.1, Color(0.15, 0.1, 0.3), -0.8, 0.7)
            _sp(h, 0.18, Color(0.7, 0.4, 1.0), Vector3(0, 0, -1.98), Vector3(0.8, 1.2, 1.1), 0.25, 4.5)
            _b(h, Vector3(0.44, 0.04, 0.04), Color(0.8, 0.9, 1.0), Vector3(0, 0, -1.8), Vector3.ZERO, 0.3, 2.0)
            _b(h, Vector3(0.04, 0.44, 0.04), Color(0.8, 0.9, 1.0), Vector3(0, 0, -1.8), Vector3.ZERO, 0.3, 2.0)
            _b(h, Vector3(0.04, 0.3, 0.04), Color(0.8, 0.9, 1.0), Vector3(0.0, 0.0, -1.8), Vector3(0, 0, 45), 0.3, 2.0)
            _cz(h, 0.07, 0.07, 0.05, Color(0.6, 0.65, 0.8), -1.55, 0.3)
        "water_element":
            # у руці немає предмета: кулак опутаний живою водою (кульки на орбітах)
            var wh := Node3D.new()
            wh.set_script(load("res://water_hands.gd"))
            h.add_child(wh)
            wh.position = Vector3(0, 0, -0.04)
        "fire_element":
            # у руці немає предмета: кулак палає, злітають жарини
            var fe := Node3D.new()
            fe.set_script(load("res://fire_hands.gd"))
            h.add_child(fe)
            fe.position = Vector3(0, 0, -0.04)
        "fire_scythe":
            # Коса з синім полум'ям: довге древко, на кінці — серповидне лезо (дуга з брусків у площині XZ), вздовж леза горить синій вогонь
            var blue := Color(0.3, 0.75, 1.0)
            var bone := Color(0.12, 0.14, 0.22)
            Util.add_mesh(h, Util.cylinder(0.035, 0.035, 2.6), bone, Vector3(0, 0, -0.95), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.sphere(0.07), blue, Vector3(0, 0, 0.35), Vector3.ZERO, 0.4, 3.0)       # набалдашник
            _b(h, Vector3(0.16, 0.12, 0.2), bone, Vector3(0, 0, -2.2))                                      # втулка леза
            var segs := 9
            var prev := Vector3(0.0, 0.0, -2.2)
            for i in range(1, segs + 1):
                var t := float(i) / float(segs)
                var ang := t * 1.9                                  # дуга закручується в бік і назад
                var pt := Vector3(sin(ang) * 1.25, 0.0, -2.2 + (1.0 - cos(ang)) * 0.45 - t * 0.2)
                var mid := (prev + pt) * 0.5
                var d := pt - prev
                var yaw := rad_to_deg(atan2(d.x, d.z))
                var thick := lerpf(0.2, 0.04, t)                    # лезо звужується до вістря
                _b(h, Vector3(0.05, 0.05, d.length() + 0.04), Color(0.55, 0.85, 1.0), mid, Vector3(0, yaw, 0), 0.2, 4.0)
                _b(h, Vector3(thick, 0.025, d.length() * 0.9), Color(0.2, 0.5, 1.0), mid, Vector3(0, yaw, 0), 0.3, 2.0)
                if i % 3 == 0:
                    var fl := BlueFire.make_flame(6, 0.55, 0.12, 1.1)
                    fl.position = mid + Vector3(0, 0.05, 0)
                    h.add_child(fl)
                    fl.emitting = true
                prev = pt
            var glow := OmniLight3D.new()
            glow.light_color = Color(0.3, 0.65, 1.0)
            glow.light_energy = 0.9
            glow.omni_range = 3.5
            glow.shadow_enabled = false
            glow.position = Vector3(0.6, 0.1, -2.3)
            h.add_child(glow)
        "frost_staff":
            # у руці немає предмета: над кулаком висить холодний туман і кружляють крижинки
            var fh := Node3D.new()
            fh.set_script(load("res://frost_hands.gd"))
            h.add_child(fh)
            fh.position = Vector3(0, 0, -0.04)
        "epicenter_blade":
            _b(h, Vector3(0.18, 0.05, 2.4), Color(0.2, 0.5, 0.15), Vector3(0, 0, -1.5), Vector3.ZERO, 0.3, 1.5)
            _b(h, Vector3(0.08, 0.06, 2.3), Color(0.5, 1.0, 0.3), Vector3(0, 0.03, -1.5), Vector3.ZERO, 0.3, 4.0)
            _b(h, Vector3(0.8, 0.09, 0.12), dark, Vector3(0, 0, -0.3))
            _b(h, Vector3(0.09, 0.09, 0.5), dark, Vector3(0, 0, 0.0))
