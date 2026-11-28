extends Node2D

# Layout bench. Places every prop and edits footprint, reach, scale, offset, z, and rotation live.

## Minimum grid coordinate for valid prop placement cells.
const PAD_MIN := -8
## Maximum grid coordinate for valid prop placement cells.
const PAD_MAX := 40
## Synthetic palette id for the thronglet preview instance.
const THRONG_ID := "throng:0"
## Anim clip name that uses tub partner offsets in prop mode.
const BATH_CLIP := "Throng_FallInBath_Spritesheet"
## Roundabout body clip used when painting structure anims.
const RIDE_CLIP := "ThrongA_Roundabout_SpriteSheet"
## World scale multiplier when staging effect previews.
const EFFECT_PREVIEW_SCALE := 8.0
## Per-clip throng scale/offset/rotation persistence for anim review.
const ThrongTune := preload("res://scripts/data/tune/throng_tune.gd")
## Per-clip FPS and frame overrides saved from the throng anim strip.
const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")
## Carousel lab JSON schema loader for roundabout admission tuning.
const TiovivoLabTune := preload("res://scripts/data/tune/tiovivo_lab_tune.gd")
## Path mask → atlas piece lab (dev/path_lab.json).
const PathLabScript := preload("res://scripts/dev/path_lab.gd")
const WorldBootstrap := preload("res://scripts/presentation/world/world_bootstrap.gd")

## Main scene host providing camera, world drawer, and dev entry.
var main = null
## Left scrollable rail for prop palette and layout actions.
var rail: PanelContainer
## Bottom inspector bar for footprint, reach, and transform spin boxes.
var bar: PanelContainer
## VBox listing grouped prop palette buttons.
var list: VBoxContainer
## Shows armed prop id or MULTI when several uids are selected.
var name_label: Label
## Footprint edit status line in prop layout mode.
var status: Label
## Inspector spin for prop footprint width in cells.
var grid_x: SpinBox
## Inspector spin for prop footprint height in cells.
var grid_y: SpinBox
## Inspector spin for horizontal interaction reach in cells.
var reach_x: SpinBox
## Inspector spin for vertical interaction reach in cells.
var reach_y: SpinBox
## Inspector spin for prop world sprite scale.
var scale_box: SpinBox
## Inspector spin for prop sprite X offset in world units.
var off_x: SpinBox
## Inspector spin for prop sprite Y offset in world units.
var off_y: SpinBox
## Inspector spin for lit/active sprite X offset.
var active_x: SpinBox
## Inspector spin for lit/active sprite Y offset.
var active_y: SpinBox
## Inspector spin for prop draw sort bias (z).
var z_box: SpinBox
## Inspector spin for prop rotation in degrees.
var rot_box: SpinBox
## Returns to normal play from layout mode.
var quit_button: Button
## Toggles lit building preview for supported structure kinds.
var active_button: Button
## Palette prop id to toggle Button map.
var buttons := {}
## Currently armed prop kind id for placement and inspector.
var armed := ""
## Prop id being dragged from palette before drop.
var drag_id := ""
## Uid of placed instance being repositioned, or -1.
var move_uid := -1
## Grid delta from grab cell to instance origin while moving.
var move_grab := Vector2i.ZERO
## Spawned bench instances with uid, id, and world at.
var placed: Array = []
## Uid list for multi-select footprint editing.
var selected_uids: Array = []
## Monotonic uid issued to the next placed instance.
var next_uid := 1
## Uid to pooled Node2D used for structure or throng draws.
var nodes := {}
## Uid set marking pooled nodes claimed during the current paint pass.
var _node_used := {}
## Guard suppressing cfg write-back while UI is being populated.
var _fill := false
## Whether lit structure sprites are shown in prop mode.
var show_active := false
## True when anim review UI is active instead of props.
var throng_mode := false
## True when isolated effect preview UI is active.
var effect_mode := false
## True when carousel tiovivo lab UI is active.
var lab_mode := false
## Path piece lab (mask gallery + sprite picker).
var path_lab = null
## Reserved uid for the staged effect thronglet instance.
const EFFECT_ACTIVE_UID := -2
## Left rail for clip list and anim tuning in throng mode.
var throng_rail: PanelContainer
## Bottom bar with FPS, mirror, and play controls for clips.
var throng_bar: PanelContainer
## Left rail listing aura/act effect ids to preview.
var effect_rail: PanelContainer
## Bottom bar with effect metrics and replay controls.
var effect_bar: PanelContainer
## Left rail of carousel/spawn/sync tuning controls.
var lab_rail: PanelContainer
## Bottom lab action bar with pause, step, and save.
var lab_bar: PanelContainer
## Title label on the carousel lab bar.
var lab_name: Label
## Right-aligned lab status and admit metrics label.
var lab_status: Label
## Maps lab cfg group:key to SpinBox, OptionButton, or CheckBox.
var lab_spins := {}
## In-memory tiovivo lab tune dictionary mirrored to JSON.
var lab_cfg := {}
## Synthetic thronglet dicts used only in carousel lab simulation.
var lab_agents: Array = []
## Roundabout state dict: spin, slots, riders, center offset.
var lab_carousel := {}
## Whether lab simulation advances each tick.
var lab_running := true
## Accumulated lab simulation time in seconds.
var lab_sim_t := 0.0
## Time since last agent was admitted to the carousel.
var lab_admit_t := 0.0
## Agents admitted in the current wave when in wave mode.
var lab_wave_count := 0
## Countdown between waves in wave sync mode.
var lab_wave_pause_t := 0.0
## Next synthetic agent id for lab spawns.
var lab_next_id := 1
## Wall ms of last lab tick for step timing display.
var lab_last_ms := 0
## Selected lab agent id for delete/drag, or -1.
var lab_selected_agent := -1
## Agent id being dragged in lab view, or -1.
var lab_drag_agent := -1
## Whether the carousel center is being dragged.
var lab_drag_carousel := false
## Recent lab admit/status strings for the status line.
var lab_messages: Array = []

## VBox of effect id toggle buttons.
var effect_list: VBoxContainer
## Effect id to palette Button in effect mode.
var effect_buttons := {}
## Armed effect tune id (e.g. aura:flower).
var effect_id := ""
## Label showing human title of the armed effect.
var effect_name: Label
## Effect mode status and save outcome line.
var effect_status: Label
## Live metric readout for staged effect preview.
var effect_live: Label
## HBox of need and timing labels beside effect preview.
var effect_metrics: HBoxContainer
## HBox of clip and FX option rows for the effect.
var effect_look: HBoxContainer
## Numeric effect tune fields bound to SpinBoxes.
var effect_spins := {}
## OptionButton picking throng body clip during effect preview.
var effect_clip_box: OptionButton
## OptionButton picking overlay FX clip for the effect.
var effect_fx_box: OptionButton
## Toggles effect timeline play/pause.
var effect_play_button: Button
## Whether effect preview time is advancing.
var effect_playing := true
## Staged throng hunger need for effect gauge display.
var effect_fed := 50.0
## Staged throng fun need for effect gauge display.
var effect_fun := 50.0
## Staged throng clean need for effect gauge display.
var effect_clean := 50.0
## Elapsed seconds within the looping effect preview.
var effect_t := 0.0
## Short impulse timer for replay and ring flash.
var effect_pulse := 0.0
## Body clip name used when painting the effect thronglet.
var effect_clip := "ThrongA_Default"
## Line2D showing effect radius in world space.
var effect_ring: Line2D
## Need-bar overlay control beside the staged throng.
var effect_gauge: Control
## ColorRect fills for fed/fun/clean on the gauge.
var effect_gauge_fills: Array = []
## Labels beside each need segment on the gauge.
var effect_gauge_labels: Array = []
## Scrollable clip name buttons for anim mode.
var clip_list: VBoxContainer
## Text filter narrowing visible clip palette entries.
var clip_filter: LineEdit
## Clip name to toggle Button in anim review.
var clip_buttons := {}
## Primary armed animation clip for editing and preview.
var clip_name := ""
## Multi-selected clip names for batch anim edits.
var selected_clips: Array = []
## Multi-selected frame indexes on the current clip strip.
var selected_frames: Array = []
## Ordered clip names driving multi-clip preview playback.
var clip_order: Array = []
## Shift-range anchor clip name for multi-select.
var clip_anchor := ""
## Shift-range anchor frame index on the strip.
var frame_anchor := 0
## Shift-range anchor placed uid in prop mode.
var uid_anchor := -1
## Per-frame pin buttons on the anim strip.
var frame_buttons: Array = []
## HBox container holding frame pin buttons.
var strip: HBoxContainer
## SpinBox for preview frames-per-second of armed clip.
var fps_box: SpinBox
## SpinBox for throng sprite scale in anim review.
var throng_scale: SpinBox
## SpinBox for throng sprite X offset in anim review.
var throng_x: SpinBox
## SpinBox for throng sprite Y offset in anim review.
var throng_y: SpinBox
## SpinBox for throng rotation in anim review.
var throng_rot: SpinBox
## Play/pause toggle for clip preview.
var play_button: Button
## Toggles horizontal mirror on throng preview.
var mirror_button: Button
## Toggles apply-all-edits vs single-clip edits.
var all_button: Button
## Label for armed clip title in anim mode.
var throng_name: Label
## Anim mode status including save paths.
var throng_status: Label
## Whether clip playhead is advancing in throng mode.
var playing := true
## When true, frame edits apply to every selected clip.
var apply_all := false
## Current preview frame index on the armed clip.
var frame_i := 0
## Accumulated time driving automatic frame advance.
var play_t := 0.0
## Last rotation degrees pushed to rot spin to avoid feedback.
var _rot_shown := -1
## Wall timestamp of last playhead sync.
var play_ms := 0
## Whether throng preview is mirrored on X.
var mirror := false


## Attaches to Main, creates the effect ring, and builds prop UI and gauge.
func setup(host) -> void:
	main = host
	z_index = 6
	effect_ring = Line2D.new()
	effect_ring.width = 2.4
	effect_ring.default_color = Color(1.0, 0.75, 0.15, 1.0)
	effect_ring.z_index = 12
	effect_ring.z_as_relative = false
	effect_ring.visible = false
	add_child(effect_ring)
	_build_ui()
	_build_effect_gauge()
	path_lab = PathLabScript.new()
	path_lab.setup(main, self, _theme())
	add_child(path_lab)


## Resets modes, loads saved tunes, shows prop rail, and frames the pad.
func open() -> void:
	_clear_placed()
	_paint_ground()
	main.cam_rig.set_zoom(2.0)
	main.camera.position = main.cam_rig.to_iso(Catalog.cell_world(Vector2i(8, 16)))
	PropTune.load_saved()
	ThrongTune.load_saved()
	AnimTune.load_saved()
	EffectTune.load_saved()
	lab_cfg = TiovivoLabTune.load_saved()
	_lab_reset_state(false)
	throng_mode = false
	effect_mode = false
	lab_mode = false
	if path_lab != null:
		path_lab.close()
	rail.visible = true
	bar.visible = true
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	if effect_rail:
		effect_rail.visible = false
	if effect_bar:
		effect_bar.visible = false
	if lab_rail:
		lab_rail.visible = false
	if lab_bar:
		lab_bar.visible = false
	drag_id = ""
	move_uid = -1
	selected_clips.clear()
	selected_frames.clear()
	clip_name = ""
	clip_anchor = ""
	frame_anchor = 0
	uid_anchor = -1
	effect_id = ""
	_arm("", -1)
	tick()


## Tears down placed props, frees bench UI, and hides all dev rails.
func close() -> void:
	_clear_placed()
	_hide_effect_need_bars()
	lab_agents.clear()
	lab_carousel.clear()
	if effect_gauge:
		effect_gauge.queue_free()
		effect_gauge = null
		effect_gauge_fills.clear()
		effect_gauge_labels.clear()
	if effect_ring:
		effect_ring.visible = false
		effect_ring.queue_free()
		effect_ring = null
	if rail:
		rail.visible = false
		rail.queue_free()
		rail = null
	if bar:
		bar.visible = false
		bar.queue_free()
		bar = null
	if throng_rail:
		throng_rail.visible = false
		throng_rail.queue_free()
		throng_rail = null
	if throng_bar:
		throng_bar.visible = false
		throng_bar.queue_free()
		throng_bar = null
	if effect_rail:
		effect_rail.visible = false
		effect_rail.queue_free()
		effect_rail = null
	if effect_bar:
		effect_bar.visible = false
		effect_bar.queue_free()
		effect_bar = null
	if lab_rail:
		lab_rail.visible = false
		lab_rail.queue_free()
		lab_rail = null
	if lab_bar:
		lab_bar.visible = false
		lab_bar.queue_free()
		lab_bar = null
	if path_lab != null:
		path_lab.dispose()
		path_lab.queue_free()
		path_lab = null


## Paints placed props or lab/effect previews and syncs playheads each frame.
func tick() -> void:
	if main == null:
		return
	_advance()
	if path_lab != null and path_lab.is_open():
		path_lab.tick()
		return
	if lab_mode:
		_lab_drag_update()
		_lab_tick_draw()
		queue_redraw()
		return
	var draws: Array = []
	_node_used = {}
	var throng_inst := {}
	for inst in placed:
		if effect_mode and str(inst.id) == THRONG_ID:
			throng_inst = inst
			continue
		var row := _row_for(str(inst.id))
		if row.is_empty():
			continue
		_paint_inst(draws, row, _live_at(inst), 1.0, int(inst.uid), _node_used)
	if effect_mode and not throng_inst.is_empty():
		_paint_effect_throng(draws, _live_at(throng_inst), 1.0)
	if _show_ghost():
		var ghost := _row_for(drag_id)
		if not ghost.is_empty():
			var origin := Catalog.cell_world(_cursor_cell())
			_paint_inst(draws, ghost, origin, 0.45, -1, _node_used)
	draws.sort_custom(func(a, b): return float(a.sy) < float(b.sy))
	main.world_drawer.paint_props(draws)
	_lift_nodes()
	_drop_nodes(_node_used)
	if throng_mode:
		_sync_playhead()
	if effect_mode:
		_sync_effect_live()
		_sync_effect_need_bars()
		_sync_effect_ring()
	elif effect_ring != null:
		effect_ring.visible = false
	queue_redraw()


## Routes mouse and keyboard to prop edit, anim, effect, or lab handlers.
func input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and (drag_id != "" or move_uid >= 0):
			drag_id = ""
			move_uid = -1
			_mark_buttons()
		if event.pressed and lab_mode:
			lab_drag_agent = -1
			lab_drag_carousel = false
		if not event.pressed and lab_mode:
			_lab_release_drag()
		main.cam_rig.dragging = event.pressed
		main.cam_rig.drag_from = event.position
		main.cam_rig.cam_from = main.camera.position
		main.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if path_lab != null and path_lab.is_open():
			path_lab.handle_click(event.shift_pressed)
			main.get_viewport().set_input_as_handled()
			return
		if lab_mode:
			_lab_click(event.shift_pressed)
			main.get_viewport().set_input_as_handled()
			return
		if effect_mode:
			main.get_viewport().set_input_as_handled()
			return
		_click(event.shift_pressed, event.meta_pressed)
		main.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if lab_mode:
			_lab_release_drag()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if lab_mode:
			if event.keycode == KEY_SPACE:
				var focus: Control = main.get_viewport().gui_get_focus_owner()
				if focus is LineEdit or focus is SpinBox:
					return
				_lab_toggle_run()
				main.get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE:
				if lab_selected_agent >= 0 or lab_drag_agent >= 0 or lab_drag_carousel:
					lab_selected_agent = -1
					lab_drag_agent = -1
					lab_drag_carousel = false
				else:
					main._leave_dev()
				main.get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
				_lab_remove_selected()
				main.get_viewport().set_input_as_handled()
				return
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if not effect_mode:
				_remove_selected()
			main.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and (throng_mode or effect_mode):
			var focus: Control = main.get_viewport().gui_get_focus_owner()
			if focus is LineEdit:
				return
			if effect_mode:
				_toggle_effect_play()
			else:
				_toggle_play()
			main.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if drag_id != "":
				drag_id = ""
				_mark_buttons()
			elif move_uid >= 0:
				move_uid = -1
			else:
				main._leave_dev()
			main.get_viewport().set_input_as_handled()


## Overlays grid, footprints, reach, selection marks, and placement ghost.
func _draw() -> void:
	if main == null:
		return
	if path_lab != null and path_lab.is_open():
		return
	if lab_mode:
		_lab_draw()
		return
	if effect_mode:
		return
	var poly: PackedVector2Array = main.placement_overlay.place_cell_poly()
	if poly.is_empty():
		return
	var grid := Color(1, 1, 1, 0.16)
	for cell in _view_cells():
		_stroke(cell, poly, grid, Color(0, 0, 0, 0))
	for inst in placed:
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		var origin: Vector2 = _live_at(inst)
		var on := _uid_picked(int(inst.uid))
		var moving := int(inst.uid) == move_uid
		var bad := moving and not _fits(origin, tune.footprint, int(inst.uid))
		var fill := Color(0.9, 0.25, 0.2, 0.28) if bad else Color(1.0, 0.82, 0.25, 0.28) if on else Color(0.35, 0.85, 0.5, 0.16)
		var edge := Color(1.0, 0.35, 0.3, 0.95) if bad else Color(1.0, 0.9, 0.4, 0.95) if on else Color(0.55, 1.0, 0.7, 0.75)
		for cell in _cells(origin, tune.footprint):
			_stroke(cell, poly, edge, fill)
		_stroke_reach(origin, tune, edge if on else Color(0.55, 0.9, 1.0, 0.28))
		if on:
			var mark := origin
			if throng_mode and str(inst.id) == THRONG_ID and clip_name == BATH_CLIP:
				mark += Catalog.TUB_SEAT_OFF
			_cross(mark)
	_stroke_partner(poly)
	if not _show_ghost():
		return
	var ghost_tune: Dictionary = PropTune.get_tune(drag_id)
	var ghost_at := Catalog.cell_world(_cursor_cell())
	var ghost_ok := _fits(ghost_at, ghost_tune.footprint, -1)
	var ghost_edge := Color(0.55, 0.86, 1.0, 0.95) if ghost_ok else Color(1.0, 0.35, 0.3, 0.95)
	var ghost_fill := Color(0.4, 0.7, 1.0, 0.14) if ghost_ok else Color(0.9, 0.25, 0.2, 0.2)
	for cell in _cells(ghost_at, ghost_tune.footprint):
		_stroke(cell, poly, ghost_edge, ghost_fill)
	_stroke_reach(ghost_at, ghost_tune, Color(0.55, 0.86, 1.0, 0.7))


## Handles selection, multi-select, and move grab on the placement pad.
func _click(shift: bool = false, meta: bool = false) -> void:
	if drag_id != "":
		return
	var cell := _cursor_cell()
	if not _in_pad(cell):
		return
	var hit := _hit(cell)
	if hit < 0:
		move_uid = -1
		if not shift:
			_arm("", -1)
			uid_anchor = -1
		return
	var inst: Dictionary = placed[hit]
	var uid := int(inst.uid)
	var id := str(inst.id)
	if shift and meta and not selected_uids.is_empty():
		_range_uids(uid, id, cell)
	elif shift:
		_toggle_uid(uid, id)
	else:
		_arm(id, uid)
	move_uid = uid
	move_grab = cell - _cell_of(inst.at)


## Arms palette drag for a prop id without placing yet.
func _begin_drag(id: String) -> void:
	drag_id = id
	move_uid = -1
	_mark_buttons()


## Commits move or drops a new instance when drag ends on the pad.
func release_drag() -> void:
	if move_uid >= 0 and drag_id == "":
		_finish_move()
		return
	if drag_id == "":
		return
	var id := drag_id
	drag_id = ""
	if not _over_ui():
		var cell := _cursor_cell()
		var origin := Catalog.cell_world(cell)
		var tune: Dictionary = PropTune.get_tune(id)
		if _in_pad(cell) and _fits(origin, tune.footprint, -1):
			var uid := next_uid
			next_uid += 1
			placed.append({"uid": uid, "id": id, "at": origin})
			_arm(id, uid)
			return
		if _in_pad(cell):
			_refuse()
	_mark_buttons()


## Sets armed prop id and primary selection for the inspector.
func _arm(id: String, uid: int) -> void:
	armed = id
	selected_uids.clear()
	if uid >= 0:
		selected_uids.append(uid)
		uid_anchor = uid
	else:
		uid_anchor = -1
	_refresh_prop_edit()


## Adds or removes one placed uid from the selection set.
func _toggle_uid(uid: int, id: String) -> void:
	var at := selected_uids.find(uid)
	if at >= 0:
		selected_uids.remove_at(at)
		if selected_uids.is_empty():
			armed = ""
			uid_anchor = -1
			_refresh_prop_edit()
			return
		var primary := _primary_uid()
		var index := _index_of(primary)
		armed = str(placed[index].id) if index >= 0 else ""
		_refresh_prop_edit()
		return
	selected_uids.append(uid)
	armed = id
	_refresh_prop_edit()


## Shift-selects all instances whose cells fall in the rubber band.
func _range_uids(uid: int, id: String, cell: Vector2i) -> void:
	var anchor_uid := uid_anchor if uid_anchor >= 0 else _primary_uid()
	var index := _index_of(anchor_uid)
	if index < 0:
		_arm(id, uid)
		uid_anchor = uid
		return
	var anchor_cell := _cell_of(placed[index].at)
	var lo := Vector2i(mini(anchor_cell.x, cell.x), mini(anchor_cell.y, cell.y))
	var hi := Vector2i(maxi(anchor_cell.x, cell.x), maxi(anchor_cell.y, cell.y))
	selected_uids.clear()
	for inst in placed:
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		for spot in _cells(inst.at, tune.footprint):
			if spot.x < lo.x or spot.x > hi.x or spot.y < lo.y or spot.y > hi.y:
				continue
			var picked := int(inst.uid)
			if selected_uids.find(picked) < 0:
				selected_uids.append(picked)
			break
	if selected_uids.find(uid) < 0:
		selected_uids.append(uid)
	elif selected_uids.size() > 1:
		selected_uids.erase(uid)
		selected_uids.append(uid)
	armed = id
	_refresh_prop_edit()


## Refreshes inspector fields, buttons, and status for selection.
func _refresh_prop_edit() -> void:
	if armed == "":
		_clear_edit()
	elif armed == THRONG_ID:
		name_label.text = "MULTI"
		if selected_uids.size() > 1:
			name_label.text = "MULTI  +%d" % (selected_uids.size() - 1)
		_set_edit_enabled(false)
	else:
		_fill_inspector()
		_set_edit_enabled(true)
	_mark_buttons()
	_sync_quit()
	_refresh_status()


## Last uid in selected_uids used as inspector primary.
func _primary_uid() -> int:
	if selected_uids.is_empty():
		return -1
	return int(selected_uids[selected_uids.size() - 1])


## Whether a placed uid is in the current selection.
func _uid_picked(uid: int) -> bool:
	return selected_uids.find(uid) >= 0


## Distinct prop ids among selected uids for batch tune edits.
func _edit_ids() -> Array:
	var ids: Array = []
	var seen := {}
	for raw in selected_uids:
		var index := _index_of(int(raw))
		if index < 0:
			continue
		var id := str(placed[index].id)
		if id == "" or id == THRONG_ID or seen.has(id):
			continue
		seen[id] = true
		ids.append(id)
	if ids.is_empty() and armed != "" and armed != THRONG_ID:
		ids.append(armed)
	return ids


## Deletes all selected placed instances and frees nodes.
func _remove_selected() -> void:
	if selected_uids.is_empty():
		return
	var uids: Array = selected_uids.duplicate()
	for raw in uids:
		var uid := int(raw)
		var index := _index_of(uid)
		if index < 0:
			continue
		if uid == move_uid:
			move_uid = -1
		placed.remove_at(index)
		if nodes.has(uid):
			var node: Node2D = nodes[uid]
			nodes.erase(uid)
			node.queue_free()
	selected_uids.clear()
	armed = ""
	_clear_edit()
	_mark_buttons()
	_sync_quit()
	_refresh_status()


## Resets PropTune defaults for every distinct id in the selection.
func _reset_kind() -> void:
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		PropTune.reset(str(id))
	_fill_inspector()
	_mark_buttons()
	_refresh_status()


## Persists prop, throng, anim, and effect tunes then reloads.
func _save_restart() -> void:
	var prop_path: String = PropTune.save_file()
	var throng_path: String = ThrongTune.save_file()
	var anim_path: String = AnimTune.save_file()
	var effect_path: String = EffectTune.save_file()
	if prop_path == "" or throng_path == "" or anim_path == "" or effect_path == "":
		if status:
			status.text = "NO SE PUDO GUARDAR"
		if throng_status:
			throng_status.text = "NO SE PUDO GUARDAR"
		if effect_status:
			effect_status.text = "NO SE PUDO GUARDAR"
		return
	print("prop tune: ", prop_path)
	print("throng tune: ", throng_path)
	print("anim tune: ", anim_path)
	print("effect tune: ", effect_path)
	PropTune.arm_boot()
	main.get_tree().reload_current_scene()


## Fills the pad tiles via Main world ground helper.
func _paint_ground() -> void:
	main.tilemap.clear()
	main.path_overlay.clear_paths(main.pathmap)
	for y in range(PAD_MIN, PAD_MAX + 1):
		for x in range(PAD_MIN, PAD_MAX + 1):
			main.tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


## Removes every placed instance and frees pooled nodes.
func _clear_placed() -> void:
	placed.clear()
	selected_uids.clear()
	for uid in nodes.keys():
		var node: Node2D = nodes[uid]
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


## Catalog palette row dict for a prop id string.
func _row_for(id: String) -> Dictionary:
	if id == THRONG_ID:
		return {"id": THRONG_ID, "node": false}
	return PropTune.entry(id)


## Idle clip name for throng preview at a given time.
func _throng_idle_clip(time: float) -> String:
	return "ThrongA_Default Blink" if int(time * 2.0) % 5 == 4 else "ThrongA_Default"


## Appends world draw entries and structure sprites for one placement.
func _paint_inst(draws: Array, row: Dictionary, origin: Vector2, alpha: float, uid: int, used: Dictionary) -> void:
	if str(row.get("id", "")) == THRONG_ID:
		if throng_mode:
			_paint_tuned(draws, origin, alpha)
		elif effect_mode:
			_paint_effect_throng(draws, origin, alpha)
		else:
			var clip := _throng_idle_clip(Time.get_ticks_msec() / 1000.0)
			var frame := ThrongClips.frame_at(clip, 0)
			var off: Vector2 = ThrongTune.frame_offset(clip, 0)
			main.iso_draw.push_iso(draws, origin + off, frame, Color(1, 1, 1, alpha), 0.0, ThrongTune.frame_scale(clip, 0))
			draws[draws.size() - 1]["rot"] = ThrongTune.frame_rot(clip, 0)
		return
	var tune: Dictionary = PropTune.get_tune(str(row.id))
	if bool(row.get("node", false)):
		var node: Node2D = _take_node(uid)
		var at: Vector2 = _anchor(row, origin, tune, 0)
		node.position = main.cam_rig.to_iso(at)
		node.scale = Vector2(float(tune.scale), float(tune.scale))
		node.rotation_degrees = float(tune.rot)
		node.z_index = int(round(float(tune.z)))
		node.modulate = Color(1, 1, 1, alpha)
		node.visible = true
		used[uid] = true
		return
	var kind := int(row.get("kind", -1))
	if str(row.get("group", "")) == "building" and _want_active_sprite(kind):
		_paint_active_building(draws, kind, origin, alpha, uid, used, tune)
		return
	if str(row.get("group", "")) == "building" and (kind == Catalog.BLD_ROUND or kind == Catalog.BLD_FLOWER):
		_paint_structure_anim(draws, kind, origin, alpha, _frame_of(row), tune, uid, used)
		return
	if str(row.get("group", "")) == "building" and main.structure_tex.idle_structure_texture(kind) != null:
		_paint_idle_structure(draws, kind, origin, alpha, tune, uid, used)
		return
	var frame := _frame_of(row)
	var at: Vector2 = _anchor(row, origin, tune, frame)
	main.iso_draw.push_iso(draws, at, frame, Color(1, 1, 1, alpha), 0.0, float(tune.scale))
	var last: Dictionary = draws[draws.size() - 1]
	last["sy"] = float(last.get("sy", last.p.y)) + float(tune.z)
	last["rot"] = float(tune.rot)
	if str(row.group) == "feature" and int(row.kind) == Catalog.FEAT_ANOMALY:
		main.iso_draw.push_iso(draws, at, AssetFrames.ANOMALY_RAY, Color(1, 1, 1, alpha), 0.0, float(tune.scale))
		var ray: Dictionary = draws[draws.size() - 1]
		ray["sy"] = float(last.sy) + 0.5
		ray["rot"] = float(tune.rot)


## World anchor point for a prop given tune offsets and frame.
func _anchor(row: Dictionary, origin: Vector2, tune: Dictionary, frame: int) -> Vector2:
	var extra: Vector2 = tune.offset
	if bool(row.get("node", false)):
		return origin + extra
	var size: Vector2i = tune.footprint
	return origin + Catalog.footprint_center(size) + main.iso_draw.pad_nudge(frame, float(tune.scale), size) + extra


## Atlas frame index for a placed row including anim and structure.
func _frame_of(row: Dictionary) -> int:
	var kind := int(row.kind)
	var ore := int(row.ore)
	var time := Time.get_ticks_msec() / 1000.0
	if str(row.group) == "feature":
		var frame: int = main.anim_frames.feature_frame(kind, time, ore)
		if frame < 0:
			frame = main.anim_frames.prop_frame(Catalog.icon_for_feature(kind, ore))
		return frame
	if str(row.group) == "item":
		if kind == Catalog.ITEM_EGG:
			return AnimTune.sheet_frame("egg", posmod(int(time * 4.0), 5))
		return main.anim_frames.prop_frame(Catalog.icon_for_item(kind))
	if kind == Catalog.BLD_ROUND:
		return posmod(int(time * 8.0), StructureTextures.ROUND_ANIM_N)
	if kind == Catalog.BLD_FLOWER:
		return posmod(int(time * 6.0), StructureTextures.FLOWER_ANIM_N)
	return main.anim_frames.prop_frame(int(row.icon))


## Borrows or creates a pooled Node2D for a placed uid.
func _take_node(uid: int) -> Node2D:
	if nodes.has(uid) and is_instance_valid(nodes[uid]) and not (nodes[uid] is Sprite2D):
		return nodes[uid]
	if nodes.has(uid) and is_instance_valid(nodes[uid]):
		nodes[uid].queue_free()
		nodes.erase(uid)
	var node: Node2D = (load("res://scripts/presentation/props/monolith_prop.gd") as GDScript).new()
	main.world_layer.add_child(node)
	nodes[uid] = node
	return node


## Whether this building kind has a lit active texture.
func _want_active_sprite(kind: int) -> bool:
	if not Catalog.building_has_active(kind):
		return false
	if show_active:
		return true
	return effect_mode and str(effect_id).begins_with("visit:")


## Borrows a Sprite2D for the lit building overlay.
func _take_active_sprite(uid: int, kind: int) -> Sprite2D:
	var tex: Texture2D = main.structure_tex.active_structure_texture(kind)
	if nodes.has(uid) and is_instance_valid(nodes[uid]) and nodes[uid] is Sprite2D:
		var kept: Sprite2D = nodes[uid]
		kept.texture = tex
		return kept
	if nodes.has(uid) and is_instance_valid(nodes[uid]):
		nodes[uid].queue_free()
		nodes.erase(uid)
	var node := Sprite2D.new()
	node.centered = true
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.texture = tex
	main.world_layer.add_child(node)
	nodes[uid] = node
	return node


## Draws idle, active, or goo building layers for one uid.
func _paint_active_building(
	_draws: Array,
	kind: int,
	origin: Vector2,
	alpha: float,
	uid: int,
	used: Dictionary,
	tune: Dictionary
) -> void:
	var tex: Texture2D = main.structure_tex.active_structure_texture(kind)
	if tex == null:
		return
	# Active offset is independent of the idle/default offset.
	var frame: int = main.anim_frames.prop_frame(Catalog.icon_for_building(kind))
	var size: Vector2i = tune.get("footprint", Vector2i(1, 1))
	var sprite_scale := float(tune.scale)
	var active_off: Vector2 = tune.active_offset if tune.has("active_offset") else Vector2.ZERO
	var at: Vector2 = origin + Catalog.footprint_center(size) + main.iso_draw.pad_nudge(frame, sprite_scale, size) + active_off
	var screen_p: Vector2 = main.cam_rig.to_iso(at)
	var node: Sprite2D = _take_active_sprite(uid, kind)
	node.scale = Vector2(sprite_scale, sprite_scale)
	node.rotation_degrees = float(tune.rot)
	node.modulate = Color(1, 1, 1, alpha)
	node.position = screen_p + main.structure_tex.structure_sprite_lift(tex, sprite_scale)
	node.visible = true
	used[uid] = true


## Pulls pooled nodes off-screen before sorting world draws.
func _lift_nodes() -> void:
	for uid in nodes.keys():
		var node: Node2D = nodes[uid]
		if not is_instance_valid(node) or not node.visible:
			continue
		if node.get_parent() == main.world_layer:
			main.world_layer.move_child(node, -1)


## Returns unused pooled nodes to the cache after painting.
func _drop_nodes(used: Dictionary) -> void:
	var drop: Array = []
	for uid in nodes.keys():
		if used.has(uid):
			continue
		if int(uid) < 0:
			if is_instance_valid(nodes[uid]):
				nodes[uid].visible = false
			continue
		drop.append(uid)
	for uid in drop:
		var node: Node2D = nodes[uid]
		nodes.erase(uid)
		if is_instance_valid(node):
			node.queue_free()


## Whether a semi-transparent placement ghost should draw.
func _show_ghost() -> bool:
	if drag_id == "" or _over_ui():
		return false
	return _in_pad(_cursor_cell())


## True when the cursor is over a dev bench control, not the pad.
func _over_ui() -> bool:
	var hovered: Control = main.get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if rail and (hovered == rail or rail.is_ancestor_of(hovered)):
		return true
	if bar and (hovered == bar or bar.is_ancestor_of(hovered)):
		return true
	if throng_rail and throng_rail.visible and (hovered == throng_rail or throng_rail.is_ancestor_of(hovered)):
		return true
	if throng_bar and throng_bar.visible and (hovered == throng_bar or throng_bar.is_ancestor_of(hovered)):
		return true
	return false


## Placement pad cell under the mouse in grid coordinates.
func _cursor_cell() -> Vector2i:
	return _cell_of(main.cam_rig.grid_pointer_world())


## Grid cell containing a world position on the pad.
func _cell_of(at: Vector2) -> Vector2i:
	var tile := float(Catalog.TILE)
	return Vector2i(int(floor(at.x / tile)), int(floor(at.y / tile)))


## Whether a grid cell lies inside PAD_MIN..PAD_MAX.
func _in_pad(cell: Vector2i) -> bool:
	return cell.x >= PAD_MIN and cell.x <= PAD_MAX and cell.y >= PAD_MIN and cell.y <= PAD_MAX


## All grid cells covered by a footprint at an origin.
func _cells(origin: Vector2, size: Vector2i) -> Array[Vector2i]:
	var origin_cell := _cell_of(origin)
	var out: Array[Vector2i] = []
	for off in Catalog.footprint_offsets(size):
		out.append(origin_cell + off)
	return out


## World origin for an instance, including in-progress move.
func _live_at(inst: Dictionary) -> Vector2:
	if int(inst.uid) != move_uid or _over_ui():
		return inst.at
	return Catalog.cell_world(_cursor_cell() - move_grab)


## Commits move_uid position when drag ends on a valid cell.
func _finish_move() -> void:
	var uid := move_uid
	move_uid = -1
	var index := _index_of(uid)
	if index < 0 or _over_ui():
		return
	var inst: Dictionary = placed[index]
	var origin := Catalog.cell_world(_cursor_cell() - move_grab)
	var tune: Dictionary = PropTune.get_tune(str(inst.id))
	if not _fits(origin, tune.footprint, uid):
		_refuse()
		return
	inst.at = origin


## Whether a footprint at origin avoids overlap excluding one uid.
func _fits(origin: Vector2, size: Vector2i, ignore_uid: int) -> bool:
	for cell in _cells(origin, size):
		if not _in_pad(cell):
			return false
		if _occupied(cell, ignore_uid):
			return false
	return true


## Whether any placed instance covers a cell except ignore_uid.
func _occupied(cell: Vector2i, ignore_uid: int) -> bool:
	for inst in placed:
		if int(inst.uid) == ignore_uid:
			continue
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		var size: Vector2i = tune.footprint
		if _covers(inst.at, size, cell):
			return true
	return false


## Whether tune footprint size is allowed for prop id.
func _foot_fits(id: String, size: Vector2i) -> bool:
	for inst in placed:
		if str(inst.id) != id:
			continue
		if not _fits(inst.at, size, int(inst.uid)):
			return false
	return true


## Brief status flash when placement is rejected.
func _refuse() -> void:
	if status:
		status.text = "NO CABE"
	if throng_status:
		throng_status.text = "NO CABE"


## Uid index into placed at a grid cell, or -1.
func _hit(cell: Vector2i) -> int:
	for i in range(placed.size() - 1, -1, -1):
		var inst: Dictionary = placed[i]
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		if _covers(inst.at, tune.footprint, cell):
			return i
	return -1


## Whether a footprint at origin includes a given cell.
func _covers(origin: Vector2, size: Vector2i, cell: Vector2i) -> bool:
	for spot in _cells(origin, size):
		if spot == cell:
			return true
	return false


## Index in placed for a uid, or -1.
func _index_of(uid: int) -> int:
	for i in placed.size():
		if int(placed[i].uid) == uid:
			return i
	return -1


## Pad cells currently visible for grid overlay drawing.
func _view_cells() -> Array[Vector2i]:
	var rect: Rect2 = main.cam_rig.world_view().grow(24.0)
	var tile := float(Catalog.TILE)
	var x0 := int(floor(rect.position.x / tile))
	var y0 := int(floor(rect.position.y / tile))
	var x1 := int(floor(rect.end.x / tile))
	var y1 := int(floor(rect.end.y / tile))
	var out: Array[Vector2i] = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cell := Vector2i(x, y)
			if _in_pad(cell):
				out.append(cell)
	return out


## Draws one cell isometric outline with edge and fill colors.
func _stroke(cell: Vector2i, poly: PackedVector2Array, edge: Color, fill: Color) -> void:
	var pos: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(cell))
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(pos + p)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge, 1.0, false)


## Draws selection crosshair at a world point.
func _cross(at: Vector2) -> void:
	var p: Vector2 = main.cam_rig.to_iso(at)
	draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color.WHITE, 1.0, false)
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color.WHITE, 1.0, false)


## Constructs prop-mode rails, palette, and inspector spin boxes.
func _build_ui() -> void:
	var theme := _theme()
	var root: Control = main.ui.get_child(0)
	rail = PanelContainer.new()
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = 4
	rail.offset_top = 4
	rail.offset_right = 56
	rail.offset_bottom = -4
	rail.mouse_filter = Control.MOUSE_FILTER_STOP
	rail.theme = theme
	rail.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	rail.add_child(scroll)
	root.add_child(rail)
	_build_list()

	bar = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 60
	bar.offset_top = -178
	bar.offset_right = -4
	bar.offset_bottom = -4
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.theme = theme
	bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var hint := Label.new()
	hint.text = "SHIFT+CLICK MULTI. SHIFT+CMD+CLICK RANGO. LOS CAMBIOS VAN A TODOS. SAVE ESCRIBE prop_tune, throng_tune, anim_tune Y effect_tune. RX/RY ES LA ELIPSE DE INTERACCION. AX/AY MUEVE EL SPRITE ACTIVE (CASA/TEATRO). ACTIVE PREVISUALIZA ESA VERSION."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	name_label = Label.new()
	name_label.clip_text = true
	box.add_child(name_label)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 4)
	grid_x = _spin(1, 8, 1, true)
	grid_y = _spin(1, 8, 1, true)
	reach_x = _spin(4, 160, 1)
	reach_y = _spin(4, 160, 1)
	scale_box = _spin(0.01, 3.0, 0.05)
	off_x = _spin(-160, 160, 1)
	off_y = _spin(-160, 160, 1)
	active_x = _spin(-160, 160, 1)
	active_y = _spin(-160, 160, 1)
	z_box = _spin(-40, 40, 1)
	rot_box = _spin(-180, 180, 1)
	grid_x.tooltip_text = "Celdas que ocupa en X"
	grid_y.tooltip_text = "Celdas que ocupa en Y"
	reach_x.tooltip_text = "Eje X de la elipse de interaccion (pixeles de mundo). Los thronglets se acercan por este anillo."
	reach_y.tooltip_text = "Eje Y de la elipse de interaccion (pixeles de mundo). Los thronglets se acercan por este anillo."
	scale_box.tooltip_text = "Escala del sprite"
	off_x.tooltip_text = "Offset X. Con ACTIVE OFF: sprite idle. Con ACTIVE ON: solo el sprite occupied."
	off_y.tooltip_text = "Offset Y. Con ACTIVE OFF: sprite idle. Con ACTIVE ON: solo el sprite occupied."
	active_x.tooltip_text = "Offset X solo del sprite active/ocupado (mismo valor que X con ACTIVE ON)."
	active_y.tooltip_text = "Offset Y solo del sprite active/ocupado (mismo valor que Y con ACTIVE ON)."
	z_box.tooltip_text = "Orden. Mas alto queda delante. En el monolito es el z_index."
	rot_box.tooltip_text = "Rotacion en grados. Positivo gira a la derecha, alrededor del ancla."
	_pair(metrics, "GX", grid_x)
	_pair(metrics, "GY", grid_y)
	_pair(metrics, "RX", reach_x)
	_pair(metrics, "RY", reach_y)
	_pair(metrics, "SC", scale_box)
	_pair(metrics, "X", off_x)
	_pair(metrics, "Y", off_y)
	_pair(metrics, "AX", active_x)
	_pair(metrics, "AY", active_y)
	_pair(metrics, "Z", z_box)
	_pair(metrics, "R", rot_box)
	box.add_child(metrics)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(_text_button("RESET", _reset_kind))
	quit_button = _text_button("QUITAR", _remove_selected)
	actions.add_child(quit_button)
	active_button = _text_button("ACTIVE", _toggle_active_preview)
	active_button.tooltip_text = "Mostrar la version occupied/active del edificio (casa, lujo, teatro)"
	actions.add_child(active_button)
	actions.add_child(_text_button("SAVE & RESTART", _save_restart))
	actions.add_child(_text_button("ANIM", _show_throng))
	actions.add_child(_text_button("EFFECTS", _show_effects))
	actions.add_child(_text_button("LAB TIOVIVO", _show_lab))
	actions.add_child(_text_button("LAB PATH", _show_path_lab))
	actions.add_child(_text_button("MENU", main._leave_dev))
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.clip_text = true
	actions.add_child(status)
	box.add_child(actions)
	bar.add_child(box)
	root.add_child(bar)
	grid_x.value_changed.connect(_on_foot)
	grid_y.value_changed.connect(_on_foot)
	reach_x.value_changed.connect(_on_reach)
	reach_y.value_changed.connect(_on_reach)
	scale_box.value_changed.connect(_on_scale)
	off_x.value_changed.connect(_on_offset)
	off_y.value_changed.connect(_on_offset)
	active_x.value_changed.connect(_on_active_offset)
	active_y.value_changed.connect(_on_active_offset)
	z_box.value_changed.connect(_on_z)
	rot_box.value_changed.connect(_on_rot)
	_sync_active_button()
	_build_throng_ui(theme, root)
	_build_effect_ui(theme, root)
	_build_lab_ui(theme, root)


## Populates grouped prop buttons from the catalog.
func _build_list() -> void:
	_section("MULTI")
	var multi := Button.new()
	multi.icon = main.ui_assets.tex("res://resources/ui/face_base.png")
	multi.tooltip_text = "MULTI"
	multi.custom_minimum_size = Vector2(32, 32)
	multi.expand_icon = true
	multi.focus_mode = Control.FOCUS_NONE
	multi.button_down.connect(_begin_drag.bind(THRONG_ID))
	list.add_child(multi)
	buttons[THRONG_ID] = multi
	_section("OBRA")
	for row in PropTune.entries():
		if str(row.group) == "building":
			_add_palette(row)
	_section("SUELO")
	for row in PropTune.entries():
		if str(row.group) == "feature":
			_add_palette(row)
	_section("COSAS")
	for row in PropTune.entries():
		if str(row.group) == "item":
			_add_palette(row)


## Adds a centered section title label to the palette list.
func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(label)


## Appends one prop toggle button to the palette list.
func _add_palette(row: Dictionary) -> void:
	var button := Button.new()
	if str(row.group) == "feature" and int(row.kind) == Catalog.FEAT_ANOMALY:
		button.icon = main.world_drawer.cell_tex(AssetFrames.ANOMALY)
	else:
		button.icon = main.world_marks_ui.atlas_icon(int(row.icon))
	button.tooltip_text = str(row.label)
	button.custom_minimum_size = Vector2(32, 32)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(_begin_drag.bind(str(row.id)))
	list.add_child(button)
	buttons[str(row.id)] = button


## Creates a themed bench button wired to a Callable.
func _text_button(text: String, call: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	return button


## Factory for bounded SpinBox controls with shared bench theme.
func _spin(lo: float, hi: float, step: float, whole: bool = false) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = lo
	box.max_value = hi
	box.step = step if whole else 0.01
	if not whole and not is_equal_approx(step, 0.01):
		box.custom_arrow_step = step
	box.rounded = whole
	box.custom_minimum_size = Vector2(52, 22)
	box.update_on_text_changed = whole
	box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return box


## Adds a titled row with one inspector SpinBox.
func _pair(row: HBoxContainer, title: String, box: SpinBox) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(16, 0)
	row.add_child(label)
	row.add_child(box)


## Shared green/wood Theme for all dev bench controls.
func _theme() -> Theme:
	var theme := Theme.new()
	if main.ui_theme != null:
		theme.default_font = main.ui_theme.default_font
		theme.default_font_size = main.ui_theme.default_font_size
	var normal := _flat(Color(0.16, 0.09, 0.06, 1), Color(0.55, 0.36, 0.18))
	var hover := _flat(Color(0.42, 0.24, 0.1, 1), Color(0.9, 0.7, 0.3))
	var panel := _flat(Color(0.07, 0.04, 0.03, 0.94), Color(0.85, 0.62, 0.28))
	var line := _flat(Color(0.12, 0.07, 0.04, 1), Color(0.55, 0.36, 0.18))
	line.set_content_margin_all(1)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	theme.set_stylebox("focus", "Button", normal)
	theme.set_stylebox("disabled", "Button", normal)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("normal", "LineEdit", line)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.45, 0.35))
	theme.set_color("font_color", "Label", Color(1, 0.95, 0.86))
	theme.set_color("font_color", "LineEdit", Color.WHITE)
	return theme


## StyleBoxFlat helper for panel fills and borders.
func _flat(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	return box


## Clears inspector labels and disables footprint spins.
func _clear_edit() -> void:
	name_label.text = "ARRASTRA UN ICONO"
	_set_edit_enabled(false)


## Enables or locks footprint and reach inspector spins.
func _set_edit_enabled(on: bool) -> void:
	for box in [grid_x, grid_y, scale_box, off_x, off_y, z_box, rot_box]:
		box.editable = on
	var row: Dictionary = PropTune.entry(armed) if on else {}
	var building := on and str(row.get("group", "")) == "building"
	reach_x.editable = building
	reach_y.editable = building
	var has_active := building and Catalog.building_has_active(int(row.get("kind", -1)))
	active_x.editable = has_active
	active_y.editable = has_active


## Whether active offset spins are the focused edit target.
func _editing_active_offset() -> bool:
	if not show_active:
		return false
	var row: Dictionary = PropTune.entry(armed)
	return not row.is_empty() and Catalog.building_has_active(int(row.get("kind", -1)))


## Pushes PropTune fields into inspector spins for selection.
func _fill_inspector() -> void:
	var row: Dictionary = PropTune.entry(armed)
	if row.is_empty():
		return
	var tune: Dictionary = PropTune.get_tune(armed)
	var size: Vector2i = tune.footprint
	var off: Vector2 = tune.offset
	var reach: Vector2 = tune.reach
	var active_off: Vector2 = tune.active_offset if tune.has("active_offset") else Vector2.ZERO
	var title := "%s   %s" % [str(row.label), str(row.constant)]
	var kinds := _edit_ids()
	if kinds.size() > 1:
		title = "%s  +%d" % [title, kinds.size() - 1]
	if Catalog.building_has_active(int(row.get("kind", -1))):
		title = "%s  [%s]" % [title, "ACTIVE" if show_active else "IDLE"]
	name_label.text = title
	_fill = true
	grid_x.set_value_no_signal(size.x)
	grid_y.set_value_no_signal(size.y)
	reach_x.set_value_no_signal(reach.x)
	reach_y.set_value_no_signal(reach.y)
	scale_box.set_value_no_signal(float(tune.scale))
	# With ACTIVE ON, X/Y dial the active sprite; idle offset stays in AX/AY mirrors.
	if _editing_active_offset():
		off_x.set_value_no_signal(active_off.x)
		off_y.set_value_no_signal(active_off.y)
	else:
		off_x.set_value_no_signal(off.x)
		off_y.set_value_no_signal(off.y)
	active_x.set_value_no_signal(active_off.x)
	active_y.set_value_no_signal(active_off.y)
	z_box.set_value_no_signal(float(tune.z))
	rot_box.set_value_no_signal(float(tune.rot))
	_fill = false
	_set_edit_enabled(true)
	_sync_active_button()


## Updates pressed state on palette and clip/effect buttons.
func _mark_buttons() -> void:
	var picked := {}
	for id in _edit_ids():
		picked[str(id)] = true
	for id in buttons.keys():
		var button: Button = buttons[id]
		var dirty := PropTune.is_dirty(str(id))
		if str(id) == drag_id:
			button.modulate = Color(0.65, 0.88, 1.0)
		elif picked.has(str(id)) or str(id) == armed:
			button.modulate = Color(1, 0.86, 0.4)
		elif dirty:
			button.modulate = Color(0.65, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE


## Sets quit button label based on active dev mode.
func _sync_quit() -> void:
	if quit_button:
		quit_button.disabled = selected_uids.is_empty()


## Refreshes prop, throng, effect, and lab status lines.
func _refresh_status() -> void:
	var props: int = PropTune.change_count()
	var clips: int = ThrongTune.change_count() + AnimTune.change_count()
	var effects: int = EffectTune.change_count()
	var text := "SIN CAMBIOS"
	if props > 0 or clips > 0 or effects > 0:
		text = "%d PROPS  %d CLIPS  %d FX" % [props, clips, effects]
	if status:
		status.text = text
	if throng_status:
		throng_status.text = text
	if effect_status:
		effect_status.text = text


## Applies footprint dimension edits to PropTune for selection.
func _on_foot(_v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	var next := Vector2i(int(grid_x.value), int(grid_y.value))
	for id in ids:
		if not _foot_fits(str(id), next):
			var tune: Dictionary = PropTune.get_tune(armed)
			var size: Vector2i = tune.footprint
			_fill = true
			grid_x.set_value_no_signal(size.x)
			grid_y.set_value_no_signal(size.y)
			_fill = false
			_refuse()
			return
	for id in ids:
		PropTune.set_footprint(str(id), next.x, next.y)
	_mark_buttons()
	_refresh_status()


## Writes prop scale from scale_box to PropTune.
func _on_scale(v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		PropTune.set_scale(str(id), v)
	_mark_buttons()
	_refresh_status()


## Writes sprite offset from off_x/off_y spins.
func _on_offset(_v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	if _editing_active_offset():
		for id in ids:
			PropTune.set_active_offset(str(id), off_x.value, off_y.value)
		_fill = true
		active_x.set_value_no_signal(off_x.value)
		active_y.set_value_no_signal(off_y.value)
		_fill = false
	else:
		for id in ids:
			PropTune.set_offset(str(id), off_x.value, off_y.value)
	_mark_buttons()
	_refresh_status()


## Writes lit-sprite offset for structures that support it.
func _on_active_offset(_v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		PropTune.set_active_offset(str(id), active_x.value, active_y.value)
	if _editing_active_offset():
		_fill = true
		off_x.set_value_no_signal(active_x.value)
		off_y.set_value_no_signal(active_y.value)
		_fill = false
	_mark_buttons()
	_refresh_status()


## Flips show_active and repaints structure overlays.
func _toggle_active_preview() -> void:
	show_active = not show_active
	_sync_active_button()
	if armed != "" and not PropTune.entry(armed).is_empty():
		_fill_inspector()


## Updates active_button pressed state from show_active.
func _sync_active_button() -> void:
	if active_button == null:
		return
	active_button.modulate = Color(0.55, 1.0, 0.7) if show_active else Color.WHITE
	active_button.text = "ACTIVE ON" if show_active else "ACTIVE"


## Applies draw sort z from z_box to selected prop tunes.
func _on_z(v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		PropTune.set_z(str(id), v)
	_mark_buttons()
	_refresh_status()


## Applies rotation degrees from rot_box to selection.
func _on_rot(v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		PropTune.set_rot(str(id), v)
	_mark_buttons()
	_refresh_status()


## Applies interaction reach cells from reach spins.
func _on_reach(_v: float) -> void:
	if _fill:
		return
	var ids := _edit_ids()
	if ids.is_empty():
		return
	for id in ids:
		if str(PropTune.entry(str(id)).get("group", "")) != "building":
			continue
		PropTune.set_reach(str(id), reach_x.value, reach_y.value)
	_mark_buttons()
	_refresh_status()
	queue_redraw()


## Draws reach diamond outline for one tuned prop.
func _stroke_reach(origin: Vector2, tune: Dictionary, color: Color) -> void:
	var reach: Vector2 = tune.get("reach", Vector2.ZERO)
	if reach.x < 1.0 or reach.y < 1.0:
		return
	var size: Vector2i = tune.footprint
	var center: Vector2 = origin + Catalog.footprint_center(size)
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		var world := center + Vector2(cos(ang) * reach.x, sin(ang) * reach.y)
		pts.append(main.cam_rig.to_iso(world))
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], color, 1.2, false)


## Builds anim-mode rails, clip list, strip, and transport bar.
func _build_throng_ui(theme: Theme, root: Control) -> void:
	throng_rail = PanelContainer.new()
	throng_rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	throng_rail.offset_left = 4
	throng_rail.offset_top = 4
	throng_rail.offset_right = 188
	throng_rail.offset_bottom = -4
	throng_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	throng_rail.theme = theme
	throng_rail.visible = false
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	clip_filter = LineEdit.new()
	clip_filter.placeholder_text = "BUSCAR"
	clip_filter.text_changed.connect(_on_filter)
	column.add_child(clip_filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	clip_list = VBoxContainer.new()
	clip_list.add_theme_constant_override("separation", 1)
	clip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(clip_list)
	column.add_child(scroll)
	throng_rail.add_child(column)
	root.add_child(throng_rail)
	_build_clip_list()

	throng_bar = PanelContainer.new()
	throng_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	throng_bar.offset_left = 196
	throng_bar.offset_top = -152
	throng_bar.offset_right = -4
	throng_bar.offset_bottom = -4
	throng_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	throng_bar.theme = theme
	throng_bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var hint := Label.new()
	hint.text = "SHIFT+CLICK MULTI. SHIFT+CMD+CLICK RANGO EN CLIPS O FRAMES. VARIOS CLIPS = TODOS SUS FRAMES."
	hint.clip_text = true
	box.add_child(hint)
	throng_name = Label.new()
	throng_name.clip_text = true
	box.add_child(throng_name)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 4)
	fps_box = _spin(0.5, 24.0, 0.5)
	throng_scale = _spin(0.01, 3.0, 0.05)
	throng_x = _spin(-160, 160, 1)
	throng_y = _spin(-160, 160, 1)
	throng_rot = _spin(-180, 180, 1)
	fps_box.tooltip_text = "Fotogramas por segundo. Un frame, mitosis y el bano no guardan fps."
	throng_scale.tooltip_text = "Escala. Aplica a frames/clips seleccionados."
	throng_x.tooltip_text = "Offset X. Aplica a frames/clips seleccionados."
	throng_y.tooltip_text = "Offset Y. Aplica a frames/clips seleccionados."
	throng_rot.tooltip_text = "Rotacion. Aplica a frames/clips seleccionados. Positivo gira a la derecha."
	_pair(metrics, "FPS", fps_box)
	_pair(metrics, "SC", throng_scale)
	_pair(metrics, "X", throng_x)
	_pair(metrics, "Y", throng_y)
	_pair(metrics, "R", throng_rot)
	box.add_child(metrics)
	var frame_scroll := ScrollContainer.new()
	frame_scroll.custom_minimum_size = Vector2(0, 32)
	frame_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	frame_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	frame_scroll.add_child(strip)
	box.add_child(frame_scroll)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	play_button = _text_button("PAUSA", _toggle_play)
	actions.add_child(play_button)
	actions.add_child(_text_button("<", _step.bind(-1)))
	actions.add_child(_text_button(">", _step.bind(1)))
	mirror_button = _text_button("ESPEJO", _toggle_mirror)
	actions.add_child(mirror_button)
	all_button = _text_button("TODOS", _toggle_all)
	all_button.tooltip_text = "Copia escala, posicion y rotacion a cada fotograma del clip activo. Con varios clips, a todos."
	actions.add_child(all_button)
	actions.add_child(_text_button("RESET", _reset_clip))
	box.add_child(actions)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 4)
	save_row.add_child(_text_button("SAVE & RESTART", _save_restart))
	save_row.add_child(_text_button("PROPS", _show_props))
	save_row.add_child(_text_button("EFFECTS", _show_effects))
	save_row.add_child(_text_button("LAB TIOVIVO", _show_lab))
	save_row.add_child(_text_button("LAB PATH", _show_path_lab))
	save_row.add_child(_text_button("MENU", main._leave_dev))
	throng_status = Label.new()
	throng_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	throng_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throng_status.clip_text = true
	save_row.add_child(throng_status)
	box.add_child(save_row)
	throng_bar.add_child(box)
	root.add_child(throng_bar)
	fps_box.value_changed.connect(_on_throng_fps)
	throng_scale.value_changed.connect(_on_throng_scale)
	throng_x.value_changed.connect(_on_throng_offset)
	throng_y.value_changed.connect(_on_throng_offset)
	throng_rot.value_changed.connect(_on_throng_rot)


## Builds effect-mode palette rail and metrics bar.
func _build_effect_ui(theme: Theme, root: Control) -> void:
	effect_rail = PanelContainer.new()
	effect_rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	effect_rail.offset_left = 4
	effect_rail.offset_top = 4
	effect_rail.offset_right = 188
	effect_rail.offset_bottom = -4
	effect_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	effect_rail.theme = theme
	effect_rail.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	effect_list = VBoxContainer.new()
	effect_list.add_theme_constant_override("separation", 1)
	effect_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(effect_list)
	effect_rail.add_child(scroll)
	root.add_child(effect_rail)
	_build_effect_list()

	effect_bar = PanelContainer.new()
	effect_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	effect_bar.offset_left = 196
	effect_bar.offset_top = -188
	effect_bar.offset_right = -4
	effect_bar.offset_bottom = -4
	effect_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	effect_bar.theme = theme
	effect_bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var hint := Label.new()
	hint.text = "PREVIEW EN VIVO. CLIP/FX/MOTION AQUI. FRAMES FINOS EN ANIM. SPACE PAUSA. SAVE ESCRIBE effect_tune.json."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	effect_name = Label.new()
	effect_name.clip_text = true
	box.add_child(effect_name)
	effect_live = Label.new()
	effect_live.clip_text = true
	box.add_child(effect_live)
	effect_look = HBoxContainer.new()
	effect_look.add_theme_constant_override("separation", 4)
	box.add_child(effect_look)
	effect_metrics = HBoxContainer.new()
	effect_metrics.add_theme_constant_override("separation", 4)
	box.add_child(effect_metrics)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	effect_play_button = _text_button("PAUSA", _toggle_effect_play)
	actions.add_child(effect_play_button)
	actions.add_child(_text_button("REPLAY", _replay_effect))
	actions.add_child(_text_button("RESET", _reset_effect))
	actions.add_child(_text_button("CLIP ANIM", _open_effect_clip_anim))
	actions.add_child(_text_button("SAVE & RESTART", _save_restart))
	actions.add_child(_text_button("PROPS", _show_props))
	actions.add_child(_text_button("ANIM", _show_throng))
	actions.add_child(_text_button("LAB TIOVIVO", _show_lab))
	actions.add_child(_text_button("LAB PATH", _show_path_lab))
	actions.add_child(_text_button("MENU", main._leave_dev))
	effect_status = Label.new()
	effect_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect_status.clip_text = true
	actions.add_child(effect_status)
	box.add_child(actions)
	effect_bar.add_child(box)
	root.add_child(effect_bar)


## Fills effect_list buttons from EffectTune catalog.
func _build_effect_list() -> void:
	var last_group := ""
	for row in EffectTune.entries():
		var group := str(row.group)
		if group != last_group:
			var label := Label.new()
			label.text = group
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			effect_list.add_child(label)
			last_group = group
		var button := Button.new()
		button.text = str(row.label)
		button.tooltip_text = str(row.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 20)
		button.pressed.connect(_select_effect.bind(str(row.id)))
		effect_list.add_child(button)
		effect_buttons[str(row.id)] = button


## Arms one effect id and stages its preview scene.
func _select_effect(id: String) -> void:
	effect_id = id
	_fill_effect()
	_stage_effect()
	_mark_effects()
	_refresh_status()


## Pushes EffectTune fields into effect inspector controls.
func _fill_effect() -> void:
	_fill = true
	for child in effect_metrics.get_children():
		child.queue_free()
	for child in effect_look.get_children():
		child.queue_free()
	effect_spins.clear()
	effect_clip_box = null
	effect_fx_box = null
	if effect_id == "" or EffectTune.entry(effect_id).is_empty():
		effect_name.text = "SIN EFECTO"
		_fill = false
		return
	var row: Dictionary = EffectTune.entry(effect_id)
	var tune: Dictionary = EffectTune.get_tune(effect_id)
	effect_name.text = "%s  (%s)" % [str(row.label), effect_id]
	_fill_effect_look(tune)
	for key in row.fields:
		var field := str(key)
		if EffectTune.is_str_field(field):
			continue
		if field == "lift" or field == "bob" or field == "orbit":
			continue
		var meta: Dictionary = EffectTune.field_meta(effect_id, field)
		var box := _spin(float(meta.min), float(meta.max), float(meta.step), bool(meta.whole))
		box.set_value_no_signal(float(tune.get(field, 0.0)))
		var field_key := field
		box.value_changed.connect(func(_v: float): _on_effect_num(field_key))
		_pair(effect_metrics, field.to_upper(), box)
		effect_spins[field] = box
	for field in ["lift", "bob", "orbit"]:
		var meta2: Dictionary = EffectTune.field_meta(effect_id, field)
		var box2 := _spin(float(meta2.min), float(meta2.max), float(meta2.step), bool(meta2.whole))
		box2.set_value_no_signal(float(tune.get(field, 0.0)))
		var motion_key: String = field
		box2.value_changed.connect(func(_v: float): _on_effect_num(motion_key))
		_pair(effect_metrics, field.to_upper(), box2)
		effect_spins[field] = box2
	_fill = false
	_sync_effect_live()


## Populates clip and FX option rows for the armed effect.
func _fill_effect_look(tune: Dictionary) -> void:
	var clip_label := Label.new()
	clip_label.text = "CLIP"
	effect_look.add_child(clip_label)
	effect_clip_box = OptionButton.new()
	effect_clip_box.custom_minimum_size = Vector2(180, 22)
	effect_clip_box.focus_mode = Control.FOCUS_NONE
	var clip_names: PackedStringArray = ThrongTune.game_names()
	var rest: PackedStringArray = ThrongTune.rest_names()
	for clip in clip_names:
		effect_clip_box.add_item(clip)
	for clip in rest:
		effect_clip_box.add_item(clip)
	_select_option(effect_clip_box, str(tune.get("clip", "ThrongA_Default")))
	effect_clip_box.item_selected.connect(_on_effect_clip)
	effect_look.add_child(effect_clip_box)
	var fx_label := Label.new()
	fx_label.text = "FX"
	effect_look.add_child(fx_label)
	effect_fx_box = OptionButton.new()
	effect_fx_box.custom_minimum_size = Vector2(90, 22)
	effect_fx_box.focus_mode = Control.FOCUS_NONE
	for fx in EffectTune.FX_CHOICES:
		effect_fx_box.add_item(str(fx))
	_select_option(effect_fx_box, str(tune.get("fx", "none")))
	effect_fx_box.item_selected.connect(_on_effect_fx)
	effect_look.add_child(effect_fx_box)


## Selects OptionButton item matching a string value.
func _select_option(box: OptionButton, value: String) -> void:
	for i in box.item_count:
		if box.get_item_text(i) == value:
			box.select(i)
			return
	if box.item_count > 0:
		box.select(0)


## Persists one numeric effect tune field from a spin.
func _on_effect_num(key: String) -> void:
	if _fill or effect_id == "":
		return
	var box: SpinBox = effect_spins.get(key, null)
	if box == null:
		return
	EffectTune.set_num(effect_id, key, float(box.value))
	_mark_effects()
	_refresh_status()
	queue_redraw()


## Updates effect_clip when body clip option changes.
func _on_effect_clip(index: int) -> void:
	if _fill or effect_id == "" or effect_clip_box == null:
		return
	var clip := effect_clip_box.get_item_text(index)
	EffectTune.set_str(effect_id, "clip", clip)
	effect_clip = clip
	_mark_effects()
	_refresh_status()
	queue_redraw()


## Updates overlay FX when the FX option changes.
func _on_effect_fx(index: int) -> void:
	if _fill or effect_id == "" or effect_fx_box == null:
		return
	EffectTune.set_str(effect_id, "fx", effect_fx_box.get_item_text(index))
	_mark_effects()
	_refresh_status()
	queue_redraw()


## Jumps to throng anim mode editing the effect body clip.
func _open_effect_clip_anim() -> void:
	var clip := effect_clip
	if effect_id != "":
		clip = str(EffectTune.get_tune(effect_id).get("clip", clip))
	_show_throng()
	if clip != "":
		_select_clip(clip)


## Restores EffectTune defaults for the armed effect id.
func _reset_effect() -> void:
	if effect_id == "":
		return
	EffectTune.reset(effect_id)
	_fill_effect()
	_stage_effect()
	_mark_effects()
	_refresh_status()


## Refreshes pressed state on effect palette buttons.
func _mark_effects() -> void:
	for id in effect_buttons.keys():
		var button: Button = effect_buttons[id]
		var dirty := EffectTune.is_dirty(str(id))
		if str(id) == effect_id:
			button.modulate = Color(1, 0.86, 0.4)
		elif dirty:
			button.modulate = Color(0.65, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE


## Toggles effect_playing and play button icon.
func _toggle_effect_play() -> void:
	effect_playing = not effect_playing
	_sync_effect_play_button()


## Resets effect_t and pulses the preview ring.
func _replay_effect() -> void:
	_effect_reset_needs()
	effect_playing = true
	_sync_effect_play_button()
	_sync_effect_live()


## Updates effect play button from effect_playing.
func _sync_effect_play_button() -> void:
	if effect_play_button:
		effect_play_button.text = "PAUSA" if effect_playing else "PLAY"


## Refreshes live timing and metric labels each tick.
func _sync_effect_live() -> void:
	if effect_live == null:
		return
	effect_live.text = "FED %d   FUN %d   CLEAN %d   (preview x%d)" % [
		int(round(effect_fed)),
		int(round(effect_fun)),
		int(round(effect_clean)),
		int(EFFECT_PREVIEW_SCALE),
	]


## Default body clip for an effect id when staging.
func _effect_clip_for(id: String) -> String:
	var tune: Dictionary = EffectTune.get_tune(id)
	var clip := str(tune.get("clip", ""))
	if clip != "" and ThrongClips.has_clip(clip):
		return clip
	match id:
		"act:eat":
			return "ThrongA_Eat"
		"act:bath":
			return BATH_CLIP
		"act:round":
			return RIDE_CLIP
		"act:play", "act:ball", "aura:flower", "aura:statue", "aura:wood", "aura:ball", "feat:totem":
			return "ThrongA_Jump_VariantA_Spritesheet"
		"act:sponge", "feat:curer":
			return "ThrongA_Happy"
		"feat:fire", "goo":
			return "ThrongA_Sad"
		_:
			return "ThrongA_Default"


## Sets staged fed/fun/clean for the effect preview throng.
func _effect_reset_needs() -> void:
	effect_t = 0.0
	effect_pulse = 0.0
	match effect_id:
		"goo", "feat:fire":
			effect_fed = 100.0
			effect_fun = 100.0
			effect_clean = 100.0
		"need":
			effect_fed = 50.0
			effect_fun = 50.0
			effect_clean = 50.0
		"act:eat":
			effect_fed = 20.0
			effect_fun = 70.0
			effect_clean = 70.0
		"act:bath", "act:sponge", "act:mop", "feat:curer":
			effect_fed = 70.0
			effect_fun = 70.0
			effect_clean = 20.0
		"act:play", "act:ball", "act:round", "visit:theatre", "aura:flower", "aura:statue", "aura:wood", "aura:ball", "feat:totem":
			effect_fed = 70.0
			effect_fun = 20.0
			effect_clean = 70.0
		"visit:dwell", "visit:fancy":
			effect_fed = 20.0
			effect_fun = 70.0
			effect_clean = 20.0
		_:
			effect_fed = 40.0
			effect_fun = 40.0
			effect_clean = 40.0


## Catalog building kind drawn as effect partner, if any.
func _effect_partner_kind() -> int:
	match effect_id:
		"visit:dwell":
			return Catalog.BLD_DWELL
		"visit:fancy":
			return Catalog.BLD_FANCY
		"visit:theatre":
			return Catalog.BLD_THEATRE
		"aura:flower", "act:play":
			return Catalog.BLD_FLOWER
		"aura:statue":
			return Catalog.BLD_STATUE
		"aura:wood":
			return Catalog.BLD_WOOD
		"act:bath":
			return Catalog.BLD_TUB
		"act:round":
			return Catalog.BLD_ROUND
		_:
			return -1


## World feature kind staged beside certain effects.
func _effect_partner_feature() -> int:
	match effect_id:
		"feat:totem":
			return Catalog.FEAT_TOTEM
		"feat:curer":
			return Catalog.FEAT_CURER
		"feat:fire":
			return Catalog.FEAT_FIRE
		_:
			return -1


## Ensures effect throng instance and partners exist on the pad.
func _stage_effect() -> void:
	_clear_placed()
	_paint_ground()
	effect_clip = _effect_clip_for(effect_id)
	effect_playing = true
	_sync_effect_play_button()
	_effect_reset_needs()
	var throng_cell := Vector2i(8, 16)
	if effect_id == "goo":
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				var cell := throng_cell + Vector2i(ox, oy)
				main.tilemap.set_cell(cell, 0, Vector2i(WorldBootstrap.WASTE_ATLAS + absi((cell.x * 3 + cell.y * 5) % WorldBootstrap.WASTE_VARIANTS), 0))
	# Items sit beside the thronglet. Buildings/features are painted with the throng so sort stays correct.
	var item_id := ""
	if effect_id == "act:eat":
		item_id = "item:%d" % Catalog.ITEM_APPLE
	elif effect_id == "act:ball" or effect_id == "aura:ball":
		item_id = "item:%d" % Catalog.ITEM_BALL
	if item_id != "":
		var uid := next_uid
		next_uid += 1
		placed.append({"uid": uid, "id": item_id, "at": Catalog.cell_world(throng_cell + Vector2i(1, 0))})
	var throng_uid := next_uid
	next_uid += 1
	placed.append({"uid": throng_uid, "id": THRONG_ID, "at": Catalog.cell_world(throng_cell)})
	main.camera.position = main.cam_rig.to_iso(Catalog.cell_world(throng_cell))
	_sync_effect_live()


## Advances effect timeline, pulses, and partner anims.
func _tick_effect(dt: float) -> void:
	var tune: Dictionary = EffectTune.get_tune(effect_id)
	var step := dt * EFFECT_PREVIEW_SCALE
	match effect_id:
		"goo":
			effect_fed = maxf(0.0, effect_fed - float(tune.fed) * step)
			effect_clean = maxf(0.0, effect_clean - float(tune.clean) * step)
		"need":
			pass
		"visit:dwell", "visit:fancy", "visit:theatre":
			effect_fed = minf(100.0, effect_fed + float(tune.fed) * step)
			effect_clean = minf(100.0, effect_clean + float(tune.clean) * step)
			effect_fun = minf(100.0, effect_fun + float(tune.fun) * step)
		"aura:flower", "aura:statue", "aura:wood", "feat:totem", "aura:ball":
			effect_fun = minf(100.0, effect_fun + float(tune.fun) * step)
		"feat:curer":
			effect_fed = minf(100.0, effect_fed + float(tune.fed) * step)
			effect_clean = minf(100.0, effect_clean + float(tune.clean) * step)
			effect_fun = minf(100.0, effect_fun + float(tune.fun) * step)
		"feat:fire":
			effect_clean = maxf(0.0, effect_clean - float(tune.clean) * step)
		"act:bath":
			effect_clean = minf(100.0, effect_clean + float(tune.clean) * step)
		"act:play", "act:round":
			effect_fun = minf(100.0, effect_fun + float(tune.fun) * step)
		"act:eat":
			effect_pulse += step
			if effect_pulse >= float(tune.bite):
				effect_pulse = 0.0
				effect_fed = float(tune.fed)
				effect_t = 0.0
			elif effect_fed >= float(tune.fed) - 0.01 and effect_t > 1.2:
				effect_fed = 20.0
		"act:ball":
			effect_pulse += step
			if effect_pulse >= 1.2:
				effect_pulse = 0.0
				effect_fun = minf(100.0, effect_fun + float(tune.fun))
		"act:sponge":
			effect_pulse += step
			if effect_pulse >= 0.35:
				effect_pulse = 0.0
				var stroke := float(tune.stroke_cap)
				effect_clean = minf(100.0, effect_clean + stroke * float(tune.gain) * 0.25)
		"act:mop":
			effect_pulse += step
			if effect_pulse >= 1.0:
				effect_pulse = 0.0
				effect_clean = float(tune.clean)
				effect_t = 0.0
			elif effect_clean >= float(tune.clean) - 0.01 and effect_t > 1.5:
				effect_clean = 20.0


## World anchor for the staged effect thronglet.
func _effect_throng_origin() -> Vector2:
	for inst in placed:
		if str(inst.id) == THRONG_ID:
			return _live_at(inst)
	return Catalog.cell_world(Vector2i(8, 16))


## World position for partner prop/building beside throng.
func _effect_partner_origin(throng_origin: Vector2) -> Vector2:
	var kind := _effect_partner_kind()
	if kind == Catalog.BLD_TUB or kind == Catalog.BLD_ROUND:
		return throng_origin
	if kind >= 0:
		var tune: Dictionary = PropTune.get_tune("building:%d" % kind)
		var size: Vector2i = tune.get("footprint", Vector2i(1, 1))
		# Keep the thronglet south of the prop so it sorts and reads in front.
		return throng_origin - Vector2(0, float(Catalog.TILE * (maxi(size.y, 1) + 1)))
	var feat := _effect_partner_feature()
	if feat >= 0:
		return throng_origin - Vector2(0, float(Catalog.TILE * 2))
	return throng_origin


## Draws partner structures/features for effect preview.
func _paint_effect_partner(draws: Array, origin: Vector2, alpha: float) -> float:
	var partner_at := _effect_partner_origin(origin)
	var kind := _effect_partner_kind()
	if kind >= 0:
		var before := draws.size()
		var prop_frame := -1
		if kind == Catalog.BLD_ROUND:
			prop_frame = posmod(int(effect_t * 8.0), StructureTextures.ROUND_ANIM_N)
		elif kind == Catalog.BLD_FLOWER:
			prop_frame = posmod(int(effect_t * 6.0), StructureTextures.FLOWER_ANIM_N)
		_paint_building(draws, kind, partner_at, alpha, prop_frame)
		if draws.size() > before:
			return float(draws[draws.size() - 1].get("sy", 0.0)) + 1.0
		return main.iso_draw.prop_front_sort_y(main.iso_draw.building_draw_at(kind, partner_at))
	var feat := _effect_partner_feature()
	if feat >= 0:
		var row: Dictionary = PropTune.entry("feature:%d" % feat)
		if row.is_empty():
			return NAN
		var before := draws.size()
		_paint_inst(draws, row, partner_at, alpha, -1, {})
		if draws.size() > before:
			return float(draws[draws.size() - 1].get("sy", 0.0)) + 1.0
	return NAN


## Draws the staged thronglet body for effect mode.
func _paint_effect_throng(draws: Array, origin: Vector2, alpha: float) -> void:
	var tune: Dictionary = EffectTune.get_tune(effect_id)
	var sort_y := _paint_effect_partner(draws, origin, alpha)
	if effect_id.begins_with("visit:"):
		# Guest is inside the building — only the prop shows.
		return
	var clip := effect_clip
	var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(ThrongClips.BASE, 1))
	var fps := float(ThrongTune.get_tune(clip).get("fps", 8.0))
	var index := 0
	if box.y > 1:
		if clip == BATH_CLIP:
			index = clampi(int(effect_t * 4.0) % box.y, 0, box.y - 1)
		else:
			index = posmod(int(effect_t * fps), box.y)
	var frame := ThrongClips.frame_at(clip, index)
	var off: Vector2 = ThrongTune.frame_offset(clip, index)
	var pos := origin + off
	var lift: float = main.iso_draw.effect_look_lift(tune, effect_t)
	if effect_id == "act:bath":
		pos = origin + Catalog.TUB_SEAT_OFF + off
		lift = _bath_lift(index)
	if is_nan(sort_y):
		sort_y = main.cam_rig.to_iso(origin).y + 8.0
	else:
		sort_y = maxf(sort_y, main.cam_rig.to_iso(origin).y + 8.0)
	main.iso_draw.push_iso(draws, pos, frame, Color(1, 1, 1, alpha), lift, ThrongTune.frame_scale(clip, index), sort_y)
	draws[draws.size() - 1]["rot"] = ThrongTune.frame_rot(clip, index)
	draws[draws.size() - 1]["dirty"] = 1.0 - clampf(effect_clean / 100.0, 0.0, 1.0)
	_paint_effect_fx(draws, pos, sort_y + 1.0, tune)


## Queues overlay FX sprites for the effect preview.
func _paint_effect_fx(draws: Array, pos: Vector2, sort_y: float, tune: Dictionary) -> void:
	match effect_id:
		"act:sponge":
			main.iso_draw.paint_sponge_suds(draws, pos, sort_y, effect_t, tune)
		"act:wash_sparkle", "act:bath_exit":
			main.iso_draw.paint_clean_sparkle(draws, pos, sort_y + 0.4, tune, 1.0, -1.0, effect_t)
		"act:mop":
			main.iso_draw.paint_clean_sparkle(draws, pos, sort_y + 0.4, EffectTune.get_tune("act:wash_sparkle"), 1.0, -1.0, effect_t)
		_:
			pass


## Creates need-bar overlay beside the effect throng.
func _build_effect_gauge() -> void:
	var root: Control = main.ui.get_child(0)
	effect_gauge = Control.new()
	effect_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_gauge.visible = false
	effect_gauge.z_index = 20
	root.add_child(effect_gauge)
	effect_gauge_fills.clear()
	effect_gauge_labels.clear()
	var names := ["FED", "FUN", "CLEAN"]
	var colors := [Color(0.86, 0.22, 0.24), Color(0.95, 0.72, 0.22), Color(0.32, 0.62, 0.9)]
	for i in 3:
		var row := HBoxContainer.new()
		row.position = Vector2(0, float(i) * 18.0)
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := Label.new()
		tag.text = names[i]
		tag.custom_minimum_size = Vector2(44, 14)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		var track := ColorRect.new()
		track.custom_minimum_size = Vector2(90, 10)
		track.color = Color(0, 0, 0, 0.65)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(track)
		var fill := ColorRect.new()
		fill.color = colors[i]
		fill.size = Vector2(90, 10)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		effect_gauge_fills.append(fill)
		var value := Label.new()
		value.custom_minimum_size = Vector2(28, 14)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value)
		effect_gauge_labels.append(value)
		effect_gauge.add_child(row)


## Updates gauge fills from effect_fed/fun/clean.
func _sync_effect_need_bars() -> void:
	if effect_gauge == null:
		return
	var origin := _effect_throng_origin()
	if effect_id == "act:bath":
		origin += Catalog.TUB_SEAT_OFF
	var world: Vector2 = main.cam_rig.to_iso(origin) + Vector2(-20, -56)
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * world
	effect_gauge.position = screen
	effect_gauge.visible = true
	var amounts := [effect_fed, effect_fun, effect_clean]
	for i in 3:
		var fill: ColorRect = effect_gauge_fills[i]
		fill.size = Vector2(90.0 * clampf(amounts[i] / 100.0, 0.0, 1.0), 10)
		var label: Label = effect_gauge_labels[i]
		label.text = str(int(round(amounts[i])))
	main.need_show = false
	if main.need_card != null:
		main.need_card.visible = false


## Hides and clears gauge when leaving effect mode.
func _hide_effect_need_bars() -> void:
	if effect_gauge != null:
		effect_gauge.visible = false
	if main == null:
		return
	main.need_show = false
	if main.need_card != null:
		main.need_card.visible = false


## World center for effect ring and radius tests.
func _effect_radius_center() -> Vector2:
	return _effect_throng_origin()


## Positions and scales the Line2D effect radius ring.
func _sync_effect_ring() -> void:
	if effect_ring == null:
		return
	var tune: Dictionary = EffectTune.get_tune(effect_id)
	if not tune.has("radius") or float(tune.radius) < 1.0:
		effect_ring.visible = false
		return
	var radius := float(tune.radius)
	var center := _effect_radius_center()
	var pts := PackedVector2Array()
	var steps := 36
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		pts.append(main.cam_rig.to_iso(center + Vector2(cos(ang) * radius, sin(ang) * radius)))
	effect_ring.points = pts
	effect_ring.visible = true


## Populates anim clips grouped by situation pools.
func _build_clip_list() -> void:
	clip_order.clear()
	_clip_section("MULTIS")
	var game: PackedStringArray = ThrongTune.game_names()
	for clip in game:
		_add_clip_button(clip, _short(clip))
	_clip_section("RESTO")
	var rest: PackedStringArray = ThrongTune.rest_names()
	for clip in rest:
		_add_clip_button(clip, _short(clip))
	var last_group := ""
	var anim_ids: PackedStringArray = AnimTune.ids()
	for key in anim_ids:
		var row: Dictionary = AnimTune.entry(key)
		var group := str(row.get("group", ""))
		if group != last_group:
			_clip_section(group)
			last_group = group
		_add_clip_button("anim:" + key, str(row.get("label", key)))


## Section header in the scrollable clip list.
func _clip_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clip_list.add_child(label)


## One clip toggle with shortened label in anim rail.
func _add_clip_button(clip: String, title: String) -> void:
	var button := Button.new()
	button.text = title
	button.tooltip_text = clip
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 20)
	button.pressed.connect(_select_clip.bind(clip))
	clip_list.add_child(button)
	clip_buttons[clip] = button
	clip_order.append(clip)


## Whether a clip name is a multi-frame animation strip.
func _is_anim(clip: String) -> bool:
	return clip.begins_with("anim:")


## Filesystem key used by AnimTune for a clip.
func _anim_key(clip: String) -> String:
	return clip.substr(5)


## Short display label derived from a long clip name.
func _short(clip: String) -> String:
	if _is_anim(clip):
		return str(AnimTune.entry(_anim_key(clip)).get("label", clip))
	for prefix in ["ThrongA_", "ThrongB_", "ThrongC_", "ThrongD_", "ThrongE_", "Throng_", "Thronglet_"]:
		if clip.begins_with(prefix):
			return clip.substr(prefix.length())
	return clip


## Switches UI to anim review and ensures stage throng exists.
func _show_throng() -> void:
	throng_mode = true
	effect_mode = false
	lab_mode = false
	if path_lab != null:
		path_lab.close()
	rail.visible = false
	bar.visible = false
	if effect_rail:
		effect_rail.visible = false
	if effect_bar:
		effect_bar.visible = false
	if lab_rail:
		lab_rail.visible = false
	if lab_bar:
		lab_bar.visible = false
	if effect_ring:
		effect_ring.visible = false
	_hide_effect_need_bars()
	throng_rail.visible = true
	throng_bar.visible = true
	_clear_placed()
	_paint_ground()
	_ensure_stage()
	if clip_name == "":
		_select_clip("ThrongA_Default")
	else:
		if selected_clips.is_empty():
			selected_clips = [clip_name]
		_fill_clip()
		_mark_clips()
		_sync_play_button()
	_refresh_status()


## Switches UI back to prop layout mode.
func _show_props() -> void:
	throng_mode = false
	effect_mode = false
	lab_mode = false
	if path_lab != null:
		path_lab.close()
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	if effect_rail:
		effect_rail.visible = false
	if effect_bar:
		effect_bar.visible = false
	if lab_rail:
		lab_rail.visible = false
	if lab_bar:
		lab_bar.visible = false
	if effect_ring:
		effect_ring.visible = false
	_hide_effect_need_bars()
	_clear_placed()
	_paint_ground()
	rail.visible = true
	bar.visible = true
	_mark_buttons()
	_refresh_status()


## Switches UI to isolated effect preview mode.
func _show_effects() -> void:
	throng_mode = false
	effect_mode = true
	lab_mode = false
	if path_lab != null:
		path_lab.close()
	rail.visible = false
	bar.visible = false
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	if lab_rail:
		lab_rail.visible = false
	if lab_bar:
		lab_bar.visible = false
	effect_rail.visible = true
	effect_bar.visible = true
	if effect_id == "" or effect_id == "decay":
		_select_effect("goo")
	else:
		_fill_effect()
		_stage_effect()
		_mark_effects()
	_refresh_status()


## Switches UI to path piece lab (mask gallery + sprite picker).
func _show_path_lab() -> void:
	throng_mode = false
	effect_mode = false
	lab_mode = false
	rail.visible = false
	bar.visible = false
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	if effect_rail:
		effect_rail.visible = false
	if effect_bar:
		effect_bar.visible = false
	if lab_rail:
		lab_rail.visible = false
	if lab_bar:
		lab_bar.visible = false
	if effect_ring:
		effect_ring.visible = false
	_hide_effect_need_bars()
	_clear_placed()
	main.world_drawer.paint_props([])
	_paint_ground()
	main.cam_rig.set_zoom(1.6)
	main.camera.position = main.cam_rig.to_iso(Catalog.cell_world(Vector2i(12, 18)))
	if path_lab != null:
		path_lab.open()
	queue_redraw()
	_refresh_status()


## Guarantees throng:0 placement exists for anim/effect staging.
func _ensure_stage() -> void:
	for inst in placed:
		if str(inst.id) != THRONG_ID:
			continue
		if _primary_uid() < 0:
			_arm(THRONG_ID, int(inst.uid))
		return
	var uid := next_uid
	next_uid += 1
	placed.append({"uid": uid, "id": THRONG_ID, "at": Catalog.cell_world(Vector2i(8, 16))})
	_arm(THRONG_ID, uid)


## Arms one clip for editing and refreshes strip and inspector.
func _select_clip(clip: String) -> void:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var meta := Input.is_key_pressed(KEY_META)
	if shift and meta and clip_name != "":
		_range_clips(clip)
		return
	if shift and clip_name != "":
		_toggle_clip(clip)
		return
	clip_name = clip
	selected_clips = [clip]
	clip_anchor = clip
	selected_frames.clear()
	frame_i = 0
	frame_anchor = 0
	play_t = 0.0
	playing = true
	_rot_shown = -1
	_build_strip()
	_fill_clip()
	_mark_clips()
	_sync_play_button()


## Adds or removes a clip from multi-select in anim mode.
func _toggle_clip(clip: String) -> void:
	var at := selected_clips.find(clip)
	if at >= 0:
		if selected_clips.size() <= 1:
			return
		selected_clips.remove_at(at)
		if clip == clip_name:
			clip_name = str(selected_clips[selected_clips.size() - 1])
			selected_frames.clear()
			frame_i = 0
			frame_anchor = 0
			play_t = 0.0
			_rot_shown = -1
			_build_strip()
			_fill_clip()
	else:
		selected_clips.append(clip)
	_mark_clips()
	_sync_play_button()
	if throng_name and clip_name != "":
		throng_name.text = _clip_title()


## Shift-selects a span of clip list buttons.
func _range_clips(clip: String) -> void:
	var anchor := clip_anchor if clip_anchor != "" else clip_name
	var a := clip_order.find(anchor)
	var b := clip_order.find(clip)
	if a < 0 or b < 0:
		_toggle_clip(clip)
		return
	var lo := mini(a, b)
	var hi := maxi(a, b)
	selected_clips.clear()
	for i in range(lo, hi + 1):
		selected_clips.append(str(clip_order[i]))
	var focus_changed := clip != clip_name
	clip_name = clip
	if focus_changed:
		selected_frames.clear()
		frame_i = 0
		frame_anchor = 0
		play_t = 0.0
		_rot_shown = -1
		_build_strip()
		_fill_clip()
	_mark_clips()
	_sync_play_button()
	if throng_name:
		throng_name.text = _clip_title()


## Clip names receiving edits when apply_all or multi-select.
func _edit_clips() -> Array:
	if not selected_clips.is_empty():
		return selected_clips.duplicate()
	if clip_name != "":
		return [clip_name]
	return []


## Steps playhead to next frame or next clip in clip_order.
func _advance() -> void:
	var now := Time.get_ticks_msec()
	if play_ms == 0:
		play_ms = now
	var dt := minf(float(now - play_ms) / 1000.0, 0.1)
	play_ms = now
	if throng_mode and playing and clip_name != "":
		play_t += dt
	if effect_mode and effect_playing and effect_id != "":
		effect_t += dt
		_tick_effect(dt)
	if lab_mode and lab_running:
		_lab_step(dt)


## Grid dimensions of one clip strip from ThrongClips metadata.
func _box_of(clip: String) -> Vector2i:
	if _is_anim(clip):
		var row: Dictionary = AnimTune.entry(_anim_key(clip))
		return Vector2i(int(row.get("start", 0)), int(row.get("count", 1)))
	var raw: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(ThrongClips.BASE, 1))
	return raw


## Grid dimensions of the currently armed clip.
func _box() -> Vector2i:
	return _box_of(clip_name)


## Effective preview FPS from AnimTune or clip default.
func _clip_fps() -> float:
	if _is_anim(clip_name):
		return float(AnimTune.get_tune(_anim_key(clip_name)).get("fps", 8.0))
	return float(ThrongTune.get_tune(clip_name).get("fps", 8.0))


## World offset applied to throng preview from ThrongTune.
func _shown_off() -> Vector2:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_offset(_anim_key(clip_name), index)
	return ThrongTune.frame_offset(clip_name, index)


## Rotation degrees applied to throng preview.
func _shown_rot() -> float:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_rot(_anim_key(clip_name), index)
	return ThrongTune.frame_rot(clip_name, index)


## Sprite scale applied to throng preview.
func _shown_scale() -> float:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_scale(_anim_key(clip_name), index)
	return ThrongTune.frame_scale(clip_name, index)


## Frame index currently shown on the strip.
func _shown_index() -> int:
	var n := maxi(_box().y, 1)
	if not playing:
		return clampi(frame_i, 0, n - 1)
	return posmod(int(play_t * _clip_fps()), n)


## Display string for throng_name including multi-select hint.
func _clip_title() -> String:
	var n := maxi(_box().y, 1)
	var title := "%s   %d/%d" % [_short(clip_name), _shown_index() + 1, n]
	if selected_clips.size() > 1:
		title += "  +%d CLIPS" % (selected_clips.size() - 1)
	elif selected_frames.size() > 1:
		title += "  +%d FRAMES" % (selected_frames.size() - 1)
	if clip_name == BATH_CLIP:
		return title + "  + BANERA"
	if clip_name == RIDE_CLIP:
		return title + "  + TIOVIVO"
	return title


## Draws throng preview meshes using ThrongTune offsets.
func _paint_tuned(draws: Array, origin: Vector2, alpha: float) -> void:
	if clip_name == "":
		return
	if _is_anim(clip_name):
		_paint_anim(draws, origin, alpha)
		return
	var off: Vector2 = ThrongTune.frame_offset(clip_name, _shown_index())
	var frame := _box().x + _shown_index()
	var pos := origin + off
	var lift := 0.0
	var sort_y := NAN
	var kind := _partner_kind(clip_name)
	if kind >= 0:
		var before := draws.size()
		var prop_frame := -1
		if kind == Catalog.BLD_ROUND:
			prop_frame = posmod(_shown_index(), StructureTextures.ROUND_ANIM_N)
		_paint_building(draws, kind, origin, alpha, prop_frame)
		if draws.size() > before:
			sort_y = float(draws[draws.size() - 1].get("sy", 0.0)) + 1.0
		if kind == Catalog.BLD_TUB:
			pos = origin + Catalog.TUB_SEAT_OFF + off
			lift = _bath_lift(_shown_index())
	main.iso_draw.push_iso(draws, pos, frame, Color(1, 1, 1, alpha), lift, ThrongTune.frame_scale(clip_name, _shown_index()))
	draws[draws.size() - 1]["rot"] = ThrongTune.frame_rot(clip_name, _shown_index())
	if not is_nan(sort_y):
		draws[draws.size() - 1]["sy"] = sort_y
	if mirror:
		draws[draws.size() - 1]["flip"] = -1.0


## Draws one or more clips in sequence for live preview.
func _paint_anim(draws: Array, origin: Vector2, alpha: float) -> void:
	var key := _anim_key(clip_name)
	var index := _shown_index()
	var off: Vector2 = AnimTune.frame_offset(key, index)
	var scale := AnimTune.frame_scale(key, index)
	if key == "round" or key == "flower":
		var kind := Catalog.BLD_ROUND if key == "round" else Catalog.BLD_FLOWER
		if key == "round":
			scale = Catalog.building_sprite_scale(Catalog.BLD_ROUND) * scale
		else:
			scale = Catalog.building_sprite_scale(Catalog.BLD_FLOWER) * scale
		_paint_building(draws, kind, origin + off, alpha, index)
		if not draws.is_empty():
			draws[draws.size() - 1]["rot"] = AnimTune.frame_rot(key, index)
		return
	var frame := _box().x + index
	main.iso_draw.push_iso(draws, origin + off, frame, Color(1, 1, 1, alpha), 0.0, scale)
	draws[draws.size() - 1]["rot"] = AnimTune.frame_rot(key, index)
	if mirror:
		draws[draws.size() - 1]["flip"] = -1.0


## Building kind drawn as clip partner (tub, round, etc.).
func _partner_kind(clip: String) -> int:
	if clip == BATH_CLIP:
		return Catalog.BLD_TUB
	if clip == RIDE_CLIP:
		return Catalog.BLD_ROUND
	return -1


## Extra Y lift for bath clip frames on the pad.
func _bath_lift(index: int) -> float:
	if index >= 5:
		return Catalog.TUB_SOAK_LIFT
	return lerpf(Catalog.TUB_ENTER_LIFT, Catalog.TUB_SOAK_LIFT, float(index) / 4.0)


## Draws static or animated building preview for a kind.
func _paint_building(draws: Array, kind: int, origin: Vector2, alpha: float, frame_override: int) -> void:
	var row: Dictionary = PropTune.entry("building:%d" % kind)
	if row.is_empty():
		return
	var tune: Dictionary = PropTune.get_tune(str(row.id))
	if _want_active_sprite(kind):
		_paint_active_building(draws, kind, origin, alpha, EFFECT_ACTIVE_UID, _node_used, tune)
		return
	if kind == Catalog.BLD_ROUND or kind == Catalog.BLD_FLOWER:
		_paint_structure_anim(draws, kind, origin, alpha, frame_override, tune, EFFECT_ACTIVE_UID, _node_used)
		return
	if main.structure_tex.idle_structure_texture(kind) != null:
		_paint_idle_structure(draws, kind, origin, alpha, tune, EFFECT_ACTIVE_UID, _node_used)
		return
	var frame := frame_override
	if frame < 0:
		frame = _frame_of(row)
	var at: Vector2 = _anchor(row, origin, tune, frame)
	var tint := Color(1, 1, 1, alpha)
	if kind == Catalog.BLD_TUB:
		tint = Color(0.85, 0.95, 1.0, alpha)
	main.iso_draw.push_iso(draws, at, frame, tint, 0.0, float(tune.scale))
	var last: Dictionary = draws[draws.size() - 1]
	last["sy"] = float(last.get("sy", last.p.y)) + float(tune.z)
	last["rot"] = float(tune.rot)


## Paints idle structure texture for bench preview.
func _paint_idle_structure(
	draws: Array,
	kind: int,
	origin: Vector2,
	alpha: float,
	tune: Dictionary,
	uid: int,
	used: Dictionary
) -> void:
	var tex: Texture2D = main.structure_tex.idle_structure_texture(kind)
	if tex == null:
		return
	var frame: int = main.anim_frames.prop_frame(Catalog.icon_for_building(kind))
	var size: Vector2i = tune.get("footprint", Vector2i(1, 1))
	var sprite_scale := float(tune.scale)
	var extra: Vector2 = tune.offset if tune.has("offset") else Vector2.ZERO
	var at: Vector2 = origin + Catalog.footprint_center(size) + main.iso_draw.pad_nudge(frame, sprite_scale, size) + extra
	var tint := Color(1, 1, 1, alpha)
	if kind == Catalog.BLD_TUB:
		tint = Color(0.85, 0.95, 1.0, alpha)
	var screen_p: Vector2 = main.cam_rig.to_iso(at)
	var node: Sprite2D = _take_structure_sprite(uid, tex)
	node.scale = Vector2(sprite_scale, sprite_scale)
	node.rotation_degrees = float(tune.rot)
	node.modulate = tint
	node.position = screen_p + main.structure_tex.structure_sprite_lift(tex, sprite_scale)
	node.visible = true
	used[uid] = true
	draws.append({
		"p": screen_p,
		"sy": screen_p.y + float(tune.z),
		"icon": frame,
		"tint": tint,
		"scale": sprite_scale,
		"meta_only": true,
	})


## Paints looping structure animation frames.
func _paint_structure_anim(
	draws: Array,
	kind: int,
	origin: Vector2,
	alpha: float,
	anim_idx: int,
	tune: Dictionary,
	uid: int,
	used: Dictionary
) -> void:
	var idx := anim_idx
	if idx < 0:
		idx = _frame_of(PropTune.entry("building:%d" % kind))
	var tex: Texture2D = main.structure_tex.structure_anim_texture(kind, idx)
	if tex == null:
		tex = main.structure_tex.idle_structure_texture(kind)
	if tex == null:
		return
	var frame: int = main.anim_frames.prop_frame(Catalog.icon_for_building(kind))
	var size: Vector2i = tune.get("footprint", Vector2i(1, 1))
	var sprite_scale := float(tune.scale)
	if kind == Catalog.BLD_ROUND:
		sprite_scale *= AnimTune.frame_scale("round", idx)
	var extra: Vector2 = tune.offset if tune.has("offset") else Vector2.ZERO
	var at: Vector2 = origin + Catalog.footprint_center(size) + main.iso_draw.pad_nudge(frame, sprite_scale, size) + extra
	if kind == Catalog.BLD_ROUND:
		at += AnimTune.frame_offset("round", idx)
	elif kind == Catalog.BLD_FLOWER:
		at += AnimTune.frame_offset("flower", idx)
	var screen_p: Vector2 = main.cam_rig.to_iso(at)
	var node: Sprite2D = _take_structure_sprite(uid, tex)
	node.scale = Vector2(sprite_scale, sprite_scale)
	node.rotation_degrees = float(tune.rot)
	if kind == Catalog.BLD_ROUND:
		node.rotation_degrees += AnimTune.frame_rot("round", idx)
	node.modulate = Color(1, 1, 1, alpha)
	node.position = screen_p + main.structure_tex.structure_sprite_lift(tex, sprite_scale)
	node.visible = true
	used[uid] = true
	# Sort bookkeeping only — Sprite2D already draws the frame. Painting this row
	# would also blit the atlas default under the anim (flower/round double sprite).
	draws.append({
		"p": screen_p,
		"sy": screen_p.y + float(tune.z),
		"icon": frame,
		"tint": Color(1, 1, 1, alpha),
		"scale": sprite_scale,
		"meta_only": true,
	})


## Borrows Sprite2D for a structure layer texture.
func _take_structure_sprite(uid: int, tex: Texture2D) -> Sprite2D:
	if nodes.has(uid) and is_instance_valid(nodes[uid]) and nodes[uid] is Sprite2D:
		var kept: Sprite2D = nodes[uid]
		kept.texture = tex
		return kept
	if nodes.has(uid) and is_instance_valid(nodes[uid]):
		nodes[uid].queue_free()
		nodes.erase(uid)
	var node := Sprite2D.new()
	node.centered = true
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.texture = tex
	main.world_layer.add_child(node)
	nodes[uid] = node
	return node


## Draws partner footprint outlines for clip partners.
func _stroke_partner(poly: PackedVector2Array) -> void:
	if not throng_mode:
		return
	var kind := _partner_kind(clip_name)
	if kind < 0:
		return
	var tune: Dictionary = PropTune.get_tune("building:%d" % kind)
	var edge := Color(0.55, 0.75, 1.0, 0.7)
	var fill := Color(0.4, 0.65, 1.0, 0.1)
	for inst in placed:
		if str(inst.id) != THRONG_ID:
			continue
		for cell in _cells(_live_at(inst), tune.footprint):
			_stroke(cell, poly, edge, fill)


## Advances frame_i from play_t and clip FPS when playing.
func _sync_playhead() -> void:
	if throng_name and clip_name != "":
		throng_name.text = _clip_title()
	_mark_frames()
	_sync_rot_box()


## Pushes shown rotation into rot spin without feedback loop.
func _sync_rot_box() -> void:
	if throng_rot == null or clip_name == "":
		return
	var index := _shown_index()
	if index == _rot_shown:
		return
	_rot_shown = index
	var off: Vector2 = _shown_off()
	_fill = true
	throng_x.set_value_no_signal(off.x)
	throng_y.set_value_no_signal(off.y)
	throng_rot.set_value_no_signal(_shown_rot())
	throng_scale.set_value_no_signal(_shown_scale())
	_fill = false


## Toggles playing and play button state in anim mode.
func _toggle_play() -> void:
	if clip_name == "":
		return
	if playing:
		frame_i = _shown_index()
		playing = false
	else:
		playing = true
	_sync_play_button()
	_sync_playhead()


## Flips mirror flag and repaints throng preview.
func _toggle_mirror() -> void:
	mirror = not mirror
	_sync_play_button()


## Steps playhead forward or backward by one frame.
func _step(dir: int) -> void:
	if clip_name == "":
		return
	var n := maxi(_box().y, 1)
	frame_i = posmod(_shown_index() + dir, n)
	playing = false
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var meta := Input.is_key_pressed(KEY_META)
	if shift and meta:
		_range_frames(frame_i)
		return
	if not shift:
		selected_frames = [frame_i]
		frame_anchor = frame_i
		apply_all = false
	elif selected_frames.find(frame_i) < 0:
		if selected_frames.is_empty():
			selected_frames.append(posmod(frame_i - dir, n))
		selected_frames.append(frame_i)
		apply_all = false
	_sync_play_button()
	_sync_playhead()


## Updates play button label from playing flag.
func _sync_play_button() -> void:
	if play_button:
		play_button.text = "PAUSA" if playing else "PLAY"
	if mirror_button:
		mirror_button.modulate = Color(1, 0.86, 0.4) if mirror else Color.WHITE
	if all_button:
		all_button.modulate = Color(1, 0.86, 0.4) if apply_all else Color.WHITE


## Rebuilds per-frame pin buttons for the armed clip.
func _build_strip() -> void:
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	frame_buttons.clear()
	var box := _box()
	var keep: Array = []
	for raw in selected_frames:
		var index := int(raw)
		if index >= 0 and index < box.y:
			keep.append(index)
	selected_frames = keep
	for i in box.y:
		var button := Button.new()
		button.icon = main.world_drawer.cell_tex(box.x + i)
		button.custom_minimum_size = Vector2(28, 28)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_pin_frame.bind(i))
		strip.add_child(button)
		frame_buttons.append(button)


## Toggles whether a frame index is pinned on the strip.
func _pin_frame(i: int) -> void:
	playing = false
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var meta := Input.is_key_pressed(KEY_META)
	if shift and meta:
		_range_frames(i)
		return
	if shift:
		_toggle_frame(i)
		return
	selected_frames = [i]
	frame_i = i
	frame_anchor = i
	apply_all = false
	_sync_play_button()
	_sync_playhead()


## Multi-select one frame index on the strip.
func _toggle_frame(i: int) -> void:
	apply_all = false
	var at := selected_frames.find(i)
	if at >= 0:
		if selected_frames.size() <= 1:
			frame_i = i
			_sync_play_button()
			_sync_playhead()
			return
		selected_frames.remove_at(at)
		frame_i = int(selected_frames[selected_frames.size() - 1])
	else:
		if selected_frames.is_empty():
			selected_frames.append(frame_i)
		if selected_frames.find(i) < 0:
			selected_frames.append(i)
		frame_i = i
	_sync_play_button()
	_sync_playhead()


## Shift-selects a span of frame indexes.
func _range_frames(i: int) -> void:
	apply_all = false
	var n := maxi(_box().y, 1)
	var anchor := clampi(frame_anchor, 0, n - 1)
	var target := clampi(i, 0, n - 1)
	var lo := mini(anchor, target)
	var hi := maxi(anchor, target)
	selected_frames.clear()
	for index in range(lo, hi + 1):
		selected_frames.append(index)
	frame_i = target
	_sync_play_button()
	_sync_playhead()


## Loads AnimTune values into strip and transport controls.
func _fill_clip() -> void:
	if clip_name == "" or fps_box == null:
		return
	var tune: Dictionary = AnimTune.get_tune(_anim_key(clip_name)) if _is_anim(clip_name) else ThrongTune.get_tune(clip_name)
	_fill = true
	fps_box.editable = AnimTune.fps_editable(_anim_key(clip_name)) if _is_anim(clip_name) else ThrongTune.fps_editable(clip_name)
	fps_box.set_value_no_signal(float(tune.get("fps", 8.0)))
	_fill = false
	_rot_shown = -1
	_sync_rot_box()
	if throng_name:
		throng_name.text = _clip_title()


## Resets AnimTune defaults for edit target clips.
func _reset_clip() -> void:
	var clips := _edit_clips()
	if clips.is_empty():
		return
	for clip in clips:
		if _is_anim(str(clip)):
			AnimTune.reset(_anim_key(str(clip)))
		else:
			ThrongTune.reset(str(clip))
	_fill_clip()
	_mark_clips()
	_refresh_status()


## Filters visible clip buttons by substring match.
func _on_filter(text: String) -> void:
	var q := text.strip_edges().to_lower()
	for key in clip_buttons.keys():
		var button: Button = clip_buttons[key]
		var clip := str(key)
		button.visible = q == "" or q in clip.to_lower() or q in _short(clip).to_lower()


## Updates pressed state for clip list buttons.
func _mark_clips() -> void:
	var picked := {}
	for clip in _edit_clips():
		picked[str(clip)] = true
	for key in clip_buttons.keys():
		var button: Button = clip_buttons[key]
		var clip := str(key)
		var dirty: bool = AnimTune.is_dirty(_anim_key(clip)) if _is_anim(clip) else ThrongTune.is_dirty(clip)
		if picked.has(clip):
			button.modulate = Color(1, 0.86, 0.4)
		elif dirty:
			button.modulate = Color(0.65, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE


## Updates pressed state for strip frame buttons.
func _mark_frames() -> void:
	var index := _shown_index()
	var picked := {}
	if apply_all or selected_clips.size() > 1:
		for i in frame_buttons.size():
			picked[i] = true
	elif not selected_frames.is_empty():
		for raw in selected_frames:
			picked[int(raw)] = true
	else:
		picked[index] = true
	for i in frame_buttons.size():
		var button: Button = frame_buttons[i]
		if not is_instance_valid(button):
			continue
		button.modulate = Color(1, 0.86, 0.4) if picked.has(i) else Color.WHITE


## Persists FPS override to AnimTune for edit targets.
func _on_throng_fps(v: float) -> void:
	if _fill or clip_name == "":
		return
	for clip in _edit_clips():
		if _is_anim(str(clip)):
			if AnimTune.fps_editable(_anim_key(str(clip))):
				AnimTune.set_fps(_anim_key(str(clip)), v)
		elif ThrongTune.fps_editable(str(clip)):
			ThrongTune.set_fps(str(clip), v)
	_mark_clips()
	_refresh_status()


## Flips apply_all and refreshes clip status.
func _toggle_all() -> void:
	apply_all = not apply_all
	if apply_all:
		selected_frames.clear()
	_sync_play_button()
	_mark_frames()


## Frame indexes edited on one clip via multi-select.
func _edit_indexes_for(clip: String) -> Array:
	var indexes: Array = []
	var n := maxi(_box_of(clip).y, 1)
	var multi_clip := selected_clips.size() > 1
	if multi_clip or apply_all:
		for i in n:
			indexes.append(i)
		return indexes
	if not selected_frames.is_empty():
		for raw in selected_frames:
			var index := int(raw)
			if index >= 0 and index < n:
				indexes.append(index)
		if not indexes.is_empty():
			return indexes
	indexes.append(clampi(_shown_index(), 0, n - 1))
	return indexes


## Clip names that receive frame and offset edits.
func _edit_targets() -> Array:
	var targets: Array = []
	for clip in _edit_clips():
		var name := str(clip)
		for index in _edit_indexes_for(name):
			targets.append({"clip": name, "index": int(index)})
	return targets


## Frame index held when play is paused on the strip.
func _hold_frame() -> int:
	var index := _shown_index()
	if playing:
		frame_i = index
		playing = false
		if selected_frames.is_empty() and not apply_all and selected_clips.size() <= 1:
			selected_frames = [index]
		_sync_play_button()
	return index


## Writes throng scale from spin to ThrongTune.
func _on_throng_scale(v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for target in _edit_targets():
		var clip := str(target.clip)
		var index := int(target.index)
		if _is_anim(clip):
			AnimTune.set_frame_scale(_anim_key(clip), index, v)
		else:
			ThrongTune.set_frame_scale(clip, index, v)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()


## Writes throng offset from spins to ThrongTune.
func _on_throng_offset(_v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for target in _edit_targets():
		var clip := str(target.clip)
		var index := int(target.index)
		if _is_anim(clip):
			AnimTune.set_frame_offset(_anim_key(clip), index, throng_x.value, throng_y.value)
		else:
			ThrongTune.set_frame_offset(clip, index, throng_x.value, throng_y.value)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()


## Writes throng rotation from spin to ThrongTune.
func _on_throng_rot(v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for target in _edit_targets():
		var clip := str(target.clip)
		var index := int(target.index)
		if _is_anim(clip):
			AnimTune.set_frame_rot(_anim_key(clip), index, v)
		else:
			ThrongTune.set_frame_rot(clip, index, v)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()


# -------------------------------------------------------------------
# TIovivo / carousel lab
# -------------------------------------------------------------------

## Switches UI to tiovivo carousel lab and syncs cfg.
func _show_lab() -> void:
	throng_mode = false
	effect_mode = false
	lab_mode = true
	if path_lab != null:
		path_lab.close()
	rail.visible = false
	bar.visible = false
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	if effect_rail:
		effect_rail.visible = false
	if effect_bar:
		effect_bar.visible = false
	if effect_ring:
		effect_ring.visible = false
	_hide_effect_need_bars()
	if lab_rail:
		lab_rail.visible = true
	if lab_bar:
		lab_bar.visible = true
	_clear_placed()
	_paint_ground()
	if lab_carousel.is_empty():
		lab_cfg = TiovivoLabTune.load_saved()
		_lab_reset_state(true)
	else:
		_lab_sync_ui_from_cfg()
	_refresh_status()
	_lab_set_status("LAB TIOVIVO LISTO")


## Builds carousel tuning rail and lab action bar.
func _build_lab_ui(theme: Theme, root: Control) -> void:
	lab_rail = PanelContainer.new()
	lab_rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	lab_rail.offset_left = 4
	lab_rail.offset_top = 4
	lab_rail.offset_right = 220
	lab_rail.offset_bottom = -4
	lab_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	lab_rail.theme = theme
	lab_rail.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	lab_rail.add_child(scroll)
	root.add_child(lab_rail)

	var hint := Label.new()
	hint.text = "CLICK: selecciona/mueve thronglet o tiovivo. CLICK vacio: mueve tiovivo. SHIFT+CLICK: añade thronglet. DEL: borra. SPACE: pausa. Config guarda en dev/tiovivo_lab.json."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

	v.add_child(_lab_section("TIOVIVO / GIRO"))
	_lab_add_spin(v, "CX", "carousel", "center_offset_x", -64, 64, 0.5, "Offset X del centro de giro (mundo)")
	_lab_add_spin(v, "CY", "carousel", "center_offset_y", -64, 64, 0.5, "Offset Y del centro de giro (mundo)")
	_lab_add_spin(v, "DIST", "carousel", "seat_spacing", 0.0, 80.0, 0.5, "Distancia entre plazas montadas (separacion entre thronglets)")
	_lab_add_spin(v, "SLOTS", "carousel", "slots", 1, 12, 1, "Numero de plazas", true)
	_lab_add_spin(v, "GIRO", "carousel", "spin_speed", -12.0, 12.0, 0.1, "Velocidad de giro (rad/s)")
	_lab_add_spin(v, "ANG0", "carousel", "slot_base_deg", -180, 180, 5, "Angulo base de las plazas (puntos concretos sobre el carrusel)")
	_lab_add_option(v, "MIRAN", "carousel", "face_mode", ["inward", "outward", "tangent", "spin"], "Hacia donde miran los thronglets montados")
	_lab_add_spin(v, "DIR", "carousel", "sprite_dir_offset", -8, 8, 1, "Ajuste de frame direccional del thronglet (0-7) segun su posicion en el carrusel", true)
	_lab_add_toggle(v, "DIR GIRO", "carousel", "sprite_dir_follow", "Cambiar sprite segun gira en el carrusel (si no, sprite fijo por plaza)")
	_lab_add_spin(v, "STAY", "carousel", "min_stay", 0.0, 60.0, 0.5, "Permanencia minima montado (s)")
	_lab_add_spin(v, "FUN/s", "carousel", "ride_fun_rate", 0.0, 20.0, 0.25, "Diversion por segundo montado")
	_lab_add_spin(v, "DONE", "carousel", "ride_done", 0.0, 100.0, 1.0, "Diversion objetivo para bajar")

	v.add_child(_lab_section("SINCRONIZACION"))
	_lab_add_option(v, "MODO", "sync", "mode", ["continuous", "interval", "wave"], "Modo de entrada: continuo, intervalo fijo, u oleadas")
	_lab_add_spin(v, "INTER", "sync", "interval", 0.0, 30.0, 0.25, "Intervalo minimo entre entradas (s)")
	_lab_add_spin(v, "OLEADA", "sync", "wave_size", 1, 12, 1, "Entradas por oleada", true)
	_lab_add_spin(v, "PAUSA", "sync", "wave_pause", 0.0, 30.0, 0.25, "Pausa entre oleadas (s)")
	_lab_add_spin(v, "ABORD", "sync", "max_boarding", 1, 12, 1, "Maximo abordando a la vez", true)
	_lab_add_spin(v, "DELAY", "sync", "initial_delay", 0.0, 30.0, 0.25, "Retardo inicial antes de abrir")
	_lab_add_toggle(v, "COLA", "sync", "queue", "Respetar cola/turno (evita apelotonarse)")
	_lab_add_toggle(v, "REENTRA", "sync", "reenter", "Tras bajar, vuelven a intentar entrar")

	v.add_child(_lab_section("THRONGLETS"))
	_lab_add_spin(v, "N", "spawn", "count", 1, 40, 1, "Cantidad para (re)generar", true)
	_lab_add_spin(v, "ANILLO", "spawn", "ring_radius", 20.0, 240.0, 5.0, "Radio de aparicion alrededor del tiovivo")
	_lab_add_spin(v, "FUN0", "spawn", "initial_fun", 0.0, 100.0, 5.0, "Diversion inicial")

	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 4)
	spawn_row.add_child(_text_button("+1", func(): _lab_spawn(1)))
	spawn_row.add_child(_text_button("+5", func(): _lab_spawn(5)))
	spawn_row.add_child(_text_button("GENERAR", _lab_respawn_all))
	spawn_row.add_child(_text_button("LIMPIAR", _lab_clear_agents))
	v.add_child(spawn_row)

	lab_bar = PanelContainer.new()
	lab_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lab_bar.offset_left = 228
	lab_bar.offset_top = -132
	lab_bar.offset_right = -4
	lab_bar.offset_bottom = -4
	lab_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	lab_bar.theme = theme
	lab_bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	lab_name = Label.new()
	lab_name.text = "LABORATORIO TIOVIVO"
	lab_name.clip_text = true
	box.add_child(lab_name)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(_text_button("PAUSA/PLAY", _lab_toggle_run))
	actions.add_child(_text_button("STEP", _lab_step_once))
	actions.add_child(_text_button("RESET", func(): _lab_reset_state(true)))
	actions.add_child(_text_button("GUARDAR JSON", _lab_save))
	actions.add_child(_text_button("CARGAR JSON", _lab_load))
	actions.add_child(_text_button("PROPS", _show_props))
	actions.add_child(_text_button("ANIM", _show_throng))
	actions.add_child(_text_button("EFFECTS", _show_effects))
	actions.add_child(_text_button("LAB PATH", _show_path_lab))
	actions.add_child(_text_button("MENU", main._leave_dev))
	lab_status = Label.new()
	lab_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab_status.clip_text = true
	actions.add_child(lab_status)
	box.add_child(actions)
	lab_bar.add_child(box)
	root.add_child(lab_bar)


## Centered section title for lab tuning groups.
func _lab_section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Reads nested lab_cfg group/key with optional default.
func _lab_cfg_get(group: String, key: String, def = null):
	if not lab_cfg.has(group):
		return def
	var g = lab_cfg[group]
	if typeof(g) == TYPE_DICTIONARY and g.has(key):
		return g[key]
	return def


## Writes one key into nested lab_cfg group dict.
func _lab_cfg_set(group: String, key: String, value) -> void:
	if not lab_cfg.has(group) or typeof(lab_cfg[group]) != TYPE_DICTIONARY:
		lab_cfg[group] = {}
	lab_cfg[group][key] = value


## Adds a labeled spin bound to lab_cfg with tooltip.
func _lab_add_spin(parent: VBoxContainer, title: String, group: String, key: String, mn: float, mx: float, step: float, tip: String, whole: bool = false) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(54, 0)
	label.tooltip_text = tip
	row.add_child(label)
	var box := _spin(mn, mx, step, whole)
	box.tooltip_text = tip
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	parent.add_child(row)
	var skey := "%s:%s" % [group, key]
	lab_spins[skey] = box
	box.value_changed.connect(func(v): _lab_on_spin(group, key, v, whole))
	return box


## Adds a labeled option row bound to lab_cfg.
func _lab_add_option(parent: VBoxContainer, title: String, group: String, key: String, opts: Array, tip: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(54, 0)
	label.tooltip_text = tip
	row.add_child(label)
	var ob := OptionButton.new()
	ob.tooltip_text = tip
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in opts:
		ob.add_item(str(o))
	row.add_child(ob)
	parent.add_child(row)
	var skey := "%s:%s" % [group, key]
	lab_spins[skey] = ob
	ob.item_selected.connect(func(_i): _lab_on_option(group, key, ob))
	return ob


## Adds a checkbox row bound to lab_cfg.
func _lab_add_toggle(parent: VBoxContainer, title: String, group: String, key: String, tip: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = title
	cb.tooltip_text = tip
	parent.add_child(cb)
	var skey := "%s:%s" % [group, key]
	lab_spins[skey] = cb
	cb.toggled.connect(func(v): _lab_on_toggle(group, key, v))
	return cb


## Persists spin edits into lab_cfg including center_offset pair.
func _lab_on_spin(group: String, key: String, v: float, whole: bool) -> void:
	if _fill:
		return
	# special mapping for vector-like offsets stored as arrays
	if group == "carousel" and key == "center_offset_x":
		var arr = lab_cfg.get("carousel", {}).get("center_offset", [18.0, 18.0])
		if typeof(arr) != TYPE_ARRAY or arr.size() < 2:
			arr = [18.0, 18.0]
		arr[0] = v
		_lab_cfg_set("carousel", "center_offset", arr)
	elif group == "carousel" and key == "center_offset_y":
		var arr = lab_cfg.get("carousel", {}).get("center_offset", [18.0, 18.0])
		if typeof(arr) != TYPE_ARRAY or arr.size() < 2:
			arr = [18.0, 18.0]
		arr[1] = v
		_lab_cfg_set("carousel", "center_offset", arr)
	else:
		_lab_cfg_set(group, key, int(v) if whole else v)
	_lab_apply_cfg_to_runtime()


## Persists option button selection into lab_cfg.
func _lab_on_option(group: String, key: String, ob: OptionButton) -> void:
	if _fill:
		return
	_lab_cfg_set(group, key, ob.get_item_text(ob.selected))
	_lab_apply_cfg_to_runtime()


## Persists checkbox value into lab_cfg.
func _lab_on_toggle(group: String, key: String, v: bool) -> void:
	if _fill:
		return
	_lab_cfg_set(group, key, v)
	_lab_apply_cfg_to_runtime()


## Pushes lab_cfg into all lab_spins without firing signals.
func _lab_sync_ui_from_cfg() -> void:
	_fill = true
	var car: Dictionary = lab_cfg.get("carousel", {})
	var off = car.get("center_offset", [18.0, 18.0])
	var offx := float(off[0]) if typeof(off) == TYPE_ARRAY and off.size() > 0 else 12.0
	var offy := float(off[1]) if typeof(off) == TYPE_ARRAY and off.size() > 1 else 12.0
	_lab_set_spin("carousel:center_offset_x", offx)
	_lab_set_spin("carousel:center_offset_y", offy)
	_lab_set_spin("carousel:seat_spacing", float(car.get("seat_spacing", 0.0)))
	_lab_set_spin("carousel:slots", int(car.get("slots", 4)))
	_lab_set_spin("carousel:spin_speed", float(car.get("spin_speed", -2.8)))
	_lab_set_spin("carousel:slot_base_deg", float(car.get("slot_base_deg", 0.0)))
	_lab_set_option("carousel:face_mode", str(car.get("face_mode", "inward")))
	_lab_set_spin("carousel:sprite_dir_offset", int(car.get("sprite_dir_offset", 4)))
	_lab_set_check("carousel:sprite_dir_follow", bool(car.get("sprite_dir_follow", true)))
	_lab_set_spin("carousel:min_stay", float(car.get("min_stay", 8.0)))
	_lab_set_spin("carousel:ride_fun_rate", float(car.get("ride_fun_rate", 2.5)))
	_lab_set_spin("carousel:ride_done", float(car.get("ride_done", 95.0)))
	var sync: Dictionary = lab_cfg.get("sync", {})
	_lab_set_option("sync:mode", str(sync.get("mode", "continuous")))
	_lab_set_spin("sync:interval", float(sync.get("interval", 2.0)))
	_lab_set_spin("sync:wave_size", int(sync.get("wave_size", 1)))
	_lab_set_spin("sync:wave_pause", float(sync.get("wave_pause", 4.0)))
	_lab_set_spin("sync:max_boarding", int(sync.get("max_boarding", 1)))
	_lab_set_spin("sync:initial_delay", float(sync.get("initial_delay", 0.0)))
	_lab_set_check("sync:queue", bool(sync.get("queue", true)))
	_lab_set_check("sync:reenter", bool(sync.get("reenter", true)))
	var sp: Dictionary = lab_cfg.get("spawn", {})
	_lab_set_spin("spawn:count", int(sp.get("count", 6)))
	_lab_set_spin("spawn:ring_radius", float(sp.get("ring_radius", 80.0)))
	_lab_set_spin("spawn:initial_fun", float(sp.get("initial_fun", 20.0)))
	_fill = false


## Sets one lab spin value by group:key string.
func _lab_set_spin(key: String, v) -> void:
	if not lab_spins.has(key):
		return
	var n = lab_spins[key]
	if n is SpinBox:
		(n as SpinBox).set_value_no_signal(float(v))


## Selects option text for one lab group:key control.
func _lab_set_option(key: String, v: String) -> void:
	if not lab_spins.has(key):
		return
	var n = lab_spins[key]
	if n is OptionButton:
		var ob := n as OptionButton
		for i in ob.item_count:
			if ob.get_item_text(i) == v:
				ob.select(i)
				return


## Sets checked state for one lab toggle control.
func _lab_set_check(key: String, v: bool) -> void:
	if not lab_spins.has(key):
		return
	var n = lab_spins[key]
	if n is CheckBox:
		(n as CheckBox).set_pressed_no_signal(v)


## Copies lab_cfg carousel fields into lab_carousel runtime.
func _lab_apply_cfg_to_runtime() -> void:
	if lab_carousel.is_empty():
		return
	var car: Dictionary = lab_cfg.get("carousel", {})
	var off = car.get("center_offset", [18.0, 18.0])
	var offx := float(off[0]) if typeof(off) == TYPE_ARRAY and off.size() > 0 else 12.0
	var offy := float(off[1]) if typeof(off) == TYPE_ARRAY and off.size() > 1 else 12.0
	lab_carousel.center_offset = Vector2(offx, offy)
	var slots_n := maxi(1, int(car.get("slots", 4)))
	var spacing := float(car.get("seat_spacing", float(lab_carousel.get("seat_spacing", 0.0))))
	if car.has("radius"):
		spacing = 2.0 * float(car.get("radius", 4.0)) * sin(PI / maxf(1.0, float(slots_n)))
		car.erase("radius")
	if spacing < 0.0:
		spacing = 12.0
	lab_carousel.seat_spacing = spacing
	car["seat_spacing"] = spacing
	lab_carousel.slot_base_deg = float(car.get("slot_base_deg", 0.0))
	lab_carousel.face_mode = str(car.get("face_mode", "inward"))
	lab_carousel.sprite_dir_offset = int(car.get("sprite_dir_offset", 4))
	lab_carousel.sprite_dir_follow = bool(car.get("sprite_dir_follow", true))
	if slots_n != int(lab_carousel.get("slots", 4)):
		lab_carousel.slots = slots_n
		_lab_reseat_agents()
	else:
		lab_carousel.slots = slots_n
	lab_carousel.radius = _lab_seat_radius(slots_n, spacing)
	lab_carousel.spin_speed = float(car.get("spin_speed", -2.8))
	lab_carousel.min_stay = float(car.get("min_stay", 8.0))
	lab_carousel.ride_fun_rate = float(car.get("ride_fun_rate", 2.5))
	lab_carousel.ride_done = float(car.get("ride_done", 95.0))
	_lab_update_status()


## Snaps admitted agents onto carousel slot positions.
func _lab_reseat_agents() -> void:
	var taken := {}
	var keep: Array = []
	for a in lab_agents:
		if str(a.state) == "riding":
			var slot := int(a.get("slot", -1))
			if slot >= 0 and slot < int(lab_carousel.slots) and not taken.has(slot):
				taken[slot] = true
				keep.append(a)
			else:
				a.state = "exit"
				a.slot = -1
		elif int(a.get("slot", -1)) >= int(lab_carousel.slots):
			a.slot = -1


## Clears lab agents and optionally respawns from spawn.count.
func _lab_reset_state(respawn: bool) -> void:
	lab_agents.clear()
	lab_sim_t = 0.0
	lab_admit_t = float(lab_cfg.get("sync", {}).get("initial_delay", 0.0))
	lab_wave_count = 0
	lab_wave_pause_t = 0.0
	lab_next_id = 1
	lab_last_ms = Time.get_ticks_msec()
	lab_selected_agent = -1
	lab_drag_agent = -1
	lab_drag_carousel = false
	lab_running = not bool(lab_cfg.get("paused", false))
	var car: Dictionary = lab_cfg.get("carousel", {})
	var cell_arr = car.get("cell", [8, 16])
	var cx := int(cell_arr[0]) if typeof(cell_arr) == TYPE_ARRAY and cell_arr.size() > 0 else 8
	var cy := int(cell_arr[1]) if typeof(cell_arr) == TYPE_ARRAY and cell_arr.size() > 1 else 16
	var off = car.get("center_offset", [18.0, 18.0])
	var offx := float(off[0]) if typeof(off) == TYPE_ARRAY and off.size() > 0 else 12.0
	var offy := float(off[1]) if typeof(off) == TYPE_ARRAY and off.size() > 1 else 12.0
	var slots_n := maxi(1, int(car.get("slots", 4)))
	var spacing := float(car.get("seat_spacing", 0.0))
	if car.has("radius"):
		# compat: old configs used orbit radius; convert to distance between plazas
		spacing = 2.0 * float(car.get("radius", 4.0)) * sin(PI / maxf(1.0, float(slots_n)))
		car.erase("radius")
	if spacing < 0.0:
		spacing = 12.0
	car["seat_spacing"] = spacing
	lab_carousel = {
		"pos": Catalog.cell_world(Vector2i(cx, cy)),
		"spin": 0.0,
		"center_offset": Vector2(offx, offy),
		"seat_spacing": spacing,
		"radius": _lab_seat_radius(slots_n, spacing),
		"slots": slots_n,
		"spin_speed": float(car.get("spin_speed", -2.8)),
		"slot_base_deg": float(car.get("slot_base_deg", 0.0)),
		"face_mode": str(car.get("face_mode", "inward")),
		"sprite_dir_offset": int(car.get("sprite_dir_offset", 4)),
		"sprite_dir_follow": bool(car.get("sprite_dir_follow", true)),
		"min_stay": float(car.get("min_stay", 8.0)),
		"ride_fun_rate": float(car.get("ride_fun_rate", 2.5)),
		"ride_done": float(car.get("ride_done", 95.0)),
	}
	if respawn:
		_lab_respawn_all()
	_lab_sync_ui_from_cfg()
	_lab_update_status()


## Clears and respawns lab_agents per spawn.count cfg.
func _lab_respawn_all() -> void:
	lab_agents.clear()
	lab_selected_agent = -1
	var n := maxi(1, int(lab_cfg.get("spawn", {}).get("count", 6)))
	_lab_spawn(n, true)
	_lab_update_status()


## Removes all synthetic lab agents without touching cfg.
func _lab_clear_agents() -> void:
	lab_agents.clear()
	lab_selected_agent = -1
	_lab_update_status()


## Adds n wandering lab agents around the carousel ring.
func _lab_spawn(n: int, reset_ring: bool = false) -> void:
	var sp: Dictionary = lab_cfg.get("spawn", {})
	var ring := float(sp.get("ring_radius", 80.0))
	var fun0 := float(sp.get("initial_fun", 20.0))
	var center := _lab_ride_center()
	for i in n:
		var ang := randf() * TAU if not reset_ring else (TAU * float(lab_agents.size()) / maxf(1.0, float(n)))
		if not reset_ring:
			ang = randf() * TAU
		var r := ring * randf_range(0.7, 1.1)
		var pos := center + Vector2(cos(ang) * r, sin(ang) * r)
		lab_agents.append({
			"id": lab_next_id,
			"pos": pos,
			"dir": Vector2(cos(ang + PI), sin(ang + PI)),
			"state": "seek",
			"slot": -1,
			"age": 0.0,
			"fun": fun0,
			"cooldown": 0.0,
			"queue_t": randf() * 0.1,
		})
		lab_next_id += 1
	_lab_update_status()


## Computes seat ring radius from slot count and spacing.
func _lab_seat_radius(slots_n: int, spacing: float) -> float:
	# Distance between plazas is the primary control: radius derived so adjacent seats are `spacing` apart.
	if slots_n <= 1:
		return 0.0
	var denom := 2.0 * sin(PI / float(slots_n))
	if absf(denom) < 0.0001:
		return 0.0
	return spacing / denom


## World center of the lab carousel including cfg offset.
func _lab_ride_center() -> Vector2:
	if lab_carousel.is_empty():
		return Vector2.ZERO
	return Vector2(lab_carousel.pos) + Vector2(lab_carousel.get("center_offset", Vector2(18, 18)))


## Angle in radians for carousel seat index.
func _lab_slot_ang(slot: int) -> float:
	var n := maxf(1.0, float(lab_carousel.get("slots", 4)))
	var base := deg_to_rad(float(lab_carousel.get("slot_base_deg", 0.0)))
	return float(lab_carousel.get("spin", 0.0)) + base + float(slot) * TAU / n


## World position for a carousel seat index.
func _lab_slot_pos(slot: int) -> Vector2:
	var center := _lab_ride_center()
	var ang := _lab_slot_ang(slot)
	var r := float(lab_carousel.get("radius", 4.0))
	return center + Vector2(cos(ang) * r, sin(ang) * r)


## Unit facing vector for a seat from face_mode cfg.
func _lab_slot_dir(slot: int) -> Vector2:
	var ang := _lab_slot_ang(slot)
	var center := _lab_ride_center()
	var pos := _lab_slot_pos(slot)
	var mode := str(lab_carousel.get("face_mode", "inward"))
	match mode:
		"inward":
			var d := center - pos
			return d.normalized() if d.length() > 0.001 else Vector2(cos(ang + PI), sin(ang + PI))
		"outward":
			var d := pos - center
			return d.normalized() if d.length() > 0.001 else Vector2(cos(ang), sin(ang))
		"tangent":
			return Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5))
		"spin":
			return Vector2(cos(ang - PI * 0.5), sin(ang - PI * 0.5))
		_:
			var d := center - pos
			return d.normalized() if d.length() > 0.001 else Vector2(cos(ang + PI), sin(ang + PI))


## Stand position agents use before boarding a slot.
func _lab_approach_pos(slot: int) -> Vector2:
	# Approach from outside toward the concrete seat point; entry can come from any direction.
	var seat := _lab_slot_pos(slot)
	var center := _lab_ride_center()
	var out := seat - center
	if out.length() < 0.001:
		out = Vector2(1, 0)
	return seat + out.normalized() * 10.0


## Queue gate position for slot admission logic.
func _lab_gate_pos(slot: int) -> Vector2:
	# Kept for drawing/compat: point just outside the seat
	return _lab_approach_pos(slot)


## Set of occupied seat indexes optionally excluding one agent.
func _lab_taken_slots(except_id: int = -1) -> Dictionary:
	var taken := {}
	for a in lab_agents:
		var aid := int(a.get("id", -1))
		if aid == except_id:
			continue
		var st := str(a.get("state", ""))
		var slot := int(a.get("slot", -1))
		if slot >= 0 and (st == "boarding" or st == "riding" or st == "reserved"):
			taken[slot] = aid
	return taken


## First unoccupied carousel seat index, or -1.
func _lab_free_slot() -> int:
	var taken := _lab_taken_slots()
	for s in int(lab_carousel.get("slots", 4)):
		if not taken.has(s):
			return s
	return -1


## Whether sync rules allow boarding another agent now.
func _lab_can_admit() -> bool:
	var sync: Dictionary = lab_cfg.get("sync", {})
	var mode := str(sync.get("mode", "continuous"))
	var boarding := 0
	for a in lab_agents:
		if str(a.state) == "boarding":
			boarding += 1
	if boarding >= int(sync.get("max_boarding", 1)):
		return false
	if lab_admit_t > 0.0:
		return false
	if mode == "interval":
		return true
	if mode == "wave":
		if lab_wave_pause_t > 0.0:
			return false
		if lab_wave_count >= int(sync.get("wave_size", 1)):
			return false
		return true
	# continuous
	return true


## Records admission time and updates wave counters.
func _lab_mark_admitted() -> void:
	var sync: Dictionary = lab_cfg.get("sync", {})
	var mode := str(sync.get("mode", "continuous"))
	if mode == "interval":
		lab_admit_t = maxf(lab_admit_t, float(sync.get("interval", 2.0)))
	elif mode == "wave":
		lab_wave_count += 1
		if lab_wave_count >= int(sync.get("wave_size", 1)):
			lab_wave_pause_t = float(sync.get("wave_pause", 4.0))
			lab_wave_count = 0
	else:
		lab_admit_t = maxf(lab_admit_t, 0.15)


## Simulates agent movement, boarding, riding, and exit one dt.
func _lab_step(dt: float) -> void:
	if lab_carousel.is_empty():
		return
	lab_sim_t += dt
	lab_admit_t = maxf(0.0, lab_admit_t - dt)
	lab_wave_pause_t = maxf(0.0, lab_wave_pause_t - dt)

	# spin only when someone is riding
	var spinning := false
	for a in lab_agents:
		if str(a.state) == "riding":
			spinning = true
			break
	if spinning:
		lab_carousel.spin = float(lab_carousel.get("spin", 0.0)) + float(lab_carousel.get("spin_speed", -2.8)) * dt

	var sync: Dictionary = lab_cfg.get("sync", {})
	var reenter := bool(sync.get("reenter", true))
	var queue_on := bool(sync.get("queue", true))
	var ride_done := float(lab_carousel.get("ride_done", 95.0))
	var min_stay := float(lab_carousel.get("min_stay", 8.0))
	var fun_rate := float(lab_carousel.get("ride_fun_rate", 2.5))
	var center := _lab_ride_center()

	# stable queue order
	var seekers: Array = []
	for i in lab_agents.size():
		if str(lab_agents[i].state) == "seek" or str(lab_agents[i].state) == "queue":
			seekers.append(i)
	seekers.sort_custom(func(a_i, b_i): return float(lab_agents[a_i].get("queue_t", 0.0)) < float(lab_agents[b_i].get("queue_t", 0.0)))

	var admit_budget := 99
	if queue_on:
		admit_budget = 1 if str(sync.get("mode", "continuous")) != "wave" else int(sync.get("wave_size", 1))

	for a in lab_agents:
		var st := str(a.state)
		if st == "cooldown":
			a.cooldown = float(a.get("cooldown", 0.0)) - dt
			if a.cooldown <= 0.0:
				if reenter:
					a.state = "seek"
					a.fun = float(lab_cfg.get("spawn", {}).get("initial_fun", 20.0))
					a.queue_t = lab_sim_t + randf() * 0.2
				else:
					a.state = "idle"
			continue
		if st == "idle":
			continue
		if st == "riding":
			a.age = float(a.get("age", 0.0)) + dt
			a.fun = minf(100.0, float(a.get("fun", 0.0)) + fun_rate * dt)
			var slot := int(a.get("slot", 0))
			a.pos = _lab_slot_pos(slot)
			a.dir = _lab_slot_dir(slot)
			if a.fun >= ride_done and a.age >= min_stay:
				a.state = "exit"
				a.slot = -1
				var ang := _lab_slot_ang(slot)
				a["exit_target"] = center + Vector2(cos(ang), sin(ang)) * (float(lab_carousel.get("radius", 4.0)) + 28.0)
			continue
		if st == "exit":
			var target: Vector2 = a.get("exit_target", center + Vector2(0, 40))
			if _lab_move_toward(a, target, 34.0, dt) < 3.0:
				a.state = "cooldown"
				a.cooldown = 1.5
			continue
		if st == "boarding":
			var slot := int(a.get("slot", -1))
			if slot < 0:
				a.state = "seek"
				continue
			var seat := _lab_slot_pos(slot)
			# Mount onto the concrete seat point on the carousel (entry can come from any direction)
			var left := _lab_move_toward(a, seat, 32.0, dt)
			if left <= 1.5:
				a.pos = seat
				a.dir = _lab_slot_dir(slot)
				a.state = "riding"
				a.age = 0.0
			continue
		# seek/queue: wait for admission
		a.queue_t = float(a.get("queue_t", lab_sim_t))
		if st == "seek":
			a.state = "queue" if queue_on else "seek"

	# admission pass: board onto concrete seat points (can approach from anywhere)
	var ordered: Array = []
	for a in lab_agents:
		if str(a.state) == "seek" or str(a.state) == "queue":
			ordered.append(a)
	ordered.sort_custom(func(x, y): return float(x.get("queue_t", 0.0)) < float(y.get("queue_t", 0.0)))
	for idx in ordered.size():
		var a = ordered[idx]
		var slot := int(a.get("slot", -1))
		if slot < 0 or _lab_taken_slots(int(a.get("id", -1))).has(slot):
			slot = _lab_free_slot()
			a.slot = slot
		if slot < 0:
			# queue around carousel
			var qang := (float(idx) / maxf(1.0, float(ordered.size()))) * TAU
			var qpos := center + Vector2(cos(qang), sin(qang)) * (float(lab_carousel.get("radius", 4.0)) + 34.0 + float(idx % 3) * 8.0)
			_lab_move_toward(a, qpos, 22.0, dt)
			a.state = "queue"
			continue
		var seat := _lab_slot_pos(slot)
		if _lab_can_admit():
			a.state = "boarding"
			_lab_mark_admitted()
		else:
			if queue_on:
				# wait in a ring around the carousel until admitted
				var qang := float(idx) * (TAU / maxf(1.0, float(ordered.size())))
				var qpos := center + Vector2(cos(qang), sin(qang)) * (float(lab_carousel.get("radius", 4.0)) + 40.0 + float(idx % 3) * 10.0)
				_lab_move_toward(a, qpos, 22.0, dt)
				a.state = "queue"
			else:
				# free approach from anywhere, but do not mount until admitted
				var hold := _lab_approach_pos(slot)
				if a.get("pos", Vector2.ZERO).distance_to(seat) > 14.0:
					_lab_move_toward(a, hold, 20.0, dt)
				a.state = "seek"
	_lab_update_status()


## Steers one lab agent toward target at speed; returns distance left.
func _lab_move_toward(a: Dictionary, target: Vector2, speed: float, dt: float) -> float:
	var pos: Vector2 = a.get("pos", Vector2.ZERO)
	var d := target - pos
	var dist := d.length()
	if dist > 0.001:
		var step: float = minf(dist, speed * dt)
		var dir: Vector2 = d / dist
		pos += dir * step
		a.pos = pos
		a.dir = dir
	return maxf(0.0, dist - speed * dt)


## Paints lab agents and carousel into the world drawer.
func _lab_tick_draw() -> void:
	if main == null:
		return
	var draws: Array = []
	_node_used = {}
	# carousel building
	var carousel_sy_base := -INF
	if not lab_carousel.is_empty():
		var pos: Vector2 = lab_carousel.get("pos", Catalog.cell_world(Vector2i(8, 16)))
		var spin: float = float(lab_carousel.get("spin", 0.0))
		var prop_frame: int = posmod(
			int(floor(spin / (TAU / float(StructureTextures.ROUND_ANIM_N)))),
			StructureTextures.ROUND_ANIM_N
		)
		_paint_building(draws, Catalog.BLD_ROUND, pos, 1.0, prop_frame)
		if not draws.is_empty():
			# keep building at a base depth so riders can sort in front/behind by seat
			carousel_sy_base = float(draws[draws.size() - 1].get("sy", main.cam_rig.to_iso(pos).y))
			draws[draws.size() - 1]["sy"] = carousel_sy_base
	# thronglets
	for a in lab_agents:
		var st := str(a.get("state", "seek"))
		var clip := "ThrongA_Default"
		if st == "riding":
			clip = RIDE_CLIP
		elif st == "boarding" or st == "seek" or st == "queue" or st == "exit":
			clip = "Throng_Walk_Anim_Spritesheet" if ThrongClips.CLIPS.has("Throng_Walk_Anim_Spritesheet") else "ThrongA_Default"
		elif st == "cooldown" or st == "idle":
			clip = "ThrongA_Default"
		var box: Vector2i = ThrongClips.CLIPS.get(clip, Vector2i(ThrongClips.BASE, 1))
		var fps := 8.0
		if st != "riding":
			fps = float(ThrongTune.get_tune(clip).get("fps", 8.0)) if not ThrongTune.get_tune(clip).is_empty() else 8.0
		var idx := 0
		if st == "riding":
			# sprite changes according to position/direction on the carousel (DIR/DIR GIRO to calibrate)
			if bool(lab_carousel.get("sprite_dir_follow", true)):
				var ang := _lab_slot_ang(int(a.get("slot", 0)))
				var dir_off := int(lab_carousel.get("sprite_dir_offset", 0))
				idx = posmod(-int(round(ang / TAU * float(box.y))) + dir_off, maxi(1, box.y))
			else:
				idx = posmod(int(lab_carousel.get("sprite_dir_offset", 0)), maxi(1, box.y))
		elif box.y > 1:
			idx = posmod(int(lab_sim_t * fps + float(int(a.get("id", 0)))), box.y)
		var frame := ThrongClips.frame_at(clip, idx)
		var slot := int(a.get("slot", 0))
		var pos: Vector2 = _lab_slot_pos(slot) if st == "riding" else a.get("pos", Vector2.ZERO)
		var lift := 0.0
		if st == "riding":
			lift = 2.0
		var off := Vector2.ZERO
		var t = ThrongTune.get_tune(clip)
		if st != "riding" and not t.is_empty():
			off = ThrongTune.frame_offset(clip, idx)
		var sc := 1.0
		if not t.is_empty():
			sc = ThrongTune.frame_scale(clip, idx)
		var tint := Color(1, 1, 1, 1)
		if int(a.get("id", -1)) == lab_selected_agent:
			tint = Color(1.0, 1.0, 0.55, 1.0)
		var sy := float(main.cam_rig.to_iso(pos).y) + 8.0
		if st == "riding" and carousel_sy_base > -INF:
			# Flat disk: all riders stay above the carousel.
			sy = carousel_sy_base + 1.0 + float(slot) * 0.01
		main.iso_draw.push_iso(draws, pos + off, frame, tint, lift, sc, sy)
		if st == "riding":
			# directional ride sprites already encode orientation; avoid extra flip/rotation jitter
			var trot := ThrongTune.frame_rot(clip, idx)
			if trot != 0.0:
				draws[draws.size() - 1]["rot"] = trot
		else:
			var move_dir: Vector2 = a.get("dir", Vector2(0, 1))
			if move_dir.length() > 0.001:
				var sdir: Vector2 = main.cam_rig.to_iso(pos + move_dir) - main.cam_rig.to_iso(pos)
				if sdir.x < -0.01:
					draws[draws.size() - 1]["flip"] = -1.0
				elif sdir.x > 0.01:
					draws[draws.size() - 1]["flip"] = 1.0
	draws.sort_custom(func(a, b): return float(a.sy) < float(b.sy))
	main.world_drawer.paint_props(draws)
	var car_node = nodes.get(EFFECT_ACTIVE_UID)
	if car_node != null and is_instance_valid(car_node) and car_node.visible:
		if carousel_sy_base > -INF:
			car_node.set_meta("sy", carousel_sy_base)
		main.world_layer.move_child(car_node, 0)
	_drop_nodes(_node_used)
	_lab_update_status()


## Overlays lab slot rings, gates, and selection handles.
func _lab_draw() -> void:
	if main == null:
		return
	var poly: PackedVector2Array = main.placement_overlay.place_cell_poly()
	if not poly.is_empty():
		var grid := Color(1, 1, 1, 0.12)
		for cell in _view_cells():
			_stroke(cell, poly, grid, Color(0, 0, 0, 0))
	if lab_carousel.is_empty():
		return
	# ride center and slots
	var center := _lab_ride_center()
	_cross(center)
	var steps := 36
	var r := float(lab_carousel.get("radius", 4.0))
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var p0: Vector2 = main.cam_rig.to_iso(center + Vector2(cos(a0) * r, sin(a0) * r))
		var p1: Vector2 = main.cam_rig.to_iso(center + Vector2(cos(a1) * r, sin(a1) * r))
		draw_line(p0, p1, Color(0.2, 0.9, 1.0, 0.5), 2.0)
	var slots_n := int(lab_carousel.get("slots", 4))
	for s in slots_n:
		var sp := _lab_slot_pos(s)
		var c := Color(0.3, 1.0, 0.4, 0.8)
		if _lab_taken_slots().has(s):
			c = Color(1.0, 0.4, 0.3, 0.9)
		# concrete mounted seat point
		draw_circle(main.cam_rig.to_iso(sp), 4.5, c)
		# facing direction indicator
		var dir := _lab_slot_dir(s)
		draw_line(main.cam_rig.to_iso(sp), main.cam_rig.to_iso(sp + dir * 8.0), Color(0.95, 0.95, 1.0, 0.7), 2.0)
	# selected agent marker
	if lab_selected_agent >= 0:
		for a in lab_agents:
			if int(a.get("id", -1)) == lab_selected_agent:
				draw_circle(main.cam_rig.to_iso(a.get("pos", Vector2.ZERO)), 6.0, Color(1, 1, 0.4, 0.9))
				break


## Selects agents, starts drags, or spawns on shift-click.
func _lab_click(shift: bool) -> void:
	var world: Vector2 = main.cam_rig.grid_pointer_world()
	if shift:
		_lab_spawn(1)
		if not lab_agents.is_empty():
			lab_agents[lab_agents.size() - 1].pos = world
			lab_selected_agent = int(lab_agents[lab_agents.size() - 1].id)
		return
	# pick agent
	var best := -1
	var best_d := 18.0
	for a in lab_agents:
		var d := world.distance_to(a.get("pos", Vector2.ZERO))
		if d < best_d:
			best_d = d
			best = int(a.get("id", -1))
	if best >= 0:
		lab_selected_agent = best
		lab_drag_agent = best
		lab_drag_carousel = false
		return
	# pick carousel (near center or base)
	if not lab_carousel.is_empty():
		var base: Vector2 = lab_carousel.get("pos", Vector2.ZERO)
		var c := _lab_ride_center()
		if world.distance_to(c) < 28.0 or world.distance_to(base) < 28.0:
			lab_drag_carousel = true
			lab_selected_agent = -1
			return
	# else move carousel to clicked cell
	var cell := _cursor_cell()
	if _in_pad(cell):
		lab_carousel.pos = Catalog.cell_world(cell)
		var car: Dictionary = lab_cfg.get("carousel", {})
		car["cell"] = [cell.x, cell.y]
		lab_cfg["carousel"] = car
		lab_drag_carousel = false
		lab_selected_agent = -1


## Ends agent or carousel drag and re-seats riders.
func _lab_release_drag() -> void:
	if lab_drag_carousel and not lab_carousel.is_empty():
		var cell := _cell_of(lab_carousel.get("pos", Catalog.cell_world(Vector2i(8, 16))))
		var car: Dictionary = lab_cfg.get("carousel", {})
		car["cell"] = [cell.x, cell.y]
		lab_cfg["carousel"] = car
	lab_drag_agent = -1
	lab_drag_carousel = false


## Deletes lab_selected_agent from lab_agents.
func _lab_remove_selected() -> void:
	if lab_selected_agent < 0:
		return
	var kept: Array = []
	for a in lab_agents:
		if int(a.get("id", -1)) != lab_selected_agent:
			kept.append(a)
	lab_agents = kept
	lab_selected_agent = -1
	_lab_update_status()


## Toggles lab_running simulation pause.
func _lab_toggle_run() -> void:
	lab_running = not lab_running
	lab_cfg["paused"] = not lab_running
	_lab_update_status()


## Advances lab simulation by one fixed dt while paused.
func _lab_step_once() -> void:
	if lab_carousel.is_empty():
		return
	var was := lab_running
	lab_running = false
	_lab_step(1.0 / 30.0)
	lab_running = was
	_lab_update_status()


## Writes lab_cfg to dev/tiovivo_lab.json via TiovivoLabTune.
func _lab_save() -> void:
	# sync carousel cell and paused
	if not lab_carousel.is_empty():
		var cell := _cell_of(lab_carousel.get("pos", Catalog.cell_world(Vector2i(8, 16))))
		var car: Dictionary = lab_cfg.get("carousel", {})
		car["cell"] = [cell.x, cell.y]
		lab_cfg["carousel"] = car
	lab_cfg["paused"] = not lab_running
	var path := TiovivoLabTune.save_file(lab_cfg)
	if path != "":
		_lab_set_status("GUARDADO: %s" % path)
	else:
		_lab_set_status("ERROR AL GUARDAR")


## Reloads lab_cfg from saved JSON and refreshes UI.
func _lab_load() -> void:
	lab_cfg = TiovivoLabTune.load_saved()
	_lab_reset_state(true)
	_lab_set_status("CARGADO dev/tiovivo_lab.json")


## Sets lab_status text and appends to lab_messages.
func _lab_set_status(text: String) -> void:
	if lab_status:
		lab_status.text = text


## Rebuilds status from admit metrics and agent counts.
func _lab_update_status() -> void:
	if not lab_mode:
		return
	var riding := 0
	var boarding := 0
	var queue_n := 0
	for a in lab_agents:
		var st := str(a.get("state", ""))
		if st == "riding":
			riding += 1
		elif st == "boarding":
			boarding += 1
		elif st == "queue" or st == "seek":
			queue_n += 1
	var sync: Dictionary = lab_cfg.get("sync", {})
	var mode := str(sync.get("mode", "continuous"))
	var run := "PLAY" if lab_running else "PAUSA"
	var msg := "%s | N=%d mont=%d suben=%d cola=%d modo=%s t=%.1fs" % [run, lab_agents.size(), riding, boarding, queue_n, mode, lab_sim_t]
	if lab_name:
		lab_name.text = "LABORATORIO TIOVIVO  -  centro(%.1f,%.1f) dist=%.1f slots=%d  ang0=%.0f miran=%s" % [
			float(lab_carousel.get("center_offset", Vector2(18, 18)).x),
			float(lab_carousel.get("center_offset", Vector2(18, 18)).y),
			float(lab_carousel.get("seat_spacing", 0.0)),
			int(lab_carousel.get("slots", 4)),
			float(lab_carousel.get("slot_base_deg", 0.0)),
			str(lab_carousel.get("face_mode", "inward"))
		]
	_lab_set_status(msg)


## Moves dragged agent or carousel center while mouse held.
func _lab_drag_update() -> void:
	if not lab_mode:
		return
	var world: Vector2 = main.cam_rig.grid_pointer_world()
	if lab_drag_agent >= 0:
		for a in lab_agents:
			if int(a.get("id", -1)) == lab_drag_agent:
				a.pos = world
				if str(a.state) == "riding" or str(a.state) == "boarding":
					a.state = "seek"
					a.slot = -1
					a.age = 0.0
					a.queue_t = lab_sim_t
				break
	elif lab_drag_carousel and not lab_carousel.is_empty():
		lab_carousel.pos = world
