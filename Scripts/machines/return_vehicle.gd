extends Area3D
class_name ReturnVehicle

# return_vehicle.gd
# Sol 1 Mars Ascent Vehicle (MAV):
# - Requires all three habitat systems (Oxygen Scrubber, Power Unit, Water System) repaired first.
# - Prints missing requirements if the player attempts repair early.
# - Repair uses hold-E for 3.0 seconds with circular progress ring.
# - On repair completion, launches ending sequence:
#   * Letterbox bars slide in, HUD hidden.
#   * Rocket ignites with exhaust particles, low rumble, and camera shake for 3s.
#   * Lifts off over 10s into space while camera follows and pulls back to show planet & starry sky.
#   * Fades to black, displays "Mission complete", sol count, and restart button.
#   * Uses the player's existing camera and cutscene system.

signal launch_success

@export_group("MAV Tuning")
@export var repair_hold_duration: float = 3.0
@export var ignition_duration: float = 3.0
@export var liftoff_duration: float = 10.0
@export var liftoff_altitude: float = 450.0

@onready var rocket_root: Node3D = $Rocket if has_node("Rocket") else $RocketMesh
@onready var prompt_label: Label3D = $PromptLabel
@onready var thruster_particles: GPUParticles3D = $ThrusterParticles

var is_player_nearby: bool = false
var is_holding_repair: bool = false
var repair_hold_timer: float = 0.0
var is_repaired: bool = false
var is_launched: bool = false

var base_rocket_local_pos: Vector3 = Vector3.ZERO
var rumble_player: AudioStreamPlayer3D = null

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	if rocket_root:
		base_rocket_local_pos = rocket_root.position
	
	_setup_rumble_audio()
	_update_prompt()

func _setup_rumble_audio() -> void:
	rumble_player = AudioStreamPlayer3D.new()
	rumble_player.name = "RumbleAudio"
	rumble_player.unit_size = 35.0
	rumble_player.max_distance = 250.0
	
	# Low rumble generator placeholder
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	rumble_player.stream = gen
	add_child(rumble_player)

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

func get_missing_repairs() -> Array[String]:
	var gm = _get_gm()
	var missing: Array[String] = []
	if not gm or not gm.scrubber_repaired:
		missing.append("Oxygen Scrubber")
	if not gm or not gm.power_unit_repaired:
		missing.append("Power Unit")
	if not gm or not gm.water_repaired:
		missing.append("Water System")
	return missing

func are_all_prerequisites_met() -> bool:
	return get_missing_repairs().is_empty()

func _update_prompt() -> void:
	if not prompt_label:
		return
	if is_launched:
		prompt_label.text = "🚀 MAV LAUNCH IN PROGRESS"
		return
	if is_repaired:
		prompt_label.text = "🚀 MAV Rocket Repaired\nReady for Liftoff"
		return
		
	var missing = get_missing_repairs()
	if missing.size() > 0:
		prompt_label.text = "🚀 Mars Ascent Vehicle (Offline)\nRequires: %s" % [", ".join(missing)]
	else:
		prompt_label.text = "🚀 Mars Ascent Vehicle (All Systems Online)\nHold [E] to Prepare & Launch MAV Rocket"

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_launched or is_repaired:
		return
	
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		_try_start_repair()

func _try_start_repair() -> void:
	var missing = get_missing_repairs()
	var hud = _get_hud()
	
	if missing.size() > 0:
		var missing_str = ", ".join(missing)
		print("[MAV ROCKET] Repair attempt blocked. Missing requirements: [%s]" % missing_str)
		if hud:
			if hud.has_method("show_message"):
				hud.show_message("Cannot repair MAV: Missing [%s]" % missing_str, 3.5)
			elif hud.has_method("show_alert"):
				hud.show_alert("Cannot repair MAV: Missing [%s]" % missing_str, true)
		return
	
	# All 3 prerequisites met: begin holding E for 3 seconds
	is_holding_repair = true
	repair_hold_timer = 0.0
	if hud and hud.has_method("show_progress_ring"):
		hud.show_progress_ring(0.0)

func _process(delta: float) -> void:
	if is_holding_repair:
		_process_repair_hold(delta)

func _process_repair_hold(delta: float) -> void:
	advance_repair_hold(delta, false)

func advance_repair_hold(delta: float, force_key_held: bool = false) -> void:
	var hud = _get_hud()
	var e_pressed = force_key_held or Input.is_action_pressed("interact") or Input.is_physical_key_pressed(KEY_E)
	
	if not is_player_nearby or not e_pressed:
		# Cancelled early with no cost
		is_holding_repair = false
		repair_hold_timer = 0.0
		if hud and hud.has_method("hide_progress_ring"):
			hud.hide_progress_ring()
		return
	
	repair_hold_timer += delta
	var prog = clampf(repair_hold_timer / repair_hold_duration, 0.0, 1.0)
	if hud and hud.has_method("update_progress_ring"):
		hud.update_progress_ring(prog)
	
	if repair_hold_timer >= repair_hold_duration:
		is_holding_repair = false
		repair_hold_timer = 0.0
		if hud and hud.has_method("hide_progress_ring"):
			hud.hide_progress_ring()
		_complete_mav_repair()

func _complete_mav_repair() -> void:
	if is_repaired:
		return
	is_repaired = true
	print("\n==================================================")
	print("MAV ROCKET REPAIR COMPLETE! ALL SYSTEMS NOMINAL")
	print("==================================================")
	
	_update_prompt()
	var hud = _get_hud()
	if hud and hud.has_method("show_message"):
		hud.show_message("MAV Rocket repair complete! Initiating Expedition Liftoff...", 3.0)
	
	# Start ending cutscene
	start_ending_liftoff()

func start_ending_liftoff() -> void:
	if is_launched:
		return
	is_launched = true
	
	var tree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if not tree or not tree.root:
		return
	var player = tree.root.find_child("Player", true, false) as PlanetWalker
	var world_node = tree.root.find_child("World", true, false)
	var sol_count = 1
	if world_node and "survival" in world_node and world_node.survival:
		sol_count = world_node.survival.current_sol
	
	if player and player.has_method("start_ending_sequence"):
		player.start_ending_sequence(self, sol_count)
	else:
		start_ignition()
		var tw = create_tween()
		tw.tween_method(set_liftoff_progress, 0.0, 1.0, liftoff_duration)
		tw.tween_callback(func():
			launch_success.emit()
			if hud_ref() and hud_ref().has_method("show_victory_screen"):
				hud_ref().show_victory_screen(sol_count)
		)

func start_ignition() -> void:
	if prompt_label:
		prompt_label.visible = false
	if thruster_particles:
		thruster_particles.restart()
		thruster_particles.emitting = true
	if rumble_player:
		rumble_player.play()
	print("[MAV ROCKET] Engine ignition engaged: Exhaust plume active, low rumble sound playing.")

func set_liftoff_progress(progress: float) -> void:
	if not rocket_root:
		rocket_root = get_node_or_null("Rocket") if has_node("Rocket") else get_node_or_null("RocketMesh")
	if rocket_root:
		# Ascend along local Y (which points away from planet)
		rocket_root.position.y = base_rocket_local_pos.y + progress * liftoff_altitude

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = false
		if is_holding_repair:
			is_holding_repair = false
			repair_hold_timer = 0.0
			var hud = _get_hud()
			if hud and hud.has_method("hide_progress_ring"):
				hud.hide_progress_ring()

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

func hud_ref() -> CanvasLayer:
	return _get_hud()
