extends RefCounted
class_name GameFlowUI

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")

## Main scene node whose market, kit, and gaze panels are coordinated with pause UI.
var host: Node2D
## Plays menu UI sounds and the game-over sting when panels open.
var media
## Menu ink color and slot button chrome for pause and game-over lists.
var ui_assets

## Top-right bars control that toggles the in-game pause sheet.
var menu_button: Button
## Centered panel hosting continue, sandbox island, and quit rows while paused.
var slots_panel: PanelContainer
## Centered panel shown after the last thronglet dies with restart and load options.
var over_panel: PanelContainer
## Vertical list rebuilt when game over triggers with checkpoint buttons.
var over_list: VBoxContainer
## Vertical list cleared and refilled each time the pause menu opens.
var slots_list: VBoxContainer
## Semi-transparent click-catcher behind pause UI that dismisses the menu.
var menu_dim: ColorRect

## Host hook resizing sandbox island tier from the pause menu plus/minus rows.
var on_sandbox_resize: Callable
## Host hook transitioning from a loaded checkpoint back into active gameplay.
var on_enter_game: Callable
## Host hook starting a clean run from the game-over restart button.
var on_start_new_game: Callable
## Host hook saving if needed and returning to the title screen from pause.
var on_show_title: Callable
## Host hook exiting the application from the pause menu.
var on_quit_game: Callable
## Host hook aborting kit drag when opening pause so tools do not stay grabbed.
var on_cancel_kit_drag: Callable
## Host hook collapsing the build kit while pause or game-over UI is up.
var on_set_kit_shown: Callable
## Host hook releasing charged tool state when pause opens.
var on_clear_tool_charge: Callable
## Host hook reading the active tool id before pause forces the eye tool.
var on_get_tool: Callable
## Host hook selecting a tool after pause forces inspection mode.
var on_set_tool: Callable


## Wires host, media, and gameplay flow callbacks.
func setup(
		p_host: Node2D,
		p_media,
		p_ui_assets,
		p_on_sandbox_resize: Callable,
		p_on_enter_game: Callable,
		p_on_start_new_game: Callable,
		p_on_show_title: Callable,
		p_on_quit_game: Callable,
		p_on_cancel_kit_drag: Callable,
		p_on_set_kit_shown: Callable,
		p_on_clear_tool_charge: Callable,
		p_on_get_tool: Callable,
		p_on_set_tool: Callable,
) -> void:
	host = p_host
	media = p_media
	ui_assets = p_ui_assets
	on_sandbox_resize = p_on_sandbox_resize
	on_enter_game = p_on_enter_game
	on_start_new_game = p_on_start_new_game
	on_show_title = p_on_show_title
	on_quit_game = p_on_quit_game
	on_cancel_kit_drag = p_on_cancel_kit_drag
	on_set_kit_shown = p_on_set_kit_shown
	on_clear_tool_charge = p_on_clear_tool_charge
	on_get_tool = p_on_get_tool
	on_set_tool = p_on_set_tool


## Pause dim, menu button, slots and game-over panels.
func build_pause(root: Control) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	dim.z_index = 40
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close_slots()
	)
	root.add_child(dim)
	menu_dim = dim

	menu_button = Button.new()
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_button.offset_left = -30
	menu_button.offset_top = 4
	menu_button.offset_right = -4
	menu_button.offset_bottom = 28
	menu_button.z_index = 42
	menu_button.pressed.connect(toggle_slots)
	var empty := StyleBoxEmpty.new()
	menu_button.add_theme_stylebox_override("normal", empty)
	menu_button.add_theme_stylebox_override("hover", empty)
	menu_button.add_theme_stylebox_override("focus", empty)
	menu_button.add_theme_stylebox_override("pressed", empty)
	menu_button.add_theme_stylebox_override("hover_pressed", empty)
	var menu_icon := TextureRect.new()
	menu_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_icon.texture = ui_assets.tex("res://resources/ui/menu_bars.png")
	menu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(menu_icon)
	root.add_child(menu_button)

	var pause_center := CenterContainer.new()
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.z_index = 41
	slots_panel = PanelContainer.new()
	slots_panel.visible = false
	slots_list = VBoxContainer.new()
	slots_list.add_theme_constant_override("separation", 3)
	slots_panel.add_child(slots_list)
	pause_center.add_child(slots_panel)
	over_panel = PanelContainer.new()
	over_panel.visible = false
	over_list = VBoxContainer.new()
	over_list.add_theme_constant_override("separation", 3)
	over_panel.add_child(over_list)
	pause_center.add_child(over_panel)
	root.add_child(pause_center)


## Opens or closes the pause slots menu.
func toggle_slots() -> void:
	if ThrongletSimServer.game_over:
		return
	media.play("ui")
	if slots_panel.visible:
		close_slots()
	else:
		open_menu()


## Pauses sim and populates pause menu.
func open_menu() -> void:
	slots_panel.visible = true
	menu_dim.visible = true
	ThrongletSimServer.paused = true
	host.market_open = false
	if on_clear_tool_charge.is_valid():
		on_clear_tool_charge.call()
	if on_set_tool.is_valid():
		on_set_tool.call(Catalog.TOOL_EYE)
	if on_cancel_kit_drag.is_valid():
		on_cancel_kit_drag.call()
	host.kit_open = false
	if on_set_kit_shown.is_valid():
		on_set_kit_shown.call(false)
	show_menu()


## Hides pause menu and unpauses sim.
func close_slots() -> void:
	slots_panel.visible = false
	menu_dim.visible = false
	ThrongletSimServer.paused = false


## Fills pause menu rows for current mode.
func show_menu() -> void:
	clear_menu(slots_list)
	menu_label(slots_list, "PAUSA")
	menu_button_row(slots_list, "CONTINUAR", close_slots)
	if ThrongletSimServer.sandbox_mode:
		menu_label(slots_list, "ISLA %d" % ThrongletSimServer.land_tier)
		menu_button_row(slots_list, "ISLA +", on_sandbox_resize.bind(1))
		menu_button_row(slots_list, "ISLA -", on_sandbox_resize.bind(-1))
	menu_button_row(slots_list, "SALIR DE LA PARTIDA", leave_to_title)
	menu_button_row(slots_list, "SALIR DEL JUEGO", on_quit_game)


## Removes all children from a menu list.
func clear_menu(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


## Centered heading label in a menu list.
func menu_label(list: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", ui_assets.menu_ink())
	list.add_child(title)


## Styled menu button wired to a callback.
func menu_button_row(list: VBoxContainer, text: String, call: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(180, 0)
	button.disabled = disabled
	var hover: StyleBox = ui_assets.slot_style()
	hover.modulate_color = Color(1.0, 0.82, 0.45)
	var pressed: StyleBox = ui_assets.slot_style()
	pressed.modulate_color = Color(0.55, 0.34, 0.18)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var ink: Color = ui_assets.menu_ink()
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.32, 0.22))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.82))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.94, 0.82))
	button.pressed.connect(func() -> void:
		media.play("ui")
		call.call()
	)
	list.add_child(button)


## Toggles game-over panel and side effects.
func sync_game_over() -> void:
	if over_panel == null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	var show: bool = sim.game_over and not host.in_title
	if over_panel.visible == show:
		return
	over_panel.visible = show
	if not show:
		return
	media.play("gameover")
	if host.gaze_panel != null:
		host.gaze_panel.visible = false
	host.kit_open = false
	if on_set_kit_shown.is_valid():
		on_set_kit_shown.call(false)
	host.market_open = false
	if host.market_panel != null:
		host.market_panel.visible = false
	slots_panel.visible = false
	if menu_dim != null:
		menu_dim.visible = false
	fill_game_over()


## Restart and checkpoint rows on game over.
func fill_game_over() -> void:
	clear_menu(over_list)
	menu_label(over_list, "GAME OVER")
	menu_label(over_list, "EL ULTIMO MULTI HA MUERTO")
	menu_button_row(over_list, "EMPEZAR DE NUEVO", game_over_restart)
	var rows: Array = ThrongletSimServer.save_system.list_checkpoints()
	if rows.is_empty():
		menu_label(over_list, "NO HAY GUARDADOS")
		return
	menu_label(over_list, "ULTIMOS GUARDADOS")
	for i in rows.size():
		var row: Dictionary = rows[i]
		menu_button_row(over_list, checkpoint_text(i, row), game_over_load_slot.bind(int(row.i)))


## Short label for a save slot row.
func checkpoint_text(order: int, row: Dictionary) -> String:
	var living := int(row.get("living", 0))
	if order == 0:
		return "ULTIMO  POB %d" % living
	return "ANTERIOR %d  POB %d" % [order, living]


## Starts a new game from game over.
func game_over_restart() -> void:
	over_panel.visible = false
	if on_start_new_game.is_valid():
		on_start_new_game.call()


## Loads checkpoint index and enters game.
func game_over_load_slot(index: int) -> void:
	if not ThrongletSimServer.save_system.load_slot(index):
		return
	over_panel.visible = false
	if on_enter_game.is_valid():
		on_enter_game.call()


## Saves progress if needed and opens title.
func leave_to_title() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		sim.save_system.save_progress()
	if on_show_title.is_valid():
		on_show_title.call()