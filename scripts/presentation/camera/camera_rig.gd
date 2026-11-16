extends RefCounted
class_name CameraRig

const ZOOM_MIN := 0.55
const ZOOM_MAX := 4.5
const ZOOM_STEP := 1.12

var zoom_level := 2.0
var dragging := false
var drag_from := Vector2.ZERO
var cam_from := Vector2.ZERO

var _camera: Camera2D
var _tilemap: TileMapLayer
var _get_viewport_rect: Callable
var _get_mouse_viewport: Callable
var _get_mouse_global: Callable


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


func zoom_by(direction: float, modal_open: bool = false) -> void:
	if modal_open:
		return
	if direction > 0.0:
		zoom_factor(ZOOM_STEP)
	elif direction < 0.0:
		zoom_factor(1.0 / ZOOM_STEP)


func zoom_factor(factor: float, modal_open: bool = false) -> void:
	if factor <= 0.0 or modal_open:
		return
	zoom_level = clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


func begin_drag(mouse_pos: Vector2) -> void:
	dragging = true
	drag_from = mouse_pos
	cam_from = _camera.position


func end_drag() -> void:
	dragging = false


func is_dragging() -> bool:
	return dragging


func set_zoom(level: float) -> void:
	zoom_level = clampf(level, ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()


func focus_world(world_pos: Vector2) -> void:
	_camera.position = to_iso(world_pos)
	_snap()


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


func iso_view() -> Rect2:
	var size: Vector2 = Vector2(_get_viewport_rect.call().size) / zoom_level
	return Rect2(_camera.position - size * 0.5, size)


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


func to_iso(world_pos: Vector2) -> Vector2:
	# Match TileMapLayer.map_to_local for DIAMOND_DOWN (half-tile origin offset).
	var tile := Vector2(_tilemap.tile_set.tile_size)
	var cell := world_pos / float(Catalog.TILE) - Vector2(0.5, 0.5)
	return Vector2(
		tile.x * 0.5 * (cell.x - cell.y + 1.0),
		tile.y * 0.5 * (cell.x + cell.y + 1.0),
	)


func from_iso(iso: Vector2) -> Vector2:
	var tile := Vector2(_tilemap.tile_set.tile_size)
	var a := iso.x / (tile.x * 0.5)
	var b := iso.y / (tile.y * 0.5)
	var cell := Vector2((a + b) * 0.5 - 1.0, (b - a) * 0.5)
	return (cell + Vector2(0.5, 0.5)) * float(Catalog.TILE)


func pointer_world() -> Vector2:
	return from_iso(Vector2(_get_mouse_global.call()))


func grid_pointer_world() -> Vector2:
	# Use Godot's diamond hit-test so the cell under the cursor matches the painted tile.
	var cell: Vector2i = _tilemap.local_to_map(Vector2(_get_mouse_global.call()))
	return Catalog.cell_world(cell)


func _apply_zoom() -> void:
	_camera.zoom = Vector2(zoom_level, zoom_level)


func _snap() -> void:
	var step := 1.0 / zoom_level
	_camera.position = _camera.position.snapped(Vector2(step, step))
