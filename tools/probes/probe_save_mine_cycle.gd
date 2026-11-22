extends SceneTree

## Load the player's real slot_0 save and verify mine/factory cycle on live state.

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
	sim.testing = true
	sim.smoke_hold = true
	if not FileAccess.file_exists(SAVE):
		print("PROBE FAIL no save ", SAVE)
		quit(1)
		return
	if not sim.save_system.load_game():
		print("PROBE FAIL load")
		quit(1)
		return
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim._invalidate_factory_cache()

	var mines: Array = []
	var factories: Array = []
	for b in sim.buildings:
		if b.dead:
			continue
		var k := int(b.kind)
		if k == Catalog.BLD_MINE or k == Catalog.BLD_MINE2:
			mines.append(b)
		elif k == Catalog.BLD_FACTORY or k == Catalog.BLD_FACTORY2:
			factories.append(b)

	print("SAVE living=%d gems=%d mines=%d factories=%d has_factory=%s" % [
		sim.living, sim.gems, mines.size(), factories.size(), str(sim._has_factory()),
	])
	for b in mines:
		var info: Dictionary = sim.capacity_info(b)
		print("  MINE id=%s stock=%s/%s full=%s guests=%d active=%s" % [
			str(b.id), str(info.get("n")), str(info.get("cap")), str(info.get("full")),
			sim._live_guests(b), str(b.get("active", false)),
		])
	for b in factories:
		print("  FACTORY id=%s buffer=%s" % [str(b.id), str(b.get("buffer", 0))])

	if mines.is_empty():
		print("PROBE FAIL no mines in save")
		quit(1)
		return
	if factories.is_empty():
		print("PROBE FAIL no factories in save")
		quit(1)
		return

	# Top up needs near the first mine so work can start.
	var mine: Dictionary = mines[0]
	var factory: Dictionary = factories[0]
	# Camera over the mine↔factory corridor so AGENT_NEAR seek budget hits workers.
	var mid := Vector2(
		(float(mine.x) + float(factory.x)) * 0.5,
		(float(mine.y) + float(factory.y)) * 0.5
	)
	sim.view_rect = Rect2(mid.x - 220.0, mid.y - 260.0, 440.0, 520.0)
	var ready := 0
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		if _dist(sim.pos_x[i], sim.pos_y[i], float(mine.x), float(mine.y)) > 220.0:
			continue
		sim.fed[i] = maxf(sim.fed[i], 100.0)
		sim.clean[i] = maxf(sim.clean[i], 100.0)
		sim.amused[i] = maxf(sim.amused[i], 100.0)
		ready += 1
	print("NEAR_READY=%d view=%s" % [ready, str(sim.view_rect)])

	var gems0: int = int(sim.gems)
	var stock0: int = int(mine.get("buffer", 0))
	var factory0: int = int(factory.get("buffer", 0))
	var saw_guest := false
	var saw_carry := false
	var saw_stock_up := false
	var max_stock := stock0
	var max_factory := factory0
	var dt := 1.0 / 30.0
	for _frame in 1500:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		sim.frozen = false
		# Keep a handful near the mine work-ready (camera colony).
		if (_frame % 15) == 0:
			var topped := 0
			for i in sim.slot_count:
				if sim.state[i] != Catalog.ST_LIVING:
					continue
				if _dist(sim.pos_x[i], sim.pos_y[i], float(mine.x), float(mine.y)) > 180.0:
					continue
				sim.fed[i] = 100.0
				sim.clean[i] = 100.0
				sim.amused[i] = 100.0
				topped += 1
				if topped >= 8:
					break
		sim._step(dt)
		var stock := int(mine.get("buffer", 0))
		if stock > stock0:
			saw_stock_up = true
		max_stock = maxi(max_stock, stock)
		if sim._live_guests(mine) > 0:
			saw_guest = true
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING and int(sim.carry[i]) == Catalog.CARRY_ORE:
				saw_carry = true
				break
		max_factory = maxi(max_factory, int(factory.get("buffer", 0)))
		if max_factory > factory0 and int(sim.gems) > gems0:
			break

	var gems1: int = int(sim.gems)
	print("AFTER stock %d->max%d factory %d->max%d gems %d->%d guest=%s carry=%s stock_up=%s" % [
		stock0, max_stock, factory0, max_factory, gems0, gems1, saw_guest, saw_carry, saw_stock_up,
	])
	var info: Dictionary = sim.capacity_info(mine)
	print("capacity_info=%s occupancy='%s'" % [str(info), sim.occupancy_text(mine)])

	var errors: Array[String] = []
	if not saw_stock_up and not saw_guest and not saw_carry:
		errors.append("stock never rose and nobody mined")
	if not saw_guest and not saw_carry:
		errors.append("no dig guest and no ore carry")
	if max_factory <= factory0 and gems1 <= gems0:
		errors.append("factory never gained ore/energy under camera view")

	if errors.is_empty():
		print("PROBE PASS")
		quit(0)
		return
	print("PROBE FAIL")
	for e in errors:
		print("  - ", e)
	quit(1)
	return


func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
