extends SceneTree


## Headless check that goo pollution shuts dwell guests and nearest queries.

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript = preload("res://scripts/core/ThrongletSimServer.gd")


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	root.add_child(sim)
	await process_frame
	sim.testing = true
	sim.sandbox_mode = true
	sim.world_entities._bootstrap_sandbox(0)
	await process_frame

	var placed = false
	var at = Vector2.ZERO
	for dx in range(-12, 13):
		for dy in range(-12, 13):
			var x = float(dx) * float(Catalog.TILE)
			var y = float(dy) * float(Catalog.TILE)
			if sim.player_tools.can_place_building(Catalog.BLD_DWELL, x, y):
				placed = sim.player_tools.place_building(Catalog.BLD_DWELL, x, y)
				at = Vector2(x, y)
				break
		if placed:
			break
	if not placed:
		print("PROBE FAIL place dwell")
		quit(1)
		return

	var b = {}
	for row in sim.buildings:
		if not bool(row.dead) and int(row.kind) == Catalog.BLD_DWELL:
			b = row
			break
	if b.is_empty():
		print("PROBE FAIL no dwell at %s" % str(at))
		quit(1)
		return

	if sim.building_sim.building_is_polluted(b):
		print("PROBE FAIL clean dwell already polluted")
		quit(1)
		return

	for cell in sim.building_sim._footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(Catalog.BLD_DWELL)):
		sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_GOO, false)

	if not sim.building_sim.building_is_polluted(b):
		print("PROBE FAIL goo footprint not detected")
		quit(1)
		return

	b.guests = [{"id": 0, "left": 10.0}]
	b.active = true
	sim.building_sim._tick_buildings(0.016)
	if bool(b.get("active", true)):
		print("PROBE FAIL polluted dwell still active")
		quit(1)
		return
	if not b.get("guests", []).is_empty():
		print("PROBE FAIL polluted dwell kept guests")
		quit(1)
		return

	var nearest = sim.building_sim._nearest_building_kinds(float(b.x), float(b.y), [Catalog.BLD_DWELL], 400.0)
	if not nearest.is_empty():
		print("PROBE FAIL nearest still returns polluted dwell")
		quit(1)
		return

	print("PROBE OK polluted dwell shuts and is skipped")
	quit(0)
