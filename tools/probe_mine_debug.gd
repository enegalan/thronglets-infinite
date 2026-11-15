extends SceneTree

const SimScript := preload("res://ThrongletSimServer.gd")


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
	for bridge in sim.bridges:
		bridge.done = true
		bridge.progress = int(bridge.need)
	sim.part_two = true
	var ore := {}
	for feat in sim.features:
		if not feat.dead and int(feat.cx) == 0 and sim._ore_tier(int(feat.kind)) > 0:
			ore = feat
			break
	var ore_at := Catalog.snap_world(float(ore.x), float(ore.y))
	for feat in sim.features:
		if feat.dead or int(feat.id) == int(ore.id):
			continue
		if Vector2(float(feat.x), float(feat.y)).distance_to(ore_at) < 120.0:
			feat.dead = true
	sim._rebuild_hash()
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 112.0, ore_at.y + 96.0, 1)
	sim._add_item(Catalog.ITEM_WOOD, ore_at.x + 128.0, ore_at.y + 96.0, 1)
	sim.place_building(Catalog.BLD_MINE, ore_at.x, ore_at.y)
	var mine := {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_MINE:
			mine = b
			break
	for it in sim.items:
		if int(it.kind) == Catalog.ITEM_WOOD or int(it.kind) == Catalog.ITEM_ORE or int(it.kind) == Catalog.ITEM_BONE:
			it.dead = true
	var gate := sim._approach_building(mine, -1)
	var id := sim._push_slot(gate.x + 140.0, gate.y + 140.0, 95.0, 95.0, 95.0, 0.0, 0)
	sim.cool[id] = 999.0
	sim.mito_charge[id] = 0.0
	sim._rebuild_hash()
	var spot := sim._approach_building(mine, id)
	var center := sim._footprint_center_of(mine)
	var reach := Catalog.building_reach(Catalog.BLD_MINE)
	print("pos=", sim.pos_x[id], ",", sim.pos_y[id])
	print("mine=", mine.x, ",", mine.y, " center=", center, " reach=", reach)
	print("spot=", spot, " dist_spot=", Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(spot))
	print("inside=", sim._inside_building_reach(sim.pos_x[id], sim.pos_y[id], mine))
	print("blocked_here=", sim._move_blocked(sim.pos_x[id], sim.pos_y[id]))
	print("blocked_spot=", sim._move_blocked(spot.x, spot.y))
	print("land_here=", sim._land_inland(sim.pos_x[id], sim.pos_y[id]))
	print("tile=", sim._tile_at(sim.pos_x[id], sim.pos_y[id]))
	var sought := sim._seek_mine(id, 26.0, 0.2)
	print("seek=", sought, " after=", sim.pos_x[id], ",", sim.pos_y[id], " dir=", sim.dir_x[id], ",", sim.dir_y[id], " act=", sim.act[id])
	for n in 30:
		sim._seek_mine(id, 26.0, 0.2)
	print("after30=", sim.pos_x[id], ",", sim.pos_y[id], " d=", Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(Vector2(float(mine.x), float(mine.y))))
	# Direct walk test
	sim.pos_x[id] = gate.x + 140.0
	sim.pos_y[id] = gate.y + 140.0
	for n in 30:
		sim._walk(id, spot.x, spot.y, 26.0, 0.2)
	print("walk30=", sim.pos_x[id], ",", sim.pos_y[id], " dspot=", Vector2(sim.pos_x[id], sim.pos_y[id]).distance_to(spot))
	quit()
