extends SceneTree

const SimScript := preload("res://ThrongletSimServer.gd")
const SAVE := "/Users/egalan/Library/Application Support/Godot/app_userdata/Thronglets- Infinite/thronglets_slot_0.save"


func _init() -> void:
	call_deferred("_run")


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
		print("PROBE FAIL no save")
		quit(1)
		return
	if not sim.load_game():
		print("PROBE FAIL load")
		quit(1)
		return
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	print("SAVE living=%d gems=%d wood=%d factory_unlock=%s market=%s" % [
		sim.living,
		sim.gems,
		sim.count_item(Catalog.ITEM_WOOD),
		str(bool(sim.unlocks.get("factory", false))),
		str(sim._has_building(Catalog.BLD_MARKET)),
	])
	var factories := 0
	for b in sim.buildings:
		if not b.dead and (int(b.kind) == Catalog.BLD_FACTORY or int(b.kind) == Catalog.BLD_FACTORY2):
			factories += 1
	print("FACTORIES already=%d" % factories)
	var build_kinds := {}
	var build_xy: Array = []
	for b in sim.buildings:
		if b.dead:
			continue
		var k := int(b.kind)
		build_kinds[k] = int(build_kinds.get(k, 0)) + 1
		if build_xy.size() < 20:
			build_xy.append("k%s@(%.0f,%.0f)" % [str(k), float(b.x), float(b.y)])
	print("BUILD kinds=%s" % str(build_kinds))
	print("BUILD sample=%s" % " ".join(build_xy))
	print("GOAL %s" % sim.goal_line())

	# Scan every revealed chunk for a free 5x5 factory pad.
	var free_n := 0
	var free_ignore_items := 0
	var first_free := Vector2.ZERO
	var first_ignore := Vector2.ZERO
	var first_home := Vector2.ZERO
	var item_blocked := 0
	var other_blocked := 0
	var home_free := 0
	var home_hard := 0
	var samples: Array = []
	var free_by_chunk := {}
	for key in sim.revealed.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			continue
		var chunk := Vector2i(int(parts[0]), int(parts[1]))
		var chunk_key := "%d,%d" % [chunk.x, chunk.y]
		for ly in range(2, Catalog.CHUNK - 2, 2):
			for lx in range(2, Catalog.CHUNK - 2, 2):
				var wx := float((chunk.x * Catalog.CHUNK + lx) * Catalog.TILE + 8)
				var wy := float((chunk.y * Catalog.CHUNK + ly) * Catalog.TILE + 8)
				var at := Catalog.snap_world(wx, wy)
				if not sim._can_drop(at.x, at.y, false):
					continue
				var cells := sim._footprint_cells(at.x, at.y, Catalog.footprint_for_building(Catalog.BLD_FACTORY))
				if not sim._footprint_holds(cells):
					continue
				var item_hit := false
				var hard_hit := false
				var feat_hit := 0
				var bld_hit := 0
				for cell in cells:
					var mid := sim._cell_world(cell)
					if not sim.revealed.has(sim._ck_of(mid.x, mid.y)) or sim._on_bridge(mid.x, mid.y):
						hard_hit = true
						break
					if int(sim.building_cell.get(cell, -1)) >= 0:
						bld_hit += 1
						hard_hit = true
						break
					if int(sim.feature_cell.get(cell, -1)) >= 0:
						feat_hit += 1
						hard_hit = true
						break
					if not sim._item_spot_free(mid.x, mid.y):
						item_hit = true
				var on_home := chunk.x == 0 and chunk.y == 0
				if hard_hit:
					other_blocked += 1
					if on_home:
						home_hard += 1
					continue
				if item_hit:
					item_blocked += 1
					if first_ignore == Vector2.ZERO:
						first_ignore = at
					free_ignore_items += 1
					continue
				free_n += 1
				free_by_chunk[chunk_key] = int(free_by_chunk.get(chunk_key, 0)) + 1
				if on_home:
					home_free += 1
					if first_home == Vector2.ZERO:
						first_home = at
				if first_free == Vector2.ZERO:
					first_free = at
				if samples.size() < 8:
					samples.append(at)
	print("SCAN free=%d home_free=%d home_hard=%d free_if_ignore_items=%d item_blocked=%d hard_blocked=%d" % [
		free_n, home_free, home_hard, free_ignore_items, item_blocked, other_blocked,
	])
	print("FREE by chunk=%s samples=%s" % [str(free_by_chunk), str(samples)])
	print("FIRST free=%s home=%s ignore_items=%s" % [str(first_free), str(first_home), str(first_ignore)])
	# Why home island rejects 5x5: classify blockers near existing buildings.
	var why_feat := 0
	var why_bld := 0
	var why_tile := 0
	var why_bridge := 0
	var why_reveal := 0
	var feat_kinds := {}
	for ly in range(2, Catalog.CHUNK - 2):
		for lx in range(2, Catalog.CHUNK - 2):
			var wx2 := float(lx * Catalog.TILE + 8)
			var wy2 := float(ly * Catalog.TILE + 8)
			var at2 := Catalog.snap_world(wx2, wy2)
			if not sim.revealed.has(sim._ck_of(at2.x, at2.y)):
				continue
			if not sim._tile_holds(at2.x, at2.y):
				continue
			var cells2 := sim._footprint_cells(at2.x, at2.y, Catalog.footprint_for_building(Catalog.BLD_FACTORY))
			var blocked_by := ""
			for cell2 in cells2:
				var mid2 := sim._cell_world(cell2)
				if not sim.revealed.has(sim._ck_of(mid2.x, mid2.y)):
					blocked_by = "reveal"
					why_reveal += 1
					break
				if sim._on_bridge(mid2.x, mid2.y):
					blocked_by = "bridge"
					why_bridge += 1
					break
				if not sim._tile_holds(mid2.x, mid2.y):
					blocked_by = "tile"
					why_tile += 1
					break
				var bid := int(sim.building_cell.get(cell2, -1))
				if bid >= 0:
					blocked_by = "bld"
					why_bld += 1
					break
				var fid := int(sim.feature_cell.get(cell2, -1))
				if fid >= 0:
					var feat = sim.feature_by_id.get(fid, {})
					var fk := int(feat.get("kind", -1))
					feat_kinds[fk] = int(feat_kinds.get(fk, 0)) + 1
					blocked_by = "feat"
					why_feat += 1
					break
			if blocked_by == "":
				pass
	print("HOME why feat=%d bld=%d tile=%d bridge=%d reveal=%d feat_kinds=%s" % [
		why_feat, why_bld, why_tile, why_bridge, why_reveal, str(feat_kinds),
	])
	# Would a smaller pad fit on home?
	for size in [Vector2i(5, 5), Vector2i(4, 4), Vector2i(3, 3), Vector2i(2, 2)]:
		var nfit := 0
		for ly3 in range(2, Catalog.CHUNK - 2, 2):
			for lx3 in range(2, Catalog.CHUNK - 2, 2):
				var at3 := Catalog.snap_world(float(lx3 * Catalog.TILE + 8), float(ly3 * Catalog.TILE + 8))
				if not sim._can_drop(at3.x, at3.y, false):
					continue
				var ok := true
				for cell3 in sim._footprint_cells(at3.x, at3.y, size):
					var mid3 := sim._cell_world(cell3)
					if not sim.revealed.has(sim._ck_of(mid3.x, mid3.y)) or sim._on_bridge(mid3.x, mid3.y):
						ok = false
						break
					if not sim._tile_holds(mid3.x, mid3.y):
						ok = false
						break
					if int(sim.building_cell.get(cell3, -1)) >= 0 or int(sim.feature_cell.get(cell3, -1)) >= 0:
						ok = false
						break
					if not sim._item_spot_free(mid3.x, mid3.y):
						ok = false
						break
				if ok:
					nfit += 1
		print("HOME fit size=%dx%d count=%d" % [size.x, size.y, nfit])

	if not bool(sim.unlocks.get("factory", false)):
		print("BUY attempt gems=%d cost=%d" % [sim.gems, int(Catalog.MARKET.factory.cost)])
		var bought := sim.buy("factory")
		print("BUY factory=%s unlock=%s notes=%s" % [
			str(bought), str(bool(sim.unlocks.get("factory", false))), str(sim.notes),
		])
		sim.notes.clear()

	var target := first_home if first_home != Vector2.ZERO else first_free
	if target == Vector2.ZERO:
		target = sim._smoke_find_spot(Catalog.BLD_FACTORY, [
			Vector2(256, 256), Vector2(200, 280), Vector2(320, 200), Vector2(180, 180),
		])
		print("SMOKE spot=%s" % str(target))

	if target == Vector2.ZERO:
		print("PROBE FAIL no free pad anywhere")
		quit(1)
		return

	var can := sim.can_place_building(Catalog.BLD_FACTORY, target.x, target.y)
	print("CAN place at %s = %s wood=%d home=%s" % [
		str(target), str(can), sim.count_item(Catalog.ITEM_WOOD), str(first_home != Vector2.ZERO),
	])
	while sim.count_item(Catalog.ITEM_WOOD) < 3:
		sim._add_item(Catalog.ITEM_WOOD, target.x + 96.0, target.y + 96.0, 1)
	sim.notes.clear()
	var placed := sim.place_building(Catalog.BLD_FACTORY, target.x, target.y)
	print("PLACE=%s notes=%s" % [str(placed), str(sim.notes)])
	var after := 0
	for b in sim.buildings:
		if not b.dead and (int(b.kind) == Catalog.BLD_FACTORY or int(b.kind) == Catalog.BLD_FACTORY2):
			after += 1
	print("FACTORIES after=%d" % after)
	var home_ok := first_home != Vector2.ZERO and placed
	print("PROBE result=%s home_place=%s" % [("PASS" if home_ok else "FAIL"), str(home_ok)])
	quit(0 if home_ok else 1)
