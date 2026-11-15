extends Node3D
class_name RoverSite

# rover_site.gd
# Abandoned Martian rover half-sunk into the regolith with tire tracks,
# scattered rock debris, and power_unit_core pickup on the rover deck.

@onready var power_zone: Area3D = get_node_or_null("PowerCorePickup")
@onready var power_prompt: Label3D = get_node_or_null("PowerCorePickup/PromptLabel")
@onready var power_mesh: MeshInstance3D = get_node_or_null("PowerCorePickup/CoreMesh")

var player_in_power_zone: bool = false
var power_core_collected: bool = false

func _ready() -> void:
	_spawn_small_rocks()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.power_core_collected:
		_mark_power_core_collected(false)
	
	if power_zone:
		power_zone.body_entered.connect(_on_power_body_entered)
		power_zone.body_exited.connect(_on_power_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if player_in_power_zone and not power_core_collected:
			collect_power_core()
			get_viewport().set_input_as_handled()

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
	if player_in_power_zone and not power_core_collected:
		if power_prompt:
			power_prompt.visible = true
		if hud and hud.has_method("show_interaction_prompt"):
			hud.show_interaction_prompt("Recover Power Unit Core")
	else:
		if power_prompt:
			power_prompt.visible = false
		if hud and hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

func collect_power_core() -> void:
	if power_core_collected:
		return
	
	power_core_collected = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.power_core_collected = true
		gm.add_power_core(1)
		print("[ROVER] Power unit core recovered: inventory = %d" % gm.power_unit_core)
	else:
		print("[ROVER] Power unit core recovered (no GameManager)")
	
	_mark_power_core_collected(true)
	
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Power unit core recovered", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Power unit core recovered", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()

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
	var root_node = get_tree().root
	var hud = root_node.find_child("HUD", true, false) as CanvasLayer
	return hud

func _spawn_small_rocks() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 4242
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.30, 0.16)
	mat.roughness = 0.95
	
	# Scatter 20 small rocks within 2.5m to 7.0m of the rover
	var rocks_root = Node3D.new()
	rocks_root.name = "ScatteredRocks"
	add_child(rocks_root)
	
	for i in range(20):
		var mi = MeshInstance3D.new()
		var sm = BoxMesh.new()
		var s_size = rng.randf_range(0.18, 0.42)
		sm.size = Vector3(s_size, s_size * 0.7, s_size * 1.1)
		mi.mesh = sm
		mi.material_override = mat
		
		var r_angle = rng.randf() * TAU
		var r_dist = rng.randf_range(2.6, 6.8)
		mi.position = Vector3(cos(r_angle) * r_dist, 0.05, sin(r_angle) * r_dist)
		mi.rotation = Vector3(rng.randf() * 0.8, rng.randf() * TAU, rng.randf() * 0.8)
		rocks_root.add_child(mi)
