extends Node3D
# Рука, опутана водою: маленька хвиляста «краплина» навколо кулака + кульки води, що кружляють орбітами
# й тонке водяне кільце. Прикріплюється до правої (у руці зі зброєю) і лівої руки героя.
# pulse() — стрибок розміру в момент атаки.

const WaterOrb = preload("res://water_orb.gd")

var _orbs: Array = []
var _phase: Array = []
var _speed: Array = []
var _ring: MeshInstance3D
var _blob: MeshInstance3D
var _t := 0.0
var _kick := 0.0
var radius := 0.2
var count := 5

func _ready() -> void:
    # водяний кокон навколо кулака
    _blob = MeshInstance3D.new()
    var bm := SphereMesh.new()
    bm.radius = 0.13
    bm.height = 0.26
    bm.radial_segments = 20
    bm.rings = 10
    _blob.mesh = bm
    _blob.material_override = WaterOrb.water_material()
    _blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_blob)

    # кульки на орбітах (кожна на своєму нахилі й швидкості)
    for i in range(count):
        var m := MeshInstance3D.new()
        var sm := SphereMesh.new()
        var r := 0.05 + 0.02 * float(i % 3)
        sm.radius = r
        sm.height = r * 2.0
        sm.radial_segments = 12
        sm.rings = 6
        m.mesh = sm
        m.material_override = WaterOrb.water_material()
        m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(m)
        _orbs.append(m)
        _phase.append(TAU * float(i) / float(count))
        _speed.append(3.2 + 0.9 * float(i % 3))

    # кільце води, що обертається
    _ring = MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = radius * 0.9
    tm.outer_radius = radius * 1.0 + 0.02
    tm.rings = 24
    tm.ring_segments = 8
    _ring.mesh = tm
    _ring.material_override = WaterOrb.water_material()
    _ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_ring)

func pulse() -> void:
    _kick = 1.0

func _process(delta: float) -> void:
    _t += delta
    _kick = maxf(0.0, _kick - delta * 7.0)
    var s := 1.0 + 0.5 * _kick
    scale = Vector3.ONE * s
    var bp := 1.0 + 0.07 * sin(_t * 9.0)
    _blob.scale = Vector3(bp, 1.0 / bp, bp)
    for i in range(_orbs.size()):
        var a: float = float(_phase[i]) + _t * float(_speed[i])
        var tilt := float(i) * 0.9
        var r := radius * (1.0 + 0.15 * sin(_t * 4.0 + float(i)))
        var p := Vector3(cos(a) * r, sin(a * 1.0) * r * 0.55, sin(a) * r)
        p = p.rotated(Vector3(1, 0, 0), tilt)
        p = p.rotated(Vector3(0, 1, 0), tilt * 0.7)
        (_orbs[i] as Node3D).position = p
    _ring.rotation = Vector3(_t * 2.1, _t * 1.4, 0.0)
