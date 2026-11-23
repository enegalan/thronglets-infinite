extends SceneTree

## Tree square with one gap: must exit the gap, never chord through walls / unstick-loop.

const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")
const DT := 0.08
const SPEED := 26.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	sim.world_seed = 4242
	seed(4242)
	root.add_child(sim)
	await process_frame
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()

	var origin := _pick_pad(sim)
	if origin.x <= -999000:
		print("PROBE FAIL no inland pad")
		quit(1)
		return

	var errors: Array[String] = _case_enclosure(sim, origin)
	if errors.is_empty():
		print("PROBE OK enclosure_gap")
		quit(0)
	else:
		for e in errors:
			print("PROBE FAIL ", e)
		quit(1)


func _pick_pad(sim) -> Vector2i:
	var mid: float = float(sim.island_gen.island_mid())
	var reach: float = float(sim.island_gen.island_reach())
	var lo: float = float(sim.SPAWN_CLEAR) + 40.0
	var hi: float = reach - 48.0
	for ang_i in 64:
		var ang: float = float(ang_i) * TAU / 64.0
		for rad_i in 8:
			var rad: float = lerpf(lo, hi, float(rad_i) / 7.0)
			var px: float = mid + cos(ang) * rad
			var py: float = mid + sin(ang) * rad
			if sim._near_spawn(px, py):
				continue
			if not sim._land_inland(px, py):
				continue
			return sim._cell_vec(px, py)
	return Vector2i(-999999, -999999)


func _clear_pad(sim, origin: Vector2i, half: int) -> void:
	for oy in range(-half, half + 1):
		for ox in range(-half, half + 1):
			var key := Vector2i(origin.x + ox, origin.y + oy)
			if sim.feature_cell.has(key):
				var fid: int = int(sim.feature_cell[key])
				var feat: Dictionary = sim.feature_by_id.get(fid, {})
				if not feat.is_empty():
					feat.dead = true
				sim.feature_cell.erase(key)
			if sim.building_cell.has(key):
				var bid: int = int(sim.building_cell[key])
				var b: Dictionary = sim.building_by_id.get(bid, {})
				if not b.is_empty():
					b.dead = true
				sim.building_cell.erase(key)
			sim._set_world_cell(key.x, key.y, Catalog.TILE_GRASS, true)


func _plant(sim, cell: Vector2i) -> bool:
	var at: Vector2 = Catalog.cell_world(cell)
	return not sim._add_feature(Catalog.FEAT_TREE, at.x, at.y, 1, 0, false).is_empty()


func _case_enclosure(sim, origin: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	_clear_pad(sim, origin, 10)
	# 5x5 ring, gap on south wall center.
	var half := 2
	var planted := 0
	for ox in range(-half, half + 1):
		for oy in range(-half, half + 1):
			if absi(ox) != half and absi(oy) != half:
				continue
			if ox == 0 and oy == half:
				continue # gap
			if _plant(sim, origin + Vector2i(ox, oy)):
				planted += 1
	if planted < 15:
		errors.append("enclosure: planted %d trees" % planted)
		return errors

	var start: Vector2i = origin
	# Stay inland: pick the nearest open cell east of the ring.
	var goal_cell := origin + Vector2i(half + 2, 0)
	var start_at: Vector2 = Catalog.cell_world(start)
	var goal: Vector2 = Catalog.cell_world(goal_cell)
	if sim._move_blocked(goal.x, goal.y):
		goal_cell = origin + Vector2i(half + 2, half + 2)
		goal = Catalog.cell_world(goal_cell)
	if sim._move_blocked(goal.x, goal.y):
		errors.append("enclosure: no open goal near ring")
		return errors

	# Trees on the east wall must block the straight chord.
	if sim._axis_clear(start_at.x, start_at.y, goal.x, start_at.y):
		errors.append("enclosure: east chord open through wall")
	if sim._axis_clear(start_at.x, start_at.y, goal.x, goal.y):
		errors.append("enclosure: diagonal chord open through wall")

	var hop: Vector2 = sim._path_hop(start_at.x, start_at.y, goal.x, goal.y)
	var cells: Array = sim._bfs_path_cells(start, goal_cell)
	print("hop=", hop, " bfs_n=", cells.size(), " goal=", goal_cell)
	var hop_cell: Vector2i = sim._cell_vec(hop.x, hop.y)
	if hop_cell == start + Vector2i(1, 0) or hop_cell == start + Vector2i(2, 0):
		errors.append("enclosure: hop aims into east wall %s" % str(hop_cell))
	if cells.size() > 1 and int(cells[1].y) <= start.y and int(cells[1].x) != start.x:
		# First step should head toward the south gap, not east into the wall.
		if int(cells[1].x) > start.x and int(cells[1].y) == start.y:
			errors.append("enclosure: bfs steps east into wall (%s)" % str(cells[1]))

	var id: int = int(sim._push_slot(start_at.x, start_at.y, 40.0, 40.0, 95.0, 999.0, 0))
	sim.pos_x[id] = start_at.x
	sim.pos_y[id] = start_at.y
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0
	sim._rebuild_hash()

	var blocked_hits := 0
	var teleports := 0
	var max_jump := 0.0
	for _n in 500:
		var before: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
		sim._walk(id, goal.x, goal.y, SPEED, DT)
		var after: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
		var jump: float = before.distance_to(after)
		if jump > max_jump:
			max_jump = jump
		if jump > SPEED * DT * 2.5:
			teleports += 1
		if sim._move_blocked(after.x, after.y):
			blocked_hits += 1
		if after.distance_to(goal) < 3.0:
			break

	var end: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
	var end_cell: Vector2i = sim._cell_vec(end.x, end.y)
	print("end_cell=", end_cell, " d=%.1f teleports=%d blocked=%d max_jump=%.1f" % [
		end.distance_to(goal), teleports, blocked_hits, max_jump])

	if blocked_hits > 0:
		errors.append("enclosure: stood on blocked (%d)" % blocked_hits)
	if teleports > 2:
		errors.append("enclosure: unstick loop teleports=%d" % teleports)
	if end.distance_to(goal) > 4.0:
		errors.append("enclosure: missed goal d=%.1f" % end.distance_to(goal))
	if absi(end_cell.x - origin.x) <= half and absi(end_cell.y - origin.y) <= half:
		errors.append("enclosure: still inside ring at %s" % str(end_cell))
	return errors
