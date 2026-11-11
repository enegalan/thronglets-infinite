extends Node2D

# Layout bench. Places every prop and edits footprint, scale, offset, z, and rotation live.

const PAD_MIN := -8
const PAD_MAX := 40
const THRONG_ID := "throng:0"
const BATH_CLIP := "Throng_FallInBath_Spritesheet"
const RIDE_CLIP := "ThrongA_Roundabout_SpriteSheet"
const ThrongTune := preload("res://throng_tune.gd")
const AnimTune := preload("res://anim_tune.gd")

var main = null
var rail: PanelContainer
var bar: PanelContainer
var list: VBoxContainer
var name_label: Label
var status: Label
var grid_x: SpinBox
var grid_y: SpinBox
var scale_box: SpinBox
var off_x: SpinBox
var off_y: SpinBox
var z_box: SpinBox
var rot_box: SpinBox
var quit_button: Button
var buttons := {}
var armed := ""
var drag_id := ""
var move_uid := -1
var move_grab := Vector2i.ZERO
var placed: Array = []
var selected := -1
var next_uid := 1
var nodes := {}
var _fill := false
var throng_mode := false
var throng_rail: PanelContainer
var throng_bar: PanelContainer
var clip_list: VBoxContainer
var clip_filter: LineEdit
var clip_buttons := {}
var clip_name := ""
var frame_buttons: Array = []
var strip: HBoxContainer
var fps_box: SpinBox
var throng_scale: SpinBox
var throng_x: SpinBox
var throng_y: SpinBox
var throng_rot: SpinBox
var play_button: Button
var mirror_button: Button
var all_button: Button
var throng_name: Label
var throng_status: Label
var playing := true
var apply_all := false
var frame_i := 0
var play_t := 0.0
var _rot_shown := -1
var play_ms := 0
var mirror := false


func setup(host) -> void:
	main = host
	z_index = 6
	_build_ui()


func open() -> void:
	_clear_placed()
	_paint_ground()
	main.zoom_level = 2.0
	main.camera.zoom = Vector2(2, 2)
	main.camera.position = main._to_iso(Catalog.cell_world(Vector2i(8, 16)))
	PropTune.load_saved()
	ThrongTune.load_saved()
	AnimTune.load_saved()
	throng_mode = false
	rail.visible = true
	bar.visible = true
	drag_id = ""
	move_uid = -1
	_arm("", -1)
	tick()


func close() -> void:
	_clear_placed()
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


func tick() -> void:
	if main == null:
		return
	_advance()
	var draws: Array = []
	var used := {}
	for inst in placed:
		var row := _row_for(str(inst.id))
		if row.is_empty():
			continue
		_paint_inst(draws, row, _live_at(inst), 1.0, int(inst.uid), used)
	if _show_ghost():
		var ghost := _row_for(drag_id)
		if not ghost.is_empty():
			var origin := Catalog.cell_world(_cursor_cell())
			_paint_inst(draws, ghost, origin, 0.45, -1, used)
	draws.sort_custom(func(a, b): return float(a.sy) < float(b.sy))
	main._paint_props(draws)
	_lift_nodes()
	_drop_nodes(used)
	if throng_mode:
		_sync_playhead()
	queue_redraw()


func input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and (drag_id != "" or move_uid >= 0):
			drag_id = ""
			move_uid = -1
			_mark_buttons()
		main.dragging = event.pressed
		main.drag_from = event.position
		main.cam_from = main.camera.position
		main.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click()
		main.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_remove_selected()
			main.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and throng_mode:
			var focus: Control = main.get_viewport().gui_get_focus_owner()
			if focus is LineEdit:
				return
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


func _draw() -> void:
	if main == null:
		return
	var poly: PackedVector2Array = main._place_cell_poly()
	if poly.is_empty():
		return
	var grid := Color(1, 1, 1, 0.16)
	for cell in _view_cells():
		_stroke(cell, poly, grid, Color(0, 0, 0, 0))
	for inst in placed:
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		var origin: Vector2 = _live_at(inst)
		var on := int(inst.uid) == selected
		var moving := int(inst.uid) == move_uid
		var bad := moving and not _fits(origin, tune.footprint, int(inst.uid))
		var fill := Color(0.9, 0.25, 0.2, 0.28) if bad else Color(1.0, 0.82, 0.25, 0.28) if on else Color(0.35, 0.85, 0.5, 0.16)
		var edge := Color(1.0, 0.35, 0.3, 0.95) if bad else Color(1.0, 0.9, 0.4, 0.95) if on else Color(0.55, 1.0, 0.7, 0.75)
		for cell in _cells(origin, tune.footprint):
			_stroke(cell, poly, edge, fill)
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


func _click() -> void:
	if drag_id != "":
		return
	var cell := _cursor_cell()
	if not _in_pad(cell):
		return
	var hit := _hit(cell)
	if hit < 0:
		move_uid = -1
		_arm("", -1)
		return
	var inst: Dictionary = placed[hit]
	_arm(str(inst.id), int(inst.uid))
	move_uid = int(inst.uid)
	move_grab = cell - _cell_of(inst.at)


func _begin_drag(id: String) -> void:
	drag_id = id
	move_uid = -1
	_mark_buttons()


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


func _arm(id: String, uid: int) -> void:
	armed = id
	selected = uid
	if id == "":
		_clear_edit()
	elif id == THRONG_ID:
		name_label.text = "MULTI"
		_set_edit_enabled(false)
	else:
		_fill_inspector()
		_set_edit_enabled(true)
	_mark_buttons()
	_sync_quit()
	_refresh_status()


func _remove_selected() -> void:
	var index := _index_of(selected)
	if index < 0:
		return
	var uid := int(placed[index].uid)
	if uid == move_uid:
		move_uid = -1
	placed.remove_at(index)
	if nodes.has(uid):
		var node: Node2D = nodes[uid]
		nodes.erase(uid)
		node.queue_free()
	selected = -1
	_sync_quit()


func _reset_kind() -> void:
	if armed == "":
		return
	PropTune.reset(armed)
	_fill_inspector()
	_mark_buttons()
	_refresh_status()


func _save_restart() -> void:
	var prop_path: String = PropTune.save_file()
	var throng_path: String = ThrongTune.save_file()
	var anim_path: String = AnimTune.save_file()
	if prop_path == "" or throng_path == "" or anim_path == "":
		if status:
			status.text = "NO SE PUDO GUARDAR"
		if throng_status:
			throng_status.text = "NO SE PUDO GUARDAR"
		return
	print("prop tune: ", prop_path)
	print("throng tune: ", throng_path)
	print("anim tune: ", anim_path)
	PropTune.arm_boot()
	main.get_tree().reload_current_scene()


func _paint_ground() -> void:
	main.tilemap.clear()
	for y in range(PAD_MIN, PAD_MAX + 1):
		for x in range(PAD_MIN, PAD_MAX + 1):
			main.tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


func _clear_placed() -> void:
	placed.clear()
	selected = -1
	for uid in nodes.keys():
		var node: Node2D = nodes[uid]
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


func _row_for(id: String) -> Dictionary:
	if id == THRONG_ID:
		return {"id": THRONG_ID, "node": false}
	return PropTune.entry(id)


func _throng_frame(time: float) -> int:
	var clip := "ThrongA_Default Blink" if int(time * 2.0) % 5 == 4 else "ThrongA_Default"
	return ThrongClips.frame_at(clip, 0)


func _paint_inst(draws: Array, row: Dictionary, origin: Vector2, alpha: float, uid: int, used: Dictionary) -> void:
	if str(row.get("id", "")) == THRONG_ID:
		if throng_mode:
			_paint_tuned(draws, origin, alpha)
		else:
			var frame := _throng_frame(Time.get_ticks_msec() / 1000.0)
			main._push_iso(draws, origin, frame, Color(1, 1, 1, alpha), 0.0, 1.0)
		return
	var tune: Dictionary = PropTune.get_tune(str(row.id))
	if bool(row.get("node", false)):
		var node: Node2D = _take_node(uid)
		var at: Vector2 = _anchor(row, origin, tune, 0)
		node.position = main._to_iso(at)
		node.scale = Vector2(float(tune.scale), float(tune.scale))
		node.rotation_degrees = float(tune.rot)
		node.z_index = int(round(float(tune.z)))
		node.modulate = Color(1, 1, 1, alpha)
		node.visible = true
		used[uid] = true
		return
	var frame := _frame_of(row)
	var at: Vector2 = _anchor(row, origin, tune, frame)
	main._push_iso(draws, at, frame, Color(1, 1, 1, alpha), 0.0, float(tune.scale))
	var last: Dictionary = draws[draws.size() - 1]
	last["sy"] = float(last.get("sy", last.p.y)) + float(tune.z)
	last["rot"] = float(tune.rot)
	if str(row.group) == "feature" and int(row.kind) == Catalog.FEAT_ANOMALY:
		main._push_iso(draws, at, AssetFrames.ANOMALY_RAY, Color(1, 1, 1, alpha), 0.0, float(tune.scale))
		var ray: Dictionary = draws[draws.size() - 1]
		ray["sy"] = float(last.sy) + 0.5
		ray["rot"] = float(tune.rot)


func _anchor(row: Dictionary, origin: Vector2, tune: Dictionary, frame: int) -> Vector2:
	var extra: Vector2 = tune.offset
	if bool(row.get("node", false)):
		return origin + extra
	var size: Vector2i = tune.footprint
	return origin + Catalog.footprint_center(size) + main._pad_nudge(frame, float(tune.scale), size) + extra


func _frame_of(row: Dictionary) -> int:
	var kind := int(row.kind)
	var ore := int(row.ore)
	var time := Time.get_ticks_msec() / 1000.0
	if str(row.group) == "feature":
		var frame: int = main._feature_frame(kind, time, ore)
		if frame < 0:
			frame = main._prop_frame(Catalog.icon_for_feature(kind, ore))
		return frame
	if str(row.group) == "item":
		if kind == Catalog.ITEM_EGG:
			return main.EGG_ANIM + posmod(int(time * 4.0), 5)
		return main._prop_frame(Catalog.icon_for_item(kind))
	if kind == Catalog.BLD_ROUND:
		return main.ROUND_ANIM + posmod(int(time * 8.0), 8)
	return main._prop_frame(int(row.icon))


func _take_node(uid: int) -> Node2D:
	if nodes.has(uid) and is_instance_valid(nodes[uid]):
		return nodes[uid]
	var node: Node2D = (load("res://monolith_prop.gd") as GDScript).new()
	main.world_layer.add_child(node)
	nodes[uid] = node
	return node


func _lift_nodes() -> void:
	for uid in nodes.keys():
		var node: Node2D = nodes[uid]
		if not is_instance_valid(node) or not node.visible:
			continue
		if node.get_parent() == main.world_layer:
			main.world_layer.move_child(node, -1)


func _drop_nodes(used: Dictionary) -> void:
	var drop: Array = []
	for uid in nodes.keys():
		if used.has(uid):
			continue
		if int(uid) == -1:
			if is_instance_valid(nodes[uid]):
				nodes[uid].visible = false
			continue
		drop.append(uid)
	for uid in drop:
		var node: Node2D = nodes[uid]
		nodes.erase(uid)
		if is_instance_valid(node):
			node.queue_free()


func _show_ghost() -> bool:
	if drag_id == "" or _over_ui():
		return false
	return _in_pad(_cursor_cell())


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


func _cursor_cell() -> Vector2i:
	return _cell_of(main._grid_pointer())


func _cell_of(at: Vector2) -> Vector2i:
	var tile := float(Catalog.TILE)
	return Vector2i(int(floor(at.x / tile)), int(floor(at.y / tile)))


func _in_pad(cell: Vector2i) -> bool:
	return cell.x >= PAD_MIN and cell.x <= PAD_MAX and cell.y >= PAD_MIN and cell.y <= PAD_MAX


func _cells(origin: Vector2, size: Vector2i) -> Array[Vector2i]:
	var origin_cell := _cell_of(origin)
	var out: Array[Vector2i] = []
	for off in Catalog.footprint_offsets(size):
		out.append(origin_cell + off)
	return out


func _live_at(inst: Dictionary) -> Vector2:
	if int(inst.uid) != move_uid or _over_ui():
		return inst.at
	return Catalog.cell_world(_cursor_cell() - move_grab)


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


func _fits(origin: Vector2, size: Vector2i, ignore_uid: int) -> bool:
	for cell in _cells(origin, size):
		if not _in_pad(cell):
			return false
		if _occupied(cell, ignore_uid):
			return false
	return true


func _occupied(cell: Vector2i, ignore_uid: int) -> bool:
	for inst in placed:
		if int(inst.uid) == ignore_uid:
			continue
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		var size: Vector2i = tune.footprint
		if _covers(inst.at, size, cell):
			return true
	return false


func _foot_fits(id: String, size: Vector2i) -> bool:
	for inst in placed:
		if str(inst.id) != id:
			continue
		if not _fits(inst.at, size, int(inst.uid)):
			return false
	return true


func _refuse() -> void:
	if status:
		status.text = "NO CABE"
	if throng_status:
		throng_status.text = "NO CABE"


func _hit(cell: Vector2i) -> int:
	for i in range(placed.size() - 1, -1, -1):
		var inst: Dictionary = placed[i]
		var tune: Dictionary = PropTune.get_tune(str(inst.id))
		if _covers(inst.at, tune.footprint, cell):
			return i
	return -1


func _covers(origin: Vector2, size: Vector2i, cell: Vector2i) -> bool:
	for spot in _cells(origin, size):
		if spot == cell:
			return true
	return false


func _index_of(uid: int) -> int:
	for i in placed.size():
		if int(placed[i].uid) == uid:
			return i
	return -1


func _view_cells() -> Array[Vector2i]:
	var rect: Rect2 = main._world_view().grow(24.0)
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


func _stroke(cell: Vector2i, poly: PackedVector2Array, edge: Color, fill: Color) -> void:
	var pos: Vector2 = main._to_iso(Catalog.cell_world(cell))
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(pos + p)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge, 1.0, false)


func _cross(at: Vector2) -> void:
	var p: Vector2 = main._to_iso(at)
	draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color.WHITE, 1.0, false)
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color.WHITE, 1.0, false)


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
	bar.offset_top = -136
	bar.offset_right = -4
	bar.offset_bottom = -4
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.theme = theme
	bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var hint := Label.new()
	hint.text = "ARRASTRA UN PUESTO PARA MOVERLO. EL GRID NO PISA OTRO. SAVE ESCRIBE dev/prop_tune.json, dev/throng_tune.json Y dev/anim_tune.json."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	name_label = Label.new()
	name_label.clip_text = true
	box.add_child(name_label)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 4)
	grid_x = _spin(1, 8, 1)
	grid_y = _spin(1, 8, 1)
	scale_box = _spin(0.25, 3.0, 0.05)
	off_x = _spin(-160, 160, 1)
	off_y = _spin(-160, 160, 1)
	z_box = _spin(-40, 40, 1)
	rot_box = _spin(-180, 180, 1)
	grid_x.tooltip_text = "Celdas que ocupa en X"
	grid_y.tooltip_text = "Celdas que ocupa en Y"
	scale_box.tooltip_text = "Escala del sprite"
	off_x.tooltip_text = "Mueve el sprite en X, pixeles de mundo"
	off_y.tooltip_text = "Mueve el sprite en Y, pixeles de mundo"
	z_box.tooltip_text = "Orden. Mas alto queda delante. En el monolito es el z_index."
	rot_box.tooltip_text = "Rotacion en grados. Positivo gira a la derecha, alrededor del ancla."
	_pair(metrics, "GX", grid_x)
	_pair(metrics, "GY", grid_y)
	_pair(metrics, "SC", scale_box)
	_pair(metrics, "X", off_x)
	_pair(metrics, "Y", off_y)
	_pair(metrics, "Z", z_box)
	_pair(metrics, "R", rot_box)
	box.add_child(metrics)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(_text_button("RESET", _reset_kind))
	quit_button = _text_button("QUITAR", _remove_selected)
	actions.add_child(quit_button)
	actions.add_child(_text_button("SAVE & RESTART", _save_restart))
	actions.add_child(_text_button("ANIM", _show_throng))
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
	scale_box.value_changed.connect(_on_scale)
	off_x.value_changed.connect(_on_offset)
	off_y.value_changed.connect(_on_offset)
	z_box.value_changed.connect(_on_z)
	rot_box.value_changed.connect(_on_rot)
	_build_throng_ui(theme, root)


func _build_list() -> void:
	_section("MULTI")
	var multi := Button.new()
	multi.icon = main._tex("res://resources/ui/face_base.png")
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


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(label)


func _add_palette(row: Dictionary) -> void:
	var button := Button.new()
	if str(row.group) == "feature" and int(row.kind) == Catalog.FEAT_ANOMALY:
		button.icon = _frame_tex(AssetFrames.ANOMALY)
	else:
		button.icon = main._atlas_icon(int(row.icon))
	button.tooltip_text = str(row.label)
	button.custom_minimum_size = Vector2(32, 32)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(_begin_drag.bind(str(row.id)))
	list.add_child(button)
	buttons[str(row.id)] = button


func _text_button(text: String, call: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	return button


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = lo
	box.max_value = hi
	box.step = step
	box.rounded = step >= 1.0
	box.custom_minimum_size = Vector2(52, 22)
	box.update_on_text_changed = true
	box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return box


func _pair(row: HBoxContainer, title: String, box: SpinBox) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(16, 0)
	row.add_child(label)
	row.add_child(box)


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


func _flat(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	return box


func _clear_edit() -> void:
	name_label.text = "ARRASTRA UN ICONO"
	_set_edit_enabled(false)


func _set_edit_enabled(on: bool) -> void:
	for box in [grid_x, grid_y, scale_box, off_x, off_y, z_box, rot_box]:
		box.editable = on


func _fill_inspector() -> void:
	var row: Dictionary = PropTune.entry(armed)
	if row.is_empty():
		return
	var tune: Dictionary = PropTune.get_tune(armed)
	var size: Vector2i = tune.footprint
	var off: Vector2 = tune.offset
	name_label.text = "%s   %s" % [str(row.label), str(row.constant)]
	_fill = true
	grid_x.set_value_no_signal(size.x)
	grid_y.set_value_no_signal(size.y)
	scale_box.set_value_no_signal(float(tune.scale))
	off_x.set_value_no_signal(off.x)
	off_y.set_value_no_signal(off.y)
	z_box.set_value_no_signal(float(tune.z))
	rot_box.set_value_no_signal(float(tune.rot))
	_fill = false


func _mark_buttons() -> void:
	for id in buttons.keys():
		var button: Button = buttons[id]
		var dirty := PropTune.is_dirty(str(id))
		if str(id) == drag_id:
			button.modulate = Color(0.65, 0.88, 1.0)
		elif str(id) == armed:
			button.modulate = Color(1, 0.86, 0.4)
		elif dirty:
			button.modulate = Color(0.65, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE


func _sync_quit() -> void:
	if quit_button:
		quit_button.disabled = selected < 0


func _refresh_status() -> void:
	var props: int = PropTune.change_count()
	var clips: int = ThrongTune.change_count() + AnimTune.change_count()
	var text := "SIN CAMBIOS"
	if props > 0 or clips > 0:
		text = "%d PROPS  %d CLIPS" % [props, clips]
	if status:
		status.text = text
	if throng_status:
		throng_status.text = text


func _on_foot(_v: float) -> void:
	if _fill or armed == "":
		return
	var next := Vector2i(int(grid_x.value), int(grid_y.value))
	if not _foot_fits(armed, next):
		var tune: Dictionary = PropTune.get_tune(armed)
		var size: Vector2i = tune.footprint
		_fill = true
		grid_x.set_value_no_signal(size.x)
		grid_y.set_value_no_signal(size.y)
		_fill = false
		_refuse()
		return
	PropTune.set_footprint(armed, next.x, next.y)
	_mark_buttons()
	_refresh_status()


func _on_scale(v: float) -> void:
	if _fill or armed == "":
		return
	PropTune.set_scale(armed, v)
	_mark_buttons()
	_refresh_status()


func _on_offset(_v: float) -> void:
	if _fill or armed == "":
		return
	PropTune.set_offset(armed, off_x.value, off_y.value)
	_mark_buttons()
	_refresh_status()


func _on_z(v: float) -> void:
	if _fill or armed == "":
		return
	PropTune.set_z(armed, v)
	_mark_buttons()
	_refresh_status()


func _on_rot(v: float) -> void:
	if _fill or armed == "":
		return
	PropTune.set_rot(armed, v)
	_mark_buttons()
	_refresh_status()


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
	hint.text = "TODOS COPIA ESCALA, POSICION Y ROTACION A CADA FOTOGRAMA. SIN TODOS, SOLO AL QUE VES."
	hint.clip_text = true
	box.add_child(hint)
	throng_name = Label.new()
	throng_name.clip_text = true
	box.add_child(throng_name)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 4)
	fps_box = _spin(0.5, 24.0, 0.5)
	throng_scale = _spin(0.25, 3.0, 0.05)
	throng_x = _spin(-160, 160, 1)
	throng_y = _spin(-160, 160, 1)
	throng_rot = _spin(-180, 180, 1)
	fps_box.tooltip_text = "Fotogramas por segundo. Un frame, mitosis y el bano no guardan fps."
	throng_scale.tooltip_text = "Escala de este fotograma. Con TODOS, de todos."
	throng_x.tooltip_text = "Mueve este fotograma en X. Con TODOS, mueve todos."
	throng_y.tooltip_text = "Mueve este fotograma en Y. Con TODOS, mueve todos."
	throng_rot.tooltip_text = "Rotacion de este fotograma. Con TODOS, gira todos. Positivo gira a la derecha."
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
	all_button.tooltip_text = "La escala, la posicion y la rotacion que marques se copian a cada fotograma."
	actions.add_child(all_button)
	actions.add_child(_text_button("RESET", _reset_clip))
	box.add_child(actions)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 4)
	save_row.add_child(_text_button("SAVE & RESTART", _save_restart))
	save_row.add_child(_text_button("PROPS", _show_props))
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


func _build_clip_list() -> void:
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


func _clip_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clip_list.add_child(label)


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


func _is_anim(clip: String) -> bool:
	return clip.begins_with("anim:")


func _anim_key(clip: String) -> String:
	return clip.substr(5)


func _short(clip: String) -> String:
	if _is_anim(clip):
		return str(AnimTune.entry(_anim_key(clip)).get("label", clip))
	for prefix in ["ThrongA_", "ThrongB_", "ThrongC_", "ThrongD_", "ThrongE_", "Throng_", "Thronglet_"]:
		if clip.begins_with(prefix):
			return clip.substr(prefix.length())
	return clip


func _show_throng() -> void:
	throng_mode = true
	rail.visible = false
	bar.visible = false
	throng_rail.visible = true
	throng_bar.visible = true
	_ensure_stage()
	if clip_name == "":
		_select_clip("ThrongA_Default")
	else:
		_fill_clip()
		_mark_clips()
		_sync_play_button()
	_refresh_status()


func _show_props() -> void:
	throng_mode = false
	if throng_rail:
		throng_rail.visible = false
	if throng_bar:
		throng_bar.visible = false
	rail.visible = true
	bar.visible = true
	_mark_buttons()
	_refresh_status()


func _ensure_stage() -> void:
	for inst in placed:
		if str(inst.id) != THRONG_ID:
			continue
		if selected < 0:
			_arm(THRONG_ID, int(inst.uid))
		return
	var uid := next_uid
	next_uid += 1
	placed.append({"uid": uid, "id": THRONG_ID, "at": Catalog.cell_world(Vector2i(8, 16))})
	_arm(THRONG_ID, uid)


func _select_clip(clip: String) -> void:
	clip_name = clip
	frame_i = 0
	play_t = 0.0
	playing = true
	_rot_shown = -1
	_build_strip()
	_fill_clip()
	_mark_clips()
	_sync_play_button()


func _advance() -> void:
	var now := Time.get_ticks_msec()
	if play_ms == 0:
		play_ms = now
	var dt := minf(float(now - play_ms) / 1000.0, 0.1)
	play_ms = now
	if throng_mode and playing and clip_name != "":
		play_t += dt


func _box() -> Vector2i:
	if _is_anim(clip_name):
		var row: Dictionary = AnimTune.entry(_anim_key(clip_name))
		return Vector2i(int(row.get("start", 0)), int(row.get("count", 1)))
	var raw: Vector2i = ThrongClips.CLIPS.get(clip_name, Vector2i(ThrongClips.BASE, 1))
	return raw


func _clip_fps() -> float:
	if _is_anim(clip_name):
		return float(AnimTune.get_tune(_anim_key(clip_name)).get("fps", 8.0))
	return float(ThrongTune.get_tune(clip_name).get("fps", 8.0))


func _shown_off() -> Vector2:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_offset(_anim_key(clip_name), index)
	return ThrongTune.frame_offset(clip_name, index)


func _shown_rot() -> float:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_rot(_anim_key(clip_name), index)
	return ThrongTune.frame_rot(clip_name, index)


func _shown_scale() -> float:
	var index := _shown_index()
	if _is_anim(clip_name):
		return AnimTune.frame_scale(_anim_key(clip_name), index)
	return ThrongTune.frame_scale(clip_name, index)


func _shown_index() -> int:
	var n := maxi(_box().y, 1)
	if not playing:
		return clampi(frame_i, 0, n - 1)
	return posmod(int(play_t * _clip_fps()), n)


func _clip_title() -> String:
	var n := maxi(_box().y, 1)
	var title := "%s   %d/%d" % [_short(clip_name), _shown_index() + 1, n]
	if clip_name == BATH_CLIP:
		return title + "  + BANERA"
	if clip_name == RIDE_CLIP:
		return title + "  + TIOVIVO"
	return title


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
			prop_frame = main.ROUND_ANIM + posmod(_shown_index(), 8)
		_paint_building(draws, kind, origin, alpha, prop_frame)
		if draws.size() > before:
			sort_y = float(draws[draws.size() - 1].get("sy", 0.0)) + 1.0
		if kind == Catalog.BLD_TUB:
			pos = origin + Catalog.TUB_SEAT_OFF + off
			lift = _bath_lift(_shown_index())
	main._push_iso(draws, pos, frame, Color(1, 1, 1, alpha), lift, ThrongTune.frame_scale(clip_name, _shown_index()))
	draws[draws.size() - 1]["rot"] = ThrongTune.frame_rot(clip_name, _shown_index())
	if not is_nan(sort_y):
		draws[draws.size() - 1]["sy"] = sort_y
	if mirror:
		draws[draws.size() - 1]["flip"] = -1.0


func _paint_anim(draws: Array, origin: Vector2, alpha: float) -> void:
	var key := _anim_key(clip_name)
	var index := _shown_index()
	var off: Vector2 = AnimTune.frame_offset(key, index)
	var frame := _box().x + index
	main._push_iso(draws, origin + off, frame, Color(1, 1, 1, alpha), 0.0, AnimTune.frame_scale(key, index))
	draws[draws.size() - 1]["rot"] = AnimTune.frame_rot(key, index)
	if mirror:
		draws[draws.size() - 1]["flip"] = -1.0


func _partner_kind(clip: String) -> int:
	if clip == BATH_CLIP:
		return Catalog.BLD_TUB
	if clip == RIDE_CLIP:
		return Catalog.BLD_ROUND
	return -1


func _bath_lift(index: int) -> float:
	if index >= 5:
		return Catalog.TUB_SOAK_LIFT
	return lerpf(Catalog.TUB_ENTER_LIFT, Catalog.TUB_SOAK_LIFT, float(index) / 4.0)


func _paint_building(draws: Array, kind: int, origin: Vector2, alpha: float, frame_override: int) -> void:
	var row: Dictionary = PropTune.entry("building:%d" % kind)
	if row.is_empty():
		return
	var tune: Dictionary = PropTune.get_tune(str(row.id))
	var frame := frame_override
	if frame < 0:
		frame = _frame_of(row)
	var at: Vector2 = _anchor(row, origin, tune, frame)
	var tint := Color(1, 1, 1, alpha)
	if kind == Catalog.BLD_TUB:
		tint = Color(0.85, 0.95, 1.0, alpha)
	main._push_iso(draws, at, frame, tint, 0.0, float(tune.scale))
	var last: Dictionary = draws[draws.size() - 1]
	last["sy"] = float(last.get("sy", last.p.y)) + float(tune.z)
	last["rot"] = float(tune.rot)


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


func _sync_playhead() -> void:
	if throng_name and clip_name != "":
		throng_name.text = _clip_title()
	_mark_frames()
	_sync_rot_box()


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


func _toggle_mirror() -> void:
	mirror = not mirror
	_sync_play_button()


func _step(dir: int) -> void:
	if clip_name == "":
		return
	var n := maxi(_box().y, 1)
	frame_i = posmod(_shown_index() + dir, n)
	playing = false
	_sync_play_button()
	_sync_playhead()


func _sync_play_button() -> void:
	if play_button:
		play_button.text = "PAUSA" if playing else "PLAY"
	if mirror_button:
		mirror_button.modulate = Color(1, 0.86, 0.4) if mirror else Color.WHITE
	if all_button:
		all_button.modulate = Color(1, 0.86, 0.4) if apply_all else Color.WHITE


func _build_strip() -> void:
	for child in strip.get_children():
		strip.remove_child(child)
		child.queue_free()
	frame_buttons.clear()
	var box := _box()
	for i in box.y:
		var button := Button.new()
		button.icon = _frame_tex(box.x + i)
		button.custom_minimum_size = Vector2(28, 28)
		button.expand_icon = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_pin_frame.bind(i))
		strip.add_child(button)
		frame_buttons.append(button)


func _pin_frame(i: int) -> void:
	playing = false
	frame_i = i
	_sync_play_button()
	_sync_playhead()


func _frame_tex(frame: int) -> AtlasTexture:
	var tex: Texture2D = main.world.texture
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var cols := ThrongClips.SHEET_COLS
	var rows := ThrongClips.SHEET_ROWS
	var cw := float(tex.get_width()) / float(cols)
	var ch := float(tex.get_height()) / float(rows)
	var col := frame % cols
	var row := frame / cols
	atlas.region = Rect2(float(col) * cw, float(row) * ch, cw, ch)
	return atlas


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


func _reset_clip() -> void:
	if clip_name == "":
		return
	if _is_anim(clip_name):
		AnimTune.reset(_anim_key(clip_name))
	else:
		ThrongTune.reset(clip_name)
	_fill_clip()
	_mark_clips()
	_refresh_status()


func _on_filter(text: String) -> void:
	var q := text.strip_edges().to_lower()
	for key in clip_buttons.keys():
		var button: Button = clip_buttons[key]
		var clip := str(key)
		button.visible = q == "" or q in clip.to_lower() or q in _short(clip).to_lower()


func _mark_clips() -> void:
	for key in clip_buttons.keys():
		var button: Button = clip_buttons[key]
		var clip := str(key)
		var dirty: bool = AnimTune.is_dirty(_anim_key(clip)) if _is_anim(clip) else ThrongTune.is_dirty(clip)
		if clip == clip_name:
			button.modulate = Color(1, 0.86, 0.4)
		elif dirty:
			button.modulate = Color(0.65, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE


func _mark_frames() -> void:
	var index := _shown_index()
	for i in frame_buttons.size():
		var button: Button = frame_buttons[i]
		if not is_instance_valid(button):
			continue
		button.modulate = Color(1, 0.86, 0.4) if i == index else Color.WHITE


func _on_throng_fps(v: float) -> void:
	if _fill or clip_name == "":
		return
	if _is_anim(clip_name):
		AnimTune.set_fps(_anim_key(clip_name), v)
	else:
		ThrongTune.set_fps(clip_name, v)
	_mark_clips()
	_refresh_status()


func _toggle_all() -> void:
	apply_all = not apply_all
	_sync_play_button()


func _edit_indexes() -> Array:
	var indexes: Array = []
	if apply_all:
		for i in maxi(_box().y, 1):
			indexes.append(i)
		return indexes
	indexes.append(_shown_index())
	return indexes


func _hold_frame() -> int:
	var index := _shown_index()
	if playing:
		frame_i = index
		playing = false
		_sync_play_button()
	return index


func _on_throng_scale(v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for index in _edit_indexes():
		if _is_anim(clip_name):
			AnimTune.set_frame_scale(_anim_key(clip_name), int(index), v)
		else:
			ThrongTune.set_frame_scale(clip_name, int(index), v)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()


func _on_throng_offset(_v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for index in _edit_indexes():
		if _is_anim(clip_name):
			AnimTune.set_frame_offset(_anim_key(clip_name), int(index), throng_x.value, throng_y.value)
		else:
			ThrongTune.set_frame_offset(clip_name, int(index), throng_x.value, throng_y.value)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()


func _on_throng_rot(v: float) -> void:
	if _fill or clip_name == "":
		return
	var shown := _hold_frame()
	for index in _edit_indexes():
		if _is_anim(clip_name):
			AnimTune.set_frame_rot(_anim_key(clip_name), int(index), v)
		else:
			ThrongTune.set_frame_rot(clip_name, int(index), v)
	_rot_shown = shown
	_mark_clips()
	_refresh_status()
