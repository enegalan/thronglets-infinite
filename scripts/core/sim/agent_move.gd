class_name SimAgentMove
extends RefCounted

## Agent locomotion: walk, BFS pathing, unstick, haul waypoints.

var sim


## Stores the simulation server used for movement.
func _init(sim_ref) -> void:
	sim = sim_ref

## Inertia walk toward a seek target using the same cardinal pathing as active goals.
func _coast(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	# Same cardinal/BFS stepper as _walk — coast must not charge diagonals into trees.
	_walk(i, tx, ty, speed, dt)



## Drifts along the current facing, peeling around trees when the forward cell is blocked.
func _coast_dir(i: int, speed: float, dt: float) -> void:
	var step = speed * dt
	if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) < 0.01 or step < 0.01:
		return
	_snap_dir_cardinal(i)
	if _move_cardinal_toward(i, sim.pos_x[i] + sim.dir_x[i] * 32.0, sim.pos_y[i] + sim.dir_y[i] * 32.0, step):
		return
	# Peel around the tree — never freeze with dir=0 until the next seek.
	var peel = _open_dir(i, Vector2(sim.dir_x[i], sim.dir_y[i]))
	if peel == Vector2.ZERO:
		peel = _open_dir(i, _side_dir(i, Vector2(sim.dir_x[i], sim.dir_y[i])))
	if peel != Vector2.ZERO:
		sim.dir_x[i] = peel.x
		sim.dir_y[i] = peel.y
		_snap_dir_cardinal(i)
		if _move_cardinal_toward(i, sim.pos_x[i] + sim.dir_x[i] * 32.0, sim.pos_y[i] + sim.dir_y[i] * 32.0, step):
			return
	if sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]) or sim.collision._corner_trap(i):
		sim.collision._unstick(i)
	else:
		_pick_wander(i)
	if i < sim.seek_t.size():
		sim.seek_t[i] = 0.0



## Snaps movement intent to a single cardinal axis for grid-safe locomotion.
func _snap_dir_cardinal(i: int) -> void:
	if absf(sim.dir_x[i]) >= absf(sim.dir_y[i]):
		sim.dir_x[i] = 0.0 if is_zero_approx(sim.dir_x[i]) else signf(sim.dir_x[i])
		sim.dir_y[i] = 0.0
	else:
		sim.dir_y[i] = 0.0 if is_zero_approx(sim.dir_y[i]) else signf(sim.dir_y[i])
		sim.dir_x[i] = 0.0



## Detects convex corners or obstacles blocking the straight haul line toward the factory.
func _haul_path_blocked(i: int, tx: float, ty: float) -> bool:
	var dx = tx - sim.pos_x[i]
	var dy = ty - sim.pos_y[i]
	var dist = sqrt(dx * dx + dy * dy)
	if dist < 20.0:
		return false
	return _goal_path_blocked(sim.pos_x[i], sim.pos_y[i], dx / dist, dy / dist, mini(dist, 56.0))



## Picks a local inland hop that still progresses ore delivery when the direct path is blocked.
func _haul_waypoint(i: int, tx: float, ty: float) -> Vector2:
	# Local inland hop that still progresses toward the factory rim.
	var origin = Vector2(sim.pos_x[i], sim.pos_y[i])
	var goal = Vector2(tx, ty)
	var goal_dir = goal - origin
	if goal_dir.length_squared() < 0.01:
		return goal
	goal_dir = goal_dir.normalized()
	# Prefer the hop already in seek — flipping every frame loops the hauler.
	if i < sim.seek_t.size() and sim.seek_t[i] > 0.15:
		var kept = Vector2(sim.seek_x[i], sim.seek_y[i])
		if origin.distance_squared_to(kept) > 14.0 * 14.0 and not sim.collision._move_blocked(kept.x, kept.y):
			if (kept - origin).normalized().dot(goal_dir) > 0.05:
				return kept
	var inland = _inland_dir(i)
	var shore = _shore_push(i)
	var facing = Vector2(sim.dir_x[i], sim.dir_y[i])
	var best = goal
	var best_score = -INF
	for n in 12:
		var ang = float(n) * (TAU / 12.0)
		var hop = origin + Vector2(cos(ang), sin(ang)) * 56.0
		if sim.collision._move_blocked(hop.x, hop.y):
			continue
		var step = hop - origin
		var step_n = step.normalized()
		var score = step.dot(goal_dir) * 3.0
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
		var inland_hop = origin + inland * 48.0
		if not sim.collision._move_blocked(inland_hop.x, inland_hop.y):
			return inland_hop
	return goal



## Idle exploration movement when no need or job owns the agent this tick.
func _wander(i: int, speed: float, dt: float) -> void:
	# Drop stale seek (tub/food/…) or debug path and coast keep chasing it.
	if i < sim.seek_t.size():
		sim.seek_t[i] = 0.0
	sim.wander_t[i] -= dt
	if sim.wander_t[i] <= 0.0:
		_pick_wander(i)
	if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) < 0.01:
		return
	_snap_dir_cardinal(i)
	if sim.collision._move_blocked(sim.pos_x[i] + sim.dir_x[i] * 12.0, sim.pos_y[i] + sim.dir_y[i] * 12.0):
		_pick_wander(i)
		_snap_dir_cardinal(i)
		if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) < 0.01:
			return
	_move_cardinal_toward(i, sim.pos_x[i] + sim.dir_x[i] * 32.0, sim.pos_y[i] + sim.dir_y[i] * 32.0, speed * dt)



## Chooses a new wander heading from curiosity, shore bias, and local clearance.
func _pick_wander(i: int) -> void:
	if randf() < 0.14:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		sim.wander_t[i] = randf_range(0.35, 1.1)
		return
	var open = _open_dir(i, _curious_dir(i))
	if open == Vector2.ZERO:
		open = _open_dir(i, _shore_push(i))
	if open == Vector2.ZERO:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		sim.wander_t[i] = randf_range(0.25, 0.7)
		return
	sim.dir_x[i] = open.x
	sim.dir_y[i] = open.y
	sim.wander_t[i] = randf_range(0.9, 2.8)



## Blends shore push, nearby building pull, and random exploration for wander steering.
func _curious_dir(i: int) -> Vector2:
	var shore = _shore_push(i)
	if shore != Vector2.ZERO and randf() < 0.75:
		return shore
	var spot = _curiosity_spot(i)
	if spot != Vector2.ZERO and randf() < 0.65:
		return spot
	var ang = randf() * TAU
	var explore = Vector2(cos(ang), sin(ang))
	var inland = _inland_dir(i)
	var mixed = explore * 0.8 + inland * 0.2
	if mixed.length_squared() < 0.01:
		return explore
	return mixed.normalized()



## Unit direction toward a random nearby building or open map point for casual roaming.
func _curiosity_spot(i: int) -> Vector2:
	var px = sim.pos_x[i]
	var py = sim.pos_y[i]
	var best = Vector2.ZERO
	var best_d = 200.0
	for b in sim.buildings:
		if b.get("dead", false):
			continue
		var bx = float(b.x)
		var by = float(b.y)
		var d = sim.spatial._dist_point(px, py, bx, by)
		if d < 36.0 or d > best_d:
			continue
		if randf() > 0.4:
			continue
		best_d = d
		best = Vector2(bx - px, by - py)
	if best != Vector2.ZERO:
		return best.normalized()
	var ang = randf() * TAU
	var reach = randf_range(48.0, 130.0)
	var tx = px + cos(ang) * reach
	var ty = py + sin(ang) * reach
	if sim.collision._move_blocked(tx, ty):
		return Vector2.ZERO
	return Vector2(cos(ang), sin(ang))



## Steering away from water and hard blocks so wanderers stay on buildable land.
func _shore_push(i: int) -> Vector2:
	var push = Vector2.ZERO
	for n in 8:
		var a = float(n) * TAU * 0.125
		var sx = cos(a)
		var sy = sin(a)
		if sim.collision._tile_at(sim.pos_x[i] + sx * 10.0, sim.pos_y[i] + sy * 10.0) == Catalog.TILE_WATER:
			push -= Vector2(sx, sy)
		elif sim.collision._move_blocked(sim.pos_x[i] + sx * 10.0, sim.pos_y[i] + sy * 10.0):
			push -= Vector2(sx, sy) * 0.55
	if push.length_squared() < 0.01:
		return Vector2.ZERO
	return push.normalized()



## Bias toward the island interior center for haul waypoints and path scoring.
func _inland_dir(i: int) -> Vector2:
	var to = Vector2(256.0 - sim.pos_x[i], 256.0 - sim.pos_y[i])
	if to.length_squared() < 1.0:
		return Vector2(cos(float(i)), sin(float(i)))
	return to.normalized()



## Unobstructed distance along a direction from the agent's current position.
func _clear_run(i: int, dx: float, dy: float) -> float:
	return sim.collision._clear_run_at(sim.pos_x[i], sim.pos_y[i], dx, dy)



## Best cardinal escape direction around obstacles favoring clearance and preferred bearing.
func _open_dir(i: int, prefer: Vector2) -> Vector2:
	var base = prefer
	if base.length_squared() < 0.01:
		base = Vector2(1.0, 0.0)
	else:
		base = base.normalized()
	var best = Vector2.ZERO
	var best_score = -1.0
	# Min run 6 — a 1-tile tree gap clears ~8px; 10 rejected every narrow path.
	for n in 8:
		var d = base.rotated(float(n) * (TAU / 8.0))
		var run = _clear_run(i, d.x, d.y)
		if run < 6.0:
			continue
		var score = run * 2.5 + d.dot(base) * 5.0
		if score > best_score:
			best_score = score
			best = d
	if best != Vector2.ZERO:
		return best
	for n in 8:
		var d2 = base.rotated(float(n) * (TAU / 8.0) + TAU / 16.0)
		var run2 = _clear_run(i, d2.x, d2.y)
		if run2 < 4.0:
			continue
		var score2 = run2 * 2.5 + d2.dot(base) * 5.0
		if score2 > best_score:
			best_score = score2
			best = d2
	return best



## Picks left or right tangent around a blocked forward goal for corner peeling.
func _side_dir(i: int, goal: Vector2) -> Vector2:
	# Tangents around a blocked goal. Shore-push aims backward and restarts the corner loop.
	var left = Vector2(-goal.y, goal.x)
	var right = Vector2(goal.y, -goal.x)
	var run_l = _clear_run(i, left.x, left.y)
	var run_r = _clear_run(i, right.x, right.y)
	var cur = Vector2(sim.dir_x[i], sim.dir_y[i])
	if cur.length_squared() > 0.2:
		if cur.dot(left) >= cur.dot(right):
			run_l += 6.0
		else:
			run_r += 6.0
	return left if run_l >= run_r else right



## Briefly suppresses replanned seeks after an unstick or failed step to reduce oscillation.
func _hold_avoid(i: int, secs: float = 0.2) -> void:
	if i < 0 or i >= sim.avoid_t.size():
		return
	sim.avoid_t[i] = maxf(sim.avoid_t[i], secs)



## Goal-directed locomotion with BFS hops, peeling, unstick, and seek memory for agents.
func _walk(i: int, tx: float, ty: float, speed: float, dt: float) -> void:
	var _walk_t0 = 0
	if sim.save_perf_mode:
		_walk_t0 = Time.get_ticks_usec()
	if sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]):
		sim.collision._unstick(i)
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
		if sim.save_perf_mode:
			sim.set_meta("_ap_walk_us", int(sim.get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	var dx = tx - sim.pos_x[i]
	var dy = ty - sim.pos_y[i]
	var dist = sqrt(dx * dx + dy * dy)
	if dist < 1.0:
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
		if i < sim.avoid_t.size():
			sim.avoid_t[i] = 0.0
		if sim.save_perf_mode:
			sim.set_meta("_ap_walk_us", int(sim.get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	if i < sim.seek_t.size():
		sim.seek_x[i] = tx
		sim.seek_y[i] = ty
		sim.seek_t[i] = Catalog.SEEK_HOLD
	if sim.avoid_t[i] > 0.0:
		sim.avoid_t[i] = maxf(0.0, sim.avoid_t[i] - dt)
	var step = speed * dt
	var hop = _path_hop(sim.pos_x[i], sim.pos_y[i], tx, ty)
	if hop == Vector2.ZERO:
		# No improving BFS step (blocked goal / sealed best). Stopping beats
		# unstick-teleport bouncing inside a tree enclosure forever.
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
		if sim.save_perf_mode:
			sim.set_meta("_ap_walk_us", int(sim.get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	# Already on the best open cell (blocked goal / dead-end approach) — stop, do not unstick-spin.
	if absf(hop.x - sim.pos_x[i]) <= 0.5 and absf(hop.y - sim.pos_y[i]) <= 0.5:
		if sim.collision._move_blocked(tx, ty) or dist <= float(Catalog.TILE) * 1.25:
			if i < sim.seek_t.size():
				sim.seek_t[i] = 0.0
		if sim.save_perf_mode:
			sim.set_meta("_ap_walk_us", int(sim.get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))
		return
	var moved = _steer_toward(i, hop.x, hop.y, step)
	if not moved:
		# Peel around the blocker toward the hop; unstick only when wedged.
		var toward = Vector2(hop.x - sim.pos_x[i], hop.y - sim.pos_y[i])
		var peel = _open_dir(i, toward)
		if peel == Vector2.ZERO:
			peel = _open_dir(i, _side_dir(i, toward))
		if peel != Vector2.ZERO:
			sim.dir_x[i] = peel.x
			sim.dir_y[i] = peel.y
			_snap_dir_cardinal(i)
			moved = _move_cardinal_toward(i, sim.pos_x[i] + sim.dir_x[i] * 32.0, sim.pos_y[i] + sim.dir_y[i] * 32.0, step)
		if not moved:
			if sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]) or sim.collision._corner_trap(i):
				sim.collision._unstick(i)
			if i < sim.seek_t.size():
				sim.seek_t[i] = 0.0
	elif sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]):
		sim.collision._unstick(i)
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
	if sim.save_perf_mode:
		sim.set_meta("_ap_walk_us", int(sim.get_meta("_ap_walk_us", 0)) + (Time.get_ticks_usec() - _walk_t0))



## Steps one frame toward a hop using cardinal alignment on grid neighbors else free steer.
func _steer_toward(i: int, tx: float, ty: float, step: float) -> bool:
	# Cardinal BFS hops stay on one axis (no cell-center zigzag). Open space steers linearly.
	var hop_cell = sim.spatial._cell_vec(tx, ty)
	var cur_cell = sim.spatial._cell_vec(sim.pos_x[i], sim.pos_y[i])
	var dc = hop_cell - cur_cell
	if absi(dc.x) + absi(dc.y) == 1:
		if dc.x != 0:
			return _move_cardinal_toward(i, tx, sim.pos_y[i], step)
		return _move_cardinal_toward(i, sim.pos_x[i], ty, step)
	var adx = tx - sim.pos_x[i]
	var ady = ty - sim.pos_y[i]
	# Ignore sub-tile drift on the minor axis so "up" stays a straight line.
	if absf(adx) <= 1.5 and absf(ady) > absf(adx):
		adx = 0.0
	elif absf(ady) <= 1.5 and absf(adx) > absf(ady):
		ady = 0.0
	var len = sqrt(adx * adx + ady * ady)
	if len < 0.01:
		return false
	var mx = adx / len * step
	var my = ady / len * step
	if absf(mx) > absf(adx):
		mx = adx
	if absf(my) > absf(ady):
		my = ady
	var nx = sim.pos_x[i] + mx
	var ny = sim.pos_y[i] + my
	if not sim.collision._move_blocked(nx, ny):
		sim.dir_x[i] = mx / step if step > 0.0001 else 0.0
		sim.dir_y[i] = my / step if step > 0.0001 else 0.0
		_move(i, mx, my)
		return true
	return _move_cardinal_toward(i, tx, ty, step)



## Moves along one axis per frame to avoid wedging agents into tree corners.
func _move_cardinal_toward(i: int, tx: float, ty: float, step: float) -> bool:
	# One axis per frame — diagonals wedge thronglets into tree/rock corners.
	var adx = tx - sim.pos_x[i]
	var ady = ty - sim.pos_y[i]
	var sx = 0.0 if absf(adx) <= 0.5 else signf(adx)
	var sy = 0.0 if absf(ady) <= 0.5 else signf(ady)
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
		var nx = sim.pos_x[i] + delta.x
		var ny = sim.pos_y[i] + delta.y
		if sim.collision._move_blocked(nx, ny):
			continue
		sim.dir_x[i] = 0.0 if is_zero_approx(delta.x) else signf(delta.x)
		sim.dir_y[i] = 0.0 if is_zero_approx(delta.y) else signf(delta.y)
		_move(i, delta.x, delta.y)
		return true
	return false



## Next world waypoint toward a goal via axis clearance or one BFS grid step.
func _path_hop(fx: float, fy: float, tx: float, ty: float) -> Vector2:
	# Next waypoint: open-field goal, else one BFS cell (never a far L-corner —
	# steering at a distant corner chords through tree walls / enclosure gaps).
	var adx = absf(tx - fx)
	var ady = absf(ty - fy)
	if adx < 1.0 and ady < 1.0:
		return Vector2(tx, ty)
	var h_then_v = _axis_clear(fx, fy, tx, fy) and (ady < 1.0 or _axis_clear(tx, fy, tx, ty))
	var v_then_h = _axis_clear(fx, fy, fx, ty) and (adx < 1.0 or _axis_clear(fx, ty, tx, ty))
	if h_then_v and v_then_h and _axis_clear(fx, fy, tx, ty):
		return Vector2(tx, ty)
	var next_cell = _bfs_next_cell(sim.spatial._cell_vec(fx, fy), sim.spatial._cell_vec(tx, ty))
	if next_cell.x <= -999000:
		return Vector2.ZERO
	return sim.world_entities._cell_world(next_cell)



## True when a straight segment between two points has no blocking tiles along it.
func _axis_clear(ax: float, ay: float, bx: float, by: float) -> bool:
	var dx = bx - ax
	var dy = by - ay
	var dist = sqrt(dx * dx + dy * dy)
	if dist < 0.5:
		return not sim.collision._move_blocked(bx, by)
	var steps = maxi(1, int(ceil(dist / 4.0)))
	for s in range(1, steps + 1):
		var t = float(s) / float(steps)
		if sim.collision._move_blocked(ax + dx * t, ay + dy * t):
			return false
	return true



## First walkable grid step from [param start] toward [param goal] within PATH_BFS_MAX.
func _bfs_next_cell(start: Vector2i, goal: Vector2i) -> Vector2i:
	var miss = Vector2i(-999999, -999999)
	if start == goal:
		return start
	var goal_at = sim.world_entities._cell_world(goal)
	var goal_open = not sim.collision._move_blocked(goal_at.x, goal_at.y)
	var q: Array[Vector2i] = [start]
	var came = {}
	came[start] = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited = 0
	var best = start
	var best_d = start.distance_squared_to(goal)
	while not q.is_empty() and visited < sim.PATH_BFS_MAX:
		var cur: Vector2i = q.pop_front()
		visited += 1
		var d0 = cur.distance_squared_to(goal)
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
			var at = sim.world_entities._cell_world(nxt)
			if sim.collision._move_blocked(at.x, at.y):
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



## Full cardinal cell path from start to goal or best approach when the goal cell is blocked.
func _bfs_path_cells(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal:
		out.append(start)
		return out
	var goal_at = sim.world_entities._cell_world(goal)
	var goal_open = not sim.collision._move_blocked(goal_at.x, goal_at.y)
	var q: Array[Vector2i] = [start]
	var came = {}
	came[start] = start
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited = 0
	var best = start
	var best_d = start.distance_squared_to(goal)
	while not q.is_empty() and visited < sim.PATH_BFS_MAX:
		var cur: Vector2i = q.pop_front()
		visited += 1
		var d0 = cur.distance_squared_to(goal)
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
			var at = sim.world_entities._cell_world(nxt)
			if sim.collision._move_blocked(at.x, at.y):
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
	var i = stack.size() - 1
	while i >= 0:
		out.append(stack[i])
		i -= 1
	return out



## Whether a diagonal step hits an inside corner between two axis blockers.
func _convex_corner_at(px: float, py: float, dx: float, dy: float) -> bool:
	var sx = 0.0 if absf(dx) < 0.001 else signf(dx)
	var sy = 0.0 if absf(dy) < 0.001 else signf(dy)
	if sx == 0.0 or sy == 0.0:
		return false
	var probe = 4.0
	var can_x = not sim.collision._move_blocked(px + sx * probe, py)
	var can_y = not sim.collision._move_blocked(px, py + sy * probe)
	return can_x and can_y and sim.collision._move_blocked(px + sx * probe, py + sy * probe)



## Raycast along a move intent for blockers or convex corners within a limit.
func _goal_path_blocked(px: float, py: float, dx: float, dy: float, limit: float) -> bool:
	# Scan the approach. A late 4px probe wasted a walk into the corner.
	var span = minf(limit, 40.0)
	if span < 4.0:
		return _convex_corner_at(px, py, dx, dy)
	var clear = 0.0
	var step = 4.0
	while clear + step <= span:
		clear += step
		var x = px + dx * clear
		var y = py + dy * clear
		if sim.collision._move_blocked(x, y):
			return true
		if _convex_corner_at(x, y, dx, dy):
			return true
	return false



## Axis-separated slide for one agent against blockers; updates wear and spatial hash.
func _move(i: int, dx: float, dy: float) -> void:
	var ox = sim.pos_x[i]
	var oy = sim.pos_y[i]
	var moved = false
	var can_x = not sim.collision._move_blocked(ox + dx, oy)
	var can_y = not sim.collision._move_blocked(ox, oy + dy)
	if can_x and can_y and not sim.collision._move_blocked(ox + dx, oy + dy):
		sim.pos_x[i] = ox + dx
		sim.pos_y[i] = oy + dy
		sim.paths._wear_ground(i)
		sim.spatial._hash_relocate(i)
		return
	# Convex corner: commit to one axis. Do not unstick — that bounces them
	# backward and _walk then charges the same corner again.
	if can_x and can_y:
		var use_x = absf(dx) >= absf(dy)
		if absf(sim.dir_x[i]) > 0.7 and absf(sim.dir_y[i]) < 0.3:
			use_x = can_x
		elif absf(sim.dir_y[i]) > 0.7 and absf(sim.dir_x[i]) < 0.3:
			use_x = false
		else:
			var sx = 0.0 if absf(dx) < 0.0001 else signf(dx)
			var sy = 0.0 if absf(dy) < 0.0001 else signf(dy)
			var run_x = 0.0 if sx == 0.0 else sim.collision._clear_run_at(ox, oy, sx, 0.0)
			var run_y = 0.0 if sy == 0.0 else sim.collision._clear_run_at(ox, oy, 0.0, sy)
			if run_x > run_y:
				use_x = true
			elif run_y > run_x:
				use_x = false
		if use_x and can_x:
			sim.pos_x[i] = ox + dx
			sim.dir_x[i] = 0.0 if absf(dx) < 0.0001 else signf(dx)
			sim.dir_y[i] = 0.0
			moved = true
		elif can_y:
			sim.pos_y[i] = oy + dy
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0 if absf(dy) < 0.0001 else signf(dy)
			moved = true
		if moved:
			_hold_avoid(i, 0.95)
		else:
			sim.collision._unstick(i)
			_hold_avoid(i, 1.1)
		if sim.pos_x[i] != ox or sim.pos_y[i] != oy:
			sim.paths._wear_ground(i)
			sim.spatial._hash_relocate(i)
		return
	if can_x:
		sim.pos_x[i] = ox + dx
		moved = true
	if not sim.collision._move_blocked(sim.pos_x[i], oy + dy):
		sim.pos_y[i] = oy + dy
		moved = true
	elif can_y and not can_x:
		sim.pos_y[i] = oy + dy
		moved = true
	if not moved:
		sim.collision._unstick(i)
		_hold_avoid(i, 1.1)
	elif sim.collision._corner_trap(i):
		sim.collision._unstick(i)
		_hold_avoid(i, 1.1)
	if sim.pos_x[i] != ox or sim.pos_y[i] != oy:
		sim.paths._wear_ground(i)
		sim.spatial._hash_relocate(i)


