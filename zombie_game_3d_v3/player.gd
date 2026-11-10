extends CharacterBody3D
# Гравець у бою. Характеристики беруться з прогресу (game_state.gd): зброя, броня, навики.
# Зброя в бою — тільки з набору (loadout), обраного в меню. Керування: WASD, ЛКМ/Пробіл, 1-5 / Q,E / колесо.

const Weapons = preload("res://weapons.gd")
const WeaponModels = preload("res://weapon_models.gd")
const ProjectileScript = preload("res://projectile.gd")
const GameState = preload("res://game_state.gd")
const Armor = preload("res://armor.gd")
const Util = preload("res://util.gd")
const Fx = preload("res://effects.gd")
const Skills = preload("res://skills.gd")
const HeroScript = preload("res://hero.gd")
const BlueFire = preload("res://blue_fire.gd")

signal stats_changed
signal died
signal hurt

const BASE_SPEED := 7.2
const SWING_TIME := 0.18
const DASH_SPEED := 30.0          # м/с під час ривку (3 м ≈ 0.1 с, 10 м ≈ 0.33 с)
const DASH_HALF_WIDTH := 0.9      # на скільки метрів убік від лінії ривка зачіпаються вороги

var max_hp := 100
var hp := 100
var loadout: Array = []
var current := "knife"
var cooldown := 0.0
var aim := Vector3(0, 0, -1)
var swing_time := 0.0
var swing_arc := 1.4
var swing_kind := "melee"
var invuln := 0.0
var slow_time := 0.0
var dead := false
var camera: Camera3D
var walk_t := 0.0

# стан удару клинком (ніж / кинджал / меч / двуручний меч / списи / булава / молоти, див. Weapons.BLADE)
var blade_active := false
var blade_struck := false      # «жива» фаза вже закінчилась
var blade_sound := false
var blade_cfg: Dictionary = {}
var blade_clock := 0.0
var blade_dur := 0.3
var blade_dir := 1.0           # +1: зліва направо, -1: справа наліво
var blade_flip := 1.0
var blade_dmg := 0.0
var blade_reach := 1.5
var blade_half := 0.7          # половина дуги
var blade_knock := 4.0
var blade_hit: Array = []
var blade_burn := 0.0         # урон горіння за секунду, яким удар підпалює (Вогняна коса)
var blade_wave := 0.0         # урон вогняної хвилі від удару
var blade_wave_r := 0.0       # радіус хвилі, м

# бонуси з навиків і броні
var dmg_mult := 1.0
var cd_mult := 1.0
var crit_chance := 0.05
var defense := 0.0
var speed_mult := 1.0
var regen := 0.0
var regen_acc := 0.0
var heal_acc := 0.0

# блискавичний ривок (навик «dash», права кнопка миші)
var dash_level := 0
var dash_cd := 0.0
var dash_cd_max := 5.0
var dash_active := false
var dash_dir := Vector3(0, 0, -1)
var dash_left := 0.0
var dash_dmg := 0.0
var dash_hit: Array = []
var dash_arc_t := 0.0

# вибуховий стрибок (навик «jump», пробіл)
# Стрибок на дальню відстань: злітає високо (видно з камери), всього ~1.5 с; підйом повільніший, падіння швидке.
const JUMP_RISE := 0.9           # с угору
const JUMP_FALL := 0.6           # с униз (приземляється різко)
const JUMP_HEIGHT := 8.0         # висота героя над землею в найвищій точці, м
var jump_level := 0
var jump_cd := 0.0
var jump_active := false
var jump_clock := 0.0
var jump_dir := Vector3(0, 0, -1)
var jump_speed := 0.0          # горизонтальна швидкість у польоті, м/с
var jump_keep_walls := false   # у замку на старті стіни не пропускають

var visual: Node3D        # модель героя (hero.gd)
var hero
var weapon_holder: Node3D

func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 1
    collision_mask = 4          # перешкоди (дерева, стіни)
    add_to_group("player")

    max_hp = 100 + 15 * GameState.skill_level("vitality")
    hp = max_hp
    dmg_mult = 1.0 + 0.04 * float(GameState.skill_level("power"))
    cd_mult = maxf(0.5, 1.0 - 0.03 * float(GameState.skill_level("haste")))
    crit_chance = 0.05 + 0.02 * float(GameState.skill_level("crit"))
    defense = GameState.armor_defense()
    speed_mult = 1.0 + 0.03 * float(GameState.skill_level("swift")) + GameState.armor_speed()
    regen = 0.3 * float(GameState.skill_level("regen"))
    if GameState.skill_unlocked("dash"):
        dash_level = GameState.skill_level("dash")
    if dash_level > 0:
        dash_cd_max = Skills.dash_cooldown(dash_level)
    if GameState.skill_unlocked("jump"):
        jump_level = GameState.skill_level("jump")
    loadout = GameState.loadout.duplicate()
    if loadout.is_empty():
        loadout = ["knife"]
    current = String(loadout[0])

    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.5
    cap.height = 1.8
    shape.shape = cap
    shape.position.y = 0.9
    add_child(shape)
    _build_model()

func weapon_level(id: String) -> int:
    return int(GameState.weapon_levels.get(id, 0))

func _build_model() -> void:
    # Модель, скелет і анімації героя живуть у hero.gd; броня з прогресу малюється там само.
    hero = HeroScript.new()
    hero.player = self
    add_child(hero)
    visual = hero
    weapon_holder = hero.weapon_holder
    hero.set_weapon(current)

func _build_weapon() -> void:
    hero.set_weapon(current)

# ---------- Зброя ----------
func equip(id: String) -> void:
    if loadout.has(id):
        current = id
        blade_active = false
        _build_weapon()
        Sfx.play("equip")
        stats_changed.emit()

func cycle(step: int) -> void:
    if loadout.size() < 2:
        return
    var i := loadout.find(current)
    i = posmod(i + step, loadout.size())
    equip(String(loadout[i]))

# ---------- Ввід ----------
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var k := int(event.physical_keycode)
        if k >= int(KEY_1) and k <= int(KEY_9):
            var idx := k - int(KEY_1)
            if idx < loadout.size():
                equip(String(loadout[idx]))
    if event.is_action_pressed("weapon_next"):
        cycle(1)
    elif event.is_action_pressed("weapon_prev"):
        cycle(-1)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            cycle(-1)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            cycle(1)

func _update_aim() -> void:
    if camera == null or dash_active:
        return
    # важкий удар: у «живу» фазу герой уже вклався в замах і не довертається
    if blade_active and bool(blade_cfg.get("lock_aim", false)) and blade_clock >= float(blade_cfg["t0"]) * blade_dur:
        return
    var mp := get_viewport().get_mouse_position()
    var ray_from := camera.project_ray_origin(mp)
    var ray_dir := camera.project_ray_normal(mp)
    var hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_from, ray_dir)
    if hit != null:
        var v: Vector3 = hit - global_position
        v.y = 0.0
        if v.length() > 0.2:
            aim = v.normalized()

func _physics_process(delta: float) -> void:
    if dead:
        return
    var spd := BASE_SPEED * speed_mult
    if slow_time > 0.0:
        spd *= 0.55
        slow_time = maxf(0.0, slow_time - delta)
    if blade_active:
        spd *= float(blade_cfg.get("move_mult", 1.0))
    var d2 := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = Vector3(d2.x, 0.0, d2.y) * spd
    if blade_active and not blade_struck and blade_clock >= float(blade_cfg["t0"]) * blade_dur:
        velocity += aim * float(blade_cfg.get("lunge", 0.0))   # випад / крок уперед разом з ударом
    var expected := 0.0
    if dash_active:
        # ривок: швидкість обмежена залишком шляху, щоб не «перестрибнути» кінцеву точку
        velocity = dash_dir * minf(DASH_SPEED, dash_left / maxf(delta, 0.0001))
        expected = velocity.length() * delta
    if jump_active:
        # політ: рух задано заздалегідь, вхід гравця ігнорується
        velocity = jump_dir * jump_speed
    var prev_pos := global_position
    move_and_slide()
    if dash_active:
        _dash_step(prev_pos, expected, delta)

    _update_aim()

    dash_cd = maxf(0.0, dash_cd - delta)
    jump_cd = maxf(0.0, jump_cd - delta)
    if jump_active:
        _jump_update(delta)
    cooldown = maxf(0.0, cooldown - delta)
    swing_time = maxf(0.0, swing_time - delta)
    invuln = maxf(0.0, invuln - delta)
    visual.visible = not (invuln > 0.0 and int(invuln * 20.0) % 2 == 0)

    if regen > 0.0 and hp < max_hp:
        regen_acc += regen * delta
        if regen_acc >= 1.0:
            regen_acc -= 1.0
            heal(1)

    _blade_update(delta)

    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        try_dash()

    if jump_level > 0:
        # із навиком стрибка пробіл стрибає, а атакує лише ЛКМ
        if Input.is_physical_key_pressed(KEY_SPACE):
            try_jump()
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            attack()
    elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("attack"):
        attack()

# ---------- Вибуховий стрибок ----------
# Точка землі під курсором (або null).
func _cursor_ground() -> Variant:
    if camera == null:
        return null
    var mp := get_viewport().get_mouse_position()
    return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(mp), camera.project_ray_normal(mp))

func try_jump() -> void:
    if jump_level <= 0 or jump_active or jump_cd > 0.0 or dead or dash_active:
        return
    _update_aim()
    var dist := Skills.JUMP_DIST
    var hit = _cursor_ground()
    if hit != null:
        var v: Vector3 = hit - global_position
        v.y = 0.0
        dist = clampf(v.length(), Skills.JUMP_DIST_MIN, Skills.JUMP_DIST)
    jump_dir = Vector3(aim.x, 0.0, aim.z).normalized()
    if jump_dir.length() < 0.1:
        jump_dir = Vector3(0, 0, -1)
    jump_speed = dist / (JUMP_RISE + JUMP_FALL)
    jump_active = true
    jump_clock = 0.0
    jump_cd = Skills.JUMP_CD
    blade_active = false                # стрибок перериває замах
    swing_time = 0.0
    # у польоті герой пролітає над деревами й стінами (крім замку на старті, де стіни тримають)
    var lv := get_tree().current_scene
    jump_keep_walls = lv != null and "castle_wait" in lv and bool(lv.castle_wait)
    if not jump_keep_walls:
        collision_mask = 0
    Sfx.play("swing_heavy", -4.0, 0.8)
    Fx.burst(get_parent(), global_position + Vector3(0.0, 0.2, 0.0), Color(0.75, 0.6, 0.4), 16, 4.5, 0.1)
    stats_changed.emit()

func _jump_update(delta: float) -> void:
    jump_clock += delta
    if jump_clock < JUMP_RISE:
        var u := jump_clock / JUMP_RISE
        hero.position.y = JUMP_HEIGHT * (1.0 - (1.0 - u) * (1.0 - u))      # швидкий зліт, біля вершини гальмує
        return
    var w := clampf((jump_clock - JUMP_RISE) / JUMP_FALL, 0.0, 1.0)
    hero.position.y = JUMP_HEIGHT * (1.0 - w * w)                            # падіння прискорюється
    if w >= 1.0:
        jump_active = false
        velocity = Vector3.ZERO
        hero.position.y = 0.0
        _settle_after_jump()
        collision_mask = 4
        _jump_land()

# Якщо приземлилися всередині дерева чи стіни — зсуваємось до найближчого вільного місця.
func _settle_after_jump() -> void:
    if jump_keep_walls:
        return
    var space := get_world_3d().direct_space_state
    var sh := SphereShape3D.new()
    sh.radius = 0.8
    var base := global_position
    for ring in range(0, 6):
        var rad := 1.5 * float(ring)
        var steps := 1 if ring == 0 else 12
        for k in range(steps):
            var ang := TAU * float(k) / float(steps)
            var pos := base + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
            var q := PhysicsShapeQueryParameters3D.new()
            q.shape = sh
            q.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 0.95, pos.z))
            q.collision_mask = 4
            if space.intersect_shape(q, 1).is_empty():
                global_position = Vector3(pos.x, base.y, pos.z)
                return

# Приземлення: міні-вибух навколо героя — урон усім у радіусі, відкидання від центру.
func _jump_land() -> void:
    var radius := Skills.jump_radius(jump_level)
    var dmg := Skills.jump_damage(jump_level)
    var center := global_position
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z) or z.dying:
            continue
        var to: Vector3 = z.global_position - center
        to.y = 0.0
        if to.length() <= radius + z.radius:
            var dir := to
            if dir.length() < 0.05:
                dir = aim
            z.take_damage(dmg, dir, 10.0, false, "")
    hero.play_attack("aoe", TAU, 0.4)
    Sfx.play("explosion")
    Fx.jump_blast(get_parent(), center, radius)
    var lv := get_tree().current_scene
    if lv != null and "shake" in lv:
        lv.shake = 0.45

# ---------- Блискавичний ривок ----------
func try_dash() -> void:
    if dash_level <= 0 or dash_active or dash_cd > 0.0 or dead:
        return
    _update_aim()                       # напрямок — туди, куди зараз націлена миша
    dash_dir = Vector3(aim.x, 0.0, aim.z).normalized()
    if dash_dir.length() < 0.1:
        return
    aim = dash_dir
    dash_active = true
    dash_left = Skills.dash_distance(dash_level)
    dash_dmg = Skills.dash_damage(dash_level)
    dash_hit.clear()
    dash_cd = dash_cd_max
    dash_arc_t = 0.0
    blade_active = false                # ривок перериває замах
    swing_time = 0.0
    Sfx.play("zap", 0.0, 0.8)
    Fx.dash_lightning(get_parent(), global_position, global_position + dash_dir * dash_left)
    stats_changed.emit()

func _dash_step(prev_pos: Vector3, expected: float, delta: float) -> void:
    var cur := global_position
    var seg := cur - prev_pos
    seg.y = 0.0
    var moved := seg.length()
    dash_left -= moved
    # урон усім, кого герой зачепив цим кроком (кожен — один раз за ривок)
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z) or dash_hit.has(z) or z.dying:
            continue
        var zp: Vector3 = z.global_position
        var ab := cur - prev_pos
        ab.y = 0.0
        var t := 0.0
        var ab2 := ab.length_squared()
        if ab2 > 0.000001:
            t = clampf(((zp.x - prev_pos.x) * ab.x + (zp.z - prev_pos.z) * ab.z) / ab2, 0.0, 1.0)
        var closest := prev_pos + ab * t
        var dx := zp.x - closest.x
        var dz := zp.z - closest.z
        if sqrt(dx * dx + dz * dz) <= DASH_HALF_WIDTH + z.radius:
            dash_hit.append(z)
            z.take_damage(dash_dmg, dash_dir, 7.0, false, "")
            Fx.dash_hit(get_parent(), zp + Vector3(0.0, 1.1, 0.0))
    dash_arc_t -= delta
    if dash_arc_t <= 0.0:
        dash_arc_t = 0.03
        Fx.lightning_arc(get_parent(), global_position + Vector3(0.0, 1.0, 0.0))
    # кінець: пройшли всю дистанцію або вперлися в перешкоду
    if dash_left <= 0.02 or moved < expected * 0.3:
        dash_active = false
        velocity = Vector3.ZERO
        Fx.burst(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Color(0.6, 0.85, 1.0), 16, 6.0, 0.08)

# ---------- Атака ----------
func attack() -> void:
    if cooldown > 0.0:
        return
    var id := current
    var w: Dictionary = Weapons.DATA[id]
    var lvl := weapon_level(id)
    var dmg := Weapons.damage(id, lvl) * dmg_mult * Weapons.mastery_mult(GameState.weapon_mastery(id))
    cooldown = Weapons.cooldown(id, lvl) * cd_mult
    match String(w["type"]):
        "melee":
            if Weapons.is_blade(id):
                _blade_start(id, w, lvl, dmg)
            else:
                _melee(id, w, lvl, dmg)
        "aoe":
            if Weapons.is_blade(id):
                _blade_start(id, w, lvl, dmg)
            else:
                _aoe(id, w, lvl, dmg)
        "proj":
            _shoot(id, w, lvl, dmg)
        "chain":
            _chain(id, w, lvl, dmg)
        "water":
            _water(id, w, lvl, dmg)
        "ice":
            _ice(id, w, lvl, dmg)
        "fire":
            _fire(id, w, lvl, dmg)

func _hit(z, dmg: float, knock: float, dir: Vector3, wid: String = "") -> void:
    var wpn := wid if wid != "" else current
    var crit := randf() < crit_chance
    var d := dmg
    if crit:
        d = dmg * 2.0
    z.take_damage(d, dir, knock, crit, wpn)
    var ls := float(Weapons.DATA[wpn].get("lifesteal", 0.0))
    if ls > 0.0:
        heal_acc += d * ls
        if heal_acc >= 1.0:
            var whole := int(heal_acc)
            heal_acc -= float(whole)
            heal(whole)

# Запускає анімацію удару/пострілу на моделі героя.
func _swing(kind: String, arc: float) -> void:
    swing_kind = kind
    swing_arc = arc
    swing_time = SWING_TIME
    hero.play_attack(kind, arc, cooldown * 0.85)

func _melee(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("melee", float(w["arc"]))
    if float(w["cooldown"]) >= 0.8:
        Sfx.play("swing_heavy")
    else:
        Sfx.play("swing")
    var reach := Weapons.range_of(id, lvl)
    for z in get_tree().get_nodes_in_group("attackable"):
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        if to.length() <= reach + z.radius:
            if aim.angle_to(to) <= swing_arc * 0.5:
                _hit(z, dmg, float(w["knock"]), aim)

# ---------- Удари клинком: замах -> «жива» фаза -> повернення ----------
static func _smooth(x: float) -> float:
    var t := clampf(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

func _blade_start(id: String, w: Dictionary, _lvl: int, dmg: float) -> void:
    var cfg: Dictionary = Weapons.BLADE[id]
    blade_cfg = cfg
    blade_active = true
    blade_struck = false
    blade_sound = false
    blade_clock = 0.0
    blade_dur = maxf(0.06, cooldown * 0.92)
    blade_dmg = dmg
    blade_reach = Weapons.range_of(id, weapon_level(id))
    blade_half = float(w["arc"]) * 0.5
    if String(cfg["style"]) == "stab":
        blade_half *= float(cfg.get("cone", 1.0))
    blade_knock = float(w["knock"])
    blade_burn = 0.0
    blade_wave = 0.0
    blade_wave_r = 0.0
    if w.has("burn"):
        var bonus := dmg_mult * Weapons.mastery_mult(GameState.weapon_mastery(id))
        blade_burn = Weapons.burn_dps(id, weapon_level(id)) * bonus
        blade_wave = Weapons.wave_damage(id, weapon_level(id)) * bonus
        blade_wave_r = float(w.get("wave_r", 7.0))
    blade_hit.clear()
    if bool(cfg.get("alternate", false)):
        blade_flip = -blade_flip
        blade_dir = blade_flip
    else:
        blade_dir = 1.0
    swing_kind = "aoe" if String(cfg["style"]) == "slam" else "melee"
    swing_arc = float(w["arc"])
    swing_time = blade_dur
    hero.play_blade(String(cfg["style"]), blade_dir, blade_half, blade_dur, float(cfg["t0"]), float(cfg["t1"]))

func _blade_update(delta: float) -> void:
    if not blade_active:
        return
    blade_clock += delta
    var t0 := float(blade_cfg["t0"]) * blade_dur
    var t1 := float(blade_cfg["t1"]) * blade_dur
    if blade_clock >= t0 and not blade_struck:
        if not blade_sound:
            blade_sound = true
            if String(blade_cfg["style"]) in ["heavy", "bash", "slam"]:
                Sfx.play("swing_heavy")
            else:
                Sfx.play("swing")
            if bool(blade_cfg.get("wave", false)):
                _fire_wave()
        var q := clampf((blade_clock - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
        _blade_sweep(q)
        if blade_clock >= t1:
            blade_struck = true
    if blade_clock >= blade_dur:
        blade_active = false

# q: 0..1 — як далеко клинок пройшов по дузі. Урон отримують усі, кого клинок уже «зачепив» і хто ще не поранений цим ударом.
func _blade_sweep(q: float) -> void:
    if String(blade_cfg["style"]) == "thrust":
        _spear_sweep(q)
        return
    if String(blade_cfg["style"]) in ["bash", "slam"]:
        if q >= 1.0:
            _smash()   # булава / молот б'ють не «по дорозі», а одним ударом у момент влучання
        return
    var lo := -blade_half
    var hi := blade_half
    if String(blade_cfg["style"]) != "stab":
        var s0 := blade_dir * blade_half
        var cur := lerpf(s0, -s0, _smooth(q))
        lo = minf(s0, cur)
        hi = maxf(s0, cur)
    for z in get_tree().get_nodes_in_group("attackable"):
        if blade_hit.has(z) or not is_instance_valid(z):
            continue
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        var dist := to.length()
        if dist > blade_reach + z.radius:
            continue
        var ang := 0.0
        if dist > 0.01:
            ang = aim.signed_angle_to(to, Vector3.UP)
        if ang >= lo and ang <= hi:
            blade_hit.append(z)
            _hit(z, blade_dmg, blade_knock, to)
            if blade_burn > 0.0 and is_instance_valid(z):
                z.ignite(blade_burn, current)     # підпалює саме удар косою (хвиля — ні)

# Вогняна хвиля від коси: біжить по прямій вперед від удару на blade_wave_r метрів (розростаючись вбік), шкодить, але НЕ підпалює.
func _fire_wave() -> void:
    if blade_wave <= 0.0:
        return
    var w := BlueFire.new()
    w.player = self
    w.length = blade_wave_r
    w.dir = Vector3(aim.x, 0.0, aim.z).normalized()
    w.dmg = blade_wave
    w.knock = blade_knock * 0.6
    get_parent().add_child(w)
    w.global_position = global_position + w.dir * 0.8 + Vector3(0.0, 0.05, 0.0)
    Sfx.play("slam", -6.0, 1.5)

# Урон від хвилі: як звичайний удар (крит, вампіризм), але зараховується косі, навіть якщо зброю вже змінили.
func wave_hit(z, dmg: float, knock: float, dir: Vector3) -> void:
    if is_instance_valid(z):
        _hit(z, dmg, knock, dir, BlueFire.WEAPON_ID)

# Влучання булави / молота — один раз, коли головка зброї доходить до цілі.
# Булава: конус перед героєм, ворогів відкидає від героя. Молот: удар у землю, ударна хвиля навколо героя.
func _smash() -> void:
    var slam := String(blade_cfg["style"]) == "slam"
    var head := global_position + aim * minf(blade_reach * 0.6, 2.2) + Vector3(0.0, 0.15, 0.0)
    for z in get_tree().get_nodes_in_group("attackable"):
        if not is_instance_valid(z):
            continue
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        if to.length() > blade_reach + z.radius:
            continue
        if not slam and to.length() > 0.01 and aim.angle_to(to) > blade_half:
            continue
        _hit(z, blade_dmg, blade_knock, to)
    if slam:
        Sfx.play("slam")
        Fx.explosion(get_parent(), global_position + Vector3(0, 0.3, 0), blade_reach, Color(0.9, 0.75, 0.45))
        Fx.burst(get_parent(), head, Color(0.7, 0.6, 0.45), 16, 5.0, 0.1)
    else:
        Sfx.play("slam", -7.0, 1.35)
        Fx.burst(get_parent(), head, Color(0.8, 0.75, 0.65), 10, 3.5, 0.07)

# Випад списом: ураження — вузька «смуга» вздовж прицілу, а не конус. Наконечник рухається вперед
# разом з анімацією (q: 0..1), тож ближніх зачіпає першими, дальніх — коли наконечник до них дотягнеться.
# Проколює всіх на лінії (кожного — один раз за удар), відкидає строго вздовж списа.
func _spear_sweep(q: float) -> void:
    var lane := float(blade_cfg.get("lane", 0.4))
    var tip := lerpf(blade_reach * 0.55, blade_reach, _smooth(q))
    for z in get_tree().get_nodes_in_group("attackable"):
        if blade_hit.has(z) or not is_instance_valid(z):
            continue
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        var along := to.dot(aim)
        if along < -0.1:
            continue
        var side := (to - aim * along).length()
        if side > lane + z.radius:
            continue
        if along - z.radius > tip:
            continue
        blade_hit.append(z)
        _hit(z, blade_dmg, blade_knock, aim)

func _aoe(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("aoe", TAU)
    Sfx.play("slam")
    var reach := Weapons.range_of(id, lvl)
    Fx.explosion(get_parent(), global_position + Vector3(0, 0.3, 0), reach, Color(0.9, 0.75, 0.45))
    for z in get_tree().get_nodes_in_group("attackable"):
        var to: Vector3 = z.global_position - global_position
        to.y = 0.0
        if to.length() <= reach + z.radius:
            _hit(z, dmg, float(w["knock"]), to)

func _shoot(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("ranged", 0.0)
    match String(w["style"]):
        "arrow":
            Sfx.play("bow")
        "bolt":
            Sfx.play("xbow")
        "bullet":
            Sfx.play("gun")
        "fire":
            Sfx.play("fire")
        _:
            Sfx.play("throw")
    var count := int(w.get("count", 1))
    var spread := float(w.get("spread", 0.0))
    for i in range(count):
        var ang := 0.0
        if count > 1:
            ang = lerpf(-spread, spread, float(i) / float(count - 1))
        var p = ProjectileScript.new()
        p.direction = aim.rotated(Vector3.UP, ang)
        p.position = global_position + Vector3(0, 1.05, 0) + p.direction * 0.8
        p.damage = dmg
        p.weapon_id = id
        p.speed = float(w["speed"])
        p.pierce = Weapons.pierce(id, lvl)
        p.aoe = float(w.get("aoe", 0.0)) * (1.0 + 0.04 * float(lvl))
        p.knock = float(w["knock"])
        p.style = String(w["style"])
        get_parent().add_child(p)

# Стихія води: з руки (по черзі лівої й правої) виринає водяна кулька, злітає вгору й пікірує у найближчого ворога перед героєм.
var water_side := 1.0
const WaterOrbScript = preload("res://water_orb.gd")
func _water(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("ranged", 0.0)
    hero.play_attack("cast", 0.0, cooldown * 0.85)
    Sfx.play("water", -2.0, 0.9 + randf() * 0.25)
    water_side = -water_side
    var perp := Vector3(-aim.z, 0.0, aim.x).normalized() * water_side
    var o = WaterOrbScript.new()
    o.aim_dir = aim
    o.side = water_side
    o.position = global_position + Vector3(0.0, 1.0, 0.0) + aim * 0.55 + perp * 0.3
    o.damage = dmg
    o.knock = float(w["knock"])
    o.weapon_id = id
    o.crit_chance = crit_chance
    o.speed = float(w["speed"])
    o.reach = Weapons.range_of(id, lvl)
    o.slow_secs = float(w.get("slow", 1.0))
    o.slow_mult = float(w.get("slow_mult", 0.5))
    o.rise_time = clampf(cooldown * 0.5, 0.09, 0.18)
    get_parent().add_child(o)

# Стихія морозу: над героєм поступово виростає бурулька (вістрям униз), розвертається до прицілу й летить у найближчого ворога.
var ice_slot := 0
const ICE_SLOTS := [-0.9, 0.3, -0.3, 0.9, 0.0, -0.6, 0.6]
const IceShardScript = preload("res://ice_shard.gd")
func _ice(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("ranged", 0.0)
    hero.play_attack("cast", 0.0, cooldown * 0.85)
    Sfx.play("ice", -3.0, 0.9 + randf() * 0.2)
    ice_slot = (ice_slot + 1) % ICE_SLOTS.size()
    var perp := Vector3(-aim.z, 0.0, aim.x).normalized()
    var s = IceShardScript.new()
    s.aim_dir = aim
    s.owner_player = self
    s.hover = Vector3(0.0, 2.6, 0.0) + perp * float(ICE_SLOTS[ice_slot]) + aim * 0.4
    s.damage = dmg
    s.knock = float(w["knock"])
    s.weapon_id = id
    s.crit_chance = crit_chance
    s.speed = float(w["speed"])
    s.reach = Weapons.range_of(id, lvl)
    s.freeze_secs = float(w.get("freeze", 1.0))
    s.freeze_chance = float(w.get("freeze_chance", 1.0))
    s.freeze_chance_boss = float(w.get("freeze_chance_boss", s.freeze_chance))
    s.grow_time = clampf(cooldown * 1.2, 0.25, 0.7)
    s.position = global_position + Vector3(0.0, 2.6, 0.0)
    get_parent().add_child(s)

# Стихія вогню: над героєм виростає вогняна куля діаметром 2 м (~1 с на 1-му рівні), летить у найближчого ворога й вибухає на 6 м навколо.
var fire_slot := 0
const FIRE_SLOTS := [0.0, -1.9, 1.9]
const FireOrbScript = preload("res://fire_orb.gd")
func _fire(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("ranged", 0.0)
    hero.play_attack("cast", 0.0, cooldown * 0.85)
    Sfx.play("fire", -3.0, 0.7 + randf() * 0.15)
    fire_slot = (fire_slot + 1) % FIRE_SLOTS.size()
    var perp := Vector3(-aim.z, 0.0, aim.x).normalized()
    var o = FireOrbScript.new()
    o.aim_dir = aim
    o.owner_player = self
    o.hover = Vector3(0.0, 3.3, 0.0) + perp * float(FIRE_SLOTS[fire_slot]) + aim * 0.4
    o.damage = dmg
    o.knock = float(w["knock"])
    o.weapon_id = id
    o.crit_chance = crit_chance
    o.speed = float(w["speed"])
    o.blast_r = float(w.get("aoe", 6.0))
    o.reach = Weapons.range_of(id, lvl)
    o.grow_time = clampf(cooldown * 0.5, 0.2, 1.0)
    o.position = global_position + Vector3(0.0, 3.3, 0.0)
    get_parent().add_child(o)

func _chain(id: String, w: Dictionary, lvl: int, dmg: float) -> void:
    _swing("ranged", 0.0)
    Sfx.play("zap")
    var reach := Weapons.range_of(id, lvl)
    var origin := global_position + Vector3(0, 1.3, 0)
    var cur := origin
    var hits: Array = []
    var color := Color(0.5, 0.85, 1.0)
    var n := Weapons.chain_count(id, lvl)
    for i in range(n):
        var best = null
        var best_d := 1000000.0
        for z in get_tree().get_nodes_in_group("attackable"):
            if hits.has(z):
                continue
            var to: Vector3 = z.global_position - cur
            to.y = 0.0
            var dist := to.length()
            if i == 0:
                var from_me: Vector3 = z.global_position - global_position
                from_me.y = 0.0
                if dist > reach or aim.angle_to(from_me) > 0.7:
                    continue
            elif dist > 4.5:
                continue
            if dist < best_d:
                best_d = dist
                best = z
        if best == null:
            if i == 0:
                Fx.bolt(get_parent(), origin, origin + aim * reach, color)
            break
        var tpos: Vector3 = best.global_position + Vector3(0, 1.2, 0)
        Fx.bolt(get_parent(), cur, tpos, color)
        Fx.burst(get_parent(), tpos, color, 6, 3.0, 0.08)
        var dir: Vector3 = best.global_position - global_position
        dir.y = 0.0
        _hit(best, dmg * pow(0.85, float(i)), float(w["knock"]), dir)
        hits.append(best)
        cur = tpos

# ---------- Урон / лікування ----------
func take_damage(amount: int, slow_secs: float = 0.0) -> void:
    if dead or invuln > 0.0 or jump_active:     # у польоті (вибуховий стрибок) героя не можна поранити
        return
    var dmg := maxi(1, int(ceil(float(amount) * (1.0 - defense))))
    hp -= dmg
    invuln = 0.4
    if slow_secs > 0.0:
        slow_time = maxf(slow_time, slow_secs)
    Fx.burst(get_parent(), global_position + Vector3(0, 1.1, 0), Color(0.8, 0.1, 0.1), 8, 4.0, 0.08)
    hero.hurt()
    Sfx.play("player_hurt")
    if hp <= 0:
        hp = 0
        dead = true
        visual.visible = true
        hero.die()
        Sfx.play("player_die")
        died.emit()
    hurt.emit()
    stats_changed.emit()

func heal(amount: int) -> void:
    if dead:
        return
    hp = mini(max_hp, hp + amount)
    stats_changed.emit()

# Вбивство зброєю weapon_id: рахуємо для майстерності, на новому рівні — повідомлення над героєм.
func register_weapon_kill(weapon_id: String) -> void:
    if weapon_id == "" or not Weapons.DATA.has(weapon_id):
        return
    var before := GameState.weapon_mastery(weapon_id)
    GameState.weapon_kills[weapon_id] = int(GameState.weapon_kills.get(weapon_id, 0)) + 1
    var after := GameState.weapon_mastery(weapon_id)
    if after > before:
        Fx.damage_text(get_parent(), global_position + Vector3(0, 3.0, 0),
            "%s: майстерність %d!" % [String(Weapons.DATA[weapon_id]["name"]), after], Color(0.55, 1.0, 0.55))
        Sfx.play("buy")
        GameState.save_game()

func on_kill() -> void:
    var v := GameState.skill_level("vampire")
    if v > 0:
        heal(v)
