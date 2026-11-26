extends SceneTree

## Production-path mine cycle checks (real ThrongletSimServer._step, no mocks).
## Phases:
##   A) passive stock fill to FULL without factory/workers
##   B) diggers enter/exit with ore once factory exists
##   C) haul to factory buffer and gem gain

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript = preload("res://scripts/core/ThrongletSimServer.gd")


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
func _run() -> void:
	var errors: Array[String] = []
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
		sim.world_entities._bootstrap_new()
	sim.island_gen.seed_mine_nodes(0, 0)
	for key in ["mine", "factory", "pickaxe", "market"]:
		sim.unlocks[key] = true
	sim.gems = 500
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()

	var ore = {}
	for feat in sim.features:
		if feat.dead:
			continue
		if sim.building_sim._ore_tier(int(feat.kind)) > 0:
			ore = feat
			break
	if ore.is_empty():
		print("PROBE FAIL no ore")
		quit(1)
		return

	var ore_at = Catalog.snap_world(float(ore.x), float(ore.y))
	for feat in sim.features:
		if feat.dead or int(feat.id) == int(ore.id):
			continue
		if _dist(float(feat.x), float(feat.y), ore_at.x, ore_at.y) < 140.0:
			feat.dead = true
	for b in sim.buildings:
		if b.dead:
			continue
		if _dist(float(b.x), float(b.y), ore_at.x, ore_at.y) < 140.0:
			b.dead = true
	sim.spatial._rebuild_hash()
	sim.world_entities._rebuild_kind_indexes()
	sim.building_sim._invalidate_factory_cache()

	var node_tier = maxi(1, sim.building_sim._ore_tier(int(ore.kind)))
	sim.world_entities._kill_feature(ore)
	var mine: Dictionary = sim.world_entities._add_building(Catalog.BLD_MINE, ore_at.x, ore_at.y)
	if mine.is_empty():
		print("PROBE FAIL mine place")
		quit(1)
		return
	mine.node = node_tier
	mine.buffer = 0
	mine.timer = 0.01

	# --- A: passive fill to FULL, no factory ---
	print("PHASE A passive fill (no factory)")
	var dt = 1.0 / 30.0
	var t = 0.0
	var filled_at = -1.0
	var fill_limit = SimScript.MINE_FILL_TIME * float(SimScript.MINE_STOCK_CAP) + 4.0
	while t < fill_limit:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		sim.frozen = false
		sim._step(dt)
		t += dt
		var stock = int(mine.get("buffer", 0))
		var info: Dictionary = sim.building_sim.capacity_info(mine)
		if stock >= SimScript.MINE_STOCK_CAP:
			filled_at = t
			if not bool(info.get("full", false)):
				errors.append("capacity_info.full false at stock=%d" % stock)
			if sim.building_sim.occupancy_text(mine) != "LLENO":
				errors.append("occupancy_text expected LLENO got '%s'" % sim.building_sim.occupancy_text(mine))
			break
	print("  stock=%d/%d at t=%.1fs" % [int(mine.get("buffer", 0)), SimScript.MINE_STOCK_CAP, filled_at])
	if filled_at < 0.0:
		errors.append("mine never reached FULL in %.1fs" % fill_limit)
	elif filled_at > SimScript.MINE_FILL_TIME * float(SimScript.MINE_STOCK_CAP) + 2.0:
		errors.append("fill too slow t=%.1f" % filled_at)

	# --- B/C: place factory, seed workers, watch dig/haul/gems ---
	print("PHASE B/C dig + haul + gems")
	var factory = {}
	for attempt in 64:
		var px = float(mine.x) + 96.0 + float((attempt % 8) - 3) * 16.0
		var py = float(mine.y) + float(int(attempt / 8) - 3) * 16.0
		var at = Catalog.snap_world(px, py)
		if sim.building_sim._building_spot_free(-1, at.x, at.y, Catalog.BLD_FACTORY):
			factory = sim.world_entities._add_building(Catalog.BLD_FACTORY, at.x, at.y)
			if not factory.is_empty():
				break
	if factory.is_empty():
		print("PROBE FAIL factory place")
		quit(1)
		return
	sim.building_sim._invalidate_factory_cache()
	if not sim.building_sim._has_factory():
		errors.append("_has_factory false after place")

	var living = 0
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		sim.fed[i] = 100.0
		sim.clean[i] = 100.0
		sim.amused[i] = 100.0
		sim.cool[i] = 2.0
		sim.carry[i] = Catalog.CARRY_NONE
		sim.pos_x[i] = float(mine.x) + 20.0 + float(living % 3) * 10.0
		sim.pos_y[i] = float(mine.y) + 28.0 + float(int(living / 3)) * 10.0
		sim.spatial._hash_relocate(i)
		living += 1
		if living >= 6:
			break
	if living < 2:
		sim.harness.debug_spawn(6, Vector2(float(mine.x) + 24.0, float(mine.y) + 28.0))
		for i in sim.slot_count:
			if sim.state[i] != Catalog.ST_LIVING:
				continue
			sim.fed[i] = 100.0
			sim.clean[i] = 100.0
			sim.amused[i] = 100.0
			sim.cool[i] = 2.0

	var gems0: int = int(sim.gems)
	var stock0: int = int(mine.get("buffer", 0))
	var saw_guest = false
	var saw_hidden_guest = false
	var saw_carry = false
	var saw_exit_carry = false
	var saw_factory_buf = false
	var guest_t = -1.0
	var carry_t = -1.0
	var factory_t = -1.0
	var gem_t = -1.0
	t = 0.0
	while t < 90.0:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		sim.frozen = false
		sim._step(dt)
		t += dt
		var guests = sim.building_sim._live_guests(mine)
		if guests > 0:
			if not saw_guest:
				guest_t = t
			saw_guest = true
			# Guests must resolve as indoors/hidden diggers.
			for guest in mine.get("guests", []):
				var gid = int(guest.id)
				if gid >= 0 and sim.building_sim.indoors(gid):
					saw_hidden_guest = true
					break
		for i in sim.slot_count:
			if sim.state[i] != Catalog.ST_LIVING:
				continue
			if int(sim.carry[i]) != Catalog.CARRY_ORE:
				continue
			if not saw_carry:
				carry_t = t
			saw_carry = true
			if not sim.building_sim._is_guest(mine, i):
				saw_exit_carry = true
		if int(factory.get("buffer", 0)) > 0:
			if not saw_factory_buf:
				factory_t = t
			saw_factory_buf = true
		if int(sim.gems) > gems0 and gem_t < 0.0:
			gem_t = t

	var gems1: int = int(sim.gems)
	var stock1: int = int(mine.get("buffer", 0))
	print("  guests@%.1fs carry@%.1fs factory_buf@%.1fs gem@%.1fs" % [guest_t, carry_t, factory_t, gem_t])
	print("  stock %d->%d factory_buf=%d gems %d->%d hidden=%s exit_carry=%s" % [
		stock0, stock1, int(factory.get("buffer", 0)), gems0, gems1, saw_hidden_guest, saw_exit_carry,
	])

	if not saw_guest:
		errors.append("no digger entered mine")
	if not saw_hidden_guest:
		errors.append("digger not indoors while guest")
	if not saw_carry:
		errors.append("no thronglet carried ore")
	if not saw_exit_carry:
		errors.append("ore carry never seen outside mine")
	if not saw_factory_buf and gems1 <= gems0:
		errors.append("factory never received ore / no gems gained")
	if gems1 <= gems0 and int(factory.get("buffer", 0)) <= 0:
		errors.append("no energy produced and empty factory buffer")

	# capacity_info contract
	var info_end: Dictionary = sim.building_sim.capacity_info(mine)
	if info_end.is_empty() or not bool(info_end.get("mine", false)):
		errors.append("capacity_info broken for mine: %s" % str(info_end))
	if int(info_end.get("cap", 0)) != SimScript.MINE_STOCK_CAP:
		errors.append("cap mismatch %s vs %d" % [str(info_end.get("cap")), SimScript.MINE_STOCK_CAP])

	if errors.is_empty():
		print("PROBE PASS")
		quit(0)
		return
	print("PROBE FAIL")
	for e in errors:
		print("  - ", e)
	quit(1)
	return


## Euclidean distance between two world points.
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx = ax - bx
	var dy = ay - by
	return sqrt(dx * dx + dy * dy)
