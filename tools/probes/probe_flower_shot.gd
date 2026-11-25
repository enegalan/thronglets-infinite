extends SceneTree

func _init() -> void:
	call_deferred("_go")

func _go() -> void:
	# Load main scene
	var packed = load("res://main/Main.tscn")
	if packed == null:
		for p in ["res://Main.tscn", "res://scenes/Main.tscn", "res://main.tscn"]:
			packed = load(p)
			if packed: break
	print("packed=", packed)
	if packed == null:
		# resolve uid
		var ps = ProjectSettings.get_setting("application/run/main_scene")
		print("main_scene setting=", ps)
		packed = load(ps)
		print("packed2=", packed)
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	var sim = root.get_node("ThrongletSimServer")
	sim.new_sandbox_game()
	main.in_title = false
	if main.has_method("_leave_title"):
		main._leave_title()
	elif main.has_method("_start_sandbox_game"):
		pass
	main.in_title = false
	if main.title_root: main.title_root.visible = false
	sim.sandbox_mode = true
	sim.unlocks["flower"] = true
	await process_frame
	# place flower near camera
	var cam = main.camera
	var at = main.cam_rig.from_iso(cam.position)
	at = Catalog.snap_world(at.x, at.y)
	print("try place at ", at, " can=", sim.can_place_building(Catalog.BLD_FLOWER, at.x, at.y))
	# search nearby
	var placed_at = Vector2.ZERO
	for r in range(0, 30):
		for dx in range(-r, r+1):
			for dy in range(-r, r+1):
				var wx = at.x + float(dx * Catalog.TILE)
				var wy = at.y + float(dy * Catalog.TILE)
				if sim.can_place_building(Catalog.BLD_FLOWER, wx, wy):
					var ok = sim.place_building(Catalog.BLD_FLOWER, wx, wy)
					print("placed=", ok, " at ", wx, ",", wy)
					placed_at = Vector2(wx, wy)
					r = 999
					break
			if r >= 999: break
		if r >= 999: break
	# force sync a few frames
	for i in 5:
		await process_frame
	var sprites = main._building_active_sprites
	print("sprites=", sprites.keys())
	for id in sprites.keys():
		var n = sprites[id]
		print(" sprite id=", id, " vis=", n.visible, " tex=", n.texture, " pos=", n.position, " scale=", n.scale)
	# save viewport
	await process_frame
	var img = main.get_viewport().get_texture().get_image()
	img.save_png("res://shots/probe_flower_place.png")
	print("saved shots/probe_flower_place.png")
	quit()
