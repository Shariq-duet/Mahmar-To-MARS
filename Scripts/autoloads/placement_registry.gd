@tool
extends Node

# placement_registry.gd
# Autoload named PlacementRegistry.
# Manages world positions, directions, and spawned scenes using normalized planetary coordinates.
# Saves/loads from res://placements.json.

signal entry_added(name: String, entry: Dictionary)
signal entry_removed(name: String)

const SAVE_PATH = "res://placements.json"

@export var debug_placement: bool = true
@export var planet_path: NodePath = NodePath("/root/World/ProceduralMars")

# Dictionary of entries: name -> Dictionary
var entries: Dictionary = {}
var spawned_instances: Dictionary = {}
var next_marker_index: int = 1

func _ready() -> void:
	load_placements()

func _get_planet() -> Node:
	var p = get_node_or_null(planet_path)
	if p:
		return p
	var tree = get_tree()
	if tree and tree.root:
		p = tree.root.find_child("ProceduralMars", true, false)
		if p:
			return p
	return null

func _resolve_alias(entry_name: String) -> String:
	if entries.has(entry_name):
		return entry_name
	if entry_name == "pod" and entries.has("home"):
		return "home"
	if entry_name == "home" and entries.has("pod"):
		return "pod"
	return entry_name

func get_position(entry_name: String) -> Variant:
	if entries.is_empty():
		load_placements()
	var resolved = _resolve_alias(entry_name)
	if not entries.has(resolved):
		push_warning("PlacementRegistry: Entry '%s' not found!" % entry_name)
		return null
	
	var data = entries[resolved]
	var dir: Vector3 = data.get("direction", Vector3.UP).normalized()
	var height_offset: float = float(data.get("height_offset", 0.0))
	
	var planet = _get_planet()
	var center = planet.global_position if planet else Vector3.ZERO
	
	var surf_pt = Vector3.ZERO
	if planet and planet.has_method("get_surface_point"):
		surf_pt = planet.get_surface_point(dir)
	else:
		surf_pt = center + dir * 500.0
	
	var normal = (surf_pt - center).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	
	return surf_pt + normal * height_offset

func get_entry(entry_name: String) -> Dictionary:
	if entries.is_empty():
		load_placements()
	var resolved = _resolve_alias(entry_name)
	return entries.get(resolved, {})

func set_entry(entry_name: String, data: Dictionary) -> void:
	entries[entry_name] = data
	emit_signal("entry_added", entry_name, data)
	_auto_save()

func remove_entry(entry_name: String) -> void:
	if entries.has(entry_name):
		entries.erase(entry_name)
		emit_signal("entry_removed", entry_name)
		_auto_save()

func save_player_placement(entry_name: String, pos: Vector3, scene_path: String = "", color: Color = Color("#3fd0f0")) -> Dictionary:
	var planet = _get_planet()
	var center = planet.global_position if planet else Vector3.ZERO
	var dir = (pos - center).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector3.UP
	
	var entry_data = {
		"name": entry_name,
		"direction": dir,
		"height_offset": 0.0,
		"yaw": 0.0,
		"debug_color": color,
		"scene_path": scene_path
	}
	
	set_entry(entry_name, entry_data)
	print("[PLACEMENT REGISTRY] Saved player location '%s' at direction %s (pos: %s) to %s" % [entry_name, dir, pos, SAVE_PATH])
	
	# Also spawn visual marker sphere with 3D label
	_create_debug_sphere(entry_name, pos, color)
	
	# If world is active, add to tracked POIs so compass and signals list pick it up!
	var tree = get_tree()
	if tree and tree.root:
		var world = tree.root.find_child("World", true, false)
		if world and world.has_method("register_runtime_poi"):
			world.register_runtime_poi(entry_name, pos, color)
	
	return entry_data

func spawn(entry_name: String, parent: Node = null) -> Node3D:
	var data = get_entry(entry_name)
	if data.is_empty():
		push_warning("PlacementRegistry: Cannot spawn missing entry '%s'!" % entry_name)
		return null
	
	var pos = get_position(entry_name)
	if pos == null:
		return null
	
	var scene_to_instantiate: PackedScene = null
	if data.has("scene") and data["scene"] is PackedScene:
		scene_to_instantiate = data["scene"]
	elif data.has("scene_path") and ResourceLoader.exists(str(data["scene_path"])):
		scene_to_instantiate = load(str(data["scene_path"]))
	
	if not scene_to_instantiate:
		push_warning("PlacementRegistry: No valid scene for entry '%s'!" % entry_name)
		return null
	
	var inst = scene_to_instantiate.instantiate() as Node3D
	if not inst:
		return null
	
	var planet = _get_planet()
	var center = planet.global_position if planet else Vector3.ZERO
	var normal = (pos - center).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	
	var fwd = Vector3.FORWARD
	fwd = (fwd - normal * fwd.dot(normal)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector3.RIGHT
		fwd = (fwd - normal * fwd.dot(normal)).normalized()
	var right = fwd.cross(normal).normalized()
	
	inst.global_position = pos
	inst.global_transform.basis = Basis(right, normal, -fwd).orthonormalized()
	
	var yaw_deg = float(data.get("yaw", 0.0))
	if abs(yaw_deg) > 0.001:
		inst.rotate_object_local(Vector3.UP, deg_to_rad(yaw_deg))
	
	if parent:
		parent.add_child(inst)
	else:
		var root = get_tree().root
		root.add_child(inst)
	
	spawned_instances[entry_name] = inst
	return inst

func _unhandled_input(event: InputEvent) -> void:
	if not debug_placement:
		return
	
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.physical_keycode == KEY_P):
		var tree = get_tree()
		if tree and tree.root:
			var hud = tree.root.find_child("HUD", true, false)
			var player = tree.root.find_child("Player", true, false)
			if hud and hud.has_method("open_placement_dialog") and player:
				hud.open_placement_dialog(player.global_position)
				var vp = get_viewport()
				if vp:
					vp.set_input_as_handled()
				return
		_handle_debug_placement_raycast()

func _handle_debug_placement_raycast() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var camera = viewport.get_camera_3d()
	if not camera:
		return
	
	var ray_start = camera.global_position
	var ray_dir = -camera.global_transform.basis.z
	var ray_end = ray_start + ray_dir * 1000.0
	
	var space = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit = space.intersect_ray(query)
	
	if not hit.is_empty():
		var hit_pos = hit["position"]
		var planet = _get_planet()
		var center = planet.global_position if planet else Vector3.ZERO
		var dir = (hit_pos - center).normalized()
		
		# Generate unique marker_N name (never reuse a name)
		var marker_name = ""
		while true:
			marker_name = "marker_%d" % next_marker_index
			next_marker_index += 1
			if not entries.has(marker_name):
				break
		
		var entry_data = {
			"name": marker_name,
			"direction": dir,
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color.CYAN
		}
		
		set_entry(marker_name, entry_data)
		print("[PLACEMENT REGISTRY] Added marker '%s' at direction: %s (Hit Position: %s)" % [marker_name, dir, hit_pos])
		
		# Show small colored sphere labeled with the name
		_create_debug_sphere(marker_name, hit_pos, Color.CYAN)

func _create_debug_sphere(marker_name: String, pos: Vector3, color: Color) -> void:
	var sphere = MeshInstance3D.new()
	sphere.name = "DebugMarker_" + marker_name
	var sm = SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	sm.material = mat
	sphere.mesh = sm
	
	var lbl = Label3D.new()
	lbl.text = marker_name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 0.6, 0)
	lbl.font_size = 24
	sphere.add_child(lbl)
	
	var tree = get_tree()
	if tree and tree.root:
		tree.root.add_child(sphere)
		sphere.global_position = pos

func _auto_save() -> void:
	# In editor or interactive debug mode, save to JSON
	save_placements()

func save_placements() -> void:
	var dict_to_save: Dictionary = {}
	for k in entries.keys():
		var e = entries[k]
		var dir: Vector3 = e.get("direction", Vector3.UP)
		var col = e.get("debug_color", Color.CYAN)
		var col_str = col.to_html(true) if col is Color else str(col)
		dict_to_save[k] = {
			"name": k,
			"direction": [dir.x, dir.y, dir.z],
			"height_offset": float(e.get("height_offset", 0.0)),
			"yaw": float(e.get("yaw", 0.0)),
			"debug_color": col_str,
			"scene_path": str(e.get("scene_path", ""))
		}
	
	var json_str = JSON.stringify(dict_to_save, "\t")
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
		print("[PLACEMENT REGISTRY] Saved %d entries to %s" % [entries.size(), SAVE_PATH])

func load_placements() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		# Default startup entry: "pod"
		_init_default_pod_entry()
		save_placements()
		return
	
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		_init_default_pod_entry()
		return
	
	var json_str = f.get_as_text()
	f.close()
	
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		entries.clear()
		for k in parsed.keys():
			var item = parsed[k]
			var d_arr = item.get("direction", [0.0, 1.0, 0.0])
			var dir = Vector3(d_arr[0], d_arr[1], d_arr[2]).normalized()
			var col = Color.from_string(item.get("debug_color", "#33ccff"), Color.CYAN)
			entries[k] = {
				"name": k,
				"direction": dir,
				"height_offset": float(item.get("height_offset", 0.0)),
				"yaw": float(item.get("yaw", 0.0)),
				"debug_color": col,
				"scene_path": str(item.get("scene_path", ""))
			}
			# Update next marker index if matching marker_N
			if k.begins_with("marker_"):
				var idx = k.substr(7).to_int()
				if idx >= next_marker_index:
					next_marker_index = idx + 1
		print("[PLACEMENT REGISTRY] Loaded %d entries from %s" % [entries.size(), SAVE_PATH])
	
	if not entries.has("pod") or not entries.has("home"):
		_init_default_pod_entry()
		save_placements()

func _init_default_pod_entry() -> void:
	var pod_dir = Vector3(-0.061628, 0.996195, -0.061628).normalized()
	if not entries.has("home"):
		entries["home"] = {
			"name": "home",
			"direction": pod_dir,
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color("#3fd0f0"),
			"scene_path": "res://Scenes/machines/crashed_pod.tscn"
		}
	if not entries.has("pod"):
		entries["pod"] = {
			"name": "pod",
			"direction": pod_dir,
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color("#33ccff"),
			"scene_path": "res://Scenes/machines/crashed_pod.tscn"
		}
	if not entries.has("mav_rocket"):
		entries["mav_rocket"] = {
			"name": "mav_rocket",
			"direction": Vector3(0.0, 1.0, 0.0),
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color("#f0a830"),
			"scene_path": "res://Scenes/machines/return_vehicle.tscn"
		}
	if not entries.has("crash_base"):
		entries["crash_base"] = {
			"name": "crash_base",
			"direction": Vector3(-0.090302, 0.993322, 0.070235),
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color("#e0a030"),
			"scene_path": "res://Scenes/machines/crash_base.tscn"
		}
	if not entries.has("noctis_chasm"):
		entries["noctis_chasm"] = {
			"name": "noctis_chasm",
			"direction": Vector3(0.240905, 0.953582, 0.180679),
			"height_offset": 0.0,
			"yaw": 0.0,
			"debug_color": Color("#b040d0"),
			"scene_path": ""
		}
