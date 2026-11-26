extends RefCounted
class_name VideoLibrary

## Dark purple ink for faux-DOS filenames and shell button text in the video browser.
const VIDEO_SHELL_INK := Color(29.0 / 255.0, 22.0 / 255.0, 73.0 / 255.0)
## Cyan used for shell borders, title bar accents, and inner panel fills.
const VIDEO_SHELL_CYAN := Color(88.0 / 255.0, 200.0 / 255.0, 218.0 / 255.0)
## Story clips listed as retro movie files with ids, labels, and thumbnail keys.
const VIDEO_LIBRARY := [
	{"id": "SEQ_1.5", "label": "MOV_01_AB4F12.MOV", "thumb": "1.5"},
	{"id": "SEQ_2.1", "label": "MOV_02_208FA3.MOV", "thumb": "2.1"},
	{"id": "SEQ_3.4", "label": "MOV_03_09FF90.MOV", "thumb": "3.4"},
	{"id": "SEQ_4.2", "label": "MOV_04_0024AB.MOV", "thumb": "4.2"},
	{"id": "SEQ_5.3", "label": "MOV_05_AB4F12.MOV", "thumb": "5.3"},
	{"id": "SEQ_6.2", "label": "MOV_06_FFFDA7.MOV", "thumb": "6.2"},
	{"id": "SEQ_7.3", "label": "MOV_07_73757A.MOV", "thumb": "7.3"},
	{"id": "SEQ_8.3", "label": "MOV_08_12412B.MOV", "thumb": "8.3"},
]

## Main scene node used for viewport sizing and parenting the overlay.
var host: Node2D
## Plays UI feedback and full-screen clips when the user picks an unlocked entry.
var media
## Shared DOS font and nine-patch textures for shell chrome and thumbnails.
var ui_assets

## Full-screen overlay that dims the title and blocks input behind the browser.
var video_library: Control
## Sized faux-terminal frame (shadow, border, title bar, and content plate).
var video_library_shell: Control
## Three-column thumbnail grid plus the exit cell at the end of the list.
var video_library_grid: GridContainer

## Returns the title backdrop control so shell layout can match its size.
var _get_title_root: Callable
## Returns the title HUD menu control hidden while the library is open.
var _get_title_menu: Callable


## Wires host, media, assets, and title accessors.
func setup(
		p_host: Node2D,
		p_media,
		p_ui_assets,
		get_title_root: Callable,
		get_title_menu: Callable,
) -> void:
	host = p_host
	media = p_media
	ui_assets = p_ui_assets
	_get_title_root = get_title_root
	_get_title_menu = get_title_menu


## Constructs faux-shell video grid on the title root.
func build(root: Control) -> void:
	video_library = Control.new()
	video_library.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_library.mouse_filter = Control.MOUSE_FILTER_STOP
	video_library.visible = false
	video_library.z_index = 5
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.15)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	video_library.add_child(dim)

	video_library_shell = Control.new()
	video_library_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	video_library.add_child(video_library_shell)

	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(73.0 / 255.0, 73.0 / 255.0, 73.0 / 255.0, 0.8)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(shadow)

	var chrome := ColorRect.new()
	chrome.name = "Chrome"
	chrome.color = VIDEO_SHELL_CYAN
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(chrome)

	var ring := ColorRect.new()
	ring.name = "Ring"
	ring.color = Color(1, 1, 1, 1)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(ring)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = VIDEO_SHELL_CYAN
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(fill)

	var title_bg := ColorRect.new()
	title_bg.name = "TitleBg"
	title_bg.color = Color(1, 1, 1, 1)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(title_bg)

	var title := Label.new()
	title.name = "Title"
	title.text = "C:\\BIN\\.SHELL\\"
	title.add_theme_font_override("font", ui_assets.dos_font())
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(title)

	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.color = Color(1, 1, 1, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(plate)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 1)
	frame_style.border_color = VIDEO_SHELL_CYAN
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	video_library_shell.add_child(frame)

	var content := PanelContainer.new()
	content.name = "Content"
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(1, 1, 1, 1)
	content_style.border_color = VIDEO_SHELL_CYAN
	content_style.set_border_width_all(1)
	content_style.content_margin_left = 14
	content_style.content_margin_right = 14
	content_style.content_margin_top = 10
	content_style.content_margin_bottom = 8
	content.add_theme_stylebox_override("panel", content_style)
	frame.add_child(content)

	video_library_grid = GridContainer.new()
	video_library_grid.columns = 3
	video_library_grid.add_theme_constant_override("h_separation", 24)
	video_library_grid.add_theme_constant_override("v_separation", 6)
	video_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video_library_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(video_library_grid)
	root.add_child(video_library)


## Shows library and lays out shell geometry.
func open() -> void:
	media.play("ui")
	var title_menu: Control = _get_title_menu.call() as Control if _get_title_menu.is_valid() else null
	if title_menu != null:
		title_menu.visible = false
	fill()
	if video_library != null:
		video_library.visible = true
		layout_shell()


## Hides the video library overlay.
func close() -> void:
	media.play("ui")
	if video_library != null:
		video_library.visible = false


## Positions shell chrome from title viewport size.
func layout_shell() -> void:
	if video_library_shell == null:
		return
	var title_root: Control = _get_title_root.call() as Control if _get_title_root.is_valid() else null
	var area := title_root.size if title_root != null else host.get_viewport_rect().size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(640, 360)
	var chrome_size := Vector2(area.x * 0.88, area.y * 0.96)
	var shadow_o := Vector2(8, 8)
	var shell_size := chrome_size + shadow_o
	video_library_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	video_library_shell.size = shell_size
	video_library_shell.position = (area - chrome_size) * 0.5
	video_library_shell.clip_contents = false
	var border := 12.0
	var ring_w := 2.0
	var shadow := video_library_shell.get_node_or_null("Shadow") as Control
	if shadow != null:
		shadow.position = shadow_o
		shadow.size = chrome_size
	var chrome := video_library_shell.get_node_or_null("Chrome") as Control
	if chrome != null:
		chrome.position = Vector2.ZERO
		chrome.size = chrome_size
	var ring := video_library_shell.get_node_or_null("Ring") as Control
	if ring != null:
		ring.position = Vector2(border - ring_w, border - ring_w)
		ring.size = chrome_size - Vector2(border - ring_w, border - ring_w) * 2.0
	var fill := video_library_shell.get_node_or_null("Fill") as Control
	if fill != null:
		fill.position = Vector2(border, border)
		fill.size = chrome_size - Vector2(border, border) * 2.0
	var inner_pos := Vector2(border, border)
	var inner_size := chrome_size - Vector2(border, border) * 2.0
	var title_h := 18.0
	var cyan_gap := 10.0
	var side_pad := 6.0
	var title_bg := video_library_shell.get_node_or_null("TitleBg") as Control
	if title_bg != null:
		title_bg.position = inner_pos + Vector2(side_pad, 2)
		title_bg.size = Vector2(inner_size.x - side_pad * 2.0, title_h)
	var title := video_library_shell.get_node_or_null("Title") as Control
	if title != null:
		title.position = title_bg.position + Vector2(8, 0) if title_bg != null else inner_pos
		title.size = Vector2(inner_size.x - side_pad * 2.0 - 16, title_h)
	var top := inner_pos.y + 2 + title_h + cyan_gap
	var plate_pos := Vector2(inner_pos.x + side_pad, top)
	var plate_size := Vector2(inner_size.x - side_pad * 2.0, maxf(8.0, inner_pos.y + inner_size.y - top - 4))
	var plate := video_library_shell.get_node_or_null("Plate") as Control
	if plate != null:
		plate.position = plate_pos
		plate.size = plate_size
	var frame := video_library_shell.get_node_or_null("Frame") as Control
	if frame != null:
		frame.position = plate_pos
		frame.size = plate_size


## True when the player has already watched the clip and earns the unlocked thumbnail.
func video_unlocked(clip_id: String) -> bool:
	return bool(media.video_played.get(clip_id, false))


## Rebuilds thumbnail grid and exit cell.
func fill() -> void:
	if video_library_grid == null:
		return
	while video_library_grid.get_child_count() > 0:
		var child: Node = video_library_grid.get_child(0)
		video_library_grid.remove_child(child)
		child.free()
	for entry in VIDEO_LIBRARY:
		video_library_grid.add_child(video_library_cell(entry))
	var exit_wrap := VBoxContainer.new()
	exit_wrap.add_theme_constant_override("separation", 2)
	exit_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	exit_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var exit_btn := Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(96, 64)
	exit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exit_btn.add_theme_font_override("font", ui_assets.dos_font())
	exit_btn.add_theme_font_size_override("font_size", 18)
	exit_btn.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_hover_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_pressed_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_focus_color", VIDEO_SHELL_INK)
	var exit_style := StyleBoxTexture.new()
	exit_style.texture = ui_assets.tex_rgba("res://resources/ui/video/exit.png")
	exit_style.texture_margin_left = 20
	exit_style.texture_margin_top = 20
	exit_style.texture_margin_right = 17
	exit_style.texture_margin_bottom = 18
	exit_style.set_content_margin_all(4)
	var exit_pressed := exit_style.duplicate()
	exit_pressed.texture = ui_assets.tex_rgba("res://resources/ui/video/exit_pressed.png")
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	exit_btn.add_theme_stylebox_override("hover", exit_style)
	exit_btn.add_theme_stylebox_override("pressed", exit_pressed)
	exit_btn.add_theme_stylebox_override("focus", exit_style)
	exit_btn.pressed.connect(close)
	exit_wrap.add_child(exit_btn)
	var exit_pad := Label.new()
	exit_pad.text = " "
	exit_pad.add_theme_font_override("font", ui_assets.dos_font())
	exit_pad.add_theme_font_size_override("font_size", 10)
	exit_pad.modulate = Color(1, 1, 1, 0)
	exit_wrap.add_child(exit_pad)
	video_library_grid.add_child(exit_wrap)


## Thumbnail button and filename label column.
func video_library_cell(entry: Dictionary) -> VBoxContainer:
	var clip_id := str(entry.id)
	var unlocked := video_unlocked(clip_id)
	var thumb_key := str(entry.thumb)
	var thumb_path := "res://resources/ui/video/%s_thumbnail%s.png" % [
		thumb_key,
		"" if unlocked else "_locked",
	]
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var btn := TextureButton.new()
	btn.texture_normal = ui_assets.tex_rgba(thumb_path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.custom_minimum_size = Vector2(96, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(video_library_pick.bind(clip_id, unlocked))
	cell.add_child(btn)
	var label := Label.new()
	label.text = str(entry.label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ui_assets.dos_font())
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	cell.add_child(label)
	return cell


## Plays unlocked clip or ignores locked.
func video_library_pick(clip_id: String, unlocked: bool) -> void:
	media.play("ui")
	if not unlocked:
		return
	if video_library != null:
		video_library.visible = false
	media.video_from_library = true
	if not media.play_video(clip_id, true):
		media.video_from_library = false
		open()

