extends Object

# Bench tunes for animations that are not thronglet clips.
# The game never reads this script. res://dev/anim_tune.json is the handoff.

const PATH := "res://dev/anim_tune.json"

const FPS := {}
const SCALE := {
	"egg": 0.4,
}
const FRAME_SCALE := {
	"hand": {
		"0": 0.6,
		"1": 0.6,
		"2": 0.6,
		"3": 0.6,
	},
}
const FRAME_OFF := {
	"egg": {
		"0": Vector2(2, 2),
		"1": Vector2(2, 2),
		"2": Vector2(2, 2),
		"3": Vector2(2, 2),
		"4": Vector2(2, 2),
	},
}
const FRAME_ROT := {}

# Not in AssetFrames.SLOTS. Packed earlier into the world sheet.
const SPECIALS := [
	{
		"id": "egg",
		"label": "HUEVO",
		"group": "OBJETOS",
		"start": 87,
		"count": 5,
		"fps": 4.0,
		"where": "Main.EGG_ANIM is 87 and covers 5 frames. _egg_frame picks one of those frames from the egg state. The bench loops them at 4 fps.",
	},
	{
		"id": "round",
		"label": "TIOVIVO",
		"group": "ESTRUCTURAS",
		"start": 132,
		"count": 8,
		"fps": 8.0,
		"where": "An active roundabout uses Main.ROUND_ANIM + int(time * 8) % 8. ROUND_ANIM is 132.",
	},
]

# Optional display for AssetFrames slots. Missing slots still appear; id defaults to lower(slot).
const META := {
	"FIRE": {"id": "fire", "label": "FUEGO", "group": "EFECTOS", "fps": 8.0, "where": "Main._feature_frame for FEAT_FIRE uses AssetFrames.frame(AssetFrames.FIRE, AssetFrames.FIRE_N, int(time * 8))."},
	"FIRE_BLOB": {"id": "fire_blob", "label": "FUEGO BOLAS", "group": "EFECTOS", "fps": 8.0, "where": "On odd seconds, FEAT_FIRE also draws AssetFrames.frame(AssetFrames.FIRE_BLOB, AssetFrames.FIRE_BLOB_N, int(time * 8))."},
	"FUMES": {"id": "fumes", "label": "HUMOS", "group": "EFECTOS", "fps": 8.0, "where": "Main._push_glitch_fumes uses AssetFrames.frame(AssetFrames.FUMES, AssetFrames.FUMES_N, int(time * 8))."},
	"CLEAN": {"id": "clean", "label": "CHISPA", "group": "EFECTOS", "fps": 10.0, "where": "ACT_WASH draws AssetFrames.frame(AssetFrames.CLEAN, AssetFrames.CLEAN_N, int(time * 10))."},
	"SPLASH": {"id": "splash", "label": "SALPICADURA", "group": "EFECTOS", "fps": 8.0, "where": "ACT_BATH, when the thronglet is not seated and the suds frame is missing, draws AssetFrames.frame(AssetFrames.SPLASH, AssetFrames.SPLASH_N, int(time * 8))."},
	"HAND": {"id": "hand", "label": "MANO", "group": "EFECTOS", "fps": 8.0, "where": "A held thronglet draws AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, int(time * 8))."},
	"BUBBLE": {"id": "bubble", "label": "BURBUJA", "group": "EFECTOS", "fps": 8.0, "where": "AssetFrames.BUBBLE. Play does not loop this strip."},
	"BUBBLE_LIGHT": {"id": "foam", "label": "ESPUMA", "group": "EFECTOS", "fps": 8.0, "where": "AssetFrames.BUBBLE_LIGHT. Play does not loop this strip."},
	"SMOKE": {"id": "smoke", "label": "HUMO", "group": "EFECTOS", "fps": 8.0, "where": "AssetFrames.SMOKE. Play does not loop this strip."},
	"GLITCH": {"id": "glitch", "label": "GLITCH", "group": "EFECTOS", "fps": 8.0, "where": "AssetFrames.GLITCH. Play does not loop this strip."},
	"TILE_GLITCH": {"id": "tile", "label": "BALDOSA", "group": "EFECTOS", "fps": 8.0, "where": "AssetFrames.TILE_GLITCH. Play does not loop this strip."},
	"AURA": {"id": "aura", "label": "AURA", "group": "EFECTOS"},
	"SPARK": {"id": "spark", "label": "CHISPA FX", "group": "EFECTOS"},
	"SUDS": {"id": "suds", "label": "JABON", "group": "EFECTOS"},
	"ANOMALY": {"id": "anomaly", "label": "ANOMALIA", "group": "BIOMAS"},
	"ANOMALY_RAY": {"id": "anomaly_ray", "label": "RAYO", "group": "BIOMAS"},
	"GLITCH_HOUSE": {"id": "glitch_house", "label": "CASA GLITCH", "group": "BIOMAS"},
	"GLITCH_TREE": {"id": "glitch_tree", "label": "ARBOL GLITCH", "group": "BIOMAS"},
	"GLITCH_TREE_C": {"id": "glitch_tree_c", "label": "ARBOL GLITCH C", "group": "BIOMAS"},
	"GLITCH_TREE_D": {"id": "glitch_tree_d", "label": "ARBOL GLITCH D", "group": "BIOMAS"},
	"WASTE_TREE": {"id": "waste_tree", "label": "ARBOL YERMO", "group": "BIOMAS"},
	"WASTE_TREE_B": {"id": "waste_tree_b", "label": "ARBOL YERMO B", "group": "BIOMAS"},
	"EPILOGUE": {"id": "epilogue", "label": "EPILOGO", "group": "BIOMAS"},
	"ROTTEN_APPLE": {"id": "rotten_apple", "label": "MANZANA PODRE", "group": "BIOMAS"},
	"EPI_APPLE": {"id": "epi_apple", "label": "MANZANA EPI", "group": "BIOMAS"},
	"MOUNT_BIG": {"id": "mount_big", "label": "MONTE GRANDE", "group": "BIOMAS"},
	"MOUNT_SMALL": {"id": "mount_small", "label": "MONTE PEQUE", "group": "BIOMAS"},
	"MOUNT_GLITCH": {"id": "mount_glitch", "label": "MONTE GLITCH", "group": "BIOMAS"},
	"GRASS_PATCH": {"id": "grass_patch", "label": "HIERBA", "group": "BIOMAS"},
}

static var overrides := {}
static var _rows := {}
static var _order: PackedStringArray = PackedStringArray()


static func ids() -> PackedStringArray:
	_ensure()
	return _order


static func entry(key: String) -> Dictionary:
	_ensure()
	return _rows.get(key, {})


static func has_clip(key: String) -> bool:
	_ensure()
	return _rows.has(key)


static func _ensure() -> void:
	if not _order.is_empty():
		return
	_rows.clear()
	_order = PackedStringArray()
	for raw in SPECIALS:
		var row: Dictionary = raw
		_push(str(row.id), row)
	for slot in AssetFrames.SLOTS:
		var name := str(slot[0])
		var start := int(slot[1])
		var count := int(slot[2])
		if count <= 0:
			continue
		var meta: Dictionary = META.get(name, {})
		var key := str(meta.get("id", name.to_lower()))
		var label := str(meta.get("label", name.replace("_", " ")))
		var group := str(meta.get("group", "HOJA"))
		var fps := float(meta.get("fps", 8.0))
		var where := str(meta.get("where", "AssetFrames.%s is %d and the count is %d." % [name, start, count]))
		_push(key, {
			"label": label,
			"group": group,
			"start": start,
			"count": count,
			"fps": fps,
			"where": where,
			"slot": name,
		})


static func _push(key: String, row: Dictionary) -> void:
	if _rows.has(key):
		return
	_rows[key] = row
	_order.append(key)


static func fps_editable(key: String) -> bool:
	return int(entry(key).get("count", 1)) > 1


static func get_tune(key: String) -> Dictionary:
	var tune := {
		"fps": default_fps(key),
		"frame_scale": default_frame_scale(key),
		"frame_off": default_frame_off(key),
		"frame_rot": default_frame_rot(key),
	}
	if not overrides.has(key):
		return tune
	var over: Dictionary = overrides[key]
	for field in over.keys():
		tune[field] = over[field]
	return tune


static func is_dirty(key: String) -> bool:
	return overrides.has(key) and not (overrides[key] as Dictionary).is_empty()


static func change_count() -> int:
	var n := 0
	for key in ids():
		if is_dirty(key):
			n += 1
	return n


static func default_fps(key: String) -> float:
	if FPS.has(key):
		return float(FPS[key])
	return float(entry(key).get("fps", 8.0))


static func default_scale(key: String) -> float:
	if not SCALE.has(key):
		return 1.0
	return float(SCALE[key])


static func default_frame_scale(key: String) -> Dictionary:
	if not FRAME_SCALE.has(key):
		return {}
	var raw: Dictionary = FRAME_SCALE[key]
	return raw.duplicate()


static func frame_scale(key: String, index: int) -> float:
	var map: Dictionary = get_tune(key).get("frame_scale", {})
	if map.has(str(index)):
		return float(map[str(index)])
	return default_scale(key)


static func default_frame_off(key: String) -> Dictionary:
	if not FRAME_OFF.has(key):
		return {}
	var raw: Dictionary = FRAME_OFF[key]
	return raw.duplicate()


static func frame_offset(key: String, index: int) -> Vector2:
	var map: Dictionary = get_tune(key).get("frame_off", {})
	var raw = map.get(str(index), Vector2.ZERO)
	if raw is Vector2:
		return raw
	return Vector2.ZERO


static func default_frame_rot(key: String) -> Dictionary:
	if not FRAME_ROT.has(key):
		return {}
	var raw: Dictionary = FRAME_ROT[key]
	return raw.duplicate()


static func frame_rot(key: String, index: int) -> float:
	var map: Dictionary = get_tune(key).get("frame_rot", {})
	return float(map.get(str(index), 0.0))


static func set_fps(key: String, value: float) -> void:
	_assign(key, "fps", snappedf(clampf(value, 0.5, 24.0), 0.01))


static func set_frame_scale(key: String, index: int, value: float) -> void:
	if index < 0 or index >= int(entry(key).get("count", 1)):
		return
	var map := default_frame_scale(key)
	if overrides.has(key) and (overrides[key] as Dictionary).has("frame_scale"):
		map = (overrides[key]["frame_scale"] as Dictionary).duplicate()
	var snapped := snappedf(clampf(value, 0.01, 3.0), 0.01)
	if is_equal_approx(snapped, default_scale(key)):
		map.erase(str(index))
	else:
		map[str(index)] = snapped
	_assign(key, "frame_scale", map)


static func set_frame_offset(key: String, index: int, x: float, y: float) -> void:
	if index < 0 or index >= int(entry(key).get("count", 1)):
		return
	var map := default_frame_off(key)
	if overrides.has(key) and (overrides[key] as Dictionary).has("frame_off"):
		map = (overrides[key]["frame_off"] as Dictionary).duplicate()
	var at := Vector2(snappedf(clampf(x, -160.0, 160.0), 0.01), snappedf(clampf(y, -160.0, 160.0), 0.01))
	if at.is_zero_approx():
		map.erase(str(index))
	else:
		map[str(index)] = at
	_assign(key, "frame_off", map)


static func set_frame_rot(key: String, index: int, value: float) -> void:
	if index < 0 or index >= int(entry(key).get("count", 1)):
		return
	var map := default_frame_rot(key)
	if overrides.has(key) and (overrides[key] as Dictionary).has("frame_rot"):
		map = (overrides[key]["frame_rot"] as Dictionary).duplicate()
	var snapped := snappedf(clampf(value, -180.0, 180.0), 0.01)
	if is_equal_approx(snapped, 0.0):
		map.erase(str(index))
	else:
		map[str(index)] = snapped
	_assign(key, "frame_rot", map)


static func reset(key: String) -> void:
	overrides.erase(key)


static func load_saved() -> void:
	overrides.clear()
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var changes = parsed.get("changes", [])
	if typeof(changes) != TYPE_ARRAY:
		return
	for raw in changes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var key := str(raw.get("id", ""))
		if not has_clip(key):
			continue
		var fields = raw.get("fields", {})
		if typeof(fields) != TYPE_DICTIONARY:
			continue
		for field in fields.keys():
			var spec = fields[field]
			if typeof(spec) != TYPE_DICTIONARY:
				continue
			if str(field) == "scale":
				if not fields.has("frame_scale"):
					_apply_legacy_scale(key, spec.get("to", null))
				continue
			var value = _read_value(key, str(field), spec.get("to", null))
			if value == null:
				continue
			_assign(key, str(field), value)


static func save_file() -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("anim tune: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(_document(), "  "))
	file.close()
	return ProjectSettings.globalize_path(PATH)


static func _assign(key: String, field: String, value) -> void:
	if not has_clip(key):
		return
	if field == "fps" and not fps_editable(key):
		return
	var same := _same(field, _base(key, field), value)
	if not overrides.has(key):
		if same:
			return
		overrides[key] = {}
	if same:
		overrides[key].erase(field)
		if overrides[key].is_empty():
			overrides.erase(key)
		return
	overrides[key][field] = value


static func _base(key: String, field: String):
	if field == "fps":
		return default_fps(key)
	if field == "frame_scale":
		return default_frame_scale(key)
	if field == "frame_off":
		return default_frame_off(key)
	if field == "frame_rot":
		return default_frame_rot(key)
	return {}


static func _same(field: String, a, b) -> bool:
	if field == "frame_scale" or field == "frame_rot":
		return _rot_same(a, b)
	if field == "frame_off":
		return _off_same(a, b)
	return is_equal_approx(float(a), float(b))


static func _rot_same(a, b) -> bool:
	var left: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {}
	var right: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {}
	if left.size() != right.size():
		return false
	for raw in left.keys():
		if not right.has(raw):
			return false
		if not is_equal_approx(float(left[raw]), float(right[raw])):
			return false
	return true


static func _read_value(key: String, field: String, raw):
	if raw == null:
		return null
	if field == "frame_scale":
		return _read_scale(key, raw)
	if field == "frame_off":
		return _read_off(key, raw)
	if field == "frame_rot":
		return _read_rot(key, raw)
	if field != "fps":
		return null
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return null
	return snappedf(clampf(float(raw), 0.5, 24.0), 0.01)


static func _off_same(a, b) -> bool:
	var left: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {}
	var right: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {}
	if left.size() != right.size():
		return false
	for raw in left.keys():
		if not right.has(raw) or not (right[raw] is Vector2):
			return false
		if not (left[raw] as Vector2).is_equal_approx(right[raw]):
			return false
	return true


static func _read_scale(key: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := int(entry(key).get("count", 1))
	var base := default_scale(key)
	for slot in raw.keys():
		var index := int(slot)
		if index < 0 or index >= n:
			continue
		var value = raw[slot]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		var snapped := snappedf(clampf(float(value), 0.01, 3.0), 0.01)
		if not is_equal_approx(snapped, base):
			map[str(index)] = snapped
	return map


static func _apply_legacy_scale(key: String, raw) -> void:
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return
	var snapped := snappedf(clampf(float(raw), 0.01, 3.0), 0.01)
	for index in int(entry(key).get("count", 1)):
		set_frame_scale(key, index, snapped)


static func _read_off(key: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := int(entry(key).get("count", 1))
	for slot in raw.keys():
		var index := int(slot)
		if index < 0 or index >= n:
			continue
		var value = raw[slot]
		if typeof(value) != TYPE_ARRAY or value.size() < 2:
			continue
		var at := Vector2(snappedf(clampf(float(value[0]), -160.0, 160.0), 0.01), snappedf(clampf(float(value[1]), -160.0, 160.0), 0.01))
		if not at.is_zero_approx():
			map[str(index)] = at
	return map


static func _read_rot(key: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := int(entry(key).get("count", 1))
	for slot in raw.keys():
		var index := int(slot)
		if index < 0 or index >= n:
			continue
		var value = raw[slot]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		var snapped := snappedf(clampf(float(value), -180.0, 180.0), 0.01)
		if not is_equal_approx(snapped, 0.0):
			map[str(index)] = snapped
	return map


static func _document() -> Dictionary:
	var changes: Array = []
	for key in ids():
		if not is_dirty(key):
			continue
		var tune := get_tune(key)
		var fields := {}
		var names: Array = ["frame_scale", "frame_off", "frame_rot"]
		if fps_editable(key):
			names.append("fps")
		for field in names:
			var name := str(field)
			if _same(name, _base(key, name), tune[name]):
				continue
			var apply := _apply(key, name)
			if name == "frame_scale":
				apply = _scale_apply(key, tune[name])
			elif name == "frame_off":
				apply = _off_apply(key, tune[name])
			elif name == "frame_rot":
				apply = _rot_apply(key, tune[name])
			fields[name] = {
				"from": _json_value(name, _base(key, name)),
				"to": _json_value(name, tune[name]),
				"apply_in": apply,
			}
		if fields.is_empty():
			continue
		var row := entry(key)
		var start := int(row.start)
		var count := int(row.count)
		changes.append({
			"id": key,
			"label": str(row.label),
			"group": str(row.group),
			"start": start,
			"count": count,
			"frames": [start, start + count - 1],
			"fields": fields,
		})
	return {
		"version": 1,
		"do_not_runtime_load": true,
		"how_to_apply": _how(),
		"units": {
			"fps": "frames per second for this strip",
			"frame_scale": "sprite scale keyed by frame index. A missing index uses SCALE, or 1",
			"frame_off": "extra world pixels [x, y] after the anchor, keyed by frame index. A missing index stays at (0, 0)",
			"frame_rot": "degrees clockwise around the anchor, keyed by frame index. A missing index stays at 0",
		},
		"changes": changes,
	}


static func _apply(key: String, field: String) -> String:
	var row := entry(key)
	var where := str(row.get("where", ""))
	var span := "sheet frames %d through %d" % [int(row.start), int(row.start) + int(row.count) - 1]
	if field == "fps":
		return "Only %s, %s. %s Replace that time multiplier with to. In anim_tune.gd set FPS[\"%s\"] to to, or remove the key when to is the row default. Do not load this file at runtime." % [key, span, where, key]
	return ""


static func _scale_apply(key: String, value: Dictionary) -> String:
	var row := entry(key)
	var start := int(row.start)
	var bits := PackedStringArray()
	var slots: Array = value.keys()
	slots.sort()
	for raw in slots:
		var index := int(raw)
		bits.append("index %d (sheet %d) = %s" % [index, start + index, str(snappedf(float(value[raw]), 0.01))])
	var listed := "no scaled frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of %s. %s. %s Pass that scale only for a listed sheet frame. Every other frame stays at SCALE, or 1. In anim_tune.gd set FRAME_SCALE[\"%s\"] to the to map, or remove the key when it is empty. Do not scale the whole strip unless every index is listed. Do not load this file at runtime." % [key, listed, str(row.get("where", "")), key]


static func _off_apply(key: String, value: Dictionary) -> String:
	var row := entry(key)
	var start := int(row.start)
	var bits := PackedStringArray()
	var slots: Array = value.keys()
	slots.sort()
	for raw in slots:
		var index := int(raw)
		var at: Vector2 = value[raw]
		bits.append("index %d (sheet %d) = [%s, %s]" % [index, start + index, str(snappedf(at.x, 0.01)), str(snappedf(at.y, 0.01))])
	var listed := "no moved frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of %s. %s. %s Add that [x, y] as world pixels after the anchor on that sheet frame only. +x east, +y south. Every other frame stays at (0, 0). In anim_tune.gd set FRAME_OFF[\"%s\"] to the to map, or remove the key when it is empty. Do not move the whole strip. Do not load this file at runtime." % [key, listed, str(row.get("where", "")), key]


static func _rot_apply(key: String, value: Dictionary) -> String:
	var row := entry(key)
	var start := int(row.start)
	var bits := PackedStringArray()
	var slots: Array = value.keys()
	slots.sort()
	for raw in slots:
		var index := int(raw)
		bits.append("index %d (sheet %d) = %s degrees" % [index, start + index, str(snappedf(float(value[raw]), 0.01))])
	var listed := "no rotated frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of %s. %s. %s Main._write_mesh reads draw rot and spins that one quad clockwise around the anchor. Set rot only for a listed sheet frame. Every other frame stays at 0. In anim_tune.gd set FRAME_ROT[\"%s\"] to the to map, or remove the key when it is empty. Do not rotate the whole strip. Do not load this file at runtime." % [key, listed, str(row.get("where", "")), key]


static func _json_rot(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var slots: Array = raw.keys()
	slots.sort()
	for slot in slots:
		out[str(slot)] = snappedf(float(raw[slot]), 0.01)
	return out


static func _json_scale(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var slots: Array = raw.keys()
	slots.sort()
	for slot in slots:
		out[str(slot)] = snappedf(float(raw[slot]), 0.01)
	return out


static func _json_off(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var slots: Array = raw.keys()
	slots.sort()
	for slot in slots:
		var at: Vector2 = raw[slot]
		out[str(slot)] = [snappedf(at.x, 0.01), snappedf(at.y, 0.01)]
	return out


static func _json_value(field: String, value):
	if field == "frame_off":
		return _json_off(value)
	if field == "frame_scale":
		return _json_scale(value)
	if field == "frame_rot":
		return _json_rot(value)
	return snappedf(float(value), 0.01)


static func _how() -> String:
	return " ".join(PackedStringArray([
		"Apply each object in changes and nothing else.",
		"Do not load this file at runtime. Edit the draw named in apply_in, then update the matching const in anim_tune.gd so the bench default matches.",
		"from is the bench default at save time. to is the absolute value the bench showed.",
		"frames is the inclusive sheet index range.",
		"frame_scale keys are frame indexes inside that range. One entry scales that sprite only. A missing index stays at SCALE, or 1.",
		"frame_off keys are frame indexes inside that range. One entry moves that sprite only. A missing index stays at (0, 0).",
		"frame_rot keys are frame indexes inside that range. One entry rotates that sprite only.",
		"Do not change clips, props, or frame ranges that are not listed.",
	]))
