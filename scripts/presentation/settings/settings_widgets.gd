extends RefCounted
class_name SettingsWidgets

## Default deep blue tint matching TuckerSoft-style settings buttons.
const SETTINGS_BLUE := Color(0.0, 0.0, 170.0 / 255.0)


## Nine-patch style for blue settings buttons.
static func settings_blue_style(ui_assets) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ui_assets.tex_rgba("res://resources/ui/settings/button.png")
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## DOS-styled button that plays UI click.
static func settings_blue_button(text: String, call: Callable, ui_assets, media, min_w: float = 150.0) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(min_w, 28)
	var style := settings_blue_style(ui_assets)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_font_override("font", ui_assets.dos_font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 1.0))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.pressed.connect(func() -> void:
		media.play("ui")
		call.call()
	)
	return button


## White DOS font label for settings rows.
static func settings_label(text: String, ui_assets) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ui_assets.dos_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Label plus checkbox toggle button row.
static func settings_check_row(text: String, on: bool, call: Callable, ui_assets, media) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := settings_label(text, ui_assets)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var box := TextureButton.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.ignore_texture_size = true
	box.stretch_mode = TextureButton.STRETCH_SCALE
	box.texture_normal = ui_assets.tex_rgba(
		"res://resources/ui/settings/checkbox_on.png" if on else "res://resources/ui/settings/checkbox.png"
	)
	box.pressed.connect(func() -> void:
		media.play("ui")
		call.call()
	)
	row.add_child(box)
	return row


## Label, minus, slider, plus volume row.
static func settings_slider_row(
		text: String,
		value: float,
		call: Callable,
		ui_assets,
		media,
		on_refresh: Callable,
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := settings_label(text, ui_assets)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var minus := TextureButton.new()
	minus.texture_normal = ui_assets.tex_rgba("res://resources/ui/settings/slider_minus.png")
	minus.ignore_texture_size = true
	minus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	minus.custom_minimum_size = Vector2(14, 14)
	minus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minus.pressed.connect(func() -> void:
		media.play("ui")
		call.call(clampf(value - 0.1, 0.0, 1.0))
		if on_refresh.is_valid():
			on_refresh.call()
	)
	row.add_child(minus)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 20)
	slider.add_theme_stylebox_override("slider", settings_slider_track())
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.add_theme_icon_override("grabber", ui_assets.tex_rgba("res://resources/ui/settings/slider_thumb.png"))
	slider.add_theme_icon_override("grabber_highlight", ui_assets.tex_rgba("res://resources/ui/settings/slider_thumb.png"))
	slider.value_changed.connect(func(v: float) -> void:
		call.call(v)
	)
	row.add_child(slider)
	var plus := TextureButton.new()
	plus.texture_normal = ui_assets.tex_rgba("res://resources/ui/settings/slider_plus.png")
	plus.ignore_texture_size = true
	plus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	plus.custom_minimum_size = Vector2(14, 14)
	plus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plus.pressed.connect(func() -> void:
		media.play("ui")
		call.call(clampf(value + 0.1, 0.0, 1.0))
		if on_refresh.is_valid():
			on_refresh.call()
	)
	row.add_child(plus)
	return row


## Flat white stylebox for slider groove.
static func settings_slider_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.set_content_margin_all(0)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

