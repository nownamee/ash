extends Node3D
# Головний герой — «виживальник» (куртка, рюкзак зі спальником, пов'язка, рукавиці, чоботи).
# Модель зібрана як справжній скелет із вузлів: таз, хребет, голова, руки, ноги.
# Ноги й руки працюють на двокістковій IK: ступні ставляться на землю кроком, руки тягнуться до зброї.
#
# Анімації:
#   - спокій: дихання, легке погойдування зброї;
#   - біг у БУДЬ-ЯКОМУ напрямку відносно прицілу (вперед / боком / назад) з нахилом, скрученням корпусу, підскоком таза;
#   - удар по дузі, випад списом, удар зверху (молот), постріл із віддачею (друга рука підтримує зброю);
#   - рух від поранення, падіння при смерті, кроки зі звуком.
# Керує героєм player.gd: задає player, викликає set_weapon / play_attack / hurt / die.

const Util = preload("res://util.gd")
const Armor = preload("res://armor.gd")
const GameState = preload("res://game_state.gd")
const Weapons = preload("res://weapons.gd")
const WeaponModels = preload("res://weapon_models.gd")
const MagmaMaterial = preload("res://magma_material.gd")

const HIP_Y := 0.93
const THIGH := 0.48
const SHIN := 0.48
const ANKLE_H := 0.10
const UPPER_ARM := 0.30
const FOREARM := 0.30
const SHOULDER := Vector3(0.31, 0.50, 0.0)
const HOLD := Vector3(0.30, 0.20, -0.36)
const LEFT_IDLE := Vector3(-0.27, 0.14, -0.20)
const LEFT_SUPPORT := Vector3(-0.14, 0.26, -0.52)
const STRIDE := 0.46
const FOOT_LIFT := 0.24

var player
var weapon_holder: Node3D
var water_l: Node3D          # водяна оболонка на лівій руці («Стихія води»)
var hips: Node3D
var spine: Node3D
var head: Node3D
var legs_root: Node3D
var arm_r_up: Node3D
var arm_r_lo: Node3D
var arm_l_up: Node3D
var arm_l_lo: Node3D
var leg_l_up: Node3D
var leg_l_lo: Node3D
var leg_r_up: Node3D
var leg_r_lo: Node3D
var foot_l: Node3D
var foot_r: Node3D

var phase := 0.0
var time := 0.0
var move_blend := 0.0
var leg_yaw := 0.0
var support := 0.0
var flinch := 0.0
var dead := false
var last_step := 0
var weapon_id := "knife"
var weapon_type := "melee"

# атака
var atk_clock := 99.0
var atk_dur := 0.3
var atk_kind := "melee"
var atk_arc := 1.4
var v_twist := 0.0
var v_lean := 0.0
var v_hold := Vector3.ZERO
var v_rot := Vector3.ZERO

# удар клинком (ніж / кинджал / меч / двуручний меч / спис)
var b_style := "slash"
var b_dir := 1.0
var b_half := 0.7
var b_t0 := 0.2
var b_t1 := 0.6

func _ready() -> void:
    _build()

# ================= Побудова моделі =================
func _ball(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 20
    s.rings = 10
    return s

func _cyl(top: float, bot: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = top
    c.bottom_radius = bot
    c.height = h
    c.radial_segments = 16
    c.rings = 1
    return c

# Кінцівка-сегмент: вузол-шарнір угорі, меш звисає вздовж -Y.
func _limb(parent: Node3D, length: float, r_top: float, r_bot: float, color: Color) -> Node3D:
    var pivot := Node3D.new()
    parent.add_child(pivot)
    Util.add_mesh(pivot, _cyl(r_top, r_bot, length), color, Vector3(0, -length * 0.5, 0), Vector3.ZERO, 0.9)
    Util.add_mesh(pivot, _ball(r_top * 1.05), color, Vector3.ZERO, Vector3.ZERO, 0.9)
    return pivot

func _build() -> void:
    var skin := Color(0.90, 0.73, 0.58)
    var jacket := Color(0.23, 0.27, 0.21)
    var jacket_dark := Color(0.16, 0.19, 0.15)
    var pants := Color(0.17, 0.18, 0.22)
    var boot := Color(0.11, 0.09, 0.08)
    var glove := Color(0.10, 0.10, 0.11)
    var hair := Color(0.17, 0.10, 0.06)
    var red := Color(0.62, 0.10, 0.10)
    var belt := Color(0.30, 0.19, 0.10)
    var pack := Color(0.32, 0.28, 0.18)
    var pack_dark := Color(0.20, 0.17, 0.11)
    var gold := Color(0.75, 0.6, 0.2)

    var head_t := GameState.armor_best("head")
    var body_t := GameState.armor_best("body")
    var boots_t := GameState.armor_best("boots")

    # --- таз ---
    hips = Node3D.new()
    add_child(hips)
    Util.add_mesh(hips, Util.box(Vector3(0.40, 0.22, 0.26)), pants, Vector3.ZERO, Vector3.ZERO, 0.9)
    Util.add_mesh(hips, Util.box(Vector3(0.42, 0.06, 0.28)), belt, Vector3(0, 0.10, 0), Vector3.ZERO, 0.7)
    Util.add_mesh(hips, Util.box(Vector3(0.07, 0.06, 0.02)), gold, Vector3(0, 0.10, -0.15), Vector3.ZERO, 0.3)
    Util.add_mesh(hips, Util.box(Vector3(0.07, 0.13, 0.13)), belt, Vector3(-0.23, 0.0, 0.02), Vector3.ZERO, 0.7)
    Util.add_mesh(hips, Util.box(Vector3(0.07, 0.13, 0.13)), belt, Vector3(0.23, 0.0, 0.02), Vector3.ZERO, 0.7)

    # --- хребет / тулуб (обертається навколо талії) ---
    spine = Node3D.new()
    add_child(spine)
    Util.add_mesh(spine, Util.box(Vector3(0.36, 0.22, 0.24)), jacket_dark, Vector3(0, 0.13, 0), Vector3.ZERO, 0.9)
    Util.add_mesh(spine, Util.box(Vector3(0.50, 0.34, 0.28)), jacket, Vector3(0, 0.40, 0), Vector3.ZERO, 0.9)
    Util.add_mesh(spine, Util.capsule(0.15, 0.58), jacket, Vector3(0, 0.53, 0), Vector3(0, 0, 90), 0.9)
    Util.add_mesh(spine, _cyl(0.10, 0.12, 0.08), red, Vector3(0, 0.62, 0), Vector3.ZERO, 0.8)
    Util.add_mesh(spine, _cyl(0.055, 0.065, 0.10), skin, Vector3(0, 0.66, 0), Vector3.ZERO, 0.8)
    # нагрудні кишені й ремені
    Util.add_mesh(spine, Util.box(Vector3(0.10, 0.12, 0.05)), belt, Vector3(-0.12, 0.30, -0.16), Vector3.ZERO, 0.7)
    Util.add_mesh(spine, Util.box(Vector3(0.10, 0.12, 0.05)), belt, Vector3(0.12, 0.30, -0.16), Vector3.ZERO, 0.7)
    Util.add_mesh(spine, Util.box(Vector3(0.05, 0.36, 0.03)), pack_dark, Vector3(-0.17, 0.42, -0.15), Vector3.ZERO, 0.8)
    Util.add_mesh(spine, Util.box(Vector3(0.05, 0.36, 0.03)), pack_dark, Vector3(0.17, 0.42, -0.15), Vector3.ZERO, 0.8)
    # рюкзак зі спальником
    Util.add_mesh(spine, Util.box(Vector3(0.34, 0.40, 0.16)), pack, Vector3(0, 0.36, 0.22), Vector3.ZERO, 0.9)
    Util.add_mesh(spine, Util.box(Vector3(0.26, 0.14, 0.06)), pack_dark, Vector3(0, 0.30, 0.32), Vector3.ZERO, 0.9)
    Util.add_mesh(spine, _cyl(0.07, 0.07, 0.38), pack_dark, Vector3(0, 0.60, 0.24), Vector3(0, 0, 90), 0.9)
    if body_t > 0:
        var bc: Color = Armor.PLATE_COLORS[body_t]
        _magmify(Util.add_mesh(spine, Util.box(Vector3(0.54, 0.40, 0.06)), bc, Vector3(0, 0.40, -0.17), Vector3.ZERO, 0.35), body_t, 1.0)
        _magmify(Util.add_mesh(spine, Util.box(Vector3(0.40, 0.14, 0.06)), bc, Vector3(0, 0.16, -0.14), Vector3.ZERO, 0.35), body_t, 2.0)
        var pl := Util.add_mesh(spine, _ball(0.14), bc, Vector3(-0.35, 0.57, 0), Vector3.ZERO, 0.35)
        pl.scale = Vector3(1.0, 0.75, 1.1)
        _magmify(pl, body_t, 3.0)
        var pr := Util.add_mesh(spine, _ball(0.14), bc, Vector3(0.35, 0.57, 0), Vector3.ZERO, 0.35)
        pr.scale = Vector3(1.0, 0.75, 1.1)
        _magmify(pr, body_t, 4.0)
        if body_t >= 5:
            # броня професійного лицаря: горжет, ребро жорсткості, пояс і кант на наплічниках
            var trim := Color(0.86, 0.68, 0.22) if body_t >= 6 else Color(0.82, 0.86, 0.92)
            if body_t >= 11:
                trim = Color(1.0, 0.52, 0.10)      # розжарена магма
            elif body_t >= 9:
                trim = Color(0.55, 0.95, 1.0)      # примарне сяйво
            elif body_t >= 7:
                trim = Color(0.98, 0.62, 0.14)      # «Броня мегаполіса»: бурштинові смуги
            _magmify(Util.add_mesh(spine, _cyl(0.13, 0.15, 0.07), bc, Vector3(0, 0.66, 0), Vector3.ZERO, 0.3), body_t, 5.0)
            Util.add_mesh(spine, Util.box(Vector3(0.06, 0.38, 0.05)), trim, Vector3(0, 0.40, -0.205), Vector3.ZERO, 0.25)
            Util.add_mesh(spine, Util.box(Vector3(0.44, 0.04, 0.07)), trim, Vector3(0, 0.24, -0.17), Vector3.ZERO, 0.25)
            Util.add_mesh(spine, _ball(0.075), trim, Vector3(-0.35, 0.65, 0), Vector3.ZERO, 0.25)
            Util.add_mesh(spine, _ball(0.075), trim, Vector3(0.35, 0.65, 0), Vector3.ZERO, 0.25)
            if body_t == 6:
                # малиновий налатник із золотим хрестом
                Util.add_mesh(spine, Util.box(Vector3(0.20, 0.30, 0.02)), Color(0.55, 0.06, 0.09), Vector3(0, 0.14, -0.19), Vector3.ZERO, 0.85)
                Util.add_mesh(spine, Util.box(Vector3(0.03, 0.22, 0.022)), trim, Vector3(0, 0.15, -0.20), Vector3.ZERO, 0.25)
                Util.add_mesh(spine, Util.box(Vector3(0.12, 0.03, 0.022)), trim, Vector3(0, 0.19, -0.20), Vector3.ZERO, 0.25)
            if body_t == 7 or body_t == 8:
                # «Броня мегаполіса»: хрестові ремені, бурштиновий ліхтарик на грудях; на 8-му ще шипи на наплічниках
                for ry in [-28.0, 28.0]:
                    Util.add_mesh(spine, Util.box(Vector3(0.05, 0.46, 0.02)), Color(0.12, 0.13, 0.12), Vector3(0, 0.38, -0.21), Vector3(0, 0, ry), 0.8)
                Util.add_mesh(spine, _ball(0.04), trim, Vector3(0, 0.46, -0.225), Vector3.ZERO, 0.2, 2.5)
                if body_t == 8:
                    for sx2: float in [-0.35, 0.35]:
                        Util.add_mesh(spine, _cyl(0.0, 0.04, 0.14), trim, Vector3(sx2, 0.74, 0), Vector3.ZERO, 0.3)
            if body_t == 9 or body_t == 10:
                # «Саван Привида»: світна душа в грудях, рвані смуги савана, блукаючі вогники над плечима
                var glow := Color(0.55, 0.95, 1.0)
                Util.add_mesh(spine, _ball(0.06), glow, Vector3(0, 0.40, -0.215), Vector3.ZERO, 0.2, 2.5)
                for sx: float in [-0.14, -0.05, 0.05, 0.14]:
                    var strip := Util.add_mesh(spine, Util.box(Vector3(0.07, 0.26, 0.015)), Color(0.78, 0.92, 1.0, 0.55), Vector3(sx, 0.05, -0.19), Vector3(0, 0, sx * 40.0), 0.9)
                    strip.scale = Vector3(1.0, 1.0 + absf(sx) * 2.0, 1.0)
                if body_t >= 10:
                    Util.add_mesh(spine, _ball(0.04), glow, Vector3(-0.35, 0.80, 0), Vector3.ZERO, 0.2, 3.0)
                    Util.add_mesh(spine, _ball(0.04), glow, Vector3(0.35, 0.80, 0), Vector3.ZERO, 0.2, 3.0)
                    Util.add_mesh(spine, Util.box(Vector3(0.40, 0.03, 0.05)), glow, Vector3(0, 0.50, -0.20), Vector3.ZERO, 0.2, 1.8)
            if body_t >= 11:
                _magma_body(body_t)

    # --- голова ---
    head = Node3D.new()
    spine.add_child(head)
    head.position = Vector3(0, 0.78, 0)
    var skull := Util.add_mesh(head, _ball(0.17), skin, Vector3.ZERO, Vector3.ZERO, 0.8)
    skull.scale = Vector3(1.0, 1.1, 1.0)
    Util.add_mesh(head, _ball(0.022), Color(0.06, 0.05, 0.05), Vector3(-0.062, 0.0, -0.152), Vector3.ZERO, 0.3)
    Util.add_mesh(head, _ball(0.022), Color(0.06, 0.05, 0.05), Vector3(0.062, 0.0, -0.152), Vector3.ZERO, 0.3)
    Util.add_mesh(head, Util.box(Vector3(0.03, 0.05, 0.04)), Color(0.82, 0.64, 0.5), Vector3(0, -0.03, -0.17), Vector3.ZERO, 0.8)
    var hr := Util.add_mesh(head, _ball(0.185), hair, Vector3(0, 0.05, 0.03), Vector3.ZERO, 0.9)
    hr.scale = Vector3(1.0, 0.8, 1.05)
    Util.add_mesh(head, _cyl(0.19, 0.19, 0.04), red, Vector3(0, 0.07, 0.0), Vector3.ZERO, 0.8)
    Util.add_mesh(head, Util.box(Vector3(0.05, 0.03, 0.10)), red, Vector3(0.04, 0.05, 0.22), Vector3(0, 20, 0), 0.8)
    Util.add_mesh(head, Util.box(Vector3(0.05, 0.03, 0.10)), red, Vector3(-0.04, 0.03, 0.22), Vector3(0, -20, 0), 0.8)
    if head_t > 0:
        var hc: Color = Armor.PLATE_COLORS[head_t]
        var helm := Util.add_mesh(head, _ball(0.215), hc, Vector3(0, 0.06, 0.01), Vector3.ZERO, 0.35)
        helm.scale = Vector3(1.0, 0.82, 1.0)
        _magmify(helm, head_t, 6.0)
        _magmify(Util.add_mesh(head, Util.box(Vector3(0.05, 0.15, 0.04)), hc, Vector3(0, -0.01, -0.20), Vector3.ZERO, 0.35), head_t, 7.0)
        if head_t >= 3:
            _magmify(Util.add_mesh(head, Util.box(Vector3(0.04, 0.10, 0.30)), hc, Vector3(0, 0.22, 0.0), Vector3.ZERO, 0.35), head_t, 8.0)
        if head_t >= 5:
            # шолом професійного лицаря: щілина забрала, нащічники, обідок; на 6-му — золото й малиновий султан
            var htrim := Color(0.86, 0.68, 0.22) if head_t >= 6 else Color(0.82, 0.86, 0.92)
            if head_t >= 11:
                htrim = Color(1.0, 0.52, 0.10)
            elif head_t >= 9:
                htrim = Color(0.55, 0.95, 1.0)
            elif head_t >= 7:
                htrim = Color(0.98, 0.62, 0.14)
            Util.add_mesh(head, Util.box(Vector3(0.22, 0.035, 0.05)), Color(0.02, 0.02, 0.03), Vector3(0, 0.03, -0.205), Vector3.ZERO, 0.4)
            _magmify(Util.add_mesh(head, Util.box(Vector3(0.035, 0.15, 0.13)), hc, Vector3(-0.195, -0.04, -0.05), Vector3.ZERO, 0.35), head_t, 9.0)
            _magmify(Util.add_mesh(head, Util.box(Vector3(0.035, 0.15, 0.13)), hc, Vector3(0.195, -0.04, -0.05), Vector3.ZERO, 0.35), head_t, 10.0)
            Util.add_mesh(head, _cyl(0.205, 0.205, 0.03), htrim, Vector3(0, 0.12, 0.01), Vector3.ZERO, 0.25)
            if head_t == 6:
                Util.add_mesh(head, Util.box(Vector3(0.05, 0.14, 0.30)), Color(0.62, 0.07, 0.10), Vector3(0, 0.33, 0.02), Vector3(-12, 0, 0), 0.85)
            if head_t == 7 or head_t == 8:
                # «Броня мегаполіса»: світла бурштинова смуга забрала; на 8-му ще гребінь
                Util.add_mesh(head, Util.box(Vector3(0.20, 0.025, 0.03)), htrim, Vector3(0, 0.03, -0.215), Vector3.ZERO, 0.2, 2.5)
                if head_t == 8:
                    Util.add_mesh(head, Util.box(Vector3(0.05, 0.08, 0.34)), htrim, Vector3(0, 0.30, 0.0), Vector3.ZERO, 0.4)
            if head_t == 9 or head_t == 10:
                # світні очі в прорізі забрала; на 8-му ще й примарні роги та хвіст-серпанок
                var eye := Color(0.55, 0.95, 1.0)
                Util.add_mesh(head, Util.box(Vector3(0.05, 0.03, 0.03)), eye, Vector3(-0.06, 0.03, -0.215), Vector3.ZERO, 0.2, 3.0)
                Util.add_mesh(head, Util.box(Vector3(0.05, 0.03, 0.03)), eye, Vector3(0.06, 0.03, -0.215), Vector3.ZERO, 0.2, 3.0)
                if head_t >= 10:
                    Util.add_mesh(head, Util.box(Vector3(0.04, 0.22, 0.04)), Color(0.72, 0.92, 1.0, 0.6), Vector3(-0.15, 0.24, 0.0), Vector3(0, 0, 28), 0.5, 0.8)
                    Util.add_mesh(head, Util.box(Vector3(0.04, 0.22, 0.04)), Color(0.72, 0.92, 1.0, 0.6), Vector3(0.15, 0.24, 0.0), Vector3(0, 0, -28), 0.5, 0.8)
                    Util.add_mesh(head, Util.box(Vector3(0.10, 0.04, 0.26)), Color(0.72, 0.92, 1.0, 0.45), Vector3(0, 0.12, 0.24), Vector3(-18, 0, 0), 0.9)
            if head_t >= 11:
                _magma_head(head_t)

    # --- руки ---
    arm_r_up = _limb(spine, UPPER_ARM, 0.068, 0.056, jacket)
    arm_r_lo = _limb(spine, FOREARM, 0.056, 0.048, jacket_dark)
    Util.add_mesh(arm_r_lo, _ball(0.06), glove, Vector3(0, -FOREARM, 0), Vector3.ZERO, 0.8)
    arm_l_up = _limb(spine, UPPER_ARM, 0.068, 0.056, jacket)
    arm_l_lo = _limb(spine, FOREARM, 0.056, 0.048, jacket_dark)
    Util.add_mesh(arm_l_lo, _ball(0.06), glove, Vector3(0, -FOREARM, 0), Vector3.ZERO, 0.8)

    # місце, куди кладеться зброя (кисть правої руки)
    weapon_holder = Node3D.new()
    spine.add_child(weapon_holder)
    weapon_holder.position = HOLD

    # --- ноги ---
    legs_root = Node3D.new()
    add_child(legs_root)
    leg_l_up = _limb(legs_root, THIGH, 0.092, 0.074, pants)
    leg_l_lo = _limb(legs_root, SHIN, 0.072, 0.058, pants)
    leg_r_up = _limb(legs_root, THIGH, 0.092, 0.074, pants)
    leg_r_lo = _limb(legs_root, SHIN, 0.072, 0.058, pants)
    foot_l = _make_foot(legs_root, boot, boots_t)
    foot_r = _make_foot(legs_root, boot, boots_t)
    if boots_t > 0:
        var oc: Color = Armor.PLATE_COLORS[boots_t]
        _magmify(Util.add_mesh(leg_l_lo, _cyl(0.078, 0.066, 0.24), oc, Vector3(0, -0.22, 0), Vector3.ZERO, 0.35), boots_t, 11.0)
        _magmify(Util.add_mesh(leg_r_lo, _cyl(0.078, 0.066, 0.24), oc, Vector3(0, -0.22, 0), Vector3.ZERO, 0.35), boots_t, 12.0)
        if boots_t >= 5:
            # наколінники професійного лицаря (на 6-му — із золотим обідком)
            var gtrim := Color(0.86, 0.68, 0.22) if boots_t >= 6 else Color(0.82, 0.86, 0.92)
            if boots_t >= 11:
                gtrim = Color(1.0, 0.52, 0.10)
            elif boots_t >= 9:
                gtrim = Color(0.55, 0.95, 1.0)
            elif boots_t >= 7:
                gtrim = Color(0.98, 0.62, 0.14)
            for lo in [leg_l_lo, leg_r_lo]:
                var knee := Util.add_mesh(lo, _ball(0.085), oc, Vector3(0, -0.01, -0.05), Vector3.ZERO, 0.3)
                knee.scale = Vector3(1.0, 0.8, 0.9)
                _magmify(knee, boots_t, 13.0)
                Util.add_mesh(lo, _cyl(0.085, 0.082, 0.025), gtrim, Vector3(0, -0.10, 0), Vector3.ZERO, 0.25, 1.5 if boots_t >= 9 else 0.0)
                if boots_t == 10:
                    # примарний вогник біля щиколотки
                    Util.add_mesh(lo, _ball(0.035), gtrim, Vector3(0, -0.30, 0.09), Vector3.ZERO, 0.2, 3.0)
                if boots_t >= 11:
                    _magma_leg(lo, boots_t)

    _pose(0.0)

func _make_foot(parent: Node3D, boot: Color, tier: int) -> Node3D:
    var f := Node3D.new()
    parent.add_child(f)
    Util.add_mesh(f, Util.box(Vector3(0.15, 0.10, 0.30)), boot, Vector3(0, -0.05, -0.06), Vector3.ZERO, 0.8)
    Util.add_mesh(f, Util.box(Vector3(0.16, 0.03, 0.32)), Color(0.05, 0.05, 0.05), Vector3(0, -0.095, -0.06), Vector3.ZERO, 0.9)
    if tier > 0:
        var oc: Color = Armor.PLATE_COLORS[tier]
        _magmify(Util.add_mesh(f, Util.box(Vector3(0.17, 0.13, 0.33)), oc, Vector3(0, -0.04, -0.06), Vector3.ZERO, 0.35), tier, 14.0)
        if tier >= 5:
            var ftrim := Color(0.86, 0.68, 0.22) if tier >= 6 else Color(0.82, 0.86, 0.92)
            if tier >= 11:
                ftrim = Color(1.0, 0.52, 0.10)
            elif tier >= 9:
                ftrim = Color(0.55, 0.95, 1.0)
            elif tier >= 7:
                ftrim = Color(0.98, 0.62, 0.14)
            Util.add_mesh(f, Util.box(Vector3(0.175, 0.03, 0.12)), ftrim, Vector3(0, 0.0, -0.17), Vector3.ZERO, 0.25, 1.5 if tier >= 9 else 0.0)
        if tier >= 11:
            _magma_foot(f, tier)
    return f

# ================= Магмова броня (рівні 11-13) =================
# 11 «Обпалений базальт»: темний камінь із тонкими розжареними тріщинами.
# 12 «Розпечена лава»: ширші жили лави, роги й шипи з розжареними кінчиками, полум'я на шоломі та п'ятах.
# 13 «Рідка магма»: вся броня вкрита шейдером магми (magma_material.gd), що переливається; сяючі ядро, роги, шипи й краплі лави.
const EMBER := Color(1.0, 0.45, 0.08)
const HOT := Color(1.0, 0.80, 0.25)
const WHITE_HOT := Color(1.0, 0.95, 0.65)

# На 13-му рівні замінює матеріал деталі на «рідку магму».
func _magmify(mi: MeshInstance3D, tier: int, variation: float) -> MeshInstance3D:
    if tier >= Armor.MAX_TIER:
        mi.material_override = MagmaMaterial.make(variation)
    return mi

# Деталь із шейдером магми (без металевого «каркаса» під нею).
func _magma_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, variation: float) -> MeshInstance3D:
    var mi := Util.add_mesh(parent, mesh, Color(0.2, 0.05, 0.02), pos, rot_deg, 0.5)
    mi.material_override = MagmaMaterial.make(variation, 2.8)
    return mi

# Світна деталь (розжарене кіньця, тріщина, крапля).
func _ember(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, color: Color = EMBER, energy: float = 2.6) -> MeshInstance3D:
    return Util.add_mesh(parent, mesh, color, pos, rot_deg, 0.3, energy)

func _magma_body(tier: int) -> void:
    var rock: Color = Armor.PLATE_COLORS[tier]
    # тріщини жару на нагруднику: x, y, поворот, довжина
    var cracks: Array = [[-0.15, 0.52, -18.0, 0.16], [0.10, 0.46, 14.0, 0.20], [-0.05, 0.32, -6.0, 0.14], [0.16, 0.26, 24.0, 0.12], [-0.17, 0.22, 20.0, 0.10]]
    if tier == 11:
        for c in cracks:
            _ember(spine, Util.box(Vector3(0.014, float(c[3]), 0.012)), Vector3(float(c[0]), float(c[1]), -0.208), Vector3(0, 0, float(c[2])), EMBER, 2.2)
        _ember(spine, Util.box(Vector3(0.012, 0.09, 0.012)), Vector3(-0.35, 0.60, -0.10), Vector3(0, 0, 20), EMBER, 2.2)
        _ember(spine, Util.box(Vector3(0.012, 0.09, 0.012)), Vector3(0.35, 0.60, -0.10), Vector3(0, 0, -20), EMBER, 2.2)
    elif tier == 12:
        for c in cracks:
            _ember(spine, Util.box(Vector3(0.03, float(c[3]) * 1.3, 0.016)), Vector3(float(c[0]), float(c[1]), -0.208), Vector3(0, 0, float(c[2])), EMBER, 2.8)
        _ember(spine, Util.box(Vector3(0.16, 0.05, 0.02)), Vector3(0, 0.40, -0.215), Vector3.ZERO, HOT, 3.0)       # жерло на грудях
        for sx: float in [-0.35, 0.35]:
            Util.add_mesh(spine, _cyl(0.0, 0.055, 0.18), rock, Vector3(sx, 0.76, 0), Vector3.ZERO, 0.5)
            _ember(spine, _cyl(0.0, 0.025, 0.07), Vector3(sx, 0.86, 0), Vector3.ZERO, EMBER, 3.0)
        for fx: float in [-0.09, -0.045, 0.0, 0.045, 0.09]:                                                        # полум'яний комір
            _ember(spine, _cyl(0.0, 0.022, 0.09), Vector3(fx, 0.74, -0.09), Vector3.ZERO, EMBER, 2.6)
    else:
        # 13: ядро-магма, довгі шипи на плечах, краплі лави на поясі
        _ember(spine, _ball(0.075), Vector3(0, 0.40, -0.225), Vector3.ZERO, WHITE_HOT, 3.6)
        var halo := _ember(spine, _ball(0.11), Vector3(0, 0.40, -0.20), Vector3.ZERO, EMBER, 1.6)
        halo.scale = Vector3(1.0, 1.0, 0.4)
        for sx: float in [-0.35, 0.35]:
            _magma_part(spine, _cyl(0.0, 0.07, 0.30), Vector3(sx, 0.82, 0), Vector3.ZERO, 20.0 + sx * 10.0)
            _magma_part(spine, _cyl(0.0, 0.045, 0.18), Vector3(sx * 1.35, 0.70, 0), Vector3(0, 0, -sx * 110.0), 22.0 + sx * 10.0)
            _ember(spine, _ball(0.03), Vector3(sx, 0.99, 0), Vector3.ZERO, WHITE_HOT, 3.5)
        for dx: float in [-0.17, -0.06, 0.07, 0.17]:
            var drop := _ember(spine, _ball(0.03), Vector3(dx, 0.07 - absf(dx) * 0.2, -0.195), Vector3.ZERO, HOT, 3.0)
            drop.scale = Vector3(1.0, 1.9, 1.0)
        _magma_part(spine, Util.box(Vector3(0.46, 0.05, 0.08)), Vector3(0, 0.22, -0.18), Vector3.ZERO, 23.0)
        # м'яке світло від броні на землю й навколишніх
        var li := OmniLight3D.new()
        li.light_color = Color(1.0, 0.42, 0.10)
        li.light_energy = 0.9
        li.omni_range = 3.6
        li.position = Vector3(0, 0.45, -0.45)
        li.set_script(load("res://light_flicker.gd"))       # світло лави трохи пульсує
        li.set("speed", 2.6)
        li.set("amount", 0.18)
        spine.add_child(li)

func _magma_head(tier: int) -> void:
    var rock: Color = Armor.PLATE_COLORS[tier]
    if tier == 11:
        _ember(head, Util.box(Vector3(0.20, 0.018, 0.03)), Vector3(0, 0.03, -0.212), Vector3.ZERO, EMBER, 2.8)       # жар у проріз забрала
        for sx: float in [-0.15, 0.15]:
            Util.add_mesh(head, _cyl(0.0, 0.045, 0.16), rock, Vector3(sx, 0.20, 0.0), Vector3(0, 0, -sx * 190.0), 0.5)
        _ember(head, Util.box(Vector3(0.012, 0.10, 0.012)), Vector3(-0.19, 0.14, -0.10), Vector3(0, 0, 14), EMBER, 2.2)
        _ember(head, Util.box(Vector3(0.012, 0.10, 0.012)), Vector3(0.19, 0.14, -0.10), Vector3(0, 0, -14), EMBER, 2.2)
    elif tier == 12:
        _ember(head, Util.box(Vector3(0.05, 0.03, 0.03)), Vector3(-0.06, 0.03, -0.215), Vector3.ZERO, HOT, 3.4)     # розжарені очі
        _ember(head, Util.box(Vector3(0.05, 0.03, 0.03)), Vector3(0.06, 0.03, -0.215), Vector3.ZERO, HOT, 3.4)
        for sx: float in [-0.17, 0.17]:
            Util.add_mesh(head, _cyl(0.0, 0.05, 0.28), rock, Vector3(sx, 0.24, 0.0), Vector3(0, 0, -sx * 200.0), 0.5)
            _ember(head, _cyl(0.0, 0.025, 0.08), Vector3(sx * 1.55, 0.36, 0.0), Vector3(0, 0, -sx * 200.0), EMBER, 3.0)
        for fz: float in [-0.08, 0.0, 0.08]:                                                                      # полум'яний гребінь
            _ember(head, _cyl(0.0, 0.03, 0.14 - absf(fz) * 0.4), Vector3(0, 0.33, fz), Vector3.ZERO, EMBER, 2.6)
        _ember(head, Util.box(Vector3(0.014, 0.12, 0.014)), Vector3(-0.2, -0.02, -0.12), Vector3(0, 0, 10), EMBER, 2.8)
        _ember(head, Util.box(Vector3(0.014, 0.12, 0.014)), Vector3(0.2, -0.02, -0.12), Vector3(0, 0, -10), EMBER, 2.8)
    else:
        _ember(head, Util.box(Vector3(0.22, 0.03, 0.03)), Vector3(0, 0.03, -0.214), Vector3.ZERO, WHITE_HOT, 3.6)  # біло-розпечений проріз
        for sx: float in [-0.17, 0.17]:
            _magma_part(head, _cyl(0.0, 0.06, 0.34), Vector3(sx, 0.26, 0.0), Vector3(0, 0, -sx * 200.0), 30.0 + sx * 10.0)
            _magma_part(head, _cyl(0.0, 0.04, 0.16), Vector3(sx * 2.05, 0.43, 0.0), Vector3(0, 0, -sx * 330.0), 33.0 + sx * 10.0)
        for i in range(5):                                                                                          # корона магмових шипів
            var a := (float(i) - 2.0) * 0.5
            _magma_part(head, _cyl(0.0, 0.03, 0.15), Vector3(sin(a) * 0.12, 0.30 + cos(a) * 0.02, -0.02), Vector3(0, 0, -a * 50.0), 40.0 + float(i))
        for sp in [Vector3(-0.10, 0.52, 0.04), Vector3(0.12, 0.58, -0.02), Vector3(0.0, 0.64, 0.08)]:                # іскри над головою
            _ember(head, _ball(0.018), sp, Vector3.ZERO, WHITE_HOT, 3.5)

func _magma_leg(lo: Node3D, tier: int) -> void:
    var rock: Color = Armor.PLATE_COLORS[tier]
    if tier == 11:
        _ember(lo, Util.box(Vector3(0.012, 0.12, 0.012)), Vector3(0, -0.20, -0.078), Vector3(8, 0, 0), EMBER, 2.2)
        _ember(lo, Util.box(Vector3(0.012, 0.09, 0.012)), Vector3(0.03, -0.30, -0.074), Vector3(-8, 0, 12), EMBER, 2.2)
        _ember(lo, _cyl(0.07, 0.07, 0.015), Vector3(0, -0.36, 0), Vector3.ZERO, EMBER, 2.4)
    elif tier == 12:
        _ember(lo, Util.box(Vector3(0.026, 0.18, 0.014)), Vector3(0, -0.22, -0.08), Vector3(8, 0, 0), EMBER, 2.8)
        _ember(lo, _cyl(0.072, 0.072, 0.025), Vector3(0, -0.36, 0), Vector3.ZERO, HOT, 3.0)
        Util.add_mesh(lo, _cyl(0.0, 0.04, 0.13), rock, Vector3(0, -0.01, -0.15), Vector3(-90, 0, 0), 0.5)         # шип на коліні
        _ember(lo, _cyl(0.0, 0.02, 0.05), Vector3(0, -0.01, -0.235), Vector3(-90, 0, 0), EMBER, 3.0)
    else:
        _magma_part(lo, _cyl(0.0, 0.05, 0.16), Vector3(0, -0.01, -0.16), Vector3(-90, 0, 0), 50.0)
        _ember(lo, _cyl(0.074, 0.074, 0.03), Vector3(0, -0.36, 0), Vector3.ZERO, WHITE_HOT, 3.2)
        for dx: float in [-0.04, 0.04]:
            var drop := _ember(lo, _ball(0.02), Vector3(dx, -0.40, -0.06), Vector3.ZERO, HOT, 3.0)
            drop.scale = Vector3(1.0, 1.8, 1.0)

func _magma_foot(f: Node3D, tier: int) -> void:
    # розжарена підошва
    _ember(f, Util.box(Vector3(0.15, 0.012, 0.28)), Vector3(0, -0.108, -0.06), Vector3.ZERO, EMBER, 2.4 if tier < 13 else 3.2)
    if tier == 11:
        _ember(f, Util.box(Vector3(0.012, 0.012, 0.10)), Vector3(0, 0.03, -0.20), Vector3.ZERO, EMBER, 2.2)
    elif tier == 12:
        _ember(f, Util.box(Vector3(0.03, 0.014, 0.16)), Vector3(0, 0.03, -0.17), Vector3.ZERO, EMBER, 2.8)
        _ember(f, _cyl(0.0, 0.035, 0.12), Vector3(0, -0.03, 0.17), Vector3(90, 0, 0), EMBER, 2.8)                  # полум'я на п'ятах
    else:
        _magma_part(f, Util.box(Vector3(0.12, 0.05, 0.14)), Vector3(0, 0.03, -0.14), Vector3.ZERO, 60.0)
        _ember(f, _cyl(0.0, 0.045, 0.16), Vector3(0, -0.03, 0.18), Vector3(90, 0, 0), HOT, 3.2)
        _ember(f, _cyl(0.0, 0.025, 0.09), Vector3(0, -0.03, 0.22), Vector3(90, 0, 0), WHITE_HOT, 3.6)

# ================= Керування ззовні =================
func set_weapon(id: String) -> void:
    weapon_id = id
    var w: Dictionary = Weapons.DATA.get(id, {})
    weapon_type = String(w.get("type", "melee"))
    for c in weapon_holder.get_children():
        c.queue_free()
    WeaponModels.build(weapon_holder, id)
    if water_l != null and is_instance_valid(water_l):
        water_l.queue_free()
    water_l = null
    if (id == "water_element" or id == "frost_staff" or id == "fire_element") and arm_l_lo != null:
        water_l = Node3D.new()
        var hands_script := "res://water_hands.gd"
        if id == "frost_staff":
            hands_script = "res://frost_hands.gd"
        elif id == "fire_element":
            hands_script = "res://fire_hands.gd"
        water_l.set_script(load(hands_script))
        arm_l_lo.add_child(water_l)
        water_l.position = Vector3(0.0, -FOREARM, 0.0)

# kind: "melee" / "aoe" / "ranged"; arc — дуга удару (радіани); dur — тривалість анімації
func play_attack(kind: String, arc: float, dur: float) -> void:
    atk_kind = kind
    atk_arc = arc
    atk_dur = clampf(dur, 0.12, 0.45)
    atk_clock = 0.0
    if weapon_id == "water_element" or weapon_id == "frost_staff" or weapon_id == "fire_element":
        for c in weapon_holder.get_children():
            if c.has_method("pulse"):
                c.pulse()
        if water_l != null and is_instance_valid(water_l):
            water_l.pulse()

# Удар клинком: style — slash / stab / heavy; dir — +1 зліва направо, -1 справа наліво;
# half — половина дуги; dur — тривалість; t0..t1 — частки, коли клинок «живий» (збігається з player.gd).
func play_blade(style: String, dir: float, half: float, dur: float, t0: float, t1: float) -> void:
    atk_kind = "blade"
    b_style = style
    b_dir = dir
    b_half = half
    b_t0 = t0
    b_t1 = t1
    atk_dur = maxf(dur, 0.05)
    atk_clock = 0.0

func hurt() -> void:
    flinch = 1.0

func die() -> void:
    dead = true
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(self, "rotation:x", 1.45, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(self, "position:y", 0.22, 0.6)

# ================= Допоміжна математика =================
func _sm(x: float) -> float:
    var t := clampf(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

# Повертає вузол так, щоб його локальна вісь -Y дивилась уздовж dir.
func _aim_down(n: Node3D, dir: Vector3) -> void:
    var y := -dir.normalized()
    var helper := Vector3(0.0, 0.0, -1.0)
    if absf(y.dot(helper)) > 0.95:
        helper = Vector3.RIGHT
    var x := helper.cross(y).normalized()
    var z := x.cross(y).normalized()
    n.basis = Basis(x, y, z)

# Двокісткова IK: root — плече/стегно, target — кисть/щиколотка, pole — куди дивиться лікоть/коліно.
# Усе в просторі спільного батька вузлів up і lo. Повертає реальну кінцеву точку (ціль, обмежену довжиною кінцівки).
func _ik(up: Node3D, lo: Node3D, root: Vector3, target: Vector3, pole: Vector3, l1: float, l2: float) -> Vector3:
    var to := target - root
    var dist := to.length()
    var dir := Vector3.DOWN
    if dist > 0.0001:
        dir = to / dist
    var d := clampf(dist, 0.08, l1 + l2 - 0.002)
    var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
    var a := acos(cos_a)
    var axis := dir.cross(pole)
    if axis.length() < 0.001:
        axis = Vector3.RIGHT
    axis = axis.normalized()
    var upper_dir := dir.rotated(axis, a)
    var joint := root + upper_dir * l1
    var end := root + dir * d
    var lower_dir := (end - joint).normalized()
    up.position = root
    _aim_down(up, upper_dir)
    lo.position = joint
    _aim_down(lo, lower_dir)
    return end

# ================= Анімація =================
func _process(delta: float) -> void:
    if player == null or dead:
        return
    time += delta
    var vel: Vector3 = player.velocity
    var spd := Vector2(vel.x, vel.z).length()

    var want := 0.0
    if spd > 0.6:
        want = 1.0
    move_blend = lerpf(move_blend, want, 1.0 - exp(-12.0 * delta))

    # корпус повернутий до прицілу (плавно)
    var aim: Vector3 = player.aim
    rotation.y = lerp_angle(rotation.y, atan2(-aim.x, -aim.z), 1.0 - exp(-18.0 * delta))

    # напрямок руху відносно корпусу: вперед / боком / назад
    var lean := 0.0
    var dir_sign := 1.0
    if spd > 0.6:
        var lv := Vector3(vel.x, 0.0, vel.z).rotated(Vector3.UP, -rotation.y)
        lean = atan2(lv.x, -lv.z)
        if absf(lean) > PI * 0.5:
            lean -= signf(lean) * PI
            dir_sign = -1.0
    leg_yaw = lerp_angle(leg_yaw, -lean, 1.0 - exp(-12.0 * delta))

    phase += delta * (5.0 + 1.35 * spd) * dir_sign * move_blend
    var sf := clampf(spd / 7.2, 0.0, 1.0)
    var amp := move_blend * lerpf(0.55, 1.0, sf)

    _update_attack(delta)
    flinch *= exp(-8.0 * delta)
    _pose(delta, amp, sf, lean)

    # кроки зі звуком
    var step_idx := int(floorf(phase / PI))
    if step_idx != last_step:
        last_step = step_idx
        if move_blend > 0.6:
            Sfx.play("step", 0.0, 0.9 + randf() * 0.2)

func _update_attack(delta: float) -> void:
    atk_clock += delta
    var tw := 0.0
    var ln := 0.0
    var hold := Vector3.ZERO
    var rot := Vector3.ZERO
    var p := atk_clock / atk_dur
    if p < 1.0:
        if atk_kind == "melee":
            if atk_arc < 0.9:
                var k := sin(p * PI)
                hold = Vector3(0.0, 0.0, -0.30 * k)
                ln = -0.25 * k
                tw = 0.15 * k
            else:
                var a := minf(atk_arc * 0.5, 1.3)
                var sweep := 0.0
                if p < 0.15:
                    sweep = a * _sm(p / 0.15)
                elif p < 0.62:
                    sweep = lerpf(a, -a, _sm((p - 0.15) / 0.47))
                else:
                    sweep = lerpf(-a, 0.0, _sm((p - 0.62) / 0.38))
                tw = sweep * 0.45
                rot = Vector3(0.0, sweep * 0.55, 0.0)
                ln = -0.12 * sin(p * PI)
                hold = Vector3(0.0, 0.0, -0.10 * sin(p * PI))
        elif atk_kind == "blade":
            var bp := _blade_pose(p)
            tw = float(bp["tw"])
            ln = float(bp["ln"])
            hold = bp["hold"]
            rot = bp["rot"]
        elif atk_kind == "aoe":
            var raise := 0.0
            if p < 0.30:
                raise = _sm(p / 0.30)
            elif p < 0.48:
                raise = lerpf(1.0, -0.25, _sm((p - 0.30) / 0.18))
            else:
                raise = lerpf(-0.25, 0.0, _sm((p - 0.48) / 0.52))
            hold = Vector3(0.0, 0.55 * raise, 0.22 * raise)
            rot = Vector3(raise, 0.0, 0.0)
            ln = 0.12 * maxf(raise, 0.0) + 2.0 * minf(raise, 0.0)
        elif atk_kind == "cast":
            # вода: руки йдуть вгору (кульки злітають), потім різкий викид уперед
            var up := 0.0
            var fw := 0.0
            if p < 0.45:
                up = _sm(p / 0.45)
            else:
                up = lerpf(1.0, 0.0, _sm((p - 0.45) / 0.55))
                fw = sin(clampf((p - 0.45) / 0.3, 0.0, 1.0) * PI)
            hold = Vector3(0.0, 0.20 * up, -0.14 * fw)
            rot = Vector3(-0.35 * up + 0.2 * fw, 0.0, 0.0)
            ln = -0.06 * fw
        else:
            var kk := 1.0 - _sm(p)
            hold = Vector3(0.0, 0.02 * kk, 0.16 * kk)
            rot = Vector3(0.12 * kk, 0.0, 0.0)
            ln = 0.12 * kk
    # згладжування, щоб підряд швидкі удари не "смикались"
    var k2 := 1.0 - exp(-35.0 * delta)
    v_twist = lerpf(v_twist, tw, k2)
    v_lean = lerpf(v_lean, ln, k2)
    v_hold = v_hold.lerp(hold, k2)
    v_rot = v_rot.lerp(rot, k2)

# Поза руки з клинком за прогресом удару p (0..1). Те саме згладжування, що й у player._blade_sweep.
func _blade_pose(p: float) -> Dictionary:
    var tw := 0.0
    var ln := 0.0
    var hold := Vector3.ZERO
    var rot := Vector3.ZERO
    var t0 := maxf(b_t0, 0.01)
    var t1 := maxf(b_t1, t0 + 0.01)
    if b_style == "stab":
        # назад рукою -> різкий випад уперед -> повернення
        var z := 0.0
        var lean := 0.0
        if p < t0:
            var w := _sm(p / t0)
            z = 0.20 * w
            lean = 0.10 * w
            tw = -0.12 * w
        elif p < t1:
            var k := _sm((p - t0) / (t1 - t0))
            z = lerpf(0.20, -0.20, k)
            lean = lerpf(0.10, -0.38, k)
            tw = lerpf(-0.12, 0.10, k)
        else:
            var r := _sm((p - t1) / (1.0 - t1))
            z = lerpf(-0.20, 0.0, r)
            lean = lerpf(-0.38, 0.0, r)
            tw = lerpf(0.10, 0.0, r)
        hold = Vector3(0.0, 0.06, z)
        ln = lean
        return {"tw": tw, "ln": ln, "hold": hold, "rot": rot}
    if b_style == "thrust":
        # спис: обома руками назад (наконечник відводиться) -> різкий довгий випад -> повернення.
        # Корпус майже не нахиляється, а зброя тримається рівно, щоб наконечник не встромлявся в землю.
        var z2 := 0.0
        var lean2 := 0.0
        var tw2 := 0.0
        if p < t0:
            var w3 := _sm(p / t0)
            z2 = 0.34 * w3
            lean2 = 0.06 * w3
            tw2 = -0.22 * w3
        elif p < t1:
            var k3 := _sm((p - t0) / (t1 - t0))
            z2 = lerpf(0.34, -0.42, k3)
            lean2 = lerpf(0.06, -0.16, k3)
            tw2 = lerpf(-0.22, 0.20, k3)
        else:
            var r3 := _sm((p - t1) / (1.0 - t1))
            z2 = lerpf(-0.42, 0.0, r3)
            lean2 = lerpf(-0.16, 0.0, r3)
            tw2 = lerpf(0.20, 0.0, r3)
        return {"tw": tw2, "ln": lean2, "hold": Vector3(0.0, 0.04, z2), "rot": Vector3(-lean2, 0.0, 0.0)}
    if b_style == "bash" or b_style == "slam":
        return _smash_pose(p, t0, t1)
    var heavy := b_style == "heavy"
    var a := minf(b_half, 1.45 if heavy else 1.3)
    var s0 := b_dir * a
    var sweep := 0.0
    var up := 0.0
    var back := 0.0
    if p < t0:
        # замах: клинок відводиться на початок дуги (важкий ще й піднімається, герой відхиляється назад)
        var w2 := _sm(p / t0)
        sweep = lerpf(0.0, s0, w2)
        if heavy:
            up = 0.22 * w2
            back = 0.18 * w2
    elif p < t1:
        var k2 := _sm((p - t0) / (t1 - t0))
        sweep = lerpf(s0, -s0, k2)
        if heavy:
            up = lerpf(0.22, 0.0, k2)
            back = lerpf(0.18, -0.22, k2)
        else:
            back = -0.12 * sin(k2 * PI)
    else:
        var r2 := _sm((p - t1) / (1.0 - t1))
        sweep = lerpf(-s0, 0.0, r2)
        if heavy:
            back = lerpf(-0.22, 0.0, r2)
    tw = sweep * 0.45
    rot = Vector3(0.0, sweep * 0.55, 0.0)
    ln = back
    hold = Vector3(0.0, up, -0.10 * sin(clampf(p, 0.0, 1.0) * PI))
    return {"tw": tw, "ln": ln, "hold": hold, "rot": rot}

# Булава (одна рука) і молот (дві руки, над головою): підняти -> швидкий удар зверху з розгоном -> влучання -> повернення.
# Влучання (p = t1) збігається з моментом урону в player._smash.
func _smash_pose(p: float, t0: float, t1: float) -> Dictionary:
    var slam := b_style == "slam"
    # (підйом зброї; відхил корпусу назад; тангаж зброї; висота; вперед-назад; скручування)
    var up_rot := 1.15
    var up_y := 0.42
    var up_back := 0.10
    var end_rot := -0.20
    var end_lean := -0.16
    var end_z := -0.20
    var end_y := -0.06
    var up_tw := -0.25
    var end_tw := 0.22
    if slam:
        up_rot = 1.55
        up_y = 0.62
        up_back = 0.24
        end_rot = -0.35
        end_lean = -0.30
        end_z = -0.28
        end_y = -0.10
        up_tw = 0.0
        end_tw = 0.0
    var rot_x := 0.0
    var ln := 0.0
    var y := 0.0
    var z := 0.0
    var tw := 0.0
    if p < t0:
        # підйом / замах: повільно, зі зростаючим відхилом назад
        var w := _sm(p / t0)
        rot_x = up_rot * w
        ln = up_back * w
        y = up_y * w
        z = 0.12 * w
        tw = up_tw * w
    elif p < t1:
        # удар: розгін (квадрат), щоб влучання було різким
        var k := clampf((p - t0) / (t1 - t0), 0.0, 1.0)
        k = k * k
        rot_x = lerpf(up_rot, end_rot, k)
        ln = lerpf(up_back, end_lean, k)
        y = lerpf(up_y, end_y, k)
        z = lerpf(0.12, end_z, k)
        tw = lerpf(up_tw, end_tw, k)
    else:
        # після влучання зброя на мить завмирає в землі, потім повертається
        var r := _sm((p - t1) / (1.0 - t1))
        rot_x = lerpf(end_rot, 0.0, r)
        ln = lerpf(end_lean, 0.0, r)
        y = lerpf(end_y, 0.0, r)
        z = lerpf(end_z, 0.0, r)
        tw = lerpf(end_tw, 0.0, r)
    return {"tw": tw, "ln": ln, "hold": Vector3(0.0, y, z), "rot": Vector3(rot_x, 0.0, 0.0)}

func _pose(delta: float, amp: float = 0.0, sf: float = 0.0, lean: float = 0.0) -> void:
    var p := phase
    var breathe := sin(time * 1.9) * (1.0 - amp)
    var hip_y := HIP_Y - cos(2.0 * p) * 0.045 * amp + breathe * 0.006 - flinch * 0.04

    # таз і ноги
    hips.position = Vector3(0.0, hip_y, 0.0)
    hips.rotation.y = leg_yaw * 0.6 - sin(p) * 0.08 * amp
    legs_root.rotation.y = leg_yaw
    for side in [0, 1]:
        var t := p + PI * float(side)
        var xs := 0.15
        if side == 0:
            xs = -0.15
        var zf := STRIDE * amp * cos(t)
        var lift := FOOT_LIFT * amp * maxf(0.0, -sin(t))
        var hip := Vector3(xs, hip_y, 0.0)
        var ankle := Vector3(xs, ANKLE_H + lift, -zf)
        var up_n := leg_r_up
        var lo_n := leg_r_lo
        var foot := foot_r
        if side == 0:
            up_n = leg_l_up
            lo_n = leg_l_lo
            foot = foot_l
        var end := _ik(up_n, lo_n, hip, ankle, Vector3(0.0, 0.0, -1.0), THIGH, SHIN)
        foot.position = end
        foot.rotation.x = 0.4 * amp * cos(t)

    # хребет, голова
    var lean_run := 0.06 + 0.16 * sf * move_blend
    spine.position = Vector3(0.0, hip_y, 0.0)
    spine.rotation = Vector3(
        -lean_run + 0.30 * flinch + v_lean + breathe * 0.012,
        sin(p) * 0.16 * amp + v_twist,
        -lean * 0.12 * amp)
    head.rotation = Vector3(
        -spine.rotation.x * 0.7 + sin(2.0 * p) * 0.03 * amp,
        -spine.rotation.y * 0.6,
        -spine.rotation.z * 0.5)

    # права рука тримає зброю
    weapon_holder.position = HOLD + v_hold + Vector3(0.0, breathe * 0.008 + sin(2.0 * p) * 0.025 * amp, 0.0)
    weapon_holder.rotation = v_rot
    _ik(arm_r_up, arm_r_lo, Vector3(SHOULDER.x, SHOULDER.y, 0.0), weapon_holder.position, Vector3(0.7, -0.9, 0.3), UPPER_ARM, FOREARM)

    # ліва рука: махає при бігу, а з далекобійною зброєю підтримує її спереду
    var sup_t := 0.0
    if weapon_type == "proj" or weapon_type == "chain" or weapon_type == "water" or weapon_type == "ice" or weapon_type == "fire":
        sup_t = 1.0
    if delta > 0.0:
        support = lerpf(support, sup_t, 1.0 - exp(-8.0 * delta))
    else:
        support = sup_t
    var idle := LEFT_IDLE + Vector3(0.0, absf(sin(p)) * 0.05 * amp, cos(p) * 0.24 * amp)
    var tgt := idle.lerp(LEFT_SUPPORT + Vector3(0.0, 0.0, v_hold.z * 0.7), support)
    _ik(arm_l_up, arm_l_lo, Vector3(-SHOULDER.x, SHOULDER.y, 0.0), tgt, Vector3(-0.7, -0.9, 0.3), UPPER_ARM, FOREARM)
