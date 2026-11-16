extends RefCounted
class_name ShotCapture

var main: Node2D
var sim: Node

var frames := 0
var done := false
var hud_saved := false
var bubbles_saved := false
var egg_done := false
var console_saved := false
var name_saved := false
var dos_saved := false
var settings_saved := false
var sign_saved := false
var path_saved := false
var fx_saved := false
var fx_i := 0
var round_ids: Array = []
var round_mark := -1
var round_hold := 0
var board: SubViewport
var video_saved := false
var title_saved := false


func setup(p_main: Node2D) -> void:
	main = p_main
	sim = ThrongletSimServer


func tick_shot() -> void:
	if sim.shot_fx:
		_tick_shot_fx()
		return
	if sim.shot_round:
		_tick_shot_round()
		return
	if sim.shot_carry:
		_tick_shot_carry()
		return
	if board == null:
		if sim.shot_throng >= 0:
			main.selected = sim.shot_throng
		if sim.shot_factory >= 0:
			main.selected_bld = sim.shot_factory
		var reach: float = float(sim.shot_span)
		var half_w := reach * sqrt(2.0)
		var half_h := reach * 0.70710678
		var view := main.get_viewport_rect().size
		var zoom := minf(view.x / (half_w * 2.0 + 64.0), view.y / (half_h * 2.0 + 96.0))
		if path_saved:
			main.cam_rig.set_zoom(4.0)
			main.camera.position = main.cam_rig.to_iso(sim.shot_path)
		else:
			main.cam_rig.set_zoom(zoom)
			main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
		frames += 1
		if not dos_saved:
			if main.ui != null:
				main.ui.visible = true
			main._open_dos()
			main.dos_shown = main.dos_full.length()
			main.dos_label.text = main.dos_full
			if frames < 4:
				return
			if not save_shot(main.get_viewport(), "res://shots/dos.png"):
				main.get_tree().quit(1)
				return
			main._finish_dos()
			dos_saved = true
			frames = 0
			return
		if not console_saved:
			var show_console: bool = float(sim.shot_span) <= 360.0
			main._set_hud_shown(false)
			if main.kit_panel != null:
				main.kit_panel.visible = false
			if main.focus_dim != null:
				main.focus_dim.visible = false
			if main.focus_frame != null:
				main.focus_frame.visible = false
			if main.focus_box != null:
				main.focus_box.visible = false
			if main.console != null:
				main.console.visible = show_console
			if main.console_log != null:
				main.console_log.text = ""
			if main.console_prompts != null:
				main.console_prompts.visible = false
			if main.console_input != null:
				main.console_input.visible = false
			if show_console:
				main._layout_console()
				main.console_log.text = "Arrastra una setita de la base al Dr. Thronglet."
				sim.shown_dialogue = true
			if frames < 8:
				return
			if not save_shot(main.get_viewport(), "res://shots/console.png"):
				main.get_tree().quit(1)
				return
			console_saved = true
			frames = 0
			return
		if not title_saved:
			main.in_title = true
			if main.ui != null:
				main.ui.visible = true
			main.title_root.visible = true
			main.crt_on = true
			main._apply_crt()
			main._fill_title()
			main.title_layout_size = Vector2.ZERO
			main._tick_title(0.0)
			if frames < 8:
				return
			if not save_shot(main.get_viewport(), "res://shots/title.png"):
				main.get_tree().quit(1)
				return
			title_saved = true
			frames = 0
			return
		if not settings_saved:
			main.in_title = true
			main.title_root.visible = true
			main.crt_on = true
			main._apply_crt()
			var settings_shots := [
				{"tab": 0, "path": "res://shots/settings_mail.png"},
				{"tab": 1, "path": "res://shots/settings_cog.png"},
				{"tab": 2, "path": "res://shots/settings_sound.png"},
				{"tab": 3, "path": "res://shots/settings.png"},
			]
			var shot_i := mini(frames / 4, settings_shots.size() - 1)
			var spec: Dictionary = settings_shots[shot_i]
			main.settings_tab = int(spec.tab)
			main.crt_on = true
			main._apply_crt()
			main._fill_settings()
			if frames % 4 != 3:
				return
			if not save_shot(main.get_viewport(), str(spec.path)):
				main.get_tree().quit(1)
				return
			if shot_i < settings_shots.size() - 1:
				return
			main.crt_on = false
			main._apply_crt()
			main.title_root.visible = false
			main.in_title = false
			settings_saved = true
			frames = 0
			return
		if not video_saved:
			main.in_title = true
			main.title_root.visible = true
			main.crt_on = true
			main._apply_crt()
			main._fill_title()
			if main.title_menu != null:
				main.title_menu.visible = false
			if main.title_hud != null:
				main.title_hud.visible = true
			if main.video_library_grid == null or main.video_library_grid.get_child_count() == 0:
				main.media.video_played["SEQ_1.5"] = true
				main._fill_video_library()
			if main.video_library != null:
				main.video_library.visible = true
				main._layout_video_library_shell()
			if frames < 8:
				return
			if not save_shot(main.get_viewport(), "res://shots/video_library.png"):
				main.get_tree().quit(1)
				return
			if main.video_library != null:
				main.video_library.visible = false
			main.title_root.visible = false
			main.in_title = false
			video_saved = true
			frames = 0
			return
		if not sign_saved:
			sim.tutorial_i = 2
			main._set_hud_shown(false)
			main._sync_focus(0.0)
			if frames < 4:
				return
			if not save_shot(main.get_viewport(), "res://shots/sign.png"):
				main.get_tree().quit(1)
				return
			sim.tutorial_i = -1
			if main.sign_button != null:
				main.sign_button.visible = false
			main._set_hud_shown(true)
			main._sync_focus(0.0)
			sign_saved = true
			frames = 0
			return
		if not hud_saved:
			sim.glitch_t = 0.0
			if main.glitch_overlay != null:
				main.glitch_overlay.visible = false
			sim.modal = {}
			sim.talk_pending = {}
			sim.frozen = false
			sim.tutorial_i = -1
			if main.sign_button != null:
				main.sign_button.visible = false
			if not egg_done:
				var egg: Dictionary = main._starter_egg()
				if egg.is_empty():
					sim._spawn_starter_egg()
					egg = main._starter_egg()
				if float(egg.get("air", 0.0)) <= 0.0 and main.focus_hold <= 0.0 and frames == 1:
					egg.air = 140.0
					egg.x = 256.0
					egg.y = 256.0
				var egg_air := float(egg.get("air", 0.0))
				if egg_air > 0.0:
					egg.air = maxf(0.0, egg_air - 6.0)
					main.focus_hold = 0.45
					if main.ui != null:
						main.ui.visible = true
					main._set_hud_shown(true)
					main._sync_focus(0.016)
					return
				if main.focus_hold > 0.0:
					main.focus_hold = maxf(0.0, main.focus_hold - 0.016)
					main._sync_focus(0.016)
					return
				egg_done = true
				frames = 0
				return
			main.focus_on = false
			if main.focus_dim != null:
				main.focus_dim.visible = false
			if main.focus_frame != null:
				main.focus_frame.visible = false
			if main.focus_box != null:
				main.focus_box.visible = false
			if sim.barks.is_empty() and sim.shot_throng >= 0:
				sim.barks.append({
					"id": sim.shot_throng,
					"icon": Catalog.ICON_APPLE,
					"t": 30.0,
					"x": sim.pos_x[sim.shot_throng],
					"y": sim.pos_y[sim.shot_throng],
				})
			if main.ui != null:
				main.ui.visible = true
			main._set_hud_shown(true)
			main.kit_open = true
			main.kit_tab = 0
			main._set_kit_shown(true)
			main._sync_hud(0.0)
			main._sync_focus(0.0)
			if main.task_panel != null:
				main.task_panel.visible = true
			if frames < 12:
				return
			if not save_shot(main.get_viewport(), "res://shots/hud_task.png"):
				main.get_tree().quit(1)
				return
			hud_saved = true
			frames = 0
			return
		if not bubbles_saved:
			if main.task_panel != null:
				main.task_panel.visible = false
			if sim.barks.is_empty() and sim.shot_throng >= 0:
				sim.barks.append({
					"id": sim.shot_throng,
					"icon": Catalog.ICON_APPLE,
					"t": 30.0,
					"x": sim.pos_x[sim.shot_throng],
					"y": sim.pos_y[sim.shot_throng],
				})
			if sim.shot_throng >= 0:
				main.camera.position = main.cam_rig.to_iso(Vector2(sim.pos_x[sim.shot_throng], sim.pos_y[sim.shot_throng]))
			main.cam_rig.set_zoom(3.0)
			main._sync_marks()
			if frames < 8:
				return
			if not save_shot(main.get_viewport(), "res://shots/bubbles_now.png"):
				main.get_tree().quit(1)
				return
			bubbles_saved = true
			sim.barks.clear()
			frames = 0
			return
		if not path_saved:
			if frames < 12:
				return
			if not save_shot(main.get_viewport(), "res://shots/island_all.png"):
				main.get_tree().quit(1)
				return
			main.camera.position = main.cam_rig.to_iso(sim.shot_path)
			main.cam_rig.set_zoom(4.0)
			path_saved = true
			frames = 0
			return
		if frames < 6:
			return
		if not save_shot(main.get_viewport(), "res://shots/path_zoom.png"):
			main.get_tree().quit(1)
			return
		build_asset_shot()
		frames = 0
		return
	frames += 1
	if frames < 16:
		return
	if not save_shot(board, "res://shots/thronglet_sheet.png"):
		main.get_tree().quit(1)
		return
	done = true
	main.get_tree().quit(0)


func _tick_shot_carry() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main._set_kit_shown(false)
	if main.task_panel != null:
		main.task_panel.visible = false
	main.crt_on = false
	main._apply_crt()
	main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
	var view := main.get_viewport_rect().size
	var reach: float = float(sim.shot_span)
	var half_w := reach * sqrt(2.0)
	var half_h := reach * 0.70710678
	var zoom := minf(view.x / (half_w * 2.0 + 48.0), view.y / (half_h * 2.0 + 64.0))
	main.cam_rig.set_zoom(clampf(zoom, 3.0, 6.0))
	frames += 1
	if frames < 8:
		return
	var wood_f: int = int(main._prop_frame(Catalog.ICON_WOOD))
	var bone_f: int = int(main._prop_frame(Catalog.ICON_BONE))
	var ore_f: int = int(main._prop_frame(Catalog.ICON_ORE))
	var carry_fs: Array = []
	var carriers := 0
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		carriers += 1
		carry_fs.append(main._frame(i, sim.time))
	print("SHOT CARRY frames=%s ore=%d wood=%d bone=%d carriers=%d carry=%s" % [
		carry_fs.size(), ore_f, wood_f, bone_f, carriers, str(carry_fs)
	])
	if ore_f < 0 or wood_f < 0 or bone_f < 0 or carriers < 3:
		print("SHOT CARRY FAIL ore=%d wood=%d bone=%d carriers=%d" % [ore_f, wood_f, bone_f, carriers])
		main.get_tree().quit(1)
		return
	if not save_shot(main.get_viewport(), "res://shots/carry_check.png"):
		main.get_tree().quit(1)
		return
	done = true
	main.get_tree().quit(0)


func _tick_shot_round() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main._set_kit_shown(false)
	if main.task_panel != null:
		main.task_panel.visible = false
	main.crt_on = false
	main._apply_crt()
	main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
	main.cam_rig.set_zoom(5.0)
	var round_b := {}
	for b in sim.buildings:
		if not b.dead and int(b.kind) == Catalog.BLD_ROUND:
			round_b = b
			break
	if round_b.is_empty():
		print("SHOT ROUND FAIL no building")
		main.get_tree().quit(1)
		return
	var marks := [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]
	if round_ids.is_empty():
		sim.frozen = true
		round_b.active = true
		round_b.spin = 0.0
		round_b.ride_angles = {}
		round_b.ride_slots = {}
		round_b.riders = []
		round_b.rider = -1
		round_ids.clear()
		for slot_i in 8:
			var id: int = int(sim._push_slot(float(round_b.x) + 24.0, float(round_b.y) + 24.0, 80.0, 20.0, 80.0, 80.0, -1))
			if id < 0:
				break
			sim.act[id] = ThrongletSimServer.ACT_PLAY
			sim.act_t[id] = 0.55
			sim._set_ride_slot(round_b, id, slot_i)
			sim._set_rider(round_b, id, true)
			sim._set_ride_age(round_b, id, 0.0)
			sim._place_on_ride_slot(id, round_b, slot_i)
			round_ids.append(id)
		round_b.active = true
		sim._rebuild_hash()
		print("SHOT ROUND seated ids=%s slots=%s" % [str(round_ids), str(round_b.get("ride_slot", {}))])
		round_mark = 0
		round_hold = 0
		return
	if round_mark >= marks.size():
		done = true
		main.get_tree().quit(0)
		return
	var target := float(marks[round_mark]) * TAU
	round_b.spin = target
	round_b.active = true
	for id in round_ids:
		if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_LIVING:
			continue
		var slot: int = int(sim._ride_slot_of(round_b, id))
		sim._place_on_ride_slot(id, round_b, slot)
		sim.act[id] = ThrongletSimServer.ACT_PLAY
		sim.act_t[id] = 0.55
	round_hold += 1
	if round_hold < 2:
		return
	if round_ids.size() < 2:
		print("SHOT ROUND FAIL seated=%s" % str(round_ids))
		main.get_tree().quit(1)
		return
	var a := int(round_ids[0])
	var b_id := int(round_ids[1])
	var mid := Vector2(float(round_b.x), float(round_b.y)) + Catalog.ROUND_RIDE_OFF
	var ang_a := atan2(sim.pos_y[a] - mid.y, sim.pos_x[a] - mid.x)
	var ang_b := atan2(sim.pos_y[b_id] - mid.y, sim.pos_x[b_id] - mid.x)
	var sep := absf(fposmod(ang_a - ang_b + PI, TAU) - PI)
	var gap := Vector2(sim.pos_x[a] - sim.pos_x[b_id], sim.pos_y[a] - sim.pos_y[b_id]).length()
	var deg := int(round(float(marks[round_mark]) * 360.0))
	print("SHOT ROUND spin=%d deg sep=%.2f gap=%.1f a=(%.1f,%.1f) b=(%.1f,%.1f) frame=%d" % [
		deg, sep, gap, sim.pos_x[a], sim.pos_y[a], sim.pos_x[b_id], sim.pos_y[b_id],
		132 + posmod(int(floor(target / (TAU / 8.0))), 8)
	])
	if absf(sep - PI) > 0.12:
		print("SHOT ROUND FAIL unsynced sep=%.2f at %d" % [sep, deg])
		main.get_tree().quit(1)
		return
	if gap < Catalog.ROUND_RIDE_RADIUS * 1.5:
		print("SHOT ROUND FAIL clumped gap=%.1f at %d" % [gap, deg])
		main.get_tree().quit(1)
		return
	if not save_shot(main.get_viewport(), "res://shots/round_spin_%03d.png" % deg):
		main.get_tree().quit(1)
		return
	round_mark += 1
	round_hold = 0


func _tick_shot_fx() -> void:
	var cases := [
		{"id": "aura:flower", "wait": 24, "path": "res://shots/fx_aura_flower.png"},
		{"id": "act:bath", "wait": 24, "path": "res://shots/fx_act_bath.png"},
		{"id": "act:sponge", "wait": 24, "path": "res://shots/fx_act_sponge.png"},
		{"id": "visit:dwell", "wait": 24, "path": "res://shots/fx_visit_dwell.png"},
		{"id": "feat:fire", "wait": 24, "path": "res://shots/fx_feat_fire.png"},
	]
	if not fx_saved:
		if not main.dev_on:
			main._enter_dev()
			frames = 0
			return
		if main.dev_bench == null:
			print("SHOT FAIL no dev_bench")
			main.get_tree().quit(1)
			return
		if not bool(main.dev_bench.effect_mode):
			main.dev_bench._show_effects()
			frames = 0
			return
		var spec: Dictionary = cases[mini(fx_i, cases.size() - 1)]
		if str(main.dev_bench.effect_id) != str(spec.id):
			main.dev_bench._select_effect(str(spec.id))
			main.dev_bench.effect_playing = true
			main.dev_bench._sync_effect_play_button()
			for _i in 40:
				main.dev_bench._tick_effect(0.05)
			main.dev_bench.effect_t = 2.5
			frames = 0
			return
		frames += 1
		if frames < int(spec.wait):
			return
		print("SHOT FX id=%s fed=%.1f fun=%.1f clean=%.1f clip=%s gauge=%s ring=%s ui=%s" % [
			spec.id,
			main.dev_bench.effect_fed,
			main.dev_bench.effect_fun,
			main.dev_bench.effect_clean,
			main.dev_bench.effect_clip,
			main.dev_bench.effect_gauge.visible if main.dev_bench.effect_gauge != null else false,
			main.dev_bench.effect_ring.visible if main.dev_bench.effect_ring != null else false,
			main.ui.visible if main.ui != null else false,
		])
		if not save_shot(main.get_viewport(), str(spec.path)):
			main.get_tree().quit(1)
			return
		fx_i += 1
		frames = 0
		if fx_i < cases.size():
			return
		fx_saved = true
		done = true
		main.get_tree().quit(0)
		return
	done = true
	main.get_tree().quit(0)


func save_shot(source: Viewport, path: String) -> bool:
	var image := source.get_texture().get_image()
	if image == null or image.get_width() < 2:
		print("SHOT FAIL no image %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var err := image.save_png(path)
	print("SHOT %s path=%s size=%sx%s" % ["OK" if err == OK else "FAIL", path, image.get_width(), image.get_height()])
	return err == OK


func build_asset_shot() -> void:
	var board_vp := SubViewport.new()
	board_vp.size = Vector2i(960, 980)
	board_vp.disable_3d = true
	board_vp.transparent_bg = false
	board_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(board_vp)
	board = board_vp
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = main.world.texture
	sheet.material = main.world.material
	sheet.multimesh = main._mesh(true, Vector2(main.WORLD_CELL, main.WORLD_CELL))
	board_vp.add_child(sheet)
	var samples: Array = [
		["idle", ThrongClips.frame_at("ThrongA_Default", 0), 0.0],
		["talk", ThrongClips.frame_at("ThrongA_Talk", 2), 0.0],
		["dead", ThrongClips.frame_at("ThrongA_Dead_001", 0), 0.0],
		["bones", ThrongClips.frame_at("ThrongA_Bones", 0), 0.0],
		["sing", ThrongClips.frame_at("Throng_Sing_Spritesheet", 2), 0.0],
		["kick", ThrongClips.frame_at("ThrongA_Bored_KickRock", 6), 0.0],
		["ghost", ThrongClips.frame_at("ThrongA_Default_Ghost", 0), 0.0],
		["outline", ThrongClips.frame_at("Thronglet_Outline", 0), 0.0],
		["celebrate", ThrongClips.frame_at("ThrongA_Celebrate_Spritesheet", 4), 0.0],
		["shrug", ThrongClips.frame_at("ThrongA_Shrug", 1), 0.0],
		["think", ThrongClips.frame_at("ThrongA_DeepThought_Spritesheet", 1), 0.0],
		["jump", ThrongClips.frame_at("ThrongA_Jump", 0), 0.0],
		["dirty", ThrongClips.frame_at("ThrongA_Default", 0), 1.0],
		["bubble", AssetFrames.frame(AssetFrames.BUBBLE, AssetFrames.BUBBLE_N, 0), 0.0],
		["foam", AssetFrames.frame(AssetFrames.BUBBLE_LIGHT, AssetFrames.BUBBLE_LIGHT_N, 1), 0.0],
		["clean", AssetFrames.frame(AssetFrames.CLEAN, AssetFrames.CLEAN_N, 1), 0.0],
		["splash", AssetFrames.frame(AssetFrames.SPLASH, AssetFrames.SPLASH_N, 1), 0.0],
		["smoke", AssetFrames.frame(AssetFrames.SMOKE, AssetFrames.SMOKE_N, 1), 0.0],
		["aura", AssetFrames.frame(AssetFrames.AURA, AssetFrames.AURA_N, 1), 0.0],
		["spark", AssetFrames.frame(AssetFrames.SPARK, AssetFrames.SPARK_N, 1), 0.0],
		["glitch", AssetFrames.frame(AssetFrames.GLITCH, AssetFrames.GLITCH_N, 3), 0.0],
		["tile", AssetFrames.frame(AssetFrames.TILE_GLITCH, AssetFrames.TILE_GLITCH_N, 1), 0.0],
		["hand", AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, 1), 0.0],
		["fire", AssetFrames.FIRE, 0.0],
		["blob", AssetFrames.FIRE_BLOB, 0.0],
		["house", AssetFrames.GLITCH_HOUSE, 0.0],
		["gtree", AssetFrames.GLITCH_TREE, 0.0],
		["treec", AssetFrames.GLITCH_TREE_C, 0.0],
		["treed", AssetFrames.GLITCH_TREE_D, 0.0],
		["waste", AssetFrames.WASTE_TREE, 0.0],
		["wasteb", AssetFrames.WASTE_TREE_B, 0.0],
		["anomaly", AssetFrames.ANOMALY, 0.0],
		["ray", AssetFrames.ANOMALY_RAY, 0.0],
		["epilogue", AssetFrames.EPILOGUE, 0.0],
		["rotten", AssetFrames.ROTTEN_APPLE, 0.0],
		["mount", AssetFrames.MOUNT_BIG, 0.0],
		["fumes", AssetFrames.FUMES, 0.0],
		["grass", AssetFrames.GRASS_PATCH, 0.0],
		["suds", AssetFrames.SUDS, 0.0],
	]
	var draws: Array = []
	var labels := CanvasLayer.new()
	board_vp.add_child(labels)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(root)
	var theme := Theme.new()
	var font: Font = main.ui_assets.ui_font() as Font
	if font != null:
		theme.default_font = font
		theme.default_font_size = 16
	root.theme = theme
	var scale := 0.55
	var cols := 8
	for i in samples.size():
		var sample: Array = samples[i]
		var col := i % cols
		var row := int(i / cols)
		var center := Vector2(56 + col * 116, 58 + row * 108)
		var frame := int(sample[1])
		if frame < 0:
			continue
		draws.append({
			"p": center + Vector2(0, main.WORLD_CELL * 0.5 * scale),
			"icon": frame,
			"tint": Color.WHITE,
			"scale": scale,
			"dirty": float(sample[2]),
		})
		var tag := Label.new()
		tag.text = str(sample[0])
		tag.position = center + Vector2(-40, 34)
		tag.size = Vector2(80, 12)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(tag)
	main._write_mesh(sheet.multimesh, draws)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 820)
	panel.custom_minimum_size = Vector2(620, 120)
	if ResourceLoader.exists("res://resources/ui/wood_panel.png"):
		panel.add_theme_stylebox_override("panel", main.ui_assets.box_style("res://resources/ui/wood_panel.png", 24, 24))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var quote := Label.new()
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(540, 70)
	quote.add_theme_font_size_override("font_size", 16)
	var line := LineBook.line_for("shot_check")
	quote.text = line if line != "" else "SIN LINEA"
	margin.add_child(quote)
	root.add_child(panel)
	var faces := ["epilogue_angry", "epilogue_bewildered", "epilogue_caretaker", "epilogue_birthday", "epilogue_capitalist"]
	for i in faces.size():
		var face := TextureRect.new()
		face.texture = main.ui_assets.tex(main.POP_FACES[faces[i]])
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2(660 + (i % 3) * 96, 820 + int(i / 3) * 70)
		face.size = Vector2(88, 64)
		root.add_child(face)
	var plates: PackedStringArray = main._biome_plate_paths("epilogue")
	plates.append_array(main._biome_plate_paths("anomaly"))
	for i in plates.size():
		var plate := TextureRect.new()
		plate.texture = main.ui_assets.tex(plates[i])
		plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		plate.position = Vector2(16 + i * 100, 760)
		plate.size = Vector2(92, 28)
		root.add_child(plate)
