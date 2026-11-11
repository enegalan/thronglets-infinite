extends Node

# Colony simulation.
# The bug defleshes a body into bone. The axe leaves a stump. The hammer removes it.
# Mitosis requires food, fun and clean together. The last death ends the run.

const DECAY_FED := 0.12
const DECAY_FUN := 0.07
const DECAY_CLEAN := 0.08
const MOVE_SPEED := 26.0
const MITOSIS_CHARGE := 6.0
const MITOSIS_ANIM := 0.45
const MITOSIS_SPLIT_ALONG := 0.72
const MITOSIS_OFFSET := 12.0
const STARVE_GRACE := 30.0
const EGG_NEED := 4
const EGG_FALL := 140.0
const BALL_LIFE := 60.0
const TALK_OPEN_DELAY := 1.0
const BATH_CLEAN_RATE := 9.0
const BATH_DONE := 95.0
const BATH_MIN_STAY := 5.0
const BATH_ENTER_T := 1.2
# Open grass around the egg so the opening shot stays clear of trees.
const SPAWN_CLEAR := 110.0

var testing := false
var smoke_hold := false
var save_path := "user://thronglets_infinite.save"
var world_seed := 1
var biomes: Array = []
var biome_by_id := {}

var unlocks := {}
var unlock_serial := 0
var ethics: Array = []
var notes: Array = []
var sfx_queue: Array = []
var voice_wait := 0.0
var modal := {}
var talk_pending := {}
var gaze_queue: Array = []
var frozen := false
var moral := 0
var mutations := {}

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
var peak := 0
var land_tier := 0
var bridge_open := false
var glitch_seen := false
var glitch_t := 0.0
var gaze_home := {}
var barks: Array = []
var wear := {}
var wear_from := {}
var shot_mode := false
var shot_focus := Vector2(256, 256)
var shot_span := 210.0
const WEAR_NEED := 40
const WEAR_STEPS := 4
var living := 0
var monolith_tier_spawned := {}

var revealed := {}
var chunks := {}
var bridge_done := {}
var bridges: Array = []
var dirty_chunks: Array = []
var paint_epoch := 0
var sister_cx := 1
var sister_cy := 0
var sister_ready := false

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
var sponge_id := -1
var sponge_hold := 0.0

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
var mito_t := PackedFloat32Array()
var mito_charge := PackedFloat32Array()
var shake_t := PackedFloat32Array()
var buff_t := PackedFloat32Array()
var state := PackedInt32Array()
var carry := PackedInt32Array()
var carry_value := PackedInt32Array()
var tint := PackedInt32Array()
var claim := PackedInt32Array()
var act := PackedInt32Array()
var act_t := PackedFloat32Array()
var tick_stamp := PackedInt32Array()
var pops: Array = []
var current_slot := -1
var paused := false
var game_over := false
# Seconds between autosaves. A later settings screen can change this. Zero turns it off.
var autosave_interval := 60.0
var autosave_t := 0.0
var hash_head := PackedInt32Array()
var hash_next := PackedInt32Array()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shot_mode = args.has("--shot")
	testing = args.has("--smoke") or shot_mode
	if testing:
		save_path = "user://thronglets_smoke.save"
		world_seed = 12345
		smoke_hold = true
	else:
		world_seed = randi()
	hash_head.resize(Catalog.HASH_SIZE)
	hash_head.fill(-1)
	_load_biomes()
	_init_unlocks()
	if testing:
		_bootstrap_new()
	if testing:
		_begin_smoke()


func _process(delta: float) -> void:
	if smoke_hold or paused:
		return
	_step(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not testing and current_slot >= 0 and not game_over:
		save_slot(current_slot)


func _begin_smoke() -> void:
	if shot_mode:
		await get_tree().process_frame
		_prep_shot_world()
		return
	_run_checks()


func _step(delta: float) -> void:
	frame_i += 1
	if frame_i > 1000000:
		frame_i = 1
	if sponge_hold > 0.0:
		sponge_hold = maxf(0.0, sponge_hold - delta)
		if sponge_hold <= 0.0:
			sponge_id = -1
	_tick_talk_wait(delta)
	if not frozen:
		_ensure_bridge_site()
		_tick_items(delta)
		_tick_trees(delta)
		_tick_props(delta)
		_tick_buildings(delta)
		_tick_auras(delta)
		_tick_visible(delta)
		_tick_slice(delta)
		_tick_pops(delta)
		_tick_barks(delta)
		_compact(items)
		_compact(features)
		_compact(buildings)
	_check_milestones()
	_tick_voice(delta)
	_rebuild_hash()
	_tick_autosave(delta)


func _tick_slice(delta: float) -> void:
	if slot_count <= 0:
		return
	var steps := mini(Catalog.SLICE, slot_count)
	var passes := maxi(1, int(ceil(float(slot_count) / float(steps))))
	var dt := delta * float(passes)
	for _s in steps:
		var i := cursor
		cursor = (cursor + 1) % slot_count
		_tick_one(i, dt)
		_sample_mood(i)
		if cursor == 0:
			_publish_mood()


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


func _tick_visible(delta: float) -> void:
	if view_rect.size == Vector2.ZERO or hash_head.is_empty():
		return
	var ids := query_rect(view_rect.grow(48.0))
	for id in ids:
		_tick_one(int(id), delta)


func _tick_one(i: int, dt: float) -> void:
	if i < 0 or i >= slot_count:
		return
	if tick_stamp[i] == frame_i:
		return
	tick_stamp[i] = frame_i
	if state[i] != Catalog.ST_LIVING:
		return
	if held_kind == "thronglet" and i == held_ref:
		return
	if mito_t[i] > 0.0:
		mito_t[i] = maxf(0.0, mito_t[i] - dt)
		if mito_t[i] <= 0.0:
			_finish_mitosis(i)
		return
	var decay := _decay_scale()
	fed[i] = maxf(0.0, fed[i] - DECAY_FED * decay * dt)
	amused[i] = maxf(0.0, amused[i] - DECAY_FUN * decay * dt)
	clean[i] = maxf(0.0, clean[i] - DECAY_CLEAN * decay * dt)
	var tile := _tile_at(pos_x[i], pos_y[i])
	if tile == Catalog.TILE_GOO:
		var goo_hit := 0.35 if bool(mutations.get("adapt", false)) else 0.9
		clean[i] = maxf(0.0, clean[i] - goo_hit * dt)
		fed[i] = maxf(0.0, fed[i] - 0.35 * dt)
	if fed[i] <= 0.0 or amused[i] <= 0.0 or clean[i] <= 0.0:
		starve[i] += dt
		if starve[i] >= STARVE_GRACE:
			_die_neglect(i)
			return
	else:
		starve[i] = 0.0
	if fed[i] < Catalog.NEED_HUNGRY:
		hungry_t[i] += dt
	else:
		hungry_t[i] = 0.0
	_maybe_bark(i)
	if act_t[i] > 0.0:
		act_t[i] = maxf(0.0, act_t[i] - dt)
		if act_t[i] <= 0.0:
			act[i] = 0
	if shake_t[i] > 0.0:
		shake_t[i] = maxf(0.0, shake_t[i] - dt)
		act[i] = ACT_WASH
		act_t[i] = 0.2
	if i == sponge_id and sponge_hold > 0.0:
		return
	cool[i] = maxf(0.0, cool[i] - dt)
	# Tub sitters stay on the pad. Everyone else, including a finished ride, gets pushed out.
	var tub_here := seat_of(i)
	var in_tub := not tub_here.is_empty() and float(tub_here.get("bath_t", -1.0)) >= 0.0
	if _blocked(pos_x[i], pos_y[i]) and not in_tub:
		_unstick(i)
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
			# Stay outside the solid footprint; use from the approach ring.
			if _dist_i(i, float(visit.x), float(visit.y)) > 22.0:
				var door := _approach_spot(float(visit.x), float(visit.y), 18.0, i)
				_walk(i, float(door.x), float(door.y), MOVE_SPEED, dt)
			else:
				act[i] = ACT_PLAY if _is_show(visit_kind) else ACT_BATH
				act_t[i] = 0.4
			return
	# Keep an in-progress soak even after clean rises past NEED_SEEK.
	var tub_seat := seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		_do_bath(i, tub_seat, dt)
		return
	var riding_b := _ride_building(i)
	if not riding_b.is_empty() and amused[i] >= Catalog.NEED_OK:
		_leave_ride(i, riding_b)
	var ready := fed[i] >= Catalog.NEED_OK and amused[i] >= Catalog.NEED_OK and clean[i] >= Catalog.NEED_OK and cool[i] <= 0.0
	if ready:
		mito_charge[i] = minf(MITOSIS_CHARGE, mito_charge[i] + dt)
		if mito_charge[i] >= MITOSIS_CHARGE:
			mito_charge[i] = 0.0
			_start_mitosis(i)
			return
	else:
		mito_charge[i] = maxf(0.0, mito_charge[i] - dt * 1.5)
	var speed := MOVE_SPEED
	if buff_t[i] > 0.0:
		speed = 36.0
		buff_t[i] = maxf(0.0, buff_t[i] - dt)
	# Distress first, then whichever need is furthest from mitosis. Work waits.
	if fed[i] < Catalog.NEED_HUNGRY:
		_release_claim(i)
		if _seek_food(i, speed, dt):
			return
		_release_apple_claim(i)
	if clean[i] < Catalog.NEED_SEEK:
		if _seek_clean(i, speed, dt):
			_release_item_claims(i)
			return
	if amused[i] < Catalog.NEED_FUN:
		if _tend_fun(i, speed, dt):
			return
	if fed[i] < Catalog.NEED_OK or clean[i] < Catalog.NEED_OK or amused[i] < Catalog.NEED_OK:
		var lack_fed := Catalog.NEED_OK - fed[i]
		var lack_clean := Catalog.NEED_OK - clean[i]
		var lack_fun := Catalog.NEED_OK - amused[i]
		if lack_fed >= lack_clean and lack_fed >= lack_fun:
			if _seek_food(i, speed, dt):
				return
			_release_apple_claim(i)
		elif lack_clean >= lack_fun:
			if _seek_clean(i, speed, dt):
				_release_item_claims(i)
				return
			_release_claim(i)
		elif _tend_fun(i, speed, dt):
			return
		if fed[i] < Catalog.NEED_OK and _seek_food(i, speed, dt):
			return
		if clean[i] < Catalog.NEED_OK and _seek_clean(i, speed, dt):
			_release_item_claims(i)
			return
		if amused[i] < Catalog.NEED_OK and _tend_fun(i, speed, dt):
			return
	else:
		_release_apple_claim(i)
		_release_claim(i)
	if _try_haul(i, speed, dt):
		return
	if _seek_mine(i, speed, dt):
		_release_item_claims(i)
		return
	_release_item_claims(i)
	_wander(i, speed, dt)


func _start_mitosis(i: int) -> void:
	if slot_count >= Catalog.MAX_SLOTS:
		if not cap_told:
			cap_told = true
			notes.append("LA COLONIA NO CABE MÁS.")
		cool[i] = Catalog.MITOSIS_WAIT
		return
	cool[i] = Catalog.MITOSIS_WAIT
	mito_charge[i] = 0.0
	mito_t[i] = MITOSIS_ANIM


func _finish_mitosis(i: int) -> void:
	if slot_count >= Catalog.MAX_SLOTS:
		if not cap_told:
			cap_told = true
			notes.append("LA COLONIA NO CABE MÁS.")
		return
	var x := pos_x[i] + MITOSIS_OFFSET
	var y := pos_y[i]
	if _blocked(x, y):
		x = pos_x[i]
		y = pos_y[i]
	_push_slot(x, y, 70.0, 70.0, 70.0, Catalog.MITOSIS_WAIT, int(tint[i]))
	sfx_queue.append("mitosis")
	sfx_queue.append("uplink")


func _seek_food(i: int, speed: float, dt: float) -> bool:
	var apple := _nearest_apple(i, 240.0)
	if apple.is_empty():
		return false
	if not _claim_apple(i, apple):
		return false
	var tx := float(apple.x)
	var ty := float(apple.y)
	var best := _dist_i(i, tx, ty)
	if best < 12.0:
		act[i] = ACT_EAT
		act_t[i] = 0.25
		apple.bite = float(apple.get("bite", 0.0)) + dt
		if float(apple.bite) >= 0.45:
			apple.dead = true
			apple.claimer = -1
			fed[i] = 100.0
			sfx_queue.append("apple")
			hungry_t[i] = 0.0
			_pop(pos_x[i], pos_y[i], Catalog.ICON_APPLE)
			_release_apple_claim(i)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _nearest_apple(i: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for it in items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_APPLE:
			continue
		if float(it.get("air", 0.0)) > 0.0:
			continue
		var who := int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if who < slot_count and state[who] == Catalog.ST_LIVING and not _food_priority_beats(i, who):
				continue
			if who < 0 or who >= slot_count or state[who] != Catalog.ST_LIVING:
				it.claimer = -1
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
	apple.claimer = i
	return true


func _release_apple_claim(i: int) -> void:
	_release_item_claims(i)


func _nearest_free_item(i: int, kind: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for it in items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		var who := int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if who < slot_count and state[who] == Catalog.ST_LIVING:
				continue
			it.claimer = -1
		var d := _dist_i(i, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best


func _claim_item(i: int, item: Dictionary) -> void:
	if item.is_empty():
		return
	var who := int(item.get("claimer", -1))
	if who == i:
		return
	if who >= 0 and who != i and who < slot_count and state[who] == Catalog.ST_LIVING:
		return
	_release_item_claims(i)
	item.claimer = i


func _release_item_claims(i: int) -> void:
	for it in items:
		if int(it.get("claimer", -1)) == i:
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
	else:
		_release_claim(i)
	if best < 20.0 and use_tub:
		_do_bath(i, target, dt)
		return true
	if best < 22.0 and not use_tub:
		_enter_visit(i, target)
		act[i] = ACT_BATH
		act_t[i] = 0.4
		return true
	var edge := _approach_spot(float(target.x), float(target.y), 18.0, i)
	_walk(i, float(edge.x), float(edge.y), speed, dt)
	return true


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
	var seat := Vector2(float(b.x), float(b.y)) + Catalog.TUB_SEAT_OFF
	pos_x[i] = seat.x
	pos_y[i] = seat.y
	dir_x[i] = 0.0
	dir_y[i] = 0.0
	b.active = true
	clean[i] = minf(100.0, clean[i] + BATH_CLEAN_RATE * dt)
	if clean[i] >= BATH_DONE and float(b.bath_t) >= BATH_MIN_STAY:
		_finish_bath(i, b)


func _finish_bath(i: int, b: Dictionary) -> void:
	var rim := _approach_spot(float(b.x), float(b.y), 18.0, i)
	_release_claim(i)
	pos_x[i] = float(rim.x)
	pos_y[i] = float(rim.y)
	act[i] = ACT_BATH
	act_t[i] = 0.35


func _nearest_roundabout(i: int, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)) or int(b.kind) != Catalog.BLD_ROUND:
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


func _set_rider(b: Dictionary, i: int, on: bool) -> void:
	var kept: Array = []
	for raw in _rider_list(b):
		if int(raw) != i:
			kept.append(int(raw))
	if on:
		kept.append(i)
	b.riders = kept


func _ride_building(i: int) -> Dictionary:
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if _is_rider(b, i):
			return b
	return {}


func _clear_ride(i: int) -> void:
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


func _ride_radius(b: Dictionary) -> float:
	var size := Catalog.footprint_for_building(int(b.kind))
	var half := Vector2(float(size.x), float(size.y)) * float(Catalog.TILE) * 0.5
	return half.length() + 8.0


func _leave_ride(i: int, b: Dictionary) -> void:
	_set_rider(b, i, false)
	if int(act[i]) == ACT_PLAY:
		act[i] = 0
		act_t[i] = 0.0
	var away := _approach_spot(float(b.x), float(b.y), 72.0, i)
	if _blocked(away.x, away.y):
		return
	if _dist_point(away.x, away.y, float(b.x), float(b.y)) < 48.0:
		return
	pos_x[i] = away.x
	pos_y[i] = away.y


func _do_roundabout_ride(i: int, b: Dictionary, dt: float) -> void:
	if int(act[i]) != ACT_PLAY:
		sfx_queue.append("round_start")
	act[i] = ACT_PLAY
	act_t[i] = 0.55
	_set_rider(b, i, true)
	_release_item_claims(i)
	var center := _footprint_center_of(b)
	var orbit_r := _ride_radius(b)
	var dx := pos_x[i] - center.x
	var dy := pos_y[i] - center.y
	var ang := atan2(dy, dx)
	if dx * dx + dy * dy < 1.0:
		ang = float(i) * 1.7
	ang += 2.8 * dt
	var placed := false
	for step in 8:
		var a := ang + float(step) * (TAU / 8.0)
		var nx := center.x + cos(a) * orbit_r
		var ny := center.y + sin(a) * orbit_r
		if _blocked(nx, ny):
			continue
		pos_x[i] = nx
		pos_y[i] = ny
		dir_x[i] = cos(a + PI * 0.5)
		dir_y[i] = sin(a + PI * 0.5)
		placed = true
		break
	if not placed:
		var rim := _approach_spot(center.x, center.y, orbit_r, i)
		if not _blocked(rim.x, rim.y):
			pos_x[i] = rim.x
			pos_y[i] = rim.y
	amused[i] = minf(100.0, amused[i] + 26.0 * dt)
	b.active = true


func _tend_fun(i: int, speed: float, dt: float) -> bool:
	var riding_b := _ride_building(i)
	if not riding_b.is_empty() and amused[i] < Catalog.NEED_OK:
		_do_roundabout_ride(i, riding_b, dt)
		return true
	var round_near := _nearest_roundabout(i, 42.0)
	if not round_near.is_empty():
		_do_roundabout_ride(i, round_near, dt)
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
		if best < 42.0:
			_do_roundabout_ride(i, round, dt)
			return true
		var rim := _approach_spot(tx, ty, 18.0, i)
		_walk(i, float(rim.x), float(rim.y), speed, dt)
		return true
	if use_ball:
		_claim_ball(i, ball)
	else:
		_release_item_claims(i)
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
				ball.rest = 0.7
				ball.life = BALL_LIFE
				amused[i] = minf(100.0, amused[i] + 14.0)
				dir_x[i] = 0.0
				dir_y[i] = 0.0
				_pop(pos_x[i], pos_y[i] - 6.0, Catalog.ICON_BALL)
				sfx_queue.append("ball")
			elif best > 4.0:
				_walk(i, tx, ty, speed * 1.15, dt)
			else:
				dir_x[i] = 0.0
				dir_y[i] = 0.0
			return true
		if _is_show(play_kind):
			if best < 26.0:
				_enter_visit(i, play)
				act[i] = ACT_PLAY
				act_t[i] = 0.4
			else:
				var show_edge := _approach_spot(tx, ty, 24.0, i)
				_walk(i, float(show_edge.x), float(show_edge.y), speed, dt)
			return true
		amused[i] = minf(100.0, amused[i] + 18.0 * dt)
		return true
	var walk_to := _approach_spot(tx, ty, 18.0, i) if not use_ball else Vector2(tx, ty)
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
	var bridge := _nearest_open_bridge(pos_x[i], pos_y[i], 8000.0)
	if not bridge.is_empty():
		var wood := _nearest_free_item(i, Catalog.ITEM_WOOD, 2800.0)
		if not wood.is_empty():
			return _walk_pickup(i, wood, Catalog.CARRY_WOOD, speed, dt)
		var bone := _nearest_free_item(i, Catalog.ITEM_BONE, 2800.0)
		if not bone.is_empty():
			return _walk_pickup(i, bone, Catalog.CARRY_BONE, speed, dt)
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
		if not item.dead and not item.held and int(item.get("claimer", -1)) == i:
			carry[i] = carry_kind
			carry_value[i] = int(item.value)
			item.claimer = -1
			item.dead = true
			if carry_kind == Catalog.CARRY_WOOD:
				sfx_queue.append("wood_grab")
			elif carry_kind == Catalog.CARRY_BONE:
				sfx_queue.append("bone_grab")
			_release_item_claims(i)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _deliver(i: int, speed: float, dt: float) -> bool:
	var tx := 0.0
	var ty := 0.0
	var factory := {}
	var bridge := {}
	if carry[i] == Catalog.CARRY_ORE:
		factory = _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2], 4000.0)
		if factory.is_empty():
			carry[i] = Catalog.CARRY_NONE
			return false
		tx = float(factory.x)
		ty = float(factory.y)
	else:
		bridge = _nearest_open_bridge(pos_x[i], pos_y[i], 8000.0)
		if bridge.is_empty():
			carry[i] = Catalog.CARRY_NONE
			return false
		var drop := _bridge_drop_point(bridge)
		tx = drop.x
		ty = drop.y
	act[i] = ACT_WORK
	act_t[i] = 0.3
	_walk(i, tx, ty, speed, dt)
	if _dist_i(i, tx, ty) < 64.0:
		if carry[i] == Catalog.CARRY_ORE:
			factory.buffer = int(factory.get("buffer", 0)) + maxi(1, carry_value[i])
			factory.active = true
			_pop(float(factory.x), float(factory.y) - 4.0, Catalog.ICON_ORE)
		else:
			_drop_on_bridge(float(bridge.x), float(bridge.y), carry[i])
		carry[i] = Catalog.CARRY_NONE
		carry_value[i] = 0
	return true


func _seek_mine(i: int, speed: float, dt: float) -> bool:
	var mine := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		return false
	var cap := 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	if _workers_near(mine, cap + 2) >= cap and _dist_i(i, float(mine.x), float(mine.y)) > 36.0:
		return false
	var spot := _approach_spot(float(mine.x), float(mine.y), 22.0, i)
	var tx := float(spot.x)
	var ty := float(spot.y)
	if _dist_i(i, tx, ty) < 8.0:
		act[i] = ACT_WORK
		act_t[i] = 0.5
		shake_t[i] = maxf(shake_t[i], 0.2)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _wander(i: int, speed: float, dt: float) -> void:
	wander_t[i] -= dt
	if wander_t[i] <= 0.0:
		_pick_wander(i)
	if absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
		return
	if _blocked(pos_x[i] + dir_x[i] * 12.0, pos_y[i] + dir_y[i] * 12.0):
		_pick_wander(i)
		if absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
			return
	_move(i, dir_x[i] * speed * dt, dir_y[i] * speed * dt)


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
	if _blocked(tx, ty):
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
		elif _blocked(pos_x[i] + sx * 10.0, pos_y[i] + sy * 10.0):
			push -= Vector2(sx, sy) * 0.55
	if push.length_squared() < 0.01:
		return Vector2.ZERO
	return push.normalized()


func _inland_dir(i: int) -> Vector2:
	if carry[i] != Catalog.CARRY_NONE and carry[i] != Catalog.CARRY_ORE:
		var bridge := _nearest_open_bridge(pos_x[i], pos_y[i], 8000.0)
		if not bridge.is_empty():
			var drop := _bridge_drop_point(bridge)
			var to_drop := Vector2(drop.x - pos_x[i], drop.y - pos_y[i])
			if to_drop.length_squared() > 1.0:
				return to_drop.normalized()
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
	for n in 16:
		var d := base.rotated(float(n) * (TAU / 16.0))
		var run := _clear_run(i, d.x, d.y)
		if run < 12.0:
			continue
		# Prefer open runway over greedily facing the goal into a dead end.
		var score := run * 2.5 + d.dot(base) * 5.0
		if score > best_score:
			best_score = score
			best = d
	if best != Vector2.ZERO:
		return best
	# Last resort: accept a shorter gap so they can leave a tight cove.
	for n in 16:
		var d := base.rotated(float(n) * (TAU / 16.0))
		var run := _clear_run(i, d.x, d.y)
		if run < 6.0:
			continue
		var score := run * 2.5 + d.dot(base) * 5.0
		if score > best_score:
			best_score = score
			best = d
	return best


func _walk(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	var dx := tx - pos_x[i]
	var dy := ty - pos_y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		return
	var gx := dx / dist
	var gy := dy / dist
	var goal := Vector2(gx, gy)
	var goal_run := _clear_run(i, gx, gy)
	# Demand a real open corridor, not a few free pixels that lead back into a cove.
	var need_run := clampf(dist, 20.0, 40.0)
	if goal_run >= need_run:
		dir_x[i] = gx
		dir_y[i] = gy
	else:
		var cur := Vector2(dir_x[i], dir_y[i])
		var keep := false
		if cur.length_squared() > 0.2:
			cur = cur.normalized()
			var cur_run := _clear_run(i, cur.x, cur.y)
			# Keep circling the obstacle until the goal corridor is truly open.
			if cur_run >= 14.0 and goal_run < need_run and cur.dot(goal) > -0.85:
				keep = true
				dir_x[i] = cur.x
				dir_y[i] = cur.y
		if not keep:
			var bias := _shore_push(i)
			if bias == Vector2.ZERO:
				bias = goal
			var detour := _open_dir(i, bias)
			if detour == Vector2.ZERO:
				detour = _open_dir(i, goal)
			if detour == Vector2.ZERO:
				_unstick(i)
				return
			dir_x[i] = detour.x
			dir_y[i] = detour.y
	_move(i, dir_x[i] * speed * dt, dir_y[i] * speed * dt)


func _move(i: int, dx: float, dy: float) -> void:
	var ox := pos_x[i]
	var oy := pos_y[i]
	var moved := false
	var can_x := not _blocked(ox + dx, oy)
	var can_y := not _blocked(ox, oy + dy)
	if can_x and can_y and not _blocked(ox + dx, oy + dy):
		pos_x[i] = ox + dx
		pos_y[i] = oy + dy
		_wear_ground(i)
		return
	if can_x:
		pos_x[i] = ox + dx
		moved = true
	if not _blocked(pos_x[i], oy + dy):
		pos_y[i] = oy + dy
		moved = true
	elif can_y and not can_x:
		pos_y[i] = oy + dy
		moved = true
	if not moved or (moved and _corner_trap(i)):
		_unstick(i)
	if pos_x[i] != ox or pos_y[i] != oy:
		_wear_ground(i)


func _wear_ground(i: int) -> void:
	var cell := _cell_vec(pos_x[i], pos_y[i])
	var key := "%d,%d" % [cell.x, cell.y]
	if str(wear_from.get(i, "")) == key:
		return
	wear_from[i] = key
	if _tile_at(pos_x[i], pos_y[i]) != Catalog.TILE_GRASS:
		return
	var before := wear_stage(cell.x, cell.y)
	var n := int(wear.get(key, 0)) + 1
	if n >= WEAR_NEED:
		wear.erase(key)
		_set_world_cell(cell.x, cell.y, Catalog.TILE_DIRT, true)
		return
	wear[key] = n
	if wear_stage(cell.x, cell.y) != before:
		_mark_dirty(_ck(_floor_div(cell.x, Catalog.CHUNK), _floor_div(cell.y, Catalog.CHUNK)))


func wear_stage(cx: int, cy: int) -> int:
	var n := int(wear.get("%d,%d" % [cx, cy], 0))
	var per := maxi(1, WEAR_NEED / (WEAR_STEPS + 1))
	return mini(WEAR_STEPS, n / per)


func _thought_known(key: String) -> bool:
	return bool(unlocks.get(key, false))


func _thought_icon(i: int) -> int:
	# Only desire things the colony has already discovered.
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
			continue
		if _dist_i(i, float(feat.x), float(feat.y)) < 48.0:
			return Catalog.ICON_FIRE
	if _is_penned(i):
		return Catalog.ICON_ROCK
	var tile := _tile_at(pos_x[i], pos_y[i])
	if tile == Catalog.TILE_GOO:
		if _thought_known("mop"):
			return Catalog.ICON_MOP
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	if fed[i] < Catalog.NEED_HUNGRY and _thought_known("apple"):
		return Catalog.ICON_APPLE
	if clean[i] < Catalog.NEED_SEEK:
		if _thought_known("bathtub"):
			return Catalog.ICON_TUB
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	if amused[i] < Catalog.NEED_FUN:
		if _thought_known("roundabout"):
			return Catalog.ICON_ROUND
		if _thought_known("ball"):
			return Catalog.ICON_BALL
	var doing := int(act[i])
	if doing == ACT_EAT and _thought_known("apple"):
		return Catalog.ICON_APPLE
	if doing == ACT_BATH and _thought_known("bathtub"):
		return Catalog.ICON_TUB
	if doing == ACT_WASH and _thought_known("sponge"):
		return Catalog.ICON_SPONGE
	if doing == ACT_PLAY:
		if _thought_known("roundabout"):
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
		if _blocked(pos_x[i] + d.x * 14.0, pos_y[i] + d.y * 14.0):
			blocked_n += 1
	return blocked_n >= 6


func _maybe_bark(i: int) -> void:
	if barks.size() >= 3:
		return
	if view_rect.size != Vector2.ZERO and not view_rect.has_point(Vector2(pos_x[i], pos_y[i])):
		return
	for bark in barks:
		if int(bark.id) == i:
			return
	var icon := _thought_icon(i)
	if icon < 0:
		return
	var urgent := (
		icon == Catalog.ICON_FIRE
		or icon == Catalog.ICON_APPLE
		or icon == Catalog.ICON_MOP
		or icon == Catalog.ICON_ROCK
		or icon == Catalog.ICON_TUB
		or icon == Catalog.ICON_SPONGE
		or icon == Catalog.ICON_BALL
		or icon == Catalog.ICON_ROUND
	)
	if urgent:
		if randf() > 0.03:
			return
	elif randf() > 0.006:
		return
	barks.append({
		"id": i,
		"icon": icon,
		"t": 1.8 if urgent else 2.2,
		"x": pos_x[i],
		"y": pos_y[i],
	})


func _tick_voice(delta: float) -> void:
	voice_wait = maxf(0.0, voice_wait - delta)
	if voice_wait > 0.0 or living <= 0 or frozen:
		return
	var upset := -1
	var sing := -1
	var idle := -1
	for i in slot_count:
		if state[i] != Catalog.ST_LIVING:
			continue
		if fed[i] < Catalog.NEED_HUNGRY or clean[i] < 20.0:
			upset = i
		elif int(act[i]) == ACT_PLAY:
			sing = i
		elif absf(dir_x[i]) + absf(dir_y[i]) < 0.01:
			idle = i
	voice_wait = randf_range(7.0, 12.0)
	if upset >= 0:
		sfx_queue.append("voice_upset")
	elif sing >= 0:
		sfx_queue.append("voice_sing")
	elif idle >= 0 and randf() < 0.45:
		sfx_queue.append("voice_prrr")
	var fast := 0
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING and absf(dir_x[i]) + absf(dir_y[i]) > 0.85:
			fast += 1
	if fast > 10:
		sfx_queue.append("speed")
	else:
		voice_wait = 2.0


func _tick_barks(delta: float) -> void:
	var kept: Array = []
	for bark in barks:
		bark.t = float(bark.t) - delta
		var i := int(bark.id)
		if float(bark.t) <= 0.0 or i < 0 or i >= slot_count or state[i] != Catalog.ST_LIVING:
			continue
		bark.x = pos_x[i]
		bark.y = pos_y[i]
		kept.append(bark)
	barks = kept


func seat_of(i: int) -> Dictionary:
	for b in buildings:
		if b.dead or int(b.kind) != Catalog.BLD_TUB:
			continue
		if int(b.get("occupant", -1)) == i:
			return b
	return {}


func ride_of(i: int) -> Dictionary:
	if i < 0 or i >= slot_count or int(act[i]) != ACT_PLAY:
		return {}
	return _ride_building(i)


func ball_of(i: int) -> Dictionary:
	if i < 0 or i >= slot_count or int(act[i]) != ACT_PLAY:
		return {}
	for it in items:
		if it.dead or int(it.kind) != Catalog.ITEM_BALL:
			continue
		if int(it.get("claimer", -1)) == i:
			return it
	return {}


func _visit_rule(kind: int) -> Dictionary:
	if kind == Catalog.BLD_DWELL:
		return {"cap": 4, "stay": 14.0, "cool": 12.0, "fed": 16.0, "clean": 22.0, "fun": 0.0}
	if kind == Catalog.BLD_FANCY:
		return {"cap": 10, "stay": 20.0, "cool": 10.0, "fed": 18.0, "clean": 34.0, "fun": 0.0}
	if kind == Catalog.BLD_THEATRE:
		return {"cap": 18, "stay": 9.0, "cool": 8.0, "fed": 0.0, "clean": 0.0, "fun": 28.0}
	return {}


func _is_show(kind: int) -> bool:
	return kind == Catalog.BLD_THEATRE


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
	if bool(mutations.get("care", false)):
		stay *= 1.35
	if bool(mutations.get("hard", false)):
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
	var rule := _visit_rule(int(b.kind))
	if rule.is_empty():
		return true
	if _is_guest(b, i):
		return true
	if _banned(b, i):
		return false
	return _live_guests(b) < int(rule.cap)


func _guest_building(i: int) -> Dictionary:
	for b in buildings:
		if b.dead:
			continue
		if _is_guest(b, i):
			return b
	return {}


func _push_out(b: Dictionary, i: int) -> void:
	var ang := randf() * TAU
	var nx := pos_x[i] + cos(ang) * 22.0
	var ny := pos_y[i] + sin(ang) * 22.0
	if not _blocked(nx, ny):
		pos_x[i] = nx
		pos_y[i] = ny
	if int(b.kind) == Catalog.BLD_TUB:
		sfx_queue.append("tub_out")


func _drop_guest(b: Dictionary, i: int) -> void:
	var guests: Array = []
	for guest in b.get("guests", []):
		if int(guest.id) != i:
			guests.append(guest)
	b.guests = guests
	var away: Array = b.get("away", [])
	var rule := _visit_rule(int(b.kind))
	away.append({"id": i, "t": float(rule.get("cool", 8.0))})
	b.away = away
	_push_out(b, i)


func _enter_visit(i: int, b: Dictionary) -> void:
	if b.is_empty() or _is_guest(b, i) or not _can_enter(b, i):
		return
	var rule := _visit_rule(int(b.kind))
	if rule.is_empty():
		return
	var guests: Array = b.get("guests", [])
	guests.append({"id": i, "left": _stay_for(int(b.kind), float(rule.stay))})
	b.guests = guests
	if int(b.kind) == Catalog.BLD_TUB:
		sfx_queue.append("tub_in")
		sfx_queue.append("splash")


func _tick_visit(b: Dictionary, dt: float) -> void:
	var rule := _visit_rule(int(b.kind))
	var away: Array = []
	for ban in b.get("away", []):
		ban.t = float(ban.t) - dt
		if float(ban.t) > 0.0:
			away.append(ban)
	var kept: Array = []
	for guest in b.get("guests", []):
		var id := int(guest.id)
		if id < 0 or id >= slot_count or state[id] != Catalog.ST_LIVING:
			continue
		guest.left = float(guest.left) - dt
		if float(guest.left) <= 0.0:
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
	b.active = not kept.is_empty()


func _apple_land_spot(bx: float, by: float) -> Vector2:
	for _n in 8:
		var ang := randf() * TAU
		var rad := randf_range(Catalog.APPLE_LAND_MIN, Catalog.APPLE_LAND_MAX)
		var px := bx + cos(ang) * rad
		var py := by + sin(ang) * rad
		if not _blocked(px, py):
			return Vector2(px, py)
	return Vector2(bx, by + Catalog.APPLE_LAND_MIN)


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
	var fall_t := Catalog.APPLE_FALL_T
	var dropped := _add_item(Catalog.ITEM_APPLE, start.x, start.y, 1)
	dropped.air = lift
	dropped.fall = lift / fall_t
	dropped.tx = dest.x
	dropped.ty = dest.y
	dropped.vx = (dest.x - start.x) / fall_t
	dropped.vy = (dest.y - start.y) / fall_t


func structure_full(b: Dictionary) -> bool:
	var kind := int(b.kind)
	if kind == Catalog.BLD_TUB:
		var occ := int(b.get("occupant", -1))
		return occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING
	var limit := 0
	var radius := 0.0
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
		var rule := _visit_rule(kind)
		return _live_guests(b) >= int(rule.cap)
	if kind == Catalog.BLD_ROUND:
		limit = 6
		radius = 30.0
	else:
		return false
	return _count_living_near(float(b.x), float(b.y), radius) >= limit


func _corner_trap(i: int) -> bool:
	var open := 0
	for n in 8:
		var a := float(n) * TAU * 0.125
		if not _blocked(pos_x[i] + cos(a) * 8.0, pos_y[i] + sin(a) * 8.0):
			open += 1
	return open <= 2


func _unstick(i: int) -> void:
	var prefer := _shore_push(i)
	if prefer == Vector2.ZERO:
		prefer = _inland_dir(i)
	var step := _open_dir(i, prefer)
	if step == Vector2.ZERO:
		step = _open_dir(i, _inland_dir(i))
	var candidates: Array[Vector2] = []
	if step != Vector2.ZERO:
		candidates.append(step)
	if prefer != Vector2.ZERO:
		candidates.append(prefer)
	for n in 16:
		var a := float(n) * (TAU / 16.0)
		candidates.append(Vector2(cos(a), sin(a)))
	var try_dist: Array[float] = [10.0, 8.0, 6.0, 4.0, 3.0, 2.0]
	for dist in try_dist:
		var best := Vector2.ZERO
		var best_run := -1.0
		for cand in candidates:
			var nx: float = pos_x[i] + cand.x * dist
			var ny: float = pos_y[i] + cand.y * dist
			if _blocked(nx, ny):
				continue
			var run := _clear_run_at(nx, ny, cand.x, cand.y)
			var score := run + cand.dot(prefer) * 6.0
			if score > best_run:
				best_run = score
				best = cand
		if best != Vector2.ZERO:
			pos_x[i] = pos_x[i] + best.x * dist
			pos_y[i] = pos_y[i] + best.y * dist
			dir_x[i] = best.x
			dir_y[i] = best.y
			wander_t[i] = randf_range(0.7, 1.6)
			return
	wander_t[i] = 0.0


func _clear_run_at(px: float, py: float, dx: float, dy: float) -> float:
	var clear := 0.0
	var step := 4.0
	while clear + step <= 40.0:
		if _blocked(px + dx * (clear + step), py + dy * (clear + step)):
			return clear
		clear += step
	return 40.0


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


func _queue_tree_seed(x: float, y: float, wait: float) -> void:
	tree_seeds.append({"x": x, "y": y, "t": wait})


func _try_plant_tree(x: float, y: float) -> void:
	if _blocked(x, y) or _on_bridge(x, y):
		return
	if not _feature_at(x, y, 6.0).is_empty():
		return
	if not _building_at(x, y, 10.0).is_empty():
		return
	_add_feature(Catalog.FEAT_TREE, x, y, 1, 0, true)


func _tick_items(dt: float) -> void:
	for it in items:
		if it.dead or it.held:
			continue
		if int(it.kind) == Catalog.ITEM_EGG:
			_tick_egg(it, dt)
			continue
		if int(it.kind) == Catalog.ITEM_APPLE and float(it.get("air", 0.0)) > 0.0:
			var rate := float(it.get("fall", 20.0))
			var air := maxf(0.0, float(it.air) - rate * dt)
			it.air = air
			var nx := float(it.x) + float(it.get("vx", 0.0)) * dt
			var ny := float(it.y) + float(it.get("vy", 0.0)) * dt
			if not _blocked(nx, float(it.y)):
				it.x = nx
			if not _blocked(float(it.x), ny):
				it.y = ny
			if air <= 0.0:
				it.air = 0.0
				it.vx = 0.0
				it.vy = 0.0
				it.fall = 0.0
				if it.has("tx") and it.has("ty"):
					var lx := float(it.tx)
					var ly := float(it.ty)
					if not _blocked(lx, ly):
						it.x = lx
						it.y = ly
					it.erase("tx")
					it.erase("ty")
			continue
		if int(it.kind) != Catalog.ITEM_BALL:
			continue
		it.rest = maxf(0.0, float(it.get("rest", 0.0)) - dt)
		it.life = maxf(0.0, float(it.get("life", BALL_LIFE)) - dt)
		if float(it.life) <= 0.0:
			it.claimer = -1
			it.dead = true
			_pop(float(it.x), float(it.y), Catalog.ICON_FX_POOF)
			continue
		var vx := float(it.get("vx", 0.0))
		var vy := float(it.get("vy", 0.0))
		if absf(vx) + absf(vy) > 2.0:
			var nx := float(it.x) + vx * dt
			var ny := float(it.y) + vy * dt
			if _blocked(nx, float(it.y)):
				vx = -vx * 0.55
			else:
				it.x = nx
			if _blocked(float(it.x), ny):
				vy = -vy * 0.55
			else:
				it.y = ny
			it.vx = vx * 0.9
			it.vy = vy * 0.9
		_boost(float(it.x), float(it.y), 28.0, 2, 0.0, 0.0, 20.0 * dt, 0.0)


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


func _tick_buildings(dt: float) -> void:
	for b in buildings:
		if b.dead:
			continue
		if bool(b.get("lifted", false)):
			b.active = false
			continue
		var kind := int(b.kind)
		b.active = false
		if kind == Catalog.BLD_APPLE:
			_tick_apple_tree(b, dt)
		elif kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			var cap := 6 if kind == Catalog.BLD_MINE2 else 2
			var workers := _workers_near(b, cap)
			if workers > 0:
				b.active = true
				b.timer = float(b.timer) - dt * float(workers)
				if float(b.timer) <= 0.0:
					b.timer = 2.2
					var drop := _loot_spot(b)
					_add_item(Catalog.ITEM_ORE, drop.x, drop.y, _mine_value(b))
					_pop(drop.x, drop.y - 2.0, Catalog.ICON_ORE)
		elif kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			b.timer = float(b.timer) - dt
			if float(b.timer) <= 0.0:
				var buffered := int(b.get("buffer", 0))
				if buffered > 0:
					b.buffer = buffered - 1
					b.timer = 0.7 if kind == Catalog.BLD_FACTORY2 else 2.0
					gems += 2 if kind == Catalog.BLD_FACTORY2 else 1
					b.active = true
					_pop(float(b.x), float(b.y) - 6.0, Catalog.ICON_GEM)
					_spill_goo(float(b.x), float(b.y), 2 if kind == Catalog.BLD_FACTORY2 else 1)
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
						gems += 5 if bool(mutations.get("fuel", false)) else 3
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
			if spinning or _count_living_near(float(b.x), float(b.y), 48.0) > 0:
				b.active = true
		elif kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
			_tick_visit(b, dt)


func _tick_auras(dt: float) -> void:
	for b in buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FLOWER:
			_boost(float(b.x), float(b.y), 28.0, 3, 0.0, 0.0, 10.0 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
			_boost(float(b.x), float(b.y), 36.0, 4, 0.0, 0.0, 14.0 * dt, 0.8, ACT_PLAY)
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
		_drop_loose(Catalog.ITEM_APPLE, x, y, 1)
	elif tool == Catalog.TOOL_BALL:
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
	if not _can_drop(at.x, at.y) or not _item_spot_free(at.x, at.y) or int(building_cell.get(_cell_vec(at.x, at.y), -1)) >= 0:
		notes.append("AHI NO.")
		sfx_queue.append("error")
		return
	var it := _add_item(kind, at.x, at.y, value)
	if kind == Catalog.ITEM_BALL:
		it.life = BALL_LIFE
		it.vx = 0.0
		it.vy = 0.0
		it.rest = 0.0
		notes.append("LOS MULTIS JUEGAN SI LES FALTA DIVERSION.")
	sfx_queue.append("ball" if kind == Catalog.ITEM_BALL else "place")


func _tool_axe(x: float, y: float) -> void:
	var feat := _axe_feature_at(x, y)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_TREE:
		_chop(feat)
		sfx_queue.append("chop")
		return
	if not feat.is_empty() and (int(feat.kind) == Catalog.FEAT_COSMETIC or int(feat.kind) == Catalog.FEAT_COSMETIC_BAD):
		_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_POOF)
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
	_add_item(Catalog.ITEM_WOOD, float(feat.x) + 8.0, float(feat.y), 1)
	_pop(float(feat.x), float(feat.y), Catalog.ICON_FX_CHOP)
	_pop(float(feat.x), float(feat.y) + 6.0, Catalog.ICON_FX_POOF)
	trees_chopped += 1
	_refresh_pop_gates()
	if trees_chopped >= 12:
		_grant("grabber", "DOCE ARBOLES. LA MANO JUNTA LO SUELTO.")


func _tool_hammer(x: float, y: float) -> void:
	var item := _item_at(x, y, 10.0)
	if not item.is_empty() and int(item.kind) == Catalog.ITEM_ORE and part_two:
		gems += int(item.value)
		item.dead = true
		notes.append("EL MINERAL SUELTA ENERGIA.")
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
				_queue_tree_seed(float(feat.x), float(feat.y), Catalog.TREE_REPLANT)
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
				_add_item(Catalog.ITEM_ORE, float(feat.x), float(feat.y), ore_n if kind == Catalog.FEAT_BIGROCK else maxi(3, ore_n))
			_kill_feature(feat)
		return


func _tool_pick(x: float, y: float) -> void:
	var hit := false
	for feat in features:
		if feat.dead or not _is_rock(int(feat.kind)):
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.PICK_RADIUS:
			var kind := int(feat.kind)
			_hammer_feature(feat)
			hit = true
			if kind == Catalog.FEAT_ORE_MEGA or kind == Catalog.FEAT_ORE_SUPER or kind == Catalog.FEAT_ORE_ULTRA:
				sfx_queue.append("superore")
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
		var ore := _item_at(x, y, 10.0)
		if not ore.is_empty() and int(ore.kind) == Catalog.ITEM_ORE and part_two:
			return {"key": "item:%d" % int(ore.id), "x": float(ore.x), "y": float(ore.y), "n": 1}
		var feat := _feature_at(x, y, 14.0)
		if not feat.is_empty() and int(feat.kind) != Catalog.FEAT_TREE and int(feat.kind) != Catalog.FEAT_MONOLITH and _ore_tier(int(feat.kind)) == 0:
			return {"key": "feat:%d" % int(feat.id), "x": float(feat.x), "y": float(feat.y), "n": 1}
		var b := _building_at(x, y, 16.0)
		if not b.is_empty():
			return {"key": "bld:%d" % int(b.id), "x": float(b.x), "y": float(b.y), "n": 1}
		return {}
	if tool == Catalog.TOOL_PICK:
		var rocks := _count_features_near(Catalog.FEAT_ROCK, x, y, Catalog.PICK_RADIUS) + _count_features_near(Catalog.FEAT_BIGROCK, x, y, Catalog.PICK_RADIUS)
		if rocks <= 0:
			return {}
		return {"key": "pick:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": rocks, "radius": Catalog.PICK_RADIUS}
	if tool == Catalog.TOOL_SAW:
		var trees := _count_features_near(Catalog.FEAT_TREE, x, y, Catalog.SAW_RADIUS)
		if trees <= 0:
			return {}
		return {"key": "saw:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": trees, "radius": Catalog.SAW_RADIUS}
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
	return {}


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
			if _blocked(px, py) or not _item_spot_free(px, py, int(it.id)):
				continue
			it.x = px
			it.y = py
			dropped = true
			break
		if not dropped:
			it.x = x + randf_range(-12.0, 12.0)
			it.y = y + randf_range(-12.0, 12.0)
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
	_add_item(Catalog.ITEM_TNT, x, y, 1)
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
	var c0 := _cell_vec(x - 48.0, y - 48.0)
	var c1 := _cell_vec(x + 48.0, y + 48.0)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx := float(cx * Catalog.TILE + 8)
			var wy := float(cy * Catalog.TILE + 8)
			if _dist_point(x, y, wx, wy) > 48.0:
				continue
			if _tile_at(wx, wy) == Catalog.TILE_GOO:
				var base := _base_at(wx, wy)
				if base == Catalog.TILE_GOO or base == Catalog.TILE_MOUNTAIN:
					base = Catalog.TILE_DIRT
				_set_world_cell(cx, cy, base, false)
	goo_count = _count_goo()
	var ids := query_radius(x, y, 48.0)
	for id in ids:
		if state[int(id)] == Catalog.ST_LIVING:
			clean[int(id)] = 100.0
	sfx_queue.append("mop")


func scrub(x: float, y: float, stroke: float) -> void:
	if frozen:
		return
	var ids := query_radius(x, y, 30.0)
	if ids.is_empty():
		return
	sponge_hold = 0.35
	sponge_id = -1
	if stroke < 4.0:
		return
	var gain := minf(stroke, 22.0) * 2.0
	for raw in ids:
		var id := int(raw)
		if state[id] != Catalog.ST_LIVING:
			continue
		if clean[id] >= 100.0:
			_stop_wash(id)
			continue
		clean[id] = minf(100.0, clean[id] + gain)
		if clean[id] >= 100.0:
			_stop_wash(id)
			continue
		sponge_id = id
		shake_t[id] = 0.18
		act[id] = ACT_WASH
		act_t[id] = 0.25
		if int(frame_i) % 4 == 0:
			_pop(pos_x[id], pos_y[id] - 6.0, Catalog.ICON_FX_SPARK)
			_pop(pos_x[id] + 4.0, pos_y[id] - 10.0, Catalog.ICON_SPONGE)
			sfx_queue.append("scrub")


func _stop_wash(id: int) -> void:
	if id < 0 or id >= slot_count:
		return
	shake_t[id] = 0.0
	if act[id] == ACT_WASH:
		act[id] = 0
		act_t[id] = 0.0
	if sponge_id == id:
		sponge_id = -1


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
			notes.append("VIVIENDA. CUPO 4. COMEN, SE LAVAN Y SALEN.")
		Catalog.BLD_FANCY:
			notes.append("VIVIENDA DE LUJO. CABEN MÁS Y SE LAVAN MÁS.")
		Catalog.BLD_MINE, Catalog.BLD_MINE2:
			notes.append("LA MINA SACA MINERAL SI HAY MULTIS TRABAJANDO.")
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


func drop_hand(x: float, y: float) -> void:
	if hand_id == -1:
		return
	var it = item_by_id.get(hand_id, {})
	var drop_id := hand_id
	hand_id = -1
	if it.is_empty() or it.dead:
		return
	it.held = false
	var at := Vector2(x, y)
	if Catalog.item_snaps_grid(int(it.kind)):
		at = Catalog.snap_world(x, y)
	if int(it.kind) == Catalog.ITEM_WOOD or int(it.kind) == Catalog.ITEM_BONE:
		var bridge := _nearest_open_bridge(at.x, at.y, 90.0)
		if not bridge.is_empty():
			it.dead = true
			var kind := Catalog.CARRY_WOOD if int(it.kind) == Catalog.ITEM_WOOD else Catalog.CARRY_BONE
			_drop_on_bridge(float(bridge.x), float(bridge.y), kind)
			return
	if _tile_at(at.x, at.y) == Catalog.TILE_VOID:
		it.dead = true
		_fall_void(at.x, at.y)
		return
	if not _can_drop(at.x, at.y) or not _item_spot_free(at.x, at.y, drop_id):
		return
	it.x = at.x
	it.y = at.y
	if int(it.kind) == Catalog.ITEM_WOOD:
		sfx_queue.append("wood_drop")
	elif int(it.kind) == Catalog.ITEM_BONE:
		sfx_queue.append("bone_drop")
	if int(it.kind) == Catalog.ITEM_EGG:
		_help_egg(it)


func is_holding() -> bool:
	return held_kind != "" or hand_id != -1 or has_scoop()


func grab_thronglet(id: int) -> bool:
	if frozen or is_holding():
		return false
	if id < 0 or id >= slot_count or state[id] != Catalog.ST_LIVING:
		return false
	held_kind = "thronglet"
	held_ref = id
	held_x = pos_x[id]
	held_y = pos_y[id]
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
		_unbind_feature(feat)
		return true
	var b := _building_at(x, y, 16.0)
	if not b.is_empty():
		held_kind = "building"
		held_ref = int(b.id)
		held_x = float(b.x)
		held_y = float(b.y)
		_lift_building(b)
		return true
	var it := _item_at(x, y, 10.0)
	if not it.is_empty() and (bool(it.get("fixed", false)) or int(it.kind) == Catalog.ITEM_EGG):
		if int(it.kind) == Catalog.ITEM_EGG:
			_help_egg(it)
		return false
	return take_hand(x, y)


func release_at(x: float, y: float, short_click: bool, allow_use: bool = true) -> Dictionary:
	if hand_id != -1:
		var it = item_by_id.get(hand_id, {})
		var ix := x
		var iy := y
		if short_click and not it.is_empty():
			ix = float(it.x)
			iy = float(it.y)
		elif not it.is_empty() and Catalog.item_snaps_grid(int(it.kind)):
			var snapped := Catalog.snap_world(ix, iy)
			ix = snapped.x
			iy = snapped.y
		drop_hand(ix, iy)
		return {}
	if held_kind == "":
		return {}
	var px := held_x if short_click else x
	var py := held_y if short_click else y
	var kind := held_kind
	var id := held_ref
	var use := allow_use and short_click and kind == "building"
	if kind != "thronglet" and not short_click:
		var snapped := Catalog.snap_world(px, py)
		px = snapped.x
		py = snapped.y
	if kind == "thronglet" and id >= 0 and id < slot_count and state[id] == Catalog.ST_LIVING:
		if not short_click and _tile_at(px, py) == Catalog.TILE_VOID:
			pos_x[id] = px
			pos_y[id] = py
			_fall_void(px, py)
			_vacate(id)
		elif short_click or _can_drop(px, py):
			pos_x[id] = px
			pos_y[id] = py
	elif kind == "rock":
		var feat = feature_by_id.get(id, {})
		if not feat.is_empty() and not feat.dead:
			if _tile_at(px, py) == Catalog.TILE_VOID:
				_fall_void(px, py)
				_kill_feature(feat)
			elif not _can_drop(px, py) or not _stands(px, py, _span_for_feature(int(feat.kind))) or not _bind_feature_at(feat, px, py):
				feat.x = held_x
				feat.y = held_y
				_bind_feature_at(feat, held_x, held_y)
			feat.lifted = false
	elif kind == "building":
		var b = building_by_id.get(id, {})
		if not b.is_empty() and not b.dead:
			var placed := _can_drop(px, py) and _building_spot_free(id, px, py) and _bind_building_at(b, px, py)
			if not placed:
				b.x = held_x
				b.y = held_y
				_bind_building_at(b, held_x, held_y)
			b.lifted = false
	_clear_held()
	if use:
		return eye_use(held_x, held_y)
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


func _can_drop(x: float, y: float, allow_ore: bool = false) -> bool:
	return revealed.has(_ck_of(x, y)) and not _blocked(x, y, allow_ore) and not _on_bridge(x, y)


func _tile_holds(px: float, py: float) -> bool:
	var tile := _tile_at(px, py)
	if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER or tile == Catalog.TILE_FOG:
		return false
	return not _is_bridge_tile(tile)


func _span_for_feature(kind: int) -> Vector2:
	if kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_FLOWER or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
		return Vector2(8.0, 14.0)
	if kind == Catalog.FEAT_BIGROCK:
		return Vector2(12.0, 22.0)
	return Vector2(16.0, 52.0)


func _stands(x: float, y: float, span: Vector2) -> bool:
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
		# Fresh mines must sit on an ore node; relocated mines already consumed theirs.
		if id < 0 and mine_feat_id < 0:
			return false
	for cell in cells:
		var at := _cell_world(cell)
		if not revealed.has(_ck_of(at.x, at.y)) or _on_bridge(at.x, at.y):
			return false
		var bid := int(building_cell.get(cell, -1))
		if bid >= 0 and bid != id:
			return false
		var fid := int(feature_cell.get(cell, -1))
		if fid >= 0:
			# Ore nodes are 2x2; a mine may cover every cell of the same node.
			if not mine or fid != mine_feat_id:
				return false
		if not _item_spot_free(at.x, at.y):
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
	_unbind_feature(feat)
	feat.x = x
	feat.y = y
	var c := _chunk_at(x, y)
	feat.cx = c.x
	feat.cy = c.y
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
			return false
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
		return bool(unlocks.get(str(entry.unlock), false))
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
		ore_feat = _feature_at(at.x, at.y, 12.0)
		if ore_feat.is_empty() or _ore_tier(int(ore_feat.kind)) == 0:
			notes.append("LA MINA SOLO VA SOBRE UN NODO.")
			sfx_queue.append("error")
			return false
		node = _ore_tier(int(ore_feat.kind))
		at = Catalog.snap_world(float(ore_feat.x), float(ore_feat.y))
	var allow_ore := not ore_feat.is_empty()
	if not _can_drop(at.x, at.y, allow_ore) or not _building_spot_free(-1, at.x, at.y, kind):
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sfx_queue.append("error")
		return false
	if not _consume_kind(Catalog.ITEM_WOOD, int(info.wood), at.x, at.y):
		notes.append("FALTA MADERA.")
		sfx_queue.append("error")
		return false
	if allow_ore:
		_kill_feature(ore_feat)
	var b := _add_building(kind, at.x, at.y)
	if b.is_empty():
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sfx_queue.append("error")
		return false
	b.node = node
	sfx_queue.append(_place_sfx(kind))
	_pop(at.x, at.y, int(info.icon))
	_refresh_pop_gates()
	return true


func spot_ok(x: float, y: float, building_id: int = -1, ignore_item_id: int = -1, build_kind: int = -1) -> bool:
	var at := Catalog.snap_world(x, y)
	var allow_ore := build_kind == Catalog.BLD_MINE or build_kind == Catalog.BLD_MINE2
	if not allow_ore and building_id >= 0:
		var held = building_by_id.get(building_id, {})
		var held_kind := int(held.get("kind", -1))
		allow_ore = held_kind == Catalog.BLD_MINE or held_kind == Catalog.BLD_MINE2
	if not _can_drop(at.x, at.y, allow_ore):
		return false
	if building_id >= 0 or build_kind >= 0:
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
	var at := Catalog.snap_world(x, y)
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
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
	if gems < cost:
		notes.append("FALTAN GEMAS.")
		return false
	gems -= cost
	_grant(key, "COMPRADO: " + str(Catalog.MARKET[key].label))
	return true


func choose(index: int) -> void:
	if modal.is_empty():
		return
	_restore_gaze()
	var event := str(modal.event)
	var action: Dictionary = modal.action if modal.action is Dictionary else {}
	var gaze: Dictionary = Catalog.GAZE[event]
	var choices: Array = gaze.choices
	if index < 0 or index >= choices.size():
		return
	_set_ethics(event, index, str(choices[index]))
	_apply_moral_choice(gaze, index)
	modal = {}
	frozen = false
	var allow: Array = gaze.allow
	if allow.has(index) and not action.is_empty():
		_apply_action(action)
	sfx_queue.append("ui")
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
	var n := 0
	for it in items:
		if not it.dead and not it.held and int(it.kind) == kind:
			n += 1
	for i in slot_count:
		if carry[i] == Catalog.CARRY_WOOD and kind == Catalog.ITEM_WOOD:
			n += 1
		elif carry[i] == Catalog.CARRY_BONE and kind == Catalog.ITEM_BONE:
			n += 1
		elif carry[i] == Catalog.CARRY_ORE and kind == Catalog.ITEM_ORE:
			n += 1
	return n


func count_dead() -> int:
	var n := 0
	for i in slot_count:
		if state[i] == Catalog.ST_DEAD:
			n += 1
	return n


func debug_spawn(amount: int, around: Vector2) -> void:
	for _n in amount:
		if slot_count >= Catalog.MAX_SLOTS:
			break
		var x := around.x + randf_range(-360.0, 360.0)
		var y := around.y + randf_range(-220.0, 220.0)
		if _blocked(x, y):
			x = around.x
			y = around.y
		_push_slot(x, y, 80.0, 80.0, 80.0, 8.0, randi() % Catalog.TINTS.size())
	_rebuild_hash()
	notes.append("ENJAMBRE DE PRUEBA: %d" % living)


func world_open() -> bool:
	return bridge_open or part_two


func chunk_shown(ck: String) -> bool:
	if not revealed.has(ck):
		return false
	if ck == "0,0":
		return true
	return world_open()


func chunk_key_at(x: float, y: float) -> String:
	var c := _chunk_at(x, y)
	return _ck(c.x, c.y)


func _hide_closed_world() -> void:
	if world_open():
		return
	var drop: Array = []
	for key in revealed.keys():
		if str(key) != "0,0":
			drop.append(str(key))
	for ck in drop:
		revealed.erase(ck)
		_mark_dirty(ck)


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


func query_rect(rect: Rect2) -> Array:
	var half := rect.size * 0.5
	return query_radius(rect.get_center().x, rect.get_center().y, half.length() + 24.0)


func query_radius(x: float, y: float, radius: float) -> Array:
	var out: Array = []
	if hash_head.is_empty():
		return out
	var reach := int(ceil(radius / Catalog.HASH_CELL))
	var cx := int(floor(x / Catalog.HASH_CELL))
	var cy := int(floor(y / Catalog.HASH_CELL))
	var r2 := radius * radius
	for oy in range(cy - reach, cy + reach + 1):
		for ox in range(cx - reach, cx + reach + 1):
			var i := hash_head[_bucket_cell(ox, oy)]
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
const SLOT_COUNT := 4


func _pop(x: float, y: float, icon: int) -> void:
	pops.append({"x": x, "y": y, "t": 0.55, "icon": icon, "lift": 0.0})


func _tick_pops(dt: float) -> void:
	var kept: Array = []
	for pop in pops:
		pop.t = float(pop.t) - dt
		pop.lift = float(pop.lift) + 22.0 * dt
		if float(pop.t) > 0.0:
			kept.append(pop)
	pops = kept


func _boot_game() -> void:
	var last := _last_slot()
	if last >= 0 and load_slot(last):
		return
	var legacy := "user://thronglets_infinite.save"
	if FileAccess.file_exists(legacy):
		save_path = legacy
		if load_game():
			save_slot(0)
			return
	_bootstrap_new()


func new_game() -> void:
	current_slot = -1
	ethics = []
	_init_unlocks()
	unlock_serial += 1
	world_seed = randi()
	if world_seed == 0:
		world_seed = 1
	_bootstrap_new()
	notes.append("PARTIDA NUEVA.")


func list_slots() -> Array:
	var meta := _read_meta()
	var out: Array = []
	for i in SLOT_COUNT:
		var row: Dictionary = meta.get(str(i), {})
		out.append({
			"i": i,
			"used": FileAccess.file_exists(_slot_path(i)),
			"living": int(row.get("living", 0)),
			"peak": int(row.get("peak", 0)),
		})
	return out


func save_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	current_slot = index
	save_path = _slot_path(index)
	if not save_game():
		return false
	var meta := _read_meta()
	meta["last"] = index
	meta[str(index)] = {"living": living, "peak": peak}
	_write_meta(meta)
	autosave_t = 0.0
	return true


func _tick_autosave(delta: float) -> void:
	if testing or game_over or not session_live or autosave_interval <= 0.0:
		return
	autosave_t += delta
	if autosave_t < autosave_interval:
		return
	autosave_t = 0.0
	var index := current_slot if current_slot >= 0 else 0
	save_slot(index)


func has_checkpoint() -> bool:
	return current_slot >= 0 and FileAccess.file_exists(_slot_path(current_slot))


func load_checkpoint() -> bool:
	if not has_checkpoint():
		return false
	return load_slot(current_slot)


func load_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	save_path = _slot_path(index)
	if not load_game():
		return false
	current_slot = index
	var meta := _read_meta()
	meta["last"] = index
	_write_meta(meta)
	unlock_serial += 1
	return true


func delete_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	var path := _slot_path(index)
	if FileAccess.file_exists(path):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(path.get_file())
	var meta := _read_meta()
	meta.erase(str(index))
	if int(meta.get("last", -1)) == index:
		meta["last"] = -1
		for i in SLOT_COUNT:
			if i != index and FileAccess.file_exists(_slot_path(i)):
				meta["last"] = i
				break
	_write_meta(meta)
	if current_slot == index:
		current_slot = -1
	notes.append("PARTIDA BORRADA.")
	return true


func _slot_path(index: int) -> String:
	return "user://thronglets_slot_%d.save" % index


func resume_last() -> bool:
	if session_live:
		return true
	var last := _last_slot()
	if last < 0:
		return false
	return load_slot(last)


func _last_slot() -> int:
	var meta := _read_meta()
	return int(meta.get("last", -1))


func _read_meta() -> Dictionary:
	if not FileAccess.file_exists("user://thronglets_slots.meta"):
		return {}
	var file := FileAccess.open("user://thronglets_slots.meta", FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var(true)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func _write_meta(meta: Dictionary) -> void:
	var file := FileAccess.open("user://thronglets_slots.meta", FileAccess.WRITE)
	if file != null:
		file.store_var(meta, true)


func save_game() -> bool:
	cancel_hold()
	var gazing := frozen and not gaze_home.is_empty()
	_restore_gaze()
	_compact(items)
	_compact(features)
	_compact(buildings)
	var data := {
		"v": 1,
		"seed": world_seed,
		"peak": peak,
		"gems": gems,
		"gems_peak": gems_peak,
		"land_tier": land_tier,
		"bridge_open": bridge_open,
		"glitch_seen": glitch_seen,
		"unlocks": unlocks.duplicate(true),
		"ethics": ethics.duplicate(true),
		"moral": moral,
		"mutations": mutations.duplicate(true),
		"part_two": part_two,
		"mountain_seen": mountain_seen,
		"trees_chopped": trees_chopped,
		"stumps_cleared": stumps_cleared,
		"bug_uses": bug_uses,
		"tnt_used": tnt_used,
		"goo_count": goo_count,
		"cap_told": cap_told,
		"monoliths": monolith_tier_spawned.duplicate(true),
		"pos_x": pos_x,
		"pos_y": pos_y,
		"dir_x": dir_x,
		"dir_y": dir_y,
		"fed": fed,
		"amused": amused,
		"clean": clean,
		"cool": cool,
		"starve": starve,
		"hungry_t": hungry_t,
		"wander_t": wander_t,
		"mito_t": mito_t,
		"mito_charge": mito_charge,
		"shake_t": shake_t,
		"buff_t": buff_t,
		"state": state,
		"carry": carry,
		"carry_value": carry_value,
		"tint": tint,
		"claim": claim,
		"act": act,
		"act_t": act_t,
		"items": items.duplicate(true),
		"buildings": buildings.duplicate(true),
		"features": features.duplicate(true),
		"tree_seeds": tree_seeds.duplicate(true),
		"bridges": bridges.duplicate(true),
		"chunks": chunks.duplicate(true),
		"wear": wear.duplicate(),
		"bridge_done": bridge_done.duplicate(true),
		"revealed": revealed.duplicate(true),
		"sister_cx": sister_cx,
		"sister_cy": sister_cy,
		"sister_ready": sister_ready,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		notes.append("NO SE PUDO GUARDAR.")
		if gazing:
			_line_up_gaze()
		return false
	file.store_var(data, true)
	notes.append("PARTIDA GUARDADA.")
	if gazing:
		_line_up_gaze()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		notes.append("NO HAY PARTIDA.")
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var(true)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 1 or not data.has("pos_x"):
		notes.append("PARTIDA ILEGIBLE.")
		return false
	_reset_world()
	world_seed = int(data.get("seed", 1))
	peak = int(data.get("peak", 0))
	gems = int(data.get("gems", 0))
	gems_peak = maxi(int(data.get("gems_peak", gems)), gems)
	land_tier = int(data.get("land_tier", 0))
	bridge_open = bool(data.get("bridge_open", false))
	unlocks = data.get("unlocks", unlocks)
	glitch_seen = bool(data.get("glitch_seen", false))
	ethics = data.get("ethics", [])
	moral = int(data.get("moral", 0))
	mutations = data.get("mutations", {})
	if typeof(mutations) != TYPE_DICTIONARY:
		mutations = {}
	part_two = bool(data.get("part_two", false))
	mountain_seen = bool(data.get("mountain_seen", false))
	trees_chopped = int(data.get("trees_chopped", 0))
	stumps_cleared = int(data.get("stumps_cleared", 0))
	bug_uses = int(data.get("bug_uses", 0))
	tnt_used = int(data.get("tnt_used", 0))
	goo_count = int(data.get("goo_count", 0))
	cap_told = bool(data.get("cap_told", false))
	monolith_tier_spawned = data.get("monoliths", {})
	talk_pending = {}
	gaze_queue.clear()
	pos_x = _as_f32(data.pos_x)
	pos_y = _as_f32(data.pos_y)
	dir_x = _as_f32(data.dir_x)
	dir_y = _as_f32(data.dir_y)
	fed = _as_f32(data.fed)
	amused = _as_f32(data.amused)
	clean = _as_f32(data.clean)
	cool = _as_f32(data.cool)
	starve = _as_f32(data.starve)
	hungry_t = _as_f32(data.get("hungry_t", []))
	wander_t = _as_f32(data.wander_t)
	mito_t = _as_f32(data.mito_t)
	mito_charge = _as_f32(data.get("mito_charge", []))
	shake_t = _as_f32(data.shake_t)
	buff_t = _as_f32(data.buff_t)
	state = _as_i32(data.state)
	carry = _as_i32(data.carry)
	carry_value = _as_i32(data.carry_value)
	tint = _as_i32(data.tint)
	claim = _as_i32(data.claim)
	slot_count = pos_x.size()
	act = _as_i32(data.get("act", []))
	act_t = _as_f32(data.get("act_t", []))
	while act.size() < slot_count:
		act.append(0)
	while act_t.size() < slot_count:
		act_t.append(0.0)
	while mito_charge.size() < slot_count:
		mito_charge.append(0.0)
	while hungry_t.size() < slot_count:
		hungry_t.append(0.0)
	items = data.get("items", [])
	buildings = data.get("buildings", [])
	features = data.get("features", [])
	tree_seeds = data.get("tree_seeds", [])
	bridges = data.get("bridges", [])
	chunks = data.get("chunks", {})
	wear = data.get("wear", {})
	if typeof(wear) != TYPE_DICTIONARY:
		wear = {}
	wear_from.clear()
	bridge_done = data.get("bridge_done", {})
	revealed = data.get("revealed", {})
	sister_cx = int(data.get("sister_cx", 1))
	sister_cy = int(data.get("sister_cy", 0))
	sister_ready = bool(data.get("sister_ready", false))
	_recount()
	_reindex()
	if not bridge_open and (part_two or land_tier >= 2):
		bridge_open = true
	_refresh_pop_gates(false)
	_shape_island()
	_hide_closed_world()
	if bridge_open and not part_two and _ethics_choice("need_bridge") == -1:
		_queue_talk("need_bridge", {})
	_repair_done_bridges()
	_ensure_island_mines()
	_rebuild_hash()
	paint_epoch += 1
	dirty_chunks.clear()
	for key in revealed.keys():
		dirty_chunks.append(str(key))
	frozen = false
	game_over = false
	paused = false
	modal = {}
	hand_id = -1
	_clear_held()
	sponge_id = -1
	sponge_hold = 0.0
	notes.append("PARTIDA CARGADA.")
	session_live = true
	_open_special_biomes()
	if living <= 0 and peak > 0:
		_enter_game_over()
	return true


func _repair_done_bridges() -> void:
	for bridge in bridges:
		if not bool(bridge.get("done", false)):
			continue
		var tile := Catalog.TILE_BRIDGE_BONE if int(bridge.get("bones", 0)) > 0 else Catalog.TILE_BRIDGE_WOOD
		var dest := _sister_chunk()
		_reveal(dest.x, dest.y)
		var start := _home_bridge_drop()
		var finish := _nearest_island_shore(dest.x, dest.y, start)
		_paint_wood_bridge(start, finish, tile)


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
	_add_item(kind, pos_x[i], pos_y[i], maxi(1, carry_value[i]))
	carry[i] = Catalog.CARRY_NONE
	carry_value[i] = 0


func _lift_building(b: Dictionary) -> void:
	var occ := int(b.get("occupant", -1))
	if occ >= 0 and occ < claim.size():
		claim[occ] = -1
	b.occupant = -1
	b.bath_t = -1.0
	b.guests = []
	b.away = []
	b.riders = []
	b.lifted = true
	b.active = false
	_unbind_building(b)


func _deflesh(id: int, count_use: bool) -> void:
	if id < 0 or id >= slot_count or state[id] == Catalog.ST_VACANT:
		return
	var x := pos_x[id]
	var y := pos_y[id]
	var was_living := state[id] == Catalog.ST_LIVING
	_release_claim(id)
	_release_item_claims(id)
	_drop_carried(id)
	_clear_ride(id)
	if was_living:
		living -= 1
	state[id] = Catalog.ST_VACANT
	_add_item(Catalog.ITEM_BONE, x, y, 1)
	_pop(x, y, ThrongClips.frame_at("ThrongA_Bones", 0))
	if count_use and part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")
	sfx_queue.append("deflesh")
	if was_living and living <= 0:
		_enter_game_over()


func _swarm(x: float, y: float) -> void:
	var ids := query_radius(x, y, 36.0)
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
			state[i] = Catalog.ST_VACANT
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
			_become_corpse(int(id))
			any = true
	if any:
		sfx_queue.append("bones")
		_reflect("tool")


func _die_neglect(i: int) -> void:
	_become_corpse(i)
	sfx_queue.append("bones")
	_reflect("neglect")


func _become_corpse(i: int) -> void:
	if state[i] != Catalog.ST_LIVING:
		return
	state[i] = Catalog.ST_DEAD
	living -= 1
	carry[i] = Catalog.CARRY_NONE
	_release_claim(i)
	_release_item_claims(i)
	_clear_ride(i)
	if living <= 0:
		_enter_game_over()


func _vacate(i: int) -> void:
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return
	var was_living := state[i] == Catalog.ST_LIVING
	if was_living:
		living -= 1
	state[i] = Catalog.ST_VACANT
	_release_claim(i)
	_release_item_claims(i)
	_clear_ride(i)
	if was_living and living <= 0:
		_enter_game_over()


func _enter_game_over() -> void:
	if game_over or living > 0 or peak <= 0:
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
	if game_over or not Catalog.GAZE.has(event):
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
		if _ethics_choice(event) != -1 and (next.action is Dictionary and next.action.is_empty()):
			continue
		_schedule_talk(event, next.action if next.action is Dictionary else {})
		return


func _schedule_talk(event: String, action: Dictionary) -> void:
	var wait := 0.0 if testing else TALK_OPEN_DELAY
	if wait <= 0.0:
		modal = {"event": event, "action": action}
		_begin_gaze()
		return
	talk_pending = {"event": event, "action": action, "wait": wait}


func _tick_talk_wait(delta: float) -> void:
	if talk_pending.is_empty() or not modal.is_empty() or frozen or game_over:
		return
	talk_pending.wait = maxf(0.0, float(talk_pending.wait) - delta)
	if float(talk_pending.wait) > 0.0:
		return
	modal = {"event": str(talk_pending.event), "action": talk_pending.action if talk_pending.action is Dictionary else {}}
	talk_pending = {}
	_begin_gaze()


func _begin_gaze() -> void:
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
		if is_inf(spot.x):
			spot = focus + Vector2((float(placed % 4) - 1.5) * 22.0, 36.0 + float(int(placed / 4)) * 18.0)
		pos_x[i] = spot.x
		pos_y[i] = spot.y
		dir_x[i] = 0.0
		dir_y[i] = 1.0
		gaze_home[i] = Vector2(here_x, here_y)
		placed += 1


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
	for step in 16:
		for side in [-1, 0, 1]:
			var at := base + Vector2(float(side) * 14.0 + float(step) * 6.0, float(step) * 12.0)
			if _blocked(at.x, at.y) or _gaze_taken(at.x, at.y):
				continue
			if is_inf(fallback.x):
				fallback = at
			if not _gaze_covered(at.x, at.y):
				return at
	return fallback


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


func _apply_moral_choice(gaze: Dictionary, index: int) -> void:
	var morals: Array = gaze.get("moral", [])
	if index < morals.size():
		moral = clampi(moral + int(morals[index]), -5, 5)
	var flags: Array = gaze.get("mutate", [])
	if index < flags.size():
		var flag := str(flags[index])
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


func _decay_scale() -> float:
	var scale := 1.0
	if bool(mutations.get("care", false)) or moral > 0:
		scale *= 0.9
	if bool(mutations.get("hard", false)) or bool(mutations.get("numb", false)) or moral < 0:
		scale *= 1.12
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
	sfx_queue.append("unlock_" + key)
	if talk and Catalog.UNLOCK_TALK.has(key):
		_queue_talk(str(Catalog.UNLOCK_TALK[key]), {})
	elif message != "":
		notes.append(message)
	return true


func _refresh_pop_gates(announce: bool = true) -> void:
	# One tool when the previous task is done, so the talk matches the goal.
	if peak >= 6:
		_grant("axe", "", announce)
	if trees_chopped >= 1:
		_grant("hammer", "", announce)
	if stumps_cleared >= 1:
		_grant("bathtub", "", announce)
	if _has_building(Catalog.BLD_TUB):
		_grant("apple_tree", "", announce)
	if _has_building(Catalog.BLD_APPLE):
		_grant("roundabout", "", announce)
	if peak >= 25:
		_ensure_monolith(1)
	if _has_building(Catalog.BLD_ROUND) and peak >= 12:
		_open_sister(announce)
	_check_milestones(announce)


func _open_sister(announce: bool) -> void:
	if part_two:
		return
	var first := not bridge_open
	bridge_open = true
	_ensure_bridge_site()
	if first and announce and _ethics_choice("need_bridge") == -1:
		_queue_talk("need_bridge", {})


func _milestone_defs() -> Array:
	return [
		{"kind": "pop", "n": 6},
		{"kind": "pop", "n": 12},
		{"kind": "bridge", "n": 0},
		{"kind": "gem", "n": 20},
		{"kind": "pop", "n": 30},
		{"kind": "gem", "n": 100},
		{"kind": "pop", "n": 80},
		{"kind": "gem", "n": 500},
	]


func _milestone_met(step: Dictionary) -> bool:
	var kind := str(step.kind)
	if kind == "pop":
		return peak >= int(step.n)
	if kind == "gem":
		return gems_peak >= int(step.n)
	return part_two


func _check_milestones(announce: bool = true) -> void:
	if gems > gems_peak:
		gems_peak = gems
	var defs := _milestone_defs()
	var grew := false
	while land_tier < defs.size() and _milestone_met(defs[land_tier]):
		land_tier += 1
		grew = true
	if not grew:
		_hide_closed_world()
		_open_special_biomes()
		return
	if announce:
		notes.append("LA ISLA CRECE.")
	_shape_island()
	_hide_closed_world()
	_open_special_biomes()


func _ensure_bridge_site() -> void:
	if part_two or not world_open():
		return
	_ensure_sister_layout()
	var gap := _gap_chunk()
	var sister := _sister_chunk()
	if not revealed.has(_ck(gap.x, gap.y)):
		_reveal(gap.x, gap.y)
	if not revealed.has(_ck(sister.x, sister.y)):
		_reveal(sister.x, sister.y)
	if _primary_open_bridge().is_empty():
		_ensure(gap.x, gap.y)
		_ensure(sister.x, sister.y)
		var drop := _home_bridge_drop()
		var far := _nearest_island_shore(sister.x, sister.y, drop)
		var mid := drop.lerp(far, 0.5)
		bridges.append({
			"ck": _ck(gap.x, gap.y),
			"x": mid.x,
			"y": mid.y,
			"drop_x": drop.x,
			"drop_y": drop.y,
			"progress": 0,
			"need": 6,
			"bones": 0,
			"done": false,
		})
	else:
		var bridge := _primary_open_bridge()
		var drop2 := _home_bridge_drop()
		bridge.drop_x = drop2.x
		bridge.drop_y = drop2.y


func _ensure_sister_layout() -> void:
	if sister_ready:
		return
	# Adjacent chunk: short void between shores for the bridge.
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var pick: Vector2i = dirs[absi(int(world_seed)) % dirs.size()]
	sister_cx = pick.x
	sister_cy = pick.y
	sister_ready = true


func _sister_chunk() -> Vector2i:
	_ensure_sister_layout()
	return Vector2i(sister_cx, sister_cy)


func _gap_chunk() -> Vector2i:
	# Bridge key lives on the sister chunk (adjacent void between island edges).
	return _sister_chunk()


func goal_line() -> String:
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
		return _goal_build("CONSTRUYE UNA BANERA", 1)
	if not _has_building(Catalog.BLD_APPLE):
		return _goal_build("PLANTA UN MANZANO", 1)
	if not _has_building(Catalog.BLD_ROUND):
		return _goal_build("COLOCA UN TIOVIVO", 1)
	if peak < 12:
		return "CRECE LA COLONIA  %d/12" % mini(peak, 12)
	if not part_two:
		var bridge := _primary_open_bridge()
		if bridge.is_empty():
			return "PREPARA EL PUENTE"
		return "PUENTE  %d/%d  TALA MADERA Y ELLOS LA LLEVAN" % [mini(int(bridge.progress), int(bridge.need)), int(bridge.need)]
	var defs := _milestone_defs()
	if land_tier >= defs.size():
		return "LA ISLA ESTA COMPLETA"
	var step: Dictionary = defs[land_tier]
	var kind := str(step.kind)
	var n := int(step.n)
	if kind == "pop":
		return "EXPANDE  %d/%d MULTIS" % [mini(peak, n), n]
	if kind == "gem":
		if n >= 100 and bool(unlocks.get("mine", false)):
			return "JUNTA ENERGIA  %d/%d  (MINAS EN NODOS → CRISTALES)" % [mini(gems_peak, n), n]
		return "JUNTA ENERGIA  %d/%d  (MARTILLO: ROCA → MINERAL)" % [mini(gems_peak, n), n]
	return "HAZ UN PUENTE"


func _goal_build(label: String, cost: int) -> String:
	var have := count_item(Catalog.ITEM_WOOD)
	if have < cost:
		return "TALA MADERA  %d/%d  LUEGO %s" % [have, cost, label]
	return "%s  (%d MADERA)" % [label, cost]


func _enter_part_two(reason: String, talk_market: bool = true) -> void:
	var first := not part_two
	part_two = true
	_grant("market", "", talk_market)
	_grant("flower", "", false)
	_grant("sculpture", "", false)
	if first:
		_seed_early_ore(12)
		_grant("pickaxe", "", false)
		_grant("mine", "", false)
		notes.append("EL PICO Y LAS MINAS YA ESTAN. EL MERCADO, EN EL MENU.")
		if reason != "":
			notes.append(reason)
	_check_milestones()


func _seed_early_ore(want: int = 12) -> void:
	if want <= 0:
		return
	var placed := 0
	var chunks_to_fill: Array[Vector2i] = [Vector2i(0, 0)]
	var sister := _sister_chunk()
	if chunks.has(_ck(sister.x, sister.y)):
		chunks_to_fill.append(sister)
	for c in chunks_to_fill:
		if placed >= want:
			break
		var ck := _ck(c.x, c.y)
		if not chunks.has(ck):
			_ensure(c.x, c.y)
		var tiles = chunks[ck].tiles
		for _try in 80:
			if placed >= want:
				break
			var lx := randi() % Catalog.CHUNK
			var ly := randi() % Catalog.CHUNK
			var tile := int(tiles[ly * Catalog.CHUNK + lx])
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER or _is_bridge_tile(tile):
				continue
			var wx := float((c.x * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy := float((c.y * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if _blocked(wx, wy) or _on_bridge(wx, wy):
				continue
			if c.x == 0 and c.y == 0 and _near_spawn(wx, wy):
				continue
			if not _feature_at(wx, wy, 14.0).is_empty():
				continue
			if not _building_at(wx, wy, 14.0).is_empty():
				continue
			_add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 3, true)
			placed += 1


func _ensure_monolith(tier: int) -> void:
	if bool(monolith_tier_spawned.get(tier, false)):
		return
	if tier == 1 and bool(unlocks.get("bug", false)):
		return
	if tier == 2 and bool(unlocks.get("nuke", false)):
		return
	monolith_tier_spawned[tier] = true
	var x := 168.0 + float(tier) * 78.0
	var y := 168.0
	if _blocked(x, y):
		x = 256.0
		y = 150.0 + float(tier) * 20.0
	_add_feature(Catalog.FEAT_MONOLITH, x, y, 4, tier)
	notes.append("UN MONOLITO HA APARECIDO.")
	sfx_queue.append("monolith_in")
	sfx_queue.append("monolith_reveal")


func _touch_monolith(feat: Dictionary) -> void:
	var tier := int(feat.ore)
	if tier == 1:
		_grant("bug", "EL MONOLITO ENTREGA EL BICHO. ABRE UN CUERPO Y DEJA HUESO.")
	elif tier == 2:
		_grant("nuke", "EL MONOLITO ENTREGA EL TERMAL. LIMPIA UN SECTOR. LA PARTIDA SIGUE.")
	_kill_feature(feat)
	sfx_queue.append("monolith")


func _drop_on_bridge(x: float, y: float, carry_kind: int) -> void:
	var bridge := _nearest_open_bridge(x, y, 90.0)
	if bridge.is_empty():
		return
	if carry_kind == Catalog.CARRY_BONE:
		bridge.progress = int(bridge.progress) + 3
		bridge.bones = int(bridge.bones) + 1
		sfx_queue.append("bridge_bone")
	else:
		bridge.progress = int(bridge.progress) + 1
		sfx_queue.append("bridge_wood")
	if int(bridge.progress) >= int(bridge.need) and not bool(bridge.done):
		_finish_bridge(bridge)


func _finish_bridge(bridge: Dictionary) -> void:
	bridge.done = true
	var ck := str(bridge.ck)
	bridge_done[ck] = true
	var tile := Catalog.TILE_BRIDGE_BONE if int(bridge.bones) > 0 else Catalog.TILE_BRIDGE_WOOD
	var dest := _sister_chunk()
	_reveal(dest.x, dest.y)
	var start := _home_bridge_drop()
	var finish := _nearest_island_shore(dest.x, dest.y, start)
	_paint_wood_bridge(start, finish, tile)
	bridge.drop_x = start.x
	bridge.drop_y = start.y
	notes.append("EL PUENTE DE MADERA LLEGA A LA ISLA.")
	var used_bones := int(bridge.bones) > 0
	_enter_part_two("EL PRIMER PUENTE ABRE LA SEGUNDA PARTE.", not used_bones)
	if used_bones:
		_reflect("bones")


func _nearest_island_shore(cx: int, cy: int, from: Vector2) -> Vector2:
	_ensure(cx, cy)
	var ck := _ck(cx, cy)
	var tiles = chunks[ck].tiles
	var best := _chunk_center(cx, cy)
	var best_d := 1.0e12
	var found := false
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(tiles[ly * Catalog.CHUNK + lx])
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE:
				continue
			var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			var d := _dist_point(from.x, from.y, wx, wy)
			if d < best_d:
				best_d = d
				best = Vector2(wx, wy)
				found = true
	if found:
		return best
	return _chunk_center(cx, cy)


func _paint_wood_bridge(start: Vector2, finish: Vector2, tile: int) -> void:
	var delta := finish - start
	var dist := delta.length()
	if dist < 1.0:
		return
	var dir := delta / dist
	# Bite a bit into both shores so the deck meets land without a seam.
	var from := start - dir * float(Catalog.TILE)
	var to := finish + dir * float(Catalog.TILE)
	var a := _cell_vec(from.x, from.y)
	var b := _cell_vec(to.x, to.y)
	var cells := _raster_line(a.x, a.y, b.x, b.y)
	var thick: Array[Vector2i] = [Vector2i(0, 0)]
	if absi(b.x - a.x) >= absi(b.y - a.y):
		thick.append(Vector2i(0, -1))
		thick.append(Vector2i(0, 1))
	else:
		thick.append(Vector2i(-1, 0))
		thick.append(Vector2i(1, 0))
	for cell in cells:
		for off in thick:
			_set_bridge_cell(cell.x + off.x, cell.y + off.y, tile)


func _raster_line(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	while true:
		out.append(Vector2i(x, y))
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return out


func _set_bridge_cell(cx: int, cy: int, tile: int) -> void:
	var chunk_x := _floor_div(cx, Catalog.CHUNK)
	var chunk_y := _floor_div(cy, Catalog.CHUNK)
	var ck := _ck(chunk_x, chunk_y)
	_ensure(chunk_x, chunk_y)
	if not revealed.has(ck):
		revealed[ck] = true
	var lx := cx - chunk_x * Catalog.CHUNK
	var ly := cy - chunk_y * Catalog.CHUNK
	if lx < 0 or ly < 0 or lx >= Catalog.CHUNK or ly >= Catalog.CHUNK:
		return
	var now := int(chunks[ck].tiles[ly * Catalog.CHUNK + lx])
	if now == Catalog.TILE_MOUNTAIN or now == Catalog.TILE_RUBBLE:
		return
	var cell := Vector2i(cx, cy)
	if feature_cell.has(cell):
		var feat = feature_by_id.get(int(feature_cell[cell]), {})
		if not feat.is_empty():
			_kill_feature(feat)
	var b := _building_at(float(cx * Catalog.TILE + 8), float(cy * Catalog.TILE + 8), 8.0)
	if not b.is_empty():
		b.dead = true
	_set_local_tile(ck, lx, ly, tile, true)


func _bridge_path_solid(start: Vector2, finish: Vector2) -> bool:
	var a := _cell_vec(start.x, start.y)
	var b := _cell_vec(finish.x, finish.y)
	var cells := _raster_line(a.x, a.y, b.x, b.y)
	for cell in cells:
		if not _cell_has_bridge_or_land(cell.x, cell.y) \
			and not _cell_has_bridge_or_land(cell.x + 1, cell.y) \
			and not _cell_has_bridge_or_land(cell.x - 1, cell.y) \
			and not _cell_has_bridge_or_land(cell.x, cell.y + 1) \
			and not _cell_has_bridge_or_land(cell.x, cell.y - 1):
			return false
	return true


func _cell_has_bridge_or_land(cx: int, cy: int) -> bool:
	var chunk_x := _floor_div(cx, Catalog.CHUNK)
	var chunk_y := _floor_div(cy, Catalog.CHUNK)
	var ck := _ck(chunk_x, chunk_y)
	if not chunks.has(ck):
		return false
	var lx := cx - chunk_x * Catalog.CHUNK
	var ly := cy - chunk_y * Catalog.CHUNK
	if lx < 0 or ly < 0 or lx >= Catalog.CHUNK or ly >= Catalog.CHUNK:
		return false
	var tile := int(chunks[ck].tiles[ly * Catalog.CHUNK + lx])
	return tile == Catalog.TILE_BRIDGE_WOOD or tile == Catalog.TILE_BRIDGE_BONE \
		or tile == Catalog.TILE_GRASS or tile == Catalog.TILE_DIRT or tile == Catalog.TILE_BLOOM


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
	_hide_closed_world()


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
	sfx_queue.append("egg_hatch")
	sfx_queue.append("hatch")
	_pop(x, y - 6.0, Catalog.ICON_EGG)
	_queue_talk("first_born", {})


func _reset_world() -> void:
	revealed.clear()
	chunks.clear()
	bridge_done.clear()
	bridges.clear()
	dirty_chunks.clear()
	sister_cx = 1
	sister_cy = 0
	sister_ready = false
	features.clear()
	feature_by_id.clear()
	feature_cell.clear()
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
	peak = 0
	gems = 0
	gems_peak = 0
	land_tier = 0
	special_biomes = {}
	bridge_open = false
	glitch_seen = false
	glitch_t = 0.0
	gaze_home.clear()
	barks.clear()
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
	mito_t = PackedFloat32Array()
	mito_charge = PackedFloat32Array()
	shake_t = PackedFloat32Array()
	buff_t = PackedFloat32Array()
	state = PackedInt32Array()
	carry = PackedInt32Array()
	carry_value = PackedInt32Array()
	tint = PackedInt32Array()
	claim = PackedInt32Array()
	act = PackedInt32Array()
	act_t = PackedFloat32Array()
	tick_stamp = PackedInt32Array()
	pops.clear()
	hash_next = PackedInt32Array()
	paint_epoch += 1


func _push_slot(x: float, y: float, fed_v: float, fun_v: float, clean_v: float, cool_v: float, tint_i: int) -> int:
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
	mito_t.append(0.0)
	mito_charge.append(0.0)
	shake_t.append(0.0)
	buff_t.append(0.0)
	state.append(Catalog.ST_LIVING)
	carry.append(Catalog.CARRY_NONE)
	carry_value.append(0)
	tint.append(_birth_tint(tint_i))
	claim.append(-1)
	act.append(0)
	act_t.append(0.0)
	tick_stamp.append(0)
	hash_next.append(-1)
	var id := slot_count
	slot_count += 1
	living += 1
	if living > peak:
		peak = living
		_refresh_pop_gates()
	return id


func _reveal(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	var fresh := not revealed.has(ck)
	revealed[ck] = true
	_ensure(cx, cy)
	if not fresh:
		return
	_mark_dirty(ck)


func _try_reveal(cx: int, cy: int) -> void:
	if not world_open() and not (cx == 0 and cy == 0):
		return
	# Only home, gap and sister exist as content. Sea chunks stay unrevealed fog.
	if not _is_known_chunk(cx, cy):
		return
	var ck := _ck(cx, cy)
	if revealed.has(ck):
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nk := _ck(cx + d.x, cy + d.y)
		if revealed.has(nk) and _edge_open(cx + d.x, cy + d.y, cx, cy):
			_reveal(cx, cy)
			return


func _is_known_chunk(cx: int, cy: int) -> bool:
	if cx == 0 and cy == 0:
		return true
	_ensure_sister_layout()
	var sister := _sister_chunk()
	var gap := _gap_chunk()
	return (cx == sister.x and cy == sister.y) or (cx == gap.x and cy == gap.y)


func _edge_open(ax: int, ay: int, bx: int, by: int) -> bool:
	var sister := _sister_chunk()
	var gap := _gap_chunk()
	var to_sister := bx == sister.x and by == sister.y
	var from_sister := ax == sister.x and ay == sister.y
	if to_sister or from_sister:
		return bool(bridge_done.get(_ck(gap.x, gap.y), false))
	return true


func _ensure(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if chunks.has(ck):
		return
	var biome := _biome_formula(cx, cy)
	var tiles := _fill_tiles(cx, cy, biome)
	chunks[ck] = {"biome": biome, "axis": "", "tiles": tiles, "base": tiles.duplicate()}
	if cx == 0 and cy == 0:
		_shape_island()
		_seed_mine_nodes(0, 0)
	elif _is_island_chunk(cx, cy):
		_shape_remote_island(cx, cy)
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
	elif _is_island_chunk(cx, cy):
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
	if cx == 0 and cy == 0:
		return true
	_ensure_sister_layout()
	return cx == sister_cx and cy == sister_cy


func _shape_remote_island(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if not chunks.has(ck):
		return
	var tiles = chunks[ck].tiles
	var mid := float(Catalog.CHUNK * Catalog.TILE) * 0.5
	# Equal or larger than the home island at the moment it appears.
	var reach := maxf(148.0, _island_reach() + 12.0)
	reach = minf(reach, 220.0)
	var phase := float(absi(cx * 13 + cy * 29 + int(world_seed))) * 0.17
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var idx := ly * Catalog.CHUNK + lx
			var now := int(tiles[idx])
			if now == Catalog.TILE_BRIDGE_WOOD or now == Catalog.TILE_BRIDGE_BONE:
				continue
			var wx := float(lx * Catalog.TILE + 8)
			var wy := float(ly * Catalog.TILE + 8)
			if _disk_land(wx, wy, mid, reach, phase):
				if now != Catalog.TILE_DIRT and now != Catalog.TILE_WATER:
					tiles[idx] = Catalog.TILE_GRASS
			elif now != Catalog.TILE_BRIDGE_WOOD and now != Catalog.TILE_BRIDGE_BONE:
				tiles[idx] = Catalog.TILE_VOID
	tiles = _paint_water(tiles, cx, cy)
	chunks[ck].tiles = tiles
	chunks[ck].base = tiles.duplicate()
	_seed_mine_nodes(cx, cy)


func _ensure_island_mines() -> void:
	_seed_mine_nodes(0, 0)
	_ensure_sister_layout()
	var sister := _sister_chunk()
	if chunks.has(_ck(sister.x, sister.y)):
		_seed_mine_nodes(sister.x, sister.y)


func _count_mine_nodes(cx: int, cy: int) -> int:
	var n := 0
	for feat in features:
		if feat.dead:
			continue
		if int(feat.cx) != cx or int(feat.cy) != cy:
			continue
		if _ore_tier(int(feat.kind)) > 0:
			n += 1
	return n


func _seed_mine_nodes(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if not chunks.has(ck):
		return
	var tiles = chunks[ck].tiles
	var placed := _count_mine_nodes(cx, cy)
	var want := 3
	var tries := 0
	while placed < want and tries < 400:
		tries += 1
		var lx := randi() % Catalog.CHUNK
		var ly := randi() % Catalog.CHUNK
		if not _mine_spot_ok(cx, cy, lx, ly, tiles, 58.0):
			continue
		var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		var kind := Catalog.FEAT_SUPER if placed == 0 else Catalog.FEAT_NODE
		var ore := 2 if kind == Catalog.FEAT_SUPER else 1
		if _add_feature(kind, wx, wy, 1, ore, true).is_empty():
			continue
		placed += 1
	if placed > 0:
		return
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not _mine_spot_ok(cx, cy, lx, ly, tiles, 0.0):
				continue
			var fx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var fy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if not _add_feature(Catalog.FEAT_SUPER, fx, fy, 1, 2, true).is_empty():
				return


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


func _mine_spot_ok(cx: int, cy: int, lx: int, ly: int, tiles, mid_min: float) -> bool:
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var nx := lx + ox
			var ny := ly + oy
			if nx < 0 or ny < 0 or nx >= Catalog.CHUNK or ny >= Catalog.CHUNK:
				return false
			var tile := int(tiles[ny * Catalog.CHUNK + nx])
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or _is_bridge_tile(tile):
				return false
			var wx := float((cx * Catalog.CHUNK + nx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ny) * Catalog.TILE + 8)
			var key := Vector2i(cx * Catalog.CHUNK + nx, cy * Catalog.CHUNK + ny)
			if feature_cell.has(key):
				var feat = feature_by_id.get(int(feature_cell[key]), {})
				if not feat.is_empty() and not feat.dead:
					return false
			if not _building_at(wx, wy, 10.0).is_empty():
				return false
	if mid_min > 0.0:
		var local_mid := float(Catalog.CHUNK * Catalog.TILE) * 0.5
		if _dist_point(local_mid, local_mid, float(lx * Catalog.TILE + 8), float(ly * Catalog.TILE + 8)) < mid_min:
			return false
	return true


func _fall_void(x: float, y: float) -> void:
	_pop(x, y, Catalog.ICON_FX_POOF)
	notes.append("SE CAE AL VACIO. LA PARTIDA SIGUE.")
	sfx_queue.append("crush")


func occupancy_text(b: Dictionary) -> String:
	var rule := _visit_rule(int(b.kind))
	if rule.is_empty():
		return ""
	var n := _live_guests(b)
	var cap := int(rule.cap)
	if n >= cap:
		return "LLENO"
	return "%d/%d" % [n, cap]


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
			_boost(float(feat.x), float(feat.y), 32.0, 4, 0.0, 0.0, 12.0 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.FEAT_CURER:
			_boost(float(feat.x), float(feat.y), 28.0, 3, 4.0 * dt, 16.0 * dt, 0.0, 0.0, ACT_BATH)
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


func _disk_land(x: float, y: float, mid: float, reach: float, phase: float) -> bool:
	var ang := atan2(y - mid, x - mid)
	var wobble := sin(ang * 2.0 + phase) * 20.0 + sin(ang * 5.0 + phase * 1.4) * 10.0 + sin(ang * 7.0 + 0.8) * 5.0
	return _dist_point(mid, mid, x, y) <= reach + wobble


func _ellipse(px: float, py: float, center: Vector2, axis: Vector2, rx: float, ry: float) -> float:
	var rel := Vector2(px, py) - center
	var side := Vector2(-axis.y, axis.x)
	var u := rel.dot(axis) / rx
	var v := rel.dot(side) / ry
	return u * u + v * v


func _local_mid() -> float:
	return float(Catalog.CHUNK * Catalog.TILE) * 0.5


func _open_ground(cx: int, cy: int, lx: int, ly: int) -> bool:
	if lx < 0 or ly < 0 or lx >= Catalog.CHUNK or ly >= Catalog.CHUNK:
		return false
	var tile := int(chunks[_ck(cx, cy)].tiles[ly * Catalog.CHUNK + lx])
	return tile == Catalog.TILE_GRASS or tile == Catalog.TILE_DIRT or tile == Catalog.TILE_BLOOM


func _paint_water(tiles: PackedByteArray, cx: int, cy: int) -> PackedByteArray:
	_ensure_sister_layout()
	var outward := Vector2(float(sister_cx), float(sister_cy))
	if outward.length() < 0.5:
		outward = Vector2(1, 0)
	outward = outward.normalized()
	var away := -outward
	if cx != 0 or cy != 0:
		away = outward
	var side := Vector2(-away.y, away.x)
	var mid := _local_mid()
	var origin := Vector2(float(cx * Catalog.CHUNK * Catalog.TILE), float(cy * Catalog.CHUNK * Catalog.TILE))
	var lake := Vector2(mid, mid) + side * 78.0 + away * 24.0
	var made := 0
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not _wet_cell(tiles, lx, ly, mid, origin, lake, side, lake, 64.0, 34.0, 26.0, 0.0):
				continue
			tiles[ly * Catalog.CHUNK + lx] = Catalog.TILE_WATER
			made += 1
	if made >= 10:
		return tiles
	var inland := Vector2(mid, mid) + side * 64.0
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var idx := ly * Catalog.CHUNK + lx
			var tile := int(tiles[idx])
			if tile != Catalog.TILE_GRASS and tile != Catalog.TILE_DIRT and tile != Catalog.TILE_BLOOM:
				continue
			var px := float(lx * Catalog.TILE + 8)
			var py := float(ly * Catalog.TILE + 8)
			if _dist_point(mid, mid, px, py) < 58.0:
				continue
			if _dist_point(inland.x, inland.y, px, py) > 40.0:
				continue
			var wx := origin.x + px
			var wy := origin.y + py
			if not _feature_at(wx, wy, 6.0).is_empty() or not _building_at(wx, wy, 8.0).is_empty():
				continue
			tiles[idx] = Catalog.TILE_WATER
	return tiles


func _wet_cell(tiles: PackedByteArray, lx: int, ly: int, mid: float, origin: Vector2, bay: Vector2, away: Vector2, pond: Vector2, camp: float, bay_rx: float, bay_ry: float, pond_r: float) -> bool:
	var idx := ly * Catalog.CHUNK + lx
	var tile := int(tiles[idx])
	if tile != Catalog.TILE_GRASS and tile != Catalog.TILE_DIRT and tile != Catalog.TILE_BLOOM:
		return false
	var px := float(lx * Catalog.TILE + 8)
	var py := float(ly * Catalog.TILE + 8)
	if _dist_point(mid, mid, px, py) < camp:
		return false
	var wx := origin.x + px
	var wy := origin.y + py
	if not _feature_at(wx, wy, 6.0).is_empty() or not _building_at(wx, wy, 8.0).is_empty():
		return false
	if _ellipse(px, py, bay, away, bay_rx, bay_ry) <= 1.0:
		return true
	return _dist_point(pond.x, pond.y, px, py) <= pond_r


func _pick_points(cx: int, cy: int, want: int, min_mid: float, apart: float, salt: int) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var mid := _local_mid()
	var n := 0
	while found.size() < want and n < 40:
		n += 1
		var lx := 3 + int(_rand(cx, cy, n, salt, 51) * 26.0)
		var ly := 3 + int(_rand(cx, cy, n, salt + 3, 52) * 26.0)
		var px := float(lx * Catalog.TILE + 8)
		var py := float(ly * Catalog.TILE + 8)
		if _dist_point(mid, mid, px, py) < min_mid:
			continue
		if not _open_ground(cx, cy, lx, ly):
			continue
		var spot := Vector2(px, py)
		var ok := true
		for have in found:
			if have.distance_to(spot) < apart:
				ok = false
				break
		if ok:
			found.append(spot)
	return found


func _nearest_point(px: float, py: float, points: Array[Vector2]) -> float:
	var best := 10000.0
	var at := Vector2(px, py)
	for p in points:
		best = minf(best, at.distance_to(p))
	return best


func _wants_tree(cx: int, cy: int, lx: int, ly: int) -> bool:
	var px := float(lx * Catalog.TILE + 8)
	var py := float(ly * Catalog.TILE + 8)
	if _near_island_mid(px, py):
		return false
	var near := _nearest_point(px, py, _pick_points(cx, cy, 6, SPAWN_CLEAR + 8.0, 52.0, 2))
	if near < 110.0:
		return _rand(cx, cy, lx, ly, 1) < 0.62
	if near < 140.0:
		return _rand(cx, cy, lx, ly, 1) < 0.28
	return _rand(cx, cy, lx, ly, 1) < 0.04


func _count_kind_on(cx: int, cy: int, kind: int) -> int:
	var n := 0
	for feat in features:
		if feat.dead or int(feat.cx) != cx or int(feat.cy) != cy:
			continue
		if int(feat.kind) == kind:
			n += 1
	return n


func _free_land_near(cx: int, cy: int, points: Array[Vector2], n: int) -> Vector2:
	if points.is_empty():
		return Vector2(-1, -1)
	var origin: Vector2 = points[n % points.size()]
	var ang := float(n) * 2.399
	var dist := 12.0 + float(n % 6) * 16.0
	var px := origin.x + cos(ang) * dist
	var py := origin.y + sin(ang) * dist
	if _near_island_mid(px, py):
		return Vector2(-1, -1)
	var lx := int(floor(px / float(Catalog.TILE)))
	var ly := int(floor(py / float(Catalog.TILE)))
	if not _open_ground(cx, cy, lx, ly):
		return Vector2(-1, -1)
	var wx := float(cx * Catalog.CHUNK * Catalog.TILE) + px
	var wy := float(cy * Catalog.CHUNK * Catalog.TILE) + py
	if not _feature_at(wx, wy, 10.0).is_empty():
		return Vector2(-1, -1)
	return Vector2(wx, wy)


func _top_up_island(cx: int, cy: int, groves: Array[Vector2], rocks: Array[Vector2]) -> void:
	var trees := _count_kind_on(cx, cy, Catalog.FEAT_TREE)
	var stones := _count_kind_on(cx, cy, Catalog.FEAT_ROCK) + _count_kind_on(cx, cy, Catalog.FEAT_BIGROCK)
	var guard := 0
	while trees < 48 and guard < 120:
		guard += 1
		var spot := _free_land_near(cx, cy, groves, guard)
		if spot.x < 0.0:
			continue
		if _add_feature(Catalog.FEAT_TREE, spot.x, spot.y, 1, 0, true).is_empty():
			continue
		trees += 1
	guard = 0
	while stones < 18 and guard < 80:
		guard += 1
		var rock := _free_land_near(cx, cy, rocks, guard + 3)
		if rock.x < 0.0:
			continue
		var ore := 1 if guard % 3 == 0 else 0
		if _add_feature(Catalog.FEAT_ROCK, rock.x, rock.y, 1 + ore, ore, true).is_empty():
			continue
		stones += 1


func _scatter_island(cx: int, cy: int) -> void:
	var groves := _pick_points(cx, cy, 6, SPAWN_CLEAR + 8.0, 52.0, 2)
	var rocks := _pick_points(cx, cy, 3, SPAWN_CLEAR + 12.0, 72.0, 6)
	var origin := Vector2(float(cx * Catalog.CHUNK * Catalog.TILE), float(cy * Catalog.CHUNK * Catalog.TILE))
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not _open_ground(cx, cy, lx, ly):
				continue
			var px := float(lx * Catalog.TILE + 8)
			var py := float(ly * Catalog.TILE + 8)
			var wx := origin.x + px
			var wy := origin.y + py
			if _near_island_mid(px, py):
				continue
			var grove := _nearest_point(px, py, groves)
			var rock := _nearest_point(px, py, rocks)
			if grove < 110.0 and _rand(cx, cy, lx, ly, 1) < 0.62:
				_add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif grove < 140.0 and _rand(cx, cy, lx, ly, 1) < 0.28:
				_add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif rock < 64.0 and _rand(cx, cy, lx, ly, 2) < 0.22:
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 2, 1, true)
			elif rock < 80.0 and _rand(cx, cy, lx, ly, 3) < 0.4:
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 0, true)
			elif grove > 140.0:
				_scatter_one(cx, cy, wx, wy, lx, ly)
	for rp in rocks:
		_add_feature(Catalog.FEAT_BIGROCK, origin.x + rp.x, origin.y + rp.y, 4, 1, true)
	_top_up_island(cx, cy, groves, rocks)


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
			if tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_VOID or _is_bridge_tile(tile):
				continue
			var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if _rand(cx, cy, lx, ly, 1) < float(spec.get("tree", 0.0)):
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
	return minf(200.0, 170.0 + float(land_tier) * 24.0)


func _shape_island() -> void:
	var ck := "0,0"
	if not chunks.has(ck):
		return
	var tiles = chunks[ck].tiles
	var keep := {}
	for i in slot_count:
		if state[i] != Catalog.ST_LIVING:
			continue
		_keep_cell(keep, pos_x[i], pos_y[i])
	for b in buildings:
		if not b.dead:
			_keep_cell(keep, float(b.x), float(b.y))
	var reach := _island_reach()
	var changed := false
	var fresh: Array[Vector2] = []
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var wx := float(lx * Catalog.TILE + 8)
			var wy := float(ly * Catalog.TILE + 8)
			var phase := float(absi(int(world_seed) % 628)) * 0.01
			var land := _disk_land(wx, wy, 256.0, reach, phase)
			var idx := ly * Catalog.CHUNK + lx
			var tile := int(tiles[idx])
			if tile == Catalog.TILE_BRIDGE_WOOD or tile == Catalog.TILE_BRIDGE_BONE:
				continue
			if land:
				if tile == Catalog.TILE_VOID:
					tiles[idx] = Catalog.TILE_GRASS
					fresh.append(Vector2(wx, wy))
					changed = true
			elif not keep.has("%d,%d" % [lx, ly]) and tile != Catalog.TILE_VOID:
				tiles[idx] = Catalog.TILE_VOID
				changed = true
	if not changed:
		return
	tiles = _paint_water(tiles, 0, 0)
	chunks[ck].tiles = tiles
	chunks[ck].base = tiles.duplicate()
	for feat in features:
		if feat.dead or int(feat.cx) != 0 or int(feat.cy) != 0:
			continue
		if int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		var sx := _cell_of(float(feat.x))
		var sy := _cell_of(float(feat.y))
		if sx < 0 or sy < 0 or sx >= Catalog.CHUNK or sy >= Catalog.CHUNK:
			continue
		var under := int(tiles[sy * Catalog.CHUNK + sx])
		if under == Catalog.TILE_VOID or under == Catalog.TILE_WATER:
			_kill_feature(feat)
	for spot in fresh:
		if _on_bridge(spot.x, spot.y):
			continue
		if _near_spawn(spot.x, spot.y):
			continue
		if _tile_at(spot.x, spot.y) == Catalog.TILE_WATER:
			continue
		var fx := _cell_of(spot.x)
		var fy := _cell_of(spot.y)
		if _wants_tree(0, 0, fx, fy):
			_add_feature(Catalog.FEAT_TREE, spot.x, spot.y, 1, 0, true)
		elif _rand(0, 0, fx, fy, 23) < 0.16:
			_add_feature(Catalog.FEAT_ROCK, spot.x, spot.y, 1, 0, true)
	_seed_mine_nodes(0, 0)
	_mark_dirty(ck)


func _keep_cell(keep: Dictionary, x: float, y: float) -> void:
	var lx := _cell_of(x)
	var ly := _cell_of(y)
	if lx < 0 or ly < 0 or lx >= Catalog.CHUNK or ly >= Catalog.CHUNK:
		return
	keep["%d,%d" % [lx, ly]] = true


func _near_spawn(x: float, y: float) -> bool:
	return _dist_point(256.0, 256.0, x, y) < SPAWN_CLEAR


func _near_island_mid(px: float, py: float) -> bool:
	var mid := _local_mid()
	return _dist_point(mid, mid, px, py) < SPAWN_CLEAR


func _clear_spawn() -> void:
	var doomed: Array = []
	for feat in features:
		if feat.dead:
			continue
		if _near_spawn(float(feat.x), float(feat.y)):
			doomed.append(feat)
	for feat in doomed:
		_kill_feature(feat)


func _add_feature(kind: int, x: float, y: float, hp: int, ore: int, rooted: bool = false) -> Dictionary:
	if _on_bridge(x, y):
		return {}
	if kind == Catalog.FEAT_TREE and _near_spawn(x, y):
		return {}
	if rooted and not _stands(x, y, _span_for_feature(kind)):
		return {}
	if not _is_mine_node(kind) and _near_mine_node(x, y):
		return {}
	if _feature_crowded(x, y, kind):
		return {}
	var cells := _footprint_cells(x, y, Catalog.footprint_for_feature(kind))
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
	for cell in cells:
		feature_cell[cell] = id
	return feat


func _kill_feature(feat: Dictionary) -> void:
	if feat.is_empty() or feat.dead:
		return
	feat.dead = true
	_unbind_feature(feat)
	feature_by_id.erase(int(feat.id))


func _add_item(kind: int, x: float, y: float, value: int) -> Dictionary:
	var id := next_item_id
	next_item_id += 1
	var it := {"id": id, "kind": kind, "x": x, "y": y, "value": value, "held": false, "dead": false, "fixed": false}
	if kind == Catalog.ITEM_BALL:
		it.life = BALL_LIFE
	items.append(it)
	item_by_id[id] = it
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
	return b


func _remove_building(b: Dictionary) -> void:
	_pop(float(b.x), float(b.y), Catalog.ICON_FX_POOF)
	b.dead = true
	_unbind_building(b)
	building_by_id.erase(int(b.id))
	var occ := int(b.occupant)
	if occ >= 0 and occ < claim.size():
		claim[occ] = -1


func _consume_kind(kind: int, count: int, near_x: float, near_y: float) -> bool:
	if count <= 0:
		return true
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
		return true
	var carriers: Array = []
	for i in slot_count:
		if not _carry_matches(i, kind):
			continue
		carriers.append(i)
	carriers.sort_custom(func(a, b):
		return _dist_i(int(a), near_x, near_y) < _dist_i(int(b), near_x, near_y)
	)
	for i in carriers:
		if left <= 0:
			break
		carry[int(i)] = Catalog.CARRY_NONE
		carry_value[int(i)] = 0
		left -= 1
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
		return
	if occ >= 0 and occ != i:
		return
	_release_claim(i)
	tub.occupant = i
	tub.bath_t = -1.0
	claim[i] = int(tub.id)


func _release_claim(i: int) -> void:
	if i < 0 or i >= claim.size():
		return
	var bid := claim[i]
	claim[i] = -1
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


func _nearest_tub(i: int) -> Dictionary:
	var best := {}
	var best_d := 999999.0
	for b in buildings:
		if b.dead or int(b.kind) != Catalog.BLD_TUB:
			continue
		var occ := int(b.occupant)
		if occ >= 0 and occ != i:
			continue
		var d := _dist_i(i, float(b.x), float(b.y))
		if d < best_d and d < 280.0:
			best_d = d
			best = b
	return best


func _nearest_building_kinds(x: float, y: float, kinds: Array, max_dist: float, who: int = -1) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for b in buildings:
		if b.dead or not kinds.has(int(b.kind)):
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
	for it in items:
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


func _nearest_open_bridge(x: float, y: float, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for bridge in bridges:
		if bool(bridge.done):
			continue
		var d := _dist_point(x, y, float(bridge.x), float(bridge.y))
		if d < best_d:
			best_d = d
			best = bridge
	return best


func _primary_open_bridge() -> Dictionary:
	return _nearest_open_bridge(256.0, 256.0, 99999.0)


func _bridge_drop_point(bridge: Dictionary) -> Vector2:
	if str(bridge.get("ck", "")) == "2,0":
		var home := _home_bridge_drop()
		if not _blocked(home.x, home.y):
			return home
	if bridge.has("drop_x") and bridge.has("drop_y"):
		var dx := float(bridge.drop_x)
		var dy := float(bridge.drop_y)
		if not _blocked(dx, dy):
			return Vector2(dx, dy)
	return _find_bridge_drop(float(bridge.x), float(bridge.y))


func _home_bridge_drop() -> Vector2:
	var sister := _sister_chunk()
	var target := _chunk_center(sister.x, sister.y)
	return _nearest_island_shore(0, 0, target)


func _find_bridge_drop(cx: float, cy: float) -> Vector2:
	var offsets: Array[Vector2] = [
		Vector2(-56, 0), Vector2(56, 0), Vector2(0, -56), Vector2(0, 56),
		Vector2(-72, 0), Vector2(72, 0), Vector2(0, -72), Vector2(0, 72),
		Vector2(-56, -24), Vector2(-56, 24), Vector2(56, -24), Vector2(56, 24),
	]
	for off in offsets:
		var px := cx + off.x
		var py := cy + off.y
		if revealed.has(_ck_of(px, py)) and not _blocked(px, py):
			return Vector2(px, py)
	for off in offsets:
		var px2 := cx + off.x
		var py2 := cy + off.y
		if not _blocked(px2, py2):
			return Vector2(px2, py2)
	return Vector2(cx - 56.0, cy)


func bridge_marker() -> Dictionary:
	var bridge := _primary_open_bridge()
	if bridge.is_empty():
		return {}
	return {
		"x": float(bridge.x),
		"y": float(bridge.y),
		"drop_x": float(bridge.get("drop_x", bridge.x)),
		"drop_y": float(bridge.get("drop_y", bridge.y)),
		"progress": int(bridge.progress),
		"need": int(bridge.need),
		"ck": str(bridge.ck),
	}


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


func _workers_near(b: Dictionary, cap: int) -> int:
	var ids := query_radius(float(b.x), float(b.y), 36.0)
	var n := 0
	for id in ids:
		if state[int(id)] != Catalog.ST_LIVING:
			continue
		var need := 50.0
		if bool(mutations.get("hard", false)):
			need = 32.0
		elif bool(mutations.get("care", false)):
			need = 65.0
		if fed[int(id)] < need or amused[int(id)] < need or clean[int(id)] < need:
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


func _has_factory() -> bool:
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			return true
	return false


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


func _blocked(px: float, py: float, allow_ore: bool = false) -> bool:
	var tile := _tile_at(px, py)
	if Catalog.tile_blocks(tile):
		return true
	var cell := _cell_vec(px, py)
	if feature_cell.has(cell):
		var feat = feature_by_id.get(int(feature_cell[cell]), {})
		if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
			if allow_ore and _ore_tier(int(feat.kind)) > 0:
				return false
			return true
	if building_cell.has(cell):
		var b = building_by_id.get(int(building_cell[cell]), {})
		if not b.is_empty() and not b.dead and Catalog.building_blocks(int(b.kind)):
			return true
	return false


func _approach_spot(x: float, y: float, radius: float, who: int = -1) -> Vector2:
	var best := Vector2(x, y)
	var best_d := 1.0e9
	var from := Vector2(x, y)
	if who >= 0 and who < slot_count:
		from = Vector2(pos_x[who], pos_y[who])
	for n in 12:
		var ang := float(n) * (TAU / 12.0)
		var px := x + cos(ang) * radius
		var py := y + sin(ang) * radius
		if _blocked(px, py):
			continue
		var d := from.distance_squared_to(Vector2(px, py))
		if d < best_d:
			best_d = d
			best = Vector2(px, py)
	if best_d < 1.0e9:
		return best
	for grow in 2:
		var ring := radius + 8.0 * float(grow + 1)
		for n in 12:
			var ang := float(n) * (TAU / 12.0)
			var px := x + cos(ang) * ring
			var py := y + sin(ang) * ring
			if _blocked(px, py):
				continue
			return Vector2(px, py)
	return best


func _is_bridge_tile(tile: int) -> bool:
	return tile == Catalog.TILE_BRIDGE_WOOD or tile == Catalog.TILE_BRIDGE_BONE


func _on_bridge(px: float, py: float) -> bool:
	return _is_bridge_tile(_tile_at(px, py))


func _tile_at(px: float, py: float) -> int:
	var c := _chunk_at(px, py)
	var ck := _ck(c.x, c.y)
	if not revealed.has(ck):
		return Catalog.TILE_FOG
	_ensure(c.x, c.y)
	var local := _local_cell(px, py)
	return int(chunks[ck].tiles[local.y * Catalog.CHUNK + local.x])


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
	chunks[ck].tiles[idx] = tile
	if also_base:
		chunks[ck].base[idx] = tile
	_mark_dirty(ck)


func _rebuild_hash() -> void:
	for b in Catalog.HASH_SIZE:
		hash_head[b] = -1
	for i in slot_count:
		if state[i] == Catalog.ST_VACANT:
			hash_next[i] = -1
			continue
		var bucket := _bucket(pos_x[i], pos_y[i])
		hash_next[i] = hash_head[bucket]
		hash_head[bucket] = i


func _feature_movable(feat: Dictionary) -> bool:
	if feat.is_empty() or feat.dead or bool(feat.get("rooted", false)):
		return false
	# Terrain trees stay planted. Only loose rocks can be carried.
	return int(feat.kind) == Catalog.FEAT_ROCK


func _anchor_terrain_feature(feat: Dictionary) -> void:
	var kind := int(feat.kind)
	if kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		feat.rooted = true


func _reindex() -> void:
	feature_by_id.clear()
	feature_cell.clear()
	item_by_id.clear()
	building_by_id.clear()
	building_cell.clear()
	next_feature_id = 1
	next_item_id = 1
	next_building_id = 1
	for feat in features:
		if feat.dead:
			continue
		_anchor_terrain_feature(feat)
		feature_by_id[int(feat.id)] = feat
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
	hash_next = PackedInt32Array()
	hash_next.resize(slot_count)
	hash_next.fill(-1)


func _recount() -> void:
	living = 0
	for i in slot_count:
		if state[i] == Catalog.ST_LIVING:
			living += 1
	peak = maxi(peak, living)


func _compact(list: Array) -> void:
	var w := 0
	for i in list.size():
		if not bool(list[i].get("dead", false)):
			list[w] = list[i]
			w += 1
	list.resize(w)


func _init_unlocks() -> void:
	unlocks = {
		"eye": true,
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
	var file := FileAccess.open("res://biomes.json", FileAccess.READ)
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


func _open_special_biomes() -> void:
	if not world_open():
		return
	_ensure_sister_layout()
	var taken := {"0,0": true, _ck(sister_cx, sister_cy): true}
	var want: Array[String] = []
	if land_tier >= 4:
		want.append("mountain")
	if land_tier >= 5:
		want.append("glitch")
	if land_tier >= 6:
		want.append("anomaly")
	if land_tier >= 7:
		want.append("epilogue")
	var dirs: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(3, -3),
	]
	var cursor := 0
	for biome in want:
		var placed := false
		while cursor < dirs.size() and not placed:
			var spot: Vector2i = dirs[cursor]
			cursor += 1
			var key := _ck(spot.x, spot.y)
			if taken.has(key):
				continue
			taken[key] = true
			if str(special_biomes.get(key, "")) == biome and chunks.has(key):
				placed = true
				continue
			special_biomes[key] = biome
			if chunks.has(key):
				chunks.erase(key)
			_reveal(spot.x, spot.y)
			_ensure(spot.x, spot.y)
			placed = true


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


func _prep_shot_world() -> void:
	_clear_shot_props()
	var taken := {}
	var missed: Array = []
	var buildings_to_place := [
		Catalog.BLD_MARKET, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_FACTORY2, Catalog.BLD_THEATRE,
		Catalog.BLD_FACTORY, Catalog.BLD_DWELL, Catalog.BLD_FANCY, Catalog.BLD_APPLE, Catalog.BLD_TUB,
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
	shot_focus = Vector2(256, 256)
	shot_span = _island_reach() + 48.0
	view_rect = Rect2(shot_focus.x - shot_span, shot_focus.y - shot_span, shot_span * 2.0, shot_span * 2.0)
	notes.clear()
	sfx_queue.clear()
	pops.clear()
	barks.clear()
	modal = {}
	frozen = false
	_rebuild_hash()
	smoke_hold = true
	print("SHOT READY buildings=%s features=%s items=%s missed=%s" % [buildings.size(), features.size(), items.size(), missed])


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


func _run_checks() -> void:
	var errors: Array = []
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
			choose(0)
		if bool(mutations.get("care", false)) != true:
			errors.append("care mutation missing")
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
	if world_open():
		errors.append("world open before roundabout")
	_ensure_sister_layout()
	var sister := _sister_chunk()
	if maxi(absi(sister.x), absi(sister.y)) != 1:
		errors.append("sister not adjacent")
	_reveal(sister.x, sister.y)
	if str(chunks[_ck(sister.x, sister.y)].biome) != "grove":
		errors.append("sister biome " + str(chunks[_ck(sister.x, sister.y)].biome))
	var sister_land := 0
	for t in chunks[_ck(sister.x, sister.y)].tiles:
		if int(t) != Catalog.TILE_VOID and int(t) != Catalog.TILE_WATER:
			sister_land += 1
	if sister_land < 120:
		errors.append("sister not island shaped")
	if _count_mine_nodes(0, 0) < 1:
		errors.append("home mine nodes missing")
	if _count_mine_nodes(sister.x, sister.y) < 1:
		errors.append("sister mine nodes missing")
	if not bool(unlocks.axe):
		errors.append("axe locked")
	bridge_open = true
	_ensure_bridge_site()
	if not modal.is_empty() and str(modal.get("event", "")) == "need_bridge":
		choose(0)
	if _primary_open_bridge().is_empty():
		errors.append("bridge missing")
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
	var open_bridge := _primary_open_bridge()
	if open_bridge.is_empty():
		errors.append("open bridge gone")
	else:
		open_bridge.progress = int(open_bridge.need)
		_finish_bridge(open_bridge)
	var plank := 0
	var home := _home_bridge_drop()
	var far := _nearest_island_shore(sister.x, sister.y, home)
	if home.distance_to(far) > 360.0:
		errors.append("bridge too long")
	for ck in chunks.keys():
		for t in chunks[ck].tiles:
			if int(t) == Catalog.TILE_BRIDGE_WOOD or int(t) == Catalog.TILE_BRIDGE_BONE:
				plank += 1
	if plank < 4:
		errors.append("wood bridge missing")
	if not _bridge_path_solid(home, far):
		errors.append("bridge gaps")
	_shape_island()
	if not _bridge_path_solid(home, far):
		errors.append("bridge wiped by reshape")
	var mid := home.lerp(far, 0.5)
	if not _on_bridge(mid.x, mid.y):
		errors.append("bridge mid missing")
	elif can_place_building(Catalog.BLD_TUB, mid.x, mid.y):
		errors.append("build on bridge allowed")
	if not _add_feature(Catalog.FEAT_ROCK, mid.x, mid.y, 1, 0, true).is_empty():
		errors.append("rock on bridge")
	if not bool(bridge_done.get(_ck(sister.x, sister.y), false)):
		errors.append("bridge not marked done")
	if not bool(unlocks.get("market", false)):
		errors.append("market unlock after bridge")
	if not bool(unlocks.get("mine", false)):
		errors.append("mine unlock after bridge")
	while not modal.is_empty():
		choose(0)
	var ore_node := {}
	for feat in features:
		if not feat.dead and int(feat.cx) == 0 and _ore_tier(int(feat.kind)) > 0:
			ore_node = feat
			break
	if ore_node.is_empty():
		errors.append("no ore node for mine")
	else:
		_add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 48.0, float(ore_node.y), 1)
		_add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 64.0, float(ore_node.y), 1)
		if not can_place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine blocked on ore node")
		elif not place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine place on ore node")
		elif _count_mine_nodes(0, 0) < 1:
			errors.append("mine ate every ore node")
	var market_at := Vector2(256.0, 200.0)
	for spot in [Vector2(256.0, 200.0), Vector2(220.0, 220.0), Vector2(280.0, 220.0), Vector2(256.0, 300.0)]:
		if can_place_building(Catalog.BLD_MARKET, spot.x, spot.y):
			market_at = spot
			break
	if not place_building(Catalog.BLD_MARKET, market_at.x, market_at.y):
		errors.append("market place free")
	elif place_building(Catalog.BLD_MARKET, market_at.x + 40.0, market_at.y):
		errors.append("market unique broken")
	var tub_spot := Vector2(200.0, 280.0)
	for spot in [Vector2(200.0, 280.0), Vector2(180.0, 260.0), Vector2(220.0, 300.0)]:
		if can_place_building(Catalog.BLD_TUB, spot.x, spot.y):
			tub_spot = spot
			break
	if place_building(Catalog.BLD_TUB, tub_spot.x, tub_spot.y):
		if not _blocked(tub_spot.x, tub_spot.y):
			errors.append("tub not solid")
		var rim := _approach_spot(tub_spot.x, tub_spot.y, 18.0)
		if _blocked(rim.x, rim.y):
			errors.append("tub approach blocked")
	else:
		errors.append("tub place for solid")
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
	var round_b := {}
	for spot in [Vector2(300.0, 300.0), Vector2(140.0, 200.0), Vector2(360.0, 180.0), Vector2(160.0, 320.0)]:
		var at := Catalog.snap_world(spot.x, spot.y)
		if _building_spot_free(-1, at.x, at.y, Catalog.BLD_ROUND):
			round_b = _add_building(Catalog.BLD_ROUND, at.x, at.y)
			if not round_b.is_empty():
				break
	if round_b.is_empty():
		errors.append("roundabout place")
	elif state[0] == Catalog.ST_LIVING:
		var back := Vector2(pos_x[0], pos_y[0])
		var gate := _approach_spot(float(round_b.x), float(round_b.y), 36.0, 0)
		pos_x[0] = gate.x
		pos_y[0] = gate.y
		amused[0] = 40.0
		_do_roundabout_ride(0, round_b, 0.2)
		if _blocked(pos_x[0], pos_y[0]):
			errors.append("roundabout ride blocked")
		if _ride_building(0).is_empty():
			errors.append("roundabout lost rider")
		amused[0] = Catalog.NEED_OK
		_leave_ride(0, round_b)
		if not _ride_building(0).is_empty():
			errors.append("roundabout kept rider")
		if _blocked(pos_x[0], pos_y[0]):
			errors.append("roundabout left them blocked")
		if _dist_i(0, float(round_b.x), float(round_b.y)) < 48.0:
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
		for i in slot_count:
			if carry[i] == Catalog.CARRY_WOOD:
				carry[i] = Catalog.CARRY_NONE
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
		errors.append("tub missing for lift")
	else:
		held_kind = "building"
		held_ref = int(tub_b.id)
		held_x = float(tub_b.x)
		held_y = float(tub_b.y)
		_lift_building(tub_b)
		if int(building_cell.get(_cell_vec(held_x, held_y), -1)) == int(tub_b.id):
			errors.append("lifted tub still bound")
		release_at(held_x, held_y, true, false)
		if bool(tub_b.get("lifted", false)):
			errors.append("tub stayed lifted")
		if int(building_cell.get(_cell_vec(float(tub_b.x), float(tub_b.y)), -1)) != int(tub_b.id):
			errors.append("tub did not sit back")
	var forest := {}
	for feat in features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE:
			forest = feat
			break
	if not forest.is_empty() and not _blocked(float(forest.x), float(forest.y)):
		errors.append("tree not solid")
	_rebuild_hash()
	if find_thronglet(pos_x[0], pos_y[0], 8.0, true) != 0:
		errors.append("hash miss")
	if living >= 1 and state[0] == Catalog.ST_LIVING:
		var cove := _cell_vec(240.0, 240.0)
		for oy in range(-4, 5):
			for ox in range(-4, 5):
				var cx := cove.x + ox
				var cy := cove.y + oy
				var key := Vector2i(cx, cy)
				if feature_cell.has(key):
					var fid := int(feature_cell[key])
					var feat = feature_by_id.get(fid, {})
					if not feat.is_empty():
						feat.dead = true
					feature_cell.erase(key)
				# Grass pocket west/north; water blocks east/south like a cove.
				var water := ox >= 1 or oy >= 1
				_set_world_cell(cx, cy, Catalog.TILE_WATER if water else Catalog.TILE_GRASS, true)
		pos_x[0] = float(cove.x) * Catalog.TILE + Catalog.TILE * 0.5
		pos_y[0] = float(cove.y) * Catalog.TILE + Catalog.TILE * 0.5
		dir_x[0] = 1.0
		dir_y[0] = 1.0
		var start := Vector2(pos_x[0], pos_y[0])
		for _n in 120:
			_walk(0, start.x + 96.0, start.y + 96.0, MOVE_SPEED, 0.08)
		if _dist_point(pos_x[0], pos_y[0], start.x, start.y) < 28.0:
			errors.append("stuck in water corner")
		if _tile_at(pos_x[0], pos_y[0]) == Catalog.TILE_WATER:
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
		choose(0)
	if frozen:
		errors.append("frozen after choice")
	var live_now := living
	var gems_now := gems
	if not save_game():
		errors.append("save failed")
	gems = 999
	if not load_game():
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
	print("SMOKE " + ("OK" if errors.is_empty() else "FAIL"))
	for err in errors:
		print(" - " + str(err))
	get_tree().quit(0 if errors.is_empty() else 1)
