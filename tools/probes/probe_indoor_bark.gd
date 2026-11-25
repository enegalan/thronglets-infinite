extends SceneTree


## Headless check for indoor bark building placement and guest behavior.

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
	for key in ["dwelling", "bathtub", "theatre", "mine", "roundabout", "ball", "apple", "flower", "pickaxe"]:
		sim.unlocks[key] = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	var mid := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if Vector2(float(feat.x), float(feat.y)).distance_to(mid) < 160.0:
			feat.dead = true
	var home := _place(sim, Catalog.BLD_DWELL, mid)
	var show_b := _place(sim, Catalog.BLD_THEATRE, mid + Vector2(64, 0))
	var mine := _place(sim, Catalog.BLD_MINE, mid + Vector2(-64, 0))
	print("placed home=%s theatre=%s mine=%s" % [not home.is_empty(), not show_b.is_empty(), not mine.is_empty()])
	var cases := [
		{"name": "home", "b": home, "fed": 90.0, "fun": 90.0, "clean": 90.0},
		{"name": "theatre", "b": show_b, "fed": 90.0, "fun": 40.0, "clean": 90.0},
		{"name": "mine", "b": mine, "fed": 90.0, "fun": 90.0, "clean": 90.0},
		{"name": "home_hungry", "b": home, "fed": 50.0, "fun": 90.0, "clean": 90.0},
		{"name": "theatre_hungry", "b": show_b, "fed": 50.0, "fun": 90.0, "clean": 90.0},
	]
	var failed := 0
	for c in cases:
		var b: Dictionary = c.b
		if b.is_empty():
			print(c.name, " SKIP no building")
			continue
		var rim := sim._approach_building(b, -1)
		var id := sim._push_slot(rim.x, rim.y, float(c.fed), float(c.fun), float(c.clean), 0.0, 0)
		sim._rebuild_hash()
		sim.view_rect = Rect2(mid - Vector2(300, 300), Vector2(600, 600))
		if sim._is_guest(b, id):
			sim._drop_guest(b, id)
		var entered := sim._enter_visit(id, b)
		var kind := int(b.kind)
		if sim._is_show(kind):
			sim.act[id] = sim.ACT_PLAY
		elif sim._is_mine_kind(kind):
			sim.act[id] = sim.ACT_WORK
		else:
			sim.act[id] = sim.ACT_BATH
		sim.act_t[id] = 1.0
		var icon := sim._thought_icon(id)
		var can_sing := sim.bark_can_sing(id)
		var indoors := sim.indoors(id)
		print("%s entered=%s indoors=%s act=%d icon=%d can_sing=%s" % [
			c.name, entered, indoors, int(sim.act[id]), icon, can_sing
		])
		sim.barks.clear()
		sim.bark_cool[id] = 0.0
		var got := false
		for _n in 50000:
			sim._maybe_bark(id)
			if not sim.barks.is_empty():
				got = true
				break
		print("  force_bark got=%s bark=%s" % [got, sim.barks])
		if not indoors or icon >= 0 or can_sing or got:
			failed += 1
			print("  FAIL expected indoors with no thought/bark")
		if sim._is_guest(b, id):
			sim._drop_guest(b, id)
	quit(1 if failed > 0 else 0)

## Places a building kind near a world point and returns the slot dict.
func _place(sim, kind: int, around: Vector2) -> Dictionary:
	for attempt in 64:
		var px := around.x + float((attempt % 8) - 4) * 16.0
		var py := around.y + float(int(attempt / 8) - 3) * 16.0
		var at := Catalog.snap_world(px, py)
		if sim._building_spot_free(-1, at.x, at.y, kind):
			var b: Dictionary = sim._add_building(kind, at.x, at.y)
			if not b.is_empty():
				return b
	return {}
