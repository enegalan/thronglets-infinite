extends RefCounted
class_name PrefsController
## Persists and applies user preferences.

## Allowed language labels written to opening.cfg.
const SETTINGS_LANGS := ["Español"]

## Whether the CRT post-effect overlay stays visible after load.
var crt_on := true
## Whether the FPS counter is shown during gameplay (hidden on title).
var show_fps := false
## Whether placement and collision debug overlays stay enabled.
var show_hitboxes := false
## Language name persisted in opening.cfg for the settings screen.
var settings_lang := SETTINGS_LANGS[0]

## Media layer that owns captions and volume sliders tied to prefs.
var _media
## Resolves the fullscreen CRT ColorRect from the host UI tree.
var _get_crt_overlay: Callable
## Resolves the FPS Label node toggled by show_fps.
var _get_fps_label: Callable
## Reports whether the title screen is active (suppresses FPS display).
var _get_in_title: Callable
## Clears hitbox overlays immediately when the pref is turned off.
var _on_hide_hitboxes: Callable
## Notifies the host to refresh settings-dependent UI after a toggle.
var _on_settings_changed: Callable


## Stores media and UI node accessors plus change callbacks.
func setup(
		media,
		get_crt_overlay: Callable,
		get_fps_label: Callable,
		get_in_title: Callable,
		on_hide_hitboxes: Callable,
		on_settings_changed: Callable,
) -> void:
	_media = media
	_get_crt_overlay = get_crt_overlay
	_get_fps_label = get_fps_label
	_get_in_title = get_in_title
	_on_hide_hitboxes = on_hide_hitboxes
	_on_settings_changed = on_settings_changed


## Reads opening.cfg into runtime preference fields.
func load_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://opening.cfg")
	_media.captions_on = bool(cfg.get_value("opening", "captions", true))
	crt_on = bool(cfg.get_value("opening", "crt", true))
	show_fps = bool(cfg.get_value("opening", "show_fps", false))
	show_hitboxes = bool(cfg.get_value("opening", "show_hitboxes", false))
	_media.sfx_vol = clampf(float(cfg.get_value("opening", "sfx", 1.0)), 0.0, 1.0)
	_media.music_vol = clampf(float(cfg.get_value("opening", "music", 1.0)), 0.0, 1.0)
	var lang := str(cfg.get_value("opening", "lang", settings_lang))
	if lang in SETTINGS_LANGS:
		settings_lang = lang


## Writes current preferences to opening.cfg.
func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opening", "captions", _media.captions_on)
	cfg.set_value("opening", "crt", crt_on)
	cfg.set_value("opening", "show_fps", show_fps)
	cfg.set_value("opening", "show_hitboxes", show_hitboxes)
	cfg.set_value("opening", "sfx", _media.sfx_vol)
	cfg.set_value("opening", "music", _media.music_vol)
	cfg.set_value("opening", "lang", settings_lang)
	cfg.save("user://opening.cfg")


## Shows or hides the CRT overlay from [member crt_on].
func apply_crt() -> void:
	var overlay: ColorRect = _get_crt_overlay.call() as ColorRect
	if overlay != null:
		overlay.visible = crt_on


## Pushes SFX and music volumes to the media layer.
func apply_volumes() -> void:
	if _media != null:
		_media.apply_volumes()


## Toggles FPS label visibility from prefs and title state.
func apply_show_fps() -> void:
	var fps_label: Label = _get_fps_label.call() as Label
	var in_title: bool = bool(_get_in_title.call())
	if fps_label != null:
		fps_label.visible = show_fps and not in_title


## Applies CRT, volumes, and FPS display.
func apply_all() -> void:
	apply_crt()
	apply_volumes()
	apply_show_fps()


## Sets SFX volume, applies audio, and saves.
func set_sfx_vol(value: float) -> void:
	_media.sfx_vol = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_prefs()


## Sets music volume, applies audio, and saves.
func set_music_vol(value: float) -> void:
	_media.music_vol = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_prefs()


## Toggles captions and persists.
func toggle_captions() -> void:
	_media.captions_on = not _media.captions_on
	save_prefs()
	_notify_settings()


## Toggles CRT filter and persists.
func toggle_crt() -> void:
	crt_on = not crt_on
	apply_crt()
	save_prefs()
	_notify_settings()


## Toggles FPS counter and persists.
func toggle_show_fps() -> void:
	show_fps = not show_fps
	apply_show_fps()
	save_prefs()
	_notify_settings()


## Toggles hitbox debug overlay and persists.
func toggle_show_hitboxes() -> void:
	show_hitboxes = not show_hitboxes
	if not show_hitboxes:
		if _on_hide_hitboxes.is_valid():
			_on_hide_hitboxes.call()
	save_prefs()
	_notify_settings()


## Notifies listeners that settings changed.
func _notify_settings() -> void:
	if _on_settings_changed.is_valid():
		_on_settings_changed.call()