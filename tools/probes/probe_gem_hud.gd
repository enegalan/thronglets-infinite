extends SceneTree

const UIAssets := preload("res://scripts/presentation/ui/ui_assets.gd")
const PLAQUE_H := 36


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui_assets: UIAssets = UIAssets.new()
	var vp := SubViewport.new()
	vp.size = Vector2i(260, 90)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	root.add_child(vp)

	var root_ctrl := Control.new()
	root_ctrl.size = Vector2(260, 90)
	vp.add_child(root_ctrl)

	var badge := TextureRect.new()
	badge.texture = ui_assets.tex("res://resources/ui/thronglet_counter.png")
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	badge.position = Vector2(6, 6)
	badge.size = Vector2(60, 60)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP
	root_ctrl.add_child(badge)

	var gem_panel := Control.new()
	gem_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_panel.position = Vector2(72, 18)
	gem_panel.custom_minimum_size = Vector2(96, PLAQUE_H)
	gem_panel.size = Vector2(96, PLAQUE_H)
	root_ctrl.add_child(gem_panel)

	var gem_bg := NinePatchRect.new()
	gem_bg.texture = ui_assets.tex("res://resources/ui/gem_frame.png")
	gem_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem_bg.patch_margin_left = 17
	gem_bg.patch_margin_right = 19
	gem_bg.patch_margin_top = 5
	gem_bg.patch_margin_bottom = 5
	gem_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_panel.add_child(gem_bg)

	var gem_row := HBoxContainer.new()
	gem_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem_row.offset_left = 10
	gem_row.offset_top = 0
	gem_row.offset_right = -14
	gem_row.offset_bottom = 0
	gem_row.add_theme_constant_override("separation", 10)
	gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_panel.add_child(gem_row)

	var gem_icon_slot := CenterContainer.new()
	gem_icon_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gem_row.add_child(gem_icon_slot)

	var gem_icon := TextureRect.new()
	gem_icon.texture = ui_assets.tex("res://resources/ui/gem_icon.png")
	gem_icon.custom_minimum_size = Vector2(17, 18)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_icon_slot.add_child(gem_icon)

	var gem_label_slot := CenterContainer.new()
	gem_label_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gem_row.add_child(gem_label_slot)

	var gem_label := Label.new()
	gem_label.text = "642"
	var font := ui_assets.ui_font()
	if font != null:
		gem_label.add_theme_font_override("font", font)
	gem_label.add_theme_font_size_override("font_size", 18)
	gem_label.add_theme_constant_override("line_spacing", -2)
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_label.add_theme_color_override("font_color", Color.WHITE)
	gem_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gem_label.add_theme_constant_override("outline_size", 2)
	gem_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	gem_label.add_theme_constant_override("shadow_offset_x", 1)
	gem_label.add_theme_constant_override("shadow_offset_y", 1)
	gem_label_slot.add_child(gem_label)

	await process_frame
	await process_frame
	var text_w := gem_label.get_minimum_size().x
	var width := int(ceil(10.0 + 17.0 + 10.0 + text_w + 14.0))
	width = maxi(width, 96)
	gem_panel.custom_minimum_size = Vector2(width, PLAQUE_H)
	gem_panel.size = Vector2(width, PLAQUE_H)
	await process_frame
	await process_frame

	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("probe_gem_hud: empty capture")
		quit(1)
		return
	img.save_png("res://shots/hud_gem_probe.png")
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("res://shots/hud_gem_probe_x3.png")
	print("PROBE GEM HUD OK size=%sx%s plaque=%sx%s" % [vp.size.x, vp.size.y, width, PLAQUE_H])
	quit(0)
