extends Node

# Colony simulation.
# The bug defleshes a body into bone. The axe leaves a stump. The hammer removes it.
# Mitosis requires food, fun and clean together. The last death ends the run.

const DECAY_FED := 0.12
const DECAY_FUN := 0.07
const DECAY_CLEAN := 0.08
const MOVE_SPEED := 26.0
const MITOSIS_CHARGE := 6.0
const STARVE_GRACE := 30.0
const EGG_NEED := 4
const EGG_FALL := 140.0
const BALL_LIFE := 180.0

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
var gaze_queue: Array = []
var frozen := false
var moral := 0
var mutations := {}

var part_two := false
var mountain_seen := false
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
const BARKS := ["BIEN", "HOLA", "JUEGO"]
const WEAR_NEED := 10
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
var next_building_id := 1

var slot_count := 0
var cursor := 0
var mood_face := "base"
var _mood_base := 0
var _mood_happy := 0
var _mood_cry := 0
var _mood_sus := 0
var _mood_freak := 0
var _mood_trance := 0
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
	testing = OS.get_cmdline_user_args().has("--smoke")
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
	await get_tree().process_frame
	_run_checks()


func _step(delta: float) -> void:
	frame_i += 1
	if frame_i > 1000000:
		frame_i = 1
	if sponge_hold > 0.0:
		sponge_hold = maxf(0.0, sponge_hold - delta)
		if sponge_hold <= 0.0:
			sponge_id = -1
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
	elif fed_v >= 90.0 and fun_v >= 90.0 and clean_v >= 90.0:
		_mood_trance += 1
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
		["trance", _mood_trance],
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
	_mood_trance = 0


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
	var visit := _guest_building(i)
	if not visit.is_empty():
		if _is_show(int(visit.kind)) and fed[i] < Catalog.NEED_HUNGRY:
			_drop_guest(visit, i)
		else:
			var speed_in := MOVE_SPEED
			if _dist_i(i, float(visit.x), float(visit.y)) > 8.0:
				_walk(i, float(visit.x), float(visit.y), speed_in, dt)
			else:
				act[i] = ACT_PLAY if _is_show(int(visit.kind)) else ACT_BATH
				act_t[i] = 0.4
			return
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
	if fed[i] < Catalog.NEED_HUNGRY:
		_release_claim(i)
		if _seek_food(i, speed, dt):
			return
		_release_apple_claim(i)
	else:
		_release_apple_claim(i)
	var bridge_job := not part_two and not _primary_open_bridge().is_empty()
	if bridge_job and _try_haul(i, speed, dt):
		return
	if clean[i] < Catalog.NEED_SEEK:
		if _seek_clean(i, speed, dt):
			_release_item_claims(i)
			return
	else:
		_release_claim(i)
	if amused[i] < Catalog.NEED_FUN and _seek_fun(i, speed, dt):
		return
	var cared := fed[i] >= 70.0 and amused[i] >= 70.0 and clean[i] >= 70.0
	if cared and _try_haul(i, speed, dt):
		return
	if cared and _seek_mine(i, speed, dt):
		_release_item_claims(i)
		return
	_release_item_claims(i)
	_wander(i, speed, dt)


func _start_mitosis(i: int) -> void:
	if slot_count >= Catalog.MAX_SLOTS:
		if not cap_told:
			cap_told = true
			notes.append("LA COLONIA NO CABE MAS.")
		cool[i] = Catalog.MITOSIS_WAIT
		return
	cool[i] = Catalog.MITOSIS_WAIT
	mito_charge[i] = 0.0
	mito_t[i] = 0.45
	var ang := randf() * TAU
	var x := pos_x[i] + cos(ang) * 10.0
	var y := pos_y[i] + sin(ang) * 10.0
	if _blocked(x, y):
		x = pos_x[i]
		y = pos_y[i]
	_push_slot(x, y, 70.0, 70.0, 70.0, Catalog.MITOSIS_WAIT, int(tint[i]))
	sfx_queue.append("mitosis")


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
	if best < 12.0 and use_tub:
		act[i] = ACT_BATH
		act_t[i] = 0.45
		clean[i] = minf(100.0, clean[i] + 38.0 * dt)
		shake_t[i] = maxf(shake_t[i], 0.2)
		if clean[i] >= 98.0:
			_release_claim(i)
		return true
	if best < 18.0 and not use_tub:
		_enter_visit(i, target)
		act[i] = ACT_BATH
		act_t[i] = 0.4
		return true
	_walk(i, float(target.x), float(target.y), speed, dt)
	return true


func _seek_fun(i: int, speed: float, dt: float) -> bool:
	var ball := _nearest_ball(i, 260.0)
	var play := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_ROUND, Catalog.BLD_THEATRE, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD], 320.0, i)
	var tx := 0.0
	var ty := 0.0
	var best := 999999.0
	var radius := 16.0
	var use_ball := false
	var play_kind := -1
	if not ball.is_empty():
		best = _dist_i(i, float(ball.x), float(ball.y))
		tx = float(ball.x)
		ty = float(ball.y)
		radius = 16.0
		use_ball = true
	if not play.is_empty():
		var d2 := _dist_i(i, float(play.x), float(play.y))
		if d2 < best:
			best = d2
			tx = float(play.x)
			ty = float(play.y)
			play_kind = int(play.kind)
			if play_kind == Catalog.BLD_ROUND:
				radius = 30.0
			elif _is_show(play_kind):
				radius = 52.0
			else:
				radius = 22.0
			use_ball = false
	if best > 900000.0:
		return false
	if use_ball:
		_claim_ball(i, ball)
	else:
		_release_item_claims(i)
	if best < radius:
		var was_play := int(act[i]) == ACT_PLAY
		act[i] = ACT_PLAY
		act_t[i] = 0.55
		if use_ball and int(ball.get("claimer", -1)) == i:
			if float(ball.get("rest", 0.0)) <= 0.0:
				var kx := float(ball.x) - pos_x[i]
				var ky := float(ball.y) - pos_y[i]
				var kl := sqrt(kx * kx + ky * ky)
				if kl < 1.0:
					var ang := randf() * TAU
					kx = cos(ang)
					ky = sin(ang)
					kl = 1.0
				ball.vx = kx / kl * 96.0
				ball.vy = ky / kl * 78.0
				ball.rest = 0.7
				ball.life = BALL_LIFE
				amused[i] = minf(100.0, amused[i] + 14.0)
				shake_t[i] = maxf(shake_t[i], 0.35)
				_pop(pos_x[i], pos_y[i] - 6.0, Catalog.ICON_BALL)
				sfx_queue.append("ball")
			else:
				_walk(i, tx, ty, speed * 1.15, dt)
			return true
		if play_kind == Catalog.BLD_ROUND:
			if not was_play:
				sfx_queue.append("round_start")
			var ang := atan2(pos_y[i] - ty, pos_x[i] - tx) + 2.8 * dt
			var orbit_r := 12.0
			var nx := tx + cos(ang) * orbit_r
			var ny := ty + sin(ang) * orbit_r
			if not _blocked(nx, ny):
				dir_x[i] = cos(ang + PI * 0.5)
				dir_y[i] = sin(ang + PI * 0.5)
				pos_x[i] = nx
				pos_y[i] = ny
			amused[i] = minf(100.0, amused[i] + 26.0 * dt)
			shake_t[i] = maxf(shake_t[i], 0.15)
			return true
		if _is_show(play_kind):
			if best < 26.0:
				_enter_visit(i, play)
				act[i] = ACT_PLAY
				act_t[i] = 0.4
			else:
				_walk(i, tx, ty, speed, dt)
			return true
		amused[i] = minf(100.0, amused[i] + 18.0 * dt)
		return true
	_walk(i, tx, ty, speed, dt)
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
	var ang := float(i % 8) / 8.0 * TAU
	var tx := float(mine.x) + cos(ang) * 18.0
	var ty := float(mine.y) + sin(ang) * 18.0
	if _blocked(tx, ty):
		tx = float(mine.x)
		ty = float(mine.y) + 18.0
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
	if randf() < 0.38:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		wander_t[i] = randf_range(0.9, 2.8)
		return
	var open := _open_dir(i, _inland_dir(i))
	if open == Vector2.ZERO:
		dir_x[i] = 0.0
		dir_y[i] = 0.0
		wander_t[i] = randf_range(0.4, 1.0)
		return
	dir_x[i] = open.x
	dir_y[i] = open.y
	wander_t[i] = randf_range(0.6, 2.0)


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


func _open_dir(i: int, prefer: Vector2) -> Vector2:
	var base := prefer
	if base.length_squared() < 0.01:
		base = Vector2(1.0, 0.0)
	else:
		base = base.normalized()
	for n in 12:
		var ang := float(n) * (TAU / 12.0) + randf() * 0.2
		var d := base.rotated(ang if n > 0 else randf_range(-0.4, 0.4))
		if n == 0:
			d = base.rotated(randf_range(-0.5, 0.5))
		if not _blocked(pos_x[i] + d.x * 14.0, pos_y[i] + d.y * 14.0):
			if not _blocked(pos_x[i] + d.x * 6.0, pos_y[i] + d.y * 6.0):
				return d
	return Vector2.ZERO


func _walk(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	var dx := tx - pos_x[i]
	var dy := ty - pos_y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		return
	dir_x[i] = dx / dist
	dir_y[i] = dy / dist
	if _blocked(pos_x[i] + dir_x[i] * 10.0, pos_y[i] + dir_y[i] * 10.0):
		var detour := _open_dir(i, Vector2(dir_x[i], dir_y[i]))
		if detour != Vector2.ZERO:
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
	if n < 2:
		return 0
	return mini(WEAR_STEPS, n / 2)


func _maybe_bark(i: int) -> void:
	if barks.size() >= 3:
		return
	if view_rect.size != Vector2.ZERO and not view_rect.has_point(Vector2(pos_x[i], pos_y[i])):
		return
	for bark in barks:
		if int(bark.id) == i:
			return
	var near_fire := false
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
			continue
		if _dist_i(i, float(feat.x), float(feat.y)) < 48.0:
			near_fire = true
			break
	if near_fire:
		if randf() > 0.02:
			return
		barks.append({
			"id": i,
			"text": "",
			"icon": Catalog.ICON_FIRE,
			"t": 1.6,
			"x": pos_x[i],
			"y": pos_y[i],
		})
		return
	if fed[i] < 70.0 or amused[i] < 70.0 or clean[i] < 70.0:
		return
	if randf() > 0.004:
		return
	barks.append({
		"id": i,
		"text": BARKS[randi() % BARKS.size()],
		"t": 2.0,
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
	var best := {}
	var best_d := 16.0
	for b in buildings:
		if b.dead or int(b.kind) != Catalog.BLD_ROUND:
			continue
		var d := Vector2(pos_x[i] - float(b.x), pos_y[i] - float(b.y)).length()
		if d < best_d:
			best_d = d
			best = b
	return best


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


func _tick_apple_tree(b: Dictionary, dt: float) -> void:
	var fruits: Array = b.get("fruits", [])
	b.fruits = fruits
	var growing := false
	for fruit in fruits:
		if float(fruit.s) < 1.0:
			fruit.s = minf(1.0, float(fruit.s) + dt * 0.4)
			growing = true
			break
	if not growing and fruits.size() < 3:
		var used := {}
		for fruit in fruits:
			used[int(fruit.slot)] = true
		var slot := 0
		while used.has(slot) and slot < 3:
			slot += 1
		if slot < 3:
			fruits.append({"slot": slot, "s": 0.2})
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
	b.timer = 5.0
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
	var slot := clampi(int(fruit.slot), 0, 2)
	fruits.remove_at(ripe)
	var ox: float = [-10.0, 10.0, 0.0][slot]
	var oy: float = [4.0, 6.0, 2.0][slot]
	var lift: float = [34.0, 30.0, 40.0][slot]
	var dropped := _add_item(Catalog.ITEM_APPLE, float(b.x) + ox, float(b.y) + oy, 1)
	dropped.air = lift
	dropped.fall = 30.0
	dropped.vx = ox * 2.2
	b.active = true


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
		radius = 44.0
	else:
		return false
	return _count_living_near(float(b.x), float(b.y), radius) >= limit


func _corner_trap(i: int) -> bool:
	var open := 0
	for n in 4:
		var a := float(n) * TAU * 0.25
		if not _blocked(pos_x[i] + cos(a) * 8.0, pos_y[i] + sin(a) * 8.0):
			open += 1
	return open <= 1


func _unstick(i: int) -> void:
	var prefer := _inland_dir(i)
	if absf(dir_x[i]) + absf(dir_y[i]) > 0.2:
		prefer = Vector2(dir_x[i], dir_y[i]).normalized()
	var step := _open_dir(i, prefer)
	if step == Vector2.ZERO:
		step = _open_dir(i, _inland_dir(i))
	if step == Vector2.ZERO:
		step = _inland_dir(i)
	var try_dist: Array[float] = [6.0, 4.0, 3.0, 2.0]
	for dist in try_dist:
		var nx: float = pos_x[i] + step.x * dist
		var ny: float = pos_y[i] + step.y * dist
		if not _blocked(nx, ny):
			pos_x[i] = nx
			pos_y[i] = ny
			dir_x[i] = step.x
			dir_y[i] = step.y
			wander_t[i] = randf_range(0.3, 0.8)
			return
	wander_t[i] = 0.0


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
			var fall := float(it.get("fall", 30.0)) + 240.0 * dt
			it.fall = fall
			var air := maxf(0.0, float(it.air) - fall * dt)
			it.air = air
			var nx := float(it.x) + float(it.get("vx", 0.0)) * dt
			if not _blocked(nx, float(it.y)):
				it.x = nx
			if air <= 0.0:
				it.air = 0.0
				it.vx = 0.0
				it.fall = 0.0
			continue
		if int(it.kind) != Catalog.ITEM_BALL:
			continue
		it.rest = maxf(0.0, float(it.get("rest", 0.0)) - dt)
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


func _tick_buildings(dt: float) -> void:
	for b in buildings:
		if b.dead:
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
					_add_item(Catalog.ITEM_ORE, float(b.x), float(b.y) + 14.0, _mine_value(b))
					_pop(float(b.x), float(b.y) - 2.0, Catalog.ICON_ORE)
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
			if occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING and _dist_i(occ, float(b.x), float(b.y)) < 16.0:
				b.active = true
		elif kind == Catalog.BLD_ROUND:
			if _count_living_near(float(b.x), float(b.y), 40.0) > 0:
				b.active = true
		elif kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
			_tick_visit(b, dt)


func _tick_auras(dt: float) -> void:
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_ROUND:
			_boost(float(b.x), float(b.y), 44.0, 6, 0.0, 0.0, 22.0 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.BLD_FLOWER:
			_boost(float(b.x), float(b.y), 28.0, 3, 0.0, 0.0, 10.0 * dt, 0.0, ACT_PLAY)
		elif kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
			_boost(float(b.x), float(b.y), 36.0, 4, 0.0, 0.0, 14.0 * dt, 0.8, ACT_PLAY)
		elif kind == Catalog.BLD_TUB:
			var occ := int(b.occupant)
			if occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING and _dist_i(occ, float(b.x), float(b.y)) < 16.0:
				clean[occ] = minf(100.0, clean[occ] + 30.0 * dt)
				act[occ] = ACT_BATH
				act_t[occ] = maxf(act_t[occ], 0.3)
				if clean[occ] >= 98.0:
					_release_claim(occ)


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
	if not _can_drop(at.x, at.y) or not _item_spot_free(at.x, at.y):
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
	var feat := _feature_at(x, y, 14.0)
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
		var tree := _feature_at(x, y, 14.0)
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
			notes.append("LA BANERA LIMPIA A QUIEN SE METE.")
		Catalog.BLD_ROUND:
			notes.append("EL TIOVIVO SUBE LA DIVERSION. LOS MULTIS GIRAN ALREDEDOR.")
		Catalog.BLD_DWELL:
			notes.append("VIVIENDA. CUPO 4. COMEN, SE LAVAN Y SALEN.")
		Catalog.BLD_FANCY:
			notes.append("VIVIENDA DE LUJO. CABEN MAS Y SE LAVAN MAS.")
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


func grab_at(x: float, y: float) -> bool:
	if frozen or is_holding():
		return false
	var id := find_thronglet(x, y, 14.0, true)
	if id >= 0:
		held_kind = "thronglet"
		held_ref = id
		held_x = pos_x[id]
		held_y = pos_y[id]
		return true
	var feat := _feature_at(x, y, 14.0)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_ROCK:
		if bool(feat.get("rooted", false)):
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
		b.lifted = true
		var occ := int(b.occupant)
		if occ >= 0 and occ < claim.size():
			claim[occ] = -1
		b.occupant = -1
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
			if _can_drop(px, py) and _building_spot_free(id, px, py) and _stands(px, py, Vector2(16.0, 52.0)):
				b.x = px
				b.y = py
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


func _can_drop(x: float, y: float) -> bool:
	return revealed.has(_ck_of(x, y)) and not _blocked(x, y) and not _on_bridge(x, y)


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


func _building_spot_free(id: int, x: float, y: float) -> bool:
	var other := _building_at(x, y, 14.0)
	return other.is_empty() or int(other.id) == id


func _unbind_feature(feat: Dictionary) -> void:
	var cell := _cell_vec(float(feat.x), float(feat.y))
	if int(feature_cell.get(cell, -1)) == int(feat.id):
		feature_cell.erase(cell)


func _bind_feature_at(feat: Dictionary, x: float, y: float) -> bool:
	var cell := _cell_vec(x, y)
	if feature_cell.has(cell) and int(feature_cell[cell]) != int(feat.id):
		return false
	feat.x = x
	feat.y = y
	var c := _chunk_at(x, y)
	feat.cx = c.x
	feat.cy = c.y
	feature_cell[cell] = int(feat.id)
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
	if not _can_drop(at.x, at.y) or not _stands(at.x, at.y, Vector2(16.0, 52.0)):
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sfx_queue.append("error")
		return false
	if not _building_at(at.x, at.y, 14.0).is_empty() or not _item_spot_free(at.x, at.y):
		notes.append("YA HAY ALGO AHI.")
		return false
	if kind == Catalog.BLD_MARKET and _has_building(Catalog.BLD_MARKET):
		notes.append("SOLO PUEDE HABER UN MERCADO.")
		return false
	var node := 0
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		var feat := _feature_at(at.x, at.y, 12.0)
		if feat.is_empty() or _ore_tier(int(feat.kind)) == 0:
			notes.append("LA MINA SOLO VA SOBRE UN NODO.")
			return false
		node = _ore_tier(int(feat.kind))
		_kill_feature(feat)
	if not _consume_kind(Catalog.ITEM_WOOD, int(info.wood), at.x, at.y):
		notes.append("FALTA MADERA.")
		return false
	var b := _add_building(kind, at.x, at.y)
	b.node = node
	sfx_queue.append(_place_sfx(kind))
	_pop(at.x, at.y, int(info.icon))
	_refresh_pop_gates()
	return true


func spot_ok(x: float, y: float, building_id: int = -1, ignore_item_id: int = -1) -> bool:
	var at := Catalog.snap_world(x, y)
	if not _can_drop(at.x, at.y):
		return false
	if not _item_spot_free(at.x, at.y, ignore_item_id):
		return false
	if building_id >= 0:
		return _building_spot_free(building_id, at.x, at.y)
	return _building_at(at.x, at.y, 14.0).is_empty()


func can_place_building(kind: int, x: float, y: float) -> bool:
	if kind == Catalog.BLD_MARKET and _has_building(Catalog.BLD_MARKET):
		return false
	var at := Catalog.snap_world(x, y)
	return spot_ok(x, y) and _stands(at.x, at.y, Vector2(16.0, 52.0))


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


func _deflesh(id: int, count_use: bool) -> void:
	if id < 0 or id >= slot_count or state[id] == Catalog.ST_VACANT:
		return
	var x := pos_x[id]
	var y := pos_y[id]
	if state[id] == Catalog.ST_LIVING:
		living -= 1
	state[id] = Catalog.ST_VACANT
	_add_item(Catalog.ITEM_BONE, x, y, 1)
	_pop(x, y, ThrongClips.frame_at("ThrongA_Bones", 0))
	if count_use and part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")
	sfx_queue.append("deflesh")


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
	if was_living and living <= 0:
		_enter_game_over()


func _enter_game_over() -> void:
	if game_over or living > 0 or peak <= 0:
		return
	game_over = true
	paused = true
	frozen = false
	modal = {}
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
	if modal.is_empty():
		modal = {"event": event, "action": action}
		_begin_gaze()
	else:
		gaze_queue.append({"event": event, "action": action})


func _open_next_talk() -> void:
	while not gaze_queue.is_empty():
		var next: Dictionary = gaze_queue.pop_front()
		var event := str(next.event)
		if _ethics_choice(event) != -1 and (next.action is Dictionary and next.action.is_empty()):
			continue
		modal = {"event": event, "action": next.action if next.action is Dictionary else {}}
		_begin_gaze()
		return


func _begin_gaze() -> void:
	frozen = true
	_clear_action_motion()
	_line_up_gaze()
	sfx_queue.append("talk")


func _line_up_gaze() -> void:
	_restore_gaze()
	var focus := view_rect.get_center()
	if view_rect.size == Vector2.ZERO:
		focus = Vector2(256, 256)
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
		var clear := not _blocked(here_x, here_y) and not _gaze_covered(here_x, here_y)
		if not clear:
			var spot := _gaze_spot(focus, placed % 4, int(placed / 4))
			if is_inf(spot.x):
				continue
			pos_x[i] = spot.x
			pos_y[i] = spot.y
			dir_x[i] = 0.0
			dir_y[i] = 1.0
		gaze_home[i] = Vector2(here_x, here_y)
		placed += 1


func _gaze_spot(focus: Vector2, col: int, row: int) -> Vector2:
	var base := focus + Vector2((float(col) - 1.5) * 22.0, 36.0 + float(row) * 18.0)
	var fallback := Vector2(INF, INF)
	for step in 12:
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
		return
	if announce:
		notes.append("LA ISLA CRECE.")
	_shape_island()
	_hide_closed_world()


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
		_ensure_early_ore_stock(n)
		if n >= 100 and bool(unlocks.get("mine", false)):
			return "JUNTA ENERGIA  %d/%d  (MINAS EN NODOS → CRISTALES)" % [mini(gems_peak, n), n]
		return "JUNTA ENERGIA  %d/%d  (MARTILLO: ROCA → MINERAL)" % [mini(gems_peak, n), n]
	return "HAZ UN PUENTE"


func _goal_build(label: String, cost: int) -> String:
	var have := count_item(Catalog.ITEM_WOOD)
	if have < cost:
		return "TALA MADERA  %d/%d  LUEGO %s" % [have, cost, label]
	return "%s  (%d MADERA)" % [label, cost]


func _ensure_early_ore_stock(need: int = 20) -> void:
	if not part_two or gems_peak >= need:
		return
	var rocks := 0
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_ROCK:
			continue
		rocks += 1
	if rocks >= 8:
		return
	_seed_early_ore(8 - rocks)


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
			if _dist_point(256.0, 256.0, wx, wy) < 70.0 and c.x == 0 and c.y == 0:
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
	_mood_trance = 0
	living = 0
	peak = 0
	gems = 0
	gems_peak = 0
	land_tier = 0
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
	if _dist_point(_local_mid(), _local_mid(), px, py) < 48.0:
		return false
	var near := _nearest_point(px, py, _pick_points(cx, cy, 6, 60.0, 52.0, 2))
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
	if _dist_point(_local_mid(), _local_mid(), px, py) < 52.0:
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
	var groves := _pick_points(cx, cy, 6, 60.0, 52.0, 2)
	var rocks := _pick_points(cx, cy, 3, 64.0, 72.0, 6)
	var mid := _local_mid()
	var origin := Vector2(float(cx * Catalog.CHUNK * Catalog.TILE), float(cy * Catalog.CHUNK * Catalog.TILE))
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not _open_ground(cx, cy, lx, ly):
				continue
			var px := float(lx * Catalog.TILE + 8)
			var py := float(ly * Catalog.TILE + 8)
			var wx := origin.x + px
			var wy := origin.y + py
			if _dist_point(mid, mid, px, py) < 48.0:
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
		if _dist_point(256.0, 256.0, spot.x, spot.y) < 52.0:
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


func _clear_spawn() -> void:
	var doomed: Array = []
	for feat in features:
		if feat.dead:
			continue
		if _dist_point(256.0, 256.0, float(feat.x), float(feat.y)) < 52.0:
			doomed.append(feat)
	for feat in doomed:
		_kill_feature(feat)


func _add_feature(kind: int, x: float, y: float, hp: int, ore: int, rooted: bool = false) -> Dictionary:
	if _on_bridge(x, y):
		return {}
	if rooted and not _stands(x, y, _span_for_feature(kind)):
		return {}
	if not _is_mine_node(kind) and _near_mine_node(x, y):
		return {}
	if _feature_crowded(x, y, kind):
		return {}
	var cell := _cell_vec(x, y)
	if feature_cell.has(cell):
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
	feature_cell[cell] = id
	return feat


func _kill_feature(feat: Dictionary) -> void:
	if feat.is_empty() or feat.dead:
		return
	feat.dead = true
	var cell := _cell_vec(float(feat.x), float(feat.y))
	if int(feature_cell.get(cell, -1)) == int(feat.id):
		feature_cell.erase(cell)
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
		"node": 0,
		"buffer": 0,
		"burn": 0.0,
		"incinerate": false,
		"active": false,
		"dead": false,
	}
	buildings.append(b)
	building_by_id[id] = b
	return b


func _remove_building(b: Dictionary) -> void:
	_pop(float(b.x), float(b.y), Catalog.ICON_FX_POOF)
	b.dead = true
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
		b.occupant = -1


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
			var d := _dist_point(x, y, float(feat.x), float(feat.y))
			if d <= best_d:
				best_d = d
				best = feat
	return best


func _building_at(x: float, y: float, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for b in buildings:
		if b.dead:
			continue
		var d := _dist_point(x, y, float(b.x), float(b.y))
		if d <= best_d:
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


func _blocked(px: float, py: float) -> bool:
	var tile := _tile_at(px, py)
	if Catalog.tile_blocks(tile):
		return true
	var cell := _cell_vec(px, py)
	if feature_cell.has(cell):
		var feat = feature_by_id.get(int(feature_cell[cell]), {})
		if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
			return true
	return false


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


func _reindex() -> void:
	feature_by_id.clear()
	feature_cell.clear()
	item_by_id.clear()
	building_by_id.clear()
	next_feature_id = 1
	next_item_id = 1
	next_building_id = 1
	for feat in features:
		if feat.dead:
			continue
		feature_by_id[int(feat.id)] = feat
		feature_cell[_cell_vec(float(feat.x), float(feat.y))] = int(feat.id)
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
	if cx == 0 and cy == 0:
		return "meadow"
	if _is_island_chunk(cx, cy):
		return "grove"
	return "sea"


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


func _run_checks() -> void:
	var errors: Array = []
	if living != 0:
		errors.append("start living %s" % living)
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
	var market_at := Vector2(256.0, 200.0)
	for spot in [Vector2(256.0, 200.0), Vector2(220.0, 220.0), Vector2(280.0, 220.0), Vector2(256.0, 300.0)]:
		if can_place_building(Catalog.BLD_MARKET, spot.x, spot.y):
			market_at = spot
			break
	if not place_building(Catalog.BLD_MARKET, market_at.x, market_at.y):
		errors.append("market place free")
	elif place_building(Catalog.BLD_MARKET, market_at.x + 40.0, market_at.y):
		errors.append("market unique broken")
	_rebuild_hash()
	if find_thronglet(pos_x[0], pos_y[0], 8.0, true) != 0:
		errors.append("hash miss")
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
	while living > 0:
		var last := -1
		for i in slot_count:
			if state[i] == Catalog.ST_LIVING:
				last = i
				break
		if last < 0:
			break
		_become_corpse(last)
	if not game_over:
		errors.append("no game over")
	print("SMOKE " + ("OK" if errors.is_empty() else "FAIL"))
	for err in errors:
		print(" - " + str(err))
	get_tree().quit(0 if errors.is_empty() else 1)
