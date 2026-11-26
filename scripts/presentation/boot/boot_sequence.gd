extends RefCounted
class_name BootSequence
## Logo video, DOS intro typing, and transition into the title flow.

## Main presentation host (media, title, pause flags).
var host: Node2D
## Media controller used for the logo/SEQ videos and SFX.
var media
## Shared UI fonts/textures for the DOS screen and tutorial sign.
var ui_assets

## Current boot phase: "" | "logo" | "dos".
var boot := ""
## True once the logo VideoStreamPlayer has actually started playing.
var logo_started := false
## Seconds spent in the logo phase (retry/fallback timing).
var logo_wait := 0.0

## Full-screen black DOS intro layer (hidden after finish_dos).
var dos_root: Control
## Typewriter label that reveals [member dos_full].
var dos_label: Label
## Complete intro text loaded from LineBook (SYS.GAME_INTRO).
var dos_full := ""
## How many characters of [member dos_full] are already shown.
var dos_shown := 0
## Seconds held after the typewriter finishes before auto-advancing.
var dos_hold := 0.0
## Full-screen CRT shader overlay (toggled from prefs, not boot flow).
var crt_overlay: ColorRect
## Wooden tutorial sign button shown during early gameplay tips.
var sign_button: Button

## Host callback when the tutorial sign is pressed.
var on_advance_sign: Callable
## Host callback to open the title screen after DOS/video.
var on_show_title: Callable


## Binds the game host, media, and UI asset helpers.
func setup(p_host: Node2D, p_media, p_ui_assets) -> void:
	host = p_host
	media = p_media
	ui_assets = p_ui_assets


## Creates CRT, DOS intro, and sign UI under [param root].
func build_opening(root: Control) -> void:
	# CRT overlay layer.
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 128
	host.add_child(crt_layer)
	crt_overlay = ColorRect.new()
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.visible = false
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = load("res://resources/ui/crt_overlay.gdshader")
	crt_overlay.material = crt_mat
	crt_layer.add_child(crt_overlay)

	# DOS intro layer.
	dos_root = Control.new()
	dos_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_root.mouse_filter = Control.MOUSE_FILTER_STOP
	dos_root.visible = false
	dos_root.z_index = 72
	var dos_bg := ColorRect.new()
	dos_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_bg.color = Color(0, 0, 0, 1)
	dos_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dos_root.add_child(dos_bg)
	dos_label = Label.new()
	dos_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_label.offset_left = 16
	dos_label.offset_top = 12
	dos_label.offset_right = -72
	dos_label.offset_bottom = -28
	dos_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dos_label.add_theme_font_override("font", ui_assets.dos_font())
	dos_label.add_theme_font_size_override("font_size", 16)
	dos_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.4))
	dos_root.add_child(dos_label)
	# TODO: Remove this
	var dos_face := TextureRect.new()
	dos_face.texture = ui_assets.tex("res://resources/ui/face_base.png")
	dos_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dos_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dos_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dos_face.self_modulate = Color(0.35, 1.0, 0.4)
	dos_face.anchor_left = 1.0
	dos_face.anchor_right = 1.0
	dos_face.offset_left = -56
	dos_face.offset_top = 8
	dos_face.offset_right = -8
	dos_face.offset_bottom = 48
	dos_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dos_root.add_child(dos_face)
	root.add_child(dos_root)

	# Tutorial sign button.
	sign_button = Button.new()
	sign_button.visible = false
	sign_button.z_index = 34
	sign_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_button.add_theme_font_override("font", ui_assets.ui_font())
	sign_button.add_theme_font_size_override("font_size", 14)
	var ink := Color(0.1, 0.07, 0.04)
	sign_button.add_theme_color_override("font_color", ink)
	sign_button.add_theme_color_override("font_hover_color", ink)
	sign_button.add_theme_color_override("font_pressed_color", ink)
	sign_button.add_theme_color_override("font_focus_color", ink)
	var wood: StyleBox = ui_assets.box_style("res://resources/ui/sign_plank.png", 8, 6)
	sign_button.add_theme_stylebox_override("normal", wood)
	sign_button.add_theme_stylebox_override("hover", wood)
	sign_button.add_theme_stylebox_override("pressed", wood)
	sign_button.add_theme_stylebox_override("focus", wood)
	var arrow := TextureRect.new()
	arrow.texture = ui_assets.tex("res://resources/ui/sign_arrow.png")
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_SCALE
	arrow.anchor_left = 1.0
	arrow.anchor_top = 1.0
	arrow.anchor_right = 1.0
	arrow.anchor_bottom = 1.0
	arrow.offset_left = -16.0
	arrow.offset_top = -12.0
	arrow.offset_right = -11.0
	arrow.offset_bottom = -9.0
	sign_button.add_child(arrow)
	if on_advance_sign.is_valid():
		sign_button.pressed.connect(on_advance_sign)
	root.add_child(sign_button)


## Starts the TuckerSoft logo video and pauses gameplay.
func begin_logo() -> void:
	boot = "logo"
	logo_started = false
	logo_wait = 0.0
	media.logo_video_playing = true
	host.in_title = true
	ThrongletSimServer.paused = true
	var title_root: Control = host.title.title_root
	if title_root != null:
		title_root.visible = false
	if dos_root != null:
		dos_root.visible = false
	if not media.play_video("tuckersoft_logo_30fps_1MB", true):
		begin_dos()
	else:
		media.video_player.volume_db = 6.0


## Advances logo playback or falls through to DOS on [param delta].
func tick_logo(delta: float) -> void:
	if boot != "logo" or media.video_player == null:
		return
	logo_wait += delta
	if media.video_player.is_playing():
		logo_started = true
		return
	if logo_started:
		begin_dos()
		return
	if logo_wait > 1.0 and media.video_player.stream != null:
		media.video_player.play()
	if logo_wait > 2.0:
		begin_dos()


## Ends logo phase and prepares the DOS text intro.
func begin_dos() -> void:
	if boot != "logo":
		return
	boot = "dos"
	if media != null:
		media.video_from_title = false
	if media != null and media.video_player != null:
		media.video_player.stop()
		media.video_player.visible = false
		var plate: ColorRect = media.video_player.get_meta("plate") as ColorRect
		if plate != null:
			plate.visible = false
	show_dos()


## Pauses sim and opens the DOS screen.
func show_dos() -> void:
	host.in_title = true
	ThrongletSimServer.paused = true
	open_dos()


## Resets DOS typewriter text from line book content.
func open_dos() -> void:
	dos_full = LineBook.row("SYS.GAME_INTRO", 3).replace("\\n", "\n")
	dos_full = dos_full.replace("\\\\", "\\").replace("\\\\", "\\")
	dos_shown = 0
	dos_hold = 0.0
	dos_label.text = ""
	dos_root.visible = true


## Types DOS text and auto-advances when complete.
func tick_dos(delta: float) -> void:
	if dos_root == null or not dos_root.visible:
		return
	if dos_shown < dos_full.length():
		dos_shown = mini(dos_full.length(), dos_shown + 3)
		dos_label.text = dos_full.substr(0, dos_shown)
		return
	if ThrongletSimServer.testing:
		return
	dos_hold += delta
	if dos_hold > 1.2:
		finish_dos()


## Closes DOS and plays next video or shows title.
func finish_dos() -> void:
	if dos_root == null or not dos_root.visible:
		return
	dos_root.visible = false
	boot = ""
	if ThrongletSimServer.testing:
		return
	if media.play_video("SEQ_1.5", true):
		return
	if on_show_title.is_valid():
		on_show_title.call()