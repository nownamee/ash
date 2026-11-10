extends RefCounted

static func spawn(terrain: Node, kind: String, x: float, z: float, rng: RandomNumberGenerator) -> bool:
	match kind:
		"tide_stone": _tide_stone(terrain, x, z, rng)
		"wreck_boat": _wreck_boat(terrain, x, z, rng)
		"tide_chain": _tide_chain(terrain, x, z, rng)
		"tide_algae": _tide_algae(terrain, x, z, rng)
		"tide_piling": _tide_piling(terrain, x, z, rng)
		"tide_driftwood": _tide_driftwood(terrain, x, z, rng)
		"tide_buoy": _tide_buoy(terrain, x, z, rng)
		"abbey_stone": _abbey_stone(terrain, x, z, rng)
		"bell_frame": _bell_frame(terrain, x, z, rng)
		"bell_shrine": _bell_shrine(terrain, x, z, rng)
		"wax_candle": _wax_candle(terrain, x, z, rng)
		"torn_banner": _torn_banner(terrain, x, z, rng)
		"abbey_arch": _abbey_arch(terrain, x, z, rng)
		"obsidian": _obsidian(terrain, x, z, rng)
		"glass_spire": _glass_spire(terrain, x, z, rng)
		"glass_shards": _glass_shards(terrain, x, z, rng)
		"glass_arch": _glass_arch(terrain, x, z, rng)
		"glass_pillar": _glass_pillar(terrain, x, z, rng)
		"glass_crack": _glass_crack(terrain, x, z, rng)
		"iron_workshop": _iron_workshop(terrain, x, z, rng)
		"iron_gear": _iron_gear(terrain, x, z, rng)
		"iron_chain": _iron_chain(terrain, x, z, rng)
		"oil_barrel": _oil_barrel(terrain, x, z, rng)
		"forge_hearth": _forge_hearth(terrain, x, z, rng)
		"anvil": _anvil(terrain, x, z, rng)
		"iron_crate": _iron_crate(terrain, x, z, rng)
		_:
			return false
	return true

static func _begin(terrain: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	terrain.call("_begin", x, z, rng.randf() * TAU)

static func _part(terrain: Node, shape: String, pos: Vector3, size: Vector3, rot: Vector3, color: Color) -> void:
	terrain.call("_part", shape, pos, size, rot, color)

static func _box(terrain: Node, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	_part(terrain, "box", pos, size, rot, color)

static func _cyl(terrain: Node, pos: Vector3, size: Vector3, color: Color) -> void:
	_part(terrain, "cyl", pos, size, Vector3.ZERO, color)

static func _cone(terrain: Node, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	_part(terrain, "cone", pos, size, rot, color)

static func _tide_stone(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.105, 0.15, 0.16).lightened(rng.randf_range(0.0, 0.12))
	_part(t, "sphere", Vector3(0, 0.43, 0), Vector3(1.9, 0.92, 1.5), Vector3(0, rng.randf_range(-20, 20), 0), stone)
	_part(t, "sphere", Vector3(-0.48, 0.58, 0.16), Vector3(0.95, 0.82, 0.9), Vector3.ZERO, stone.lightened(0.08))
	_part(t, "sphere", Vector3(0.15, 0.88, -0.06), Vector3(1.25, 0.12, 0.9), Vector3(0, 15, 0), Color(0.11, 0.24, 0.20))
	t.call("_col_box", Vector3.ZERO, Vector3(1.35, 0.76, 1.12))

static func _wreck_boat(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var wood := Color(0.22, 0.14, 0.09)
	var wet := Color(0.12, 0.105, 0.08)
	_box(t, Vector3(0, 0.25, 0), Vector3(4.3, 0.42, 1.2), wood)
	_box(t, Vector3(0, 0.48, -0.67), Vector3(4.5, 0.48, 0.22), wet, Vector3(0, 0, -7))
	_box(t, Vector3(-0.1, 0.48, 0.67), Vector3(4.5, 0.48, 0.22), wet, Vector3(0, 0, 8))
	for i in range(5):
		var px := -1.7 + float(i) * 0.83
		_box(t, Vector3(px, 0.39, 0), Vector3(0.17, 0.5, 1.15), wood.lightened(rng.randf_range(-0.04, 0.12)), Vector3(0, 0, rng.randf_range(-8, 8)))
	_box(t, Vector3(0.3, 1.1, -0.1), Vector3(0.16, 2.0, 0.16), Color(0.18, 0.12, 0.08), Vector3(0, 0, 18))
	_box(t, Vector3(1.1, 1.75, -0.12), Vector3(1.55, 0.13, 0.14), Color(0.24, 0.16, 0.10), Vector3(0, 0, -28))
	t.call("_col_box", Vector3.ZERO, Vector3(4.4, 0.72, 1.55))

static func _tide_chain(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var iron := Color(0.16, 0.18, 0.17)
	for side in [-1.0, 1.0]:
		_cyl(t, Vector3(side * 1.8, 0.65, 0), Vector3(0.26, 1.3, 0.26), Color(0.20, 0.16, 0.12))
		t.call("_col_cyl", Vector3(side * 1.8, 0, 0), 0.18, 1.2)
	for i in range(9):
		var f := float(i) / 8.0
		var y := 0.92 - sin(f * PI) * 0.43
		_box(t, Vector3(lerpf(-1.72, 1.72, f), y, 0), Vector3(0.3, 0.09, 0.09), iron, Vector3(0, 0, rng.randf_range(-18, 18)))

static func _tide_algae(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	for i in range(rng.randi_range(3, 6)):
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0.035 + rng.randf() * 0.02, rng.randf_range(-0.8, 0.8))
		var s := rng.randf_range(0.4, 1.0)
		_part(t, "sphere", p, Vector3(1.5, 0.1, 0.75) * s, Vector3(0, rng.randf_range(-35, 35), 0), Color(0.10, 0.23, 0.17).lightened(rng.randf_range(0.0, 0.12)))

static func _tide_piling(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var wood := Color(0.20, 0.135, 0.085)
	for p in [Vector3(-0.9, 1.15, -0.62), Vector3(0.9, 0.85, -0.62), Vector3(-0.65, 1.0, 0.68), Vector3(0.85, 1.25, 0.62)]:
		_cyl(t, p, Vector3(0.38, p.y * 2.0, 0.38), wood.lightened(rng.randf_range(0.0, 0.1)))
	_box(t, Vector3(0, 1.2, 0), Vector3(2.4, 0.2, 0.18), wood)
	t.call("_col_box", Vector3.ZERO, Vector3(1.8, 1.5, 1.45))

static func _tide_driftwood(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var wood := Color(0.25, 0.17, 0.105)
	_box(t, Vector3(0, 0.25, 0), Vector3(3.2, 0.36, 0.42), wood, Vector3(0, 0, rng.randf_range(-12, 12)))
	_box(t, Vector3(-0.25, 0.38, 0.22), Vector3(1.7, 0.26, 0.26), wood.lightened(0.12), Vector3(0, rng.randf_range(-20, 20), -17))
	_box(t, Vector3(0.95, 0.3, -0.18), Vector3(0.9, 0.2, 0.2), wood.darkened(0.12), Vector3(0, 12, 12))
	t.call("_col_box", Vector3.ZERO, Vector3(2.8, 0.5, 0.55))

static func _tide_buoy(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	_cyl(t, Vector3(0, 0.28, 0), Vector3(0.65, 0.56, 0.65), Color(0.22, 0.16, 0.11))
	_part(t, "sphere", Vector3(0, 0.86, 0), Vector3(0.72, 0.75, 0.72), Vector3.ZERO, Color(0.42, 0.18, 0.10))
	_cyl(t, Vector3(0, 1.48, 0), Vector3(0.12, 0.55, 0.12), Color(0.20, 0.18, 0.13))
	_part(t, "sphere", Vector3(0, 1.79, 0), Vector3(0.2, 0.2, 0.2), Vector3.ZERO, Color(0.72, 0.48, 0.22))
	t.call("_col_cyl", Vector3.ZERO, 0.45, 1.35)

static func _abbey_stone(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.36, 0.36, 0.34)
	_box(t, Vector3(0, 0.28, 0), Vector3(2.2, 0.55, 1.2), stone)
	_box(t, Vector3(-0.35, 0.76, -0.1), Vector3(1.3, 0.42, 0.88), stone.lightened(0.07), Vector3(0, 12, 0))
	_box(t, Vector3(0.72, 0.64, 0.2), Vector3(0.82, 0.32, 0.76), stone.darkened(0.08), Vector3(0, -18, 0))
	t.call("_col_box", Vector3.ZERO, Vector3(1.8, 0.95, 1.0))

static func _bell_frame(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var wood := Color(0.25, 0.17, 0.105)
	for side in [-1.0, 1.0]:
		_cyl(t, Vector3(side * 1.65, 1.7, 0), Vector3(0.34, 3.4, 0.34), wood)
		_box(t, Vector3(side * 1.65, 1.8, 0), Vector3(0.52, 3.5, 0.52), wood.darkened(0.08))
		t.call("_col_box", Vector3(side * 1.65, 0, 0), Vector3(0.48, 3.25, 0.48))
	_box(t, Vector3(0, 3.42, 0), Vector3(3.7, 0.42, 0.48), wood.lightened(0.05))
	_cyl(t, Vector3(0, 2.92, 0), Vector3(0.62, 0.55, 0.62), Color(0.43, 0.31, 0.12))
	_cone(t, Vector3(0, 2.57, 0), Vector3(0.92, 0.82, 0.92), Color(0.49, 0.36, 0.14), Vector3(180, 0, 0))
	_part(t, "sphere", Vector3(0, 2.3, 0), Vector3(0.72, 0.48, 0.72), Vector3.ZERO, Color(0.52, 0.38, 0.15))
	_cyl(t, Vector3(0, 2.13, 0), Vector3(0.13, 0.35, 0.13), Color(0.24, 0.20, 0.12))

static func _bell_shrine(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.34, 0.34, 0.33)
	_box(t, Vector3(0, 0.22, 0), Vector3(3.4, 0.42, 2.4), stone.darkened(0.12))
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 1.35, 1.55, -0.75), Vector3(0.58, 2.7, 0.62), stone)
		_box(t, Vector3(side * 1.35, 1.4, 0.75), Vector3(0.58, 2.4, 0.62), stone.darkened(0.06))
		_cyl(t, Vector3(side * 1.35, 3.0, 0), Vector3(0.55, 0.65, 0.55), Color(0.44, 0.32, 0.13))
		_cone(t, Vector3(side * 1.35, 2.61, 0), Vector3(0.82, 0.74, 0.82), Color(0.50, 0.37, 0.15), Vector3(180, 0, 0))
		for zside in [-1.0, 1.0]:
			t.call("_col_box", Vector3(side * 1.35, 0, zside * 0.75), Vector3(0.56, 2.4, 0.58))
	_box(t, Vector3(0, 2.92, -0.72), Vector3(3.35, 0.48, 0.7), stone.lightened(0.08))
	_box(t, Vector3(0, 2.75, 0.76), Vector3(3.35, 0.32, 0.6), stone)

static func _wax_candle(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	for i in range(3):
		var px := float(i - 1) * 0.42
		var h := rng.randf_range(0.42, 0.9)
		_cyl(t, Vector3(px, h * 0.5, 0), Vector3(0.22, h, 0.22), Color(0.66, 0.61, 0.47).lightened(rng.randf_range(0.0, 0.1)))
		_box(t, Vector3(px, h + 0.04, 0), Vector3(0.035, 0.14, 0.035), Color(0.16, 0.12, 0.08))
		_cone(t, Vector3(px, h + 0.16, 0), Vector3(0.12, 0.22, 0.12), Color(0.72, 0.41, 0.14))

static func _torn_banner(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	_cyl(t, Vector3(0, 1.9, 0), Vector3(0.12, 3.8, 0.12), Color(0.24, 0.17, 0.11))
	var cloth := Color(0.34, 0.16, 0.13).lightened(rng.randf_range(0.0, 0.12))
	_box(t, Vector3(0.58, 2.55, 0), Vector3(1.05, 1.15, 0.09), cloth, Vector3(0, 0, -5))
	_box(t, Vector3(0.46, 1.98, 0.02), Vector3(0.62, 0.35, 0.08), cloth.darkened(0.08), Vector3(0, 0, 9))
	_cyl(t, Vector3(0.55, 3.18, 0), Vector3(0.08, 1.35, 0.08), Color(0.31, 0.22, 0.14))
	t.call("_col_cyl", Vector3.ZERO, 0.09, 3.5)

static func _abbey_arch(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.39, 0.39, 0.37)
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 1.6, 1.65, 0), Vector3(0.78, 3.3, 0.82), stone)
		_box(t, Vector3(side * 1.6, 3.35, 0), Vector3(1.0, 0.32, 1.0), stone.lightened(0.08))
		t.call("_col_box", Vector3(side * 1.6, 0, 0), Vector3(0.8, 3.1, 0.8))
	_box(t, Vector3(0, 3.65, 0), Vector3(4.0, 0.68, 0.9), stone)
	_box(t, Vector3(-0.72, 4.0, 0), Vector3(1.2, 0.34, 1.0), stone.darkened(0.08), Vector3(0, 0, 8))

static func _obsidian(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	_cone(t, Vector3(0, 0.82, 0), Vector3(1.7, 1.75, 1.55), Color(0.075, 0.045, 0.10))
	_cone(t, Vector3(-0.48, 0.42, 0.2), Vector3(0.86, 0.95, 0.78), Color(0.14, 0.09, 0.17), Vector3(0, 0, -18))
	_cone(t, Vector3(0.5, 0.34, -0.15), Vector3(0.76, 0.72, 0.7), Color(0.045, 0.04, 0.07), Vector3(0, 0, 14))
	_box(t, Vector3(0.1, 0.82, -0.55), Vector3(0.09, 1.1, 0.06), Color(0.34, 0.28, 0.40), Vector3(0, 0, 20))
	t.call("_col_box", Vector3.ZERO, Vector3(1.2, 1.1, 1.0))

static func _glass_spire(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var violet := Color(0.16, 0.085, 0.24)
	_cone(t, Vector3(0, 2.1, 0), Vector3(1.65, 4.2, 1.5), violet)
	_cone(t, Vector3(-0.52, 1.16, 0.14), Vector3(0.86, 2.3, 0.78), Color(0.23, 0.12, 0.32), Vector3(0, 0, 9))
	_cone(t, Vector3(0.56, 0.92, -0.18), Vector3(0.72, 1.85, 0.7), Color(0.09, 0.07, 0.14), Vector3(0, 0, -12))
	_box(t, Vector3(0.28, 1.75, -0.53), Vector3(0.07, 2.3, 0.06), Color(0.48, 0.42, 0.56), Vector3(0, 0, 12))
	t.call("_col_cyl", Vector3.ZERO, 0.72, 3.0)

static func _glass_shards(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	for i in range(5):
		var a := TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
		var h := rng.randf_range(0.45, 1.45)
		var p := Vector3(cos(a) * rng.randf_range(0.25, 0.8), h * 0.5, sin(a) * rng.randf_range(0.25, 0.8))
		_cone(t, p, Vector3(rng.randf_range(0.3, 0.65), h, rng.randf_range(0.3, 0.65)), Color(0.17, 0.09, 0.24).lightened(rng.randf_range(0.0, 0.14)), Vector3(0, 0, rng.randf_range(-12, 12)))

static func _glass_arch(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var violet := Color(0.17, 0.10, 0.25)
	for side in [-1.0, 1.0]:
		_cone(t, Vector3(side * 1.55, 1.85, 0), Vector3(1.05, 3.7, 0.95), violet)
		_box(t, Vector3(side * 1.55, 1.55, 0), Vector3(0.54, 3.0, 0.52), violet.darkened(0.1))
		t.call("_col_box", Vector3(side * 1.55, 0, 0), Vector3(0.72, 2.8, 0.72))
	_box(t, Vector3(0, 3.58, 0), Vector3(3.7, 0.52, 0.68), Color(0.21, 0.12, 0.3))
	_box(t, Vector3(0.12, 3.83, -0.36), Vector3(1.7, 0.08, 0.05), Color(0.54, 0.45, 0.62), Vector3(0, 0, 7))

static func _glass_pillar(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var c := Color(0.12, 0.075, 0.18)
	_cone(t, Vector3(0, 1.82, 0), Vector3(1.35, 3.65, 1.25), c)
	_cone(t, Vector3(0.32, 3.03, 0.03), Vector3(0.72, 2.05, 0.65), c.lightened(0.12), Vector3(0, 0, 9))
	_box(t, Vector3(-0.25, 1.8, -0.47), Vector3(0.08, 2.0, 0.06), Color(0.48, 0.42, 0.56), Vector3(0, 0, -8))
	t.call("_col_cyl", Vector3.ZERO, 0.62, 2.8)

static func _glass_crack(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	for i in range(5):
		var px := -1.45 + float(i) * 0.7
		_box(t, Vector3(px, 0.035, rng.randf_range(-0.2, 0.2)), Vector3(rng.randf_range(0.5, 1.1), 0.06, 0.075), Color(0.20, 0.10, 0.28), Vector3(0, rng.randf_range(-18, 18), rng.randf_range(-3, 3)))
	_box(t, Vector3(0.3, 0.075, -0.08), Vector3(0.65, 0.05, 0.04), Color(0.50, 0.42, 0.58), Vector3(0, 28, 0))

static func _iron_workshop(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.29, 0.22, 0.17)
	var wood := Color(0.24, 0.15, 0.09)
	_box(t, Vector3(0, 0.08, 0), Vector3(5.8, 0.16, 5.0), Color(0.24, 0.19, 0.15))
	_box(t, Vector3(0, 1.22, -2.3), Vector3(5.6, 2.4, 0.4), stone)
	_box(t, Vector3(-2.7, 1.2, 0), Vector3(0.42, 2.35, 4.3), stone.darkened(0.06))
	_box(t, Vector3(2.7, 1.2, 0), Vector3(0.42, 2.35, 4.3), stone)
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 2.35, 1.15, 2.05), Vector3(0.38, 2.2, 0.4), wood)
		_box(t, Vector3(side * 2.55, 2.62, -0.05), Vector3(0.18, 0.2, 4.6), wood.lightened(0.08), Vector3(0, 0, side * 12))
	_box(t, Vector3(0, 2.55, 2.15), Vector3(5.0, 0.24, 0.28), wood)
	_box(t, Vector3(-0.8, 3.0, 0), Vector3(0.18, 0.18, 5.1), wood, Vector3(0, 0, -8))
	_box(t, Vector3(1.0, 3.05, -0.15), Vector3(0.18, 0.18, 4.8), wood, Vector3(0, 0, 9))
	t.call("_col_box", Vector3(0, 0, -2.3), Vector3(5.4, 2.2, 0.42))
	t.call("_col_box", Vector3(-2.7, 0, 0), Vector3(0.45, 2.1, 4.1))
	t.call("_col_box", Vector3(2.7, 0, 0), Vector3(0.45, 2.1, 4.1))
	for side in [-1.0, 1.0]:
		t.call("_col_box", Vector3(side * 2.35, 0, 2.05), Vector3(0.42, 2.0, 0.42))

static func _iron_gear(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var iron := Color(0.33, 0.20, 0.12)
	_cyl(t, Vector3(0, 0.2, 0), Vector3(2.05, 0.3, 2.05), iron)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		_box(t, Vector3(cos(a) * 1.12, 0.22, sin(a) * 1.12), Vector3(0.42, 0.32, 0.38), iron.lightened(0.04), Vector3(0, rad_to_deg(a), 0))
	_cyl(t, Vector3(0, 0.4, 0), Vector3(0.78, 0.45, 0.78), Color(0.22, 0.14, 0.09))
	_cyl(t, Vector3(0, 0.66, 0), Vector3(0.24, 0.12, 0.24), Color(0.46, 0.31, 0.17))
	t.call("_col_cyl", Vector3.ZERO, 1.3, 0.55)

static func _iron_chain(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var iron := Color(0.20, 0.19, 0.16)
	for i in range(13):
		var f := float(i) / 12.0
		var px := lerpf(-2.0, 2.0, f)
		var pz := sin(f * PI * 2.0) * 0.22
		_box(t, Vector3(px, 0.08, pz), Vector3(0.34, 0.12, 0.12), iron, Vector3(0, rng.randf_range(-20, 20), rng.randf_range(-12, 12)))

static func _oil_barrel(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var rust := Color(0.39, 0.19, 0.095).lightened(rng.randf_range(0.0, 0.08))
	_cyl(t, Vector3(0, 0.58, 0), Vector3(0.92, 1.16, 0.92), rust)
	for y in [0.3, 0.82]:
		_cyl(t, Vector3(0, y, 0), Vector3(0.99, 0.1, 0.99), Color(0.20, 0.17, 0.14))
	_cyl(t, Vector3(0, 1.19, 0), Vector3(0.87, 0.08, 0.87), Color(0.17, 0.13, 0.10))
	t.call("_col_cyl", Vector3.ZERO, 0.48, 1.1)

static func _forge_hearth(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var stone := Color(0.28, 0.24, 0.20)
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 0.88, 0.42, 0), Vector3(0.42, 0.84, 1.9), stone)
		_box(t, Vector3(side * 0.48, 0.34, -0.8), Vector3(0.42, 0.68, 0.35), stone.lightened(0.06))
	_box(t, Vector3(0, 0.16, 0.7), Vector3(1.8, 0.32, 0.4), stone.darkened(0.1))
	_part(t, "sphere", Vector3(0, 0.14, -0.1), Vector3(0.78, 0.16, 0.7), Vector3.ZERO, Color(0.40, 0.13, 0.045))
	_part(t, "sphere", Vector3(0.08, 0.2, -0.05), Vector3(0.32, 0.28, 0.24), Vector3.ZERO, Color(0.67, 0.29, 0.055))
	t.call("_col_box", Vector3(-0.88, 0, 0), Vector3(0.42, 0.8, 1.8))
	t.call("_col_box", Vector3(0.88, 0, 0), Vector3(0.42, 0.8, 1.8))

static func _anvil(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var iron := Color(0.29, 0.27, 0.24)
	_box(t, Vector3(0, 0.24, 0), Vector3(0.76, 0.48, 0.7), Color(0.24, 0.16, 0.105))
	_box(t, Vector3(0, 0.62, 0), Vector3(1.25, 0.38, 0.72), iron)
	_box(t, Vector3(0.78, 0.67, 0), Vector3(0.65, 0.22, 0.42), iron.lightened(0.1), Vector3(0, 0, -8))
	_box(t, Vector3(0, 0.94, 0), Vector3(1.05, 0.18, 0.62), iron.lightened(0.12))
	t.call("_col_box", Vector3.ZERO, Vector3(1.15, 0.9, 0.65))

static func _iron_crate(t: Node, x: float, z: float, rng: RandomNumberGenerator) -> void:
	_begin(t, x, z, rng)
	var wood := Color(0.25, 0.16, 0.095)
	_box(t, Vector3(0, 0.48, 0), Vector3(1.2, 0.92, 1.1), wood)
	for side in [-1.0, 1.0]:
		_box(t, Vector3(side * 0.62, 0.48, 0), Vector3(0.1, 1.0, 1.16), Color(0.34, 0.21, 0.11))
		_box(t, Vector3(0, 0.48, side * 0.57), Vector3(1.25, 1.0, 0.1), Color(0.34, 0.21, 0.11))
	_box(t, Vector3(0, 0.49, -0.59), Vector3(1.3, 0.12, 0.12), Color(0.25, 0.22, 0.17))
	_box(t, Vector3(0, 0.49, 0.59), Vector3(1.3, 0.12, 0.12), Color(0.25, 0.22, 0.17))
	t.call("_col_box", Vector3.ZERO, Vector3(1.15, 0.95, 1.05))
