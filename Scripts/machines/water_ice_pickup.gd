extends Area3D
class_name WaterIcePickup

# water_ice_pickup.gd
# Collectable water ice crystal on the water ice patch.
# Press E to collect, adds to inventory, prints count after each pickup.

@export var sample_id: int = 1

@onready var prompt_label: Label3D = $PromptLabel
@onready var ice_mesh: MeshInstance3D = $IceMesh

var is_player_nearby: bool = false
var is_collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_collected:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		collect()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = false
		_update_prompt()

func _update_prompt() -> void:
	var hud = _get_hud()
	if is_player_nearby and not is_collected:
		if prompt_label:
			prompt_label.visible = true
		if hud and hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt("Take Water Ice")
	else:
		if prompt_label:
			prompt_label.visible = false
		if hud and hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func collect() -> void:
	if is_collected:
		return
	
	is_collected = true
	var gm = get_node_or_null("/root/GameManager")
	var count = 1
	if gm:
		gm.add_water_ice(1)
		count = gm.water_ice
	
	var world_node = get_tree().root.find_child("World", true, false)
	if world_node and "survival" in world_node and world_node.survival:
		world_node.survival.add_water_ice()
	
	print("[WATER ICE PICKUP] Water ice #%d collected! Count in inventory: %d" % [sample_id, count])
	
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	
	if ice_mesh:
		var tw = create_tween()
		tw.tween_property(ice_mesh, "scale", Vector3.ZERO, 0.25)
		tw.tween_callback(func(): ice_mesh.visible = false)
	
	if prompt_label:
		prompt_label.visible = false
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Water ice collected (+1)", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Water ice collected (+1)", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func _get_hud() -> CanvasLayer:
	var root_node = get_tree().root
	var hud = root_node.find_child("HUD", true, false) as CanvasLayer
	return hud
