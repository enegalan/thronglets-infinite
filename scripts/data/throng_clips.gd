class_name ThrongClips
extends Object

const SHEET_COLS := 16
const SHEET_ROWS := 46
const BASE := 144

const CLIPS := {
	"ThrongA_PanicRun": Vector2i(654, 4),
	"ThrongA_PanicRunFire": Vector2i(658, 4),
	"ThrongA_FreakOut": Vector2i(662, 12),
	"ThrongA_LiftProp": Vector2i(674, 7),
	"ThrongA_LiftPropWalk": Vector2i(681, 2),
	"ThrongA_DropProp": Vector2i(683, 4),
	"ThrongA_Happy_Walk": Vector2i(687, 2),
	"ThrongA_Sad_Walk": Vector2i(689, 2),
	"ThrongA_PuppyDogEyes": Vector2i(691, 4),
	"ThrongA_InAwe": Vector2i(695, 4),
	"ThrongA_Deflesh": Vector2i(699, 24),
	"ThrongA_AngryAtPlayer_Spritesheet": Vector2i(144, 3),
	"ThrongA_Bones": Vector2i(147, 1),
	"ThrongA_Bored_KickRock": Vector2i(148, 14),
	"ThrongA_Celebrate_Spritesheet": Vector2i(162, 9),
	"ThrongA_Dead_001": Vector2i(171, 1),
	"ThrongA_Dead_002": Vector2i(172, 1),
	"ThrongA_DeepThought_Spritesheet": Vector2i(173, 3),
	"ThrongA_Default": Vector2i(176, 1),
	"ThrongA_Default Blink": Vector2i(177, 1),
	"ThrongA_EarWiggleLow": Vector2i(178, 8),
	"ThrongA_EarWiggleStand": Vector2i(186, 4),
	"ThrongA_Eat": Vector2i(190, 2),
	"ThrongA_Grumpy": Vector2i(192, 1),
	"ThrongA_Happy": Vector2i(193, 5),
	"ThrongA_ImpactfulExplanation_Spritesheet": Vector2i(198, 3),
	"ThrongA_Jump": Vector2i(201, 1),
	"ThrongA_Jump-EarWiggle": Vector2i(202, 5),
	"ThrongA_JumpBlink": Vector2i(207, 1),
	"ThrongA_Jump_High": Vector2i(208, 1),
	"ThrongA_Jump_VariantA_Spritesheet": Vector2i(209, 10),
	"ThrongA_LooktAtPlayerHappyNod_Spritesheet": Vector2i(219, 10),
	"ThrongA_MitosisCutscene_NoBlood_Spritesheet": Vector2i(229, 34),
	"ThrongA_Mitosis_Spritesheet": Vector2i(263, 36),
	"ThrongA_Pickaxe_Spritesheet": Vector2i(299, 9),
	"ThrongA_Possessed_AntennaSpinEar_Spritesheet": Vector2i(308, 6),
	"ThrongA_Possessed_AntennaSpinTalk_Spritesheet": Vector2i(314, 6),
	"ThrongA_Possessed_AntennaSpin_Spritesheet": Vector2i(320, 6),
	"ThrongA_Possessed_EarRaise_Spritesheet": Vector2i(326, 6),
	"ThrongA_ReactToKill": Vector2i(332, 6),
	"ThrongA_Rotund_Spritesheet": Vector2i(338, 4),
	"ThrongA_Roundabout_SpriteSheet": Vector2i(342, 8),
	"ThrongA_Sad": Vector2i(350, 7),
	"ThrongA_Shrug": Vector2i(357, 4),
	"ThrongA_SingToThronglet_Spritesheet2": Vector2i(361, 6),
	"ThrongA_SkepticalToPlayer_Spritesheet": Vector2i(367, 3),
	"ThrongA_Sophisticated": Vector2i(370, 1),
	"ThrongA_Squint": Vector2i(371, 3),
	"ThrongA_Step01": Vector2i(374, 1),
	"ThrongA_Step01_noface": Vector2i(375, 1),
	"ThrongA_Step02": Vector2i(376, 1),
	"ThrongA_Step02_noface": Vector2i(377, 1),
	"ThrongA_Talk": Vector2i(378, 6),
	"ThrongA_TalkToOtherThronglet_Spritesheet2": Vector2i(384, 3),
	"ThrongA_Talk_Blink_Spritesheet": Vector2i(387, 8),
	"ThrongA_Talk_EarOffset_Spritesheet": Vector2i(395, 5),
	"ThrongA_Talk_EyeRoll_Spritesheet": Vector2i(400, 7),
	"ThrongA_Talk_HandsBack_Spritesheet": Vector2i(407, 6),
	"ThrongA_Talk_Low_Spritesheet": Vector2i(413, 6),
	"ThrongA_Talk_OffCenter": Vector2i(419, 6),
	"ThrongA_Talk_ScratchArm_Spritesheet": Vector2i(425, 9),
	"ThrongA_Talk_Tall_Spritesheet": Vector2i(434, 6),
	"ThrongB_SingToThronglet_Spritesheet2": Vector2i(440, 8),
	"ThrongB_TalkToOtherThronglet_Spritesheet2": Vector2i(448, 3),
	"ThrongC_SingToThronglet_Spritesheet2": Vector2i(451, 8),
	"ThrongC_TalkToOtherThronglet_Spritesheet2": Vector2i(459, 3),
	"ThrongD_SingToThronglet_Spritesheet2": Vector2i(462, 9),
	"ThrongD_TalkToOtherThronglet_Spritesheet2": Vector2i(471, 3),
	"ThrongE_SingToThronglet_Spriesheet2": Vector2i(474, 8),
	"ThrongE_TalkToOtherThronglet_Spritesheet": Vector2i(482, 3),
	"ThrongE_TalkToOtherThronglet_Spritesheet2": Vector2i(485, 3),
	"Throng_Anim_Flying_Spritesheet": Vector2i(516, 9),
	"Throng_Egg_A": Vector2i(525, 1),
	"Throng_Egg_A_Glow": Vector2i(526, 1),
	"Throng_Egg_A_WiggleLeft": Vector2i(527, 1),
	"Throng_Egg_A_WiggleRight": Vector2i(528, 1),
	"Throng_Egg_B": Vector2i(529, 1),
	"Throng_Egg_B_Glow": Vector2i(530, 1),
	"Throng_Egg_B_WiggleLeft": Vector2i(531, 1),
	"Throng_Egg_B_WiggleRight": Vector2i(532, 1),
	"Throng_Egg_C": Vector2i(533, 1),
	"Throng_Egg_C_Empty": Vector2i(534, 1),
	"Throng_Egg_Sparkle_SpriteSheet2": Vector2i(535, 5),
	"Throng_FallInBath_Spritesheet": Vector2i(540, 8),
	"Throng_Grumpy3": Vector2i(548, 2),
	"Throng_Grumpy_Sheet": Vector2i(550, 3),
	"Throng_Idle_AntennaSpin_EyesClosed_Spritesheet": Vector2i(553, 4),
	"Throng_Idle_AntennaSpin_Spritesheet": Vector2i(557, 4),
	"Throng_Idle_BackTurned": Vector2i(561, 1),
	"Throng_Idle_EarsUp": Vector2i(562, 1),
	"Throng_Idle_EyesDirection_Spritesheet": Vector2i(563, 8),
	"Throng_Prop_Blood_A": Vector2i(571, 1),
	"Throng_Prop_Shadow_A": Vector2i(572, 1),
	"Throng_Prop_Shadow_A 1": Vector2i(573, 1),
	"Throng_SarcasticSquint2": Vector2i(574, 3),
	"Throng_SarcasticSquint3": Vector2i(577, 2),
	"Throng_SingB_Spritesheet": Vector2i(579, 8),
	"Throng_SingC_Spritesheet": Vector2i(587, 9),
	"Throng_SingD_Spritesheet": Vector2i(596, 9),
	"Throng_SingE_Spritesheet": Vector2i(605, 8),
	"Throng_Sing_Spritesheet": Vector2i(613, 6),
	"Throng_Sophisticated2": Vector2i(619, 3),
	"Throng_Sophisticated3": Vector2i(622, 2),
	"Throng_Think_Spritesheet": Vector2i(624, 5),
	"Throng_Think_TwiddleThumbs_Spritesheet": Vector2i(629, 7),
	"Throng_WalkBack_Anim_Spritesheet": Vector2i(636, 5),
	"Throng_Walk_Anim_Spritesheet": Vector2i(641, 5),
	"Throng_Walk_Homed_Spritesheet": Vector2i(646, 5),
	"ThrongA_Default_Ghost": Vector2i(651, 1),
	"Thronglet_Outline": Vector2i(652, 1),
	"Throng_Outline": Vector2i(653, 1),
}

## Situation pools. Prefer these over ad-hoc Main literals.
const IDLE_CALM := [
		"ThrongA_Default",
		"ThrongA_Default Blink",
		"ThrongA_Happy",
		"ThrongA_EarWiggleLow",
		"Throng_Idle_AntennaSpin_Spritesheet",
		"Throng_Idle_EyesDirection_Spritesheet",
		"Throng_Idle_EarsUp",
		"Throng_Idle_BackTurned",
		"Throng_Think_Spritesheet",
]

const IDLE_SLEEP := [
		"Throng_Idle_AntennaSpin_EyesClosed_Spritesheet",
]

const MOOD_BORED := [
		"ThrongA_Bored_KickRock",
		"Throng_Grumpy_Sheet",
		"Throng_Grumpy3",
		"ThrongA_Grumpy",
		"ThrongA_PuppyDogEyes",
]

const MOOD_SAD := [
		"ThrongA_Sad",
]

const SING_PEER := [
		"Throng_Sing_Spritesheet",
		"Throng_SingB_Spritesheet",
		"Throng_SingC_Spritesheet",
		"Throng_SingD_Spritesheet",
		"Throng_SingE_Spritesheet",
		"ThrongA_SingToThronglet_Spritesheet2",
		"ThrongB_SingToThronglet_Spritesheet2",
		"ThrongC_SingToThronglet_Spritesheet2",
		"ThrongD_SingToThronglet_Spritesheet2",
		"ThrongE_SingToThronglet_Spriesheet2",
]

const TALK_PEER := [
		"ThrongA_TalkToOtherThronglet_Spritesheet2",
		"ThrongB_TalkToOtherThronglet_Spritesheet2",
		"ThrongC_TalkToOtherThronglet_Spritesheet2",
		"ThrongD_TalkToOtherThronglet_Spritesheet2",
		"ThrongE_TalkToOtherThronglet_Spritesheet",
		"ThrongE_TalkToOtherThronglet_Spritesheet2",
]

const TALK_CONSOLE := [
		"ThrongA_Talk",
		"ThrongA_Talk_Blink_Spritesheet",
		"ThrongA_Talk_EarOffset_Spritesheet",
		"ThrongA_Talk_EyeRoll_Spritesheet",
		"ThrongA_Talk_HandsBack_Spritesheet",
		"ThrongA_Talk_Low_Spritesheet",
		"ThrongA_Talk_OffCenter",
		"ThrongA_Talk_ScratchArm_Spritesheet",
		"ThrongA_Talk_Tall_Spritesheet",
]

const TALK_REACT := [
		"ThrongA_LooktAtPlayerHappyNod_Spritesheet",
		"ThrongA_SkepticalToPlayer_Spritesheet",
		"ThrongA_AngryAtPlayer_Spritesheet",
		"ThrongA_DeepThought_Spritesheet",
		"ThrongA_ImpactfulExplanation_Spritesheet",
		"ThrongA_Shrug",
		"ThrongA_InAwe",
]

const POSSESSED := [
		"ThrongA_Possessed_AntennaSpin_Spritesheet",
		"ThrongA_Possessed_AntennaSpinTalk_Spritesheet",
		"ThrongA_Possessed_AntennaSpinEar_Spritesheet",
		"ThrongA_Possessed_EarRaise_Spritesheet",
]

const CELEBRATE := [
		"ThrongA_Celebrate_Spritesheet",
		"ThrongA_Jump",
		"ThrongA_Jump-EarWiggle",
]

const PANIC := [
		"ThrongA_ReactToKill",
		"ThrongA_FreakOut",
		"ThrongA_PanicRun",
		"ThrongA_PanicRunFire",
]

const STRIP_DIR := "res://resources/sprites/throng_anims/"
const STRIP_MANIFEST := STRIP_DIR + "manifest.json"

static var _frame_clip: PackedStringArray = PackedStringArray()
static var _frame_index: PackedInt32Array = PackedInt32Array()
static var _frame_map_ready := false
static var _strip_tex: Dictionary = {}
static var _strip_meta: Dictionary = {}
static var _sprite_frames: SpriteFrames = null

static func has_clip(clip: String) -> bool:
	return CLIPS.has(clip)

static func frame_count(clip: String) -> int:
	var box: Vector2i = CLIPS.get(clip, Vector2i(20, 1))
	return maxi(box.y, 1)

static func frame_at(clip: String, tick: int) -> int:
	var box: Vector2i = CLIPS.get(clip, Vector2i(20, 1))
	if box.y <= 1:
		return box.x
	return box.x + posmod(tick, box.y)

static func frame_along(clip: String, along: float) -> int:
	var box: Vector2i = CLIPS.get(clip, Vector2i(20, 1))
	var n := maxi(box.y, 1)
	return box.x + clampi(int(clampf(along, 0.0, 0.999) * float(n)), 0, n - 1)

static func pick(pool: Array, index: int, time: float, hold: float) -> int:
	if pool.is_empty():
		return 20
	var which := int(time / hold) + index
	var name := str(pool[posmod(which, pool.size())])
	var local := time - float(int(time / hold)) * hold
	return frame_at(name, int(local * 8.0))

static func strip_file(clip: String) -> String:
	return str(clip).replace(" ", "_").replace("/", "_") + ".png"

static func strip_path(clip: String) -> String:
	return STRIP_DIR + strip_file(clip)

static func _ensure_strip_meta() -> void:
	if not _strip_meta.is_empty():
		return
	if not FileAccess.file_exists(STRIP_MANIFEST):
		return
	var raw := FileAccess.get_file_as_string(STRIP_MANIFEST)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var clips: Variant = parsed.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY:
		return
	_strip_meta = clips

static func strip_tex(clip: String) -> Texture2D:
	if _strip_tex.has(clip):
		return _strip_tex[clip]
	var path := strip_path(clip)
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_strip_tex[clip] = tex
	return tex

static func strip_frame(clip: String, tick: int) -> AtlasTexture:
	var sheet := strip_tex(clip)
	if sheet == null:
		return null
	_ensure_strip_meta()
	var meta: Variant = _strip_meta.get(clip, {})
	var count := frame_count(clip)
	var cell_w := 0
	var cell_h := 0
	if typeof(meta) == TYPE_DICTIONARY:
		count = maxi(int(meta.get("frames", count)), 1)
		cell_w = int(meta.get("cell_w", 0))
		cell_h = int(meta.get("cell_h", 0))
	if cell_w <= 0:
		cell_w = maxi(sheet.get_width() / count, 1)
	if cell_h <= 0:
		cell_h = sheet.get_height()
	var idx := posmod(tick, count)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(idx * cell_w, 0, cell_w, cell_h)
	atlas.filter_clip = true
	return atlas

static func sprite_frames() -> SpriteFrames:
	if _sprite_frames != null:
		return _sprite_frames
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for clip in CLIPS.keys():
		var name := str(clip)
		frames.add_animation(name)
		frames.set_animation_speed(name, 8.0)
		frames.set_animation_loop(name, true)
		var n := frame_count(name)
		for i in n:
			var cell := strip_frame(name, i)
			if cell != null:
				frames.add_frame(name, cell)
	_sprite_frames = frames
	return _sprite_frames

static func _ensure_frame_map() -> void:
	if _frame_map_ready:
		return
	var max_frame := 0
	for clip in CLIPS.keys():
		var box: Vector2i = CLIPS[clip]
		max_frame = maxi(max_frame, box.x + box.y)
	_frame_clip.resize(max_frame)
	_frame_index.resize(max_frame)
	for i in max_frame:
		_frame_clip[i] = ""
		_frame_index[i] = -1
	for clip in CLIPS.keys():
		var box: Vector2i = CLIPS[clip]
		var name := str(clip)
		for i in box.y:
			var f := box.x + i
			_frame_clip[f] = name
			_frame_index[f] = i
	_frame_map_ready = true

static func clip_name_at(frame: int) -> String:
	_ensure_frame_map()
	if frame < 0 or frame >= _frame_clip.size():
		return ""
	return _frame_clip[frame]

static func clip_index_at(frame: int) -> int:
	_ensure_frame_map()
	if frame < 0 or frame >= _frame_index.size():
		return -1
	return _frame_index[frame]

static func info_at(frame: int) -> Dictionary:
	var clip := clip_name_at(frame)
	if clip.is_empty():
		return {}
	return {"clip": clip, "index": clip_index_at(frame)}

