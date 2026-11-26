extends SceneTree


## Headless check that revealed land grows without hard island bounds.

## Preloaded ThrongletSimServer script used for headless simulation steps.
const SimScript = preload("res://scripts/core/ThrongletSimServer.gd")


## Defers probe execution until the SceneTree root is ready.
func _init() -> void:
	call_deferred("_run")


## Boots the sim, runs assertions, and quits with pass/fail status.
func _run() -> void:
	var sim = SimScript.new()
	# Do not set testing before add_child — _ready() would start the smoke suite.
	sim.smoke_hold = true
	sim.world_seed = 7777
	seed(7777)
	root.add_child(sim)
	await process_frame
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	sim.world_seed = 7777
	seed(7777)
	if not sim.chunks.has("0,0"):
		sim.world_entities._bootstrap_new()
	elif sim.land_tier != 0:
		sim.land_tier = 0
		sim.island_gen.shape_island()
	var r0: float = sim.island_gen.island_reach()
	var land0 = _count_land(sim)
	print("tier0 reach=", r0, " land=", land0, " chunks=", sim.chunks.size())
	sim.land_tier = 3
	var added3: int = sim.island_gen.shape_island()
	var r3: float = sim.island_gen.island_reach()
	var land3 = _count_land(sim)
	print("tier3 reach=", r3, " land=", land3, " added=", added3, " chunks=", sim.chunks.keys())
	sim.land_tier = 8
	var added8: int = sim.island_gen.shape_island()
	var r8: float = sim.island_gen.island_reach()
	var land8 = _count_land(sim)
	print("tier8 reach=", r8, " land=", land8, " added=", added8, " chunks=", sim.chunks.size(), " keys=", sim.chunks.keys())
	print("milestone8=", sim.dialogue._milestone_at(8), " milestone9=", sim.dialogue._milestone_at(9))
	var ok: bool = r0 == 170.0 and r3 > 252.0 and r8 > r3 and land8 > land3 and sim.chunks.size() > 1
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Counts land tiles in revealed chunks for infinite island asserts.
func _count_land(sim) -> int:
	var n = 0
	for ck in sim.chunks.keys():
		var tiles = sim.chunks[ck].tiles
		for i in tiles.size():
			var t = int(tiles[i])
			if t != Catalog.TILE_VOID and t != Catalog.TILE_FOG:
				n += 1
	return n
