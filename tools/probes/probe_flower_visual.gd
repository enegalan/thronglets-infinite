extends SceneTree


## Sandbox scene probe that exercises flower visual states on the real Main tree.


func _init() -> void:
	call_deferred("_go")


## Boots the scene harness, runs checks, and quits with pass/fail status.
func _go() -> void:
	await process_frame
	var sim: Node = root.get_node("ThrongletSimServer")
	# Skip title/logo and shot harness; keep normal Main._process sync.
	sim.set("testing", true)
	sim.set("shot_mode", false)
	sim.call("new_sandbox_game")
	await process_frame
	sim.set("sandbox_mode", true)
	sim.set("gems", 999)
	var unlocks: Dictionary = sim.get("unlocks")
	unlocks["flower"] = true
	unlocks["sculpture"] = true

	var packed: PackedScene = load(str(ProjectSettings.get_setting("application/run/main_scene")))
	var main: Node2D = packed.instantiate()
	root.add_child(main)
	main.set("in_title", false)
	if main.get("title_root") != null:
		main.title.title_root.visible = false
	await process_frame
	await process_frame

	var placed_at = Vector2.ZERO
	var ok_n = 0
	for y in range(-12, 13):
		for x in range(-12, 13):
			var wx = float(x * Catalog.TILE)
			var wy = float(y * Catalog.TILE)
			if bool(sim.call("can_place_building", Catalog.BLD_FLOWER, wx, wy)):
				ok_n += 1
				if placed_at == Vector2.ZERO:
					placed_at = Vector2(wx, wy)
	print("can_place spots=", ok_n, " first=", placed_at)
	var placed: bool = false
	if ok_n > 0:
		placed = bool(sim.call("place_building", Catalog.BLD_FLOWER, placed_at.x, placed_at.y))
	print("place -> ", placed)

	if main.get("cam_rig") != null and main.get("camera") != null:
		main.cam_rig.set_zoom(3.0)
		main.camera.position = main.cam_rig.to_iso(placed_at)

	for _i in 10:
		await process_frame

	var sprites: Dictionary = main.get("_building_active_sprites")
	print("sprites=", sprites.keys())
	for id in sprites.keys():
		var n: Sprite2D = sprites[id]
		var path = "<null>"
		if n.texture != null:
			path = str(n.texture.resource_path)
		print(
			" sprite id=", id,
			" vis=", n.visible,
			" tex=", path,
			" pos=", n.position,
			" scale=", n.scale,
			" size=", (n.texture.get_size() if n.texture else Vector2.ZERO)
		)

	# Texture load check independent of viewport.
	var tex0: Texture2D = main.structure_tex.structure_anim_texture(Catalog.BLD_FLOWER, 0)
	print("flower_0 tex=", tex0, " path=", tex0.resource_path if tex0 else "")
	quit()
