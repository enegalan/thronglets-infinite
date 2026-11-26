extends RefCounted
class_name ShotCapture

## Shared world mesh/cell sizing used when building shot review boards.
const WorldBootstrap := preload("res://scripts/presentation/world/world_bootstrap.gd")

## Main scene driving viewport capture and camera framing.
var main: Node2D

var sim: Node

## Frames waited before capturing the current shot step.
var frames := 0
## Shot harness finished and ready to quit.
var done := false
## Whether task and gem HUD reference shots were written.
var hud_saved := false
## Whether bark bubble shot was captured.
var bubbles_saved := false
## Whether starter egg air-drain sequence completed before HUD.
var egg_done := false
## Whether gaze console placeholder shot was saved.
var console_saved := false
## Unused name-field shot gate (legacy sequence slot).
var name_saved := false
## Whether DOS boot fullscreen shot was captured.
var dos_saved := false
## Whether all settings tab shots were captured.
var settings_saved := false
## Whether tutorial sign overlay shot was captured.
var sign_saved := false
## Whether island overview shot finished before path zoom.
var path_saved := false
## Whether dev-bench FX reference shots all succeeded.
var fx_saved := false
## Index of current effect case in the FX shot suite.
var fx_i := 0
## Living ids seated on the roundabout for spin shots.
var round_ids: Array = []
## Index of spin angle landmark being validated.
var round_mark := -1
## Frames to hold each spin angle before capture.
var round_hold := 0
## SubViewport or MultiMesh board used as PNG capture source.
var board: Node
## Whether video library shell shot was captured.
var video_saved := false
## Whether title screen CRT shot was captured.
var title_saved := false
## Multi-step apple bite sequence phase index.
var apple_phase := 0
## First thronglet id in apple bite choreography.
var apple_a := -1
## Second thronglet id in apple bite choreography.
var apple_b := -1
## World apple item id tracked across bite phases.
var apple_id := -1
## Frames waited in the current apple phase guard.
var apple_wait := 0
## Building-kind index in goo idle/active/goo row shots.
var bld_goo_i := 0
## Goo suite phase: per-kind rows, mop before, mop after.
var bld_goo_phase := 0
## Building id used for mop before/after goo shots.
var bld_goo_mop_id := -1
## Corpse blood wide vs close-up shot phase.
var blood_phase := 0


## Caches Main and ThrongletSimServer references for shot runs.
func setup(p_main: Node2D) -> void:
	main = p_main
	sim = ThrongletSimServer


## Main shot driver: routes to specialized captures or UI sequence.
func tick_shot() -> void:
	if sim.shot_anims:
		_tick_shot_anims()
		return
	if sim.shot_dirt:
		_tick_shot_dirt()
		return
	if sim.shot_ball:
		_tick_shot_ball()
		return
	if sim.shot_wash:
		_tick_shot_wash()
		return
	if sim.shot_bld_goo:
		_tick_shot_bld_goo()
		return
	if sim.shot_blood:
		_tick_shot_blood()
		return
	if sim.shot_fx:
		_tick_shot_fx()
		return
	if sim.shot_round:
		_tick_shot_round()
		return
	if sim.shot_carry:
		_tick_shot_carry()
		return
	if sim.shot_apple:
		_tick_shot_apple()
		return
	if sim.shot_needs:
		_tick_shot_needs()
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
			main.boot_seq.open_dos()
			main.boot_seq.dos_shown = main.boot_seq.dos_full.length()
			main.boot_seq.dos_label.text = main.boot_seq.dos_full
			if frames < 4:
				return
			if not save_shot(main.get_viewport(), "res://shots/dos.png"):
				main.get_tree().quit(1)
				return
			main.boot_seq.finish_dos()
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
			if main.gaze_panel != null:
				main.gaze_panel.visible = show_console
			if show_console:
				main.console_ui.layout_console()
				if main.gaze_text != null:
					main.gaze_text.text = "[SHOT] Placeholder console text."
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
			main.title.title_root.visible = true
			main.prefs.crt_on = true
			main.prefs.apply_crt()
			main.title.fill_title()
			main.title.title_layout_size = Vector2.ZERO
			main.title.tick(0.0)
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
			main.title.title_root.visible = true
			main.prefs.crt_on = true
			main.prefs.apply_crt()
			var settings_shots := [
				{"tab": 0, "path": "res://shots/settings_mail.png"},
				{"tab": 1, "path": "res://shots/settings_cog.png"},
				{"tab": 2, "path": "res://shots/settings_sound.png"},
				{"tab": 3, "path": "res://shots/settings.png"},
			]
			var shot_i := mini(frames / 4, settings_shots.size() - 1)
			var spec: Dictionary = settings_shots[shot_i]
			main.settings_menu.settings_tab = int(spec.tab)
			main.prefs.crt_on = true
			main.prefs.apply_crt()
			main.settings_menu.fill()
			if frames % 4 != 3:
				return
			if not save_shot(main.get_viewport(), str(spec.path)):
				main.get_tree().quit(1)
				return
			if shot_i < settings_shots.size() - 1:
				return
			main.prefs.crt_on = false
			main.prefs.apply_crt()
			main.title.title_root.visible = false
			main.in_title = false
			settings_saved = true
			frames = 0
			return
		if not video_saved:
			main.in_title = true
			main.title.title_root.visible = true
			main.prefs.crt_on = true
			main.prefs.apply_crt()
			main.title.fill_title()
			if main.settings_menu.title_menu != null:
				main.settings_menu.title_menu.visible = false
			if main.title.title_hud != null:
				main.title.title_hud.visible = true
			if main.video_lib.video_library_grid == null or main.video_lib.video_library_grid.get_child_count() == 0:
				main.media.video_played["SEQ_1.5"] = true
				main.video_lib.fill()
			if main.video_lib.video_library != null:
				main.video_lib.video_library.visible = true
				main.video_lib.layout_shell()
			if frames < 8:
				return
			if not save_shot(main.get_viewport(), "res://shots/video_library.png"):
				main.get_tree().quit(1)
				return
			if main.video_lib.video_library != null:
				main.video_lib.video_library.visible = false
			main.title.title_root.visible = false
			main.in_title = false
			video_saved = true
			frames = 0
			return
		if not sign_saved:
			sim.tutorial_i = 2
			main._set_hud_shown(false)
			main.focus_viewport.sync_focus(0.0)
			if frames < 4:
				return
			if not save_shot(main.get_viewport(), "res://shots/sign.png"):
				main.get_tree().quit(1)
				return
			sim.tutorial_i = -1
			if main.boot_seq.sign_button != null:
				main.boot_seq.sign_button.visible = false
			main._set_hud_shown(true)
			main.focus_viewport.sync_focus(0.0)
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
			if main.boot_seq.sign_button != null:
				main.boot_seq.sign_button.visible = false
			if not egg_done:
				var egg: Dictionary = main.focus_viewport.starter_egg()
				if egg.is_empty():
					sim.world_entities._spawn_starter_egg()
					egg = main.focus_viewport.starter_egg()
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
					main.focus_viewport.sync_focus(0.016)
					return
				if main.focus_hold > 0.0:
					main.focus_hold = maxf(0.0, main.focus_hold - 0.016)
					main.focus_viewport.sync_focus(0.016)
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
			main.kit_toolbar.set_kit_shown(true)
			main._sync_hud(0.0)
			main.focus_viewport.sync_focus(0.0)
			if main.task_panel != null:
				main.task_panel.visible = true
			if frames < 12:
				return
			if not save_shot(main.get_viewport(), "res://shots/hud_task.png"):
				main.get_tree().quit(1)
				return
			# Gem plaque reference shot: force part-two HUD and crop the top-left strip.
			sim.part_two = true
			sim.gems = 642
			main._sync_hud(0.0)
			if not save_shot(main.get_viewport(), "res://shots/hud_gem.png"):
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
			main.world_marks_ui.sync_marks()
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


## Captures need-bar low and recovered card shots.
func _tick_shot_needs() -> void:
	if main.ui != null:
		main.ui.visible = true
	main.kit_open = true
	main.kit_tab = 0
	main.kit_toolbar.set_kit_shown(true)
	main._set_hud_shown(true)
	if main.gaze_panel != null:
		main.gaze_panel.visible = false
	main.prefs.crt_on = false
	main.prefs.apply_crt()
	if sim.shot_throng >= 0:
		main.selected = sim.shot_throng
	main.cam_rig.set_zoom(3.2)
	main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
	main._sync_hud(0.0)
	if "task_panel" in main and main.task_panel != null:
		main.task_panel.visible = false
	frames += 1
	if frames == 8 and sim.shot_throng >= 0:
		sim.fed[sim.shot_throng] = 18.0
		sim.amused[sim.shot_throng] = 0.0
		sim.clean[sim.shot_throng] = 0.0
	if frames == 18 and sim.shot_throng >= 0:
		sim.fed[sim.shot_throng] = 100.0
		sim.amused[sim.shot_throng] = 100.0
		sim.clean[sim.shot_throng] = 100.0
	main.world_marks_ui.sync_need_bars()
	if frames == 14:
		RenderingServer.force_draw()
		if not save_shot(main.get_viewport(), "res://shots/needs_low.png"):
			main.get_tree().quit(1)
			return
		return
	if frames < 28:
		return
	RenderingServer.force_draw()
	if not save_shot(main.get_viewport(), "res://shots/needs_card.png"):
		main.get_tree().quit(1)
		return
	print("SHOT NEEDS DONE fed=%.0f amused=%.0f clean=%.0f" % [
		sim.fed[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
		sim.amused[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
		sim.clean[sim.shot_throng] if sim.shot_throng >= 0 else -1.0,
	])
	done = true
	main.get_tree().quit(0)


## Validates prop carry frames and saves carry_check.png.
func _tick_shot_carry() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main.kit_toolbar.set_kit_shown(false)
	if main.task_panel != null:
		main.task_panel.visible = false
	main.prefs.crt_on = false
	main.prefs.apply_crt()
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
	var wood_f: int = int(main.anim_frames.prop_frame(Catalog.ICON_WOOD))
	var bone_f: int = int(main.anim_frames.prop_frame(Catalog.ICON_BONE))
	var ore_f: int = int(main.anim_frames.prop_frame(Catalog.ICON_ORE))
	var carry_fs: Array = []
	var carriers := 0
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		carriers += 1
		carry_fs.append(main.anim_frames.frame(i, sim.time))
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


## Seats riders and captures synchronized spin angles.
func _tick_shot_round() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main.kit_toolbar.set_kit_shown(false)
	if main.task_panel != null:
		main.task_panel.visible = false
	main.prefs.crt_on = false
	main.prefs.apply_crt()
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
			var id: int = int(sim.world_entities._push_slot(float(round_b.x) + 24.0, float(round_b.y) + 24.0, 80.0, 20.0, 80.0, 80.0, -1))
			if id < 0:
				break
			sim.act[id] = ThrongletSimServer.ACT_PLAY
			sim.act_t[id] = 0.55
			sim.agent_tick._set_ride_slot(round_b, id, slot_i)
			sim.agent_tick._set_rider(round_b, id, true)
			sim.agent_tick._set_ride_age(round_b, id, 0.0)
			sim.agent_tick._place_on_ride_slot(id, round_b, slot_i)
			round_ids.append(id)
		round_b.active = true
		sim.spatial._rebuild_hash()
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
		var slot: int = int(sim.agent_tick._ride_slot_of(round_b, id))
		sim.agent_tick._place_on_ride_slot(id, round_b, slot)
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
	var ang_a = atan2(sim.pos_y[a] - mid.y, sim.pos_x[a] - mid.x)
	var ang_b = atan2(sim.pos_y[b_id] - mid.y, sim.pos_x[b_id] - mid.x)
	var sep := absf(fposmod(ang_a - ang_b + PI, TAU) - PI)
	var gap = Vector2(sim.pos_x[a] - sim.pos_x[b_id], sim.pos_y[a] - sim.pos_y[b_id]).length()
	var deg := int(round(float(marks[round_mark]) * 360.0))
	print("SHOT ROUND spin=%d deg sep=%.2f gap=%.1f a=(%.1f,%.1f) b=(%.1f,%.1f) frame=%d" % [
		deg, sep, gap, sim.pos_x[a], sim.pos_y[a], sim.pos_x[b_id], sim.pos_y[b_id],
		posmod(int(floor(target / (TAU / float(StructureTextures.ROUND_ANIM_N)))), StructureTextures.ROUND_ANIM_N)
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


## Steps dev bench effects and saves each fx_*.png.
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



## Looks up the living ITEM_APPLE dict in sim.items.
func _apple_item() -> Dictionary:
	for it in sim.items:
		if not it.dead and int(it.kind) == Catalog.ITEM_APPLE:
			return it
	return {}


## Runs live bite timing and saves apple_bites_*.png.
func _tick_shot_apple() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main.kit_toolbar.set_kit_shown(false)
	if "kit_panel" in main and main.kit_panel != null:
		main.kit_panel.visible = false
	if "task_panel" in main and main.task_panel != null:
		main.task_panel.visible = false
	if main.gaze_panel != null:
		main.gaze_panel.visible = false
	main.prefs.crt_on = false
	main.prefs.apply_crt()
	main.cam_rig.set_zoom(5.5)
	main.camera.position = main.cam_rig.to_iso(sim.shot_focus)

	if apple_phase == 0:
		# Keep simulation held while binding actors and capturing initial state.
		sim.frozen = false
		sim.paused = false
		sim.smoke_hold = true
		# bind actor IDs once
		if apple_id < 0:
			for it in sim.items:
				if not it.dead and int(it.kind) == Catalog.ITEM_APPLE:
					apple_id = int(it.id)
					break
		if apple_a < 0 or apple_b < 0:
			var ids: Array = []
			for i in sim.slot_count:
				if sim.state[i] == Catalog.ST_LIVING:
					ids.append(i)
			if ids.size() >= 2:
				# A is hungrier/closer initially
				if sim.fed[int(ids[0])] <= sim.fed[int(ids[1])]:
					apple_a = int(ids[0]); apple_b = int(ids[1])
				else:
					apple_a = int(ids[1]); apple_b = int(ids[0])
		frames += 1
		if frames < 12:
			return
		if not save_shot(main.get_viewport(), "res://shots/apple_bites_01_full.png"):
			main.get_tree().quit(1)
			return
		apple_phase = 1
		frames = 0
		apple_wait = 0
		sim.smoke_hold = false
		return

	sim.frozen = false
	sim.paused = false
	sim.smoke_hold = false

	if apple_phase == 1:
		# wait for A to eat first bite
		apple_wait += 1
		var apple := _apple_item()
		var bites := int(apple.get("bites_left", 3)) if not apple.is_empty() else -1
		# capture mid-bite: sprite should already show the bite being taken
		if bites == 3 and not apple.is_empty() and float(apple.get("bite", 0.0)) > 0.15 and frames == 0:
			frames = 1
			if not save_shot(main.get_viewport(), "res://shots/apple_bites_01b_biting.png"):
				main.get_tree().quit(1)
				return
		if bites == 2 and apple_a >= 0 and sim.fed[apple_a] >= 95.0:
			if frames <= 1:
				frames = 2
			frames += 1
			if frames < 22:
				return
			apple_phase = 2
			frames = 0
			apple_wait = 0
			# prepare B to eat remaining bites
			if apple_b >= 0:
				sim.fed[apple_b] = 15.0
				sim.hungry_t[apple_b] = 6.0
				sim.amused[apple_b] = 90.0
				sim.clean[apple_b] = 90.0
				# bring B close so it reaches the apple reliably
				if not apple.is_empty():
					sim.pos_x[apple_b] = float(apple.x) + 18.0
					sim.pos_y[apple_b] = float(apple.y) + 4.0
			if not save_shot(main.get_viewport(), "res://shots/apple_bites_02_after_first.png"):
				main.get_tree().quit(1)
				return
			return
		if apple_wait > 1200:
			print("SHOT APPLE TIMEOUT phase1 bites=%s fedA=%s" % [bites, sim.fed[apple_a] if apple_a >= 0 else -1])
			save_shot(main.get_viewport(), "res://shots/apple_bites_timeout_1.png")
			main.get_tree().quit(1)
			return
		return

	if apple_phase == 2:
		# B eats second bite
		apple_wait += 1
		var apple := _apple_item()
		var bites := int(apple.get("bites_left", 3)) if not apple.is_empty() else -1
		if bites == 1:
			frames += 1
			if frames < 20:
				return
			apple_phase = 3
			frames = 0
			apple_wait = 0
			# B is full after second bite; make B hungry again so it can finish the apple
			if apple_b >= 0:
				sim.fed[apple_b] = 15.0
				sim.hungry_t[apple_b] = 6.0
				sim.amused[apple_b] = 90.0
				sim.clean[apple_b] = 90.0
				sim.mito_charge[apple_b] = 0.0
				if not apple.is_empty():
					sim.pos_x[apple_b] = float(apple.x) + 14.0
					sim.pos_y[apple_b] = float(apple.y) + 2.0
			if not save_shot(main.get_viewport(), "res://shots/apple_bites_03_after_second.png"):
				main.get_tree().quit(1)
				return
			return
		if apple_wait > 1200:
			print("SHOT APPLE TIMEOUT phase2 bites=%s fedB=%s" % [bites, sim.fed[apple_b] if apple_b >= 0 else -1])
			save_shot(main.get_viewport(), "res://shots/apple_bites_timeout_2.png")
			main.get_tree().quit(1)
			return
		return

	if apple_phase == 3:
		# B eats third bite, apple should be gone
		apple_wait += 1
		var apple := _apple_item()
		var gone := apple.is_empty()
		if gone:
			frames += 1
			if frames < 20:
				return
			if not save_shot(main.get_viewport(), "res://shots/apple_bites_04_finished.png"):
				main.get_tree().quit(1)
				return
			done = true
			print("SHOT APPLE DONE")
			main.get_tree().quit(0)
			return
		if apple_wait > 1200:
			print("SHOT APPLE TIMEOUT phase3 gone=%s" % gone)
			save_shot(main.get_viewport(), "res://shots/apple_bites_timeout_3.png")
			main.get_tree().quit(1)
			return
		return

## Renders a Viewport to PNG under res://shots.
func save_shot(source: Viewport, path: String) -> bool:
	var image := source.get_texture().get_image()
	if image == null or image.get_width() < 2:
		print("SHOT FAIL no image %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var err := image.save_png(path)
	print("SHOT %s path=%s size=%sx%s" % ["OK" if err == OK else "FAIL", path, image.get_width(), image.get_height()])
	return err == OK


## Captures anim review board and per-strip copies.
func _tick_shot_anims() -> void:
	if board == null:
		if main.ui != null:
			main.ui.visible = false
		build_anim_review_shot()
		frames = 0
		return
	frames += 1
	if frames < 10:
		return
	if not save_shot(board, "res://shots/anim_review.png"):
		main.get_tree().quit(1)
		return
	# Also dump each situation as its own strip sheet for closer inspection.
	if not _save_anim_strip_shots():
		main.get_tree().quit(1)
		return
	done = true
	print("SHOT ANIMS DONE")
	main.get_tree().quit(0)


## Hides kit and gaze UI for building goo captures.
func _bld_goo_hide_ui() -> void:
	if main.ui != null:
		main.ui.visible = false
	main.kit_open = false
	main.kit_toolbar.set_kit_shown(false)
	if "kit_panel" in main and main.kit_panel != null:
		main.kit_panel.visible = false
	if "task_panel" in main and main.task_panel != null:
		main.task_panel.visible = false
	if main.gaze_panel != null:
		main.gaze_panel.visible = false
	main.prefs.crt_on = false
	main.prefs.apply_crt()


## Frames camera from shot_span around shot_focus.
func _bld_goo_frame_camera() -> void:
	var view := main.get_viewport_rect().size
	var reach: float = float(sim.shot_span)
	var half_w := reach * sqrt(2.0)
	var half_h := reach * 0.70710678
	var zoom := minf(view.x / (half_w * 2.0 + 64.0), view.y / (half_h * 2.0 + 96.0))
	main.cam_rig.set_zoom(clampf(zoom, 1.2, 3.5))
	main.camera.position = main.cam_rig.to_iso(sim.shot_focus)


## Validates idle/active/goo sprites before goo PNG.
func _bld_goo_assert_overlays(row: Dictionary, name: String) -> bool:
	var idle: Dictionary = row.idle
	var active: Dictionary = row.active
	var goo: Dictionary = row.goo
	if idle.is_empty() or active.is_empty() or goo.is_empty():
		print("SHOT BLD GOO FAIL %s missing building" % name)
		return false
	if sim.building_sim.building_is_polluted(idle):
		print("SHOT BLD GOO FAIL %s idle polluted" % name)
		return false
	if sim.building_sim.building_is_polluted(active):
		print("SHOT BLD GOO FAIL %s active polluted" % name)
		return false
	if not sim.building_sim.building_is_polluted(goo):
		print("SHOT BLD GOO FAIL %s goo not polluted" % name)
		return false
	var kind := int(idle.kind)
	if main.structure_tex.active_structure_texture(kind) == null:
		print("SHOT BLD GOO FAIL %s missing active tex" % name)
		return false
	if main.structure_tex.goo_structure_texture(kind) == null:
		print("SHOT BLD GOO FAIL %s missing goo tex" % name)
		return false
	var show_on := false
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or kind == Catalog.BLD_THEATRE:
		show_on = int(sim.building_sim._live_guests(active)) > 0
	else:
		show_on = bool(active.get("active", false))
	if not show_on:
		print("SHOT BLD GOO FAIL %s active not lit" % name)
		return false
	var idle_id := int(idle.id)
	var active_id := int(active.id)
	var goo_id := int(goo.id)
	var idle_node: Sprite2D = main._building_active_sprites.get(idle_id)
	var active_node: Sprite2D = main._building_active_sprites.get(active_id)
	var goo_node: Sprite2D = main._building_active_sprites.get(goo_id)
	if idle_node == null or not idle_node.visible:
		print("SHOT BLD GOO FAIL %s idle sprite missing" % name)
		return false
	if active_node == null or not active_node.visible:
		print("SHOT BLD GOO FAIL %s active sprite missing" % name)
		return false
	if goo_node == null or not goo_node.visible:
		print("SHOT BLD GOO FAIL %s goo sprite missing" % name)
		return false
	if idle_node.texture != main.structure_tex.idle_structure_texture(kind):
		print("SHOT BLD GOO FAIL %s idle tex mismatch" % name)
		return false
	if active_node.texture != main.structure_tex.active_structure_texture(kind):
		print("SHOT BLD GOO FAIL %s active tex mismatch" % name)
		return false
	if goo_node.texture != main.structure_tex.goo_structure_texture(kind):
		print("SHOT BLD GOO FAIL %s goo tex mismatch" % name)
		return false
	var scale_tol := 0.001
	var want_scale := Catalog.building_sprite_scale(kind)
	for pair in [[idle_node, "idle"], [active_node, "active"], [goo_node, "goo"]]:
		var node: Sprite2D = pair[0]
		if absf(node.scale.x - want_scale) > scale_tol:
			print("SHOT BLD GOO FAIL %s %s scale=%.3f" % [name, str(pair[1]), node.scale.x])
			return false
	print("SHOT BLD GOO OK %s idle/active/goo sprites+scale" % name)
	return true


## Captures per-kind goo rows and mop logic sweep.
func _tick_shot_bld_goo() -> void:
	# Per kind: idle | active | goo row shot, then mop before/after + logic sweep.
	_bld_goo_hide_ui()
	var kinds: Array = sim.harness._shot_bld_goo_kinds()
	if bld_goo_phase == 0:
		if bld_goo_i >= kinds.size():
			bld_goo_phase = 1
			frames = 0
			# Prep mop scene on dwell.
			var dwell_kind := Catalog.BLD_DWELL
			sim.harness._clear_shot_props()
			var at: Vector2 = sim.harness._shot_force_pad(dwell_kind, 256.0, 256.0)
			var b: Dictionary = sim.world_entities._add_building(dwell_kind, at.x, at.y)
			if b.is_empty():
				print("SHOT BLD GOO FAIL mop place dwell")
				main.get_tree().quit(1)
				return
			sim.harness._shot_paint_building_goo(b)
			bld_goo_mop_id = int(b.id)
			sim.shot_focus = Vector2(float(b.x), float(b.y))
			sim.shot_span = 90.0
			sim.view_rect = Rect2(sim.shot_focus.x - sim.shot_span, sim.shot_focus.y - sim.shot_span, sim.shot_span * 2.0, sim.shot_span * 2.0)
			sim.smoke_hold = true
			sim.spatial._rebuild_hash()
			print("SHOT BLD GOO MOP PREP id=%s polluted=%s" % [bld_goo_mop_id, sim.building_sim.building_is_polluted(b)])
			return
		var spec: Dictionary = kinds[bld_goo_i]
		if frames == 0:
			var row: Dictionary = sim.harness._shot_place_bld_row(int(spec.kind))
			if row.has("error"):
				print("SHOT BLD GOO FAIL %s" % str(row.error))
				main.get_tree().quit(1)
				return
			main.set_meta("shot_bld_row", row)
		_bld_goo_frame_camera()
		frames += 1
		if frames < 10:
			return
		RenderingServer.force_draw()
		var row_now: Dictionary = main.get_meta("shot_bld_row", {})
		if not _bld_goo_assert_overlays(row_now, str(spec.name)):
			main.get_tree().quit(1)
			return
		var path := "res://shots/bld_%s_idle_active_goo.png" % str(spec.name)
		if not save_shot(main.get_viewport(), path):
			main.get_tree().quit(1)
			return
		bld_goo_i += 1
		frames = 0
		return

	if bld_goo_phase == 1:
		_bld_goo_frame_camera()
		frames += 1
		if frames < 8:
			return
		var b: Dictionary = sim.building_by_id.get(bld_goo_mop_id, {})
		if b.is_empty() or not sim.building_sim.building_is_polluted(b):
			print("SHOT BLD GOO FAIL mop before not polluted")
			main.get_tree().quit(1)
			return
		RenderingServer.force_draw()
		if not save_shot(main.get_viewport(), "res://shots/bld_mop_before.png"):
			main.get_tree().quit(1)
			return
		sim.harness._shot_mop_building(b)
		sim.building_sim._tick_buildings(0.016)
		if sim.building_sim.building_is_polluted(b):
			print("SHOT BLD GOO FAIL mop left dwell polluted")
			main.get_tree().quit(1)
			return
		bld_goo_phase = 2
		frames = 0
		print("SHOT BLD GOO MOP dwell cleaned")
		return

	if bld_goo_phase == 2:
		_bld_goo_frame_camera()
		frames += 1
		if frames < 8:
			return
		RenderingServer.force_draw()
		if not save_shot(main.get_viewport(), "res://shots/bld_mop_after.png"):
			main.get_tree().quit(1)
			return
		# Logic sweep: every goo-capable kind pollutes then cleans under mop.
		for spec in kinds:
			var kind := int(spec.kind)
			sim.harness._clear_shot_props()
			var at: Vector2 = sim.harness._shot_force_pad(kind, 256.0, 256.0)
			var b2: Dictionary = sim.world_entities._add_building(kind, at.x, at.y)
			if b2.is_empty():
				print("SHOT BLD GOO FAIL mop-loop place %s" % str(spec.name))
				main.get_tree().quit(1)
				return
			sim.harness._shot_paint_building_goo(b2)
			if not sim.building_sim.building_is_polluted(b2):
				print("SHOT BLD GOO FAIL mop-loop %s not polluted" % str(spec.name))
				main.get_tree().quit(1)
				return
			sim.harness._shot_mop_building(b2)
			sim.building_sim._tick_buildings(0.016)
			if sim.building_sim.building_is_polluted(b2):
				print("SHOT BLD GOO FAIL mop-loop %s still polluted" % str(spec.name))
				main.get_tree().quit(1)
				return
			print("SHOT BLD GOO MOP OK %s" % str(spec.name))
		done = true
		print("SHOT BLD GOO DONE")
		main.get_tree().quit(0)
		return


## Captures neglect vs splash blood layouts.
func _tick_shot_blood() -> void:
	# Left: neglect corpse (no blood). Mid: living. Right: splash-kill + blood pool.
	if blood_phase == 0 and frames == 0:
		if main.ui != null:
			main.ui.visible = false
		main.kit_open = false
		main.kit_toolbar.set_kit_shown(false)
		if main.task_panel != null:
			main.task_panel.visible = false
		main.prefs.crt_on = false
		main.prefs.apply_crt()
		main.cam_rig.set_zoom(3.0)
		main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
	frames += 1
	if blood_phase == 0:
		if frames < 8:
			return
		var blood_n := 0
		var dead_n := 0
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_DEAD:
				dead_n += 1
				if i < sim.bloody.size() and int(sim.bloody[i]) != 0:
					blood_n += 1
		if dead_n < 2 or blood_n != 1:
			print("SHOT BLOOD FAIL dead=%d bloody=%d expected dead>=2 bloody=1" % [dead_n, blood_n])
			main.get_tree().quit(1)
			return
		RenderingServer.force_draw()
		if not save_shot(main.get_viewport(), "res://shots/corpse_blood.png"):
			main.get_tree().quit(1)
			return
		main.cam_rig.set_zoom(5.0)
		main.camera.position = main.cam_rig.to_iso(sim.shot_focus + Vector2(48.0, 0.0))
		blood_phase = 1
		frames = 0
		return
	if frames < 4:
		return
	RenderingServer.force_draw()
	if not save_shot(main.get_viewport(), "res://shots/corpse_blood_close.png"):
		main.get_tree().quit(1)
		return
	done = true
	print("SHOT BLOOD DONE")
	main.get_tree().quit(0)


## Simulates sponge scrub and saves wash comparison.
func _tick_shot_wash() -> void:
	# Left: bubbles from live scrub path (small strokes). Right: CLEAN + Happy.
	if frames == 0:
		if main.ui != null:
			main.ui.visible = false
		main.kit_open = false
		main.kit_toolbar.set_kit_shown(false)
		if main.task_panel != null:
			main.task_panel.visible = false
		main.prefs.crt_on = false
		main.prefs.apply_crt()
		main.tool = Catalog.TOOL_SPONGE
		main.cam_rig.set_zoom(3.0)
		main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
		print("SHOT WASH SCALE sponge_suds=%.2f sparkle=%.2f stroke_min=%.2f" % [
			float(EffectTune.get_tune("act:sponge").get("scale", 0.0)),
			float(EffectTune.get_tune("act:wash_sparkle").get("scale", 0.0)),
			ThrongletSimServer.SCRUB_STROKE_MIN,
		])
	frames += 1
	main.sponge_tracking = true
	# Simulate gentle rub (was failing when stroke_min was 2.0).
	var scrub_at = Vector2(sim.shot_focus.x - 36.0 + sin(float(frames) * 0.9) * 3.0, sim.shot_focus.y)
	var stroke := 0.0 if frames <= 1 else scrub_at.distance_to(main.sponge_last)
	main.sponge_last = scrub_at
	sim.player_tools.scrub(scrub_at.x, scrub_at.y, stroke, stroke >= ThrongletSimServer.SCRUB_STROKE_MIN)
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		if float(sim.cheer_t[i]) > 0.0:
			sim.cheer_t[i] = maxf(float(sim.cheer_t[i]), 0.55)
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0
	for pop in sim.pops:
		if str(pop.get("kind", "")) == "wash":
			pop.t = maxf(float(pop.t), 0.55)
			pop.life = ThrongletSimServer.WASH_FX_LIFE
			pop.lift = 6.0
	var wash_act := 0
	for i in sim.slot_count:
		if int(sim.act[i]) == ThrongletSimServer.ACT_WASH:
			wash_act += 1
	# Prove suds persist across many scrub frames (was 1-frame flicker).
	if frames == 8:
		print("SHOT WASH MID act_wash=%d sponge_hold=%.2f" % [wash_act, sim.sponge_hold])
	if frames < 28:
		return
	RenderingServer.force_draw()
	if not save_shot(main.get_viewport(), "res://shots/wash_scrub_vs_sparkle.png"):
		main.get_tree().quit(1)
		return
	done = true
	print("SHOT WASH DONE act_wash=%d sponge_id=%d hold=%.2f suds_scale=%.2f" % [
		wash_act,
		sim.sponge_id,
		sim.sponge_hold,
		float(EffectTune.get_tune("act:sponge").get("scale", 0.0)),
	])
	main.get_tree().quit(0)


## Freezes kick/happy walk and validates ball scale shot.
func _tick_shot_ball() -> void:
	# Live world: Default | Happy_Walk+ball | kick Happy+ball pop — scales must match.
	if frames == 0:
		if main.ui != null:
			main.ui.visible = false
		main.kit_open = false
		main.kit_toolbar.set_kit_shown(false)
		if main.task_panel != null:
			main.task_panel.visible = false
		main.prefs.crt_on = false
		main.prefs.apply_crt()
		main.cam_rig.set_zoom(3.0)
		main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
		var hw := ThrongClips.frame_at("ThrongA_Happy_Walk", 0)
		var df := ThrongClips.frame_at("ThrongA_Default", 0)
		print("SHOT BALL SCALE Default=%.2f Happy_Walk=%.2f pop_ball=%.2f" % [
			main.anim_frames.throng_sprite_scale(df),
			main.anim_frames.throng_sprite_scale(hw),
			Catalog.BALL_SPRITE_SCALE,
		])
	frames += 1
	# Keep pop alive across the capture window.
	for pop in sim.pops:
		pop.t = 0.55
		pop.lift = 8.0
	if frames < 10:
		return
	# Freeze walkers mid-step so Happy_Walk stays selected.
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01:
			sim.dir_x[i] = 1.0
			sim.dir_y[i] = 0.0
			sim.act[i] = ThrongletSimServer.ACT_PLAY
			sim.act_t[i] = 0.55
	RenderingServer.force_draw()
	if not save_shot(main.get_viewport(), "res://shots/ball_kick_scale.png"):
		main.get_tree().quit(1)
		return
	var hw2: int = ThrongClips.frame_at("ThrongA_Happy_Walk", 0)
	var sc: float = float(main.anim_frames.throng_sprite_scale(hw2))
	if absf(sc - 0.4) > 0.01:
		print("SHOT BALL FAIL Happy_Walk scale=%.3f expected 0.4" % sc)
		main.get_tree().quit(1)
		return
	done = true
	print("SHOT BALL DONE Happy_Walk_scale=%.2f" % sc)
	main.get_tree().quit(0)


## Captures dirt shader parity on walk vs held board.
func _tick_shot_dirt() -> void:
	# Screen-space board through the real thronglet shader (no headless SubViewport).
	if frames == 0:
		if main.ui != null:
			main.ui.visible = false
		main.kit_open = false
		main.kit_toolbar.set_kit_shown(false)
		if main.task_panel != null:
			main.task_panel.visible = false
		main.prefs.crt_on = false
		main.prefs.apply_crt()
		# Hide island thronglets — board owns the proof sprites.
		sim.held_kind = ""
		sim.held_ref = -1
		for i in sim.slot_count:
			if sim.state[i] == Catalog.ST_LIVING:
				sim.state[i] = Catalog.ST_VACANT
		main.cam_rig.set_zoom(2.0)
		main.camera.position = main.cam_rig.to_iso(sim.shot_focus)
		_build_dirt_screen_board()
	frames += 1
	if frames < 8:
		return
	var far: bool = main.cam_rig.zoom_level < 2.5
	print("SHOT DIRT PROBE zoom=%.2f far=%s board=%s" % [
		main.cam_rig.zoom_level, str(far), str(board != null),
	])
	RenderingServer.force_draw()
	if not save_shot(main.get_viewport(), "res://shots/dirt_walk_vs_held.png"):
		main.get_tree().quit(1)
		return
	done = true
	print("SHOT DIRT DONE zoom=%.2f far=%s" % [main.cam_rig.zoom_level, str(far)])
	main.get_tree().quit(0)


## Builds screen-space dirt comparison multimesh.
func _build_dirt_screen_board() -> void:
	var samples: Array = [
		["clean Default", "ThrongA_Default", 0, 0.0],
		["dirty Default", "ThrongA_Default", 0, 1.0],
		["dirty Walk0", "Throng_Walk_Anim_Spritesheet", 0, 1.0],
		["dirty Walk2", "Throng_Walk_Anim_Spritesheet", 2, 1.0],
		["dirty Homed", "Throng_Walk_Homed_Spritesheet", 2, 1.0],
		["held=Default", "ThrongA_Default", 0, 1.0],
	]
	var layer := CanvasLayer.new()
	layer.layer = 80
	main.add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.36, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var title := Label.new()
	title.text = "Dirt @ zoom 2.0 far_view — Walk/Homed must match held Default"
	title.position = Vector2(16, 10)
	title.size = Vector2(900, 24)
	root.add_child(title)
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = main.world_drawer.cell_tex(ThrongClips.frame_at("ThrongA_Default", 0))
	sheet.material = main.world.material
	sheet.multimesh = main.world_boot.mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
	sheet.z_index = 1
	root.add_child(sheet)
	board = sheet
	var scale := 1.15
	var draws: Array = []
	var cols := 3
	for i in samples.size():
		var sample: Array = samples[i]
		var clip := str(sample[1])
		if not ThrongClips.has_clip(clip):
			print("SHOT DIRT SKIP missing %s" % clip)
			continue
		var col := i % cols
		var row := int(i / cols)
		var center := Vector2(140.0 + float(col) * 200.0, 120.0 + float(row) * 160.0)
		var frame := ThrongClips.frame_at(clip, int(sample[2]))
		draws.append({
			"p": center + Vector2(0.0, WorldBootstrap.WORLD_CELL * 0.5 * scale),
			"icon": frame,
			"tint": Color.WHITE,
			"scale": scale,
			"dirty": float(sample[3]),
		})
		var tag := Label.new()
		tag.text = "%s  f=%d d=%.0f" % [str(sample[0]), frame, float(sample[3])]
		tag.position = center + Vector2(-70, 58)
		tag.size = Vector2(160, 18)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(tag)
	main.world_drawer.write_mesh(sheet.multimesh, draws)
	print("SHOT DIRT BOARD n=%d zoom=%.2f" % [draws.size(), main.cam_rig.zoom_level])


## Offline SubViewport dirt board for manual debug.
func build_dirt_review_shot() -> void:
	# Atlas board kept for offline debug; live --shot-dirt uses _tick_shot_dirt.
	main.cam_rig.set_zoom(2.0)
	var samples: Array = [
		["clean Default", "ThrongA_Default", 0, 0.0],
		["dirty Default", "ThrongA_Default", 0, 1.0],
		["dirty Walk0", "Throng_Walk_Anim_Spritesheet", 0, 1.0],
		["dirty Walk2", "Throng_Walk_Anim_Spritesheet", 2, 1.0],
		["dirty Homed", "Throng_Walk_Homed_Spritesheet", 2, 1.0],
		["held=Default", "ThrongA_Default", 0, 1.0],
	]
	var cols := 3
	var rows := int((samples.size() + cols - 1) / cols)
	var board_vp := SubViewport.new()
	board_vp.size = Vector2i(cols * 150 + 40, rows * 150 + 70)
	board_vp.disable_3d = true
	board_vp.transparent_bg = false
	board_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(board_vp)
	board = board_vp
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.42, 0.22)
	bg.size = Vector2(board_vp.size)
	board_vp.add_child(bg)
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = main.world_drawer.cell_tex(ThrongClips.frame_at("ThrongA_Default", 0))
	sheet.material = main.world.material
	sheet.multimesh = main.world_boot.mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
	board_vp.add_child(sheet)
	var scale := 0.9
	var draws: Array = []
	for i in samples.size():
		var sample: Array = samples[i]
		var clip := str(sample[1])
		if not ThrongClips.has_clip(clip):
			continue
		var col := i % cols
		var row := int(i / cols)
		var center := Vector2(75 + col * 150, 75 + row * 150)
		draws.append({
			"p": center + Vector2(0, WorldBootstrap.WORLD_CELL * 0.5 * scale),
			"icon": ThrongClips.frame_at(clip, int(sample[2])),
			"tint": Color.WHITE,
			"scale": scale,
			"dirty": float(sample[3]),
		})
	main.world_drawer.write_mesh(sheet.multimesh, draws)


## Clip matrix used for anim review and strip dumps.
func _anim_review_samples() -> Array:
	return [
		["1 idle", "ThrongA_Default", 0, 0.0],
		["1 happy", "ThrongA_Happy", 2, 0.0],
		["1 blink", "ThrongA_Default Blink", 0, 0.0],
		["1 antenna", "Throng_Idle_AntennaSpin_Spritesheet", 2, 0.0],
		["2 bored", "ThrongA_Bored_KickRock", 6, 0.0],
		["2 puppy", "ThrongA_PuppyDogEyes", 2, 0.0],
		["2 grumpy", "Throng_Grumpy_Sheet", 1, 0.0],
		["2 sad", "ThrongA_Sad", 3, 0.0],
		["3 freak", "ThrongA_FreakOut", 4, 0.0],
		["3 panic", "ThrongA_PanicRun", 1, 0.0],
		["3 fire", "ThrongA_PanicRunFire", 1, 0.0],
		["4 talk", "ThrongA_Talk", 2, 0.0],
		["4 blink", "ThrongA_Talk_Blink_Spritesheet", 2, 0.0],
		["4 react", "ThrongA_LooktAtPlayerHappyNod_Spritesheet", 4, 0.0],
		["4 awe", "ThrongA_InAwe", 2, 0.0],
		["4b poss", "ThrongA_Possessed_AntennaSpin_Spritesheet", 2, 0.0],
		["5 sing", "Throng_Sing_Spritesheet", 2, 0.0],
		["5 peer", "ThrongA_TalkToOtherThronglet_Spritesheet2", 1, 0.0],
		["6 celeb0", "ThrongA_Celebrate_Spritesheet", 0, 0.0],
		["6 celeb5", "ThrongA_Celebrate_Spritesheet", 5, 0.0],
		["7 reactK", "ThrongA_ReactToKill", 2, 0.0],
		["8 homed", "Throng_Walk_Homed_Spritesheet", 2, 0.0],
		["8 happyW", "ThrongA_Happy_Walk", 0, 0.0],
		["8 sadW", "ThrongA_Sad_Walk", 0, 0.0],
		["8 haul", "ThrongA_LiftPropWalk", 0, 0.0],
		["8 lift", "ThrongA_LiftProp", 3, 0.0],
		["9 sleep", "Throng_Idle_AntennaSpin_EyesClosed_Spritesheet", 1, 0.0],
		["dirty", "ThrongA_Default", 0, 1.0],
	]


## Builds labeled SubViewport for thronglet_sheet.
func build_anim_review_shot() -> void:
	var samples: Array = _anim_review_samples()
	var cols := 7
	var rows := int((samples.size() + cols - 1) / cols)
	var board_vp := SubViewport.new()
	board_vp.size = Vector2i(cols * 140 + 40, rows * 130 + 60)
	board_vp.disable_3d = true
	board_vp.transparent_bg = false
	board_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(board_vp)
	board = board_vp
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16)
	bg.size = Vector2(board_vp.size)
	board_vp.add_child(bg)
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = main.world_drawer.cell_tex(ThrongClips.frame_at("ThrongA_Default", 0))
	sheet.material = main.world.material
	sheet.multimesh = main.world_boot.mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
	board_vp.add_child(sheet)
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
		theme.default_font_size = 14
	root.theme = theme
	var title := Label.new()
	title.text = "Thronglet anim review (#37) — check atlas cells"
	title.position = Vector2(16, 8)
	title.size = Vector2(board_vp.size.x - 32, 24)
	root.add_child(title)
	var scale := 0.85
	var draws: Array = []
	for i in samples.size():
		var sample: Array = samples[i]
		var clip := str(sample[1])
		if not ThrongClips.has_clip(clip):
			print("SHOT ANIMS SKIP missing %s" % clip)
			continue
		var col := i % cols
		var row := int(i / cols)
		var center := Vector2(70 + col * 140, 70 + row * 130)
		var frame := ThrongClips.frame_at(clip, int(sample[2]))
		draws.append({
			"p": center + Vector2(0, WorldBootstrap.WORLD_CELL * 0.5 * scale),
			"icon": frame,
			"tint": Color.WHITE,
			"scale": scale,
			"dirty": float(sample[3]),
		})
		var tag := Label.new()
		tag.text = str(sample[0])
		tag.position = center + Vector2(-56, 40)
		tag.size = Vector2(112, 16)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(tag)
	main.world_drawer.write_mesh(sheet.multimesh, draws)


## Copies raw atlas strips into shots/ for inspection.
func _save_anim_strip_shots() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var wanted := [
		["anim_idle.png", "ThrongA_Default"],
		["anim_bored.png", "ThrongA_Bored_KickRock"],
		["anim_puppy.png", "ThrongA_PuppyDogEyes"],
		["anim_freak.png", "ThrongA_FreakOut"],
		["anim_panic.png", "ThrongA_PanicRun"],
		["anim_panic_fire.png", "ThrongA_PanicRunFire"],
		["anim_talk.png", "ThrongA_Talk"],
		["anim_possessed.png", "ThrongA_Possessed_AntennaSpin_Spritesheet"],
		["anim_sing.png", "Throng_Sing_Spritesheet"],
		["anim_peer_talk.png", "ThrongA_TalkToOtherThronglet_Spritesheet2"],
		["anim_celebrate.png", "ThrongA_Celebrate_Spritesheet"],
		["anim_react_kill.png", "ThrongA_ReactToKill"],
		["anim_walk_homed.png", "Throng_Walk_Homed_Spritesheet"],
		["anim_happy_walk.png", "ThrongA_Happy_Walk"],
		["anim_sad_walk.png", "ThrongA_Sad_Walk"],
		["anim_haul.png", "ThrongA_LiftPropWalk"],
		["anim_lift.png", "ThrongA_LiftProp"],
		["anim_sleep.png", "Throng_Idle_AntennaSpin_EyesClosed_Spritesheet"],
		["anim_inawe.png", "ThrongA_InAwe"],
	]
	for row in wanted:
		var path := "res://shots/%s" % str(row[0])
		var clip := str(row[1])
		var strip_path := ThrongClips.strip_path(clip)
		var abs_src := ProjectSettings.globalize_path(strip_path)
		if not FileAccess.file_exists(strip_path) and not FileAccess.file_exists(abs_src):
			print("SHOT FAIL missing strip %s" % strip_path)
			return false
		var abs_dst := ProjectSettings.globalize_path(path)
		var err := DirAccess.copy_absolute(abs_src, abs_dst)
		print("SHOT %s path=%s" % ["OK" if err == OK else "FAIL", path])
		if err != OK:
			return false
	return true


## Builds thronglet and FX atlas montage for asset sheet.
func build_asset_shot() -> void:
	var board_vp := SubViewport.new()
	board_vp.size = Vector2i(960, 980)
	board_vp.disable_3d = true
	board_vp.transparent_bg = false
	board_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(board_vp)
	board = board_vp
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = main.world_drawer.cell_tex(ThrongClips.frame_at("ThrongA_Default", 0))
	sheet.material = main.world.material
	sheet.multimesh = main.world_boot.mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
	board_vp.add_child(sheet)
	var samples: Array = [
		["idle", ThrongClips.frame_at("ThrongA_Default", 0), 0.0],
		["talk", ThrongClips.frame_at("ThrongA_Talk", 2), 0.0],
		["dead", ThrongClips.frame_at("ThrongA_Dead_001", 0), 0.0],
		["bones", ThrongClips.frame_at("ThrongA_Bones", 0), 0.0],
		["sing", ThrongClips.frame_at("Throng_Sing_Spritesheet", 2), 0.0],
		["kick", ThrongClips.frame_at("ThrongA_Bored_KickRock", 6), 0.0],
		["freak", ThrongClips.frame_at("ThrongA_FreakOut", 4), 0.0],
		["panic", ThrongClips.frame_at("ThrongA_PanicRun", 1), 0.0],
		["react", ThrongClips.frame_at("ThrongA_ReactToKill", 2), 0.0],
		["possessed", ThrongClips.frame_at("ThrongA_Possessed_AntennaSpin_Spritesheet", 2), 0.0],
		["sleep", ThrongClips.frame_at("Throng_Idle_AntennaSpin_EyesClosed_Spritesheet", 1), 0.0],
		["homed", ThrongClips.frame_at("Throng_Walk_Homed_Spritesheet", 2), 0.0],
		["haul", ThrongClips.frame_at("ThrongA_LiftPropWalk", 0), 0.0],
		["happyW", ThrongClips.frame_at("ThrongA_Happy_Walk", 0), 0.0],
		["sadW", ThrongClips.frame_at("ThrongA_Sad_Walk", 0), 0.0],
		["puppy", ThrongClips.frame_at("ThrongA_PuppyDogEyes", 2), 0.0],
		["inawe", ThrongClips.frame_at("ThrongA_InAwe", 2), 0.0],
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
			"p": center + Vector2(0, WorldBootstrap.WORLD_CELL * 0.5 * scale),
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
	main.world_drawer.write_mesh(sheet.multimesh, draws)
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
		face.texture = main.ui_assets.tex(main.ui_assets.POP_FACES[faces[i]])
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2(660 + (i % 3) * 96, 820 + int(i / 3) * 70)
		face.size = Vector2(88, 64)
		root.add_child(face)
