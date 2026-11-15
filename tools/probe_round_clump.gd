extends SceneTree

const SimScript := preload("res://ThrongletSimServer.gd")


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
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.roundabout = true
	sim.testing = true
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var at := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		var dx := float(feat.x) - at.x
		var dy := float(feat.y) - at.y
		if sqrt(dx * dx + dy * dy) < 120.0:
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
	var mid := at + Catalog.ROUND_RIDE_OFF
	var ids: Array = []
	# Crowd approaching from the same side — the live clump case.
	for n in 6:
		var id := sim._push_slot(mid.x + 40.0 + float(n) * 3.0, mid.y + 8.0 + float(n) * 2.0, 95.0, 30.0 + float(n), 95.0, 0.0, n)
		if id >= 0:
			ids.append(id)
	sim._rebuild_hash()
	sim.view_rect = Rect2(at - Vector2(200, 200), Vector2(400, 400))
	print("PROBE clump round at=(%.1f,%.1f) mid=(%.1f,%.1f) ids=%s" % [at.x, at.y, mid.x, mid.y, str(ids)])
	var dt := 1.0 / 30.0
	var worst_gap := 9999.0
	var clump_frames := 0
	for frame in 300:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim._step(dt)
		var on: Array = []
		for id in ids:
			if not sim.ride_of(int(id)).is_empty():
				on.append(int(id))
		if on.size() >= 2:
			var gaps: Array = []
			for i in on.size():
				for j in range(i + 1, on.size()):
					var g := _dist(sim.pos_x[on[i]], sim.pos_y[on[i]], sim.pos_x[on[j]], sim.pos_y[on[j]])
					gaps.append(g)
					worst_gap = minf(worst_gap, g)
			var min_g := 9999.0
			for g2 in gaps:
				min_g = minf(min_g, float(g2))
			# Adjacent cardinal seats are r*√2 apart; anything under ~1.1r is a pile.
			if min_g < Catalog.ROUND_RIDE_RADIUS * 1.1:
				clump_frames += 1
				if clump_frames <= 5 or frame % 30 == 0:
					var line := "CLUMP t=%.1f min_gap=%.2f slots=%s" % [float(frame) * dt, min_g, str(round_b.get("ride_slot", {}))]
					for id2 in on:
						line += " | %d(%.1f,%.1f)" % [id2, sim.pos_x[id2], sim.pos_y[id2]]
					print(line)
		if frame % 30 == 0:
			var line2 := "SHOT t=%.1f riders=%d spin=%.2f active=%s" % [
				float(frame) * dt, on.size(), float(round_b.get("spin", 0.0)), round_b.get("active", false)
			]
			for id3 in on:
				line2 += " | %d s=%s (%.1f,%.1f)" % [
					id3, str(sim._ride_slot_of(round_b, id3)), sim.pos_x[id3], sim.pos_y[id3]
				]
			print(line2)
	print("PROBE summary riders_final=%s slots=%s worst_gap=%.2f clump_frames=%d" % [
		str(round_b.get("riders", [])), str(round_b.get("ride_slot", {})), worst_gap, clump_frames
	])
	var mounted := 0
	for raw in round_b.get("riders", []):
		if int(raw) >= 0:
			mounted += 1
	var ok := mounted >= 2 and clump_frames == 0 and worst_gap >= Catalog.ROUND_RIDE_RADIUS * 1.2
	print("PROBE result=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
