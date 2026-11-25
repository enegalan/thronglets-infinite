extends Node2D
class_name DashArea

## Iso-space vertices of the tool-radius preview loop to stroke.
var pts: PackedVector2Array = PackedVector2Array()
## Line color for the preview outline (valid vs empty targets).
var color: Color = Color.WHITE
## When true, stroke segments with dashes; otherwise draw a solid loop.
var dashed: bool = true
## Current camera zoom used to keep dash length and width stable on screen.
var zoom_scale: float = 1.0


## Updates polygon, color, dash mode, and zoom then redraws.
func set_area(p: PackedVector2Array, c: Color, d: bool = true, z: float = 1.0) -> void:
	pts = p
	color = c
	dashed = d
	# Keep dashes in a stable world-space band; extreme zoom used to make the
	# custom dash stepper run unbounded when a point went non-finite.
	zoom_scale = clampf(z, 0.25, 8.0)
	queue_redraw()


## Renders the polyline with finite-point filtering and optional dashes.
func _draw() -> void:
	if pts.size() < 2:
		return
	var clean := PackedVector2Array()
	clean.resize(pts.size())
	var n := 0
	for p in pts:
		if is_finite(p.x) and is_finite(p.y):
			clean[n] = p
			n += 1
	clean.resize(n)
	if clean.size() < 2:
		return
	var w: float = maxf(1.0, 2.0 / zoom_scale)
	if not dashed:
		draw_polyline(clean, color, w, true)
		return
	# Engine dashed stroke (finite-only). Avoids a custom while-loop that can
	# hang forever if total length becomes INF/NaN (silent hard exit on macOS).
	var dash_len: float = clampf(10.0 / zoom_scale, 2.0, 48.0)
	for i in range(clean.size() - 1):
		var a: Vector2 = clean[i]
		var b: Vector2 = clean[i + 1]
		if a.distance_squared_to(b) < 0.0001:
			continue
		draw_dashed_line(a, b, color, w, dash_len, false, true)