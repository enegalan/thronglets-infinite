extends SceneTree


## Headless check that a full roundabout is skipped and campers abandon.

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	sim.shot_mode = false
	sim.world_seed = 4242
	seed(4242)
	root.add_child(sim)
	await process_frame
	await process_frame
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.roundabout = true
	sim.unlocks.ball = true
	var at := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if _dist(float(feat.x), float(feat.y), at.x, at.y) < 120.0:
			feat.dead = true
	var round_b := {}
	for attempt in 40:
		var px := at.x + float((attempt % 8) - 4) * 16.0
		var py := at.y + float(int(attempt / 8) - 2) * 16.0
		if sim._building_spot_free(-1, px, py, Catalog.BLD_ROUND):
			round_b = sim._add_building(Catalog.BLD_ROUND, px, py)
			if not round_b.is_empty():
				at = Vector2(float(round_b.x), float(round_b.y))
				break
	if round_b.is_empty():
		print("PROBE FAIL no roundabout")
		quit(1)
		return
	var mid := sim._ride_center_of(round_b)
	var slots_n := sim._ride_slot_count()
	var riders: Array = []
	for n in slots_n:
		var ang := float(n) * TAU / float(slots_n)
		var sx := mid.x + cos(ang) * sim._ride_radius(round_b)
		var sy := mid.y + sin(ang) * sim._ride_radius(round_b)
		var id := sim._push_slot(sx, sy, 95.0, 20.0, 95.0, 0.0, n)
		if id < 0:
			print("PROBE FAIL rider spawn")
			quit(1)
			return
		riders.append(id)
		sim._do_roundabout_ride(id, round_b, 0.2)
	if not sim.structure_full(round_b):
		print("PROBE FAIL not full after seat riders taken=%s need=%s" % [
			sim._taken_ride_slots(round_b).size(), slots_n,
		])
		quit(1)
		return
	var rim := sim._approach_building(round_b, -1)
	var seeker := sim._push_slot(float(rim.x), float(rim.y), 95.0, 15.0, 95.0, 0.0, 99)
	if seeker < 0:
		print("PROBE FAIL seeker spawn")
		quit(1)
		return
	var ball_spot := mid + Vector2(72.0, 8.0)
	if sim._move_blocked(ball_spot.x, ball_spot.y):
		ball_spot = Vector2(float(rim.x) + 40.0, float(rim.y))
	sim._add_item(Catalog.ITEM_BALL, ball_spot.x, ball_spot.y, 1)
	sim._rebuild_hash()
	sim.view_rect = Rect2(at - Vector2(220, 220), Vector2(440, 440))
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	sim.smoke_hold = false
	# Full ride must be invisible to a seeker with no seat claim.
	var nearest := sim._nearest_roundabout(seeker, 320.0)
	if not nearest.is_empty():
		print("PROBE FAIL nearest still returns full ride")
		quit(1)
		return
	var before := Vector2(sim.pos_x[seeker], sim.pos_y[seeker])
	var camp := 0
	var dt := 1.0 / 30.0
	for _frame in 90:
		for id in riders:
			if sim.state[id] == Catalog.ST_LIVING and sim._ride_building(id).is_empty():
				sim.amused[id] = 20.0
				sim._do_roundabout_ride(id, round_b, dt)
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim._step(dt)
		await process_frame
		var d := _dist(sim.pos_x[seeker], sim.pos_y[seeker], mid.x, mid.y)
		var on_ride := not sim._ride_building(seeker).is_empty()
		var has_slot := sim._ride_slot_of(round_b, seeker) >= 0
		var walking := absf(sim.dir_x[seeker]) + absf(sim.dir_y[seeker]) > 0.15
		var near_rim := d < sim._ride_radius(round_b) + 36.0
		if near_rim and walking and not on_ride and not has_slot and sim.amused[seeker] < Catalog.NEED_FUN:
			camp += 1
	var after := Vector2(sim.pos_x[seeker], sim.pos_y[seeker])
	var moved := before.distance_to(after)
	var fun_now: float = float(sim.amused[seeker])
	var fun_gain: float = fun_now - 15.0
	print("PROBE round_full_abandon camp=%s moved=%.1f fun=%.1f full=%s nearest_empty=%s" % [
		camp, moved, fun_now, sim.structure_full(round_b), sim._nearest_roundabout(seeker, 320.0).is_empty(),
	])
	# Must not camp the rim; should leave or play elsewhere.
	var ok: bool = camp < 45 and (moved > 8.0 or fun_gain > 1.0 or fun_now >= Catalog.NEED_FUN)
	if not ok:
		print("PROBE FAIL round_full_abandon")
		quit(1)
		return
	print("PROBE OK round_full_abandon")
	quit(0)


## Euclidean distance between two world points.
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
