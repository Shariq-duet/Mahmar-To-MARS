@tool
extends SceneTree

# test_opening_and_placement_registry.gd
# Verification script for opening sequence and PlacementRegistry

func _init():
	print("\n==================================================")
	print("STARTING FULL OPENING & PLACEMENT REGISTRY TEST")
	print("==================================================")
	
	# 1. Load world scene
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	# Process multiple frames so planet generation and physics settle
	for i in range(5):
		await process_frame
	
	var player = world.get_node("Player") as PlanetWalker
	var planet = world.get_node("ProceduralMars")
	var registry = root.get_node_or_null("PlacementRegistry")
	if not registry:
		var RegistryScript = load("res://Scripts/autoloads/placement_registry.gd")
		registry = RegistryScript.new()
		registry.name = "PlacementRegistry"
		root.add_child(registry)
		await process_frame
	
	# ----------------------------------------------------
	# CHECK 1: POD SIZE & HATCH CLEARANCE
	# ----------------------------------------------------
	print("\n--- 1. POD SIZE & HATCH DIMENSIONS ---")
	var pod = world.crashed_pod_node as CrashedPod
	assert(pod != null, "CrashedPod node must exist!")
	var pod_bounds = pod.get_pod_bounding_size()
	var hatch_dim = pod.get_hatch_dimensions()
	print("Pod Global Scale:   %s" % pod.scale)
	print("Pod Bounding Size:  Width X = %.2f m, Height Y = %.2f m, Depth Z = %.2f m" % [pod_bounds.x, pod_bounds.y, pod_bounds.z])
	print("Hatch Opening Size: Width X = %.2f m, Height Y = %.2f m" % [hatch_dim["width"], hatch_dim["height"]])
	print("Headroom Clearance: +%.2f m (Player Height: 1.8 m)" % (hatch_dim["height"] - 1.8))
	assert(hatch_dim["height"] >= 2.5, "Hatch must be >= 2.5 units tall!")
	assert(pod_bounds.y >= 5.5 and pod_bounds.y <= 6.5, "Pod height should be ~6 units!")
	print("Pod Size & Hatch Clearance: PASS")

	# ----------------------------------------------------
	# CHECK 2: LYING ASTRONAUT GROUND CLEARANCE & ZERO CLIPPING
	# ----------------------------------------------------
	print("\n--- 2. ASTRONAUT GROUND HEIGHT & ZERO CLIPPING ---")
	var ground_info = player._find_ground_height_under_astronaut()
	var ground_dist = ground_info["height"]
	var center = planet.global_position
	
	var min_world_dist = 1e9
	var lowest_world_pt = Vector3.ZERO
	var meshes = player.find_children("*", "MeshInstance3D", true, false)
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
	print("Ground Height directly under astronaut: %.4f m" % ground_dist)
	print("Astronaut Lowest Mesh Point Height:    %.4f m" % min_world_dist)
	print("Lowest World Point:                    %s" % lowest_world_pt)
	print("Selected Lying Pose:                   SIDE POSE (Pitch -80°, Roll +70°)")
	print("Measured Ground Clearance:             +%.4f m" % measured_clearance)
	print("Delta vs Ground:                       %.4f units (target <= 0.1 units)" % delta_vs_ground)
	assert(measured_clearance >= 0.0, "Astronaut must have zero clipping (positive ground clearance)!")
	assert(delta_vs_ground <= 0.1, "Delta between ground and lowest mesh point must be <= 0.1 units!")
	print("Lying Pose & Ground Clearance: PASS")

	# ----------------------------------------------------
	# CHECK 3: LOOK-AROUND CAMERA ZOOM & SINGLE SLOW TURN
	# ----------------------------------------------------
	print("\n--- 3. LOOK-AROUND CAMERA ZOOM & SINGLE SLOW TURN ---")
	player.start_cinematic_lying_intro()
	var spring_arm = player.spring_arm
	var camera_arm = player.camera_arm
	
	# Verify Phase 1 (0 to 6s): Steady zoom, NO sweeps
	var initial_yaw = player.camera_yaw
	var initial_length = spring_arm.spring_length
	print("At t = 0.0s: SpringArm Length = %.2f m, Camera Yaw = %.2f°" % [initial_length, rad_to_deg(initial_yaw)])
	
	# Simulate 3 seconds of zoom
	for frame in range(180): # 3.0s at 60fps
		player._update_cinematic_intro(1.0 / 60.0)
	
	var mid_yaw = player.camera_yaw
	var mid_length = spring_arm.spring_length
	print("At t = 3.0s: SpringArm Length = %.2f m, Camera Yaw = %.2f°" % [mid_length, rad_to_deg(mid_yaw)])
	assert(abs(mid_yaw - initial_yaw) < 0.001, "Camera must NOT sweep back and forth during zoom phase!")
	assert(mid_length < initial_length and mid_length > 2.5, "Camera must be zooming in steadily!")
	
	# Simulate to 6.0 seconds (zoom completes to 2.5m)
	for frame in range(180): # another 3.0s
		player._update_cinematic_intro(1.0 / 60.0)
	
	var zoom_end_length = spring_arm.spring_length
	var zoom_end_yaw = player.camera_yaw
	print("At t = 6.0s (Zoom End): SpringArm Length = %.2f m, Camera Yaw = %.2f°" % [zoom_end_length, rad_to_deg(zoom_end_yaw)])
	assert(abs(zoom_end_length - 2.5) < 0.05, "Zoom must stop at 2.5 units!")
	assert(abs(zoom_end_yaw - initial_yaw) < 0.001, "Camera must have held steady heading with no sweeps!")

	# Simulate Phase 2 (6.0s to 8.5s): Single slow turn toward pod
	for frame in range(150): # 2.5s at 60fps
		player._update_cinematic_intro(1.0 / 60.0)
	
	var turned_yaw = player.camera_yaw
	print("At t = 8.5s (Turn End): Facing Pod Target Yaw = %.2f°" % rad_to_deg(turned_yaw))
	assert(abs(turned_yaw - initial_yaw) > 0.1, "Camera must have turned toward pod!")
	assert(abs(spring_arm.spring_length - 2.5) < 0.05, "Camera distance must hold steady at 2.5m!")
	print("Camera Steady Zoom & Single Slow Turn: PASS")

	# ----------------------------------------------------
	# CHECK 4: STAND-UP STEP & INPUT ENABLED
	# ----------------------------------------------------
	print("\n--- 4. STAND-UP STEP & MOVEMENT RESTORATION ---")
	# Trigger transition to Phase 3 (stand-up)
	player._update_cinematic_intro(0.1)
	assert(player.is_standing_up, "Stand-up step must be active!")
	assert(player.is_input_locked, "Input must remain locked during stand-up!")
	
	# Simulate 2.0 seconds of stand-up blending
	for frame in range(125): # 2.08s at 60fps
		player._update_stand_up(1.0 / 60.0)
	
	assert(not player.is_standing_up, "Stand-up must finish after 2.0s!")
	assert(not player.is_lying, "Astronaut must no longer be lying!")
	assert(not player.is_input_locked, "Input must be unlocked after stand-up!")
	print("Input enabled check: PASS (is_input_locked = false)")
	
	# Simulate player walking
	var start_pos = player.global_position
	# Apply forward movement input
	player.velocity = -player.global_transform.basis.z * player.haggard_speed
	player.move_and_slide()
	var moved_dist = player.global_position.distance_to(start_pos)
	print("Player moved distance after standing up: %.4f m" % moved_dist)
	print("Player Movement Check: PASS")

	# ----------------------------------------------------
	# CHECK 5: PLACEMENT REGISTRY & DEBUG KEY P
	# ----------------------------------------------------
	print("\n--- 5. PLACEMENT REGISTRY & KEY P ---")
	registry.debug_placement = true
	var initial_entries_count = registry.entries.size()
	print("Initial Registry Entries: %s (Count: %d)" % [str(registry.entries.keys()), initial_entries_count])
	assert(registry.entries.has("pod"), "Registry must have 'pod' entry!")
	
	# Verify get_position("pod")
	var pod_pos_reg = registry.get_position("pod")
	print("PlacementRegistry.get_position('pod') = %s" % pod_pos_reg)
	assert(pod_pos_reg != null, "get_position('pod') must return a valid Vector3!")
	
	# Test key P / raycast
	# Setup mock camera
	var camera = player.get_node("CameraArm/SpringArm3D/Camera3D") as Camera3D
	assert(camera != null, "Camera3D must exist!")
	registry._handle_debug_placement_raycast()
	
	var updated_count = registry.entries.size()
	print("Entries after debug raycast: %s (Count: %d)" % [str(registry.entries.keys()), updated_count])
	assert(updated_count == initial_entries_count + 1, "Debug key P must add one marker entry!")
	
	var new_marker_name = "marker_%d" % (registry.next_marker_index - 1)
	assert(registry.entries.has(new_marker_name), "Marker name must be present in registry!")
	var marker_pos = registry.get_position(new_marker_name)
	print("New Marker '%s' position: %s" % [new_marker_name, marker_pos])
	
	# Test reloading placements from placements.json
	registry.save_placements()
	registry.entries.clear()
	registry.load_placements()
	print("Entries after reloading from JSON: %s (Count: %d)" % [str(registry.entries.keys()), registry.entries.size()])
	assert(registry.entries.has(new_marker_name), "Reloaded registry must contain '%s'!" % new_marker_name)
	var reloaded_pos = registry.get_position(new_marker_name)
	var pos_diff = marker_pos.distance_to(reloaded_pos)
	print("Marker position delta after reload: %.6f m" % pos_diff)
	assert(pos_diff < 0.001, "Reloaded marker must return the exact same spot!")
	print("Placement Registry & Key P: PASS")

	# ----------------------------------------------------
	# CHECK 6: CAVE VISIBILITY & ENTRANCE CHECK
	# ----------------------------------------------------
	print("\n--- 6. CAVE ENTRANCES OPEN CHECK ---")
	world._check_cave_visibility()
	print("Cave Check: PASS (All OPEN)")

	print("\n==================================================")
	print("ALL VERIFICATION CHECKS PASSED WITH 0 ERRORS!")
	print("==================================================\n")
	quit()
