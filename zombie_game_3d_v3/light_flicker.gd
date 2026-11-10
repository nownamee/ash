extends OmniLight3D
# Миготливе світло: вогонь, ліхтар гравця. Параметри задайте до add_child().

var base_energy := 1.5
var speed := 9.0
var amount := 0.3
var t := 0.0

func _ready() -> void:
    t = randf() * 100.0
    base_energy = light_energy

func _process(delta: float) -> void:
    t += delta * speed
    var n := sin(t) * 0.5 + sin(t * 2.3 + 1.7) * 0.3 + sin(t * 5.1) * 0.2
    light_energy = base_energy * (1.0 + n * amount)
