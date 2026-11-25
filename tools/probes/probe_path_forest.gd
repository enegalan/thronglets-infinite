extends SceneTree

## Headless pathing probe: corner trap, 1-tile gap, rock/tree wall detour, maze.
## Asserts progress, never stands on blocked cells, and path length stays near-optimal.

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")

## Fixed sim step delta used while walking throngs in path probes.
const DT := 0.08

## Throng walk speed in world units per second for path stepping.
const SPEED := 26.0


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
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

	var pads: Array[Vector2i] = _pick_pads(sim, 4)
	if pads.size() < 4:
		print("PROBE FAIL not enough inland pads outside spawn (%d)" % pads.size())
		quit(1)
		return

	var errors: Array[String] = []
	errors.append_array(_case_corner_trap(sim, pads[0]))
	errors.append_array(_case_narrow_gap(sim, pads[1]))
	errors.append_array(_case_rock_detour(sim, pads[2]))
	errors.append_array(_case_forest_maze(sim, pads[3]))
	errors.append_array(_case_linear_up(sim, pads[0]))

	if errors.is_empty():
		print("PROBE OK path_forest")
		quit(0)
	else:
		for e in errors:
			print("PROBE FAIL ", e)
		quit(1)


## Finds inland grass pads outside spawn for isolated path scenarios.
func _pick_pads(sim, need: int) -> Array[Vector2i]:
	var mid: float = float(sim.island_gen.island_mid())
	var reach: float = float(sim.island_gen.island_reach())
	var lo: float = float(sim.SPAWN_CLEAR) + 28.0
	var hi: float = reach - 36.0
	var out: Array[Vector2i] = []
	var used: Dictionary = {}
	for ang_i in 48:
		if out.size() >= need:
			break
		var ang: float = float(ang_i) * TAU / 48.0
		for rad_i in 6:
			var rad: float = lerpf(lo, hi, float(rad_i) / 5.0)
			var px: float = mid + cos(ang) * rad
			var py: float = mid + sin(ang) * rad
			if sim._near_spawn(px, py):
				continue
			if not sim._land_inland(px, py):
				continue
			var cell: Vector2i = sim._cell_vec(px, py)
			var key: String = "%d,%d" % [cell.x, cell.y]
			if used.has(key):
				continue
			# Keep pads apart so cases do not overlap.
			var far_enough: bool = true
			for prev in out:
				if absi(prev.x - cell.x) + absi(prev.y - cell.y) < 14:
					far_enough = false
					break
			if not far_enough:
				continue
			used[key] = true
			out.append(cell)
			break
	return out


## Clears features and buildings in a square around a test origin.
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


## Plants a feature kind on a cell and returns the feature dict.
func _plant(sim, kind: int, cell: Vector2i, ore: int = 0) -> Dictionary:
	var at: Vector2 = Catalog.cell_world(cell)
	var feat: Dictionary = sim._add_feature(kind, at.x, at.y, 1 + ore, ore, false)
	return feat


## Spawns a throng on a cell and returns its slot id.
func _spawn_at(sim, cell: Vector2i) -> int:
	var at: Vector2 = Catalog.cell_world(cell)
	if sim._move_blocked(at.x, at.y):
		return -1
	var id: int = int(sim._push_slot(at.x, at.y, 95.0, 95.0, 95.0, 999.0, 0))
	sim.pos_x[id] = at.x
	sim.pos_y[id] = at.y
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0
	if id < sim.seek_t.size():
		sim.seek_t[id] = 0.0
	sim._rebuild_hash()
	return id


## Steps sim toward a goal and returns throng position and blocked flags.
func _walk_until(sim, id: int, goal: Vector2, steps: int) -> Dictionary:
	var blocked_hits: int = 0
	var path_len: float = 0.0
	var prev: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
	for _n in steps:
		sim._walk(id, goal.x, goal.y, SPEED, DT)
		var cur: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
		path_len += prev.distance_to(cur)
		prev = cur
		if sim._move_blocked(cur.x, cur.y):
			blocked_hits += 1
		if cur.distance_to(goal) < 2.0:
			break
	return {
		"pos": Vector2(sim.pos_x[id], sim.pos_y[id]),
		"blocked_hits": blocked_hits,
		"path_len": path_len,
		"dist": Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(goal),
	}


## Manhattan distance between two world points.
func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


## Path scenario: throng must escape a corner pocket.
func _case_corner_trap(sim, origin: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	_clear_pad(sim, origin, 6)
	var tree_a: Vector2i = origin + Vector2i(2, 1)
	var tree_b: Vector2i = origin + Vector2i(1, 2)
	if _plant(sim, Catalog.FEAT_TREE, tree_a).is_empty():
		errors.append("corner: plant A")
	if _plant(sim, Catalog.FEAT_TREE, tree_b).is_empty():
		errors.append("corner: plant B")
	if not errors.is_empty():
		return errors
	var ta: Vector2 = Catalog.cell_world(tree_a)
	if not sim._move_blocked(ta.x, ta.y):
		errors.append("corner: tree A not solid")
		return errors
	var start: Vector2i = origin
	var goal: Vector2 = Catalog.cell_world(origin + Vector2i(3, 3))
	var id: int = _spawn_at(sim, start)
	if id < 0:
		errors.append("corner: spawn blocked")
		return errors
	var start_at: Vector2 = Catalog.cell_world(start)
	var result: Dictionary = _walk_until(sim, id, goal, 220)
	if int(result.blocked_hits) > 0:
		errors.append("corner: stood on blocked (%d)" % int(result.blocked_hits))
	if float(result.dist) > 3.0:
		errors.append("corner: missed goal d=%.1f at %s" % [float(result.dist), str(result.pos)])
	var opt: float = _manhattan(start_at, goal)
	if float(result.path_len) > opt * 2.2 + 16.0:
		errors.append("corner: wasteful path=%.1f opt=%.1f" % [float(result.path_len), opt])
	print("corner d=%.1f path=%.1f opt=%.1f blocked=%d" % [
		float(result.dist), float(result.path_len), opt, int(result.blocked_hits)])
	return errors


## Path scenario: single-tile gap through a rock wall.
func _case_narrow_gap(sim, origin: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	_clear_pad(sim, origin, 8)
	var planted: int = 0
	for ox in range(0, 7):
		if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(ox, -1)).is_empty():
			planted += 1
		if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(ox, 1)).is_empty():
			planted += 1
	if planted < 12:
		errors.append("gap: planted %d/14 trees" % planted)
		return errors
	var start: Vector2i = origin + Vector2i(-1, 0)
	var goal: Vector2 = Catalog.cell_world(origin + Vector2i(7, 0))
	var id: int = _spawn_at(sim, start)
	if id < 0:
		errors.append("gap: spawn blocked")
		return errors
	var start_at: Vector2 = Catalog.cell_world(start)
	var result: Dictionary = _walk_until(sim, id, goal, 280)
	if int(result.blocked_hits) > 0:
		errors.append("gap: stood on blocked (%d)" % int(result.blocked_hits))
	if float(result.dist) > 3.0:
		errors.append("gap: missed corridor goal d=%.1f" % float(result.dist))
	var opt: float = _manhattan(start_at, goal)
	if float(result.path_len) > opt * 1.8 + 12.0:
		errors.append("gap: wasteful path=%.1f opt=%.1f" % [float(result.path_len), opt])
	print("gap d=%.1f path=%.1f opt=%.1f blocked=%d" % [
		float(result.dist), float(result.path_len), opt, int(result.blocked_hits)])
	return errors


## Path scenario: detour around a rock/tree barrier.
func _case_rock_detour(sim, origin: Vector2i) -> Array[String]:
	# Rock sits on the straight line; sparse trees thicken the wall without crowded-fail.
	var errors: Array[String] = []
	_clear_pad(sim, origin, 8)
	if _plant(sim, Catalog.FEAT_ROCK, origin + Vector2i(2, 0)).is_empty():
		errors.append("rock: plant rock")
		return errors
	var planted: int = 0
	for oy in [-3, 3]:
		if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(2, oy)).is_empty():
			planted += 1
	var rock_at: Vector2 = Catalog.cell_world(origin + Vector2i(2, 0))
	if not sim._move_blocked(rock_at.x, rock_at.y):
		errors.append("rock: rock not solid")
		return errors
	var start: Vector2i = origin + Vector2i(0, 0)
	var start_at: Vector2 = Catalog.cell_world(start)
	var goal: Vector2 = Catalog.cell_world(origin + Vector2i(4, 0))
	if sim._axis_clear(start_at.x, start_at.y, goal.x, start_at.y):
		errors.append("rock: straight path still open")
		return errors
	var id: int = _spawn_at(sim, start)
	if id < 0:
		errors.append("rock: spawn blocked")
		return errors
	var result: Dictionary = _walk_until(sim, id, goal, 320)
	if int(result.blocked_hits) > 0:
		errors.append("rock: stood on blocked (%d)" % int(result.blocked_hits))
	if float(result.dist) > 3.0:
		errors.append("rock: missed detour goal d=%.1f at %s" % [float(result.dist), str(result.pos)])
	var opt: float = _manhattan(start_at, goal) + float(Catalog.TILE) * 4.0
	if float(result.path_len) > opt * 2.0 + 24.0:
		errors.append("rock: wasteful path=%.1f budget=%.1f" % [float(result.path_len), opt * 2.0])
	print("rock d=%.1f path=%.1f budget=%.1f blocked=%d trees=%d" % [
		float(result.dist), float(result.path_len), opt * 2.0, int(result.blocked_hits), planted])
	return errors


## Path scenario: weave through a forest maze.
func _case_forest_maze(sim, origin: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	_clear_pad(sim, origin, 10)
	var planted: int = 0
	for ox in range(0, 5):
		if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(ox, -1)).is_empty():
			planted += 1
	if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(2, 0)).is_empty():
		planted += 1
	if not _plant(sim, Catalog.FEAT_TREE, origin + Vector2i(2, 1)).is_empty():
		planted += 1
	if planted < 7:
		errors.append("maze: planted %d/7 trees" % planted)
		return errors
	var start: Vector2i = origin + Vector2i(0, 0)
	var goal: Vector2 = Catalog.cell_world(origin + Vector2i(4, 0))
	var id: int = _spawn_at(sim, start)
	if id < 0:
		errors.append("maze: spawn blocked")
		return errors
	var start_at: Vector2 = Catalog.cell_world(start)
	var result: Dictionary = _walk_until(sim, id, goal, 400)
	if int(result.blocked_hits) > 0:
		errors.append("maze: stood on blocked (%d)" % int(result.blocked_hits))
	if float(result.dist) > 3.0:
		errors.append("maze: missed goal d=%.1f at %s" % [float(result.dist), str(result.pos)])
	var opt: float = _manhattan(start_at, goal) + float(Catalog.TILE) * 4.0
	if float(result.path_len) > opt * 2.5 + 32.0:
		errors.append("maze: wasteful path=%.1f budget=%.1f" % [float(result.path_len), opt * 2.5])
	print("maze d=%.1f path=%.1f budget=%.1f blocked=%d" % [
		float(result.dist), float(result.path_len), opt * 2.5, int(result.blocked_hits)])
	return errors


## Path scenario: straight walk with no obstacles.
func _case_linear_up(sim, origin: Vector2i) -> Array[String]:
	# Off-center start walking pure north must not stairstep / zigzag on X.
	var errors: Array[String] = []
	_clear_pad(sim, origin, 8)
	var start: Vector2i = origin + Vector2i(0, 4)
	var goal: Vector2 = Catalog.cell_world(origin + Vector2i(0, -4))
	var id: int = _spawn_at(sim, start)
	if id < 0:
		errors.append("linear: spawn blocked")
		return errors
	# Nudge off cell center — old cardinal stepper zig-zagged toward each hop center.
	sim.pos_x[id] = sim.pos_x[id] - 3.0
	var start_x: float = float(sim.pos_x[id])
	var max_drift: float = 0.0
	var sign_flips: int = 0
	var prev_dx: float = 0.0
	for _n in 220:
		var before: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
		sim._walk(id, goal.x, goal.y, SPEED, DT)
		var after: Vector2 = Vector2(sim.pos_x[id], sim.pos_y[id])
		if sim._move_blocked(after.x, after.y):
			errors.append("linear: stood on blocked")
			break
		var drift: float = absf(after.x - start_x)
		if drift > max_drift:
			max_drift = drift
		var step_dx: float = after.x - before.x
		if absf(step_dx) > 0.05 and absf(prev_dx) > 0.05 and signf(step_dx) != signf(prev_dx):
			sign_flips += 1
		if absf(step_dx) > 0.05:
			prev_dx = step_dx
		if after.distance_to(goal) < 2.0:
			break
	var end_d: float = Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(goal)
	if end_d > 3.0:
		errors.append("linear: missed goal d=%.1f" % end_d)
	if max_drift > 1.6:
		errors.append("linear: x drift %.2f (zigzag)" % max_drift)
	if sign_flips > 2:
		errors.append("linear: x sign flips %d" % sign_flips)
	print("linear d=%.1f drift=%.2f flips=%d" % [end_d, max_drift, sign_flips])
	return errors
