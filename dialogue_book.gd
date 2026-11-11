class_name DialogueBook
extends RefCounted

const Catalog := preload("res://catalog.gd")
const TREE_DIR := "res://resources/dialogue/trees"
const INDEX_PATH := "res://resources/dialogue/trees/_index.json"

static var trees := {}
static var index := {}
static var ready := false
static var ambient_ids: Array = []


static func ensure() -> void:
	if ready:
		return
	ready = true
	trees = {}
	index = {}
	ambient_ids = []
	if FileAccess.file_exists(INDEX_PATH):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if typeof(raw) == TYPE_DICTIONARY:
			index = raw
	var dir := DirAccess.open(TREE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json") and name != "_index.json":
			var path := TREE_DIR + "/" + name
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("id", "")) != "":
				var tid := str(parsed.id)
				trees[tid] = parsed
				if str(parsed.get("status", "draft")) != "skipped":
					ambient_ids.append(tid)
		name = dir.get_next()
	dir.list_dir_end()


static func tree_id_for(event: String) -> String:
	ensure()
	var gaze_table: Dictionary = {}
	if Catalog.GAZE.has(event):
		gaze_table = Catalog.GAZE[event]
	var mapped := str(gaze_table.get("tree", ""))
	if mapped != "" and trees.has(mapped):
		return mapped
	if trees.has(event):
		return event
	return ""


static func has_tree(event: String) -> bool:
	return tree_id_for(event) != ""


static func open_session(event: String) -> Dictionary:
	ensure()
	return open_tree(tree_id_for(event))


static func open_tree(tid: String) -> Dictionary:
	ensure()
	if tid == "" or not trees.has(tid):
		return {}
	var tree: Dictionary = trees[tid]
	if str(tree.get("status", "")) == "skipped":
		return {}
	var start := str(tree.get("start", "n0"))
	var node: Dictionary = _node(tree, start)
	var log: Array = []
	_append_lines(log, node)
	return {
		"tree": tid,
		"node": start,
		"log": log,
		"seq": 1,
	}


static func choices_of(session: Dictionary) -> Array:
	ensure()
	var tree: Dictionary = trees.get(str(session.get("tree", "")), {})
	var node: Dictionary = _node(tree, str(session.get("node", "")))
	var raw = node.get("choices", [])
	return raw if raw is Array else []


static func log_text(session: Dictionary) -> String:
	var rows: Array = session.get("log", [])
	if typeof(rows) != TYPE_ARRAY:
		return ""
	var out := ""
	for i in rows.size():
		if i > 0:
			out += "\n"
		out += str(rows[i])
	return out


static func advance(session: Dictionary, index: int) -> Dictionary:
	ensure()
	var tree: Dictionary = trees.get(str(session.get("tree", "")), {})
	if tree.is_empty():
		return {"done": true, "session": session, "edge": {}}
	var choices := choices_of(session)
	if index < 0 or index >= choices.size():
		return {"done": false, "session": session, "edge": {}}
	var edge: Dictionary = choices[index] if choices[index] is Dictionary else {}
	var label := str(edge.get("label", ""))
	var log: Array = session.get("log", []).duplicate()
	log.append(">> input \"%s\"" % label)
	var next_id := str(edge.get("next", ""))
	if next_id == "" or next_id == "null" or next_id == "end":
		session["log"] = log
		session["seq"] = int(session.get("seq", 1)) + 1
		session["node"] = ""
		return {"done": true, "session": session, "edge": edge}
	var next_node: Dictionary = _node(tree, next_id)
	_append_lines(log, next_node)
	session["log"] = log
	session["node"] = next_id
	session["seq"] = int(session.get("seq", 1)) + 1
	var next_choices = next_node.get("choices", [])
	if typeof(next_choices) != TYPE_ARRAY or next_choices.is_empty():
		return {"done": true, "session": session, "edge": edge}
	return {"done": false, "session": session, "edge": edge}


static func ambient_for(used: Dictionary) -> String:
	ensure()
	for tid in ambient_ids:
		if used.has(tid):
			continue
		var tree: Dictionary = trees.get(tid, {})
		if str(tree.get("status", "")) == "skipped":
			continue
		return tid
	return ""


static func _node(tree: Dictionary, node_id: String) -> Dictionary:
	var nodes = tree.get("nodes", {})
	if typeof(nodes) != TYPE_DICTIONARY:
		return {}
	var node = nodes.get(node_id, {})
	return node if node is Dictionary else {}


static func _append_lines(log: Array, node: Dictionary) -> void:
	var lines = node.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		return
	for row in lines:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var text := str(row.get("text", "")).strip_edges()
		if text == "":
			continue
		var who := str(row.get("who", "them"))
		if who == "player":
			log.append(">> input \"%s\"" % text)
		else:
			log.append("> %s" % text)
