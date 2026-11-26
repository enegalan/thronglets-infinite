class_name PathLabTune

## Path overlay piece map. Saved to res://dev/path_lab.json.
##
## Thin trails use the 4 cardinal bits (N=1 E=2 S=4 W=8) when no diagonal
## "counts". Filled plazas (2x2 / 4x4 blobs from screenshots ~54:30+) also need
## diagonals: a diagonal only counts when both adjacent cardinals are path
## (classic blob rule). That unlocks the unused atlas tiles (3,7–14), especially
## tile 9 rotated for outer corners of a filled block.

const PATH := "res://dev/path_lab.json"
const SHEET := "res://resources/tiles/path_overlay.png"
const TILE_COUNT := 15

## Cardinal bits.
const N := 1
const E := 2
const S := 4
const W := 8

## Diagonal bits (only valid when both adjacent cardinals are set).
const NE := 1
const SE := 2
const SW := 4
const NW := 8

## Thin trail defaults (old PATH_PIECE). Used when no counted diagonal is set.
const DEFAULT_THIN := [
	"0h", "6rv", "6h", "5h", "6r", "4rv", "5hv", "2rrr",
	"6", "5", "4", "2", "5r", "2rv", "2rrh", "1",
]

## Fill / blob defaults. Tile 9 = outer corner (dirt NW, grass SE) + rotations.
## Tile 8 = solid interior. Edges/inners are best-effort starters for the lab.
## Fill defaults from lab (dev/path_lab.json).
const DEFAULT_FILL := {
	"fill_solid": "8",
	"fill_outer_se": "9",
	"fill_outer_sw": "9rrr",
	"fill_outer_nw": "9rr",
	"fill_outer_ne": "9r",
	"fill_edge_n": "10rr",
	"fill_edge_e": "10r",
	"fill_edge_s": "10",
	"fill_edge_w": "10rrr",
	# T into a 2xN / stepped blob (one counted diagonal, not a full edge).
	"fill_t_n": "10v",
	"fill_t_e": "14rv",
	"fill_t_s": "3",
	"fill_t_w": "14rrr",
	"fill_inner_se": "3rrr",
	"fill_inner_sw": "3rr",
	"fill_inner_nw": "7rr",
	"fill_inner_ne": "3",
}

## Ordered fill type ids shown in the lab.
const FILL_IDS := [
	"fill_solid",
	"fill_outer_se", "fill_outer_sw", "fill_outer_nw", "fill_outer_ne",
	"fill_edge_n", "fill_edge_e", "fill_edge_s", "fill_edge_w",
	"fill_t_n", "fill_t_e", "fill_t_s", "fill_t_w",
	"fill_inner_se", "fill_inner_sw", "fill_inner_nw", "fill_inner_ne",
]

const FILL_LABELS := {
	"fill_solid": "RELLENO SOLIDO",
	"fill_outer_se": "RELLENO ESQ SE",
	"fill_outer_sw": "RELLENO ESQ SW",
	"fill_outer_nw": "RELLENO ESQ NW",
	"fill_outer_ne": "RELLENO ESQ NE",
	"fill_edge_n": "RELLENO BORDE N",
	"fill_edge_e": "RELLENO BORDE E",
	"fill_edge_s": "RELLENO BORDE S",
	"fill_edge_w": "RELLENO BORDE W",
	"fill_t_n": "RELLENO T N",
	"fill_t_e": "RELLENO T E",
	"fill_t_s": "RELLENO T S",
	"fill_t_w": "RELLENO T W",
	"fill_inner_se": "RELLENO INT SE",
	"fill_inner_sw": "RELLENO INT SW",
	"fill_inner_nw": "RELLENO INT NW",
	"fill_inner_ne": "RELLENO INT NE",
}

## Human labels for each thin 4-neighbor mask (0–15).
const MASK_LABELS := [
	"SOLO",
	"PUNTA N",
	"PUNTA E",
	"ESQUINA N+E",
	"PUNTA S",
	"RECTO N-S",
	"ESQUINA E+S",
	"T N+E+S",
	"PUNTA W",
	"ESQUINA N+W",
	"RECTO E-W",
	"T N+E+W",
	"ESQUINA S+W",
	"T N+S+W",
	"T E+S+W",
	"CRUZ",
]

## Short kind tag for thin masks.
const MASK_KINDS := [
	"aislado",
	"punta",
	"punta",
	"esquina",
	"punta",
	"recto",
	"esquina",
	"T",
	"punta",
	"esquina",
	"recto",
	"T",
	"esquina",
	"T",
	"T",
	"cruz",
]

## Internal cache backing path lab tune lookups.
static var _cache: Dictionary = {}
## Internal cache backing path lab tune lookups.
static var _cache_mtime: int = -1


## Shipped defaults for path_lab.json.
static func defaults() -> Dictionary:
	var thin: Array = []
	for mask in range(16):
		thin.append({
			"mask": mask,
			"id": thin_id(mask),
			"label": MASK_LABELS[mask],
			"kind": MASK_KINDS[mask],
			"dirs": mask_dirs(mask),
			"piece": DEFAULT_THIN[mask],
		})
	var fill: Array = []
	for id in FILL_IDS:
		fill.append({
			"id": id,
			"label": str(FILL_LABELS.get(id, id)),
			"kind": "relleno",
			"piece": str(DEFAULT_FILL.get(id, "8")),
		})
	return {
		"sheet": SHEET,
		"tile_count": TILE_COUNT,
		"bits": {"N": N, "E": E, "S": S, "W": W, "NE": NE, "SE": SE, "SW": SW, "NW": NW},
		"thin": thin,
		"fill": fill,
	}


## Clears cached lab JSON so the next read reloads from disk.
static func invalidate() -> void:
	_cache.clear()
	_cache_mtime = -1


## Thin type id for cardinal [param mask].
static func thin_id(mask: int) -> String:
	return "thin_%02d" % clampi(mask, 0, 15)


## Direction letters present in cardinal [param mask].
static func mask_dirs(mask: int) -> Array:
	var dirs: Array = []
	if mask & N:
		dirs.append("N")
	if mask & E:
		dirs.append("E")
	if mask & S:
		dirs.append("S")
	if mask & W:
		dirs.append("W")
	return dirs


## Display label for thin [param mask].
static func label_for(mask: int) -> String:
	return MASK_LABELS[clampi(mask, 0, 15)]


## Kind tag for thin [param mask].
static func kind_for(mask: int) -> String:
	return MASK_KINDS[clampi(mask, 0, 15)]


## Label for a type id (thin_XX or fill_*).
static func label_for_id(id: String) -> String:
	if id.begins_with("thin_"):
		return label_for(int(id.substr(5)))
	return str(FILL_LABELS.get(id, id))


## Counts set bits in [param value].
static func _pop(value: int) -> int:
	var n := 0
	var v := value
	while v != 0:
		n += v & 1
		v >>= 1
	return n


## Resolves type id from cardinal + counted-diagonal masks.
static func type_id(card: int, diag: int) -> String:
	var c := card & 15
	var d := diag & 15
	# Diagonals that cannot count are ignored by the caller; still clamp.
	if d == 0:
		return thin_id(c)

	# Full surround → solid fill (4x4 interiors).
	if c == 15 and d == 15:
		return "fill_solid"

	# Four cardinals with one grass pocket → inner corner.
	if c == 15:
		if d == (NE | SE | SW):
			return "fill_inner_nw"
		if d == (SE | SW | NW):
			return "fill_inner_ne"
		if d == (SW | NW | NE):
			return "fill_inner_se"
		if d == (NW | NE | SE):
			return "fill_inner_sw"
		# Partial diagonals with full cardinals: prefer solid if 2+ diags, else thin cross.
		if _pop(d) >= 2:
			return "fill_solid"
		return thin_id(15)

	# Outer corner of a filled block: exactly two adjacent cardinals + their diagonal.
	if c == (N | W) and (d & NW):
		return "fill_outer_se"
	if c == (N | E) and (d & NE):
		return "fill_outer_sw"
	if c == (S | E) and (d & SE):
		return "fill_outer_nw"
	if c == (S | W) and (d & SW):
		return "fill_outer_ne"

	# Edge of a filled block: named by the open (grass) side.
	# Missing N → northern edge; missing E → eastern edge; etc.
	if c == (E | S | W) and (d & SE) and (d & SW):
		return "fill_edge_n"
	if c == (N | S | W) and (d & NW) and (d & SW):
		return "fill_edge_e"
	if c == (N | E | W) and (d & NE) and (d & NW):
		return "fill_edge_s"
	if c == (N | E | S) and (d & NE) and (d & SE):
		return "fill_edge_w"

	# T with only one counted diagonal: 2x2 + stub / stepped 2xN (tile 14).
	# Full edges already returned above when both diags are set.
	if c == (E | S | W):
		return "fill_t_n"
	if c == (N | S | W):
		return "fill_t_e"
	if c == (N | E | W):
		return "fill_t_s"
	if c == (N | E | S):
		return "fill_t_w"

	# Anything else with a counted diagonal falls back to thin art for that card.
	return thin_id(c)


## Piece string for cardinal+diag from saved config.
static func piece_for(card: int, diag: int = 0) -> String:
	return piece_for_id(type_id(card, diag))


## Compat: thin-only lookup by cardinal mask.
static func piece(mask: int) -> String:
	return piece_for(mask, 0)


## Piece string for a type id.
static func piece_for_id(id: String) -> String:
	var cfg := load_saved()
	if id.begins_with("thin_"):
		var mask := clampi(int(id.substr(5)), 0, 15)
		var thin = cfg.get("thin", cfg.get("pieces", []))
		if typeof(thin) == TYPE_ARRAY and thin.size() > mask:
			var row = thin[mask]
			if typeof(row) == TYPE_DICTIONARY and row.has("piece"):
				return str(row.piece)
			if typeof(row) == TYPE_STRING:
				return str(row)
		return DEFAULT_THIN[mask]
	var fill = cfg.get("fill", [])
	if typeof(fill) == TYPE_ARRAY:
		for row in fill:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
				return str(row.get("piece", DEFAULT_FILL.get(id, "8")))
	return str(DEFAULT_FILL.get(id, "8"))


## Parses a piece string into atlas index and transform ops.
static func parse_piece(piece_str: String) -> Dictionary:
	var raw := piece_str.strip_edges()
	var index_chars := ""
	var ops := ""
	for i in raw.length():
		var ch := raw.substr(i, 1)
		if index_chars.is_empty() and ch.is_valid_int():
			index_chars += ch
		elif ch.is_valid_int() and ops.is_empty():
			index_chars += ch
		else:
			ops += ch
	var index := int(index_chars) if index_chars != "" else 0
	index = clampi(index, 0, TILE_COUNT - 1)
	return {"index": index, "ops": ops}


## Builds a piece string from atlas [param index] and [param ops].
static func encode_piece(index: int, ops: String) -> String:
	var clean_ops := ""
	for i in ops.length():
		var ch := ops.substr(i, 1).to_lower()
		if ch == "h" or ch == "v" or ch == "r":
			clean_ops += ch
	return "%d%s" % [clampi(index, 0, TILE_COUNT - 1), clean_ops]


## Loads path_lab.json and merges over defaults.
static func load_saved() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		_cache = defaults()
		_cache_mtime = -1
		return _cache.duplicate(true)
	var mtime := FileAccess.get_modified_time(PATH)
	if not _cache.is_empty() and mtime == _cache_mtime:
		return _cache.duplicate(true)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_cache = defaults()
		_cache_mtime = mtime
		return _cache.duplicate(true)
	_cache = _merge(defaults(), parsed)
	_cache_mtime = mtime
	return _cache.duplicate(true)


## Writes a path lab config dictionary to disk.
static func save_file(cfg: Dictionary) -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("path lab: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(_normalize(cfg), "  "))
	file.close()
	invalidate()
	return ProjectSettings.globalize_path(PATH)


## Normalizes cfg into the shipped schema before writing.
static func _normalize(cfg: Dictionary) -> Dictionary:
	return _merge(defaults(), cfg)


## Merges saved thin/fill piece strings over defaults.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	if over.has("sheet"):
		out.sheet = str(over.sheet)
	if over.has("tile_count"):
		out.tile_count = int(over.tile_count)

	var thin_src = over.get("thin", over.get("pieces", []))
	if typeof(thin_src) == TYPE_ARRAY:
		var thin: Array = out.thin
		for i in mini(thin.size(), thin_src.size()):
			var row: Dictionary = thin[i]
			var item = thin_src[i]
			if typeof(item) == TYPE_DICTIONARY and item.has("piece"):
				row.piece = str(item.piece)
			elif typeof(item) == TYPE_STRING:
				row.piece = str(item)
			thin[i] = row
		out.thin = thin
	# Drop legacy duplicate key if present in memory after merge/save.
	out.erase("pieces")

	var fill_src = over.get("fill", [])
	if typeof(fill_src) == TYPE_ARRAY:
		var by_id := {}
		for item in fill_src:
			if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("piece"):
				by_id[str(item.id)] = str(item.piece)
		var fill: Array = out.fill
		for i in fill.size():
			var row: Dictionary = fill[i]
			var id := str(row.id)
			if by_id.has(id):
				row.piece = by_id[id]
			fill[i] = row
		out.fill = fill
	return out
