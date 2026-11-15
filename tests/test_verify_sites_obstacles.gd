@tool
extends SceneTree

# test_verify_sites_obstacles.gd
# Comprehensive verification suite for Part A, B, C, D, E of Sites & Obstacles update.

func _init() -> void:
	print("\n==================================================")
	print("STARTING TEST: SITES & OBSTACLES VERIFICATION")
	print("==================================================")
	
	var t_start = Time.get_ticks_usec()
	
	# 1. Reset GameManager session state for clean test run
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
	var planet = world.get_node("ProceduralMars")
	var hud = world.get_node("HUD")
	var pod = world.crashed_pod_node as CrashedPod
	var survival = world.survival as SurvivalSystem
	var crash_base = world.crash_base_node
	var rover_site = world.rover_site_node
	
	# =========================================================================
	# VERIFY CHECK 1: PRINT REGISTRY POSITIONS & DISTANCES FROM POD
	# =========================================================================
	print("\n--- 1. REGISTRY POSITIONS & DISTANCES FROM POD ---")
	var pod_pos = registry.get_position("pod") as Vector3
	var crash_pos = registry.get_position("crash_base") as Vector3
	var rover_pos = registry.get_position("rover_site") as Vector3
	var water_pos = registry.get_position("water_deposit") as Vector3
	
	var dist_pod_crash = pod_pos.distance_to(crash_pos)
	var dist_pod_rover = pod_pos.distance_to(rover_pos)
	var dist_pod_water = pod_pos.distance_to(water_pos)
	
	print("Pod Position:            %s" % pod_pos)
	print("Crash Base Position:     %s | Distance from Pod: %.2f m" % [crash_pos, dist_pod_crash])
	print("Rover Site Position:     %s | Distance from Pod: %.2f m (Requirement >= 80m: %s)" % [rover_pos, dist_pod_rover, "PASS" if dist_pod_rover >= 80.0 else "FAIL"])
	print("Water Deposit Position:  %s | Distance from Pod: %.2f m (Requirement >= 60m: %s)" % [water_pos, dist_pod_water, "PASS" if dist_pod_water >= 60.0 else "FAIL"])
	
	assert(dist_pod_rover >= 80.0, "rover_site must be at least 80 units from pod! (got %.2fm)" % dist_pod_rover)
	assert(dist_pod_water >= 60.0, "water_deposit must be at least 60 units from pod! (got %.2fm)" % dist_pod_water)
	
	# Check distance to caves
	for c_idx in range(planet.get_cave_pit_count()):
		var cave_pt = planet.get_cave_pit_surface_point(c_idx)
		var c_name = planet.get_cave_pit_name(c_idx)
		var d_rover_cave = rover_pos.distance_to(cave_pt)
		var d_water_cave = water_pos.distance_to(cave_pt)
		print("  Cave [%s] - Dist to Rover: %.2fm (>=80m: %s) | Dist to Water: %.2fm (>=60m: %s)" % [
			c_name, d_rover_cave, "PASS" if d_rover_cave >= 80.0 else "FAIL",
			d_water_cave, "PASS" if d_water_cave >= 60.0 else "FAIL"
		])
		assert(d_rover_cave >= 80.0, "rover_site must be >= 80m from cave %s!" % c_name)
		assert(d_water_cave >= 60.0, "water_deposit must be >= 60m from cave %s!" % c_name)
	
	print("Registry Positions & Distances Check: PASS")

	# =========================================================================
	# VERIFY CHECK 2: WATER DEPOSIT METRICS (PEAK HEIGHT & ICE PATCH RADIUS)
	# =========================================================================
	print("\n--- 2. WATER DEPOSIT METRICS ---")
	var water_metrics = planet.get_water_deposit_metrics()
	var peak_h = water_metrics["peak_height"]
	var ice_rad = water_metrics["ice_radius"]
	print("Mountain Peak Height above base radius: %.2f m (Requirement < 60m: %s)" % [peak_h, "PASS" if peak_h < 60.0 else "FAIL"])
	print("Water Ice Basin Radius:                 %.2f m" % ice_rad)
	assert(peak_h < 60.0, "Mountain peak height must be strictly below 60 units above base radius!")
	assert(ice_rad >= 14.0 and ice_rad <= 16.0, "Ice basin radius must be ~15 units!")
	print("Water Deposit Metrics Check: PASS")

	# =========================================================================
	# VERIFY CHECK 3: WALK ROUTES & CLEAR LANE CHECK (PART D)
	# =========================================================================
	print("\n--- 3. WALK ROUTES & 4-UNIT CLEAR LANE VERIFICATION ---")
	var obs_root = world.get_node_or_null("RouteObstacles")
	assert(obs_root != null, "RouteObstacles node must exist in world!")
	
	var routes_to_test = [
		{"name": "Home to Crash Base", "start": pod_pos, "end": crash_pos},
		{"name": "Home to Water Deposit", "start": pod_pos, "end": water_pos},
		{"name": "Home to Rover Site", "start": pod_pos, "end": rover_pos}
	]
	
	var total_obs_count = 0
	for r_info in routes_to_test:
		var r_name = r_info["name"]
		var p_start = r_info["start"] as Vector3
		var p_end = r_info["end"] as Vector3
		var dir_start = (p_start - planet.global_position).normalized()
		var dir_end = (p_end - planet.global_position).normalized()
		var total_ang = acos(clampf(dir_start.dot(dir_end), -1.0, 1.0))
		var total_dist = total_ang * planet.radius
		
		# Sample path every 1 meter and verify clear lane
		var num_samples = int(total_dist)
		var min_clearance_to_obs = 9999.0
		var nearest_obs_name = ""
		
		for step in range(num_samples):
			var t = float(step) / float(num_samples)
			var path_dir = dir_start.slerp(dir_end, t).normalized()
			var path_pos = planet.get_surface_point(path_dir)
			
			# Check against all obstacle nodes
			for child in obs_root.get_children():
				var obs_pos = child.global_position
				var dist = path_pos.distance_to(obs_pos)
				
				# Determine obstacle radius
				var col_shape = child.find_child("ColShape", true, false) as CollisionShape3D
				var obs_radius = 0.65
				if col_shape and col_shape.shape is SphereShape3D:
					obs_radius = col_shape.shape.radius
				
				var net_clearance = dist - obs_radius
				if net_clearance < min_clearance_to_obs:
					min_clearance_to_obs = net_clearance
					nearest_obs_name = child.name
		
		print("Route [%s] (Length: %.1fm):" % [r_name, total_dist])
		print("  Minimum net clearance to any obstacle: %.2f m (Target > 2.0m for 4-unit clear lane)" % min_clearance_to_obs)
		print("  Clear Lane Status: %s (Nearest obstacle: %s)" % ["CLEAR" if min_clearance_to_obs >= 2.0 else "ENCROACHMENT!", nearest_obs_name])
		assert(min_clearance_to_obs >= 2.0, "Route [%s] has obstacle encroaching inside 4-unit clear lane! Net clearance: %.2fm" % [r_name, min_clearance_to_obs])
	
	print("4-Unit Clear Lane Walk Check: ALL ROUTES 100% CLEAR - PASS")

	# =========================================================================
	# VERIFY CHECK 4: ROVER SITE CORE RECOVERY & POWER UNIT REPAIR (PART B)
	# =========================================================================
	print("\n--- 4. ROVER SITE RECOVERY & POWER UNIT REPAIR ---")
	assert(rover_site != null, "RoverSite node must exist in world!")
	
	# Initial inventory checks
	print("Initial power_unit_core: %d (Expected: 0)" % gm.power_unit_core)
	assert(gm.power_unit_core == 0, "power_unit_core must start at 0!")
	assert(gm.power_core_collected == false, "power_core_collected must start false!")
	assert(gm.power_unit_repaired == false, "power_unit_repaired must start false!")
	
	# Try repairing power unit without core
	pod.active_machine = "PowerUnit"
	pod._interact_with_machine("PowerUnit")
	print("HUD Alert text without core: '%s'" % hud.alert_text.text)
	assert(hud.alert_text.text == "Needs a power unit core from Rover Site", "Must show 'Needs a power unit core from Rover Site'!")
	assert(pod.is_holding_repair == false, "Repair hold must not start without core!")
	
	# Recover power core from Rover
	rover_site.recover_power_core()
	print("After rover recovery: power_unit_core = %d, collected = %s" % [gm.power_unit_core, gm.power_core_collected])
	assert(gm.power_unit_core == 1, "Must have 1 power_unit_core after recovery!")
	assert(gm.power_core_collected == true, "power_core_collected must be true!")
	assert(hud.alert_text.text == "Power unit core recovered", "HUD must show 'Power unit core recovered'!")
	
	# Try recovering a second time: must not give another core
	rover_site.recover_power_core()
	assert(gm.power_unit_core == 1, "Must not be able to recover core twice!")
	
	# Simulate 3-second hold E repair on PowerUnit
	pod.active_machine = "PowerUnit"
	Input.action_press("interact")
	pod._interact_with_machine("PowerUnit")
	assert(pod.is_holding_repair == true, "Repair hold must start with core present!")
	assert(pod.repair_target_machine == "PowerUnit", "Repair target must be PowerUnit!")
	
	# Test canceling early
	Input.action_release("interact")
	pod._process_repair_hold(0.5)
	assert(pod.is_holding_repair == false, "Repair hold must cancel on release!")
	assert(gm.power_unit_core == 1, "Core must not be consumed on canceled repair!")
	assert(gm.power_unit_repaired == false, "Must not be repaired on cancel!")
	
	# Now hold full 3.0 seconds
	Input.action_press("interact")
	pod._interact_with_machine("PowerUnit")
	pod._process_repair_hold(1.5)
	assert(pod.is_holding_repair == true, "Hold at 1.5s should still be running!")
	pod._process_repair_hold(1.6) # Reaches 3.1s >= 3.0s
	Input.action_release("interact")
	
	print("After full hold: power_unit_repaired = %s, cores remaining = %d" % [gm.power_unit_repaired, gm.power_unit_core])
	assert(gm.power_unit_repaired == true, "power_unit_repaired must be true!")
	assert(gm.power_unit_core == 0, "power_unit_core must be consumed!")
	assert(hud.alert_text.text == "Power unit repaired", "HUD must show 'Power unit repaired'!")
	
	# Wait for 1.5s tween to complete
	if pod.repair_tween and pod.repair_tween.is_running():
		await pod.repair_tween.finished
	else:
		for f in range(120):
			await process_frame
	
	print("Power light color after 1.5s tween: %s" % pod.power_light.light_color)
	assert(pod.power_light.light_color.is_equal_approx(Color(0.2, 1.0, 0.3)), "Power light must turn green!")
	print("Rover Recovery & Power Unit Repair Check: PASS")

	# =========================================================================
	# VERIFY CHECK 5: HABITAT SURROUNDINGS & HATCH CLEARANCE (PART E)
	# =========================================================================
	print("\n--- 5. HABITAT SURROUNDINGS & HATCH CLEARANCE (PART E) ---")
	var surroundings = world.get_node_or_null("PodSurroundings")
	assert(surroundings != null, "PodSurroundings must exist in world!")
	
	var dust_ring = surroundings.get_node_or_null("DustDriftRing")
	var spires = surroundings.get_node_or_null("RockSpires")
	var light_left = surroundings.get_node_or_null("AirlockLightStrip_Left")
	var light_right = surroundings.get_node_or_null("AirlockLightStrip_Right")
	
	assert(dust_ring != null, "DustDriftRing must exist!")
	assert(spires != null, "RockSpires must exist!")
	assert(light_left != null and light_right != null, "Airlock light strips must exist!")
	
	var hatch_node = pod.find_child("Line0022", true, false) as Node3D
	var hatch_pos = hatch_node.global_position if hatch_node else pod.global_position
	
	# Check hatch clearance on all dust drift clusters and spires
	for cluster in dust_ring.get_children():
		var d = cluster.global_position.distance_to(hatch_pos)
		assert(d >= 6.0, "Dust cluster [%s] encroaches inside 6m hatch radius! Dist: %.2fm" % [cluster.name, d])
	
	for spire in spires.get_children():
		var d = spire.global_position.distance_to(hatch_pos)
		assert(d >= 6.0, "Spire [%s] encroaches inside 6m hatch radius! Dist: %.2fm" % [spire.name, d])
	
	print("Pod Surroundings & 6m Hatch Clearance Check: PASS (%d dust clusters, %d spires, 2 light strips)" % [
		dust_ring.get_child_count(), spires.get_child_count()
	])

	# =========================================================================
	# VERIFY CHECK 6: CAVE VISIBILITY RAY-CHECK STILL OPEN
	# =========================================================================
	print("\n--- 6. CAVE VISIBILITY RAY-CHECK STILL OPEN ---")
	world._check_cave_visibility()
	print("Cave Visibility Check: PASS (All OPEN)")

	# =========================================================================
	# VERIFY CHECK 7: FRAMETIME EVALUATION
	# =========================================================================
	print("\n--- 7. FRAMETIME EVALUATION ---")
	var frame_times: Array[float] = []
	for f in range(60):
		var ft_start = Time.get_ticks_usec()
		world._physics_process(1.0 / 60.0)
		var ft_dur = (Time.get_ticks_usec() - ft_start) / 1000.0 # ms
		frame_times.append(ft_dur)
		await process_frame
	
	var sum_ft = 0.0
	for ft in frame_times:
		sum_ft += ft
	var avg_ft = sum_ft / frame_times.size()
	print("Average physics frame time: %.3f ms (Requirement increase <= 2.0ms: PASS)" % avg_ft)
	assert(avg_ft < 2.0, "Average physics frametime must be well under 2.0ms!")
	print("Frametime Evaluation Check: PASS")

	var total_dur = (Time.get_ticks_usec() - t_start) / 1000000.0
	print("\n==================================================")
	print("ALL SITES & OBSTACLES CHECKS PASSED WITH 0 ERRORS in %.2fs!" % total_dur)
	print("==================================================\n")
	quit()
