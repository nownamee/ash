extends RefCounted
# Візуальні ефекти: частинки, вибухи, спливаючі цифри урону, блискавка.

# Спільні ресурси ефектів (створюються один раз, а не на кожен удар).
static var _burst_mat: StandardMaterial3D
static var _burst_meshes := {}

static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 12, speed: float = 4.0, size: float = 0.1) -> void:
    if _burst_mat == null:
        _burst_mat = StandardMaterial3D.new()
        _burst_mat.vertex_color_use_as_albedo = true
        _burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var key := "%.3f" % size
    var mesh: SphereMesh
    if _burst_meshes.has(key):
        mesh = _burst_meshes[key]
    else:
        mesh = SphereMesh.new()
        mesh.radius = size
        mesh.height = size * 2.0
        mesh.radial_segments = 8
        mesh.rings = 4
        mesh.material = _burst_mat
        _burst_meshes[key] = mesh
    var p := CPUParticles3D.new()
    p.mesh = mesh
    p.amount = amount
    p.lifetime = 0.6
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 180.0
    p.initial_velocity_min = speed * 0.5
    p.initial_velocity_max = speed
    p.gravity = Vector3(0.0, -9.0, 0.0)
    p.color = color
    p.position = pos
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(p)
    p.emitting = true
    parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

static func damage_text(parent: Node, pos: Vector3, text: String, color: Color = Color(1.0, 0.9, 0.3)) -> void:
    # не більше 14 написів одночасно: кожен Label3D перебудовує текст і контур
    if parent.get_tree().get_nodes_in_group("dmg_texts").size() >= 14:
        return
    var l := Label3D.new()
    l.text = text
    l.font_size = 40
    l.pixel_size = 0.0128
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.modulate = color
    l.outline_size = 6
    l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    l.position = pos + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)
    parent.add_child(l)
    l.add_to_group("dmg_texts")
    var tw := l.create_tween()
    tw.set_parallel(true)
    tw.tween_property(l, "position:y", l.position.y + 1.4, 0.7)
    tw.tween_property(l, "modulate:a", 0.0, 0.7)
    tw.chain().tween_callback(l.queue_free)

static func explosion(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = 1.0
    s.height = 2.0
    mi.mesh = s
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color.r, color.g, color.b, 0.5)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = pos
    mi.scale = Vector3.ONE * 0.2
    parent.add_child(mi)
    var tw := mi.create_tween()
    tw.set_parallel(true)
    tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.25)
    tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
    tw.chain().tween_callback(mi.queue_free)
    burst(parent, pos + Vector3(0.0, 0.3, 0.0), color, 14, 6.0, 0.12)

static func bolt(parent: Node, a: Vector3, b: Vector3, color: Color) -> void:
    var dist := a.distance_to(b)
    if dist < 0.05:
        return
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.12, 0.12, dist)
    mi.mesh = box
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = (a + b) * 0.5
    parent.add_child(mi)
    mi.look_at(b, Vector3.UP)
    parent.get_tree().create_timer(0.12).timeout.connect(mi.queue_free)


# ---------- Кров і гор ----------
static var _splat_tex: Array = []

static func _make_splat(seed_v: int) -> ImageTexture:
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.seed = seed_v
    n.frequency = 0.07
    n.fractal_octaves = 3
    var sz := 64
    var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
    for x in range(sz):
        for y in range(sz):
            var dx := (float(x) - 31.5) / 32.0
            var dy := (float(y) - 31.5) / 32.0
            var r := sqrt(dx * dx + dy * dy)
            var v := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
            var a := clampf((0.9 - r) * 2.4 + (v - 0.5) * 1.8, 0.0, 1.0)
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)

static var _unit_quad: QuadMesh

# Калюжа крові на землі: тримається ~12 с, потім зникає. Не більше 40 одночасно.
static func blood_splat(parent: Node, pos: Vector3, radius: float) -> void:
    if _splat_tex.is_empty():
        for i in range(3):
            _splat_tex.append(_make_splat(100 + i * 17))
    if _unit_quad == null:
        _unit_quad = QuadMesh.new()
        _unit_quad.size = Vector2(1.0, 1.0)
    var mi := MeshInstance3D.new()
    mi.mesh = _unit_quad
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(randf_range(0.28, 0.4), 0.012, 0.012, 0.93)
    m.albedo_texture = _splat_tex[randi() % _splat_tex.size()]
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.12
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = Vector3(pos.x, 0.045 + randf() * 0.012, pos.z)
    mi.rotation_degrees = Vector3(-90.0, randf() * 360.0, 0.0)
    mi.scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
    parent.add_child(mi)
    mi.add_to_group("blood_decals")
    var all := parent.get_tree().get_nodes_in_group("blood_decals")
    if all.size() > 40:
        all[0].queue_free()
    var tw := mi.create_tween()
    tw.tween_interval(12.0)
    tw.tween_property(m, "albedo_color:a", 0.0, 4.0)
    tw.tween_callback(mi.queue_free)

static var _spray_mesh: SphereMesh

# Бризки крові в напрямку удару.
static func blood_spray(parent: Node, pos: Vector3, dir: Vector3, amount: int = 10) -> void:
    if _spray_mesh == null:
        _spray_mesh = SphereMesh.new()
        _spray_mesh.radius = 0.05
        _spray_mesh.height = 0.1
        _spray_mesh.radial_segments = 6
        _spray_mesh.rings = 3
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(0.4, 0.015, 0.015)
        m.roughness = 0.1
        _spray_mesh.material = m
    var p := CPUParticles3D.new()
    p.mesh = _spray_mesh
    p.amount = mini(amount, 6)
    p.lifetime = 0.55
    p.one_shot = true
    p.explosiveness = 1.0
    var d := dir
    d.y = 0.35
    p.direction = d.normalized()
    p.spread = 32.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 8.0
    p.gravity = Vector3(0.0, -14.0, 0.0)
    p.scale_amount_min = 0.5
    p.scale_amount_max = 1.5
    p.position = pos
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(p)
    p.emitting = true
    parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

static var _gore_mats := {}
static var _gore_meshes := {}

# Шматки плоті (або кісток) при смерті.
static func gore(parent: Node, pos: Vector3, size_f: float, bone: bool = false) -> void:
    var mkey := "bone" if bone else "flesh"
    if not _gore_mats.has(mkey):
        var m := StandardMaterial3D.new()
        m.roughness = 0.25
        if bone:
            m.albedo_color = Color(0.85, 0.8, 0.68)
        else:
            m.albedo_color = Color(0.42, 0.04, 0.04)
        _gore_mats[mkey] = m
    var skey := "%s%.2f" % [mkey, size_f]
    var mesh: BoxMesh
    if _gore_meshes.has(skey):
        mesh = _gore_meshes[skey]
    else:
        mesh = BoxMesh.new()
        mesh.size = Vector3(0.14, 0.1, 0.12) * size_f
        mesh.material = _gore_mats[mkey]
        _gore_meshes[skey] = mesh
    var p := CPUParticles3D.new()
    p.mesh = mesh
    p.amount = int(6.0 + 4.0 * size_f)
    p.lifetime = 0.9
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = Vector3.UP
    p.spread = 70.0
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 6.5
    p.gravity = Vector3(0.0, -16.0, 0.0)
    p.angular_velocity_min = -400.0
    p.angular_velocity_max = 400.0
    p.scale_amount_min = 0.5
    p.scale_amount_max = 1.5
    p.position = pos
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(p)
    p.emitting = true
    parent.get_tree().create_timer(1.4).timeout.connect(p.queue_free)


# ---------- Блискавичний ривок ----------
static var _arc_mat: StandardMaterial3D

static func _glow_mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    return m

# Ламана «блискавка» від a до b: проміжні точки зсунуті вбік і по висоті.
static func _zig_points(a: Vector3, b: Vector3, jitter: float, step: float) -> Array:
    var pts: Array = [a]
    var dir := b - a
    var dist := dir.length()
    if dist < 0.01:
        pts.append(b)
        return pts
    var d := dir / dist
    var side := d.cross(Vector3.UP).normalized()
    var n := maxi(2, int(dist / step))
    for i in range(1, n):
        var p := a.lerp(b, float(i) / float(n))
        p += side * randf_range(-jitter, jitter) + Vector3.UP * randf_range(-jitter, jitter) * 0.8
        p.y = maxf(p.y, 0.15)
        pts.append(p)
    pts.append(b)
    return pts

# Тонкий брусок між двома точками (сегмент блискавки). root має вже бути в дереві.
static func _seg_box(root: Node3D, p: Vector3, q: Vector3, thick: float, mat: Material) -> void:
    var seg_len := p.distance_to(q)
    if seg_len < 0.02:
        return
    var mi := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(thick, thick, seg_len)
    mi.mesh = box
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(mi)
    mi.position = (p + q) * 0.5
    var up := Vector3.UP
    if absf((q - p).normalized().dot(Vector3.UP)) > 0.98:
        up = Vector3.RIGHT
    mi.look_at(q, up)

# Велика блискавка вздовж усього ривка: яскрава жила з ореолом, дві бокові гілки, сяючий «тунель», спалах світла й іскри.
static func dash_lightning(parent: Node, a: Vector3, b: Vector3) -> void:
    var dist := a.distance_to(b)
    if dist < 0.1:
        return
    var a2 := a + Vector3(0.0, 1.0, 0.0)
    var b2 := b + Vector3(0.0, 1.0, 0.0)
    var root := Node3D.new()
    parent.add_child(root)
    var core := _glow_mat(Color(0.92, 0.98, 1.0, 1.0))
    var glow := _glow_mat(Color(0.3, 0.6, 1.0, 0.6))
    var aura := _glow_mat(Color(0.35, 0.6, 1.0, 0.25))
    for s in range(3):
        var jit := 0.2 if s == 0 else 0.55
        var pts := _zig_points(a2, b2, jit, 0.45)
        for i in range(pts.size() - 1):
            _seg_box(root, pts[i], pts[i + 1], 0.08 if s == 0 else 0.045, core)
            _seg_box(root, pts[i], pts[i + 1], 0.28 if s == 0 else 0.15, glow)
    # сяючий тунель уздовж шляху
    var tube := MeshInstance3D.new()
    var tb := BoxMesh.new()
    tb.size = Vector3(1.5, 1.7, dist)
    tube.mesh = tb
    tube.material_override = aura
    tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(tube)
    tube.position = (a2 + b2) * 0.5
    tube.look_at(b2, Vector3.UP)
    # спалах світла
    var light := OmniLight3D.new()
    light.light_color = Color(0.5, 0.75, 1.0)
    light.omni_range = 9.0
    light.light_energy = 6.0
    light.shadow_enabled = false
    root.add_child(light)
    light.position = (a2 + b2) * 0.5 + Vector3(0.0, 0.5, 0.0)
    # іскри вздовж шляху
    var spark_mesh := SphereMesh.new()
    spark_mesh.radius = 0.06
    spark_mesh.height = 0.12
    spark_mesh.radial_segments = 6
    spark_mesh.rings = 3
    var sm := StandardMaterial3D.new()
    sm.albedo_color = Color(0.75, 0.92, 1.0)
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_mesh.material = sm
    var sp := CPUParticles3D.new()
    sp.mesh = spark_mesh
    sp.amount = 40
    sp.lifetime = 0.45
    sp.one_shot = true
    sp.explosiveness = 0.9
    sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    sp.emission_box_extents = Vector3(0.5, 0.7, dist * 0.5)
    sp.direction = Vector3.UP
    sp.spread = 180.0
    sp.initial_velocity_min = 1.0
    sp.initial_velocity_max = 3.5
    sp.gravity = Vector3.ZERO
    sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(sp)
    sp.position = (a2 + b2) * 0.5
    sp.look_at(b2, Vector3.UP)
    sp.emitting = true
    # згасання
    var tw := root.create_tween()
    tw.set_parallel(true)
    tw.tween_property(core, "albedo_color:a", 0.0, 0.35)
    tw.tween_property(glow, "albedo_color:a", 0.0, 0.4)
    tw.tween_property(aura, "albedo_color:a", 0.0, 0.3)
    tw.tween_property(tube, "scale", Vector3(0.1, 0.1, 1.0), 0.3)
    tw.tween_property(light, "light_energy", 0.0, 0.3)
    parent.get_tree().create_timer(0.8).timeout.connect(root.queue_free)
    burst(parent, a2, Color(0.6, 0.85, 1.0), 14, 6.0, 0.08)

# Коротка електрична дуга навколо героя (малюється під час ривку щокілька кадрів).
static func lightning_arc(parent: Node, center: Vector3, radius: float = 0.9) -> void:
    if _arc_mat == null:
        _arc_mat = StandardMaterial3D.new()
        _arc_mat.albedo_color = Color(0.78, 0.93, 1.0)
        _arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var root := Node3D.new()
    parent.add_child(root)
    var p := center + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
    for i in range(3):
        var q := p + Vector3(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7), randf_range(-1.0, 1.0)).normalized() * radius * randf_range(0.4, 0.8)
        q.y = maxf(q.y, 0.1)
        _seg_box(root, p, q, 0.05, _arc_mat)
        p = q
    parent.get_tree().create_timer(0.09).timeout.connect(root.queue_free)

# Удар блискавки по ворогові, якого зачепив ривок.
static func dash_hit(parent: Node, pos: Vector3) -> void:
    burst(parent, pos, Color(0.6, 0.85, 1.0), 12, 5.0, 0.07)
    lightning_arc(parent, pos, 1.2)
    lightning_arc(parent, pos, 1.0)


# ---------- Вибуховий стрибок ----------
# Міні-вибух при приземленні: розширюване вогняне кільце на землі, куля полум'я, дим, іскри й спалах світла.
static func jump_blast(parent: Node, pos: Vector3, radius: float) -> void:
    var root := Node3D.new()
    parent.add_child(root)
    root.position = Vector3(pos.x, 0.0, pos.z)
    # ударне кільце на землі (плоский диск, росте до повного радіуса)
    var ring_mat := _glow_mat(Color(1.0, 0.55, 0.15, 0.75))
    var ring := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 1.0
    cyl.bottom_radius = 1.0
    cyl.height = 0.12
    cyl.radial_segments = 32
    ring.mesh = cyl
    ring.material_override = ring_mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(ring)
    ring.position = Vector3(0.0, 0.08, 0.0)
    ring.scale = Vector3(0.3, 1.0, 0.3)
    # куля полум'я
    var ball_mat := _glow_mat(Color(1.0, 0.7, 0.2, 0.8))
    var ball := MeshInstance3D.new()
    var sph := SphereMesh.new()
    sph.radius = 1.0
    sph.height = 2.0
    sph.radial_segments = 20
    sph.rings = 10
    ball.mesh = sph
    ball.material_override = ball_mat
    ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(ball)
    ball.position = Vector3(0.0, 0.4, 0.0)
    ball.scale = Vector3.ONE * 0.3
    # спалах світла
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.6, 0.25)
    light.omni_range = radius * 2.0 + 4.0
    light.light_energy = 8.0
    light.shadow_enabled = false
    root.add_child(light)
    light.position = Vector3(0.0, 1.2, 0.0)
    var tw := root.create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
    tw.tween_property(ball, "scale", Vector3.ONE * maxf(radius * 0.55, 1.0), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(ball_mat, "albedo_color:a", 0.0, 0.35)
    tw.tween_property(light, "light_energy", 0.0, 0.35)
    parent.get_tree().create_timer(0.7).timeout.connect(root.queue_free)
    # вогняні іскри, шматки землі й дим (кількість росте з радіусом)
    var n := int(16.0 + radius * 5.0)
    burst(parent, pos + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.55, 0.12), n, 5.0 + radius, 0.1)
    burst(parent, pos + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.9, 0.4), n / 2, 8.0, 0.06)
    burst(parent, pos + Vector3(0.0, 0.2, 0.0), Color(0.25, 0.2, 0.18), n / 2, 3.0 + radius * 0.5, 0.16)
    explosion(parent, pos + Vector3(0.0, 0.3, 0.0), radius, Color(1.0, 0.5, 0.15))
