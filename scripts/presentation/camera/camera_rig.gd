extends RefCounted
class_name CameraRig


## Camera pan, zoom, iso/world picking, and viewport bounds for Main.

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")

## Closest allowed camera zoom (wide view).
const ZOOM_MIN := 0.55
## Furthest allowed camera zoom (tight view).
const ZOOM_MAX := 4.5
## Multiplier applied per wheel notch or zoom hotkey step.
const ZOOM_STEP := 1.12

## Current uniform zoom factor pushed to the Camera2D each frame.
var zoom_level := 2.0
## True while the player is click-dragging to pan the view.
var dragging := false
## Viewport mouse position where the current drag began.
var drag_from := Vector2.ZERO
## Camera position saved at drag start for offset panning.
var cam_from := Vector2.ZERO

## Scene Camera2D node whose position and zoom this rig drives.
var _camera: Camera2D
## Tile layer used for iso/world coordinate conversion.
var _tilemap: TileMapLayer
## Host callback that returns the visible viewport rect in pixels.
var _get_viewport_rect: Callable
## Host callback for mouse position in viewport space during drag.
var _get_mouse_viewport: Callable
## Host callback for mouse position in global/camera space for picking.
var _get_mouse_global: Callable


## Wires camera, tilemap, and input callables then applies initial zoom.
func setup(
		camera: Camera2D,
		tilemap: TileMapLayer,
		get_viewport_rect: Callable,
		get_mouse_viewport: Callable,
		get_mouse_global: Callable,
) -> void:
	_camera = camera
	_tilemap = tilemap
	_get_viewport_rect = get_viewport_rect
	_get_mouse_viewport = get_mouse_viewport
	_get_mouse_global = get_mouse_global
	_apply_zoom()
	_snap()


## Steps zoom in or out when not blocked by a modal.
func zoom_by(direction: float, modal_open: bool = false) -> void:
	if modal_open:
		return
	if direction > 0.0:
		zoom_factor(ZOOM_STEP)
	elif direction < 0.0:
		zoom_factor(1.0 / ZOOM_STEP)


## Multiplies zoom level by [param factor] within configured limits.
func zoom_factor(factor: float, modal_open: bool = false) -> void:
	if factor <= 0.0 or modal_open:
		return
	zoom_level = clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


## Starts a drag-pan from [param mouse_pos].
func begin_drag(mouse_pos: Vector2) -> void:
	dragging = true
	drag_from = mouse_pos
	cam_from = _camera.position


## Ends an in-progress drag-pan.
func end_drag() -> void:
	dragging = false


## True while a mouse drag is offsetting the camera from [member drag_from].
func is_dragging() -> bool:
	return dragging


## Sets absolute zoom [param level] within min/max bounds.
func set_zoom(level: float) -> void:
	zoom_level = clampf(level, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


## Centers the camera on [param world_pos] in world space.
func focus_world(world_pos: Vector2) -> void:
	_camera.position = to_iso(world_pos)
	_snap()


## Applies keyboard pan, drag offset, zoom, and snap for this frame.
func move(delta: float, typing: bool, dev_on: bool) -> void:
	var keys := Vector2.ZERO
	if not typing:
		if Input.is_key_pressed(KEY_A) or (not dev_on and Input.is_key_pressed(KEY_LEFT)):
			keys.x -= 1.0
		if Input.is_key_pressed(KEY_D) or (not dev_on and Input.is_key_pressed(KEY_RIGHT)):
			keys.x += 1.0
		if Input.is_key_pressed(KEY_W) or (not dev_on and Input.is_key_pressed(KEY_UP)):
			keys.y -= 1.0
		if Input.is_key_pressed(KEY_S) or (not dev_on and Input.is_key_pressed(KEY_DOWN)):
			keys.y += 1.0
	_camera.position += keys * 220.0 * delta / zoom_level
	if dragging:
		var drag := Vector2(_get_mouse_viewport.call()) - drag_from
		_camera.position = cam_from - drag / zoom_level
	_apply_zoom()
	_snap()


## Returns the visible viewport in isometric (camera) space.
func iso_view() -> Rect2:
	var size: Vector2 = Vector2(_get_viewport_rect.call().size) / zoom_level
	return Rect2(_camera.position - size * 0.5, size)


## Returns the visible area as an axis-aligned world-space rectangle.
func world_view() -> Rect2:
	var view := iso_view()
	var corners: Array[Vector2] = [
		from_iso(view.position),
		from_iso(view.position + Vector2(view.size.x, 0)),
		from_iso(view.position + Vector2(0, view.size.y)),
		from_iso(view.end),
	]
	var lo := corners[0]
	var hi := corners[0]
	for corner in corners:
		lo = lo.min(corner)
		hi = hi.max(corner)
	return Rect2(lo, hi - lo)


## Maps [param world_pos] to isometric screen space.
func to_iso(world_pos: Vector2) -> Vector2:
	# Match TileMapLayer.map_to_local for DIAMOND_DOWN (half-tile origin offset).
	var tile := Vector2(_tilemap.tile_set.tile_size)
	var cell := world_pos / float(Catalog.TILE) - Vector2(0.5, 0.5)
	return Vector2(
		tile.x * 0.5 * (cell.x - cell.y + 1.0),
		tile.y * 0.5 * (cell.x + cell.y + 1.0),
	)


## Maps [param iso] from isometric space back to world coordinates.
func from_iso(iso: Vector2) -> Vector2:
	var tile := Vector2(_tilemap.tile_set.tile_size)
	var a := iso.x / (tile.x * 0.5)
	var b := iso.y / (tile.y * 0.5)
	var cell := Vector2((a + b) * 0.5 - 1.0, (b - a) * 0.5)
	return (cell + Vector2(0.5, 0.5)) * float(Catalog.TILE)


## World position under the mouse cursor.
func pointer_world() -> Vector2:
	return from_iso(Vector2(_get_mouse_global.call()))


## Snapped world center of the diamond cell under the cursor.
func grid_pointer_world() -> Vector2:
	# Use Godot's diamond hit-test so the cell under the cursor matches the painted tile.
	var cell: Vector2i = _tilemap.local_to_map(Vector2(_get_mouse_global.call()))
	return Catalog.cell_world(cell)


## Pushes [member zoom_level] to the Camera2D node.
func _apply_zoom() -> void:
	_camera.zoom = Vector2(zoom_level, zoom_level)


## Snaps camera position to a zoom-dependent pixel grid.
func _snap() -> void:
	var step := 1.0 / zoom_level
	_camera.position = _camera.position.snapped(Vector2(step, step))


## Biome id at the camera center ([param in_tree] selects coordinate space).
func camera_biome(in_tree: bool) -> String:
	if _camera == null:
		return ""
	var world_pos := from_iso(_camera.position) if in_tree else _camera.position
	return ThrongletSimServer.biome_at(world_pos.x, world_pos.y)


## Returns "mine", "market", or "" for a nearby building at camera center.
func near_spot() -> String:
	var sim: ThrongletSim = ThrongletSimServer
	if _camera == null:
		return ""
	var at := from_iso(_camera.position)
	var mine := false
	var market := false
	for building in sim.buildings:
		if bool(building.get("dead", false)):
			continue
		var kind := int(building.get("kind", -1))
		var dist := at.distance_to(Vector2(float(building.x), float(building.y)))
		if dist > Catalog.NEAR_BUILDING:
			continue
		if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			mine = true
		elif kind == Catalog.BLD_MARKET:
			market = true
	if mine:
		return "mine"
	if market:
		return "market"
	return ""
