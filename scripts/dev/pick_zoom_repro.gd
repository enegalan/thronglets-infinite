extends Node

# godot --path . -- --pick-zoom-repro [--pick-count=5000]
# Boots, zooms out, arms pickaxe charge-area every frame, fires pick.

## Main host for camera and kit state during pickaxe zoom reproduction.
var main = null
## CLI reproduction state machine phase name.
var phase := "boot"
## Elapsed time within the current reproduction phase.
var phase_t := 0.0
## Total frames since reproduction harness start.
var frames := 0
## Thronglet count to spawn via debug_spawn before stress test.
var count := 5000


## Parses --pick-count and prints harness start banner.
func setup(host) -> void:
	main = host
	var args := OS.get_cmdline_user_args()
	for raw in args:
		var a := str(raw)
		if a.begins_with("--pick-count="):
			count = maxi(0, int(a.substr(a.find("=") + 1)))
	print("PICK ZOOM REPRO start count=%s" % count)


## Advances boot, warmup, charge-area hold, tool fire, and exit phases.
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
				main.kit_toolbar.set_kit_shown(false)
				phase = "hold"
				phase_t = 0.0
		"hold":
			phase_t += delta
			# Force the charge-area path that arms when the pico is out.
			var zoom_scale: float = float(main.cam_rig.zoom_level)
			var pts: PackedVector2Array = main.iso_draw.iso_ellipse_points(
				Vector2(256, 256), Catalog.PICK_RADIUS, Catalog.PICK_RADIUS * 0.82, 48
			)
			main.placement_overlay.charge_area.call("set_area", pts, Color(0.35, 1.0, 0.45, 1.0), true, zoom_scale)
			main.placement_overlay.charge_area.visible = true
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


## Enters play UI, unlocks pickaxe, optionally spams world, zooms to minimum.
func _boot() -> void:
	var sim = ThrongletSimServer
	if sim == null or main.cam_rig == null:
		return
	sim.paused = false
	sim.frozen = false
	sim.smoke_hold = false
	sim.modal = {}
	main.in_title = false
	if main.title.title_root != null:
		main.title.title_root.visible = false
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
