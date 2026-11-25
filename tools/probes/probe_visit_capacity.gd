extends SceneTree

## Prove dwell/theatre capacity_info + occupancy_text (FULL/LLENO), and factories stay empty.


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
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.dwelling = true
	sim.unlocks.theatre = true
	sim.unlocks.factory = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var mid := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if _dist(float(feat.x), float(feat.y), mid.x, mid.y) < Catalog.NEAR_BUILDING:
			feat.dead = true
	var errors: Array = []
	var home := _place(sim, Catalog.BLD_DWELL, mid)
	if home.is_empty():
		errors.append("place dwell failed")
	var show_b := _place(sim, Catalog.BLD_THEATRE, mid + Vector2(96, 0))
	if show_b.is_empty():
		errors.append("place theatre failed")
	var factory := _place(sim, Catalog.BLD_FACTORY, mid + Vector2(0, 96))
	if factory.is_empty():
		errors.append("place factory failed")
	if not errors.is_empty():
		for e in errors:
			print("PROBE FAIL %s" % e)
		quit(1)
		return
	var home_cap := int(sim.capacity_info(home).get("cap", 0))
	if home_cap < 1:
		errors.append("dwell capacity_info empty: %s" % str(sim.capacity_info(home)))
	# Fill dwell to cap via _enter_visit.
	var ids: Array = []
	for i in home_cap:
		var rim: Vector2 = sim._approach_building(home, -1)
		var id := sim._push_slot(rim.x, rim.y, 40.0, 40.0, 40.0, 0.0, 0)
		if id < 0:
			errors.append("spawn guest %d failed" % i)
			continue
		if not sim._enter_visit(id, home):
			errors.append("enter_visit failed for %d" % id)
		ids.append(id)
	sim._rebuild_hash()
	var info: Dictionary = sim.capacity_info(home)
	if not bool(info.get("visit", false)):
		errors.append("dwell not marked visit: %s" % str(info))
	if not bool(info.get("full", false)):
		errors.append("dwell not full after %d guests: %s live=%d" % [home_cap, str(info), sim._live_guests(home)])
	if sim.occupancy_text(home) != "LLENO":
		errors.append("dwell occupancy expected LLENO got '%s'" % sim.occupancy_text(home))
	# Theatre partial: gauge only, no "n/cap" text.
	var t_rim: Vector2 = sim._approach_building(show_b, -1)
	var tid := sim._push_slot(t_rim.x, t_rim.y, 90.0, 90.0, 20.0, 0.0, 0)
	if tid < 0 or not sim._enter_visit(tid, show_b):
		errors.append("theatre guest enter failed")
	else:
		var tinfo: Dictionary = sim.capacity_info(show_b)
		if int(tinfo.get("n", 0)) < 1 or bool(tinfo.get("full", true)):
			errors.append("theatre partial expected n>=1 not full: %s" % str(tinfo))
		if sim.occupancy_text(show_b) != "":
			errors.append("theatre partial must not show counter, got '%s'" % sim.occupancy_text(show_b))
	home.guests = []
	if sim.occupancy_text(home) != "":
		errors.append("empty dwell must not show counter, got '%s'" % sim.occupancy_text(home))
	# Factory must never report capacity marks.
	if not sim.capacity_info(factory).is_empty():
		errors.append("factory capacity_info should be empty: %s" % str(sim.capacity_info(factory)))
	if sim.occupancy_text(factory) != "":
		errors.append("factory occupancy should be empty got '%s'" % sim.occupancy_text(factory))
	if errors.is_empty():
		print("PROBE PASS dwell_full=%s theatre=%s factory_empty=1" % [str(info), str(sim.capacity_info(show_b))])
	else:
		for e in errors:
			print("PROBE FAIL %s" % e)
	quit(0 if errors.is_empty() else 1)


## Places a building kind near a world point and returns the slot dict.
func _place(sim, kind: int, around: Vector2) -> Dictionary:
	for attempt in 64:
		var px := around.x + float((attempt % 8) - 4) * 16.0
		var py := around.y + float(int(attempt / 8) - 3) * 16.0
		var at := Catalog.snap_world(px, py)
		if sim._building_spot_free(-1, at.x, at.y, kind):
			var b: Dictionary = sim._add_building(kind, at.x, at.y)
			if not b.is_empty():
				return b
	return {}


## Euclidean distance between two world points.
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	return Vector2(ax, ay).distance_to(Vector2(bx, by))
