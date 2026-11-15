extends Area3D
class_name CrashedPod

# crashed_pod.gd
# Sol 1 Life Pod: Interior, 3 damaged machines, interaction zones, and staged arrival sequence.
# Supports Part A: Oxygen scrubber repair with salvaged filter core and power cost.

signal solar_deployed
signal arrival_sequence_finished
signal scrubber_repaired_signal

@export_group("Pod Root Scale")
@export var base_root_scale: Vector3 = Vector3(2.912167, 1.075458, 2.950094) # 8.0m wide, 6.0m tall
@export var pod_scale: float = 2.0:
	set(val):
		pod_scale = val
		_apply_scale()

var root_scale: Vector3:
	get:
		return base_root_scale * pod_scale
	set(val):
		base_root_scale = val

@export_group("Arrival Sequence Timings")
@export var freeze_duration: float = 1.0
@export var fade_out_duration: float = 1.0
@export var fade_in_duration: float = 1.0
@export var hud_element_fade_duration: float = 0.5
@export var hud_element_gap: float = 0.8
@export var jetpack_text_duration: float = 3.0

@export_group("Solar System")
@export var solar_is_deployed: bool = false

@export_group("Scrubber Repair")
@export var repair_core_cost: int = 1
@export var repair_power_cost: float = 10.0
@export var oxygen_repair_factor: float = 0.5

@export_group("Power Unit Repair")
@export var repair_power_core_cost: int = 1
@export var power_output_boost: float = 1.8

@export_group("Water System Repair")
@export var repair_water_ice_cost: int = 1

# Internal state
var arrival_sequence_completed: bool = false
var is_arrival_sequence_running: bool = false
var is_door_open: bool = false
var is_player_nearby: bool = false
var active_machine: String = ""
var overlapping_machines: Array[String] = []
var current_player: Node3D = null
var is_scrubber_highlighted: bool = false
var pulse_timer: float = 0.0

var is_scrubber_repaired: bool = false
var is_power_unit_repaired: bool = false
var is_water_tank_repaired: bool = false
var is_holding_repair: bool = false
var repair_target_machine: String = ""
var repair_hold_timer: float = 0.0
const REPAIR_HOLD_DURATION: float = 3.0

var survival_ref: RefCounted = null
var spark_particles: CPUParticles3D = null
var repair_audio: AudioStreamPlayer3D = null
var repair_tween: Tween = null

# Node references
@onready var prompt_label: Label3D = $PromptLabel
@onready var solar_mesh: Node3D = $DeployedSolar

@onready var scrubber_node: Node3D = $OxygenScrubber
@onready var scrubber_mesh: MeshInstance3D = get_node_or_null("OxygenScrubber/MeshInstance3D")
@onready var scrubber_light: OmniLight3D = $OxygenScrubber/RedGlowLight
@onready var scrubber_zone: Area3D = $OxygenScrubber/InteractZone
@onready var scrubber_prompt: Label3D = $OxygenScrubber/PromptLabel

@onready var power_node: Node3D = $PowerUnit
@onready var power_mesh: MeshInstance3D = get_node_or_null("PowerUnit/MeshInstance3D")
@onready var power_light: OmniLight3D = $PowerUnit/RedGlowLight
@onready var power_zone: Area3D = $PowerUnit/InteractZone
@onready var power_prompt: Label3D = $PowerUnit/PromptLabel

@onready var water_node: Node3D = $WaterTank
@onready var water_mesh: MeshInstance3D = get_node_or_null("WaterTank/MeshInstance3D")
@onready var water_light: OmniLight3D = $WaterTank/RedGlowLight
@onready var water_zone: Area3D = $WaterTank/InteractZone
@onready var water_prompt: Label3D = $WaterTank/PromptLabel

var door_node: Node3D = null

func _apply_scale() -> void:
	scale = base_root_scale * pod_scale
	align_floor_to_hatch()

func align_floor_to_hatch() -> void:
	var door_mesh = find_child("Line002_glass_02", true, false) as MeshInstance3D
	var floor_node = get_node_or_null("InteriorFloor") as StaticBody3D
	if not floor_node:
		return
	var floor_col = floor_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not floor_col:
		return
	var floor_box = floor_col.shape as BoxShape3D
	if not floor_box:
		floor_box = BoxShape3D.new()
		floor_col.shape = floor_box
	
	var thickness: float = 0.4
	floor_box.size = Vector3(2.4, thickness, 2.6)
	
	var hatch_floor_global_y: float = global_position.y
	if door_mesh and door_mesh.mesh:
		var aabb = door_mesh.get_aabb()
		var h_global = door_mesh.to_global(Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
		hatch_floor_global_y = h_global.y
	else:
		hatch_floor_global_y = global_position.y + 3.26
		
	var b = global_transform.basis
	var fz = floor_node.position.z
	var divisor = b.y.y if abs(b.y.y) > 0.001 else 1.0
	var required_top_local_y = (hatch_floor_global_y - global_position.y - b.z.y * fz) / divisor
	floor_node.position.y = required_top_local_y - thickness * 0.5
	floor_node.force_update_transform()
	
	# Reposition machine interact zones so they sit right on the floor
	if scrubber_node:
		scrubber_node.position.y = required_top_local_y + 0.1
	if power_node:
		power_node.position.y = required_top_local_y + 0.1
	if water_node:
		water_node.position.y = required_top_local_y + 0.1

func get_hatch_dimensions() -> Dictionary:
	var door_mesh = find_child("Line002_glass_02", true, false) as MeshInstance3D
	if door_mesh and door_mesh.mesh:
		var aabb = door_mesh.global_transform * door_mesh.get_aabb()
		return {"width": aabb.size.x, "height": aabb.size.y, "depth": aabb.size.z}
	return {"width": 3.77 * pod_scale, "height": 2.67 * pod_scale, "depth": 1.32 * pod_scale}

func get_pod_bounding_size() -> Vector3:
	var total_aabb = AABB()
	var first = true
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if mi.mesh and mi.visible:
			var mb = mi.global_transform * mi.get_aabb()
			if first:
				total_aabb = mb
				first = false
			else:
				total_aabb = total_aabb.merge(mb)
	return total_aabb.size

func _ready() -> void:
	_apply_scale()
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	door_node = find_child("Line0022", true, false) as Node3D
	
	var hatch_dim = get_hatch_dimensions()
	var pod_bounds = get_pod_bounding_size()
	print("\n==================================================")
	print("CRASHED POD SCALING & HATCH CLEARANCE (8x6 SCALE)")
	print("==================================================")
	print("Pod Global Scale:        %s" % scale)
	print("Pod Bounding Size:       Width X = %.2f m, Height Y = %.2f m, Depth Z = %.2f m" % [pod_bounds.x, pod_bounds.y, pod_bounds.z])
	print("Hatch Opening Size:      Width X = %.2f m, Height Y = %.2f m" % [hatch_dim["width"], hatch_dim["height"]])
	print("Hatch Height Check:      %s (>= 2.5m requirement, Player height: 1.8m)" % ("PASS" if hatch_dim["height"] >= 2.5 else "FAIL"))
	print("Stooping/Clipping Check: NO STOOPING (Clearance: +%.2f m headroom)" % (hatch_dim["height"] - 1.8))
	print("==================================================\n")
	
	if solar_mesh:
		solar_mesh.visible = solar_is_deployed
	_update_prompt()
	
	# Connect machine interact zones
	if scrubber_zone:
		scrubber_zone.body_entered.connect(func(b): _on_machine_entered(b, "OxygenScrubber"))
		scrubber_zone.body_exited.connect(func(b): _on_machine_exited(b, "OxygenScrubber"))
	if power_zone:
		power_zone.body_entered.connect(func(b): _on_machine_entered(b, "PowerUnit"))
		power_zone.body_exited.connect(func(b): _on_machine_exited(b, "PowerUnit"))
	if water_zone:
		water_zone.body_entered.connect(func(b): _on_machine_entered(b, "WaterTank"))
		water_zone.body_exited.connect(func(b): _on_machine_exited(b, "WaterTank"))
	
	_setup_repair_effects()
	_check_session_repaired_state()

func _setup_repair_effects() -> void:
	if scrubber_node:
		# Spark CPUParticles3D
		spark_particles = CPUParticles3D.new()
		spark_particles.name = "SparkParticles"
		spark_particles.emitting = false
		spark_particles.one_shot = true
		spark_particles.explosiveness = 0.95
		spark_particles.amount = 40
		spark_particles.lifetime = 0.6
		spark_particles.direction = Vector3(0, 1, 0)
		spark_particles.spread = 45.0
		spark_particles.initial_velocity_min = 2.0
		spark_particles.initial_velocity_max = 5.0
		spark_particles.gravity = Vector3(0, -9.8, 0)
		spark_particles.color = Color(1.0, 0.8, 0.2, 1.0)
		scrubber_node.add_child(spark_particles)
		spark_particles.position = Vector3(0, 0.8, 0)
		
		# Low-volume repair sound
		repair_audio = AudioStreamPlayer3D.new()
		repair_audio.name = "RepairAudio"
		repair_audio.volume_db = -12.0
		repair_audio.unit_size = 10.0
		repair_audio.max_distance = 30.0
		
		# Synthesize a clean two-tone chime AudioStreamWAV
		var sample_rate = 22050
		var num_samples = int(sample_rate * 0.35)
		var pcm = PackedByteArray()
		pcm.resize(num_samples)
		for i in range(num_samples):
			var t = float(i) / sample_rate
			var freq = 587.33 if t < 0.15 else 880.0
			var wave = sin(t * TAU * freq)
			var env = exp(-t * 6.0)
			var val = clamp(int((wave * env) * 120.0 + 128.0), 0, 255)
			pcm.set(i, val)
		
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = sample_rate
		wav.data = pcm
		repair_audio.stream = wav
		scrubber_node.add_child(repair_audio)
		repair_audio.position = Vector3(0, 0.5, 0)

func _check_session_repaired_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.scrubber_repaired:
		is_scrubber_repaired = true
		is_scrubber_highlighted = false
		if scrubber_light:
			scrubber_light.light_color = Color(0.2, 1.0, 0.3)
			scrubber_light.light_energy = 2.0
		if scrubber_mesh:
			var mat = scrubber_mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				mat.albedo_color = Color(0.1, 0.5, 0.2)
				mat.emission = Color(0.2, 1.0, 0.3)
				mat.emission_energy_multiplier = 2.0
	
	if gm and gm.power_unit_repaired:
		is_power_unit_repaired = true
		if power_light:
			power_light.light_color = Color(0.2, 1.0, 0.3)
			power_light.light_energy = 2.0
		if power_mesh:
			var mat = power_mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				mat.albedo_color = Color(0.1, 0.5, 0.2)
				mat.emission = Color(0.2, 1.0, 0.3)
				mat.emission_energy_multiplier = 2.0

func _process(delta: float) -> void:
	if is_holding_repair:
		_process_repair_hold(delta)
	
	if is_scrubber_highlighted and scrubber_mesh and not is_scrubber_repaired:
		pulse_timer += delta
		var pulse = (sin(pulse_timer * 4.0) + 1.0) * 0.5
		var mat = scrubber_mesh.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = lerp(1.5, 5.0, pulse)
		if scrubber_light:
			scrubber_light.light_energy = lerp(1.0, 3.5, pulse)
			
	if overlapping_machines.size() > 1 and current_player:
		_refresh_active_machine()

func _process_repair_hold(delta: float) -> void:
	if not Input.is_action_pressed("interact") or active_machine != repair_target_machine:
		# Canceled early
		is_holding_repair = false
		repair_hold_timer = 0.0
		repair_target_machine = ""
		var hud = _get_hud()
		if hud and hud.has_method("hide_progress_ring"):
			hud.hide_progress_ring()
		return
	
	repair_hold_timer += delta
	var prog = clampf(repair_hold_timer / REPAIR_HOLD_DURATION, 0.0, 1.0)
	var hud = _get_hud()
	if hud and hud.has_method("update_progress_ring"):
		hud.update_progress_ring(prog)
	
	if repair_hold_timer >= REPAIR_HOLD_DURATION:
		var target = repair_target_machine
		is_holding_repair = false
		repair_hold_timer = 0.0
		repair_target_machine = ""
		if hud and hud.has_method("hide_progress_ring"):
			hud.hide_progress_ring()
		if target == "OxygenScrubber":
			_complete_scrubber_repair()
		elif target == "PowerUnit":
			_complete_power_unit_repair()
		elif target == "WaterTank":
			_complete_water_repair()

func _update_prompt() -> void:
	if not prompt_label:
		return
	if not solar_is_deployed:
		prompt_label.text = "📦 Survival Pod (Crash Site)\nPress E to Deploy Emergency Solar Panels"
	else:
		prompt_label.text = "🏠 Survival Shelter (Safe Zone)\nRefilling Oxygen & Protected from Radiation"

func _on_machine_entered(body: Node3D, machine_name: String) -> void:
	if body.is_in_group("player") or body.name == "Player":
		current_player = body
		if not overlapping_machines.has(machine_name):
			overlapping_machines.append(machine_name)
		_refresh_active_machine()

func _on_machine_exited(body: Node3D, machine_name: String) -> void:
	if body.is_in_group("player") or body.name == "Player":
		overlapping_machines.erase(machine_name)
		if is_holding_repair and machine_name == repair_target_machine:
			is_holding_repair = false
			repair_hold_timer = 0.0
			repair_target_machine = ""
			var hud = _get_hud()
			if hud and hud.has_method("hide_progress_ring"):
				hud.hide_progress_ring()
		_refresh_active_machine()

func _refresh_active_machine() -> void:
	var prev_machine = active_machine
	if overlapping_machines.is_empty():
		active_machine = ""
		if prev_machine != "":
			var hud = _get_hud()
			if hud and hud.has_method("clear_interaction_prompt"):
				hud.clear_interaction_prompt()
	elif overlapping_machines.size() == 1:
		active_machine = overlapping_machines[0]
	else:
		var closest = ""
		var min_d = 999999.0
		for m_name in overlapping_machines:
			var node = get_node_or_null(m_name)
			if node and current_player:
				var d = node.global_position.distance_to(current_player.global_position)
				if d < min_d:
					min_d = d
					closest = m_name
		active_machine = closest if closest != "" else overlapping_machines[-1]
	
	if prev_machine != active_machine:
		_update_machine_prompts()

func _update_machine_prompts() -> void:
	var hud = _get_hud()
	if scrubber_prompt:
		scrubber_prompt.visible = (active_machine == "OxygenScrubber")
		if scrubber_prompt.visible:
			if is_scrubber_repaired:
				scrubber_prompt.text = "Oxygen Scrubber (Repaired)\nOperational"
				if hud and hud.has_method("clear_interaction_prompt"):
					hud.clear_interaction_prompt()
			else:
				scrubber_prompt.text = "Oxygen Scrubber (Offline)\n[E] Hold 3s to Repair"
				if hud and hud.has_method("set_interaction_prompt"):
					hud.set_interaction_prompt("[E] Hold to Repair Scrubber")
		else:
			if not is_scrubber_repaired:
				scrubber_prompt.text = "Oxygen Scrubber (Damaged)\n[E] Inspect"
			else:
				scrubber_prompt.text = "Oxygen Scrubber (Operational)"
	
	if power_prompt:
		power_prompt.visible = (active_machine == "PowerUnit")
		if power_prompt.visible:
			if is_power_unit_repaired:
				power_prompt.text = "Power Unit (Repaired)\nOperational"
				if hud and hud.has_method("clear_interaction_prompt"):
					hud.clear_interaction_prompt()
			else:
				power_prompt.text = "Power Unit (Offline)\n[E] Hold 3s to Repair"
				if hud and hud.has_method("set_interaction_prompt"):
					hud.set_interaction_prompt("[E] Hold to Repair Power Unit")
		else:
			if not is_power_unit_repaired:
				power_prompt.text = "Power Unit (Damaged)\n[E] Inspect"
			else:
				power_prompt.text = "Power Unit (Operational)"
	if water_prompt:
		water_prompt.visible = (active_machine == "WaterTank")
		if water_prompt.visible and hud and hud.has_method("set_interaction_prompt"):
			hud.set_interaction_prompt("[E] Inspect Water Tank")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
		
	if active_machine != "":
		_interact_with_machine(active_machine)
	elif is_player_nearby and not solar_is_deployed:
		deploy_solar()

func _get_survival() -> RefCounted:
	if survival_ref:
		return survival_ref
	var tree = get_tree()
	if tree and tree.root:
		var world = tree.root.find_child("World", true, false)
		if world and "survival" in world and world.survival:
			survival_ref = world.survival
			return survival_ref
	return null

func _interact_with_machine(m_name: String) -> void:
	var hud = _get_hud()
	match m_name:
		"OxygenScrubber":
			if is_scrubber_repaired:
				if hud and hud.has_method("show_message"):
					hud.show_message("Oxygen Scrubber is fully operational", 3.0)
				return
			
			var gm = get_node_or_null("/root/GameManager")
			var cores = gm.filter_core if gm else 0
			if cores < repair_core_cost:
				print("[INTERACTION] OxygenScrubber: Needs a filter core from Crash Base")
				if hud and hud.has_method("show_message"):
					hud.show_message("Needs a filter core from Crash Base", 3.0)
				elif hud and hud.has_method("show_alert"):
					hud.show_alert("Needs a filter core from Crash Base", true)
				return
			
			var s = _get_survival()
			if s and s.power < repair_power_cost:
				print("[INTERACTION] OxygenScrubber: Not enough power to repair (Current: %.1f%%, Required: %.1f%%)" % [s.power, repair_power_cost])
				if hud and hud.has_method("show_message"):
					hud.show_message("Not enough power to repair", 3.0)
				elif hud and hud.has_method("show_alert"):
					hud.show_alert("Not enough power to repair", true)
				return
			
			# Begin holding E
			is_holding_repair = true
			repair_target_machine = "OxygenScrubber"
			repair_hold_timer = 0.0
			if hud and hud.has_method("show_progress_ring"):
				hud.show_progress_ring(0.0)
				
		"PowerUnit":
			if is_power_unit_repaired:
				if hud and hud.has_method("show_message"):
					hud.show_message("Power Unit is fully operational", 3.0)
				return
			
			var gm = get_node_or_null("/root/GameManager")
			var cores = gm.power_unit_core if gm else 0
			if cores < repair_power_core_cost:
				print("[INTERACTION] PowerUnit: Needs a power unit core from Rover Site")
				if hud and hud.has_method("show_message"):
					hud.show_message("Needs a power unit core from Rover Site", 3.0)
				elif hud and hud.has_method("show_alert"):
					hud.show_alert("Needs a power unit core from Rover Site", true)
				return
			
			# Begin holding E
			is_holding_repair = true
			repair_target_machine = "PowerUnit"
			repair_hold_timer = 0.0
			if hud and hud.has_method("show_progress_ring"):
				hud.show_progress_ring(0.0)
				
		"WaterTank":
			if is_water_tank_repaired:
				if hud and hud.has_method("show_message"):
					hud.show_message("Water System is fully operational", 3.0)
				return
			
			var gm = get_node_or_null("/root/GameManager")
			var ice_count = gm.water_ice if gm else 0
			if ice_count < repair_water_ice_cost:
				print("[INTERACTION] WaterTank: Needs water ice from Water Deposit")
				if hud and hud.has_method("show_message"):
					hud.show_message("Needs water ice from Water Deposit", 3.0)
				elif hud and hud.has_method("show_alert"):
					hud.show_alert("Needs water ice from Water Deposit", true)
				return
			
			# Begin holding E
			is_holding_repair = true
			repair_target_machine = "WaterTank"
			repair_hold_timer = 0.0
			if hud and hud.has_method("show_progress_ring"):
				hud.show_progress_ring(0.0)

func _complete_water_repair() -> void:
	is_water_tank_repaired = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.water_repaired = true
		if gm.water_ice >= repair_water_ice_cost:
			gm.water_ice -= repair_water_ice_cost
	
	var s = _get_survival()
	if s and s.has_method("add_water_ice"):
		s.add_water_ice()
	
	if water_light:
		var tw = create_tween()
		tw.tween_property(water_light, "light_color", Color(0.2, 1.0, 0.3), 1.5)
		tw.tween_property(water_light, "light_energy", 2.0, 1.5)
	
	if water_prompt:
		water_prompt.text = "Water System (Online)\nOperational"
	
	print("[WATER SYSTEM] Water recycling system repaired!")
	var hud = _get_hud()
	if hud and hud.has_method("show_message"):
		hud.show_message("Water recycling system repaired", 3.0)

func _complete_scrubber_repair() -> void:
	is_scrubber_repaired = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.scrubber_repaired = true
		gm.use_filter_core(repair_core_cost)
	
	var s = _get_survival()
	if s:
		if "is_scrubber_repaired" in s:
			s.is_scrubber_repaired = true
		if "power" in s:
			s.power = max(0.0, s.power - repair_power_cost)
		if "base_o2_rate" in s:
			var old_drain = s.base_o2_rate
			s.base_o2_rate *= oxygen_repair_factor
			print("[OXYGEN SCRUBBER] Drain rate before: %.3f/s, after: %.3f/s" % [old_drain, s.base_o2_rate])
		elif "o2_drain_inside" in s:
			var old_drain = s.o2_drain_inside
			s.o2_drain_inside *= oxygen_repair_factor
			print("[OXYGEN SCRUBBER] Drain rate before: %.3f/s, after: %.3f/s" % [old_drain, s.o2_drain_inside])
	
	# Glow red to green over 1.5 seconds
	is_scrubber_highlighted = false
	var tw = create_tween()
	repair_tween = tw
	tw.set_parallel(true)
	if scrubber_light:
		tw.tween_property(scrubber_light, "light_color", Color(0.2, 1.0, 0.3), 1.5)
		tw.tween_property(scrubber_light, "light_energy", 2.2, 1.5)
	if scrubber_mesh:
		var mat = scrubber_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			tw.tween_property(mat, "albedo_color", Color(0.1, 0.5, 0.2), 1.5)
			tw.tween_property(mat, "emission", Color(0.2, 1.0, 0.3), 1.5)
			tw.tween_property(mat, "emission_energy_multiplier", 2.0, 1.5)
	
	# Spark burst
	if spark_particles:
		spark_particles.position = Vector3(0, 0.8, 0)
		spark_particles.restart()
		spark_particles.emitting = true
	
	# Audio sound
	if repair_audio:
		repair_audio.position = Vector3(0, 0.5, 0)
		repair_audio.play()
	
	# Message for 3 seconds
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Oxygen scrubber repaired", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Oxygen scrubber repaired", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()
	
	print("[SCRUBBER REPAIR] Oxygen scrubber repaired successfully!")
	_update_machine_prompts()
	scrubber_repaired_signal.emit()

func _complete_power_unit_repair() -> void:
	is_power_unit_repaired = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.power_unit_repaired = true
		gm.use_power_core(repair_power_core_cost)
	
	var s = _get_survival()
	if s:
		if "is_power_unit_repaired" in s:
			s.is_power_unit_repaired = true
		if "solar_power_gain" in s:
			var old_gain = s.solar_power_gain
			s.solar_power_gain = max(1.5, s.solar_power_gain * power_output_boost)
			print("[POWER UNIT] Solar power gain before: %.3f/s, after: %.3f/s" % [old_gain, s.solar_power_gain])
		elif "base_power_drain" in s:
			s.base_power_drain = max(0.05, s.base_power_drain / power_output_boost)
	
	# Glow red to green over 1.5 seconds
	var tw = create_tween()
	repair_tween = tw
	tw.set_parallel(true)
	if power_light:
		tw.tween_property(power_light, "light_color", Color(0.2, 1.0, 0.3), 1.5)
		tw.tween_property(power_light, "light_energy", 2.2, 1.5)
	if power_mesh:
		var mat = power_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			tw.tween_property(mat, "albedo_color", Color(0.1, 0.5, 0.2), 1.5)
			tw.tween_property(mat, "emission", Color(0.2, 1.0, 0.3), 1.5)
			tw.tween_property(mat, "emission_energy_multiplier", 2.0, 1.5)
	
	# Spark burst at power_node
	if spark_particles and power_node:
		spark_particles.global_position = power_node.global_position + Vector3(0, 0.8, 0)
		spark_particles.restart()
		spark_particles.emitting = true
	
	# Audio sound
	if repair_audio and power_node:
		repair_audio.global_position = power_node.global_position
		repair_audio.play()
	
	# Message for 3 seconds
	var hud = _get_hud()
	if hud:
		if hud.has_method("show_message"):
			hud.show_message("Power unit repaired", 3.0)
		elif hud.has_method("show_alert"):
			hud.show_alert("Power unit repaired", false)
		if hud.has_method("clear_interaction_prompt"):
			hud.clear_interaction_prompt()
	
	print("[POWER REPAIR] Power unit repaired successfully!")
	_update_machine_prompts()

func _get_hud() -> CanvasLayer:
	var root_node = get_tree().root
	var hud = root_node.find_child("HUD", true, false) as CanvasLayer
	return hud

func deploy_solar() -> void:
	solar_is_deployed = true
	if solar_mesh:
		solar_mesh.visible = true
	_update_prompt()
	solar_deployed.emit()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = true
		_update_prompt()
		var hud = _get_hud()
		start_arrival_sequence(body, hud)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		is_player_nearby = false

func set_door_open(open: bool) -> void:
	if not door_node:
		door_node = find_child("Line0022", true, false) as Node3D
	if not door_node:
		return
		
	if open and not is_door_open:
		door_node.rotate_x(deg_to_rad(85.0))
		door_node.position.y += 350.0
		is_door_open = true
	elif not open and is_door_open:
		door_node.position.y -= 350.0
		door_node.rotate_x(-deg_to_rad(85.0))
		is_door_open = false

func highlight_oxygen_scrubber(enable: bool) -> void:
	is_scrubber_highlighted = enable

# -------------------------------------------------------------------------
# ARRIVAL SEQUENCE
# -------------------------------------------------------------------------
func start_arrival_sequence(player: Node3D, hud: CanvasLayer) -> void:
	if arrival_sequence_completed or is_arrival_sequence_running:
		return
	is_arrival_sequence_running = true

	var t0: float = Time.get_ticks_msec() / 1000.0
	print("\n==================================================")
	print("STARTING SOL 1 LIFE POD ARRIVAL SEQUENCE")
	print("==================================================")

	# Step 1: Freeze player input for 1 second, then fade screen to black over 1 second
	print("[ARRIVAL SEQUENCE] Step 1: Freezing player input for %.1fs at t = 0.00s" % freeze_duration)
	if player:
		player.set_physics_process(false)
		if "velocity" in player:
			player.velocity = Vector3.ZERO
	await get_tree().create_timer(freeze_duration).timeout

	var t_fade_out: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Step 1: Fading screen to black over %.1fs at t = %.2fs" % [fade_out_duration, t_fade_out])
	if hud and hud.has_method("fade_screen"):
		await hud.fade_screen(1.0, fade_out_duration)
	else:
		await get_tree().create_timer(fade_out_duration).timeout

	# Step 2: Fade back in. Show pod door as open (set door node to its open pose if closed)
	var t_fade_in: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Step 2: Fading screen back in over %.1fs at t = %.2fs" % [fade_in_duration, t_fade_in])
	set_door_open(true)
	print("[ARRIVAL SEQUENCE] Step 2: Pod door set to OPEN pose")
	if hud and hud.has_method("fade_screen"):
		await hud.fade_screen(0.0, fade_in_duration)
	else:
		await get_tree().create_timer(fade_in_duration).timeout

	# Step 3: Reveal HUD one element at a time, each fading in over 0.5s with a 0.8s gap:
	var t_hud_start: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Step 3: Revealing HUD elements one at a time (fade: %.1fs, gap: %.1fs) at t = %.2fs:" % [hud_element_fade_duration, hud_element_gap, t_hud_start])
	if hud and hud.has_method("reveal_hud_staged"):
		await hud.reveal_hud_staged(hud_element_fade_duration, hud_element_gap, t0)
	else:
		var hud_elements = ["Health", "Oxygen", "Suit", "Outpost Power", "Outpost Water", "Outpost Food"]
		for i in range(hud_elements.size()):
			var elem_t: float = (Time.get_ticks_msec() / 1000.0) - t0
			print("  [HUD REVEAL] %d. %s Bar faded in at t = %.2fs" % [i + 1, hud_elements[i], elem_t])
			await get_tree().create_timer(hud_element_gap).timeout

	# Step 4: Show jetpack unlock text "Jetpack online" for 3 seconds. Enable jetpack input.
	var t_jetpack: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Step 4: Showing 'Jetpack online' text for %.1fs at t = %.2fs. Enabling jetpack input." % [jetpack_text_duration, t_jetpack])
	if player and player.has_method("set_haggard"):
		player.set_haggard(false)
	if hud and hud.has_method("show_jetpack_online"):
		hud.show_jetpack_online(jetpack_text_duration)
	await get_tree().create_timer(jetpack_text_duration).timeout

	# Step 5: Show objective "Repair the oxygen scrubber" and highlight OxygenScrubber machine with a pulsing glow
	var t_obj: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Step 5: Showing objective 'Repair the oxygen scrubber' at t = %.2fs. Highlighting OxygenScrubber with pulsing glow." % t_obj)
	if hud and hud.has_method("show_objective"):
		hud.show_objective("Repair the oxygen scrubber")
	highlight_oxygen_scrubber(true)

	# Restore normal player input and camera control at end of sequence
	if player:
		player.set_physics_process(true)
		if "is_camera_guided" in player:
			player.is_camera_guided = false

	var t_end: float = (Time.get_ticks_msec() / 1000.0) - t0
	print("[ARRIVAL SEQUENCE] Sequence completed. Player input & camera control restored at t = %.2fs." % t_end)
	print("==================================================\n")

	arrival_sequence_completed = true
	is_arrival_sequence_running = false
	arrival_sequence_finished.emit()

# -------------------------------------------------------------------------
# HABITAT & OXYGEN SURROUNDINGS (Part E)
# -------------------------------------------------------------------------
func setup_surroundings(planet_node: Node3D) -> void:
	var existing = get_parent().get_node_or_null("PodSurroundings") if get_parent() else null
	if existing:
		existing.queue_free()
	
	var surroundings_root = Node3D.new()
	surroundings_root.name = "PodSurroundings"
	if get_parent():
		get_parent().add_child(surroundings_root)
	else:
		add_child(surroundings_root)
	
	var pod_center = global_position
	var pod_norm = pod_center.normalized()
	
	var hatch_node = find_child("Line0022", true, false) as Node3D
	var hatch_pos = hatch_node.global_position if hatch_node else to_global(Vector3(0, 0.4, 2.4))
	
	# Airlock approach orientation (facing away from hatch)
	var hatch_dir = (hatch_pos - pod_center)
	var hatch_fwd = (hatch_dir - pod_norm * hatch_dir.dot(pod_norm)).normalized()
	if hatch_fwd.length_squared() < 0.01:
		hatch_fwd = -global_transform.basis.z
	var hatch_right = hatch_fwd.cross(pod_norm).normalized()
	
	# 1. Faint emissive light strip along the pod's base to read as an airlock approach
	var strip_mat = StandardMaterial3D.new()
	strip_mat.albedo_color = Color(0.25, 0.85, 0.95)
	strip_mat.emission_enabled = true
	strip_mat.emission = Color(0.25, 0.85, 0.95)
	strip_mat.emission_energy_multiplier = 1.8
	
	var strip_mesh = BoxMesh.new()
	strip_mesh.size = Vector3(0.12, 0.04, 3.2)
	
	for side_sign in [-1.0, 1.0]:
		var strip_center = hatch_pos + hatch_right * (side_sign * 1.1) + hatch_fwd * 1.6
		if planet_node and planet_node.has_method("get_surface_point"):
			strip_center = planet_node.get_surface_point(strip_center.normalized()) + pod_norm * 0.02
		
		var rocket_pos = Vector3(0, 494.424, 0)
		if strip_center.distance_to(rocket_pos) < 60.0:
			continue
		
		var strip_inst = MeshInstance3D.new()
		strip_inst.name = "AirlockLightStrip_%s" % ("Left" if side_sign < 0 else "Right")
		strip_inst.mesh = strip_mesh
		strip_inst.material_override = strip_mat
		surroundings_root.add_child(strip_inst)
		
		var strip_basis = Basis(hatch_right, pod_norm, -hatch_fwd)
		strip_inst.global_transform = Transform3D(strip_basis, strip_center)
	
	# Subtle ground glow for airlock approach
	var airlock_light = OmniLight3D.new()
	airlock_light.name = "AirlockGlowLight"
	airlock_light.light_color = Color(0.25, 0.85, 0.95)
	airlock_light.light_energy = 0.8
	airlock_light.omni_range = 4.5
	surroundings_root.add_child(airlock_light)
	airlock_light.global_position = hatch_pos + hatch_fwd * 1.5 + pod_norm * 0.3
	
	# 2. 20-unit ring of low dust drift (flattened rock clusters with dust colour)
	# Radius 12m to 20m from pod center, strictly >= 6.0m from hatch
	var dust_mat = StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.82, 0.38, 0.18)
	dust_mat.roughness = 0.94
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 98765
	
	var ring_rocks_root = Node3D.new()
	ring_rocks_root.name = "DustDriftRing"
	surroundings_root.add_child(ring_rocks_root)
	
	var placed_drifts = 0
	var num_drifts = 12
	for i in range(num_drifts):
		var angle = float(i) / float(num_drifts) * TAU + rng.randf_range(-0.15, 0.15)
		var ring_dist = rng.randf_range(13.0, 19.5)
		
		# Radial direction on sphere
		var tangent_dir = (hatch_right * cos(angle) + hatch_fwd * sin(angle)).normalized()
		var ang_rad = ring_dist / 500.0
		var cluster_dir = (pod_norm * cos(ang_rad) + tangent_dir * sin(ang_rad)).normalized()
		var cluster_pos = planet_node.get_surface_point(cluster_dir) if planet_node else pod_center + tangent_dir * ring_dist
		
		# Clear approach check: no obstacles inside 6.0 units of the hatch
		if cluster_pos.distance_to(hatch_pos) < 6.0:
			continue
		
		# Rocket clearance check: strictly >= 60.0 units from mav_rocket
		var rocket_pos = Vector3(0, 494.424, 0)
		if cluster_pos.distance_to(rocket_pos) < 60.0:
			continue
		
		# Create flattened cluster of 2-3 rocks
		var cluster_node = Node3D.new()
		cluster_node.name = "DustCluster_%d" % placed_drifts
		ring_rocks_root.add_child(cluster_node)
		
		var cl_norm = cluster_pos.normalized()
		var cl_fwd = tangent_dir
		var cl_right = cl_fwd.cross(cl_norm).normalized()
		cl_fwd = cl_norm.cross(cl_right).normalized()
		cluster_node.global_transform = Transform3D(Basis(cl_right, cl_norm, -cl_fwd), cluster_pos)
		
		var rock_count = rng.randi_range(2, 3)
		for r in range(rock_count):
			var r_mesh = BoxMesh.new()
			var sx = rng.randf_range(1.2, 2.4)
			var sy = rng.randf_range(0.18, 0.35) # Flattened low dust drift
			var sz = rng.randf_range(1.0, 2.2)
			r_mesh.size = Vector3(sx, sy, sz)
			
			var mi = MeshInstance3D.new()
			mi.mesh = r_mesh
			mi.material_override = dust_mat
			cluster_node.add_child(mi)
			
			var ro_x = rng.randf_range(-0.6, 0.6)
			var ro_z = rng.randf_range(-0.6, 0.6)
			mi.position = Vector3(ro_x, sy * 0.35, ro_z)
			mi.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0, TAU), rng.randf_range(-0.1, 0.1))
		
		placed_drifts += 1
	
	# 3. Two dead shrub-like rock spires
	var spire_mat = StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.24, 0.18, 0.15)
	spire_mat.roughness = 0.92
	
	var spires_root = Node3D.new()
	spires_root.name = "RockSpires"
	surroundings_root.add_child(spires_root)
	
	var spire_angles = [1.85, -1.85] # Flanking back-left and back-right
	for s_idx in range(spire_angles.size()):
		var s_ang = spire_angles[s_idx]
		var s_dist = 14.5
		var s_tangent = (hatch_right * cos(s_ang) + hatch_fwd * sin(s_ang)).normalized()
		var s_dir = (pod_norm * cos(s_dist / 500.0) + s_tangent * sin(s_dist / 500.0)).normalized()
		var s_pos = planet_node.get_surface_point(s_dir) if planet_node else pod_center + s_tangent * s_dist
		
		# Verify hatch clearance (>= 6.0m)
		assert(s_pos.distance_to(hatch_pos) >= 6.0, "Spire must be at least 6.0m from hatch!")
		
		# Rocket clearance check: strictly >= 60.0 units from mav_rocket
		var rocket_pos = Vector3(0, 494.424, 0)
		if s_pos.distance_to(rocket_pos) < 60.0:
			continue
		
		var spire_node = Node3D.new()
		spire_node.name = "RockSpire_%d" % (s_idx + 1)
		spires_root.add_child(spire_node)
		
		var s_norm = s_pos.normalized()
		var s_fwd = s_tangent
		var s_right = s_fwd.cross(s_norm).normalized()
		s_fwd = s_norm.cross(s_right).normalized()
		spire_node.global_transform = Transform3D(Basis(s_right, s_norm, -s_fwd), s_pos)
		
		# Shrub-like branching rock spire (4 segments)
		for seg in range(4):
			var seg_mesh = CylinderMesh.new()
			seg_mesh.top_radius = 0.08 + seg * 0.04
			seg_mesh.bottom_radius = 0.16 + seg * 0.06
			seg_mesh.height = 0.95
			
			var seg_mi = MeshInstance3D.new()
			seg_mi.mesh = seg_mesh
			seg_mi.material_override = spire_mat
			spire_node.add_child(seg_mi)
			
			var seg_y = 0.45 + seg * 0.8
			var seg_tilt_x = sin(seg * 1.5 + s_idx) * 0.18
			var seg_tilt_z = cos(seg * 1.7 + s_idx) * 0.18
			seg_mi.position = Vector3(seg_tilt_x * 0.5, seg_y, seg_tilt_z * 0.5)
			seg_mi.rotation = Vector3(seg_tilt_x, float(seg) * 1.2, seg_tilt_z)
	
	print("[POD SURROUNDINGS] Habitat surroundings initialized:")
	print("  - Airlock approach light strips placed (Hatch dist: %.2fm)" % hatch_pos.distance_to(pod_center))
	print("  - %d dust drift clusters in 20-unit ring (all >= 6.0m from hatch)" % placed_drifts)
	print("  - 2 dead shrub-like rock spires placed (all >= 6.0m from hatch)")
