extends Node3D

signal destroyed(target: Node3D)

const Fx = preload("res://effects.gd")

const BURN_INTERVAL := 0.5
const BURN_DURATION := 3.0

var kind := "bell"
var hp := 140.0
var max_hp := 140.0
var radius := 0.9
var size := 1.0
var dying := false
var data: Dictionary = {"boss": false}
var label_text := ""
var color := Color.WHITE

var _model_root: Node3D
var _base_ring: MeshInstance3D
var _label: Label3D
var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D
var _burn_dps := 0.0
var _burn_left := 0.0
var _burn_clock := 0.0
var _burn_weapon := ""
var _slow_left := 0.0
var _freeze_left := 0.0

func _ready() -> void:
	add_to_group("attackable")
	max_hp = maxf(max_hp, 1.0)
	hp = clampf(hp, 0.0, max_hp)
	_build_model()
	_build_base_ring()
	_build_hud()
	_update_health_bar()

func _process(delta: float) -> void:
	if dying:
		return
	_slow_left = maxf(0.0, _slow_left - delta)
	_freeze_left = maxf(0.0, _freeze_left - delta)
	_update_burn(delta)

func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO, _knock_power: float = 8.0, crit: bool = false, _weapon: String = "") -> void:
	if dying or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_update_health_bar()
	if is_inside_tree():
		var text_color := Color(1.0, 0.4, 0.15) if crit else Color(1.0, 0.9, 0.45)
		Fx.damage_text(get_parent(), global_position + Vector3(0.0, 2.0 * size, 0.0), str(int(round(amount))), text_color)
	if hp <= 0.0:
		_destroy()

func ignite(dps: float, weapon: String = "") -> void:
	if dying or dps <= 0.0:
		return
	if _burn_left <= 0.0:
		_burn_clock = 0.0
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, BURN_DURATION)
	_burn_weapon = weapon

func apply_slow(secs: float, _mult: float) -> void:
	if not dying:
		_slow_left = maxf(_slow_left, secs)

func apply_freeze(secs: float) -> void:
	if not dying:
		_freeze_left = maxf(_freeze_left, secs)

func _update_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	var active_delta := minf(delta, _burn_left)
	_burn_left -= active_delta
	_burn_clock += active_delta
	while _burn_clock >= BURN_INTERVAL or (_burn_left <= 0.0 and _burn_clock > 0.0):
		var tick_duration := minf(BURN_INTERVAL, _burn_clock)
		_burn_clock -= tick_duration
		take_damage(_burn_dps * tick_duration, Vector3.ZERO, 0.0, false, _burn_weapon)
		if dying:
			return
	if _burn_left <= 0.0:
		_burn_dps = 0.0
		_burn_clock = 0.0
		_burn_weapon = ""

func _destroy() -> void:
	if dying:
		return
	dying = true
	hp = 0.0
	_burn_left = 0.0
	remove_from_group("attackable")
	_model_root.visible = false
	_base_ring.visible = false
	_label.visible = false
	_bar_bg.visible = false
	_bar_fg.visible = false
	destroyed.emit(self)

func _main_color() -> Color:
	if color != Color.WHITE:
		return color
	match kind:
		"bell":
			return Color(0.86, 0.65, 0.2)
		"mirror":
			return Color(0.25, 0.72, 0.94)
		"nest":
			return Color(0.48, 0.67, 0.3)
		_:
			return Color(0.9, 0.38, 0.16)

func _build_model() -> void:
	if is_instance_valid(_model_root):
		_model_root.queue_free()
	_model_root = Node3D.new()
	_model_root.scale = Vector3.ONE * maxf(size, 0.1)
	add_child(_model_root)
	var main := _main_color()
	var dark := main.darkened(0.55)
	var light := main.lightened(0.3)
	match kind:
		"bell":
			_add_cylinder(_model_root, 0.16, 0.2, 0.24, Vector3(0.0, 1.42, 0.0), dark)
			_add_cylinder(_model_root, 0.34, 0.64, 0.82, Vector3(0.0, 0.91, 0.0), main)
			_add_cylinder(_model_root, 0.67, 0.67, 0.12, Vector3(0.0, 0.48, 0.0), light)
			_add_sphere(_model_root, 0.14, Vector3(0.0, 0.31, 0.0), light)
			_add_box(_model_root, Vector3(0.54, 0.12, 0.16), dark, Vector3(0.0, 1.55, 0.0))
		"mirror":
			_add_box(_model_root, Vector3(1.1, 1.65, 0.16), dark, Vector3(0.0, 1.03, 0.0))
			_add_box(_model_root, Vector3(0.82, 1.34, 0.045), light, Vector3(0.0, 1.03, -0.105))
			_add_box(_model_root, Vector3(0.12, 1.65, 0.12), main, Vector3(-0.52, 1.03, -0.16))
			_add_box(_model_root, Vector3(0.12, 1.65, 0.12), main, Vector3(0.52, 1.03, -0.16))
			_add_box(_model_root, Vector3(1.12, 0.13, 0.12), main, Vector3(0.0, 1.79, -0.16))
			_add_box(_model_root, Vector3(1.12, 0.13, 0.12), main, Vector3(0.0, 0.27, -0.16))
			_add_cylinder(_model_root, 0.35, 0.55, 0.2, Vector3(0.0, 0.1, 0.0), dark)
		"nest":
			_add_sphere(_model_root, 0.58, Vector3(0.0, 0.53, 0.0), dark, Vector3(1.3, 0.68, 1.0))
			_add_sphere(_model_root, 0.32, Vector3(0.0, 0.9, -0.02), light, Vector3(1.0, 1.35, 0.85))
			_add_sphere(_model_root, 0.2, Vector3(-0.35, 0.72, 0.18), main, Vector3(1.0, 1.3, 0.9))
			_add_sphere(_model_root, 0.2, Vector3(0.36, 0.68, 0.15), main, Vector3(1.0, 1.3, 0.9))
			_add_cone(_model_root, 0.15, 0.65, dark, Vector3(-0.43, 0.72, -0.08), Vector3(0.0, 0.0, 28.0))
			_add_cone(_model_root, 0.15, 0.65, dark, Vector3(0.44, 0.7, -0.08), Vector3(0.0, 0.0, -28.0))
		_:
			_add_cylinder(_model_root, 0.45, 0.68, 0.28, Vector3(0.0, 0.2, 0.0), dark)
			_add_torus(_model_root, 0.55, 0.66, Vector3(0.0, 1.05, 0.0), light, Vector3(90.0, 0.0, 0.0))
			_add_sphere(_model_root, 0.34, Vector3(0.0, 1.05, 0.0), light, Vector3(1.0, 1.25, 1.0), 0.8)
			for i in range(3):
				var angle := TAU * float(i) / 3.0
				var pos := Vector3(cos(angle) * 0.62, 0.78, sin(angle) * 0.62)
				_add_cylinder(_model_root, 0.09, 0.13, 0.9, pos, main)

func _build_base_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.84
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8
	_base_ring = MeshInstance3D.new()
	_base_ring.mesh = mesh
	_base_ring.material_override = _material(_main_color().lightened(0.18), 0.35, 0.2)
	_base_ring.scale = Vector3(radius, maxf(radius * 0.32, 0.1), radius)
	_base_ring.position.y = 0.08
	_base_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_base_ring)

func _build_hud() -> void:
	_label = Label3D.new()
	_label.text = label_text if label_text != "" else _kind_label()
	_label.font_size = 36
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = _main_color().lightened(0.35)
	_label.outline_size = 7
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.position.y = 2.55 * size
	add_child(_label)

	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.5, 0.13)
	_bar_bg = MeshInstance3D.new()
	_bar_bg.mesh = bg_mesh
	_bar_bg.material_override = _material(Color(0.02, 0.02, 0.03, 0.88), 1.0)
	_bar_bg.position.y = 2.2 * size
	_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar_bg)

	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(1.5, 0.09)
	_bar_fg = MeshInstance3D.new()
	_bar_fg.mesh = fg_mesh
	_bar_fg.material_override = _material(Color(0.2, 0.85, 0.35), 1.0, 0.15)
	_bar_fg.position.y = 2.2 * size
	_bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar_fg)

func _update_health_bar() -> void:
	if not is_instance_valid(_bar_bg) or not is_instance_valid(_bar_fg):
		return
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var width := maxf(0.001, 1.5 * ratio)
	(_bar_fg.mesh as QuadMesh).size = Vector2(width, 0.09)
	_bar_fg.position.x = -(1.5 - width) * 0.5
	var mat := _bar_fg.material_override as StandardMaterial3D
	mat.albedo_color = Color(0.2, 0.85, 0.35).lerp(Color(0.9, 0.12, 0.08), 1.0 - ratio)

func _kind_label() -> String:
	match kind:
		"bell":
			return "ДЗВІН"
		"mirror":
			return "ДЗЕРКАЛО"
		"nest":
			return "ГНІЗДО"
		_:
			return "ЯДРО"

func _material(tint: Color, roughness: float = 0.7, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = emission
	return mat

func _add_mesh(parent: Node3D, mesh: Mesh, tint: Color, pos: Vector3, mat_roughness: float = 0.7, emission: float = 0.0, rot_deg: Vector3 = Vector3.ZERO, mesh_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(tint, mat_roughness, emission)
	instance.position = pos
	instance.rotation_degrees = rot_deg
	instance.scale = mesh_scale
	parent.add_child(instance)
	return instance

func _add_box(parent: Node3D, dimensions: Vector3, tint: Color, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_mesh(parent, mesh, tint, pos)

func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, tint: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	_add_mesh(parent, mesh, tint, pos)

func _add_sphere(parent: Node3D, sphere_radius: float, pos: Vector3, tint: Color, mesh_scale: Vector3 = Vector3.ONE, emission: float = 0.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = sphere_radius
	mesh.height = sphere_radius * 2.0
	_add_mesh(parent, mesh, tint, pos, 0.42, emission, Vector3.ZERO, mesh_scale)

func _add_cone(parent: Node3D, base_radius: float, height: float, tint: Color, pos: Vector3, rot_deg: Vector3) -> void:
	var mesh := ConeMesh.new()
	mesh.bottom_radius = base_radius
	mesh.height = height
	_add_mesh(parent, mesh, tint, pos, 0.88, 0.0, rot_deg)

func _add_torus(parent: Node3D, inner_radius: float, outer_radius: float, pos: Vector3, tint: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	_add_mesh(parent, mesh, tint, pos, 0.36, 0.2, rot_deg)
