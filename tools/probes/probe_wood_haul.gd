extends SceneTree

const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var sim = SimScript.new()
	sim.testing = true
	sim.smoke_hold = true
	sim.world_seed = 4242
	seed(4242)
	root.add_child(sim)
	await process_frame
	await process_frame
	sim.testing = true
	sim.smoke_hold = true
	sim.frozen = false
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim._ensure_bridge_site()
	var bridge: Dictionary = sim._primary_open_bridge()
	if bridge.is_empty():
		sim.bridges.append({
			"ck": "0,0",
			"x": 256.0,
			"y": 256.0,
			"drop_x": 256.0,
			"drop_y": 256.0,
			"progress": 0,
			"need": 12,
			"bones": 0,
			"done": false,
		})
		bridge = sim.bridges[0]
	for it in sim.items:
		if int(it.kind) == Catalog.ITEM_WOOD:
			it.dead = true
	var home := Vector2(256.0, 256.0)
	if bridge.has("drop_x"):
		home = Vector2(float(bridge.drop_x), float(bridge.drop_y))
	# Find a walkable plank spot near home.
	var plank_at := Vector2.ZERO
	for n in 48:
		var ang := float(n) * (TAU / 48.0)
		var px := home.x + cos(ang) * 36.0
		var py := home.y + sin(ang) * 36.0
		if not sim._move_blocked(px, py) and sim._land_inland(px, py):
			plank_at = Vector2(px, py)
			break
	if plank_at == Vector2.ZERO:
		print("PROBE FAIL no walkable plank spot near ", home)
		quit(1)
		return
	sim._add_item(Catalog.ITEM_WOOD, plank_at.x, plank_at.y, 1)
	var wood := {}
	for it in sim.items:
		if not it.dead and int(it.kind) == Catalog.ITEM_WOOD:
			wood = it
			break
	var ids: Array = []
	for n in 3:
		var ang := float(n) * 2.1
		var sx := plank_at.x + cos(ang) * 48.0
		var sy := plank_at.y + sin(ang) * 48.0
		if sim._move_blocked(sx, sy):
			sx = plank_at.x + 48.0
			sy = plank_at.y
			if sim._move_blocked(sx, sy):
				sx = plank_at.x
				sy = plank_at.y + 48.0
		var id := sim._push_slot(sx, sy, 95.0, 95.0, 95.0, 0.0, 0)
		if id < 0:
			continue
		sim.cool[id] = 999.0
		sim.mito_charge[id] = 0.0
		ids.append(id)
	if wood.is_empty() or ids.is_empty():
		print("PROBE FAIL setup wood=%s ids=%s" % [str(not wood.is_empty()), str(ids)])
		quit(1)
		return
	sim._rebuild_hash()
	var lead := int(ids[0])
	print("PROBE setup plank=%s throng=%s bridge=%s ids=%d" % [
		str(plank_at), str(Vector2(sim.pos_x[lead], sim.pos_y[lead])),
		str(not bridge.is_empty()), ids.size(),
	])
	var picked := 0
	var carried := 0
	var min_d := 99999.0
	for step in 240:
		sim.frame_i += 1
		for id in ids:
			sim._tick_one(int(id), 0.2)
		var d := sim._dist_i(lead, float(wood.x), float(wood.y))
		if d < min_d:
			min_d = d
		if bool(wood.dead):
			picked = step + 1
			break
	for id in ids:
		if int(sim.carry[int(id)]) == Catalog.CARRY_WOOD:
			carried += 1
	print("PROBE wood_dead=%s picked_step=%d carriers=%d claim=%s min_d=%.1f" % [
		str(wood.dead), picked, carried, str(wood.get("claimer", -1)), min_d,
	])
	if not bool(wood.dead) and carried < 1:
		print("PROBE FAIL nobody picked wood")
		quit(1)
		return
	print("PROBE OK")
	quit(0)
