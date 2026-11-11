class_name PropTune

# Dev bench overrides. The game never reads this.
# res://dev/prop_tune.json is the handoff for applying the same values in code.

const PATH := "res://dev/prop_tune.json"
const BOOT := "user://dev_bench.flag"

static var _rows: Array = []
static var _index := {}
static var overrides := {}


static func entries() -> Array:
	if _rows.is_empty():
		_build()
	return _rows


static func entry(id: String) -> Dictionary:
	entries()
	return _index.get(id, {})


static func get_tune(id: String) -> Dictionary:
	var tune := _defaults(entry(id))
	if not overrides.has(id):
		return tune
	var over: Dictionary = overrides[id]
	for key in over.keys():
		tune[key] = over[key]
	return tune


static func is_dirty(id: String) -> bool:
	return overrides.has(id) and not (overrides[id] as Dictionary).is_empty()


static func change_count() -> int:
	var n := 0
	for row in entries():
		if is_dirty(str(row.id)):
			n += 1
	return n


static func set_footprint(id: String, x: int, y: int) -> void:
	_assign(id, "footprint", Vector2i(clampi(x, 1, 8), clampi(y, 1, 8)))


static func set_scale(id: String, value: float) -> void:
	_assign(id, "scale", snappedf(clampf(value, 0.25, 3.0), 0.05))


static func set_offset(id: String, x: float, y: float) -> void:
	var at := Vector2(snappedf(clampf(x, -160.0, 160.0), 1.0), snappedf(clampf(y, -160.0, 160.0), 1.0))
	_assign(id, "offset", at)


static func set_z(id: String, value: float) -> void:
	_assign(id, "z", snappedf(clampf(value, -40.0, 40.0), 1.0))


static func set_rot(id: String, value: float) -> void:
	_assign(id, "rot", snappedf(clampf(value, -180.0, 180.0), 1.0))


static func reset(id: String) -> void:
	overrides.erase(id)


static func load_saved() -> void:
	overrides.clear()
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var changes = parsed.get("changes", [])
	if typeof(changes) != TYPE_ARRAY:
		return
	for raw in changes:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var id := str(raw.get("id", ""))
		if entry(id).is_empty():
			continue
		var fields = raw.get("fields", {})
		if typeof(fields) != TYPE_DICTIONARY:
			continue
		for key in fields.keys():
			var field = fields[key]
			if typeof(field) != TYPE_DICTIONARY:
				continue
			var value = _read_value(str(key), field.get("to", null))
			if value == null:
				continue
			_assign(id, str(key), value)


static func save_file() -> String:
	var dir := ProjectSettings.globalize_path("res://dev")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("prop tune: " + error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(JSON.stringify(_document(), "  "))
	file.close()
	return ProjectSettings.globalize_path(PATH)


static func arm_boot() -> void:
	var file := FileAccess.open(BOOT, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("1")


static func consume_boot() -> bool:
	if not FileAccess.file_exists(BOOT):
		return false
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("dev_bench.flag")
	return true


static func _build() -> void:
	for kind in Catalog.BUILD_INFO:
		var info: Dictionary = Catalog.BUILD_INFO[kind]
		_push("building", int(kind), 0, str(info.label), _bld_name(int(kind)), int(info.icon), false)
	_push("feature", Catalog.FEAT_TREE, 0, "ARBOL", "FEAT_TREE", Catalog.ICON_TREE, false)
	_push("feature", Catalog.FEAT_STUMP, 0, "TOCON", "FEAT_STUMP", Catalog.ICON_STUMP, false)
	_push("feature", Catalog.FEAT_ROCK, 0, "ROCA", "FEAT_ROCK", Catalog.ICON_ROCK, false)
	_push("feature", Catalog.FEAT_ROCK, 1, "ROCA MINERAL", "FEAT_ROCK", Catalog.ICON_ORE_ROCK, false)
	_push("feature", Catalog.FEAT_NODE, 0, "NODO", "FEAT_NODE", Catalog.ICON_NODE, false)
	_push("feature", Catalog.FEAT_SUPER, 0, "SUPER", "FEAT_SUPER", Catalog.ICON_SUPER, false)
	_push("feature", Catalog.FEAT_FLOWER, 0, "FLOR", "FEAT_FLOWER", Catalog.ICON_FLOWER, false)
	_push("feature", Catalog.FEAT_MONOLITH, 0, "MONOLITO", "FEAT_MONOLITH", Catalog.ICON_MONOLITH, true)
	_push("feature", Catalog.FEAT_BIGROCK, 0, "ROCA GRANDE", "FEAT_BIGROCK", Catalog.ICON_BIGROCK, false)
	_push("feature", Catalog.FEAT_COSMETIC, 0, "ARBOL RARO", "FEAT_COSMETIC", Catalog.ICON_COSMETIC, false)
	_push("feature", Catalog.FEAT_COSMETIC_BAD, 0, "ARBOL SECO", "FEAT_COSMETIC_BAD", Catalog.ICON_COSMETIC_BAD, false)
	_push("feature", Catalog.FEAT_ORE_MEGA, 0, "MINERAL MEGA", "FEAT_ORE_MEGA", Catalog.ICON_ORE_MEGA, false)
	_push("feature", Catalog.FEAT_ORE_SUPER, 0, "MINERAL SUPER", "FEAT_ORE_SUPER", Catalog.ICON_ORE_SUPER, false)
	_push("feature", Catalog.FEAT_ORE_ULTRA, 0, "MINERAL ULTRA", "FEAT_ORE_ULTRA", Catalog.ICON_ORE_ULTRA, false)
	_push("feature", Catalog.FEAT_FIRE, 0, "FUEGO", "FEAT_FIRE", Catalog.ICON_FIRE, false)
	_push("feature", Catalog.FEAT_TOTEM, 0, "TOTEM", "FEAT_TOTEM", Catalog.ICON_TOTEM, false)
	_push("feature", Catalog.FEAT_CURER, 0, "CURACION", "FEAT_CURER", Catalog.ICON_CURER, false)
	_push("feature", Catalog.FEAT_MSTUMP, 0, "TOCON MEGA", "FEAT_MSTUMP", Catalog.ICON_MSTUMP, false)
	_push("feature", Catalog.FEAT_MNODE, 0, "NODO MEGA", "FEAT_MNODE", Catalog.ICON_MNODE, false)
	_variants(Catalog.FEAT_GLITCH_TREE, 5, "ARBOL GLITCH", "FEAT_GLITCH_TREE", Catalog.ICON_TREE)
	_push("feature", Catalog.FEAT_GLITCH_HOUSE, 0, "CASA GLITCH", "FEAT_GLITCH_HOUSE", Catalog.ICON_DWELL, false)
	_push("feature", Catalog.FEAT_ANOMALY, 0, "ANOMALIA", "FEAT_ANOMALY", Catalog.ICON_ROCK, false)
	_push("item", Catalog.ITEM_APPLE, 0, "MANZANA", "ITEM_APPLE", Catalog.ICON_APPLE, false)
	_push("item", Catalog.ITEM_BALL, 0, "BALON", "ITEM_BALL", Catalog.ICON_BALL, false)
	_push("item", Catalog.ITEM_WOOD, 0, "MADERA", "ITEM_WOOD", Catalog.ICON_WOOD, false)
	_push("item", Catalog.ITEM_BONE, 0, "HUESO", "ITEM_BONE", Catalog.ICON_BONE, false)
	_push("item", Catalog.ITEM_ORE, 0, "MINERAL", "ITEM_ORE", Catalog.ICON_ORE, false)
	_push("item", Catalog.ITEM_TNT, 0, "TNT", "ITEM_TNT", Catalog.ICON_TNT, false)
	_push("item", Catalog.ITEM_EGG, 0, "HUEVO", "ITEM_EGG", Catalog.ICON_EGG, false)


static func _variants(kind: int, count: int, label: String, constant: String, icon: int) -> void:
	for ore in count:
		var name := label if count == 1 else "%s %d" % [label, ore + 1]
		_push("feature", kind, ore, name, constant, icon, false)


static func _push(group: String, kind: int, ore: int, label: String, constant: String, icon: int, node: bool) -> void:
	var id := "%s:%d" % [group, kind]
	if ore > 0:
		id += ":%d" % ore
	var row := {
		"id": id,
		"group": group,
		"kind": kind,
		"ore": ore,
		"label": label,
		"constant": constant,
		"icon": icon,
		"node": node,
	}
	_rows.append(row)
	_index[id] = row


static func _bld_name(kind: int) -> String:
	match kind:
		Catalog.BLD_APPLE:
			return "BLD_APPLE"
		Catalog.BLD_TUB:
			return "BLD_TUB"
		Catalog.BLD_ROUND:
			return "BLD_ROUND"
		Catalog.BLD_DWELL:
			return "BLD_DWELL"
		Catalog.BLD_FANCY:
			return "BLD_FANCY"
		Catalog.BLD_MINE:
			return "BLD_MINE"
		Catalog.BLD_MINE2:
			return "BLD_MINE2"
		Catalog.BLD_FACTORY:
			return "BLD_FACTORY"
		Catalog.BLD_FACTORY2:
			return "BLD_FACTORY2"
		Catalog.BLD_THEATRE:
			return "BLD_THEATRE"
		Catalog.BLD_MARKET:
			return "BLD_MARKET"
		Catalog.BLD_FLOWER:
			return "BLD_FLOWER"
		Catalog.BLD_STATUE:
			return "BLD_STATUE"
		Catalog.BLD_WOOD:
			return "BLD_WOOD"
		_:
			return "BLD_%d" % kind


static func _defaults(row: Dictionary) -> Dictionary:
	var size := Vector2i(1, 1)
	var scale := 1.0
	var offset := Vector2.ZERO
	if not row.is_empty():
		var group := str(row.group)
		var kind := int(row.kind)
		var ore := int(row.ore)
		if group == "building":
			size = Catalog.footprint_for_building(kind)
			scale = Catalog.building_sprite_scale(kind)
			offset = Catalog.building_draw_off(kind)
		elif group == "feature":
			size = Catalog.footprint_for_feature(kind)
			scale = Catalog.feature_sprite_scale(kind, ore)
			offset = Catalog.feature_draw_off(kind, ore)
		elif group == "item":
			scale = Catalog.item_sprite_scale(kind)
			offset = Catalog.item_draw_off(kind)
	return {"footprint": size, "scale": scale, "offset": offset, "z": 0.0, "rot": 0.0}


static func _assign(id: String, key: String, value) -> void:
	if entry(id).is_empty():
		return
	var base: Dictionary = _defaults(entry(id))
	var same := _same(key, base[key], value)
	if not overrides.has(id):
		if same:
			return
		overrides[id] = {}
	if same:
		overrides[id].erase(key)
		if overrides[id].is_empty():
			overrides.erase(id)
		return
	overrides[id][key] = value


static func _same(key: String, a, b) -> bool:
	if key == "footprint":
		return a == b
	if key == "offset":
		return (a as Vector2).is_equal_approx(b)
	return is_equal_approx(float(a), float(b))


static func _read_value(key: String, raw):
	if raw == null:
		return null
	if key == "footprint" or key == "offset":
		if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
			return null
		if key == "footprint":
			return Vector2i(clampi(int(raw[0]), 1, 8), clampi(int(raw[1]), 1, 8))
		return Vector2(
			snappedf(clampf(float(raw[0]), -160.0, 160.0), 1.0),
			snappedf(clampf(float(raw[1]), -160.0, 160.0), 1.0)
		)
	if key != "scale" and key != "z" and key != "rot":
		return null
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return null
	if key == "scale":
		return snappedf(clampf(float(raw), 0.25, 3.0), 0.05)
	if key == "rot":
		return snappedf(clampf(float(raw), -180.0, 180.0), 1.0)
	return snappedf(clampf(float(raw), -40.0, 40.0), 1.0)


static func _document() -> Dictionary:
	var changes: Array = []
	for row in entries():
		var id := str(row.id)
		if not is_dirty(id):
			continue
		var tune := get_tune(id)
		var base := _defaults(row)
		var fields := {}
		for key in ["footprint", "scale", "offset", "z", "rot"]:
			if _same(key, base[key], tune[key]):
				continue
			fields[key] = {
				"from": _json_value(key, base[key]),
				"to": _json_value(key, tune[key]),
				"apply_in": _apply_in(row, key),
			}
		if fields.is_empty():
			continue
		changes.append({
			"id": id,
			"group": str(row.group),
			"kind": int(row.kind),
			"ore": int(row.ore),
			"constant": str(row.constant),
			"label": str(row.label),
			"draw": "node" if bool(row.node) else "sprite",
			"fields": fields,
		})
	return {
		"version": 1,
		"do_not_runtime_load": true,
		"how_to_apply": _how(),
		"units": {
			"footprint": "cells [x, y], centered on the snap cell through Catalog.footprint_offsets",
			"scale": "uniform sprite scale passed to _push_iso and _pad_nudge",
			"offset": "extra world pixels [x, y] after the current anchor. +x east, +y south",
			"z": "sprite: added to sort y, higher draws in front. node: Node2D z_index",
			"rot": "degrees, clockwise, around the anchor. 0 leaves the sprite unrotated",
		},
		"changes": changes,
	}


static func _json_value(key: String, value):
	if key == "footprint":
		var size: Vector2i = value
		return [size.x, size.y]
	if key == "offset":
		var at: Vector2 = value
		return [snappedf(at.x, 1.0), snappedf(at.y, 1.0)]
	if key == "scale":
		return snappedf(float(value), 0.05)
	return snappedf(float(value), 1.0)


static func _anchor_fn(row: Dictionary) -> String:
	if bool(row.node):
		return "Main._sync_monolith"
	if str(row.group) == "building":
		return "Main._building_draw_at"
	if str(row.group) == "item":
		return "Main._item_draw_at"
	return "Main._feature_draw_at"


static func _shares_kind(row: Dictionary) -> bool:
	var n := 0
	for other in entries():
		if str(other.group) == str(row.group) and int(other.kind) == int(row.kind):
			n += 1
	return n > 1


static func _only(row: Dictionary) -> String:
	var constant := "Catalog." + str(row.constant)
	if _shares_kind(row):
		return "Only %s when ore == %d. Do not change the other ore values of this kind." % [constant, int(row.ore)]
	return "Only %s. Do not change other kinds." % constant


static func _apply_in(row: Dictionary, key: String) -> String:
	var only := _only(row)
	var group := str(row.group)
	var fn := _anchor_fn(row)
	if key == "footprint":
		if group == "building":
			return only + " Change that match arm in Catalog.footprint_for_building. If it falls through to the default, give it its own arm. Placement already uses this function."
		if group == "feature":
			var extra := ""
			if _shares_kind(row):
				extra = " footprint_for_feature(kind) ignores ore today, so branch on ore and leave the other variants on their current size."
			return only + " Change Catalog.footprint_for_feature." + extra + " Placement already uses this function."
		return only + " Items have no footprint yet. Main._item_draw_at passes Vector2i(1, 1). Use this size there, the same way buildings use footprint_for_building."
	if key == "scale":
		if bool(row.node):
			return only + " In Main._sync_monolith set Node2D.scale to Vector2(scale, scale). It is unset today, which means (1, 1)."
		if group == "building":
			return only + " Pass this scale to _pad_nudge in Main._building_draw_at and to _push_iso for this building in _sync_actors, the carried ghost, the kit ghost, and the focus draw. BLD_TUB uses Catalog.TUB_SPRITE_SCALE. BLD_ROUND uses Catalog.ROUND_SPRITE_SCALE. Other buildings use 1.0."
		if group == "item":
			return only + " Pass this scale to _pad_nudge in Main._item_draw_at and to _push_iso for this item. Items use 1.0 today."
		return only + " Pass this scale to _pad_nudge in Main._feature_draw_at and to _push_iso for this feature, including the held-feature ghost. Features use 1.0 today."
	if key == "offset":
		if bool(row.node):
			return only + " Add this world Vector2 to the position passed into Main._sync_monolith. That anchor is the snap cell, not the footprint center."
		return only + " Add this world Vector2 at the end of %s, after footprint_center and _pad_nudge. The bench anchor already includes those, so this vector is only the extra the user dialed." % fn
	if key == "rot":
		if bool(row.node):
			return only + " Set rotation_degrees on the monolith Node2D in Main._sync_monolith. Positive degrees turn clockwise around the snap-cell anchor. 0 means leave it at 0."
		return only + " Degrees, clockwise, around the anchor after footprint_center, _pad_nudge, and the extra offset. Main._write_mesh reads the draw key rot and spins the quad around p. Set rot on this prop's draws in _sync_actors, the carried ghost, the kit ghost, and the focus draw. 0 means leave the key unset. Do not rotate other props."
	if bool(row.node):
		return only + " Set z_index on the monolith Node2D in Main._sync_monolith. 0 means leave it unset."
	return only + " Add this number to that prop's draw sy after _push_iso. Higher draws in front. Multimesh props have no z_index. Do not set one."


static func _how() -> String:
	return " ".join(PackedStringArray([
		"Apply each object in changes and nothing else.",
		"Do not load this file at runtime. Edit the scripts so the live values match to.",
		"from is the code value at save time. to is the absolute value the bench showed.",
		"Follow apply_in on each field. It names the constant and, when a kind has several sprites, the ore variant.",
		"Skip fields that are not listed.",
		"footprint cells stay centered on the snap cell through Catalog.footprint_offsets.",
		"offset is extra world pixels after the anchor the bench already uses. Do not also edit _CENTER.",
		"scale goes to both the mesh scale and _pad_nudge, or to Node2D.scale for draw node.",
		"z on a sprite is a sort-y bias. z on a node is z_index.",
		"rot is degrees clockwise around the anchor. 0 means no rotation.",
		"Do not change costs, unlocks, or unlisted props.",
	]))
