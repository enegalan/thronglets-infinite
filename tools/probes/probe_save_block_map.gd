extends SceneTree

const SimScript := preload("res://scripts/core/ThrongletSimServer.gd")
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
	sim.save_system.load_game()
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
	print("Scanning corridor mine->factory")
	var x0: float = float(mine.x)
	var y0: float = float(mine.y)
	var x1: float = float(factory.x)
	var y1: float = float(factory.y)
	for row in 20:
		var t: float = float(row) / 19.0
		var px: float = lerpf(x0, x1, t)
		var py: float = lerpf(y0, y1, t)
		var cell := sim._cell_vec(px, py)
		var why := "open"
		if sim._move_blocked(px, py):
			why = "tile"
			var tile := sim._tile_at(px, py)
			if Catalog.tile_blocks(tile):
				why = "tile_%d" % tile
			elif sim.building_cell.has(cell):
				var b = sim.building_by_id.get(int(sim.building_cell[cell]), {})
				why = "bld_%s" % str(b.get("kind", "?"))
			elif sim.feature_cell.has(cell):
				var f = sim.feature_by_id.get(int(sim.feature_cell[cell]), {})
				why = "feat_%s" % str(f.get("kind", "?"))
			else:
				why = "other"
		print("  %.0f%% (%.0f,%.0f) %s" % [t * 100.0, px, py, why])
	# Side corridors at the stuck band y~160
	print("Side scan at y=160")
	var row := ""
	for sx in range(200, 400, 16):
		var px2: float = float(sx)
		var py2: float = 160.0
		row += "X" if sim._move_blocked(px2, py2) else "."
	print(row)
	print("approach factory=", sim._approach_building(factory, -1))
	print("factory reach=", Catalog.building_reach(int(factory.kind)))
	print("PROBE DONE")
	quit(0)
