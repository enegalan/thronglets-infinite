extends RefCounted
class_name ConsoleUI

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const DialogueBook := preload("res://scripts/data/dialogue/dialogue_book.gd")

## Main host exposing gaze panels, console glyphs, UI assets, and media cues.
var host: Node2D
## Camera rig reference for future world-anchored console layout.
var cam_rig: CameraRig

## Attaches the presentation host that owns gaze widgets and console art.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host
	cam_rig = p_cam_rig

## Retro green frame, rules, and optional swirl art.
func build_console_frame(panel: Control, edge: float = 2.0, pattern: int = -1) -> void:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var fill := ColorRect.new()
	fill.color = Color(0.0, 0.02, 0.0, 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = edge
	fill.offset_top = edge
	fill.offset_right = -edge
	fill.offset_bottom = -edge
	frame.add_child(fill)
	var ink := Color(0.0, 224.0 / 255.0, 0.0)
	console_rule(frame, true, false, edge, ink)
	console_rule(frame, true, true, edge, ink)
	console_rule(frame, false, false, edge, ink)
	console_rule(frame, false, true, edge, ink)
	if pattern >= 0:
		panel.clip_contents = true
		panel.set_meta("pattern", pattern)
		add_swirls(panel, pattern)
		add_side_glyphs(panel, edge)
		add_corner_glyphs(panel, pattern)


## Adds one console border bar to a frame.
func console_rule(frame: Control, horizontal: bool, at_end: bool, thick: float, ink: Color) -> void:
	var bar := ColorRect.new()
	bar.color = ink
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		bar.anchor_right = 1.0
		if at_end:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -thick
		else:
			bar.offset_bottom = thick
	elif at_end:
		bar.anchor_left = 1.0
		bar.anchor_right = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_left = -thick
	else:
		bar.anchor_bottom = 1.0
		bar.offset_right = thick
	frame.add_child(bar)


## Attaches swirl background textures to a panel.
func add_swirls(panel: Control, pattern: int) -> void:
	var atlas := "res://resources/ui/atlas/Sprites-ConsoleUI/"
	if pattern == 0:
		swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background_Left.png", "swirl_l")
	swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background_Right.png", "swirl_r")
	var line := swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background.png", "swirl_line")
	line.anchor_right = 1.0


## Spawns a nearest-neighbor swirl strip anchored to a panel edge for console chrome.
func swirl_rect(panel: Control, path: String, node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = host.ui_assets.tex(path)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_top = 0.0
	rect.anchor_bottom = 0.0
	if node_name.ends_with("_r"):
		rect.anchor_left = 1.0
		rect.anchor_right = 1.0
	panel.add_child(rect)
	return rect


## Adds side decorative glyph strips.
func add_side_glyphs(panel: Control, edge: float) -> void:
	var atlas := "res://resources/ui/atlas/Sprites-ConsoleUI/"
	side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Left_Background_Map.png", true, edge, "side_back_l")
	side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Right_Background_Map.png", false, edge, "side_back_r")
	side_glyph(panel, atlas + "UI_DialogueUI_UI_E_AddlGlyphs_Left_Foreground_Map.png", true, edge, "side_glyph_l")
	side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Right_Foreground_Map.png", false, edge, "side_glyph_r")


## One vertical side glyph strip on the panel edge.
func side_glyph(panel: Control, path: String, left: bool, edge: float, node_name: String) -> void:
	var strip := TextureRect.new()
	strip.name = node_name
	strip.texture = host.ui_assets.tex(path)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.anchor_top = 0.0
	strip.anchor_bottom = 0.0
	if left:
		strip.anchor_left = 0.0
		strip.anchor_right = 0.0
	else:
		strip.anchor_left = 1.0
		strip.anchor_right = 1.0
	strip.offset_top = edge
	strip.offset_bottom = edge
	strip.set_meta("edge", edge)
	panel.add_child(strip)


## Animated corner glyphs for dialogue slots.
func add_corner_glyphs(panel: Control, pattern: int) -> void:
	var presets: Array[int] = [
		Control.PRESET_TOP_LEFT,
		Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT,
		Control.PRESET_BOTTOM_RIGHT,
	]
	for i in presets.size():
		var glyph := TextureRect.new()
		glyph.name = "corner_%d" % i
		glyph.set_anchors_preset(presets[i])
		glyph.flip_h = i == 0 or i == 2
		glyph.flip_v = i <= 1
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.self_modulate = Color(0.0, 1.0, 0.0)
		glyph.set_meta("corner", i)
		glyph.set_meta("phase", pattern * 2)
		if not host.console_glyphs.is_empty():
			glyph.texture = host.console_glyphs[i % host.console_glyphs.size()]
		host.console_corner_glyphs.append(glyph)
		panel.add_child(glyph)


## Sizes corner glyphs to slot height.
func fit_corner_glyphs(panel: Control, height: float) -> void:
	var size := minf(36.0, maxf(14.0, height * 0.42))
	for child in panel.get_children():
		var glyph := child as TextureRect
		if glyph == null or not str(glyph.name).begins_with("corner_"):
			continue
		var corner := int(glyph.get_meta("corner", 0))
		var right := corner == 1 or corner == 3
		var bottom := corner >= 2
		glyph.offset_left = -size if right else 0.0
		glyph.offset_right = 0.0 if right else size
		glyph.offset_top = -size if bottom else 0.0
		glyph.offset_bottom = 0.0 if bottom else size


## Layouts swirls, sides, and corners for panel height.
func fit_console_art(panel: Control, panel_h: float, slot_h: float) -> void:
	var pattern := int(panel.get_meta("pattern", 0))
	var shift_l := 0.0
	var shift_r := 0.0
	if pattern == 1:
		shift_l = 0.08
		shift_r = 0.62
	elif pattern == 2:
		shift_l = 0.48
		shift_r = 0.18
	elif pattern >= 3:
		shift_l = 0.72
		shift_r = 0.40
	var slide := 0.0 if pattern == 0 else float(pattern - 1) * slot_h
	fit_swirls(panel, panel_h, slot_h, slide)
	fit_side_glyphs(panel, panel_h, shift_l, shift_r)
	fit_corner_glyphs(panel, slot_h)


## Positions swirl textures within the console panel.
func fit_swirls(panel: Control, panel_h: float, slot_h: float, slide: float) -> void:
	var pattern := int(panel.get_meta("pattern", 0))
	var edge := 2.0
	var inner := maxf(8.0, panel_h - edge * 2.0)
	for child in panel.get_children():
		var rect := child as TextureRect
		if rect == null or not str(rect.name).begins_with("swirl_"):
			continue
		if str(rect.name) == "swirl_line":
			var along := 0.55 if pattern == 0 else float((pattern - 1) % 3) / 2.0
			var y := edge + maxf(0.0, slot_h - edge * 2.0 - 4.0) * along
			rect.offset_left = edge
			rect.offset_right = -edge
			rect.offset_top = y
			rect.offset_bottom = y + 4.0
			continue
		var tex := rect.texture
		if tex == null or tex.get_height() <= 0:
			continue
		var width := inner * float(tex.get_width()) / float(tex.get_height())
		rect.offset_top = edge - slide
		rect.offset_bottom = edge - slide + inner
		if str(rect.name).ends_with("_l"):
			rect.offset_left = edge
			rect.offset_right = edge + width
		else:
			rect.offset_right = -edge
			rect.offset_left = -(edge + width)


## Positions side strips with optional vertical shift.
func fit_side_glyphs(panel: Control, height: float, shift_l: float = 0.0, shift_r: float = 0.0) -> void:
	for child in panel.get_children():
		var strip := child as TextureRect
		if strip == null or not str(strip.name).begins_with("side_"):
			continue
		var tex := strip.texture
		if tex == null or tex.get_height() <= 0:
			continue
		var edge := float(strip.get_meta("edge", 3.0))
		var inner := maxf(8.0, height - edge * 2.0)
		var width := inner * float(tex.get_width()) / float(tex.get_height())
		var shift := shift_l if str(strip.name).ends_with("_l") else shift_r
		strip.offset_top = edge - shift * inner
		strip.offset_bottom = strip.offset_top + inner
		if str(strip.name).ends_with("_l"):
			strip.offset_left = edge
			strip.offset_right = edge + width
		else:
			strip.offset_right = -edge
			strip.offset_left = -(edge + width)


## Adds corner and optional mid-side console glyphs.
func pin_glyphs(panel: Control, size: float) -> void:
	var corners: Array[int] = [
		Control.PRESET_TOP_LEFT,
		Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT,
		Control.PRESET_BOTTOM_RIGHT,
	]
	for i in corners.size():
		var glyph := TextureRect.new()
		glyph.set_anchors_preset(corners[i])
		glyph.flip_h = i == 1 or i == 3
		glyph.flip_v = i >= 2
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.offset_left = -size if glyph.flip_h else 0.0
		glyph.offset_right = 0.0 if glyph.flip_h else size
		glyph.offset_top = -size if glyph.flip_v else 0.0
		glyph.offset_bottom = 0.0 if glyph.flip_v else size
		if not host.console_glyphs.is_empty():
			glyph.texture = host.console_glyphs[i % host.console_glyphs.size()]
		panel.add_child(glyph)
		host.console_corner_glyphs.append(glyph)
	if size < 40.0:
		return
	for side in 2:
		var glyph := TextureRect.new()
		glyph.anchor_top = 0.5
		glyph.anchor_bottom = 0.5
		glyph.anchor_left = 0.0 if side == 0 else 1.0
		glyph.anchor_right = glyph.anchor_left
		glyph.flip_h = side == 1
		glyph.offset_left = -size if side == 1 else 0.0
		glyph.offset_right = 0.0 if side == 1 else size
		glyph.offset_top = -size * 0.5
		glyph.offset_bottom = size * 0.5
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not host.console_glyphs.is_empty():
			glyph.texture = host.console_glyphs[side % host.console_glyphs.size()]
		panel.add_child(glyph)
		host.console_corner_glyphs.append(glyph)


## Advances gaze dialogue on console click.
func on_console_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var sim: ThrongletSim = ThrongletSimServer
	if sim.modal.is_empty():
		return
	var naming := str(sim.modal.get("event", "")) == "player_name" and str(sim.modal.get("step", "")) == "echo"
	if not naming and not sim.modal.has("lines"):
		return
	host.media.play("console_select")
	sim.dialogue.choose(0)
	host.get_viewport().set_input_as_handled()


## Rebuilds gaze choices and typewriter console text.
func sync_gaze() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.game_over or sim.modal.is_empty():
		if host.shown_event != "":
			host.media.play("dialogue_out")
		host.gaze_panel.visible = false
		host.shown_event = ""
		host.shown_seq = 0
		host.console_line = ""
		host.console_reveal = 0
		host.console_shown = ""
		host.console_corner_glyphs.clear()
		return
	var event := str(sim.modal.event)
	var seq := int(sim.modal.get("seq", 1))
	if event != host.shown_event or seq != host.shown_seq:
		if event != host.shown_event:
			if host.shown_event != "":
				host.media.play("dialogue_out")
			host.media.play("dialogue_in")
		else:
			host.media.play("console")
		var session := {
			"tree": str(sim.modal.get("tree", "")),
			"node": str(sim.modal.get("node", "")),
			"log": sim.modal.get("log", []),
			"seq": seq,
		}
		var next_line: String = sim.dialogue.address(DialogueBook.log_text(session)).replace("[", "(").replace("]", ")")
		var keep_prefix: bool = event == host.shown_event and host.console_line != "" and next_line.begins_with(host.console_line)
		host.console_reveal = host.console_line.length() if keep_prefix else 0
		host.console_line = next_line
		host.console_shown = ""
		host.shown_event = event
		host.shown_seq = seq
		for child in host.gaze_box.get_children():
			child.queue_free()
		host.console_corner_glyphs.clear()
		var line_talk: bool = sim.modal.has("lines")
		if host.gaze_face != null:
			host.gaze_face.visible = not line_talk
			host.gaze_face.custom_minimum_size = Vector2.ZERO if line_talk else Vector2(72, 72)
			if not line_talk:
				var face_key := "epilogue_caretaker"
				if host.ui_assets.POP_FACES.has(sim.mood_face):
					face_key = sim.mood_face
				elif bool(sim.mutations.get("care", false)):
					face_key = "epilogue_caretaker"
				elif bool(sim.mutations.get("numb", false)) or bool(sim.mutations.get("hard", false)):
					face_key = "epilogue_angry"
				host.gaze_face.texture = host.ui_assets.tex(host.ui_assets.POP_FACES[face_key])
		var choices: Array = [] if line_talk else DialogueBook.choices_of(session)
		var naming := event == "player_name"
		var name_step := str(sim.modal.get("step", ""))
		if naming:
			if host.gaze_face != null:
				host.gaze_face.visible = false
				host.gaze_face.custom_minimum_size = Vector2.ZERO
			if name_step == "ask":
				choices = [{"label": LineBook.row("SYS.PLAYERINPUT", 1)}]
			elif name_step == "confirm":
				choices = [
					{"label": LineBook.row("SYS.PLAYERINPUT", 3)},
					{"label": LineBook.row("SYS.PLAYERINPUT", 4)},
				]
			else:
				choices = []
			if host.name_edit != null:
				host.name_edit.visible = name_step == "ask"
				if name_step == "ask":
					host.name_edit.text = str(sim.modal.get("draft", ""))
					host.name_edit.grab_focus()
		elif host.name_edit != null:
			host.name_edit.visible = false
		var ink := Color(0.22, 0.86, 0.28)
		var flat := StyleBoxEmpty.new()
		flat.content_margin_left = 32
		flat.content_margin_right = 22
		flat.content_margin_top = 10
		flat.content_margin_bottom = 8
		for i in choices.size():
			var edge: Dictionary = choices[i] if choices[i] is Dictionary else {}
			var slot := Control.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.clip_contents = true
			build_console_frame(slot, 2.0, i + 1)
			var button := Button.new()
			button.set_anchors_preset(Control.PRESET_FULL_RECT)
			button.text = str(edge.get("label", ""))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_color_override("font_color", ink)
			button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
			button.add_theme_color_override("font_focus_color", Color(0.7, 1.0, 0.7))
			button.add_theme_color_override("font_pressed_color", Color(0.1, 0.45, 0.16))
			button.add_theme_color_override("font_hover_pressed_color", Color(0.1, 0.45, 0.16))
			button.add_theme_stylebox_override("normal", flat)
			button.add_theme_stylebox_override("hover", flat)
			button.add_theme_stylebox_override("focus", flat)
			button.add_theme_stylebox_override("pressed", flat)
			button.add_theme_stylebox_override("hover_pressed", flat)
			var index := i
			button.pressed.connect(func():
				host.media.play("console_select")
				if host.name_edit != null and host.name_edit.visible:
					ThrongletSimServer.modal["draft"] = host.name_edit.text
				ThrongletSimServer.dialogue.choose(index)
			)
			slot.add_child(button)
			host.gaze_box.add_child(slot)
	if host.console_line != "":
		if host.console_reveal < host.console_line.length():
			host.console_reveal = mini(host.console_line.length(), host.console_reveal + 4)
		var shown: String = host.console_line.substr(0, host.console_reveal)
		if shown != host.console_shown:
			host.console_shown = shown
			host.gaze_text.clear()
			host.gaze_text.add_theme_font_size_override("normal_font_size", 16)
			host.gaze_text.add_theme_color_override("default_color", Color(0.22, 0.86, 0.28))
			host.gaze_text.append_text(shown)
	if not host.console_glyphs.is_empty():
		var tick := int(host.anim_time * 1000.0 / 160.0)
		var alive: Array[TextureRect] = []
		for i in host.console_corner_glyphs.size():
			var node = host.console_corner_glyphs[i]
			if not is_instance_valid(node) or not (node is TextureRect):
				continue
			var glyph: TextureRect = node
			var phase := int(glyph.get_meta("phase", 0))
			glyph.texture = host.console_glyphs[(tick + i + phase) % host.console_glyphs.size()]
			alive.append(glyph)
		host.console_corner_glyphs = alive
	host.gaze_panel.visible = true
	layout_console()
	if host.console_line != "" and host.gaze_text.get_line_count() > 0:
		host.gaze_text.scroll_to_line(host.gaze_text.get_line_count() - 1)


## Splits gaze log and choice column widths.
func layout_console() -> void:
	if host.gaze_log == null or host.gaze_box == null:
		return
	var width: float = host.gaze_panel.offset_right - host.gaze_panel.offset_left
	var count := 0
	for child in host.gaze_box.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	var gap := 4.0
	host.gaze_log.offset_left = 0.0
	host.gaze_log.offset_top = 0.0
	host.gaze_log.offset_bottom = 0.0
	var panel_h: float = host.gaze_panel.offset_bottom - host.gaze_panel.offset_top
	if count <= 0 or width < 32.0:
		host.gaze_log.offset_right = 0.0
		host.gaze_box.visible = false
		fit_console_art(host.gaze_log, panel_h, panel_h)
		return
	var choice_w := int(width * 0.4)
	host.gaze_log.offset_right = -(choice_w + gap)
	host.gaze_box.visible = true
	host.gaze_box.offset_left = -choice_w
	host.gaze_box.offset_right = 0.0
	host.gaze_box.offset_top = 0.0
	host.gaze_box.offset_bottom = 0.0
	fit_console_art(host.gaze_log, panel_h, panel_h)
	var slot_h: float = (panel_h - gap * float(count - 1)) / float(count)
	for child in host.gaze_box.get_children():
		if child is Control and not child.is_queued_for_deletion():
			fit_console_art(child, panel_h, slot_h)
