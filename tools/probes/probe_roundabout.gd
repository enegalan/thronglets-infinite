extends SceneTree


## Headless check for roundabout ride seek, enter, and fun gain.

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
	sim.shot_mode = false
	sim.world_seed = 4242
	seed(4242)
	root.add_child(sim)
	await process_frame
	await process_frame
	if not sim.chunks.has("0,0"):
		sim._bootstrap_new()
	sim.unlocks.roundabout = true
	sim.unlocks.axe = true
	sim.unlocks.hammer = true
	var at := Vector2(256.0, 256.0)
	for feat in sim.features:
		if feat.dead:
			continue
		if _dist(float(feat.x), float(feat.y), at.x, at.y) < 100.0:
			feat.dead = true
	var round_b := {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_ROUND:
			round_b = b
			at = Vector2(float(b.x), float(b.y))
			break
	if round_b.is_empty():
		for attempt in 40:
			var px := at.x + float((attempt % 8) - 4) * 16.0
			var py := at.y + float(int(attempt / 8) - 2) * 16.0
			if sim._building_spot_free(-1, px, py, Catalog.BLD_ROUND):
				round_b = sim._add_building(Catalog.BLD_ROUND, px, py)
				if not round_b.is_empty():
					at = Vector2(float(round_b.x), float(round_b.y))
					break
	if round_b.is_empty():
		print("PROBE FAIL no roundabout")
		quit(1)
		return
	# Idle: nobody near — must stay inactive.
	sim._tick_buildings(0.2)
	if bool(round_b.get("active", false)):
		print("PROBE FAIL idle active")
		quit(1)
		return
	print("SHOT idle active=%s" % round_b.get("active", false))
	var riders: Array = []
	var mid := at + Catalog.ROUND_RIDE_OFF
	for n in 3:
		var ang := float(n) * TAU / 3.0
		var sx := mid.x + cos(ang) * 36.0
		var sy := mid.y + sin(ang) * 36.0
		var id := sim._push_slot(sx, sy, 95.0, 40.0 + float(n) * 8.0, 95.0, 0.0, n)
		if id >= 0:
			riders.append(id)
	sim._rebuild_hash()
	sim.view_rect = Rect2(at - Vector2(220, 220), Vector2(440, 440))
	sim.testing = true
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim._restore_gaze()
	sim.frozen = false
	print("PROBE round id=%s at=(%.1f,%.1f) riders=%s" % [str(round_b.get("id", -1)), at.x, at.y, str(riders)])
	var dt := 1.0 / 30.0
	var mounted := {}
	var left := {}
	var jumps := 0
	var min_pair := 9999.0
	var saw_active := false
	var sep_bad := 0
	var spin0 := -1.0
	var ang0 := {}
	for frame in 420:
		sim.modal = {}
		sim.talk_pending = {}
		sim.gaze_queue.clear()
		if sim.frozen:
			sim._restore_gaze()
			sim.frozen = false
		var before: Dictionary = {}
		for id in riders:
			before[id] = Vector2(sim.pos_x[id], sim.pos_y[id])
		sim._step(dt)
		var t := float(frame) * dt
		if bool(round_b.get("active", false)):
			saw_active = true
		var on_pad: Array = []
		for id in riders:
			var riding := not sim.ride_of(id).is_empty()
			var key := int(id)
			if riding and not mounted.has(key):
				mounted[key] = t
				print("SHOT mount id=%d t=%.2f pos=(%.1f,%.1f) slot=%s amused=%.1f" % [
					key, t, sim.pos_x[id], sim.pos_y[id], str(sim._ride_slot_of(round_b, key)), sim.amused[id]
				])
			if not riding and mounted.has(key) and not left.has(key):
				left[key] = t
				print("SHOT leave id=%d t=%.2f pos=(%.1f,%.1f) amused=%.1f rode=%.2fs" % [
					key, t, sim.pos_x[id], sim.pos_y[id], sim.amused[id], t - float(mounted[key])
				])
			var prev: Vector2 = before[id]
			var move := Vector2(sim.pos_x[id], sim.pos_y[id]) - prev
			# Gate→seat mount teleports; only flag snaps after the mount frame.
			if move.length() > 28.0 and mounted.has(key) and riding and t > float(mounted[key]) + 0.001:
				jumps += 1
				print("SHOT jump id=%d t=%.2f d=%.1f from=(%.1f,%.1f) to=(%.1f,%.1f) ride=%s" % [
					key, t, move.length(), prev.x, prev.y, sim.pos_x[id], sim.pos_y[id], str(riding)
				])
			if riding:
				on_pad.append(id)
		if on_pad.size() >= 2:
			var spin_now := float(round_b.get("spin", 0.0))
			if spin0 < 0.0:
				spin0 = spin_now
				for id in on_pad:
					ang0[int(id)] = atan2(sim.pos_y[id] - mid.y, sim.pos_x[id] - mid.x)
			else:
				# Shared spin: every rider's angle advances by the same delta.
				var dspin := spin_now - spin0
				for id in on_pad:
					var key := int(id)
					if not ang0.has(key):
						continue
					var now := atan2(sim.pos_y[key] - mid.y, sim.pos_x[key] - mid.x)
					var expect := float(ang0[key]) + dspin
					var err := absf(fposmod(now - expect + PI, TAU) - PI)
					if err > 0.15:
						sep_bad += 1
			for i in on_pad.size():
				for j in range(i + 1, on_pad.size()):
					var ia := int(on_pad[i])
					var ib := int(on_pad[j])
					var gap := _dist(sim.pos_x[ia], sim.pos_y[ia], sim.pos_x[ib], sim.pos_y[ib])
					min_pair = minf(min_pair, gap)
		if frame % 30 == 0:
			var line := "SHOT t=%.1f active=%s" % [t, round_b.get("active", false)]
			for id in riders:
				var on := "R" if not sim.ride_of(id).is_empty() else "-"
				line += " | %d%s (%.0f,%.0f) s=%s fun=%.0f" % [
					int(id), on, sim.pos_x[id], sim.pos_y[id], str(sim._ride_slot_of(round_b, int(id))), sim.amused[id]
				]
			print(line)
	# Force dismount and confirm the pad goes idle when unused.
	for id in riders:
		if not sim.ride_of(int(id)).is_empty():
			sim._leave_ride(int(id), round_b)
	sim._tick_buildings(dt)
	if bool(round_b.get("active", false)):
		print("PROBE FAIL still active after leave riders=%s" % str(round_b.get("riders", [])))
		quit(1)
		return
	print("PROBE summary mounts=%d leaves=%d jumps=%d min_pair=%.1f saw_active=%s sep_bad=%d spin=%.2f" % [
		mounted.size(), left.size(), jumps, min_pair, saw_active, sep_bad, float(round_b.get("spin", 0.0))
	])
	var ok := jumps == 0 and mounted.size() > 0 and saw_active and sep_bad == 0
	var end_t := 420.0 * dt
	var long_ride := false
	for id in riders:
		var key := int(id)
		var m := float(mounted.get(key, -1.0))
		var l := float(left.get(key, -1.0))
		var rode := l - m if m >= 0.0 and l >= 0.0 else -1.0
		var stayed := end_t - m if m >= 0.0 else -1.0
		print("PROBE id=%d mount=%.2f leave=%.2f rode=%.2f stayed=%.2f final_fun=%.1f" % [
			key, m, l, rode, stayed, sim.amused[id]
		])
		if m >= 0.0 and (rode >= SimScript.RIDE_MIN_STAY - 0.05 or stayed >= SimScript.RIDE_MIN_STAY - 0.05):
			long_ride = true
	# Adjacent 90° slots are r*√2 apart; require that floor.
	ok = ok and long_ride and min_pair >= Catalog.ROUND_RIDE_RADIUS * 1.3
	print("PROBE result=%s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## Euclidean distance between two world points.
func _dist(ax: float, ay: float, bx: float, by: float) -> float:
	var dx := ax - bx
	var dy := ay - by
	return sqrt(dx * dx + dy * dy)
