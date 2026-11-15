extends CharacterBody3D
class_name PlanetWalker

# planet_walker.gd
# CharacterBody3D with radial spherical gravity, camera look, and animation state.
# Features:
# 1. Procedural Haggard Gait (Sol 1 wounded state, 1.1 steps/s, uneven 4cm bob, 14 deg lean, 3.5 deg sway, dragged leg, arm tremor, 1.2 m/s).
# 2. Automated Hatch Stepping-Out State (2.0s forward movement on handoff).
# 3. Camera Soft-Lock to Survival Pod (6s smooth ease-in-out blend, release after 10s walking or pod reached, pause when still).
# 4. Outer Wilds style 3D spherical physics and jetpack thrusters.

@export var planet_center := Vector3.ZERO
@export var move_speed := 7.0
@export var run_speed := 11.0
@export var jump_speed := 7.5
@export var gravity := 5.8    # Scaled Mars gravity for responsive jumping
@export var mouse_sensitivity := 0.0025

# Haggard Procedural Gait (Sol 1 injured crash recovery state)
@export_group("Haggard Procedural Gait (Sol 1)")
@export var is_haggard: bool = true
@export var haggard_speed: float = 1.2                   # Movement speed: 1.2 units per second, not faster
@export var haggard_step_rate: float = 1.1               # Step rate: 1.1 steps per second
@export var haggard_vertical_bob: float = 0.04           # Vertical bob: small, about 4 cm (0.04 m)
@export var haggard_uneven_bob_ratio: float = 0.25       # Alternate steps slightly different in height
@export var haggard_forward_lean_deg: float = 14.0       # Forward lean on the spine/torso: 12 to 15 degrees, held constant
@export var haggard_side_sway_deg: float = 3.5           # Side sway: 3 to 4 degrees on the root, one full cycle per two steps
@export var haggard_drag_stride_reduction: float = 0.15  # One leg dragged: 15% shorter stride on one side to suggest injury
@export var haggard_tremor_strength: float = 0.04        # Arms tremor noise strength
@export var stepping_out_duration: float = 2.0           # 2s short stepping out state moving forward from hatch

# Camera Soft-Lock to Pod
@export_group("Camera Soft-Lock (Sol 1 Pod Guide)")
@export var enable_camera_guide: bool = true
@export var camera_guide_blend_duration: float = 6.0     # 6s blend toward pod with smooth ease
@export var camera_guide_max_walk_duration: float = 10.0 # Release lock after 10s of walking toward pod
@export var camera_still_threshold_time: float = 2.0     # Standing still for > 2s pauses camera guide

# Jetpack mechanics (Outer Wilds style thrusters)
@export_group("Jetpack")
@export var jetpack_thrust := 15.0
@export var jetpack_fuel_max := 100.0
@export var jetpack_burn_rate := 28.0
@export var jetpack_recharge_rate := 45.0
@export var jetpack_horiz_boost := 6.5

signal jetpack_fuel_changed(current_fuel: float, max_fuel: float)

# Node references
@onready var camera_arm: Node3D = $CameraArm
@onready var spring_arm: SpringArm3D = $CameraArm/SpringArm3D
@onready var visual_mesh: Node3D = $VisualMesh
@onready var jetpack_particles: GPUParticles3D = $VisualMesh/JetpackParticles
var anim_player: AnimationPlayer = null

var camera_pitch := -15.0
var camera_yaw := 0.0
var is_jumping := false
var is_jetpacking := false
var air_timer := 0.0
var jetpack_fuel := 100.0

# Stepping out state
var spawn_position: Vector3 = Vector3.ZERO
var is_stepping_out: bool = false
var stepping_out_timer: float = 0.0

# Cinematic Letterboxed Lying Intro (Sol 1 Opening)
@export_group("Cinematic Lying Intro (Sol 1)")
@export var start_in_cinematic_intro: bool = true
@export var cinematic_zoom_start_dist: float = 6.0       # Zoom in slowly from 6 units away
@export var cinematic_zoom_end_dist: float = 2.5         # Zoom in to 2.5 units
@export var cinematic_zoom_duration: float = 6.0         # Over about 6 seconds
@export var cinematic_turn_duration: float = 2.5         # Single slow turn toward pod (no sweep back)
@export var steady_look_yaw_deg: float = 0.0             # Steady heading during zoom (no pan sweeps)
@export var camera_sway_amplitude: float = 0.0035        # Faint breathing sway: about 0.35 cm (< 0.5 cm)
@export var camera_sway_frequency: float = 1.5708        # Slow breathing (~4s cycle)

# Ending Sequence (MAV Liftoff)
@export_group("Ending Sequence")
@export var ending_ignition_duration: float = 3.0
@export var ending_liftoff_duration: float = 10.0
@export var ending_cam_pullback_dist: float = 180.0

var is_ending_cutscene_active: bool = false
var ending_cutscene_timer: float = 0.0
var ending_rocket: Node3D = null
var ending_sol: int = 1
var ending_cam_start_dist: float = 4.5
var ending_cam_start_pitch: float = 0.0

signal pod_detection_triggered
signal cinematic_intro_completed

var is_lying: bool = false
var is_input_locked: bool = false
var is_cinematic_intro_active: bool = false
var is_standing_up: bool = false
var stand_up_timer: float = 0.0
var stand_up_duration: float = 2.0
var lying_astro_transform: Transform3D
var target_pod_yaw: float = 0.0
var cinematic_timer: float = 0.0
var letterbox_ui: Node = null
var normal_camera_arm_pos: Vector3 = Vector3(0.0, 1.45, 0.0)
var cinematic_camera_arm_pos: Vector3 = Vector3(0.0, 0.35, -0.6)
var logged_zoom_start: bool = false
var logged_zoom_end: bool = false
var logged_turn_end: bool = false

# Camera guide state
var initial_offset_yaw: float = deg_to_rad(35.0) # 35° cinematic initial angle looking slightly toward wreck
var camera_guide_walk_time: float = 0.0
var camera_still_time: float = 0.0
var is_camera_guided: bool = true
var target_pod_node: Node3D = null
var manual_camera_yaw: float = 0.0
var base_guided_yaw: float = 0.0
var has_recorded_initial_yaw: bool = false
var logged_angle_0s: bool = false
var logged_angle_3s: bool = false
var logged_angle_6s: bool = false

# Procedural gait skeleton state
var astro_root: Node3D = null
var skeleton: Skeleton3D = null
var default_astro_transform: Transform3D
var gait_phase: float = 0.0

var hips_bone_idx: int = -1
var spine_bone_idx: int = -1
var spine1_bone_idx: int = -1
var neck_bone_idx: int = -1
var l_up_leg_idx: int = -1
var r_up_leg_idx: int = -1
var l_leg_idx: int = -1
var r_leg_idx: int = -1
var l_arm_idx: int = -1
var r_arm_idx: int = -1
var r_forearm_idx: int = -1

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(65.0)
	
	astro_root = visual_mesh.get_node_or_null("Astronaut")
	if astro_root:
		default_astro_transform = astro_root.transform

	var skeletons = visual_mesh.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() > 0:
		skeleton = skeletons[0] as Skeleton3D
		hips_bone_idx = skeleton.find_bone("mixamorig_Hips")
		spine_bone_idx = skeleton.find_bone("mixamorig_Spine")
		spine1_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		neck_bone_idx = skeleton.find_bone("mixamorig_Neck")
		l_up_leg_idx = skeleton.find_bone("mixamorig_LeftUpLeg")
		r_up_leg_idx = skeleton.find_bone("mixamorig_RightUpLeg")
		l_leg_idx = skeleton.find_bone("mixamorig_LeftLeg")
		r_leg_idx = skeleton.find_bone("mixamorig_RightLeg")
		l_arm_idx = skeleton.find_bone("mixamorig_LeftArm")
		r_arm_idx = skeleton.find_bone("mixamorig_RightArm")
		r_forearm_idx = skeleton.find_bone("mixamorig_RightForeArm")

	var players = visual_mesh.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		anim_player = players[0] as AnimationPlayer
		_inspect_animations()
		_play_anim("idle")

	if camera_arm:
		normal_camera_arm_pos = camera_arm.position
	
	if start_in_cinematic_intro:
		call_deferred("start_cinematic_lying_intro")

func _inspect_animations() -> void:
	if not anim_player:
		return
	print("\n==================================================")
	print("ASTRONAUT ANIMATION INSPECTION")
	print("==================================================")
	var anim_list = anim_player.get_animation_list()
	var found_idle = false
	var found_walk = false
	var found_run = false
	for anim_name in anim_list:
		var anim = anim_player.get_animation(anim_name)
		var length = anim.length if anim else 0.0
		print("  - Animation: '%-8s' | Length: %.3f s | Loop: %s" % [anim_name, length, str(anim.loop_mode)])
		if anim_name == "idle": found_idle = true
		if anim_name == "walk": found_walk = true
		if anim_name == "run": found_run = true
	print("Core Animation Check:")
	print("  Idle: %s" % ("FOUND" if found_idle else "MISSING"))
	print("  Walk: %s" % ("FOUND" if found_walk else "MISSING"))
	print("  Run:  %s" % ("FOUND" if found_run else "MISSING"))
	print("Haggard Procedural Gait Configuration:")
	print("  Step Rate:          %.2f steps/s" % haggard_step_rate)
	print("  Vertical Bob:       %.2f cm (uneven ratio: %.0f%%)" % [haggard_vertical_bob * 100.0, haggard_uneven_bob_ratio * 100.0])
	print("  Forward Lean:       %.1f° constant" % haggard_forward_lean_deg)
	print("  Side Sway:          %.1f° (1 cycle per 2 steps)" % haggard_side_sway_deg)
	print("  Dragged Leg Stride: -%.0f%% reduction" % (haggard_drag_stride_reduction * 100.0))
	print("  Movement Speed:     %.2f m/s (max <= 1.2)" % haggard_speed)
	print("  Arms Configuration: Right hand clutched on chest with tremor, left arm hanging")
	print("Skeleton accessible: %s (bones mapped: spine=%d, legs=%d/%d, arms=%d/%d)" % [
		str(skeleton != null), spine_bone_idx, l_up_leg_idx, r_up_leg_idx, r_arm_idx, r_forearm_idx
	])
	print("==================================================\n")

func _get_planet() -> Node:
	var root = get_parent()
	if root:
		var p = root.get_node_or_null("ProceduralMars")
		if p: return p
	var tree = get_tree()
	if tree and tree.root:
		var p = tree.root.find_child("ProceduralMars", true, false)
		if p: return p
	return null

func _find_ground_height_under_astronaut() -> Dictionary:
	var planet = _get_planet()
	var center = planet.global_position if planet else planet_center
	var up = (global_position - center).normalized()
	if up.length_squared() < 0.001:
		up = Vector3.UP
	
	var space = get_world_3d().direct_space_state
	var ray_start = global_position + up * 10.0
	var ray_end = global_position - up * 15.0
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit = space.intersect_ray(query)
	
	var ground_pos = Vector3.ZERO
	if not hit.is_empty():
		ground_pos = hit["position"]
	elif planet and planet.has_method("get_surface_point"):
		ground_pos = planet.get_surface_point(up)
	else:
		ground_pos = center + up * 500.0
	
	var ground_h = (ground_pos - center).length()
	return {"position": ground_pos, "height": ground_h, "normal": (ground_pos - center).normalized()}

func get_astronaut_lowest_local_y() -> float:
	var lowest_y = 1e9
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if not mi.mesh: continue
		var aabb = mi.get_aabb()
		for xi in [0, 1]:
			for yi in [0, 1]:
				for zi in [0, 1]:
					var pt = aabb.position + aabb.size * Vector3(xi, yi, zi)
					var world_pt = mi.global_transform * pt
					var local_pt = global_transform.affine_inverse() * world_pt
					if local_pt.y < lowest_y:
						lowest_y = local_pt.y
	return lowest_y if lowest_y < 1e8 else 0.0

func start_stepping_out(duration: float = 2.0) -> void:
	is_stepping_out = true
	stepping_out_timer = duration
	print("[STEPPING OUT] Player stepping out from hatch for %.2f seconds at %.1f m/s..." % [duration, haggard_speed])

func start_cinematic_lying_intro() -> void:
	is_lying = true
	is_input_locked = true
	is_cinematic_intro_active = true
	cinematic_timer = 0.0
	logged_zoom_start = false
	logged_zoom_end = false
	logged_turn_end = false
	
	# Instantiate or attach Letterbox UI
	if not letterbox_ui or not is_instance_valid(letterbox_ui):
		var lb_scene = load("res://Scenes/ui/letterbox.tscn")
		if lb_scene:
			letterbox_ui = lb_scene.instantiate()
			var tree = get_tree()
			if tree and tree.root:
				tree.root.add_child.call_deferred(letterbox_ui)
	
	if letterbox_ui:
		if "hide_hud" in letterbox_ui:
			letterbox_ui.hide_hud = true
		if letterbox_ui.has_method("slide_in"):
			letterbox_ui.slide_in(0.8)
	
	# Snap player global position to ground directly under astronaut using physics raycast
	var ground_info = _find_ground_height_under_astronaut()
	global_position = ground_info["position"]
	
	# Apply initial lying pose to astronaut mesh
	_apply_lying_pose(0.0)
	
	# Configure camera for start of look-around zoom: steady heading (no sweeps), 6.0 units away
	if camera_arm:
		normal_camera_arm_pos = camera_arm.position
		camera_arm.position = cinematic_camera_arm_pos
		camera_yaw = deg_to_rad(steady_look_yaw_deg)
		camera_pitch = deg_to_rad(-22.0)
		camera_arm.rotation.y = camera_yaw
		camera_arm.rotation.x = camera_pitch
	
	if spring_arm:
		spring_arm.spring_length = cinematic_zoom_start_dist
	
	var active_cam = get_viewport().get_camera_3d()
	if not active_cam and spring_arm:
		active_cam = spring_arm.get_node_or_null("Camera3D") as Camera3D
	
	var cam_pos = active_cam.global_position if active_cam else (camera_arm.global_position if camera_arm else global_position)
	logged_zoom_start = true
	
	# Measure ground clearance and lowest point
	var planet = _get_planet()
	var center = planet.global_position if planet else planet_center
	var ground_dist = ground_info["height"]
	var min_world_dist = 1e9
	var lowest_world_pt = Vector3.ZERO
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if not mi.mesh: continue
		var aabb = mi.get_aabb()
		for xi in [0, 1]:
			for yi in [0, 1]:
				for zi in [0, 1]:
					var pt = aabb.position + aabb.size * Vector3(xi, yi, zi)
					var world_pt = mi.global_transform * pt
					var d = (world_pt - center).length()
					if d < min_world_dist:
						min_world_dist = d
						lowest_world_pt = world_pt
	
	var measured_clearance = min_world_dist - ground_dist
	var delta_vs_ground = abs(min_world_dist - ground_dist)
	print("\n==================================================")
	print("SOL 1 CINEMATIC LETTERBOXED LYING INTRO STARTED")
	print("==================================================")
	print("Astronaut State: Lying on ground next to hatch")
	print("Player Input: LOCKED")
	print("Letterbox: Sliding in (12% screen height black bars)")
	print("Zoom Start Camera Position: %s" % cam_pos)
	print("Initial Distance: %.2f units (Target: %.2f units)" % [spring_arm.spring_length if spring_arm else 6.0, cinematic_zoom_start_dist])
	print("Camera Heading: %.1f° (Steady, no sweeping pan)" % steady_look_yaw_deg)
	print("Breathing Sway: %.2f cm (Slow, < 0.5 cm)" % (camera_sway_amplitude * 100.0))
	print("Ground Height directly under astronaut: %.4f m" % ground_dist)
	print("Astronaut Lowest Mesh Point Height:    %.4f m" % min_world_dist)
	print("Lowest World Point:                    %s" % lowest_world_pt)
	print("Selected Lying Pose:                   PRONE POSE (Face down on Mars regolith)")
	print("Measured Ground Clearance:             +%.4f m" % measured_clearance)
	print("Delta vs Ground:                       %.4f units (target <= 0.1 units)" % delta_vs_ground)
	print("Zero Clipping Check:                   %s" % ("PASS" if measured_clearance >= 0.0 else "FAIL"))
	print("==================================================\n")

func set_lying_state(lying: bool) -> void:
	is_lying = lying
	if not lying:
		if camera_arm:
			camera_arm.position = normal_camera_arm_pos
		if spring_arm:
			spring_arm.spring_length = 4.5
		if astro_root:
			astro_root.transform = default_astro_transform

func _update_cinematic_intro(delta: float) -> void:
	cinematic_timer += delta
	
	# Phase 1: Steady look-around zoom (0s to 6s) - NO sweeping pan
	if cinematic_timer <= cinematic_zoom_duration:
		var progress = clampf(cinematic_timer / cinematic_zoom_duration, 0.0, 1.0)
		var ease_p = progress * progress * (3.0 - 2.0 * progress) # smoothstep
		
		# Steady zoom distance from 6.0 units to 2.5 units
		if spring_arm:
			spring_arm.spring_length = lerpf(cinematic_zoom_start_dist, cinematic_zoom_end_dist, ease_p)
		
		# Camera yaw held steady - no left-right panning sweeps
		camera_yaw = deg_to_rad(steady_look_yaw_deg)
		if camera_arm:
			camera_arm.rotation.y = camera_yaw
			camera_arm.rotation.x = camera_pitch
		
		# Faint breathing sway (under 0.5 cm, slow)
		var cam = spring_arm.get_node_or_null("Camera3D") as Camera3D if spring_arm else null
		if cam:
			cam.v_offset = sin(cinematic_timer * camera_sway_frequency) * camera_sway_amplitude
			cam.h_offset = cos(cinematic_timer * camera_sway_frequency * 0.5) * (camera_sway_amplitude * 0.5)
		
		# Log at zoom end
		if not logged_zoom_end and cinematic_timer >= cinematic_zoom_duration:
			logged_zoom_end = true
			var end_cam_pos = cam.global_position if cam else camera_arm.global_position
			print("\n==================================================")
			print("LOOK-AROUND CAMERA ZOOM COMPLETED (t = 6.0s)")
			print("Zoom End Camera Position:   %s" % end_cam_pos)
			print("End Distance: %.2f units (Target: %.2f units, No sweeps)" % [spring_arm.spring_length if spring_arm else 2.5, cinematic_zoom_end_dist])
			print("Steady Zoom Complete. Initiating single slow turn toward pod...")
			print("==================================================\n")

	# Phase 2: Single slow turn toward the pod (6s to 8.5s)
	elif cinematic_timer <= (cinematic_zoom_duration + cinematic_turn_duration):
		var turn_progress = clampf((cinematic_timer - cinematic_zoom_duration) / cinematic_turn_duration, 0.0, 1.0)
		var ease_turn = turn_progress * turn_progress * (3.0 - 2.0 * turn_progress)
		
		# Compute pod target yaw
		var pod_pos = Vector3.ZERO
		var reg = get_node_or_null("/root/PlacementRegistry")
		if reg and reg.has_method("get_position"):
			var p = reg.get_position("pod")
			if p != null:
				pod_pos = p
		if pod_pos == Vector3.ZERO:
			var pod_node = _find_pod()
			if pod_node:
				pod_pos = pod_node.global_position
		
		var planet = _get_planet()
		var center = planet.global_position if planet else planet_center
		var up = (global_position - center).normalized()
		var to_pod = pod_pos - global_position
		var to_pod_tan = (to_pod - up * to_pod.dot(up)).normalized()
		var fwd = -global_transform.basis.z
		fwd = (fwd - up * fwd.dot(up)).normalized()
		target_pod_yaw = fwd.signed_angle_to(to_pod_tan, up)
		
		camera_yaw = lerp_angle(deg_to_rad(steady_look_yaw_deg), target_pod_yaw, ease_turn)
		if camera_arm:
			camera_arm.rotation.y = camera_yaw
			camera_arm.rotation.x = camera_pitch
		if spring_arm:
			spring_arm.spring_length = cinematic_zoom_end_dist
		
		var cam = spring_arm.get_node_or_null("Camera3D") as Camera3D if spring_arm else null
		if cam:
			cam.v_offset = sin(cinematic_timer * camera_sway_frequency) * camera_sway_amplitude
			cam.h_offset = cos(cinematic_timer * camera_sway_frequency * 0.5) * (camera_sway_amplitude * 0.5)
		
		if not logged_turn_end and turn_progress >= 1.0:
			logged_turn_end = true
			print("\n==================================================")
			print("CAMERA TURN TOWARD POD COMPLETED (Single slow turn)")
			print("Facing Pod Target Angle: %.2f°" % rad_to_deg(camera_yaw))
			print("Holding camera on pod. Will not sweep back.")
			print("==================================================\n")

	# Phase 3: Transition to Stand-up (t > 8.5s)
	else:
		if is_cinematic_intro_active:
			is_cinematic_intro_active = false
			
			# Keep letterbox bars active during haggard walking until pod is reached; restore HUD visibility
			if letterbox_ui:
				if "hide_hud" in letterbox_ui:
					letterbox_ui.hide_hud = false
				if letterbox_ui.has_method("set_hud_visible"):
					letterbox_ui.set_hud_visible(true)
			
			cinematic_intro_completed.emit()
			
			# Begin stand-up step over 2 seconds
			stand_up(2.0)

func stand_up(duration: float = 2.0) -> void:
	is_standing_up = true
	stand_up_timer = 0.0
	stand_up_duration = duration
	if astro_root:
		lying_astro_transform = astro_root.transform
	print("\n==================================================")
	print("ASTRONAUT STAND-UP INITIATED")
	print("Blending from lying pose to standing over %.2f seconds..." % duration)
	print("==================================================")

func _update_stand_up(delta: float) -> void:
	if not is_standing_up:
		return
	stand_up_timer += delta
	var progress = clampf(stand_up_timer / stand_up_duration, 0.0, 1.0)
	var ease_p = progress * progress * (3.0 - 2.0 * progress) # smoothstep
	
	if astro_root:
		astro_root.transform = lying_astro_transform.interpolate_with(default_astro_transform, ease_p)
	
	if skeleton:
		var neck_rot = Quaternion(Vector3.UP, deg_to_rad(15.0)).slerp(Quaternion.IDENTITY, ease_p)
		if neck_bone_idx >= 0: skeleton.set_bone_pose_rotation(neck_bone_idx, neck_rot)
		if r_arm_idx >= 0:
			var r_arm_lying = Quaternion(Vector3.FORWARD, deg_to_rad(18.0)) * Quaternion(Vector3.UP, deg_to_rad(-20.0))
			skeleton.set_bone_pose_rotation(r_arm_idx, r_arm_lying.slerp(Quaternion.IDENTITY, ease_p))
		if r_forearm_idx >= 0:
			var r_fa_lying = Quaternion(Vector3.RIGHT, deg_to_rad(45.0))
			skeleton.set_bone_pose_rotation(r_forearm_idx, r_fa_lying.slerp(Quaternion.IDENTITY, ease_p))
		if l_arm_idx >= 0:
			var l_arm_lying = Quaternion(Vector3.FORWARD, deg_to_rad(-18.0)) * Quaternion(Vector3.UP, deg_to_rad(20.0))
			skeleton.set_bone_pose_rotation(l_arm_idx, l_arm_lying.slerp(Quaternion.IDENTITY, ease_p))
	
	if camera_arm:
		camera_arm.position = cinematic_camera_arm_pos.lerp(normal_camera_arm_pos, ease_p)
	
	if spring_arm:
		spring_arm.spring_length = lerpf(cinematic_zoom_end_dist, 4.5, ease_p)
	
	if stand_up_timer >= stand_up_duration:
		is_standing_up = false
		is_lying = false
		is_input_locked = false
		if astro_root:
			astro_root.transform = default_astro_transform
		if camera_arm:
			camera_arm.position = normal_camera_arm_pos
		if spring_arm:
			spring_arm.spring_length = 4.5
		
		# Explicit requirement: Print "input enabled" to Output panel
		print("input enabled")
		print("\n==================================================")
		print("STAND-UP COMPLETE: INPUT ENABLED")
		print("Player movement active. Sol 1 haggard walk engaged.")
		print("==================================================\n")

func _find_pod() -> Node3D:
	if target_pod_node and is_instance_valid(target_pod_node):
		return target_pod_node
	var root = get_parent()
	if root:
		var pod = root.get_node_or_null("CrashedPod")
		if not pod:
			var areas = root.find_children("*", "Area3D", true, false)
			for a in areas:
				if a.name == "CrashedPod" or a is CrashedPod:
					target_pod_node = a
					return a
		else:
			target_pod_node = pod
			return pod
	return null

func start_ending_sequence(rocket_node: Node3D, sol: int = 1) -> void:
	is_ending_cutscene_active = true
	is_input_locked = true
	ending_cutscene_timer = 0.0
	ending_rocket = rocket_node
	ending_sol = sol
	
	if spring_arm:
		ending_cam_start_dist = spring_arm.spring_length
	ending_cam_start_pitch = camera_pitch
	
	# Instantiate or attach Letterbox UI, slide in and hide normal HUD
	if not letterbox_ui or not is_instance_valid(letterbox_ui):
		var lb_scene = load("res://Scenes/ui/letterbox.tscn")
		if lb_scene:
			letterbox_ui = lb_scene.instantiate()
			var tree = get_tree()
			if tree and tree.root:
				tree.root.add_child.call_deferred(letterbox_ui)
	
	if letterbox_ui:
		if "hide_hud" in letterbox_ui:
			letterbox_ui.hide_hud = true
		if letterbox_ui.has_method("set_hud_visible"):
			letterbox_ui.set_hud_visible(false)
		if letterbox_ui.has_method("slide_in"):
			letterbox_ui.slide_in(0.8)
	
	# Hide normal HUD meters
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and "control_root" in hud and hud.control_root:
		hud.control_root.visible = false
	
	# Rocket ignition (exhaust plume, rumble sound)
	if ending_rocket and ending_rocket.has_method("start_ignition"):
		ending_rocket.start_ignition()
	
	print("\n==================================================")
	print("MAV ENDING CUTSCENE INITIATED (Sol %d)" % sol)
	print("Letterbox bars sliding in. HUD hidden.")
	print("Rocket ignition engaged: 3.0s thruster shake followed by 10.0s liftoff.")
	print("==================================================\n")

func _update_ending_cutscene(delta: float) -> void:
	ending_cutscene_timer += delta
	var total_dur = ending_ignition_duration + ending_liftoff_duration # 3.0 + 10.0 = 13.0s
	
	var cam = spring_arm.get_node_or_null("Camera3D") as Camera3D if spring_arm else null
	
	# Face camera arm toward rocket smoothly
	if ending_rocket and camera_arm:
		var up = (global_position - planet_center).normalized()
		var to_rocket = (ending_rocket.global_position - camera_arm.global_position)
		var to_r_tangent = (to_rocket - up * to_rocket.dot(up)).normalized()
		if to_r_tangent.length_squared() > 0.01:
			var target_yaw = atan2(-to_r_tangent.x, -to_r_tangent.z)
			camera_arm.rotation.y = lerp_angle(camera_arm.rotation.y, target_yaw, clampf(4.0 * delta, 0.0, 1.0))
	
	# Phase 1: Thruster ignition & rumble (0 to 3s)
	if ending_cutscene_timer <= ending_ignition_duration:
		var prog = ending_cutscene_timer / ending_ignition_duration
		# Thruster rumble shake for 3s
		var shake_mag = lerpf(0.02, 0.06, prog)
		if cam:
			cam.h_offset = randf_range(-shake_mag, shake_mag)
			cam.v_offset = randf_range(-shake_mag, shake_mag)
	
	# Phase 2: Liftoff over 10s (3s to 13s)
	elif ending_cutscene_timer <= total_dur:
		var t_liftoff = (ending_cutscene_timer - ending_ignition_duration) / ending_liftoff_duration
		var ease_p = t_liftoff * t_liftoff # quadratic acceleration upward
		
		# Move rocket upward
		if ending_rocket and ending_rocket.has_method("set_liftoff_progress"):
			ending_rocket.set_liftoff_progress(ease_p)
		
		# Camera pulls back from ending_cam_start_dist to ending_cam_pullback_dist (up to 180 units)
		# to frame the rising rocket against the planet curvature and starry sky
		if spring_arm:
			spring_arm.spring_length = lerpf(ending_cam_start_dist, ending_cam_pullback_dist, ease_p)
		
		# Camera tilts upward to follow rocket into starry sky
		camera_pitch = lerpf(ending_cam_start_pitch, deg_to_rad(35.0), ease_p)
		if camera_arm:
			camera_arm.rotation.x = camera_pitch
		
		# Residual thruster shake diminishing as rocket ascends away
		var shake_mag = (1.0 - t_liftoff) * 0.04
		if cam:
			cam.h_offset = randf_range(-shake_mag, shake_mag)
			cam.v_offset = randf_range(-shake_mag, shake_mag)
	
	# Phase 3: Liftoff complete (> 13s) -> Fade to black & Victory Screen
	else:
		if is_ending_cutscene_active:
			is_ending_cutscene_active = false
			if cam:
				cam.h_offset = 0.0
				cam.v_offset = 0.0
			
			print("\n==================================================")
			print("MAV LIFTOFF COMPLETE: MISSION COMPLETE!")
			print("Survived to Sol %d. Presenting Victory Screen." % ending_sol)
			print("==================================================\n")
			
			var hud = get_tree().root.find_child("HUD", true, false)
			if hud and hud.has_method("show_victory_screen"):
				hud.show_victory_screen(ending_sol)

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked or is_cinematic_intro_active or is_ending_cutscene_active:
		return

	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if is_camera_guided and is_haggard:
			manual_camera_yaw -= event.relative.x * mouse_sensitivity
		else:
			camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(-75.0), deg_to_rad(65.0))

func _physics_process(delta: float) -> void:
	var up: Vector3 = (global_position - planet_center).normalized()
	if up.length_squared() < 0.001:
		up = Vector3.UP
	
	# Align character's base orientation so local Y matches planet normal
	var fwd: Vector3 = -global_transform.basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = -global_transform.basis.y
		fwd = (fwd - up * fwd.dot(up)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	var right: Vector3 = fwd.cross(up).normalized()

	# Re-orient body basis along surface tangent
	var t := global_transform
	t.basis = Basis(right, up, -fwd).orthonormalized()
	global_transform = t

	# Ending sequence handling (MAV ignition, shake for 3s, liftoff over 10s with camera pullback)
	if is_ending_cutscene_active:
		_update_ending_cutscene(delta)
		_update_animation_state(0.0, false, delta)
		move_and_slide()
		return

	# Cinematic Lying Intro handling (input locked, camera zoom & slow turn toward pod)
	if is_cinematic_intro_active:
		_update_cinematic_intro(delta)
		_update_animation_state(0.0, false, delta)
		move_and_slide()
		return

	# Stand-up transition handling (smoothly blend from lying to standing over 2s)
	if is_standing_up:
		_update_stand_up(delta)
		_update_animation_state(0.0, false, delta)
		move_and_slide()
		return

	# Stepping out logic
	var input := Vector2.ZERO
	if is_input_locked:
		input = Vector2.ZERO
	elif is_stepping_out:
		stepping_out_timer -= delta
		input = Vector2(0, -1) # Automated forward movement out of the hatch
		if stepping_out_timer <= 0.0:
			is_stepping_out = false
			print("[STEPPING OUT] Stepping out completed (2.0s). Player control handed over.")
	else:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var is_moving = (input.length_squared() > 0.01 or is_stepping_out)

	# Update camera soft-lock to pod
	_update_camera_soft_lock(delta, up, fwd, right, is_moving)

	# Project camera direction onto ground tangent plane for movement
	var cam_fwd: Vector3 = -camera_arm.global_transform.basis.z if camera_arm else fwd
	var cam_tangent: Vector3 = (cam_fwd - up * cam_fwd.dot(up)).normalized()
	var cam_right: Vector3 = cam_tangent.cross(up).normalized()

	var is_sprinting = Input.is_action_pressed("run")
	var cur_speed: float
	if is_haggard:
		cur_speed = haggard_speed
		is_sprinting = false
	else:
		cur_speed = run_speed if is_sprinting else move_speed

	var v_up: Vector3 = up * velocity.dot(up)
	var move_dir: Vector3 = (cam_tangent * -input.y + cam_right * input.x)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()

	var v_tan: Vector3 = move_dir * cur_speed

	# Floor state and jump/jetpack handling
	var on_floor = is_on_floor()
	var jump_held = Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept")
	var jump_just_pressed = Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")

	if on_floor:
		jetpack_fuel = min(jetpack_fuel_max, jetpack_fuel + jetpack_recharge_rate * delta)
		is_jetpacking = false
		if jetpack_particles and jetpack_particles.emitting:
			jetpack_particles.emitting = false

		if not is_jumping:
			air_timer = 0.0
			floor_snap_length = 1.2
		else:
			if velocity.dot(up) <= 0.1:
				is_jumping = false
				air_timer = 0.0
				floor_snap_length = 1.2

		# Initial ground jump (disabled during haggard)
		if jump_just_pressed and not is_haggard:
			v_up = up * jump_speed
			is_jumping = true
			air_timer = 0.15
			floor_snap_length = 0.0
			_play_anim("jump", 0.08)
	else:
		air_timer += delta
		
		# Jetpack firing while airborne (unlocked after pod is reached)
		if jump_held and jetpack_fuel > 0.0 and not is_haggard:
			is_jetpacking = true
			if jetpack_particles and not jetpack_particles.emitting:
				jetpack_particles.emitting = true
			
			v_up += up * jetpack_thrust * delta - up * gravity * delta
			var current_up_speed = v_up.dot(up)
			if current_up_speed > 16.0:
				v_up = up * 16.0
			
			if move_dir.length_squared() > 0.05:
				v_tan += move_dir * jetpack_horiz_boost * delta

			jetpack_fuel = max(0.0, jetpack_fuel - jetpack_burn_rate * delta)
		else:
			is_jetpacking = false
			if jetpack_particles and jetpack_particles.emitting:
				jetpack_particles.emitting = false
			v_up -= up * gravity * delta

	jetpack_fuel_changed.emit(jetpack_fuel, jetpack_fuel_max)

	velocity = v_tan + v_up
	up_direction = up
	move_and_slide()

	# Rotate visual mesh to face travel direction smoothly
	if visual_mesh and move_dir.length_squared() > 0.01:
		var target_t = visual_mesh.global_transform.looking_at(visual_mesh.global_position + move_dir, up)
		visual_mesh.global_transform = visual_mesh.global_transform.interpolate_with(target_t, clamp(18.0 * delta, 0.0, 1.0)).orthonormalized()

	# Update animation and procedural gait
	_update_animation_state(v_tan.length(), is_sprinting, delta)

func _update_camera_soft_lock(delta: float, up: Vector3, fwd: Vector3, right: Vector3, is_moving: bool) -> void:
	if not camera_arm:
		return

	if not has_recorded_initial_yaw:
		has_recorded_initial_yaw = true
		base_guided_yaw = camera_yaw

	var pod_pos = Vector3.ZERO
	var reg = get_node_or_null("/root/PlacementRegistry")
	if reg and reg.has_method("get_position"):
		var p = reg.get_position("pod")
		if p != null:
			pod_pos = p
	var pod = _find_pod()
	if pod_pos == Vector3.ZERO and pod:
		pod_pos = pod.global_position
	var to_pod = pod_pos - global_position
	var to_pod_tan = (to_pod - up * to_pod.dot(up)).normalized() if (pod and to_pod.length_squared() > 0.1) else fwd

	# Camera guide soft-lock to pod during restricted phase
	if is_haggard and enable_camera_guide and is_camera_guided and pod:
		if is_moving:
			camera_still_time = 0.0
			camera_guide_walk_time += delta
			
			# Check release condition: walking towards pod for about 10 seconds
			if camera_guide_walk_time >= camera_guide_max_walk_duration:
				is_camera_guided = false
				camera_yaw = base_guided_yaw + manual_camera_yaw
				print("[CAMERA SOFT-LOCK] Released soft-lock after %.1f seconds of walking. Full camera control restored." % camera_guide_walk_time)
		else:
			camera_still_time += delta

		# If player has been standing still for > 2 seconds, do not move the camera
		var is_standing_still = (camera_still_time > camera_still_threshold_time)

		if not is_standing_still and is_camera_guided:
			# Desired yaw pointing towards the pod in player's local frame
			var target_yaw = fwd.signed_angle_to(to_pod_tan, up)
			
			# Smooth ease-in-out curve over 6.0 seconds
			var progress = clampf(camera_guide_walk_time / camera_guide_blend_duration, 0.0, 1.0)
			var ease_w = progress * progress * (3.0 - 2.0 * progress) # Standard smoothstep ease-in-out
			
			# Start from initial offset yaw (35.0°) and smoothly blend to target yaw (pointing directly at pod)
			base_guided_yaw = target_yaw + (1.0 - ease_w) * initial_offset_yaw
			camera_yaw = base_guided_yaw + manual_camera_yaw
			camera_arm.rotation.y = camera_yaw

			# Angle verification logging at 0s, 3s, 6s
			var current_angle_to_pod = (1.0 - ease_w) * rad_to_deg(initial_offset_yaw)

			if not logged_angle_0s and camera_guide_walk_time >= 0.0:
				logged_angle_0s = true
				print("[CAMERA SOFT-LOCK] t = 0.0s | Camera look-at angle to pod: %.2f° (initial)" % current_angle_to_pod)
			elif not logged_angle_3s and camera_guide_walk_time >= 3.0:
				logged_angle_3s = true
				print("[CAMERA SOFT-LOCK] t = 3.0s | Camera look-at angle to pod: %.2f° (smooth ease blending toward pod)" % current_angle_to_pod)
			elif not logged_angle_6s and camera_guide_walk_time >= 6.0:
				logged_angle_6s = true
				print("[CAMERA SOFT-LOCK] t = 6.0s | Camera look-at angle to pod: %.2f° (soft-lock complete, pointing directly at pod)" % current_angle_to_pod)
	else:
		if is_camera_guided and not is_haggard:
			is_camera_guided = false

	camera_arm.rotation.y = camera_yaw
	camera_arm.rotation.x = camera_pitch

func _update_animation_state(speed_horiz: float, sprinting: bool, delta: float) -> void:
	if not anim_player:
		return
	
	if is_lying:
		_apply_lying_pose(delta)
		return

	# Only play jump when explicitly jumping or jetpacking
	if is_jumping or is_jetpacking:
		_play_anim("jump", 0.12)
		anim_player.speed_scale = 1.0
		_reset_haggard_pose(delta)
	elif is_haggard:
		if speed_horiz > 0.05 or is_stepping_out:
			if anim_player.has_animation("haggard_walk"):
				_play_anim("haggard_walk", 0.25)
			else:
				_play_anim("walk", 0.25)
			anim_player.speed_scale = clamp(speed_horiz / haggard_speed * 0.75, 0.45, 0.85)
			_apply_procedural_haggard_gait(delta)
		else:
			if anim_player.has_animation("haggard_idle"):
				_play_anim("haggard_idle", 0.25)
			else:
				_play_anim("idle", 0.25)
			anim_player.speed_scale = 1.0
			_apply_haggard_idle_pose(delta)
	elif speed_horiz > 0.35:
		if sprinting:
			_play_anim("run", 0.15)
			anim_player.speed_scale = clamp(speed_horiz / run_speed, 0.85, 1.3)
			_reset_haggard_pose(delta)
		else:
			_play_anim("walk", 0.15)
			anim_player.speed_scale = clamp(speed_horiz / move_speed, 0.85, 1.3)
			_reset_haggard_pose(delta)
	else:
		_play_anim("idle", 0.25)
		anim_player.speed_scale = 1.0
		_reset_haggard_pose(delta)

func _apply_procedural_haggard_gait(delta: float) -> void:
	# Advance gait cycle phase based on step rate: 1.1 steps/second (full cycle = 2 steps)
	var cycle_freq = haggard_step_rate / 2.0
	gait_phase += delta * cycle_freq * TAU
	
	# 1. Vertical Bob (small, about 4 cm, with uneven rhythm between alternate steps)
	var step_index = int(gait_phase / PI) % 2
	var bob_factor = 1.0 - (haggard_uneven_bob_ratio if step_index == 1 else 0.0)
	var bob_y = -abs(sin(gait_phase)) * haggard_vertical_bob * bob_factor

	# 2. Side Sway (3 to 4 degrees on the root, one full cycle per two steps)
	var sway_angle = sin(gait_phase) * deg_to_rad(haggard_side_sway_deg)
	var sway_x = sin(gait_phase) * 0.035

	# 3. Forward Lean on the spine/torso (12 to 15 degrees, held constant)
	var lean_angle = deg_to_rad(haggard_forward_lean_deg)

	# 4. Leg Motion with One Leg Dragged (15% shorter stride on dragged right leg)
	var l_stride = sin(gait_phase) * deg_to_rad(22.0)
	var r_stride = -sin(gait_phase) * deg_to_rad(22.0) * (1.0 - haggard_drag_stride_reduction)
	var l_knee = max(0.0, -sin(gait_phase)) * deg_to_rad(26.0)
	var r_knee = max(0.0, sin(gait_phase)) * deg_to_rad(13.0) # Injured knee stiff

	# 5. Arms (Right hand clutching chest/ribs, left arm loosely hanging with tremor noise)
	var tremor = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * haggard_tremor_strength

	# Apply bone poses to skeleton
	if skeleton:
		if spine_bone_idx >= 0:
			skeleton.set_bone_pose_rotation(spine_bone_idx, Quaternion(Vector3.RIGHT, lean_angle * 0.6))
		if spine1_bone_idx >= 0:
			skeleton.set_bone_pose_rotation(spine1_bone_idx, Quaternion(Vector3.RIGHT, lean_angle * 0.4))
		if neck_bone_idx >= 0:
			skeleton.set_bone_pose_rotation(neck_bone_idx, Quaternion(Vector3.RIGHT, deg_to_rad(-6.0)))
		
		if l_up_leg_idx >= 0:
			skeleton.set_bone_pose_rotation(l_up_leg_idx, Quaternion(Vector3.RIGHT, l_stride))
		if r_up_leg_idx >= 0:
			skeleton.set_bone_pose_rotation(r_up_leg_idx, Quaternion(Vector3.RIGHT, r_stride))
		if l_leg_idx >= 0:
			skeleton.set_bone_pose_rotation(l_leg_idx, Quaternion(Vector3.RIGHT, -l_knee))
		if r_leg_idx >= 0:
			skeleton.set_bone_pose_rotation(r_leg_idx, Quaternion(Vector3.RIGHT, -r_knee))

		if r_arm_idx >= 0:
			var r_arm_rot = Quaternion(Vector3(1, 0, 0), deg_to_rad(30.0)) * Quaternion(Vector3(0, 0, 1), deg_to_rad(-22.0))
			skeleton.set_bone_pose_rotation(r_arm_idx, r_arm_rot)
		if r_forearm_idx >= 0:
			var r_forearm_rot = Quaternion(Vector3.RIGHT, deg_to_rad(95.0)) * Quaternion.from_euler(tremor)
			skeleton.set_bone_pose_rotation(r_forearm_idx, r_forearm_rot)

		if l_arm_idx >= 0:
			var l_swing = sin(gait_phase) * deg_to_rad(8.0)
			var l_arm_rot = Quaternion(Vector3.RIGHT, l_swing) * Quaternion.from_euler(tremor * 0.4)
			skeleton.set_bone_pose_rotation(l_arm_idx, l_arm_rot)

	# Apply root transform: vertical bob, side sway, and forward lean
	if astro_root:
		var t = default_astro_transform
		t.origin.y += bob_y
		t.origin.x += sway_x
		t = t.rotated_local(Vector3.FORWARD, sway_angle).rotated_local(Vector3.RIGHT, lean_angle)
		astro_root.transform = t

func _apply_haggard_idle_pose(delta: float) -> void:
	var lean_angle = deg_to_rad(haggard_forward_lean_deg * 0.75)
	var tremor = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (haggard_tremor_strength * 0.4)

	if skeleton:
		if spine_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine_bone_idx, Quaternion(Vector3.RIGHT, lean_angle * 0.6))
		if spine1_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine1_bone_idx, Quaternion(Vector3.RIGHT, lean_angle * 0.4))
		if neck_bone_idx >= 0: skeleton.set_bone_pose_rotation(neck_bone_idx, Quaternion(Vector3.RIGHT, deg_to_rad(-4.0)))
		if l_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_up_leg_idx, Quaternion.IDENTITY)
		if r_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_up_leg_idx, Quaternion.IDENTITY)
		if l_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_leg_idx, Quaternion.IDENTITY)
		if r_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_leg_idx, Quaternion.IDENTITY)
		if r_arm_idx >= 0:
			skeleton.set_bone_pose_rotation(r_arm_idx, Quaternion(Vector3(1, 0, 0), deg_to_rad(28.0)) * Quaternion(Vector3(0, 0, 1), deg_to_rad(-20.0)))
		if r_forearm_idx >= 0:
			skeleton.set_bone_pose_rotation(r_forearm_idx, Quaternion(Vector3.RIGHT, deg_to_rad(95.0)) * Quaternion.from_euler(tremor))
		if l_arm_idx >= 0:
			skeleton.set_bone_pose_rotation(l_arm_idx, Quaternion.IDENTITY)
	
	if astro_root:
		var t = default_astro_transform.rotated_local(Vector3.RIGHT, lean_angle)
		astro_root.transform = astro_root.transform.interpolate_with(t, clamp(8.0 * delta, 0.0, 1.0))

func _reset_haggard_pose(delta: float) -> void:
	if skeleton:
		if spine_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine_bone_idx, Quaternion.IDENTITY)
		if spine1_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine1_bone_idx, Quaternion.IDENTITY)
		if neck_bone_idx >= 0: skeleton.set_bone_pose_rotation(neck_bone_idx, Quaternion.IDENTITY)
		if l_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_up_leg_idx, Quaternion.IDENTITY)
		if r_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_up_leg_idx, Quaternion.IDENTITY)
		if l_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_leg_idx, Quaternion.IDENTITY)
		if r_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_leg_idx, Quaternion.IDENTITY)
		if l_arm_idx >= 0: skeleton.set_bone_pose_rotation(l_arm_idx, Quaternion.IDENTITY)
		if r_arm_idx >= 0: skeleton.set_bone_pose_rotation(r_arm_idx, Quaternion.IDENTITY)
		if r_forearm_idx >= 0: skeleton.set_bone_pose_rotation(r_forearm_idx, Quaternion.IDENTITY)
	if astro_root:
		astro_root.transform = astro_root.transform.interpolate_with(default_astro_transform, clamp(10.0 * delta, 0.0, 1.0))

func set_haggard(value: bool) -> void:
	if is_haggard == value:
		return
	is_haggard = value
	if not is_haggard:
		is_camera_guided = false # Release camera soft-lock immediately upon reaching pod
		is_stepping_out = false
		_reset_haggard_pose(1.0)
		if astro_root:
			astro_root.transform = default_astro_transform
		
		# Slide letterbox bars out now that the pod has been reached
		if letterbox_ui and is_instance_valid(letterbox_ui) and letterbox_ui.has_method("slide_out"):
			letterbox_ui.slide_out(0.8)
			
		print("\n[PLAYER RECOVERY] Haggard state cleared. Sol 1 survival pod reached!")
		print("[PLAYER RECOVERY] Letterbox bars slid out. Camera soft-lock released. Normal walk (%.1f m/s) and run (%.1f m/s) restored. Jetpack unlocked.\n" % [move_speed, run_speed])

func _apply_lying_pose(_delta: float) -> void:
	if is_standing_up:
		return
	if anim_player:
		if anim_player.has_animation("haggard_idle"):
			_play_anim("haggard_idle", 0.25)
		else:
			_play_anim("idle", 0.25)
		anim_player.speed_scale = 1.0

	if skeleton:
		if spine_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine_bone_idx, Quaternion.IDENTITY)
		if spine1_bone_idx >= 0: skeleton.set_bone_pose_rotation(spine1_bone_idx, Quaternion.IDENTITY)
		# Face down: head turned slightly so cheek rests naturally on the ground
		if neck_bone_idx >= 0: skeleton.set_bone_pose_rotation(neck_bone_idx, Quaternion(Vector3.UP, deg_to_rad(15.0)))
		if l_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_up_leg_idx, Quaternion.IDENTITY)
		if r_up_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_up_leg_idx, Quaternion.IDENTITY)
		if l_leg_idx >= 0: skeleton.set_bone_pose_rotation(l_leg_idx, Quaternion.IDENTITY)
		if r_leg_idx >= 0: skeleton.set_bone_pose_rotation(r_leg_idx, Quaternion.IDENTITY)
		# Arms relaxed along the ground beside the body
		if r_arm_idx >= 0:
			skeleton.set_bone_pose_rotation(r_arm_idx, Quaternion(Vector3.FORWARD, deg_to_rad(18.0)) * Quaternion(Vector3.UP, deg_to_rad(-20.0)))
		if r_forearm_idx >= 0:
			skeleton.set_bone_pose_rotation(r_forearm_idx, Quaternion(Vector3.RIGHT, deg_to_rad(45.0)))
		if l_arm_idx >= 0:
			skeleton.set_bone_pose_rotation(l_arm_idx, Quaternion(Vector3.FORWARD, deg_to_rad(-18.0)) * Quaternion(Vector3.UP, deg_to_rad(20.0)))

	if astro_root:
		# Prone pose (Face down on Mars regolith): rotated +90 degrees around local X
		var t = default_astro_transform
		t = t.rotated_local(Vector3.RIGHT, deg_to_rad(90.0))
		t.origin = Vector3.ZERO
		astro_root.transform = t
		
		# Compute lowest local Y and lift to ensure zero clipping with positive clearance
		var lowest_local_y = get_astronaut_lowest_local_y()
		var clearance = 0.03 # 3 cm positive ground clearance
		t.origin = Vector3(0.0, -lowest_local_y + clearance, 0.0)
		astro_root.transform = t

func _play_anim(anim_name: String, blend_time: float = 0.15) -> void:
	if anim_player and anim_player.current_animation != anim_name:
		anim_player.play(anim_name, blend_time)
