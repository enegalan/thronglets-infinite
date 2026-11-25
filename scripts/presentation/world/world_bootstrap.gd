extends RefCounted
class_name WorldBootstrap

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const PathOverlay := preload("res://scripts/presentation/world/path_overlay.gd")
const DashArea := preload("res://scripts/presentation/overlays/dash_area.gd")

# Matches tools/make_art.py CELL. The quad is the whole cell; sprites sit on its bottom edge.
## World grid cell size in pixels.
const WORLD_CELL := 128.0
## Atlas tile id for river water.
const RIVER_ATLAS := 12
## Atlas tile id base for waste variants.
const WASTE_ATLAS := 48
## Number of waste tile variants.
const WASTE_VARIANTS := 6
## Frames in the water animation loop.
const WATER_FRAMES := 4
## Water animation speed in frames per second.
const WATER_ANIM_SPEED := 6.0

## Cached terrain and path atlases loaded when building tilesets and painting.
var _ui_assets: UIAssets
## Connects grass-path cells to tilemap stamps and iso path sprites per chunk.
var _path_overlay: PathOverlay
## River tile variant index last written to avoid redundant tilemap updates.
var _water_frame := -1


## Injects texture loading and path stamping used by chunk paint and tileset build.
func setup(ui_assets: UIAssets, path_overlay = null) -> void:
	_ui_assets = ui_assets
	_path_overlay = path_overlay


## Builds the starfield backdrop behind the island.
func build_sky(host: Node2D) -> void:
	var sky := CanvasLayer.new()
	sky.layer = -1
	host.add_child(sky)
	var stars := TextureRect.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.texture = _ui_assets.tex("res://resources/tiles/space.png")
	stars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stars.stretch_mode = TextureRect.STRETCH_SCALE
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(stars)


## Creates tilemaps, multimesh layers, void back, and the play camera on [param host].
func build_world(host: Node2D) -> void:
	host.tilemap = TileMapLayer.new()
	host.tilemap.tile_set = make_tileset()
	host.tilemap.z_index = 0
	host.add_child(host.tilemap)
	host.pathmap = TileMapLayer.new()
	host.pathmap.tile_set = make_path_tileset()
	host.pathmap.z_index = 1
	host.pathmap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(host.pathmap)
	# Water is painted as terrain tiles on the main tilemap (uniform, no shore/corner shaping).
	host.path_root = Node2D.new()
	host.path_root.z_index = 1
	host.add_child(host.path_root)
	host._attach_world_overlay_nodes()
	# Static quiet features sit under world_layer so far-view thronglets read on top.
	host.feat_static = Node2D.new()
	host.feat_static.z_index = 2
	host.feat_static.visible = false
	host.add_child(host.feat_static)
	host._feat_bands = []
	host.world_layer = Node2D.new()
	host.world_layer.z_index = 2
	host.add_child(host.world_layer)
	host.world = MultiMeshInstance2D.new()
	host.world.multimesh = mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
	host.world_layer.add_child(host.world)
	host._prop_bands = [host.world]
	host.throng_crowd = MultiMeshInstance2D.new()
	host.throng_crowd.z_index = 3
	host.throng_crowd_mesh = mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
	host.throng_crowd.multimesh = host.throng_crowd_mesh
	host.throng_crowd_mesh.visible_instance_count = 0
	host.throng_crowd.visible = false
	host.add_child(host.throng_crowd)
	host.void_back = Node2D.new()
	host.void_back.z_index = -1
	host.add_child(host.void_back)
	host._void_bands = []
	host.camera = Camera2D.new()
	host.add_child(host.camera)
	host.camera.make_current()


## Builds the isometric terrain tileset from the terrain atlas.
func make_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(32, 16)
	var atlas := TileSetAtlasSource.new()
	var terrain := _ui_assets.tex("res://resources/tiles/terrain_tileset.png")
	atlas.texture = terrain
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in terrain.get_width() / 32:
		var coord := Vector2i(i, 0)
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
	return tileset


## Builds the isometric path overlay tileset.
func make_path_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(32, 16)
	var atlas := TileSetAtlasSource.new()
	var path_tex := _ui_assets.tex("res://resources/tiles/path_overlay.png")
	atlas.texture = path_tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in 15:
		atlas.create_tile(Vector2i(i, 0))
	return tileset


## Advances animated water tiles when the frame index changes.
func sync_water_animation(host: Node2D, anim_time: float) -> void:
	if host.water_cells.is_empty() or host.tilemap == null:
		return
	var frame := posmod(int(anim_time * WATER_ANIM_SPEED), WATER_FRAMES)
	if frame == _water_frame:
		return
	_water_frame = frame
	for cell in host.water_cells.keys():
		host.tilemap.set_cell(cell, 0, Vector2i(RIVER_ATLAS + frame, 0))


## Repaints dirty/fog chunks and ensures the camera neighborhood is drawn.
func sync_world(host: Node2D, cam_rig: CameraRig) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.paint_epoch != seen_epoch(host):
		set_seen_epoch(host, sim.paint_epoch)
		host.call("_clear_world_sprite_registry")
		host.painted.clear()
		host.tilemap.clear()
		host.water_cells.clear()
		if host.pathmap != null:
			host.pathmap.clear()
			for cell in _path_overlay.path_nodes.keys():
				_path_overlay.drop_path_at(cell, true)
	for ck in sim.take_dirty():
		paint_chunk(host, str(ck), not sim.chunk_shown(str(ck)), null)
	var rect := cam_rig.world_view().grow(128.0)
	var size := float(Catalog.TILE * Catalog.CHUNK)
	var x0 := int(floor(rect.position.x / size))
	var y0 := int(floor(rect.position.y / size))
	var x1 := int(floor(rect.end.x / size))
	var y1 := int(floor(rect.end.y / size))
	for cy in range(y0 - 1, y1 + 2):
		for cx in range(x0 - 1, x1 + 2):
			var ck := "%d,%d" % [cx, cy]
			if sim.chunk_shown(ck):
				if str(host.painted.get(ck, "")) != "real":
					paint_chunk(host, ck, false)
			elif str(host.painted.get(ck, "")) != "fog":
				paint_chunk(host, ck, true)


## Returns the last paint epoch applied on [param host].
func seen_epoch(host: Node2D) -> int:
	return int(host.seen_epoch)


## Records which sim paint_epoch the host terrain already reflects after a full clear.
func set_seen_epoch(host: Node2D, epoch: int) -> void:
	host.seen_epoch = epoch


## Paints one chunk as fog or real terrain (and optional path overlay).
## [param into] optional alternate TileMapLayer (focus viewport); null uses the main map.
func paint_chunk(host: Node2D, ck: String, fog: bool, into = null) -> void:
	var map: TileMapLayer = host.tilemap if into == null else into
	var paths: TileMapLayer = host.pathmap if into == null else host.focus_pathmap
	var sim: ThrongletSim = ThrongletSimServer
	var origin: Vector2i = sim.chunk_origin(ck)
	var main_world := into == null
	if fog:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var cell := origin + Vector2i(lx, ly)
				map.erase_cell(cell)
				_path_overlay.drop_path_at(cell, main_world)
				if main_world:
					host.water_cells.erase(cell)
		if main_world:
			host.painted[ck] = "fog"
		return
	var tiles: PackedByteArray = sim.chunk_tiles(ck)
	if tiles.is_empty():
		return
	# Clear stale water cells for this chunk before repainting.
	if main_world:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				host.water_cells.erase(origin + Vector2i(lx, ly))
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(tiles[ly * Catalog.CHUNK + lx])
			var cell: Vector2i = origin + Vector2i(lx, ly)
			if tile == Catalog.TILE_VOID:
				map.erase_cell(cell)
				_path_overlay.drop_path_at(cell, main_world)
				if main_world:
					host.water_cells.erase(cell)
			else:
				var atlas_x := tile
				if tile == Catalog.TILE_GRASS:
					var pick := absi((lx * 13 + ly * 7) % 3)
					if pick == 1:
						atlas_x = 10
					elif pick == 2:
						atlas_x = 11
				elif tile == Catalog.TILE_WATER:
					var variant := absi((cell.x * 3 + cell.y * 5) % WATER_FRAMES)
					atlas_x = RIVER_ATLAS + variant
					if main_world:
						host.water_cells[cell] = variant
				elif tile == Catalog.TILE_GOO:
					atlas_x = WASTE_ATLAS + absi((cell.x * 3 + cell.y * 5) % WASTE_VARIANTS)
				map.set_cell(cell, 0, Vector2i(atlas_x, 0))
				_path_overlay.paint_path_cell(paths, cell, tile)
	if main_world:
		host.painted[ck] = "real"


## Creates the thronglet atlas shader material for MultiMesh bands.
func material(h_frames: int, v_frames: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/thronglet_shader.gdshader")
	mat.set_shader_parameter("h_frames", h_frames)
	mat.set_shader_parameter("v_frames", v_frames)
	return mat


## Creates an empty colored MultiMesh with a quad of [param size].
func mesh(colored: bool, size: Vector2) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_2D
	m.use_custom_data = true
	m.use_colors = colored
	m.mesh = quad
	m.instance_count = 16
	m.visible_instance_count = 0
	return m
