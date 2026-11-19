class_name EffectTune

# Dev bench overrides for thronglet need rates and presentation.
# The game never reads this. res://dev/effect_tune.json is the handoff.

const PATH := "res://dev/effect_tune.json"
const LOOK_KEYS := ["clip", "fx", "lift", "bob", "orbit", "scale", "fx_x", "fx_y"]
const FX_CHOICES := ["none", "spark", "suds", "splash", "aura", "fire", "clean"]

# Rate defaults match ThrongletSimServer / Catalog literals.
const DEFAULTS := {
	"goo": {"fed": 0.35, "clean": 0.9, "clean_adapt": 0.35},
	"need": {"ok": 85.0, "hungry": 75.0, "seek": 40.0, "fun": 82.0},
	"visit:dwell": {"cap": 4.0, "stay": 18.0, "cool": 14.0, "fed": 6.0, "clean": 8.0, "fun": 0.0},
	"visit:fancy": {"cap": 10.0, "stay": 24.0, "cool": 12.0, "fed": 7.0, "clean": 12.0, "fun": 0.0},
	"visit:theatre": {"cap": 18.0, "stay": 14.0, "cool": 10.0, "fed": 0.0, "clean": 0.0, "fun": 9.0},
	"aura:flower": {"radius": 28.0, "limit": 3.0, "fun": 3.5, "buff": 0.0},
	"aura:statue": {"radius": 36.0, "limit": 4.0, "fun": 5.0, "buff": 0.8},
	"aura:wood": {"radius": 36.0, "limit": 4.0, "fun": 5.0, "buff": 0.8},
	"feat:totem": {"radius": 32.0, "limit": 4.0, "fun": 4.0, "buff": 0.0},
	"feat:curer": {"radius": 28.0, "limit": 3.0, "fed": 1.5, "clean": 5.0, "fun": 0.0, "buff": 0.0},
	"feat:fire": {"radius": 28.0, "clean": 8.0},
	"aura:ball": {"radius": 28.0, "limit": 2.0, "fun": 20.0},
	"act:eat": {"bite": 0.45, "fed": 100.0},
	"act:bath": {"clean": 3.0, "done": 95.0, "min_stay": 8.0, "enter": 1.2},
	"act:play": {"fun": 6.0},
	"act:ball": {"fun": 8.0},
	"act:round": {"fun": 2.5},
	"act:sponge": {"radius": 30.0, "stroke_min": 2.0, "stroke_cap": 22.0, "gain": 2.0},
	"act:mop": {"radius": 48.0, "clean": 100.0},
}

# Presentation defaults used by the bench preview. apply_in points at Main._frame.
const LOOK := {
	"goo": {"clip": "ThrongA_Sad", "fx": "none", "lift": 0.0, "bob": 0.0, "orbit": 6.0},
	"need": {"clip": "ThrongA_Default", "fx": "none", "lift": 0.0, "bob": 0.0, "orbit": 0.0},
	"visit:dwell": {"clip": "ThrongA_Default", "fx": "spark", "lift": 0.0, "bob": 0.0, "orbit": 8.0},
	"visit:fancy": {"clip": "ThrongA_Default", "fx": "spark", "lift": 0.0, "bob": 0.0, "orbit": 8.0},
	"visit:theatre": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "spark", "lift": 0.0, "bob": 2.0, "orbit": 8.0},
	"aura:flower": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 2.0, "orbit": 14.0},
	"aura:statue": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 2.0, "orbit": 14.0},
	"aura:wood": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 2.0, "orbit": 14.0},
	"feat:totem": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 2.0, "orbit": 12.0},
	"feat:curer": {"clip": "ThrongA_Happy", "fx": "suds", "lift": 0.0, "bob": 0.0, "orbit": 0.0},
	"feat:fire": {"clip": "ThrongA_Sad", "fx": "none", "lift": 0.0, "bob": 0.0, "orbit": 10.0},
	"aura:ball": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 2.0, "orbit": 14.0},
	"act:eat": {"clip": "ThrongA_Eat", "fx": "none", "lift": 0.0, "bob": 5.0, "orbit": 0.0},
	"act:bath": {"clip": "Throng_FallInBath_Spritesheet", "fx": "splash", "lift": 0.0, "bob": 0.0, "orbit": 0.0},
	"act:bath_exit": {"clip": "ThrongA_Happy", "fx": "clean", "lift": 0.0, "bob": 0.0, "orbit": 0.0, "scale": 0.3, "fx_x": 3.0, "fx_y": 3.0},
	"act:play": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 3.0, "orbit": 10.0},
	"act:ball": {"clip": "ThrongA_Jump_VariantA_Spritesheet", "fx": "none", "lift": 0.0, "bob": 0.0, "orbit": 14.0},
	"act:round": {"clip": "ThrongA_Roundabout_SpriteSheet", "fx": "none", "lift": 1.5, "bob": 10.0, "orbit": 0.0},
	"act:sponge": {"clip": "ThrongA_Happy", "fx": "suds", "lift": 0.0, "bob": 0.0, "orbit": 0.0, "scale": 0.4, "fx_x": 7.0, "fx_y": 7.0},
	"act:mop": {"clip": "ThrongA_Happy", "fx": "suds", "lift": 0.0, "bob": 0.0, "orbit": 0.0, "scale": 1.0, "fx_x": 0.0, "fx_y": 0.0},
}

static var _rows: Array = []
static var _index := {}
static var overrides := {}


static func entries() -> Array:
	if _rows.is_empty():
		_build()
	return _rows


static func entry(id: String) -> Dictionary:
	entries()
	return _index.get(id, {})


static func get_tune(id: String) -> Dictionary:
	var tune := _defaults(id)
	if not overrides.has(id):
		return tune
	var over: Dictionary = overrides[id]
	for key in over.keys():
		tune[key] = over[key]
	return tune


static func is_dirty(id: String) -> bool:
	return overrides.has(id) and not (overrides[id] as Dictionary).is_empty()


static func change_count() -> int:
	var n := 0
	for row in entries():
		if is_dirty(str(row.id)):
			n += 1
	return n


static func is_str_field(key: String) -> bool:
	return key == "clip" or key == "fx"


static func field_meta(id: String, key: String) -> Dictionary:
	if is_str_field(key):
		return {"min": 0.0, "max": 0.0, "step": 1.0, "whole": false, "str": true}
	var whole := key == "cap" or key == "limit"
	var lo := 0.0
	var hi := 200.0
	var step := 0.01
	match key:
		"cap", "limit":
			lo = 0.0
			hi = 64.0
			step = 1.0
		"radius", "orbit":
			lo = 0.0
			hi = 160.0
			step = 1.0
		"lift", "bob":
			lo = 0.0
			hi = 40.0
			step = 0.1
		"buff":
			lo = 0.0
			hi = 10.0
			step = 0.05
		"scale":
			lo = 0.05
			hi = 4.0
			step = 0.05
		"fx_x", "fx_y":
			lo = -120.0
			hi = 120.0
			step = 0.5
		"bite", "enter", "min_stay", "stroke_min", "gain":
			lo = 0.0
			hi = 60.0
			step = 0.05
		"stroke_cap":
			lo = 0.0
			hi = 100.0
			step = 0.5
		"stay", "cool":
			lo = 0.0
			hi = 120.0
			step = 0.5
		"ok", "hungry", "seek", "done":
			lo = 0.0
			hi = 100.0
			step = 1.0
		"fed", "fun", "clean", "clean_adapt":
			if id == "goo":
				lo = 0.0
				hi = 5.0
				step = 0.01
			elif id.begins_with("visit:") or id.begins_with("aura:") or id.begins_with("feat:"):
				lo = 0.0
				hi = 80.0
				step = 0.5
			else:
				lo = 0.0
				hi = 100.0
				step = 0.5
		_:
			lo = 0.0
			hi = 200.0
			step = 0.01
	return {"min": lo, "max": hi, "step": step, "whole": whole, "str": false}


static func set_num(id: String, key: String, value: float) -> void:
	if is_str_field(key):
		return
	var meta := field_meta(id, key)
	var snapped: float
	if bool(meta.whole):
		snapped = float(clampi(int(round(value)), int(meta.min), int(meta.max)))
	else:
		snapped = snappedf(clampf(value, float(meta.min), float(meta.max)), 0.01)
	_assign(id, key, snapped)


static func set_str(id: String, key: String, value: String) -> void:
	if not is_str_field(key):
		return
	var text := value.strip_edges()
	if key == "fx" and not FX_CHOICES.has(text):
		text = "none"
	if key == "clip" and text == "":
		text = "ThrongA_Default"
	_assign(id, key, text)


static func reset(id: String) -> void:
	overrides.erase(id)


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
		var id := str(raw.get("id", ""))
		if entry(id).is_empty():
			continue
		var fields = raw.get("fields", {})
		if typeof(fields) != TYPE_DICTIONARY:
			continue
		for key in fields.keys():
			var field = fields[key]
			if typeof(field) != TYPE_DICTIONARY:
				continue
			var value = _read_value(id, str(key), field.get("to", null))
			if value == null:
				continue
			_assign(id, str(key), value)


static func save_file() -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("effect tune: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(_document(), "  "))
	file.close()
	return ProjectSettings.globalize_path(PATH)


static func _build() -> void:
	_push("GLOBAL", "goo", "GOO", ["fed", "clean", "clean_adapt"])
	_push("GLOBAL", "need", "NEED", ["ok", "hungry", "seek", "fun"])
	_push("VISIT", "visit:dwell", "CASA", ["cap", "stay", "cool", "fed", "clean", "fun"])
	_push("VISIT", "visit:fancy", "CASA FANCY", ["cap", "stay", "cool", "fed", "clean", "fun"])
	_push("VISIT", "visit:theatre", "TEATRO", ["cap", "stay", "cool", "fed", "clean", "fun"])
	_push("AURA", "aura:flower", "FLOR", ["radius", "limit", "fun", "buff"])
	_push("AURA", "aura:statue", "ESTATUA", ["radius", "limit", "fun", "buff"])
	_push("AURA", "aura:wood", "MADERA", ["radius", "limit", "fun", "buff"])
	_push("AURA", "feat:totem", "TOTEM", ["radius", "limit", "fun", "buff"])
	_push("AURA", "feat:curer", "CURACION", ["radius", "limit", "fed", "clean", "fun", "buff"])
	_push("AURA", "feat:fire", "FUEGO", ["radius", "clean"])
	_push("AURA", "aura:ball", "BALON AURA", ["radius", "limit", "fun"])
	_push("ACTION", "act:eat", "COMER", ["bite", "fed"])
	_push("ACTION", "act:bath", "BANERA", ["clean", "done", "min_stay", "enter"])
	_push("ACTION", "act:bath_exit", "SALIDA BANERA", [])
	_push("ACTION", "act:play", "JUGAR", ["fun"])
	_push("ACTION", "act:ball", "PATADA BALON", ["fun"])
	_push("ACTION", "act:round", "TIOVIVO", ["fun"])
	_push("ACTION", "act:sponge", "ESPONJA", ["radius", "stroke_min", "stroke_cap", "gain"])
	_push("ACTION", "act:mop", "FREGONA", ["radius", "clean"])


static func _push(group: String, id: String, label: String, keys: Array) -> void:
	var packed := PackedStringArray()
	for key in keys:
		packed.append(str(key))
	for key in LOOK_KEYS:
		packed.append(str(key))
	var row := {
		"id": id,
		"group": group,
		"label": label,
		"fields": packed,
	}
	_rows.append(row)
	_index[id] = row


static func _defaults(id: String) -> Dictionary:
	var out := {}
	var base = DEFAULTS.get(id, {})
	if typeof(base) == TYPE_DICTIONARY:
		for key in base.keys():
			out[str(key)] = float(base[key])
	var look = LOOK.get(id, {})
	if typeof(look) == TYPE_DICTIONARY:
		for key in look.keys():
			var name := str(key)
			if is_str_field(name):
				out[name] = str(look[key])
			else:
				out[name] = float(look[key])
	return out


static func _same(key: String, a, b) -> bool:
	if is_str_field(key):
		return str(a) == str(b)
	return is_equal_approx(float(a), float(b))


static func _assign(id: String, key: String, value) -> void:
	var row := entry(id)
	if row.is_empty():
		return
	if not (row.fields as PackedStringArray).has(key):
		return
	var base: Dictionary = _defaults(id)
	if not base.has(key):
		return
	var same := _same(key, base[key], value)
	if not overrides.has(id):
		if same:
			return
		overrides[id] = {}
	if same:
		overrides[id].erase(key)
		if overrides[id].is_empty():
			overrides.erase(id)
		return
	overrides[id][key] = value


static func _read_value(id: String, key: String, raw):
	if raw == null:
		return null
	if is_str_field(key):
		if typeof(raw) != TYPE_STRING:
			return null
		var text := str(raw).strip_edges()
		if key == "fx" and not FX_CHOICES.has(text):
			return null
		if key == "clip" and text == "":
			return null
		return text
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return null
	var meta := field_meta(id, key)
	if bool(meta.whole):
		return float(clampi(int(round(float(raw))), int(meta.min), int(meta.max)))
	return snappedf(clampf(float(raw), float(meta.min), float(meta.max)), 0.01)


static func _json_value(key: String, value):
	if is_str_field(key):
		return str(value)
	return snappedf(float(value), 0.01)


static func _document() -> Dictionary:
	var changes: Array = []
	for row in entries():
		var id := str(row.id)
		if not is_dirty(id):
			continue
		var tune := get_tune(id)
		var base := _defaults(id)
		var fields := {}
		for key in row.fields:
			var name := str(key)
			if _same(name, base[name], tune[name]):
				continue
			fields[name] = {
				"from": _json_value(name, base[name]),
				"to": _json_value(name, tune[name]),
				"apply_in": _apply_in(id, name),
			}
		if fields.is_empty():
			continue
		changes.append({
			"id": id,
			"group": str(row.group),
			"label": str(row.label),
			"fields": fields,
		})
	return {
		"version": 2,
		"do_not_runtime_load": true,
		"how_to_apply": _how(),
		"units": {
			"fed_fun_clean_rates": "points per second while the effect applies, unless noted",
			"cap_limit": "integer counts",
			"radius_orbit": "world pixels",
			"lift_bob": "preview motion. lift is bob amplitude, bob is cycles-ish speed",
			"scale": "preview VFX scale (e.g. suds/bubbles)",
			"clip": "thronglet clip name used by Main._frame for the matching ACT_*",
			"fx": "preview VFX id: none|spark|suds|splash|aura|fire|clean",
			"need_thresholds": "0-100 need scores in Catalog.NEED_*",
			"buff": "seconds of buff_t",
		},
		"changes": changes,
	}


static func _apply_in(id: String, key: String) -> String:
	if key == "clip":
		return "Main._frame for the ACT_* / behavior that drives %s. Change the ThrongClips.frame_at clip name there." % id
	if key == "fx":
		return "Preview VFX only unless noted. Map spark/suds/splash/fire to the AssetFrames draws used near %s in Main._sync_actors." % id
	if key == "lift" or key == "bob" or key == "orbit" or key == "scale" or key == "fx_x" or key == "fx_y":
		return "Bench preview motion for %s. lift/bob affect thronglet hop; orbit is VFX ring radius; scale is VFX scale; fx_x/fx_y offset the VFX. Optional live apply in Main._sync_actors motion near this action." % id
	match id:
		"goo":
			match key:
				"fed":
					return "ThrongletSimServer._tick_one TILE_GOO block: fed -= 0.35 * dt."
				"clean":
					return "ThrongletSimServer._tick_one TILE_GOO block: clean_hit when mutations.adapt is false (currently 0.9)."
				"clean_adapt":
					return "ThrongletSimServer._tick_one TILE_GOO block: clean_hit when mutations.adapt is true (currently 0.35)."
		"need":
			match key:
				"ok":
					return "Catalog.NEED_OK."
				"hungry":
					return "Catalog.NEED_HUNGRY."
				"seek":
					return "Catalog.NEED_SEEK."
				"fun":
					return "Catalog.NEED_FUN."
		"visit:dwell":
			return "ThrongletSimServer._visit_rule BLD_DWELL key '%s'." % key
		"visit:fancy":
			return "ThrongletSimServer._visit_rule BLD_FANCY key '%s'." % key
		"visit:theatre":
			return "ThrongletSimServer._visit_rule BLD_THEATRE key '%s'." % key
		"aura:flower":
			return "ThrongletSimServer._tick_auras BLD_FLOWER _boost args (%s). fun is rate/sec passed as fun * dt." % key
		"aura:statue":
			return "ThrongletSimServer._tick_auras BLD_STATUE _boost args (%s). fun is rate/sec passed as fun * dt." % key
		"aura:wood":
			return "ThrongletSimServer._tick_auras BLD_WOOD _boost args (%s). fun is rate/sec passed as fun * dt." % key
		"feat:totem":
			return "ThrongletSimServer._tick_props FEAT_TOTEM _boost args (%s). fun is rate/sec." % key
		"feat:curer":
			return "ThrongletSimServer._tick_props FEAT_CURER _boost args (%s). fed/clean are rate/sec." % key
		"feat:fire":
			match key:
				"radius":
					return "ThrongletSimServer._tick_props FEAT_FIRE query_radius."
				"clean":
					return "ThrongletSimServer._tick_props FEAT_FIRE: clean -= rate * dt."
		"aura:ball":
			return "ThrongletSimServer ball item tick _boost args (%s). fun is rate/sec." % key
		"act:eat":
			match key:
				"bite":
					return "ThrongletSimServer._seek_food: per-bite progress threshold before a bite is consumed."
				"fed":
					return "ThrongletSimServer._seek_food: fed[i] = value after each apple bite (3 bites per apple)."
		"act:bath":
			match key:
				"clean":
					return "ThrongletSimServer.BATH_CLEAN_RATE used in _do_bath."
				"done":
					return "ThrongletSimServer.BATH_DONE."
				"min_stay":
					return "ThrongletSimServer.BATH_MIN_STAY."
				"enter":
					return "ThrongletSimServer.BATH_ENTER_T."
		"act:play":
			return "ThrongletSimServer._seek_fun: amused += fun * dt near a play building."
		"act:ball":
			return "ThrongletSimServer._seek_fun: amused += fun on ball kick."
		"act:round":
			return "ThrongletSimServer._do_roundabout_ride: amused += fun * dt."
		"act:sponge":
			match key:
				"radius":
					return "ThrongletSimServer.scrub query_radius."
				"stroke_min":
					return "ThrongletSimServer.scrub: ignore strokes below this."
				"stroke_cap":
					return "ThrongletSimServer.scrub: minf(stroke, stroke_cap)."
				"gain":
					return "ThrongletSimServer.scrub: clean += minf(stroke, stroke_cap) * gain."
		"act:mop":
			match key:
				"radius":
					return "ThrongletSimServer._mop query_radius and tile clear radius."
				"clean":
					return "ThrongletSimServer._mop: clean[id] = value for living thronglets in radius."
	return "ThrongletSimServer / Catalog / Main for %s.%s" % [id, key]


static func _how() -> String:
	return " ".join(PackedStringArray([
		"Apply each object in changes and nothing else.",
		"Do not load this file at runtime. Edit ThrongletSimServer.gd, catalog.gd, or Main._frame so the live values match to, then update DEFAULTS/LOOK in effect_tune.gd.",
		"from is the bench default at save time. to is the absolute value the bench showed.",
		"Follow apply_in on each field.",
		"Skip fields that are not listed.",
		"clip is the thronglet spritesheet name. Fine frame edits stay in throng_tune / ANIM.",
		"fx is the preview VFX id. Map it to AssetFrames draws when applying live.",
		"lift/bob/orbit are preview motion knobs.",
		"Visit fed/clean/fun and aura fun/fed/clean are points per second unless apply_in says otherwise.",
		"Do not change costs, unlocks, dialogue ops, or unlisted rates.",
	]))
