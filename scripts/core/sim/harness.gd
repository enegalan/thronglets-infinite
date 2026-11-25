class_name SimHarness
extends RefCounted

## Smoke shots, factory checks, and automated assertion suite.

var sim


## Stores the simulation server used for harness side effects.
func _init(sim_ref) -> void:
	sim = sim_ref

## Cheat spawn of living agents around a point for stress tests and local population bursts.
func debug_spawn(amount: int, around: Vector2) -> void:
	var rx = 360.0 + sqrt(float(maxi(0, amount))) * 8.0
	var ry = 220.0 + sqrt(float(maxi(0, amount))) * 5.0
	for _n in amount:
		if sim.slot_count >= Catalog.MAX_SLOTS:
			break
		var x = around.x + randf_range(-rx, rx)
		var y = around.y + randf_range(-ry, ry)
		if sim.collision._blocked(x, y):
			x = around.x + randf_range(-rx * 0.3, rx * 0.3)
			y = around.y + randf_range(-ry * 0.3, ry * 0.3)
		sim.world_entities._push_slot(x, y, 80.0, 80.0, 80.0, 8.0, randi() % Catalog.TINTS.size())
	sim.spatial._rebuild_hash()
	sim.notes.append("ENJAMBRE DE PRUEBA: %d" % sim.living)



## Fills the island with buildings, loot, and worn paths to benchmark rendering and pathfinding load.
func debug_perf_busy(around: Vector2, scale: int = 1) -> Dictionary:
	# Populate a mid-game-like island so perf measures props/paths/AI seeks, not an empty field.
	# scale=1 ≈ early mid-game; scale=3+ packs many more props/paths for stress.
	scale = maxi(1, scale)
	for info in Catalog.BUILD_INFO.values():
		sim.unlocks[str(info.unlock)] = true
	for key in ["axe", "mine", "factory", "factory2", "theatre", "nuke", "bug"]:
		sim.unlocks[key] = true
	sim.gems = maxi(sim.gems, 500)
	var placed_bld = 0
	var placed_item = 0
	var placed_path = 0
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
		var ox = float((s % 3) - 1) * 220.0
		var oy = float((s / 3) - (scale / 6)) * 180.0
		for row in base_plan:
			# Only one market: keep the first, skip extras.
			if int(row[0]) == Catalog.BLD_MARKET and s > 0:
				continue
			var off: Vector2 = row[1]
			plan.append([row[0], Vector2(off.x + ox, off.y + oy)])
	for row in plan:
		var kind = int(row[0])
		var off2: Vector2 = row[1]
		var at = Catalog.snap_world(around.x + off2.x, around.y + off2.y)
		if sim.world_entities._try_add_building_near(kind, at.x, at.y):
			placed_bld += 1
	var loot: Array = [
		[Catalog.ITEM_APPLE, 18 * scale],
		[Catalog.ITEM_BALL, 8 * scale],
		[Catalog.ITEM_WOOD, 24 * scale],
		[Catalog.ITEM_BONE, 10 * scale],
		[Catalog.ITEM_ORE, 12 * scale],
	]
	var spread = 200.0 + float(scale - 1) * 80.0
	for row2 in loot:
		var ikind = int(row2[0])
		var n = int(row2[1])
		for _i in n:
			var ix = around.x + randf_range(-spread, spread)
			var iy = around.y + randf_range(-spread * 0.7, spread * 0.7)
			if sim.collision._blocked(ix, iy):
				ix = around.x + randf_range(-80.0, 80.0)
				iy = around.y + randf_range(-80.0, 80.0)
			sim.world_entities._add_item(ikind, ix, iy, 1)
			placed_item += 1
	# Stamp worn paths in a cross + grid so path sprites stress the draw path.
	var origin = sim.spatial._cell_vec(around.x, around.y)
	var path_r = 10 + 6 * (scale - 1)
	var side_r = 4 + 2 * (scale - 1)
	for i in range(-path_r, path_r + 1):
		for cell in [origin + Vector2i(i, 0), origin + Vector2i(0, i)]:
			var key = "%d,%d" % [cell.x, cell.y]
			if int(sim.wear.get(key, 0)) < sim.WEAR_NEED:
				sim.wear[key] = sim.WEAR_NEED
				sim.paths._mark_path(cell)
				placed_path += 1
		if absi(i) % 3 == 0:
			for j in range(-side_r, side_r + 1):
				var side = origin + Vector2i(i, j)
				var skey = "%d,%d" % [side.x, side.y]
				if int(sim.wear.get(skey, 0)) < sim.WEAR_NEED:
					sim.wear[skey] = sim.WEAR_NEED
					sim.paths._mark_path(side)
					placed_path += 1
	sim.world_entities._rebuild_kind_indexes()
	sim.spatial._rebuild_hash()
	sim.paint_epoch += 1
	sim.notes.append("PERF BUSY x%d: bld=%d item=%d path=%d" % [scale, placed_bld, placed_item, placed_path])
	return {"scale": scale, "buildings": placed_bld, "items": placed_item, "paths": placed_path}



## Building kind rows used by the goo comparison screenshot harness.
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



## Paints grass under a building footprint for clean capture staging.
func _shot_force_pad(kind: int, x: float, y: float) -> Vector2:
	var at = Catalog.snap_world(x, y)
	for cell in sim.building_sim._footprint_cells(at.x, at.y, Catalog.footprint_for_building(kind)):
		sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_GRASS, true)
	return at



## Marks a staged building footprint with pollution goo tiles.
func _shot_paint_building_goo(b: Dictionary) -> void:
	for cell in sim.building_sim._footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
		sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_GOO, false)
	sim.goo_count = sim.world_entities._count_goo()



## Runs mop over every footprint cell of a staged building for capture.
func _shot_mop_building(b: Dictionary) -> void:
	# Sweep the mop over every footprint cell (mines exceed one MOP_RADIUS).
	for cell in sim.building_sim._footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
		var at = sim.world_entities._cell_world(cell)
		sim.player_tools._mop(at.x, at.y)



## Activates a staged building with guests, factory ore, or mine buffer for shots.
func _shot_activate_building(b: Dictionary) -> void:
	var kind = int(b.kind)
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or kind == Catalog.BLD_THEATRE:
		var tid = sim.world_entities._push_slot_quiet(float(b.x) + 400.0, float(b.y) + 400.0, 90.0, 90.0, 90.0, 90.0, 0)
		if tid < 0:
			b.active = true
			return
		b.guests = [{"id": tid, "left": 99.0}]
		if tid < sim.link_guest.size():
			sim.link_guest[tid] = int(b.id)
		b.active = true
		return
	b.active = true
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		_shot_fill_factory(b)
		b.timer = sim.building_sim._factory_cycle_time(kind) * 0.4
	elif sim.building_sim._is_mine_kind(kind):
		b.buffer = maxi(1, int(b.get("buffer", 0)))



## Places idle, active, and goo columns of one kind for overlay alignment captures.
func _shot_place_bld_row(kind: int) -> Dictionary:
	# Left idle | mid active | right goo. Same kind for overlay alignment checks.
	_clear_shot_props()
	var size = Catalog.footprint_for_building(kind)
	var gap = float(size.x + 2) * float(Catalog.TILE)
	var cy = 256.0
	var spots = [
		Catalog.snap_world(256.0 - gap, cy),
		Catalog.snap_world(256.0, cy),
		Catalog.snap_world(256.0 + gap, cy),
	]
	var out = {"idle": {}, "active": {}, "goo": {}, "focus": Vector2(256.0, cy)}
	var keys = ["idle", "active", "goo"]
	for i in keys.size():
		var at: Vector2 = spots[i]
		at = _shot_force_pad(kind, at.x, at.y)
		var b: Dictionary = sim.world_entities._add_building(kind, at.x, at.y)
		if b.is_empty():
			# Nudge a little if bind failed on the first try.
			for n in 8:
				var nx = at.x + float((n % 4) - 1) * float(Catalog.TILE)
				var ny = at.y + float(int(n / 4) - 1) * float(Catalog.TILE)
				_shot_force_pad(kind, nx, ny)
				b = sim.world_entities._add_building(kind, nx, ny)
				if not b.is_empty():
					break
		if b.is_empty():
			out["error"] = "place %s col=%s" % [kind, keys[i]]
			return out
		out[keys[i]] = b
	_shot_activate_building(out.active)
	_shot_paint_building_goo(out.goo)
	var span = gap + float(size.x) * float(Catalog.TILE) * 0.75
	sim.shot_focus = out.focus
	sim.shot_span = maxf(120.0, span)
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	return out



## Screenshot setup: unlocks major buildings and frames the goo comparison scene.
func _prep_shot_bld_goo() -> void:
	# Capture harness places each idle|active|goo row and the mop pair.
	sim.unlocks.dwelling = true
	sim.unlocks.fancy = true
	sim.unlocks.theatre = true
	sim.unlocks.mine = true
	sim.unlocks.mine2 = true
	sim.unlocks.factory = true
	sim.unlocks.factory2 = true
	sim.unlocks.mop = true
	_clear_shot_props()
	sim.shot_focus = Vector2(256.0, 256.0)
	sim.shot_span = 140.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.smoke_hold = true
	print("SHOT BLD GOO READY")



## Stages neglect corpse, living thronglet, and splash-kill blood for capture.
func _prep_shot_blood() -> void:
	_clear_shot_props()
	# Left: neglect corpse (no blood). Mid: living. Right: splash-kill corpse + Throng_Prop_Blood_A.
	var ax = 256.0
	var ay = 256.0
	var neglect_id = sim.world_entities._push_slot(ax - 48.0, ay, 90.0, 90.0, 90.0, 90.0, 0)
	var living_id = sim.world_entities._push_slot(ax, ay, 90.0, 90.0, 90.0, 90.0, 1)
	var splash_id = sim.world_entities._push_slot(ax + 48.0, ay, 90.0, 90.0, 90.0, 90.0, 2)
	if neglect_id >= 0:
		sim.dir_x[neglect_id] = 1.0
		sim.dir_y[neglect_id] = 0.0
		sim.world_entities._become_corpse(neglect_id, false)
	if living_id >= 0:
		sim.dir_x[living_id] = 0.0
		sim.dir_y[living_id] = 0.0
		sim.act[living_id] = 0
	if splash_id >= 0:
		sim.dir_x[splash_id] = -1.0
		sim.dir_y[splash_id] = 0.0
		sim.player_tools._splash_kill(sim.pos_x[splash_id], sim.pos_y[splash_id], 8.0)
	sim.peak = maxi(sim.peak, 3)
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 80.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.smoke_hold = true
	sim.spatial._rebuild_hash()
	print("SHOT BLOOD READY neglect=%s living=%s splash=%s bloody=%s/%s/%s" % [
		neglect_id,
		living_id,
		splash_id,
		int(sim.bloody[neglect_id]) if neglect_id >= 0 else -1,
		int(sim.bloody[living_id]) if living_id >= 0 else -1,
		int(sim.bloody[splash_id]) if splash_id >= 0 else -1,
	])



## Stages scrubbing versus post-wash happy and clean VFX for sponge shots.
func _prep_shot_wash() -> void:
	_clear_shot_props()
	# Left: ACT_WASH + bubbles on body. Right: post-wash Happy stand + one CLEAN burst.
	var ax = 256.0
	var ay = 256.0
	var scrub_id = sim.world_entities._push_slot(ax - 36.0, ay, 90.0, 90.0, 20.0, 90.0, 0)
	var done_id = sim.world_entities._push_slot(ax + 36.0, ay, 90.0, 90.0, 100.0, 90.0, 1)
	if scrub_id >= 0:
		sim.dir_x[scrub_id] = 0.0
		sim.dir_y[scrub_id] = 0.0
		sim.act[scrub_id] = sim.ACT_WASH
		sim.act_t[scrub_id] = 0.85
		sim.clean[scrub_id] = 40.0
		sim.sponge_id = scrub_id
		sim.sponge_hold = 1.0
	if done_id >= 0:
		sim.dir_x[done_id] = 0.0
		sim.dir_y[done_id] = 0.0
		sim.act[done_id] = 0
		sim.clean[done_id] = 100.0
		sim.world_entities._ensure_agent_timers(done_id)
		sim.cheer_t[done_id] = sim.WASH_FX_LIFE
		sim.player_tools._pop_wash_sparkle(done_id)
	sim.peak = maxi(sim.peak, 2)
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 72.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.unlocks.sponge = true
	sim.smoke_hold = true
	sim.spatial._rebuild_hash()
	print("SHOT WASH READY scrub=%s done=%s" % [scrub_id, done_id])



## Stages stand, walk, and kick ball poses for play animation regression.
func _prep_shot_ball() -> void:
	_clear_shot_props()
	# Left: Default stand. Mid: content Happy_Walk + ball claim (bug was 1.0 scale).
	# Right: kick pop of ICON_BALL beside still Happy.
	var ax = 256.0
	var ay = 256.0
	var stand_id = sim.world_entities._push_slot(ax - 48.0, ay, 95.0, 95.0, 95.0, 95.0, 0)
	var walk_id = sim.world_entities._push_slot(ax, ay, 95.0, 95.0, 95.0, 95.0, 1)
	var kick_id = sim.world_entities._push_slot(ax + 48.0, ay, 95.0, 95.0, 95.0, 95.0, 2)
	var ball = sim.world_entities._add_item(Catalog.ITEM_BALL, ax + 10.0, ay - 8.0, 1)
	if stand_id >= 0:
		sim.dir_x[stand_id] = 0.0
		sim.dir_y[stand_id] = 0.0
		sim.act[stand_id] = 0
	if walk_id >= 0:
		sim.dir_x[walk_id] = 1.0
		sim.dir_y[walk_id] = 0.0
		sim.act[walk_id] = sim.ACT_PLAY
		sim.act_t[walk_id] = 0.55
		if not ball.is_empty():
			sim.agent_tick._claim_item(walk_id, ball)
	if kick_id >= 0:
		sim.dir_x[kick_id] = 0.0
		sim.dir_y[kick_id] = 0.0
		sim.act[kick_id] = sim.ACT_PLAY
		sim.act_t[kick_id] = 0.55
		if not ball.is_empty():
			sim.link_ball[kick_id] = int(ball.id)
		sim.dialogue._pop(sim.pos_x[kick_id], sim.pos_y[kick_id] - 6.0, Catalog.ICON_BALL, Catalog.BALL_SPRITE_SCALE)
	sim.peak = maxi(sim.peak, 3)
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 80.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.unlocks.ball = true
	sim.smoke_hold = true
	sim.spatial._rebuild_hash()
	print("SHOT BALL READY stand=%s walk=%s kick=%s ball=%s" % [
		stand_id, walk_id, kick_id, int(ball.get("id", -1)) if not ball.is_empty() else -1,
	])



## Stages filthy walking versus held thronglet for cleanliness UI capture.
func _prep_shot_dirt() -> void:
	_clear_shot_props()
	# Two filthy thronglets at default zoom: left walks, right is held (Default body).
	var ax = 256.0
	var ay = 256.0
	var walk_id = sim.world_entities._push_slot(ax - 28.0, ay, 90.0, 90.0, 0.0, 0.0, 0)
	var held_id = sim.world_entities._push_slot(ax + 28.0, ay, 90.0, 90.0, 0.0, 0.0, 1)
	if walk_id >= 0:
		sim.fed[walk_id] = 90.0
		sim.amused[walk_id] = 90.0
		sim.clean[walk_id] = 0.0
		sim.dir_x[walk_id] = 1.0
		sim.dir_y[walk_id] = 0.0
		sim.act[walk_id] = 0
		sim.act_t[walk_id] = 0.0
	if held_id >= 0:
		sim.fed[held_id] = 90.0
		sim.amused[held_id] = 90.0
		sim.clean[held_id] = 0.0
		sim.dir_x[held_id] = 0.0
		sim.dir_y[held_id] = 0.0
		sim.act[held_id] = 0
		sim.act_t[held_id] = 0.0
		sim.held_kind = "thronglet"
		sim.held_ref = held_id
		sim.shot_throng = held_id
	sim.peak = maxi(sim.peak, 2)
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 64.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.smoke_hold = true
	sim.spatial._rebuild_hash()
	print("SHOT DIRT READY walk=%s held=%s clean_w=%.0f clean_h=%.0f" % [
		walk_id, held_id,
		sim.clean[walk_id] if walk_id >= 0 else -1.0,
		sim.clean[held_id] if held_id >= 0 else -1.0,
	])



## Stages low mixed needs HUD with nearby apple and ball props.
func _prep_shot_needs() -> void:
	_clear_shot_props()
	# One thronglet with mixed needs so the HUD card matches the video card.
	var ax = 256.0
	var ay = 256.0
	sim.shot_throng = sim.world_entities._push_slot(ax, ay, 18.0, 62.0, 12.0, 0.0, 0)
	if sim.shot_throng >= 0:
		# First capture (needs_low) matches video 68:00; second bumps to full cyan.
		sim.fed[sim.shot_throng] = 18.0
		sim.amused[sim.shot_throng] = 0.0
		sim.clean[sim.shot_throng] = 0.0
		sim.dir_x[sim.shot_throng] = 0.0
		sim.dir_y[sim.shot_throng] = 0.0
		sim.act[sim.shot_throng] = 0
		sim.act_t[sim.shot_throng] = 0.0
		sim.peak = maxi(sim.peak, 1)
	sim.world_entities._add_item(Catalog.ITEM_APPLE, ax + 18.0, ay + 4.0, 1)
	sim.world_entities._add_item(Catalog.ITEM_BALL, ax + 40.0, ay - 6.0, 1)
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 72.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.unlocks.apple = true
	sim.unlocks.ball = true
	sim.unlocks.sponge = true
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	print("SHOT NEEDS READY throng=%s fed=%.0f amused=%.0f clean=%.0f" % [
		sim.shot_throng,
		sim.fed[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
		sim.amused[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
		sim.clean[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
	])



## Stages hungry pair and three-bite apple for eating animation capture.
func _prep_shot_apple() -> void:
	_clear_shot_props()
	# Two hungry thronglets and one apple with 3 bites.
	var ax = 256.0
	var ay = 256.0
	var apple = sim.world_entities._add_item(Catalog.ITEM_APPLE, ax, ay, 1)
	apple.air = 0.0
	apple.fixed = false
	apple.bites_left = 3
	apple.bite = 0.0
	var a = sim.world_entities._push_slot(ax - 10.0, ay, 20.0, 80.0, 80.0, 0.0, 0)
	var b = sim.world_entities._push_slot(ax + 64.0, ay + 8.0, 95.0, 80.0, 80.0, 0.0, 1)
	# a is very hungry and close -> eats first bite. b is satisfied for now.
	if a >= 0:
		sim.fed[a] = 20.0
		sim.hungry_t[a] = 5.0
		sim.dir_x[a] = 0.0
		sim.dir_y[a] = 0.0
		sim.act[a] = 0
		sim.act_t[a] = 0.0
	if b >= 0:
		sim.fed[b] = 95.0
		sim.hungry_t[b] = 0.0
		sim.dir_x[b] = 0.0
		sim.dir_y[b] = 0.0
		sim.act[b] = 0
		sim.act_t[b] = 0.0
	sim.shot_focus = Vector2(ax, ay)
	sim.shot_span = 56.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.unlocks.apple = true
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	print("SHOT APPLE READY a=%s b=%s apple_bites=%s" % [a, b, apple.get("bites_left", -1)])



## Stages wood, bone, and ore carry poses beside ground haul items.
func _prep_shot_carry() -> void:
	_clear_shot_props()
	var rows = [
		{"item": Catalog.ITEM_WOOD, "carry": Catalog.CARRY_WOOD, "x": 220.0},
		{"item": Catalog.ITEM_BONE, "carry": Catalog.CARRY_BONE, "x": 256.0},
		{"item": Catalog.ITEM_ORE, "carry": Catalog.CARRY_ORE, "x": 292.0},
	]
	var focus = Vector2(256.0, 256.0)
	for row in rows:
		var gx = float(row.x)
		sim.world_entities._add_item(int(row.item), gx, 248.0, 1)
		var id = sim.world_entities._push_slot(gx, 268.0, 90.0, 90.0, 90.0, 0.0, 0)
		if id < 0:
			continue
		sim.world_entities._set_carry(id, int(row.carry), 1)
		sim.dir_x[id] = 0.0
		sim.dir_y[id] = 0.0
		sim.act[id] = 0
		sim.act_t[id] = 0.0
		if sim.shot_throng < 0:
			sim.shot_throng = id
	sim.shot_focus = focus
	sim.shot_span = 72.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	print("SHOT CARRY READY throng=%s items=%s living=%s" % [sim.shot_throng, sim.items.size(), sim.living])



## Plants an isolated roundabout framed for carousel idle capture.
func _prep_shot_round() -> void:
	_clear_shot_props()
	sim.unlocks.roundabout = true
	var at = Catalog.snap_world(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		var fdx = float(feat.x) - at.x
		var fdy = float(feat.y) - at.y
		if sqrt(fdx * fdx + fdy * fdy) < 80.0:
			feat.dead = true
	var round_b = sim.world_entities._add_building(Catalog.BLD_ROUND, at.x, at.y)
	if round_b.is_empty():
		for attempt in 40:
			var px = at.x + float((attempt % 8) - 4) * 16.0
			var py = at.y + float(int(attempt / 8) - 2) * 16.0
			if sim.building_sim._building_spot_free(-1, px, py, Catalog.BLD_ROUND):
				round_b = sim.world_entities._add_building(Catalog.BLD_ROUND, px, py)
				if not round_b.is_empty():
					at = Vector2(float(round_b.x), float(round_b.y))
					break
	if round_b.is_empty():
		print("SHOT ROUND FAIL no roundabout")
		return
	# Idle frame first: carousel planted, nobody near, must stay still.
	sim.shot_focus = at + Catalog.ROUND_RIDE_OFF
	sim.shot_span = 56.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	print("SHOT ROUND READY at=(%.1f,%.1f) id=%s" % [at.x, at.y, str(round_b.get("id", -1))])



## Fills the smoke island with buildings, items, features, path wear, and factory.
func _prep_shot_world() -> void:
	_clear_shot_props()
	var taken = {}
	var missed: Array = []
	var buildings_to_place = [
		Catalog.BLD_FACTORY, Catalog.BLD_MARKET, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_DWELL,
		Catalog.BLD_FANCY, Catalog.BLD_APPLE, Catalog.BLD_TUB,
		Catalog.BLD_ROUND, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD,
	]
	for kind in buildings_to_place:
		var at = _shot_spot(taken, Catalog.footprint_for_building(kind))
		if at.x < 0.0 or sim.world_entities._add_building(kind, at.x, at.y).is_empty():
			missed.append("building %s" % kind)
	for kind in [Catalog.ITEM_APPLE, Catalog.ITEM_BALL, Catalog.ITEM_WOOD, Catalog.ITEM_BONE, Catalog.ITEM_ORE, Catalog.ITEM_TNT, Catalog.ITEM_EGG]:
		var at = _shot_spot(taken, Vector2i(1, 1), 0, 24.0, 1)
		if at.x < 0.0:
			missed.append("item %s" % kind)
			continue
		var it = sim.world_entities._add_item(kind, at.x, at.y, 1)
		it.air = 0.0
		it.fixed = true
	var features_to_place = [
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
		var kind = int(spec.kind)
		var size = Catalog.footprint_for_feature(kind)
		var halo = 0 if size == Vector2i(1, 1) else 1
		var at = _shot_spot(taken, size, halo, 40.0, 1)
		if at.x < 0.0 or _shot_add_feature(kind, at.x, at.y, int(spec.ore)).is_empty():
			missed.append("feature %s" % kind)
	sim.shot_throng = sim.world_entities._push_slot(200.0, 300.0, 55.0, 70.0, 8.0, 0.0, 0)
	if sim.shot_throng >= 0:
		sim.peak = maxi(sim.peak, 1)
	for b in sim.buildings:
		if int(b.kind) == Catalog.BLD_FACTORY:
			_shot_fill_factory(b)
			sim.shot_factory = int(b.id)
			break
	if sim.shot_factory < 0:
		var at = _shot_spot(taken, Catalog.footprint_for_building(Catalog.BLD_FACTORY), 0, 16.0, 0)
		if at.x >= 0.0:
			var placed = sim.world_entities._add_building(Catalog.BLD_FACTORY, at.x, at.y)
			if not placed.is_empty():
				_shot_fill_factory(placed)
				sim.shot_factory = int(placed.id)
	var path_cells = _stamp_shot_path()
	sim.shot_focus = Vector2(256, 256)
	sim.shot_span = sim.island_gen.island_reach() + 48.0
	sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
	sim.unlocks.bathtub = true
	sim.unlocks.apple_tree = true
	sim.unlocks.roundabout = true
	sim.unlocks.axe = true
	sim.unlocks.hammer = true
	sim.unlocks.dwelling = true
	sim.unlocks.bug = true
	sim.gems = 20
	sim.unlock_serial += 1
	sim.notes.clear()
	sim.sfx_queue.clear()
	sim.pops.clear()
	sim.barks.clear()
	sim.modal = {}
	sim.frozen = false
	sim.spatial._rebuild_hash()
	sim.smoke_hold = true
	print("SHOT READY buildings=%s features=%s items=%s factory=%s path=%s missed=%s" % [sim.buildings.size(), sim.features.size(), sim.items.size(), sim.shot_factory, path_cells, missed])



## Tests whether a grass cell can host shot path stamping without void neighbors.
func _shot_open_grass(cell: Vector2i) -> bool:
	if sim.building_cell.has(cell) or sim.feature_cell.has(cell):
		return false
	var at = Catalog.cell_world(cell)
	if sim.collision._tile_at(at.x, at.y) != Catalog.TILE_GRASS:
		return false
	for spot in [cell + Vector2i(1, 0), cell + Vector2i(-1, 0), cell + Vector2i(0, 1), cell + Vector2i(0, -1)]:
		var around = Catalog.cell_world(spot)
		if sim.collision._tile_at(around.x, around.y) == Catalog.TILE_VOID:
			return false
	return true



## Carves and marks worn footpath cells for the world overview shot.
func _stamp_shot_path() -> int:
	var origin = Vector2i(-1, -1)
	var best = -1
	for y in range(8, 24):
		for x in range(6, 22):
			var open = true
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
			var at = Catalog.cell_world(Vector2i(x + 3, y + 1))
			var score = 999999
			for b in sim.buildings:
				if b.dead:
					continue
				score = mini(score, int(sim.spatial._dist_point(at.x, at.y, float(b.x), float(b.y))))
			for feat in sim.features:
				if feat.dead:
					continue
				score = mini(score, int(sim.spatial._dist_point(at.x, at.y, float(feat.x), float(feat.y))))
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
		sim.wear["%d,%d" % [cell.x, cell.y]] = sim.WEAR_NEED
		sim.paths._mark_path(cell)
	sim.shot_path = Catalog.cell_world(origin + Vector2i(3, 1))
	return cells.size()



## Clears features, buildings, items, and agents for a fresh capture sandbox.
func _clear_shot_props() -> void:
	sim.features.clear()
	sim.feature_by_id.clear()
	sim.feature_cell.clear()
	sim.buildings.clear()
	sim.building_by_id.clear()
	sim.building_cell.clear()
	sim.items.clear()
	sim.item_by_id.clear()
	sim.tree_seeds.clear()
	for i in sim.slot_count:
		sim.state[i] = Catalog.ST_VACANT
	sim.living = 0
	sim.hand_id = -1
	sim.player_tools._clear_held()
	sim.world_entities._rebuild_kind_indexes()
	sim.building_sim._invalidate_factory_cache()
	sim.world_entities._invalidate_walk_cells()



## Finds a non-overlapping grass anchor on the shot island for a footprint.
func _shot_spot(taken: Dictionary, size: Vector2i, halo: int = 1, margin: float = 40.0, skirt: int = 0) -> Vector2:
	var reach = sim.island_gen.island_reach() - margin
	for y in range(6, 27):
		for x in range(6, 27):
			var anchor = Vector2i(x, y)
			var world = Catalog.cell_world(anchor)
			var cells = sim.building_sim._footprint_cells(world.x, world.y, size)
			var ok = true
			for cell in cells:
				if taken.has(cell):
					ok = false
					break
				var at = Catalog.cell_world(cell)
				if sim.spatial._dist_point(256.0, 256.0, at.x, at.y) > reach or not sim.collision._tile_holds(at.x, at.y):
					ok = false
					break
				for oy in range(-skirt, skirt + 1):
					for ox in range(-skirt, skirt + 1):
						var around = Catalog.cell_world(cell + Vector2i(ox, oy))
						if not sim.collision._tile_holds(around.x, around.y):
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



## Adds a rooted feature for capture layout without campaign placement rules.
func _shot_add_feature(kind: int, x: float, y: float, ore: int) -> Dictionary:
	var id = sim.next_feature_id
	sim.next_feature_id += 1
	var c = sim.spatial._chunk_at(x, y)
	var feat = {
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
	if not sim.world_entities._bind_feature_at(feat, x, y):
		return {}
	sim.features.append(feat)
	sim.feature_by_id[id] = feat
	return feat



## Searches hints then the home chunk for a valid building site in tests.
func _smoke_find_spot(kind: int, hints: Array) -> Vector2:
	for spot in hints:
		var at: Vector2 = spot
		if sim.player_tools.can_place_building(kind, at.x, at.y):
			return Catalog.snap_world(at.x, at.y)
	for ly in range(4, Catalog.CHUNK - 4, 2):
		for lx in range(4, Catalog.CHUNK - 4, 2):
			var wx = float(lx * Catalog.TILE + 8)
			var wy = float(ly * Catalog.TILE + 8)
			if sim.player_tools.can_place_building(kind, wx, wy):
				return Catalog.snap_world(wx, wy)
	return Vector2.ZERO



## Preloads factory pile and buffer for factory visual and smoke checks.
func _shot_fill_factory(b: Dictionary) -> void:
	var piled: Array = []
	for n in 24:
		piled.append(n + 1)
	b.pile = piled
	b.buffer = piled.size()



## Smoke assertion for factory ring wedges, delivery, pile order, and spend.
func _check_factory_fill(errors: Array) -> void:
	var factory = {}
	for b in sim.buildings:
		if b.dead:
			continue
		var kind = int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			factory = b
			break
	if factory.is_empty():
		var spot = _smoke_find_spot(Catalog.BLD_FACTORY, [
			Vector2(300.0, 300.0), Vector2(140.0, 200.0), Vector2(360.0, 180.0), Vector2(160.0, 320.0),
			Vector2(200.0, 180.0), Vector2(240.0, 340.0), Vector2(168.0, 216.0),
		])
		if spot != Vector2.ZERO:
			factory = sim.world_entities._add_building(Catalog.BLD_FACTORY, spot.x, spot.y)
	if factory.is_empty():
		for ly in range(3, Catalog.CHUNK - 3):
			for lx in range(3, Catalog.CHUNK - 3):
				var wx = float(lx * Catalog.TILE + 8)
				var wy = float(ly * Catalog.TILE + 8)
				var at = Catalog.snap_world(wx, wy)
				if not sim.building_sim._building_spot_free(-1, at.x, at.y, Catalog.BLD_FACTORY):
					continue
				factory = sim.world_entities._add_building(Catalog.BLD_FACTORY, at.x, at.y)
				if not factory.is_empty():
					break
			if not factory.is_empty():
				break
	if factory.is_empty():
		errors.append("factory fill: no building")
		return
	var main = sim.get_tree().current_scene
	var marks = null if main == null else main.get("world_marks_ui")
	if marks == null or not marks.has_method("sync_factory_mark"):
		errors.append("factory fill: no view")
		return
	factory.buffer = 0
	factory.pile = []
	factory.timer = 0.25
	main.selected_bld = int(factory.id)
	var i = 0
	sim.pos_x[i] = float(factory.x)
	sim.pos_y[i] = float(factory.y)
	var cycle = sim.building_sim._factory_cycle_time(Catalog.BLD_FACTORY)
	# Ring tracks process time, not stock: empty at cycle start, full at the end.
	sim.world_entities._set_carry(i, Catalog.CARRY_ORE, 1)
	sim.agent_tick._deliver(i, sim.MOVE_SPEED, 0.05)
	if int(factory.get("buffer", 0)) < 1:
		errors.append("factory fill: deposit failed")
		return
	factory.timer = cycle
	marks.sync_factory_mark(sim)
	var shown0 = 0
	for slice in marks.factory_slices:
		if slice.visible:
			shown0 += 1
	if shown0 != 0:
		errors.append("factory fill: expected 0 slices at cycle start got %d" % shown0)
	factory.timer = cycle * 0.5
	marks.sync_factory_mark(sim)
	var shown_mid = 0
	for slice in marks.factory_slices:
		if slice.visible:
			shown_mid += 1
	if shown_mid != sim.FACTORY_WEDGES / 2:
		errors.append("factory fill: expected %d slices at mid-cycle got %d" % [sim.FACTORY_WEDGES / 2, shown_mid])
	factory.timer = 0.0
	marks.sync_factory_mark(sim)
	var shown_end = 0
	for slice in marks.factory_slices:
		if slice.visible:
			shown_end += 1
	if shown_end != sim.FACTORY_WEDGES:
		errors.append("factory fill: expected %d slices at cycle end got %d" % [sim.FACTORY_WEDGES, shown_end])
	print("FACTORY FILL time wedges start=%d mid=%d end=%d buffer=%d" % [
		shown0, shown_mid, shown_end, int(factory.get("buffer", 0)),
	])
	# Pile still stacks beyond the ring; order is FIFO for spend.
	factory.buffer = 0
	factory.pile = []
	var deposits = sim.FACTORY_WEDGES + 2
	for step in deposits:
		sim.world_entities._set_carry(i, Catalog.CARRY_ORE, 1)
		sim.pos_x[i] = float(factory.x)
		sim.pos_y[i] = float(factory.y)
		sim.agent_tick._deliver(i, sim.MOVE_SPEED, 0.05)
	var piled: Array = factory.get("pile", [])
	var order = PackedStringArray()
	for token in piled:
		order.append(str(int(token)))
	print("FACTORY PILE " + " ".join(order))
	var want = PackedStringArray()
	for n in deposits:
		want.append(str(n + 1))
	if " ".join(order) != " ".join(want):
		errors.append("factory pile order " + " ".join(order))
	sim.building_sim._factory_spend(factory)
	var left: Array = factory.get("pile", [])
	if left.size() != deposits - 1:
		errors.append("factory pile spend")
	elif int(left[0]) != 2:
		errors.append("factory pile spend")



## Smoke assertion for DOS intro copy, tutorial signs, and opening count mark.
func _check_opening(errors: Array) -> void:
	var dos = LineBook.row("SYS.GAME_INTRO", 3)
	var clean = LineBook.row("SYS.MESSAGES", 15)
	var crt = LineBook.row("SYS.SETTINGS", 14)
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
	sim.tutorial_i = 0
	sim.count_unknown = true
	sim.dialogue.advance_tutorial()
	sim.dialogue.advance_tutorial()
	sim.dialogue.advance_tutorial()
	if sim.tutorial_i != -1:
		errors.append("tutorial end")
	sim.dialogue._know_count()
	if sim.count_unknown:
		errors.append("count mark")



## Smoke assertion for name modal validation, confirm flow, and persistence.
func _check_player_name(errors: Array) -> void:
	if str(sim.modal.get("event", "")) != "player_name":
		errors.append("name prompt missing")
		print("NAME MISSING")
		return
	sim.dialogue.submit_name("")
	var empty_log = " ".join(sim.modal.get("log", []))
	sim.dialogue.submit_name("shit")
	var banned_log = " ".join(sim.modal.get("log", []))
	sim.dialogue.submit_name("€")
	var charset_log = " ".join(sim.modal.get("log", []))
	sim.dialogue.submit_name("Ana")
	var asked = str(sim.modal.get("step", "")) == "confirm" and "Ana" in " ".join(sim.modal.get("log", []))
	sim.dialogue.choose(1)
	var declined = str(sim.modal.get("step", "")) == "ask"
	sim.dialogue.submit_name("Ana")
	sim.dialogue.choose(0)
	var echo = " ".join(sim.modal.get("log", []))
	var echoed = str(sim.modal.get("step", "")) == "echo" and ">> entrada \"Ana\"" in echo
	sim.dialogue.choose(0)
	var stored = sim.player_name == "Ana" and sim.modal.is_empty()
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



## Automated smoke suite: hatch, unlocks, buildings, movement, save, and game over.
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
	if sim.living != 0:
		errors.append("start living %s" % sim.living)
	for feat in sim.features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
			continue
		if sim.island_gen.near_spawn(float(feat.x), float(feat.y)):
			errors.append("tree in spawn clearing")
			break
	var egg = sim.world_entities._nearest_item(256.0, 256.0, Catalog.ITEM_EGG, 40.0)
	if egg.is_empty():
		errors.append("no starter egg")
	else:
		if float(egg.get("air", 0.0)) <= 0.0:
			errors.append("egg not falling")
		egg.air = 0.0
		egg.fall = 0.0
		for _n in sim.EGG_NEED:
			sim.dialogue._help_egg(egg)
		if sim.living != 1:
			errors.append("hatch living %s" % sim.living)
		if not egg.dead:
			errors.append("egg remains")
		if sim.modal.is_empty() or str(sim.modal.get("event", "")) != "first_born":
			errors.append("first_born talk missing")
		else:
			var guard = 0
			while not sim.modal.is_empty() and guard < 80:
				if str(sim.modal.get("event", "")) == "player_name":
					break
				sim.dialogue.choose(0)
				guard += 1
			_check_player_name(errors)
		if LineBook.lines_for("first_born").is_empty():
			errors.append("first_born lines missing")
		if sim.dialogue._ethics_choice("first_born") == -1:
			errors.append("first_born ethics missing")
		var again = sim.world_entities._add_item(Catalog.ITEM_EGG, 260.0, 260.0, 0)
		again.air = 0.0
		again.hatch = 0
		again.need = 1
		sim.dialogue._help_egg(again)
		if sim.living != 1:
			errors.append("second egg spawned multi")
		if not again.dead:
			errors.append("second egg remains")
	if not bool(sim.unlocks.camera):
		errors.append("camera locked at start")
	if bool(sim.unlocks.axe):
		errors.append("axe early")
	if sim.living < 1:
		errors.append("no first multi")
	else:
		sim.fed[0] = 100.0
		sim.amused[0] = 100.0
		sim.clean[0] = 100.0
		sim.cool[0] = 0.0
		sim.shake_t[0] = 0.0
		sim.mito_t[0] = 0.0
		sim.mito_charge[0] = 0.0
		for _n in 40:
			sim.fed[0] = 100.0
			sim.amused[0] = 100.0
			sim.clean[0] = 100.0
			sim.cool[0] = 0.0
			sim._step(0.2)
			if sim.living >= 2:
				break
		if sim.living < 2:
			errors.append("mitosis living %s" % sim.living)
		sim.dialogue._queue_talk("learn_self", {})
		var talk_guard = 0
		while not sim.modal.is_empty() and talk_guard < 80:
			sim.dialogue.choose(0)
			talk_guard += 1
		if LineBook.lines_for("learn_self").is_empty():
			errors.append("learn_self lines missing")
		if sim.dialogue._ethics_choice("learn_self") == -1:
			errors.append("learn_self ethics missing")
	if not bool(sim.unlocks.camera):
		errors.append("camera locked after hatch")
	sim.peak = 6
	sim.dialogue._refresh_pop_gates(false)
	if not sim.modal.is_empty():
		errors.append("quiet grant opened talk")
	if not bool(sim.unlocks.axe):
		errors.append("axe at 6")
	if bool(sim.unlocks.hammer) or bool(sim.unlocks.bathtub):
		errors.append("build before tools at 6")
	sim.trees_chopped = 1
	sim.dialogue._refresh_pop_gates(false)
	if not bool(sim.unlocks.hammer):
		errors.append("hammer after chop")
	if bool(sim.unlocks.bathtub):
		errors.append("bathtub before stump")
	sim.stumps_cleared = 1
	sim.dialogue._refresh_pop_gates(false)
	if not bool(sim.unlocks.bathtub):
		errors.append("bathtub after stump")
	if bool(sim.unlocks.apple_tree):
		errors.append("apple before tub")
	sim.peak = 12
	sim.dialogue._refresh_pop_gates(false)
	if bool(sim.unlocks.apple_tree) or bool(sim.unlocks.roundabout):
		errors.append("care builds from peak")
	if sim.island_gen.count_mine_nodes(0, 0) < 1:
		errors.append("home mine nodes missing")
	if not bool(sim.unlocks.axe):
		errors.append("axe locked")
	var tree = {}
	for feat in sim.features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE and int(feat.cx) == 0:
			tree = feat
			break
	if tree.is_empty():
		errors.append("no tree")
	else:
		var tree_at = Vector2(float(tree.x), float(tree.y))
		tree.rooted = false
		sim.player_tools.grab_at(tree_at.x, tree_at.y)
		var tree_moved = float(tree.x) != tree_at.x or float(tree.y) != tree_at.y
		if sim.held_kind == "rock" or tree_moved:
			errors.append("terrain tree movable")
		sim.player_tools.cancel_hold()
		tree.rooted = true
		sim.player_tools._chop(tree)
		if int(tree.kind) != Catalog.FEAT_STUMP or sim.world_entities.count_item(Catalog.ITEM_WOOD) < 1:
			errors.append("chop")
		sim.player_tools._hammer_feature(tree)
		if not tree.dead:
			errors.append("stump remains")
	sim.world_entities._expand_super_island(false)
	if not sim.part_two:
		errors.append("part two not reached")
	sim.island_gen.shape_island()
	var drain_i = 0
	while not sim.modal.is_empty() and drain_i < 128:
		sim.dialogue.choose(0)
		drain_i += 1
	sim.frozen = false
	sim.dialogue._restore_gaze()
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_LIVING:
			sim.pos_x[i] = 120.0
			sim.pos_y[i] = 120.0
	var ore_node = {}
	for feat in sim.features:
		if not feat.dead and int(feat.cx) == 0 and sim.building_sim._ore_tier(int(feat.kind)) > 0:
			ore_node = feat
			break
	if ore_node.is_empty():
		errors.append("no ore node for mine")
	else:
		sim.unlocks["mine"] = true
		# Keep wood outside the 6x5 mine footprint so _item_spot_free passes.
		sim.world_entities._add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 112.0, float(ore_node.y) + 96.0, 1)
		sim.world_entities._add_item(Catalog.ITEM_WOOD, float(ore_node.x) + 128.0, float(ore_node.y) + 96.0, 1)
		if not sim.player_tools.can_place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine blocked on ore node")
		elif not sim.player_tools.place_building(Catalog.BLD_MINE, float(ore_node.x), float(ore_node.y)):
			errors.append("mine place on ore node")
		elif sim.island_gen.count_mine_nodes(0, 0) < 1:
			errors.append("mine ate every ore node")
	sim.frozen = false
	var market_at = Vector2(256.0, 200.0)
	var market_ok = false
	for spot in [Vector2(256.0, 200.0), Vector2(220.0, 220.0), Vector2(280.0, 220.0), Vector2(256.0, 300.0), Vector2(180.0, 320.0), Vector2(320.0, 160.0), Vector2(160.0, 200.0), Vector2(300.0, 300.0)]:
		if sim.player_tools.can_place_building(Catalog.BLD_MARKET, spot.x, spot.y):
			market_at = spot
			market_ok = true
			break
	if not market_ok or not sim.player_tools.place_building(Catalog.BLD_MARKET, market_at.x, market_at.y):
		errors.append("market place free")
	elif sim.player_tools.place_building(Catalog.BLD_MARKET, market_at.x + 40.0, market_at.y):
		errors.append("market unique broken")
	var tub_spot = _smoke_find_spot(Catalog.BLD_TUB, [
		Vector2(200.0, 280.0), Vector2(180.0, 260.0), Vector2(220.0, 300.0),
		Vector2(140.0, 300.0), Vector2(300.0, 140.0), Vector2(340.0, 240.0), Vector2(100.0, 220.0),
	])
	if tub_spot == Vector2.ZERO or not sim.player_tools.place_building(Catalog.BLD_TUB, tub_spot.x, tub_spot.y):
		errors.append("tub place for solid")
	else:
		if not bool(sim.unlocks.apple_tree):
			errors.append("apple after tub")
		if bool(sim.unlocks.roundabout):
			errors.append("round before apple")
		if not sim.collision._blocked(tub_spot.x, tub_spot.y):
			errors.append("tub not solid")
		var rim = sim.collision._approach_building({"kind": Catalog.BLD_TUB, "x": tub_spot.x, "y": tub_spot.y, "id": -1}, -1)
		if sim.collision._blocked(rim.x, rim.y):
			errors.append("tub approach blocked")
		var apple_spot = _smoke_find_spot(Catalog.BLD_APPLE, [
			Vector2(tub_spot.x + 64.0, tub_spot.y + 48.0), Vector2(220.0, 200.0), Vector2(280.0, 280.0),
			Vector2(120.0, 280.0), Vector2(320.0, 160.0), Vector2(180.0, 340.0),
		])
		if apple_spot == Vector2.ZERO or not sim.player_tools.place_building(Catalog.BLD_APPLE, apple_spot.x, apple_spot.y):
			errors.append("apple place for unlock")
		elif not bool(sim.unlocks.roundabout):
			errors.append("round after apple")
	var dug = {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MINE:
			dug = b
			break
	if dug.is_empty():
		errors.append("mine missing for ore drop")
	else:
		var drop = sim.world_tick._loot_spot(dug)
		if sim.collision._blocked(drop.x, drop.y):
			errors.append("ore drop blocked")
		if int(sim.building_cell.get(sim.spatial._cell_vec(drop.x, drop.y), -1)) == int(dug.id):
			errors.append("ore drop on mine")
		var gate = sim.collision._approach_building(dug, 0)
		if sim.collision._blocked(gate.x, gate.y):
			errors.append("mine approach blocked")
		elif sim.state[0] == Catalog.ST_LIVING:
			var back = Vector2(sim.pos_x[0], sim.pos_y[0])
			sim.pos_x[0] = gate.x
			sim.pos_y[0] = gate.y
			sim.fed[0] = 90.0
			sim.amused[0] = 90.0
			sim.clean[0] = 90.0
			sim.world_entities._set_carry(0, Catalog.CARRY_NONE)
			sim.act[0] = 0
			sim.act_t[0] = 0.0
			sim.agent_tick._seek_mine(0, sim.MOVE_SPEED, 0.2)
			if int(sim.act[0]) != sim.ACT_WORK:
				errors.append("mine work not started")
			else:
				# Dirty thronglets must not keep working / seeking the mine.
				sim.clean[0] = 20.0
				sim.act[0] = 0
				sim.act_t[0] = 0.0
				if sim.agent_tick._seek_mine(0, sim.MOVE_SPEED, 0.2) or int(sim.act[0]) == sim.ACT_WORK:
					errors.append("dirty thronglet sought mine")
				sim.clean[0] = 90.0
				sim.act[0] = 0
				sim.act_t[0] = 0.0
				sim.agent_tick._seek_mine(0, sim.MOVE_SPEED, 0.2)
				if int(sim.act[0]) != sim.ACT_WORK:
					errors.append("mine work not resumed")
				# Cap is 2: claim the walk so a third ready thronglet cannot join.
				var helper = -1
				for hi in sim.slot_count:
					if hi != 0 and sim.state[hi] == Catalog.ST_LIVING:
						helper = hi
						break
				if helper >= 0 and int(sim.act[0]) == sim.ACT_WORK:
					var helper_back = Vector2(sim.pos_x[helper], sim.pos_y[helper])
					sim.pos_x[helper] = gate.x + 6.0
					sim.pos_y[helper] = gate.y + 6.0
					sim.fed[helper] = 90.0
					sim.amused[helper] = 90.0
					sim.clean[helper] = 90.0
					sim.world_entities._set_carry(helper, Catalog.CARRY_NONE)
					sim.agent_tick._set_mine_job(0, int(dug.id))
					sim.agent_tick._set_mine_job(helper, int(dug.id))
					sim.act[helper] = sim.ACT_WORK
					sim.act_t[helper] = 0.5
					var third = -1
					for ti in sim.slot_count:
						if ti != 0 and ti != helper and sim.state[ti] == Catalog.ST_LIVING:
							third = ti
							break
					if third >= 0:
						sim.pos_x[third] = gate.x - 10.0
						sim.pos_y[third] = gate.y - 10.0
						sim.fed[third] = 90.0
						sim.amused[third] = 90.0
						sim.clean[third] = 90.0
						sim.world_entities._set_carry(third, Catalog.CARRY_NONE)
						sim.act[third] = 0
						sim.act_t[third] = 0.0
						sim.agent_tick._set_mine_job(third, -1)
						if sim.agent_tick._seek_mine(third, sim.MOVE_SPEED, 0.2):
							errors.append("mine over capacity seek")
						if int(sim.act[third]) == sim.ACT_WORK:
							errors.append("mine over capacity work")
						if int(sim.mine_job[third]) == int(dug.id):
							errors.append("mine over capacity job")
					sim.pos_x[helper] = helper_back.x
					sim.pos_y[helper] = helper_back.y
					sim.act[helper] = 0
					sim.act_t[helper] = 0.0
					sim.agent_tick._set_mine_job(helper, -1)
				var stock_before = int(dug.get("buffer", 0))
				dug.timer = 0.01
				sim.building_sim._tick_buildings(0.05)
				if int(sim.act[0]) != sim.ACT_WORK:
					errors.append("mine worker lost before ore drop")
				elif int(dug.get("buffer", 0)) <= stock_before:
					errors.append("mine did not stock ore")
				else:
					# Mines stock into buffer; seed a ground pile for haul-path coverage.
					sim.world_entities._add_item(Catalog.ITEM_ORE, drop.x, drop.y, 1)
					var factory = {}
					var factory_free = 0
					for ly in range(3, Catalog.CHUNK - 3):
						for lx in range(3, Catalog.CHUNK - 3):
							var wx = float(lx * Catalog.TILE + 8)
							var wy = float(ly * Catalog.TILE + 8)
							var at = Catalog.snap_world(wx, wy)
							if not sim.building_sim._building_spot_free(-1, at.x, at.y, Catalog.BLD_FACTORY):
								continue
							factory_free += 1
							factory = sim.world_entities._add_building(Catalog.BLD_FACTORY, at.x, at.y)
							if not factory.is_empty():
								break
						if not factory.is_empty():
							break
					if factory.is_empty():
						errors.append("factory for ore haul")
						print("SMOKE DBG factory_free=%s feats=%s trees=%s rocks=%s" % [
							factory_free, sim.features.size(),
							sim.world_entities._count_kind_on(0, 0, Catalog.FEAT_TREE),
							sim.world_entities._count_kind_on(0, 0, Catalog.FEAT_ROCK) + sim.world_entities._count_kind_on(0, 0, Catalog.FEAT_BIGROCK),
						])
					else:
						var ore_it = sim.agent_tick._nearest_free_item(0, Catalog.ITEM_ORE, Catalog.NEAR_BUILDING)
						if ore_it.is_empty():
							errors.append("ore missing for haul")
						else:
							sim.pos_x[0] = float(ore_it.x)
							sim.pos_y[0] = float(ore_it.y)
							sim.agent_tick._walk_pickup(0, ore_it, Catalog.CARRY_ORE, sim.MOVE_SPEED, 1.0)
							if sim.carry[0] != Catalog.CARRY_ORE:
								errors.append("ore haul pickup")
							else:
								sim.pos_x[0] = float(factory.x)
								sim.pos_y[0] = float(factory.y)
								sim.agent_tick._deliver(0, sim.MOVE_SPEED, 0.2)
								if sim.carry[0] != Catalog.CARRY_NONE:
									errors.append("ore haul deliver")
								elif int(factory.get("buffer", 0)) < 1:
									errors.append("factory missed ore")
								sim.world_entities._remove_building(factory)
			sim.pos_x[0] = back.x
			sim.pos_y[0] = back.y
			sim.act[0] = 0
			sim.act_t[0] = 0.0
			sim.world_entities._set_carry(0, Catalog.CARRY_NONE)
	var round_b = {}
	for spot in [Vector2(300.0, 300.0), Vector2(140.0, 200.0), Vector2(360.0, 180.0), Vector2(160.0, 320.0), Vector2(200.0, 180.0), Vector2(240.0, 340.0), Vector2(340.0, 260.0)]:
		var at = Catalog.snap_world(spot.x, spot.y)
		if sim.building_sim._building_spot_free(-1, at.x, at.y, Catalog.BLD_ROUND):
			round_b = sim.world_entities._add_building(Catalog.BLD_ROUND, at.x, at.y)
			if not round_b.is_empty():
				break
	if round_b.is_empty():
		var round_spot = _smoke_find_spot(Catalog.BLD_ROUND, [])
		if round_spot != Vector2.ZERO:
			round_b = sim.world_entities._add_building(Catalog.BLD_ROUND, round_spot.x, round_spot.y)
	if round_b.is_empty():
		errors.append("roundabout place")
	elif sim.state[0] == Catalog.ST_LIVING:
		var back = Vector2(sim.pos_x[0], sim.pos_y[0])
		var gate = sim.collision._approach_building(round_b, 0)
		sim.pos_x[0] = gate.x
		sim.pos_y[0] = gate.y
		sim.amused[0] = 40.0
		sim.agent_tick._do_roundabout_ride(0, round_b, 0.2)
		var ride_mid = sim.agent_tick._ride_center_of(round_b)
		if sim.collision._ride_spot_blocked(sim.pos_x[0], sim.pos_y[0], round_b):
			errors.append("roundabout ride blocked")
		if sim.spatial._dist_i(0, ride_mid.x, ride_mid.y) > sim.agent_tick._ride_radius(round_b) + 6.0:
			errors.append("roundabout ride off pad")
		if sim.agent_tick._ride_building(0).is_empty():
			errors.append("roundabout lost rider")
		sim.amused[0] = Catalog.NEED_OK
		sim.agent_tick._leave_ride(0, round_b)
		if not sim.agent_tick._ride_building(0).is_empty():
			errors.append("roundabout kept rider")
		if sim.collision._blocked(sim.pos_x[0], sim.pos_y[0]):
			errors.append("roundabout left them blocked")
		if sim.agent_tick._is_rider(round_b, 0):
			errors.append("roundabout did not let go")
		sim.pos_x[0] = back.x
		sim.pos_y[0] = back.y
		sim.act[0] = 0
		sim.act_t[0] = 0.0
		sim.world_entities._remove_building(round_b)
	elif not round_b.is_empty():
		sim.world_entities._remove_building(round_b)
	var spare = {}
	for feat in sim.features:
		if not feat.dead and sim.building_sim._ore_tier(int(feat.kind)) > 0:
			spare = feat
			break
	if spare.is_empty():
		errors.append("no spare node")
	else:
		for it in sim.items:
			if int(it.kind) == Catalog.ITEM_WOOD:
				it.dead = true
		for raw in sim.living_ids:
			var i = int(raw)
			if sim.carry[i] == Catalog.CARRY_WOOD:
				sim.world_entities._set_carry(i, Catalog.CARRY_NONE)
		var node_id = int(spare.id)
		sim.player_tools.place_building(Catalog.BLD_MINE, float(spare.x), float(spare.y))
		var still = sim.feature_by_id.get(node_id, {})
		if still.is_empty() or still.dead:
			errors.append("mine ate node without wood")
	var tub_b = {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_TUB:
			tub_b = b
			break
	if tub_b.is_empty():
		errors.append("tub missing for select")
	else:
		sim.player_tools.cancel_hold()
		var grabbed = sim.player_tools.grab_at(float(tub_b.x), float(tub_b.y))
		if sim.held_kind == "building":
			errors.append("eye must not lift buildings")
			sim.player_tools._clear_held()
			if bool(tub_b.get("lifted", false)):
				tub_b.lifted = false
				sim.building_sim._bind_building_at(tub_b, float(tub_b.x), float(tub_b.y))
		elif grabbed:
			sim.player_tools.cancel_hold()
	var market_b = {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MARKET:
			market_b = b
			break
	if market_b.is_empty():
		errors.append("market missing for select")
	else:
		sim.player_tools.cancel_hold()
		var market_grab = sim.player_tools.grab_at(float(market_b.x), float(market_b.y))
		if sim.held_kind == "building":
			errors.append("eye must not lift buildings")
			sim.player_tools._clear_held()
			if bool(market_b.get("lifted", false)):
				market_b.lifted = false
				sim.building_sim._bind_building_at(market_b, float(market_b.x), float(market_b.y))
		elif market_grab:
			sim.player_tools.cancel_hold()
		sim.frozen = false
		var hit = sim.player_tools.eye_use(float(market_b.x), float(market_b.y))
		if str(hit.get("type", "")) != "market":
			errors.append("eye select building")
	var forest = {}
	for feat in sim.features:
		if not feat.dead and int(feat.kind) == Catalog.FEAT_TREE:
			forest = feat
			break
	if not forest.is_empty() and not sim.collision._blocked(float(forest.x), float(forest.y)):
		errors.append("tree not solid")
	for feat in sim.features:
		if feat.dead:
			continue
		var grid = Catalog.snap_world(float(feat.x), float(feat.y))
		if absf(float(feat.x) - grid.x) > 0.01 or absf(float(feat.y) - grid.y) > 0.01:
			errors.append("feature off grid")
			break
	if sim.living >= 1 and sim.state[0] == Catalog.ST_LIVING:
		# Outside SPAWN_CLEAR so rooted trees are allowed.
		var corner = sim.spatial._cell_vec(140.0, 140.0)
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				var key = Vector2i(corner.x + ox, corner.y + oy)
				if sim.feature_cell.has(key):
					var fid = int(sim.feature_cell[key])
					var feat = sim.feature_by_id.get(fid, {})
					if not feat.is_empty():
						feat.dead = true
					sim.feature_cell.erase(key)
				sim.collision._set_world_cell(key.x, key.y, Catalog.TILE_GRASS, true)
		var open_at = Catalog.cell_world(corner)
		var block_at = Catalog.cell_world(corner + Vector2i(1, 1))
		# rooted=false: canopy span would fail _stands on the small grass patch.
		var corner_tree = sim.world_entities._add_feature(Catalog.FEAT_TREE, block_at.x, block_at.y, 1, 0, false)
		if corner_tree.is_empty():
			errors.append("tree corner setup")
		else:
			sim.pos_x[0] = open_at.x
			sim.pos_y[0] = open_at.y
			sim.dir_x[0] = 1.0
			sim.dir_y[0] = 1.0
			var corner_start = Vector2(sim.pos_x[0], sim.pos_y[0])
			var into_tree = 0
			for _n in 90:
				sim.agent_move._walk(0, block_at.x, block_at.y, sim.MOVE_SPEED, 0.08)
				if sim.collision._move_blocked(sim.pos_x[0], sim.pos_y[0]):
					into_tree += 1
			if sim.spatial._dist_point(sim.pos_x[0], sim.pos_y[0], corner_start.x, corner_start.y) < 12.0:
				errors.append("stuck on tree corner")
			if into_tree > 0 or sim.collision._move_blocked(sim.pos_x[0], sim.pos_y[0]):
				errors.append("walked into tree")
	sim.spatial._rebuild_hash()
	if sim.spatial.find_thronglet(sim.pos_x[0], sim.pos_y[0], 8.0, true) != 0:
		errors.append("hash miss")
	if sim.living >= 1 and sim.state[0] == Catalog.ST_LIVING:
		var cove = sim.spatial._cell_vec(240.0, 240.0)
		for oy in range(-6, 7):
			for ox in range(-6, 7):
				var cx = cove.x + ox
				var cy = cove.y + oy
				var key = Vector2i(cx, cy)
				if sim.feature_cell.has(key):
					var fid = int(sim.feature_cell[key])
					var feat = sim.feature_by_id.get(fid, {})
					if not feat.is_empty():
						feat.dead = true
					sim.feature_cell.erase(key)
				# Grass core west/north; water east/south. Lip stays unwalkable under inland pad.
				var water = ox >= 1 or oy >= 1
				sim.collision._set_world_cell(cx, cy, Catalog.TILE_WATER if water else Catalog.TILE_GRASS, true)
		# Start on an inland cell, not the water lip.
		sim.pos_x[0] = float(cove.x - 1) * Catalog.TILE + Catalog.TILE * 0.5
		sim.pos_y[0] = float(cove.y - 1) * Catalog.TILE + Catalog.TILE * 0.5
		sim.dir_x[0] = 1.0
		sim.dir_y[0] = 1.0
		var start = Vector2(sim.pos_x[0], sim.pos_y[0])
		for _n in 120:
			sim.agent_move._walk(0, start.x + 96.0, start.y + 96.0, sim.MOVE_SPEED, 0.08)
		if sim.spatial._dist_point(sim.pos_x[0], sim.pos_y[0], start.x, start.y) < 28.0:
			errors.append("stuck in water corner")
		if sim.collision._tile_at(sim.pos_x[0], sim.pos_y[0]) == Catalog.TILE_WATER or not sim.collision._land_inland(sim.pos_x[0], sim.pos_y[0]):
			errors.append("walked into water")
	while not sim.modal.is_empty():
		sim.dialogue.choose(0)
	sim.fed[1] = 0.0
	sim.amused[1] = 0.0
	sim.clean[1] = 0.0
	sim.starve[1] = 30.0
	sim.tick_stamp[1] = 0
	sim.agent_tick._tick_one(1, 0.1)
	if sim.state[1] != Catalog.ST_DEAD:
		errors.append("neglect state")
	if sim.modal.is_empty() or str(sim.modal.get("event", "")) != "neglect":
		errors.append("neglect gaze")
	else:
		while not sim.modal.is_empty():
			sim.dialogue.choose(0)
	if sim.frozen:
		errors.append("frozen after choice")
	var live_now = sim.living
	var gems_now = sim.gems
	if not sim.save_system.save_game():
		errors.append("save failed")
	sim.gems = 999
	if not sim.save_system.load_game():
		errors.append("load failed")
	elif sim.living != live_now or sim.gems != gems_now:
		errors.append("load mismatch living %s/%s gems %s/%s" % [sim.living, live_now, sim.gems, gems_now])
	var before_goal = sim.features.size()
	sim.dialogue.goal_line()
	if sim.features.size() != before_goal:
		errors.append("goal line mutated world")
	var victim = -1
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_LIVING:
			victim = i
			break
	sim.unlocks.bug = true
	var pop = sim.living
	if victim >= 0:
		sim.player_tools._tool_bug(sim.pos_x[victim], sim.pos_y[victim])
		if sim.living != pop:
			errors.append("bug killed early")
		if sim.modal.is_empty():
			errors.append("bug modal missing")
		else:
			sim.dialogue.choose(2)
			if sim.living != pop:
				errors.append("bug killed on refuse")
	var tub_now = {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_TUB:
			tub_now = b
			break
	if sim.living > 1 and not tub_now.is_empty():
		var bather = -1
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING:
				bather = i
				break
		sim.building_sim._claim_tub(bather, tub_now)
		var pop_now = sim.living
		sim.world_entities._deflesh(bather, false)
		if int(tub_now.occupant) != -1:
			errors.append("deflesh left tub occupied")
		if sim.living != pop_now - 1:
			errors.append("deflesh living %s" % sim.living)
		if sim.game_over:
			errors.append("deflesh ended with others alive")
	while sim.living > 1:
		var last = -1
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING:
				last = i
				break
		if last < 0:
			break
		sim.world_entities._become_corpse(last)
	if sim.living == 1:
		var last_one = -1
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING:
				last_one = i
				break
		sim.world_entities._deflesh(last_one, false)
	if not sim.game_over:
		errors.append("no game over")
	_check_factory_fill(errors)
	_check_opening(errors)
	print("SMOKE " + ("OK" if errors.is_empty() else "FAIL"))
	for err in errors:
		print(" - " + str(err))
	sim.get_tree().quit(0 if errors.is_empty() else 1)



