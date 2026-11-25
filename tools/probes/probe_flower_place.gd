extends SceneTree


## Scene-tree probe that validates flower building placement in the live Main scene.


func _init() -> void:
	call_deferred("_go")


## Boots the scene harness, runs checks, and quits with pass/fail status.
func _go() -> void:
	await process_frame
	await process_frame
	var sim: Node = root.get_node("ThrongletSimServer")
	sim.call("new_game") if sim.has_method("new_game") else null
	await process_frame
	sim.set("sandbox_mode", true)
	var unlocks: Dictionary = sim.get("unlocks")
	unlocks["flower"] = true
	sim.set("gems", 999)
	print(
		"sandbox=",
		sim.get("sandbox_mode"),
		" gems=",
		sim.get("gems"),
		" unlock=",
		unlocks.get("flower", false)
	)
	var first := Vector2(-9999, -9999)
	var ok_n := 0
	for y in range(-20, 21):
		for x in range(-20, 21):
			var wx := float(x * Catalog.TILE)
			var wy := float(y * Catalog.TILE)
			if bool(sim.call("can_place_building", Catalog.BLD_FLOWER, wx, wy)):
				ok_n += 1
				if first.x < -9000.0:
					first = Vector2(wx, wy)
	print("can_place spots=", ok_n, " first=", first)
	if ok_n > 0:
		var placed: bool = bool(sim.call("place_building", Catalog.BLD_FLOWER, first.x, first.y))
		print("place -> ", placed)
	var n := 0
	for b in sim.get("buildings"):
		if not bool(b.get("dead", false)) and int(b.get("kind", -1)) == Catalog.BLD_FLOWER:
			n += 1
			print("flower=", b)
	print("flower count=", n)
	quit()
