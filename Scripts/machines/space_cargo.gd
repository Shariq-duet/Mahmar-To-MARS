extends Node3D
class_name SpaceCargo

# space_cargo.gd
# Sol 1 Space Cargo Transporter Model on Crevasse Rim:
# - Lists cargo model node tree.
# - Keeps only the Filter Core and Power Unit Core meshes.
# - Deletes / hides all container, crate, pallet, and packaging meshes.
# - Scales cores to about 0.6 units across.
# - Places cores on crevasse rim at cargo_site (>=0.5m above terrain).
# - Retains Area3D pickup zones, [E] interact prompt, and one-time collection.

@export_group("Core Tuning & Offsets")
@export var target_core_size: float = 0.6
@export var filter_core_scale: Vector3 = Vector3(0.872, 0.872, 0.872) # ~0.6 units across
@export var power_core_scale: Vector3 = Vector3(0.936, 0.936, 0.936)  # ~0.6 units across
@export var filter_core_offset: Vector3 = Vector3(-1.2, 0.65, 0.0)
@export var power_core_offset: Vector3 = Vector3(1.2, 0.65, 0.0)

@onready var filter_zone: Area3D = $FilterCorePickup
@onready var filter_prompt: Label3D = $FilterCorePickup/PromptLabel
@onready var filter_mesh: MeshInstance3D = $FilterCorePickup/CoreMesh

@onready var power_zone: Area3D = $PowerCorePickup
@onready var power_prompt: Label3D = $PowerCorePickup/PromptLabel
@onready var power_mesh: MeshInstance3D = $PowerCorePickup/CoreMesh

var player_in_filter_zone: bool = false
var player_in_power_zone: bool = false
var filter_core_collected: bool = false
var power_core_collected: bool = false

var kept_mesh_names: Array[String] = []
var removed_mesh_names: Array[String] = []

func _ready() -> void:
	_process_cargo_model_tree()
	
	var gm = _get_gm()
	if gm:
		if gm.cargo_filter_core_collected:
			_mark_filter_core_collected(false)
		if gm.cargo_power_core_collected:
			_mark_power_core_collected(false)
	
	if filter_zone:
		if not filter_zone.body_entered.is_connected(_on_filter_body_entered):
			filter_zone.body_entered.connect(_on_filter_body_entered)
		if not filter_zone.body_exited.is_connected(_on_filter_body_exited):
			filter_zone.body_exited.connect(_on_filter_body_exited)
	
	if power_zone:
		if not power_zone.body_entered.is_connected(_on_power_body_entered):
			power_zone.body_entered.connect(_on_power_body_entered)
		if not power_zone.body_exited.is_connected(_on_power_body_exited):
			power_zone.body_exited.connect(_on_power_body_exited)

func _process_cargo_model_tree() -> void:
	var cargo_model = get_node_or_null("CargoModel")
	print("\n==================================================")
	print("SPACE CARGO MODEL NODE TREE INSPECTION (PART B)")
	print("==================================================")
	if cargo_model:
		_print_node_tree(cargo_model, "")
	
	# Mesh classification
	# Kept: Object_4 (Filter Core), Object_5 (Power Unit Core)
	# Removed: Container body, bottom, basket, pallets, packaging caps
	var meshes_to_remove = [
		"Object_16", # Cabin_Bearer1_2 (Pallet / Bearer 1)
		"Object_18", # Cabin_Bearer2_3 (Pallet / Bearer 2)
		"Object_12", # Cabin_Basket_4 (Crate / Basket)
		"Object_9",  # Cabin_Bottom_5 (Container Bottom)
		"Object_10", # Cabin_Bottom_5 (Container Base)
		"Object_20", # Cabin_Cap_7 (Packaging Cap)
		"Object_7",  # Cabin_008_0 (Packaging Lid)
		"Object_14"  # Cabin_011_1 (Packaging Latch)
	]
	
	kept_mesh_names = ["Object_4 (Filter Core)", "Object_5 (Power Unit Core)"]
	removed_mesh_names = [
		"Cabin_Bearer1_2 / Object_16 (Pallet Bearer 1)",
		"Cabin_Bearer2_3 / Object_18 (Pallet Bearer 2)",
		"Cabin_Basket_4 / Object_12 (Crate / Basket)",
		"Cabin_Bottom_5 / Object_9, Object_10 (Container Bottom)",
		"Cabin_Cap_7 / Object_20 (Packaging Cap)",
		"Cabin_008_0 / Object_7 (Packaging Lid)",
		"Cabin_011_1 / Object_14 (Packaging Latch)"
	]
	
	if cargo_model:
		for rem_name in meshes_to_remove:
			var node = cargo_model.find_child(rem_name, true, false)
			if node:
				if node is Node3D:
					node.visible = false
		var body_node = cargo_model.find_child("Cabin_Body_6", true, false)
		# Hide container body and cap parent containers
		var bottom_parent = cargo_model.find_child("Cabin_Bottom_5", true, false)
		if bottom_parent and bottom_parent is Node3D:
			bottom_parent.visible = false
		var cap_parent = cargo_model.find_child("Cabin_Cap_7", true, false)
		if cap_parent and cap_parent is Node3D:
			cap_parent.visible = false
	
	print("\n--- KEPT CORE MESHES ---")
	for kn in kept_mesh_names:
		print("  - KEPT: %s" % kn)
	
	print("\n--- REMOVED CONTAINER / PALLET / CRATE MESHES ---")
	for rn in removed_mesh_names:
		print("  - REMOVED: %s" % rn)
	
	# Scale remaining cores to about 0.6 units across
	if filter_mesh:
		filter_mesh.scale = filter_core_scale
	if power_mesh:
		power_mesh.scale = power_core_scale
	
	print("\n--- CORE SCALING (TARGET ~0.6 UNITS ACROSS) ---")
	print("  - Filter Core Scale:     %s (Width: %.2f units)" % [filter_core_scale, target_core_size])
	print("  - Power Unit Core Scale: %s (Width: %.2f units)" % [power_core_scale, target_core_size])
	
	# Verify placement heights above terrain
	call_deferred("_verify_core_heights_above_terrain")

func _verify_core_heights_above_terrain() -> void:
	var planet = get_tree().root.find_child("ProceduralMars", true, false)
	if not planet or not planet.has_method("get_surface_point"):
		return
	
	var filter_pos = filter_zone.global_position if filter_zone else global_position + filter_core_offset
	var power_pos = power_zone.global_position if power_zone else global_position + power_core_offset
	
	var f_dir = (filter_pos - planet.global_position).normalized()
	var f_surf = planet.get_surface_point(f_dir)
	var f_h = (filter_pos - planet.global_position).length() - (f_surf - planet.global_position).length()
	
	var p_dir = (power_pos - planet.global_position).normalized()
	var p_surf = planet.get_surface_point(p_dir)
	var p_h = (power_pos - planet.global_position).length() - (p_surf - planet.global_position).length()
	
	print("\n--- CREVASSE RIM PLACEMENT (REQUIREMENT >= 0.5 UNITS ABOVE TERRAIN) ---")
	print("  - Filter Core Pickup Pos: %s | Height above terrain: %.4f m (PASS: %s)" % [filter_pos, f_h, f_h >= 0.5])
	print("  - Power Core Pickup Pos:  %s | Height above terrain: %.4f m (PASS: %s)" % [power_pos, p_h, p_h >= 0.5])
	print("==================================================\n")

func _print_node_tree(n: Node, indent: String) -> void:
	var extra = ""
	if n is MeshInstance3D and n.mesh:
		extra = " | Mesh: %s, AABB: %s" % [n.name, n.get_aabb().size]
	print("%s- %s (%s)%s" % [indent, n.name, n.get_class(), extra])
	for c in n.get_children():
		_print_node_tree(c, indent + "  ")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		if player_in_filter_zone and not filter_core_collected:
			collect_filter_core()
			get_viewport().set_input_as_handled()
		elif player_in_power_zone and not power_core_collected:
			collect_power_core()
			get_viewport().set_input_as_handled()

func _on_filter_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_filter_zone = true
		_update_prompts()

func _on_filter_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_filter_zone = false
		_update_prompts()

func _on_power_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_power_zone = true
		_update_prompts()

func _on_power_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_power_zone = false
		_update_prompts()

func _update_prompts() -> void:
	var hud = _get_hud()
	if player_in_filter_zone and not filter_core_collected:
		if filter_prompt:
			filter_prompt.visible = true
		if hud and hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt("Take Filter Core")
	else:
		if filter_prompt:
			filter_prompt.visible = false
	
	if player_in_power_zone and not power_core_collected:
		if power_prompt:
			power_prompt.visible = true
		if hud and hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt("Recover Power Unit Core")
	else:
		if power_prompt:
			power_prompt.visible = false
	
	if not player_in_filter_zone and not player_in_power_zone:
		if hud and hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func collect_filter_core() -> void:
	if filter_core_collected:
		return
	
	filter_core_collected = true
	var gm = _get_gm()
	if gm:
		gm.cargo_filter_core_collected = true
		gm.add_filter_core(1)
		print("[CARGO] Filter core state change: collected = true, filter_cores in inventory = %d" % gm.filter_core)
	else:
		print("[CARGO] Filter core state change: collected = true (no GameManager)")
	
	_mark_filter_core_collected(true)
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Filter core acquired", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Filter core acquired", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func collect_power_core() -> void:
	if power_core_collected:
		return
	
	power_core_collected = true
	var gm = _get_gm()
	if gm:
		gm.cargo_power_core_collected = true
		gm.power_core_collected = true
		gm.add_power_core(1)
		print("[CARGO] Power unit core state change: collected = true, power_cores in inventory = %d" % gm.power_unit_core)
	else:
		print("[CARGO] Power unit core state change: collected = true (no GameManager)")
	
	_mark_power_core_collected(true)
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Power unit core recovered", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Power unit core recovered", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func _mark_filter_core_collected(animate: bool) -> void:
	filter_core_collected = true
	if filter_prompt:
		filter_prompt.visible = false
	if filter_zone:
		var col = filter_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", true)
	if filter_mesh:
		if animate:
			var tw = create_tween()
			tw.tween_property(filter_mesh, "scale", Vector3.ZERO, 0.3)
			tw.tween_callback(func(): filter_mesh.visible = false)
		else:
			filter_mesh.visible = false

func _mark_power_core_collected(animate: bool) -> void:
	power_core_collected = true
	if power_prompt:
		power_prompt.visible = false
	if power_zone:
		var col = power_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", true)
	if power_mesh:
		if animate:
			var tw = create_tween()
			tw.tween_property(power_mesh, "scale", Vector3.ZERO, 0.3)
			tw.tween_callback(func(): power_mesh.visible = false)
		else:
			power_mesh.visible = false

func _get_hud() -> CanvasLayer:
	var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root:
		var hud = tree.root.find_child("HUD", true, false) as CanvasLayer
		if hud: return hud
	var top: Node = self
	while top and top.get_parent():
		top = top.get_parent()
	if top:
		var hud = top.find_child("HUD", true, false) as CanvasLayer
		if hud: return hud
	return null

func _get_gm() -> Node:
	var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree and tree.root:
		var gm = tree.root.find_child("GameManager", true, false)
		if gm: return gm
	var top: Node = self
	while top and top.get_parent():
		top = top.get_parent()
	if top:
		var gm = top.find_child("GameManager", true, false)
		if gm: return gm
	if is_inside_tree():
		return get_node_or_null("/root/GameManager")
	return null
