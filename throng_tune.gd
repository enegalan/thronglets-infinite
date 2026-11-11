extends Object

# Bench defaults for thronglet clips. The game never reads this script.
# res://dev/throng_tune.json is the handoff. Apply it in Main, then update the
# consts below so the next bench load does not keep a stale override.

const PATH := "res://dev/throng_tune.json"

# Sampled with frame_along. They have no fps field.
const ALONG := {
	"ThrongA_Mitosis_Spritesheet": true,
	"Throng_FallInBath_Spritesheet": true,
}

# frame_at(clip, int(time * fps)). Missing means 8, which is also ThrongClips.pick.
const FPS := {
	"ThrongA_Eat": 6.0,
	"ThrongA_Happy": 6.0,
	"ThrongA_Sad": 6.0,
}

# Clip -> uniform sprite scale used when a frame has no entry. Missing means 1.
const SCALE := {
	"ThrongA_AngryAtPlayer_Spritesheet": 0.4,
	"ThrongA_Bones": 0.4,
	"ThrongA_Bored_KickRock": 0.4,
	"ThrongA_Celebrate_Spritesheet": 0.4,
	"ThrongA_Dead_001": 0.4,
	"ThrongA_Dead_002": 0.4,
	"ThrongA_DeepThought_Spritesheet": 0.4,
	"ThrongA_Default": 0.4,
	"ThrongA_Default Blink": 0.4,
	"ThrongA_Default_Ghost": 0.4,
	"ThrongA_EarWiggleLow": 0.4,
	"ThrongA_EarWiggleStand": 0.4,
	"ThrongA_Eat": 0.4,
	"ThrongA_Grumpy": 0.4,
	"ThrongA_Happy": 0.4,
	"ThrongA_ImpactfulExplanation_Spritesheet": 0.4,
	"ThrongA_Jump": 0.4,
	"ThrongA_Jump-EarWiggle": 0.4,
	"ThrongA_JumpBlink": 0.4,
	"ThrongA_Jump_High": 0.4,
	"ThrongA_Jump_VariantA_Spritesheet": 0.4,
	"ThrongA_LooktAtPlayerHappyNod_Spritesheet": 0.4,
	"ThrongA_MitosisCutscene_NoBlood_Spritesheet": 0.4,
	"ThrongA_Mitosis_Spritesheet": 0.4,
	"ThrongA_Pickaxe_Spritesheet": 0.4,
	"ThrongA_Possessed_AntennaSpinEar_Spritesheet": 0.4,
	"ThrongA_Possessed_AntennaSpinTalk_Spritesheet": 0.4,
	"ThrongA_Possessed_AntennaSpin_Spritesheet": 0.4,
	"ThrongA_Possessed_EarRaise_Spritesheet": 0.4,
	"ThrongA_ReactToKill": 0.4,
	"ThrongA_Rotund_Spritesheet": 0.4,
	"ThrongA_Roundabout_SpriteSheet": 0.4,
	"ThrongA_Sad": 0.4,
	"ThrongA_Shrug": 0.4,
	"ThrongA_SingToThronglet_Spritesheet2": 0.4,
	"ThrongA_SkepticalToPlayer_Spritesheet": 0.4,
	"ThrongA_Sophisticated": 0.4,
	"ThrongA_Squint": 0.4,
	"ThrongA_Step01": 0.4,
	"ThrongA_Step01_noface": 0.4,
	"ThrongA_Step02": 0.4,
	"ThrongA_Step02_noface": 0.4,
	"ThrongA_Talk": 0.4,
	"ThrongA_TalkToOtherThronglet_Spritesheet2": 0.4,
	"ThrongA_Talk_Blink_Spritesheet": 0.4,
	"ThrongA_Talk_EarOffset_Spritesheet": 0.4,
	"ThrongA_Talk_EyeRoll_Spritesheet": 0.4,
	"ThrongA_Talk_HandsBack_Spritesheet": 0.4,
	"ThrongA_Talk_Low_Spritesheet": 0.4,
	"ThrongA_Talk_OffCenter": 0.4,
	"ThrongA_Talk_ScratchArm_Spritesheet": 0.4,
	"ThrongA_Talk_Tall_Spritesheet": 0.4,
	"ThrongB_SingToThronglet_Spritesheet2": 0.4,
	"ThrongB_TalkToOtherThronglet_Spritesheet2": 0.4,
	"ThrongC_SingToThronglet_Spritesheet2": 0.4,
	"ThrongC_TalkToOtherThronglet_Spritesheet2": 0.4,
	"ThrongD_SingToThronglet_Spritesheet2": 0.4,
	"ThrongD_TalkToOtherThronglet_Spritesheet2": 0.4,
	"ThrongE_SingToThronglet_Spriesheet2": 0.4,
	"ThrongE_TalkToOtherThronglet_Spritesheet": 0.4,
	"ThrongE_TalkToOtherThronglet_Spritesheet2": 0.4,
	"Throng_Alien_Anim_Flying_Spritesheet": 0.4,
	"Throng_Alien_EggHatch": 0.4,
	"Throng_Alien_Jump": 0.4,
	"Throng_Alien_Neutral": 0.4,
	"Throng_Alien_Neutral-HandOnHeadset": 0.4,
	"Throng_Alien_Talk": 0.4,
	"Throng_Alien_TalkFacingForward": 0.4,
	"Throng_Alien_Walk": 0.4,
	"Throng_Anim_Flying_Spritesheet": 0.4,
	"Throng_Egg_B_WiggleRight": 0.4,
	"Throng_FallInBath_Spritesheet": 0.4,
	"Throng_Grumpy3": 0.4,
	"Throng_Grumpy_Sheet": 0.4,
	"Throng_Idle_AntennaSpin_EyesClosed_Spritesheet": 0.4,
	"Throng_Idle_AntennaSpin_Spritesheet": 0.4,
	"Throng_Idle_BackTurned": 0.4,
	"Throng_Idle_EarsUp": 0.4,
	"Throng_Idle_EyesDirection_Spritesheet": 0.4,
	"Throng_SarcasticSquint2": 0.4,
	"Throng_SarcasticSquint3": 0.4,
	"Throng_SingB_Spritesheet": 0.4,
	"Throng_SingC_Spritesheet": 0.4,
	"Throng_SingD_Spritesheet": 0.4,
	"Throng_SingE_Spritesheet": 0.4,
	"Throng_Sing_Spritesheet": 0.4,
	"Throng_Sophisticated2": 0.4,
	"Throng_Sophisticated3": 0.4,
	"Throng_Think_Spritesheet": 0.4,
	"Throng_Think_TwiddleThumbs_Spritesheet": 0.4,
	"Throng_WalkBack_Anim_Spritesheet": 0.4,
	"Throng_Walk_Anim_Spritesheet": 0.4,
	"Throng_Walk_Homed_Spritesheet": 0.4
}

# Clip -> {frame index: scale}. A missing index uses SCALE, or 1.
const FRAME_SCALE := {
	"Throng_Outline": {
		"0": 0.7,
	},
}

# Clip -> {frame index: Vector2}. Missing index means (0, 0). One frame does not move the others.
const FRAME_OFF := {
	"ThrongA_MitosisCutscene_NoBlood_Spritesheet": {
		"0": Vector2(21, 21),
		"1": Vector2(21, 21),
		"2": Vector2(21, 21),
		"3": Vector2(21, 21),
		"4": Vector2(21, 21),
		"5": Vector2(21, 21),
		"6": Vector2(21, 21),
		"7": Vector2(21, 21),
		"8": Vector2(21, 21),
		"9": Vector2(21, 21),
		"10": Vector2(21, 21),
		"11": Vector2(21, 21),
		"12": Vector2(21, 21),
		"13": Vector2(21, 21),
		"14": Vector2(21, 21),
		"15": Vector2(21, 21),
		"16": Vector2(21, 21),
		"17": Vector2(21, 21),
		"18": Vector2(21, 21),
		"19": Vector2(21, 21),
		"20": Vector2(21, 21),
		"21": Vector2(21, 21),
		"22": Vector2(21, 21),
		"23": Vector2(21, 21),
		"24": Vector2(21, 21),
		"25": Vector2(21, 21),
		"26": Vector2(21, 21),
		"27": Vector2(21, 21),
		"28": Vector2(21, 21),
		"29": Vector2(21, 21),
		"30": Vector2(21, 21),
		"31": Vector2(21, 21),
		"32": Vector2(21, 21),
		"33": Vector2(21, 21),
	},
	"ThrongA_Mitosis_Spritesheet": {
		"0": Vector2(24, 24),
		"1": Vector2(24, 24),
		"2": Vector2(24, 24),
		"3": Vector2(24, 24),
		"4": Vector2(24, 24),
		"5": Vector2(24, 24),
		"6": Vector2(24, 24),
		"7": Vector2(24, 24),
		"8": Vector2(24, 24),
		"9": Vector2(24, 24),
		"10": Vector2(24, 24),
		"11": Vector2(24, 24),
		"12": Vector2(24, 24),
		"13": Vector2(24, 24),
		"14": Vector2(24, 24),
		"15": Vector2(24, 24),
		"16": Vector2(24, 24),
		"17": Vector2(24, 24),
		"18": Vector2(24, 24),
		"19": Vector2(24, 24),
		"20": Vector2(24, 24),
		"21": Vector2(24, 24),
		"22": Vector2(24, 24),
		"23": Vector2(24, 24),
		"24": Vector2(24, 24),
		"25": Vector2(24, 24),
		"26": Vector2(24, 24),
		"27": Vector2(24, 24),
		"28": Vector2(24, 24),
		"29": Vector2(24, 24),
		"30": Vector2(24, 24),
		"31": Vector2(24, 24),
		"32": Vector2(24, 24),
		"33": Vector2(24, 24),
		"34": Vector2(24, 24),
		"35": Vector2(24, 24),
	},
	"ThrongA_Roundabout_SpriteSheet": {
		"0": Vector2(15, 15),
		"1": Vector2(15, 15),
		"2": Vector2(15, 15),
		"3": Vector2(15, 15),
		"4": Vector2(15, 15),
		"5": Vector2(15, 15),
		"6": Vector2(15, 15),
		"7": Vector2(15, 15),
	},
	"Throng_Alien_EggHatch": {
		"0": Vector2(3, 3),
		"1": Vector2(3, 3),
		"2": Vector2(3, 3),
	},
	"Throng_FallInBath_Spritesheet": {
		"0": Vector2(-8, -4),
		"1": Vector2(-8, -4),
		"2": Vector2(-8, -4),
		"3": Vector2(-8, -4),
		"4": Vector2(-8, -4),
		"5": Vector2(-8, -4),
		"6": Vector2(-8, -4),
		"7": Vector2(-8, -4),
	},
}

# Clip -> {frame index: degrees}. Missing index means 0. One frame does not rotate the others.
const FRAME_ROT := {}

const GAME := [
	"ThrongA_Default",
	"ThrongA_Default Blink",
	"Throng_Walk_Anim_Spritesheet",
	"Throng_WalkBack_Anim_Spritesheet",
	"Throng_Walk_Homed_Spritesheet",
	"ThrongA_Eat",
	"ThrongA_Sad",
	"ThrongA_Grumpy",
	"ThrongA_Happy",
	"Throng_FallInBath_Spritesheet",
	"ThrongA_Pickaxe_Spritesheet",
	"ThrongA_Jump_VariantA_Spritesheet",
	"ThrongA_Roundabout_SpriteSheet",
	"ThrongA_Mitosis_Spritesheet",
	"ThrongA_Dead_001",
	"ThrongA_Dead_002",
	"ThrongA_Bones",
	"ThrongA_Talk",
	"ThrongA_EarWiggleLow",
	"ThrongA_Celebrate_Spritesheet",
	"ThrongA_Shrug",
	"Throng_Think_Spritesheet",
	"ThrongA_Jump",
	"ThrongA_Bored_KickRock",
	"ThrongA_Default_Ghost",
	"Throng_Sing_Spritesheet",
	"Throng_SingB_Spritesheet",
	"Throng_SingC_Spritesheet",
	"ThrongA_SingToThronglet_Spritesheet2",
]

static var overrides := {}


static func game_names() -> PackedStringArray:
	var names := PackedStringArray()
	for raw in GAME:
		var clip := str(raw)
		if ThrongClips.has_clip(clip):
			names.append(clip)
	return names


static func rest_names() -> PackedStringArray:
	var skip := {}
	for raw in GAME:
		skip[str(raw)] = true
	var names := PackedStringArray()
	for key in ThrongClips.CLIPS.keys():
		var clip := str(key)
		if skip.has(clip):
			continue
		names.append(clip)
	names.sort()
	return names


static func fps_editable(clip: String) -> bool:
	if ALONG.has(clip):
		return false
	return _count(clip) > 1


static func get_tune(clip: String) -> Dictionary:
	var tune := {
		"fps": default_fps(clip),
		"frame_scale": default_frame_scale(clip),
		"frame_off": default_frame_off(clip),
		"frame_rot": default_frame_rot(clip),
	}
	if not overrides.has(clip):
		return tune
	var over: Dictionary = overrides[clip]
	for key in over.keys():
		tune[key] = over[key]
	return tune


static func is_dirty(clip: String) -> bool:
	return overrides.has(clip) and not (overrides[clip] as Dictionary).is_empty()


static func change_count() -> int:
	var n := 0
	for clip in _every():
		if is_dirty(clip):
			n += 1
	return n


static func default_fps(clip: String) -> float:
	if not FPS.has(clip):
		return 8.0
	return float(FPS[clip])


static func default_scale(clip: String) -> float:
	if not SCALE.has(clip):
		return 1.0
	return float(SCALE[clip])


static func default_frame_scale(clip: String) -> Dictionary:
	if not FRAME_SCALE.has(clip):
		return {}
	var raw: Dictionary = FRAME_SCALE[clip]
	return raw.duplicate()


static func frame_scale(clip: String, index: int) -> float:
	var map: Dictionary = get_tune(clip).get("frame_scale", {})
	if map.has(str(index)):
		return float(map[str(index)])
	return default_scale(clip)


static func default_frame_off(clip: String) -> Dictionary:
	if not FRAME_OFF.has(clip):
		return {}
	var raw: Dictionary = FRAME_OFF[clip]
	return raw.duplicate()


static func frame_offset(clip: String, index: int) -> Vector2:
	var map: Dictionary = get_tune(clip).get("frame_off", {})
	var raw = map.get(str(index), Vector2.ZERO)
	if raw is Vector2:
		return raw
	return Vector2.ZERO


static func default_frame_rot(clip: String) -> Dictionary:
	if not FRAME_ROT.has(clip):
		return {}
	var raw: Dictionary = FRAME_ROT[clip]
	return raw.duplicate()


static func frame_rot(clip: String, index: int) -> float:
	var map: Dictionary = get_tune(clip).get("frame_rot", {})
	return float(map.get(str(index), 0.0))


static func set_fps(clip: String, value: float) -> void:
	_assign(clip, "fps", snappedf(clampf(value, 0.5, 24.0), 0.5))


static func set_frame_scale(clip: String, index: int, value: float) -> void:
	if index < 0 or index >= _count(clip):
		return
	var map := default_frame_scale(clip)
	if overrides.has(clip) and (overrides[clip] as Dictionary).has("frame_scale"):
		map = (overrides[clip]["frame_scale"] as Dictionary).duplicate()
	var snapped := snappedf(clampf(value, 0.25, 3.0), 0.05)
	if is_equal_approx(snapped, default_scale(clip)):
		map.erase(str(index))
	else:
		map[str(index)] = snapped
	_assign(clip, "frame_scale", map)


static func set_frame_offset(clip: String, index: int, x: float, y: float) -> void:
	if index < 0 or index >= _count(clip):
		return
	var map := default_frame_off(clip)
	if overrides.has(clip) and (overrides[clip] as Dictionary).has("frame_off"):
		map = (overrides[clip]["frame_off"] as Dictionary).duplicate()
	var at := Vector2(snappedf(clampf(x, -160.0, 160.0), 1.0), snappedf(clampf(y, -160.0, 160.0), 1.0))
	if at.is_zero_approx():
		map.erase(str(index))
	else:
		map[str(index)] = at
	_assign(clip, "frame_off", map)


static func set_frame_rot(clip: String, index: int, value: float) -> void:
	if index < 0 or index >= _count(clip):
		return
	var map := default_frame_rot(clip)
	if overrides.has(clip) and (overrides[clip] as Dictionary).has("frame_rot"):
		map = (overrides[clip]["frame_rot"] as Dictionary).duplicate()
	var snapped := snappedf(clampf(value, -180.0, 180.0), 1.0)
	if is_equal_approx(snapped, 0.0):
		map.erase(str(index))
	else:
		map[str(index)] = snapped
	_assign(clip, "frame_rot", map)


static func reset(clip: String) -> void:
	overrides.erase(clip)


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
		var clip := str(raw.get("id", ""))
		if not ThrongClips.has_clip(clip):
			continue
		var fields = raw.get("fields", {})
		if typeof(fields) != TYPE_DICTIONARY:
			continue
		for key in fields.keys():
			var field = fields[key]
			if typeof(field) != TYPE_DICTIONARY:
				continue
			if str(key) == "scale":
				if not fields.has("frame_scale"):
					_apply_legacy_scale(clip, field.get("to", null))
				continue
			var value = _read_value(clip, str(key), field.get("to", null))
			if value == null:
				continue
			_assign(clip, str(key), value)


static func save_file() -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("throng tune: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(_document(), "  "))
	file.close()
	return ProjectSettings.globalize_path(PATH)


static func _every() -> PackedStringArray:
	var names := PackedStringArray()
	for key in ThrongClips.CLIPS.keys():
		names.append(str(key))
	names.sort()
	return names


static func _count(clip: String) -> int:
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
	return maxi(box.y, 1)


static func _assign(clip: String, key: String, value) -> void:
	if not ThrongClips.has_clip(clip):
		return
	if key == "fps" and not fps_editable(clip):
		return
	var same := _same(key, _base_value(clip, key), value)
	if not overrides.has(clip):
		if same:
			return
		overrides[clip] = {}
	if same:
		overrides[clip].erase(key)
		if overrides[clip].is_empty():
			overrides.erase(clip)
		return
	overrides[clip][key] = value


static func _base_value(clip: String, key: String):
	if key == "fps":
		return default_fps(clip)
	if key == "frame_scale":
		return default_frame_scale(clip)
	if key == "frame_off":
		return default_frame_off(clip)
	if key == "frame_rot":
		return default_frame_rot(clip)
	return {}


static func _same(key: String, a, b) -> bool:
	if key == "frame_scale" or key == "frame_rot":
		return _rot_same(a, b)
	if key == "frame_off":
		return _off_same(a, b)
	return is_equal_approx(float(a), float(b))


static func _read_value(clip: String, key: String, raw):
	if raw == null:
		return null
	if key == "fps" and not fps_editable(clip):
		return null
	if key == "frame_scale":
		return _read_scale(clip, raw)
	if key == "frame_off":
		return _read_off(clip, raw)
	if key == "frame_rot":
		return _read_rot(clip, raw)
	if key != "fps":
		return null
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return null
	return snappedf(clampf(float(raw), 0.5, 24.0), 0.5)


static func _document() -> Dictionary:
	var changes: Array = []
	for clip in _every():
		if not is_dirty(clip):
			continue
		var tune := get_tune(clip)
		var fields := {}
		var keys: Array = ["frame_scale", "frame_off", "frame_rot"]
		if fps_editable(clip):
			keys.append("fps")
		for key in keys:
			var name := str(key)
			if _same(name, _base_value(clip, name), tune[name]):
				continue
			var apply := _apply(clip, name)
			if name == "frame_scale":
				apply = _scale_apply(clip, tune[name])
			elif name == "frame_off":
				apply = _off_apply(clip, tune[name])
			elif name == "frame_rot":
				apply = _rot_apply(clip, tune[name])
			fields[name] = {
				"from": _json_value(name, _base_value(clip, name)),
				"to": _json_value(name, tune[name]),
				"apply_in": apply,
			}
		if fields.is_empty():
			continue
		var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
		changes.append({
			"id": clip,
			"start": box.x,
			"count": box.y,
			"frames": [box.x, box.x + box.y - 1],
			"fields": fields,
		})
	return {
		"version": 1,
		"do_not_runtime_load": true,
		"how_to_apply": _how(),
		"units": {
			"fps": "frames per second. Replaces the multiplier in frame_at(clip, int(time * fps)). pick() uses 8.",
			"frame_scale": "sprite scale keyed by frame index. A missing index uses SCALE, or 1",
			"frame_off": "extra world pixels [x, y] after the feet, keyed by frame index. A missing index stays at (0, 0)",
			"frame_rot": "degrees clockwise around the feet, keyed by frame index. A missing index stays at 0",
		},
		"changes": changes,
	}


static func _span(clip: String) -> String:
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
	return "frames %d through %d" % [box.x, box.x + box.y - 1]


static func _apply(clip: String, key: String) -> String:
	var span := _span(clip)
	if key == "fps":
		return "Only this clip, %s. %s Replace that multiplier with to and keep any + float(i) phase. If a pool plays it through ThrongClips.pick, use to for this clip only and leave every clip that is not in changes at 8. If nothing plays this clip, do not add a call. In throng_tune.gd set FPS[\"%s\"] to to, or remove the key when to is 8. Do not change ThrongClips.CLIPS. Do not load this file at runtime." % [span, _fps_where(clip), clip]
	return ""


static func _scale_apply(clip: String, value: Dictionary) -> String:
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
	var bits := PackedStringArray()
	var keys: Array = value.keys()
	keys.sort()
	for raw in keys:
		var index := int(raw)
		bits.append("index %d (sheet %d) = %s" % [index, box.x + index, str(snappedf(float(value[raw]), 0.05))])
	var listed := "no scaled frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of this clip, %s. %s. Pass that scale to _push_iso only when the drawn sheet frame is listed. Every other frame stays at the clip default, SCALE or 1. Do not use _pad_nudge. In throng_tune.gd set FRAME_SCALE[\"%s\"] to the to map, or remove the key when it is empty. Do not scale the whole clip unless every index is listed. Do not load this file at runtime." % [_span(clip), listed, clip]


static func _off_apply(clip: String, value: Dictionary) -> String:
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
	var bits := PackedStringArray()
	var keys: Array = value.keys()
	keys.sort()
	for raw in keys:
		var index := int(raw)
		var at: Vector2 = value[raw]
		bits.append("index %d (sheet %d) = [%d, %d]" % [index, box.x + index, int(round(at.x)), int(round(at.y))])
	var listed := "no moved frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of this clip, %s. %s. Add that [x, y] as world pixels after the feet on that sheet frame only. +x east, +y south. Every other frame of the clip stays at (0, 0). It is not a pad nudge. In throng_tune.gd set FRAME_OFF[\"%s\"] to the to map, or remove the key when it is empty. Do not move the whole clip. Do not load this file at runtime." % [_span(clip), listed, clip]


static func _rot_apply(clip: String, value: Dictionary) -> String:
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(0, 1))
	var bits := PackedStringArray()
	var keys: Array = value.keys()
	keys.sort()
	for raw in keys:
		var index := int(raw)
		bits.append("index %d (sheet %d) = %d degrees" % [index, box.x + index, int(round(float(value[raw])))])
	var listed := "no rotated frames" if bits.is_empty() else ", ".join(bits)
	return "Only these frames of this clip, %s. %s. Main._write_mesh reads draw rot and spins that one quad clockwise around the feet. Set rot only when the drawn sheet frame is listed. Every other frame of the clip stays at 0. In throng_tune.gd set FRAME_ROT[\"%s\"] to the to map, or remove the key when it is empty. Do not rotate the whole clip. Do not load this file at runtime." % [_span(clip), listed, clip]


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


static func _read_scale(clip: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := _count(clip)
	var base := default_scale(clip)
	for key in raw.keys():
		var index := int(key)
		if index < 0 or index >= n:
			continue
		var value = raw[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		var snapped := snappedf(clampf(float(value), 0.25, 3.0), 0.05)
		if not is_equal_approx(snapped, base):
			map[str(index)] = snapped
	return map


static func _apply_legacy_scale(clip: String, raw) -> void:
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return
	var snapped := snappedf(clampf(float(raw), 0.25, 3.0), 0.05)
	for index in _count(clip):
		set_frame_scale(clip, index, snapped)


static func _read_off(clip: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := _count(clip)
	for key in raw.keys():
		var index := int(key)
		if index < 0 or index >= n:
			continue
		var value = raw[key]
		if typeof(value) != TYPE_ARRAY or value.size() < 2:
			continue
		var at := Vector2(snappedf(clampf(float(value[0]), -160.0, 160.0), 1.0), snappedf(clampf(float(value[1]), -160.0, 160.0), 1.0))
		if not at.is_zero_approx():
			map[str(index)] = at
	return map


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


static func _read_rot(clip: String, raw):
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var map := {}
	var n := _count(clip)
	for key in raw.keys():
		var index := int(key)
		if index < 0 or index >= n:
			continue
		var value = raw[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			continue
		var snapped := snappedf(clampf(float(value), -180.0, 180.0), 1.0)
		if not is_equal_approx(snapped, 0.0):
			map[str(index)] = snapped
	return map


static func _fps_where(clip: String) -> String:
	match clip:
		"ThrongA_Eat":
			return "Main._frame ACT_EAT calls frame_at(clip, int(time * 6.0))."
		"ThrongA_Happy":
			return "Main._frame calls frame_at(clip, int(time * 6.0)) for an empty bath and for ACT_WASH. CALM and SING also reach it through ThrongClips.pick, which uses 8."
		"ThrongA_Sad":
			return "Main._frame calls frame_at(clip, int(time * 6.0)) when fed or clean is low."
		"Throng_Walk_Anim_Spritesheet":
			return "Main._frame calls frame_at(clip, int(time * 8.0 + float(i))) for forward or side movement and for play-with-ball."
		"Throng_WalkBack_Anim_Spritesheet":
			return "Main._frame calls frame_at(clip, int(time * 8.0 + float(i))) when moving away, including play-with-ball."
		"ThrongA_Jump_VariantA_Spritesheet":
			return "Main._frame ACT_PLAY calls frame_at(clip, int(time * 8.0)) when there is no ball and no ride."
		"ThrongA_Roundabout_SpriteSheet":
			return "Main._frame ACT_PLAY calls frame_at(clip, int(time * 8.0)) when the thronglet is on a ride."
		"ThrongA_Pickaxe_Spritesheet":
			return "Main._frame ACT_WORK calls frame_at(clip, int(time * 8.0)) while standing."
		_:
			return "No direct frame_at rate. ThrongClips.pick plays a pooled clip at int(local * 8.0). Idle chatter uses Main.CALM, singing uses Main.SING, frozen talk uses ThrongClips.TALK."


static func _json_rot(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var keys: Array = raw.keys()
	keys.sort()
	for key in keys:
		out[str(key)] = int(round(float(raw[key])))
	return out


static func _json_scale(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var keys: Array = raw.keys()
	keys.sort()
	for key in keys:
		out[str(key)] = snappedf(float(raw[key]), 0.05)
	return out


static func _json_off(value) -> Dictionary:
	var out := {}
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var keys: Array = raw.keys()
	keys.sort()
	for key in keys:
		var at: Vector2 = raw[key]
		out[str(key)] = [int(round(at.x)), int(round(at.y))]
	return out


static func _json_value(key: String, value):
	if key == "frame_off":
		return _json_off(value)
	if key == "frame_scale":
		return _json_scale(value)
	if key == "frame_rot":
		return _json_rot(value)
	return snappedf(float(value), 0.5)


static func _how() -> String:
	return " ".join(PackedStringArray([
		"Apply each object in changes and nothing else.",
		"Do not load this file at runtime. Edit Main so the live draw matches to, then update the matching const in throng_tune.gd so the bench default matches and a later save does not ask for the same change.",
		"from is the bench default at save time. to is the absolute value the bench showed.",
		"frames is the inclusive sheet index range. Clip ranges do not overlap.",
		"fps is the frame_at multiplier. One-frame clips, mitosis, and the bath fall have no fps field. Mitosis and the bath fall advance with frame_along.",
		"frame_scale keys are frame indexes. One entry scales that sprite only. A missing index stays at SCALE, or 1.",
		"frame_off keys are frame indexes. One entry moves that sprite only. A missing index stays at (0, 0). Do not edit the sheet and do not edit _CENTER.",
		"frame_rot keys are frame indexes. One entry rotates that sprite only. A missing index stays at 0.",
		"Do not change clips, props, costs, or frame ranges that are not listed.",
	]))
