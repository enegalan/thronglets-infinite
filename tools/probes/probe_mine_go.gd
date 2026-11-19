extends SceneTree

const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
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
	sim.part_two = true
	var ore := {}
	for feat in sim.features:
		if not feat.dead and int(feat.cx) == 0 and sim._ore_tier(int(feat.kind)) > 0:
			ore = feat
			break
	if ore.is_empty():
		print("PROBE FAIL no ore")
		quit(1)
		return
	var ore_at := Catalog.snap_world(float(ore.x), float(ore.y))
	for feat in sim.features:
		if feat.dead or int(feat.id) == int(ore.id):
			continue
		if _dist(float(feat.x), float(feat.y), ore_at.x, ore_at.y) < 120.0:
			feat.dead = true
	sim._rebuild_hash()
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 112.0, ore_at.y + 96.0, 1)
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 128.0, ore_at.y + 96.0, 1)
	if not sim.place_building(Catalog.BLD_MINE, ore_at.x, ore_at.y):
		print("PROBE FAIL mine place")
		quit(1)
		return
	var mine := {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MINE:
			mine = b
			break
	for it in sim.items:
		if int(it.kind) == Catalog.ITEM_WOOD or int(it.kind) == Catalog.ITEM_ORE or int(it.kind) == Catalog.ITEM_BONE:
			it.dead = true
	var gate := sim._approach_building(mine, -1)
	# Find a walkable spawn ~120px from the gate.
	var spawn := Vector2.ZERO
	for n in 32:
		var ang := float(n) * (TAU / 32.0)
		var px := gate.x + cos(ang) * 120.0
		var py := gate.y + sin(ang) * 120.0
		if not sim._move_blocked(px, py) and sim._land_inland(px, py):
			spawn = Vector2(px, py)
			break
	if spawn == Vector2.ZERO:
		print("PROBE FAIL no walkable spawn near gate=", gate)
		quit(1)
		return
	var id := sim._push_slot(spawn.x, spawn.y, 95.0, 95.0, 95.0, 0.0, 0)
	if id < 0:
		print("PROBE FAIL spawn")
		quit(1)
		return
	sim.mito_charge[id] = 0.0
	sim.cool[id] = 999.0
	sim._rebuild_hash()
	sim._restore_gaze()
	sim.frozen = false
	var start_d := _dist(sim.pos_x[id], sim.pos_y[id], float(mine.x), float(mine.y))
	print("PROBE start_d=%.1f spawn=(%.1f,%.1f) gate=(%.1f,%.1f) blocked=%s" % [
		start_d, spawn.x, spawn.y, gate.x, gate.y, str(sim._move_blocked(spawn.x, spawn.y)),
	])
	var dt := 1.0 / 30.0
	var worked := false
	var min_d := start_d
	for frame in 600:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		sim.frozen = false
		sim.fed[id] = 95.0
		sim.amused[id] = 95.0
		sim.clean[id] = 95.0
		sim.cool[id] = 999.0
		sim.mito_charge[id] = 0.0
		sim._step(dt)
		var d := _dist(sim.pos_x[id], sim.pos_y[id], float(mine.x), float(mine.y))
		min_d = minf(min_d, d)
		if int(sim.act[id]) == SimScript.ACT_WORK and int(sim.mine_job[id]) == int(mine.id) and d < 80.0:
			worked = true
		if frame % 30 == 0:
			print("SHOT t=%.1f d=%.1f job=%d act=%d pos=(%.1f,%.1f)" % [
				float(frame) * dt, d, int(sim.mine_job[id]), int(sim.act[id]), sim.pos_x[id], sim.pos_y[id],
			])
		if worked:
			break
	print("PROBE worked=%s min_d=%.1f job=%d act=%d" % [str(worked), min_d, int(sim.mine_job[id]), int(sim.act[id])])
	print("PROBE result=%s" % ("PASS" if worked else "FAIL"))
	quit(0 if worked else 1)


func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
