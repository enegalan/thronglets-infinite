extends SceneTree


## Loads slot_0 and traces factory haul stuck states.

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
	if not sim.save_system.load_game():
		print("FAIL load")
		quit(1)
		return
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim._invalidate_factory_cache()

	var mine := {}
	var factory := {}
	for b in sim.buildings:
		if b.dead:
			continue
		var k := int(b.kind)
		if (k == Catalog.BLD_MINE or k == Catalog.BLD_MINE2) and mine.is_empty():
			mine = b
		elif (k == Catalog.BLD_FACTORY or k == Catalog.BLD_FACTORY2) and factory.is_empty():
			factory = b
	print("mine=(%.1f,%.1f) factory=(%.1f,%.1f) dist=%.1f" % [
		float(mine.x), float(mine.y), float(factory.x), float(factory.y),
		Vector2(float(mine.x), float(mine.y)).distance_to(Vector2(float(factory.x), float(factory.y))),
	])
	print("factory blocked=%s land=%s tile=%s" % [
		str(sim._move_blocked(float(factory.x), float(factory.y))),
		str(sim._land_inland(float(factory.x), float(factory.y))),
		str(sim._tile_at(float(factory.x), float(factory.y))),
	])

	# Pick one living thronglet and force ore haul with per-frame decide (bypass AI budget).
	var id := -1
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_LIVING:
			id = i
			break
	var gate := sim._approach_building(mine, id)
	sim.pos_x[id] = gate.x
	sim.pos_y[id] = gate.y
	sim._hash_relocate(id)
	sim.fed[id] = 100.0
	sim.clean[id] = 100.0
	sim.amused[id] = 100.0
	sim.cool[id] = 999.0
	sim.mito_charge[id] = 0.0
	sim._set_carry(id, Catalog.CARRY_ORE, 1)
	print("haul start carry=%d d_fact=%.1f" % [
		int(sim.carry[id]),
		Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(Vector2(float(factory.x), float(factory.y))),
	])

	var dt := 1.0 / 30.0
	var gems0 := int(sim.gems)
	for frame in 900:
		sim.fed[id] = 100.0
		sim.clean[id] = 100.0
		sim.amused[id] = 100.0
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		# Buildings tick (factory spend) + forced decide for this carrier.
		sim._tick_buildings(dt)
		if sim._tick_busy(id, dt, true):
			sim._tick_decide(id, dt)
		if frame % 30 == 0 or int(sim.carry[id]) == Catalog.CARRY_NONE:
			print("t=%.1f carry=%d act=%d pos=(%.1f,%.1f) d_fact=%.1f fbuf=%d gems=%d" % [
				float(frame) * dt, int(sim.carry[id]), int(sim.act[id]),
				sim.pos_x[id], sim.pos_y[id],
				Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(Vector2(float(factory.x), float(factory.y))),
				int(factory.get("buffer", 0)), sim.gems,
			])
		if int(factory.get("buffer", 0)) > 0 or (int(sim.gems) > gems0 and int(sim.carry[id]) == Catalog.CARRY_NONE):
			print("HAUL OK t=%.1f fbuf=%d gems=%d->%d" % [float(frame) * dt, int(factory.get("buffer", 0)), gems0, sim.gems])
			print("PROBE PASS")
			quit(0)
			return

	print("PROBE FAIL haul stuck carry=%d d_fact=%.1f fbuf=%d" % [
		int(sim.carry[id]),
		Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(Vector2(float(factory.x), float(factory.y))),
		int(factory.get("buffer", 0)),
	])
	# Sample blocked steps toward factory.
	var dx: float = float(factory.x) - sim.pos_x[id]
	var dy: float = float(factory.y) - sim.pos_y[id]
	var len: float = sqrt(dx * dx + dy * dy)
	if len > 1.0:
		dx /= len
		dy /= len
	for step in 10:
		var px: float = sim.pos_x[id] + dx * float(step) * 24.0
		var py: float = sim.pos_y[id] + dy * float(step) * 24.0
		print("  step%d (%.1f,%.1f) blocked=%s tile=%s" % [
			step, px, py, str(sim._move_blocked(px, py)), str(sim._tile_at(px, py)),
		])
	quit(1)
