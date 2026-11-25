extends RefCounted
class_name TitleScreen

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")

## Main scene node whose flags and child panels are reset when entering title.
var host: Node2D
## Fades title music and plays menu SFX for start, settings, and video actions.
var media
## Loads menu sprites, wood buttons, and icon textures for the backdrop and HUD.
var ui_assets

## Full-screen title layer toggled when leaving gameplay or closing overlays.
var title_root: Control
## Interactive menu buttons laid over the parallax backdrop.
var title_hud: Control
## Hamburger control that opens the TuckerSoft settings overlay.
var title_bars: Button
## Primary action that continues a save or starts a new run.
var title_start: Button
## Secondary wood button that launches sandbox mode without a campaign save.
var title_sandbox: Button
## Retro shell icon that opens the faux video file browser.
var title_video: Button
## Orbital cloud sprites with per-layer phase, speed, and ellipse parameters.
var title_clouds: Array = []
## Accumulated delta used to advance cloud motion along their tracks.
var title_time := 0.0
## Sun flare sprite positioned above the cast during layout sync.
var title_flare: TextureRect
## Ground strip anchored to the bottom edge of the title viewport.
var title_grass: TextureRect
## Game logo centered in the upper third of the title screen.
var title_logo: TextureRect
## Front-facing thronglet in the title cast lineup.
var title_front: TextureRect
## Side-facing thronglet beside the front character at the grass line.
var title_side: TextureRect
## Egg prop completing the promotional cast on the title hill.
var title_egg: TextureRect
## Last viewport size applied to backdrop and HUD to avoid redundant layout.
var title_layout_size := Vector2.ZERO

## Host hook that rebuilds and shows the settings menu from the bars button.
var on_fill_settings: Callable
## Host hook that tears down title UI and enters sandbox play.
var on_start_sandbox: Callable
## Host hook that hides the HUD and opens the video library overlay.
var on_open_video_library: Callable
## Host hook that resumes the live session or latest checkpoint; returns whether it did.
var on_continue_game: Callable
## Host hook that begins a fresh campaign when no continue path is available.
var on_start_new_game: Callable
## Host hook clearing an in-progress kit drag when returning to title.
var on_cancel_kit_drag: Callable
## Host hook showing or hiding the build kit panel while on title.
var on_set_kit_shown: Callable


## Wires host, media, assets, and title callbacks.
func setup(
		p_host: Node2D,
		p_media,
		p_ui_assets,
		p_on_fill_settings: Callable,
		p_on_start_sandbox: Callable,
		p_on_open_video_library: Callable,
		p_on_continue_game: Callable,
		p_on_start_new_game: Callable,
		p_on_cancel_kit_drag: Callable,
		p_on_set_kit_shown: Callable,
) -> void:
	host = p_host
	media = p_media
	ui_assets = p_ui_assets
	on_fill_settings = p_on_fill_settings
	on_start_sandbox = p_on_start_sandbox
	on_open_video_library = p_on_open_video_library
	on_continue_game = p_on_continue_game
	on_start_new_game = p_on_start_new_game
	on_cancel_kit_drag = p_on_cancel_kit_drag
	on_set_kit_shown = p_on_set_kit_shown


## Pauses sim and reveals title HUD.
func show_title() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	sim.player_tools.cancel_hold()
	host.in_title = true
	sim.paused = true
	host.market_open = false
	if on_cancel_kit_drag.is_valid():
		on_cancel_kit_drag.call()
	host.kit_open = false
	if host.kit_panel:
		if on_set_kit_shown.is_valid():
			on_set_kit_shown.call(false)
	if host.game_flow != null:
		if host.game_flow.slots_panel:
			host.game_flow.slots_panel.visible = false
		if host.game_flow.menu_dim:
			host.game_flow.menu_dim.visible = false
	title_root.visible = true
	title_layout_size = Vector2.ZERO
	media.logo_video_playing = false
	fill_title()
	if media != null and media.music != null:
		var tween: Tween = host.create_tween()
		tween.tween_property(media.music, "volume_db", -6.0, 1.0)


## Sky, clouds, grass, cast, and logo layers.
func build_backdrop(root: Control) -> void:
	title_clouds.clear()
	title_time = 0.0
	title_layout_size = Vector2.ZERO
	var stage := Control.new()
	stage.name = "TitleBackdrop"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)

	var sky := _title_sprite("res://resources/ui/menu/sky_gradient.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(sky)

	title_flare = _title_sprite("res://resources/ui/menu/sun_flare.png", true)
	title_flare.stretch_mode = TextureRect.STRETCH_SCALE
	title_flare.modulate = Color(1, 1, 1, 1)
	stage.add_child(title_flare)

	var cloud_layer := Control.new()
	cloud_layer.name = "TitleClouds"
	cloud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_layer.clip_contents = false
	stage.add_child(cloud_layer)
	var cloud_tracks := [
		{"path": "res://resources/ui/menu/cloud_3.png", "width": 0.20, "cy": 0.13, "rx": 0.50, "ry": 0.045, "speed": 0.045, "phase": 0.10},
		{"path": "res://resources/ui/menu/cloud_2.png", "width": 0.28, "cy": 0.25, "rx": 0.56, "ry": 0.065, "speed": 0.038, "phase": 0.25},
		{"path": "res://resources/ui/menu/cloud_1.png", "width": 0.34, "cy": 0.37, "rx": 0.62, "ry": 0.080, "speed": 0.030, "phase": 0.40},
	]
	for track in cloud_tracks:
		for twin in [0.0, 0.5]:
			var cloud := _title_sprite(str(track.path), true)
			cloud.stretch_mode = TextureRect.STRETCH_SCALE
			cloud_layer.add_child(cloud)
			title_clouds.append({
				"node": cloud,
				"phase": float(track.phase) + twin,
				"speed": float(track.speed),
				"width": float(track.width),
				"cy": float(track.cy),
				"rx": float(track.rx),
				"ry": float(track.ry),
			})

	title_grass = _title_sprite("res://resources/ui/menu/grass.png", true)
	title_grass.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(title_grass)

	var cast := Control.new()
	cast.name = "TitleCast"
	cast.set_anchors_preset(Control.PRESET_FULL_RECT)
	cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(cast)

	title_front = _title_sprite("res://resources/ui/menu/thronglet_front.png", true)
	title_front.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_front)

	title_side = _title_sprite("res://resources/ui/menu/thronglet_side.png", true)
	title_side.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_side)

	title_egg = _title_sprite("res://resources/ui/menu/egg.png", true)
	title_egg.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_egg)

	title_logo = _title_sprite("res://resources/ui/menu/logo.png", true)
	title_logo.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(title_logo)


## Menu buttons on the title overlay.
func build_hud(root: Control) -> void:
	title_hud = Control.new()
	title_hud.name = "TitleHud"
	title_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_hud)
	title_bars = _title_icon_button("res://resources/ui/menu_bars.png", on_fill_settings)
	title_bars.modulate = Color(1.25, 1.05, 0.85)
	title_hud.add_child(title_bars)
	title_start = _title_wood_button(Callable(self, "_title_press_start"))
	title_hud.add_child(title_start)
	title_sandbox = _title_wood_button(on_start_sandbox)
	title_sandbox.text = "Sandbox"
	title_sandbox.add_theme_font_size_override("font_size", 16)
	title_hud.add_child(title_sandbox)
	title_video = _title_icon_button("res://resources/ui/menu/video.png", on_open_video_library, false)
	title_video.flat = false
	var video_plate: StyleBox = ui_assets.oldos_plate_style(4)
	title_video.add_theme_stylebox_override("normal", video_plate)
	title_video.add_theme_stylebox_override("hover", video_plate)
	title_video.add_theme_stylebox_override("pressed", video_plate)
	title_video.add_theme_stylebox_override("focus", video_plate)
	title_video.add_theme_stylebox_override("hover_pressed", video_plate)
	title_hud.add_child(title_video)


## Wood-plate text button with continue SFX.
func _title_wood_button(call: Callable) -> Button:
	var button := Button.new()
	button.flat = false
	button.text = "Comenzar"
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", ui_assets.ui_font())
	button.add_theme_font_size_override("font_size", 22)
	var ink := Color(1.0, 1.0, 0.96)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.78))
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04))
	var wood: StyleBox = ui_assets.box_style("res://resources/ui/menu/start.png", 8, 0)
	button.add_theme_stylebox_override("normal", wood)
	button.add_theme_stylebox_override("hover", wood)
	button.add_theme_stylebox_override("pressed", wood)
	button.add_theme_stylebox_override("focus", wood)
	button.add_theme_stylebox_override("hover_pressed", wood)
	if call.is_valid():
		button.pressed.connect(func() -> void:
			media.play_sfx_then("ui_game_continue", call)
		)
	return button


## Icon-only texture button.
func _title_icon_button(path: String, call: Callable, fill: bool = false) -> Button:
	var button := Button.new()
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("hover_pressed", empty)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.texture = ui_assets.tex_rgba(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE if fill else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.set_meta("icon", icon)
	if call.is_valid():
		button.pressed.connect(func() -> void:
			media.play("ui")
			call.call()
		)
	return button


## Continue save or start new game.
func _title_press_start() -> void:
	if on_continue_game.is_valid() and on_continue_game.call():
		return
	if on_start_new_game.is_valid():
		on_start_new_game.call()


## Builds a non-interactive menu sprite, using RGBA loading when the art needs transparency.
func _title_sprite(path: String, keep_alpha: bool = false) -> TextureRect:
	var node := TextureRect.new()
	node.texture = ui_assets.tex_rgba(path) if keep_alpha else ui_assets.tex(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Size preserving aspect for a target height.
func _title_fit(node: TextureRect, height: float) -> Vector2:
	var tex: Texture2D = node.texture
	if tex == null or tex.get_height() < 1:
		return Vector2(height, height)
	var aspect := float(tex.get_width()) / float(tex.get_height())
	return Vector2(height * aspect, height)


## Positions sprite with feet at center.y.
func _title_place(node: TextureRect, center: Vector2, size: Vector2) -> void:
	node.size = size
	node.position = Vector2(center.x - size.x * 0.5, center.y - size.y)


## Layouts backdrop and HUD for viewport size.
func sync_title_layout(area: Vector2) -> void:
	if title_flare == null:
		return
	var flare_size := Vector2(area.x * 0.78, area.y * 0.58)
	title_flare.size = flare_size
	title_flare.position = Vector2((area.x - flare_size.x) * 0.5, area.y * 0.22)

	var grass_tex: Texture2D = title_grass.texture
	var grass_aspect := 2.285
	if grass_tex != null and grass_tex.get_height() > 0:
		grass_aspect = float(grass_tex.get_width()) / float(grass_tex.get_height())
	var grass_h := area.x / grass_aspect
	title_grass.size = Vector2(area.x, grass_h)
	title_grass.position = Vector2(0.0, area.y - grass_h)

	var feet := area.y * 0.60
	var front_size := _title_fit(title_front, area.y * 0.355)
	var side_size := _title_fit(title_side, area.y * 0.285)
	var egg_size := _title_fit(title_egg, area.y * 0.180)
	_title_place(title_front, Vector2(area.x * 0.515, feet), front_size)
	_title_place(title_side, Vector2(area.x * 0.665, feet), side_size)
	_title_place(title_egg, Vector2(area.x * 0.365, feet), egg_size)

	var logo_size := _title_fit(title_logo, area.y * 0.21)
	if logo_size.x > area.x * 0.58 and title_logo.texture != null:
		logo_size.x = area.x * 0.58
		logo_size.y = logo_size.x * float(title_logo.texture.get_height()) / float(title_logo.texture.get_width())
	title_logo.size = logo_size
	title_logo.position = Vector2((area.x - logo_size.x) * 0.5, area.y * 0.035)

	sync_title_hud(area)


## Animates clouds along elliptical tracks.
func tick(delta: float) -> void:
	if title_root == null or not title_root.visible:
		return
	title_time += delta
	var area := title_root.size
	if area.x < 8.0 or area.y < 8.0:
		return
	if area != title_layout_size:
		title_layout_size = area
		sync_title_layout(area)
	var cx := area.x * 0.5
	for cloud in title_clouds:
		var node: TextureRect = cloud.node
		var tex: Texture2D = node.texture
		if tex == null:
			continue
		var tw := area.x * float(cloud.width)
		var th := tw * float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
		var t: float = fposmod(float(cloud.phase) + title_time * float(cloud.speed), 1.0)
		var x := lerpf(area.x, -tw, t)
		var cloud_cx := x + tw * 0.5
		var rx_px := area.x * float(cloud.rx)
		var nx := clampf((cloud_cx - cx) / maxf(rx_px, 1.0), -1.0, 1.0)
		var y := area.y * float(cloud.cy) - area.y * float(cloud.ry) * sqrt(1.0 - nx * nx) - th * 0.5
		node.position = Vector2(x, y)
		node.size = Vector2(tw, th)


## Positions title menu buttons proportionally.
func sync_title_hud(area: Vector2) -> void:
	if title_hud == null:
		return
	var bars_s := Vector2(area.x * 0.048, area.x * 0.040)
	title_bars.size = bars_s
	title_bars.position = Vector2(area.x * 0.022, area.y * 0.038)
	var start_s := Vector2(area.x * 0.265, area.y * 0.155)
	title_start.size = start_s
	title_start.position = Vector2(area.x * 0.383, area.y * 0.755)
	if title_sandbox != null:
		var sand_s := Vector2(area.x * 0.18, area.y * 0.08)
		title_sandbox.size = sand_s
		title_sandbox.position = Vector2(
			title_start.position.x + (start_s.x - sand_s.x) * 0.5,
			title_start.position.y + start_s.y + area.y * 0.012
		)
	var video_s := Vector2(area.x * 0.128, area.y * 0.150)
	title_video.size = video_s
	title_video.position = Vector2(area.x * 0.795, area.y * 0.725)
	var video_icon: TextureRect = title_video.get_meta("icon") as TextureRect
	if video_icon != null:
		var inset := video_s.y * 0.22
		video_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_icon.offset_left = inset
		video_icon.offset_top = inset
		video_icon.offset_right = -inset
		video_icon.offset_bottom = -inset


## Hides settings and sets continue vs start label.
func fill_title() -> void:
	if host.settings_menu != null:
		if host.settings_menu.title_menu != null:
			host.settings_menu.title_menu.visible = false
		if host.settings_menu.settings_shell != null:
			host.settings_menu.settings_shell.visible = false
	if title_hud != null:
		title_hud.visible = true
	title_layout_size = Vector2.ZERO
	if title_start != null:
		title_start.text = "Continuar" if has_continue() else "Comenzar"


## Whether a live session or checkpoint exists.
func has_continue() -> bool:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		return true
	return ThrongletSimServer.save_system.has_checkpoint()

