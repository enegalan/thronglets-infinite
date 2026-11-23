extends Node

# godot --path . -- --pick-zoom-repro [--pick-count=5000]
# Boots, zooms out, arms pickaxe charge-area every frame, fires pick.

var main = null
var phase := "boot"
var phase_t := 0.0
var frames := 0
var count := 5000


func setup(host) -> void:
	main = host
	var args := OS.get_cmdline_user_args()
	for raw in args:
		var a := str(raw)
		if a.begins_with("--pick-count="):
			count = maxi(0, int(a.substr(a.find("=") + 1)))
	print("PICK ZOOM REPRO start count=%s" % count)


func tick(delta: float) -> void:
	if main == null:
		return
	frames += 1
	match phase:
		"boot":
			_boot()
		"warmup":
			phase_t += delta
			if phase_t >= 0.8:
				print("PICK ZOOM REPRO zoom=%s arm pick living=%s" % [
					main.cam_rig.zoom_level, ThrongletSimServer.living
				])
				main.kit_drag = {"type": "tool", "id": Catalog.TOOL_PICK}
				main.tool = Catalog.TOOL_PICK
				main.kit_open = false
				if main.has_method("_set_kit_shown"):
					main._set_kit_shown(false)
				phase = "hold"
				phase_t = 0.0
		"hold":
			phase_t += delta
			# Force the charge-area path that arms when the pico is out.
			var zoom_scale: float = float(main.cam_rig.zoom_level)
			var pts: PackedVector2Array = main._iso_ellipse_points(
				Vector2(256, 256), Catalog.PICK_RADIUS, Catalog.PICK_RADIUS * 0.82, 48
			)
			main.charge_area.call("set_area", pts, Color(0.35, 1.0, 0.45, 1.0), true, zoom_scale)
			main.charge_area.visible = true
			if frames % 30 == 0:
				print("PICK ZOOM REPRO hold t=%.2f pts=%d fps=%s" % [
					phase_t, pts.size(), Engine.get_frames_per_second()
				])
			if phase_t >= 1.2:
				print("PICK ZOOM REPRO fire use_tool pick")
				ThrongletSimServer.use_tool(Catalog.TOOL_PICK, 256.0, 256.0)
				phase = "after"
				phase_t = 0.0
		"after":
			phase_t += delta
			if phase_t >= 1.0:
				print("PICK ZOOM REPRO OK frames=%d fps=%s" % [frames, Engine.get_frames_per_second()])
				phase = "quit"
				get_tree().quit(0)
		"quit":
			get_tree().quit(0)


func _boot() -> void:
	var sim = ThrongletSimServer
	if sim == null or main.cam_rig == null:
		return
	sim.paused = false
	sim.frozen = false
	sim.smoke_hold = false
	sim.modal = {}
	main.in_title = false
	if main.title_root != null:
		main.title_root.visible = false
	if main.ui != null:
		main.ui.visible = true
	if sim.unlocks is Dictionary:
		sim.unlocks["pickaxe"] = true
		sim.unlocks["unlock_pickaxe"] = true
	if count > 0:
		sim.debug_perf_busy(Vector2(256, 256), 2)
		main.seen_epoch = -1
		sim.debug_spawn(count, Vector2(256, 256))
	main.cam_rig.set_zoom(CameraRig.ZOOM_MIN)
	main.cam_rig.focus_world(Vector2(256, 256))
	print("PICK ZOOM REPRO booted living=%s features=%s zoom=%s" % [
		sim.living, sim.features.size(), main.cam_rig.zoom_level
	])
	phase = "warmup"
	phase_t = 0.0
