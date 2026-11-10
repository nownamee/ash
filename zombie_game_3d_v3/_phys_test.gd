extends Node
const GameState = preload("res://game_state.gd")
const ZombieScript = preload("res://zombie.gd")
const PickupScript = preload("res://pickup.gd")
const ProjectileScript = preload("res://projectile.gd")
class Dummy extends Node3D:
    var dead := false
    var healed := 0
    func take_damage(_a, _b = 0.0) -> void:
        pass
    func heal(a) -> void:
        healed += a
var lvl
var n := 0
var dummy
var zs := {}
var wall
var pk
var pstate := 0
func _ready() -> void:
    GameState.load_game()
    GameState.selected_loc = "loc1"
    lvl = load("res://level.tscn").instantiate()
    add_child(lvl)
func mk(kind: String, pos: Vector3):
    var z = ZombieScript.new()
    z.setup(kind, 1, 1)
    z.target = dummy
    z.position = pos
    z.idle = false
    lvl.world.add_child(z)
    return z
func _physics_process(_d: float) -> void:
    n += 1
    var p = lvl.player
    if n == 5:
        # --- player accel ---
        p.global_position = Vector3(800, 0, 800)
        Input.action_press("move_right")
    if n >= 6 and n <= 16:
        print("ACC f=%d vel=%.2f" % [n - 5, p.velocity.x])
    if n == 17:
        Input.action_release("move_right")
    if n >= 18 and n <= 24:
        print("DEC f=%d vel=%.2f" % [n - 17, p.velocity.x])
    if n == 30:
        # --- knockback setup, far away area ---
        dummy = Dummy.new()
        dummy.position = Vector3(2000, 0, 2000)
        lvl.world.add_child(dummy)
        wall = StaticBody3D.new()
        wall.collision_layer = 4
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(0.5, 3, 40)
        cs.shape = bs
        cs.position.y = 1.5
        wall.add_child(cs)
        wall.position = Vector3(1001.5, 0, 1006)
        lvl.world.add_child(wall)
        zs["walker"] = mk("walker", Vector3(1000, 0, 1000))
        zs["icegiant"] = mk("icegiant", Vector3(1000, 0, 1004))
        zs["swamp_hulk"] = mk("swamp_hulk", Vector3(1000, 0, 1008))
        zs["walker2"] = mk("walker", Vector3(1000, 0, 1012))
        for k in zs:
            zs[k].speed = 0.0
    if n == 40:
        for k in zs:
            zs[k].hp = 1.0e6
            zs[k].max_hp = 1.0e6
            var sx: float = zs[k].global_position.x
            zs[k].set_meta("sx", sx)
            zs[k].take_damage(1.0, Vector3(1, 0, 0), 8.0)
        zs["walker2"].take_damage(1.0, Vector3(1, 0, 0), 30.0)   # hard: should hit wall at x=1005.75
    if n >= 41 and n <= 80 and n % 6 == 0:
        var s := "KB f=%d" % (n - 40)
        for k in zs:
            var z = zs[k]
            s += " %s dx=%.2f kn=%.2f y=%.2f stun=%.2f" % [k, z.global_position.x - float(z.get_meta("sx")), z.knock.length(), z.global_position.y, z.stun_t]
        print(s)
    if n == 100:
        # death fling
        var a = mk("walker", Vector3(1000, 0, 1020))
        var b = mk("swamp_hulk", Vector3(1000, 0, 1024))
        a.speed = 0.0
        b.speed = 0.0
        a.hp = 1.0
        b.hp = 1.0
        a.set_meta("sx", 1000.0)
        b.set_meta("sx", 1000.0)
        zs["da"] = a
        zs["db"] = b
        a.take_damage(5.0, Vector3(1, 0, 0), 14.0)
        b.take_damage(5.0, Vector3(1, 0, 0), 14.0)
    if n >= 101 and n <= 150 and n % 7 == 0:
        var s := "DEATH f=%d" % (n - 100)
        for k in ["da", "db"]:
            var z = zs[k]
            if is_instance_valid(z):
                s += " %s dx=%.2f y=%.2f vel=%.2f" % [k, z.global_position.x - 1000.0, z.global_position.y, z._corpse_vel.length()]
        print(s)
    if n == 160:
        pk = PickupScript.new()
        pk.target = p
        pk.position = p.global_position + Vector3(4.0, 0, 0)
        lvl.world.add_child(pk)
        pstate = n
    if pk != null and is_instance_valid(pk) and n > 160 and n % 6 == 0 and n < 260:
        print("PICKUP f=%d dist=%.2f y=%.2f ppos=%s pk=%s" % [n - 160, pk.global_position.distance_to(p.global_position), pk.orb.position.y, str(p.global_position), str(pk.global_position)])
    if n == 260:
        print("PICKUP freed=%s hp_before..." % str(pk == null or not is_instance_valid(pk)))
        # crowd: 20 walkers packed, measure overlap after 3 s
        for i in range(20):
            var z = mk("walker", Vector3(1000 + randf() * 1.5, 0, 1100 + randf() * 1.5))
            z.speed = 1.0
            z.target = dummy
            zs["c%d" % i] = z
        dummy.position = Vector3(1000, 0, 1130)
        var pr = ProjectileScript.new()
        pr.direction = Vector3(1, 0, 0)
        pr.style = "arrow"
        pr.position = Vector3(900, 1.05, 900)
        pr.speed = 24.0
        lvl.world.add_child(pr)
        zs["proj"] = pr
    if n > 260 and n < 320 and n % 12 == 0 and is_instance_valid(zs["proj"]):
        print("PROJ f=%d y=%.2f pitch=%.2f" % [n - 260, zs["proj"].position.y, zs["proj"].rotation.x])
    if n == 440:
        var mn := 99.0
        var cnt := 0
        for i in range(20):
            for j in range(i + 1, 20):
                var d: float = zs["c%d" % i].global_position.distance_to(zs["c%d" % j].global_position)
                mn = minf(mn, d)
                if d < 0.6:
                    cnt += 1
        print("CROWD min_dist=%.2f overlapping_pairs(<0.6)=%d" % [mn, cnt])
        print("PHYS_DONE")
        get_tree().quit()
