extends Node2D

const MODEL := "res://resources/models/Monolith_Act1.glb"
# Same pixels-per-unit as the other props, then fitted so the stack
# stands a little taller than a house instead of several times one.
const PX_PER_UNIT := 52.0 * 0.38
const VIEW_W := 96
const VIEW_H := 112
const LOOK_Y := 1.5
const GROUND_Y := 0.0


func _ready() -> void:
	var built := _load_model()
	if built == null:
		return
	var view := SubViewport.new()
	view.size = Vector2i(VIEW_W, VIEW_H)
	view.transparent_bg = true
	view.gui_disable_input = true
	view.handle_input_locally = false
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_CLEAR_COLOR
	world_env.background_color = Color(0, 0, 0, 0)
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.72, 0.74, 0.78)
	world_env.ambient_light_energy = 0.85
	env.environment = world_env
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	view.add_child(sun)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, -0.2, 0)
	view.add_child(pivot)
	pivot.add_child(built)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(VIEW_H) / PX_PER_UNIT
	cam.rotation_degrees = Vector3(-26.565, 45.0, 0.0)
	var look := Vector3(0, LOOK_Y, 0)
	cam.position = look + cam.transform.basis.z * 8.0
	cam.current = true
	view.add_child(cam)
	var sprite := Sprite2D.new()
	sprite.texture = view.get_texture()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ground := float(VIEW_H) * 0.5 + (LOOK_Y - GROUND_Y) * PX_PER_UNIT
	sprite.offset = Vector2(-float(VIEW_W) * 0.5, -ground)
	add_child(sprite)


func _load_model() -> Node3D:
	var bytes := FileAccess.get_file_as_bytes(MODEL)
	if bytes.is_empty() or bytes.size() < 20:
		return null
	var json_len := bytes.decode_u32(12)
	var doc: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var bin_at := 20 + json_len + 8
	var bin := bytes.slice(bin_at, bytes.size())
	var views: Array = doc.bufferViews
	var faces: Array = []
	for image in doc.images:
		var view: Dictionary = views[int(image.bufferView)]
		var start := int(view.get("byteOffset", 0))
		var png := bin.slice(start, start + int(view.byteLength))
		var img := Image.new()
		if img.load_png_from_buffer(png) != OK:
			faces.append(null)
			continue
		var tex := ImageTexture.create_from_image(img)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
		mat.metallic = 0.0
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		faces.append(mat)
	var meshes: Array = []
	for spec in doc.meshes:
		var prim: Dictionary = spec.primitives[0]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _read_vec3(bin, views, doc.accessors[int(prim.attributes.POSITION)])
		arrays[Mesh.ARRAY_NORMAL] = _read_vec3(bin, views, doc.accessors[int(prim.attributes.NORMAL)])
		arrays[Mesh.ARRAY_TEX_UV] = _read_vec2(bin, views, doc.accessors[int(prim.attributes.TEXCOORD_0)])
		arrays[Mesh.ARRAY_INDEX] = _read_indices(bin, views, doc.accessors[int(prim.indices)])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat_i := int(prim.get("material", 0))
		if mat_i < faces.size() and faces[mat_i] != null:
			mesh.surface_set_material(0, faces[mat_i])
		meshes.append(mesh)
	return _build_node(doc.nodes, meshes, int(doc.scenes[0].nodes[0]))


func _build_node(nodes: Array, meshes: Array, index: int) -> Node3D:
	var spec: Dictionary = nodes[index]
	var name := str(spec.get("name", ""))
	if name.find("Glitch") >= 0 or name.find("Particle") >= 0 or name == "PhysicsCollider":
		return null
	var node := Node3D.new()
	node.name = name
	var t: Array = spec.get("translation", [0, 0, 0])
	var s: Array = spec.get("scale", [1, 1, 1])
	node.position = Vector3(float(t[0]), float(t[1]), float(t[2]))
	node.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))
	if spec.has("rotation"):
		var r: Array = spec.rotation
		node.quaternion = Quaternion(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	if spec.has("mesh"):
		var body := MeshInstance3D.new()
		body.mesh = meshes[int(spec.mesh)]
		node.add_child(body)
	for child in spec.get("children", []):
		var branch := _build_node(nodes, meshes, int(child))
		if branch != null:
			node.add_child(branch)
	return node


func _read_vec3(bin: PackedByteArray, views: Array, acc: Dictionary) -> PackedVector3Array:
	var view: Dictionary = views[int(acc.bufferView)]
	var stride := int(view.get("byteStride", 12))
	var start := int(view.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var out := PackedVector3Array()
	out.resize(int(acc.count))
	for i in int(acc.count):
		var at := start + i * stride
		out[i] = Vector3(bin.decode_float(at), bin.decode_float(at + 4), bin.decode_float(at + 8))
	return out


func _read_vec2(bin: PackedByteArray, views: Array, acc: Dictionary) -> PackedVector2Array:
	var view: Dictionary = views[int(acc.bufferView)]
	var stride := int(view.get("byteStride", 8))
	var start := int(view.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var out := PackedVector2Array()
	out.resize(int(acc.count))
	for i in int(acc.count):
		var at := start + i * stride
		out[i] = Vector2(bin.decode_float(at), 1.0 - bin.decode_float(at + 4))
	return out


func _read_indices(bin: PackedByteArray, views: Array, acc: Dictionary) -> PackedInt32Array:
	var view: Dictionary = views[int(acc.bufferView)]
	var start := int(view.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var out := PackedInt32Array()
	out.resize(int(acc.count))
	for i in int(acc.count):
		out[i] = bin.decode_u16(start + i * 2)
	return out
