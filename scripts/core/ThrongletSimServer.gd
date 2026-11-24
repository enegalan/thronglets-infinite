extends Node

# Colony simulation.

const DialogueBook := preload("res://scripts/data/dialogue/dialogue_book.gd")
const ProgressionManager := preload("res://scripts/core/progression_manager.gd")
const ProgressionCatalog := preload("res://scripts/data/progression_catalog.gd")
const TiovivoLabTune := preload("res://scripts/data/tune/tiovivo_lab_tune.gd")
const SaveSystemScript := preload("res://scripts/core/save_system.gd")
const IslandGenScript := preload("res://scripts/core/IslandGen.gd")

const DECAY_FED := 0.24
const DECAY_FUN := 0.14
const DECAY_CLEAN := 0.16
const MOVE_SPEED := 26.0
const PATH_BFS_MAX := 256
const MITOSIS_CHARGE := 6.0
const MITOSIS_ANIM := 0.45
const MITOSIS_SPLIT_ALONG := 0.72
const MITOSIS_OFFSET := 12.0
const STARVE_GRACE := 30.0
const EGG_NEED := 4
const EGG_FALL := 140.0
const BALL_LIFE := 60.0
const CORPSE_LIFE := 60.0
# The ring art is eight wedges: a time meter for one ore→energy cycle, not stock.
const FACTORY_WEDGES := 8
const FACTORY_PROCESS_TIME := 8.0
const FACTORY_PROCESS_TIME2 := 4.0
# Per ore unit spent. Early original cycles paid ~+10; Mk II pays more.
const FACTORY_GEM_PAY := 10
const FACTORY_GEM_PAY2 := 25
# Chance that a finished factory cycle spills goo (was always on; too aggressive).
const FACTORY_GOO_CHANCE := 0.25
# Mine ore stock (blue bar). Fills on a timer; diggers enter and leave with a load.
const MINE_STOCK_CAP := 5
const MINE_STOCK_CAP2 := 8
const MINE_FILL_TIME := 8.0
const MINE_DIG_TIME := 2.5
const TALK_OPEN_DELAY := 1.0
const BATH_CLEAN_RATE := 3.0
const BATH_DONE := 95.0
const BATH_MIN_STAY := 8.0
const BATH_ENTER_T := 1.2
const RIDE_FUN_RATE := 2.5
const RIDE_DONE := 95.0
const RIDE_MIN_STAY := 8.0

func _ride_cfg() -> Dictionary:
	# TiovivoLabTune caches by file mtime, so this stays cheap.
	return TiovivoLabTune.carousel()

func _ride_fun_rate() -> float:
	return float(_ride_cfg().get("ride_fun_rate", RIDE_FUN_RATE))

func _ride_done_need() -> float:
	return float(_ride_cfg().get("ride_done", RIDE_DONE))

func _ride_min_stay_need() -> float:
	return float(_ride_cfg().get("min_stay", RIDE_MIN_STAY))
const PLAY_AURA_FUN := 6.0
const BALL_KICK_FUN := 8.0
# Open grass around the egg so the opening shot stays clear of trees.
const SPAWN_CLEAR := 110.0

var testing := false
var smoke_hold := false
var perf_mode := false
var save_perf_mode := false
var save_path := ""
var world_seed := 1
var biomes: Array = []
var biome_by_id := {}

var unlocks := {}
var unlock_serial := 0
var ethics: Array = []
var save_system: SaveSystem
var notes: Array = []
var sfx_queue: Array = []
var voice_wait := 0.0
var modal := {}
var talk_pending := {}
var gaze_queue: Array = []
var frozen := false
var moral := 0
var mutations := {}
var talked_trees := {}
var learn_talked := false

var part_two := false
var mountain_seen := false
var special_biomes := {}
var trees_chopped := 0
var stumps_cleared := 0
var bug_uses := 0
var tnt_used := 0
var goo_count := 0
var gems := 0
var gems_peak := 0
var total_gems_earned := 0
var deaths_total := 0
var peak := 0
var land_tier := 0
var sandbox_mode := false
const SANDBOX_TIER_MIN := 0
const SANDBOX_TIER_MAX := 16
const SANDBOX_START_TIER := 2
const SANDBOX_GEMS := 99999
var _shaping_island := false
var glitch_seen := false
var glitch_t := 0.0
var gaze_home := {}
var barks: Array = []
var wear := {}
var wear_from := {}
var shot_mode := false
var shot_fx := false
var shot_carry := false
var shot_round := false
var shot_apple := false
var shot_needs := false
var shot_anims := false
var shot_dirt := false
var shot_ball := false
var shot_wash := false
var shot_bld_goo := false
var shot_blood := false
var shot_focus := Vector2(256, 256)
var shot_span := 210.0
var shot_throng := -1
var shot_factory := -1
var shot_path := Vector2(256, 256)
var ambient_n := 0
const WEAR_NEED := 120
const WEAR_STEPS := 4
var living := 0
var monolith_tier_spawned := {}

var revealed := {}
var chunks := {}
var dirty_chunks: Array = []
var paint_epoch := 0
# Bumped when features are added/removed so presentation can rebuild static prop meshes.
var feat_mesh_epoch := 0
var lists_dirty := false

var features: Array = []
var feature_by_id := {}
var feature_cell := {}
var next_feature_id := 1
var tree_seeds: Array = []

var items: Array = []
var item_by_id := {}
var next_item_id := 1
var hand_id := -1
var held_kind := ""
var held_ref := -1
var held_x := 0.0
var held_y := 0.0
var scoop_item_ids: Array = []
var scoop_dead_ids: Array = []
var session_live := false
var player_name := ""
var tutorial_i := -1
var count_unknown := false
var _name_rules := false
var _name_chars := ""
var _name_bans: PackedStringArray = PackedStringArray()
var sponge_id := -1
var sponge_hold := 0.0
## Thronglets cleaned while scrubbing; sparkle+Happy fire on mouse/kit release.
var wash_fx_pending: Array = []

var buildings: Array = []
var building_by_id := {}
var building_cell := {}
var next_building_id := 1

var slot_count := 0
var cursor := 0
var mood_face := "base"
var _mood_base := 0
var _mood_happy := 0
var _mood_cry := 0
var _mood_sus := 0
var _mood_freak := 0
var frame_i := 0
var view_rect := Rect2()
var cap_told := false

var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var dir_x := PackedFloat32Array()
var dir_y := PackedFloat32Array()
var fed := PackedFloat32Array()
var amused := PackedFloat32Array()
var clean := PackedFloat32Array()
var cool := PackedFloat32Array()
var starve := PackedFloat32Array()
var hungry_t := PackedFloat32Array()
var wander_t := PackedFloat32Array()
var avoid_t := PackedFloat32Array()
var mito_t := PackedFloat32Array()
var mito_charge := PackedFloat32Array()
var shake_t := PackedFloat32Array()
var buff_t := PackedFloat32Array()
var react_t := PackedFloat32Array()
var cheer_t := PackedFloat32Array()
var sleep_t := PackedFloat32Array()
## Peer social beat: stand, face partner, talk or sing body clips.
var peer_t := PackedFloat32Array()
var peer_of := PackedInt32Array()
var peer_sing := PackedByteArray()
## One-shot DropProp after putting down a haul.
var drop_t := PackedFloat32Array()
## 1 = violent corpse (saw / tnt / nuke); draw Throng_Prop_Blood_A under it.
var bloody := PackedByteArray()
var state := PackedInt32Array()
var carry := PackedInt32Array()
var carry_value := PackedInt32Array()
var tint := PackedInt32Array()
var claim := PackedInt32Array()
var mine_job := PackedInt32Array()
var act := PackedInt32Array()
var act_t := PackedFloat32Array()
var tick_stamp := PackedInt32Array()
var pops: Array = []
var current_slot := -1
var paused := false
var game_over := false
## Swarm celebration window after unlock / milestone (seconds).
var celebrate_t := 0.0
const PEER_R := 40.0
const REACT_KILL_R := 72.0
const REACT_DUR := 0.85
const CHEER_DUR := 0.9
const CELEBRATE_DUR := 1.4
## One ThrongA_Happy loop @ 6fps (5 frames) — matches CLEAN sparkle life.
const WASH_FX_LIFE := 5.0 / 6.0
## World units of sponge motion per frame to count as scrub (clean gain + start wash).
## Kept low: at zoom 2 a gentle rub is often < 1.0 world/frame; 2.0 never lit suds in play.
const SCRUB_STROKE_MIN := 0.35
const SLEEP_DUR := 3.2
const PEER_DUR := 2.4
const DROP_DUR := 0.5
## Mine dig body: pickaxe swing then Twiddle wait (seconds each).
const MINE_SWING_T := 0.7
const MINE_WAIT_T := 0.55
# Seconds between autosaves. A later settings screen can change this. Zero turns it off.
var autosave_interval := 60.0
var autosave_t := 0.0
var save_pulse := 0
var hash_head := PackedInt32Array()
var hash_next := PackedInt32Array()
var hash_cell := PackedInt32Array()
# O(1) reverse links: thronglet slot -> entity id (-1 = none).
var link_tub := PackedInt32Array()
var link_ride := PackedInt32Array()
var link_guest := PackedInt32Array()
var link_claim := PackedInt32Array()
var link_ball := PackedInt32Array()
var living_ids := PackedInt32Array()
var living_at := PackedInt32Array()
var bark_cool := PackedFloat32Array()
## Cached penned flag (expensive probe); refreshed on the same cadence as rock bark.
var penned_flag := PackedByteArray()
var fires: Array = []
# Features keyed by chunk ("cx,cy") so draw/sync only walks visible chunks.
var features_by_chunk := {}
# Cached colony walkable-cell count; invalidated when terrain/props change.
var _walk_cells_cache := -1
var _has_factory_cache := false
var _has_factory_known := false
# Per-cell inland (cliff) cache: depends only on tiles, not props.
var inland_cache := {}
# bid -> assigned mine workers (avoids O(living) scans in _seek_mine).
var mine_job_n := {}
# Full AI while the colony fits — LOD budgets only above this (50k–120k scale).
const AGENT_FULL_CAP := 220
const AGENT_STICKY_BUDGET := 160
const AGENT_SEEK_BUDGET := 48
const AGENT_CHEAP_BUDGET := 256
const AGENT_NEAR_BUDGET := 420
const AGENT_NEAR_PAD := 160.0
const AGENT_STICKY_SCAN_CAP := 4000
var _decay_scale_frame := -1
var _decay_scale_cached := 1.0
var _agent_done_frame := PackedInt32Array()
# Kind-partitioned live lists so seeks skip full items/buildings scans.
var items_apple: Array = []
var items_ball: Array = []
var items_wood: Array = []
var items_bone: Array = []
var items_ore: Array = []
var blds_tub: Array = []
var blds_round: Array = []
var blds_home: Array = []
var blds_mine: Array = []
var blds_show: Array = []
# Generation cache for ground piles; carried resources stay O(1) via carry_*_n.
var _item_count_gen := 0
var _item_count_built := -1
var _item_count_wood := 0
var _item_count_bone := 0
var _item_count_ore := 0
var _item_count_other := {}
var carry_wood_n := 0
var carry_bone_n := 0
var carry_ore_n := 0
var _milestone_cool := 0.0
var dead_n := 0
var dead_ids := PackedInt32Array()
var seek_x := PackedFloat32Array()
var seek_y := PackedFloat32Array()
var seek_t := PackedFloat32Array()

var _rng := RandomNumberGenerator.new()
var item_physics: ItemPhysics
var island_gen


func _ready() -> void:
	item_physics = ItemPhysics.new(self)
	island_gen = IslandGenScript.new(self)
	save_system = SaveSystemScript.new(self)
	save_path = save_system.slot_path(SaveSystem.LIVE_SLOT)
	var args := OS.get_cmdline_user_args()
	perf_mode = args.has("--perf")
	save_perf_mode = args.has("--save-perf")
	shot_mode = args.has("--shot") or args.has("--shot-fx") or args.has("--shot-carry") or args.has("--shot-round") or args.has("--shot-apple") or args.has("--shot-needs") or args.has("--shot-anims") or args.has("--shot-dirt") or args.has("--shot-ball") or args.has("--shot-wash") or args.has("--shot-bld-goo") or args.has("--shot-blood")
	var pick_zoom_repro := args.has("--pick-zoom-repro")
	testing = args.has("--smoke") or shot_mode or perf_mode or pick_zoom_repro or save_perf_mode
	if args.has("--shot-fx"):
		shot_fx = true
	if args.has("--shot-carry"):
		shot_carry = true
	if args.has("--shot-round"):
		shot_round = true
	if args.has("--shot-apple"):
		shot_apple = true
	if args.has("--shot-needs"):
		shot_needs = true
	if args.has("--shot-anims"):
		shot_anims = true
	if args.has("--shot-dirt"):
		shot_dirt = true
	if args.has("--shot-ball"):
		shot_ball = true
	if args.has("--shot-wash"):
		shot_wash = true
	if args.has("--shot-bld-goo"):
		shot_bld_goo = true
	if args.has("--shot-blood"):
		shot_blood = true
	if testing and not save_perf_mode:
		# Keep smoke/shot/perf saves inside the project so headless CI sandboxes can write.
		save_path = ProjectSettings.globalize_path("res://shots/thronglets_smoke.save")
		world_seed = 12345
		seed(world_seed)
		# Perf / pick-zoom repro must keep the sim stepping; smoke/shot freeze until harness moves.
		smoke_hold = not perf_mode and not pick_zoom_repro
	elif save_perf_mode:
		# Keep the real user:// slot path; harness loads the player's save.
		smoke_hold = false
		world_seed = 12345
		seed(world_seed)
	else:
		world_seed = randi()
	hash_head.resize(Catalog.HASH_SIZE)
	hash_head.fill(-1)
	_load_biomes()
	_init_unlocks()
	if testing and not save_perf_mode:
		_bootstrap_new()
	if testing and not perf_mode and not pick_zoom_repro and not save_perf_mode:
		_begin_smoke()


func _process(delta: float) -> void:
	if smoke_hold or paused:
		return
	if save_perf_mode:
		var t0 := Time.get_ticks_usec()
		_step(delta)
		set_meta("save_perf_step_ms", float(Time.get_ticks_usec() - t0) * 0.001)
		if (frame_i % 30) == 0:
			print("SAVE PERF step_parts %s" % str(get_meta("save_perf_parts", {})))
	else:
		_step(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not testing and session_live and not game_over:
		save_system.save_progress()


func _begin_smoke() -> void:
	await get_tree().process_frame
	if shot_mode:
		if shot_carry:
			_prep_shot_carry()
		elif shot_round:
			_prep_shot_round()
		elif shot_apple:
			_prep_shot_apple()
		elif shot_needs:
			_prep_shot_needs()
		elif shot_dirt:
			_prep_shot_dirt()
		elif shot_ball:
			_prep_shot_ball()
		elif shot_wash:
			_prep_shot_wash()
		elif shot_bld_goo:
			_prep_shot_bld_goo()
		elif shot_blood:
			_prep_shot_blood()
		else:
			_prep_shot_world()
		return
	_run_checks()


func _step(delta: float) -> void:
	frame_i += 1
	if frame_i > 1000000:
		frame_i = 1
	if celebrate_t > 0.0:
		celebrate_t = maxf(0.0, celebrate_t - delta)
	if sponge_hold > 0.0:
		sponge_hold = maxf(0.0, sponge_hold - delta)
		if sponge_hold <= 0.0:
			sponge_id = -1
	_tick_talk_wait(delta)
	if save_perf_mode:
		var parts := {}
		var mark := Time.get_ticks_usec()
		if not frozen:
			item_physics.tick_items(delta)
			parts["items"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_trees(delta)
			parts["trees"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_props(delta)
			parts["props"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_monoliths(delta)
			parts["mono"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_buildings(delta)
			parts["bld"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_auras(delta)
			parts["aura"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			_tick_agents(delta)
			_tick_corpses(delta)
			parts["agents"] = float(Time.get_ticks_usec() - mark) * 0.001
			parts["agent_walk_ms"] = float(get_meta("_ap_walk_us", 0)) * 0.001
			parts["move_blocked_n"] = int(get_meta("_ap_move_n", 0))
			parts["walk_cells_n"] = int(get_meta("_ap_walk_cells_n", 0))
			set_meta("_ap_walk_us", 0)
			set_meta("_ap_move_n", 0)
			set_meta("_ap_walk_cells_n", 0)
			mark = Time.get_ticks_usec()
			if lists_dirty or (frame_i & 7) == 0:
				var item_n := items.size()
				var bld_n := buildings.size()
				var feat_n := features.size()
				_compact(items)
				_compact(features)
				_compact(buildings)
				lists_dirty = false
				if items.size() != item_n or buildings.size() != bld_n or features.size() != feat_n:
					_rebuild_kind_indexes()
			parts["compact"] = float(Time.get_ticks_usec() - mark) * 0.001
		elif str(modal.get("event", "")) == "monolith_appear":
			_tick_monoliths(delta, false)
		mark = Time.get_ticks_usec()
		_tick_barks(delta, not frozen)
		_tick_pops(delta, not frozen)
		_milestone_cool = maxf(0.0, _milestone_cool - delta)
		if _milestone_cool <= 0.0:
			_milestone_cool = 0.35
			_check_milestones()
		_tick_voice(delta)
		save_system.tick_autosave(delta)
		parts["tail"] = float(Time.get_ticks_usec() - mark) * 0.001
		set_meta("save_perf_parts", parts)
		return
	if not frozen:
		item_physics.tick_items(delta)
		_tick_trees(delta)
		_tick_props(delta)
		_tick_monoliths(delta)
		_tick_buildings(delta)
		_tick_auras(delta)
		_tick_agents(delta)
		_tick_corpses(delta)
		# Compacting 3k+ feature dicts every frame was a large sync tax; only when dirty or periodically.
		if lists_dirty or (frame_i & 7) == 0:
			var item_n := items.size()
			var bld_n := buildings.size()
			var feat_n := features.size()
			_compact(items)
			_compact(features)
			_compact(buildings)
			lists_dirty = false
			if items.size() != item_n or buildings.size() != bld_n or features.size() != feat_n:
				_rebuild_kind_indexes()
	elif str(modal.get("event", "")) == "monolith_appear":
		_tick_monoliths(delta, false)
	# Keep bark and anchored pop positions on live thronglets even during gaze teleport.
	_tick_barks(delta, not frozen)
	_tick_pops(delta, not frozen)
	_milestone_cool = maxf(0.0, _milestone_cool - delta)
	if _milestone_cool <= 0.0:
		_milestone_cool = 0.35
		_check_milestones()
	_tick_voice(delta)
	save_system.tick_autosave(delta)


func _tick_agents(delta: float) -> void:
	if living_ids.is_empty():
		return
	var n := living_ids.size()
	var decay := _decay_scale()
	_ensure_agent_done_frame()
	# Mid-game: every thronglet gets real _walk/_decide — LOD made them freeze on trees.
	if n <= AGENT_FULL_CAP:
		for raw in living_ids:
			var i_full := int(raw)
			if i_full < 0 or i_full >= slot_count or state[i_full] != Catalog.ST_LIVING:
				continue
			if held_kind == "thronglet" and i_full == held_ref:
				continue
			_tick_one(i_full, delta, decay, true)
			_sample_mood(i_full)
		_publish_mood()
		return
	var sticky_left := AGENT_STICKY_BUDGET
	var seek_left := AGENT_SEEK_BUDGET
	var cheap_left := AGENT_CHEAP_BUDGET
	# 1) Sticky goals — haul/mine first, then any active seek (needs _walk to peel buildings).
	if n <= AGENT_STICKY_SCAN_CAP:
		for pass_i in 2:
			if sticky_left <= 0:
				break
			var hard_pass := pass_i == 0
			for raw_goal in living_ids:
				if sticky_left <= 0:
					break
				var ig := int(raw_goal)
				if ig < 0 or ig >= slot_count or state[ig] != Catalog.ST_LIVING:
					continue
				if held_kind == "thronglet" and ig == held_ref:
					continue
				_ensure_agent_done_frame()
				if _agent_done_frame[ig] == frame_i:
					continue
				if hard_pass:
					if not _agent_has_hard_goal(ig):
						continue
				elif not _agent_has_goal(ig):
					continue
				_tick_one(ig, delta, decay, true)
				_ensure_agent_done_frame()
				_agent_done_frame[ig] = frame_i
				sticky_left -= 1
				_sample_mood(ig)
	# 2) Near camera: rotate idle seeks; leftovers coast so the view stays alive.
	var near_ids: Array = []
	if view_rect.size != Vector2.ZERO:
		near_ids = query_rect(view_rect.grow(AGENT_NEAR_PAD), AGENT_NEAR_BUDGET)
	var near_n := near_ids.size()
	if near_n > 0:
		var near_base := frame_i % near_n
		for j in near_n:
			var i := int(near_ids[(near_base + j) % near_n])
			if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
				continue
			if held_kind == "thronglet" and i == held_ref:
				continue
			_ensure_agent_done_frame()
			if _agent_done_frame[i] == frame_i:
				continue
			if seek_left > 0:
				_tick_one(i, delta, decay, true)
				_ensure_agent_done_frame()
				_agent_done_frame[i] = frame_i
				seek_left -= 1
				_sample_mood(i)
			else:
				# Life still advances when seek budget is exhausted; only AI seeks are deferred.
				_tick_one(i, delta, decay, false)
				_agent_done_frame[i] = frame_i
	# 3) Far / overflow: fixed rotating budgets — cost flat at 50k-120k.
	# Re-read living_ids.size() — sticky/near ticks can kill and shrink the list.
	n = living_ids.size()
	if n <= 0:
		_publish_mood()
		return
	_ensure_agent_done_frame()
	if seek_left > 0:
		var base := int((frame_i * AGENT_SEEK_BUDGET) % n)
		var far_period := maxi(1, int(ceil(float(n) / float(AGENT_SEEK_BUDGET))))
		var life_dt := delta * float(far_period)
		for j2 in seek_left:
			var live_n2 := living_ids.size()
			if live_n2 <= 0:
				break
			var i2 := int(living_ids[(base + j2) % live_n2])
			if i2 < 0 or i2 >= slot_count or state[i2] != Catalog.ST_LIVING:
				continue
			if held_kind == "thronglet" and i2 == held_ref:
				continue
			_ensure_agent_done_frame()
			if _agent_done_frame[i2] == frame_i:
				continue
			if not _tick_life(i2, life_dt, decay):
				_agent_done_frame[i2] = frame_i
				continue
			tick_stamp[i2] = frame_i
			if _tick_busy(i2, delta, true):
				_tick_decide(i2, delta)
			_agent_done_frame[i2] = frame_i
			_sample_mood(i2)
	if cheap_left > 0:
		n = living_ids.size()
		if n <= 0:
			_publish_mood()
			return
		var cbase := int((frame_i * AGENT_CHEAP_BUDGET) % n)
		var cheap_period := maxi(1, int(ceil(float(n) / float(AGENT_CHEAP_BUDGET))))
		var cheap_life_dt := delta * float(cheap_period)
		for j3 in cheap_left:
			var live_n3 := living_ids.size()
			if live_n3 <= 0:
				break
			var i3 := int(living_ids[(cbase + j3) % live_n3])
			if i3 < 0 or i3 >= slot_count or state[i3] != Catalog.ST_LIVING:
				continue
			if held_kind == "thronglet" and i3 == held_ref:
				continue
			_ensure_agent_done_frame()
			if _agent_done_frame[i3] == frame_i:
				continue
			if not _tick_life(i3, cheap_life_dt, decay):
				_agent_done_frame[i3] = frame_i
				continue
			tick_stamp[i3] = frame_i
			_tick_busy_or_coast(i3, delta)
			_agent_done_frame[i3] = frame_i
	_publish_mood()


func _ensure_agent_done_frame() -> void:
	var need := slot_count
	if _agent_done_frame.size() == need:
		return
	var old := _agent_done_frame.size()
	_agent_done_frame.resize(need)
	for k in range(old, need):
		_agent_done_frame[k] = -1


func _agent_has_hard_goal(i: int) -> bool:
	if i < 0 or i >= slot_count:
		return false
	if i < mine_job.size() and int(mine_job[i]) >= 0:
		return true
	if i < carry.size() and carry[i] != Catalog.CARRY_NONE:
		return true
	if i < link_claim.size() and link_claim[i] >= 0:
		return true
	return false


func _agent_has_goal(i: int) -> bool:
	# Any active walk needs every-frame _walk — coast cannot peel around buildings.
	if _agent_has_hard_goal(i):
		return true
	if i < seek_t.size() and seek_t[i] > 0.0:
		return true
	return false


func _sample_mood(i: int) -> void:
	if state[i] != Catalog.ST_LIVING:
		return
	var fed_v := fed[i]
	var fun_v := amused[i]
	var clean_v := clean[i]
	if fed_v < 8.0 or fun_v < 8.0 or clean_v < 8.0:
		_mood_freak += 1
	elif fed_v < 25.0 or clean_v < 12.0:
		_mood_cry += 1
	elif fun_v < 25.0:
		_mood_sus += 1
	elif fed_v >= Catalog.NEED_OK and fun_v >= Catalog.NEED_OK and clean_v >= Catalog.NEED_OK:
		_mood_happy += 1
	else:
		_mood_base += 1


func _publish_mood() -> void:
	var best := "base"
	var best_n := -1
	var bins: Array = [
		["freak", _mood_freak],
		["cry", _mood_cry],
		["suspicious", _mood_sus],
		["happy", _mood_happy],
		["base", _mood_base],
	]
	for row in bins:
		var n := int(row[1])
		if n > best_n:
			best_n = n
			best = str(row[0])
	mood_face = best if best_n > 0 else "base"
	_mood_base = 0
	_mood_happy = 0
	_mood_cry = 0
	_mood_sus = 0
	_mood_freak = 0


func _tick_one(i: int, dt: float, decay: float = -1.0, allow_seek: bool = true) -> void:
	if i < 0 or i >= slot_count:
		return
	if tick_stamp[i] == frame_i:
		return
	tick_stamp[i] = frame_i
	if state[i] != Catalog.ST_LIVING:
		return
	if held_kind == "thronglet" and i == held_ref:
		return
	if decay < 0.0:
		decay = _decay_scale()
	if not _tick_life(i, dt, decay):
		return
	if not allow_seek:
		_tick_busy_or_coast(i, dt)
		return
	if not _tick_busy(i, dt, true):
		return
	_tick_decide(i, dt)


func _tick_cheap(i: int, dt: float, decay: float) -> void:
	# Life + continue current motion/action. No seeks, no open_dir peeling.
	if i < 0 or i >= slot_count:
		return
	if tick_stamp[i] == frame_i:
		return
	tick_stamp[i] = frame_i
	if state[i] != Catalog.ST_LIVING:
		return
	if held_kind == "thronglet" and i == held_ref:
		return
	if not _tick_life(i, dt, decay):
		return
	_tick_busy_or_coast(i, dt)


func _tick_life(i: int, dt: float, decay: float) -> bool:
	# Returns false when the agent should not move/decide further this tick.
	if mito_t[i] > 0.0:
		mito_t[i] = maxf(0.0, mito_t[i] - dt)
		if mito_t[i] <= 0.0:
			_finish_mitosis(i)
		return false
	if mito_charge[i] > 0.0:
		# The mitosis sheet already plays while charging, so stay put for the
		# whole buildup + split instead of walking through the animation.
		mito_charge[i] = minf(MITOSIS_CHARGE, mito_charge[i] + dt)
		if mito_charge[i] >= MITOSIS_CHARGE:
			mito_charge[i] = 0.0
			_start_mitosis(i)
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		act[i] = 0
		act_t[i] = 0.0
		shake_t[i] = 0.0
		return false
	fed[i] = maxf(0.0, fed[i] - DECAY_FED * decay * dt)
	amused[i] = maxf(0.0, amused[i] - DECAY_FUN * decay * dt)
	clean[i] = maxf(0.0, clean[i] - DECAY_CLEAN * decay * dt)
	# Goo check is relatively rare terrain; skip most cheap frames via id phase.
	if ((frame_i + i) & 7) == 0:
		var tile := _tile_at(pos_x[i], pos_y[i])
		if tile == Catalog.TILE_GOO:
			var goo_hit := 0.35 if bool(mutations.get("adapt", false)) else 0.9
			clean[i] = maxf(0.0, clean[i] - goo_hit * dt * 8.0)
			fed[i] = maxf(0.0, fed[i] - 0.35 * dt * 8.0)
	if fed[i] <= 0.0 or amused[i] <= 0.0 or clean[i] <= 0.0:
		starve[i] += dt
		if starve[i] >= STARVE_GRACE:
			_die_neglect(i)
			return false
	else:
		starve[i] = 0.0
	if fed[i] < Catalog.NEED_HUNGRY:
		hungry_t[i] += dt
	else:
		hungry_t[i] = 0.0
	if bark_cool[i] > 0.0:
		bark_cool[i] = maxf(0.0, bark_cool[i] - dt)
	elif ((frame_i + i) & 15) == 0:
		_maybe_bark(i)
	_ensure_agent_timers(i)
	if react_t[i] > 0.0:
		react_t[i] = maxf(0.0, react_t[i] - dt)
	if cheer_t[i] > 0.0:
		cheer_t[i] = maxf(0.0, cheer_t[i] - dt)
		dir_x[i] = 0.0
		dir_y[i] = 0.0
	# Sing bark: stay put until the bocadillo (and its one-shot clip) ends.
	if bark_sing_of(i) != "":
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		if i < seek_t.size():
			seek_t[i] = 0.0
	if drop_t[i] > 0.0:
		drop_t[i] = maxf(0.0, drop_t[i] - dt)
		dir_x[i] = 0.0
		dir_y[i] = 0.0
	if peer_t[i] > 0.0:
		peer_t[i] = maxf(0.0, peer_t[i] - dt)
		if peer_t[i] <= 0.0:
			_clear_peer_social(i)
		else:
			dir_x[i] = 0.0
			dir_y[i] = 0.0
	if sleep_t[i] > 0.0:
		sleep_t[i] = maxf(0.0, sleep_t[i] - dt)
	elif act[i] == 0 and peer_t[i] <= 0.0 and drop_t[i] <= 0.0 and fed[i] >= Catalog.NEED_OK and amused[i] >= Catalog.NEED_OK and clean[i] >= Catalog.NEED_OK:
		if ((frame_i + i) % 180) == 0 and randf() < 0.08:
			sleep_t[i] = SLEEP_DUR
	if act_t[i] > 0.0:
		act_t[i] = maxf(0.0, act_t[i] - dt)
		# Sticky acts are held by claim/seat/job — cheap/far ticks must not wipe the body clip.
		if act_t[i] <= 0.0 and not _act_is_sticky(i):
			act[i] = 0
	if shake_t[i] > 0.0:
		shake_t[i] = maxf(0.0, shake_t[i] - dt)
		act[i] = ACT_WASH
		act_t[i] = 0.2
	# Re-assert wash for the whole sponge hold (even if act_t just hit 0 above).
	if i == sponge_id and sponge_hold > 0.0:
		act[i] = ACT_WASH
		act_t[i] = maxf(act_t[i], 0.35)
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return false
	if act[i] == ACT_WASH:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return false
	if cheer_t[i] > 0.0:
		return false
	if bark_sing_of(i) != "":
		return false
	cool[i] = maxf(0.0, cool[i] - dt)
	return true


func _act_is_sticky(i: int) -> bool:
	match int(act[i]):
		ACT_EAT:
			return true
		# WASH is refreshed by scrub/shake act_t — never sticky or it loops forever.
		ACT_BATH:
			return (i < link_tub.size() and link_tub[i] >= 0) \
				or (i < link_guest.size() and link_guest[i] >= 0)
		ACT_PLAY:
			if i < link_ball.size() and int(link_ball[i]) >= 0:
				return true
			return (i < link_ride.size() and link_ride[i] >= 0) \
				or (i < link_guest.size() and link_guest[i] >= 0)
		ACT_WORK:
			return (i < link_guest.size() and link_guest[i] >= 0) \
				or (i < mine_job.size() and int(mine_job[i]) >= 0)
		_:
			return false


func _tick_busy_or_coast(i: int, dt: float) -> void:
	# Cheap ticks still advance sticky interactions so body clips do not flicker to idle/walk.
	if i < drop_t.size() and drop_t[i] > 0.0:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return
	if bark_sing_of(i) != "":
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		if i < seek_t.size():
			seek_t[i] = 0.0
		return
	if i < peer_t.size() and peer_t[i] > 0.0:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return
	if act[i] == ACT_EAT and _continue_eat(i, dt):
		return
	if _continue_sticky_play_or_work(i, dt):
		return
	# Most agents are free walkers: skip tub/ride/guest scans via O(1) link checks.
	var linked := (i < link_tub.size() and link_tub[i] >= 0) \
		or (i < link_ride.size() and link_ride[i] >= 0) \
		or (i < link_guest.size() and link_guest[i] >= 0)
	if linked:
		if not _tick_busy(i, dt, false):
			return
	elif mito_charge[i] > 0.0:
		return
	if _move_blocked(pos_x[i], pos_y[i]):
		_unstick(i)
	var speed := MOVE_SPEED
	if buff_t[i] > 0.0:
		speed = 36.0
		buff_t[i] = maxf(0.0, buff_t[i] - dt)
	if i < seek_t.size() and seek_t[i] > 0.0:
		seek_t[i] = maxf(0.0, seek_t[i] - dt)
		_coast(i, seek_x[i], seek_y[i], speed, dt)
	else:
		if absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
			_pick_wander(i)
		_coast_dir(i, speed, dt)


func _tick_busy(i: int, dt: float, hard_unstick: bool) -> bool:
	# Tub / ride / guest. Returns false when occupied for the rest of the tick.
	var tub_here := seat_of(i)
	var in_tub := not tub_here.is_empty() and float(tub_here.get("bath_t", -1.0)) >= 0.0
	var on_ride := not _ride_building(i).is_empty()
	if not in_tub and not on_ride and _move_blocked(pos_x[i], pos_y[i]):
		if hard_unstick:
			_unstick(i)
		else:
			dir_x[i] = 0.0
			dir_y[i] = 0.0
			if i < seek_t.size():
				seek_t[i] = 0.0
	var visit := _guest_building(i)
	if not visit.is_empty():
		var visit_kind := int(visit.kind)
		var visit_rule := _visit_rule(visit_kind)
		var served_fed := float(visit_rule.get("fed", 0.0)) > 0.0
		var served_clean := float(visit_rule.get("clean", 0.0)) > 0.0
		var served_fun := float(visit_rule.get("fun", 0.0)) > 0.0
		var leave := false
		if fed[i] < Catalog.NEED_HUNGRY and not served_fed:
			leave = true
		elif clean[i] < Catalog.NEED_SEEK and not served_clean:
			leave = true
		elif amused[i] < Catalog.NEED_FUN and not served_fun:
			leave = true
		if leave:
			_drop_guest(visit, i)
		else:
			var door := _approach_building(visit, i)
			var at_door := _dist_i(i, float(door.x), float(door.y)) < float(Catalog.TILE) * 1.25
			if not _inside_building_reach(pos_x[i], pos_y[i], visit) and not at_door:
				if i < seek_t.size() and seek_t[i] > 0.0:
					_coast(i, seek_x[i], seek_y[i], MOVE_SPEED, dt)
				elif hard_unstick:
					_walk(i, float(door.x), float(door.y), MOVE_SPEED, dt)
			else:
				if _is_show(visit_kind):
					act[i] = ACT_PLAY
				elif _is_mine_kind(visit_kind):
					act[i] = ACT_WORK
				else:
					act[i] = ACT_BATH
				act_t[i] = 0.4
			return false
	var tub_seat := seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		_do_bath(i, tub_seat, dt)
		return false
	var riding_b := _ride_building(i)
	if not riding_b.is_empty():
		_do_roundabout_ride(i, riding_b, dt)
		return false
	var ready := fed[i] >= Catalog.NEED_OK and amused[i] >= Catalog.NEED_OK and clean[i] >= Catalog.NEED_OK and cool[i] <= 0.0
	if ready:
		mito_charge[i] = minf(MITOSIS_CHARGE, mito_charge[i] + dt)
		if mito_charge[i] >= MITOSIS_CHARGE:
			mito_charge[i] = 0.0
			_start_mitosis(i)
			return false
	else:
		mito_charge[i] = maxf(0.0, mito_charge[i] - dt * 1.5)
	return true


func _coast(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	# Same cardinal/BFS stepper as _walk — coast must not charge diagonals into trees.
	_walk(i, tx, ty, speed, dt)


func _coast_dir(i: int, speed: float, dt: float) -> void:
	var step := speed * dt
	if absf(dir_x[i]) + absf(dir_y[i]) < 0.01 or step < 0.01:
		return
	_snap_dir_cardinal(i)
	if _move_cardinal_toward(i, pos_x[i] + dir_x[i] * 32.0, pos_y[i] + dir_y[i] * 32.0, step):
		return
	# Peel around the tree — never freeze with dir=0 until the next seek.
	var peel := _open_dir(i, Vector2(dir_x[i], dir_y[i]))
	if peel == Vector2.ZERO:
		peel = _open_dir(i, _side_dir(i, Vector2(dir_x[i], dir_y[i])))
	if peel != Vector2.ZERO:
		dir_x[i] = peel.x
		dir_y[i] = peel.y
		_snap_dir_cardinal(i)
		if _move_cardinal_toward(i, pos_x[i] + dir_x[i] * 32.0, pos_y[i] + dir_y[i] * 32.0, step):
			return
	if _move_blocked(pos_x[i], pos_y[i]) or _corner_trap(i):
		_unstick(i)
	else:
		_pick_wander(i)
	if i < seek_t.size():
		seek_t[i] = 0.0


func _snap_dir_cardinal(i: int) -> void:
	if absf(dir_x[i]) >= absf(dir_y[i]):
		dir_x[i] = 0.0 if is_zero_approx(dir_x[i]) else signf(dir_x[i])
		dir_y[i] = 0.0
	else:
		dir_y[i] = 0.0 if is_zero_approx(dir_y[i]) else signf(dir_y[i])
		dir_x[i] = 0.0


func _tick_decide(i: int, dt: float) -> void:
	if i < drop_t.size() and drop_t[i] > 0.0:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return
	if i < peer_t.size() and peer_t[i] > 0.0:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return
	var speed := MOVE_SPEED
	if buff_t[i] > 0.0:
		speed = 36.0
		buff_t[i] = maxf(0.0, buff_t[i] - dt)
	# Distress first. Then haul / mine while needs are good enough (_work_ready).
	# Mitosis polish (NEED_OK) waits — otherwise a tub/ride keeps them from ever mining.
	# Wood/bone claims must drop when leaving haul, or one stuck rider locks every plank.
	if fed[i] < Catalog.NEED_HUNGRY:
		_release_claim(i)
		if _seek_food(i, speed, dt):
			_release_mine_job(i)
			return
		_release_apple_claim(i)
	if clean[i] < Catalog.NEED_SEEK:
		if _seek_clean(i, speed, dt):
			_release_item_claims(i)
			_release_mine_job(i)
			return
	# Finish a load already in hand before topping fun — otherwise the haul starves.
	if carry[i] != Catalog.CARRY_NONE and _try_haul(i, speed, dt):
		_release_mine_job(i)
		return
	if amused[i] < Catalog.NEED_FUN:
		_release_item_claims(i)
		if _tend_fun(i, speed, dt):
			_release_mine_job(i)
			return
	if _try_haul(i, speed, dt):
		_release_mine_job(i)
		return
	if _seek_mine(i, speed, dt):
		_release_item_claims(i)
		return
	if fed[i] < Catalog.NEED_OK or clean[i] < Catalog.NEED_OK or amused[i] < Catalog.NEED_OK:
		var lack_fed := Catalog.NEED_OK - fed[i]
		var lack_clean := Catalog.NEED_OK - clean[i]
		var lack_fun := Catalog.NEED_OK - amused[i]
		if lack_fed >= lack_clean and lack_fed >= lack_fun:
			if _seek_food(i, speed, dt):
				_release_mine_job(i)
				return
			_release_apple_claim(i)
		elif lack_clean >= lack_fun:
			if _seek_clean(i, speed, dt):
				_release_item_claims(i)
				_release_mine_job(i)
				return
			_release_claim(i)
		else:
			_release_item_claims(i)
			if _tend_fun(i, speed, dt):
				_release_mine_job(i)
				return
		if fed[i] < Catalog.NEED_OK and _seek_food(i, speed, dt):
			_release_mine_job(i)
			return
		if clean[i] < Catalog.NEED_OK and _seek_clean(i, speed, dt):
			_release_item_claims(i)
			_release_mine_job(i)
			return
		if amused[i] < Catalog.NEED_OK:
			_release_item_claims(i)
			if _tend_fun(i, speed, dt):
				_release_mine_job(i)
				return
	else:
		_release_apple_claim(i)
		_release_claim(i)
	_release_mine_job(i)
	_release_item_claims(i)
	if i < peer_t.size() and peer_t[i] > 0.0:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		return
	if _try_peer_social(i):
		return
	_wander(i, speed, dt)


func _start_mitosis(i: int) -> void:
	if _space_blocks_mitosis(i):
		cool[i] = Catalog.MITOSIS_WAIT
		return
	_release_item_claims(i)
	_release_mine_job(i)
	cool[i] = Catalog.MITOSIS_WAIT
	mito_charge[i] = 0.0
	mito_t[i] = MITOSIS_ANIM


func _finish_mitosis(i: int) -> void:
	if _space_blocks_mitosis(i):
		return
	var x := pos_x[i] + MITOSIS_OFFSET
	var y := pos_y[i]
	if _move_blocked(x, y):
		x = pos_x[i]
		y = pos_y[i]
	_push_slot(x, y, 70.0, 70.0, 70.0, Catalog.MITOSIS_WAIT, int(tint[i]))
	sfx_queue.append("mitosis")
	sfx_queue.append("uplink")


func colony_cap() -> int:
	return maxi(2, int(floor(float(_walk_cells()) / float(Catalog.SPACE_PER_THRONG))))


func _invalidate_walk_cells() -> void:
	_walk_cells_cache = -1


func _walk_cells() -> int:
	if save_perf_mode:
		set_meta("_ap_walk_cells_n", int(get_meta("_ap_walk_cells_n", 0)) + 1)
	if _walk_cells_cache >= 0:
		return _walk_cells_cache
	var n := 0
	for ck in revealed.keys():
		if not chunks.has(ck):
			continue
		var origin := chunk_origin(str(ck))
		var tiles: PackedByteArray = chunks[ck].tiles
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var tile := int(tiles[ly * Catalog.CHUNK + lx])
				if Catalog.tile_blocks(tile):
					continue
				var cell := Vector2i(origin.x + lx, origin.y + ly)
				if feature_cell.has(cell) or building_cell.has(cell):
					continue
				n += 1
	_walk_cells_cache = n
	return n


func _space_blocks_mitosis(i: int) -> bool:
	if slot_count >= Catalog.MAX_SLOTS or living >= colony_cap():
		_tell_space_cap()
		return true
	if _count_living_near(pos_x[i], pos_y[i], Catalog.LOCAL_CROWD_R) >= Catalog.LOCAL_CROWD_N:
		_tell_space_cap()
		return true
	return false


func _tell_space_cap() -> void:
	if cap_told:
		return
	cap_told = true
	notes.append("NO HAY SITIO: AMPLIA O DESPEJA TERRENO.")
	if not learn_talked and living >= 2 and not testing:
		learn_talked = true
		_queue_talk("learn_self", {})


func _seek_food(i: int, speed: float, dt: float) -> bool:
	var apple := _nearest_apple(i, 240.0)
	var home := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i)
	var apple_d := 999999.0 if apple.is_empty() else _dist_i(i, float(apple.x), float(apple.y))
	var home_d := 999999.0 if home.is_empty() else _dist_i(i, float(home.x), float(home.y))
	if apple.is_empty() and home.is_empty():
		return false
	# Prefer the nearer option; houses feed while resting.
	if home_d + 8.0 < apple_d:
		_release_apple_claim(i)
		return _approach_home_visit(i, home, speed, dt)
	if apple.is_empty():
		return _approach_home_visit(i, home, speed, dt)
	if not _claim_apple(i, apple):
		if not home.is_empty():
			return _approach_home_visit(i, home, speed, dt)
		return false
	var tx := float(apple.x)
	var ty := float(apple.y)
	if apple_d < 12.0:
		_chew_apple(i, apple, dt)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _claimed_apple(i: int) -> Dictionary:
	if i < 0 or i >= link_claim.size():
		return {}
	var iid := int(link_claim[i])
	if iid < 0:
		return {}
	var it: Dictionary = item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_APPLE:
		return {}
	if int(it.get("claimer", -1)) != i:
		return {}
	return it


func _chew_apple(i: int, apple: Dictionary, dt: float) -> void:
	# Eat while biting; on bite land return to idle (video: Happy stand, not Celebrate/Rotund).
	act[i] = ACT_EAT
	act_t[i] = 0.55
	dir_x[i] = 0.0
	dir_y[i] = 0.0
	var progress := float(apple.get("bite", 0.0)) + dt
	apple.bite = progress
	if progress < 0.45:
		return
	apple.bite = 0.0
	var left := int(apple.get("bites_left", 1)) - 1
	apple.bites_left = left
	fed[i] = 100.0
	act[i] = 0
	act_t[i] = 0.0
	sfx_queue.append("apple")
	hungry_t[i] = 0.0
	_release_apple_claim(i)
	if left <= 0:
		apple.dead = true
		apple.claimer = -1
	else:
		apple.claimer = -1


func _continue_eat(i: int, dt: float) -> bool:
	var apple := _claimed_apple(i)
	if apple.is_empty():
		act[i] = 0
		act_t[i] = 0.0
		return false
	if _dist_i(i, float(apple.x), float(apple.y)) >= 12.0:
		return false
	_chew_apple(i, apple, dt)
	return true


func _continue_sticky_play_or_work(i: int, dt: float) -> bool:
	# Keep ACT_PLAY / ACT_WORK body clips alive when seek budget skips full AI.
	var ball := _linked_ball(i)
	if not ball.is_empty():
		act[i] = ACT_PLAY
		act_t[i] = maxf(act_t[i], 0.35)
		var bd := _dist_i(i, float(ball.x), float(ball.y))
		if bd >= 16.0:
			_walk(i, float(ball.x), float(ball.y), MOVE_SPEED, dt)
		else:
			dir_x[i] = 0.0
			dir_y[i] = 0.0
			amused[i] = minf(100.0, amused[i] + PLAY_AURA_FUN * dt)
		return true
	if i < mine_job.size() and int(mine_job[i]) >= 0 and carry[i] == Catalog.CARRY_NONE:
		var mine: Dictionary = building_by_id.get(int(mine_job[i]), {})
		if mine.is_empty() or mine.dead:
			_release_mine_job(i)
			return false
		act[i] = ACT_WORK
		act_t[i] = maxf(act_t[i], 0.35)
		if _inside_building_reach(pos_x[i], pos_y[i], mine) or _is_guest(mine, i):
			dir_x[i] = 0.0
			dir_y[i] = 0.0
			return true
		var spot := _approach_building(mine, i)
		_walk(i, float(spot.x), float(spot.y), MOVE_SPEED, dt)
		return true
	return false


func _linked_ball(i: int) -> Dictionary:
	if i < 0 or i >= link_ball.size():
		return {}
	var iid := int(link_ball[i])
	if iid < 0:
		return {}
	var it: Dictionary = item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_BALL:
		link_ball[i] = -1
		return {}
	if int(it.get("claimer", -1)) != i:
		link_ball[i] = -1
		return {}
	return it


func _approach_home_visit(i: int, home: Dictionary, speed: float, dt: float) -> bool:
	if home.is_empty():
		return false
	_release_claim(i)
	var edge := _approach_building(home, i)
	var at_rim := _dist_i(i, float(edge.x), float(edge.y)) < 10.0
	if _inside_building_reach(pos_x[i], pos_y[i], home) or at_rim:
		if _enter_visit(i, home):
			act[i] = ACT_BATH
			act_t[i] = 0.4
			return true
		return false
	_walk(i, float(edge.x), float(edge.y), speed, dt)
	return true


func _nearest_apple(i: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for it in items_apple:
		if it.dead or it.held:
			continue
		if float(it.get("air", 0.0)) > 0.0:
			continue
		var who := int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if who < slot_count and state[who] == Catalog.ST_LIVING and not _food_priority_beats(i, who):
				continue
			if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
				_clear_item_claimer(it)
		var d := _dist_i(i, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best


func _food_priority_beats(a: int, b: int) -> bool:
	if b < 0 or b >= slot_count or state[b] != Catalog.ST_LIVING:
		return true
	if fed[b] >= Catalog.NEED_HUNGRY:
		return true
	if fed[a] >= Catalog.NEED_HUNGRY:
		return false
	if hungry_t[a] > hungry_t[b] + 0.05:
		return true
	if hungry_t[b] > hungry_t[a] + 0.05:
		return false
	if fed[a] < fed[b] - 0.5:
		return true
	if fed[b] < fed[a] - 0.5:
		return false
	return a < b


func _claim_apple(i: int, apple: Dictionary) -> bool:
	if apple.is_empty():
		return false
	var who := int(apple.get("claimer", -1))
	if who == i:
		return true
	if who >= 0 and who != i and who < slot_count and state[who] == Catalog.ST_LIVING:
		if not _food_priority_beats(i, who):
			return false
	_release_apple_claim(i)
	_bind_item_claimer(apple, i)
	return true


func _release_apple_claim(i: int) -> void:
	_release_item_claims(i)


func _items_of_kind(kind: int) -> Array:
	match kind:
		Catalog.ITEM_APPLE:
			return items_apple
		Catalog.ITEM_BALL:
			return items_ball
		Catalog.ITEM_WOOD:
			return items_wood
		Catalog.ITEM_BONE:
			return items_bone
		Catalog.ITEM_ORE:
			return items_ore
	return items


func _nearest_free_item(i: int, kind: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for it in _items_of_kind(kind):
		if it.dead or it.held or int(it.kind) != kind:
			continue
		if bool(it.get("falling_void", false)) or float(it.get("air", 0.0)) > 4.0:
			continue
		var who := int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if _item_claim_holds(who):
				continue
			_clear_item_claimer(it)
		var d := _dist_i(i, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best


func _item_claim_holds(who: int) -> bool:
	# Keep the lock while this thronglet can still walk haul this tick.
	# NEED_OK thronglets also haul; dropping the lock there left every plank
	# free each frame and nobody finished the walk-pickup.
	if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
		return false
	if mito_t[who] > 0.0 or shake_t[who] > 0.0:
		return false
	if not _ride_building(who).is_empty():
		return false
	if not seat_of(who).is_empty():
		return false
	if fed[who] < Catalog.NEED_HUNGRY or clean[who] < Catalog.NEED_SEEK or amused[who] < Catalog.NEED_FUN:
		return false
	return true


func _claim_item(i: int, item: Dictionary) -> void:
	if item.is_empty():
		return
	var who := int(item.get("claimer", -1))
	if who == i:
		return
	if who >= 0 and who != i and _item_claim_holds(who):
		return
	_release_item_claims(i)
	_bind_item_claimer(item, i)


func _bind_item_claimer(item: Dictionary, i: int) -> void:
	var prev := int(item.get("claimer", -1))
	if prev >= 0 and prev != i and prev < link_claim.size():
		if link_claim[prev] == int(item.id):
			link_claim[prev] = -1
		if link_ball[prev] == int(item.id):
			link_ball[prev] = -1
	item.claimer = i
	if i < 0 or i >= link_claim.size():
		return
	link_claim[i] = int(item.id)
	link_ball[i] = int(item.id) if int(item.kind) == Catalog.ITEM_BALL else -1


func _clear_item_claimer(item: Dictionary) -> void:
	var who := int(item.get("claimer", -1))
	item.claimer = -1
	if who < 0 or who >= link_claim.size():
		return
	if link_claim[who] == int(item.id):
		link_claim[who] = -1
	if link_ball[who] == int(item.id):
		link_ball[who] = -1


func _release_item_claims(i: int) -> void:
	if i < 0 or i >= link_claim.size():
		return
	var iid := link_claim[i]
	link_claim[i] = -1
	link_ball[i] = -1
	if iid < 0:
		return
	var it: Dictionary = item_by_id.get(iid, {})
	if not it.is_empty() and int(it.get("claimer", -1)) == i:
		it.claimer = -1


func _seek_clean(i: int, speed: float, dt: float) -> bool:
	var tub := _nearest_tub(i)
	var home := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i)
	var use_tub := false
	var target := {}
	var best := 999999.0
	if not tub.is_empty():
		best = _dist_i(i, float(tub.x), float(tub.y))
		target = tub
		use_tub = true
	if not home.is_empty():
		var d2 := _dist_i(i, float(home.x), float(home.y))
		if d2 < best:
			best = d2
			target = home
			use_tub = false
	if target.is_empty():
		_release_claim(i)
		return false
	if use_tub:
		_claim_tub(i, target)
		if int(target.get("occupant", -1)) != i:
			# Tub taken by someone else: don't camp at the rim walking in
			# place. Release and do something else this tick; retry next time.
			_release_claim(i)
			return false
		# Tub is free (or already ours): go bathe if within reach.
		var edge := _approach_building(target, i)
		var at_rim := _dist_i(i, float(edge.x), float(edge.y)) < 10.0
		if _inside_building_reach(pos_x[i], pos_y[i], target) or at_rim:
			_do_bath(i, target, dt)
			return true
		_walk(i, float(edge.x), float(edge.y), speed, dt)
		return true
	return _approach_home_visit(i, target, speed, dt)


func _do_bath(i: int, b: Dictionary, dt: float) -> void:
	if b.is_empty():
		return
	_claim_tub(i, b)
	if int(b.get("occupant", -1)) != i:
		return
	var age := float(b.get("bath_t", -1.0))
	if age < 0.0:
		b.bath_t = 0.0
		sfx_queue.append("tub_in")
		sfx_queue.append("splash")
	else:
		b.bath_t = age + dt
	act[i] = ACT_BATH
	act_t[i] = 0.55
	if i < seek_t.size():
		seek_t[i] = 0.0
	var seat := Vector2(float(b.x), float(b.y)) + Catalog.TUB_SEAT_OFF
	_set_agent_pos(i, seat.x, seat.y)
	dir_x[i] = 0.0
	dir_y[i] = 0.0
	b.active = true
	clean[i] = minf(100.0, clean[i] + BATH_CLEAN_RATE * dt)
	if clean[i] >= BATH_DONE and float(b.bath_t) >= BATH_MIN_STAY:
		_finish_bath(i, b)


func _finish_bath(i: int, b: Dictionary) -> void:
	var rim := _approach_building(b, i)
	_release_claim(i)
	if i < seek_t.size():
		seek_t[i] = 0.0
	_set_agent_pos(i, float(rim.x), float(rim.y))
	act[i] = ACT_BATH
	act_t[i] = 0.35
	_pop(pos_x[i], pos_y[i], AssetFrames.CLEAN, 1.0, i, 0.9, "bath")


func _nearest_roundabout(i: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	var slots_n := _ride_slot_count()
	for b in blds_round:
		if b.dead or bool(b.get("lifted", false)):
			continue
		# Already boarding/riding this one: keep going. Otherwise skip full rides
		# so seekers do not camp the rim walking in place (same as busy tubs).
		var mine := _is_rider(b, i) or _ride_slot_of(b, i) >= 0
		if not mine and _taken_ride_slots(b).size() >= slots_n:
			continue
		var d := _dist_i(i, float(b.x), float(b.y))
		if d < best_d:
			best_d = d
			best = b
	return best


func _rider_list(b: Dictionary) -> Array:
	var raw = b.get("riders", [])
	if raw is Array:
		return raw
	return []


func _is_rider(b: Dictionary, i: int) -> bool:
	for raw in _rider_list(b):
		if int(raw) == i:
			return true
	return false


func _set_rider(b: Dictionary, i: int, on: bool, clear_slot: bool = true) -> void:
	var kept: Array = []
	for raw in _rider_list(b):
		if int(raw) != i:
			kept.append(int(raw))
	if on:
		kept.append(i)
		if i >= 0 and i < link_ride.size():
			link_ride[i] = int(b.id)
	else:
		_set_ride_age(b, i, -1.0)
		if clear_slot:
			_set_ride_slot(b, i, -1)
		if i >= 0 and i < link_ride.size() and link_ride[i] == int(b.id):
			link_ride[i] = -1
	b.riders = kept


func _ride_building(i: int) -> Dictionary:
	if i < 0 or i >= link_ride.size():
		return {}
	var bid := link_ride[i]
	if bid >= 0:
		var linked: Dictionary = building_by_id.get(bid, {})
		if not linked.is_empty() and not linked.dead and not bool(linked.get("lifted", false)) and _is_rider(linked, i):
			return linked
		link_ride[i] = -1
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if _is_rider(b, i):
			link_ride[i] = int(b.id)
			return b
	return {}


func _clear_ride(i: int) -> void:
	if i >= 0 and i < link_ride.size() and link_ride[i] >= 0:
		var b: Dictionary = building_by_id.get(link_ride[i], {})
		if not b.is_empty() and _is_rider(b, i):
			_set_rider(b, i, false)
			return
	for b in buildings:
		if _is_rider(b, i):
			_set_rider(b, i, false)


func _footprint_center_of(b: Dictionary) -> Vector2:
	var size := Catalog.footprint_for_building(int(b.kind))
	var cells := _footprint_cells(float(b.x), float(b.y), size)
	if cells.is_empty():
		return Vector2(float(b.x), float(b.y))
	var acc := Vector2.ZERO
	for cell in cells:
		acc += _cell_world(cell)
	return acc / float(cells.size())


func _ride_center_of(b: Dictionary) -> Vector2:
	var car := _ride_cfg()
	var off: Vector2 = car.get("center_offset", Catalog.ROUND_RIDE_OFF)
	return Vector2(float(b.x), float(b.y)) + off


func _ride_radius(_b: Dictionary) -> float:
	var car := _ride_cfg()
	return TiovivoLabTune.seat_radius(int(car.get("slots", Catalog.ROUND_RIDE_SLOTS)), float(car.get("seat_spacing", 12.0)))


func _ride_slot_count() -> int:
	return maxi(1, int(_ride_cfg().get("slots", Catalog.ROUND_RIDE_SLOTS)))


func _ride_age_of(b: Dictionary, i: int) -> float:
	var ages: Variant = b.get("ride_age", {})
	if ages is Dictionary and ages.has(i):
		return float(ages[i])
	return -1.0


func _set_ride_age(b: Dictionary, i: int, age: float) -> void:
	var ages: Dictionary = {}
	var raw: Variant = b.get("ride_age", {})
	if raw is Dictionary:
		ages = (raw as Dictionary).duplicate()
	if age < 0.0:
		ages.erase(i)
	else:
		ages[i] = age
	b.ride_age = ages


func _ride_slot_of(b: Dictionary, i: int) -> int:
	var slots: Variant = b.get("ride_slot", {})
	if slots is Dictionary and slots.has(i):
		return int(slots[i])
	return -1


func _set_ride_slot(b: Dictionary, i: int, slot: int) -> void:
	var slots: Dictionary = {}
	var raw: Variant = b.get("ride_slot", {})
	if raw is Dictionary:
		slots = (raw as Dictionary).duplicate()
	if slot < 0:
		slots.erase(i)
	else:
		slots[i] = slot
	b.ride_slot = slots


func _taken_ride_slots(b: Dictionary, except_i: int = -1) -> Dictionary:
	var taken := {}
	var raw: Variant = b.get("ride_slot", {})
	if raw is Dictionary:
		for key in raw.keys():
			var who := int(key)
			if who == except_i:
				continue
			if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
				continue
			taken[int(raw[key])] = who
	return taken


func _ang_delta(a: float, b: float) -> float:
	var d := fposmod(a - b + PI, TAU) - PI
	return absf(d)


func _pick_ride_slot(b: Dictionary, approach_ang: float) -> int:
	var n := _ride_slot_count()
	var taken := _taken_ride_slots(b)
	var best := -1
	var best_score := -INF
	for slot in n:
		if taken.has(slot):
			continue
		var slot_ang := _ride_slot_ang(b, slot)
		var near := _ang_delta(slot_ang, approach_ang)
		var sep := TAU
		for other in taken.keys():
			sep = minf(sep, _ang_delta(slot_ang, _ride_slot_ang(b, int(other))))
		# Prefer max separation from seated riders; break ties toward the approach.
		var score := sep * 100.0 - near
		if taken.is_empty():
			score = -near
		if score > best_score:
			best_score = score
			best = slot
	return best


func _ride_slot_ang(b: Dictionary, slot: int) -> float:
	# Angle follows building spin plus the tuned base offset, matching the lab.
	var car := _ride_cfg()
	var n := maxf(1.0, float(_ride_slot_count()))
	var base := deg_to_rad(float(car.get("slot_base_deg", 0.0)))
	return float(b.get("spin", 0.0)) + base + float(slot) * TAU / n


func _ride_slot_pos(b: Dictionary, slot: int) -> Vector2:
	var center := _ride_center_of(b)
	var ang := _ride_slot_ang(b, slot)
	var r := _ride_radius(b)
	return Vector2(center.x + cos(ang) * r, center.y + sin(ang) * r)


func _place_on_ride_slot(i: int, b: Dictionary, slot: int) -> bool:
	var seat := _ride_slot_pos(b, slot)
	if _ride_spot_blocked(seat.x, seat.y, b):
		return false
	var ang := _ride_slot_ang(b, slot)
	_set_agent_pos(i, seat.x, seat.y)
	dir_x[i] = cos(ang + PI * 0.5)
	dir_y[i] = sin(ang + PI * 0.5)
	return true


func _leave_ride(i: int, b: Dictionary) -> void:
	_set_rider(b, i, false)
	_set_ride_age(b, i, -1.0)
	if int(act[i]) == ACT_PLAY:
		act[i] = 0
		act_t[i] = 0.0
	# Step off onto the approach rim. Do not teleport far away.
	var rim := _approach_building(b, i)
	if _move_blocked(float(rim.x), float(rim.y)):
		rim = _approach_spot(float(b.x), float(b.y), _ride_radius(b) + 10.0, i)
	if _move_blocked(float(rim.x), float(rim.y)):
		return
	_set_agent_pos(i, float(rim.x), float(rim.y))
	dir_x[i] = 0.0
	dir_y[i] = 0.0


func _ride_gate_pos(b: Dictionary, slot: int) -> Vector2:
	# Fixed compass gate (no spin). A spinning gate makes approachers chase forever.
	var center := _ride_center_of(b)
	var n := float(_ride_slot_count())
	var ang := float(slot) * TAU / n
	var reach := _ride_radius(b) + 14.0
	var gate := Vector2(center.x + cos(ang) * reach, center.y + sin(ang) * reach)
	if _move_blocked(gate.x, gate.y):
		return _approach_building(b, -1)
	return gate


func _do_roundabout_ride(i: int, b: Dictionary, dt: float) -> void:
	_release_item_claims(i)
	var center := _ride_center_of(b)
	var orbit_r := _ride_radius(b)
	var dx := pos_x[i] - center.x
	var dy := pos_y[i] - center.y
	var dist := sqrt(dx * dx + dy * dy)
	var ang := atan2(dy, dx)
	if dist < 1.0:
		ang = float(i) * 1.7
	# Approaching: keep a reserved seat and walk to that gate before stepping on.
	if dist > orbit_r + 2.0:
		if _is_rider(b, i):
			_set_rider(b, i, false, false)
		_set_ride_age(b, i, -1.0)
		var slot := _ride_slot_of(b, i)
		if slot < 0 or _taken_ride_slots(b, i).has(slot):
			slot = _pick_ride_slot(b, ang)
			if slot < 0:
				# Full: do not camp the approach rim. Seek will pick other fun.
				dir_x[i] = 0.0
				dir_y[i] = 0.0
				return
			_set_ride_slot(b, i, slot)
		var gate := _ride_gate_pos(b, slot)
		var gate_d := _dist_point(pos_x[i], pos_y[i], gate.x, gate.y)
		# Hold at the reserved gate, then step onto that seat only.
		if gate_d > 5.0 and not _inside_building_reach(pos_x[i], pos_y[i], b):
			_walk(i, float(gate.x), float(gate.y), MOVE_SPEED, dt)
			return
		var seat := _ride_slot_pos(b, slot)
		if _ride_spot_blocked(seat.x, seat.y, b) or not _place_on_ride_slot(i, b, slot):
			# Seat unusable — drop claim and retry next tick.
			_set_ride_slot(b, i, -1)
			return
		if int(act[i]) != ACT_PLAY:
			sfx_queue.append("round_start")
		act[i] = ACT_PLAY
		act_t[i] = 0.55
		_set_rider(b, i, true)
		_set_ride_age(b, i, 0.0)
		amused[i] = minf(100.0, amused[i] + _ride_fun_rate() * dt)
		b.active = true
		return
	var was_rider := _is_rider(b, i)
	if int(act[i]) != ACT_PLAY:
		sfx_queue.append("round_start")
	act[i] = ACT_PLAY
	act_t[i] = 0.55
	var slot := _ride_slot_of(b, i)
	if slot < 0 or _taken_ride_slots(b, i).has(slot):
		slot = _pick_ride_slot(b, ang)
	if slot < 0:
		_leave_ride(i, b)
		return
	_set_ride_slot(b, i, slot)
	_set_rider(b, i, true)
	var age := _ride_age_of(b, i)
	if not was_rider or age < 0.0:
		age = 0.0
	else:
		age += dt
	_set_ride_age(b, i, age)
	if not _place_on_ride_slot(i, b, slot):
		_leave_ride(i, b)
		return
	amused[i] = minf(100.0, amused[i] + _ride_fun_rate() * dt)
	b.active = true
	if amused[i] >= _ride_done_need() and age >= _ride_min_stay_need():
		_leave_ride(i, b)


func _tend_fun(i: int, speed: float, dt: float) -> bool:
	var riding_b := _ride_building(i)
	if not riding_b.is_empty():
		_do_roundabout_ride(i, riding_b, dt)
		return true
	return _seek_fun(i, speed, dt)


func _seek_fun(i: int, speed: float, dt: float) -> bool:
	var round := _nearest_roundabout(i, 320.0)
	var ball := _nearest_ball(i, 260.0)
	var play := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_THEATRE, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD], 320.0, i)
	var tx := 0.0
	var ty := 0.0
	var best := 999999.0
	var radius := 16.0
	var use_ball := false
	var use_round := false
	var play_kind := -1
	if not round.is_empty():
		best = _dist_i(i, float(round.x), float(round.y))
		tx = float(round.x)
		ty = float(round.y)
		radius = 18.0
		use_round = true
	if not ball.is_empty():
		var d_ball := _dist_i(i, float(ball.x), float(ball.y))
		if d_ball < best:
			best = d_ball
			tx = float(ball.x)
			ty = float(ball.y)
			radius = 16.0
			use_ball = true
			use_round = false
	if not play.is_empty():
		var d2 := _dist_i(i, float(play.x), float(play.y))
		if d2 < best:
			best = d2
			tx = float(play.x)
			ty = float(play.y)
			play_kind = int(play.kind)
			if _is_show(play_kind):
				radius = 52.0
			else:
				radius = 22.0
			use_ball = false
			use_round = false
	if best > 900000.0:
		return false
	if use_round:
		var rim := _approach_building(round, i)
		if _inside_building_reach(pos_x[i], pos_y[i], round) or _dist_i(i, float(rim.x), float(rim.y)) < 10.0:
			_do_roundabout_ride(i, round, dt)
			# Boarded or still holding a seat claim.
			if _is_rider(round, i) or _ride_slot_of(round, i) >= 0:
				return true
			# Full at the gate: fall through to ball / play buildings.
			use_round = false
			best = 999999.0
			if not ball.is_empty():
				best = _dist_i(i, float(ball.x), float(ball.y))
				tx = float(ball.x)
				ty = float(ball.y)
				radius = 16.0
				use_ball = true
			if not play.is_empty():
				var d_play := _dist_i(i, float(play.x), float(play.y))
				if d_play < best:
					best = d_play
					tx = float(play.x)
					ty = float(play.y)
					play_kind = int(play.kind)
					if _is_show(play_kind):
						radius = 52.0
					else:
						radius = 22.0
					use_ball = false
			if best > 900000.0:
				return false
		else:
			_walk(i, float(rim.x), float(rim.y), speed, dt)
			return true
	if use_ball:
		_claim_ball(i, ball)
	else:
		_release_item_claims(i)
	# Theatre: enter at the approach rim like homes/mines. Pad edges are often
	# blocked, so _approach_building sits just outside the reach ellipse and a
	# strict inside-only check leaves thronglets camping the door forever.
	# Rim must match _walk's give-up distance (TILE*1.25): walk stops before 10px.
	if not use_ball and not play.is_empty() and play_kind >= 0 and _is_show(play_kind):
		var show_edge := _approach_building(play, i)
		var at_rim := _dist_i(i, float(show_edge.x), float(show_edge.y)) < float(Catalog.TILE) * 1.25
		if _inside_building_reach(pos_x[i], pos_y[i], play) or at_rim:
			if _enter_visit(i, play):
				act[i] = ACT_PLAY
				act_t[i] = 0.4
				return true
			return false
		_walk(i, float(show_edge.x), float(show_edge.y), speed, dt)
		return true
	if not use_ball and not play.is_empty() and play_kind >= 0 and _inside_building_reach(pos_x[i], pos_y[i], play):
		act[i] = ACT_PLAY
		act_t[i] = 0.55
		amused[i] = minf(100.0, amused[i] + PLAY_AURA_FUN * dt)
		return true
	if best < radius:
		act[i] = ACT_PLAY
		act_t[i] = 0.55
		if use_ball and int(ball.get("claimer", -1)) == i:
			if float(ball.get("rest", 0.0)) <= 0.0:
				var kx := float(ball.x) - pos_x[i]
				var ky := float(ball.y) - pos_y[i]
				var kl := sqrt(kx * kx + ky * ky)
				if kl < 1.0:
					var kick_ang := randf() * TAU
					kx = cos(kick_ang)
					ky = sin(kick_ang)
					kl = 1.0
				ball.vx = kx / kl * 96.0
				ball.vy = ky / kl * 78.0
				ball.vz = maxf(float(ball.get("vz", 0.0)), 105.0)
				ball.air = maxf(float(ball.get("air", 0.0)), 1.0)
				ball.rest = 0.7
				ball.life = BALL_LIFE
				amused[i] = minf(100.0, amused[i] + BALL_KICK_FUN)
				dir_x[i] = 0.0
				dir_y[i] = 0.0
				_pop(pos_x[i], pos_y[i] - 6.0, Catalog.ICON_BALL, Catalog.BALL_SPRITE_SCALE)
				sfx_queue.append("ball")
			elif best > 4.0:
				_walk(i, tx, ty, speed * 1.15, dt)
			else:
				dir_x[i] = 0.0
				dir_y[i] = 0.0
			return true
		amused[i] = minf(100.0, amused[i] + PLAY_AURA_FUN * dt)
		return true
	var walk_to := _approach_building(play, i) if not use_ball and not play.is_empty() else Vector2(tx, ty)
	_walk(i, float(walk_to.x), float(walk_to.y), speed, dt)
	return true


func _nearest_ball(i: int, max_dist: float) -> Dictionary:
	return _nearest_free_item(i, Catalog.ITEM_BALL, max_dist)


func _claim_ball(i: int, ball: Dictionary) -> void:
	_claim_item(i, ball)


func _try_haul(i: int, speed: float, dt: float) -> bool:
	if carry[i] != Catalog.CARRY_NONE:
		_release_item_claims(i)
		return _deliver(i, speed, dt)
	if _has_factory():
		var ore := _nearest_free_item(i, Catalog.ITEM_ORE, 180.0)
		if not ore.is_empty():
			return _walk_pickup(i, ore, Catalog.CARRY_ORE, speed, dt)
	return false


func _walk_pickup(i: int, item: Dictionary, carry_kind: int, speed: float, dt: float) -> bool:
	_claim_item(i, item)
	var tx := float(item.x)
	var ty := float(item.y)
	if _dist_i(i, tx, ty) < 8.0:
		if item.dead or item.held:
			return false
		if int(item.get("claimer", -1)) != i:
			# Stale living claim without a hold — take it and finish the grab.
			if _item_claim_holds(int(item.get("claimer", -1))):
				return false
			item.claimer = i
		_set_carry(i, carry_kind, int(item.value))
		item.claimer = -1
		item.dead = true
		_invalidate_item_counts()
		if carry_kind == Catalog.CARRY_WOOD:
			sfx_queue.append("wood_grab")
		elif carry_kind == Catalog.CARRY_BONE:
			sfx_queue.append("bone_grab")
		_release_item_claims(i)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _deliver(i: int, speed: float, dt: float) -> bool:
	var factory := {}
	if carry[i] == Catalog.CARRY_ORE:
		factory = _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2], 4000.0)
		if factory.is_empty():
			_set_carry(i, Catalog.CARRY_NONE)
			return false
	else:
		_set_carry(i, Catalog.CARRY_NONE)
		return false
	# Walk to a free rim spot — the factory pad center is blocked and mid-path
	# shore gaps need local inland waypoints or haulers oscillate forever.
	var spot := _approach_building(factory, i)
	var tx := float(spot.x)
	var ty := float(spot.y)
	if _haul_path_blocked(i, tx, ty):
		var via := _haul_waypoint(i, tx, ty)
		tx = via.x
		ty = via.y
	act[i] = ACT_WORK
	act_t[i] = 0.3
	_walk(i, tx, ty, speed, dt)
	if (
		_inside_building_reach(pos_x[i], pos_y[i], factory)
		or _dist_i(i, float(spot.x), float(spot.y)) < 12.0
		or _dist_i(i, float(factory.x), float(factory.y)) < 72.0
	):
		_factory_stack(factory, maxi(1, carry_value[i]))
		factory.active = true
		_set_carry(i, Catalog.CARRY_NONE)
	return true


func _haul_path_blocked(i: int, tx: float, ty: float) -> bool:
	var dx := tx - pos_x[i]
	var dy := ty - pos_y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 20.0:
		return false
	return _goal_path_blocked(pos_x[i], pos_y[i], dx / dist, dy / dist, mini(dist, 56.0))


func _haul_waypoint(i: int, tx: float, ty: float) -> Vector2:
	# Local inland hop that still progresses toward the factory rim.
	var origin := Vector2(pos_x[i], pos_y[i])
	var goal := Vector2(tx, ty)
	var goal_dir := goal - origin
	if goal_dir.length_squared() < 0.01:
		return goal
	goal_dir = goal_dir.normalized()
	# Prefer the hop already in seek — flipping every frame loops the hauler.
	if i < seek_t.size() and seek_t[i] > 0.15:
		var kept := Vector2(seek_x[i], seek_y[i])
		if origin.distance_squared_to(kept) > 14.0 * 14.0 and not _move_blocked(kept.x, kept.y):
			if (kept - origin).normalized().dot(goal_dir) > 0.05:
				return kept
	var inland := _inland_dir(i)
	var shore := _shore_push(i)
	var facing := Vector2(dir_x[i], dir_y[i])
	var best := goal
	var best_score := -INF
	for n in 12:
		var ang := float(n) * (TAU / 12.0)
		var hop := origin + Vector2(cos(ang), sin(ang)) * 56.0
		if _move_blocked(hop.x, hop.y):
			continue
		var step := hop - origin
		var step_n := step.normalized()
		var score := step.dot(goal_dir) * 3.0
		score += (origin.distance_to(goal) - hop.distance_to(goal)) * 2.0
		if facing.length_squared() > 0.2:
			score += step_n.dot(facing.normalized()) * 12.0
		if inland != Vector2.ZERO:
			score += step_n.dot(inland) * 8.0
		if shore != Vector2.ZERO:
			score += step_n.dot(shore) * 10.0
		if score > best_score:
			best_score = score
			best = hop
	if best_score > -INF:
		return best
	if inland != Vector2.ZERO:
		var inland_hop := origin + inland * 48.0
		if not _move_blocked(inland_hop.x, inland_hop.y):
			return inland_hop
	return goal


func _work_radius(b: Dictionary) -> float:
	var reach := Catalog.building_reach(int(b.kind))
	return maxf(reach.x, reach.y)


func _set_mine_job(i: int, bid: int) -> void:
	if i < 0 or i >= mine_job.size():
		return
	var prev := int(mine_job[i])
	if prev == bid:
		return
	if prev >= 0:
		mine_job_n[prev] = maxi(0, int(mine_job_n.get(prev, 0)) - 1)
	mine_job[i] = bid
	if bid >= 0:
		mine_job_n[bid] = int(mine_job_n.get(bid, 0)) + 1


func _release_mine_job(i: int) -> void:
	_set_mine_job(i, -1)


func _mine_jobs(b: Dictionary) -> int:
	return int(mine_job_n.get(int(b.id), 0))


func _mine_taker(b: Dictionary, cap: int) -> int:
	var bid := int(b.id)
	var radius := _work_radius(b) + 8.0
	# Prefer assigned workers inside the mine, ready and empty-handed.
	for raw in living_ids:
		var who := int(raw)
		if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
			continue
		if int(mine_job[who]) != bid:
			continue
		if carry[who] != Catalog.CARRY_NONE:
			continue
		if not _work_ready(who):
			continue
		if _inside_building_reach(pos_x[who], pos_y[who], b) or _dist_point(pos_x[who], pos_y[who], float(b.x), float(b.y)) <= radius:
			return who
	return -1


func _seek_mine(i: int, speed: float, dt: float) -> bool:
	# Dirty / hungry thronglets must not mine. Jobs are claimed on the walk so
	# the whole colony cannot rush the rim before ACT_WORK sticks.
	if not _work_ready(i) or not _has_factory() or carry[i] != Catalog.CARRY_NONE:
		_release_mine_job(i)
		return false
	var mine := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		_release_mine_job(i)
		return false
	if _is_guest(mine, i):
		act[i] = ACT_WORK
		act_t[i] = 0.5
		return true
	var stock := int(mine.get("buffer", 0))
	var digging := _live_guests(mine)
	# Each digger needs a reserved stock unit waiting inside.
	if stock <= digging:
		_release_mine_job(i)
		return false
	var cap := 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	var bid := int(mine.id)
	var already := int(mine_job[i]) == bid
	if digging + _mine_jobs(mine) >= cap and not already:
		_release_mine_job(i)
		return false
	_set_mine_job(i, bid)
	var spot := _approach_building(mine, i)
	var tx := float(spot.x)
	var ty := float(spot.y)
	if _inside_building_reach(pos_x[i], pos_y[i], mine) or _dist_i(i, tx, ty) < 8.0:
		if _enter_visit(i, mine):
			_release_mine_job(i)
			act[i] = ACT_WORK
			act_t[i] = 0.5
			return true
		_release_mine_job(i)
		return false
	act[i] = ACT_WORK
	act_t[i] = 0.5
	_walk(i, tx, ty, speed, dt)
	return true


func _wander(i: int, speed: float, dt: float) -> void:
	# Drop stale seek (tub/food/…) or debug path and coast keep chasing it.
	if i < seek_t.size():
		seek_t[i] = 0.0
	wander_t[i] -= dt
	if wander_t[i] <= 0.0:
		_pick_wander(i)
	if absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
		return
	_snap_dir_cardinal(i)
	if _move_blocked(pos_x[i] + dir_x[i] * 12.0, pos_y[i] + dir_y[i] * 12.0):
		_pick_wander(i)
		_snap_dir_cardinal(i)
		if absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
			return
	_move_cardinal_toward(i, pos_x[i] + dir_x[i] * 32.0, pos_y[i] + dir_y[i] * 32.0, speed * dt)


func _pick_wander(i: int) -> void:
	if randf() < 0.14:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		wander_t[i] = randf_range(0.35, 1.1)
		return
	var open := _open_dir(i, _curious_dir(i))
	if open == Vector2.ZERO:
		open = _open_dir(i, _shore_push(i))
	if open == Vector2.ZERO:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		wander_t[i] = randf_range(0.25, 0.7)
		return
	dir_x[i] = open.x
	dir_y[i] = open.y
	wander_t[i] = randf_range(0.9, 2.8)


func _curious_dir(i: int) -> Vector2:
	var shore := _shore_push(i)
	if shore != Vector2.ZERO and randf() < 0.75:
		return shore
	var spot := _curiosity_spot(i)
	if spot != Vector2.ZERO and randf() < 0.65:
		return spot
	var ang := randf() * TAU
	var explore := Vector2(cos(ang), sin(ang))
	var inland := _inland_dir(i)
	var mixed := explore * 0.8 + inland * 0.2
	if mixed.length_squared() < 0.01:
		return explore
	return mixed.normalized()


func _curiosity_spot(i: int) -> Vector2:
	var px := pos_x[i]
	var py := pos_y[i]
	var best := Vector2.ZERO
	var best_d := 200.0
	for b in buildings:
		if b.get("dead", false):
			continue
		var bx := float(b.x)
		var by := float(b.y)
		var d := _dist_point(px, py, bx, by)
		if d < 36.0 or d > best_d:
			continue
		if randf() > 0.4:
			continue
		best_d = d
		best = Vector2(bx - px, by - py)
	if best != Vector2.ZERO:
		return best.normalized()
	var ang := randf() * TAU
	var reach := randf_range(48.0, 130.0)
	var tx := px + cos(ang) * reach
	var ty := py + sin(ang) * reach
	if _move_blocked(tx, ty):
		return Vector2.ZERO
	return Vector2(cos(ang), sin(ang))


func _shore_push(i: int) -> Vector2:
	var push := Vector2.ZERO
	for n in 8:
		var a := float(n) * TAU * 0.125
		var sx := cos(a)
		var sy := sin(a)
		if _tile_at(pos_x[i] + sx * 10.0, pos_y[i] + sy * 10.0) == Catalog.TILE_WATER:
			push -= Vector2(sx, sy)
		elif _move_blocked(pos_x[i] + sx * 10.0, pos_y[i] + sy * 10.0):
			push -= Vector2(sx, sy) * 0.55
	if push.length_squared() < 0.01:
		return Vector2.ZERO
	return push.normalized()


func _inland_dir(i: int) -> Vector2:
	var to := Vector2(256.0 - pos_x[i], 256.0 - pos_y[i])
	if to.length_squared() < 1.0:
		return Vector2(cos(float(i)), sin(float(i)))
	return to.normalized()


func _clear_run(i: int, dx: float, dy: float) -> float:
	return _clear_run_at(pos_x[i], pos_y[i], dx, dy)


func _open_dir(i: int, prefer: Vector2) -> Vector2:
	var base := prefer
	if base.length_squared() < 0.01:
		base = Vector2(1.0, 0.0)
	else:
		base = base.normalized()
	var best := Vector2.ZERO
	var best_score := -1.0
	# Min run 6 — a 1-tile tree gap clears ~8px; 10 rejected every narrow path.
	for n in 8:
		var d := base.rotated(float(n) * (TAU / 8.0))
		var run := _clear_run(i, d.x, d.y)
		if run < 6.0:
			continue
		var score := run * 2.5 + d.dot(base) * 5.0
		if score > best_score:
			best_score = score
			best = d
	if best != Vector2.ZERO:
		return best
	for n in 8:
		var d2 := base.rotated(float(n) * (TAU / 8.0) + TAU / 16.0)
		var run2 := _clear_run(i, d2.x, d2.y)
		if run2 < 4.0:
			continue
		var score2 := run2 * 2.5 + d2.dot(base) * 5.0
		if score2 > best_score:
			best_score = score2
			best = d2
	return best


func _side_dir(i: int, goal: Vector2) -> Vector2:
	# Tangents around a blocked goal. Shore-push aims backward and restarts the corner loop.
	var left := Vector2(-goal.y, goal.x)
	var right := Vector2(goal.y, -goal.x)
	var run_l := _clear_run(i, left.x, left.y)
	var run_r := _clear_run(i, right.x, right.y)
	var cur := Vector2(dir_x[i], dir_y[i])
	if cur.length_squared() > 0.2:
		if cur.dot(left) >= cur.dot(right):
			run_l += 6.0
		else:
			run_r += 6.0
	return left if run_l >= run_r else right


func _hold_avoid(i: int, secs: float = 0.2) -> void:
	if i < 0 or i >= avoid_t.size():
		return
	avoid_t[i] = maxf(avoid_t[i], secs)


func _walk(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	var _walk_t0 := 0
	if save_perf_mode:
		_walk_t0 = Time.get_ticks_usec()
	if _move_blocked(pos_x[i], pos_y[i]):
		_unstick(i)
		if i < seek_t.size():
			seek_t[i] = 0.0
		if save_perf_mode:
			set_meta("_ap_walk_us", int(get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	var dx := tx - pos_x[i]
	var dy := ty - pos_y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		if i < seek_t.size():
			seek_t[i] = 0.0
		if i < avoid_t.size():
			avoid_t[i] = 0.0
		if save_perf_mode:
			set_meta("_ap_walk_us", int(get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	if i < seek_t.size():
		seek_x[i] = tx
		seek_y[i] = ty
		seek_t[i] = Catalog.SEEK_HOLD
	if avoid_t[i] > 0.0:
		avoid_t[i] = maxf(0.0, avoid_t[i] - dt)
	var step := speed * dt
	var hop := _path_hop(pos_x[i], pos_y[i], tx, ty)
	if hop == Vector2.ZERO:
		# No improving BFS step (blocked goal / sealed best). Stopping beats
		# unstick-teleport bouncing inside a tree enclosure forever.
		if i < seek_t.size():
			seek_t[i] = 0.0
		if save_perf_mode:
			set_meta("_ap_walk_us", int(get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	# Already on the best open cell (blocked goal / dead-end approach) — stop, do not unstick-spin.
	if absf(hop.x - pos_x[i]) <= 0.5 and absf(hop.y - pos_y[i]) <= 0.5:
		if _move_blocked(tx, ty) or dist <= float(Catalog.TILE) * 1.25:
			if i < seek_t.size():
				seek_t[i] = 0.0
		if save_perf_mode:
			set_meta("_ap_walk_us", int(get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	var moved := _steer_toward(i, hop.x, hop.y, step)
	if not moved:
		# Peel around the blocker toward the hop; unstick only when wedged.
		var toward := Vector2(hop.x - pos_x[i], hop.y - pos_y[i])
		var peel := _open_dir(i, toward)
		if peel == Vector2.ZERO:
			peel = _open_dir(i, _side_dir(i, toward))
		if peel != Vector2.ZERO:
			dir_x[i] = peel.x
			dir_y[i] = peel.y
			_snap_dir_cardinal(i)
			moved = _move_cardinal_toward(i, pos_x[i] + dir_x[i] * 32.0, pos_y[i] + dir_y[i] * 32.0, step)
		if not moved:
			if _move_blocked(pos_x[i], pos_y[i]) or _corner_trap(i):
				_unstick(i)
			if i < seek_t.size():
				seek_t[i] = 0.0
	elif _move_blocked(pos_x[i], pos_y[i]):
		_unstick(i)
		if i < seek_t.size():
			seek_t[i] = 0.0
	if save_perf_mode:
		set_meta("_ap_walk_us", int(get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))


func _steer_toward(i: int, tx: float, ty: float, step: float) -> bool:
	# Cardinal BFS hops stay on one axis (no cell-center zigzag). Open space steers linearly.
	var hop_cell := _cell_vec(tx, ty)
	var cur_cell := _cell_vec(pos_x[i], pos_y[i])
	var dc := hop_cell - cur_cell
	if absi(dc.x) + absi(dc.y) == 1:
		if dc.x != 0:
			return _move_cardinal_toward(i, tx, pos_y[i], step)
		return _move_cardinal_toward(i, pos_x[i], ty, step)
	var adx := tx - pos_x[i]
	var ady := ty - pos_y[i]
	# Ignore sub-tile drift on the minor axis so "up" stays a straight line.
	if absf(adx) <= 1.5 and absf(ady) > absf(adx):
		adx = 0.0
	elif absf(ady) <= 1.5 and absf(adx) > absf(ady):
		ady = 0.0
	var len := sqrt(adx * adx + ady * ady)
	if len < 0.01:
		return false
	var mx := adx / len * step
	var my := ady / len * step
	if absf(mx) > absf(adx):
		mx = adx
	if absf(my) > absf(ady):
		my = ady
	var nx := pos_x[i] + mx
	var ny := pos_y[i] + my
	if not _move_blocked(nx, ny):
		dir_x[i] = mx / step if step > 0.0001 else 0.0
		dir_y[i] = my / step if step > 0.0001 else 0.0
		_move(i, mx, my)
		return true
	return _move_cardinal_toward(i, tx, ty, step)


func _move_cardinal_toward(i: int, tx: float, ty: float, step: float) -> bool:
	# One axis per frame — diagonals wedge thronglets into tree/rock corners.
	var adx := tx - pos_x[i]
	var ady := ty - pos_y[i]
	var sx := 0.0 if absf(adx) <= 0.5 else signf(adx)
	var sy := 0.0 if absf(ady) <= 0.5 else signf(ady)
	var tries: Array[Vector2] = []
	if absf(adx) >= absf(ady):
		if sx != 0.0:
			tries.append(Vector2(sx * step, 0.0))
		if sy != 0.0:
			tries.append(Vector2(0.0, sy * step))
	else:
		if sy != 0.0:
			tries.append(Vector2(0.0, sy * step))
		if sx != 0.0:
			tries.append(Vector2(sx * step, 0.0))
	for delta in tries:
		var nx := pos_x[i] + delta.x
		var ny := pos_y[i] + delta.y
		if _move_blocked(nx, ny):
			continue
		dir_x[i] = 0.0 if is_zero_approx(delta.x) else signf(delta.x)
		dir_y[i] = 0.0 if is_zero_approx(delta.y) else signf(delta.y)
		_move(i, delta.x, delta.y)
		return true
	return false


func _path_hop(fx: float, fy: float, tx: float, ty: float) -> Vector2:
	# Next waypoint: open-field goal, else one BFS cell (never a far L-corner —
	# steering at a distant corner chords through tree walls / enclosure gaps).
	var adx := absf(tx - fx)
	var ady := absf(ty - fy)
	if adx < 1.0 and ady < 1.0:
		return Vector2(tx, ty)
	var h_then_v := _axis_clear(fx, fy, tx, fy) and (ady < 1.0 or _axis_clear(tx, fy, tx, ty))
	var v_then_h := _axis_clear(fx, fy, fx, ty) and (adx < 1.0 or _axis_clear(fx, ty, tx, ty))
	if h_then_v and v_then_h and _axis_clear(fx, fy, tx, ty):
		return Vector2(tx, ty)
	var next_cell := _bfs_next_cell(_cell_vec(fx, fy), _cell_vec(tx, ty))
	if next_cell.x <= -999000:
		return Vector2.ZERO
	return _cell_world(next_cell)


func _axis_clear(ax: float, ay: float, bx: float, by: float) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.5:
		return not _move_blocked(bx, by)
	var steps := maxi(1, int(ceil(dist / 4.0)))
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		if _move_blocked(ax + dx * t, ay + dy * t):
			return false
	return true


func _bfs_next_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	var miss := Vector2i(-999999, -999999)
	if start == goal:
		return start
	var goal_at := _cell_world(goal)
	var goal_open := not _move_blocked(goal_at.x, goal_at.y)
	var q: Array[Vector2i] = [start]
	var came := {}
	came[start] = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited := 0
	var best := start
	var best_d := start.distance_squared_to(goal)
	while not q.is_empty() and visited < PATH_BFS_MAX:
		var cur: Vector2i = q.pop_front()
		visited += 1
		var d0 := cur.distance_squared_to(goal)
		if d0 < best_d:
			best_d = d0
			best = cur
		if goal_open and cur == goal:
			best = goal
			break
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came.has(nxt):
				continue
			var at := _cell_world(nxt)
			if _move_blocked(at.x, at.y):
				continue
			came[nxt] = cur
			q.append(nxt)
	var end: Vector2i = goal if (goal_open and came.has(goal)) else best
	if end == start or not came.has(end):
		return miss
	var step: Vector2i = end
	while came.has(step) and came[step] != start:
		step = came[step]
	if not came.has(step) or came[step] != start:
		return miss
	return step


func _bfs_path_cells(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal:
		out.append(start)
		return out
	var goal_at := _cell_world(goal)
	var goal_open := not _move_blocked(goal_at.x, goal_at.y)
	var q: Array[Vector2i] = [start]
	var came := {}
	came[start] = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited := 0
	var best := start
	var best_d := start.distance_squared_to(goal)
	while not q.is_empty() and visited < PATH_BFS_MAX:
		var cur: Vector2i = q.pop_front()
		visited += 1
		var d0 := cur.distance_squared_to(goal)
		if d0 < best_d:
			best_d = d0
			best = cur
		if goal_open and cur == goal:
			best = goal
			break
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came.has(nxt):
				continue
			var at := _cell_world(nxt)
			if _move_blocked(at.x, at.y):
				continue
			came[nxt] = cur
			q.append(nxt)
	var end: Vector2i = goal if (goal_open and came.has(goal)) else best
	if not came.has(end):
		out.append(start)
		return out
	var stack: Array[Vector2i] = []
	var step: Vector2i = end
	while true:
		stack.append(step)
		if step == start or not came.has(step) or came[step] == step:
			break
		step = came[step]
	var i := stack.size() - 1
	while i >= 0:
		out.append(stack[i])
		i -= 1
	return out


func _convex_corner_at(px: float, py: float, dx: float, dy: float) -> bool:
	var sx := 0.0 if absf(dx) < 0.001 else signf(dx)
	var sy := 0.0 if absf(dy) < 0.001 else signf(dy)
	if sx == 0.0 or sy == 0.0:
		return false
	var probe := 4.0
	var can_x := not _move_blocked(px + sx * probe, py)
	var can_y := not _move_blocked(px, py + sy * probe)
	return can_x and can_y and _move_blocked(px + sx * probe, py + sy * probe)


func _goal_path_blocked(px: float, py: float, dx: float, dy: float, limit: float) -> bool:
	# Scan the approach. A late 4px probe wasted a walk into the corner.
	var span := minf(limit, 40.0)
	if span < 4.0:
		return _convex_corner_at(px, py, dx, dy)
	var clear := 0.0
	var step := 4.0
	while clear + step <= span:
		clear += step
		var x := px + dx * clear
		var y := py + dy * clear
		if _move_blocked(x, y):
			return true
		if _convex_corner_at(x, y, dx, dy):
			return true
	return false


func _move(i: int, dx: float, dy: float) -> void:
	var ox := pos_x[i]
	var oy := pos_y[i]
	var moved := false
	var can_x := not _move_blocked(ox + dx, oy)
	var can_y := not _move_blocked(ox, oy + dy)
	if can_x and can_y and not _move_blocked(ox + dx, oy + dy):
		pos_x[i] = ox + dx
		pos_y[i] = oy + dy
		_wear_ground(i)
		_hash_relocate(i)
		return
	# Convex corner: commit to one axis. Do not unstick — that bounces them
	# backward and _walk then charges the same corner again.
	if can_x and can_y:
		var use_x := absf(dx) >= absf(dy)
		if absf(dir_x[i]) > 0.7 and absf(dir_y[i]) < 0.3:
			use_x = can_x
		elif absf(dir_y[i]) > 0.7 and absf(dir_x[i]) < 0.3:
			use_x = false
		else:
			var sx := 0.0 if absf(dx) < 0.0001 else signf(dx)
			var sy := 0.0 if absf(dy) < 0.0001 else signf(dy)
			var run_x := 0.0 if sx == 0.0 else _clear_run_at(ox, oy, sx, 0.0)
			var run_y := 0.0 if sy == 0.0 else _clear_run_at(ox, oy, 0.0, sy)
			if run_x > run_y:
				use_x = true
			elif run_y > run_x:
				use_x = false
		if use_x and can_x:
			pos_x[i] = ox + dx
			dir_x[i] = 0.0 if absf(dx) < 0.0001 else signf(dx)
			dir_y[i] = 0.0
			moved = true
		elif can_y:
			pos_y[i] = oy + dy
			dir_x[i] = 0.0
			dir_y[i] = 0.0 if absf(dy) < 0.0001 else signf(dy)
			moved = true
		if moved:
			_hold_avoid(i, 0.95)
		else:
			_unstick(i)
			_hold_avoid(i, 1.1)
		if pos_x[i] != ox or pos_y[i] != oy:
			_wear_ground(i)
			_hash_relocate(i)
		return
	if can_x:
		pos_x[i] = ox + dx
		moved = true
	if not _move_blocked(pos_x[i], oy + dy):
		pos_y[i] = oy + dy
		moved = true
	elif can_y and not can_x:
		pos_y[i] = oy + dy
		moved = true
	if not moved:
		_unstick(i)
		_hold_avoid(i, 1.1)
	elif _corner_trap(i):
		_unstick(i)
		_hold_avoid(i, 1.1)
	if pos_x[i] != ox or pos_y[i] != oy:
		_wear_ground(i)
		_hash_relocate(i)


func _wear_ground(i: int) -> void:
	var cell := _cell_vec(pos_x[i], pos_y[i])
	var key := "%d,%d" % [cell.x, cell.y]
	if str(wear_from.get(i, "")) == key:
		return
	wear_from[i] = key
	if _tile_at(pos_x[i], pos_y[i]) != Catalog.TILE_GRASS:
		return
	var n := int(wear.get(key, 0)) + 1
	if n > WEAR_NEED:
		return
	wear[key] = n
	if n == WEAR_NEED:
		_mark_path(cell)


func path_at(cx: int, cy: int) -> bool:
	return int(wear.get("%d,%d" % [cx, cy], 0)) >= WEAR_NEED


func _mark_path(cell: Vector2i) -> void:
	var spots: Array[Vector2i] = [
		cell,
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]
	for spot in spots:
		_mark_dirty(_ck(_floor_div(spot.x, Catalog.CHUNK), _floor_div(spot.y, Catalog.CHUNK)))


func wear_stage(cx: int, cy: int) -> int:
	var n := int(wear.get("%d,%d" % [cx, cy], 0))
	var per := maxi(1, WEAR_NEED / (WEAR_STEPS + 1))
	return mini(WEAR_STEPS, n / per)


func _thought_known(key: String) -> bool:
	return bool(unlocks.get(key, false))


func _thought_icon(i: int) -> int:
	# Only desire things the colony has already discovered.
	var doing := int(act[i])
	if not fires.is_empty():
		for feat in fires:
			if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
				continue
			if _dist_i(i, float(feat.x), float(feat.y)) < 48.0:
				return Catalog.ICON_FIRE
	# Penned check is expensive (8 blocked probes); sample infrequently.
	_ensure_agent_timers(i)
	if posmod(frame_i + i, 45) == 0:
		penned_flag[i] = 1 if _is_penned(i) else 0
	if penned_flag[i] != 0:
		return Catalog.ICON_ROCK
	var tile := _tile_at(pos_x[i], pos_y[i])
	if tile == Catalog.TILE_GOO:
		if _thought_known("mop"):
			return Catalog.ICON_MOP
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	# Hidden indoors: no thought bubble while a guest of a visit building.
	if indoors(i):
		return -1
	if fed[i] < Catalog.NEED_HUNGRY and _thought_known("apple"):
		return Catalog.ICON_APPLE
	var in_tub := link_tub[i] >= 0
	var on_ride := link_ride[i] >= 0
	if clean[i] < Catalog.NEED_SEEK and not in_tub:
		if _thought_known("bathtub"):
			return Catalog.ICON_TUB
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	if amused[i] < Catalog.NEED_FUN and not on_ride:
		if _thought_known("roundabout"):
			return Catalog.ICON_ROUND
		if _thought_known("ball"):
			return Catalog.ICON_BALL
	if doing == ACT_EAT and _thought_known("apple"):
		return Catalog.ICON_APPLE
	if doing == ACT_BATH and _thought_known("bathtub") and not in_tub:
		return Catalog.ICON_TUB
	if doing == ACT_WASH and _thought_known("sponge"):
		return Catalog.ICON_SPONGE
	if doing == ACT_PLAY:
		if _thought_known("roundabout") and not on_ride:
			return Catalog.ICON_ROUND
		if _thought_known("ball"):
			return Catalog.ICON_BALL
	if doing == ACT_WORK and (_thought_known("mine") or _thought_known("pickaxe")):
		return Catalog.ICON_ORE
	if mito_t[i] > 0.0 or mito_charge[i] > MITOSIS_CHARGE * 0.7:
		return Catalog.ICON_EGG
	if fed[i] >= 85.0 and amused[i] >= 85.0 and clean[i] >= 85.0 and _thought_known("flower"):
		return Catalog.ICON_FLOWER
	return -1


func _is_penned(i: int) -> bool:
	var blocked_n := 0
	for d in [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
	]:
		if _move_blocked(pos_x[i] + d.x * 14.0, pos_y[i] + d.y * 14.0):
			blocked_n += 1
	return blocked_n >= 6


func _maybe_bark(i: int) -> void:
	if barks.size() >= 2:
		bark_cool[i] = Catalog.BARK_COOL
		return
	if indoors(i):
		bark_cool[i] = Catalog.BARK_COOL
		return
	if view_rect.size != Vector2.ZERO and not view_rect.has_point(Vector2(pos_x[i], pos_y[i])):
		bark_cool[i] = Catalog.BARK_COOL * 0.5
		return
	for bark in barks:
		if int(bark.id) == i:
			bark_cool[i] = Catalog.BARK_COOL
			return
	var icon := _thought_icon(i)
	if icon < 0:
		bark_cool[i] = Catalog.BARK_COOL
		return
	bark_cool[i] = Catalog.BARK_COOL
	var urgent := (
		icon == Catalog.ICON_FIRE
		or icon == Catalog.ICON_APPLE
		or icon == Catalog.ICON_MOP
		or icon == Catalog.ICON_ROCK
		or icon == Catalog.ICON_TUB
		or icon == Catalog.ICON_SPONGE
		or icon == Catalog.ICON_BALL
		or icon == Catalog.ICON_ROUND
		or icon == Catalog.ICON_ORE
		or icon == Catalog.ICON_DWELL
		or icon == Catalog.ICON_FANCY
		or icon == Catalog.ICON_THEATRE
	)
	if urgent:
		if randf() > 0.0015:
			return
	elif randf() > 0.0003:
		return
	var sing := ""
	var life := 1.2 if urgent else 1.4
	if bark_can_sing(i) and not ThrongClips.BARK_SING.is_empty():
		sing = str(ThrongClips.BARK_SING[randi() % ThrongClips.BARK_SING.size()])
		# Hold still for exactly one playthrough of the picked Sing clip @ 8fps.
		var frames_n := maxi(ThrongClips.frame_count(sing), 1)
		life = float(frames_n) / 8.0
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		if i < seek_t.size():
			seek_t[i] = 0.0
	barks.append({
		"id": i,
		"icon": icon,
		"t": life,
		"life": life,
		"x": pos_x[i],
		"y": pos_y[i],
		"sing": sing,
	})


func bark_of(i: int) -> Dictionary:
	for bark in barks:
		if int(bark.get("id", -1)) == i:
			return bark
	return {}


func bark_sing_of(i: int) -> String:
	return str(bark_of(i).get("sing", ""))


func bark_can_sing(i: int) -> bool:
	# Sing B–E only when free enough for a thought bubble (not bath/theatre/carry/…).
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	if held_kind == "thronglet" and held_ref == i:
		return false
	if mito_t[i] > 0.0 or mito_charge[i] > 0.0:
		return false
	if carry[i] != Catalog.CARRY_NONE:
		return false
	if indoors(i):
		return false
	if near_fire(i):
		return false
	if i < penned_flag.size() and penned_flag[i] != 0:
		return false
	if i < cheer_t.size() and cheer_t[i] > 0.0:
		return false
	if i < peer_t.size() and peer_t[i] > 0.0:
		return false
	if i < drop_t.size() and drop_t[i] > 0.0:
		return false
	match int(act[i]):
		ACT_EAT, ACT_BATH, ACT_WASH, ACT_PLAY, ACT_WORK:
			return false
	return true


func _tick_voice(delta: float) -> void:
	voice_wait = maxf(0.0, voice_wait - delta)
	if voice_wait > 0.0 or living <= 0 or frozen:
		return
	var upset := -1
	var sing := -1
	var idle := -1
	var fast := 0
	var n := living_ids.size()
	# Sample the living list — never scan slot_count (can be 120k).
	var step := maxi(1, n / 64)
	var start := posmod(frame_i, step)
	for k in range(start, n, step):
		var i := int(living_ids[k])
		if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
			continue
		if fed[i] < Catalog.NEED_HUNGRY or clean[i] < 20.0:
			upset = i
		elif int(act[i]) == ACT_PLAY:
			sing = i
		elif absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
			idle = i
		if absf(dir_x[i]) + absf(dir_y[i]) > 0.85:
			fast += 1
	voice_wait = randf_range(12.0, 20.0)
	if upset >= 0:
		sfx_queue.append("voice_upset")
	elif sing >= 0:
		sfx_queue.append("voice_sing")
	elif idle >= 0 and randf() < 0.2:
		sfx_queue.append("voice_prrr")
	if fast > 10 and randf() < 0.35:
		sfx_queue.append("speed")


func _tick_barks(delta: float, age: bool = true) -> void:
	var kept: Array = []
	for bark in barks:
		if age:
			bark.t = float(bark.t) - delta
		var i := int(bark.id)
		if float(bark.t) <= 0.0 or i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
			continue
		if indoors(i):
			continue
		bark.x = pos_x[i]
		bark.y = pos_y[i]
		kept.append(bark)
	barks = kept


func clear_bark(id: int) -> void:
	if barks.is_empty():
		return
	var kept: Array = []
	for bark in barks:
		if int(bark.get("id", -1)) != id:
			kept.append(bark)
	barks = kept


func seat_of(i: int) -> Dictionary:
	if i < 0 or i >= link_tub.size():
		return {}
	var bid := link_tub[i]
	if bid < 0:
		return {}
	var b: Dictionary = building_by_id.get(bid, {})
	if b.is_empty() or b.dead or int(b.kind) != Catalog.BLD_TUB or int(b.get("occupant", -1)) != i:
		link_tub[i] = -1
		return {}
	return b


func indoors(i: int) -> bool:
	# Guest of a visit building (home / theatre / mine). Roundabout and tub keep
	# their on-world animations; flower/statue auras never register guests.
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	var visit := _guest_building(i)
	if visit.is_empty():
		return false
	return not _visit_rule(int(visit.kind)).is_empty()


func ride_of(i: int) -> Dictionary:
	if i < 0 or i >= slot_count or int(act[i]) != ACT_PLAY:
		return {}
	return _ride_building(i)


func has_ball(i: int) -> bool:
	if i < 0 or i >= link_ball.size() or int(act[i]) != ACT_PLAY:
		return false
	var iid := link_ball[i]
	if iid < 0:
		return false
	var it: Dictionary = item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_BALL or int(it.get("claimer", -1)) != i:
		link_ball[i] = -1
		return false
	return true


func ball_of(i: int) -> Dictionary:
	if i < 0 or i >= slot_count or int(act[i]) != ACT_PLAY:
		return {}
	var iid := link_ball[i] if i < link_ball.size() else -1
	if iid >= 0:
		var linked: Dictionary = item_by_id.get(iid, {})
		if not linked.is_empty() and not linked.dead and int(linked.kind) == Catalog.ITEM_BALL and int(linked.get("claimer", -1)) == i:
			return linked
		link_ball[i] = -1
	for it in items:
		if it.dead or int(it.kind) != Catalog.ITEM_BALL:
			continue
		if int(it.get("claimer", -1)) == i:
			if i < link_ball.size():
				link_ball[i] = int(it.id)
			return it
	return {}


func _visit_rule(kind: int) -> Dictionary:
	if kind == Catalog.BLD_DWELL:
		return {"cap": 4, "stay": 18.0, "cool": 14.0, "fed": 8.0, "clean": 8.0, "fun": 0.0}
	if kind == Catalog.BLD_FANCY:
		return {"cap": 10, "stay": 24.0, "cool": 12.0, "fed": 10.0, "clean": 12.0, "fun": 0.0}
	if kind == Catalog.BLD_THEATRE:
		return {"cap": 18, "stay": 30.0, "cool": 10.0, "fed": 0.0, "clean": 0.0, "fun": 9.0}
	if kind == Catalog.BLD_MINE:
		return {"cap": 2, "stay": MINE_DIG_TIME, "cool": 0.6, "fed": 0.0, "clean": 0.0, "fun": 0.0}
	if kind == Catalog.BLD_MINE2:
		return {"cap": 6, "stay": MINE_DIG_TIME * 0.7, "cool": 0.4, "fed": 0.0, "clean": 0.0, "fun": 0.0}
	return {}


func _is_show(kind: int) -> bool:
	return kind == Catalog.BLD_THEATRE


func _is_mine_kind(kind: int) -> bool:
	return kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2


func _mine_stock_cap(b: Dictionary) -> int:
	return MINE_STOCK_CAP2 if int(b.kind) == Catalog.BLD_MINE2 else MINE_STOCK_CAP


func _ore_tier(kind: int) -> int:
	if kind == Catalog.FEAT_NODE or kind == Catalog.FEAT_MNODE:
		return 1
	if kind == Catalog.FEAT_SUPER:
		return 2
	if kind == Catalog.FEAT_ORE_MEGA:
		return 3
	if kind == Catalog.FEAT_ORE_SUPER:
		return 4
	if kind == Catalog.FEAT_ORE_ULTRA:
		return 5
	return 0


func _is_rock(kind: int) -> bool:
	return kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK


func _stay_for(kind: int, base: float) -> float:
	if _is_show(kind):
		return base
	var stay := base
	var home := kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY
	if bool(mutations.get("care", false)):
		stay *= 1.35
	if home and bool(mutations.get("short_rest", false)):
		stay *= 0.55
	elif bool(mutations.get("hard", false)):
		stay *= 0.6
	return stay


func _is_guest(b: Dictionary, i: int) -> bool:
	for guest in b.get("guests", []):
		if int(guest.id) == i:
			return true
	return false


func _live_guests(b: Dictionary) -> int:
	var n := 0
	for guest in b.get("guests", []):
		var id := int(guest.id)
		if id >= 0 and id < slot_count and state[id] == Catalog.ST_LIVING:
			n += 1
	return n


func _banned(b: Dictionary, i: int) -> bool:
	for away in b.get("away", []):
		if int(away.id) == i and float(away.t) > 0.0:
			return true
	return false


func _can_enter(b: Dictionary, i: int) -> bool:
	if building_is_polluted(b):
		return false
	var rule := _visit_rule(int(b.kind))
	if rule.is_empty():
		return true
	if _is_guest(b, i):
		return true
	if _banned(b, i):
		return false
	return _live_guests(b) < int(rule.cap)


func _guest_building(i: int) -> Dictionary:
	if i < 0 or i >= link_guest.size():
		return {}
	var bid := link_guest[i]
	if bid >= 0:
		var linked: Dictionary = building_by_id.get(bid, {})
		if not linked.is_empty() and not linked.dead and _is_guest(linked, i):
			return linked
		link_guest[i] = -1
	for b in buildings:
		if b.dead:
			continue
		if _is_guest(b, i):
			link_guest[i] = int(b.id)
			return b
	return {}


func _push_out(b: Dictionary, i: int) -> void:
	var ang := randf() * TAU
	var nx := pos_x[i] + cos(ang) * 22.0
	var ny := pos_y[i] + sin(ang) * 22.0
	if not _move_blocked(nx, ny):
		_set_agent_pos(i, nx, ny)
	if int(b.kind) == Catalog.BLD_TUB:
		sfx_queue.append("tub_out")


func _drop_guest(b: Dictionary, i: int) -> void:
	var guests: Array = []
	for guest in b.get("guests", []):
		if int(guest.id) != i:
			guests.append(guest)
	b.guests = guests
	if i >= 0 and i < link_guest.size() and link_guest[i] == int(b.id):
		link_guest[i] = -1
	var away: Array = b.get("away", [])
	var rule := _visit_rule(int(b.kind))
	away.append({"id": i, "t": float(rule.get("cool", 8.0))})
	b.away = away
	_push_out(b, i)


func _enter_visit(i: int, b: Dictionary) -> bool:
	if b.is_empty() or _is_guest(b, i) or not _can_enter(b, i):
		return false
	var rule := _visit_rule(int(b.kind))
	if rule.is_empty():
		return false
	var kind := int(b.kind)
	# Diggers reserve one stock unit for the whole stay.
	if _is_mine_kind(kind) and int(b.get("buffer", 0)) <= _live_guests(b):
		return false
	var guests: Array = b.get("guests", [])
	guests.append({"id": i, "left": _stay_for(kind, float(rule.stay))})
	b.guests = guests
	if i >= 0 and i < link_guest.size():
		link_guest[i] = int(b.id)
	if kind == Catalog.BLD_TUB:
		sfx_queue.append("tub_in")
		sfx_queue.append("splash")
	return true


func _mine_finish_dig(b: Dictionary, id: int) -> void:
	if id < 0 or id >= slot_count or state[id] != Catalog.ST_LIVING:
		return
	if carry[id] != Catalog.CARRY_NONE:
		return
	if int(b.get("buffer", 0)) <= 0 or not _has_factory():
		return
	b.buffer = maxi(0, int(b.get("buffer", 0)) - 1)
	_set_carry(id, Catalog.CARRY_ORE, _mine_value(b))
	_release_mine_job(id)


func _tick_visit(b: Dictionary, dt: float) -> void:
	var rule := _visit_rule(int(b.kind))
	var kind := int(b.kind)
	var mine := _is_mine_kind(kind)
	var away: Array = []
	for ban in b.get("away", []):
		ban.t = float(ban.t) - dt
		if float(ban.t) > 0.0:
			away.append(ban)
	var kept: Array = []
	for guest in b.get("guests", []):
		var id := int(guest.id)
		if id < 0 or id >= slot_count or state[id] != Catalog.ST_LIVING:
			if id >= 0 and id < link_guest.size() and link_guest[id] == int(b.id):
				link_guest[id] = -1
			continue
		guest.left = float(guest.left) - dt
		if float(guest.left) <= 0.0:
			if id < link_guest.size() and link_guest[id] == int(b.id):
				link_guest[id] = -1
			if mine:
				_mine_finish_dig(b, id)
			_push_out(b, id)
			away.append({"id": id, "t": float(rule.cool)})
			continue
		if float(rule.fed) > 0.0:
			fed[id] = minf(100.0, fed[id] + float(rule.fed) * dt)
		if float(rule.clean) > 0.0:
			clean[id] = minf(100.0, clean[id] + float(rule.clean) * dt)
		if float(rule.fun) > 0.0:
			amused[id] = minf(100.0, amused[id] + float(rule.fun) * dt)
			buff_t[id] = maxf(buff_t[id], 1.2)
		kept.append(guest)
	b.guests = kept
	b.away = away
	if not mine:
		b.active = not kept.is_empty()


func _apple_land_spot(bx: float, by: float) -> Vector2:
	for _n in 8:
		var ang := randf() * TAU
		var rad := randf_range(Catalog.APPLE_LAND_MIN, Catalog.APPLE_LAND_MAX)
		var px := bx + cos(ang) * rad
		var py := by + sin(ang) * rad
		var at := Catalog.snap_world(px, py)
		if not _blocked(at.x, at.y) and _tile_holds(at.x, at.y):
			return at
	var fallback := Catalog.snap_world(bx, by + Catalog.APPLE_LAND_MIN)
	if not _blocked(fallback.x, fallback.y) and _tile_holds(fallback.x, fallback.y):
		return fallback
	return Catalog.snap_world(bx, by)


func _tick_apple_tree(b: Dictionary, dt: float) -> void:
	var fruits: Array = b.get("fruits", [])
	b.fruits = fruits
	var used := {}
	for fruit in fruits:
		used[int(fruit.slot)] = true
	var slot := 0
	while fruits.size() < 3 and slot < 3:
		if not used.has(slot):
			fruits.append({"slot": slot, "s": 0.15})
			used[slot] = true
		slot += 1
	for fruit in fruits:
		if float(fruit.s) < 1.0:
			fruit.s = minf(1.0, float(fruit.s) + dt * 0.28)
	b.timer = float(b.timer) - dt
	if float(b.timer) > 0.0:
		return
	var ripe := -1
	for n in fruits.size():
		if float(fruits[n].s) >= 1.0:
			ripe = n
			break
	if ripe < 0:
		return
	b.timer = 2.2
	var on_ground := 0
	for it in items:
		if it.dead or int(it.kind) != Catalog.ITEM_APPLE or float(it.get("air", 0.0)) > 0.0:
			continue
		if _dist_point(float(b.x), float(b.y), float(it.x), float(it.y)) < 36.0:
			on_ground += 1
	if on_ground >= 4:
		b.timer = 1.0
		return
	var fruit: Dictionary = fruits[ripe]
	var fruit_slot := clampi(int(fruit.slot), 0, 2)
	fruits.remove_at(ripe)
	var spot: Vector2 = Catalog.APPLE_SPOTS[fruit_slot]
	var lift: float = Catalog.APPLE_LIFTS[fruit_slot]
	var start := Vector2(float(b.x) + spot.x, float(b.y) + spot.y)
	var dest := _apple_land_spot(float(b.x), float(b.y))
	var fall_t := sqrt(2.0 * maxf(lift, 1.0) / item_physics.ITEM_GRAVITY)
	var dropped := _add_item(Catalog.ITEM_APPLE, start.x, start.y, 1)
	item_physics.launch_item(dropped, lift, 0.0, (dest.x - start.x) / fall_t, (dest.y - start.y) / fall_t)


func structure_full(b: Dictionary) -> bool:
	var kind := int(b.kind)
	if kind == Catalog.BLD_TUB:
		var occ := int(b.get("occupant", -1))
		return occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
		var rule := _visit_rule(kind)
		return _live_guests(b) >= int(rule.cap)
	if kind == Catalog.BLD_ROUND:
		return _taken_ride_slots(b).size() >= _ride_slot_count()
	return false


func _corner_trap(i: int) -> bool:
	# Truly boxed in — a 1-tile corridor still has 2+ opens and must stay walkable.
	var open := 0
	for n in 8:
		var a := float(n) * TAU * 0.125
		if not _move_blocked(pos_x[i] + cos(a) * 8.0, pos_y[i] + sin(a) * 8.0):
			open += 1
	return open <= 1


func _move_failed_escape(i: int) -> bool:
	# Stuck if every short step fails — used after a move into a true trap.
	for n in 8:
		var a := float(n) * TAU * 0.125
		if not _move_blocked(pos_x[i] + cos(a) * 4.0, pos_y[i] + sin(a) * 4.0):
			return false
	return true


func _unstick(i: int) -> void:
	var prefer := _shore_push(i)
	if prefer == Vector2.ZERO:
		prefer = _inland_dir(i)
	var step := _open_dir(i, prefer)
	if step == Vector2.ZERO:
		step = _open_dir(i, _inland_dir(i))
	var back := Vector2(-dir_x[i], -dir_y[i])
	if back.length_squared() > 0.2:
		back = back.normalized()
	else:
		back = Vector2.ZERO
	var candidates: Array[Vector2] = []
	if step != Vector2.ZERO:
		candidates.append(step)
	if prefer != Vector2.ZERO:
		candidates.append(prefer)
	for n in 16:
		var a := float(n) * (TAU / 16.0)
		candidates.append(Vector2(cos(a), sin(a)))
	var try_dist: Array[float] = [48.0, 40.0, 32.0, 24.0, 20.0, 16.0, 12.0, 10.0, 8.0, 6.0, 4.0]
	for dist in try_dist:
		var best := Vector2.ZERO
		var best_run := -1.0
		for cand in candidates:
			var nx: float = pos_x[i] + cand.x * dist
			var ny: float = pos_y[i] + cand.y * dist
			if _move_blocked(nx, ny):
				continue
			# Destination-only checks teleported through tree walls (enclosure escape).
			if not _axis_clear(pos_x[i], pos_y[i], nx, ny):
				continue
			var run := _clear_run_at(nx, ny, cand.x, cand.y)
			var score := run + cand.dot(prefer) * 6.0 - cand.dot(back) * 10.0
			if score > best_run:
				best_run = score
				best = cand
		if best != Vector2.ZERO:
			pos_x[i] = pos_x[i] + best.x * dist
			pos_y[i] = pos_y[i] + best.y * dist
			dir_x[i] = best.x
			dir_y[i] = best.y
			wander_t[i] = randf_range(0.7, 1.6)
			if i < seek_t.size():
				seek_t[i] = 0.0
			_hash_relocate(i)
			return
	for ring in range(1, 9):
		var rad := float(ring) * 8.0
		for n in 16:
			var a := float(n) * (TAU / 16.0)
			var nx2 := pos_x[i] + cos(a) * rad
			var ny2 := pos_y[i] + sin(a) * rad
			if _move_blocked(nx2, ny2):
				continue
			if not _axis_clear(pos_x[i], pos_y[i], nx2, ny2):
				continue
			pos_x[i] = nx2
			pos_y[i] = ny2
			dir_x[i] = cos(a)
			dir_y[i] = sin(a)
			wander_t[i] = randf_range(0.7, 1.6)
			if i < seek_t.size():
				seek_t[i] = 0.0
			_hash_relocate(i)
			return
	wander_t[i] = 0.0


func _clear_run_at(px: float, py: float, dx: float, dy: float) -> float:
	var clear := 0.0
	var step := 8.0
	while clear + step <= 32.0:
		if _move_blocked(px + dx * (clear + step), py + dy * (clear + step)):
			return clear
		clear += step
	return 32.0


func _tick_trees(dt: float) -> void:
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_STUMP:
			continue
		var grow := float(feat.get("grow", Catalog.TREE_REGROW))
		grow -= dt
		if grow > 0.0:
			feat.grow = grow
			continue
		feat.grow = 0.0
		feat.kind = Catalog.FEAT_TREE
		feat.hp = 1
		feat.rooted = true
		feat_mesh_epoch += 1
	if tree_seeds.is_empty():
		return
	var kept: Array = []
	for seed in tree_seeds:
		var left := float(seed.get("t", 0.0)) - dt
		if left > 0.0:
			seed.t = left
			kept.append(seed)
			continue
		_try_plant_tree(float(seed.x), float(seed.y))
	tree_seeds = kept


func _try_plant_tree(x: float, y: float) -> void:
	if _blocked(x, y):
		return
	if not _feature_at(x, y, 6.0).is_empty():
		return
	if not _building_at(x, y, 10.0).is_empty():
		return
	_add_feature(Catalog.FEAT_TREE, x, y, 1, 0, true)


func _tick_egg(it: Dictionary, dt: float) -> void:
	it.shake = maxf(0.0, float(it.get("shake", 0.0)) - dt)
	var air := float(it.get("air", 0.0))
	if air <= 0.0:
		return
	var fall := float(it.get("fall", 0.0)) + 220.0 * dt
	it.fall = fall
	air = maxf(0.0, air - fall * dt)
	it.air = air
	if air <= 0.0:
		it.air = 0.0
		it.fall = 0.0
		notes.append("TOCA EL HUEVO CON LA MANO PARA AYUDAR.")
		sfx_queue.append("egg_land")


func _loot_spot(b: Dictionary) -> Vector2:
	var size := Catalog.footprint_for_building(int(b.kind))
	var south := float(size.y) * float(Catalog.TILE)
	var spot := Vector2(float(b.x), float(b.y) + south)
	if not _blocked(spot.x, spot.y):
		return spot
	return _approach_spot(float(b.x), float(b.y), south + 8.0)


func building_is_polluted(b: Dictionary) -> bool:
	if b.is_empty() or bool(b.get("dead", false)):
		return false
	if not Catalog.building_has_goo(int(b.kind)):
		return false
	for cell in _footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
		if _tile_at_cell(cell) == Catalog.TILE_GOO:
			return true
	return false


func _shut_polluted_building(b: Dictionary) -> void:
	for guest in b.get("guests", []):
		var gid := int(guest.get("id", -1))
		if gid >= 0 and gid < link_guest.size() and link_guest[gid] == int(b.id):
			link_guest[gid] = -1
	b.guests = []
	b.away = []
	b.active = false
	if bool(b.get("incinerate", false)):
		b.incinerate = false
		b.burn = 0.0


func _tick_buildings(dt: float) -> void:
	for b in buildings:
		if b.dead:
			continue
		if bool(b.get("lifted", false)):
			b.active = false
			continue
		var kind := int(b.kind)
		if building_is_polluted(b):
			_shut_polluted_building(b)
			continue
		b.active = false
		if kind == Catalog.BLD_APPLE:
			_tick_apple_tree(b, dt)
		elif kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			var stock_cap := _mine_stock_cap(b)
			var stock := int(b.get("buffer", 0))
			if stock < stock_cap:
				b.timer = float(b.timer) - dt
				if float(b.timer) <= 0.0:
					b.timer = MINE_FILL_TIME
					b.buffer = mini(stock_cap, stock + 1)
			else:
				b.timer = MINE_FILL_TIME
			_tick_visit(b, dt)
			b.active = _live_guests(b) > 0
		elif kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			var cycle := _factory_cycle_time(kind)
			var buffered := int(b.get("buffer", 0))
			if buffered > 0:
				if float(b.timer) > cycle:
					b.timer = cycle
				b.timer = float(b.timer) - dt
				if float(b.timer) <= 0.0:
					_factory_spend(b)
					var _g := FACTORY_GEM_PAY2 if kind == Catalog.BLD_FACTORY2 else FACTORY_GEM_PAY
					gems += _g
					total_gems_earned += _g
					b.active = true
					_pop(float(b.x), float(b.y) - 6.0, Catalog.ICON_GEM)
					if randf() < FACTORY_GOO_CHANCE:
						_spill_goo(float(b.x), float(b.y), 2 if kind == Catalog.BLD_FACTORY2 else 1)
					buffered = int(b.get("buffer", 0))
					b.timer = cycle if buffered > 0 else 0.25
				else:
					b.active = true
			else:
				b.timer = 0.25
			if bool(b.get("incinerate", false)):
				b.active = true
				b.burn = float(b.get("burn", 0.0)) + dt
				if float(b.burn) >= 3.0:
					var corpse := _nearest_corpse(float(b.x), float(b.y), 90.0)
					if corpse >= 0:
						b.burn = 0.0
						_vacate(corpse)
						var _gg := 5 if bool(mutations.get("fuel", false)) else 3
						gems += _gg
						total_gems_earned += _gg
						sfx_queue.append("bones")
		elif kind == Catalog.BLD_TUB:
			var occ := int(b.occupant)
			if occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING and _dist_i(occ, float(b.x), float(b.y)) < 22.0:
				b.active = true
		elif kind == Catalog.BLD_ROUND:
			var spinning := false
			for raw in _rider_list(b):
				var rid := int(raw)
				if rid >= 0 and rid < slot_count and state[rid] == Catalog.ST_LIVING:
					spinning = true
					break
			# Drop seat claims from thronglets who wandered off before mounting.
			var mid := _ride_center_of(b)
			var claims: Variant = b.get("ride_slot", {})
			if claims is Dictionary:
				var keep_claims := {}
				for key in claims.keys():
					var who := int(key)
					if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
						continue
					if _is_rider(b, who) or _dist_i(who, mid.x, mid.y) <= 40.0:
						keep_claims[who] = int(claims[key])
				b.ride_slot = keep_claims
			# Spin only while someone is actually seated. Approachers leave it idle.
			b.active = spinning
			if spinning:
				b.spin = float(b.get("spin", 0.0)) + float(_ride_cfg().get("spin_speed", Catalog.ROUND_SPIN_RATE)) * dt
		elif kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
			_tick_visit(b, dt)


func capacity_info(b: Dictionary) -> Dictionary:
	if b.is_empty() or bool(b.get("dead", false)):
		return {}
	var kind := int(b.kind)
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		return {}
	if _is_mine_kind(kind):
		var cap := _mine_stock_cap(b)
		var n := clampi(int(b.get("buffer", 0)), 0, cap)
		return {"n": n, "cap": cap, "full": n >= cap, "mine": true, "visit": false}
	if kind != Catalog.BLD_DWELL and kind != Catalog.BLD_FANCY and kind != Catalog.BLD_THEATRE:
		return {}
	var rule := _visit_rule(kind)
	if rule.is_empty():
		return {}
	var cap2 := int(rule.cap)
	var n2 := clampi(_live_guests(b), 0, cap2)
	return {"n": n2, "cap": cap2, "full": n2 >= cap2, "mine": false, "visit": true}


func _tick_auras(dt: float) -> void:
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FLOWER:
			_boost(float(b.x), float(b.y), 28.0, 3, 0.0, 0.0, 3.5 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
			_boost(float(b.x), float(b.y), 36.0, 4, 0.0, 0.0, 5.0 * dt, 0.8, ACT_PLAY)
func _boost(x: float, y: float, radius: float, limit: int, fed_r: float, clean_r: float, fun_r: float, buff: float, mark_act: int = 0) -> void:
	var ids := query_radius(x, y, radius)
	var scored: Array = []
	for id in ids:
		if state[int(id)] != Catalog.ST_LIVING:
			continue
		scored.append({"id": int(id), "d": _dist_i(int(id), x, y)})
	scored.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var n := mini(limit, scored.size())
	for k in n:
		var id := int(scored[k].id)
		if fed_r > 0.0:
			fed[id] = minf(100.0, fed[id] + fed_r)
		if clean_r > 0.0:
			clean[id] = minf(100.0, clean[id] + clean_r)
		if fun_r > 0.0:
			amused[id] = minf(100.0, amused[id] + fun_r)
		if buff > 0.0:
			buff_t[id] = maxf(buff_t[id], buff)
		if mark_act > 0:
			act[id] = mark_act
			act_t[id] = maxf(act_t[id], 0.35)


func use_tool(tool: int, x: float, y: float) -> void:
	if frozen:
		return
	if not _tool_open(tool):
		sfx_queue.append("locked")
		return
	if tool == Catalog.TOOL_APPLE:
		_know_count()
		_drop_loose(Catalog.ITEM_APPLE, x, y, 1)
	elif tool == Catalog.TOOL_BALL:
		_know_count()
		_drop_loose(Catalog.ITEM_BALL, x, y, 1)
	elif tool == Catalog.TOOL_SPONGE:
		notes.append("MANTEN LA ESPONJA Y FROTA PARA LAVAR.")
	elif tool == Catalog.TOOL_AXE:
		_tool_axe(x, y)
	elif tool == Catalog.TOOL_HAMMER:
		_tool_hammer(x, y)
	elif tool == Catalog.TOOL_BUG:
		_tool_bug(x, y)
	elif tool == Catalog.TOOL_PICK:
		_tool_pick(x, y)
	elif tool == Catalog.TOOL_SAW:
		_tool_saw(x, y)
	elif tool == Catalog.TOOL_GRAB:
		_grab(x, y)
	elif tool == Catalog.TOOL_MOP:
		_mop(x, y)
	elif tool == Catalog.TOOL_SWARM:
		_tool_swarm(x, y)
	elif tool == Catalog.TOOL_TNT:
		_tool_tnt(x, y)
	elif tool == Catalog.TOOL_NUKE:
		var c := _chunk_at(x, y)
		_confirm("nuke", {"op": "nuke", "cx": c.x, "cy": c.y})


func _drop_loose(kind: int, x: float, y: float, value: int) -> void:
	var at := Vector2(x, y)
	if Catalog.item_snaps_grid(kind):
		at = Catalog.snap_world(x, y)
	var ground := _tile_at(at.x, at.y)
	var physics_drop := kind != Catalog.ITEM_EGG
	# Physics items can be dropped onto water/void and will fall/splash or fall away.
	var terrain_blocked := Catalog.tile_blocks(ground)
	if physics_drop and (ground == Catalog.TILE_WATER or ground == Catalog.TILE_VOID):
		terrain_blocked = false
	var bad_ground := not revealed.has(_ck_of(at.x, at.y)) or terrain_blocked
	if physics_drop:
		bad_ground = bad_ground or ground == Catalog.TILE_FOG
	else:
		bad_ground = bad_ground or ground == Catalog.TILE_WATER or ground == Catalog.TILE_VOID or ground == Catalog.TILE_FOG
	if bad_ground or (not physics_drop and (not _can_drop(at.x, at.y) or item_physics.obstacle_blocked(at.x, at.y))):
		notes.append("AHI NO.")
		sfx_queue.append("error")
		return
	var it := _add_item(kind, at.x, at.y, value)
	item_physics.launch_item(it, item_physics.ITEM_DROP_HEIGHT, 0.0, 0.0, 0.0)
	if kind == Catalog.ITEM_BALL:
		it.life = BALL_LIFE
		it.rest = 0.0
		notes.append("LOS MULTIS JUEGAN SI LES FALTA DIVERSION.")
	sfx_queue.append("ball" if kind == Catalog.ITEM_BALL else "place")


func _tool_axe(x: float, y: float) -> void:
	var feat := _axe_feature_at(x, y)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_TREE:
		var tx := float(feat.x)
		var ty := float(feat.y)
		_chop(feat)
		_splash_kill(tx, ty, 20.0)
		sfx_queue.append("chop")
		return
	if not feat.is_empty() and (int(feat.kind) == Catalog.FEAT_COSMETIC or int(feat.kind) == Catalog.FEAT_COSMETIC_BAD):
		_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_CHOP)
		notes.append("ESTE ARBOL NO DA MADERA.")
		sfx_queue.append("chop")
		return
	if feat.is_empty() and _tile_at(x, y) == Catalog.TILE_MOUNTAIN:
		var at := Catalog.snap_world(x, y)
		if not _add_feature(Catalog.FEAT_MSTUMP, at.x, at.y, 1, 0, true).is_empty():
			_pop(at.x, at.y, Catalog.ICON_FX_CHOP)
			sfx_queue.append("chop")


func _chop(feat: Dictionary) -> void:
	feat.kind = Catalog.FEAT_STUMP
	feat.grow = Catalog.TREE_REGROW
	# Far-view MultiMesh caches sprites by epoch — kind changes must dirty it.
	feat_mesh_epoch += 1
	var wood_it := _add_item(Catalog.ITEM_WOOD, float(feat.x) + 8.0, float(feat.y), 1)
	item_physics.launch_item(wood_it, 6.0, randf_range(85.0, 115.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
	_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_CHOP)
	trees_chopped += 1
	cap_told = false
	_refresh_pop_gates()
	if trees_chopped >= 12:
		_grant("grabber", "DOCE ARBOLES. LA MANO JUNTA LO SUELTO.")


func _tool_hammer(x: float, y: float) -> void:
	# Ore piles near mines: smash a whole patch into energy, not one crystal per click.
	if part_two and _smash_ore_near(x, y) > 0:
		sfx_queue.append("hammer")
		return
	var feat := _feature_at(x, y, 14.0)
	if not feat.is_empty():
		_hammer_feature(feat)
		sfx_queue.append("hammer")
		return
	var b := _building_at(x, y, 16.0)
	if not b.is_empty():
		_remove_building(b)
		sfx_queue.append("hammer")
		return


func _smash_ore_near(x: float, y: float) -> int:
	var gained := 0
	var smashed := 0
	for it in items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
			continue
		if _dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
			continue
		gained += maxi(1, int(it.value))
		it.dead = true
		smashed += 1
		_pop(float(it.x), float(it.y), Catalog.ICON_FX_HAMMER)
	if smashed <= 0:
		return 0
	gems += gained
	total_gems_earned += gained
	if smashed == 1:
		notes.append("EL MINERAL SUELTA ENERGIA.")
	else:
		notes.append("%d MINERAL → +%d ENERGIA." % [smashed, gained])
	return smashed


func _hammer_feature(feat: Dictionary) -> void:
	var kind := int(feat.kind)
	if kind == Catalog.FEAT_MONOLITH:
		notes.append("NO CEDE.")
		return
	if kind == Catalog.FEAT_TREE:
		notes.append("ESO QUIERE EL HACHA.")
		return
	if kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP or kind == Catalog.FEAT_FLOWER or kind == Catalog.FEAT_FIRE or kind == Catalog.FEAT_TOTEM or kind == Catalog.FEAT_CURER or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		if kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
			if kind == Catalog.FEAT_STUMP:
				stumps_cleared += 1
				tree_seeds.append({"x": float(feat.x), "y": float(feat.y), "t": Catalog.TREE_REPLANT})
				_refresh_pop_gates()
			sfx_queue.append("stump")
		elif kind == Catalog.FEAT_FIRE:
			sfx_queue.append("fire_out")
		_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_HAMMER)
		_kill_feature(feat)
		return
	if _ore_tier(kind) > 0:
		notes.append("AHI VA UNA MINA.")
		return
	if _is_rock(kind):
		_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_HAMMER)
		if kind == Catalog.FEAT_ROCK and not part_two:
			sfx_queue.append("rock_break")
			_kill_feature(feat)
			return
		feat.hp = int(feat.hp) - 1
		if int(feat.hp) <= 0:
			sfx_queue.append("rock_break")
		else:
			sfx_queue.append("rock_crack")
		if int(feat.hp) <= 0:
			var ore_n := int(feat.ore)
			if ore_n > 0:
				var ore_it := _add_item(Catalog.ITEM_ORE, float(feat.x), float(feat.y), ore_n if kind == Catalog.FEAT_BIGROCK else maxi(3, ore_n))
				item_physics.launch_item(ore_it, 6.0, randf_range(85.0, 115.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
			_kill_feature(feat)
		return


func _tool_pick(x: float, y: float) -> void:
	# Ore piles: pick can also collect energy (additive with hammer).
	if part_two and _smash_ore_near(x, y) > 0:
		sfx_queue.append("pick")
		return
	var hit := false
	for feat in features:
		if feat.dead:
			continue
		var kind := int(feat.kind)
		if _dist_point(x, y, float(feat.x), float(feat.y)) > Catalog.PICK_RADIUS:
			continue
		if _is_rock(kind):
			_hammer_feature(feat)
			hit = true
			if kind == Catalog.FEAT_ORE_MEGA or kind == Catalog.FEAT_ORE_SUPER or kind == Catalog.FEAT_ORE_ULTRA:
				sfx_queue.append("superore")
		elif kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
			_hammer_feature(feat)
			hit = true
	if not hit and _tile_at(x, y) == Catalog.TILE_MOUNTAIN:
		var at := Catalog.snap_world(x, y)
		if not _add_feature(Catalog.FEAT_MNODE, at.x, at.y, 3, 1, true).is_empty():
			_pop(at.x, at.y, Catalog.ICON_FX_HAMMER)
			hit = true
	if hit:
		sfx_queue.append("pick")


func _tool_saw(x: float, y: float) -> void:
	var hit := false
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.SAW_RADIUS:
			_chop(feat)
			hit = true
	if hit:
		_splash_kill(x, y, Catalog.SAW_RADIUS)
		sfx_queue.append("saw")


func charge_tool_target(tool: int, x: float, y: float) -> Dictionary:
	if tool == Catalog.TOOL_AXE:
		var tree := _axe_feature_at(x, y)
		if tree.is_empty() or int(tree.kind) != Catalog.FEAT_TREE:
			return {}
		return {"key": "feat:%d" % int(tree.id), "x": float(tree.x), "y": float(tree.y), "n": 1}
	if tool == Catalog.TOOL_HAMMER:
		if part_two:
			var ore_n := _count_items_near(Catalog.ITEM_ORE, x, y, Catalog.HAMMER_ORE_RADIUS)
			if ore_n > 0:
				return {
					"key": "ore:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
					"x": x,
					"y": y,
					"n": ore_n,
					"radius": Catalog.HAMMER_ORE_RADIUS,
				}
		var feat := _feature_at(x, y, 14.0)
		if not feat.is_empty() and int(feat.kind) != Catalog.FEAT_TREE and int(feat.kind) != Catalog.FEAT_MONOLITH and _ore_tier(int(feat.kind)) == 0:
			return {"key": "feat:%d" % int(feat.id), "x": float(feat.x), "y": float(feat.y), "n": 1}
		var b := _building_at(x, y, 16.0)
		if not b.is_empty():
			return {"key": "bld:%d" % int(b.id), "x": float(b.x), "y": float(b.y), "n": 1}
		return {}
	if tool == Catalog.TOOL_PICK:
		if part_two:
			var ore_n := _count_items_near(Catalog.ITEM_ORE, x, y, Catalog.HAMMER_ORE_RADIUS)
			if ore_n > 0:
				return {
					"key": "ore:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
					"x": x,
					"y": y,
					"n": ore_n,
					"radius": Catalog.HAMMER_ORE_RADIUS,
				}
		var targets := 0
		for feat in features:
			if feat.dead:
				continue
			var kind := int(feat.kind)
			if _dist_point(x, y, float(feat.x), float(feat.y)) > Catalog.PICK_RADIUS:
				continue
			if _is_rock(kind) or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
				targets += 1
		if targets <= 0:
			return {}
		return {"key": "pick:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": targets, "radius": Catalog.PICK_RADIUS}
	if tool == Catalog.TOOL_SAW:
		var trees := _count_features_near(Catalog.FEAT_TREE, x, y, Catalog.SAW_RADIUS)
		if trees <= 0:
			return {}
		return {"key": "saw:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": trees, "radius": Catalog.SAW_RADIUS}
	if tool == Catalog.TOOL_MOP:
		var dirty := 0
		for id in query_radius(x, y, Catalog.MOP_RADIUS):
			if state[int(id)] == Catalog.ST_LIVING and clean[int(id)] < 100.0:
				dirty += 1
		var goo := _count_goo_near(x, y, Catalog.MOP_RADIUS)
		var n := dirty + goo
		if n <= 0:
			n = 1
		return {
			"key": "mop:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.MOP_RADIUS,
		}
	if tool == Catalog.TOOL_GRAB:
		if has_scoop():
			return {}
		var n := _count_scoopables(x, y, Catalog.GRAB_RADIUS)
		return {
			"key": "grab:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.GRAB_RADIUS,
		}
	if tool == Catalog.TOOL_SWARM:
		var n := query_radius(x, y, Catalog.SWARM_RADIUS).size()
		return {
			"key": "swarm:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.SWARM_RADIUS,
		}
	return {}


func area_tool_hits(tool: int, x: float, y: float) -> Array:
	var hits: Array = []
	if tool == Catalog.TOOL_PICK:
		if part_two:
			for it in items:
				if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
					continue
				if _dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
					continue
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
			if not hits.is_empty():
				return hits
		for feat in features:
			if feat.dead:
				continue
			var kind := int(feat.kind)
			if not (_is_rock(kind) or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP):
				continue
			if _dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.PICK_RADIUS:
				hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
		if hits.is_empty() and _tile_at(x, y) == Catalog.TILE_MOUNTAIN:
			hits.append({"what": "mountain"})
		return hits
	if tool == Catalog.TOOL_SAW:
		for feat in features:
			if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
				continue
			if _dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.SAW_RADIUS:
				hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
		return hits
	if tool == Catalog.TOOL_MOP:
		for id in query_radius(x, y, Catalog.MOP_RADIUS):
			var i := int(id)
			if state[i] == Catalog.ST_LIVING and clean[i] < 100.0:
				hits.append({"what": "throng", "id": i, "x": pos_x[i], "y": pos_y[i]})
		if _count_goo_near(x, y, Catalog.MOP_RADIUS) > 0:
			hits.append({"what": "goo"})
		return hits
	if tool == Catalog.TOOL_SPONGE:
		for id in query_radius(x, y, Catalog.SPONGE_RADIUS):
			var i := int(id)
			if state[i] == Catalog.ST_LIVING and mito_t[i] <= 0.0 and clean[i] < 100.0:
				hits.append({"what": "throng", "id": i, "x": pos_x[i], "y": pos_y[i]})
		return hits
	if tool == Catalog.TOOL_SWARM:
		for id in query_radius(x, y, Catalog.SWARM_RADIUS):
			if state[int(id)] != Catalog.ST_VACANT:
				hits.append({"what": "throng", "id": int(id)})
		return hits
	if tool == Catalog.TOOL_GRAB:
		for it in items:
			if it.dead or it.held:
				continue
			var kind := int(it.kind)
			if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
				continue
			if _dist_point(x, y, float(it.x), float(it.y)) <= Catalog.GRAB_RADIUS:
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
		for i in slot_count:
			if state[i] != Catalog.ST_DEAD:
				continue
			if _dist_i(i, x, y) <= Catalog.GRAB_RADIUS:
				hits.append({"what": "throng", "id": i, "x": pos_x[i], "y": pos_y[i]})
		return hits
	if tool == Catalog.TOOL_AXE:
		var tree := _axe_feature_at(x, y)
		if not tree.is_empty() and int(tree.kind) == Catalog.FEAT_TREE:
			hits.append({"what": "feat", "id": int(tree.id), "x": float(tree.x), "y": float(tree.y)})
		return hits
	if tool == Catalog.TOOL_HAMMER:
		if part_two:
			for it in items:
				if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
					continue
				if _dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
					continue
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
			if not hits.is_empty():
				return hits
		var feat := _feature_at(x, y, 14.0)
		if not feat.is_empty() and int(feat.kind) != Catalog.FEAT_TREE and int(feat.kind) != Catalog.FEAT_MONOLITH and _ore_tier(int(feat.kind)) == 0:
			hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
			return hits
		var b := _building_at(x, y, 16.0)
		if not b.is_empty():
			hits.append({"what": "bld", "id": int(b.id), "x": float(b.x), "y": float(b.y)})
		return hits
	return hits


func _count_goo_near(x: float, y: float, radius: float) -> int:
	var n := 0
	var c0 := _cell_vec(x - radius, y - radius)
	var c1 := _cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx := float(cx * Catalog.TILE + 8)
			var wy := float(cy * Catalog.TILE + 8)
			if _dist_point(x, y, wx, wy) > radius:
				continue
			if _tile_at(wx, wy) == Catalog.TILE_GOO:
				n += 1
	return n


func _count_features_near(kind: int, x: float, y: float, radius: float) -> int:
	var n := 0
	for feat in features:
		if feat.dead or int(feat.kind) != kind:
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= radius:
			n += 1
	return n


func _count_scoopables(x: float, y: float, radius: float) -> int:
	var n := 0
	for it in items:
		if it.dead or it.held:
			continue
		var kind := int(it.kind)
		if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
			continue
		if _dist_point(x, y, float(it.x), float(it.y)) <= radius:
			n += 1
	for i in slot_count:
		if state[i] != Catalog.ST_DEAD:
			continue
		if _dist_i(i, x, y) <= radius:
			n += 1
	return n


func has_scoop() -> bool:
	return not scoop_item_ids.is_empty() or not scoop_dead_ids.is_empty()


func scoop_gather(x: float, y: float) -> int:
	if frozen or has_scoop() or hand_id != -1 or held_kind != "":
		return 0
	var got := 0
	for it in items:
		if it.dead or it.held:
			continue
		var kind := int(it.kind)
		if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
			continue
		if _dist_point(x, y, float(it.x), float(it.y)) > Catalog.GRAB_RADIUS:
			continue
		it.held = true
		scoop_item_ids.append(int(it.id))
		got += 1
	for i in slot_count:
		if state[i] != Catalog.ST_DEAD:
			continue
		if _dist_i(i, x, y) > Catalog.GRAB_RADIUS:
			continue
		scoop_dead_ids.append(i)
		got += 1
	if got > 0:
		scoop_follow(x, y)
		sfx_queue.append("grab")
	return got


func scoop_follow(x: float, y: float) -> void:
	var i := 0
	for raw in scoop_item_ids:
		var it = item_by_id.get(int(raw), {})
		if it.is_empty() or it.dead:
			continue
		var ang := float(i) * 0.85
		var rad := 3.0 + float(i % 3) * 2.0
		it.x = x + cos(ang) * rad
		it.y = y + sin(ang) * rad
		i += 1
	for raw2 in scoop_dead_ids:
		var id := int(raw2)
		if id < 0 or id >= slot_count or state[id] != Catalog.ST_DEAD:
			continue
		var ang2 := float(i) * 0.85
		pos_x[id] = x + cos(ang2) * 4.0
		pos_y[id] = y + sin(ang2) * 4.0
		i += 1


func scoop_drop(x: float, y: float) -> void:
	if not has_scoop():
		return
	for raw in scoop_item_ids:
		var it = item_by_id.get(int(raw), {})
		if it.is_empty() or it.dead:
			continue
		it.held = false
		var dropped := false
		for _try in 8:
			var ox := randf_range(-30.0, 30.0)
			var oy := randf_range(-30.0, 30.0)
			var px := x + ox
			var py := y + oy
			if Catalog.item_snaps_grid(int(it.kind)):
				var snapped := Catalog.snap_world(px, py)
				px = snapped.x
				py = snapped.y
			var s_ground := _tile_at(px, py)
			var scoop_physics := int(it.kind) != Catalog.ITEM_EGG
			var s_bad := s_ground == Catalog.TILE_WATER or s_ground == Catalog.TILE_VOID or s_ground == Catalog.TILE_FOG or Catalog.tile_blocks(s_ground)
			if s_bad or (not scoop_physics and item_physics.obstacle_blocked(px, py)):
				continue
			it.x = px
			it.y = py
			dropped = true
			break
		if not dropped:
			it.x = x + randf_range(-12.0, 12.0)
			it.y = y + randf_range(-12.0, 12.0)
		var sang := randf() * TAU
		var sspd := randf_range(24.0, 58.0)
		item_physics.launch_item(it, randf_range(18.0, 30.0), randf_range(25.0, 65.0), cos(sang) * sspd, sin(sang) * sspd)
	for raw2 in scoop_dead_ids:
		var id := int(raw2)
		if id < 0 or id >= slot_count or state[id] != Catalog.ST_DEAD:
			continue
		var placed := false
		for _try2 in 8:
			var dx := x + randf_range(-30.0, 30.0)
			var dy := y + randf_range(-30.0, 30.0)
			if _blocked(dx, dy):
				continue
			pos_x[id] = dx
			pos_y[id] = dy
			placed = true
			break
		if not placed:
			pos_x[id] = x + randf_range(-10.0, 10.0)
			pos_y[id] = y + randf_range(-10.0, 10.0)
	scoop_item_ids.clear()
	scoop_dead_ids.clear()
	sfx_queue.append("release")



func _tool_bug(x: float, y: float) -> void:
	var id := find_thronglet(x, y, 14.0, false)
	if id < 0:
		return
	_confirm("bug", {"op": "bug", "id": id})


func _tool_swarm(x: float, y: float) -> void:
	_confirm("bug", {"op": "swarm", "x": x, "y": y})


func _tool_tnt(x: float, y: float) -> void:
	var at := Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	var charge := _nearest_item(x, y, Catalog.ITEM_TNT, 14.0)
	if not charge.is_empty():
		_detonate(charge)
		return
	if not _can_drop(x, y) or not _item_spot_free(x, y):
		notes.append("AHI NO.")
		sfx_queue.append("error")
		return
	var tnt_it := _add_item(Catalog.ITEM_TNT, x, y, 1)
	item_physics.launch_item(tnt_it, 18.0, 0.0, 0.0, 0.0)
	notes.append("CARGA COLOCADA. PULSALA PARA DETONARLA.")
	sfx_queue.append("tnt_place")


func _detonate(charge: Dictionary) -> void:
	var x := float(charge.x)
	var y := float(charge.y)
	charge.dead = true
	_pop(x, y, Catalog.ICON_FX_BOOM)
	tnt_used += 1
	for feat in features:
		if feat.dead or int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= 56.0:
			_kill_feature(feat)
	_explode_tiles(x, y, 56.0)
	_splash_kill(x, y, 34.0)
	if tnt_used == 1:
		_ensure_monolith(2)
		notes.append("LA DINAMITA NO BASTA. OTRO MONOLITO APARECE.")
	sfx_queue.append("tnt_arm")
	sfx_queue.append("explode")


func _explode_tiles(x: float, y: float, radius: float) -> void:
	var c0 := _cell_vec(x - radius, y - radius)
	var c1 := _cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx := float(cx * Catalog.TILE + 8)
			var wy := float(cy * Catalog.TILE + 8)
			if _dist_point(x, y, wx, wy) > radius:
				continue
			var tile := _tile_at(wx, wy)
			if tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_GOO:
				_set_world_cell(cx, cy, Catalog.TILE_DIRT, true)


func _grab(x: float, y: float) -> void:
	scoop_gather(x, y)


func _mop(x: float, y: float) -> void:
	var radius := Catalog.MOP_RADIUS
	var c0 := _cell_vec(x - radius, y - radius)
	var c1 := _cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx := float(cx * Catalog.TILE + 8)
			var wy := float(cy * Catalog.TILE + 8)
			if _dist_point(x, y, wx, wy) > radius:
				continue
			if _tile_at(wx, wy) == Catalog.TILE_GOO:
				var base := _base_at(wx, wy)
				if base == Catalog.TILE_GOO or base == Catalog.TILE_MOUNTAIN:
					base = Catalog.TILE_DIRT
				_set_world_cell(cx, cy, base, false)
	goo_count = _count_goo()
	var ids := query_radius(x, y, radius)
	for id in ids:
		var tid := int(id)
		if state[tid] == Catalog.ST_LIVING and mito_t[tid] <= 0.0:
			var was_dirty := clean[tid] < 100.0
			clean[tid] = 100.0
			if was_dirty:
				_finish_wash(tid)  # mop has no hold — sparkle immediately
	sfx_queue.append("mop")


func scrub(x: float, y: float, stroke: float, rubbing: bool = false) -> void:
	if frozen:
		return
	var ids := query_radius(x, y, Catalog.SPONGE_RADIUS)
	if ids.is_empty():
		# Left every thronglet — drop wash pose; pending sparkles wait for release.
		if sponge_id >= 0:
			_clear_wash_pose(sponge_id)
			sponge_id = -1
		sponge_hold = 0.0
		return
	sponge_hold = 0.55
	var scrubbing := rubbing or stroke >= SCRUB_STROKE_MIN
	var target := _scrub_pick_target(ids)
	if target < 0:
		if sponge_id >= 0:
			_clear_wash_pose(sponge_id)
			sponge_id = -1
		return
	# Only the thronglet under the sponge shows suds; leave prior targets.
	if sponge_id >= 0 and sponge_id != target:
		_clear_wash_pose(sponge_id)
	sponge_id = target
	act[target] = ACT_WASH
	dir_x[target] = 0.0
	dir_y[target] = 0.0
	if not scrubbing:
		act_t[target] = maxf(act_t[target], 0.35)
		return
	_know_count()
	var gain := minf(stroke, 6.0) * 1.25
	if clean[target] < 100.0:
		clean[target] = minf(100.0, clean[target] + gain)
		if clean[target] >= 100.0:
			_queue_wash_fx(target)
	act_t[target] = 0.85
	if int(frame_i) % 3 == 0:
		sfx_queue.append("scrub")


func _scrub_pick_target(ids: Array) -> int:
	# Prefer current sponge_id if still in range; else nearest living thronglet.
	for raw in ids:
		var id := int(raw)
		if id == sponge_id and state[id] == Catalog.ST_LIVING and mito_t[id] <= 0.0:
			return id
	for raw2 in ids:
		var id2 := int(raw2)
		if state[id2] != Catalog.ST_LIVING or mito_t[id2] > 0.0:
			continue
		return id2
	return -1


func _wash_fx_queued(id: int) -> bool:
	for pending in wash_fx_pending:
		if int(pending) == id:
			return true
	return false


func _queue_wash_fx(id: int) -> void:
	_ensure_agent_timers(id)
	dir_x[id] = 0.0
	dir_y[id] = 0.0
	if _wash_fx_queued(id):
		return
	wash_fx_pending.append(id)


func sponge_release() -> void:
	# End scrub pose; sparkles for every thronglet cleaned during this hold.
	var pending: Array = wash_fx_pending.duplicate()
	wash_fx_pending.clear()
	if sponge_id >= 0:
		_clear_wash_pose(sponge_id)
		sponge_id = -1
	sponge_hold = 0.0
	for raw in pending:
		_finish_wash(int(raw))


func _finish_wash(id: int) -> void:
	_clear_wash_pose(id)
	if sponge_id == id:
		sponge_id = -1
		sponge_hold = 0.0
	_ensure_agent_timers(id)
	_pop_wash_sparkle(id)
	cheer_t[id] = WASH_FX_LIFE
	dir_x[id] = 0.0
	dir_y[id] = 0.0


func _pop_wash_sparkle(id: int) -> void:
	if id < 0 or id >= slot_count:
		return
	for pop in pops:
		if str(pop.get("kind", "")) == "wash" and int(pop.get("throng_id", -1)) == id:
			return
	_pop(pos_x[id], pos_y[id], AssetFrames.CLEAN, 1.0, id, WASH_FX_LIFE, "wash")


func _clear_wash_pose(id: int) -> void:
	if id < 0 or id >= slot_count:
		return
	shake_t[id] = 0.0
	if act[id] == ACT_WASH:
		act[id] = 0
		act_t[id] = 0.0


func _stop_wash(id: int) -> void:
	_clear_wash_pose(id)
	if sponge_id == id:
		sponge_id = -1
		sponge_hold = 0.0


func eye_use(x: float, y: float) -> Dictionary:
	if frozen:
		return {"type": "frozen"}
	var feat := _feature_at(x, y, 14.0)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_MONOLITH:
		_touch_monolith(feat)
		return {"type": "monolith"}
	var b := _building_at(x, y, 16.0)
	if not b.is_empty():
		var kind := int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			if not bool(b.get("incinerate", false)):
				_confirm("burn", {"op": "burn", "id": int(b.id)})
			else:
				notes.append("LA FABRICA INCINERA CADAVERES.")
			return {"type": "factory", "id": int(b.id)}
		if kind == Catalog.BLD_MARKET:
			return {"type": "market", "id": int(b.id)}
		_describe_building(b)
		return {"type": "building", "id": int(b.id), "kind": kind}
	var id := find_thronglet(x, y, 12.0, false)
	if id >= 0:
		return {"type": "thronglet", "id": id}
	return {"type": "empty"}


func _describe_building(b: Dictionary) -> void:
	var kind := int(b.kind)
	match kind:
		Catalog.BLD_APPLE:
			notes.append("EL MANZANO CRIA MANZANAS. CRECEN Y CAEN.")
		Catalog.BLD_TUB:
			notes.append("LA BANERA LIMPIA A QUIÉN SE METE.")
		Catalog.BLD_ROUND:
			notes.append("EL TIOVIVO SUBE LA DIVERSION. LOS MULTIS GIRAN ALREDEDOR.")
		Catalog.BLD_DWELL:
			notes.append("VIVIENDA. CUPO 4. COMEN, SE LAVAN Y DESCANSAN UN RATO.")
		Catalog.BLD_FANCY:
			notes.append("VIVIENDA DE LUJO. CABEN MÁS; COMEN Y SE LAVAN MEJOR.")
		Catalog.BLD_MINE, Catalog.BLD_MINE2:
			notes.append("LA MINA SE LLENA SOLA. CON FABRICA, LOS MULTIS ENTRAN Y SACAN MINERAL.")
		Catalog.BLD_THEATRE:
			notes.append("EL TEATRO TIENE CUPO. LA FUNCION ACABA Y SALEN.")
		Catalog.BLD_FLOWER:
			notes.append("LA FLOR DA UN POCO DE ALEGRIA.")
		Catalog.BLD_STATUE:
			notes.append("LA ESCULTURA ANIMA Y ACELERA A LOS CERCANOS.")
		_:
			if Catalog.BUILD_INFO.has(kind):
				notes.append(str(Catalog.BUILD_INFO[kind].label))


func take_hand(x: float, y: float) -> bool:
	if hand_id != -1 or frozen:
		return false
	var it := _item_at(x, y, 10.0)
	if it.is_empty():
		return false
	if bool(it.get("fixed", false)) or int(it.kind) == Catalog.ITEM_EGG:
		return false
	it.held = true
	hand_id = int(it.id)
	var held_kind_now := int(it.kind)
	if held_kind_now == Catalog.ITEM_WOOD:
		sfx_queue.append("wood_grab")
	elif held_kind_now == Catalog.ITEM_BONE:
		sfx_queue.append("bone_grab")
	else:
		sfx_queue.append("grab")
	return true


func drop_hand(x: float, y: float, throw_vx: float = 0.0, throw_vy: float = 0.0) -> void:
	if hand_id == -1:
		return
	var it = item_by_id.get(hand_id, {})
	if it.is_empty() or it.dead:
		hand_id = -1
		return
	var at := Vector2(x, y)
	# Fix (1): don't clear hand/held state if egg can't be dropped onto obstacle.
	if int(it.kind) == Catalog.ITEM_EGG and item_physics.obstacle_blocked(at.x, at.y):
		return
	hand_id = -1
	it.held = false
	var drop_tile := _tile_at(at.x, at.y)
	if drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG or drop_tile == Catalog.TILE_WATER:
		it.x = at.x
		it.y = at.y
		item_physics.launch_item(it, 14.0, 0.0, clampf(throw_vx, -180.0, 180.0), clampf(throw_vy, -180.0, 180.0))
		return
	it.x = at.x
	it.y = at.y
	item_physics.launch_item(it, 16.0, 20.0, clampf(throw_vx, -180.0, 180.0), clampf(throw_vy, -180.0, 180.0))
	if int(it.kind) == Catalog.ITEM_WOOD:
		sfx_queue.append("wood_drop")
	elif int(it.kind) == Catalog.ITEM_BONE:
		sfx_queue.append("bone_drop")
	else:
		sfx_queue.append("place")


func is_holding() -> bool:
	return held_kind != "" or hand_id != -1 or has_scoop()


func _ensure_agent_timers(i: int) -> void:
	# TODO: May be removed
	# Old saves lack react/cheer/sleep/peer/drop/penned arrays; grow on demand.
	while react_t.size() <= i:
		react_t.append(0.0)
	while cheer_t.size() <= i:
		cheer_t.append(0.0)
	while sleep_t.size() <= i:
		sleep_t.append(0.0)
	while peer_t.size() <= i:
		peer_t.append(0.0)
	while peer_of.size() <= i:
		peer_of.append(-1)
	while peer_sing.size() <= i:
		peer_sing.append(0)
	while drop_t.size() <= i:
		drop_t.append(0.0)
	while penned_flag.size() <= i:
		penned_flag.append(0)
	while bloody.size() <= i:
		bloody.append(0)


func grab_thronglet(id: int) -> bool:
	if frozen or is_holding():
		return false
	if id < 0 or id >= slot_count or state[id] != Catalog.ST_LIVING:
		return false
	if mito_t[id] > 0.0 or mito_charge[id] > 0.0:
		return false
	held_kind = "thronglet"
	held_ref = id
	held_x = pos_x[id]
	held_y = pos_y[id]
	dir_x[id] = 0.0
	dir_y[id] = 0.0
	act[id] = 0
	act_t[id] = 0.0
	_ensure_agent_timers(id)
	cheer_t[id] = 0.0
	react_t[id] = 0.0
	drop_t[id] = 0.0
	_clear_peer_social(id)
	clear_bark(id)
	return true


func grab_at(x: float, y: float) -> bool:
	if frozen or is_holding():
		return false
	var id := find_thronglet(x, y, 14.0, true)
	if id >= 0:
		return grab_thronglet(id)
	var feat := _feature_at(x, y, 14.0)
	if not feat.is_empty():
		if not _feature_movable(feat):
			return false
		held_kind = "rock"
		held_ref = int(feat.id)
		held_x = float(feat.x)
		held_y = float(feat.y)
		feat.lifted = true
		feat_mesh_epoch += 1
		_unbind_feature(feat)
		return true
	var it := _item_at(x, y, 10.0)
	if not it.is_empty() and (bool(it.get("fixed", false)) or int(it.kind) == Catalog.ITEM_EGG):
		if int(it.kind) == Catalog.ITEM_EGG:
			_help_egg(it)
		return false
	return take_hand(x, y)


func _thronglet_ground_ok(px: float, py: float) -> bool:
	# Mine zones are walkable ground pads: allow dropping/standing on them.
	if _on_mine_pad(px, py):
		return revealed.has(_ck_of(px, py)) and _tile_holds(px, py) and not Catalog.tile_blocks(_tile_at(px, py))
	if not _can_drop(px, py):
		return false
	return _land_inland(px, py)


func _find_safe_thronglet_spot(x: float, y: float) -> Vector2:
	for ring in 32:
		var rays := 1 if ring == 0 else 12
		for i in rays:
			var ang := float(i) * TAU / float(maxi(rays, 1))
			var r := float(ring) * 10.0
			var at := Vector2(x + cos(ang) * r, y + sin(ang) * r)
			if _thronglet_ground_ok(at.x, at.y):
				return at
	return Vector2(INF, INF)


func release_at(x: float, y: float, short_click: bool, _allow_use: bool = true, throw_vx: float = 0.0, throw_vy: float = 0.0) -> Dictionary:
	if hand_id != -1:
		var it = item_by_id.get(hand_id, {})
		var ix := x
		var iy := y
		var tvx := 0.0 if short_click else throw_vx
		var tvy := 0.0 if short_click else throw_vy
		if short_click and not it.is_empty():
			ix = float(it.x)
			iy = float(it.y)
		drop_hand(ix, iy, tvx, tvy)
		return {}
	if held_kind == "":
		return {}
	var px := held_x if short_click else x
	var py := held_y if short_click else y
	var kind := held_kind
	var id := held_ref
	if kind != "thronglet" and not short_click:
		var snapped := Catalog.snap_world(px, py)
		px = snapped.x
		py = snapped.y
	if kind == "thronglet" and id >= 0 and id < slot_count and state[id] == Catalog.ST_LIVING:
		if short_click:
			if _thronglet_ground_ok(px, py):
				_set_agent_pos(id, px, py)
		else:
			var drop_tile := _tile_at(px, py)
			if drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG:
				_set_agent_pos(id, px, py)
				_fall_void(px, py)
				_vacate(id)
			elif drop_tile == Catalog.TILE_WATER or not _thronglet_ground_ok(px, py):
				var safe := _find_safe_thronglet_spot(px, py)
				if is_inf(safe.x):
					safe = _find_safe_thronglet_spot(held_x, held_y)
				if not is_inf(safe.x):
					_set_agent_pos(id, safe.x, safe.y)
				elif drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG:
					_set_agent_pos(id, px, py)
					_fall_void(px, py)
					_vacate(id)
				else:
					if _thronglet_ground_ok(held_x, held_y):
						_set_agent_pos(id, held_x, held_y)
					else:
						_set_agent_pos(id, px, py)
			else:
				_set_agent_pos(id, px, py)
	elif kind == "rock":
		var feat = feature_by_id.get(id, {})
		if not feat.is_empty() and not feat.dead:
			if _tile_at(px, py) == Catalog.TILE_VOID or not _land_inland(px, py):
				_fall_void(px, py)
				_kill_feature(feat)
			elif not _can_drop(px, py) or not _stands(px, py, _span_for_feature(int(feat.kind))) or not _bind_feature_at(feat, px, py):
				feat.x = held_x
				feat.y = held_y
				_bind_feature_at(feat, held_x, held_y)
			feat.lifted = false
			feat_mesh_epoch += 1
	_clear_held()
	if short_click and kind == "thronglet":
		return {"type": "thronglet", "id": id}
	return {}


func cancel_hold() -> void:
	if not is_holding():
		return
	release_at(held_x, held_y, true, false)


func _clear_held() -> void:
	held_kind = ""
	held_ref = -1


func _can_drop(x: float, y: float, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	return revealed.has(_ck_of(x, y)) and not _blocked(x, y, allow_ore, allow_soft)


func _tile_holds(px: float, py: float) -> bool:
	return _tile_holds_cell(_cell_vec(px, py))


func _tile_holds_kind(tile: int) -> bool:
	return tile != Catalog.TILE_VOID and tile != Catalog.TILE_WATER and tile != Catalog.TILE_FOG


func _tile_holds_cell(cell: Vector2i) -> bool:
	return _tile_holds_kind(_tile_at_cell(cell))


func _invalidate_inland_around(cell: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			inland_cache.erase(cell + Vector2i(ox, oy))


func _land_inland(px: float, py: float) -> bool:
	return _land_inland_cell(_cell_vec(px, py))


func _land_inland_cell(cell: Vector2i) -> bool:
	# Center must hold, and no Moore neighbor may be void/water/fog.
	# Diagonal cliffs still read as "in the void" under iso sprites.
	if inland_cache.has(cell):
		return bool(inland_cache[cell])
	var ok := true
	if not _tile_holds_cell(cell):
		ok = false
	else:
		for oy in range(-1, 2):
			if not ok:
				break
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				if not _tile_holds_cell(cell + Vector2i(ox, oy)):
					ok = false
					break
	inland_cache[cell] = ok
	return ok


func _span_for_feature(kind: int) -> Vector2:
	if kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_FLOWER or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
		return Vector2(8.0, 14.0)
	if kind == Catalog.FEAT_BIGROCK:
		return Vector2(12.0, 22.0)
	return Vector2(16.0, 52.0)


func _stands(x: float, y: float, span: Vector2) -> bool:
	if not _land_inland(x, y):
		return false
	var cols: Array[float] = [-span.x, 0.0, span.x]
	var rows: Array[float] = [0.0]
	var sy := -span.y
	while sy < -0.5:
		rows.append(sy)
		sy += 16.0
	var step := float(Catalog.TILE)
	for sx in cols:
		for row in rows:
			var dcx := sx / 32.0 + row / 16.0
			var dcy := row / 16.0 - sx / 32.0
			if not _tile_holds(x + dcx * step, y + dcy * step):
				return false
	return true


func _item_spot_free(x: float, y: float, ignore_id: int = -1) -> bool:
	var other := _item_at(x, y, 10.0)
	return other.is_empty() or int(other.id) == ignore_id


func _pad_feature_soft(kind: int) -> bool:
	# Cleared when a building claims the pad. Ore nodes and monuments stay hard.
	return kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP \
		or kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK or kind == Catalog.FEAT_FLOWER \
		or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD or kind == Catalog.FEAT_FIRE


func _pad_item_soft(kind: int) -> bool:
	# Ground clutter claimed with the pad. Ore / TNT / eggs stay hard.
	return kind == Catalog.ITEM_WOOD or kind == Catalog.ITEM_APPLE \
		or kind == Catalog.ITEM_BALL or kind == Catalog.ITEM_BONE


func _pad_item_blocks(x: float, y: float, ignore_id: int = -1) -> bool:
	var other := _item_at(x, y, 10.0)
	if other.is_empty() or int(other.id) == ignore_id:
		return false
	return not _pad_item_soft(int(other.kind))


func _clear_pad_soft(cells: Array[Vector2i]) -> void:
	# Pad claim only clears blockers. Wood comes from the axe, not from placement.
	var seen := {}
	var seen_item := {}
	for cell in cells:
		var fid := int(feature_cell.get(cell, -1))
		if fid >= 0 and not seen.has(fid):
			seen[fid] = true
			var feat = feature_by_id.get(fid, {})
			if not feat.is_empty() and not feat.dead and _pad_feature_soft(int(feat.kind)):
				_kill_feature(feat)
		var at := _cell_world(cell)
		var it := _item_at(at.x, at.y, 10.0)
		if it.is_empty():
			continue
		var iid := int(it.id)
		if seen_item.has(iid) or it.dead or it.held:
			continue
		if not _pad_item_soft(int(it.kind)):
			continue
		seen_item[iid] = true
		it.dead = true
	if not seen_item.is_empty():
		_invalidate_item_counts()


func _building_spot_free(id: int, x: float, y: float, kind: int = -1) -> bool:
	var b = building_by_id.get(id, {})
	var size_kind := kind
	if size_kind < 0:
		size_kind = int(b.get("kind", -1)) if not b.is_empty() else -1
	if size_kind < 0:
		return _building_at(x, y, 14.0).is_empty()
	var cells := _footprint_cells(x, y, Catalog.footprint_for_building(size_kind))
	if not _footprint_holds(cells):
		return false
	var mine := size_kind == Catalog.BLD_MINE or size_kind == Catalog.BLD_MINE2
	var anchor := _cell_vec(x, y)
	var mine_feat_id := -1
	if mine:
		mine_feat_id = int(feature_cell.get(anchor, -1))
		var mine_feat = feature_by_id.get(mine_feat_id, {})
		if mine_feat.is_empty() or mine_feat.dead or _ore_tier(int(mine_feat.kind)) == 0:
			mine_feat_id = -1
		# Fresh campaign mines must sit on an ore node; sandbox may place freely.
		# Relocated mines already consumed theirs.
		if not sandbox_mode and id < 0 and mine_feat_id < 0:
			return false
	for cell in cells:
		var at := _cell_world(cell)
		if not revealed.has(_ck_of(at.x, at.y)):
			return false
		var bid := int(building_cell.get(cell, -1))
		if bid >= 0 and bid != id:
			return false
		var fid := int(feature_cell.get(cell, -1))
		if fid >= 0:
			# Ore nodes are multi-cell; a mine may cover every cell of the same node.
			if mine and fid == mine_feat_id:
				pass
			else:
				var feat = feature_by_id.get(fid, {})
				if feat.is_empty() or feat.dead or not _pad_feature_soft(int(feat.kind)):
					return false
		if _pad_item_blocks(at.x, at.y):
			return false
	return true


func _footprint_cells(x: float, y: float, size: Vector2i) -> Array[Vector2i]:
	var origin := _cell_vec(x, y)
	var cells: Array[Vector2i] = []
	for offset in Catalog.footprint_offsets(size):
		cells.append(origin + offset)
	return cells


func _cell_world(cell: Vector2i) -> Vector2:
	return Catalog.cell_world(cell)


func _footprint_holds(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var at := _cell_world(cell)
		if not _tile_holds(at.x, at.y):
			return false
	return true


func _unbind_feature(feat: Dictionary) -> void:
	var id := int(feat.id)
	var doomed: Array = []
	for cell in feature_cell.keys():
		if int(feature_cell[cell]) == id:
			doomed.append(cell)
	for cell in doomed:
		feature_cell.erase(cell)


func _bind_feature_at(feat: Dictionary, x: float, y: float) -> bool:
	var at := Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	var cells := _footprint_cells(x, y, Catalog.footprint_for_feature(int(feat.kind)))
	if not _footprint_holds(cells):
		return false
	for cell in cells:
		var owner := int(feature_cell.get(cell, -1))
		if owner >= 0 and owner != int(feat.id):
			return false
		var bid := int(building_cell.get(cell, -1))
		if bid >= 0:
			return false
	_feat_chunk_unindex(feat)
	_unbind_feature(feat)
	feat.x = x
	feat.y = y
	var c := _chunk_at(x, y)
	feat.cx = c.x
	feat.cy = c.y
	_feat_chunk_index(feat)
	for cell in cells:
		feature_cell[cell] = int(feat.id)
	return true


func _unbind_building(b: Dictionary) -> void:
	var id := int(b.id)
	var doomed: Array = []
	for cell in building_cell.keys():
		if int(building_cell[cell]) == id:
			doomed.append(cell)
	for cell in doomed:
		building_cell.erase(cell)


func _bind_building_at(b: Dictionary, x: float, y: float) -> bool:
	var cells := _footprint_cells(x, y, Catalog.footprint_for_building(int(b.kind)))
	if not _footprint_holds(cells):
		return false
	for cell in cells:
		var bid := int(building_cell.get(cell, -1))
		if bid >= 0 and bid != int(b.id):
			return false
		var fid := int(feature_cell.get(cell, -1))
		if fid >= 0:
			var feat = feature_by_id.get(fid, {})
			if feat.is_empty() or feat.dead or not _pad_feature_soft(int(feat.kind)):
				return false
	_clear_pad_soft(cells)
	_unbind_building(b)
	b.x = x
	b.y = y
	for cell in cells:
		building_cell[cell] = int(b.id)
	return true


func footprint_world(kind: int, x: float, y: float, is_building: bool = true) -> Array:
	var size := Catalog.footprint_for_building(kind) if is_building else Catalog.footprint_for_feature(kind)
	var out: Array = []
	for cell in _footprint_cells(x, y, size):
		out.append(_cell_world(cell))
	return out


func can_drop_feature(id: int, x: float, y: float) -> bool:
	var feat = feature_by_id.get(id, {})
	if feat.is_empty() or feat.dead:
		return false
	var at := Catalog.snap_world(x, y)
	if not _can_drop(at.x, at.y) or not _stands(at.x, at.y, _span_for_feature(int(feat.kind))):
		return false
	var cells := _footprint_cells(at.x, at.y, Catalog.footprint_for_feature(int(feat.kind)))
	for cell in cells:
		var owner := int(feature_cell.get(cell, -1))
		if owner >= 0 and owner != id:
			return false
		if int(building_cell.get(cell, -1)) >= 0:
			return false
	return true


func hand_item() -> Dictionary:
	if hand_id == -1:
		return {}
	return item_by_id.get(hand_id, {})


func _tool_open(tool: int) -> bool:
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) != tool:
			continue
		var key := str(entry.get("unlock", ""))
		if key == "":
			return true
		if not bool(unlocks.get(key, false)):
			return false
		return not ProgressionManager.replaced_by_unlocked(self, key)
	return true


func _place_sfx(kind: int) -> String:
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY:
		return "place_house"
	if kind == Catalog.BLD_TUB:
		return "place_tub"
	if kind == Catalog.BLD_ROUND:
		return "place_round"
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		return "place_factory"
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		return "place_mine"
	if kind == Catalog.BLD_THEATRE:
		return "place_theatre"
	if kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
		return "place_statue"
	if kind == Catalog.BLD_APPLE:
		return "place_apple"
	return "place"


func place_building(kind: int, x: float, y: float) -> bool:
	if frozen:
		return false
	if not Catalog.BUILD_INFO.has(kind):
		return false
	var at := Catalog.snap_world(x, y)
	var info: Dictionary = Catalog.BUILD_INFO[kind]
	if not bool(unlocks.get(str(info.unlock), false)):
		notes.append("AUN NO ESTA DESBLOQUEADO.")
		sfx_queue.append("error")
		return false
	if kind == Catalog.BLD_MARKET and _has_building(Catalog.BLD_MARKET):
		notes.append("SOLO PUEDE HABER UN MERCADO.")
		return false
	var node := 0
	var ore_feat := {}
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		if sandbox_mode:
			node = 1 if kind == Catalog.BLD_MINE else 2
		else:
			ore_feat = _feature_at(at.x, at.y, 12.0)
			if ore_feat.is_empty() or _ore_tier(int(ore_feat.kind)) == 0:
				notes.append("LA MINA SOLO VA SOBRE UN NODO.")
				sfx_queue.append("error")
				return false
			node = _ore_tier(int(ore_feat.kind))
			at = Catalog.snap_world(float(ore_feat.x), float(ore_feat.y))
	var allow_ore := not ore_feat.is_empty()
	if not _can_drop(at.x, at.y, allow_ore, true) or not _building_spot_free(-1, at.x, at.y, kind):
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sfx_queue.append("error")
		return false
	var costs := _building_costs(kind)
	var gem_cost := int(costs.gem)
	var wood_cost := int(costs.wood)
	if gem_cost > 0 and gems < gem_cost:
		notes.append("FALTAN GEMAS (%d)." % gem_cost)
		sfx_queue.append("error")
		return false
	if not _consume_kind(Catalog.ITEM_WOOD, wood_cost, at.x, at.y):
		notes.append("FALTA MADERA.")
		sfx_queue.append("error")
		return false
	if gem_cost > 0:
		gems -= gem_cost
	if allow_ore:
		_kill_feature(ore_feat)
	var b := _add_building(kind, at.x, at.y)
	if b.is_empty():
		if gem_cost > 0:
			gems += gem_cost
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sfx_queue.append("error")
		return false
	b.node = node
	sfx_queue.append(_place_sfx(kind))
	_refresh_pop_gates()
	return true


func spot_ok(x: float, y: float, building_id: int = -1, ignore_item_id: int = -1, build_kind: int = -1) -> bool:
	var at := Catalog.snap_world(x, y)
	var allow_ore := build_kind == Catalog.BLD_MINE or build_kind == Catalog.BLD_MINE2
	if not allow_ore and building_id >= 0:
		var held = building_by_id.get(building_id, {})
		var held_kind := int(held.get("kind", -1))
		allow_ore = held_kind == Catalog.BLD_MINE or held_kind == Catalog.BLD_MINE2
	var placing_bld := building_id >= 0 or build_kind >= 0
	if not _can_drop(at.x, at.y, allow_ore, placing_bld):
		return false
	if placing_bld:
		var kind := build_kind
		if kind < 0:
			var held = building_by_id.get(building_id, {})
			kind = int(held.get("kind", -1))
		if not _building_spot_free(building_id, at.x, at.y, kind):
			return false
		if ignore_item_id >= 0:
			for cell in _footprint_cells(at.x, at.y, Catalog.footprint_for_building(kind)):
				var mid := _cell_world(cell)
				var other := _item_at(mid.x, mid.y, 10.0)
				if not other.is_empty() and int(other.id) != ignore_item_id:
					return false
		return true
	if not _item_spot_free(at.x, at.y, ignore_item_id):
		return false
	return int(building_cell.get(_cell_vec(at.x, at.y), -1)) < 0


func can_place_building(kind: int, x: float, y: float) -> bool:
	if kind == Catalog.BLD_MARKET and _has_building(Catalog.BLD_MARKET):
		return false
	if not _can_afford_building(kind):
		return false
	var at := Catalog.snap_world(x, y)
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		if not sandbox_mode:
			var feat := _feature_at(at.x, at.y, 12.0)
			if feat.is_empty() or _ore_tier(int(feat.kind)) == 0:
				return false
			at = Catalog.snap_world(float(feat.x), float(feat.y))
	return spot_ok(at.x, at.y, -1, -1, kind)


func buy(key: String) -> bool:
	if not _has_building(Catalog.BLD_MARKET):
		notes.append("COLOCA EL MERCADO PRIMERO.")
		return false
	if not Catalog.MARKET.has(key):
		return false
	if bool(unlocks.get(key, false)):
		return false
	var cost := int(Catalog.MARKET[key].cost)
	var pc := ProgressionCatalog.by_id(key)
	if not pc.is_empty():
		cost = maxi(cost, int(pc.get("baseGemCost", cost)))
	if gems < cost:
		notes.append("FALTAN GEMAS.")
		return false
	gems -= cost
	_grant(key, "COMPRADO: " + str(Catalog.MARKET[key].label))
	ProgressionManager.evaluate_unlocks(self, true)
	return true


func tutorial_line() -> String:
	var signs: Array[int] = [0, 1, 15]
	if tutorial_i < 0 or tutorial_i >= signs.size():
		return ""
	return LineBook.row("SYS.MESSAGES", signs[tutorial_i])


func advance_tutorial() -> void:
	var signs: Array[int] = [0, 1, 15]
	if tutorial_i < 0:
		return
	tutorial_i += 1
	if tutorial_i < signs.size():
		return
	tutorial_i = -1
	_know_count()
	if living > 0 and _ethics_choice("first_born") == -1:
		_queue_talk("first_born", {})


func _know_count() -> void:
	count_unknown = false


func address(text: String) -> String:
	if player_name == "":
		return text
	return text.replace("[NAME]", player_name).replace("{name}", player_name)


func _open_name_ask() -> void:
	var ask := LineBook.row("SYS.PLAYERINPUT", 0)
	modal = {
		"event": "player_name",
		"step": "ask",
		"draft": "",
		"log": ["> " + ask],
		"seq": 1,
		"tree": "",
		"node": "",
	}
	_begin_gaze()


func submit_name(raw: String) -> void:
	if modal.is_empty() or str(modal.get("event", "")) != "player_name":
		return
	if str(modal.get("step", "")) != "ask":
		return
	var called := raw.strip_edges()
	modal["draft"] = called
	var notice := ""
	if called == "":
		notice = LineBook.row("SYS.NOTIFICATIONS", 54)
	elif not _name_chars_ok(called):
		notice = LineBook.row("SYS.MENUS", 27)
	elif _name_banned(called):
		notice = LineBook.row("SYS.MENUS", 23)
	if notice != "":
		modal["log"] = ["> " + LineBook.row("SYS.PLAYERINPUT", 0), "> " + notice]
		modal["seq"] = int(modal.get("seq", 1)) + 1
		return
	var confirm := LineBook.row("SYS.PLAYERINPUT", 2).replace("[NAME]", called)
	modal["step"] = "confirm"
	modal["log"] = ["> " + confirm]
	modal["seq"] = int(modal.get("seq", 1)) + 1


func _choose_name(index: int) -> void:
	var step := str(modal.get("step", ""))
	if step == "ask":
		submit_name(str(modal.get("draft", "")))
		return
	if step == "echo":
		modal = {}
		frozen = false
		_restore_gaze()
		_open_next_talk()
		return
	if step != "confirm":
		return
	if index != 0:
		modal["step"] = "ask"
		modal["draft"] = ""
		modal["log"] = ["> " + LineBook.row("SYS.PLAYERINPUT", 0)]
		modal["seq"] = int(modal.get("seq", 1)) + 1
		return
	player_name = str(modal.get("draft", ""))
	var echo := LineBook.row("SYS.PLAYERINPUT", 5).replace("{0}", player_name)
	if echo.begins_with("'") and echo.ends_with("'") and echo.length() >= 2:
		echo = echo.substr(1, echo.length() - 2)
	modal["step"] = "echo"
	modal["log"] = [echo]
	modal["seq"] = int(modal.get("seq", 1)) + 1


func _name_chars_ok(called: String) -> bool:
	_ensure_name_rules()
	if _name_chars == "" or called.length() > 24:
		return false
	for i in called.length():
		if not _name_chars.contains(called[i]):
			return false
	return true


func _name_banned(called: String) -> bool:
	_ensure_name_rules()
	var flat := _flat_name(called)
	for ban in _name_bans:
		if ban.length() >= 3 and flat.contains(ban):
			return true
	return false


func _flat_name(raw: String) -> String:
	var out := ""
	var lower := raw.to_lower()
	for i in lower.length():
		var ch := lower[i]
		if ch == " " or ch == "\t" or ch == "-" or ch == "_" or ch == ".":
			continue
		out += ch
	return out


func _ensure_name_rules() -> void:
	if _name_rules:
		return
	_name_rules = true
	var bans := FileAccess.open("res://data/dialogue/profanity.txt", FileAccess.READ)
	if bans != null:
		while not bans.eof_reached():
			var line := _flat_name(bans.get_line())
			if line.length() >= 3:
				_name_bans.append(line)
	var chars := FileAccess.open("res://data/dialogue/name_chars.txt", FileAccess.READ)
	if chars != null:
		_name_chars = chars.get_as_text()


func choose(index: int) -> void:
	if modal.is_empty():
		return
	if str(modal.get("event", "")) == "player_name":
		_choose_name(index)
		return
	if modal.has("lines"):
		_advance_lines()
		return
	var event := str(modal.event)
	if not Catalog.GAZE.has(event):
		return
	var action: Dictionary = modal.action if modal.action is Dictionary else {}
	var gaze: Dictionary = Catalog.GAZE[event]
	if not modal.has("node") or str(modal.get("tree", "")) == "":
		var opened: Dictionary = DialogueBook.open_session(event)
		if opened.is_empty():
			modal = {}
			frozen = false
			_restore_gaze()
			_open_next_talk()
			return
		modal["tree"] = opened.tree
		modal["node"] = opened.node
		modal["log"] = opened.log
		modal["seq"] = opened.seq
	var session := {
		"tree": str(modal.tree),
		"node": str(modal.node),
		"log": modal.log if modal.log is Array else [],
		"seq": int(modal.get("seq", 1)),
	}
	var choices: Array = DialogueBook.choices_of(session)
	if index < 0 or index >= choices.size():
		return
	var step: Dictionary = DialogueBook.advance(session, index)
	var edge: Dictionary = step.edge if step.edge is Dictionary else {}
	modal["log"] = step.session.log
	modal["node"] = step.session.node
	modal["seq"] = step.session.seq
	sfx_queue.append("ui")
	if not bool(step.done):
		return
	var label := str(edge.get("label", ""))
	_set_ethics(event, index, label)
	_apply_moral_edge(edge)
	talked_trees[str(modal.tree)] = true
	modal = {}
	frozen = false
	_restore_gaze()
	var allow: Array = gaze.get("allow", [])
	if allow.has(index) and not action.is_empty():
		_apply_action(action)
	if event == "first_born" and player_name == "":
		_open_name_ask()
		return
	_open_next_talk()


func inspect(id: int) -> Dictionary:
	if id < 0 or id >= slot_count or state[id] == Catalog.ST_VACANT:
		return {}
	var status := "VIVO"
	if state[id] == Catalog.ST_DEAD:
		status = "MUERTO"
	return {
		"id": id,
		"fed": fed[id],
		"amused": amused[id],
		"clean": clean[id],
		"happy": (fed[id] + amused[id] + clean[id]) / 3.0,
		"status": status,
	}


func moral_line() -> String:
	if ethics.is_empty():
		return "AUN NO TE JUZGAN."
	var mark := "CUIDADO" if moral > 0 else "FRIO" if moral < 0 else "NEUTRO"
	return "%s (%+d)  %s" % [mark, moral, str(ethics[ethics.size() - 1].text)]


func count_item(kind: int) -> int:
	_ensure_item_counts()
	match kind:
		Catalog.ITEM_WOOD:
			return _item_count_wood
		Catalog.ITEM_BONE:
			return _item_count_bone
		Catalog.ITEM_ORE:
			return _item_count_ore
		_:
			if _item_count_other.has(kind):
				return int(_item_count_other[kind])
			var n := 0
			for it in items:
				if not it.dead and not it.held and int(it.kind) == kind:
					n += 1
			_item_count_other[kind] = n
			return n


func _invalidate_item_counts() -> void:
	_item_count_gen += 1


func _carry_dec(i: int) -> void:
	if i < 0 or i >= carry.size():
		return
	match int(carry[i]):
		Catalog.CARRY_WOOD:
			carry_wood_n = maxi(0, carry_wood_n - 1)
		Catalog.CARRY_BONE:
			carry_bone_n = maxi(0, carry_bone_n - 1)
		Catalog.CARRY_ORE:
			carry_ore_n = maxi(0, carry_ore_n - 1)


func _carry_inc(i: int) -> void:
	if i < 0 or i >= carry.size():
		return
	match int(carry[i]):
		Catalog.CARRY_WOOD:
			carry_wood_n += 1
		Catalog.CARRY_BONE:
			carry_bone_n += 1
		Catalog.CARRY_ORE:
			carry_ore_n += 1


func _set_carry(i: int, kind: int, value: int = 0) -> void:
	if i < 0 or i >= carry.size():
		return
	if int(carry[i]) == kind and (kind == Catalog.CARRY_NONE or int(carry_value[i]) == value):
		return
	var was_carrying := int(carry[i]) != Catalog.CARRY_NONE
	_carry_dec(i)
	carry[i] = kind
	carry_value[i] = value if kind != Catalog.CARRY_NONE else 0
	_carry_inc(i)
	# DropProp one-shot when a haul leaves the hands.
	if was_carrying and kind == Catalog.CARRY_NONE:
		_ensure_agent_timers(i)
		drop_t[i] = DROP_DUR
		dir_x[i] = 0.0
		dir_y[i] = 0.0


func _rebuild_carry_counts() -> void:
	carry_wood_n = 0
	carry_bone_n = 0
	carry_ore_n = 0
	for raw in living_ids:
		_carry_inc(int(raw))


func _ensure_item_counts() -> void:
	if _item_count_built == _item_count_gen:
		return
	_item_count_built = _item_count_gen
	_item_count_other.clear()
	var wood := 0
	var bone := 0
	var ore := 0
	for it in items_wood:
		if not it.dead and not it.held:
			wood += 1
	for it in items_bone:
		if not it.dead and not it.held:
			bone += 1
	for it in items_ore:
		if not it.dead and not it.held:
			ore += 1
	_item_count_wood = wood + carry_wood_n
	_item_count_bone = bone + carry_bone_n
	_item_count_ore = ore + carry_ore_n


func count_dead() -> int:
	return dead_n


func debug_agent_path(i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return pts
	var fx := pos_x[i]
	var fy := pos_y[i]
	pts.append(Vector2(fx, fy))
	var has_seek := i < seek_t.size() and seek_t[i] > 0.0
	if not has_seek and not _agent_has_hard_goal(i):
		if absf(dir_x[i]) + absf(dir_y[i]) > 0.05:
			pts.append(Vector2(fx + dir_x[i] * 28.0, fy + dir_y[i] * 28.0))
		return pts
	var tx := seek_x[i] if i < seek_x.size() else fx
	var ty := seek_y[i] if i < seek_y.size() else fy
	var cells := _bfs_path_cells(_cell_vec(fx, fy), _cell_vec(tx, ty))
	for cell in cells:
		var at := _cell_world(cell)
		if pts[pts.size() - 1].distance_squared_to(at) > 0.25:
			pts.append(at)
	var goal := Vector2(tx, ty)
	var last := pts[pts.size() - 1]
	# Do not draw a fake chord through blockers when BFS stopped short of the goal.
	if last.distance_squared_to(goal) > 1.0 and _axis_clear(last.x, last.y, goal.x, goal.y):
		pts.append(goal)
	return pts


func _debug_can_food(i: int) -> bool:
	if not _nearest_apple(i, 240.0).is_empty():
		return true
	return not _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i).is_empty()


func _debug_can_clean(i: int) -> bool:
	var tub_seat := seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		return true
	if not _nearest_tub(i).is_empty():
		return true
	return not _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i).is_empty()


func _debug_can_fun(i: int) -> bool:
	if not _ride_building(i).is_empty():
		return true
	if not _nearest_roundabout(i, 320.0).is_empty():
		return true
	if not _nearest_ball(i, 260.0).is_empty():
		return true
	return not _nearest_building_kinds(
		pos_x[i], pos_y[i],
		[Catalog.BLD_THEATRE, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD],
		320.0, i
	).is_empty()


func _debug_can_haul(i: int) -> bool:
	if i < carry.size() and carry[i] != Catalog.CARRY_NONE:
		return true
	if not _has_factory():
		return false
	return not _nearest_free_item(i, Catalog.ITEM_ORE, 180.0).is_empty()


func _debug_can_mine(i: int) -> bool:
	if not _work_ready(i) or not _has_factory() or carry[i] != Catalog.CARRY_NONE:
		return false
	var mine := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		return false
	if _is_guest(mine, i):
		return true
	var stock := int(mine.get("buffer", 0))
	var digging := _live_guests(mine)
	if stock <= digging:
		return false
	var cap := 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	var already := i < mine_job.size() and int(mine_job[i]) == int(mine.id)
	if digging + _mine_jobs(mine) >= cap and not already:
		return false
	return true


func debug_agent_tasks(i: int) -> Array:
	# Mirrors _tick_decide: urgency only counts when the seek can actually run.
	var out: Array = []
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return out
	var fed_v := fed[i]
	var clean_v := clean[i]
	var fun_v := amused[i]
	var carrying := i < carry.size() and carry[i] != Catalog.CARRY_NONE
	var mining := i < mine_job.size() and int(mine_job[i]) >= 0
	var in_tub := false
	var on_ride := false
	var tub_seat := seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		in_tub = true
	if not _ride_building(i).is_empty():
		on_ride = true
	var can_food := _debug_can_food(i)
	var can_clean := _debug_can_clean(i)
	var can_fun := _debug_can_fun(i)
	var can_haul := _debug_can_haul(i)
	var can_mine := _debug_can_mine(i)
	var food_p := 0.0
	if can_food:
		if fed_v < Catalog.NEED_HUNGRY:
			food_p = 1000.0 + (Catalog.NEED_HUNGRY - fed_v)
		elif fed_v < Catalog.NEED_OK:
			food_p = 300.0 + (Catalog.NEED_OK - fed_v)
	var clean_p := 0.0
	if can_clean:
		if clean_v < Catalog.NEED_SEEK:
			clean_p = 900.0 + (Catalog.NEED_SEEK - clean_v)
		elif clean_v < Catalog.NEED_OK:
			clean_p = 300.0 + (Catalog.NEED_OK - clean_v)
		if in_tub:
			clean_p = maxf(clean_p, 950.0)
	var fun_p := 0.0
	if can_fun:
		if fun_v < Catalog.NEED_FUN:
			fun_p = 700.0 + (Catalog.NEED_FUN - fun_v)
		elif fun_v < Catalog.NEED_OK:
			fun_p = 300.0 + (Catalog.NEED_OK - fun_v)
		if on_ride:
			fun_p = maxf(fun_p, 750.0)
	var haul_p := 0.0
	if can_haul:
		haul_p = 800.0 if carrying else 50.0
	var mine_p := 0.0
	if can_mine:
		mine_p = 550.0 if mining else 500.0
	var wander_p := 10.0
	# Same gate order as _tick_decide, skipping seeks that would return false.
	var active := "wander"
	if in_tub and can_clean:
		active = "clean"
	elif on_ride and can_fun:
		active = "fun"
	elif fed_v < Catalog.NEED_HUNGRY and can_food:
		active = "food"
	elif clean_v < Catalog.NEED_SEEK and can_clean:
		active = "clean"
	elif carrying and can_haul:
		active = "haul"
	elif fun_v < Catalog.NEED_FUN and can_fun:
		active = "fun"
	elif can_haul:
		active = "haul"
	elif can_mine:
		active = "mine"
	elif fed_v < Catalog.NEED_OK or clean_v < Catalog.NEED_OK or fun_v < Catalog.NEED_OK:
		var lack_fed := Catalog.NEED_OK - fed_v if can_food else -1.0
		var lack_clean := Catalog.NEED_OK - clean_v if can_clean else -1.0
		var lack_fun := Catalog.NEED_OK - fun_v if can_fun else -1.0
		if lack_fed >= lack_clean and lack_fed >= lack_fun and lack_fed >= 0.0:
			active = "food"
		elif lack_clean >= lack_fun and lack_clean >= 0.0:
			active = "clean"
		elif lack_fun >= 0.0:
			active = "fun"
	var rows: Array = [
		{"id": "food", "label": "COMER", "priority": food_p, "active": active == "food"},
		{"id": "clean", "label": "BANARSE", "priority": clean_p, "active": active == "clean"},
		{"id": "fun", "label": "DIVERTIRSE", "priority": fun_p, "active": active == "fun"},
		{"id": "haul", "label": "ACARREAR", "priority": haul_p, "active": active == "haul"},
		{"id": "mine", "label": "MINAR", "priority": mine_p, "active": active == "mine"},
		{"id": "wander", "label": "VAGAR", "priority": wander_p, "active": active == "wander"},
	]
	for row in rows:
		# Drop targets the agent cannot act on right now (busy tub, no mine stock, …).
		if float(row.priority) <= 0.0 and str(row.id) != "wander":
			continue
		out.append(row)
	out.sort_custom(func(a, b): return float(a.priority) > float(b.priority))
	return out


func debug_spawn(amount: int, around: Vector2) -> void:
	var rx := 360.0 + sqrt(float(maxi(0, amount))) * 8.0
	var ry := 220.0 + sqrt(float(maxi(0, amount))) * 5.0
	for _n in amount:
		if slot_count >= Catalog.MAX_SLOTS:
			break
		var x := around.x + randf_range(-rx, rx)
		var y := around.y + randf_range(-ry, ry)
		if _blocked(x, y):
			x = around.x + randf_range(-rx * 0.3, rx * 0.3)
			y = around.y + randf_range(-ry * 0.3, ry * 0.3)
		_push_slot(x, y, 80.0, 80.0, 80.0, 8.0, randi() % Catalog.TINTS.size())
	_rebuild_hash()
	notes.append("ENJAMBRE DE PRUEBA: %d" % living)


func debug_perf_busy(around: Vector2, scale: int = 1) -> Dictionary:
	# Populate a mid-game-like island so perf measures props/paths/AI seeks, not an empty field.
	# scale=1 ≈ early mid-game; scale=3+ packs many more props/paths for stress.
	scale = maxi(1, scale)
	for info in Catalog.BUILD_INFO.values():
		unlocks[str(info.unlock)] = true
	for key in ["axe", "mine", "factory", "factory2", "theatre", "nuke", "bug"]:
		unlocks[key] = true
	gems = maxi(gems, 500)
	var placed_bld := 0
	var placed_item := 0
	var placed_path := 0
	var base_plan: Array = [
		[Catalog.BLD_TUB, Vector2(-48, -16)],
		[Catalog.BLD_TUB, Vector2(64, 24)],
		[Catalog.BLD_ROUND, Vector2(-16, 72)],
		[Catalog.BLD_DWELL, Vector2(96, -48)],
		[Catalog.BLD_DWELL, Vector2(-96, 48)],
		[Catalog.BLD_FANCY, Vector2(48, 96)],
		[Catalog.BLD_THEATRE, Vector2(-120, -64)],
		[Catalog.BLD_APPLE, Vector2(120, 40)],
		[Catalog.BLD_APPLE, Vector2(-64, 112)],
		[Catalog.BLD_FACTORY, Vector2(160, -24)],
		[Catalog.BLD_MARKET, Vector2(24, -112)],
	]
	var plan: Array = []
	for s in scale:
		var ox := float((s % 3) - 1) * 220.0
		var oy := float((s / 3) - (scale / 6)) * 180.0
		for row in base_plan:
			# Only one market: keep the first, skip extras.
			if int(row[0]) == Catalog.BLD_MARKET and s > 0:
				continue
			var off: Vector2 = row[1]
			plan.append([row[0], Vector2(off.x + ox, off.y + oy)])
	for row in plan:
		var kind := int(row[0])
		var off2: Vector2 = row[1]
		var at := Catalog.snap_world(around.x + off2.x, around.y + off2.y)
		if _try_add_building_near(kind, at.x, at.y):
			placed_bld += 1
	var loot: Array = [
		[Catalog.ITEM_APPLE, 18 * scale],
		[Catalog.ITEM_BALL, 8 * scale],
		[Catalog.ITEM_WOOD, 24 * scale],
		[Catalog.ITEM_BONE, 10 * scale],
		[Catalog.ITEM_ORE, 12 * scale],
	]
	var spread := 200.0 + float(scale - 1) * 80.0
	for row2 in loot:
		var ikind := int(row2[0])
		var n := int(row2[1])
		for _i in n:
			var ix := around.x + randf_range(-spread, spread)
			var iy := around.y + randf_range(-spread * 0.7, spread * 0.7)
			if _blocked(ix, iy):
				ix = around.x + randf_range(-80.0, 80.0)
				iy = around.y + randf_range(-80.0, 80.0)
			_add_item(ikind, ix, iy, 1)
			placed_item += 1
	# Stamp worn paths in a cross + grid so path sprites stress the draw path.
	var origin := _cell_vec(around.x, around.y)
	var path_r := 10 + 6 * (scale - 1)
	var side_r := 4 + 2 * (scale - 1)
	for i in range(-path_r, path_r + 1):
		for cell in [origin + Vector2i(i, 0), origin + Vector2i(0, i)]:
			var key := "%d,%d" % [cell.x, cell.y]
			if int(wear.get(key, 0)) < WEAR_NEED:
				wear[key] = WEAR_NEED
				_mark_path(cell)
				placed_path += 1
		if absi(i) % 3 == 0:
			for j in range(-side_r, side_r + 1):
				var side := origin + Vector2i(i, j)
				var skey := "%d,%d" % [side.x, side.y]
				if int(wear.get(skey, 0)) < WEAR_NEED:
					wear[skey] = WEAR_NEED
					_mark_path(side)
					placed_path += 1
	_rebuild_kind_indexes()
	_rebuild_hash()
	paint_epoch += 1
	notes.append("PERF BUSY x%d: bld=%d item=%d path=%d" % [scale, placed_bld, placed_item, placed_path])
	return {"scale": scale, "buildings": placed_bld, "items": placed_item, "paths": placed_path}


func _try_add_building_near(kind: int, x: float, y: float) -> bool:
	if not _add_building(kind, x, y).is_empty():
		return true
	for ring in range(1, 8):
		for d in [
			Vector2(ring * 16, 0), Vector2(-ring * 16, 0),
			Vector2(0, ring * 16), Vector2(0, -ring * 16),
			Vector2(ring * 16, ring * 16), Vector2(-ring * 16, ring * 16),
			Vector2(ring * 16, -ring * 16), Vector2(-ring * 16, -ring * 16),
		]:
			var try_at := Catalog.snap_world(x + d.x, y + d.y)
			if not _add_building(kind, try_at.x, try_at.y).is_empty():
				return true
	return false


func chunk_shown(ck: String) -> bool:
	return revealed.has(ck)


func chunk_at_home(x: float, y: float) -> bool:
	var c := _chunk_at(x, y)
	var key := _ck(c.x, c.y)
	return revealed.has(key) and _is_island_chunk(c.x, c.y)


func chunk_key_at(x: float, y: float) -> String:
	var c := _chunk_at(x, y)
	return _ck(c.x, c.y)


func explore_rect(rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		return
	var size := float(Catalog.TILE * Catalog.CHUNK)
	var x0 := int(floor(rect.position.x / size))
	var y0 := int(floor(rect.position.y / size))
	var x1 := int(floor(rect.end.x / size))
	var y1 := int(floor(rect.end.y / size))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			_try_reveal(cx, cy)


func query_rect(rect: Rect2, limit: int = 0) -> Array:
	# AABB over hash cells — circle(half.diagonal) massively over-included at wide zooms.
	# limit > 0 stops early (AI priority / density sampling).
	var out: Array = []
	if hash_head.is_empty() or rect.size == Vector2.ZERO:
		return out
	var pad := 8.0
	var x0 := int(floor((rect.position.x - pad) / Catalog.HASH_CELL))
	var y0 := int(floor((rect.position.y - pad) / Catalog.HASH_CELL))
	var x1 := int(floor((rect.end.x + pad) / Catalog.HASH_CELL))
	var y1 := int(floor((rect.end.y + pad) / Catalog.HASH_CELL))
	var hit := Rect2(rect.position - Vector2(pad, pad), rect.size + Vector2(pad * 2.0, pad * 2.0))
	var seen_bucket := {}
	for oy in range(y0, y1 + 1):
		for ox in range(x0, x1 + 1):
			var bucket := _bucket_cell(ox, oy)
			if seen_bucket.has(bucket):
				continue
			seen_bucket[bucket] = true
			var i := hash_head[bucket]
			var guard := 0
			while i != -1 and guard < slot_count + 2:
				guard += 1
				if i >= 0 and i < slot_count and state[i] != Catalog.ST_VACANT:
					if hit.has_point(Vector2(pos_x[i], pos_y[i])):
						out.append(i)
						if limit > 0 and out.size() >= limit:
							return out
				i = hash_next[i] if i >= 0 and i < hash_next.size() else -1
	return out


func query_radius(x: float, y: float, radius: float) -> Array:
	var out: Array = []
	if hash_head.is_empty():
		return out
	var reach := int(ceil(radius / Catalog.HASH_CELL))
	var cx := int(floor(x / Catalog.HASH_CELL))
	var cy := int(floor(y / Catalog.HASH_CELL))
	var r2 := radius * radius
	var seen_bucket := {}
	for oy in range(cy - reach, cy + reach + 1):
		for ox in range(cx - reach, cx + reach + 1):
			var bucket := _bucket_cell(ox, oy)
			if seen_bucket.has(bucket):
				continue
			seen_bucket[bucket] = true
			var i := hash_head[bucket]
			var guard := 0
			while i != -1 and guard < slot_count + 2:
				guard += 1
				if i >= 0 and i < slot_count and state[i] != Catalog.ST_VACANT:
					var dx := pos_x[i] - x
					var dy := pos_y[i] - y
					if dx * dx + dy * dy <= r2:
						out.append(i)
				i = hash_next[i] if i >= 0 and i < hash_next.size() else -1
	return out


func find_thronglet(x: float, y: float, radius: float, living_only: bool) -> int:
	var ids := query_radius(x, y, radius)
	var best_live := -1
	var best_dead := -1
	var live_d := radius * radius
	var dead_d := radius * radius
	for id in ids:
		var dx := pos_x[int(id)] - x
		var dy := pos_y[int(id)] - y
		var d := dx * dx + dy * dy
		if state[int(id)] == Catalog.ST_LIVING and d <= live_d:
			live_d = d
			best_live = int(id)
		elif state[int(id)] == Catalog.ST_DEAD and d <= dead_d:
			dead_d = d
			best_dead = int(id)
	if living_only:
		return best_live
	if best_live >= 0:
		return best_live
	return best_dead


func take_notes() -> Array:
	var copy := notes.duplicate()
	notes.clear()
	return copy


func take_sfx() -> Array:
	var copy := sfx_queue.duplicate()
	sfx_queue.clear()
	return copy


func take_dirty() -> Array:
	var copy := dirty_chunks.duplicate()
	dirty_chunks.clear()
	return copy


func chunk_tiles(ck: String) -> PackedByteArray:
	if not chunks.has(ck):
		return PackedByteArray()
	return chunks[ck].tiles


func chunk_origin(ck: String) -> Vector2i:
	var c := _parse_ck(ck)
	return Vector2i(c.x * Catalog.CHUNK, c.y * Catalog.CHUNK)


const ACT_EAT := 1
const ACT_PLAY := 2
const ACT_WASH := 3
const ACT_BATH := 4
const ACT_WORK := 5


func _pop(x: float, y: float, icon: int, sprite_scale: float = 1.0, throng_id: int = -1, life: float = 0.55, kind: String = "") -> void:
	pops.append({
		"x": x,
		"y": y,
		"t": life,
		"life": life,
		"icon": icon,
		"lift": 0.0,
		"scale": sprite_scale,
		"throng_id": throng_id,
		"kind": kind,
	})


func _tick_pops(dt: float, age: bool = true) -> void:
	var kept: Array = []
	for pop in pops:
		var throng_id := int(pop.get("throng_id", -1))
		if age:
			pop.t = float(pop.t) - dt
			if throng_id < 0:
				pop.lift = float(pop.lift) + 22.0 * dt
		if float(pop.t) <= 0.0 or (throng_id >= 0 and (throng_id >= slot_count or state[throng_id] != Catalog.ST_LIVING)):
			continue
		if throng_id >= 0:
			pop.x = pos_x[throng_id]
			pop.y = pos_y[throng_id]
		kept.append(pop)
	pops = kept


func _boot_game() -> void:
	var last := save_system.last_slot()
	if last >= 0 and save_system.load_slot(last):
		return
	_bootstrap_new()


func new_game() -> void:
	# One run only: wipe the live save and its autosave history.
	save_system.clear_saves()
	current_slot = SaveSystem.LIVE_SLOT
	ethics = []
	sandbox_mode = false
	_init_unlocks()
	unlock_serial += 1
	world_seed = randi()
	if world_seed == 0:
		world_seed = 1
	_bootstrap_new()
	tutorial_i = 0
	count_unknown = true
	notes.append("PARTIDA NUEVA.")


func new_sandbox_game(tier: int = SANDBOX_START_TIER) -> void:
	save_system.clear_sandbox_save()
	current_slot = -1
	save_path = save_system.sandbox_path()
	ethics = []
	world_seed = randi()
	if world_seed == 0:
		world_seed = 1
	_bootstrap_sandbox(clampi(tier, SANDBOX_TIER_MIN, SANDBOX_TIER_MAX))
	notes.append("SANDBOX.")


func set_sandbox_land_tier(tier: int) -> void:
	if not sandbox_mode:
		return
	var next := clampi(tier, SANDBOX_TIER_MIN, SANDBOX_TIER_MAX)
	if next == land_tier:
		return
	land_tier = next
	# Shape removes props that lost land; do not strip player-placed features on resize.
	_shape_island()
	notes.append("ISLA %d" % land_tier)


func sandbox_grow() -> void:
	set_sandbox_land_tier(land_tier + 1)


func sandbox_shrink() -> void:
	set_sandbox_land_tier(land_tier - 1)


func _apply_action(action: Dictionary) -> void:
	var op := str(action.get("op", ""))
	if op == "bug":
		_deflesh(int(action.get("id", -1)), true)
	elif op == "swarm":
		_swarm(float(action.get("x", 0.0)), float(action.get("y", 0.0)))
	elif op == "burn":
		var b = building_by_id.get(int(action.get("id", -1)), {})
		if not b.is_empty():
			b.incinerate = true
			notes.append("LA FABRICA ACEPTA CADAVERES.")
	elif op == "nuke":
		_nuke(int(action.get("cx", 0)), int(action.get("cy", 0)))


func _drop_carried(i: int) -> void:
	if i < 0 or i >= slot_count or carry[i] == Catalog.CARRY_NONE:
		return
	var kind := Catalog.ITEM_WOOD
	if carry[i] == Catalog.CARRY_BONE:
		kind = Catalog.ITEM_BONE
	elif carry[i] == Catalog.CARRY_ORE:
		kind = Catalog.ITEM_ORE
	var dropped_carry := _add_item(kind, pos_x[i], pos_y[i], maxi(1, carry_value[i]))
	item_physics.launch_item(dropped_carry, 6.0, randf_range(70.0, 100.0), randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
	_set_carry(i, Catalog.CARRY_NONE)


func _lift_building(b: Dictionary) -> void:
	var occ := int(b.get("occupant", -1))
	if occ >= 0 and occ < claim.size():
		claim[occ] = -1
		if occ < link_tub.size():
			link_tub[occ] = -1
	for guest in b.get("guests", []):
		var gid := int(guest.get("id", -1))
		if gid >= 0 and gid < link_guest.size() and link_guest[gid] == int(b.id):
			link_guest[gid] = -1
	for raw in _rider_list(b):
		var rid := int(raw)
		if rid >= 0 and rid < link_ride.size() and link_ride[rid] == int(b.id):
			link_ride[rid] = -1
	b.occupant = -1
	b.bath_t = -1.0
	b.guests = []
	b.away = []
	b.riders = []
	b.ride_slot = {}
	b.ride_age = {}
	b.lifted = true
	b.active = false
	_unbind_building(b)


func _deflesh(id: int, count_use: bool) -> void:
	if id < 0 or id >= slot_count or state[id] == Catalog.ST_VACANT:
		return
	var x := pos_x[id]
	var y := pos_y[id]
	var was_living := state[id] == Catalog.ST_LIVING
	var was_dead := state[id] == Catalog.ST_DEAD
	_release_mine_job(id)
	_release_claim(id)
	_release_item_claims(id)
	_drop_carried(id)
	_clear_ride(id)
	if was_living:
		living -= 1
		deaths_total += 1
		_living_remove(id)
	elif was_dead:
		dead_n = maxi(0, dead_n - 1)
		_dead_remove(id)
	if id < bloody.size():
		bloody[id] = 0
	state[id] = Catalog.ST_VACANT
	_hash_unlink(id)
	var bone_it := _add_item(Catalog.ITEM_BONE, x, y, 1)
	item_physics.launch_item(bone_it, 6.0, randf_range(80.0, 110.0), randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	_pop(x, y, ThrongClips.frame_at("ThrongA_Bones", 0))
	if was_living:
		_pulse_react_near(x, y, id)
	if count_use and part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")
	sfx_queue.append("deflesh")
	if was_living and living <= 0:
		_enter_game_over()


func _swarm(x: float, y: float) -> void:
	var ids := query_radius(x, y, Catalog.SWARM_RADIUS)
	for id in ids:
		if state[int(id)] != Catalog.ST_VACANT:
			_deflesh(int(id), false)
	if part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")


func _nuke(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if not chunks.has(ck):
		return
	var tiles: PackedByteArray = chunks[ck].tiles
	var base: PackedByteArray = chunks[ck].base
	for i in tiles.size():
		var tile := int(tiles[i])
		if tile == Catalog.TILE_GOO or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_MOUNTAIN:
			var restore := int(base[i])
			if restore == Catalog.TILE_GOO or restore == Catalog.TILE_RUBBLE or restore == Catalog.TILE_MOUNTAIN:
				restore = Catalog.TILE_DIRT
			tiles[i] = restore
			base[i] = restore
	for feat in features:
		if feat.dead:
			continue
		if int(feat.cx) == cx and int(feat.cy) == cy and int(feat.kind) != Catalog.FEAT_MONOLITH:
			_kill_feature(feat)
	for it in items:
		if it.dead or it.held:
			continue
		var ic := _chunk_at(float(it.x), float(it.y))
		if ic.x == cx and ic.y == cy and int(it.kind) != Catalog.ITEM_TNT:
			it.dead = true
	for i in slot_count:
		if state[i] != Catalog.ST_DEAD:
			continue
		var cc := _chunk_at(pos_x[i], pos_y[i])
		if cc.x == cx and cc.y == cy:
			_vacate(i)
	goo_count = _count_goo()
	_mark_dirty(ck)
	var mid := float(cx * Catalog.CHUNK + Catalog.CHUNK / 2) * float(Catalog.TILE)
	_pop(mid, float(cy * Catalog.CHUNK + Catalog.CHUNK / 2) * float(Catalog.TILE), Catalog.ICON_FX_BOOM)
	notes.append("EL SECTOR QUEDA LIMPIO. LA COLONIA SIGUE.")
	sfx_queue.append("nuke")
	sfx_queue.append("nuked")


func _splash_kill(x: float, y: float, radius: float) -> void:
	var ids := query_radius(x, y, radius)
	var any := false
	for id in ids:
		if state[int(id)] == Catalog.ST_LIVING:
			_become_corpse(int(id), true)
			any = true
	if any:
		sfx_queue.append("bones")
		_reflect("tool")


func _die_neglect(i: int) -> void:
	_become_corpse(i, false)
	sfx_queue.append("bones")
	_reflect("neglect")


func _become_corpse(i: int, with_blood: bool = false) -> void:
	if state[i] != Catalog.ST_LIVING:
		return
	var x := pos_x[i]
	var y := pos_y[i]
	state[i] = Catalog.ST_DEAD
	living -= 1
	dead_n += 1
	deaths_total += 1
	starve[i] = CORPSE_LIFE
	_ensure_agent_timers(i)
	bloody[i] = 1 if with_blood else 0
	_living_remove(i)
	_dead_add(i)
	_set_carry(i, Catalog.CARRY_NONE)
	if absf(dir_x[i]) < 0.01:
		dir_x[i] = 1.0
	else:
		dir_x[i] = 1.0 if dir_x[i] >= 0.0 else -1.0
	dir_y[i] = 0.0
	_release_mine_job(i)
	_release_claim(i)
	_release_item_claims(i)
	_clear_ride(i)
	_pulse_react_near(x, y, i)
	if living <= 0:
		_enter_game_over()


func _pulse_react_near(x: float, y: float, skip: int = -1) -> void:
	for id in query_radius(x, y, REACT_KILL_R):
		var j := int(id)
		if j == skip or j < 0 or j >= slot_count:
			continue
		if state[j] != Catalog.ST_LIVING:
			continue
		_ensure_agent_timers(j)
		react_t[j] = REACT_DUR


func has_living_peer(i: int, radius: float = PEER_R) -> bool:
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	for id in query_radius(pos_x[i], pos_y[i], radius):
		var j := int(id)
		if j != i and j >= 0 and j < slot_count and state[j] == Catalog.ST_LIVING:
			return true
	return false


func is_mining(i: int) -> bool:
	# Guest of a mine / mine2 — dig stay uses Pickaxe ↔ Twiddle.
	if i < 0 or i >= link_guest.size():
		return false
	var bid := int(link_guest[i])
	if bid < 0:
		return false
	var b: Dictionary = building_by_id.get(bid, {})
	if b.is_empty() or b.dead:
		return false
	return _is_mine_kind(int(b.kind))


func _peer_content(i: int) -> bool:
	return fed[i] >= Catalog.NEED_OK and amused[i] >= Catalog.NEED_OK and clean[i] >= Catalog.NEED_OK


func _peer_free(i: int) -> bool:
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	if act[i] != 0 or carry[i] != Catalog.CARRY_NONE:
		return false
	if mito_t[i] > 0.0 or mito_charge[i] > 0.0:
		return false
	if i < peer_t.size() and peer_t[i] > 0.0:
		return false
	if i < sleep_t.size() and sleep_t[i] > 0.0:
		return false
	if i < cheer_t.size() and cheer_t[i] > 0.0:
		return false
	if i < react_t.size() and react_t[i] > 0.0:
		return false
	if i < link_guest.size() and link_guest[i] >= 0:
		return false
	if i < link_tub.size() and link_tub[i] >= 0:
		return false
	if i < link_ride.size() and link_ride[i] >= 0:
		return false
	return true


func _nearest_peer_partner(i: int) -> int:
	var best := -1
	var best_d := PEER_R
	for id in query_radius(pos_x[i], pos_y[i], PEER_R):
		var j := int(id)
		if j == i or j < 0 or j >= slot_count:
			continue
		if not _peer_free(j) or not _peer_content(j):
			continue
		var d := _dist_i(i, pos_x[j], pos_y[j])
		if d < best_d:
			best_d = d
			best = j
	return best


func _try_peer_social(i: int) -> bool:
	# Content thronglets stop, face a free peer, and hold a talk/sing beat.
	_ensure_agent_timers(i)
	if not _peer_free(i) or not _peer_content(i):
		return false
	# Sparse attempts so the colony does not freeze in chat clusters.
	if ((frame_i + i) % 75) != 0 or randf() > 0.35:
		return false
	var j := _nearest_peer_partner(i)
	if j < 0:
		return false
	_ensure_agent_timers(j)
	var sing := 1 if randf() < 0.55 else 0
	peer_t[i] = PEER_DUR
	peer_t[j] = PEER_DUR
	peer_of[i] = j
	peer_of[j] = i
	peer_sing[i] = sing
	peer_sing[j] = sing
	dir_x[i] = 0.0
	dir_y[i] = 0.0
	dir_x[j] = 0.0
	dir_y[j] = 0.0
	if i < seek_t.size():
		seek_t[i] = 0.0
	if j < seek_t.size():
		seek_t[j] = 0.0
	return true


func _clear_peer_social(i: int) -> void:
	if i < 0 or i >= peer_t.size():
		return
	var j := int(peer_of[i]) if i < peer_of.size() else -1
	peer_t[i] = 0.0
	peer_of[i] = -1
	if i < peer_sing.size():
		peer_sing[i] = 0
	if j >= 0 and j < peer_of.size() and int(peer_of[j]) == i:
		peer_t[j] = 0.0
		peer_of[j] = -1
		if j < peer_sing.size():
			peer_sing[j] = 0


func near_fire(i: int, radius: float = 48.0) -> bool:
	if i < 0 or i >= slot_count:
		return false
	for feat in fires:
		if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
			continue
		if _dist_i(i, float(feat.x), float(feat.y)) < radius:
			return true
	return false


func approaching_home(i: int) -> bool:
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	if link_guest[i] >= 0:
		return false
	for b in blds_home:
		if b.dead:
			continue
		if _dist_i(i, float(b.x), float(b.y)) < 88.0:
			return true
	return false


func _tick_corpses(dt: float) -> void:
	if dead_ids.is_empty():
		return
	var k := 0
	while k < dead_ids.size():
		var id := int(dead_ids[k])
		if id < 0 or id >= slot_count or state[id] != Catalog.ST_DEAD:
			_dead_remove_at(k)
			continue
		starve[id] = maxf(0.0, starve[id] - dt)
		if starve[id] <= 0.0:
			_vacate(id)
			continue
		k += 1


func _dead_add(i: int) -> void:
	dead_ids.append(i)


func _dead_remove(i: int) -> void:
	for k in dead_ids.size():
		if int(dead_ids[k]) == i:
			_dead_remove_at(k)
			return


func _dead_remove_at(k: int) -> void:
	var last := dead_ids.size() - 1
	if k < 0 or k > last:
		return
	dead_ids[k] = dead_ids[last]
	dead_ids.resize(last)


func _vacate(i: int) -> void:
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return
	var was_living := state[i] == Catalog.ST_LIVING
	var was_dead := state[i] == Catalog.ST_DEAD
	if was_living:
		living -= 1
		_living_remove(i)
	elif was_dead:
		dead_n = maxi(0, dead_n - 1)
		_dead_remove(i)
	_set_carry(i, Catalog.CARRY_NONE)
	if i < bloody.size():
		bloody[i] = 0
	state[i] = Catalog.ST_VACANT
	_release_mine_job(i)
	_release_claim(i)
	_release_item_claims(i)
	_clear_ride(i)
	_hash_unlink(i)
	if was_living and living <= 0:
		_enter_game_over()


func _enter_game_over() -> void:
	if sandbox_mode or game_over or living > 0 or peak <= 0:
		return
	game_over = true
	paused = true
	frozen = false
	modal = {}
	talk_pending = {}
	gaze_queue.clear()
	cancel_hold()
	notes.append("EL ULTIMO MULTI HA MUERTO.")


func _confirm(event: String, action: Dictionary) -> void:
	# Sandbox has no ethics dialogue; apply destructive tools immediately.
	if sandbox_mode:
		if not action.is_empty():
			_apply_action(action)
		return
	if not Catalog.GAZE.has(event):
		return
	var prev := _ethics_choice(event)
	var allow: Array = Catalog.GAZE[event].allow
	if prev != -1 and allow.has(prev):
		_apply_action(action)
		notes.append("EL THRONG LO HA NOTADO.")
		return
	_queue_talk(event, action)


func _reflect(event: String) -> void:
	if _ethics_choice(event) != -1:
		return
	_queue_talk(event, {})


func _queue_talk(event: String, action: Dictionary) -> void:
	if sandbox_mode or game_over or not Catalog.GAZE.has(event):
		return
	if _ethics_choice(event) != -1 and action.is_empty():
		return
	for pending in gaze_queue:
		if str(pending.event) == event:
			return
	if not modal.is_empty() and str(modal.event) == event:
		return
	if not talk_pending.is_empty() and str(talk_pending.event) == event:
		return
	if modal.is_empty() and talk_pending.is_empty():
		_schedule_talk(event, action)
	else:
		gaze_queue.append({"event": event, "action": action})


func _open_next_talk() -> void:
	while not gaze_queue.is_empty():
		var next: Dictionary = gaze_queue.pop_front()
		var event := str(next.event)
		if _ethics_choice(event) != -1 and (next.action is Dictionary and next.action.is_empty()) and event != "ambient":
			continue
		var tree_id := str(next.get("tree", ""))
		if tree_id != "":
			_schedule_talk_tree(event, next.action if next.action is Dictionary else {}, tree_id)
		else:
			_schedule_talk(event, next.action if next.action is Dictionary else {})
		return


func _schedule_talk(event: String, action: Dictionary) -> void:
	var wait := 0.0 if testing else TALK_OPEN_DELAY
	if wait <= 0.0:
		_open_talk_modal(event, action)
		return
	talk_pending = {"event": event, "action": action, "wait": wait}


func _tick_talk_wait(delta: float) -> void:
	if talk_pending.is_empty() or not modal.is_empty() or frozen or game_over:
		return
	talk_pending.wait = maxf(0.0, float(talk_pending.wait) - delta)
	if float(talk_pending.wait) > 0.0:
		return
	var event := str(talk_pending.event)
	var action: Dictionary = talk_pending.action if talk_pending.action is Dictionary else {}
	var tree_id := str(talk_pending.get("tree", ""))
	talk_pending = {}
	_open_talk_modal(event, action, tree_id)


func _advance_lines() -> void:
	var lines: Array = modal.get("lines", [])
	var at := int(modal.get("line", 0)) + 1
	sfx_queue.append("ui")
	if at < lines.size():
		modal["line"] = at
		modal["seq"] = at + 1
		var log: Array = modal.get("log", [])
		log.append("> " + str(lines[at]))
		modal["log"] = log
		return
	var event := str(modal.event)
	var action: Dictionary = modal.action if modal.action is Dictionary else {}
	var label := str(lines[0]) if not lines.is_empty() else ""
	_set_ethics(event, 0, label)
	modal = {}
	frozen = false
	_restore_gaze()
	var allow: Array = Catalog.GAZE[event].get("allow", [])
	if allow.has(0) and not action.is_empty():
		_apply_action(action)
	_open_next_talk()


func _open_talk_modal(event: String, action: Dictionary, tree_override: String = "") -> void:
	var gaze: Dictionary = Catalog.GAZE.get(event, {})
	var confirm := str(gaze.get("kind", "")) == "confirm" or tree_override.begins_with("confirm")
	var opened: Dictionary = {}
	if tree_override != "":
		opened = DialogueBook.open_tree(tree_override)
	elif not confirm:
		opened = DialogueBook.open_session(event)
	if not opened.is_empty() and not DialogueBook.choices_of(opened).is_empty():
		_open_tree_modal(event, action, opened)
		return
	if not confirm:
		var lines: Array = LineBook.lines_for(event)
		if not lines.is_empty():
			modal = {
				"event": event,
				"action": action,
				"lines": lines,
				"line": 0,
				"log": ["> " + str(lines[0])],
				"seq": 1,
				"tree": "",
				"node": "",
			}
			_begin_gaze()
			return
	if opened.is_empty():
		if tree_override != "":
			opened = DialogueBook.open_tree(tree_override)
		else:
			opened = DialogueBook.open_session(event)
	if opened.is_empty():
		return
	_open_tree_modal(event, action, opened)


func _open_tree_modal(event: String, action: Dictionary, opened: Dictionary) -> void:
	modal = {
		"event": event,
		"action": action,
		"tree": opened.tree,
		"node": opened.node,
		"log": opened.log,
		"seq": opened.seq,
	}
	_begin_gaze()


func _queue_ambient_talk() -> void:
	# World bubbles are icon-only; ambient lines stay in the console / gaze path.
	if game_over or testing or living <= 0 or not modal.is_empty() or not talk_pending.is_empty():
		return
	ambient_n += 1


func _schedule_talk_tree(event: String, action: Dictionary, tree_id: String) -> void:
	var wait := 0.0 if testing else TALK_OPEN_DELAY
	if wait <= 0.0:
		_open_talk_modal(event, action, tree_id)
		return
	talk_pending = {"event": event, "action": action, "wait": wait, "tree": tree_id}


func _begin_gaze() -> void:
	# Dialogue freeze only — do not force glitch_t (that drove POSSESSED on every talk).
	# Screen/body glitch stays for monolith / late package paths that set glitch_t themselves.
	frozen = true
	_clear_action_motion()
	_line_up_gaze()
	sfx_queue.append("talk")


func _line_up_gaze() -> void:
	_restore_gaze()
	var focus := _gaze_clearing()
	var ids: Array = []
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING:
			ids.append(i)
	ids.sort_custom(func(a, b):
		var da := Vector2(pos_x[int(a)], pos_y[int(a)]).distance_squared_to(focus)
		var db := Vector2(pos_x[int(b)], pos_y[int(b)]).distance_squared_to(focus)
		return da < db
	)
	var placed := 0
	for raw in ids:
		if placed >= 8:
			break
		var i := int(raw)
		var here_x := pos_x[i]
		var here_y := pos_y[i]
		var spot := _gaze_spot(focus, placed % 4, int(placed / 4))
		if is_inf(spot.x) or _blocked(spot.x, spot.y):
			spot = _safe_gaze_spot(focus, here_x, here_y)
		if is_inf(spot.x) or _blocked(spot.x, spot.y):
			continue
		pos_x[i] = spot.x
		pos_y[i] = spot.y
		dir_x[i] = 0.0
		dir_y[i] = 1.0
		gaze_home[i] = Vector2(here_x, here_y)
		placed += 1
	_tick_barks(0.0, false)


func _gaze_clearing() -> Vector2:
	var seed := view_rect.get_center()
	if view_rect.size == Vector2.ZERO:
		seed = Vector2(256, 256)
	var best := seed
	var best_score := -1
	for ring in 10:
		var rays := 1 if ring == 0 else 8
		for corner in rays:
			var ang := float(corner) * TAU / float(maxi(rays, 1))
			var at := seed + Vector2(cos(ang), sin(ang)) * float(ring) * 28.0
			if _blocked(at.x, at.y):
				continue
			var score := 0
			for col in 4:
				for row in 2:
					var probe := at + Vector2((float(col) - 1.5) * 22.0, 36.0 + float(row) * 18.0)
					if _blocked(probe.x, probe.y) or _gaze_covered(probe.x, probe.y):
						continue
					score += 1
			if score > best_score:
				best_score = score
				best = at
				if score >= 8:
					return best
	return best


func _gaze_spot(focus: Vector2, col: int, row: int) -> Vector2:
	var base := focus + Vector2((float(col) - 1.5) * 22.0, 36.0 + float(row) * 18.0)
	var fallback := Vector2(INF, INF)
	for step in 24:
		for side in [-1, 0, 1]:
			var at := base + Vector2(float(side) * 14.0 + float(step) * 6.0, float(step) * 12.0)
			if _blocked(at.x, at.y) or _gaze_taken(at.x, at.y):
				continue
			if is_inf(fallback.x):
				fallback = at
			if not _gaze_covered(at.x, at.y):
				return at
	return fallback


func _safe_gaze_spot(focus: Vector2, here_x: float, here_y: float) -> Vector2:
	var seeds: Array[Vector2] = [focus, Vector2(here_x, here_y)]
	for seed in seeds:
		if not _blocked(seed.x, seed.y) and not _gaze_taken(seed.x, seed.y):
			return seed
		for ring in 24:
			var rays := 8
			for corner in rays:
				var ang := float(corner) * TAU / float(rays)
				var at := seed + Vector2(cos(ang), sin(ang)) * float(ring + 1) * 12.0
				if _blocked(at.x, at.y) or _gaze_taken(at.x, at.y):
					continue
				return at
	return Vector2(INF, INF)


func _gaze_taken(x: float, y: float) -> bool:
	var at := Vector2(x, y)
	for key in gaze_home.keys():
		var i := int(key)
		if i < 0 or i >= slot_count:
			continue
		if Vector2(pos_x[i], pos_y[i]).distance_squared_to(at) < 144.0:
			return true
	return false


func _iso_of(x: float, y: float) -> Vector2:
	var cell := Vector2(x, y) / float(Catalog.TILE) - Vector2(0.5, 0.5)
	return Vector2(16.0 * (1.0 + cell.x - cell.y), 8.0 * (1.0 + cell.x + cell.y))


func _gaze_covered(x: float, y: float) -> bool:
	var me := _iso_of(x, y)
	var body := Rect2(me.x - 12.0, me.y - 22.0, 24.0, 22.0)
	var c0 := _cell_vec(x - 80.0, y - 48.0)
	var c1 := _cell_vec(x + 176.0, y + 176.0)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var feat = feature_by_id.get(int(feature_cell.get(Vector2i(cx, cy), -1)), {})
			if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
				continue
			if int(feat.kind) != Catalog.FEAT_TREE:
				continue
			if _canopy_hits(me, body, float(feat.x), float(feat.y), 32.0, 62.0):
				return true
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if _canopy_hits(me, body, float(b.x), float(b.y), 32.0, 62.0):
			return true
	return false


func _canopy_hits(me: Vector2, body: Rect2, x: float, y: float, half_w: float, height: float) -> bool:
	var base := _iso_of(x, y)
	if base.y + 2.0 < me.y:
		return false
	var canopy := Rect2(base.x - half_w, base.y - height, half_w * 2.0, height)
	return canopy.intersects(body)


func _axe_feature_at(x: float, y: float) -> Dictionary:
	var feat := _feature_at(x, y, 14.0)
	var kind := int(feat.get("kind", -1))
	if kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		return feat
	var canopy := _canopy_feature_at(x, y)
	if not canopy.is_empty():
		return canopy
	return feat


func _canopy_feature_at(x: float, y: float) -> Dictionary:
	var tip := _iso_of(x, y)
	var body := Rect2(tip.x - 2.0, tip.y - 2.0, 4.0, 4.0)
	var best := {}
	var best_base_y := -1.0e9
	var c0 := _cell_vec(x - 64.0, y - 64.0)
	var c1 := _cell_vec(x + 96.0, y + 96.0)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var feat = feature_by_id.get(int(feature_cell.get(Vector2i(cx, cy), -1)), {})
			if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
				continue
			var kind := int(feat.kind)
			if kind != Catalog.FEAT_TREE and kind != Catalog.FEAT_COSMETIC and kind != Catalog.FEAT_COSMETIC_BAD:
				continue
			if not _canopy_hits(tip, body, float(feat.x), float(feat.y), 32.0, 62.0):
				continue
			var base_y := _iso_of(float(feat.x), float(feat.y)).y
			if base_y >= best_base_y:
				best_base_y = base_y
				best = feat
	return best


func _restore_gaze() -> void:
	for key in gaze_home.keys():
		var i := int(key)
		if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
			continue
		var home: Vector2 = gaze_home[key]
		pos_x[i] = home.x
		pos_y[i] = home.y
	gaze_home.clear()
	_tick_barks(0.0, false)


func _clear_wash_all() -> void:
	_clear_action_motion()


func _clear_action_motion() -> void:
	sponge_id = -1
	sponge_hold = 0.0
	for i in slot_count:
		shake_t[i] = 0.0
		act[i] = 0
		act_t[i] = 0.0


func _ethics_choice(event: String) -> int:
	var found := -1
	for entry in ethics:
		if str(entry.event) == event:
			found = int(entry.choice)
	return found


func _set_ethics(event: String, index: int, text: String) -> void:
	for entry in ethics:
		if str(entry.event) == event:
			entry.choice = index
			entry.text = text
			return
	ethics.append({"event": event, "choice": index, "text": text})


func _apply_moral_edge(edge: Dictionary) -> void:
	if edge.has("moral"):
		moral = clampi(moral + int(edge.moral), -5, 5)
	var flag := str(edge.get("mutate", ""))
	if flag != "":
		mutations[flag] = true
		if flag == "adapt":
			notes.append("ALGUNOS NACEN CON TONO MORADO.")
		elif flag == "numb":
			notes.append("SUS OJOS SE VUELVEN FRIOS.")
		elif flag == "hard":
			notes.append("LA COLONIA SE ENDURECE.")
		elif flag == "fuel":
			notes.append("APRENDEN A VER ENERGIA EN TODO.")
		elif flag == "care":
			notes.append("RECUERDAN QUE LOS CUIDAS.")
		elif flag == "short_rest":
			notes.append("PASAN MENOS TIEMPO EN LAS VIVIENDAS.")


func _decay_scale() -> float:
	if _decay_scale_frame == frame_i:
		return _decay_scale_cached
	var scale := 1.0
	if bool(mutations.get("care", false)) or moral > 0:
		scale *= 0.9
	if bool(mutations.get("hard", false)) or bool(mutations.get("numb", false)) or moral < 0:
		scale *= 1.12
	_decay_scale_frame = frame_i
	_decay_scale_cached = scale
	return scale


func _birth_tint(fallback: int) -> int:
	if bool(mutations.get("adapt", false)) and randf() < 0.55:
		return Catalog.TINT_ADAPT
	if bool(mutations.get("numb", false)) and randf() < 0.45:
		return Catalog.TINT_NUMB
	if bool(mutations.get("hard", false)) and randf() < 0.35:
		return Catalog.TINT_NUMB
	return fallback % Catalog.TINTS.size()


func _grant(key: String, message: String = "", talk: bool = true) -> bool:
	if bool(unlocks.get(key, false)):
		return false
	unlocks[key] = true
	unlock_serial += 1
	celebrate_t = CELEBRATE_DUR
	sfx_queue.append("unlock_" + key)
	if talk and Catalog.UNLOCK_TALK.has(key):
		_queue_talk(str(Catalog.UNLOCK_TALK[key]), {})
	elif message != "":
		notes.append(message)
	return true


func _refresh_pop_gates(announce: bool = true) -> void:
	ProgressionManager.evaluate_unlocks(self, announce)
	if sandbox_mode:
		return
	ProgressionManager.apply_progression_hooks(self, announce)


func _expand_super_island(announce: bool = true) -> void:
	island_gen.expand_super_island(announce)


func _milestone_defs() -> Array:
	return [
		{"kind": "pop", "n": 6},
		{"kind": "pop", "n": 12},
		{"kind": "expand", "n": 0},
		{"kind": "gem", "n": 20},
		{"kind": "pop", "n": 30},
		{"kind": "gem", "n": 20},
		{"kind": "pop", "n": 40},
		{"kind": "gem", "n": 500},
	]


func _milestone_at(tier: int) -> Dictionary:
	var defs := _milestone_defs()
	if tier < defs.size():
		return defs[tier]
	var n_base := tier - 7
	if (tier - 8) % 2 == 0:
		return {"kind": "pop", "n": 40 + n_base * 10}
	return {"kind": "gem", "n": 20 + n_base * 25}


func _milestone_met(step: Dictionary) -> bool:
	var kind := str(step.kind)
	if kind == "pop":
		return peak >= int(step.n)
	if kind == "gem":
		return gems_peak >= int(step.n)
	if kind == "expand":
		return part_two
	return false


func _check_milestones(announce: bool = true) -> void:
	if gems > gems_peak:
		gems_peak = gems
	total_gems_earned = maxi(total_gems_earned, gems_peak)
	if sandbox_mode:
		return
	if peak >= 25:
		var mono1 := false
		for feat in features:
			if not feat.dead and int(feat.kind) == Catalog.FEAT_MONOLITH and int(feat.get("ore", 0)) == 1:
				mono1 = true
				break
		var bug := bool(unlocks.get("bug", false))
		var spawned1 := bool(monolith_tier_spawned.get(1, false))
		# Migración/reparación: bug huérfano de progresión antigua o monolito marcado sin entidad.
		if bug and not spawned1:
			unlocks["bug"] = false
			bug = false
		if spawned1 and not bug and not mono1:
			monolith_tier_spawned.erase(1)
		_ensure_monolith(1)
	var grew := false
	var guard := 0
	while _milestone_met(_milestone_at(land_tier)) and guard < 64:
		land_tier += 1
		grew = true
		guard += 1
	ProgressionManager.evaluate_unlocks(self, announce)
	if not grew:
		return
	var added := _shape_island()
	if announce and added > 0:
		notes.append("LA ISLA CRECE.")


func goal_line() -> String:
	if sandbox_mode:
		return "SANDBOX  ISLA %d" % land_tier
	if living <= 0 and _has_egg():
		return "AYUDA AL HUEVO A ECLOSIONAR"
	if peak < 2:
		return "CUIDA: COMIDA, LIMPIEZA Y JUEGO HASTA LA MITOSIS"
	if not bool(unlocks.get("axe", false)):
		return "CRECE LA COLONIA  %d/6" % mini(peak, 6)
	if trees_chopped <= 0:
		return "TALA UN ARBOL CON EL HACHA"
	if stumps_cleared <= 0:
		return "QUITA EL TOCON CON EL MARTILLO"
	if not _has_building(Catalog.BLD_TUB):
		return _goal_build("CONSTRUYE UNA BANERA", int(Catalog.BUILD_INFO[Catalog.BLD_TUB].wood))
	if not _has_building(Catalog.BLD_APPLE):
		return _goal_build("PLANTA UN MANZANO", int(Catalog.BUILD_INFO[Catalog.BLD_APPLE].wood))
	if not _has_building(Catalog.BLD_ROUND):
		return _goal_build("COLOCA UN TIOVIVO", int(Catalog.BUILD_INFO[Catalog.BLD_ROUND].wood))
	if peak < 12:
		return "CRECE LA COLONIA  %d/12" % mini(peak, 12)
	if not part_two:
		return "HAZ CRECER LA COLONIA PARA EXPANDIR LA ISLA"
	var sand := _sandbox_goal()
	if sand != "":
		return sand
	var step: Dictionary = _milestone_at(land_tier)
	var kind := str(step.kind)
	var n := int(step.n)
	if kind == "pop":
		return "EXPANDE  %d/%d MULTIS" % [mini(peak, n), n]
	if kind == "gem":
		if bool(unlocks.get("mine", false)) and count_item(Catalog.ITEM_ORE) > 0:
			return "JUNTA ENERGIA  %d/%d  (MARTILLO EN EL MINERAL)" % [mini(gems_peak, n), n]
		if n >= 100 and bool(unlocks.get("mine", false)):
			return "JUNTA ENERGIA  %d/%d  (MINA EN NODO → MARTILLO EN MINERAL)" % [mini(gems_peak, n), n]
		return "JUNTA ENERGIA  %d/%d  (MARTILLO: ROCA → MINERAL)" % [mini(gems_peak, n), n]
	if kind == "expand":
		return "HAZ CRECER LA COLONIA PARA EXPANDIR LA ISLA"
	return "EXPANSION LIBRE  %d MULTIS · %d ENERGIA" % [living, gems]


func _sandbox_goal() -> String:
	# Building goals only; land growth keeps using milestones forever.
	if not _has_building(Catalog.BLD_MARKET):
		return _goal_build("COLOCA EL MERCADO", int(Catalog.BUILD_INFO[Catalog.BLD_MARKET].wood))
	if not _has_factory():
		if not bool(unlocks.get("factory", false)):
			var need := int(Catalog.MARKET.factory.cost)
			return "COMPRA LA FABRICA  %d/%d ENERGIA" % [mini(gems, need), need]
		return _goal_place("CONSTRUYE UNA FABRICA", "factory")
	if not bool(unlocks.get("theatre", false)):
		var need_t := int(Catalog.MARKET.theatre.cost)
		return "COMPRA EL TEATRO  %d/%d ENERGIA" % [mini(gems, need_t), need_t]
	if not _has_building(Catalog.BLD_THEATRE):
		return _goal_place("CONSTRUYE EL TEATRO", "theatre")
	if not bool(unlocks.get("factory2", false)):
		var need_f2 := int(Catalog.MARKET.factory2.cost)
		return "COMPRA FABRICA II  %d/%d ENERGIA" % [mini(gems, need_f2), need_f2]
	return ""


func _goal_build(label: String, cost: int) -> String:
	if cost <= 0:
		return label
	var have := count_item(Catalog.ITEM_WOOD)
	if have < cost:
		return "TALA MADERA  %d/%d  LUEGO %s" % [have, cost, label]
	return "%s  (%d MADERA)" % [label, cost]


func _goal_place(label: String, unlock_id: String) -> String:
	var cost := ProgressionManager.placement_cost(self, unlock_id)
	var resource := str(cost.get("resource", ""))
	var amount := int(cost.get("amount", 0))
	if amount <= 0 or resource == "":
		return label
	if resource == "gem":
		if gems < amount:
			return "JUNTA ENERGIA  %d/%d  LUEGO %s" % [gems, amount, label]
		return "%s  (%d ENERGIA)" % [label, amount]
	if resource == "wood":
		return _goal_build(label, amount)
	return label


func _building_costs(kind: int) -> Dictionary:
	var wood_cost := 0
	var gem_cost := 0
	if sandbox_mode:
		return {"wood": 0, "gem": 0}
	if not Catalog.BUILD_INFO.has(kind):
		return {"wood": 0, "gem": 0}
	var info: Dictionary = Catalog.BUILD_INFO[kind]
	wood_cost = int(info.wood)
	var cost := ProgressionManager.placement_cost(self, str(info.unlock))
	if str(cost.get("resource", "")) == "gem":
		gem_cost = int(cost.get("amount", 0))
	elif str(cost.get("resource", "")) == "wood":
		wood_cost = int(cost.get("amount", 0))
	return {"wood": wood_cost, "gem": gem_cost}


func _can_afford_building(kind: int) -> bool:
	var costs := _building_costs(kind)
	if int(costs.gem) > 0 and gems < int(costs.gem):
		return false
	if int(costs.wood) > 0 and count_item(Catalog.ITEM_WOOD) < int(costs.wood):
		return false
	return true


func _enter_part_two(reason: String, talk_market: bool = true) -> void:
	var first := not part_two
	part_two = true
	_grant("market", "", talk_market)
	_grant("flower", "", false)
	_grant("sculpture", "", false)
	if first:
		_seed_early_ore(6)
		notes.append("EL MERCADO ESTA LISTO. COMPRA EL PICO Y LO DEMAS ALLI.")
		if reason != "":
			notes.append(reason)
	_check_milestones()


func _seed_early_ore(want: int = 12) -> void:
	if want <= 0:
		return
	var placed := 0
	var c := Vector2i(0, 0)
	var ck := _ck(c.x, c.y)
	if not chunks.has(ck):
		_ensure(c.x, c.y)
	var tiles = chunks[ck].tiles
	for _try in 120:
		if placed >= want:
			break
		var lx := randi() % Catalog.CHUNK
		var ly := randi() % Catalog.CHUNK
		var tile := int(tiles[ly * Catalog.CHUNK + lx])
		if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER:
			continue
		var wx := float((c.x * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy := float((c.y * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		if _blocked(wx, wy):
			continue
		if _near_spawn(wx, wy):
			continue
		if not _feature_at(wx, wy, 14.0).is_empty():
			continue
		if not _building_at(wx, wy, 14.0).is_empty():
			continue
		var feat := _add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 3, true)
		if not feat.is_empty():
			placed += 1


func _ensure_monolith(tier: int) -> void:
	if bool(monolith_tier_spawned.get(tier, false)):
		return
	if tier == 1 and bool(unlocks.get("bug", false)):
		return
	if tier == 2 and bool(unlocks.get("nuke", false)):
		return
	var x := 168.0 + float(tier) * 78.0
	var y := 168.0
	if _blocked(x, y):
		x = 256.0
		y = 150.0 + float(tier) * 20.0
	var feat := _add_feature(Catalog.FEAT_MONOLITH, x, y, 4, tier)
	if feat.is_empty():
		return
	monolith_tier_spawned[tier] = true
	feat.spawn_progress = 0.0
	feat.spawn_dur = 1.4
	feat.age = 0.0
	feat.triggered = false
	feat.particle_t = 0.0
	notes.append("UN MONOLITO HA APARECIDO.")
	sfx_queue.append("monolith_in")
	sfx_queue.append("monolith_reveal")
	# Cinematic reveal so the player doesn't miss it.
	if not testing and modal.is_empty() and talk_pending.is_empty() and bool(unlocks.get("monolith_reveal_cinematic", true)):
		unlocks["monolith_reveal_cinematic"] = false
		var lines: Array = LineBook.lines_for("monolith_appear")
		if lines.is_empty():
			lines = ["Un monolito emerge del suelo..."]
		modal = {
			"event": "monolith_appear",
			"action": {},
			"lines": lines,
			"line": 0,
			"log": ["> " + str(lines[0])],
			"seq": 1,
			"tree": "",
			"node": "",
			"focus_x": x,
			"focus_y": y,
		}
		frozen = true
		_begin_gaze()


func _touch_monolith(feat: Dictionary) -> void:
	if feat.is_empty() or feat.get("dead", false):
		return
	glitch_t = maxf(glitch_t, 0.75)
	var tier := int(feat.ore)
	if tier == 1:
		_grant("bug", "EL MONOLITO ENTREGA EL BICHO. ABRE UN CUERPO Y DEJA HUESO.")
	elif tier == 2:
		_grant("nuke", "EL MONOLITO ENTREGA EL TERMAL. LIMPIA UN SECTOR. LA PARTIDA SIGUE.")
	_kill_feature(feat)
	sfx_queue.append("monolith")


func _spill_goo(x: float, y: float, amount: int) -> void:
	for _n in amount:
		var ang := randf() * TAU
		var dist := randf_range(16.0, 54.0)
		var gx := x + cos(ang) * dist
		var gy := y + sin(ang) * dist
		var tile := _tile_at(gx, gy)
		if tile == Catalog.TILE_GRASS or tile == Catalog.TILE_DIRT or tile == Catalog.TILE_BLOOM:
			var cell := _cell_vec(gx, gy)
			_set_world_cell(cell.x, cell.y, Catalog.TILE_GOO, false)
			goo_count += 1
	if goo_count >= 8 and _grant("mop", "", false):
		notes.append("LA FABRICA MANCHA EL SUELO. LLEGA LA FREGONA.")
		_reflect("goo")


func _bootstrap_new() -> void:
	var keep := world_seed
	_reset_world()
	world_seed = keep
	if world_seed == 0:
		world_seed = 1
	_reveal(0, 0)
	_clear_spawn()
	_spawn_starter_egg()
	_rebuild_hash()
	session_live = true


func _bootstrap_sandbox(tier: int) -> void:
	var keep := world_seed
	_reset_world()
	sandbox_mode = true
	world_seed = keep
	if world_seed == 0:
		world_seed = 1
	land_tier = clampi(tier, SANDBOX_TIER_MIN, SANDBOX_TIER_MAX)
	_unlock_all()
	gems = SANDBOX_GEMS
	gems_peak = SANDBOX_GEMS
	total_gems_earned = SANDBOX_GEMS
	part_two = true
	tutorial_i = -1
	count_unknown = false
	_reveal(0, 0)
	_clear_spawn()
	_shape_island()
	_sandbox_strip_props()
	_rebuild_hash()
	session_live = true


func sandbox_place_prop(prop: String, x: float, y: float) -> bool:
	if not sandbox_mode or frozen:
		return false
	var at := Catalog.snap_world(x, y)
	if not revealed.has(_ck_of(at.x, at.y)):
		return false
	match prop:
		"tree":
			if Catalog.tile_blocks(_tile_at(at.x, at.y)):
				return false
			return not _add_feature(Catalog.FEAT_TREE, at.x, at.y, 1, 0, true).is_empty()
		"rock":
			if Catalog.tile_blocks(_tile_at(at.x, at.y)):
				return false
			return not _add_feature(Catalog.FEAT_ROCK, at.x, at.y, 1, 0, true).is_empty()
		"ore":
			if Catalog.tile_blocks(_tile_at(at.x, at.y)):
				return false
			return not _add_feature(Catalog.FEAT_ROCK, at.x, at.y, 2, 1, true).is_empty()
		"flower":
			return place_building(Catalog.BLD_FLOWER, at.x, at.y)
		"water":
			var cell := _cell_vec(at.x, at.y)
			var tile := _tile_at_cell(cell)
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_FOG:
				return false
			_set_world_cell(cell.x, cell.y, Catalog.TILE_WATER, true)
			var feat := _feature_at(at.x, at.y, 8.0)
			if not feat.is_empty():
				_kill_feature(feat)
			return true
		"grass":
			var cell := _cell_vec(at.x, at.y)
			var tile := _tile_at_cell(cell)
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_FOG:
				return false
			_set_world_cell(cell.x, cell.y, Catalog.TILE_GRASS, true)
			return true
		"thronglet":
			if Catalog.tile_blocks(_tile_at(at.x, at.y)) or not _land_inland(at.x, at.y):
				return false
			var tint := randi() % Catalog.TINTS.size()
			return _push_slot(at.x, at.y, 90.0, 90.0, 90.0, 8.0, tint) >= 0
		_:
			return false


func _unlock_all() -> void:
	_init_unlocks()
	for key in unlocks.keys():
		unlocks[key] = true
	for id in ProgressionCatalog.all_ids():
		unlocks[str(id)] = true
	for key in Catalog.MARKET.keys():
		unlocks[str(key)] = true
	unlocks["camera"] = true
	unlocks["flower"] = true
	unlocks["sculpture"] = true
	unlock_serial += 1


func _sandbox_strip_props() -> void:
	if not sandbox_mode:
		return
	for feat in features:
		if feat.dead:
			continue
		_kill_feature(feat)


func _spawn_starter_egg() -> void:
	var it := _add_item(Catalog.ITEM_EGG, 256.0, 256.0, 0)
	it.fixed = true
	it.air = EGG_FALL
	it.fall = 0.0
	it.hatch = 0
	it.need = EGG_NEED
	it.shake = 0.0
	notes.append("UN HUEVO CAE DEL CIELO.")
	sfx_queue.append("egg_fall")


func _help_egg(it: Dictionary) -> void:
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_EGG:
		return
	if float(it.get("air", 0.0)) > 0.0:
		return
	it.hatch = int(it.get("hatch", 0)) + 1
	it.shake = 0.35
	sfx_queue.append("egg_crack")
	if int(it.hatch) >= int(it.get("need", EGG_NEED)):
		_hatch_egg(it)
	elif int(it.hatch) == 1:
		notes.append("SIGUE TOCANDALO. QUIERE NACER.")


func _hatch_egg(it: Dictionary) -> void:
	if it.is_empty() or it.dead:
		return
	var x := float(it.x)
	var y := float(it.y)
	it.dead = true
	if hand_id == int(it.id):
		hand_id = -1
	if peak > 0 or living > 0:
		return
	var id := _push_slot(x, y, 50.0, 50.0, 50.0, 4.0, 0)
	if id >= 0:
		shake_t[id] = 0.45
	_know_count()
	sfx_queue.append("egg_hatch")
	sfx_queue.append("hatch")
	if tutorial_i < 0:
		_queue_talk("first_born", {})


func _reset_world() -> void:
	revealed.clear()
	chunks.clear()
	dirty_chunks.clear()
	features.clear()
	feature_by_id.clear()
	feature_cell.clear()
	features_by_chunk.clear()
	inland_cache.clear()
	tree_seeds.clear()
	items.clear()
	item_by_id.clear()
	buildings.clear()
	building_by_id.clear()
	building_cell.clear()
	next_feature_id = 1
	next_item_id = 1
	next_building_id = 1
	hand_id = -1
	_clear_held()
	scoop_item_ids.clear()
	scoop_dead_ids.clear()
	sponge_id = -1
	sponge_hold = 0.0
	slot_count = 0
	cursor = 0
	mood_face = "base"
	_mood_base = 0
	_mood_happy = 0
	_mood_cry = 0
	_mood_sus = 0
	_mood_freak = 0
	living = 0
	dead_n = 0
	dead_ids = PackedInt32Array()
	carry_wood_n = 0
	carry_bone_n = 0
	carry_ore_n = 0
	_invalidate_item_counts()
	peak = 0
	gems = 0
	gems_peak = 0
	total_gems_earned = 0
	deaths_total = 0
	land_tier = 0
	sandbox_mode = false
	_shaping_island = false
	special_biomes = {}
	glitch_seen = false
	glitch_t = 0.0
	gaze_home.clear()
	barks.clear()
	wash_fx_pending.clear()
	wear.clear()
	wear_from.clear()
	trees_chopped = 0
	stumps_cleared = 0
	bug_uses = 0
	tnt_used = 0
	goo_count = 0
	part_two = false
	mountain_seen = false
	cap_told = false
	frozen = false
	game_over = false
	paused = false
	autosave_t = 0.0
	modal = {}
	talk_pending = {}
	gaze_queue.clear()
	player_name = ""
	tutorial_i = -1
	count_unknown = false
	talked_trees = {}
	learn_talked = false
	moral = 0
	mutations.clear()
	monolith_tier_spawned.clear()
	pos_x = PackedFloat32Array()
	pos_y = PackedFloat32Array()
	dir_x = PackedFloat32Array()
	dir_y = PackedFloat32Array()
	fed = PackedFloat32Array()
	amused = PackedFloat32Array()
	clean = PackedFloat32Array()
	cool = PackedFloat32Array()
	starve = PackedFloat32Array()
	hungry_t = PackedFloat32Array()
	wander_t = PackedFloat32Array()
	avoid_t = PackedFloat32Array()
	mito_t = PackedFloat32Array()
	mito_charge = PackedFloat32Array()
	shake_t = PackedFloat32Array()
	buff_t = PackedFloat32Array()
	react_t = PackedFloat32Array()
	cheer_t = PackedFloat32Array()
	sleep_t = PackedFloat32Array()
	peer_t = PackedFloat32Array()
	peer_of = PackedInt32Array()
	peer_sing = PackedByteArray()
	drop_t = PackedFloat32Array()
	bloody = PackedByteArray()
	state = PackedInt32Array()
	carry = PackedInt32Array()
	carry_value = PackedInt32Array()
	tint = PackedInt32Array()
	claim = PackedInt32Array()
	mine_job = PackedInt32Array()
	act = PackedInt32Array()
	act_t = PackedFloat32Array()
	tick_stamp = PackedInt32Array()
	pops.clear()
	wash_fx_pending.clear()
	celebrate_t = 0.0
	hash_next = PackedInt32Array()
	hash_cell = PackedInt32Array()
	link_tub = PackedInt32Array()
	link_ride = PackedInt32Array()
	link_guest = PackedInt32Array()
	link_claim = PackedInt32Array()
	link_ball = PackedInt32Array()
	living_ids = PackedInt32Array()
	living_at = PackedInt32Array()
	bark_cool = PackedFloat32Array()
	penned_flag = PackedByteArray()
	fires.clear()
	items_apple.clear()
	items_ball.clear()
	items_wood.clear()
	items_bone.clear()
	items_ore.clear()
	blds_tub.clear()
	blds_round.clear()
	blds_home.clear()
	blds_mine.clear()
	blds_show.clear()
	seek_x = PackedFloat32Array()
	seek_y = PackedFloat32Array()
	seek_t = PackedFloat32Array()
	hash_head.fill(-1)
	paint_epoch += 1
	feat_mesh_epoch += 1


func _push_slot(x: float, y: float, fed_v: float, fun_v: float, clean_v: float, cool_v: float, tint_i: int) -> int:
	var id := _push_slot_quiet(x, y, fed_v, fun_v, clean_v, cool_v, tint_i)
	if id < 0:
		return -1
	if living > peak:
		peak = living
		_refresh_pop_gates()
	return id


func _push_slot_quiet(x: float, y: float, fed_v: float, fun_v: float, clean_v: float, cool_v: float, tint_i: int) -> int:
	if slot_count >= Catalog.MAX_SLOTS:
		return -1
	var ang := randf() * TAU
	pos_x.append(x)
	pos_y.append(y)
	dir_x.append(cos(ang))
	dir_y.append(sin(ang))
	fed.append(fed_v)
	amused.append(fun_v)
	clean.append(clean_v)
	cool.append(cool_v)
	starve.append(0.0)
	hungry_t.append(0.0)
	wander_t.append(randf_range(0.2, 1.2))
	avoid_t.append(0.0)
	mito_t.append(0.0)
	mito_charge.append(0.0)
	shake_t.append(0.0)
	buff_t.append(0.0)
	react_t.append(0.0)
	cheer_t.append(0.0)
	sleep_t.append(0.0)
	peer_t.append(0.0)
	peer_of.append(-1)
	peer_sing.append(0)
	drop_t.append(0.0)
	bloody.append(0)
	state.append(Catalog.ST_LIVING)
	carry.append(Catalog.CARRY_NONE)
	carry_value.append(0)
	tint.append(_birth_tint(tint_i))
	claim.append(-1)
	mine_job.append(-1)
	act.append(0)
	act_t.append(0.0)
	tick_stamp.append(0)
	hash_next.append(-1)
	hash_cell.append(-1)
	link_tub.append(-1)
	link_ride.append(-1)
	link_guest.append(-1)
	link_claim.append(-1)
	link_ball.append(-1)
	living_at.append(-1)
	bark_cool.append(0.0)
	penned_flag.append(0)
	seek_x.append(0.0)
	seek_y.append(0.0)
	seek_t.append(0.0)
	var id := slot_count
	slot_count += 1
	living += 1
	_living_add(id)
	_hash_link(id)
	return id


func _reveal(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	var fresh := not revealed.has(ck)
	revealed[ck] = true
	_ensure(cx, cy)
	if not fresh:
		return
	cap_told = false
	# Fog→land changes cliff margins on this chunk and its borders.
	inland_cache.clear()
	_invalidate_walk_cells()
	_mark_dirty(ck)


func _try_reveal(cx: int, cy: int) -> void:
	if cx == 0 and cy == 0 or _is_island_chunk(cx, cy):
		_reveal(cx, cy)


func _is_known_chunk(cx: int, cy: int) -> bool:
	return revealed.has(_ck(cx, cy))


func _ensure(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if chunks.has(ck):
		return
	var biome := _biome_formula(cx, cy)
	var tiles := _fill_tiles(cx, cy, biome)
	chunks[ck] = {"biome": biome, "axis": "", "tiles": tiles, "base": tiles.duplicate()}
	if cx == 0 and cy == 0 and not _shaping_island:
		_shape_island()
		if not sandbox_mode:
			_seed_mine_nodes(0, 0)
	if not _shaping_island and not sandbox_mode:
		_scatter(cx, cy, biome)
	_mark_dirty(ck)


func _fill_tiles(cx: int, cy: int, biome: String) -> PackedByteArray:
	var tiles := PackedByteArray()
	tiles.resize(Catalog.CHUNK * Catalog.CHUNK)
	var base := Catalog.TILE_GRASS
	if biome == "hills" or biome == "mountain":
		base = Catalog.TILE_DIRT
	elif biome == "bloom":
		base = Catalog.TILE_BLOOM
	for i in tiles.size():
		tiles[i] = Catalog.TILE_VOID
	if cx == 0 and cy == 0:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				tiles[ly * Catalog.CHUNK + lx] = base
	elif special_biomes.has(_ck(cx, cy)):
		var paint := Catalog.TILE_GRASS
		if biome == "mountain":
			paint = Catalog.TILE_DIRT
		elif biome == "glitch":
			paint = Catalog.TILE_GOO
		var mid := float(Catalog.CHUNK) * 0.5
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var dx := float(lx) - mid
				var dy := float(ly) - mid
				if dx * dx + dy * dy < mid * mid * 0.72:
					tiles[ly * Catalog.CHUNK + lx] = paint
	return tiles


func _is_island_chunk(cx: int, cy: int) -> bool:
	return island_gen.is_island_chunk(cx, cy)


func _count_mine_nodes(cx: int, cy: int) -> int:
	return island_gen.count_mine_nodes(cx, cy)


func _seed_mine_nodes(cx: int, cy: int) -> void:
	island_gen.seed_mine_nodes(cx, cy)


func _is_mine_node(kind: int) -> bool:
	return kind == Catalog.FEAT_NODE or kind == Catalog.FEAT_SUPER or kind == Catalog.FEAT_MNODE


func _feature_crowded(x: float, y: float, kind: int) -> bool:
	if _is_mine_node(kind):
		return false
	var cell := _cell_vec(x, y)
	var reach := 1 if kind == Catalog.FEAT_TREE else 2
	for oy in range(-reach, reach + 1):
		for ox in range(-reach, reach + 1):
			if ox == 0 and oy == 0:
				continue
			var key := Vector2i(cell.x + ox, cell.y + oy)
			if not feature_cell.has(key):
				continue
			var feat = feature_by_id.get(int(feature_cell[key]), {})
			if feat.is_empty() or feat.dead:
				continue
			if kind == Catalog.FEAT_TREE and int(feat.kind) == Catalog.FEAT_TREE:
				continue
			return true
	return false


func _near_mine_node(x: float, y: float) -> bool:
	var cell := _cell_vec(x, y)
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var key := Vector2i(cell.x + ox, cell.y + oy)
			if not feature_cell.has(key):
				continue
			var feat = feature_by_id.get(int(feature_cell[key]), {})
			if not feat.is_empty() and not feat.dead and _is_mine_node(int(feat.kind)):
				return true
	return false


func _fall_void(x: float, y: float) -> void:
	notes.append("SE CAE AL VACIO. LA PARTIDA SIGUE.")
	sfx_queue.append("crush")


func occupancy_text(b: Dictionary) -> String:
	var info := capacity_info(b)
	if info.is_empty():
		return ""
	if bool(info.full):
		return "LLENO"
	return ""


func _tick_props(dt: float) -> void:
	for feat in features:
		if feat.dead:
			continue
		var kind := int(feat.kind)
		if kind == Catalog.FEAT_FIRE:
			var ids := query_radius(float(feat.x), float(feat.y), 28.0)
			for raw in ids:
				var id := int(raw)
				if state[id] == Catalog.ST_LIVING:
					clean[id] = maxf(0.0, clean[id] - 8.0 * dt)
		elif kind == Catalog.FEAT_TOTEM:
			_boost(float(feat.x), float(feat.y), 32.0, 4, 0.0, 0.0, 4.0 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.FEAT_CURER:
			_boost(float(feat.x), float(feat.y), 28.0, 3, 1.5 * dt, 5.0 * dt, 0.0, 0.0, ACT_BATH)
			var healed := false
			for raw in query_radius(float(feat.x), float(feat.y), 28.0):
				if state[int(raw)] == Catalog.ST_LIVING:
					healed = true
					break
			if healed:
				feat.snd = float(feat.get("snd", 0.0)) - dt
				if float(feat.snd) <= 0.0:
					feat.snd = 5.0
					sfx_queue.append("heal")


func _tick_monoliths(dt: float, allow_touch: bool = true) -> void:
	var to_touch: Array = []
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_MONOLITH:
			continue
		if not feat.has("spawn_progress"):
			feat.spawn_progress = 1.0
		if not feat.has("spawn_dur"):
			feat.spawn_dur = 1.4
		feat.age = float(feat.get("age", 0.0)) + dt
		var dur := maxf(0.01, float(feat.spawn_dur))
		feat.spawn_progress = minf(1.0, float(feat.spawn_progress) + dt / dur)
		feat.particle_t = maxf(0.0, float(feat.get("particle_t", 0.0)) - dt)
		if not allow_touch or bool(feat.get("triggered", false)):
			continue
		if float(feat.spawn_progress) < 1.0:
			continue
		var fx := float(feat.x)
		var fy := float(feat.y)
		for raw in query_radius(fx, fy, 28.0):
			var i := int(raw)
			if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
				continue
			to_touch.append(feat)
			break
	for feat in to_touch:
		if feat.dead or bool(feat.get("triggered", false)):
			continue
		feat.triggered = true
		_touch_monolith(feat)


func _scatter_island(cx: int, cy: int) -> void:
	island_gen.scatter_island(cx, cy)


func _count_kind_on(cx: int, cy: int, kind: int) -> int:
	return island_gen.count_kind_on(cx, cy, kind)


func _scatter_one(cx: int, cy: int, wx: float, wy: float, lx: int, ly: int) -> void:
	var roll := _rand(cx, cy, lx, ly, 31)
	if roll < 0.008:
		_add_feature(Catalog.FEAT_COSMETIC, wx, wy, 1, 0, true)
	elif roll < 0.012:
		_add_feature(Catalog.FEAT_COSMETIC_BAD, wx, wy, 1, 0, true)
	elif roll < 0.016:
		_add_feature(Catalog.FEAT_BIGROCK, wx, wy, 4, 1, true)
	elif roll < 0.019:
		_add_feature(Catalog.FEAT_ORE_MEGA, wx, wy, 1, 3, true)
	elif roll < 0.021:
		_add_feature(Catalog.FEAT_ORE_SUPER, wx, wy, 1, 4, true)
	elif roll < 0.023:
		_add_feature(Catalog.FEAT_ORE_ULTRA, wx, wy, 1, 5, true)
	elif roll < 0.026:
		if not _add_feature(Catalog.FEAT_FIRE, wx, wy, 1, 0, true).is_empty() and session_live:
			sfx_queue.append("fire_start")
	elif roll < 0.029:
		_add_feature(Catalog.FEAT_TOTEM, wx, wy, 1, 0, true)
	elif roll < 0.032:
		_add_feature(Catalog.FEAT_CURER, wx, wy, 1, 0, true)


func _scatter(cx: int, cy: int, biome: String) -> void:
	if _is_island_chunk(cx, cy):
		_scatter_island(cx, cy)
		return
	_scatter_biome_props(cx, cy, biome)
	var spec: Dictionary = biome_by_id.get(biome, {})
	var ck := _ck(cx, cy)
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(chunks[ck].tiles[ly * Catalog.CHUNK + lx])
			if tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_VOID:
				continue
			var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if not _land_inland(wx, wy):
				continue
			# Jitter 0.25..1.75 keeps mean density but breaks uniform grid fills.
			var tree_chance := float(spec.get("tree", 0.0)) * (0.25 + _rand(cx, cy, lx, ly, 19) * 1.5)
			if _rand(cx, cy, lx, ly, 1) < tree_chance:
				_add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif _rand(cx, cy, lx, ly, 2) < float(spec.get("ore", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 2, 1, true)
			elif _rand(cx, cy, lx, ly, 3) < float(spec.get("rock", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 0, true)
			elif _rand(cx, cy, lx, ly, 4) < float(spec.get("super", 0.0)):
				_add_feature(Catalog.FEAT_SUPER, wx, wy, 1, 2, true)
			elif _rand(cx, cy, lx, ly, 5) < float(spec.get("node", 0.0)):
				_add_feature(Catalog.FEAT_NODE, wx, wy, 1, 1, true)
			else:
				_scatter_one(cx, cy, wx, wy, lx, ly)


func _island_reach() -> float:
	return island_gen.island_reach()


func _shape_island() -> int:
	return island_gen.shape_island()


func _near_spawn(x: float, y: float) -> bool:
	return island_gen.near_spawn(x, y)


func _clear_spawn() -> void:
	island_gen.clear_spawn()


func _add_feature(kind: int, x: float, y: float, hp: int, ore: int, rooted: bool = false) -> Dictionary:
	var at := Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	# Campaign keeps the egg clearing tree-free; sandbox places freely.
	if kind == Catalog.FEAT_TREE and not sandbox_mode and _near_spawn(x, y):
		return {}
	if rooted and not sandbox_mode and not _stands(x, y, _span_for_feature(kind)):
		return {}
	if not _is_mine_node(kind) and _near_mine_node(x, y):
		return {}
	# Campaign scatter keeps props spaced; sandbox places adjacent rocks/trees freely.
	if not sandbox_mode and _feature_crowded(x, y, kind):
		return {}
	var cells := _footprint_cells(x, y, Catalog.footprint_for_feature(kind))
	if rooted and not sandbox_mode and not _footprint_holds(cells):
		return {}
	for cell in cells:
		if feature_cell.has(cell) or building_cell.has(cell):
			return {}
	var c := _chunk_at(x, y)
	var id := next_feature_id
	next_feature_id += 1
	var feat := {
		"id": id,
		"kind": kind,
		"x": x,
		"y": y,
		"hp": hp,
		"ore": ore,
		"cx": c.x,
		"cy": c.y,
		"dead": false,
		"rooted": rooted,
	}
	features.append(feat)
	feature_by_id[id] = feat
	_feat_chunk_index(feat)
	if kind == Catalog.FEAT_FIRE:
		fires.append(feat)
	for cell in cells:
		feature_cell[cell] = id
	feat_mesh_epoch += 1
	_invalidate_walk_cells()
	return feat


func _kill_feature(feat: Dictionary) -> void:
	if feat.is_empty() or feat.dead:
		return
	feat.dead = true
	lists_dirty = true
	feat_mesh_epoch += 1
	_feat_chunk_unindex(feat)
	if int(feat.kind) == Catalog.FEAT_FIRE:
		fires.erase(feat)
	_unbind_feature(feat)
	feature_by_id.erase(int(feat.id))
	cap_told = false
	_invalidate_walk_cells()


func _add_item(kind: int, x: float, y: float, value: int) -> Dictionary:
	var id := next_item_id
	next_item_id += 1
	var it := {"id": id, "kind": kind, "x": x, "y": y, "value": value, "held": false, "dead": false, "fixed": false, "air": 0.0, "vz": 0.0, "vx": 0.0, "vy": 0.0, "falling_void": false, "rest": 0.0}
	if kind == Catalog.ITEM_BALL:
		it.life = BALL_LIFE
	if kind == Catalog.ITEM_APPLE:
		it.bites_left = 3
		it.bite = 0.0
	items.append(it)
	item_by_id[id] = it
	_index_item(it)
	_invalidate_item_counts()
	return it


func _add_building(kind: int, x: float, y: float) -> Dictionary:
	var id := next_building_id
	next_building_id += 1
	var b := {
		"id": id,
		"kind": kind,
		"x": x,
		"y": y,
		"timer": 1.5,
		"occupant": -1,
		"bath_t": -1.0,
		"node": 0,
		"buffer": 0,
		"burn": 0.0,
		"incinerate": false,
		"active": false,
		"dead": false,
	}
	if not _bind_building_at(b, x, y):
		return {}
	buildings.append(b)
	building_by_id[id] = b
	_index_building(b)
	_invalidate_factory_cache()
	_invalidate_walk_cells()
	return b


func _index_item(it: Dictionary) -> void:
	match int(it.kind):
		Catalog.ITEM_APPLE:
			items_apple.append(it)
		Catalog.ITEM_BALL:
			items_ball.append(it)
		Catalog.ITEM_WOOD:
			items_wood.append(it)
		Catalog.ITEM_BONE:
			items_bone.append(it)
		Catalog.ITEM_ORE:
			items_ore.append(it)


func _index_building(b: Dictionary) -> void:
	match int(b.kind):
		Catalog.BLD_TUB:
			blds_tub.append(b)
		Catalog.BLD_ROUND:
			blds_round.append(b)
		Catalog.BLD_DWELL, Catalog.BLD_FANCY:
			blds_home.append(b)
		Catalog.BLD_MINE, Catalog.BLD_MINE2:
			blds_mine.append(b)
		Catalog.BLD_THEATRE:
			blds_show.append(b)


func _rebuild_kind_indexes() -> void:
	items_apple.clear()
	items_ball.clear()
	items_wood.clear()
	items_bone.clear()
	items_ore.clear()
	blds_tub.clear()
	blds_round.clear()
	blds_home.clear()
	blds_mine.clear()
	blds_show.clear()
	_invalidate_item_counts()
	for it in items:
		if it.dead:
			continue
		_index_item(it)
	for b in buildings:
		if b.dead:
			continue
		_index_building(b)


func _remove_building(b: Dictionary) -> void:
	b.dead = true
	_unbind_building(b)
	building_by_id.erase(int(b.id))
	cap_told = false
	var occ := int(b.occupant)
	if occ >= 0 and occ < claim.size():
		claim[occ] = -1
	_invalidate_factory_cache()
	_invalidate_walk_cells()


func _consume_kind(kind: int, count: int, near_x: float, near_y: float) -> bool:
	if count <= 0:
		return true
	_invalidate_item_counts()
	if count_item(kind) < count:
		return false
	var left := count
	var found: Array = []
	for it in items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		found.append(it)
	found.sort_custom(func(a, b):
		var da := _dist_point(near_x, near_y, float(a.x), float(a.y))
		var db := _dist_point(near_x, near_y, float(b.x), float(b.y))
		return da < db
	)
	for it in found:
		if left <= 0:
			break
		it.dead = true
		left -= 1
	if left <= 0:
		_invalidate_item_counts()
		return true
	var carriers: Array = []
	for raw in living_ids:
		var i := int(raw)
		if not _carry_matches(i, kind):
			continue
		carriers.append(i)
	carriers.sort_custom(func(a, b):
		return _dist_i(int(a), near_x, near_y) < _dist_i(int(b), near_x, near_y)
	)
	for i in carriers:
		if left <= 0:
			break
		_set_carry(int(i), Catalog.CARRY_NONE)
		left -= 1
	_invalidate_item_counts()
	return left <= 0


func _carry_matches(i: int, kind: int) -> bool:
	if i < 0 or i >= slot_count:
		return false
	if kind == Catalog.ITEM_WOOD:
		return carry[i] == Catalog.CARRY_WOOD
	if kind == Catalog.ITEM_BONE:
		return carry[i] == Catalog.CARRY_BONE
	if kind == Catalog.ITEM_ORE:
		return carry[i] == Catalog.CARRY_ORE
	return false


func _claim_tub(i: int, tub: Dictionary) -> void:
	var occ := int(tub.occupant)
	if occ == i:
		if i < link_tub.size():
			link_tub[i] = int(tub.id)
		return
	if occ >= 0 and occ != i:
		return
	_release_claim(i)
	tub.occupant = i
	tub.bath_t = -1.0
	claim[i] = int(tub.id)
	if i < link_tub.size():
		link_tub[i] = int(tub.id)


func _release_claim(i: int) -> void:
	if i < 0 or i >= claim.size():
		return
	var bid := claim[i]
	claim[i] = -1
	if i < link_tub.size() and (bid < 0 or link_tub[i] == bid):
		link_tub[i] = -1
	if bid < 0:
		return
	var b = building_by_id.get(bid, {})
	if not b.is_empty() and int(b.occupant) == i:
		var soaking := int(b.kind) == Catalog.BLD_TUB and float(b.get("bath_t", -1.0)) >= 0.0
		b.occupant = -1
		b.bath_t = -1.0
		b.active = false
		if soaking:
			sfx_queue.append("tub_out")


func _nearest_tub(i: int, allow_busy: bool = false) -> Dictionary:
	var best := {}
	var best_d := 999999.0
	for b in blds_tub:
		if b.dead:
			continue
		var occ := int(b.occupant)
		if occ >= 0 and occ != i and not allow_busy:
			continue
		var d := _dist_i(i, float(b.x), float(b.y))
		if d < best_d and d < 280.0:
			best_d = d
			best = b
	return best


func _buildings_for_kinds(kinds: Array) -> Array:
	if kinds.size() == 1:
		match int(kinds[0]):
			Catalog.BLD_TUB:
				return blds_tub
			Catalog.BLD_ROUND:
				return blds_round
			Catalog.BLD_DWELL, Catalog.BLD_FANCY:
				return blds_home
			Catalog.BLD_MINE, Catalog.BLD_MINE2:
				return blds_mine
			Catalog.BLD_THEATRE:
				return blds_show
	if kinds.size() == 2:
		var a := int(kinds[0])
		var b := int(kinds[1])
		if (a == Catalog.BLD_DWELL and b == Catalog.BLD_FANCY) or (b == Catalog.BLD_DWELL and a == Catalog.BLD_FANCY):
			return blds_home
		if (a == Catalog.BLD_MINE and b == Catalog.BLD_MINE2) or (b == Catalog.BLD_MINE and a == Catalog.BLD_MINE2):
			return blds_mine
	return buildings


func _nearest_building_kinds(x: float, y: float, kinds: Array, max_dist: float, who: int = -1) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for b in _buildings_for_kinds(kinds):
		if b.dead or not kinds.has(int(b.kind)):
			continue
		if building_is_polluted(b):
			continue
		if who >= 0 and not _can_enter(b, who):
			continue
		var d := _dist_point(x, y, float(b.x), float(b.y))
		if d < best_d:
			best_d = d
			best = b
	return best


func _nearest_item(x: float, y: float, kind: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for it in _items_of_kind(kind):

		if it.dead or it.held or int(it.kind) != kind:
			continue
		var d := _dist_point(x, y, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best


func _item_at(x: float, y: float, radius: float) -> Dictionary:
	return _nearest_item_any(x, y, radius)


func _nearest_item_any(x: float, y: float, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for it in items:
		if it.dead or it.held:
			continue
		var d := _dist_point(x, y, float(it.x), float(it.y))
		if d <= best_d:
			best_d = d
			best = it
	return best


func _feature_at(x: float, y: float, radius: float) -> Dictionary:
	var cell := _cell_vec(x, y)
	var owned := int(feature_cell.get(cell, -1))
	if owned >= 0:
		var hit = feature_by_id.get(owned, {})
		if not hit.is_empty() and not hit.dead:
			return hit
	var best := {}
	var best_d := radius
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var key := Vector2i(cell.x + ox, cell.y + oy)
			if not feature_cell.has(key):
				continue
			var feat = feature_by_id.get(int(feature_cell[key]), {})
			if feat.is_empty() or feat.dead:
				continue
			var size := Catalog.footprint_for_feature(int(feat.kind))
			var reach := radius + float(maxi(size.x, size.y) - 1) * float(Catalog.TILE) * 0.5
			var d := _dist_point(x, y, float(feat.x), float(feat.y))
			if d <= reach and d <= best_d:
				best_d = d
				best = feat
	return best


func _building_at(x: float, y: float, radius: float) -> Dictionary:
	var cell := _cell_vec(x, y)
	var owned := int(building_cell.get(cell, -1))
	if owned >= 0:
		var hit = building_by_id.get(owned, {})
		if not hit.is_empty() and not hit.dead:
			return hit
	var best := {}
	var best_d := radius
	for b in buildings:
		if b.dead:
			continue
		var size := Catalog.footprint_for_building(int(b.kind))
		var reach := radius + float(maxi(size.x, size.y) - 1) * float(Catalog.TILE) * 0.5
		var d := _dist_point(x, y, float(b.x), float(b.y))
		if d <= reach and d <= best_d:
			best_d = d
			best = b
	return best



func _nearest_living(x: float, y: float, radius: float) -> int:
	return find_thronglet(x, y, radius, true)


func _nearest_corpse(x: float, y: float, radius: float) -> int:
	var best := -1
	var best_d := radius
	for i in slot_count:
		if state[i] != Catalog.ST_DEAD:
			continue
		var d := _dist_i(i, x, y)
		if d < best_d:
			best_d = d
			best = i
	return best


func _work_need() -> float:
	if bool(mutations.get("hard", false)):
		return 32.0
	if bool(mutations.get("care", false)):
		return 65.0
	return 50.0


func _work_ready(i: int) -> bool:
	if i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
		return false
	var need := _work_need()
	return fed[i] >= need and amused[i] >= need and clean[i] >= need


func _workers_near(b: Dictionary, cap: int) -> int:
	var radius := _work_radius(b) + 8.0
	var ids := query_radius(float(b.x), float(b.y), radius)
	var n := 0
	for id in ids:
		var who := int(id)
		if int(act[who]) != ACT_WORK:
			continue
		if not _work_ready(who):
			continue
		n += 1
		if n >= cap:
			break
	return n


func _mine_value(b: Dictionary) -> int:
	var node := int(b.get("node", 1))
	var mine := 1 if int(b.kind) == Catalog.BLD_MINE else 2
	if mine == 1 and node == 1:
		return 1
	if mine == 2 and node == 2:
		return 3
	if node >= 3:
		return node
	return 2


func _has_egg() -> bool:
	for it in items:
		if not it.dead and int(it.kind) == Catalog.ITEM_EGG:
			return true
	return false


func has_building_kind(kind: int) -> bool:
	return _has_building(kind)


func _has_building(kind: int) -> bool:
	for b in buildings:
		if not b.dead and int(b.kind) == kind:
			return true
	return false


func _invalidate_factory_cache() -> void:
	_has_factory_known = false


func _has_factory() -> bool:
	if _has_factory_known:
		return _has_factory_cache
	_has_factory_cache = false
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			_has_factory_cache = true
			break
	_has_factory_known = true
	return _has_factory_cache


func _count_living_near(x: float, y: float, radius: float) -> int:
	var n := 0
	for id in query_radius(x, y, radius):
		if state[int(id)] == Catalog.ST_LIVING:
			n += 1
	return n


func _count_items_near(kind: int, x: float, y: float, radius: float) -> int:
	var n := 0
	for it in items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		if _dist_point(x, y, float(it.x), float(it.y)) <= radius:
			n += 1
	return n


func _count_goo() -> int:
	var n := 0
	for ck in chunks.keys():
		var tiles: PackedByteArray = chunks[ck].tiles
		for tile in tiles:
			if int(tile) == Catalog.TILE_GOO:
				n += 1
	return n


func _blocked(px: float, py: float, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	return _blocked_cell(_cell_vec(px, py), allow_ore, allow_soft)


func _blocked_cell(cell: Vector2i, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	var tile := _tile_at_cell(cell)
	if Catalog.tile_blocks(tile):
		return true
	if feature_cell.has(cell):
		var feat = feature_by_id.get(int(feature_cell[cell]), {})
		if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
			# Mine zones (ore nodes) are ground zones: walkable surface exception.
			if _ore_tier(int(feat.kind)) > 0:
				return false
			if allow_soft and _pad_feature_soft(int(feat.kind)):
				return false
			return true
	if building_cell.has(cell):
		var b = building_by_id.get(int(building_cell[cell]), {})
		if not b.is_empty() and not b.dead and Catalog.building_blocks(int(b.kind)):
			return true
	return false


func _on_mine_pad(px: float, py: float) -> bool:
	return _on_mine_pad_cell(_cell_vec(px, py))


func _on_mine_pad_cell(cell: Vector2i) -> bool:
	# Mine footprints are walkable ground pads above terrain.
	if blds_mine.is_empty() or not building_cell.has(cell):
		return false
	var b = building_by_id.get(int(building_cell[cell]), {})
	if b.is_empty() or b.dead:
		return false
	var kind := int(b.kind)
	return kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2


func _move_blocked(px: float, py: float) -> bool:
	if save_perf_mode:
		set_meta("_ap_move_n", int(get_meta("_ap_move_n", 0)) + 1)
	var cell := _cell_vec(px, py)
	# Mine zones are walkable ground pads (exception): treat as passable ground
	# above terrain, ignoring pad footprint/feature hitboxes. Without a mine,
	# the ore/node feature remains and blocks in _blocked as usual.
	if _on_mine_pad_cell(cell):
		return Catalog.tile_blocks(_tile_at_cell(cell))
	# 6px probes stay inside a 16px cell; cliff walk needs a full neighbor-tile pad.
	if _blocked_cell(cell):
		return true
	return not _land_inland_cell(cell)


func _ride_spot_blocked(px: float, py: float, ride_b: Dictionary) -> bool:
	# Riders stand on their own pad / painted disk. Everything else still blocks.
	var cell := _cell_vec(px, py)
	if building_cell.has(cell) and int(building_cell[cell]) == int(ride_b.id):
		var tile := _tile_at(px, py)
		return Catalog.tile_blocks(tile)
	# Seat ring can sit a few px past the 2x2 cell pad; still treat as the ride.
	var mid := _ride_center_of(ride_b)
	var dx := px - mid.x
	var dy := py - mid.y
	var lim := _ride_radius(ride_b) + 3.0
	if dx * dx + dy * dy <= lim * lim:
		return Catalog.tile_blocks(_tile_at(px, py))
	return _move_blocked(px, py)


func _approach_spot(x: float, y: float, radius: float, who: int = -1) -> Vector2:
	return _approach_ellipse(x, y, radius, radius, who)


func _approach_building(b: Dictionary, who: int = -1) -> Vector2:
	var center := _footprint_center_of(b)
	var reach := Catalog.building_reach(int(b.kind))
	return _approach_ellipse(center.x, center.y, reach.x, reach.y, who)


func _inside_building_reach(px: float, py: float, b: Dictionary) -> bool:
	var center := _footprint_center_of(b)
	var reach := Catalog.building_reach(int(b.kind))
	var rx := maxf(reach.x, 0.01)
	var ry := maxf(reach.y, 0.01)
	var u := (px - center.x) / rx
	var v := (py - center.y) / ry
	return u * u + v * v <= 1.0


func _approach_ellipse(x: float, y: float, rx: float, ry: float, who: int = -1) -> Vector2:
	var best := Vector2(x, y)
	var best_d := 1.0e9
	var from := Vector2(x, y)
	if who >= 0 and who < slot_count:
		from = Vector2(pos_x[who], pos_y[who])
	var ax := maxf(rx, 1.0)
	var ay := maxf(ry, 1.0)
	for n in 12:
		var ang := float(n) * (TAU / 12.0)
		var px := x + cos(ang) * ax
		var py := y + sin(ang) * ay
		if _move_blocked(px, py):
			continue
		var d := from.distance_squared_to(Vector2(px, py))
		if d < best_d:
			best_d = d
			best = Vector2(px, py)
	if best_d < 1.0e9:
		return best
	for grow in 2:
		var extra := 8.0 * float(grow + 1)
		for n in 12:
			var ang := float(n) * (TAU / 12.0)
			var px := x + cos(ang) * (ax + extra)
			var py := y + sin(ang) * (ay + extra)
			if _move_blocked(px, py):
				continue
			return Vector2(px, py)
	return best



func _tile_at(px: float, py: float) -> int:
	return _tile_at_cell(_cell_vec(px, py))


func _tile_at_cell(cell: Vector2i) -> int:
	var chunk_x := _floor_div(cell.x, Catalog.CHUNK)
	var chunk_y := _floor_div(cell.y, Catalog.CHUNK)
	var ck := _ck(chunk_x, chunk_y)
	if not revealed.has(ck):
		return Catalog.TILE_FOG
	var ch = chunks.get(ck)
	if ch == null:
		_ensure(chunk_x, chunk_y)
		ch = chunks.get(ck)
		if ch == null:
			return Catalog.TILE_FOG
	var lx := cell.x - chunk_x * Catalog.CHUNK
	var ly := cell.y - chunk_y * Catalog.CHUNK
	return int(ch.tiles[ly * Catalog.CHUNK + lx])


func _base_at(px: float, py: float) -> int:
	var c := _chunk_at(px, py)
	var ck := _ck(c.x, c.y)
	if not chunks.has(ck):
		return Catalog.TILE_DIRT
	var local := _local_cell(px, py)
	return int(chunks[ck].base[local.y * Catalog.CHUNK + local.x])


func _set_world_cell(cx: int, cy: int, tile: int, also_base: bool) -> void:
	var chunk_x := _floor_div(cx, Catalog.CHUNK)
	var chunk_y := _floor_div(cy, Catalog.CHUNK)
	var ck := _ck(chunk_x, chunk_y)
	if not revealed.has(ck):
		return
	_ensure(chunk_x, chunk_y)
	var lx := cx - chunk_x * Catalog.CHUNK
	var ly := cy - chunk_y * Catalog.CHUNK
	_set_local_tile(ck, lx, ly, tile, also_base)


func _set_local_tile(ck: String, lx: int, ly: int, tile: int, also_base: bool) -> void:
	if not chunks.has(ck):
		return
	var idx := ly * Catalog.CHUNK + lx
	var prev := int(chunks[ck].tiles[idx])
	chunks[ck].tiles[idx] = tile
	if also_base:
		chunks[ck].base[idx] = tile
	if prev != tile:
		var c := _parse_ck(ck)
		_invalidate_inland_around(Vector2i(c.x * Catalog.CHUNK + lx, c.y * Catalog.CHUNK + ly))
		_invalidate_walk_cells()
	_mark_dirty(ck)


func _living_add(i: int) -> void:
	if i < 0 or i >= living_at.size():
		return
	if living_at[i] >= 0:
		return
	living_at[i] = living_ids.size()
	living_ids.append(i)


func _living_remove(i: int) -> void:
	if i < 0 or i >= living_at.size():
		return
	var at := living_at[i]
	if at < 0:
		return
	var last_i := living_ids.size() - 1
	var last := int(living_ids[last_i])
	living_ids[at] = last
	if last < living_at.size():
		living_at[last] = at
	living_ids.resize(last_i)
	living_at[i] = -1


func _hash_unlink(i: int) -> void:
	if i < 0 or i >= hash_cell.size():
		return
	var b := hash_cell[i]
	if b < 0:
		return
	var prev := -1
	var cur := hash_head[b]
	var guard := 0
	while cur != -1 and guard < slot_count + 2:
		guard += 1
		if cur == i:
			if prev < 0:
				hash_head[b] = hash_next[i]
			else:
				hash_next[prev] = hash_next[i]
			break
		prev = cur
		cur = hash_next[cur] if cur >= 0 and cur < hash_next.size() else -1
	hash_cell[i] = -1
	hash_next[i] = -1


func _hash_link(i: int) -> void:
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return
	var b := _bucket(pos_x[i], pos_y[i])
	if i >= hash_cell.size():
		return
	hash_cell[i] = b
	hash_next[i] = hash_head[b]
	hash_head[b] = i


func _hash_relocate(i: int) -> void:
	if i < 0 or i >= hash_cell.size():
		return
	if state[i] == Catalog.ST_VACANT:
		_hash_unlink(i)
		return
	var b := _bucket(pos_x[i], pos_y[i])
	if hash_cell[i] == b:
		return
	_hash_unlink(i)
	_hash_link(i)


func _set_agent_pos(i: int, x: float, y: float) -> void:
	if i < 0 or i >= slot_count:
		return
	pos_x[i] = x
	pos_y[i] = y
	_hash_relocate(i)


func _rebuild_hash() -> void:
	if hash_cell.size() != slot_count:
		hash_cell.resize(slot_count)
	if hash_next.size() != slot_count:
		hash_next.resize(slot_count)
	hash_head.fill(-1)
	hash_cell.fill(-1)
	hash_next.fill(-1)
	for i in slot_count:
		if state[i] == Catalog.ST_VACANT:
			continue
		_hash_link(i)


func _feature_movable(feat: Dictionary) -> bool:
	if feat.is_empty() or feat.dead or bool(feat.get("rooted", false)):
		return false
	# Terrain trees stay planted. Only loose rocks can be carried.
	return int(feat.kind) == Catalog.FEAT_ROCK


func _anchor_terrain_feature(feat: Dictionary) -> void:
	var kind := int(feat.kind)
	if kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		feat.rooted = true


func _feat_chunk_index(feat: Dictionary) -> void:
	var ck := _ck(int(feat.cx), int(feat.cy))
	if not features_by_chunk.has(ck):
		features_by_chunk[ck] = []
	features_by_chunk[ck].append(feat)


func _feat_chunk_unindex(feat: Dictionary) -> void:
	var ck := _ck(int(feat.cx), int(feat.cy))
	var bucket = features_by_chunk.get(ck, null)
	if bucket == null:
		return
	bucket.erase(feat)
	if bucket.is_empty():
		features_by_chunk.erase(ck)


func features_in_rect(rect: Rect2) -> Array:
	# Only features whose chunks overlap rect (+1 chunk pad for tall sprites).
	var out: Array = []
	if rect.size == Vector2.ZERO:
		return out
	var size := float(Catalog.TILE * Catalog.CHUNK)
	var x0 := int(floor(rect.position.x / size)) - 1
	var y0 := int(floor(rect.position.y / size)) - 1
	var x1 := int(floor(rect.end.x / size)) + 1
	var y1 := int(floor(rect.end.y / size)) + 1
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var bucket = features_by_chunk.get(_ck(cx, cy), null)
			if bucket == null:
				continue
			for feat in bucket:
				if feat.dead:
					continue
				out.append(feat)
	return out


func _reindex() -> void:
	feature_by_id.clear()
	feature_cell.clear()
	features_by_chunk.clear()
	item_by_id.clear()
	building_by_id.clear()
	building_cell.clear()
	fires.clear()
	next_feature_id = 1
	next_item_id = 1
	next_building_id = 1
	for feat in features:
		if feat.dead:
			continue
		_anchor_terrain_feature(feat)
		var at := Catalog.snap_world(float(feat.x), float(feat.y))
		feat.x = at.x
		feat.y = at.y
		var c := _chunk_at(float(feat.x), float(feat.y))
		feat.cx = c.x
		feat.cy = c.y
		feature_by_id[int(feat.id)] = feat
		_feat_chunk_index(feat)
		if int(feat.kind) == Catalog.FEAT_FIRE:
			fires.append(feat)
		for cell in _footprint_cells(float(feat.x), float(feat.y), Catalog.footprint_for_feature(int(feat.kind))):
			feature_cell[cell] = int(feat.id)
		next_feature_id = maxi(next_feature_id, int(feat.id) + 1)
	for it in items:
		if it.dead:
			continue
		it.held = false
		item_by_id[int(it.id)] = it
		next_item_id = maxi(next_item_id, int(it.id) + 1)
	for b in buildings:
		if b.dead:
			continue
		building_by_id[int(b.id)] = b
		for cell in _footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
			building_cell[cell] = int(b.id)
		next_building_id = maxi(next_building_id, int(b.id) + 1)
	tick_stamp = PackedInt32Array()
	tick_stamp.resize(slot_count)
	while act.size() < slot_count:
		act.append(0)
	while act_t.size() < slot_count:
		act_t.append(0.0)
	while avoid_t.size() < slot_count:
		avoid_t.append(0.0)
	_ensure_link_arrays()
	_rebuild_links()
	_rebuild_living()
	_rebuild_kind_indexes()
	_rebuild_hash()


func _ensure_link_arrays() -> void:
	var n := slot_count
	if link_tub.size() != n:
		link_tub.resize(n)
		link_tub.fill(-1)
	if link_ride.size() != n:
		link_ride.resize(n)
		link_ride.fill(-1)
	if link_guest.size() != n:
		link_guest.resize(n)
		link_guest.fill(-1)
	if link_claim.size() != n:
		link_claim.resize(n)
		link_claim.fill(-1)
	if link_ball.size() != n:
		link_ball.resize(n)
		link_ball.fill(-1)
	if living_at.size() != n:
		living_at.resize(n)
		living_at.fill(-1)
	if bark_cool.size() != n:
		bark_cool.resize(n)
		bark_cool.fill(0.0)
	if seek_x.size() != n:
		seek_x.resize(n)
		seek_x.fill(0.0)
	if seek_y.size() != n:
		seek_y.resize(n)
		seek_y.fill(0.0)
	if seek_t.size() != n:
		seek_t.resize(n)
		seek_t.fill(0.0)
	if hash_cell.size() != n:
		hash_cell.resize(n)
		hash_cell.fill(-1)
	if hash_next.size() != n:
		hash_next.resize(n)
		hash_next.fill(-1)


func _rebuild_links() -> void:
	_ensure_link_arrays()
	link_tub.fill(-1)
	link_ride.fill(-1)
	link_guest.fill(-1)
	link_claim.fill(-1)
	link_ball.fill(-1)
	mine_job_n.clear()
	for i in mine_job.size():
		var bid := int(mine_job[i])
		if bid < 0:
			continue
		mine_job_n[bid] = int(mine_job_n.get(bid, 0)) + 1
	_invalidate_factory_cache()
	_invalidate_walk_cells()
	for b in buildings:
		if b.dead:
			continue
		var bid := int(b.id)
		var occ := int(b.get("occupant", -1))
		if occ >= 0 and occ < link_tub.size() and int(b.kind) == Catalog.BLD_TUB:
			link_tub[occ] = bid
		for guest in b.get("guests", []):
			var gid := int(guest.get("id", -1))
			if gid >= 0 and gid < link_guest.size():
				link_guest[gid] = bid
		for raw in _rider_list(b):
			var rid := int(raw)
			if rid >= 0 and rid < link_ride.size():
				link_ride[rid] = bid
	for it in items:
		if it.dead:
			continue
		var who := int(it.get("claimer", -1))
		if who < 0 or who >= link_claim.size():
			continue
		link_claim[who] = int(it.id)
		if int(it.kind) == Catalog.ITEM_BALL:
			link_ball[who] = int(it.id)


func _rebuild_living() -> void:
	living_ids = PackedInt32Array()
	if living_at.size() != slot_count:
		living_at.resize(slot_count)
	living_at.fill(-1)
	dead_n = 0
	dead_ids = PackedInt32Array()
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING:
			_living_add(i)
		elif state[i] == Catalog.ST_DEAD:
			dead_n += 1
			_dead_add(i)
			# Legacy saves keep hunger-starve leftovers; clamp into corpse lifetime.
			if starve[i] <= 0.0 or starve[i] > CORPSE_LIFE:
				starve[i] = CORPSE_LIFE


func _recount() -> void:
	_rebuild_living()
	living = living_ids.size()
	peak = maxi(peak, living)
	_rebuild_carry_counts()
	_invalidate_item_counts()


func _compact(list: Array) -> void:
	var w := 0
	for i in list.size():
		if not bool(list[i].get("dead", false)):
			list[w] = list[i]
			w += 1
	list.resize(w)


func _init_unlocks() -> void:
	unlocks = {
		"apple": true,
		"ball": true,
		"sponge": true,
		"camera": true,
		"bathtub": false,
		"apple_tree": false,
		"roundabout": false,
		"axe": false,
		"hammer": false,
		"bug": false,
		"market": false,
		"pickaxe": false,
		"mine": false,
		"dwelling": false,
		"factory": false,
		"chainsaw": false,
		"theatre": false,
		"factory2": false,
		"mine2": false,
		"fancy": false,
		"grabber": false,
		"swarm": false,
		"mop": false,
		"tnt": false,
		"nuke": false,
		"flower": false,
		"sculpture": false,
	}


func _load_biomes() -> void:
	biomes = []
	biome_by_id = {}
	var file := FileAccess.open("res://data/biomes.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return
	biomes = parsed
	for biome in biomes:
		biome_by_id[str(biome.id)] = biome


func _biome_formula(cx: int, cy: int) -> String:
	var special := str(special_biomes.get(_ck(cx, cy), ""))
	if special != "":
		return special
	if cx == 0 and cy == 0:
		return "meadow"
	if _is_island_chunk(cx, cy):
		return "grove"
	return "sea"


func _scatter_biome_props(cx: int, cy: int, biome: String) -> void:
	if biome != "glitch" and biome != "anomaly" and biome != "epilogue" and biome != "mountain":
		return
	var count := 4 if biome == "mountain" else 5
	for n in count:
		var lx := int(_rand(cx, cy, n, 0, 90) * float(Catalog.CHUNK))
		var ly := int(_rand(cx, cy, n, 1, 91) * float(Catalog.CHUNK))
		var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		var kind := Catalog.FEAT_EPILOGUE
		var ore := n % 2
		if biome == "glitch":
			kind = Catalog.FEAT_GLITCH_HOUSE if n % 2 == 0 else Catalog.FEAT_GLITCH_TREE
			ore = 0 if kind == Catalog.FEAT_GLITCH_HOUSE else n % 5
		elif biome == "anomaly":
			kind = Catalog.FEAT_ANOMALY
			ore = n % 5
		elif biome == "mountain":
			kind = Catalog.FEAT_MOUNTAIN
			ore = n % 4
		_add_feature(kind, wx, wy, 1, ore, true)


func biome_at(x: float, y: float) -> String:
	var cell := _chunk_at(x, y)
	return _biome_of(cell.x, cell.y)


func _biome_of(cx: int, cy: int) -> String:
	var ck := _ck(cx, cy)
	if chunks.has(ck):
		return str(chunks[ck].biome)
	return _biome_formula(cx, cy)


func _rand(cx: int, cy: int, lx: int, ly: int, salt: int) -> float:
	_rng.seed = int(world_seed) ^ (cx * 83492791) ^ (cy * 19349663) ^ (lx * 97) ^ (ly * 57) ^ (salt * 131)
	return _rng.randf()


func _bucket(px: float, py: float) -> int:
	return _bucket_cell(int(floor(px / Catalog.HASH_CELL)), int(floor(py / Catalog.HASH_CELL)))


func _bucket_cell(cx: int, cy: int) -> int:
	return (cx * 73856093 ^ cy * 19349663) & (Catalog.HASH_SIZE - 1)


func _chunk_at(px: float, py: float) -> Vector2i:
	return Vector2i(_floor_div(_cell_of(px), Catalog.CHUNK), _floor_div(_cell_of(py), Catalog.CHUNK))


func _ck_of(px: float, py: float) -> String:
	var c := _chunk_at(px, py)
	return _ck(c.x, c.y)


func _local_cell(px: float, py: float) -> Vector2i:
	var c := _chunk_at(px, py)
	return Vector2i(_cell_of(px) - c.x * Catalog.CHUNK, _cell_of(py) - c.y * Catalog.CHUNK)


func _cell_vec(px: float, py: float) -> Vector2i:
	return Vector2i(_cell_of(px), _cell_of(py))


func _cell_of(p: float) -> int:
	return int(floor(p / float(Catalog.TILE)))


func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))


func _chunk_center(cx: int, cy: int) -> Vector2:
	var size := float(Catalog.CHUNK * Catalog.TILE)
	return Vector2(float(cx) * size + size * 0.5, float(cy) * size + size * 0.5)


func _ck(cx: int, cy: int) -> String:
	return "%d,%d" % [cx, cy]


func _parse_ck(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _pmod(a: int, m: int) -> int:
	var r := a % m
	if r < 0:
		r += m
	return r


func _dist_i(i: int, x: float, y: float) -> float:
	var dx := pos_x[i] - x
	var dy := pos_y[i] - y
	return sqrt(dx * dx + dy * dy)


func _dist_point(x0: float, y0: float, x1: float, y1: float) -> float:
	var dx := x0 - x1
	var dy := y0 - y1
	return sqrt(dx * dx + dy * dy)


func _mark_dirty(ck: String) -> void:
	if not dirty_chunks.has(ck):
		dirty_chunks.append(ck)


func _as_f32(value) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value
	var out := PackedFloat32Array()
	if value == null:
		return out
	for v in value:
		out.append(float(v))
	return out


func _as_i32(value) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value
	var out := PackedInt32Array()
	if value == null:
		return out
	for v in value:
		out.append(int(v))
	return out



func _shot_bld_goo_kinds() -> Array:
	return [
		{"kind": Catalog.BLD_DWELL, "name": "dwell"},
		{"kind": Catalog.BLD_FANCY, "name": "fancy"},
		{"kind": Catalog.BLD_THEATRE, "name": "theatre"},
		{"kind": Catalog.BLD_MINE, "name": "mine"},
		{"kind": Catalog.BLD_MINE2, "name": "mine2"},
		{"kind": Catalog.BLD_FACTORY, "name": "factory"},
		{"kind": Catalog.BLD_FACTORY2, "name": "factory2"},
	]


func _shot_force_pad(kind: int, x: float, y: float) -> Vector2:
	var at := Catalog.snap_world(x, y)
	for cell in _footprint_cells(at.x, at.y, Catalog.footprint_for_building(kind)):
		_set_world_cell(cell.x, cell.y, Catalog.TILE_GRASS, true)
	return at


func _shot_paint_building_goo(b: Dictionary) -> void:
	for cell in _footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
		_set_world_cell(cell.x, cell.y, Catalog.TILE_GOO, false)
	goo_count = _count_goo()


func _shot_mop_building(b: Dictionary) -> void:
	# Sweep the mop over every footprint cell (mines exceed one MOP_RADIUS).
	for cell in _footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
		var at := _cell_world(cell)
		_mop(at.x, at.y)


func _shot_activate_building(b: Dictionary) -> void:
	var kind := int(b.kind)
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or kind == Catalog.BLD_THEATRE:
		var tid := _push_slot_quiet(float(b.x) + 400.0, float(b.y) + 400.0, 90.0, 90.0, 90.0, 90.0, 0)
		if tid < 0:
			b.active = true
			return
		b.guests = [{"id": tid, "left": 99.0}]
		if tid < link_guest.size():
			link_guest[tid] = int(b.id)
		b.active = true
		return
	b.active = true
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		_shot_fill_factory(b)
		b.timer = _factory_cycle_time(kind) * 0.4
	elif _is_mine_kind(kind):
		b.buffer = maxi(1, int(b.get("buffer", 0)))


func _shot_place_bld_row(kind: int) -> Dictionary:
	# Left idle | mid active | right goo. Same kind for overlay alignment checks.
	_clear_shot_props()
	var size := Catalog.footprint_for_building(kind)
	var gap := float(size.x + 2) * float(Catalog.TILE)
	var cy := 256.0
	var spots := [
		Catalog.snap_world(256.0 - gap, cy),
		Catalog.snap_world(256.0, cy),
		Catalog.snap_world(256.0 + gap, cy),
	]
	var out := {"idle": {}, "active": {}, "goo": {}, "focus": Vector2(256.0, cy)}
	var keys := ["idle", "active", "goo"]
	for i in keys.size():
		var at: Vector2 = spots[i]
		at = _shot_force_pad(kind, at.x, at.y)
		var b: Dictionary = _add_building(kind, at.x, at.y)
		if b.is_empty():
			# Nudge a little if bind failed on the first try.
			for n in 8:
				var nx := at.x + float((n % 4) - 1) * float(Catalog.TILE)
				var ny := at.y + float(int(n / 4) - 1) * float(Catalog.TILE)
				_shot_force_pad(kind, nx, ny)
				b = _add_building(kind, nx, ny)
				if not b.is_empty():
					break
		if b.is_empty():
			out["error"] = "place %s col=%s" % [kind, keys[i]]
			return out
		out[keys[i]] = b
	_shot_activate_building(out.active)
	_shot_paint_building_goo(out.goo)
	var span := gap + float(size.x) * float(Catalog.TILE) * 0.75
	shot_focus = out.focus
	shot_span = maxf(120.0, span)
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	_rebuild_hash()
	smoke_hold = true
	return out


func _prep_shot_bld_goo() -> void:
	# Capture harness places each idle|active|goo row and the mop pair.
	unlocks.dwelling = true
	unlocks.fancy = true
	unlocks.theatre = true
	unlocks.mine = true
	unlocks.mine2 = true
	unlocks.factory = true
	unlocks.factory2 = true
	unlocks.mop = true
	_clear_shot_props()
	shot_focus = Vector2(256.0, 256.0)
	shot_span = 140.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	smoke_hold = true
	print("SHOT BLD GOO READY")


func _prep_shot_blood() -> void:
	_clear_shot_props()
	# Left: neglect corpse (no blood). Mid: living. Right: splash-kill corpse + Throng_Prop_Blood_A.
	var ax := 256.0
	var ay := 256.0
	var neglect_id := _push_slot(ax - 48.0, ay, 90.0, 90.0, 90.0, 90.0, 0)
	var living_id := _push_slot(ax, ay, 90.0, 90.0, 90.0, 90.0, 1)
	var splash_id := _push_slot(ax + 48.0, ay, 90.0, 90.0, 90.0, 90.0, 2)
	if neglect_id >= 0:
		dir_x[neglect_id] = 1.0
		dir_y[neglect_id] = 0.0
		_become_corpse(neglect_id, false)
	if living_id >= 0:
		dir_x[living_id] = 0.0
		dir_y[living_id] = 0.0
		act[living_id] = 0
	if splash_id >= 0:
		dir_x[splash_id] = -1.0
		dir_y[splash_id] = 0.0
		_splash_kill(pos_x[splash_id], pos_y[splash_id], 8.0)
	peak = maxi(peak, 3)
	shot_focus = Vector2(ax, ay)
	shot_span = 80.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	smoke_hold = true
	_rebuild_hash()
	print("SHOT BLOOD READY neglect=%s living=%s splash=%s bloody=%s/%s/%s" % [
		neglect_id,
		living_id,
		splash_id,
		int(bloody[neglect_id]) if neglect_id >= 0 else -1,
		int(bloody[living_id]) if living_id >= 0 else -1,
		int(bloody[splash_id]) if splash_id >= 0 else -1,
	])


func _prep_shot_wash() -> void:
	_clear_shot_props()
	# Left: ACT_WASH + bubbles on body. Right: post-wash Happy stand + one CLEAN burst.
	var ax := 256.0
	var ay := 256.0
	var scrub_id := _push_slot(ax - 36.0, ay, 90.0, 90.0, 20.0, 90.0, 0)
	var done_id := _push_slot(ax + 36.0, ay, 90.0, 90.0, 100.0, 90.0, 1)
	if scrub_id >= 0:
		dir_x[scrub_id] = 0.0
		dir_y[scrub_id] = 0.0
		act[scrub_id] = ACT_WASH
		act_t[scrub_id] = 0.85
		clean[scrub_id] = 40.0
		sponge_id = scrub_id
		sponge_hold = 1.0
	if done_id >= 0:
		dir_x[done_id] = 0.0
		dir_y[done_id] = 0.0
		act[done_id] = 0
		clean[done_id] = 100.0
		_ensure_agent_timers(done_id)
		cheer_t[done_id] = WASH_FX_LIFE
		_pop_wash_sparkle(done_id)
	peak = maxi(peak, 2)
	shot_focus = Vector2(ax, ay)
	shot_span = 72.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	unlocks.sponge = true
	smoke_hold = true
	_rebuild_hash()
	print("SHOT WASH READY scrub=%s done=%s" % [scrub_id, done_id])


func _prep_shot_ball() -> void:
	_clear_shot_props()
	# Left: Default stand. Mid: content Happy_Walk + ball claim (bug was 1.0 scale).
	# Right: kick pop of ICON_BALL beside still Happy.
	var ax := 256.0
	var ay := 256.0
	var stand_id := _push_slot(ax - 48.0, ay, 95.0, 95.0, 95.0, 95.0, 0)
	var walk_id := _push_slot(ax, ay, 95.0, 95.0, 95.0, 95.0, 1)
	var kick_id := _push_slot(ax + 48.0, ay, 95.0, 95.0, 95.0, 95.0, 2)
	var ball := _add_item(Catalog.ITEM_BALL, ax + 10.0, ay - 8.0, 1)
	if stand_id >= 0:
		dir_x[stand_id] = 0.0
		dir_y[stand_id] = 0.0
		act[stand_id] = 0
	if walk_id >= 0:
		dir_x[walk_id] = 1.0
		dir_y[walk_id] = 0.0
		act[walk_id] = ACT_PLAY
		act_t[walk_id] = 0.55
		if not ball.is_empty():
			_claim_ball(walk_id, ball)
	if kick_id >= 0:
		dir_x[kick_id] = 0.0
		dir_y[kick_id] = 0.0
		act[kick_id] = ACT_PLAY
		act_t[kick_id] = 0.55
		if not ball.is_empty():
			link_ball[kick_id] = int(ball.id)
		_pop(pos_x[kick_id], pos_y[kick_id] - 6.0, Catalog.ICON_BALL, Catalog.BALL_SPRITE_SCALE)
	peak = maxi(peak, 3)
	shot_focus = Vector2(ax, ay)
	shot_span = 80.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	unlocks.ball = true
	smoke_hold = true
	_rebuild_hash()
	print("SHOT BALL READY stand=%s walk=%s kick=%s ball=%s" % [
		stand_id, walk_id, kick_id, int(ball.get("id", -1)) if not ball.is_empty() else -1,
	])


func _prep_shot_dirt() -> void:
	_clear_shot_props()
	# Two filthy thronglets at default zoom: left walks, right is held (Default body).
	var ax := 256.0
	var ay := 256.0
	var walk_id := _push_slot(ax - 28.0, ay, 90.0, 90.0, 0.0, 0.0, 0)
	var held_id := _push_slot(ax + 28.0, ay, 90.0, 90.0, 0.0, 0.0, 1)
	if walk_id >= 0:
		fed[walk_id] = 90.0
		amused[walk_id] = 90.0
		clean[walk_id] = 0.0
		dir_x[walk_id] = 1.0
		dir_y[walk_id] = 0.0
		act[walk_id] = 0
		act_t[walk_id] = 0.0
	if held_id >= 0:
		fed[held_id] = 90.0
		amused[held_id] = 90.0
		clean[held_id] = 0.0
		dir_x[held_id] = 0.0
		dir_y[held_id] = 0.0
		act[held_id] = 0
		act_t[held_id] = 0.0
		held_kind = "thronglet"
		held_ref = held_id
		shot_throng = held_id
	peak = maxi(peak, 2)
	shot_focus = Vector2(ax, ay)
	shot_span = 64.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	smoke_hold = true
	_rebuild_hash()
	print("SHOT DIRT READY walk=%s held=%s clean_w=%.0f clean_h=%.0f" % [
		walk_id, held_id,
		clean[walk_id] if walk_id >= 0 else -1.0,
		clean[held_id] if held_id >= 0 else -1.0,
	])


func _prep_shot_needs() -> void:
	_clear_shot_props()
	# One thronglet with mixed needs so the HUD card matches the video card.
	var ax := 256.0
	var ay := 256.0
	shot_throng = _push_slot(ax, ay, 18.0, 62.0, 12.0, 0.0, 0)
	if shot_throng >= 0:
		# First capture (needs_low) matches video 68:00; second bumps to full cyan.
		fed[shot_throng] = 18.0
		amused[shot_throng] = 0.0
		clean[shot_throng] = 0.0
		dir_x[shot_throng] = 0.0
		dir_y[shot_throng] = 0.0
		act[shot_throng] = 0
		act_t[shot_throng] = 0.0
		peak = maxi(peak, 1)
	_add_item(Catalog.ITEM_APPLE, ax + 18.0, ay + 4.0, 1)
	_add_item(Catalog.ITEM_BALL, ax + 40.0, ay - 6.0, 1)
	shot_focus = Vector2(ax, ay)
	shot_span = 72.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	unlocks.apple = true
	unlocks.ball = true
	unlocks.sponge = true
	_rebuild_hash()
	smoke_hold = true
	print("SHOT NEEDS READY throng=%s fed=%.0f amused=%.0f clean=%.0f" % [
		shot_throng,
		fed[shot_throng] if shot_throng >= 0 else -1.0,
		amused[shot_throng] if shot_throng >= 0 else -1.0,
		clean[shot_throng] if shot_throng >= 0 else -1.0,
	])


func _prep_shot_apple() -> void:
	_clear_shot_props()
	# Two hungry thronglets and one apple with 3 bites.
	var ax := 256.0
	var ay := 256.0
	var apple := _add_item(Catalog.ITEM_APPLE, ax, ay, 1)
	apple.air = 0.0
	apple.fixed = false
	apple.bites_left = 3
	apple.bite = 0.0
	var a := _push_slot(ax - 10.0, ay, 20.0, 80.0, 80.0, 0.0, 0)
	var b := _push_slot(ax + 64.0, ay + 8.0, 95.0, 80.0, 80.0, 0.0, 1)
	# a is very hungry and close -> eats first bite. b is satisfied for now.
	if a >= 0:
		fed[a] = 20.0
		hungry_t[a] = 5.0
		dir_x[a] = 0.0
		dir_y[a] = 0.0
		act[a] = 0
		act_t[a] = 0.0
	if b >= 0:
		fed[b] = 95.0
		hungry_t[b] = 0.0
		dir_x[b] = 0.0
		dir_y[b] = 0.0
		act[b] = 0
		act_t[b] = 0.0
	shot_focus = Vector2(ax, ay)
	shot_span = 56.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	unlocks.apple = true
	_rebuild_hash()
	smoke_hold = true
	print("SHOT APPLE READY a=%s b=%s apple_bites=%s" % [a, b, apple.get("bites_left", -1)])

func _prep_shot_carry() -> void:
	_clear_shot_props()
	var rows := [
		{"item": Catalog.ITEM_WOOD, "carry": Catalog.CARRY_WOOD, "x": 220.0},
		{"item": Catalog.ITEM_BONE, "carry": Catalog.CARRY_BONE, "x": 256.0},
		{"item": Catalog.ITEM_ORE, "carry": Catalog.CARRY_ORE, "x": 292.0},
	]
	var focus := Vector2(256.0, 256.0)
	for row in rows:
		var gx := float(row.x)
		_add_item(int(row.item), gx, 248.0, 1)
		var id := _push_slot(gx, 268.0, 90.0, 90.0, 90.0, 0.0, 0)
		if id < 0:
			continue
		_set_carry(id, int(row.carry), 1)
		dir_x[id] = 0.0
		dir_y[id] = 0.0
		act[id] = 0
		act_t[id] = 0.0
		if shot_throng < 0:
			shot_throng = id
	shot_focus = focus
	shot_span = 72.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	_rebuild_hash()
	smoke_hold = true
	print("SHOT CARRY READY throng=%s items=%s living=%s" % [shot_throng, items.size(), living])


func _prep_shot_round() -> void:
	_clear_shot_props()
	unlocks.roundabout = true
	var at := Catalog.snap_world(256.0, 256.0)
	for feat in features:
		if feat.dead:
			continue
		var fdx := float(feat.x) - at.x
		var fdy := float(feat.y) - at.y
		if sqrt(fdx * fdx + fdy * fdy) < 80.0:
			feat.dead = true
	var round_b := _add_building(Catalog.BLD_ROUND, at.x, at.y)
	if round_b.is_empty():
		for attempt in 40:
			var px := at.x + float((attempt % 8) - 4) * 16.0
			var py := at.y + float(int(attempt / 8) - 2) * 16.0
			if _building_spot_free(-1, px, py, Catalog.BLD_ROUND):
				round_b = _add_building(Catalog.BLD_ROUND, px, py)
				if not round_b.is_empty():
					at = Vector2(float(round_b.x), float(round_b.y))
					break
	if round_b.is_empty():
		print("SHOT ROUND FAIL no roundabout")
		return
	# Idle frame first: carousel planted, nobody near, must stay still.
	shot_focus = at + Catalog.ROUND_RIDE_OFF
	shot_span = 56.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	_rebuild_hash()
	smoke_hold = true
	print("SHOT ROUND READY at=(%.1f,%.1f) id=%s" % [at.x, at.y, str(round_b.get("id", -1))])


func _prep_shot_world() -> void:
	_clear_shot_props()
	var taken := {}
	var missed: Array = []
	var buildings_to_place := [
		Catalog.BLD_FACTORY, Catalog.BLD_MARKET, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_DWELL,
		Catalog.BLD_FANCY, Catalog.BLD_APPLE, Catalog.BLD_TUB,
		Catalog.BLD_ROUND, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD,
	]
	for kind in buildings_to_place:
		var at := _shot_spot(taken, Catalog.footprint_for_building(kind))
		if at.x < 0.0 or _add_building(kind, at.x, at.y).is_empty():
			missed.append("building %s" % kind)
	for kind in [Catalog.ITEM_APPLE, Catalog.ITEM_BALL, Catalog.ITEM_WOOD, Catalog.ITEM_BONE, Catalog.ITEM_ORE, Catalog.ITEM_TNT, Catalog.ITEM_EGG]:
		var at := _shot_spot(taken, Vector2i(1, 1), 0, 24.0, 1)
		if at.x < 0.0:
			missed.append("item %s" % kind)
			continue
		var it := _add_item(kind, at.x, at.y, 1)
		it.air = 0.0
		it.fixed = true
	var features_to_place := [
		{"kind": Catalog.FEAT_SUPER, "ore": 2},
		{"kind": Catalog.FEAT_NODE, "ore": 1},
		{"kind": Catalog.FEAT_MNODE, "ore": 1},
		{"kind": Catalog.FEAT_BIGROCK, "ore": 1},
		{"kind": Catalog.FEAT_TREE, "ore": 0},
		{"kind": Catalog.FEAT_STUMP, "ore": 0},
		{"kind": Catalog.FEAT_MSTUMP, "ore": 0},
		{"kind": Catalog.FEAT_ROCK, "ore": 0},
		{"kind": Catalog.FEAT_ROCK, "ore": 1},
		{"kind": Catalog.FEAT_ORE_MEGA, "ore": 3},
		{"kind": Catalog.FEAT_ORE_SUPER, "ore": 4},
		{"kind": Catalog.FEAT_ORE_ULTRA, "ore": 5},
		{"kind": Catalog.FEAT_MONOLITH, "ore": 0},
		{"kind": Catalog.FEAT_COSMETIC, "ore": 0},
		{"kind": Catalog.FEAT_COSMETIC_BAD, "ore": 0},
		{"kind": Catalog.FEAT_FIRE, "ore": 0},
		{"kind": Catalog.FEAT_TOTEM, "ore": 0},
	]
	for spec in features_to_place:
		var kind := int(spec.kind)
		var size := Catalog.footprint_for_feature(kind)
		var halo := 0 if size == Vector2i(1, 1) else 1
		var at := _shot_spot(taken, size, halo, 40.0, 1)
		if at.x < 0.0 or _shot_add_feature(kind, at.x, at.y, int(spec.ore)).is_empty():
			missed.append("feature %s" % kind)
	shot_throng = _push_slot(200.0, 300.0, 55.0, 70.0, 8.0, 0.0, 0)
	if shot_throng >= 0:
		peak = maxi(peak, 1)
	for b in buildings:
		if int(b.kind) == Catalog.BLD_FACTORY:
			_shot_fill_factory(b)
			shot_factory = int(b.id)
			break
	if shot_factory < 0:
		var at := _shot_spot(taken, Catalog.footprint_for_building(Catalog.BLD_FACTORY), 0, 16.0, 0)
		if at.x >= 0.0:
			var placed := _add_building(Catalog.BLD_FACTORY, at.x, at.y)
			if not placed.is_empty():
				_shot_fill_factory(placed)
				shot_factory = int(placed.id)
	var path_cells := _stamp_shot_path()
	shot_focus = Vector2(256, 256)
	shot_span = _island_reach() + 48.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	unlocks.bathtub = true
	unlocks.apple_tree = true
	unlocks.roundabout = true
	unlocks.axe = true
	unlocks.hammer = true
	unlocks.dwelling = true
	unlocks.bug = true
	gems = 20
	unlock_serial += 1
	notes.clear()
	sfx_queue.clear()
	pops.clear()
	barks.clear()
	modal = {}
	frozen = false
	_rebuild_hash()
	smoke_hold = true
	print("SHOT READY buildings=%s features=%s items=%s factory=%s path=%s missed=%s" % [buildings.size(), features.size(), items.size(), shot_factory, path_cells, missed])


func _shot_open_grass(cell: Vector2i) -> bool:
	if building_cell.has(cell) or feature_cell.has(cell):
		return false
	var at := Catalog.cell_world(cell)
	if _tile_at(at.x, at.y) != Catalog.TILE_GRASS:
		return false
	for spot in [cell + Vector2i(1, 0), cell + Vector2i(-1, 0), cell + Vector2i(0, 1), cell + Vector2i(0, -1)]:
		var around := Catalog.cell_world(spot)
		if _tile_at(around.x, around.y) == Catalog.TILE_VOID:
			return false
	return true


func _stamp_shot_path() -> int:
	var origin := Vector2i(-1, -1)
	var best := -1
	for y in range(8, 24):
		for x in range(6, 22):
			var open := true
			for i in 6:
				if not _shot_open_grass(Vector2i(x + i, y)):
					open = false
					break
			if not open:
				continue
			for i in range(1, 4):
				if not _shot_open_grass(Vector2i(x + 2, y + i)):
					open = false
					break
			if not open:
				continue
			var at := Catalog.cell_world(Vector2i(x + 3, y + 1))
			var score := 999999
			for b in buildings:
				if b.dead:
					continue
				score = mini(score, int(_dist_point(at.x, at.y, float(b.x), float(b.y))))
			for feat in features:
				if feat.dead:
					continue
				score = mini(score, int(_dist_point(at.x, at.y, float(feat.x), float(feat.y))))
			if score > best:
				best = score
				origin = Vector2i(x, y)
	if origin.x < 0:
		return 0
	var cells: Array[Vector2i] = []
	for i in 6:
		cells.append(origin + Vector2i(i, 0))
	for i in range(1, 4):
		cells.append(origin + Vector2i(2, i))
	for cell in cells:
		wear["%d,%d" % [cell.x, cell.y]] = WEAR_NEED
		_mark_path(cell)
	shot_path = Catalog.cell_world(origin + Vector2i(3, 1))
	return cells.size()


func _clear_shot_props() -> void:
	features.clear()
	feature_by_id.clear()
	feature_cell.clear()
	buildings.clear()
	building_by_id.clear()
	building_cell.clear()
	items.clear()
	item_by_id.clear()
	tree_seeds.clear()
	for i in slot_count:
		state[i] = Catalog.ST_VACANT
	living = 0
	hand_id = -1
	_clear_held()
	_rebuild_kind_indexes()
	_invalidate_factory_cache()
	_invalidate_walk_cells()


func _shot_spot(taken: Dictionary, size: Vector2i, halo: int = 1, margin: float = 40.0, skirt: int = 0) -> Vector2:
	var reach := _island_reach() - margin
	for y in range(6, 27):
		for x in range(6, 27):
			var anchor := Vector2i(x, y)
			var world := Catalog.cell_world(anchor)
			var cells := _footprint_cells(world.x, world.y, size)
			var ok := true
			for cell in cells:
				if taken.has(cell):
					ok = false
					break
				var at := Catalog.cell_world(cell)
				if _dist_point(256.0, 256.0, at.x, at.y) > reach or not _tile_holds(at.x, at.y):
					ok = false
					break
				for oy in range(-skirt, skirt + 1):
					for ox in range(-skirt, skirt + 1):
						var around := Catalog.cell_world(cell + Vector2i(ox, oy))
						if not _tile_holds(around.x, around.y):
							ok = false
							break
					if not ok:
						break
				if not ok:
					break
			if not ok:
				continue
			for cell in cells:
				for oy in range(-halo, halo + 1):
					for ox in range(-halo, halo + 1):
						taken[cell + Vector2i(ox, oy)] = true
			return world
	return Vector2(-1, -1)


func _shot_add_feature(kind: int, x: float, y: float, ore: int) -> Dictionary:
	var id := next_feature_id
	next_feature_id += 1
	var c := _chunk_at(x, y)
	var feat := {
		"id": id,
		"kind": kind,
		"x": x,
		"y": y,
		"hp": 2,
		"ore": ore,
		"cx": c.x,
		"cy": c.y,
		"dead": false,
		"rooted": true,
	}
	if not _bind_feature_at(feat, x, y):
		return {}
	features.append(feat)
	feature_by_id[id] = feat
	return feat


func _smoke_find_spot(kind: int, hints: Array) -> Vector2:
	for spot in hints:
		var at: Vector2 = spot
		if can_place_building(kind, at.x, at.y):
			return Catalog.snap_world(at.x, at.y)
	for ly in range(4, Catalog.CHUNK - 4, 2):
		for lx in range(4, Catalog.CHUNK - 4, 2):
			var wx := float(lx * Catalog.TILE + 8)
			var wy := float(ly * Catalog.TILE + 8)
			if can_place_building(kind, wx, wy):
				return Catalog.snap_world(wx, wy)
	return Vector2.ZERO


func _shot_fill_factory(b: Dictionary) -> void:
	var piled: Array = []
	for n in 24:
		piled.append(n + 1)
	b.pile = piled
	b.buffer = piled.size()


func _factory_pile(b: Dictionary) -> Array:
	var found = b.get("pile", [])
	if found is Array:
		return found
	var fresh: Array = []
	b.pile = fresh
	return fresh


func _factory_cycle_time(kind: int) -> float:
	return FACTORY_PROCESS_TIME2 if kind == Catalog.BLD_FACTORY2 else FACTORY_PROCESS_TIME


func factory_process_progress(b: Dictionary) -> float:
	# 0 at cycle start → 1 when the current ore is about to become energy.
	if b.is_empty() or bool(b.get("dead", true)):
		return 0.0
	if int(b.get("buffer", 0)) <= 0:
		return 0.0
	var cycle := _factory_cycle_time(int(b.kind))
	if cycle <= 0.01:
		return 0.0
	return clampf(1.0 - float(b.get("timer", 0.0)) / cycle, 0.0, 1.0)


func _factory_stack(b: Dictionary, n: int) -> void:
	var pile := _factory_pile(b)
	var was_empty := pile.is_empty() and int(b.get("buffer", 0)) <= 0
	var start := pile.size()
	for k in n:
		pile.append(start + k + 1)
	b.pile = pile
	b.buffer = pile.size()
	# First ore in an idle factory starts a fresh process cycle.
	if was_empty and n > 0:
		b.timer = _factory_cycle_time(int(b.kind))


func _factory_spend(b: Dictionary) -> void:
	var pile := _factory_pile(b)
	if pile.is_empty():
		b.buffer = maxi(0, int(b.get("buffer", 0)) - 1)
		return
	pile.pop_front()
	b.pile = pile
	b.buffer = pile.size()


func _check_factory_fill(errors: Array) -> void:
	var factory := {}
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			factory = b
			break
	if factory.is_empty():
		var spot := _smoke_find_spot(Catalog.BLD_FACTORY, [
			Vector2(300.0, 300.0), Vector2(140.0, 200.0), Vector2(360.0, 180.0), Vector2(160.0, 320.0),
			Vector2(200.0, 180.0), Vector2(240.0, 340.0), Vector2(168.0, 216.0),
		])
		if spot != Vector2.ZERO:
			factory = _add_building(Catalog.BLD_FACTORY, spot.x, spot.y)
	if factory.is_empty():
		for ly in range(3, Catalog.CHUNK - 3):
			for lx in range(3, Catalog.CHUNK - 3):
				var wx := float(lx * Catalog.TILE + 8)
				var wy := float(ly * Catalog.TILE + 8)
				var at := Catalog.snap_world(wx, wy)
				if not _building_spot_free(-1, at.x, at.y, Catalog.BLD_FACTORY):
					continue
				factory = _add_building(Catalog.BLD_FACTORY, at.x, at.y)
				if not factory.is_empty():
					break
			if not factory.is_empty():
				break
	if factory.is_empty():
		errors.append("factory fill: no building")
		return
	var main := get_tree().current_scene
	if main == null or not main.has_method("_sync_factory_mark"):
		errors.append("factory fill: no view")
		return
	factory.buffer = 0
	factory.pile = []
	factory.timer = 0.25
	main.selected_bld = int(factory.id)
	var i := 0
	pos_x[i] = float(factory.x)
	pos_y[i] = float(factory.y)
	var cycle := _factory_cycle_time(Catalog.BLD_FACTORY)
	# Ring tracks process time, not stock: empty at cycle start, full at the end.
	_set_carry(i, Catalog.CARRY_ORE, 1)
	_deliver(i, MOVE_SPEED, 0.05)
	if int(factory.get("buffer", 0)) < 1:
		errors.append("factory fill: deposit failed")
		return
	factory.timer = cycle
	main._sync_factory_mark(self)
	var shown0 := 0
	for slice in main.factory_slices:
		if slice.visible:
			shown0 += 1
	if shown0 != 0:
		errors.append("factory fill: expected 0 slices at cycle start got %d" % shown0)
	factory.timer = cycle * 0.5
	main._sync_factory_mark(self)
	var shown_mid := 0
	for slice in main.factory_slices:
		if slice.visible:
			shown_mid += 1
	if shown_mid != FACTORY_WEDGES / 2:
		errors.append("factory fill: expected %d slices at mid-cycle got %d" % [FACTORY_WEDGES / 2, shown_mid])
	factory.timer = 0.0
	main._sync_factory_mark(self)
	var shown_end := 0
	for slice in main.factory_slices:
		if slice.visible:
			shown_end += 1
	if shown_end != FACTORY_WEDGES:
		errors.append("factory fill: expected %d slices at cycle end got %d" % [FACTORY_WEDGES, shown_end])
	print("FACTORY FILL time wedges start=%d mid=%d end=%d buffer=%d" % [
		shown0, shown_mid, shown_end, int(factory.get("buffer", 0)),
	])
	# Pile still stacks beyond the ring; order is FIFO for spend.
	factory.buffer = 0
	factory.pile = []
	var deposits := FACTORY_WEDGES + 2
	for step in deposits:
		_set_carry(i, Catalog.CARRY_ORE, 1)
		pos_x[i] = float(factory.x)
		pos_y[i] = float(factory.y)
		_deliver(i, MOVE_SPEED, 0.05)
	var piled: Array = factory.get("pile", [])
	var order := PackedStringArray()
	for token in piled:
		order.append(str(int(token)))
	print("FACTORY PILE " + " ".join(order))
	var want := PackedStringArray()
	for n in deposits:
		want.append(str(n + 1))
	if " ".join(order) != " ".join(want):
		errors.append("factory pile order " + " ".join(order))
	_factory_spend(factory)
	var left: Array = factory.get("pile", [])
	if left.size() != deposits - 1:
		errors.append("factory pile spend")
	elif int(left[0]) != 2:
		errors.append("factory pile spend")


func _check_opening(errors: Array) -> void:
	var dos := LineBook.row("SYS.GAME_INTRO", 3)
	var clean := LineBook.row("SYS.MESSAGES", 15)
	var crt := LineBook.row("SYS.SETTINGS", 14)
	print("OPENING DOS " + dos.replace("\\n", " | "))
	print("OPENING CLEAN " + clean)
	print("OPENING CRT " + crt)
	if "TS-DOZ" not in dos or "HIMEM" not in dos or "TUCK96.IMG" not in dos:
		errors.append("dos text")
	if "TROPELES" not in dos or "NOHZDYVE" not in dos or "TSOFT_EDITOR" not in dos:
		errors.append("dos dir")
	if "limpieza" not in clean:
		errors.append("tutorial sign")
	if crt != "Filtro de TRC":
		errors.append("crt label")
	tutorial_i = 0
	count_unknown = true
	advance_tutorial()
	advance_tutorial()
	advance_tutorial()
	if tutorial_i != -1:
		errors.append("tutorial end")
	_know_count()
	if count_unknown:
		errors.append("count mark")


func _check_player_name(errors: Array) -> void:
	if str(modal.get("event", "")) != "player_name":
		errors.append("name prompt missing")
		print("NAME MISSING")
		return
	submit_name("")
	var empty_log := " ".join(modal.get("log", []))
	submit_name("shit")
	var banned_log := " ".join(modal.get("log", []))
	submit_name("€")
	var charset_log := " ".join(modal.get("log", []))
	submit_name("Ana")
	var asked := str(modal.get("step", "")) == "confirm" and "Ana" in " ".join(modal.get("log", []))
	choose(1)
	var declined := str(modal.get("step", "")) == "ask"
	submit_name("Ana")
	choose(0)
	var echo := " ".join(modal.get("log", []))
	var echoed := str(modal.get("step", "")) == "echo" and ">> entrada \"Ana\"" in echo
	choose(0)
	var stored := player_name == "Ana" and modal.is_empty()
	print("NAME EMPTY " + empty_log)
	print("NAME BANNED " + banned_log)
	print("NAME CHARSET " + charset_log)
	print("NAME ECHO " + echo)
	if "entrada" not in empty_log:
		errors.append("name empty")
	if "inapropiado" not in banned_log:
		errors.append("name banned")
	if "reconoce" not in charset_log:
		errors.append("name charset")
	if not asked or not declined or not echoed or not stored:
		errors.append("name confirm")


func _run_checks() -> void:
	var errors: Array = []
	DialogueBook.ensure()
	if not DialogueBook.has_tree("first_born"):
		errors.append("dialogue tree first_born missing")
	if not DialogueBook.trees.has("CH02_S03_010INT1"):
		errors.append("dialogue tree CH02_S03_010INT1 missing")
	if not DialogueBook.trees.has("ACT3_S020_GAPINGMAW"):
		errors.append("dialogue tree ACT3_S020_GAPINGMAW missing")
	var sample: Dictionary = DialogueBook.open_session("learn_self")
	if sample.is_empty() or not str(DialogueBook.log_text(sample)).begins_with(">"):
		errors.append("learn_self terminal log missing")
	if living != 0:
		errors.append("start living %s" % living)
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
			continue
		if _near_spawn(float(feat.x), float(feat.y)):
			errors.append("tree in spawn clearing")
			break
	var egg := _nearest_item(256.0, 256.0, Catalog.ITEM_EGG, 40.0)
	if egg.is_empty():
		errors.append("no starter egg")
	else:
		if float(egg.get("air", 0.0)) <= 0.0:
			errors.append("egg not falling")
		egg.air = 0.0
		egg.fall = 0.0
		for _n in EGG_NEED:
			_help_egg(egg)
		if living != 1:
			errors.append("hatch living %s" % living)
		if not egg.dead:
			errors.append("egg remains")
		if modal.is_empty() or str(modal.get("event", "")) != "first_born":
			errors.append("first_born talk missing")
		else:
			var guard := 0
			while not modal.is_empty() and guard < 80:
				if str(modal.get("event", "")) == "player_name":
					break
				choose(0)
				guard += 1
			_check_player_name(errors)
		if LineBook.lines_for("first_born").is_empty():
			errors.append("first_born lines missing")
		if _ethics_choice("first_born") == -1:
			errors.append("first_born ethics missing")
		var again := _add_item(Catalog.ITEM_EGG, 260.0, 260.0, 0)
		again.air = 0.0
		again.hatch = 0
		again.need = 1
		_help_egg(again)
		if living != 1:
			errors.append("second egg spawned multi")
		if not again.dead:
			errors.append("second egg remains")
	if not bool(unlocks.camera):
		errors.append("camera locked at start")
	if bool(unlocks.axe):
		errors.append("axe early")
	if living < 1:
		errors.append("no first multi")
	else:
		fed[0] = 100.0
		amused[0] = 100.0
		clean[0] = 100.0
		cool[0] = 0.0
		shake_t[0] = 0.0
		mito_t[0] = 0.0
		mito_charge[0] = 0.0
		for _n in 40:
			fed[0] = 100.0
			amused[0] = 100.0
			clean[0] = 100.0
			cool[0] = 0.0
			_step(0.2)
			if living >= 2:
				break
		if living < 2:
			errors.append("mitosis living %s" % living)
		_queue_talk("learn_self", {})
		var talk_guard := 0
		while not modal.is_empty() and talk_guard < 80:
			choose(0)
			talk_guard += 1
		if LineBook.lines_for("learn_self").is_empty():
			errors.append("learn_self lines missing")
		if _ethics_choice("learn_self") == -1:
			errors.append("learn_self ethics missing")
	if not bool(unlocks.camera):
		errors.append("camera locked after hatch")
	peak = 6
	_refresh_pop_gates(false)
	if not modal.is_empty():
		errors.append("quiet grant opened talk")
	if not bool(unlocks.axe):
		errors.append("axe at 6")
	if bool(unlocks.hammer) or bool(unlocks.bathtub):
		errors.append("build before tools at 6")
	trees_chopped = 1
	_refresh_pop_gates(false)
	if not bool(unlocks.hammer):
		errors.append("hammer after chop")
	if bool(unlocks.bathtub):
		errors.append("bathtub before stump")
	stumps_cleared = 1
	_refresh_pop_gates(false)
	if not bool(unlocks.bathtub):
		errors.append("bathtub after stump")
	if bool(unlocks.apple_tree):
		errors.append("apple before tub")
	peak = 12
	_refresh_pop_gates(false)
	if bool(unlocks.apple_tree) or bool(unlocks.roundabout):
		errors.append("care builds from peak")
	if _count_mine_nodes(0, 0) < 1:
		errors.append("home mine nodes missing")
	if not bool(unlocks.axe):
		errors.append("axe locked")
	var tree := {}
	for feat in features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE and int(feat.cx) == 0:
			tree = feat
			break
	if tree.is_empty():
		errors.append("no tree")
	else:
		var tree_at := Vector2(float(tree.x), float(tree.y))
		tree.rooted = false
		grab_at(tree_at.x, tree_at.y)
		var tree_moved := float(tree.x) != tree_at.x or float(tree.y) != tree_at.y
		if held_kind == "rock" or tree_moved:
			errors.append("terrain tree movable")
		cancel_hold()
		tree.rooted = true
		_chop(tree)
		if int(tree.kind) != Catalog.FEAT_STUMP or count_item(Catalog.ITEM_WOOD) < 1:
			errors.append("chop")
		_hammer_feature(tree)
		if not tree.dead:
			errors.append("stump remains")
	_expand_super_island(false)
	if not part_two:
		errors.append("part two not reached")
	_shape_island()
	var drain_i := 0
	while not modal.is_empty() and drain_i < 128:
		choose(0)
		drain_i += 1
	frozen = false
	_restore_gaze()
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING:
			pos_x[i] = 120.0
			pos_y[i] = 120.0
	var ore_node := {}
	for feat in features:
		if not feat.dead and int(feat.cx) == 0 and _ore_tier(int(feat.kind)) > 0:
			ore_node = feat
			break
	if ore_node.is_empty():
		errors.append("no ore node for mine")
	else:
		unlocks["mine"] = true
		# Keep wood outside the 6x5 mine footprint so _item_spot_free passes.
		_add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 112.0, float(ore_node.y) + 96.0, 1)
		_add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 128.0, float(ore_node.y) + 96.0, 1)
		if not can_place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine blocked on ore node")
		elif not place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine place on ore node")
		elif _count_mine_nodes(0, 0) < 1:
			errors.append("mine ate every ore node")
	frozen = false
	var market_at := Vector2(256.0, 200.0)
	var market_ok := false
	for spot in [Vector2(256.0, 200.0), Vector2(220.0, 220.0), Vector2(280.0, 220.0), Vector2(256.0, 300.0), Vector2(180.0, 320.0), Vector2(320.0, 160.0), Vector2(160.0, 200.0), Vector2(300.0, 300.0)]:
		if can_place_building(Catalog.BLD_MARKET, spot.x, spot.y):
			market_at = spot
			market_ok = true
			break
	if not market_ok or not place_building(Catalog.BLD_MARKET, market_at.x, market_at.y):
		errors.append("market place free")
	elif place_building(Catalog.BLD_MARKET, market_at.x + 40.0, market_at.y):
		errors.append("market unique broken")
	var tub_spot := _smoke_find_spot(Catalog.BLD_TUB, [
		Vector2(200.0, 280.0), Vector2(180.0, 260.0), Vector2(220.0, 300.0),
		Vector2(140.0, 300.0), Vector2(300.0, 140.0), Vector2(340.0, 240.0), Vector2(100.0, 220.0),
	])
	if tub_spot == Vector2.ZERO or not place_building(Catalog.BLD_TUB, tub_spot.x, tub_spot.y):
		errors.append("tub place for solid")
	else:
		if not bool(unlocks.apple_tree):
			errors.append("apple after tub")
		if bool(unlocks.roundabout):
			errors.append("round before apple")
		if not _blocked(tub_spot.x, tub_spot.y):
			errors.append("tub not solid")
		var rim := _approach_building({"kind": Catalog.BLD_TUB, "x": tub_spot.x, "y": tub_spot.y, "id": -1}, -1)
		if _blocked(rim.x, rim.y):
			errors.append("tub approach blocked")
		var apple_spot := _smoke_find_spot(Catalog.BLD_APPLE, [
			Vector2(tub_spot.x + 64.0, tub_spot.y + 48.0), Vector2(220.0, 200.0), Vector2(280.0, 280.0),
			Vector2(120.0, 280.0), Vector2(320.0, 160.0), Vector2(180.0, 340.0),
		])
		if apple_spot == Vector2.ZERO or not place_building(Catalog.BLD_APPLE, apple_spot.x, apple_spot.y):
			errors.append("apple place for unlock")
		elif not bool(unlocks.roundabout):
			errors.append("round after apple")
	var dug := {}
	for b in buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MINE:
			dug = b
			break
	if dug.is_empty():
		errors.append("mine missing for ore drop")
	else:
		var drop := _loot_spot(dug)
		if _blocked(drop.x, drop.y):
			errors.append("ore drop blocked")
		if int(building_cell.get(_cell_vec(drop.x, drop.y), -1)) == int(dug.id):
			errors.append("ore drop on mine")
		var gate := _approach_building(dug, 0)
		if _blocked(gate.x, gate.y):
			errors.append("mine approach blocked")
		elif state[0] == Catalog.ST_LIVING:
			var back := Vector2(pos_x[0], pos_y[0])
			pos_x[0] = gate.x
			pos_y[0] = gate.y
			fed[0] = 90.0
			amused[0] = 90.0
			clean[0] = 90.0
			_set_carry(0, Catalog.CARRY_NONE)
			act[0] = 0
			act_t[0] = 0.0
			_seek_mine(0, MOVE_SPEED, 0.2)
			if int(act[0]) != ACT_WORK:
				errors.append("mine work not started")
			else:
				# Dirty thronglets must not keep working / seeking the mine.
				clean[0] = 20.0
				act[0] = 0
				act_t[0] = 0.0
				if _seek_mine(0, MOVE_SPEED, 0.2) or int(act[0]) == ACT_WORK:
					errors.append("dirty thronglet sought mine")
				clean[0] = 90.0
				act[0] = 0
				act_t[0] = 0.0
				_seek_mine(0, MOVE_SPEED, 0.2)
				if int(act[0]) != ACT_WORK:
					errors.append("mine work not resumed")
				# Cap is 2: claim the walk so a third ready thronglet cannot join.
				var helper := -1
				for hi in slot_count:
					if hi != 0 and state[hi] == Catalog.ST_LIVING:
						helper = hi
						break
				if helper >= 0 and int(act[0]) == ACT_WORK:
					var helper_back := Vector2(pos_x[helper], pos_y[helper])
					pos_x[helper] = gate.x + 6.0
					pos_y[helper] = gate.y + 6.0
					fed[helper] = 90.0
					amused[helper] = 90.0
					clean[helper] = 90.0
					_set_carry(helper, Catalog.CARRY_NONE)
					_set_mine_job(0, int(dug.id))
					_set_mine_job(helper, int(dug.id))
					act[helper] = ACT_WORK
					act_t[helper] = 0.5
					var third := -1
					for ti in slot_count:
						if ti != 0 and ti != helper and state[ti] == Catalog.ST_LIVING:
							third = ti
							break
					if third >= 0:
						pos_x[third] = gate.x - 10.0
						pos_y[third] = gate.y - 10.0
						fed[third] = 90.0
						amused[third] = 90.0
						clean[third] = 90.0
						_set_carry(third, Catalog.CARRY_NONE)
						act[third] = 0
						act_t[third] = 0.0
						_set_mine_job(third, -1)
						if _seek_mine(third, MOVE_SPEED, 0.2):
							errors.append("mine over capacity seek")
						if int(act[third]) == ACT_WORK:
							errors.append("mine over capacity work")
						if int(mine_job[third]) == int(dug.id):
							errors.append("mine over capacity job")
					pos_x[helper] = helper_back.x
					pos_y[helper] = helper_back.y
					act[helper] = 0
					act_t[helper] = 0.0
					_set_mine_job(helper, -1)
				var stock_before := int(dug.get("buffer", 0))
				dug.timer = 0.01
				_tick_buildings(0.05)
				if int(act[0]) != ACT_WORK:
					errors.append("mine worker lost before ore drop")
				elif int(dug.get("buffer", 0)) <= stock_before:
					errors.append("mine did not stock ore")
				else:
					# Mines stock into buffer; seed a ground pile for haul-path coverage.
					_add_item(Catalog.ITEM_ORE, drop.x, drop.y, 1)
					var factory := {}
					var factory_free := 0
					for ly in range(3, Catalog.CHUNK - 3):
						for lx in range(3, Catalog.CHUNK - 3):
							var wx := float(lx * Catalog.TILE + 8)
							var wy := float(ly * Catalog.TILE + 8)
							var at := Catalog.snap_world(wx, wy)
							if not _building_spot_free(-1, at.x, at.y, Catalog.BLD_FACTORY):
								continue
							factory_free += 1
							factory = _add_building(Catalog.BLD_FACTORY, at.x, at.y)
							if not factory.is_empty():
								break
						if not factory.is_empty():
							break
					if factory.is_empty():
						errors.append("factory for ore haul")
						print("SMOKE DBG factory_free=%s feats=%s trees=%s rocks=%s" % [
							factory_free, features.size(),
							_count_kind_on(0, 0, Catalog.FEAT_TREE),
							_count_kind_on(0, 0, Catalog.FEAT_ROCK) + _count_kind_on(0, 0, Catalog.FEAT_BIGROCK),
						])
					else:
						var ore_it := _nearest_free_item(0, Catalog.ITEM_ORE, 180.0)
						if ore_it.is_empty():
							errors.append("ore missing for haul")
						else:
							pos_x[0] = float(ore_it.x)
							pos_y[0] = float(ore_it.y)
							_walk_pickup(0, ore_it, Catalog.CARRY_ORE, MOVE_SPEED, 1.0)
							if carry[0] != Catalog.CARRY_ORE:
								errors.append("ore haul pickup")
							else:
								pos_x[0] = float(factory.x)
								pos_y[0] = float(factory.y)
								_deliver(0, MOVE_SPEED, 0.2)
								if carry[0] != Catalog.CARRY_NONE:
									errors.append("ore haul deliver")
								elif int(factory.get("buffer", 0)) < 1:
									errors.append("factory missed ore")
								_remove_building(factory)
			pos_x[0] = back.x
			pos_y[0] = back.y
			act[0] = 0
			act_t[0] = 0.0
			_set_carry(0, Catalog.CARRY_NONE)
	var round_b := {}
	for spot in [Vector2(300.0, 300.0), Vector2(140.0, 200.0), Vector2(360.0, 180.0), Vector2(160.0, 320.0), Vector2(200.0, 180.0), Vector2(240.0, 340.0), Vector2(340.0, 260.0)]:
		var at := Catalog.snap_world(spot.x, spot.y)
		if _building_spot_free(-1, at.x, at.y, Catalog.BLD_ROUND):
			round_b = _add_building(Catalog.BLD_ROUND, at.x, at.y)
			if not round_b.is_empty():
				break
	if round_b.is_empty():
		var round_spot := _smoke_find_spot(Catalog.BLD_ROUND, [])
		if round_spot != Vector2.ZERO:
			round_b = _add_building(Catalog.BLD_ROUND, round_spot.x, round_spot.y)
	if round_b.is_empty():
		errors.append("roundabout place")
	elif state[0] == Catalog.ST_LIVING:
		var back := Vector2(pos_x[0], pos_y[0])
		var gate := _approach_building(round_b, 0)
		pos_x[0] = gate.x
		pos_y[0] = gate.y
		amused[0] = 40.0
		_do_roundabout_ride(0, round_b, 0.2)
		var ride_mid := _ride_center_of(round_b)
		if _ride_spot_blocked(pos_x[0], pos_y[0], round_b):
			errors.append("roundabout ride blocked")
		if _dist_i(0, ride_mid.x, ride_mid.y) > _ride_radius(round_b) + 6.0:
			errors.append("roundabout ride off pad")
		if _ride_building(0).is_empty():
			errors.append("roundabout lost rider")
		amused[0] = Catalog.NEED_OK
		_leave_ride(0, round_b)
		if not _ride_building(0).is_empty():
			errors.append("roundabout kept rider")
		if _blocked(pos_x[0], pos_y[0]):
			errors.append("roundabout left them blocked")
		if _is_rider(round_b, 0):
			errors.append("roundabout did not let go")
		pos_x[0] = back.x
		pos_y[0] = back.y
		act[0] = 0
		act_t[0] = 0.0
		_remove_building(round_b)
	elif not round_b.is_empty():
		_remove_building(round_b)
	var spare := {}
	for feat in features:
		if not feat.dead and _ore_tier(int(feat.kind)) > 0:
			spare = feat
			break
	if spare.is_empty():
		errors.append("no spare node")
	else:
		for it in items:
			if int(it.kind) == Catalog.ITEM_WOOD:
				it.dead = true
		for raw in living_ids:
			var i := int(raw)
			if carry[i] == Catalog.CARRY_WOOD:
				_set_carry(i, Catalog.CARRY_NONE)
		var node_id := int(spare.id)
		place_building(Catalog.BLD_MINE, float(spare.x), float(spare.y))
		var still = feature_by_id.get(node_id, {})
		if still.is_empty() or still.dead:
			errors.append("mine ate node without wood")
	var tub_b := {}
	for b in buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_TUB:
			tub_b = b
			break
	if tub_b.is_empty():
		errors.append("tub missing for select")
	else:
		cancel_hold()
		var grabbed := grab_at(float(tub_b.x), float(tub_b.y))
		if held_kind == "building":
			errors.append("eye must not lift buildings")
			_clear_held()
			if bool(tub_b.get("lifted", false)):
				tub_b.lifted = false
				_bind_building_at(tub_b, float(tub_b.x), float(tub_b.y))
		elif grabbed:
			cancel_hold()
	var market_b := {}
	for b in buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MARKET:
			market_b = b
			break
	if market_b.is_empty():
		errors.append("market missing for select")
	else:
		cancel_hold()
		var market_grab := grab_at(float(market_b.x), float(market_b.y))
		if held_kind == "building":
			errors.append("eye must not lift buildings")
			_clear_held()
			if bool(market_b.get("lifted", false)):
				market_b.lifted = false
				_bind_building_at(market_b, float(market_b.x), float(market_b.y))
		elif market_grab:
			cancel_hold()
		frozen = false
		var hit := eye_use(float(market_b.x), float(market_b.y))
		if str(hit.get("type", "")) != "market":
			errors.append("eye select building")
	var forest := {}
	for feat in features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE:
			forest = feat
			break
	if not forest.is_empty() and not _blocked(float(forest.x), float(forest.y)):
		errors.append("tree not solid")
	for feat in features:
		if feat.dead:
			continue
		var grid := Catalog.snap_world(float(feat.x), float(feat.y))
		if absf(float(feat.x) - grid.x) > 0.01 or absf(float(feat.y) - grid.y) > 0.01:
			errors.append("feature off grid")
			break
	if living >= 1 and state[0] == Catalog.ST_LIVING:
		# Outside SPAWN_CLEAR so rooted trees are allowed.
		var corner := _cell_vec(140.0, 140.0)
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				var key := Vector2i(corner.x + ox, corner.y + oy)
				if feature_cell.has(key):
					var fid := int(feature_cell[key])
					var feat = feature_by_id.get(fid, {})
					if not feat.is_empty():
						feat.dead = true
					feature_cell.erase(key)
				_set_world_cell(key.x, key.y, Catalog.TILE_GRASS, true)
		var open_at := Catalog.cell_world(corner)
		var block_at := Catalog.cell_world(corner + Vector2i(1, 1))
		# rooted=false: canopy span would fail _stands on the small grass patch.
		var corner_tree := _add_feature(Catalog.FEAT_TREE, block_at.x, block_at.y, 1, 0, false)
		if corner_tree.is_empty():
			errors.append("tree corner setup")
		else:
			pos_x[0] = open_at.x
			pos_y[0] = open_at.y
			dir_x[0] = 1.0
			dir_y[0] = 1.0
			var corner_start := Vector2(pos_x[0], pos_y[0])
			var into_tree := 0
			for _n in 90:
				_walk(0, block_at.x, block_at.y, MOVE_SPEED, 0.08)
				if _move_blocked(pos_x[0], pos_y[0]):
					into_tree += 1
			if _dist_point(pos_x[0], pos_y[0], corner_start.x, corner_start.y) < 12.0:
				errors.append("stuck on tree corner")
			if into_tree > 0 or _move_blocked(pos_x[0], pos_y[0]):
				errors.append("walked into tree")
	_rebuild_hash()
	if find_thronglet(pos_x[0], pos_y[0], 8.0, true) != 0:
		errors.append("hash miss")
	if living >= 1 and state[0] == Catalog.ST_LIVING:
		var cove := _cell_vec(240.0, 240.0)
		for oy in range(-6, 7):
			for ox in range(-6, 7):
				var cx := cove.x + ox
				var cy := cove.y + oy
				var key := Vector2i(cx, cy)
				if feature_cell.has(key):
					var fid := int(feature_cell[key])
					var feat = feature_by_id.get(fid, {})
					if not feat.is_empty():
						feat.dead = true
					feature_cell.erase(key)
				# Grass core west/north; water east/south. Lip stays unwalkable under inland pad.
				var water := ox >= 1 or oy >= 1
				_set_world_cell(cx, cy, Catalog.TILE_WATER if water else Catalog.TILE_GRASS, true)
		# Start on an inland cell, not the water lip.
		pos_x[0] = float(cove.x - 1) * Catalog.TILE + Catalog.TILE * 0.5
		pos_y[0] = float(cove.y - 1) * Catalog.TILE + Catalog.TILE * 0.5
		dir_x[0] = 1.0
		dir_y[0] = 1.0
		var start := Vector2(pos_x[0], pos_y[0])
		for _n in 120:
			_walk(0, start.x + 96.0, start.y + 96.0, MOVE_SPEED, 0.08)
		if _dist_point(pos_x[0], pos_y[0], start.x, start.y) < 28.0:
			errors.append("stuck in water corner")
		if _tile_at(pos_x[0], pos_y[0]) == Catalog.TILE_WATER or not _land_inland(pos_x[0], pos_y[0]):
			errors.append("walked into water")
	while not modal.is_empty():
		choose(0)
	fed[1] = 0.0
	amused[1] = 0.0
	clean[1] = 0.0
	starve[1] = 30.0
	tick_stamp[1] = 0
	_tick_one(1, 0.1)
	if state[1] != Catalog.ST_DEAD:
		errors.append("neglect state")
	if modal.is_empty() or str(modal.get("event", "")) != "neglect":
		errors.append("neglect gaze")
	else:
		while not modal.is_empty():
			choose(0)
	if frozen:
		errors.append("frozen after choice")
	var live_now := living
	var gems_now := gems
	if not save_system.save_game():
		errors.append("save failed")
	gems = 999
	if not save_system.load_game():
		errors.append("load failed")
	elif living != live_now or gems != gems_now:
		errors.append("load mismatch living %s/%s gems %s/%s" % [living, live_now, gems, gems_now])
	var before_goal := features.size()
	goal_line()
	if features.size() != before_goal:
		errors.append("goal line mutated world")
	var victim := -1
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING:
			victim = i
			break
	unlocks.bug = true
	var pop := living
	if victim >= 0:
		_tool_bug(pos_x[victim], pos_y[victim])
		if living != pop:
			errors.append("bug killed early")
		if modal.is_empty():
			errors.append("bug modal missing")
		else:
			choose(2)
			if living != pop:
				errors.append("bug killed on refuse")
	var tub_now := {}
	for b in buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_TUB:
			tub_now = b
			break
	if living > 1 and not tub_now.is_empty():
		var bather := -1
		for i in slot_count:
			if state[i] == Catalog.ST_LIVING:
				bather = i
				break
		_claim_tub(bather, tub_now)
		var pop_now := living
		_deflesh(bather, false)
		if int(tub_now.occupant) != -1:
			errors.append("deflesh left tub occupied")
		if living != pop_now - 1:
			errors.append("deflesh living %s" % living)
		if game_over:
			errors.append("deflesh ended with others alive")
	while living > 1:
		var last := -1
		for i in slot_count:
			if state[i] == Catalog.ST_LIVING:
				last = i
				break
		if last < 0:
			break
		_become_corpse(last)
	if living == 1:
		var last_one := -1
		for i in slot_count:
			if state[i] == Catalog.ST_LIVING:
				last_one = i
				break
		_deflesh(last_one, false)
	if not game_over:
		errors.append("no game over")
	_check_factory_fill(errors)
	_check_opening(errors)
	print("SMOKE " + ("OK" if errors.is_empty() else "FAIL"))
	for err in errors:
		print(" - " + str(err))
	get_tree().quit(0 if errors.is_empty() else 1)
