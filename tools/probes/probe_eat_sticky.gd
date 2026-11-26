extends SceneTree


## Headless check that orphan ACT_EAT sticky claims clear on full eat paths.

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
	sim.world_seed = 4242
	seed(4242)
	root.add_child(sim)
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim.world_entities._bootstrap_new()
	await process_frame

	var id = sim.world_entities._push_slot(256.0, 256.0, 40.0, 90.0, 90.0, 0.0, 0)
	sim.spatial._rebuild_hash()
	sim.world_entities._ensure_agent_timers(id)
	if id < sim.link_claim.size():
		sim.link_claim[id] = -1

	sim.act[id] = sim.ACT_EAT
	sim.act_t[id] = 0.0
	if sim.agent_tick._act_is_sticky(id):
		print("PROBE FAIL ACT_EAT sticky without apple claim")
		quit(1)
		return

	sim.act[id] = sim.ACT_EAT
	sim.act_t[id] = 0.0
	sim.agent_tick._continue_eat(id, 0.016)
	if int(sim.act[id]) != 0:
		print("PROBE FAIL _continue_eat left ACT_EAT with empty claim")
		quit(1)
		return

	sim.act[id] = sim.ACT_EAT
	sim.act_t[id] = 0.0
	sim.agent_tick._tick_decide(id, 0.016)
	# Decide clears via _continue_eat when claim empty.
	if int(sim.act[id]) == sim.ACT_EAT:
		print("PROBE FAIL full decide left orphan ACT_EAT act=%d" % int(sim.act[id]))
		quit(1)
		return

	# Non-sticky expired act must clear on life tick.
	sim.act[id] = sim.ACT_EAT
	sim.act_t[id] = 0.0
	if sim.agent_tick._act_is_sticky(id):
		print("PROBE FAIL unexpected sticky before life clear")
		quit(1)
		return
	sim._tick_life(id, 0.016, 1.0)
	if int(sim.act[id]) == sim.ACT_EAT:
		print("PROBE FAIL life tick did not clear non-sticky ACT_EAT")
		quit(1)
		return

	print("PROBE OK orphan ACT_EAT clears on full path")
	quit(0)
