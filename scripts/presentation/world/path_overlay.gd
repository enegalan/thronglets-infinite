extends RefCounted
class_name PathOverlay

const UIAssets := preload("res://scripts/presentation/ui/ui_assets.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")

# Neighbor mask: N=1, E=2, S=4, W=8. Each piece is a TEMP_Path index plus
# flips: h, v, and r (90 degrees counter-clockwise). The draw maps sprite east
# onto the east neighbor, so the bar sits inside the grass diamond.
## Atlas piece index plus h/v/r ops for each 4-neighbor grass-path mask (0–15).
const PATH_PIECE := [
	"0h", "6rv", "6h", "5h", "6r", "4rv", "5hv", "2rrr",
	"6", "5", "4", "2", "5r", "2rv", "2rrh", "1",
]

## Main-world path Sprite2D instances keyed by tile cell.
var path_nodes := {}
## Focus sub-viewport path sprites keyed by tile cell.
var focus_path_nodes := {}
## Baked iso diamond textures cached per PATH_PIECE mask string.
var path_iso := {}
## Decoded pixels from path_overlay.png for slicing raw path tiles.
var path_sheet: Image

## Main island path TileMapLayer stamped alongside terrain paints.
var _pathmap: TileMapLayer
## Scene parent for main-world path diamond sprites above the tilemap.
var _path_root: Node2D
## Focus viewport path tile layer when painting the magnified hole.
var _focus_pathmap: TileMapLayer
## Scene parent for focus-path diamond sprites.
var _focus_path_root: Node2D
## Texture loader used to read path_overlay.png into path_sheet.
var _ui_assets: UIAssets
## Camera rig that positions each path sprite at the cell iso center.
var _cam_rig: CameraRig


## Wires tilemaps, roots, UI assets, and camera rig.
func setup(
		pathmap: TileMapLayer,
		path_root: Node2D,
		focus_pathmap: TileMapLayer,
		focus_path_root: Node2D,
		ui_assets: UIAssets,
		cam_rig: CameraRig,
) -> void:
	_pathmap = pathmap
	_path_root = path_root
	_focus_pathmap = focus_pathmap
	_focus_path_root = focus_path_root
	_ui_assets = ui_assets
	_cam_rig = cam_rig


## Shows or clears path art for [param cell] on [param paths].
func paint_path_cell(paths: TileMapLayer, cell: Vector2i, tile: int) -> void:
	var main := paths == _pathmap
	var show := tile == Catalog.TILE_GRASS and ThrongletSimServer.paths.path_at(cell.x, cell.y)
	if not show:
		drop_path_at(cell, main)
		return
	var sprite := path_sprite_at(cell, main)
	var mask := path_mask(cell)
	sprite.texture = path_iso_tex(PATH_PIECE[mask])
	sprite.position = _cam_rig.to_iso(Catalog.cell_world(cell))
	# Slight overlap so neighboring diamonds cover the shared corner.
	sprite.scale = Vector2(1.12, 1.12)


## Four-neighbor bitmask for path connectivity at [param cell].
func path_mask(cell: Vector2i) -> int:
	var mask := 0
	if ThrongletSimServer.paths.path_at(cell.x, cell.y - 1):
		mask |= 1
	if ThrongletSimServer.paths.path_at(cell.x + 1, cell.y):
		mask |= 2
	if ThrongletSimServer.paths.path_at(cell.x, cell.y + 1):
		mask |= 4
	if ThrongletSimServer.paths.path_at(cell.x - 1, cell.y):
		mask |= 8
	return mask


## True if pixel ([param px], [param py]) lies inside the iso diamond.
func path_in_diamond(px: int, py: int) -> bool:
	var dx := absf(float(px) - 18.0) / 18.0
	var dy := absf(float(py) - 10.0) / 10.0
	return dx + dy <= 1.02


## Average opaque color from 16x16 path tile [param tile].
func path_fill_color(tile: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in 16:
		for x in 16:
			var color := tile.get_pixel(x, y)
			if color.a <= 40.0 / 255.0:
				continue
			r += color.r
			g += color.g
			b += color.b
			n += 1
	if n <= 0:
		return Color(0.47, 0.33, 0.2, 1.0)
	var inv := 1.0 / float(n)
	return Color(r * inv, g * inv, b * inv, 1.0)


## Builds or returns cached iso diamond texture for mask piece [param piece].
func path_iso_tex(piece: String) -> Texture2D:
	if path_iso.has(piece):
		return path_iso[piece]
	var tile := path_raw(piece.to_int())
	var ops := piece
	while not ops.is_empty() and ops.substr(0, 1).is_valid_int():
		ops = ops.substr(1)
	for i in ops.length():
		tile = path_turn(tile, ops.substr(i, 1))
	var fill := path_fill_color(tile)
	var baked := Image.create(36, 20, false, Image.FORMAT_RGBA8)
	baked.fill(Color(0, 0, 0, 0))
	# Solid diamond underlay, then path detail on top. Contiguous cells then
	# join instead of leaving grass diamonds at every 4-way intersection.
	for py in 20:
		for px in 36:
			if not path_in_diamond(px, py):
				continue
			baked.set_pixel(px, py, fill)
	for py in 20:
		for px in 36:
			var dx := px - 18
			var dy := py - 10
			var lx := dx * 0.5 + float(dy)
			var ly := float(dy) - dx * 0.5
			var sx := int(round(lx + 7.5))
			var sy := int(round(ly + 7.5))
			if sx < 0 or sy < 0 or sx > 15 or sy > 15:
				continue
			var color := tile.get_pixel(sx, sy)
			if color.a <= 40.0 / 255.0:
				continue
			baked.set_pixel(px, py, color)
	var tex := ImageTexture.create_from_image(baked)
	path_iso[piece] = tex
	return tex


## Extracts one 16x16 path tile from the sheet by [param index].
func path_raw(index: int) -> Image:
	if path_sheet == null:
		var tex: Texture2D = _ui_assets.tex("res://resources/tiles/path_overlay.png")
		path_sheet = tex.get_image()
	var raw := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ox := index * 32
	for y in 16:
		for x in 16:
			raw.set_pixel(x, y, path_sheet.get_pixel(ox + x * 2, y * 2))
	return raw


## Flips or rotates [param src] per transform op in [param op].
func path_turn(src: Image, op: String) -> Image:
	var out := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var sx := x
			var sy := y
			if op == "h":
				sx = 15 - x
			elif op == "v":
				sy = 15 - y
			else:
				sx = 15 - y
				sy = x
			out.set_pixel(x, y, src.get_pixel(sx, sy))
	return out


## Gets or creates path sprite for [param cell] on main or focus layer.
func path_sprite_at(cell: Vector2i, main: bool) -> Sprite2D:
	var nodes: Dictionary = path_nodes if main else focus_path_nodes
	if nodes.has(cell):
		return nodes[cell]
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var root := _path_root if main else _focus_path_root
	root.add_child(sprite)
	nodes[cell] = sprite
	return sprite


## Frees path sprite at [param cell] if present.
func drop_path_at(cell: Vector2i, main: bool) -> void:
	var nodes: Dictionary = path_nodes if main else focus_path_nodes
	if not nodes.has(cell):
		return
	var sprite: Sprite2D = nodes[cell]
	sprite.queue_free()
	nodes.erase(cell)


## Clears main path tilemap and sprites (avoids dev bench overlap).
func clear_paths(pathmap: TileMapLayer) -> void:
	if pathmap != null:
		pathmap.clear()
	for cell in path_nodes.keys():
		var sprite: Sprite2D = path_nodes[cell]
		if is_instance_valid(sprite):
			sprite.queue_free()
	path_nodes.clear()


## Removes all focus-layer path sprites.
func clear_focus_paths() -> void:
	for cell in focus_path_nodes.keys():
		drop_path_at(cell, false)