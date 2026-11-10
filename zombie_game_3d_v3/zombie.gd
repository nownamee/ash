extends CharacterBody3D
# Зомбі. Параметри та вигляд беруться з zombie_types.gd.
# Поведінка (ai): melee — іде й б'є; ranged — тримає дистанцію й стріляє; charger — робить ривки.

const ZombieTypes = preload("res://zombie_types.gd")
const ZombieModels = preload("res://zombie_models.gd")
const EnemyProjectile = preload("res://enemy_projectile.gd")
const Fx = preload("res://effects.gd")
const IceShard = preload("res://ice_shard.gd")
const BlueFire = preload("res://blue_fire.gd")

signal killed(reward: int, pos: Vector3, weapon: String)

var kind := "walker"
var data: Dictionary = {}
var hp := 30.0
var max_hp := 30.0
var speed := 2.2
var damage := 8
var reach := 0.9
var radius := 0.47
var reward := 5
var size := 1.0
var ai := "melee"
var resist := 0.0
var ghost := false
var slow_secs := 0.0
var frozen_t := 0.0         # скільки ще секунд зомбі повністю заморожений (Стихія морозу)
var ice_shell: MeshInstance3D
var slowed_t := 0.0        # скільки ще секунд зомбі сповільнений зброєю гравця
var slowed_mult := 1.0     # множник швидкості під сповільненням
var killer_weapon := ""   # зброя, якою завдано останній удар (для майстерності)
var burning := false       # горить синім вогнем (Вогняна коса): до смерті, щосекунди burn_dps урону
var burn_dps := 0.0
var burn_acc := 0.0        # час до наступного тіку горіння
var burn_weapon := ""
var burn_fx: CPUParticles3D
const BURN_TICK := 1.0     # раз на секунду

var atk_cd := 0.0
var shoot_timer := 1.0
var dash_cd := 2.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var knock := Vector3.ZERO
var stun_t := 0.0          # залишок «оглушення» після сильного удару (рух і атака уповільнені)
var hop_y := 0.0           # підскок від сильного удару / відльоту трупа, м
var hop_vy := 0.0
var _mass := 1.0
var _last_dir := Vector3.ZERO
var _last_impulse := 0.0
var _corpse_vel := Vector3.ZERO
var flash := 0.0
var flashing := false
var dying := false
var walk_t := 0.0
var anim_t := 0.0
var atk_anim := 0.0
var phase := 0.0
var rig: Dictionary = {}
var is_crawler := false
var target
var siege = null          # замок, який штурмуємо (місія оборони). null — звичайна поведінка
var cur_target = null     # кого б'ємо зараз: герой або замок

# Місія зачистки: зомбі стоїть і «спить», доки герой не підійде ближче за aggro_r (5-10 м, у кожного своя)
# або доки його не зачепить удар чи снаряд. Прокинувшись, поводиться як звичайний зомбі.
var idle := false
var aggro_r := 7.5

const SIEGE_AGGRO := 9.0  # якщо герой ближче цього — зомбі б'ється з ним, а не зі стінами
var home_target

# ---- Стрибок жирних зомбі (параметри — zombie_types.gd: JUMP_MEDIUM / JUMP_HUGE) ----
var jump_cfg: Dictionary = {}
var jump_cd := 15.0
var _jump_state := ""          # "" — не стрибає, "wind" — присідає, "air" — у повітрі
var _jump_t := 0.0
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _jump_dur := 1.0           # тривалість польоту цього стрибка
var _jump_h := 3.0             # висота дуги цього стрибка
var _jump_mark: MeshInstance3D = null   # тінь-мітка місця приземлення (для величезних)
var _saved_mask := 7

# ---- Розумний рух: обхід перешкод, вихід із тупиків, розштовхування в натовпі ----
const STEER_LOOK := 3.4        # на скільки метрів уперед зомбі дивиться на перешкоди
const STEER_ANGLES := [0.0, 0.45, 0.9, 1.35, 1.8, 2.4]   # відхилення від прямого шляху (рад.), від малого до великого
const GRID_CELL := 2.0
const KNOCK_FRICTION := 7.0     # експоненційне гальмування відкидання, 1/с
const KNOCK_MIN_DRAG := 2.5     # додаткове лінійне гальмування, м/с²
const KNOCK_BOUNCE := 0.3       # частка швидкості, що повертається від перешкоди
const KNOCK_MAX := 14.0
const HOP_GRAVITY := 26.0
const STUN_THRESHOLD := 6.0     # імпульс відкидання, від якого зомбі спотикається
const CORPSE_FRICTION := 4.5
const COL_R_MAX := 0.8         # колізійний радіус не більший за цей: великі боси теж пролазять між об'єктами
static var _grid: Dictionary = {}
static var _grid_frame := -1
var _col_r := 0.5
var _probe_q: PhysicsShapeQueryParameters3D
var _probe_shape: SphereShape3D
var _steer_ang := 0.0          # поточне відхилення від прямого напрямку на ціль
var _steer_t := 0.0
var _side := 1.0               # з якого боку обходимо перешкоду (щоб не метатися туди-сюди)
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_n := 0              # скільки перевірок поспіль зомбі не просувався
var _detour_t := 0.0           # поки > 0 — іде в обхід уздовж перешкоди
var _sep := Vector3.ZERO
var _frame_n := 0

var visual: Node3D
var parts: Array = []
var _flash_mats: Array = []   # унікальні матеріали моделі (спалах при ударі міняє їх, а не кожну деталь)
var _anim_acc := 0.0
var _anim_tick := 0
var _anim_off := 0
var bar_bg: MeshInstance3D
var bar_fg: MeshInstance3D
var bar_w := 1.0

const BOSS_HP_MULT := 3.0      # у скільки разів більше здоров'я мають усі боси

func _late_hp_scale(tier: int) -> float:
    # Баланс: на перших локаціях (tier 1-4) здоров'я без змін, далі плавно менше,
    # а на останніх (tier 7-10, зокрема Замок епіцентру) — рівно вдвічі менше.
    if tier <= 4:
        return 1.0
    if tier == 5:
        return 0.85
    if tier == 6:
        return 0.7
    return 0.5

func setup(k: String, wave: int, tier: int) -> void:
    # wave — номер хвилі в локації, tier — складність локації (1..10)
    kind = k
    data = ZombieTypes.DATA[k]
    var w := float(wave - 1)
    var t := float(tier - 1)
    size = float(data.get("size", 1.0))
    max_hp = float(data["hp"]) * (1.0 + 0.06 * w) * (1.0 + 0.45 * t) * _late_hp_scale(tier)
    if bool(data.get("boss", false)):
        max_hp *= BOSS_HP_MULT      # здоров'я босів утричі більше
    hp = max_hp
    speed = float(data["speed"]) * (1.0 + 0.012 * w) * (1.0 + 0.02 * t)
    damage = int(float(data["damage"]) * (1.0 + 0.04 * w) * (1.0 + 0.22 * t))
    reach = float(data["reach"]) * size
    radius = float(data["radius"]) * size
    reward = int(float(data["reward"]) * (1.0 + 0.03 * w) * (1.0 + 0.15 * t))
    ai = String(data.get("ai", "melee"))
    resist = float(data.get("knock_resist", 0.0))
    ghost = bool(data.get("ghost", false))
    slow_secs = float(data.get("slow", 0.0))
    shoot_timer = randf_range(0.5, 1.5)
    dash_cd = randf_range(1.0, 3.0)
    jump_cfg = data.get("jump", {})
    if not jump_cfg.is_empty():
        # перший стрибок не одразу і в різний час, щоб жирні не стрибали хором
        jump_cd = randf_range(4.0, float(jump_cfg["cd"]))
    bar_w = maxf(1.0, size * 0.8)
    _mass = pow(maxf(size, 0.6), 1.5) * (1.0 + resist)

func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 2
    if ghost:
        collision_mask = 3      # привид проходить крізь дерева та стіни
    else:
        collision_mask = 7      # гравець + зомбі + перешкоди
    add_to_group("zombies")
    walk_t = randf() * 6.0
    phase = randf() * 6.0
    is_crawler = bool(data["look"].get("crawl", false))

    _col_r = minf(radius, COL_R_MAX)
    var h := maxf(1.8 * size, _col_r * 2.0 + 0.1)
    if is_crawler:
        h = maxf(0.9 * size, _col_r * 2.0 + 0.1)
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = _col_r
    cap.height = h
    shape.shape = cap
    shape.position.y = h * 0.5
    add_child(shape)

    # зонд для огляду перешкод (трохи вужчий за тіло, щоб не «чіплятися» за стіну, вздовж якої йдемо)
    _probe_shape = SphereShape3D.new()
    _probe_shape.radius = _col_r * 0.85
    _probe_q = PhysicsShapeQueryParameters3D.new()
    _probe_q.shape = _probe_shape
    _probe_q.collision_mask = 4
    _stuck_pos = global_position
    if randf() < 0.5:
        _side = -1.0
    _steer_t = randf() * 0.15

    visual = Node3D.new()
    visual.scale = Vector3.ONE * size
    add_child(visual)
    parts = ZombieModels.build(visual, data)
    rig = visual.get_meta("rig", {})
    for pr in parts:
        var pmi: MeshInstance3D = pr[0]
        var pm = pmi.material_override
        if not _flash_mats.has(pm):
            _flash_mats.append(pm)
    _anim_off = randi() % 4
    _build_bar()

func _bar_material(color: Color, prio: int) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.no_depth_test = true
    m.render_priority = prio
    return m

func _build_bar() -> void:
    var y := 2.5 * size
    var q1 := QuadMesh.new()
    q1.size = Vector2(bar_w, 0.14)
    bar_bg = MeshInstance3D.new()
    bar_bg.mesh = q1
    bar_bg.material_override = _bar_material(Color(0, 0, 0, 0.7), 0)
    bar_bg.position = Vector3(0, y, 0)
    bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_bg)

    var q2 := QuadMesh.new()
    q2.size = Vector2(bar_w, 0.1)
    bar_fg = MeshInstance3D.new()
    bar_fg.mesh = q2
    bar_fg.material_override = _bar_material(Color(0.85, 0.1, 0.1, 1.0), 1)
    bar_fg.position = Vector3(0, y, 0)
    bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_fg)
    _update_bar()

func _update_bar() -> void:
    var bar_visible := hp < max_hp
    bar_bg.visible = bar_visible
    bar_fg.visible = bar_visible
    var ratio := clampf(hp / max_hp, 0.0, 1.0)
    var w := maxf(0.001, bar_w * ratio)
    (bar_fg.mesh as QuadMesh).size = Vector2(w, 0.1)
    bar_fg.position.x = -(bar_w - w) * 0.5

func _set_flash(on: bool) -> void:
    flashing = on
    for mat in _flash_mats:
        if on:
            mat.emission_enabled = true
            mat.emission = Color(1.0, 0.35, 0.3)
            mat.emission_energy_multiplier = 1.6
        elif mat.has_meta("em"):
            mat.emission_enabled = true
            mat.emission = Color(0.5, 0.8, 1.0)
            mat.emission_energy_multiplier = 0.5
        else:
            mat.emission_enabled = false

func _physics_process(delta: float) -> void:
    if burning:
        _burn_step(delta)
    if dying:
        _corpse_step(delta)
        return
    if target == null or not is_instance_valid(target):
        return
    _hop_step(delta)
    stun_t = maxf(0.0, stun_t - delta)
    if idle:
        _idle_tick(delta)
        return
    # місія з ескортом: нападаємо на найближчу ціль — героя або лицаря, що йде за ним
    if home_target == null:
        home_target = target
    var kn = get_tree().get_first_node_in_group("knight")
    if kn != null and kn.has_method("is_active") and kn.is_active() and is_instance_valid(home_target):
        var dk := Vector2(kn.global_position.x - global_position.x, kn.global_position.z - global_position.z).length()
        var dp := Vector2(home_target.global_position.x - global_position.x, home_target.global_position.z - global_position.z).length()
        target = kn if dk < dp else home_target
    elif is_instance_valid(home_target):
        target = home_target
    atk_cd = maxf(0.0, atk_cd - delta)
    if flash > 0.0:
        flash = maxf(0.0, flash - delta)
        if flash == 0.0 and flashing:
            _set_flash(false)

    # заморожений повністю: не рухається, не б'є, не стріляє й не відкидається
    if frozen_t > 0.0:
        frozen_t -= delta
        knock = Vector3.ZERO
        velocity = Vector3.ZERO
        hop_y = 0.0
        hop_vy = 0.0
        if frozen_t <= 0.0:
            _thaw()
        return

    cur_target = target
    var tpos: Vector3 = target.global_position
    if siege != null and is_instance_valid(siege) and siege.hp > 0.0:
        var pd: Vector3 = target.global_position - global_position
        pd.y = 0.0
        if pd.length() > SIEGE_AGGRO or target.dead:
            cur_target = siege
            tpos = siege.attack_point(global_position)
    var to: Vector3 = tpos - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := Vector3.ZERO
    if dist > 0.01:
        dir = to / dist
        visual.rotation.y = atan2(-dir.x, -dir.z)

    # стрибок жирного: рідкісний, перезарядка 15 с
    if not jump_cfg.is_empty() and not ghost:
        if _jump_state != "":
            _update_jump(delta)
            return
        jump_cd -= delta
        if jump_cd <= 0.0 and ai == "melee" and dist >= float(jump_cfg["min"]) and dist <= float(jump_cfg["max"]) and knock.length() < 1.0:
            if _begin_jump(dist, dir):
                return
            jump_cd = 0.5      # немає куди приземлитися — спробуємо трохи згодом

    var move_dir := dir
    slowed_t = maxf(0.0, slowed_t - delta)
    var spd := speed * (slowed_mult if slowed_t > 0.0 else 1.0)
    if ai == "ranged":
        var pref := float(data.get("pref_range", 8.0))
        if dist < pref * 0.6:
            move_dir = -dir * 0.8
        elif dist < pref:
            move_dir = Vector3.ZERO
        shoot_timer -= delta
        if shoot_timer <= 0.0 and dist < pref + 4.0:
            shoot_timer = float(data.get("shoot_cd", 2.0))
            _shoot(dir)
    elif ai == "charger":
        dash_cd -= delta
        if dash_t > 0.0:
            dash_t -= delta
            move_dir = dash_dir
            spd = speed * 3.2 * (slowed_mult if slowed_t > 0.0 else 1.0)
        elif dash_cd <= 0.0 and dist < 9.0 and dist > 2.5:
            dash_t = 0.5
            dash_cd = 3.5
            dash_dir = dir

    _frame_n += 1
    if dash_t <= 0.0 and move_dir != Vector3.ZERO and not ghost:
        move_dir = _steer(move_dir, dist, delta)
    else:
        _stuck_t = 0.0
        _stuck_pos = global_position
        _stuck_n = 0
    if dist > reach + 0.4:
        move_dir = _with_separation(move_dir)
    # дивимось туди, куди реально йдемо (в обхід), а не крізь перешкоду на героя
    if ai != "ranged" and dist > reach + 1.0 and move_dir.length_squared() > 0.04:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-move_dir.x, -move_dir.z), minf(1.0, delta * 10.0))

    if stun_t > 0.0:
        spd *= 0.2
    velocity = move_dir * spd + knock
    velocity.y = 0.0
    var kl := knock.length()
    if kl > 0.01:
        kl = maxf(0.0, kl * exp(-KNOCK_FRICTION * delta) - KNOCK_MIN_DRAG * delta)
        knock = knock.normalized() * kl if kl > 0.05 else Vector3.ZERO
    move_and_slide()
    if knock != Vector3.ZERO:
        _knock_bounce()

    var moving := Vector2(velocity.x, velocity.z).length()
    walk_t += delta * moving * 3.0
    # далекі зомбі анімуємо рідше (кожен 2-й / 4-й кадр фізики), близькі — щокадру
    _anim_acc += delta
    _anim_tick += 1
    var pdx: float = target.global_position.x - global_position.x
    var pdz: float = target.global_position.z - global_position.z
    var pd2 := pdx * pdx + pdz * pdz
    var every := 1
    if pd2 > 1024.0:
        every = 4
    elif pd2 > 324.0:
        every = 2
    if (_anim_tick + _anim_off) % every == 0:
        _animate(_anim_acc, moving)
        _anim_acc = 0.0

    if dist <= reach + 0.5 and atk_cd <= 0.0 and stun_t <= 0.0:
        atk_cd = 1.0
        atk_anim = 0.4
        cur_target.take_damage(damage, slow_secs)

# ---------- Сплячий зомбі (місія зачистки) ----------
func _idle_tick(delta: float) -> void:
    var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
    if d <= aggro_r and not bool(target.get("dead")):
        wake()
        return
    # на місці: лише дихання й похитування, і тільки коли герой досить близько, щоб це побачити
    if d < 45.0:
        _anim_acc += delta
        _anim_tick += 1
        if (_anim_tick + _anim_off) % 3 == 0:
            _animate(_anim_acc, 0.0)
            _anim_acc = 0.0

func wake() -> void:
    if not idle:
        return
    idle = false
    if bool(data.get("boss", false)):
        Sfx.play("boss_roar")
    else:
        Sfx.groan_at(global_position)

# ---------- Розумний рух ----------
# Напрям до цілі коригується так, щоб зомбі обходив дерева, стіни й будинки, а не бився в них.
# Раз на 0.12-0.2 с зонд пробує напрямки від прямого до дедалі ширших і береться перший вільний;
# обраний бік запамʼятовується (щоб не метатися). Якщо зомбі майже не просувається, вмикається обхід
# уздовж перешкоди — із чергуванням боків і дедалі довшим, поки не знайдеться вихід.
func _steer(want: Vector3, dist: float, delta: float) -> Vector3:
    var mag := want.length()
    if mag < 0.001:
        return want
    var wd := want / mag
    _stuck_t += delta
    if _stuck_t >= 0.6:
        _check_stuck(dist)
    if _detour_t > 0.0:
        _detour_t -= delta
    _steer_t -= delta
    if _steer_t <= 0.0:
        _steer_t = randf_range(0.12, 0.2)
        if dist > 35.0:
            _steer_t *= 2.5    # далекі зомбі думають рідше (економія FPS)
        _pick_angle(wd, dist)
    if absf(_steer_ang) < 0.001:
        return want
    return wd.rotated(Vector3.UP, _steer_ang) * mag

func _pick_angle(wd: Vector3, dist: float) -> void:
    var look := minf(STEER_LOOK, dist - reach * 0.5)
    if look < 0.9:
        _steer_ang = 0.0     # ціль поруч — просто йдемо до неї (стіна замку тощо)
        return
    var origin := global_position
    var detour := _detour_t > 0.0
    var best_a := 0.0
    var best_f := -1.0
    for ang in STEER_ANGLES:
        var a: float = ang
        if detour and a < 0.8:
            continue          # в обході йдемо вздовж перешкоди, а не в лоб
        var sides := [_side, -_side]
        if a == 0.0:
            sides = [1.0]
        for sg in sides:
            var aa: float = a * float(sg)
            var f := _clear_frac(origin, wd.rotated(Vector3.UP, aa), look)
            if f >= 0.98:
                _steer_ang = aa
                if a > 0.0:
                    _side = signf(aa)
                return
            if f > best_f:
                best_f = f
                best_a = aa
    _steer_ang = best_a      # усюди тісно — найвільніший напрямок

# Яку частку шляху (0..1) можна пройти в напрямку d до зіткнення з перешкодою (шар 4).
func _clear_frac(origin: Vector3, d: Vector3, look: float) -> float:
    _probe_q.transform = Transform3D(Basis.IDENTITY, origin + Vector3(0.0, 0.75, 0.0))
    _probe_q.motion = d * look
    var r := get_world_3d().direct_space_state.cast_motion(_probe_q)
    if r.size() < 1:
        return 1.0
    return r[0]

func _check_stuck(dist: float) -> void:
    var dt := _stuck_t
    var moved := Vector2(global_position.x - _stuck_pos.x, global_position.z - _stuck_pos.z).length()
    _stuck_pos = global_position
    _stuck_t = 0.0
    if dt > 1.5 or dist <= reach + 1.0 or knock.length() > 1.0:
        _stuck_n = 0
        return
    if moved < speed * dt * 0.3:
        _stuck_n += 1
        if _stuck_n % 2 == 0 or (_stuck_n >= 3 and randf() < 0.5):
            _side = -_side    # не вийшло з цього боку — пробуємо з іншого
        _detour_t = minf(1.2 + 0.6 * float(_stuck_n), 4.0)
        _steer_t = 0.0        # одразу перерахувати напрям
    elif moved > speed * dt * 0.6:
        _stuck_n = maxi(0, _stuck_n - 1)

# Зомбі злегка розштовхуються, щоб не збиватися в купу й не блокувати один одного в проходах.
func _with_separation(md: Vector3) -> Vector3:
    if (_frame_n + _anim_off) % 2 == 0:
        _sep = _sep.lerp(_calc_sep(), 0.6)
        if _sep.length_squared() < 0.0004:
            _sep = Vector3.ZERO
    if _sep == Vector3.ZERO:
        return md
    var r := md + _sep * 0.9
    if r.length() > 1.0:
        r = r.normalized()
    return r

func _calc_sep() -> Vector3:
    var f := Engine.get_physics_frames()
    if f != _grid_frame:
        _grid_frame = f
        _grid.clear()
        for zz in get_tree().get_nodes_in_group("zombies"):
            var zp: Vector3 = zz.global_position
            var key := Vector2i(floori(zp.x / GRID_CELL), floori(zp.z / GRID_CELL))
            if not _grid.has(key):
                _grid[key] = []
            _grid[key].append(zz)
    var me := global_position
    var cx := floori(me.x / GRID_CELL)
    var cz := floori(me.z / GRID_CELL)
    var push := Vector3.ZERO
    for dx in range(-1, 2):
        for dz in range(-1, 2):
            var lst = _grid.get(Vector2i(cx + dx, cz + dz))
            if lst == null:
                continue
            for o in lst:
                if o == self or not is_instance_valid(o):
                    continue
                var off: Vector3 = me - o.global_position
                off.y = 0.0
                var d := off.length()
                var rr: float = _col_r + float(o._col_r) + 0.5
                if d > 0.001 and d < rr:
                    var share: float = clampf(2.0 * float(o._mass) / (_mass + float(o._mass)), 0.3, 1.7)
                    push += off / d * (1.0 - d / rr) * share
                elif d <= 0.001:
                    push += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 0.5
    if push.length() > 1.0:
        push = push.normalized()
    return push

# ---------- Стрибок жирного ----------
# Присідає (0.55-0.75 с), стрибає дугою на місце, де стояла ціль на початку стрибка, і при приземленні
# б'є ударною хвилею по всьому, що поруч (герой, лицар, мур замку). У повітрі проходить над деревами й стінами.
func _begin_jump(dist: float, dir: Vector3) -> bool:
    var want := maxf(0.5, dist - reach * 0.6)    # приземляється впритул до цілі
    var f := 1.0
    for i in range(5):
        var cand := global_position + dir * want * f
        cand.y = 0.0
        if _landing_free(cand):
            _jump_from = global_position
            _jump_to = cand
            _jump_state = "wind"
            _jump_t = float(jump_cfg["wind"])
            # далекі стрибки довші й вищі: чим далі ціль, тим вища дуга
            var flat := Vector2(cand.x - global_position.x, cand.z - global_position.z).length()
            _jump_dur = minf(float(jump_cfg["time"]) + float(jump_cfg.get("time_per_m", 0.0)) * flat, float(jump_cfg.get("time_max", 99.0)))
            _jump_h = minf(float(jump_cfg["height"]) + float(jump_cfg.get("height_per_m", 0.0)) * flat, float(jump_cfg.get("height_max", 99.0)))
            if bool(jump_cfg.get("marker", false)):
                _make_jump_mark()
            return true
        f -= 0.15
    return false

func _landing_free(pos: Vector3) -> bool:
    var q := PhysicsShapeQueryParameters3D.new()
    var sh := SphereShape3D.new()
    sh.radius = _col_r + 0.25
    q.shape = sh
    q.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 0.9, pos.z))
    q.collision_mask = 4
    return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _update_jump(delta: float) -> void:
    _animate(delta, 0.0)
    var fd := _jump_to - global_position
    fd.y = 0.0
    if fd.length() > 0.05:
        visual.rotation.y = atan2(-fd.x, -fd.z)
    if _jump_state == "wind":
        var wind := float(jump_cfg["wind"])
        _jump_t -= delta
        var k := 1.0 - clampf(_jump_t / wind, 0.0, 1.0)
        visual.scale = Vector3(1.0 + 0.18 * k, 1.0 - 0.3 * k, 1.0 + 0.18 * k) * size   # присідає перед стрибком
        if _jump_t <= 0.0:
            _jump_state = "air"
            _jump_t = 0.0
            knock = Vector3.ZERO
            _saved_mask = collision_mask
            collision_mask = 0      # у повітрі не чіпляється за перешкоди
            visual.scale = Vector3.ONE * size
        return
    _jump_t += delta
    var u := clampf(_jump_t / _jump_dur, 0.0, 1.0)
    # поки політ не добіг до частки track, точка приземлення слідкує за героєм (потім завмирає — можна відскочити)
    var track := float(jump_cfg.get("track", 0.0))
    if u < track and target != null and is_instance_valid(target):
        var tp: Vector3 = target.global_position
        var dd := Vector3(tp.x - _jump_from.x, 0.0, tp.z - _jump_from.z)
        var dl := dd.length()
        if dl > 0.5:
            var stand := maxf(0.5, dl - reach * 0.6)
            _jump_to = Vector3(_jump_from.x, 0.0, _jump_from.z) + dd / dl * stand
    var p := _jump_from.lerp(_jump_to, u)
    p.y = 4.0 * _jump_h * u * (1.0 - u)
    global_position = p
    # висока дуга: у польоті тіло трохи витягується вгору, а перед приземленням стискається
    if _jump_mark != null:
        _jump_mark.global_position = Vector3(_jump_to.x, 0.06, _jump_to.z)
        var mk := 0.55 + 0.45 * u
        _jump_mark.scale = Vector3(mk, 1.0, mk)
        var mm := _jump_mark.material_override as StandardMaterial3D
        if mm != null:
            mm.albedo_color.a = 0.30 + 0.70 * u
    if u >= 1.0:
        _land()

# Радіус ударної хвилі при приземленні: для величезних — лише навколо тіла (радіус тіла × radius_mult), для решти — з налаштувань.
func _jump_radius() -> float:
    if jump_cfg.has("radius_mult"):
        return maxf(1.0, radius * float(jump_cfg["radius_mult"]))
    return float(jump_cfg["radius"])

# М'яка темна тінь на землі там, куди приземлиться величезний (не червона мітка): росте й темнішає, коли він наближається.
func _make_jump_mark() -> void:
    _free_jump_mark()
    var m := MeshInstance3D.new()
    var quad := PlaneMesh.new()
    var r := _jump_radius()
    quad.size = Vector2(r * 2.3, r * 2.3)
    m.mesh = quad
    var grad := Gradient.new()
    grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    grad.colors = PackedColorArray([Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0)])
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 128
    tex.height = 128
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = tex
    mat.albedo_color = Color(1, 1, 1, 0.3)
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.material_override = mat
    m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    get_parent().add_child(m)
    m.global_position = Vector3(_jump_to.x, 0.06, _jump_to.z)
    _jump_mark = m

func _free_jump_mark() -> void:
    if _jump_mark != null and is_instance_valid(_jump_mark):
        _jump_mark.queue_free()
    _jump_mark = null

func _exit_tree() -> void:
    _free_jump_mark()

func _land() -> void:
    _jump_state = ""
    _free_jump_mark()
    global_position = Vector3(_jump_to.x, 0.0, _jump_to.z)
    collision_mask = _saved_mask
    visual.scale = Vector3.ONE * size
    jump_cd = float(jump_cfg["cd"])
    atk_cd = maxf(atk_cd, 0.6)
    var r := _jump_radius()
    var dmg := int(float(damage) * float(jump_cfg["dmg"]))
    var gp := global_position
    Fx.explosion(get_parent(), gp + Vector3(0, 0.3, 0), r, Color(0.55, 0.47, 0.38))
    Fx.burst(get_parent(), gp + Vector3(0, 0.3, 0), Color(0.45, 0.38, 0.3), 22, 6.0, 0.14)
    Sfx.play_at("slam", gp, 0.0, 0.7)
    # струс камери, якщо герой поблизу
    var lv = get_tree().current_scene
    var pl = get_tree().get_first_node_in_group("player")
    if lv != null and pl != null and "shake" in lv and Vector2(pl.global_position.x - gp.x, pl.global_position.z - gp.z).length() < 25.0:
        lv.shake = maxf(float(lv.shake), 0.35)
    # ударна хвиля: герой / лицар-ескорт (кожен раз), мур замку в місії оборони
    var victims: Array = []
    if target != null and is_instance_valid(target):
        victims.append(target)
    if home_target != null and is_instance_valid(home_target) and home_target != target:
        victims.append(home_target)
    for v in victims:
        var d: Vector3 = v.global_position - gp
        d.y = 0.0
        if d.length() <= r:
            v.take_damage(dmg, slow_secs)
    if siege != null and is_instance_valid(siege) and siege.hp > 0.0:
        var wp: Vector3 = siege.attack_point(gp)
        if Vector2(wp.x - gp.x, wp.z - gp.z).length() <= r:
            siege.take_damage(dmg, 0.0)

# Анімація кінцівок: крок, похитування, випад під час атаки, цокотіння щелепою.
func _animate(delta: float, moving: float) -> void:
    anim_t += delta
    if atk_anim > 0.0:
        atk_anim = maxf(0.0, atk_anim - delta)
    if rig.is_empty():
        return
    var sw := walk_t
    var amp := clampf(moving / 2.2, 0.0, 1.5)
    var lunge := 0.0
    if atk_anim > 0.0:
        lunge = sin((1.0 - atk_anim / 0.4) * PI)
    var idle := sin(anim_t * 1.6 + phase)

    var torso: Node3D = rig["torso"]
    var head: Node3D = rig["head"]
    var jaw: Node3D = rig["jaw"]
    var arm_l: Node3D = rig["arm_l"]
    var arm_r: Node3D = rig["arm_r"]
    var fore_l = rig["fore_l"]
    var fore_r = rig["fore_r"]
    var leg_l: Node3D = rig["leg_l"]
    var leg_r: Node3D = rig["leg_r"]
    var knee_l: Node3D = rig["knee_l"]
    var knee_r: Node3D = rig["knee_r"]

    if is_crawler:
        # повзун: тягнеться руками, нога волочиться
        arm_l.rotation.x = float(rig["arm_base_l"]) + sin(sw) * 0.55 * amp + lunge * 0.5
        arm_r.rotation.x = float(rig["arm_base_r"]) - sin(sw) * 0.55 * amp + lunge * 0.5
        leg_r.rotation.x = float(rig["leg_base_r"]) + sin(sw) * 0.12 * amp
        torso.rotation.x = float(rig["torso_x"]) + sin(sw * 2.0) * 0.04 * amp - lunge * 0.2
        torso.rotation.z = sin(sw) * 0.08 * amp
        visual.position.y = 0.0
    else:
        leg_l.rotation.x = sin(sw) * 0.55 * amp
        leg_r.rotation.x = -sin(sw) * 0.55 * amp
        knee_l.rotation.x = -maxf(0.0, sin(sw + 1.2)) * 0.7 * amp
        knee_r.rotation.x = -maxf(0.0, sin(sw + 1.2 + PI)) * 0.7 * amp
        arm_l.rotation.x = float(rig["arm_base_l"]) + idle * 0.06 + sin(sw) * 0.05 * amp + lunge * 0.7
        arm_r.rotation.x = float(rig["arm_base_r"]) + sin(anim_t * 1.9 + phase + 1.0) * 0.06 + sin(sw + PI) * 0.05 * amp + lunge * 0.7
        torso.rotation.x = float(rig["torso_x"]) + sin(sw * 2.0) * 0.03 * amp - lunge * 0.3 + idle * 0.015
        torso.rotation.z = sin(sw) * 0.07 * amp + idle * 0.02
        visual.position.y = absf(sin(sw)) * 0.04 * size
    if fore_l != null:
        fore_l.rotation.x = float(rig["fore_base_l"]) + sin(anim_t * 2.3 + phase) * 0.08
    if fore_r != null:
        fore_r.rotation.x = float(rig["fore_base_r"]) + sin(anim_t * 2.1 + phase + 2.0) * 0.08
    if rig.has("wmount"):
        var wm: Node3D = rig["wmount"]
        wm.rotation.x = arm_r.rotation.x - float(rig["arm_base_r"])

    head.rotation.z = float(rig["head_z"]) + sin(anim_t * 1.3 + phase) * 0.08 + sin(sw) * 0.05 * amp
    head.rotation.x = float(rig["head_x"]) + sin(anim_t * 0.9 + phase) * 0.05
    jaw.rotation.x = float(rig["jaw_x"]) - lunge * 0.5 + sin(anim_t * 6.0 + phase) * 0.06

    if rig.has("tentacles"):
        for t in rig["tentacles"]:
            var n: Node3D = t[0]
            n.rotation.x = float(t[1]) + sin(anim_t * 2.2 + float(t[3]) * 0.8) * 0.22
            n.rotation.z = float(t[2]) + sin(anim_t * 1.7 + float(t[3]) * 0.6) * 0.18

func _shoot(dir: Vector3) -> void:
    Sfx.play_at("spit", global_position)
    var p = EnemyProjectile.new()
    p.direction = dir
    p.damage = damage
    p.speed = float(data.get("proj_speed", 12.0))
    p.color = data.get("proj_color", Color(1, 0.3, 0.3))
    p.target = cur_target
    p.position = global_position + Vector3(0, 1.3 * size, 0) + dir * 0.8
    get_parent().add_child(p)

# Підпал синім вогнем (Вогняна коса). Горить до смерті; повторний підпал лише підсилює горіння, якщо воно сильніше.
func ignite(dps: float, weapon: String = "fire_scythe") -> void:
    if dying or dps <= 0.0:
        return
    burn_weapon = weapon
    burn_dps = maxf(burn_dps, dps)
    if not burning:
        burning = true
        burn_acc = BURN_TICK
        burn_fx = BlueFire.burn_flame(size)
        add_child(burn_fx)
        Fx.burst(get_parent(), global_position + Vector3(0.0, 1.0 * size, 0.0), Color(0.3, 0.7, 1.0), 10, 3.0, 0.08)

func _burn_step(delta: float) -> void:
    if dying:
        return
    burn_acc -= delta
    if burn_acc > 0.0:
        return
    burn_acc += BURN_TICK
    killer_weapon = burn_weapon
    hp -= burn_dps
    Fx.damage_text(get_parent(), global_position + Vector3(0.0, 2.5 * size, 0.0), str(int(burn_dps)), Color(0.4, 0.8, 1.0))
    Fx.burst(get_parent(), global_position + Vector3(0.0, 1.0 * size, 0.0), Color(0.3, 0.7, 1.0), 4, 2.0, 0.06)
    _update_bar()
    if hp <= 0.0:
        _die()

# Повна заморозка від зброї гравця: навколо зомбі з'являється крижана шкаралупа.
func apply_freeze(secs: float) -> void:
    if dying:
        return
    frozen_t = maxf(frozen_t, secs)
    if ice_shell == null or not is_instance_valid(ice_shell):
        var cm := CapsuleMesh.new()
        cm.radius = 0.62 * size
        cm.height = 2.1 * size
        cm.radial_segments = 8
        cm.rings = 3
        ice_shell = MeshInstance3D.new()
        ice_shell.mesh = cm
        ice_shell.material_override = IceShard.shell_material()
        ice_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ice_shell.position = Vector3(0.0, 1.0 * size, 0.0)
        add_child(ice_shell)
        IceShard.shatter(get_parent(), global_position + Vector3(0.0, 1.0 * size, 0.0), 0.5)

func _thaw() -> void:
    frozen_t = 0.0
    if ice_shell != null and is_instance_valid(ice_shell):
        ice_shell.queue_free()
        IceShard.shatter(get_parent(), global_position + Vector3(0.0, 1.0 * size, 0.0), 1.0)
        Sfx.play_at("freeze", global_position, -8.0, 0.8)
    ice_shell = null

# Сповільнення від зброї гравця (не плутати зі slow_secs — то сповільнення, яке зомбі накладає на героя).
func apply_slow(secs: float, mult: float) -> void:
    if dying:
        return
    var was := slowed_t > 0.0
    slowed_t = maxf(slowed_t, secs)
    slowed_mult = minf(slowed_mult, mult) if was else mult

# Підскок від сильного удару: проста балістика, лише поза стрибком.
func _hop_step(delta: float) -> void:
    if hop_vy == 0.0 and hop_y <= 0.0:
        return
    if _jump_state != "":
        hop_y = 0.0
        hop_vy = 0.0
        return
    hop_vy -= HOP_GRAVITY * delta
    hop_y += hop_vy * delta
    if hop_y <= 0.0:
        hop_y = 0.0
        hop_vy = 0.0
    global_position.y = hop_y

# Відкидання відбивається від перешкод (шар 4), а не тисне в них.
func _knock_bounce() -> void:
    for i in range(get_slide_collision_count()):
        var c := get_slide_collision(i)
        var n := c.get_normal()
        n.y = 0.0
        if n.length_squared() < 0.01:
            continue
        n = n.normalized()
        var vn := knock.dot(n)
        if vn < 0.0 and c.get_collider() is StaticBody3D:
            knock -= (1.0 + KNOCK_BOUNCE) * vn * n

# Політ трупа після смерті: відлітає вздовж удару, гальмується, не проходить крізь перешкоди.
func _corpse_step(delta: float) -> void:
    if _corpse_vel == Vector3.ZERO and hop_y <= 0.0 and hop_vy == 0.0:
        return
    if _corpse_vel != Vector3.ZERO:
        var sp := maxf(0.0, _corpse_vel.length() * exp(-CORPSE_FRICTION * delta) - 1.0 * delta)
        _corpse_vel = _corpse_vel.normalized() * sp if sp > 0.1 else Vector3.ZERO
        velocity = _corpse_vel
        move_and_slide()
        for i in range(get_slide_collision_count()):
            var n := get_slide_collision(i).get_normal()
            n.y = 0.0
            if n.length_squared() > 0.01:
                n = n.normalized()
                var vn := _corpse_vel.dot(n)
                if vn < 0.0:
                    _corpse_vel -= 1.25 * vn * n
    if hop_vy != 0.0 or hop_y > 0.0:
        hop_vy -= HOP_GRAVITY * delta
        hop_y += hop_vy * delta
        if hop_y <= 0.0:
            hop_y = 0.0
            hop_vy = 0.0
            _corpse_vel *= 0.6      # приземлення гасить частину швидкості
        global_position.y = hop_y

func take_damage(amount: float, dir: Vector3, knock_power: float = 8.0, crit: bool = false, weapon: String = "") -> void:
    if dying:
        return
    if idle:
        wake()
    if weapon != "":
        killer_weapon = weapon
    hp -= amount
    flash = 0.1
    _set_flash(true)
    var impulse := knock_power * (1.0 - resist) / sqrt(maxf(size, 0.7))
    var ndir := dir
    ndir.y = 0.0
    ndir = ndir.normalized() if ndir.length() > 0.001 else Vector3.ZERO
    knock += ndir * impulse
    if knock.length() > KNOCK_MAX:
        knock = knock.normalized() * KNOCK_MAX
    _last_dir = ndir
    _last_impulse = impulse
    if impulse >= STUN_THRESHOLD:
        stun_t = maxf(stun_t, minf(0.4, 0.04 * impulse))
        if _jump_state == "" and hop_y <= 0.001:
            hop_vy = minf(5.5, 1.2 + 0.35 * impulse)
    var col := Color(1.0, 0.9, 0.3)
    if crit:
        col = Color(1.0, 0.4, 0.1)
    Fx.damage_text(get_parent(), global_position + Vector3(0, 2.2 * size, 0), str(int(amount)), col)
    Sfx.play_at("hit", global_position)
    if crit:
        Sfx.play_at("crit", global_position)
    Sfx.play_at("zhit", global_position, 0.0, 1.0 / maxf(0.7, size))
    Fx.blood_spray(get_parent(), global_position + Vector3(0, 1.2 * size, 0), dir, 8)
    if randf() < 0.25:
        Fx.blood_splat(get_parent(), global_position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)), randf_range(0.25, 0.5) * size)
    _update_bar()
    if hp <= 0.0:
        _die()

func _die() -> void:
    dying = true
    burning = false
    if burn_fx != null and is_instance_valid(burn_fx):
        burn_fx.queue_free()
    burn_fx = null
    if ice_shell != null and is_instance_valid(ice_shell):
        ice_shell.queue_free()
        IceShard.shatter(get_parent(), global_position + Vector3(0.0, 1.0 * size, 0.0), 1.0)
    ice_shell = null
    if _jump_state != "":     # убили в повітрі — падає на землю
        _jump_state = ""
        _free_jump_mark()
        global_position.y = 0.0
        visual.scale = Vector3.ONE * size
    remove_from_group("zombies")
    collision_layer = 0
    collision_mask = 0 if ghost else 4
    var fling := knock + _last_dir * (2.0 + _last_impulse * 0.5)
    if fling.length() > 10.0:
        fling = fling.normalized() * 10.0
    _corpse_vel = fling
    knock = Vector3.ZERO
    hop_y = 0.0
    hop_vy = clampf(1.5 + _last_impulse * 0.3, 0.0, 4.5) if _last_impulse > 2.0 else 0.0
    bar_bg.visible = false
    bar_fg.visible = false
    var bone := bool(data["look"].get("bare", false))
    var gpos := global_position + Vector3(0, 1.0 * size, 0)
    var ex: Variant = data.get("explode", null)
    var exploded := ex != null
    if exploded:
        var r := float(ex["radius"])
        Fx.explosion(get_parent(), global_position + Vector3(0, 0.5, 0), r, Color(0.7, 0.9, 0.2))
        if target != null and is_instance_valid(target):
            var to: Vector3 = target.global_position - global_position
            to.y = 0.0
            if to.length() <= r:
                target.take_damage(int(ex["damage"]), 0.0)
        if siege != null and is_instance_valid(siege) and siege.hp > 0.0:
            var wp: Vector3 = siege.attack_point(global_position)
            if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() <= r:
                siege.take_damage(int(ex["damage"]), 0.0)
    Fx.burst(get_parent(), gpos, Color(0.5, 0.05, 0.05), 14, 5.0, 0.1)
    Fx.gore(get_parent(), gpos, size, bone)
    if exploded:
        Sfx.play_at("explosion", global_position)
    elif size >= 1.3:
        Sfx.play_at("zdie_big", global_position)
    else:
        Sfx.play_at("zdie", global_position, 0.0, 1.0 / maxf(0.8, size))
    Fx.blood_splat(get_parent(), global_position, 0.9 * size)
    for i in range(2):
        Fx.blood_splat(get_parent(), global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * size, randf_range(0.3, 0.6) * size)
    killed.emit(reward, global_position, killer_weapon)
    if exploded:
        queue_free()
        return
    # труп: падає, лежить, потім провалюється в землю
    add_to_group("corpses")
    var corpses := get_tree().get_nodes_in_group("corpses")
    if corpses.size() > 10:
        corpses[0].queue_free()
    for pr in parts:
        var cmi: MeshInstance3D = pr[0]
        cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var tw := create_tween()
    tw.set_parallel(true)
    var fall_dir := 1.0       # +1: падає назад (навзнак), -1: уперед
    if _last_dir != Vector3.ZERO:
        var fwd := Vector3(-sin(visual.rotation.y), 0.0, -cos(visual.rotation.y))
        fall_dir = 1.0 if fwd.dot(_last_dir) < 0.0 else -1.0
    elif randf() < 0.5:
        fall_dir = -1.0
    if is_crawler:
        tw.tween_property(visual, "position:y", 0.05 * size, 0.2)
    else:
        tw.tween_property(visual, "rotation:x", fall_dir * PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.tween_property(visual, "position:y", 0.16 * size, 0.45)
    tw.chain().tween_interval(7.0)
    tw.chain().tween_property(visual, "position:y", -1.2 * size, 2.0)
    tw.chain().tween_callback(queue_free)
