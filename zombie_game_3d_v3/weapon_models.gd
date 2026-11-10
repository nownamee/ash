extends RefCounted
# 3D-моделі зброї в руці гравця. Усі "вперед" вздовж -Z.

const Util = preload("res://util.gd")
const IceShard = preload("res://ice_shard.gd")
const BlueFire = preload("res://blue_fire.gd")

static func _b(h: Node3D, size: Vector3, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, rough: float = 0.6, emit: float = 0.0) -> void:
    Util.add_mesh(h, Util.box(size), color, pos, rot, rough, emit)

static func build(h: Node3D, id: String) -> void:
    var steel := Color(0.85, 0.87, 0.93)
    var wood := Color(0.35, 0.22, 0.1)
    var gold := Color(0.75, 0.6, 0.2)
    var dark := Color(0.18, 0.18, 0.2)
    match id:
        "knife":
            _b(h, Vector3(0.05, 0.05, 0.5), steel, Vector3(0, 0, -0.3), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.07, 0.07, 0.16), wood, Vector3(0, 0, 0.02))
        "dagger":
            _b(h, Vector3(0.04, 0.03, 0.42), steel, Vector3(0, 0, -0.28), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.22, 0.04, 0.05), gold, Vector3(0, 0, -0.06))
            _b(h, Vector3(0.06, 0.06, 0.14), dark, Vector3(0, 0, 0.04))
        "sword":
            _b(h, Vector3(0.08, 0.04, 1.5), steel, Vector3(0, 0, -0.95), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.5, 0.06, 0.08), gold, Vector3(0, 0, -0.2))
            _b(h, Vector3(0.07, 0.07, 0.3), wood, Vector3(0, 0, 0.0))
        "spear":
            Util.add_mesh(h, Util.cylinder(0.03, 0.03, 3.1), wood, Vector3(0, 0, -1.3), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.cylinder(0.0, 0.07, 0.5), steel, Vector3(0, 0, -3.1), Vector3(-90, 0, 0), 0.3)
        "axe":
            _b(h, Vector3(0.06, 0.06, 1.3), wood, Vector3(0, 0, -0.55))
            _b(h, Vector3(0.06, 0.5, 0.36), steel, Vector3(0, 0.05, -1.15), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.08, 0.14, 0.16), dark, Vector3(0, 0, -1.0))
        "mace":
            _b(h, Vector3(0.07, 0.07, 1.0), wood, Vector3(0, 0, -0.45))
            Util.add_mesh(h, Util.sphere(0.2), dark, Vector3(0, 0, -1.05), Vector3.ZERO, 0.4)
            for i in range(6):
                var a := TAU * float(i) / 6.0
                _b(h, Vector3(0.07, 0.07, 0.16), steel, Vector3(cos(a) * 0.2, sin(a) * 0.2, -1.05), Vector3(0, 0, rad_to_deg(a)), 0.3)
            _b(h, Vector3(0.07, 0.07, 0.16), steel, Vector3(0, 0, -1.28))
        "greatsword":
            _b(h, Vector3(0.14, 0.04, 2.2), steel, Vector3(0, 0, -1.4), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.7, 0.08, 0.1), gold, Vector3(0, 0, -0.3))
            _b(h, Vector3(0.08, 0.08, 0.5), wood, Vector3(0, 0, 0.0))
            _b(h, Vector3(0.05, 0.05, 1.8), Color(0.6, 0.65, 0.75), Vector3(0, 0.03, -1.4), Vector3.ZERO, 0.3)
        "warhammer":
            _b(h, Vector3(0.07, 0.07, 1.5), wood, Vector3(0, 0, -0.6))
            _b(h, Vector3(0.75, 0.32, 0.32), dark, Vector3(0, 0, -1.4), Vector3.ZERO, 0.4)
            _b(h, Vector3(0.78, 0.1, 0.1), steel, Vector3(0, 0, -1.4), Vector3.ZERO, 0.3)
        "bow":
            for i in range(7):
                var t := lerpf(-1.1, 1.1, float(i) / 6.0)
                var pos := Vector3(0, sin(t) * 0.6, 0.4 - cos(t) * 0.6)
                _b(h, Vector3(0.05, 0.28, 0.05), wood, pos, Vector3(rad_to_deg(t), 0, 0))
            _b(h, Vector3(0.01, 1.06, 0.01), Color(0.9, 0.9, 0.9), Vector3(0, 0, 0.13))
        "throwing":
            _b(h, Vector3(0.04, 0.03, 0.34), steel, Vector3(0, 0, -0.22), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.06, 0.06, 0.12), dark, Vector3(0, 0, 0.0))
            _b(h, Vector3(0.04, 0.03, 0.34), steel, Vector3(0.1, 0.0, -0.18), Vector3(0, -12, 0), 0.3)
        "crossbow":
            _b(h, Vector3(0.1, 0.12, 0.9), wood, Vector3(0, 0, -0.3))
            _b(h, Vector3(1.0, 0.05, 0.07), dark, Vector3(0, 0.04, -0.7))
            _b(h, Vector3(1.0, 0.01, 0.01), Color(0.9, 0.9, 0.9), Vector3(0, 0.04, -0.5))
            _b(h, Vector3(0.04, 0.04, 0.5), steel, Vector3(0, 0.1, -0.5), Vector3.ZERO, 0.3)
        "musket":
            Util.add_mesh(h, Util.cylinder(0.04, 0.04, 1.5), dark, Vector3(0, 0.03, -0.9), Vector3(90, 0, 0), 0.3)
            _b(h, Vector3(0.09, 0.15, 0.7), wood, Vector3(0, -0.02, -0.0))
            _b(h, Vector3(0.1, 0.05, 0.08), gold, Vector3(0, 0.03, -0.4))
        "fire_staff":
            Util.add_mesh(h, Util.cylinder(0.04, 0.04, 1.9), wood, Vector3(0, 0, -0.7), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.sphere(0.15), Color(1.0, 0.5, 0.1), Vector3(0, 0, -1.72), Vector3.ZERO, 0.4, 3.0)
            _b(h, Vector3(0.28, 0.04, 0.04), gold, Vector3(0, 0, -1.55))
        "lightning":
            Util.add_mesh(h, Util.cylinder(0.04, 0.04, 1.9), wood, Vector3(0, 0, -0.7), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.sphere(0.15), Color(0.4, 0.8, 1.0), Vector3(0, 0, -1.72), Vector3.ZERO, 0.4, 3.5)
            _b(h, Vector3(0.28, 0.04, 0.04), gold, Vector3(0, 0, -1.55))
            _b(h, Vector3(0.04, 0.28, 0.04), gold, Vector3(0, 0, -1.55))
        "vamp_blade":
            _b(h, Vector3(0.1, 0.04, 1.6), Color(0.75, 0.1, 0.12), Vector3(0, 0, -1.0), Vector3.ZERO, 0.3, 1.5)
            _b(h, Vector3(0.55, 0.07, 0.09), dark, Vector3(0, 0, -0.2))
            _b(h, Vector3(0.07, 0.07, 0.3), dark, Vector3(0, 0, 0.0))
            Util.add_mesh(h, Util.sphere(0.07), Color(0.9, 0.1, 0.15), Vector3(0, 0.06, -0.2), Vector3.ZERO, 0.3, 3.0)
        "elven_bow":
            var leaf := Color(0.75, 0.9, 0.5)
            for i in range(7):
                var t := lerpf(-1.2, 1.2, float(i) / 6.0)
                var pos := Vector3(0, sin(t) * 0.65, 0.45 - cos(t) * 0.65)
                _b(h, Vector3(0.05, 0.3, 0.05), leaf, pos, Vector3(rad_to_deg(t), 0, 0), 0.4, 1.0)
            _b(h, Vector3(0.01, 1.2, 0.01), Color(1, 1, 1), Vector3(0, 0, 0.18))
        "blunderbuss":
            Util.add_mesh(h, Util.cylinder(0.04, 0.12, 0.9), dark, Vector3(0, 0.02, -0.7), Vector3(90, 0, 0), 0.3)
            _b(h, Vector3(0.09, 0.15, 0.6), wood, Vector3(0, -0.02, -0.0))
            _b(h, Vector3(0.1, 0.05, 0.08), gold, Vector3(0, 0.03, -0.3))
        "thunder_hammer":
            _b(h, Vector3(0.08, 0.08, 1.6), wood, Vector3(0, 0, -0.65))
            _b(h, Vector3(0.9, 0.42, 0.42), Color(0.25, 0.3, 0.45), Vector3(0, 0, -1.5), Vector3.ZERO, 0.3)
            _b(h, Vector3(0.94, 0.12, 0.12), Color(0.4, 0.8, 1.0), Vector3(0, 0, -1.5), Vector3.ZERO, 0.3, 3.0)
        "holy_spear":
            Util.add_mesh(h, Util.cylinder(0.035, 0.035, 3.6), Color(0.95, 0.92, 0.8), Vector3(0, 0, -1.6), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.cylinder(0.0, 0.1, 0.6), Color(1.0, 0.9, 0.4), Vector3(0, 0, -3.7), Vector3(-90, 0, 0), 0.3, 2.5)
        "dragon_staff":
            Util.add_mesh(h, Util.cylinder(0.05, 0.05, 2.1), Color(0.2, 0.05, 0.05), Vector3(0, 0, -0.8), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.sphere(0.22), Color(1.0, 0.25, 0.05), Vector3(0, 0, -1.95), Vector3.ZERO, 0.4, 4.0)
            for i in range(4):
                var a := TAU * float(i) / 4.0
                _b(h, Vector3(0.05, 0.05, 0.3), gold, Vector3(cos(a) * 0.2, sin(a) * 0.2, -1.8))
        "storm_staff":
            Util.add_mesh(h, Util.cylinder(0.05, 0.05, 2.1), Color(0.15, 0.1, 0.3), Vector3(0, 0, -0.8), Vector3(90, 0, 0))
            Util.add_mesh(h, Util.sphere(0.2), Color(0.7, 0.4, 1.0), Vector3(0, 0, -1.95), Vector3.ZERO, 0.4, 4.5)
            _b(h, Vector3(0.4, 0.04, 0.04), Color(0.8, 0.9, 1.0), Vector3(0, 0, -1.8), Vector3.ZERO, 0.3, 2.0)
            _b(h, Vector3(0.04, 0.4, 0.04), Color(0.8, 0.9, 1.0), Vector3(0, 0, -1.8), Vector3.ZERO, 0.3, 2.0)
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
