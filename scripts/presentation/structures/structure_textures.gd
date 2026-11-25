extends RefCounted
class_name StructureTextures

## Number of frames in the round building's cyclic sprite animation.
const ROUND_ANIM_N := 8
## Number of frames in the flower building's cyclic sprite animation.
const FLOWER_ANIM_N := 7

## Per-kind cache of static building sprites for the default idle look.
var _idle_structure_tex := {}
## Per-kind cache of sprites shown while a building is actively working.
var _active_structure_tex := {}
## Per-kind cache of sprites for buildings covered in goo.
var _goo_structure_tex := {}
## Per-kind-and-frame cache for animated building sprite sequences.
var _structure_anim_tex := {}


## Vertical lift so a structure sprite sits on its footprint center.
func structure_sprite_lift(tex: Texture2D, sprite_scale: float) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	return Vector2(0.0, -float(tex.get_height()) * 0.5 * sprite_scale)


## Resource path for idle building art by [param kind].
func idle_structure_sprite_path(kind: int) -> String:
	match kind:
		Catalog.BLD_DWELL:
			return "res://resources/structures/buildings/dwell.png"
		Catalog.BLD_FANCY:
			return "res://resources/structures/buildings/fancy.png"
		Catalog.BLD_THEATRE:
			return "res://resources/structures/buildings/theatre.png"
		Catalog.BLD_MINE:
			return "res://resources/structures/buildings/mine.png"
		Catalog.BLD_MINE2:
			return "res://resources/structures/buildings/mine2.png"
		Catalog.BLD_FACTORY:
			return "res://resources/structures/buildings/factory.png"
		Catalog.BLD_FACTORY2:
			return "res://resources/structures/buildings/factory2.png"
		Catalog.BLD_APPLE:
			return "res://resources/structures/buildings/apple.png"
		Catalog.BLD_TUB:
			return "res://resources/structures/buildings/tub.png"
		Catalog.BLD_ROUND:
			return "res://resources/structures/buildings/round.png"
		Catalog.BLD_FLOWER:
			return "res://resources/structures/buildings/flower.png"
		Catalog.BLD_MARKET:
			return "res://resources/structures/buildings/market.png"
		Catalog.BLD_STATUE:
			return "res://resources/structures/buildings/statue.png"
		Catalog.BLD_WOOD:
			return "res://resources/structures/buildings/wood.png"
	return ""


## Resource path for active/working building art by [param kind].
func active_structure_sprite_path(kind: int) -> String:
	match kind:
		Catalog.BLD_DWELL:
			return "res://resources/structures/buildings/dwell_active.png"
		Catalog.BLD_FANCY:
			return "res://resources/structures/buildings/fancy_active.png"
		Catalog.BLD_THEATRE:
			return "res://resources/structures/buildings/theatre_active.png"
		Catalog.BLD_MINE:
			return "res://resources/structures/buildings/mine_active.png"
		Catalog.BLD_MINE2:
			return "res://resources/structures/buildings/mine2_active.png"
		Catalog.BLD_FACTORY:
			return "res://resources/structures/buildings/factory_active.png"
		Catalog.BLD_FACTORY2:
			return "res://resources/structures/buildings/factory2_active.png"
	return ""


## Resource path for goo-covered building art by [param kind].
func goo_structure_sprite_path(kind: int) -> String:
	match kind:
		Catalog.BLD_DWELL:
			return "res://resources/structures/buildings/dwell_goo.png"
		Catalog.BLD_FANCY:
			return "res://resources/structures/buildings/fancy_goo.png"
		Catalog.BLD_THEATRE:
			return "res://resources/structures/buildings/theatre_goo.png"
		Catalog.BLD_MINE:
			return "res://resources/structures/buildings/mine_goo.png"
		Catalog.BLD_MINE2:
			return "res://resources/structures/buildings/mine2_goo.png"
		Catalog.BLD_FACTORY:
			return "res://resources/structures/buildings/factory_goo.png"
		Catalog.BLD_FACTORY2:
			return "res://resources/structures/buildings/factory2_goo.png"
	return ""


## Loads [param path] into [param cache] keyed by [param kind].
func load_structure_tex(cache: Dictionary, kind: int, path: String) -> Texture2D:
	if cache.has(kind):
		return cache[kind]
	if path == "":
		return null
	var tex: Texture2D = load(path)
	cache[kind] = tex
	return tex


## Returns the default static sprite for a building kind, loading and memoizing on first use.
func idle_structure_texture(kind: int) -> Texture2D:
	return load_structure_tex(_idle_structure_tex, kind, idle_structure_sprite_path(kind))


## Returns the working-state sprite for a building kind, loading and memoizing on first use.
func active_structure_texture(kind: int) -> Texture2D:
	return load_structure_tex(_active_structure_tex, kind, active_structure_sprite_path(kind))


## Returns the goo-covered sprite for a building kind, loading and memoizing on first use.
func goo_structure_texture(kind: int) -> Texture2D:
	return load_structure_tex(_goo_structure_tex, kind, goo_structure_sprite_path(kind))


## Path for animated building frame [param idx] of [param kind].
func structure_anim_path(kind: int, idx: int) -> String:
	match kind:
		Catalog.BLD_FLOWER:
			return "res://resources/structures/buildings/flower_%d.png" % idx
		Catalog.BLD_ROUND:
			return "res://resources/structures/buildings/round_%d.png" % idx
	return ""


## Returns one cyclic animation frame for round or flower buildings, keyed in the anim cache.
func structure_anim_texture(kind: int, idx: int) -> Texture2D:
	var key := "%d:%d" % [kind, idx]
	if _structure_anim_tex.has(key):
		return _structure_anim_tex[key]
	var path := structure_anim_path(kind, idx)
	if path == "":
		return null
	var tex: Texture2D = load(path)
	_structure_anim_tex[key] = tex
	return tex

