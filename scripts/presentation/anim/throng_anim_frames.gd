extends RefCounted
class_name ThrongAnimFrames

# Atlas frame selection for thronglets, features, props, and carry items.

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const ThrongTune := preload("res://scripts/data/tune/throng_tune.gd")
const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")
const TiovivoLabTune := preload("res://scripts/data/tune/tiovivo_lab_tune.gd")

## Catalog icon ids mapped to rows in the large building/prop atlas band.
const _BIG := {
	Catalog.ICON_TREE: 0,
	Catalog.ICON_ROCK: 1,
	Catalog.ICON_ORE_ROCK: 2,
	Catalog.ICON_NODE: 3,
	Catalog.ICON_SUPER: 4,
	Catalog.ICON_APPLE_TREE: 5,
	Catalog.ICON_TUB: 6,
	Catalog.ICON_ROUND: 7,
	Catalog.ICON_DWELL: 8,
	Catalog.ICON_FANCY: 9,
	Catalog.ICON_MINE: 10,
	Catalog.ICON_MINE2: 11,
	Catalog.ICON_FACTORY: 12,
	Catalog.ICON_FACTORY2: 13,
	Catalog.ICON_THEATRE: 14,
	Catalog.ICON_MARKET: 15,
	Catalog.ICON_MONOLITH: 16,
	Catalog.ICON_STATUE: 17,
	Catalog.ICON_GOO: 18,
	Catalog.ICON_BIGROCK: 19,
	Catalog.ICON_COSMETIC: 20,
	Catalog.ICON_COSMETIC_BAD: 21,
	Catalog.ICON_ORE_MEGA: 22,
	Catalog.ICON_ORE_SUPER: 23,
	Catalog.ICON_ORE_ULTRA: 24,
	Catalog.ICON_WOOD_STATUE: 25,
	Catalog.ICON_FIRE: 26,
	Catalog.ICON_TOTEM: 27,
	Catalog.ICON_CURER: 28,
	Catalog.ICON_JACK: 29,
	Catalog.ICON_SUPERBUG: 30,
	Catalog.ICON_MSTUMP: 31,
	Catalog.ICON_MNODE: 32,
}


## Resolves effect tune clip or returns fallback.
func effect_look_clip(id: String, fallback: String) -> String:
	var clip := str(EffectTune.get_tune(id).get("clip", ""))
	if clip != "" and ThrongClips.has_clip(clip):
		return clip
	return fallback


## True when throng [param i] must not use far-view walk simplification.
func throng_special_body(sim: ThrongletSim, i: int) -> bool:
	# Situations that must not collapse to Default/Walk under far/crowd LOD.
	if sim.frozen or sim.celebrate_t > 0.0:
		return true
	if i < sim.react_t.size() and sim.react_t[i] > 0.0:
		return true
	if i < sim.sleep_t.size() and sim.sleep_t[i] > 0.0:
		return true
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		return true
	if i < sim.drop_t.size() and sim.drop_t[i] > 0.0:
		return true
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return true
	if sim.near_fire(i):
		return true
	if i < sim.penned_flag.size() and sim.penned_flag[i] != 0:
		return true
	if int(sim.act[i]) != 0:
		return true
	if int(sim.carry[i]) != Catalog.CARRY_NONE:
		return true
	return false


## Body frame for throng [param i], simplified when [param far_view].
func frame_lod(i: int, time: float, far_view: bool) -> int:
	if not far_view:
		return frame(i, time)
	var sim: ThrongletSim = ThrongletSimServer
	if sim.state[i] == Catalog.ST_DEAD:
		return ThrongClips.frame_at("ThrongA_Dead_001" if sim.dir_x[i] >= 0.0 else "ThrongA_Dead_002", 0)
	# Far view may simplify ambient idle/walk only — never drop act/timer/critical bodies.
	if throng_special_body(sim, i):
		return frame(i, time)
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if moving:
		if absf(sim.dir_y[i]) > absf(sim.dir_x[i]) and sim.dir_y[i] < 0.0:
			return ThrongClips.frame_at("Throng_WalkBack_Anim_Spritesheet", int(time * 8.0 + float(i)))
		return ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", int(time * 8.0 + float(i)))
	if sim.clean[i] < 12.0 or sim.fed[i] < 25.0:
		return ThrongClips.frame_at("ThrongA_Sad", 0)
	return ThrongClips.frame_at("ThrongA_Default", 0)


## Full-detail body frame for throng [param i] at [param time].
func frame(i: int, time: float) -> int:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.state[i] == Catalog.ST_DEAD:
		var clip := "ThrongA_Dead_001" if sim.dir_x[i] >= 0.0 else "ThrongA_Dead_002"
		return ThrongClips.frame_at(clip, 0)
	# Held: one stable body at the cursor — do not keep cycling situation pools.
	if sim.held_kind == "thronglet" and i == sim.held_ref:
		return ThrongClips.frame_at("ThrongA_Default", 0)
	if sim.frozen:
		# 0–300 ms stagger by index (cinematic §2).
		var stare_t := time + float(i) * 0.03
		if sim.glitch_t > 0.45:
			return clip_pool(ThrongClips.POSSESSED, i, stare_t, 2.0, "ThrongA_Possessed_AntennaSpinTalk_Spritesheet")
		# Mood accents when swarm mood is tagged; otherwise console talk loop.
		if sim.mood_face != "base" and posmod(i + int(stare_t * 3.0), 5) == 0:
			return clip_pool(ThrongClips.TALK_REACT, i, stare_t, 1.2, "ThrongA_LooktAtPlayerHappyNod_Spritesheet")
		return clip_pool(ThrongClips.TALK_CONSOLE, i, stare_t, 2.4, "ThrongA_Talk")
	if sim.celebrate_t > 0.0:
		# Unlock swarm only — Jump accents are asset/shots, not live-mixed.
		return ThrongClips.frame_at("ThrongA_Celebrate_Spritesheet", int(time * 8.0 + float(i)))
	if i < sim.react_t.size() and sim.react_t[i] > 0.0:
		return ThrongClips.frame_at("ThrongA_ReactToKill", int((ThrongletSimServer.REACT_DUR - sim.react_t[i]) * 8.0))
	# Just finished a wash: stand still on Happy (not walk).
	if i < sim.cheer_t.size() and sim.cheer_t[i] > 0.0:
		return ThrongClips.frame_at(effect_look_clip("act:wash_sparkle", "ThrongA_Happy"), int(time * 6.0))
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		if i < sim.peer_sing.size() and sim.peer_sing[i] != 0:
			return clip_pool(ThrongClips.SING_PEER, i, time, 1.6, "Throng_Sing_Spritesheet")
		return clip_pool(ThrongClips.TALK_PEER, i, time, 1.8, "ThrongA_TalkToOtherThronglet_Spritesheet2")
	if i < sim.drop_t.size() and sim.drop_t[i] > 0.0:
		var drop_along := 1.0 - clampf(sim.drop_t[i] / ThrongletSimServer.DROP_DUR, 0.0, 1.0)
		return ThrongClips.frame_along("ThrongA_DropProp", drop_along)
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		var along := 0.0
		if sim.mito_t[i] > 0.0:
			var split_t := 1.0 - clampf(sim.mito_t[i] / ThrongletSimServer.MITOSIS_ANIM, 0.0, 1.0)
			along = lerpf(ThrongletSimServer.MITOSIS_SPLIT_ALONG, 0.999, split_t)
		else:
			along = clampf(sim.mito_charge[i] / ThrongletSimServer.MITOSIS_CHARGE, 0.0, 1.0) * ThrongletSimServer.MITOSIS_SPLIT_ALONG
		return ThrongClips.frame_along("ThrongA_Mitosis_Spritesheet", along)
	# Critical bodies use one clip each — never mix the whole PANIC pool live.
	if sim.near_fire(i):
		return ThrongClips.frame_at("ThrongA_PanicRunFire", int(time * 10.0 + float(i)))
	if i < sim.penned_flag.size() and sim.penned_flag[i] != 0:
		return ThrongClips.frame_at("ThrongA_FreakOut", int(time * 10.0 + float(i)))
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	var carrying := int(sim.carry[i]) != Catalog.CARRY_NONE
	if doing == ThrongletSimServer.ACT_EAT:
		return ThrongClips.frame_at(effect_look_clip("act:eat", "ThrongA_Eat"), int(time * 6.0))
	if doing == ThrongletSimServer.ACT_BATH:
		var bath_clip := effect_look_clip("act:bath", "Throng_FallInBath_Spritesheet")
		var tub: Dictionary = sim.seat_of(i)
		if tub.is_empty():
			return ThrongClips.frame_at(effect_look_clip("act:bath_exit", "ThrongA_Happy"), int(time * 6.0))
		var age := float(tub.get("bath_t", 0.0))
		var enter_t := ThrongletSimServer.BATH_ENTER_T
		if age < 0.0:
			return ThrongClips.frame_at(bath_clip, 0)
		if age < enter_t:
			return ThrongClips.frame_along(bath_clip, (age / enter_t) * (5.0 / 8.0))
		return ThrongClips.frame_at(bath_clip, 5 + int((age - enter_t) * 2.5) % 3)
	if doing == ThrongletSimServer.ACT_WASH:
		# Stable Happy loop while scrubbing — do not restart from act_t pulses.
		return ThrongClips.frame_at(effect_look_clip("act:sponge", "ThrongA_Happy"), int(time * 6.0 + float(i) * 0.37))
	if doing == ThrongletSimServer.ACT_PLAY:
		if sim.has_ball(i):
			if moving:
				return walk_clip(i, time, sim)
			return ThrongClips.frame_at(effect_look_clip("act:ball", "ThrongA_Happy"), int(time * 6.0))
		var ride: Dictionary = sim.ride_of(i)
		if not ride.is_empty():
			var clip := effect_look_clip("act:round", "ThrongA_Roundabout_SpriteSheet")
			var car := TiovivoLabTune.carousel()
			var nframes := int(ThrongClips.CLIPS[clip].y) if ThrongClips.CLIPS.has(clip) else 8
			var idx := 0
			if bool(car.get("sprite_dir_follow", true)):
				var seat := sim._ride_slot_of(ride, i)
				var ang := 0.0
				if seat >= 0:
					ang = sim._ride_slot_ang(ride, seat)
				else:
					var mid := sim._ride_center_of(ride)
					ang = atan2(sim.pos_y[i] - mid.y, sim.pos_x[i] - mid.x)
				var dir_off := int(car.get("sprite_dir_offset", 0))
				idx = posmod(int(round(ang / TAU * float(maxi(1, nframes)))) + dir_off, maxi(1, nframes))
			else:
				idx = posmod(int(car.get("sprite_dir_offset", 0)), maxi(1, nframes))
			return ThrongClips.frame_at(clip, idx)
		return ThrongClips.frame_at(effect_look_clip("act:play", "ThrongA_Jump_VariantA_Spritesheet"), int(time * 8.0))
	if doing == ThrongletSimServer.ACT_WORK and not moving:
		if sim.is_mining(i):
			var cycle := ThrongletSimServer.MINE_SWING_T + ThrongletSimServer.MINE_WAIT_T
			var beat := fposmod(time + float(i) * 0.37, cycle)
			if beat >= ThrongletSimServer.MINE_SWING_T:
				return ThrongClips.frame_at("Throng_Think_TwiddleThumbs_Spritesheet", int(time * 6.0))
		return ThrongClips.frame_at("ThrongA_Pickaxe_Spritesheet", int(time * 8.0))
	if carrying:
		if moving:
			if ThrongClips.has_clip("ThrongA_LiftPropWalk"):
				return ThrongClips.frame_at("ThrongA_LiftPropWalk", int(time * 8.0 + float(i)))
			return walk_clip(i, time, sim)
		if ThrongClips.has_clip("ThrongA_LiftProp"):
			return ThrongClips.frame_at("ThrongA_LiftProp", int(time * 6.0))
		return ThrongClips.frame_at("Throng_Think_Spritesheet", int(time * 6.0))
	# Thought bubble up: one-shot Sing B–E from bark start; stand until it ends.
	var bark: Dictionary = sim.bark_of(i)
	var bark_sing := str(bark.get("sing", ""))
	if bark_sing != "" and ThrongClips.has_clip(bark_sing):
		var bark_life := maxf(float(bark.get("life", float(bark.get("t", 1.0)))), 0.01)
		var bark_elapsed := bark_life - float(bark.get("t", 0.0))
		var bark_n := maxi(ThrongClips.frame_count(bark_sing), 1)
		var bark_idx := clampi(int(bark_elapsed * 8.0), 0, bark_n - 1)
		return ThrongClips.frame_at(bark_sing, bark_idx)
	if moving:
		return walk_clip(i, time, sim)
	if sim.clean[i] < 12.0 or sim.fed[i] < 25.0:
		return clip_pool(ThrongClips.MOOD_SAD, i, time, 2.0, "ThrongA_Sad")
	if sim.amused[i] < 25.0:
		return clip_pool(ThrongClips.MOOD_BORED, i, time, 2.2, "ThrongA_Bored_KickRock")
	if i < sim.sleep_t.size() and sim.sleep_t[i] > 0.0:
		return clip_pool(ThrongClips.IDLE_SLEEP, i, time, 2.5, "Throng_Idle_AntennaSpin_EyesClosed_Spritesheet")
	var content := sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK
	if content:
		return clip_pool(ThrongClips.IDLE_CALM, i, time, 2.2, "ThrongA_Happy")
	return clip_pool(ThrongClips.IDLE_CALM, i, time, 2.8, "ThrongA_Default")


## Walk cycle frame for throng [param i] from facing and needs.
func walk_clip(i: int, time: float, sim: ThrongletSim) -> int:
	var tick := int(time * 8.0 + float(i))
	if absf(sim.dir_y[i]) > absf(sim.dir_x[i]) and sim.dir_y[i] < 0.0:
		return ThrongClips.frame_at("Throng_WalkBack_Anim_Spritesheet", tick)
	if sim.approaching_home(i) and ThrongClips.has_clip("Throng_Walk_Homed_Spritesheet"):
		return ThrongClips.frame_at("Throng_Walk_Homed_Spritesheet", tick)
	var sad_move := sim.clean[i] < 12.0 or sim.fed[i] < 25.0
	var happy_move := sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK
	if sad_move and ThrongClips.has_clip("ThrongA_Sad_Walk"):
		return ThrongClips.frame_at("ThrongA_Sad_Walk", tick)
	if happy_move and ThrongClips.has_clip("ThrongA_Happy_Walk"):
		return ThrongClips.frame_at("ThrongA_Happy_Walk", tick)
	return ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", tick)


## Horizontal flip scale for throng [param i] sprite (-1 or 1).
func throng_flip(i: int) -> float:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.state[i] != Catalog.ST_LIVING or sim.frozen:
		return 1.0
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return 1.0
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0 and i < sim.peer_of.size():
		var other := int(sim.peer_of[i])
		if other >= 0 and other < sim.slot_count and sim.state[other] == Catalog.ST_LIVING:
			return -1.0 if sim.pos_x[other] < sim.pos_x[i] else 1.0
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if doing == ThrongletSimServer.ACT_EAT or doing == ThrongletSimServer.ACT_BATH or doing == ThrongletSimServer.ACT_WASH:
		return 1.0
	if doing == ThrongletSimServer.ACT_PLAY and not sim.has_ball(i):
		return 1.0
	if doing == ThrongletSimServer.ACT_WORK and not moving:
		return 1.0
	if not moving:
		return 1.0
	if absf(sim.dir_x[i]) > absf(sim.dir_y[i]) and sim.dir_x[i] < 0.0:
		return -1.0
	return 1.0


## Picks a timed frame from [param pool] or uses [param fallback].
func clip_pool(pool: Array, index: int, time: float, hold: float, fallback: String) -> int:
	var usable: Array[String] = []
	for raw in pool:
		var clip := str(raw)
		if ThrongClips.has_clip(clip):
			usable.append(clip)
	if usable.is_empty():
		return ThrongClips.frame_at(fallback, int(time * 6.0))
	return ThrongClips.pick(usable, index, time, hold)


## Integer animation tick from tune FPS for [param tune_id].
func anim_tick(tune_id: String, time: float) -> int:
	return int(time * float(AnimTune.get_tune(tune_id).get("fps", 8.0)))


## Animated feature frame metadata for [param kind] and variant [param ore].
func feature_anim(kind: int, time: float, ore: int = 0) -> Dictionary:
	if kind == Catalog.FEAT_GLITCH_TREE:
		var rows := [
			[AssetFrames.GLITCH_TREE, AssetFrames.GLITCH_TREE_N, "glitch_tree"],
			[AssetFrames.WASTE_TREE, AssetFrames.WASTE_TREE_N, "waste_tree"],
			[AssetFrames.GLITCH_TREE_C, AssetFrames.GLITCH_TREE_C_N, "glitch_tree_c"],
			[AssetFrames.GLITCH_TREE_D, AssetFrames.GLITCH_TREE_D_N, "glitch_tree_d"],
			[AssetFrames.WASTE_TREE_B, AssetFrames.WASTE_TREE_B_N, "waste_tree_b"],
		]
		var row: Array = rows[posmod(ore, rows.size())]
		var tune_id := str(row[2])
		var idx := posmod(anim_tick(tune_id, time), maxi(int(row[1]), 1))
		return {"frame": AssetFrames.frame(int(row[0]), int(row[1]), idx), "id": tune_id, "idx": idx}
	if kind == Catalog.FEAT_GLITCH_HOUSE:
		var idx := posmod(anim_tick("glitch_house", time), maxi(AssetFrames.GLITCH_HOUSE_N, 1))
		return {"frame": AssetFrames.frame(AssetFrames.GLITCH_HOUSE, AssetFrames.GLITCH_HOUSE_N, idx), "id": "glitch_house", "idx": idx}
	if kind == Catalog.FEAT_ANOMALY:
		var idx := posmod(anim_tick("anomaly", time), maxi(AssetFrames.ANOMALY_N, 1))
		return {"frame": AssetFrames.frame(AssetFrames.ANOMALY, AssetFrames.ANOMALY_N, idx), "id": "anomaly", "idx": idx}
	if kind == Catalog.FEAT_FIRE:
		if int(time) % 2 == 1:
			var bidx := posmod(anim_tick("fire_blob", time), maxi(AssetFrames.FIRE_BLOB_N, 1))
			var blob := AssetFrames.frame(AssetFrames.FIRE_BLOB, AssetFrames.FIRE_BLOB_N, bidx)
			if blob >= 0:
				return {"frame": blob, "id": "fire_blob", "idx": bidx}
		var fidx := posmod(anim_tick("fire", time), maxi(AssetFrames.FIRE_N, 1))
		return {"frame": AssetFrames.frame(AssetFrames.FIRE, AssetFrames.FIRE_N, fidx), "id": "fire", "idx": fidx}
	if kind == Catalog.FEAT_EPILOGUE:
		var rows := [
			[AssetFrames.EPILOGUE, AssetFrames.EPILOGUE_N, "epilogue"],
			[AssetFrames.ROTTEN_APPLE, AssetFrames.ROTTEN_APPLE_N, "rotten_apple"],
		]
		var row: Array = rows[posmod(ore, rows.size())]
		var tune_id := str(row[2])
		var idx := posmod(anim_tick(tune_id, time), maxi(int(row[1]), 1))
		return {"frame": AssetFrames.frame(int(row[0]), int(row[1]), idx), "id": tune_id, "idx": idx}
	if kind == Catalog.FEAT_MOUNTAIN:
		var rows := [
			[AssetFrames.MOUNT_BIG, AssetFrames.MOUNT_BIG_N, "mount_big"],
			[AssetFrames.MOUNT_SMALL, AssetFrames.MOUNT_SMALL_N, "mount_small"],
			[AssetFrames.MOUNT_GLITCH, AssetFrames.MOUNT_GLITCH_N, "mount_glitch"],
			[AssetFrames.GRASS_PATCH, AssetFrames.GRASS_PATCH_N, "grass_patch"],
		]
		var row: Array = rows[posmod(ore, rows.size())]
		var tune_id := str(row[2])
		var idx := posmod(anim_tick(tune_id, time), maxi(int(row[1]), 1))
		return {"frame": AssetFrames.frame(int(row[0]), int(row[1]), idx), "id": tune_id, "idx": idx}
	return {}


## Atlas frame index for feature [param kind] at [param time].
func feature_frame(kind: int, time: float, ore: int = 0) -> int:
	var anim := feature_anim(kind, time, ore)
	return int(anim.get("frame", -1)) if not anim.is_empty() else -1


## Atlas frame for large or small prop [param icon].
func prop_frame(icon: int) -> int:
	if _BIG.has(icon):
		return 96 + int(_BIG[icon])
	return 24 + icon


## Pop-up or prop frame for [param icon].
func pop_frame(icon: int) -> int:
	if icon >= ThrongClips.BASE:
		return icon
	return prop_frame(icon)


## Bitten-apple frame from item [param it] bites_left.
func apple_frame(it: Dictionary) -> int:
	var bites := int(it.get("bites_left", 3))
	if bites >= 3:
		return prop_frame(Catalog.ICON_APPLE)
	return AnimTune.sheet_frame("apple_bite", clampi(2 - bites, 0, 2))


## Egg hatch/shake animation metadata for item [param it].
func egg_anim(it: Dictionary, time: float) -> Dictionary:
	var stage := int(it.get("hatch", 0))
	var idx := 0
	if float(it.get("shake", 0.0)) > 0.0:
		var egg_fps := float(AnimTune.get_tune("egg").get("fps", 4.0))
		idx = 1 + posmod(int(time * egg_fps), 2)
	elif stage >= 3:
		idx = 4
	elif stage >= 1:
		idx = 3
	return {"frame": AnimTune.sheet_frame("egg", idx), "id": "egg", "idx": idx}


## UI icon id for carry type [param kind].
func carry_icon(kind: int) -> int:
	if kind == Catalog.CARRY_BONE:
		return Catalog.ICON_BONE
	if kind == Catalog.CARRY_ORE:
		return Catalog.ICON_ORE
	return Catalog.ICON_WOOD


## World item kind id for carry type [param kind].
func carry_item(kind: int) -> int:
	if kind == Catalog.CARRY_BONE:
		return Catalog.ITEM_BONE
	if kind == Catalog.CARRY_ORE:
		return Catalog.ITEM_ORE
	return Catalog.ITEM_WOOD


## Dirtiness factor from cleanliness [param clean] (0–1).
func throng_dirty(clean: float) -> float:
	return 1.0 - clampf(clean / 100.0, 0.0, 1.0)


## Scale and offset for throng body atlas [param frame].
func throng_sprite_look(frame: int) -> Dictionary:
	if frame == 652 or frame == 653:
		return {"scale": 0.7, "off": Vector2.ZERO}
	var clip := ThrongClips.clip_name_at(frame)
	if clip != "":
		var idx := ThrongClips.clip_index_at(frame)
		return {"scale": ThrongTune.frame_scale(clip, idx), "off": ThrongTune.frame_offset(clip, idx)}
	return {"scale": ThrongTune.default_scale("ThrongA_Default"), "off": Vector2.ZERO}


## Sprite scale for throng [param frame].
func throng_sprite_scale(frame: int) -> float:
	return float(throng_sprite_look(frame).scale)


## Sprite offset for throng [param frame].
func throng_sprite_off(frame: int) -> Vector2:
	return throng_sprite_look(frame).off