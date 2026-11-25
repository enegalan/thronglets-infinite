extends RefCounted
class_name ToolController

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")

## Main scene node holding tool id, charge state, and selection.
var host: Node2D
## Hold duration before a press on a thronglet becomes a grab instead of select.
const HAND_HOLD := 0.22

## Attaches the presentation host that owns camera and input state.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host

## Eye tool click: select thronglet or use tool.
func world_click() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var aim = aim_thronglet(false)
	host.selected = sim.spatial.find_thronglet(aim.x, aim.y, 14.0, false)
	if host.selected >= 0:
		if sim.mito_t[host.selected] > 0.0 or sim.mito_charge[host.selected] > 0.0:
			host.selected = -1
	host.selected_bld = -1
	if host.selected >= 0 and host.selected < sim.slot_count and sim.state[host.selected] != Catalog.ST_VACANT:
		host.camera.position = host.cam_rig.to_iso(Vector2(sim.pos_x[host.selected], sim.pos_y[host.selected]))
	var used = host.tool
	if used == Catalog.TOOL_SPONGE:
		return
	if is_charge_tool(used):
		return
	# Placeables use the cursor cell, not a thronglet under the pointer.
	var at = host.cam_rig.pointer_world()
	if used == Catalog.TOOL_TNT:
		at = host.cam_rig.grid_pointer_world()
	elif used == Catalog.TOOL_EYE:
		at = aim
	sim.player_tools.use_tool(used, at.x, at.y)
	if used != Catalog.TOOL_EYE:
		host.tool = Catalog.TOOL_EYE


## Whether the tool uses hold-to-charge.
func is_charge_tool(tool_id: int) -> bool:
	return tool_id == Catalog.TOOL_AXE or tool_id == Catalog.TOOL_HAMMER or tool_id == Catalog.TOOL_PICK or tool_id == Catalog.TOOL_SAW or tool_id == Catalog.TOOL_GRAB


## Active charge tool while dragging or holding.
func charge_tool_id() -> int:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.player_tools.has_scoop():
		return -1
	if not host.kit_drag.is_empty() and str(host.kit_drag.get("type", "")) == "tool":
		var drag_id = int(host.kit_drag.get("id", -1))
		if is_charge_tool(drag_id):
			return drag_id
	if is_charge_tool(host.tool) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return host.tool
	return -1


## Resets charge state and target key.
func clear_tool_charge() -> void:
	host.tool_charge = 0.0
	host.tool_charge_key = ""
	host.tool_charge_n = 0


## Advances charge bar and fires charged use.
func tick_tool_charge(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var at = host.cam_rig.pointer_world()
	if sim.player_tools.has_scoop():
		clear_tool_charge()
		if (not host.kit_drag.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and drop_on_island():
			sim.player_tools.scoop_follow(at.x, at.y)
		return
	var used = charge_tool_id()
	if used < 0 or sim.frozen or sim.paused or not drop_on_island():
		clear_tool_charge()
		return
	var target: Dictionary = sim.player_tools.charge_tool_target(used, at.x, at.y)
	if target.is_empty():
		clear_tool_charge()
		return
	var key = str(target.get("key", ""))
	var n = int(target.get("n", 0))
	if used == Catalog.TOOL_GRAB and n <= 0:
		host.tool_charge_key = key
		host.tool_charge = 0.0
		host.tool_charge_n = 0
		return
	if key != host.tool_charge_key:
		host.tool_charge_key = key
		host.tool_charge = 0.0
		host.tool_charge_n = maxi(1, n)
	else:
		host.tool_charge_n = maxi(1, n)
	host.tool_charge = minf(1.0, host.tool_charge + delta / Catalog.TOOL_CHARGE)
	if host.tool_charge < 1.0:
		return
	if used == Catalog.TOOL_GRAB:
		sim.player_tools.scoop_gather(float(target.x), float(target.y))
		clear_tool_charge()
		return
	sim.player_tools.use_tool(used, float(target.x), float(target.y))
	clear_tool_charge()


## Cancels pending thronglet grab hold.
func clear_hand_pending() -> void:
	host.hand_pending = false
	host.hand_pending_id = -1
	host.hand_hold_t = 0.0


## Completes grab after hold threshold.
func tick_hand_hold(delta: float) -> void:
	if not host.hand_pending:
		return
	var sim: ThrongletSim = ThrongletSimServer
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or sim.frozen or sim.paused:
		clear_hand_pending()
		return
	host.hand_hold_t += delta
	if host.hand_hold_t < HAND_HOLD:
		return
	var id = host.hand_pending_id
	clear_hand_pending()
	if sim.player_tools.grab_thronglet(id):
		host.selected = -1
		host.selected_bld = -1


## Begins grab, scoop, or selection on press.
func hand_press() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	clear_hand_pending()
	var at = aim_thronglet(true)
	if throng_under_cursor(true) < 0:
		var egg = egg_under_cursor()
		if not egg.is_empty():
			at = Vector2(float(egg.x), float(egg.y))
	host.hand_from = host.get_viewport().get_mouse_position()
	var throng = throng_under_cursor(true)
	if throng >= 0:
		host.hand_pending = true
		host.hand_pending_id = throng
		host.hand_hold_t = 0.0
		return
	if sim.player_tools.grab_at(at.x, at.y):
		host.selected_bld = -1
		host.selected = -1
		return
	var hit: Dictionary = sim.player_tools.eye_use(at.x, at.y)
	var kind = str(hit.get("type", ""))
	if kind == "thronglet":
		var tid = int(hit.id)
		if tid >= 0 and tid < sim.slot_count and sim.state[tid] == Catalog.ST_LIVING and (sim.mito_t[tid] > 0.0 or sim.mito_charge[tid] > 0.0):
			host.selected = -1
			host.selected_bld = -1
		else:
			host.selected = tid
			host.selected_bld = -1
	elif kind == "market":
		host.market_open = true
		host.selected = -1
		host.selected_bld = int(hit.get("id", -1))
	elif kind == "building" or kind == "factory":
		host.selected = -1
		host.selected_bld = int(hit.id)
	else:
		host.selected = -1
		host.selected_bld = -1


## Drops held items or confirms short click select.
func hand_release() -> void:
	var pending_click_id = host.hand_pending_id if host.hand_pending else -1
	clear_hand_pending()
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.player_tools.is_holding():
		if pending_click_id >= 0:
			var short_click = host.get_viewport().get_mouse_position().distance_to(host.hand_from) < 12.0
			if short_click and pending_click_id < sim.slot_count and sim.state[pending_click_id] != Catalog.ST_VACANT:
				host.selected = pending_click_id
				host.selected_bld = -1
				host.camera.position = host.cam_rig.to_iso(Vector2(sim.pos_x[host.selected], sim.pos_y[host.selected]))
			else:
				host.selected = -1
				host.selected_bld = -1
		return
	var short_click = host.get_viewport().get_mouse_position().distance_to(host.hand_from) < 12.0
	if not drop_on_island():
		sim.player_tools.cancel_hold()
		return
	var at = host.cam_rig.pointer_world()
	if sim.held_kind == "building" or sim.held_kind == "rock":
		at = host.cam_rig.grid_pointer_world()
	elif sim.hand_id != -1:
		var held: Dictionary = sim.player_tools.hand_item()
		if not held.is_empty() and Catalog.item_snaps_grid(int(held.kind)):
			at = host.cam_rig.grid_pointer_world()
	var held_thronglet: bool = sim.held_kind == "thronglet"
	var throw_v = Vector2.ZERO if short_click else host.hand_vel
	var hit: Dictionary = sim.player_tools.release_at(at.x, at.y, short_click, true, throw_v.x, throw_v.y)
	var kind = str(hit.get("type", ""))
	if kind == "thronglet":
		host.selected = int(hit.id)
		host.selected_bld = -1
	elif kind == "market":
		host.market_open = true
		host.selected = -1
		host.selected_bld = -1
	elif held_thronglet:
		host.selected = -1
		host.selected_bld = -1
	else:
		host.selected = -1
		host.selected_bld = -1



## World aim point snapped to thronglet feet.
func aim_thronglet(living_only: bool) -> Vector2:
	var id = throng_under_cursor(living_only)
	if id < 0:
		return host.cam_rig.pointer_world()
	var sim: ThrongletSim = ThrongletSimServer
	return Vector2(sim.pos_x[id], sim.pos_y[id])


## Topmost thronglet hit-tested from mouse.
func throng_under_cursor(living_only: bool) -> int:
	var sim: ThrongletSim = ThrongletSimServer
	var mouse = host.get_global_mouse_position()
	var probe = host.cam_rig.from_iso(mouse + Vector2(0.0, 10.0))
	var best = -1
	var best_feet = -1.0e9
	var best_live = false
	for raw in sim.spatial.query_radius(probe.x, probe.y, 40.0):
		var i = int(raw)
		var st = int(sim.state[i])
		if st != Catalog.ST_LIVING and st != Catalog.ST_DEAD:
			continue
		var live = st == Catalog.ST_LIVING
		if living_only and not live:
			continue
		if live and (sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0):
			continue
		var feet = host.cam_rig.to_iso(Vector2(sim.pos_x[i], sim.pos_y[i]))
		var delta = mouse - feet
		if absf(delta.x) > 12.0 or delta.y > 4.0 or delta.y < -24.0:
			continue
		if best >= 0 and live == best_live and feet.y < best_feet:
			continue
		if best >= 0 and not live and best_live:
			continue
		best = i
		best_feet = feet.y
		best_live = live
	return best


## Starter egg item under the mouse.
func egg_under_cursor() -> Dictionary:
	var mouse = host.get_global_mouse_position()
	var best = {}
	var best_feet = -1.0e9
	for it in ThrongletSimServer.items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_EGG:
			continue
		var feet = host.cam_rig.to_iso(Vector2(float(it.x), float(it.y)))
		feet.y -= float(it.get("air", 0.0))
		var delta = mouse - feet
		if absf(delta.x) > 8.0 or delta.y > 3.0 or delta.y < -18.0:
			continue
		if feet.y < best_feet:
			continue
		best = it
		best_feet = feet.y
	return best


## Whether the tool is feed, play, or sponge.
func is_care_tool(tool_id: int) -> bool:
	return tool_id == Catalog.TOOL_APPLE or tool_id == Catalog.TOOL_BALL or tool_id == Catalog.TOOL_SPONGE


## Whether drag preview snaps to the build grid.
func want_place_grid() -> bool:
	if host.in_title or not drop_on_island():
		return false
	var sim: ThrongletSim = ThrongletSimServer
	if not host.kit_drag.is_empty():
		var drag_type = str(host.kit_drag.get("type", ""))
		if drag_type == "build" or drag_type == "prop":
			return true
		return int(host.kit_drag.get("id", -1)) == Catalog.TOOL_TNT
	if sim.hand_id != -1:
		var hand: Dictionary = sim.player_tools.hand_item()
		return not hand.is_empty() and Catalog.item_snaps_grid(int(hand.kind))
	if sim.held_kind == "building" or sim.held_kind == "rock":
		return true
	return host.tool == Catalog.TOOL_TNT


## False when pointer is over blocking UI panels.
func drop_on_island() -> bool:
	var mouse = host.get_viewport().get_mouse_position()
	for panel in [host.kit_panel, host.kit_tab_row, host.market_panel, host.gaze_panel, host.game_flow.slots_panel, host.game_flow.menu_dim]:
		if panel != null and panel.visible and panel.get_global_rect().has_point(mouse):
			return false
	return true

