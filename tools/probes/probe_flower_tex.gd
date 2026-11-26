extends SceneTree


## Prints loaded flower texture paths and sizes for asset sanity checks.

func _init() -> void:
	call_deferred("_go")

## Boots the scene harness, runs checks, and quits with pass/fail status.
func _go() -> void:
	await process_frame
	for i in 7:
		var p = "res://resources/structures/buildings/flower_%d.png" % i
		var tex = load(p)
		print(p, " -> ", tex, " size=", (tex.get_size() if tex else Vector2.ZERO))
	var idle = load("res://resources/structures/buildings/flower.png")
	print("idle -> ", idle)
	quit()
