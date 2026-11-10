extends Node3D
# Снаряд гравця: стріла, болт, ніж, куля, вогняна куля (з вибухом).

const Util = preload("res://util.gd")
const Fx = preload("res://effects.gd")

var direction := Vector3(0, 0, -1)
var damage := 10.0
var speed := 24.0
var life := 1.6
var pierce := 0
var aoe := 0.0
var knock := 6.0
var style := "arrow"
var hit_ids: Array = []
var spin := 0.0
var weapon_id := ""

func _ready() -> void:
    rotation.y = atan2(-direction.x, -direction.z)
    var steel := Color(0.85, 0.87, 0.93)
    match style:
        "arrow":
            Util.add_mesh(self, Util.box(Vector3(0.04, 0.04, 0.9)), Color(0.7, 0.55, 0.3), Vector3.ZERO)
            Util.add_mesh(self, Util.cylinder(0.0, 0.08, 0.25), steel, Vector3(0, 0, -0.55), Vector3(-90, 0, 0), 0.3)
            Util.add_mesh(self, Util.box(Vector3(0.14, 0.02, 0.2)), Color(0.9, 0.9, 0.9), Vector3(0, 0, 0.4))
        "bolt":
            Util.add_mesh(self, Util.box(Vector3(0.06, 0.06, 0.7)), Color(0.3, 0.2, 0.1), Vector3.ZERO)
            Util.add_mesh(self, Util.cylinder(0.0, 0.1, 0.3), steel, Vector3(0, 0, -0.5), Vector3(-90, 0, 0), 0.3)
        "knife":
            Util.add_mesh(self, Util.box(Vector3(0.05, 0.03, 0.4)), steel, Vector3.ZERO, Vector3.ZERO, 0.3)
            spin = 18.0
        "bullet":
            Util.add_mesh(self, Util.sphere(0.1), Color(0.2, 0.2, 0.22), Vector3.ZERO, Vector3.ZERO, 0.3)
            Util.add_mesh(self, Util.box(Vector3(0.05, 0.05, 1.2)), Color(1.0, 0.9, 0.5, 0.5), Vector3(0, 0, 0.7), Vector3.ZERO, 0.5, 2.0)
        "fire":
            Util.add_mesh(self, Util.sphere(0.32), Color(1.0, 0.5, 0.1), Vector3.ZERO, Vector3.ZERO, 0.4, 4.0)
            Util.add_mesh(self, Util.sphere(0.2), Color(1.0, 0.9, 0.4), Vector3.ZERO, Vector3.ZERO, 0.4, 5.0)
            var l := OmniLight3D.new()
            l.light_color = Color(1.0, 0.6, 0.2)
            l.omni_range = 6.0
            l.light_energy = 2.0
            add_child(l)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta
    life -= delta
    if spin > 0.0:
        rotation.z += spin * delta
    for z in get_tree().get_nodes_in_group("zombies"):
        if hit_ids.has(z.get_instance_id()):
            continue
        var d := Vector3(z.global_position.x - global_position.x, 0.0, z.global_position.z - global_position.z).length()
        if d < z.radius + 0.3:
            if aoe > 0.0:
                _explode()
                return
            z.take_damage(damage, direction, knock, false, weapon_id)
            hit_ids.append(z.get_instance_id())
            if pierce <= 0:
                queue_free()
                return
            pierce -= 1
    if life <= 0.0:
        if aoe > 0.0:
            _explode()
        else:
            queue_free()

func _explode() -> void:
    var parent := get_parent()
    Fx.explosion(parent, global_position, aoe, Color(1.0, 0.5, 0.1))
    Sfx.play_at("explosion", global_position, -4.0)
    for z in get_tree().get_nodes_in_group("zombies"):
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        if to.length() <= aoe + z.radius:
            z.take_damage(damage, to, knock, false, weapon_id)
    queue_free()
