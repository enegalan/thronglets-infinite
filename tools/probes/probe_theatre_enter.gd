extends SceneTree

const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")


func _init() -> void:
	call_deferred("_run")


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
	sim.unlocks.theatre = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var mid := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if _dist(float(feat.x), float(feat.y), mid.x, mid.y) < 160.0:
			feat.dead = true
	var show_b := _place(sim, Catalog.BLD_THEATRE, mid)
	if show_b.is_empty():
		print("PROBE FAIL place theatre")
		quit(1)
		return
	var rim := sim._approach_building(show_b, -1)
	var center := sim._footprint_center_of(show_b)
	var away := (rim - center).normalized()
	# Stand just outside the old 10px rim, inside _walk's TILE*1.25 give-up zone.
	var door_stuck := rim + away * 15.0
	if sim._move_blocked(door_stuck.x, door_stuck.y):
		door_stuck = rim
	var inside := sim._inside_building_reach(float(door_stuck.x), float(door_stuck.y), show_b)
	print("PROBE theatre=(%.1f,%.1f) rim=(%.1f,%.1f) stuck=(%.1f,%.1f) stuck_inside=%s d_rim=%.1f" % [
		float(show_b.x), float(show_b.y), float(rim.x), float(rim.y),
		door_stuck.x, door_stuck.y, str(inside), door_stuck.distance_to(rim)
	])
	var seeker := sim._push_slot(door_stuck.x, door_stuck.y, 95.0, 20.0, 95.0, 0.0, 0)
	if seeker < 0:
		print("PROBE FAIL spawn")
		quit(1)
		return
	sim._rebuild_hash()
	sim.view_rect = Rect2(mid - Vector2(220, 220), Vector2(440, 440))
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	sim.smoke_hold = false
	var entered := false
	var fun_up := false
	var stay_ok := false
	var hidden := false
	var start_fun := float(sim.amused[seeker])
	var dt := 1.0 / 30.0
	for frame in 60:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim.amused[seeker] = minf(sim.amused[seeker], 40.0)
		sim.fed[seeker] = 95.0
		sim.clean[seeker] = 95.0
		sim._step(dt)
		if sim._is_guest(show_b, seeker):
			entered = true
			if sim.indoors(seeker):
				hidden = true
			var left := 0.0
			for guest in show_b.get("guests", []):
				if int(guest.id) == seeker:
					left = float(guest.left)
					break
			if left >= 29.0:
				stay_ok = true
		if float(sim.amused[seeker]) > start_fun + 2.0:
			fun_up = true
		if frame % 30 == 0:
			print("SHOT t=%.1f act=%d amused=%.0f guest=%s indoors=%s" % [
				float(frame) * dt,
				int(sim.act[seeker]),
				sim.amused[seeker],
				str(sim._is_guest(show_b, seeker)),
				str(sim.indoors(seeker)),
			])
		if entered and fun_up and stay_ok and hidden:
			break
	var rule_stay := float(sim._visit_rule(Catalog.BLD_THEATRE).get("stay", 0.0))
	print("PROBE entered=%s fun_up=%s stay_ok=%s hidden=%s rule_stay=%.0f active=%s" % [
		str(entered), str(fun_up), str(stay_ok), str(hidden), rule_stay,
		str(bool(show_b.get("active", false)))
	])
	var ok := entered and fun_up and stay_ok and hidden and rule_stay >= 30.0
	print("PROBE result=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


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


func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
