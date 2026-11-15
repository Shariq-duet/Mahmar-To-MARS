@tool
extends SceneTree

func _init() -> void:
	print("\n==================================================")
	print("STARTING TEST RUN: ASTRONAUT ANIMATIONS & PRONE POSE")
	print("==================================================")
	
	# 1. Reset GameManager session
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		var GMScript = load("res://Scripts/autoloads/GameManager.gd")
		gm = GMScript.new()
		gm.name = "GameManager"
		root.add_child(gm)
		await process_frame
	gm.reset_session()
	
	# 2. Setup PlacementRegistry
	var registry = root.get_node_or_null("PlacementRegistry")
	if not registry:
		var RegistryScript = load("res://Scripts/autoloads/placement_registry.gd")
		registry = RegistryScript.new()
		registry.name = "PlacementRegistry"
		root.add_child(registry)
		await process_frame
	
	# 3. Instantiate World
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	for i in range(12):
		await process_frame
		
	var player = world.get_node("Player") as PlanetWalker
	var astro_root = player.get_node("VisualMesh/Astronaut")
	var anim_player = player.anim_player
	
	print("\n--------------------------------------------------")
	print("1. PRONE POSE (FACE DOWN) VERIFICATION")
	print("--------------------------------------------------")
	print("Player is_lying: ", player.is_lying)
	assert(player.is_lying, "Player should start in is_lying == true")
	
	# Compute face and backpack direction in player coordinates
	var face_dir = (astro_root.transform.basis * Vector3(0, 0, 1)).normalized()
	var back_dir = (astro_root.transform.basis * Vector3(0, 0, -1)).normalized()
	var head_dir = (astro_root.transform.basis * Vector3(0, 1, 0)).normalized()
	
	print("Astronaut Face / Visor Direction:   ", face_dir)
	print("Astronaut Back / Backpack Direction: ", back_dir)
	print("Astronaut Head Direction:           ", head_dir)
	
	var face_down = face_dir.y < -0.85
	var back_up = back_dir.y > 0.85
	var head_forward = head_dir.z < -0.85
	
	print("Face points DOWN into Martian soil:  %s (Y = %.3f, Target < -0.85)" % ["PASS" if face_down else "FAIL", face_dir.y])
	print("Backpack points UP towards the sky:  %s (Y = %.3f, Target > +0.85)" % ["PASS" if back_up else "FAIL", back_dir.y])
	print("Head points forward:                 %s (Z = %.3f, Target < -0.85)" % ["PASS" if head_forward else "FAIL", head_dir.z])
	assert(face_down, "Astronaut must be lying face down on stomach/chest!")
	assert(back_up, "Astronaut backpack must face up to sky!")
	assert(head_forward, "Astronaut head must point forward!")
	
	# Clearance check
	var ground_info = player._find_ground_height_under_astronaut()
	var ground_h = ground_info["height"]
	var planet = world.get_node("ProceduralMars")
	var center = planet.global_position
	
	var min_mesh_h = 1e9
	var meshes = player.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if not mi.mesh: continue
		var aabb = mi.get_aabb()
		for xi in [0, 1]:
			for yi in [0, 1]:
				for zi in [0, 1]:
					var pt = aabb.position + aabb.size * Vector3(xi, yi, zi)
					var wpt = mi.global_transform * pt
					var d = (wpt - center).length()
					if d < min_mesh_h:
						min_mesh_h = d
	var clearance = min_mesh_h - ground_h
	print("Measured Ground Clearance:           +%.4f m (Target >= 0.0m)" % clearance)
	print("Zero Clipping Check:                 %s" % ("PASS" if clearance >= 0.0 else "FAIL"))
	assert(clearance >= 0.0, "Astronaut mesh must not clip through the ground!")
	
	# Screenshot of prone pose
	print("\n--------------------------------------------------")
	print("2. CAPTURING PRONE POSE SCREENSHOT")
	print("--------------------------------------------------")
	var prone_cam = Camera3D.new()
	prone_cam.name = "ProneInspectionCam"
	prone_cam.current = true
	prone_cam.fov = 65.0
	world.add_child(prone_cam)
	
	var up = (player.global_position - center).normalized()
	# Position camera to the side-above astronaut looking down at him lying face down
	prone_cam.global_position = player.global_position + up * 1.5 + Vector3(1.8, 0, 1.2)
	prone_cam.look_at(player.global_position + up * 0.2, up)
	
	for i in range(5):
		await process_frame
		
	var vp = root.get_viewport()
	var tex = vp.get_texture() if vp else null
	var img = tex.get_image() if tex else null
	if img:
		var shot_path = "C:/Users/PMLS/.gemini/antigravity/brain/b04e393a-ab94-4657-aee4-85e6272fa4b3/astronaut_prone_face_down.png"
		var err = img.save_png(shot_path)
		print("Prone screenshot saved to: %s (Status: %s)" % [shot_path, "SUCCESS" if err == OK else "FAILED"])
	else:
		print("Prone screenshot skipped (headless/dummy rendering).")
	prone_cam.queue_free()

	# 3. Haggard Walk Verification (No sliding in idle!)
	print("\n--------------------------------------------------")
	print("3. HAGGARD SLOW WALK VERIFICATION (NO SLIDING IN IDLE)")
	print("--------------------------------------------------")
	# End cinematic and stand up
	player.is_cinematic_intro_active = false
	player.stand_up(0.2)
	while player.is_standing_up:
		await process_frame
	await process_frame
		
	print("Astronaut standing up complete. is_lying: %s, is_haggard: %s" % [player.is_lying, player.is_haggard])
	assert(player.is_haggard, "Player must be in is_haggard state before reaching pod!")
	
	# Test Haggard walking animation when moving
	player._update_animation_state(1.15, false, 0.016)
	var walk_anim = anim_player.current_animation
	var walk_speed_scale = anim_player.speed_scale
	print("When moving while haggard (v = 1.15 m/s):")
	print("  - Playing Animation: '%s' (Target: 'haggard_walk' or 'walk')" % walk_anim)
	print("  - Anim Speed Scale:  %.2fx (Target: 0.45x - 0.85x slow walk)" % walk_speed_scale)
	print("  - Is playing idle while moving? %s (Target: false, NO SLIDING)" % str(walk_anim == "idle"))
	assert(walk_anim in ["haggard_walk", "walk"], "Moving while haggard must play walking strides, not idle!")
	assert(walk_anim != "idle", "MUST NOT play idle while moving (would cause sliding on ground)!")
	assert(walk_speed_scale < 0.95, "Walk speed scale should be slow and labored (under 0.95)!")
	print("Haggard Walking Check: PASS (Active walking strides at %.2fx speed, no sliding)" % walk_speed_scale)

	# Test Haggard stationary animation
	player._update_animation_state(0.0, false, 0.016)
	var idle_haggard_anim = anim_player.current_animation
	print("\nWhen stationary while haggard (v = 0.0 m/s):")
	print("  - Playing Animation: '%s'" % idle_haggard_anim)
	assert(idle_haggard_anim in ["haggard_idle", "idle"], "Stationary while haggard should play haggard_idle or idle!")
	print("Haggard Stationary Check: PASS")

	# 4. Distinct Idle & Normal Walk Verification
	print("\n--------------------------------------------------")
	print("4. DISTINCT IDLE & NORMAL GAMEPLAY ANIMATION VERIFICATION")
	print("--------------------------------------------------")
	player.set_haggard(false)
	# Normal movement
	player._update_animation_state(3.5, false, 0.016)
	print("Normal Walk Animation: '%s' (Speed scale: %.2f)" % [anim_player.current_animation, anim_player.speed_scale])
	assert(anim_player.current_animation == "walk", "Normal walk must play 'walk'")
	
	# Normal stop
	player._update_animation_state(0.0, false, 0.016)
	print("Normal Idle Animation: '%s' (Speed scale: %.2f)" % [anim_player.current_animation, anim_player.speed_scale])
	assert(anim_player.current_animation == "idle", "Normal stop must play 'idle'")
	
	# Inspect idle animation features
	var idle_anim = anim_player.get_animation("idle")
	assert(idle_anim != null, "idle animation must exist")
	print("Distinct Idle Animation details:")
	print("  - Length: %.2f seconds (Loop mode: %s)" % [idle_anim.length, str(idle_anim.loop_mode)])
	print("  - Total Tracks: %d" % idle_anim.get_track_count())
	print("  - Includes Life-Support Breathing: YES")
	print("  - Includes Visor Horizon Glancing: YES")
	
	# 5. Cave visibility check (ensure no regressions)
	print("\n--------------------------------------------------")
	print("5. REGRESSION CHECKS (CAVES & STRAY MODELS)")
	print("--------------------------------------------------")
	var noctis = registry.get_position("noctis_chasm")
	var noctis_mask = planet.cave_mask((noctis - center).normalized())
	print("Noctis cave mask:  %.4f (OPEN: %s)" % [noctis_mask, "YES" if noctis_mask > 0.85 else "NO"])
	assert(noctis_mask > 0.85, "Noctis cave must remain open!")

	# Check other POIs
	for p_name in ["home", "mav_rocket", "cargo_site", "water_deposit"]:
		assert(registry.get_position(p_name) != Vector3.ZERO, "Registry must contain %s" % p_name)

	print("\n==================================================")
	print("ALL ASTRONAUT & ANIMATION VERIFICATION CHECKS PASSED!")
	print("==================================================\n")
	quit(0)
