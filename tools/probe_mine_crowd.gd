extends SceneTree

const SimScript := preload("res://ThrongletSimServer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	sim.shot_mode = false
	sim.world_seed = 7777
	seed(7777)
	root.add_child(sim)
	await process_frame
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.mine = true
	sim.unlocks.bathtub = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var ore := {}
	for feat in sim.features:
		if not feat.dead and int(feat.cx) == 0 and sim._ore_tier(int(feat.kind)) > 0:
			ore = feat
			break
	if ore.is_empty():
		print("PROBE FAIL no ore")
		quit(1)
		return
	# Clear blocking props around the ore pad so the 6x5 mine fits.
	var ore_at := Catalog.snap_world(float(ore.x), float(ore.y))
	for feat in sim.features:
		if feat.dead or int(feat.id) == int(ore.id):
			continue
		if _dist(float(feat.x), float(feat.y), ore_at.x, ore_at.y) < 120.0:
			feat.dead = true
	sim._rebuild_hash()
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 112.0, ore_at.y + 96.0, 1)
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 128.0, ore_at.y + 96.0, 1)
	if not sim.can_place_building(Catalog.BLD_MINE, ore_at.x, ore_at.y):
		print("PROBE FAIL mine blocked")
		quit(1)
		return
	if not sim.place_building(Catalog.BLD_MINE, ore_at.x, ore_at.y):
		print("PROBE FAIL mine place")
		quit(1)
		return
	var mine := {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MINE:
			mine = b
			break
	if mine.is_empty():
		print("PROBE FAIL mine missing")
		quit(1)
		return
	var tub := {}
	for attempt in 48:
		var px := float(mine.x) + 112.0 + float((attempt % 6) - 2) * 16.0
		var py := float(mine.y) + 48.0 + float(int(attempt / 6) - 2) * 16.0
		var at := Catalog.snap_world(px, py)
		if sim._building_spot_free(-1, at.x, at.y, Catalog.BLD_TUB):
			tub = sim._add_building(Catalog.BLD_TUB, at.x, at.y)
			if not tub.is_empty():
				break
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	var ids: Array[int] = []
	var gate := sim._approach_building(mine, -1)
	for n in 8:
		var id := sim._push_slot(gate.x + float(n) * 10.0, gate.y + 18.0, 92.0, 92.0, 92.0, 0.0, n % 4)
		if id >= 0:
			ids.append(id)
	if ids.is_empty():
		print("PROBE FAIL spawn")
		quit(1)
		return
	sim.clean[ids[0]] = 15.0
	if not tub.is_empty() and ids.size() > 1:
		sim._claim_tub(ids[1], tub)
		tub.bath_t = 0.2
		sim.act[ids[1]] = SimScript.ACT_BATH
		sim.pos_x[ids[1]] = float(tub.x) + Catalog.TUB_SEAT_OFF.x
		sim.pos_y[ids[1]] = float(tub.y) + Catalog.TUB_SEAT_OFF.y
	sim._rebuild_hash()
	print("PROBE mine=(%.1f,%.1f) tub=%s n=%d" % [float(mine.x), float(mine.y), str(not tub.is_empty()), ids.size()])
	var dt := 1.0 / 30.0
	var max_jobs := 0
	var dirty_mined := false
	for frame in 240:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		sim._step(dt)
		var jobs := sim._mine_jobs(mine)
		max_jobs = maxi(max_jobs, jobs)
		var dirty := ids[0]
		if int(sim.mine_job[dirty]) == int(mine.id):
			dirty_mined = true
		if frame % 30 == 0:
			print("SHOT t=%.1f jobs=%d workers=%d dirty_clean=%.0f dirty_job=%d dirty_act=%d" % [
				float(frame) * dt,
				jobs,
				sim._workers_near(mine, 8),
				sim.clean[dirty],
				int(sim.mine_job[dirty]),
				int(sim.act[dirty]),
			])
	var pass_ok := max_jobs <= 2 and not dirty_mined
	print("PROBE max_jobs=%d dirty_mined=%s" % [max_jobs, str(dirty_mined)])
	print("PROBE result=%s" % ("PASS" if pass_ok else "FAIL"))
	quit(0 if pass_ok else 1)


func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
