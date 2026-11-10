extends Node3D
# Куля лікування: випадає із зомбі, підбирається підходом.

const Util = preload("res://util.gd")

var target
var amount := 15
var life := 25.0
var t := 0.0
var orb: MeshInstance3D

func _ready() -> void:
    orb = Util.add_mesh(self, Util.sphere(0.25), Color(0.2, 1.0, 0.4), Vector3(0, 0.7, 0), Vector3.ZERO, 0.3, 3.0)

func _physics_process(delta: float) -> void:
    t += delta
    life -= delta
    orb.position.y = 0.7 + sin(t * 4.0) * 0.12
    if target != null and is_instance_valid(target):
        var d := Vector3(target.global_position.x - global_position.x, 0.0, target.global_position.z - global_position.z).length()
        if d < 1.4:
            target.heal(amount)
            Sfx.play("heal")
            queue_free()
            return
    if life <= 0.0:
        queue_free()
