class_name TiovivoLabTune

## Shared config for the tiovivo/carousel. Saved to res://dev/tiovivo_lab.json.
## Used by the dev bench lab and by the game (simulation + render) so both stay faithful.

const PATH := "res://dev/tiovivo_lab.json"

## Internal cache backing tiovivo lab tune tune lookups.
static var _cache: Dictionary = {}
## Internal cache backing tiovivo lab tune tune lookups.
static var _cache_mtime: int = -1

## Shipped carousel timing and spacing defaults.
static func defaults() -> Dictionary:
	return {
		"carousel": {
			"cell": [8, 16],
			"center_offset": [18.0, 18.0],
			"seat_spacing": 0.0,
			"slots": 4,
			"spin_speed": -2.8,
			"slot_base_deg": 0.0,
			"face_mode": "inward", # inward, outward, tangent, spin
			"sprite_dir_offset": 4,
			"sprite_dir_follow": true,
			"min_stay": 8.0,
			"ride_fun_rate": 2.5,
			"ride_done": 95.0,
		},
		"sync": {
			"mode": "continuous", # continuous, interval, wave
			"interval": 2.0,
			"wave_size": 1,
			"wave_pause": 4.0,
			"max_boarding": 1,
			"initial_delay": 0.0,
			"queue": true,
			"reenter": true,
		},
		"spawn": {
			"count": 6,
			"ring_radius": 80.0,
			"initial_fun": 20.0,
		},
		"paused": false,
	}


## Clears cached lab JSON so the next read reloads from disk.
static func invalidate() -> void:
	_cache.clear()
	_cache_mtime = -1


## Merged carousel config used by the sim and presentation.
static func carousel() -> Dictionary:
	var cfg := load_saved()
	var car: Dictionary = {}
	if cfg.has("carousel") and typeof(cfg.carousel) == TYPE_DICTIONARY:
		car = cfg.carousel
	var off = car.get("center_offset", [18.0, 18.0])
	var offx := float(off[0]) if typeof(off) == TYPE_ARRAY and off.size() > 0 else 18.0
	var offy := float(off[1]) if typeof(off) == TYPE_ARRAY and off.size() > 1 else 18.0
	var slots_n := maxi(1, int(car.get("slots", 4)))
	var spacing := float(car.get("seat_spacing", 0.0))
	if car.has("radius"):
		# compat: old configs used orbit radius; convert to distance between plazas
		spacing = 2.0 * float(car.get("radius", 0.0)) * sin(PI / maxf(1.0, float(slots_n)))
	return {
		"center_offset": Vector2(offx, offy),
		"seat_spacing": spacing,
		"slots": slots_n,
		"spin_speed": float(car.get("spin_speed", -2.8)),
		"slot_base_deg": float(car.get("slot_base_deg", 0.0)),
		"face_mode": str(car.get("face_mode", "inward")),
		"sprite_dir_offset": int(car.get("sprite_dir_offset", 4)),
		"sprite_dir_follow": bool(car.get("sprite_dir_follow", true)),
		"min_stay": float(car.get("min_stay", 8.0)),
		"ride_fun_rate": float(car.get("ride_fun_rate", 2.5)),
		"ride_done": float(car.get("ride_done", 95.0)),
	}


## Computes rider ring radius from slot count and spacing.
static func seat_radius(slots_n: int, spacing: float) -> float:
	# Distance between plazas is the primary control: radius derived so adjacent seats are `spacing` apart.
	if slots_n <= 1:
		return 0.0
	var denom := 2.0 * sin(PI / float(slots_n))
	if absf(denom) < 0.0001:
		return 0.0
	return spacing / denom


## Internal helper for tiovivo lab tune tune serialization or bench rows.
static func _deep_merge(base: Variant, over: Variant) -> Variant:
	if typeof(base) != TYPE_DICTIONARY or typeof(over) != TYPE_DICTIONARY:
		return over
	var out: Dictionary = (base as Dictionary).duplicate(true)
	for key in (over as Dictionary).keys():
		if out.has(key):
			out[key] = _deep_merge(out[key], over[key])
		else:
			out[key] = over[key]
	return out


## Loads tiovivo_lab.json and merges over defaults.
static func load_saved() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		_cache = defaults()
		_cache_mtime = -1
		return _cache
	var mtime := FileAccess.get_modified_time(PATH)
	if not _cache.is_empty() and mtime == _cache_mtime:
		return _cache
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_cache = defaults()
		_cache_mtime = mtime
		return _cache
	_cache = _deep_merge(defaults(), parsed)
	_cache_mtime = mtime
	return _cache


## Writes a carousel lab config dictionary to disk.
static func save_file(cfg: Dictionary) -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("tiovivo lab: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(cfg, "  "))
	file.close()
	invalidate()
	return ProjectSettings.globalize_path(PATH)
