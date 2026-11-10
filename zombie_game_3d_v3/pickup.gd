extends Node3D
# Куля лікування: випадає із зомбі, підстрибує, підтягується до героя зблизька й підбирається.

const Util = preload("res://util.gd")

const MAGNET_R := 5.0        # з якої відстані куля починає летіти до героя
const MAGNET_DELAY := 0.5    # поки підскакує, не притягується
const POP_SPEED := 5.5
const GRAVITY := 18.0
const BOUNCE := 0.5

var target
var amount := 15
var life := 25.0
var t := 0.0
var orb: MeshInstance3D
var _vy := POP_SPEED
var _y := 0.0
var _drift := Vector3.ZERO
var _pull := 0.0

func _ready() -> void:
    orb = Util.add_mesh(self, Util.sphere(0.25), Color(0.2, 1.0, 0.4), Vector3(0, 0.7, 0), Vector3.ZERO, 0.3, 3.0)
    var a := randf() * TAU
    _drift = Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, 2.2)

func _physics_process(delta: float) -> void:
    t += delta
    life -= delta
    var settled := false
    if _vy != 0.0 or _y > 0.0:
        _vy -= GRAVITY * delta
        _y += _vy * delta
        if _y <= 0.0:
            _y = 0.0
            _vy = -_vy * BOUNCE
            if _vy < 1.2:
                _vy = 0.0
        position += _drift * delta
        _drift = _drift.move_toward(Vector3.ZERO, 2.5 * delta)
    else:
        settled = true
    var bob := sin(t * 4.0) * 0.12 * (1.0 if settled else 0.0)
    orb.position.y = 0.7 + _y + bob
    if target != null and is_instance_valid(target):
        var off: Vector3 = target.global_position - global_position
        off.y = 0.0
        var d := off.length()
        if d < 1.4:
            target.heal(amount)
            Sfx.play("heal")
            queue_free()
            return
        if t > MAGNET_DELAY and d < MAGNET_R:
            _pull = minf(_pull + 28.0 * delta, 22.0)       # розганяється, тож не відстає від бігу героя
            position += off / d * _pull * delta
        else:
            _pull = 0.0
    if life <= 0.0:
        queue_free()
