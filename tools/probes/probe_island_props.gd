extends SceneTree


## Headless tally of island props after bootstrap for generation smoke.

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
	sim.world_seed = 7777
	seed(7777)
	root.add_child(sim)
	await process_frame
	await process_frame
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	var f0 := _count_props(sim)
	print("tier0 props=", f0, " features=", sim.features.size())
	sim.land_tier = 2
	var added: int = sim._shape_island()
	var f2 := _count_props(sim)
	print("tier2 added_tiles=", added, " props=", f2, " delta=", f2.total - f0.total)
	sim.land_tier = 4
	var added4: int = sim._shape_island()
	var f4 := _count_props(sim)
	print("tier4 added_tiles=", added4, " props=", f4, " delta=", f4.total - f2.total, " chunks=", sim.chunks.size())
	var ok: bool = (f2.total > f0.total) and (f4.total > f2.total)
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Tallies prop kinds on the island for generation smoke checks.
func _count_props(sim) -> Dictionary:
	var trees := 0
	var rocks := 0
	var ore := 0
	for feat in sim.features:
		if feat.dead:
			continue
		var kind := int(feat.kind)
		if kind == Catalog.FEAT_TREE:
			trees += 1
		elif kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK:
			rocks += 1
			if int(feat.ore) > 0:
				ore += 1
		elif sim._ore_tier(kind) > 0:
			ore += 1
	return {"trees": trees, "rocks": rocks, "ore": ore, "total": trees + rocks + ore}
