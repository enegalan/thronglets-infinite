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
	var mid := Vector2(256.0, 256.0)
	for feat in sim.features:
		if not feat.dead and Vector2(float(feat.x), float(feat.y)).distance_to(mid) < 140.0:
			feat.dead = true
	var id := sim._push_slot(mid.x, mid.y, 100.0, 100.0, 100.0, 0.0, 0)
	sim._rebuild_hash()
	sim.view_rect = Rect2(mid - Vector2(220, 220), Vector2(440, 440))
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	var dt := 1.0 / 30.0
	var frozen_at := Vector2.INF
	var drift := 0.0
	var saw_split := false
	for frame in 500:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim._step(dt)
		var charging: bool = sim.mito_charge[id] > 0.0
		var splitting: bool = sim.mito_t[id] > 0.0
		if splitting:
			saw_split = true
		if charging or splitting:
			var at := Vector2(sim.pos_x[id], sim.pos_y[id])
			if frozen_at == Vector2.INF:
				frozen_at = at
			drift = maxf(drift, at.distance_to(frozen_at))
		elif frozen_at != Vector2.INF:
			break
	var ok := saw_split and frozen_at != Vector2.INF and drift < 0.01
	print("PROBE mitosis still split=%s frozen=%s drift=%.3f result=%s" % [
		str(saw_split), str(frozen_at != Vector2.INF), drift, "PASS" if ok else "FAIL"
	])
	quit(0 if ok else 1)
