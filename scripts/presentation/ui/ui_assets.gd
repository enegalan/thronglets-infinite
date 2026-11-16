extends RefCounted
class_name UIAssets

var _textures := {}


func tex(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var t: Texture2D = load(path)
	if t == null or t.get_width() < 1:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_textures[path] = t
	return t


func tex_rgba(path: String) -> Texture2D:
	var key := path + "::rgba"
	if _textures.has(key):
		return _textures[key]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return tex(path)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_textures[key] = t
	return t


func ui_font() -> FontFile:
	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	font.allow_system_fallback = false
	if font.load_dynamic_font("res://resources/ui/VT323-Regular.ttf") == OK:
		return font
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	if font.load_dynamic_font("res://resources/ui/aline_font.ttf") == OK:
		return font
	return null


func dos_font() -> FontFile:
	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if font.load_dynamic_font("res://resources/ui/PerfectDOSVGA437.ttf") == OK:
		return font
	return ui_font()


func menu_ink() -> Color:
	return Color(0.28, 0.14, 0.05)


func panel_style() -> StyleBoxTexture:
	var style := box_style("res://resources/ui/ui_frame_9patch.png", 8, 8)
	style.content_margin_top = 14
	return style


func slot_style() -> StyleBoxTexture:
	return box_style("res://resources/ui/ui_slot.png", 4, 3)


func choice_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	return style


func goal_ink() -> Color:
	return Color(0.188, 0.322, 0.416)


func oldos_plate_style(pad: int = 3) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex_rgba("res://resources/ui/ui_oldos_button.png")
	style.texture_margin_left = 20
	style.texture_margin_right = 17
	style.texture_margin_top = 20
	style.texture_margin_bottom = 18
	style.set_content_margin_all(pad)
	return style


func goal_outer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(3)
	style.shadow_color = Color(0.22, 0.22, 0.2, 0.7)
	style.shadow_size = 2
	style.shadow_offset = Vector2(3, 3)
	style.set_content_margin_all(3)
	return style


func goal_cyan_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(88.0 / 255.0, 192.0 / 255.0, 216.0 / 255.0, 1)
	style.set_border_width_all(2)
	style.set_content_margin_all(2)
	return style


func goal_tag_style() -> StyleBoxTexture:
	return box_style("res://resources/ui/ui_goal_tag.png", 0, 3)


func goal_body_style() -> StyleBoxTexture:
	return box_style("res://resources/ui/ui_goal_body.png", 0, 3)


func box_style(path: String, edge: int, pad: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex(path)
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	style.texture_margin_top = edge
	style.texture_margin_bottom = edge
	style.set_content_margin_all(pad)
	return style


func speech_bubble_style() -> StyleBoxTexture:
	var style := box_style("res://resources/ui/speech_bubble_0.png", 6, 6)
	bubble_margins(style, 0)
	return style


func bubble_margins(style: StyleBoxTexture, frame: int) -> void:
	var _frame := frame
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.texture_margin_top = 8
	style.texture_margin_bottom = 12
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 10


func apply_bubble_frame(panel: PanelContainer, frame: int) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null:
		return
	style.texture = tex("res://resources/ui/speech_bubble_%d.png" % frame)
	bubble_margins(style, frame)
