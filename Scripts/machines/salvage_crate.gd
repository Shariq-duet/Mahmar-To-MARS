extends Area3D
class_name SalvageCrate

# salvage_crate.gd
# Salvage crate containing a filter_core at crash_base.

signal core_collected

@onready var prompt_label: Label3D = $PromptLabel
@onready var crate_mesh: MeshInstance3D = $CrateMesh
@onready var edge_mesh: MeshInstance3D = $CrateMesh/EdgeMesh

var is_player_in_range: bool = false
var is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Check session persistence
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.crate_collected:
		is_collected = true
		_apply_collected_visuals()
	else:
		_apply_active_visuals()

func _apply_active_visuals() -> void:
	if prompt_label:
		prompt_label.text = "[E] Take Filter Core"
		prompt_label.visible = false
	if edge_mesh and edge_mesh.material_override is StandardMaterial3D:
		var mat = edge_mesh.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("#3fd0f0")
		mat.emission_energy_multiplier = 2.5

func _apply_collected_visuals() -> void:
	if prompt_label:
		prompt_label.text = "(Empty)"
		prompt_label.visible = false
	if edge_mesh and edge_mesh.material_override is StandardMaterial3D:
		var mat = edge_mesh.material_override as StandardMaterial3D
		mat.emission_enabled = false
		mat.albedo_color = Color(0.2, 0.25, 0.25, 1.0)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_range = true
		if not is_collected:
			if prompt_label:
				prompt_label.visible = true
			var hud = _get_hud()
			if hud and hud.has_method("set_interaction_prompt"):
				hud.set_interaction_prompt("[E] Take Filter Core")

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_in_range = false
		if prompt_label:
			prompt_label.visible = false
		var hud = _get_hud()
		if hud and hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_in_range and not is_collected and event.is_action_pressed("interact"):
		collect_core()
		get_viewport().set_input_as_handled()

func collect_core() -> void:
	if is_collected:
		return
	is_collected = true
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.crate_collected = true
		gm.add_filter_core(1)
	
	_apply_collected_visuals()
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()
		if hud.has_method("show_message"):
			hud.show_message("Filter core acquired", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Filter core acquired", false)
	
	print("[SALVAGE] Filter core acquired! Current filter_core count = %d" % (gm.filter_core if gm else 1))
	core_collected.emit()

func _get_hud() -> CanvasLayer:
	var root_node = get_tree().root
	var hud = root_node.find_child("HUD", true, false) as CanvasLayer
	return hud
