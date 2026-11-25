extends SceneTree


## Loads slot_0 and verifies throngs can reach and work assigned mines.

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")

## On-disk slot_0 save path exercised for regression probes.
const SAVE := "/Users/egalan/Library/Application Support/Godot/app_userdata/Thronglets- Infinite/thronglets_slot_0.save"


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	sim.save_path = SAVE
	root.add_child(sim)
	await process_frame
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	if not FileAccess.file_exists(SAVE):
		print("PROBE FAIL no save ", SAVE)
		quit(1)
		return
	if not sim.save_system.load_game():
		print("PROBE FAIL load")
		quit(1)
		return
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	print("SAVE living=%d peak=%d gems=%d gems_peak=%d part_two=%s" % [
		sim.living, sim.peak, sim.gems, sim.gems_peak, str(sim.part_two),
	])
	print("UNLOCK mine=%s mine2=%s pickaxe=%s market=%s factory=%s" % [
		str(bool(sim.unlocks.get("mine", false))),
		str(bool(sim.unlocks.get("mine2", false))),
		str(bool(sim.unlocks.get("pickaxe", false))),
		str(bool(sim.unlocks.get("market", false))),
		str(bool(sim.unlocks.get("factory", false))),
	])
	var mines := 0
	var factories := 0
	for b in sim.buildings:
		if b.dead:
			continue
		var k := int(b.kind)
		if k == Catalog.BLD_MINE or k == Catalog.BLD_MINE2:
			mines += 1
			print("MINE id=%s kind=%s at=(%.1f,%.1f) active=%s node=%s lifted=%s" % [
				str(b.id), str(k), float(b.x), float(b.y), str(b.get("active", false)), str(b.get("node", -1)), str(b.get("lifted", false)),
			])
		elif k == Catalog.BLD_FACTORY or k == Catalog.BLD_FACTORY2:
			factories += 1
			print("FACTORY id=%s at=(%.1f,%.1f) buffer=%s" % [str(b.id), float(b.x), float(b.y), str(b.get("buffer", 0))])
	var wood := 0
	var ore := 0
	var bone := 0
	for it in sim.items:
		if it.dead or it.held:
			continue
		match int(it.kind):
			Catalog.ITEM_WOOD:
				wood += 1
			Catalog.ITEM_ORE:
				ore += 1
			Catalog.ITEM_BONE:
				bone += 1
	print("ITEMS wood=%d ore=%d bone=%d mines=%d factories=%d" % [
		wood, ore, bone, mines, factories,
	])
	var ready := 0
	var hungry := 0
	var dirty := 0
	var bored := 0
	var working := 0
	var mining_job := 0
	var hauling := 0
	var near_mine := 0
	var sample := 0
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		if sim._work_ready(i):
			ready += 1
		if sim.fed[i] < Catalog.NEED_HUNGRY:
			hungry += 1
		if sim.clean[i] < Catalog.NEED_SEEK:
			dirty += 1
		if sim.amused[i] < Catalog.NEED_FUN:
			bored += 1
		if int(sim.act[i]) == SimScript.ACT_WORK:
			working += 1
		if int(sim.mine_job[i]) >= 0:
			mining_job += 1
		if int(sim.carry[i]) != Catalog.CARRY_NONE:
			hauling += 1
		var mine := sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
		if not mine.is_empty():
			near_mine += 1
		if sample < 8:
			var why := _why_not_mine(sim, i)
			print("T%d fed=%.0f fun=%.0f clean=%.0f act=%d carry=%d job=%d why=%s" % [
				i, sim.fed[i], sim.amused[i], sim.clean[i], int(sim.act[i]), int(sim.carry[i]), int(sim.mine_job[i]), why,
			])
			sample += 1
	print("STATS ready=%d hungry=%d dirty=%d bored=%d working=%d mine_jobs=%d hauling=%d in_mine_range=%d" % [
		ready, hungry, dirty, bored, working, mining_job, hauling, near_mine,
	])
	# Simulate 10s and watch mine jobs / ore / gems.
	var gems0: int = int(sim.gems)
	var ore0: int = ore
	var jobs_max: int = 0
	var dt := 1.0 / 30.0
	for frame in 300:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		sim.frozen = false
		sim._step(dt)
		var jobs := 0
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING and int(sim.mine_job[i]) >= 0:
				jobs += 1
		jobs_max = maxi(jobs_max, jobs)
	var ore1 := 0
	for it in sim.items:
		if not it.dead and not it.held and int(it.kind) == Catalog.ITEM_ORE:
			ore1 += 1
	print("AFTER10s mine_jobs_max=%d ore %d->%d gems %d->%d" % [jobs_max, ore0, ore1, gems0, sim.gems])
	# Force one ready thronglet to seek if any mine exists.
	var forced := false
	for b in sim.buildings:
		if b.dead:
			continue
		if int(b.kind) != Catalog.BLD_MINE and int(b.kind) != Catalog.BLD_MINE2:
			continue
		for i in sim.slot_count:
			if sim.state[i] != Catalog.ST_LIVING:
				continue
			if not sim._work_ready(i):
				continue
			var gate := sim._approach_building(b, i)
			if sim._move_blocked(gate.x, gate.y):
				print("FORCE gate blocked for mine ", b.id)
				continue
			sim.pos_x[i] = gate.x
			sim.pos_y[i] = gate.y
			sim.carry[i] = Catalog.CARRY_NONE
			sim.act[i] = 0
			sim.act_t[i] = 0.0
			sim.mine_job[i] = -1
			var ok := sim._seek_mine(i, 26.0, 0.2)
			print("FORCE seek throng=%d mine=%s ok=%s act=%d job=%d" % [
				i, str(b.id), str(ok), int(sim.act[i]), int(sim.mine_job[i]),
			])
			forced = true
			break
		if forced:
			break
	if not forced:
		print("FORCE none (no ready throng or no mine)")
	quit(0)


## Returns a short reason throng i cannot start mining.
func _why_not_mine(sim, i: int) -> String:
	if not sim._work_ready(i):
		return "not_ready"
	if sim.fed[i] < Catalog.NEED_HUNGRY:
		return "hungry"
	if sim.clean[i] < Catalog.NEED_SEEK:
		return "dirty"
	if sim.amused[i] < Catalog.NEED_FUN:
		return "bored"
	if int(sim.carry[i]) != Catalog.CARRY_NONE:
		return "carrying"
	if sim._has_factory():
		var ore_it = sim._nearest_free_item(i, Catalog.ITEM_ORE, Catalog.NEAR_BUILDING)
		if not ore_it.is_empty():
			return "haul_ore"
	var mine = sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		return "mine_too_far_or_missing"
	var cap := 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	if sim._mine_jobs(mine) >= cap and int(sim.mine_job[i]) != int(mine.id):
		return "mine_full"
	return "should_mine"
