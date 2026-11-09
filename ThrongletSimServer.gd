extends Node

# Colony simulation. Needs, tools and prices follow the Netflix Thronglets FAQ.
# The bug defleshes a body into bone. The axe leaves a stump. The hammer removes it.
# Mitosis requires food, fun and clean together. There is no forced game over.

const DECAY_FED := 0.45
const DECAY_FUN := 0.28
const DECAY_CLEAN := 0.32
const MOVE_SPEED := 26.0

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
var modal := {}
var frozen := false

var part_two := false
var mountain_seen := false
var trees_chopped := 0
var bug_uses := 0
var tnt_used := 0
var goo_count := 0
var gems := 0
var gems_peak := 0
var peak := 0
var land_tier := 0
var living := 0
var monolith_tier_spawned := {}

var revealed := {}
var chunks := {}
var bridge_done := {}
var bridges: Array = []
var dirty_chunks: Array = []
var paint_epoch := 0

var features: Array = []
var feature_by_id := {}
var feature_cell := {}
var next_feature_id := 1

var items: Array = []
var item_by_id := {}
var next_item_id := 1
var hand_id := -1
var held_kind := ""
var held_ref := -1
var held_x := 0.0
var held_y := 0.0
var session_live := false
var sponge_id := -1
var sponge_hold := 0.0

var buildings: Array = []
var building_by_id := {}
var next_building_id := 1

var slot_count := 0
var cursor := 0
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
var wander_t := PackedFloat32Array()
var mito_t := PackedFloat32Array()
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not testing and current_slot >= 0:
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
		_tick_items(delta)
		_tick_buildings(delta)
		_tick_auras(delta)
		_tick_visible(delta)
		_tick_slice(delta)
		_tick_pops(delta)
		_compact(items)
		_compact(features)
		_compact(buildings)
	_check_milestones()
	_rebuild_hash()


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
	fed[i] = maxf(0.0, fed[i] - DECAY_FED * dt)
	amused[i] = maxf(0.0, amused[i] - DECAY_FUN * dt)
	clean[i] = maxf(0.0, clean[i] - DECAY_CLEAN * dt)
	var tile := _tile_at(pos_x[i], pos_y[i])
	if tile == Catalog.TILE_GOO:
		clean[i] = maxf(0.0, clean[i] - 0.9 * dt)
		fed[i] = maxf(0.0, fed[i] - 0.35 * dt)
	if fed[i] <= 0.0 or amused[i] <= 0.0 or clean[i] <= 0.0:
		starve[i] += dt
		if starve[i] >= 18.0:
			_die_neglect(i)
			return
	else:
		starve[i] = 0.0
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
	if fed[i] >= Catalog.NEED_OK and amused[i] >= Catalog.NEED_OK and clean[i] >= Catalog.NEED_OK and cool[i] <= 0.0:
		_start_mitosis(i)
		return
	var speed := MOVE_SPEED
	if buff_t[i] > 0.0:
		speed = 36.0
		buff_t[i] = maxf(0.0, buff_t[i] - dt)
	if fed[i] < Catalog.NEED_OK:
		_release_claim(i)
		if _seek_food(i, speed, dt):
			return
	if clean[i] < Catalog.NEED_OK:
		if _seek_clean(i, speed, dt):
			return
	else:
		_release_claim(i)
	if amused[i] < Catalog.NEED_OK and _seek_fun(i, speed, dt):
		return
	var cared := fed[i] >= 70.0 and amused[i] >= 70.0 and clean[i] >= 70.0
	if cared and _try_haul(i, speed, dt):
		return
	if cared and _seek_mine(i, speed, dt):
		return
	_wander(i, speed, dt)


func _start_mitosis(i: int) -> void:
	if slot_count >= Catalog.MAX_SLOTS:
		if not cap_told:
			cap_told = true
			notes.append("LA COLONIA NO CABE MAS.")
		cool[i] = Catalog.MITOSIS_WAIT
		return
	cool[i] = Catalog.MITOSIS_WAIT
	mito_t[i] = 0.45
	var ang := randf() * TAU
	var x := pos_x[i] + cos(ang) * 10.0
	var y := pos_y[i] + sin(ang) * 10.0
	if _blocked(x, y):
		x = pos_x[i]
		y = pos_y[i]
	_push_slot(x, y, 70.0, 70.0, 70.0, 8.0, int(tint[i]))
	sfx_queue.append("mitosis")


func _seek_food(i: int, speed: float, dt: float) -> bool:
	var apple := _nearest_item(pos_x[i], pos_y[i], Catalog.ITEM_APPLE, 240.0)
	var home := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY, Catalog.BLD_APPLE], 280.0)
	var mode := ""
	var tx := 0.0
	var ty := 0.0
	var best := 999999.0
	if not apple.is_empty():
		var d := _dist_i(i, float(apple.x), float(apple.y))
		if d < best:
			best = d
			tx = float(apple.x)
			ty = float(apple.y)
			mode = "apple"
	if not home.is_empty():
		var d2 := _dist_i(i, float(home.x), float(home.y))
		if d2 < best:
			best = d2
			tx = float(home.x)
			ty = float(home.y)
			mode = "home"
	if mode == "":
		return false
	if mode == "apple" and best < 12.0:
		act[i] = ACT_EAT
		act_t[i] = 0.25
		apple.bite = float(apple.get("bite", 0.0)) + dt
		if float(apple.bite) >= 0.45:
			apple.dead = true
			fed[i] = 100.0
			_pop(pos_x[i], pos_y[i], Catalog.ICON_APPLE)
		return true
	if mode == "home" and best < 34.0:
		act[i] = ACT_EAT
		act_t[i] = 0.25
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _seek_clean(i: int, speed: float, dt: float) -> bool:
	var tub := _nearest_tub(i)
	var home := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0)
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
		act_t[i] = 0.25
		return true
	if best < 34.0 and not use_tub:
		act[i] = ACT_WORK
		act_t[i] = 0.25
		return true
	_walk(i, float(target.x), float(target.y), speed, dt)
	return true


func _seek_fun(i: int, speed: float, dt: float) -> bool:
	var ball := _nearest_item(pos_x[i], pos_y[i], Catalog.ITEM_BALL, 220.0)
	var play := _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_ROUND, Catalog.BLD_THEATRE], 300.0)
	var tx := 0.0
	var ty := 0.0
	var best := 999999.0
	var radius := 16.0
	if not ball.is_empty():
		best = _dist_i(i, float(ball.x), float(ball.y))
		tx = float(ball.x)
		ty = float(ball.y)
		radius = 18.0
	if not play.is_empty():
		var d2 := _dist_i(i, float(play.x), float(play.y))
		if d2 < best:
			best = d2
			tx = float(play.x)
			ty = float(play.y)
			radius = 28.0 if int(play.kind) == Catalog.BLD_ROUND else 48.0
	if best > 900000.0:
		return false
	if best < radius:
		act[i] = ACT_PLAY
		act_t[i] = 0.25
		if not ball.is_empty() and _dist_i(i, float(ball.x), float(ball.y)) < 20.0 and float(ball.get("rest", 0.0)) <= 0.0:
			var kx := float(ball.x) - pos_x[i]
			var ky := float(ball.y) - pos_y[i]
			var kl := sqrt(kx * kx + ky * ky)
			if kl < 1.0:
				kl = 1.0
			ball.vx = kx / kl * 78.0
			ball.vy = ky / kl * 62.0
			ball.rest = 0.55
			amused[i] = minf(100.0, amused[i] + 8.0)
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _try_haul(i: int, speed: float, dt: float) -> bool:
	if carry[i] != Catalog.CARRY_NONE:
		return _deliver(i, speed, dt)
	var bridge := _nearest_open_bridge(pos_x[i], pos_y[i], 1600.0)
	if not bridge.is_empty():
		var wood := _nearest_item(pos_x[i], pos_y[i], Catalog.ITEM_WOOD, 130.0)
		if not wood.is_empty() and _dist_point(float(wood.x), float(wood.y), float(bridge.x), float(bridge.y)) < 120.0:
			return _walk_pickup(i, wood, Catalog.CARRY_WOOD, speed, dt)
		var bone := _nearest_item(pos_x[i], pos_y[i], Catalog.ITEM_BONE, 130.0)
		if not bone.is_empty() and _dist_point(float(bone.x), float(bone.y), float(bridge.x), float(bridge.y)) < 120.0:
			return _walk_pickup(i, bone, Catalog.CARRY_BONE, speed, dt)
	if _has_factory():
		var ore := _nearest_item(pos_x[i], pos_y[i], Catalog.ITEM_ORE, 180.0)
		if not ore.is_empty():
			return _walk_pickup(i, ore, Catalog.CARRY_ORE, speed, dt)
	return false


func _walk_pickup(i: int, item: Dictionary, carry_kind: int, speed: float, dt: float) -> bool:
	var tx := float(item.x)
	var ty := float(item.y)
	if _dist_i(i, tx, ty) < 8.0:
		if not item.dead and not item.held:
			carry[i] = carry_kind
			carry_value[i] = int(item.value)
			item.dead = true
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _deliver(i: int, speed: float, dt: float) -> bool:
	var tx := 0.0
	var ty := 0.0
	var factory := {}
	if carry[i] == Catalog.CARRY_ORE:
		factory = _nearest_building_kinds(pos_x[i], pos_y[i], [Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2], 4000.0)
		if factory.is_empty():
			carry[i] = Catalog.CARRY_NONE
			return false
		tx = float(factory.x)
		ty = float(factory.y)
	else:
		var bridge := _nearest_open_bridge(pos_x[i], pos_y[i], 4000.0)
		if bridge.is_empty():
			carry[i] = Catalog.CARRY_NONE
			return false
		tx = float(bridge.x)
		ty = float(bridge.y)
	_walk(i, tx, ty, speed, dt)
	if _dist_i(i, tx, ty) < 64.0:
		if carry[i] == Catalog.CARRY_ORE:
			factory.buffer = int(factory.get("buffer", 0)) + maxi(1, carry_value[i])
		else:
			_drop_on_bridge(tx, ty, carry[i])
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
		act_t[i] = 0.25
		return true
	_walk(i, tx, ty, speed, dt)
	return true


func _wander(i: int, speed: float, dt: float) -> void:
	wander_t[i] -= dt
	if wander_t[i] <= 0.0:
		var ang := randf() * TAU
		dir_x[i] = cos(ang)
		dir_y[i] = sin(ang)
		wander_t[i] = randf_range(0.5, 1.8)
	_move(i, dir_x[i] * speed * dt, dir_y[i] * speed * dt)


func _walk(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	var dx := tx - pos_x[i]
	var dy := ty - pos_y[i]
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		return
	dir_x[i] = dx / dist
	dir_y[i] = dy / dist
	_move(i, dir_x[i] * speed * dt, dir_y[i] * speed * dt)


func _move(i: int, dx: float, dy: float) -> void:
	var moved := false
	if not _blocked(pos_x[i] + dx, pos_y[i]):
		pos_x[i] += dx
		moved = true
	if not _blocked(pos_x[i], pos_y[i] + dy):
		pos_y[i] += dy
		moved = true
	if not moved:
		wander_t[i] = 0.0


func _tick_items(dt: float) -> void:
	for it in items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_BALL:
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


func _tick_buildings(dt: float) -> void:
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_APPLE:
			b.timer = float(b.timer) - dt
			if float(b.timer) <= 0.0:
				b.timer = 5.0
				if _count_items_near(Catalog.ITEM_APPLE, float(b.x), float(b.y), 36.0) < 4:
					_add_item(Catalog.ITEM_APPLE, float(b.x) + randf_range(-8.0, 8.0), float(b.y) + 12.0, 1)
		elif kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			var cap := 6 if kind == Catalog.BLD_MINE2 else 2
			var workers := _workers_near(b, cap)
			if workers > 0:
				b.timer = float(b.timer) - dt * float(workers)
				if float(b.timer) <= 0.0:
					b.timer = 2.2
					_add_item(Catalog.ITEM_ORE, float(b.x), float(b.y) + 14.0, _mine_value(b))
		elif kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			b.timer = float(b.timer) - dt
			if float(b.timer) <= 0.0:
				var buffered := int(b.get("buffer", 0))
				if buffered > 0:
					b.buffer = buffered - 1
					b.timer = 0.7 if kind == Catalog.BLD_FACTORY2 else 2.0
					gems += 2 if kind == Catalog.BLD_FACTORY2 else 1
					_spill_goo(float(b.x), float(b.y), 2 if kind == Catalog.BLD_FACTORY2 else 1)
				else:
					b.timer = 0.25
			if bool(b.get("incinerate", false)):
				b.burn = float(b.get("burn", 0.0)) + dt
				if float(b.burn) >= 3.0:
					var corpse := _nearest_corpse(float(b.x), float(b.y), 90.0)
					if corpse >= 0:
						b.burn = 0.0
						_vacate(corpse)
						gems += 3
						sfx_queue.append("death")


func _tick_auras(dt: float) -> void:
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_DWELL:
			_boost(float(b.x), float(b.y), 42.0, 4, 18.0 * dt, 18.0 * dt, 0.0, 0.0)
		elif kind == Catalog.BLD_FANCY:
			_boost(float(b.x), float(b.y), 58.0, 10, 22.0 * dt, 22.0 * dt, 0.0, 0.0)
		elif kind == Catalog.BLD_ROUND:
			_boost(float(b.x), float(b.y), 44.0, 6, 0.0, 0.0, 22.0 * dt, 0.0)
		elif kind == Catalog.BLD_THEATRE:
			_boost(float(b.x), float(b.y), 76.0, 18, 0.0, 0.0, 28.0 * dt, 1.6)
		elif kind == Catalog.BLD_TUB:
			var occ := int(b.occupant)
			if occ >= 0 and occ < slot_count and state[occ] == Catalog.ST_LIVING and _dist_i(occ, float(b.x), float(b.y)) < 16.0:
				clean[occ] = minf(100.0, clean[occ] + 30.0 * dt)
				if clean[occ] >= 98.0:
					_release_claim(occ)


func _boost(x: float, y: float, radius: float, limit: int, fed_r: float, clean_r: float, fun_r: float, buff: float) -> void:
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


func use_tool(tool: int, x: float, y: float) -> void:
	if frozen:
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
	if _blocked(x, y):
		notes.append("AHI NO.")
		return
	_add_item(kind, x, y, value)
	sfx_queue.append("place")


func _tool_axe(x: float, y: float) -> void:
	var feat := _feature_at(x, y, 14.0)
	if feat.is_empty() or int(feat.kind) != Catalog.FEAT_TREE:
		_splash_kill(x, y, 10.0)
		return
	_chop(feat)
	_splash_kill(float(feat.x), float(feat.y), 12.0)


func _chop(feat: Dictionary) -> void:
	feat.kind = Catalog.FEAT_STUMP
	_add_item(Catalog.ITEM_WOOD, float(feat.x) + 8.0, float(feat.y), 1)
	_pop(float(feat.x), float(feat.y), Catalog.ICON_WOOD)
	trees_chopped += 1
	sfx_queue.append("chop")
	if trees_chopped >= 12:
		_grant("grabber", "DOCE ARBOLES. LA GARRA JUNTA LO SUELTO.")


func _tool_hammer(x: float, y: float) -> void:
	var item := _item_at(x, y, 10.0)
	if not item.is_empty() and int(item.kind) == Catalog.ITEM_ORE and part_two:
		gems += int(item.value)
		item.dead = true
		notes.append("EL MINERAL SUELTA ENERGIA.")
		sfx_queue.append("chop")
		return
	var feat := _feature_at(x, y, 14.0)
	if not feat.is_empty():
		_hammer_feature(feat)
		_splash_kill(x, y, 10.0)
		sfx_queue.append("chop")
		return
	var b := _building_at(x, y, 16.0)
	if not b.is_empty():
		_remove_building(b)
		_splash_kill(x, y, 10.0)
		sfx_queue.append("chop")
		return
	_splash_kill(x, y, 10.0)


func _hammer_feature(feat: Dictionary) -> void:
	var kind := int(feat.kind)
	if kind == Catalog.FEAT_MONOLITH:
		notes.append("NO CEDE.")
		return
	if kind == Catalog.FEAT_TREE:
		notes.append("ESO QUIERE EL HACHA.")
		return
	if kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_FLOWER:
		_pop(float(feat.x), float(feat.y), Catalog.ICON_STUMP if kind == Catalog.FEAT_STUMP else Catalog.ICON_FLOWER)
		_kill_feature(feat)
		return
	if kind == Catalog.FEAT_NODE or kind == Catalog.FEAT_SUPER:
		notes.append("AHI VA UNA MINA.")
		return
	if kind == Catalog.FEAT_ROCK:
		_pop(float(feat.x), float(feat.y), Catalog.ICON_ROCK)
		if not part_two:
			_kill_feature(feat)
			return
		feat.hp = int(feat.hp) - 1
		if int(feat.hp) <= 0:
			if int(feat.ore) > 0:
				_add_item(Catalog.ITEM_ORE, float(feat.x), float(feat.y), int(feat.ore))
			_kill_feature(feat)
		return


func _tool_pick(x: float, y: float) -> void:
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_ROCK:
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= 42.0:
			_hammer_feature(feat)
	_splash_kill(x, y, 16.0)
	sfx_queue.append("chop")


func _tool_saw(x: float, y: float) -> void:
	for feat in features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
			continue
		if _dist_point(x, y, float(feat.x), float(feat.y)) <= 40.0:
			_chop(feat)
			_splash_kill(float(feat.x), float(feat.y), 10.0)
	sfx_queue.append("chop")


func _tool_bug(x: float, y: float) -> void:
	var id := find_thronglet(x, y, 14.0, false)
	if id < 0:
		return
	_confirm("bug", {"op": "bug", "id": id})


func _tool_swarm(x: float, y: float) -> void:
	_confirm("bug", {"op": "swarm", "x": x, "y": y})


func _tool_tnt(x: float, y: float) -> void:
	var charge := _nearest_item(x, y, Catalog.ITEM_TNT, 14.0)
	if not charge.is_empty():
		_detonate(charge)
		return
	if _blocked(x, y):
		notes.append("AHI NO.")
		return
	_add_item(Catalog.ITEM_TNT, x, y, 1)
	notes.append("CARGA COLOCADA. PULSALA PARA DETONARLA.")
	sfx_queue.append("place")


func _detonate(charge: Dictionary) -> void:
	var x := float(charge.x)
	var y := float(charge.y)
	charge.dead = true
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
	for it in items:
		if it.dead or it.held:
			continue
		var kind := int(it.kind)
		if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
			continue
		if _dist_point(x, y, float(it.x), float(it.y)) <= 48.0:
			it.x = x
			it.y = y
	for i in slot_count:
		if state[i] != Catalog.ST_DEAD:
			continue
		if _dist_i(i, x, y) <= 48.0:
			pos_x[i] = x
			pos_y[i] = y
	sfx_queue.append("place")


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
	var id := -1
	if sponge_id >= 0 and sponge_id < slot_count and state[sponge_id] == Catalog.ST_LIVING and _dist_i(sponge_id, x, y) <= 30.0:
		id = sponge_id
	else:
		id = find_thronglet(x, y, 16.0, true)
	if id < 0:
		return
	sponge_id = id
	sponge_hold = 0.35
	if stroke < 4.0 or _dist_i(id, x, y) > 26.0:
		return
	clean[id] = minf(100.0, clean[id] + minf(stroke, 22.0) * 2.0)
	shake_t[id] = 0.18
	act[id] = ACT_WASH
	act_t[id] = 0.25
	if int(frame_i) % 4 == 0:
		_pop(pos_x[id], pos_y[id] - 6.0, Catalog.ICON_SPONGE)


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
			return {"type": "factory", "id": int(b.id)}
		if kind == Catalog.BLD_CANNON:
			_confirm("orbit", {"op": "launch", "id": int(b.id)})
			return {"type": "cannon", "id": int(b.id)}
		if kind == Catalog.BLD_MARKET:
			return {"type": "market"}
		return {"type": "building", "id": int(b.id)}
	var id := find_thronglet(x, y, 12.0, false)
	if id >= 0:
		return {"type": "thronglet", "id": id}
	return {"type": "empty"}


func take_hand(x: float, y: float) -> bool:
	if hand_id != -1 or frozen:
		return false
	var it := _item_at(x, y, 10.0)
	if it.is_empty():
		return false
	it.held = true
	hand_id = int(it.id)
	return true


func drop_hand(x: float, y: float) -> void:
	if hand_id == -1:
		return
	var it = item_by_id.get(hand_id, {})
	hand_id = -1
	if it.is_empty() or it.dead:
		return
	it.held = false
	if _blocked(x, y):
		return
	it.x = x
	it.y = y


func is_holding() -> bool:
	return held_kind != "" or hand_id != -1


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
	return take_hand(x, y)


func release_at(x: float, y: float, short_click: bool, allow_use: bool = true) -> Dictionary:
	if hand_id != -1:
		var it = item_by_id.get(hand_id, {})
		var ix := x
		var iy := y
		if short_click and not it.is_empty():
			ix = float(it.x)
			iy = float(it.y)
		drop_hand(ix, iy)
		return {}
	if held_kind == "":
		return {}
	var px := held_x if short_click else x
	var py := held_y if short_click else y
	var kind := held_kind
	var id := held_ref
	var use := allow_use and short_click and kind == "building"
	if kind == "thronglet" and id >= 0 and id < slot_count and state[id] == Catalog.ST_LIVING:
		if not short_click and _tile_at(px, py) == Catalog.TILE_VOID:
			pos_x[id] = px
			pos_y[id] = py
			_become_corpse(id)
			notes.append("SE CAE AL VACIO.")
			sfx_queue.append("death")
		elif short_click or _can_drop(px, py):
			pos_x[id] = px
			pos_y[id] = py
	elif kind == "rock":
		var feat = feature_by_id.get(id, {})
		if not feat.is_empty() and not feat.dead:
			if not _can_drop(px, py) or not _bind_feature_at(feat, px, py):
				feat.x = held_x
				feat.y = held_y
				_bind_feature_at(feat, held_x, held_y)
			feat.lifted = false
	elif kind == "building":
		var b = building_by_id.get(id, {})
		if not b.is_empty() and not b.dead:
			if _can_drop(px, py) and _building_spot_free(id, px, py):
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
	return revealed.has(_ck_of(x, y)) and not _blocked(x, y)


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


func place_building(kind: int, x: float, y: float) -> bool:
	if frozen:
		return false
	if not Catalog.BUILD_INFO.has(kind):
		return false
	var info: Dictionary = Catalog.BUILD_INFO[kind]
	if not bool(unlocks.get(str(info.unlock), false)):
		notes.append("AUN NO ESTA DESBLOQUEADO.")
		return false
	if not revealed.has(_ck_of(x, y)) or _blocked(x, y):
		notes.append("AHI NO SE PUEDE CONSTRUIR.")
		return false
	if not _building_at(x, y, 14.0).is_empty():
		notes.append("YA HAY ALGO AHI.")
		return false
	var node := 0
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		var feat := _feature_at(x, y, 12.0)
		if feat.is_empty() or (int(feat.kind) != Catalog.FEAT_NODE and int(feat.kind) != Catalog.FEAT_SUPER):
			notes.append("LA MINA SOLO VA SOBRE UN NODO.")
			return false
		node = 2 if int(feat.kind) == Catalog.FEAT_SUPER else 1
		_kill_feature(feat)
	if not _consume_kind(Catalog.ITEM_WOOD, int(info.wood), x, y):
		notes.append("FALTA MADERA.")
		return false
	var b := _add_building(kind, x, y)
	b.node = node
	if kind == Catalog.BLD_CANNON:
		_grant("nuke", "EL CANON CARGA EL DISPOSITIVO TERMONUCLEAR. NO ACABA LA PARTIDA.")
	sfx_queue.append("place")
	_pop(x, y, int(info.icon))
	return true


func buy(key: String) -> bool:
	if not bool(unlocks.get("market", false)):
		notes.append("EL MERCADO AUN NO EXISTE.")
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
	var event := str(modal.event)
	var action: Dictionary = modal.action if modal.action is Dictionary else {}
	var gaze: Dictionary = Catalog.GAZE[event]
	var choices: Array = gaze.choices
	if index < 0 or index >= choices.size():
		return
	_set_ethics(event, index, str(choices[index]))
	modal = {}
	frozen = false
	var allow: Array = gaze.allow
	if allow.has(index) and not action.is_empty():
		_apply_action(action)
	sfx_queue.append("gaze")


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
	return str(ethics[ethics.size() - 1].text)


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
	return true


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
		"unlocks": unlocks.duplicate(true),
		"ethics": ethics.duplicate(true),
		"part_two": part_two,
		"mountain_seen": mountain_seen,
		"trees_chopped": trees_chopped,
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
		"wander_t": wander_t,
		"mito_t": mito_t,
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
		"bridges": bridges.duplicate(true),
		"chunks": chunks.duplicate(true),
		"bridge_done": bridge_done.duplicate(true),
		"revealed": revealed.duplicate(true),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		notes.append("NO SE PUDO GUARDAR.")
		return false
	file.store_var(data, true)
	notes.append("PARTIDA GUARDADA.")
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
	unlocks = data.get("unlocks", unlocks)
	ethics = data.get("ethics", [])
	part_two = bool(data.get("part_two", false))
	mountain_seen = bool(data.get("mountain_seen", false))
	trees_chopped = int(data.get("trees_chopped", 0))
	bug_uses = int(data.get("bug_uses", 0))
	tnt_used = int(data.get("tnt_used", 0))
	goo_count = int(data.get("goo_count", 0))
	cap_told = bool(data.get("cap_told", false))
	monolith_tier_spawned = data.get("monoliths", {})
	pos_x = _as_f32(data.pos_x)
	pos_y = _as_f32(data.pos_y)
	dir_x = _as_f32(data.dir_x)
	dir_y = _as_f32(data.dir_y)
	fed = _as_f32(data.fed)
	amused = _as_f32(data.amused)
	clean = _as_f32(data.clean)
	cool = _as_f32(data.cool)
	starve = _as_f32(data.starve)
	wander_t = _as_f32(data.wander_t)
	mito_t = _as_f32(data.mito_t)
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
	items = data.get("items", [])
	buildings = data.get("buildings", [])
	features = data.get("features", [])
	bridges = data.get("bridges", [])
	chunks = data.get("chunks", {})
	bridge_done = data.get("bridge_done", {})
	revealed = data.get("revealed", {})
	_recount()
	_reindex()
	_check_milestones(false)
	_shape_island()
	_rebuild_hash()
	paint_epoch += 1
	dirty_chunks.clear()
	for key in revealed.keys():
		dirty_chunks.append(str(key))
	frozen = false
	modal = {}
	hand_id = -1
	_clear_held()
	sponge_id = -1
	sponge_hold = 0.0
	notes.append("PARTIDA CARGADA.")
	session_live = true
	return true


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
	elif op == "launch":
		_launch(int(action.get("id", -1)))
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
	if count_use and part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")
	sfx_queue.append("death")


func _swarm(x: float, y: float) -> void:
	var ids := query_radius(x, y, 36.0)
	for id in ids:
		if state[int(id)] != Catalog.ST_VACANT:
			_deflesh(int(id), false)
	if part_two:
		bug_uses += 1
		if bug_uses >= 3:
			_grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")


func _launch(building_id: int) -> void:
	var b = building_by_id.get(building_id, {})
	if b.is_empty():
		return
	var id := _nearest_living(float(b.x), float(b.y), 90.0)
	if id < 0:
		notes.append("NO HAY NADIE CERCA DEL CANON.")
		return
	_vacate(id)
	gems += 20
	sfx_queue.append("explode")
	notes.append("UNO SALE DE LA PANTALLA. +20 GEMAS.")


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
	notes.append("EL SECTOR QUEDA LIMPIO. LA COLONIA SIGUE.")
	sfx_queue.append("explode")


func _splash_kill(x: float, y: float, radius: float) -> void:
	var ids := query_radius(x, y, radius)
	var any := false
	for id in ids:
		if state[int(id)] == Catalog.ST_LIVING:
			_become_corpse(int(id))
			any = true
	if any:
		sfx_queue.append("death")
		_reflect("tool")


func _die_neglect(i: int) -> void:
	_become_corpse(i)
	sfx_queue.append("death")
	_reflect("neglect")


func _become_corpse(i: int) -> void:
	if state[i] != Catalog.ST_LIVING:
		return
	state[i] = Catalog.ST_DEAD
	living -= 1
	carry[i] = Catalog.CARRY_NONE
	_release_claim(i)


func _vacate(i: int) -> void:
	if i < 0 or i >= slot_count or state[i] == Catalog.ST_VACANT:
		return
	if state[i] == Catalog.ST_LIVING:
		living -= 1
	state[i] = Catalog.ST_VACANT
	_release_claim(i)


func _confirm(event: String, action: Dictionary) -> void:
	var prev := _ethics_choice(event)
	var allow: Array = Catalog.GAZE[event].allow
	if prev != -1 and allow.has(prev):
		_apply_action(action)
		notes.append("EL THRONG LO HA NOTADO.")
		return
	if not modal.is_empty():
		return
	modal = {"event": event, "action": action}
	frozen = true
	sfx_queue.append("gaze")


func _reflect(event: String) -> void:
	if _ethics_choice(event) != -1 or not modal.is_empty():
		return
	modal = {"event": event, "action": {}}
	frozen = true
	sfx_queue.append("gaze")


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


func _grant(key: String, message: String) -> bool:
	if bool(unlocks.get(key, false)):
		return false
	unlocks[key] = true
	unlock_serial += 1
	if message != "":
		notes.append(message)
	return true


func _refresh_pop_gates() -> void:
	var n := peak
	if n >= 6:
		_grant("bathtub", "BANERA LISTA. LIMPIA A UNO CADA VEZ.")
	if n >= 10:
		_grant("apple_tree", "MANZANO LISTO. SUELTA MANZANAS SOLO.")
	if n >= 15:
		_grant("roundabout", "TIOVIVO LISTO. ENTRETIENE A VARIOS.")
	if n >= 20:
		_grant("hammer", "MARTILLO LISTO. QUITA TOCONES Y ROCAS.")
	if n >= 25:
		_ensure_monolith(1)
	_check_milestones()


func _milestone_defs() -> Array:
	return [
		{"kind": "pop", "n": 6},
		{"kind": "pop", "n": 12},
		{"kind": "bridge", "n": 0},
		{"kind": "gem", "n": 25},
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
		return
	if announce:
		notes.append("LA ISLA CRECE.")
	_shape_island()


func goal_line() -> String:
	var defs := _milestone_defs()
	if land_tier >= defs.size():
		return "LA ISLA ESTA COMPLETA"
	var step: Dictionary = defs[land_tier]
	var kind := str(step.kind)
	var n := int(step.n)
	if kind == "pop":
		return "HITO  %d/%d MULTIS" % [mini(peak, n), n]
	if kind == "gem":
		return "HITO  %d/%d ENERGIA" % [mini(gems_peak, n), n]
	return "HITO  HAZ UN PUENTE"


func _enter_part_two(reason: String) -> void:
	var first := not part_two
	part_two = true
	_grant("market", "ABRE EL MERCADO. LAS GEMAS COMPRAN LO QUE VIENE.")
	_grant("flower", "")
	_grant("sculpture", "")
	if first and reason != "":
		notes.append(reason)
	_check_milestones()


func _ensure_monolith(tier: int) -> void:
	if bool(monolith_tier_spawned.get(tier, false)):
		return
	if tier == 1 and bool(unlocks.get("bug", false)):
		return
	if tier == 2 and bool(unlocks.get("cannon", false)):
		return
	monolith_tier_spawned[tier] = true
	var x := 168.0 + float(tier) * 78.0
	var y := 168.0
	if _blocked(x, y):
		x = 256.0
		y = 150.0 + float(tier) * 20.0
	_add_feature(Catalog.FEAT_MONOLITH, x, y, 4, tier)
	notes.append("UN MONOLITO HA APARECIDO.")


func _touch_monolith(feat: Dictionary) -> void:
	var tier := int(feat.ore)
	if tier == 1:
		_grant("bug", "EL MONOLITO ENTREGA EL BICHO. ABRE UN CUERPO Y DEJA HUESO.")
	elif tier == 2:
		_grant("cannon", "EL MONOLITO ENTREGA EL CANON ORBITAL.")
	_kill_feature(feat)
	sfx_queue.append("gaze")


func _drop_on_bridge(x: float, y: float, carry_kind: int) -> void:
	var bridge := _nearest_open_bridge(x, y, 90.0)
	if bridge.is_empty():
		return
	if carry_kind == Catalog.CARRY_BONE:
		bridge.progress = int(bridge.progress) + 3
		bridge.bones = int(bridge.bones) + 1
	else:
		bridge.progress = int(bridge.progress) + 1
	if int(bridge.progress) >= int(bridge.need) and not bool(bridge.done):
		_finish_bridge(bridge)


func _finish_bridge(bridge: Dictionary) -> void:
	bridge.done = true
	var ck := str(bridge.ck)
	bridge_done[ck] = true
	var axis := str(chunks[ck].axis)
	var tile := Catalog.TILE_BRIDGE_BONE if int(bridge.bones) > 0 else Catalog.TILE_BRIDGE_WOOD
	if axis == "v" or axis == "both":
		for ly in range(14, 18):
			for lx in range(13, 19):
				_set_local_tile(ck, lx, ly, tile, true)
	if axis == "h" or axis == "both":
		for ly in range(13, 19):
			for lx in range(14, 18):
				_set_local_tile(ck, lx, ly, tile, true)
	notes.append("EL PUENTE ESTA LISTO.")
	_enter_part_two("EL PRIMER PUENTE ABRE LA SEGUNDA PARTE.")
	if int(bridge.bones) > 0:
		_reflect("bones")
	sfx_queue.append("place")


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
	if goo_count >= 8:
		if _grant("mop", "LA FABRICA MANCHA EL SUELO. LLEGA LA FREGONA."):
			_reflect("goo")
		else:
			_reflect("goo")


func _bootstrap_new() -> void:
	var keep := world_seed
	_reset_world()
	world_seed = keep
	if world_seed == 0:
		world_seed = 1
	_reveal(0, 0)
	_clear_spawn()
	_push_slot(256.0, 248.0, 78.0, 78.0, 78.0, 6.0, 0)
	_push_slot(276.0, 268.0, 74.0, 80.0, 76.0, 7.0, 1)
	_push_slot(238.0, 272.0, 80.0, 72.0, 77.0, 5.0, 2)
	_rebuild_hash()
	session_live = true


func _reset_world() -> void:
	revealed.clear()
	chunks.clear()
	bridge_done.clear()
	bridges.clear()
	dirty_chunks.clear()
	features.clear()
	feature_by_id.clear()
	feature_cell.clear()
	items.clear()
	item_by_id.clear()
	buildings.clear()
	building_by_id.clear()
	next_feature_id = 1
	next_item_id = 1
	next_building_id = 1
	hand_id = -1
	_clear_held()
	sponge_id = -1
	sponge_hold = 0.0
	slot_count = 0
	cursor = 0
	living = 0
	peak = 0
	gems = 0
	gems_peak = 0
	land_tier = 0
	trees_chopped = 0
	bug_uses = 0
	tnt_used = 0
	goo_count = 0
	part_two = false
	mountain_seen = false
	cap_told = false
	frozen = false
	modal = {}
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
	wander_t = PackedFloat32Array()
	mito_t = PackedFloat32Array()
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
	wander_t.append(randf_range(0.2, 1.2))
	mito_t.append(0.0)
	shake_t.append(0.0)
	buff_t.append(0.0)
	state.append(Catalog.ST_LIVING)
	carry.append(Catalog.CARRY_NONE)
	carry_value.append(0)
	tint.append(tint_i)
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
	var biome := str(chunks[ck].biome)
	if biome == "river":
		_grant("axe", "HAY UN RIO. EL THRONG DEJA EL HACHA.")
	if biome == "mountain":
		mountain_seen = true
		_grant("tnt", "LA MONTANA ESTA CERRADA. DINAMITA.")
		_enter_part_two("LA MONTANA ABRE LA SEGUNDA PARTE.")
	_mark_dirty(ck)


func _try_reveal(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if revealed.has(ck):
		return
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nk := _ck(cx + d.x, cy + d.y)
		if revealed.has(nk) and _edge_open(cx + d.x, cy + d.y, cx, cy):
			_reveal(cx, cy)
			return


func _edge_open(ax: int, ay: int, bx: int, by: int) -> bool:
	var a := _biome_of(ax, ay)
	var b := _biome_of(bx, by)
	if a == "river" and b != "river":
		return bool(bridge_done.get(_ck(ax, ay), false))
	if a == "river" and b == "river":
		return bool(bridge_done.get(_ck(ax, ay), false)) and bool(bridge_done.get(_ck(bx, by), false))
	return true


func _ensure(cx: int, cy: int) -> void:
	var ck := _ck(cx, cy)
	if chunks.has(ck):
		return
	var biome := _biome_formula(cx, cy)
	var axis := ""
	if biome == "river":
		axis = _river_axis(cx, cy)
	var tiles := _fill_tiles(cx, cy, biome, axis)
	chunks[ck] = {"biome": biome, "axis": axis, "tiles": tiles, "base": tiles.duplicate()}
	_scatter(cx, cy, biome)
	if cx == 0 and cy == 0:
		_shape_island()
	if biome == "river":
		var center := _chunk_center(cx, cy)
		bridges.append({
			"ck": ck,
			"x": center.x,
			"y": center.y,
			"progress": 0,
			"need": 6,
			"bones": 0,
			"done": false,
		})
	_mark_dirty(ck)


func _fill_tiles(cx: int, cy: int, biome: String, axis: String) -> PackedByteArray:
	var spec: Dictionary = biome_by_id.get(biome, {})
	var base := Catalog.TILE_GRASS
	if biome == "hills" or biome == "mountain":
		base = Catalog.TILE_DIRT
	elif biome == "bloom":
		base = Catalog.TILE_BLOOM
	var tiles := PackedByteArray()
	tiles.resize(Catalog.CHUNK * Catalog.CHUNK)
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := base
			var water := false
			if biome == "river" and (axis == "v" or axis == "both") and lx >= 13 and lx <= 18:
				water = true
			if biome == "river" and (axis == "h" or axis == "both") and ly >= 13 and ly <= 18:
				water = true
			if water:
				tile = Catalog.TILE_WATER
			elif _rand(cx, cy, lx, ly, 11) < float(spec.get("mountain", 0.0)):
				tile = Catalog.TILE_MOUNTAIN
			elif _rand(cx, cy, lx, ly, 12) < float(spec.get("rubble", 0.0)):
				tile = Catalog.TILE_RUBBLE
			tiles[ly * Catalog.CHUNK + lx] = tile
	return tiles


func _scatter(cx: int, cy: int, biome: String) -> void:
	var spec: Dictionary = biome_by_id.get(biome, {})
	var ck := _ck(cx, cy)
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(chunks[ck].tiles[ly * Catalog.CHUNK + lx])
			if tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_VOID:
				continue
			var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if _rand(cx, cy, lx, ly, 1) < float(spec.get("tree", 0.0)):
				_add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0)
			elif _rand(cx, cy, lx, ly, 2) < float(spec.get("ore", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 2, 1)
			elif _rand(cx, cy, lx, ly, 3) < float(spec.get("rock", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 0)
			elif _rand(cx, cy, lx, ly, 4) < float(spec.get("super", 0.0)):
				_add_feature(Catalog.FEAT_SUPER, wx, wy, 1, 2)
			elif _rand(cx, cy, lx, ly, 5) < float(spec.get("node", 0.0)):
				_add_feature(Catalog.FEAT_NODE, wx, wy, 1, 1)
			elif _rand(cx, cy, lx, ly, 6) < float(spec.get("flower", 0.0)):
				_add_feature(Catalog.FEAT_FLOWER, wx, wy, 1, 0)


func _island_reach() -> float:
	return 122.0 + float(land_tier) * 36.0


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
			var ang := atan2(wy - 256.0, wx - 256.0)
			var wobble := sin(ang * 3.0) * 34.0 + sin(ang * 5.0 + 1.3) * 16.0
			var land := _dist_point(256.0, 256.0, wx, wy) <= reach + wobble
			var idx := ly * Catalog.CHUNK + lx
			var tile := int(tiles[idx])
			if land:
				if tile == Catalog.TILE_WATER or tile == Catalog.TILE_VOID:
					tiles[idx] = Catalog.TILE_GRASS
					fresh.append(Vector2(wx, wy))
					changed = true
			elif not keep.has("%d,%d" % [lx, ly]) and tile != Catalog.TILE_VOID:
				tiles[idx] = Catalog.TILE_VOID
				changed = true
	if not changed:
		return
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
		if int(tiles[sy * Catalog.CHUNK + sx]) == Catalog.TILE_VOID:
			_kill_feature(feat)
	for spot in fresh:
		if _dist_point(256.0, 256.0, spot.x, spot.y) < 80.0:
			continue
		var fx := _cell_of(spot.x)
		var fy := _cell_of(spot.y)
		var roll := _rand(0, 0, fx, fy, 22)
		if roll < 0.05:
			_add_feature(Catalog.FEAT_TREE, spot.x, spot.y, 1, 0)
		elif roll < 0.09:
			_add_feature(Catalog.FEAT_FLOWER, spot.x, spot.y, 1, 0)
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
		if _dist_point(256.0, 256.0, float(feat.x), float(feat.y)) < 80.0:
			doomed.append(feat)
	for feat in doomed:
		_kill_feature(feat)


func _add_feature(kind: int, x: float, y: float, hp: int, ore: int) -> Dictionary:
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
	var it := {"id": id, "kind": kind, "x": x, "y": y, "value": value, "held": false, "dead": false}
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
		"dead": false,
	}
	buildings.append(b)
	building_by_id[id] = b
	return b


func _remove_building(b: Dictionary) -> void:
	b.dead = true
	building_by_id.erase(int(b.id))
	var occ := int(b.occupant)
	if occ >= 0 and occ < claim.size():
		claim[occ] = -1


func _consume_kind(kind: int, count: int, near_x: float, near_y: float) -> bool:
	if count <= 0:
		return true
	var found: Array = []
	for it in items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		found.append(it)
	if found.size() < count:
		return false
	found.sort_custom(func(a, b):
		var da := _dist_point(near_x, near_y, float(a.x), float(a.y))
		var db := _dist_point(near_x, near_y, float(b.x), float(b.y))
		return da < db
	)
	for i in count:
		found[i].dead = true
	return true


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


func _nearest_building_kinds(x: float, y: float, kinds: Array, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for b in buildings:
		if b.dead or not kinds.has(int(b.kind)):
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
		if fed[int(id)] < 50.0 or amused[int(id)] < 50.0 or clean[int(id)] < 50.0:
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
	return 2


func _has_factory() -> bool:
	for b in buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			return true
	return false


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
		"cannon": false,
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
	if cx == 1 and cy == 0:
		return "grove"
	if cx == 4 and cy == 0:
		return "mountain"
	if _pmod(cx, 3) == 2 or _pmod(cy, 4) == 3:
		return "river"
	var land: Array = []
	for biome in biomes:
		if str(biome.id) != "river":
			land.append(str(biome.id))
	if land.is_empty():
		return "meadow"
	var h := absi((cx * 73856093) ^ (cy * 19349663) ^ int(world_seed))
	var pick := str(land[h % land.size()])
	if pick == "mountain" and maxi(absi(cx), absi(cy)) <= 2:
		return "hills" if biome_by_id.has("hills") else "meadow"
	return pick


func _biome_of(cx: int, cy: int) -> String:
	var ck := _ck(cx, cy)
	if chunks.has(ck):
		return str(chunks[ck].biome)
	return _biome_formula(cx, cy)


func _river_axis(cx: int, cy: int) -> String:
	var vertical := _pmod(cx, 3) == 2
	var horizontal := _pmod(cy, 4) == 3
	if vertical and horizontal:
		return "both"
	if vertical:
		return "v"
	return "h"


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
	if living != 3:
		errors.append("start living %s" % living)
	if not bool(unlocks.camera):
		errors.append("camera locked at start")
	if bool(unlocks.axe):
		errors.append("axe early")
	fed[0] = 100.0
	amused[0] = 100.0
	clean[0] = 100.0
	cool[0] = 0.0
	_step(0.2)
	if living < 4:
		errors.append("mitosis living %s" % living)
	if not bool(unlocks.camera):
		errors.append("camera locked after 4")
	_reveal(2, 0)
	if str(chunks["2,0"].biome) != "river":
		errors.append("biome " + str(chunks["2,0"].biome))
	if not bool(unlocks.axe):
		errors.append("axe locked")
	if not _blocked(2.0 * 512.0 + 16.0 * 16.0 + 8.0, 256.0):
		errors.append("water walkable")
	_reveal(1, 0)
	var tree := {}
	for feat in features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE and int(feat.cx) == 1:
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
	print("SMOKE " + ("OK" if errors.is_empty() else "FAIL"))
	for err in errors:
		print(" - " + str(err))
	get_tree().quit(0 if errors.is_empty() else 1)
