class_name LineBook
extends RefCounted

# Each key is one situation. The value is that situation's variant pool,
# not the whole localization dump.
const POOL := {
	"first_born": "3S02_THRONGLET",
	"unlock_axe": "3S02_AXETOOL",
	"unlock_hammer": "3S02_HAMMER",
	"unlock_bathtub": "3S02_BATHTUB",
	"unlock_apple_tree": "3S02_APPLETREE",
	"unlock_roundabout": "3S02_ROUNDABOUT",
	"unlock_pickaxe": "3S02_PICKAXE",
	"unlock_mine": "3S02_MINESTRUCT",
	"unlock_dwelling": "3S02_DWELLING",
	"unlock_factory": "3S02_FACTORY",
	"unlock_chainsaw": "3S02_CHAINSAW",
	"unlock_theatre": "3S02_THEATRE",
	"unlock_factory2": "3S02_FACTORY2",
	"unlock_mine2": "3S02_MINE2STRUC",
	"unlock_fancy": "3S02_DWELLING2",
	"unlock_bug": "3S02_BUGTOOL",
	"bug": "3S02_BUGTOOL",
	"unlock_grabber": "3S02_GRABBER",
	"unlock_mop": "3S02_MOPTOOL",
	"unlock_tnt": "3S02_TNTOBJECT",
	"unlock_nuke": "3S02_NUKEOBJECT",
	"nuke": "3S02_NUKEOBJECT",
	"unlock_swarm": "3S02_SUPERBUG",
	"shot_check": "3S02_THRONGLET",
}

static var tables := {}
static var ready := false


static func ensure() -> void:
	if ready:
		return
	ready = true
	var file := FileAccess.open("res://resources/dialogue/lines.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw = parsed.get("tables", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	tables = raw


static func line_for(event: String) -> String:
	ensure()
	var key := str(POOL.get(event, ""))
	if key == "":
		return ""
	var rows = tables.get(key, [])
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return ""
	return str(rows[absi(event.hash()) % rows.size()])
