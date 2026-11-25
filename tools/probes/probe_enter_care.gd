extends SceneTree


## Headless check that throngs enter care buildings and respect capacity rules.

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
	# _ready clears testing unless --smoke/--shot is passed.
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.bathtub = true
	sim.unlocks.roundabout = true
	sim.unlocks.axe = true
	sim.unlocks.hammer = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var mid := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if _dist(float(feat.x), float(feat.y), mid.x, mid.y) < 140.0:
			feat.dead = true
	var tub := _place(sim, Catalog.BLD_TUB, mid)
	var round_b := _place(sim, Catalog.BLD_ROUND, mid + Vector2(80.0, 0.0))
	if tub.is_empty() or round_b.is_empty():
		print("PROBE FAIL place tub=%s round=%s" % [not tub.is_empty(), not round_b.is_empty()])
		quit(1)
		return
	var dirty_id := sim._push_slot(float(tub.x) + 40.0, float(tub.y) + 8.0, 95.0, 95.0, 20.0, 0.0, 0)
	var fun_id := sim._push_slot(float(round_b.x) + 40.0, float(round_b.y) + 8.0, 95.0, 25.0, 95.0, 0.0, 1)
	if dirty_id < 0 or fun_id < 0:
		print("PROBE FAIL spawn")
		quit(1)
		return
	sim._rebuild_hash()
	sim.view_rect = Rect2(mid - Vector2(220, 220), Vector2(440, 440))
	# Placing care buildings can queue unlock talks that freeze the sim.
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	print("PROBE tub=(%.1f,%.1f) round=(%.1f,%.1f) dirty=%d fun=%d" % [
		float(tub.x), float(tub.y), float(round_b.x), float(round_b.y), dirty_id, fun_id
	])
	var bathed := false
	var rode := false
	var dt := 1.0 / 30.0
	for frame in 360:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim._step(dt)
		var seat := sim.seat_of(dirty_id)
		if not seat.is_empty() and float(seat.get("bath_t", -1.0)) >= 0.0:
			bathed = true
		if not sim.ride_of(fun_id).is_empty():
			rode = true
		if frame % 30 == 0:
			print("SHOT t=%.1f dirty act=%d clean=%.0f bath=%s | fun act=%d amused=%.0f ride=%s" % [
				float(frame) * dt,
				int(sim.act[dirty_id]), sim.clean[dirty_id], str(bathed),
				int(sim.act[fun_id]), sim.amused[fun_id], str(rode),
			])
		if bathed and rode:
			break
	print("PROBE bathed=%s rode=%s" % [str(bathed), str(rode)])
	print("PROBE result=%s" % ("PASS" if bathed and rode else "FAIL"))
	quit(0 if bathed and rode else 1)


## Places a building kind near a world point and returns the slot dict.
func _place(sim, kind: int, around: Vector2) -> Dictionary:
	for attempt in 48:
		var px := around.x + float((attempt % 8) - 4) * 16.0
		var py := around.y + float(int(attempt / 8) - 2) * 16.0
		var at := Catalog.snap_world(px, py)
		if sim._building_spot_free(-1, at.x, at.y, kind):
			var b: Dictionary = sim._add_building(kind, at.x, at.y)
			if not b.is_empty():
				return b
	return {}


## Euclidean distance between two world points.
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
