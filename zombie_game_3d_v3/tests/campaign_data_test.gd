extends SceneTree

const Locations = preload("res://locations.gd")
const Biomes = preload("res://biomes.gd")
const ZombieTypes = preload("res://zombie_types.gd")

const LEGACY_LOCATION_COUNT := 27
const LOCATION_COUNT := 47
const MAX_CAMPAIGN_ALIVE := 64

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var baseline := _load_baseline_locations()
	_check(baseline.size() == LEGACY_LOCATION_COUNT, "96.zip baseline contains 27 locations")
	_check(Locations.DATA.size() == LOCATION_COUNT, "campaign has exactly 47 locations")
	_check(baseline.size() == LEGACY_LOCATION_COUNT and Locations.DATA.size() >= LEGACY_LOCATION_COUNT, "legacy prefix is available")
	if baseline.size() == LEGACY_LOCATION_COUNT and Locations.DATA.size() >= LEGACY_LOCATION_COUNT:
		for i in range(LEGACY_LOCATION_COUNT):
			_check(_without_text(Locations.DATA[i]) == _without_text(baseline[i]), "loc%d matches its 96.zip record except player-facing text" % (i + 1))

	_test_ids_and_campaigns()
	_test_biomes_bosses_and_pools()
	_test_wave_plans(baseline)
	_test_unlocks()
	_test_map_icons_and_bounds()

	if failures == 0:
		print("PASS: %d campaign data checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d campaign data checks failed" % [failures, checks])
		quit(1)

func _without_text(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			if key == "name" or key == "desc" or key == "msg":
				continue
			out[key] = _without_text(value[key])
		return out
	if value is Array:
		var items := []
		for item in value:
			items.append(_without_text(item))
		return items
	return value

func _load_baseline_locations() -> Array:
	var zip := ZIPReader.new()
	var archive_path := ProjectSettings.globalize_path("res://../96.zip")
	var open_error := zip.open(archive_path)
	_check(open_error == OK, "open 96.zip baseline at %s" % archive_path)
	if open_error != OK:
		return []
	var source := zip.read_file("zombie_game_3d_v3/locations.gd").get_string_from_utf8()
	zip.close()
	_check(not source.is_empty(), "read baseline locations.gd from 96.zip")
	if source.is_empty():
		return []
	var baseline_script := GDScript.new()
	baseline_script.source_code = source
	var parse_error := baseline_script.reload()
	_check(parse_error == OK, "compile baseline locations.gd from 96.zip")
	if parse_error != OK:
		return []
	var data: Variant = baseline_script.get_script_constant_map().get("DATA", [])
	if typeof(data) != TYPE_ARRAY:
		_check(false, "baseline DATA is an array")
		return []
	return data

func _test_ids_and_campaigns() -> void:
	_check(Locations.DATA.size() == LOCATION_COUNT, "all campaign IDs can be checked")
	if Locations.DATA.size() != LOCATION_COUNT:
		return
	var seen := {}
	var campaigns := ["tide", "bells", "glass", "iron"]
	var campaign_biomes := {"tide": Biomes.TIDE, "bells": Biomes.BELLS, "glass": Biomes.GLASS, "iron": Biomes.IRON}
	for i in range(Locations.DATA.size()):
		var loc: Dictionary = Locations.DATA[i]
		var expected_id := "loc%d" % (i + 1)
		var id := String(loc.get("id", ""))
		_check(id == expected_id, "%s is in the expected sequence position" % expected_id)
		_check(not seen.has(id), "%s is unique" % id)
		seen[id] = true
		_check(not bool(loc.get("wip", false)), "%s is not marked WIP" % id)
		if i < LEGACY_LOCATION_COUNT:
			continue
		var offset := i - LEGACY_LOCATION_COUNT
		var campaign := String(campaigns[offset / 5])
		var stage := offset % 5 + 1
		var expected_parent := "loc27" if stage == 1 else "loc%d" % i
		_check(String(loc.get("campaign", "")) == campaign, "%s belongs to %s" % [id, campaign])
		_check(int(loc.get("stage", 0)) == stage, "%s is campaign stage %d" % [id, stage])
		_check(int(loc.get("biome", -1)) == int(campaign_biomes[campaign]), "%s uses the %s biome index" % [id, campaign])
		_check(loc.get("req", []) == [expected_parent], "%s unlocks from %s only" % [id, expected_parent])

func _test_biomes_bosses_and_pools() -> void:
	_check(Biomes.DATA.size() == 15, "all 15 biome records are present")
	_check(ZombieTypes.POOLS.size() == Biomes.DATA.size(), "each biome has a zombie pool")
	for loc in Locations.DATA:
		var id := String(loc.get("id", "?"))
		var biome := int(loc.get("biome", -1))
		var second := int(loc.get("second", -1))
		_check(biome >= 0 and biome < Biomes.DATA.size(), "%s has a valid biome index" % id)
		_check(second == -1 or (second >= 0 and second < Biomes.DATA.size()), "%s has a valid secondary biome index" % id)
		var boss_id := String(loc.get("boss", ""))
		_check(ZombieTypes.DATA.has(boss_id), "%s boss %s exists" % [id, boss_id])
		if ZombieTypes.DATA.has(boss_id):
			_check(bool(ZombieTypes.DATA[boss_id].get("boss", false)), "%s boss %s is marked as a boss type" % [id, boss_id])
	for biome_index in range(ZombieTypes.POOLS.size()):
		for entry in ZombieTypes.POOLS[biome_index]:
			_check(entry.size() >= 4, "biome %d pool entry has all fields" % biome_index)
			if entry.size() < 4:
				continue
			_check(ZombieTypes.DATA.has(String(entry[0])), "biome %d pool type %s exists" % [biome_index, String(entry[0])])

func _test_wave_plans(baseline: Array) -> void:
	var legacy_wave_cap := 0
	for loc in baseline:
		for wave in loc.get("wave_plan", []):
			if wave is Dictionary:
				legacy_wave_cap = maxi(legacy_wave_cap, int(wave.get("w", 0)))
	_check(legacy_wave_cap > 0, "legacy wave plans provide a strength cap")
	for i in range(Locations.DATA.size()):
		var loc: Dictionary = Locations.DATA[i]
		if not loc.has("wave_plan"):
			continue
		var id := String(loc.get("id", "?"))
		var plan: Array = loc["wave_plan"]
		_check(plan.size() == int(loc.get("waves", -1)), "%s wave count matches its plan" % id)
		for wave_index in range(plan.size()):
			var wave: Dictionary = plan[wave_index]
			for field in ["count", "eff", "w", "hp", "dmg", "spd", "interval", "alive"]:
				_check(wave.has(field), "%s wave %d defines %s" % [id, wave_index + 1, field])
			_check(int(wave.get("count", 0)) > 0, "%s wave %d has a positive count" % [id, wave_index + 1])
			_check(int(wave.get("alive", 0)) > 0, "%s wave %d has a positive alive cap" % [id, wave_index + 1])
			if i >= LEGACY_LOCATION_COUNT:
				_check(int(wave.get("w", legacy_wave_cap + 1)) <= legacy_wave_cap, "%s wave %d does not exceed legacy wave strength" % [id, wave_index + 1])
				_check(int(wave.get("alive", MAX_CAMPAIGN_ALIVE + 1)) <= MAX_CAMPAIGN_ALIVE, "%s wave %d alive cap is at most %d" % [id, wave_index + 1, MAX_CAMPAIGN_ALIVE])

func _test_unlocks() -> void:
	var source := FileAccess.get_file_as_string("res://game_state.gd")
	_check(source.contains("const OPEN_ALL_LOCATIONS := "), "GameState has the location-unlock flag")
	if source.is_empty():
		return
	source = source.replace("const OPEN_ALL_LOCATIONS := true", "const OPEN_ALL_LOCATIONS := false")
	var locked_state := GDScript.new()
	locked_state.source_code = source
	var parse_error := locked_state.reload()
	_check(parse_error == OK, "load a test-only GameState with open-all disabled")
	if parse_error != OK:
		return
	_check(not bool(locked_state.get_script_constant_map().get("OPEN_ALL_LOCATIONS", true)), "test GameState has OPEN_ALL_LOCATIONS disabled")
	locked_state.set("conquered", {})
	for loc in Locations.DATA:
		var req: Array = loc.get("req", [])
		var expected_without_progress := req.is_empty() and not bool(loc.get("wip", false))
		locked_state.set("conquered", {})
		_check(bool(locked_state.call("is_unlocked", loc)) == expected_without_progress, "%s unlocks correctly with no progress" % String(loc.get("id", "?")))
		for parent in req:
			locked_state.set("conquered", {String(parent): true})
			_check(bool(locked_state.call("is_unlocked", loc)), "%s unlocks after %s is conquered" % [String(loc.get("id", "?")), String(parent)])
	locked_state.set("conquered", {})

func _test_map_icons_and_bounds() -> void:
	var menu_script := load("res://menu.gd") as GDScript
	_check(menu_script != null, "load menu metadata for biome icons")
	if menu_script != null:
		var icons: Array = menu_script.get_script_constant_map().get("BIOME_ICONS", [])
		_check(icons.size() == Biomes.DATA.size(), "biome icon array matches biome count")
		for icon in icons:
			var icon_path := "res://icons/%s" % String(icon)
			_check(FileAccess.file_exists(icon_path), "biome icon exists: %s" % icon_path)
	var map_script := load("res://world_map.gd") as GDScript
	_check(map_script != null, "load world map marker geometry metadata")
	if map_script == null:
		return
	var constants := map_script.get_script_constant_map()
	var span: Vector2 = constants.get("MAP_SPAN", Vector2.ZERO)
	var world: Vector2 = constants.get("WORLD", Vector2.ZERO)
	var origin := Vector2(float(constants.get("EXTRA_LEFT", 0.0)), float(constants.get("EXTRA_TOP", 0.0)))
	_check(span.x > 0.0 and span.y > 0.0 and world.x > 0.0 and world.y > 0.0, "map exposes valid world dimensions")
	for loc in Locations.DATA:
		var map_pos: Vector2 = loc["pos"] * span + origin
		var id := String(loc.get("id", "?"))
		_check(map_pos.x >= 0.0 and map_pos.y >= 0.0 and map_pos.x <= world.x and map_pos.y <= world.y, "%s marker fits inside map world" % id)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
