extends RefCounted
class_name SettingsMenu

const SettingsWidgets := preload("res://scripts/presentation/settings/settings_widgets.gd")
const PrefsController := preload("res://scripts/presentation/prefs/prefs_controller.gd")
const TitleScreen := preload("res://scripts/presentation/title/title_screen.gd")

## Main scene node that owns overlays and receives injected callbacks.
var host: Node2D
## Plays UI clicks and routes volume changes while adjusting settings.
var media
## Shared DOS fonts and texture styles for the settings chrome.
var ui_assets
## Backing store for language, CRT, and debug toggles shown in the editor tab.
var prefs: PrefsController
## Title screen reference so opening settings can suppress title HUD chrome.
var title: TitleScreen

## Index of the foot icon tab whose panel is currently shown (mail, cog, sound, edit).
var settings_tab := 3
## Dimmed full-screen layer over the title that captures input until closed.
var title_menu: Control
## Centered TuckerSoft panel, logo, close control, and tab strip container.
var settings_shell: Control
## Scrollable column where the active tab's rows are rebuilt on each visit.
var settings_body: VBoxContainer
## Foot icon buttons whose selected texture reflects `settings_tab`.
var settings_tabs: Array = []

## Host hook to restore title menu content after closing settings.
var on_fill_title: Callable
## Host hook to return to the title screen after a save wipe.
var on_show_title: Callable
## Host hook that jumps into the dev playground from the cog tab.
var on_enter_dev: Callable
## Host hook that exits the application from the cog tab.
var on_quit_game: Callable
## Host hook that persists prefs after language or toggle changes.
var on_save_prefs: Callable
## Host hook applying SFX volume from the sound tab slider.
var on_set_sfx_vol: Callable
## Host hook applying music volume from the sound tab slider.
var on_set_music_vol: Callable
## Host hook toggling in-game caption overlays.
var on_toggle_captions: Callable
## Host hook toggling CRT post-processing from persisted prefs.
var on_toggle_crt: Callable
## Host hook toggling the on-screen FPS counter.
var on_toggle_show_fps: Callable
## Host hook toggling debug hitbox drawing.
var on_toggle_show_hitboxes: Callable


## Wires host, media, prefs, title, and setting callbacks.
func setup(
		p_host: Node2D,
		p_media,
		p_ui_assets,
		p_prefs,
		p_title: TitleScreen,
		p_on_fill_title: Callable,
		p_on_show_title: Callable,
		p_on_enter_dev: Callable,
		p_on_quit_game: Callable,
		p_on_save_prefs: Callable,
		p_on_set_sfx_vol: Callable,
		p_on_set_music_vol: Callable,
		p_on_toggle_captions: Callable,
		p_on_toggle_crt: Callable,
		p_on_toggle_show_fps: Callable,
		p_on_toggle_show_hitboxes: Callable,
) -> void:
	host = p_host
	media = p_media
	ui_assets = p_ui_assets
	prefs = p_prefs
	title = p_title
	on_fill_title = p_on_fill_title
	on_show_title = p_on_show_title
	on_enter_dev = p_on_enter_dev
	on_quit_game = p_on_quit_game
	on_save_prefs = p_on_save_prefs
	on_set_sfx_vol = p_on_set_sfx_vol
	on_set_music_vol = p_on_set_music_vol
	on_toggle_captions = p_on_toggle_captions
	on_toggle_crt = p_on_toggle_crt
	on_toggle_show_fps = p_on_toggle_show_fps
	on_toggle_show_hitboxes = p_on_toggle_show_hitboxes


## Constructs dimmed settings shell on the title root.
func build(root: Control) -> void:
	title_menu = Control.new()
	title_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	title_menu.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	title_menu.add_child(dim)

	settings_shell = Control.new()
	settings_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_menu.add_child(settings_shell)

	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -210
	col.offset_right = 210
	col.offset_top = -128
	col.offset_bottom = 148
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_shell.add_child(col)

	var panel_wrap := Control.new()
	panel_wrap.custom_minimum_size = Vector2(420, 210)
	panel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(panel_wrap)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 1)
	panel_style.border_color = Color(1, 1, 1, 1)
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	panel_wrap.add_child(panel)

	settings_body = VBoxContainer.new()
	settings_body.add_theme_constant_override("separation", 12)
	settings_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(settings_body)

	var logo := TextureRect.new()
	logo.texture = ui_assets.tex_rgba("res://resources/ui/settings/tuckersoft.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2(8, -10)
	logo.size = Vector2(150, 20)
	panel_wrap.add_child(logo)

	var close := TextureButton.new()
	close.texture_normal = ui_assets.tex_rgba("res://resources/ui/settings/close.png")
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -30
	close.offset_right = -4
	close.offset_top = -12
	close.offset_bottom = 16
	close.pressed.connect(func() -> void:
		media.play("ui")
		if on_fill_title.is_valid():
			on_fill_title.call()
	)
	panel_wrap.add_child(close)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(foot)

	var icons := [
		"res://resources/ui/settings/icon_mail.png",
		"res://resources/ui/settings/icon_cog.png",
		"res://resources/ui/settings/icon_sound.png",
		"res://resources/ui/settings/icon_edit.png",
	]
	settings_tabs.clear()
	for i in icons.size():
		var tab := TextureButton.new()
		tab.ignore_texture_size = true
		tab.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tab.custom_minimum_size = Vector2(36, 38)
		tab.pressed.connect(settings_set_tab.bind(i))
		var icon := TextureRect.new()
		icon.texture = ui_assets.tex_rgba(icons[i])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 6
		icon.offset_right = -6
		icon.offset_bottom = -6
		tab.add_child(icon)
		foot.add_child(tab)
		settings_tabs.append(tab)

	var ver := Label.new()
	ver.text = game_version()
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.add_theme_font_override("font", ui_assets.dos_font())
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	foot.add_child(ver)

	root.add_child(title_menu)


## Shows shell and fills the active tab body.
func fill() -> void:
	if title != null and title.title_hud != null:
		title.title_hud.visible = false
	if title_menu != null:
		title_menu.visible = true
	if settings_shell != null:
		settings_shell.visible = true
	settings_sync_tabs()
	clear_body(settings_body)
	match settings_tab:
		0:
			fill_mail()
		1:
			fill_cog()
		2:
			fill_sound()
		_:
			fill_edit()


## Switches tab index and refreshes content.
func settings_set_tab(index: int) -> void:
	media.play("ui")
	settings_tab = index
	fill()


## Updates tab button selected textures.
func settings_sync_tabs() -> void:
	for i in settings_tabs.size():
		var tab: TextureButton = settings_tabs[i]
		var path := "res://resources/ui/settings/tab_selected.png" if i == settings_tab else "res://resources/ui/settings/tab_unselected.png"
		tab.texture_normal = ui_assets.tex_rgba(path)


## Display version from git tag or project setting.
func game_version() -> String:
	var git_v := git_tag_version()
	if git_v != "":
		return git_v
	var v := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	return v if v != "" else "0.0.0"


## Latest git describe tag sans v prefix.
func git_tag_version() -> String:
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "describe", "--tags", "--abbrev=0"]), out, true, false)
	if code != 0 or out.is_empty():
		return ""
	var v := str(out[0]).strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	return v


## Support and FAQ tab content.
func fill_mail() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var support := SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 10), settings_support, ui_assets, media, 240)
	support.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(support)
	var faq := SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 11), settings_faq, ui_assets, media, 240)
	faq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(faq)
	settings_body.add_child(stack)


## Achievements, credits, reset, dev, and quit rows.
func fill_cog() -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 8), settings_achievements, ui_assets, media, 160))
	grid.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 12), settings_credits, ui_assets, media, 120))
	settings_body.add_child(grid)
	settings_body.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 4), settings_ask_reset, ui_assets, media, 160))
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(SettingsWidgets.settings_blue_button("DEV", on_enter_dev, ui_assets, media, 70))
	extras.add_child(SettingsWidgets.settings_blue_button("SALIR", on_quit_game, ui_assets, media, 80))
	settings_body.add_child(extras)


## SFX and music volume sliders.
func fill_sound() -> void:
	var refresh := Callable(self, "fill")
	settings_body.add_child(SettingsWidgets.settings_slider_row(
		LineBook.row("SYS.SETTINGS", 2), media.sfx_vol, on_set_sfx_vol, ui_assets, media, refresh))
	settings_body.add_child(SettingsWidgets.settings_slider_row(
		LineBook.row("SYS.SETTINGS", 1), media.music_vol, on_set_music_vol, ui_assets, media, refresh))


## Captions, CRT, FPS, hitboxes, and language row.
func fill_edit() -> void:
	settings_body.add_child(SettingsWidgets.settings_check_row(
		LineBook.row("SYS.SETTINGS", 13), media.captions_on, on_toggle_captions, ui_assets, media))
	settings_body.add_child(SettingsWidgets.settings_check_row(
		LineBook.row("SYS.SETTINGS", 14), prefs.crt_on, on_toggle_crt, ui_assets, media))
	settings_body.add_child(SettingsWidgets.settings_check_row("FPS", prefs.show_fps, on_toggle_show_fps, ui_assets, media))
	settings_body.add_child(SettingsWidgets.settings_check_row(
		"Hitboxes", prefs.show_hitboxes, on_toggle_show_hitboxes, ui_assets, media))
	var lang := HBoxContainer.new()
	lang.add_theme_constant_override("separation", 12)
	lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := SettingsWidgets.settings_label(LineBook.row("SYS.SETTINGS", 0), ui_assets)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang.add_child(label)
	lang.add_child(SettingsWidgets.settings_blue_button(prefs.settings_lang, settings_languages, ui_assets, media, 120))
	settings_body.add_child(lang)


## Language picker list with checkmarks.
func settings_languages() -> void:
	clear_body(settings_body)
	settings_body.add_child(SettingsWidgets.settings_label(LineBook.row("SYS.SETTINGS", 0), ui_assets))
	for name in PrefsController.SETTINGS_LANGS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(SettingsWidgets.settings_blue_button(name, settings_pick_lang.bind(name), ui_assets, media, 160))
		if name == prefs.settings_lang:
			var mark := TextureRect.new()
			mark.texture = ui_assets.tex_rgba("res://resources/ui/settings/checkbox_on.png")
			mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.custom_minimum_size = Vector2(24, 24)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(mark)
		settings_body.add_child(row)
	settings_body.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 3), fill, ui_assets, media, 160))


## Applies language and saves prefs.
func settings_pick_lang(name: String) -> void:
	if name in PrefsController.SETTINGS_LANGS:
		prefs.settings_lang = name
		if on_save_prefs.is_valid():
			on_save_prefs.call()
	fill()


## Opens Night School support URL.
func settings_support() -> void:
	OS.shell_open("https://support.nightschoolstudio.com/")


## Opens Thronglets FAQ URL.
func settings_faq() -> void:
	OS.shell_open("https://www.nightschoolstudio.com/thronglets")


## Placeholder achievements page.
func settings_achievements() -> void:
	clear_body(settings_body)
	settings_body.add_child(SettingsWidgets.settings_label("LOGROS", ui_assets))
	settings_body.add_child(SettingsWidgets.settings_label("—", ui_assets))
	settings_body.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 3), fill, ui_assets, media, 160))


## Credits text page.
func settings_credits() -> void:
	clear_body(settings_body)
	settings_body.add_child(SettingsWidgets.settings_label("CREDITOS", ui_assets))
	settings_body.add_child(SettingsWidgets.settings_label("Night School Studio", ui_assets))
	settings_body.add_child(SettingsWidgets.settings_label("Thronglets: Infinite", ui_assets))
	settings_body.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 3), fill, ui_assets, media, 160))


## Confirm save wipe dialog body.
func settings_ask_reset() -> void:
	clear_body(settings_body)
	settings_body.add_child(SettingsWidgets.settings_label(LineBook.row("SYS.SETTINGS", 5), ui_assets))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 6), settings_reset, ui_assets, media, 80))
	row.add_child(SettingsWidgets.settings_blue_button(LineBook.row("SYS.SETTINGS", 7), fill, ui_assets, media, 80))
	settings_body.add_child(row)


## Clears saves and returns to title.
func settings_reset() -> void:
	ThrongletSimServer.save_system.clear_all_progress()
	if on_show_title.is_valid():
		on_show_title.call()


## Frees all children of the settings body list.
func clear_body(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

