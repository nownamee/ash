extends Node3D
# Снаряд ворога (стріла мисливця, плювок, магічна куля).

const Util = preload("res://util.gd")

var direction := Vector3(0, 0, -1)
var damage := 8
var speed := 12.0
var color := Color(1, 0.3, 0.3)
var life := 3.0
var target

func _ready() -> void:
    Util.add_mesh(self, Util.sphere(0.2), color, Vector3.ZERO, Vector3.ZERO, 0.3, 3.0)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta
    life -= delta
    if target != null and is_instance_valid(target):
        var tp: Vector3 = target.global_position
        if target.has_method("attack_point"):
            tp = target.attack_point(global_position)   # замок: найближча точка муру
        var d := Vector3(tp.x - global_position.x, 0.0, tp.z - global_position.z).length()
        if d < 0.75:
            target.take_damage(damage, 0.0)
            queue_free()
            return
    if life <= 0.0:
        queue_free()
