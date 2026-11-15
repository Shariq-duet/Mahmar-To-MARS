@tool
extends SceneTree

# test_verify_lighting_cargo_survival_ending.gd
# Comprehensive automated verification script covering Parts A, B, C, D, and E.

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")

func _init() -> void:
	print("\n======================================================================")
	print("STARTING NASA MARS SURVIVAL: LIGHTING, CARGO, SURVIVAL & ENDING VERIFY")
	print("======================================================================\n")
	
	var pass_count = 0
	var total_tests = 0

	# Ensure GameManager is in root
	var gm_init = root.get_node_or_null("GameManager")
	if not gm_init:
		var gm_script = load("res://Scripts/autoloads/GameManager.gd")
		gm_init = Node.new()
		gm_init.set_script(gm_script)
		gm_init.name = "GameManager"
		root.add_child(gm_init)
	var gm = gm_init

	# ------------------------------------------------------------------
	# PART A: NIGHT LIGHTING VERIFICATION
	# ------------------------------------------------------------------
	print(">>> [PART A: NIGHT LIGHTING]")
	var dnc = DayNightCycle.new()
	dnc.sol_duration_seconds = 600.0
	
	var sun_light = DirectionalLight3D.new()
	var moon_light = DirectionalLight3D.new()
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	world_env.environment = env
	
	dnc.sun_light = sun_light
	dnc.moon_light = moon_light
	dnc.world_env = world_env
	
	root.add_child(dnc)
	root.add_child(sun_light)
	root.add_child(moon_light)
	root.add_child(world_env)
	
	# 1. Sunrise / Daylight (e.g. sol progress = 0.25 -> noon progress = 0.25)
	dnc.time_of_sol = 150.0 # daylight
	dnc._update_celestial_bodies(0.0)
	total_tests += 1
	var day_sun_ok = sun_light.visible and not moon_light.visible
	if day_sun_ok:
		print("  [PASS] Daylight state: Sun is ENABLED, Moon is DISABLED.")
		pass_count += 1
	else:
		printerr("  [FAIL] Daylight state: Sun visible=%s, Moon visible=%s" % [sun_light.visible, moon_light.visible])

	# 2. Noon state: Sun Peak
	dnc.time_of_sol = 150.0
	dnc._update_celestial_bodies(0.0)
	print("  [INFO] Sol %d Noon Sun Energy: %.2f | Max Solar Gen: %.1f/s" % [dnc.current_sol, sun_light.light_energy, 2.0])

	# 3. Night state (e.g. sol progress = 0.75 -> sun under horizon)
	dnc.time_of_sol = 450.0 # night
	dnc._update_celestial_bodies(0.0)
	total_tests += 1
	var night_ok = (not sun_light.visible) and moon_light.visible and is_equal_approx(moon_light.light_energy, 0.25) and moon_light.shadow_enabled
	if night_ok:
		print("  [PASS] Night state: Sun is DISABLED, Moon is ENABLED (Energy: %.2f, Cool Blue-White: %s, Shadows: %s)" % [
			moon_light.light_energy, moon_light.light_color, moon_light.shadow_enabled
		])
		pass_count += 1
	else:
		printerr("  [FAIL] Night state: Sun visible=%s, Moon visible=%s, Moon energy=%.2f, Shadows=%s" % [
			sun_light.visible, moon_light.visible, moon_light.light_energy, moon_light.shadow_enabled
		])

	# 4. Ambient light check at night: ~0.15 energy, terrain readable but dark
	total_tests += 1
	var night_ambient_ok = is_equal_approx(env.ambient_light_energy, 0.15)
	if night_ambient_ok:
		print("  [PASS] Night ambient lighting energy is %.2f (readable, dark, not fully bright)." % env.ambient_light_energy)
		pass_count += 1
	else:
		printerr("  [FAIL] Night ambient lighting energy is %.2f (expected 0.15)" % env.ambient_light_energy)

	# 5. Emissive beacons and pickups
	total_tests += 1
	var cargo_scene = load("res://Scenes/machines/space_cargo.tscn")
	var cargo_inst = cargo_scene.instantiate()
	var filter_mesh = cargo_inst.find_child("FilterCorePickup", true, false).find_child("CoreMesh", true, false) as MeshInstance3D
	var emissive_ok = false
	if filter_mesh:
		var mat = filter_mesh.material_override as StandardMaterial3D
		if not mat and filter_mesh.mesh:
			mat = filter_mesh.mesh.material as StandardMaterial3D
		if mat and mat.emission_enabled and mat.emission_energy_multiplier >= 2.0:
			emissive_ok = true
			print("  [PASS] Pickups have emissive glow enabled (Emission Energy: %.1f) for night visibility." % mat.emission_energy_multiplier)
	if emissive_ok:
		pass_count += 1
	else:
		printerr("  [FAIL] Pickup mesh emission check failed!")

	dnc.queue_free()
	sun_light.queue_free()
	moon_light.queue_free()
	world_env.queue_free()
	cargo_inst.queue_free()

	# ------------------------------------------------------------------
	# PART B: SPACE CARGO MODEL VERIFICATION
	# ------------------------------------------------------------------
	print("\n>>> [PART B: SPACE CARGO MODEL & CORES]")
	var cargo_node = cargo_scene.instantiate() as SpaceCargo
	root.add_child(cargo_node)
	if cargo_node.kept_mesh_names.is_empty():
		cargo_node._ready()
	
	total_tests += 1
	var kept_count = cargo_node.kept_mesh_names.size()
	var removed_count = cargo_node.removed_mesh_names.size()
	if kept_count == 2 and removed_count >= 5:
		print("  [PASS] Cargo node tree processed: 2 Cores KEPT, %d packaging/container meshes REMOVED." % [removed_count])
		pass_count += 1
	else:
		printerr("  [FAIL] Kept cores: %d, Removed meshes: %d" % [kept_count, removed_count])

	total_tests += 1
	var f_scale = cargo_node.filter_core_scale
	var p_scale = cargo_node.power_core_scale
	print("  [INFO] Filter Core Scale: %s | Power Core Scale: %s" % [f_scale, p_scale])
	if abs(f_scale.x - 0.872) < 0.05 and abs(p_scale.x - 0.936) < 0.05:
		print("  [PASS] Core meshes scaled to approximately 0.6 units across (Scale: Filter=%.3f, Power=%.3f)" % [f_scale.x, p_scale.x])
		pass_count += 1
	else:
		printerr("  [FAIL] Unexpected core scale: Filter=%s, Power=%s" % [f_scale, p_scale])

	# Check pickups E-to-collect and one-time logic
	total_tests += 1
	if gm:
		gm.filter_core = 0
		gm.cargo_filter_core_collected = false
	cargo_node.filter_core_collected = false
	cargo_node.player_in_filter_zone = true
	cargo_node.collect_filter_core()
	var first_count = gm.filter_core if gm else 1
	cargo_node.collect_filter_core() # Try second time (must not give another)
	var second_count = gm.filter_core if gm else 1
	var one_time_ok = (first_count == 1 and second_count == 1)
	if one_time_ok:
		print("  [PASS] Filter Core E-to-collect and one-time collection logic verified.")
		pass_count += 1
	else:
		printerr("  [FAIL] One-time core pickup collection failed.")
	cargo_node.queue_free()

	# ------------------------------------------------------------------
	# PART C: SURVIVAL MECHANICS VERIFICATION
	# ------------------------------------------------------------------
	print("\n>>> [PART C: SURVIVAL MECHANICS]")
	var s = SurvivalSystem.new()
	s.sol_duration_sec = 600.0

	# 1. Oxygen Drains
	# Inside pod: 0.05/s
	s.oxygen = 100.0
	s.is_in_shelter = true
	s.is_jetpacking = false
	s.is_scrubber_repaired = false
	s.power = 100.0
	s._update_oxygen(1.0)
	var o2_in = 100.0 - s.oxygen
	total_tests += 1
	if is_equal_approx(o2_in, 0.05):
		print("  [PASS] Oxygen drain inside pod: %.4f/s (expected 0.05/s)" % o2_in)
		pass_count += 1
	else:
		printerr("  [FAIL] Oxygen drain inside pod: %.4f/s (expected 0.05/s)" % o2_in)

	# Outside pod: 1.5x (0.075/s)
	s.oxygen = 100.0
	s.is_in_shelter = false
	s._update_oxygen(1.0)
	var o2_out = 100.0 - s.oxygen
	total_tests += 1
	if is_equal_approx(o2_out, 0.075):
		print("  [PASS] Oxygen drain outside pod: %.4f/s (expected 0.075/s = 1.5x)" % o2_out)
		pass_count += 1
	else:
		printerr("  [FAIL] Oxygen drain outside pod: %.4f/s (expected 0.075/s)" % o2_out)

	# Jetpacking: 3x (0.075 * 3 = 0.225/s outside)
	s.oxygen = 100.0
	s.is_in_shelter = false
	s.is_jetpacking = true
	s._update_oxygen(1.0)
	var o2_jet = 100.0 - s.oxygen
	total_tests += 1
	if is_equal_approx(o2_jet, 0.225):
		print("  [PASS] Oxygen drain jetpacking outside: %.4f/s (expected 0.225/s = 3.0x)" % o2_jet)
		pass_count += 1
	else:
		printerr("  [FAIL] Oxygen drain jetpacking: %.4f/s (expected 0.225/s)" % o2_jet)

	# Scrubber repaired factor: 0.5x
	s.oxygen = 100.0
	s.is_in_shelter = true
	s.is_jetpacking = false
	s.is_scrubber_repaired = true
	s._update_oxygen(1.0)
	var o2_scrub = 100.0 - s.oxygen
	total_tests += 1
	if is_equal_approx(o2_scrub, 0.025):
		print("  [PASS] Oxygen drain with repaired scrubber: %.4f/s (0.5x = 0.025/s)" % o2_scrub)
		pass_count += 1
	else:
		printerr("  [FAIL] Oxygen drain with scrubber: %.4f/s (expected 0.025/s)" % o2_scrub)

	# Zero power doubles drain: 2.0x
	s.oxygen = 100.0
	s.is_in_shelter = true
	s.is_scrubber_repaired = false
	s.power = 0.0
	s._update_oxygen(1.0)
	var o2_zero_pwr = 100.0 - s.oxygen
	total_tests += 1
	if is_equal_approx(o2_zero_pwr, 0.10):
		print("  [PASS] Oxygen drain at 0 power: %.4f/s (doubled = 0.10/s)" % o2_zero_pwr)
		pass_count += 1
	else:
		printerr("  [FAIL] Oxygen drain at 0 power: %.4f/s (expected 0.10/s)" % o2_zero_pwr)

	# 2. Power Generation & Consumption
	# Noon: sun_factor = 1.0 -> gen = 2.0/s, consumption = 0.8/s -> net = +1.2/s
	s.power = 50.0
	s.sun_factor = 1.0
	s.is_power_unit_repaired = false
	s.dust_storm_active = false
	s._update_power(1.0)
	var pwr_noon_net = s.power - 50.0
	total_tests += 1
	if is_equal_approx(pwr_noon_net, 1.2):
		print("  [PASS] Power net change at noon: +%.2f/s (gen: 2.0/s, consumption: 0.8/s)" % pwr_noon_net)
		pass_count += 1
	else:
		printerr("  [FAIL] Power net change at noon: +%.2f/s (expected +1.2/s)" % pwr_noon_net)

	# Night: sun_factor = 0.0 -> gen = 0, consumption = 0.8/s -> net = -0.8/s
	s.power = 50.0
	s.sun_factor = 0.0
	s._update_power(1.0)
	var pwr_night_net = 50.0 - s.power
	total_tests += 1
	if is_equal_approx(pwr_night_net, 0.8):
		print("  [PASS] Power net change at night: -%.2f/s (gen: 0, consumption: 0.8/s)" % pwr_night_net)
		pass_count += 1
	else:
		printerr("  [FAIL] Power net change at night: -%.2f/s (expected -0.8/s)" % pwr_night_net)

	# Repaired power unit adds 50% generation (gen: 2.0 * 1.5 = 3.0/s -> net: 3.0 - 0.8 = 2.2/s)
	s.power = 50.0
	s.sun_factor = 1.0
	s.is_power_unit_repaired = true
	s._update_power(1.0)
	var pwr_rep_net = s.power - 50.0
	total_tests += 1
	if is_equal_approx(pwr_rep_net, 2.2):
		print("  [PASS] Repaired Power Unit generation: +50%% (net: +%.2f/s)" % pwr_rep_net)
		pass_count += 1
	else:
		printerr("  [FAIL] Repaired Power Unit generation: +%.2f/s (expected +2.2/s)" % pwr_rep_net)

	# 3. Water drain and ice replenish
	s.water = 50.0
	s._update_water(1.0)
	var w_drain = 50.0 - s.water
	total_tests += 1
	if is_equal_approx(w_drain, 0.03):
		print("  [PASS] Water drain rate: %.3f/s (expected 0.03/s)" % w_drain)
		pass_count += 1
	else:
		printerr("  [FAIL] Water drain rate: %.3f/s (expected 0.03/s)" % w_drain)

	s.water = 50.0
	s.add_water_ice()
	total_tests += 1
	if is_equal_approx(s.water, 60.0):
		print("  [PASS] Water ice pickup adds +10 water (new water: %.1f%%)" % s.water)
		pass_count += 1
	else:
		printerr("  [FAIL] Water ice pickup: %.1f (expected 60.0)" % s.water)

	# 4. Food drain: 10 per sol
	s.food = 100.0
	s._update_food(600.0) # 1 full sol
	var food_drain = 100.0 - s.food
	total_tests += 1
	if is_equal_approx(food_drain, 10.0):
		print("  [PASS] Food drain over 1 sol: %.1f (expected 10.0 per sol)" % food_drain)
		pass_count += 1
	else:
		printerr("  [FAIL] Food drain over 1 sol: %.1f (expected 10.0)" % food_drain)

	# 5. Health regeneration inside pod & drain when vitals depleted
	s.health = 50.0
	s.is_in_shelter = true
	s.oxygen = 50.0
	s.power = 50.0
	s.water = 50.0
	s.food = 50.0
	s.solar_storm_active = false
	s.dust_storm_active = false
	s._update_suit_and_health(1.0)
	var h_regen = s.health - 50.0
	total_tests += 1
	if is_equal_approx(h_regen, 1.0):
		print("  [PASS] Health regenerates inside pod at %.1f/s when vitals > 20%%" % h_regen)
		pass_count += 1
	else:
		printerr("  [FAIL] Health regen: %.2f/s (expected 1.0/s)" % h_regen)

	# Depleted drain (2/s when any is 0)
	s.health = 50.0
	s.oxygen = 0.0
	s._update_suit_and_health(1.0)
	var h_drain = 50.0 - s.health
	total_tests += 1
	if is_equal_approx(h_drain, 2.0):
		print("  [PASS] Health drains at %.1f/s when a vital is 0" % h_drain)
		pass_count += 1
	else:
		printerr("  [FAIL] Health drain: %.2f/s (expected 2.0/s)" % h_drain)

	# 6. Solar radiation storm (Sol 3: 30s warn, 90s storm, 3/s drain outside, 0 inside)
	s.current_sol = 3
	s.time_in_sol = 40.0 # during warning window (30s before storm at 60s)
	var warned = [false]
	s.storm_warning.connect(func(_msg, active): if active: warned[0] = true)
	s._update_storms(0.0)
	total_tests += 1
	if warned[0]:
		print("  [PASS] Sol 3 Solar Storm warning fired 30s ahead of storm.")
		pass_count += 1
	else:
		printerr("  [FAIL] Sol 3 Solar Storm warning failed to fire.")

	# During storm outside: 3/s health drain
	s.time_in_sol = 70.0 # active storm
	s._update_storms(0.0)
	s.is_in_shelter = false
	s.oxygen = 100.0
	s.power = 100.0
	s.water = 100.0
	s.food = 100.0
	s.health = 50.0
	s._update_suit_and_health(1.0)
	var storm_h_drain = 50.0 - s.health
	total_tests += 1
	if is_equal_approx(storm_h_drain, 3.0):
		print("  [PASS] Solar storm outside pod drains health by %.1f/s" % storm_h_drain)
		pass_count += 1
	else:
		printerr("  [FAIL] Solar storm outside pod health drain: %.2f (expected 3.0)" % storm_h_drain)

	# During storm inside pod: 0 radiation damage
	s.is_in_shelter = true
	s.health = 50.0
	s.oxygen = 100.0
	s.power = 100.0
	s.water = 100.0
	s.food = 100.0
	s._update_suit_and_health(1.0)
	total_tests += 1
	if s.health >= 50.0:
		print("  [PASS] Pod shelter completely protects crew from solar storm radiation!")
		pass_count += 1
	else:
		printerr("  [FAIL] Solar storm damaged player inside pod!")

	# 7. Failure: health reaches 0 shows "Crew lost"
	var crew_lost_fired = [false]
	s.player_died.connect(func(reason):
		if reason.begins_with("Crew lost"):
			crew_lost_fired[0] = true
	)
	s.health = 1.0
	s.oxygen = 0.0
	s.is_in_shelter = false
	s._update_suit_and_health(1.0)
	total_tests += 1
	if crew_lost_fired[0]:
		print("  [PASS] Health reaching 0 emits 'Crew lost' failure signal.")
		pass_count += 1
	else:
		printerr("  [FAIL] 'Crew lost' signal failed to emit on 0 health.")

	# ------------------------------------------------------------------
	# PART D: ENDING SEQUENCE VERIFICATION
	# ------------------------------------------------------------------
	print("\n>>> [PART D: ENDING SEQUENCE & MAV REPAIR]")
	var mav_scene = load("res://Scenes/machines/return_vehicle.tscn")
	var mav = mav_scene.instantiate() as ReturnVehicle
	root.add_child(mav)
	if mav.rocket_root == null:
		mav._ready()

	# 1. Early repair attempt check
	if gm:
		gm.scrubber_repaired = false
		gm.power_unit_repaired = false
		gm.water_repaired = false
	
	var missing = mav.get_missing_repairs()
	total_tests += 1
	if missing.size() == 3:
		print("  [PASS] Early MAV repair blocked: Missing requirements [%s]" % [", ".join(missing)])
		pass_count += 1
	else:
		printerr("  [FAIL] Missing repairs check returned %d items (expected 3)" % missing.size())

	# 2. Complete all prerequisites
	if gm:
		gm.scrubber_repaired = true
		gm.power_unit_repaired = true
		gm.water_repaired = true
	
	total_tests += 1
	if mav.are_all_prerequisites_met():
		print("  [PASS] All 3 prerequisites met (Scrubber, Power Unit, Water System). MAV ready for repair.")
		pass_count += 1
	else:
		printerr("  [FAIL] Prerequisites check failed after setting repairs true.")

	# 3. Simulate hold-E for 3 seconds
	mav.is_player_nearby = true
	mav._try_start_repair()
	mav.advance_repair_hold(1.5, true)
	# Check early release cancels with no cost
	mav.advance_repair_hold(0.1, false)
	var cancel_ok = not mav.is_holding_repair
	# Now complete full 3.0s hold
	mav._try_start_repair()
	mav.advance_repair_hold(1.5, true)
	mav.advance_repair_hold(1.6, true) # totals 3.1s >= 3.0s
	total_tests += 1
	if mav.is_repaired and cancel_ok:
		print("  [PASS] 3.0-second hold-E repair completes successfully; early release cancels.")
		pass_count += 1
	else:
		printerr("  [FAIL] MAV repair hold failed to complete: repaired=%s, cancel_ok=%s" % [mav.is_repaired, cancel_ok])

	# 4. Liftoff translation check
	total_tests += 1
	var base_y = mav.rocket_root.position.y if mav.rocket_root else 0.0
	mav.set_liftoff_progress(0.5)
	var mid_y = mav.rocket_root.position.y if mav.rocket_root else 0.0
	mav.set_liftoff_progress(1.0)
	var final_y = mav.rocket_root.position.y if mav.rocket_root else 0.0
	if final_y > base_y + 400.0:
		print("  [PASS] MAV liftoff translation verified: base=%.1f, mid=%.1f, final=%.1f (ascending into space)" % [base_y, mid_y, final_y])
		pass_count += 1
	else:
		printerr("  [FAIL] Liftoff translation: final_y=%.1f (expected > base+400)" % final_y)

	mav.queue_free()

	# ------------------------------------------------------------------
	# PART E: SCENE INTEGRITY, CAVES & FRAMETIME
	# ------------------------------------------------------------------
	print("\n>>> [PART E: SCENE INTEGRITY, CAVES & PERFORMANCE]")
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)

	for i in range(15):
		await process_frame

	# Warm up 5 physics frames
	for f in 5:
		world._physics_process(0.016667)

	# Measure frametime over 60 physics frames
	var t0 = Time.get_ticks_usec()
	for f in 60:
		world._physics_process(0.016667)
	var t1 = Time.get_ticks_usec()
	var avg_ms = (t1 - t0) / 60000.0
	print("  [PERFORMANCE] Average world _physics_process time: %.4f ms per frame (Threshold <= 2.0 ms)" % avg_ms)
	total_tests += 1
	if avg_ms <= 2.0:
		print("  [PASS] Performance verified: %.4f ms <= 2.0 ms frametime delta." % avg_ms)
		pass_count += 1
	else:
		printerr("  [FAIL] Performance delta exceeded 2.0 ms: %.4f ms" % avg_ms)

	# Check cave raycasts
	var planet = world.get_node_or_null("ProceduralMars")
	if not planet:
		planet = world.planet
	var caves_open = 0
	var cave_count = world.cave_defs.size()
	for i in cave_count:
		var pit_pt = planet.get_cave_pit_surface_point(i)
		var pit_normal = (pit_pt - planet.global_position).normalized()
		var ray_origin = pit_pt + pit_normal * 8.0
		var ray_target = pit_pt - pit_normal * 8.0
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		var result = world.get_world_3d().direct_space_state.intersect_ray(query)
		var cave_name = world.cave_defs[i]["name"]
		if result.is_empty():
			print("  [CAVE CHECK] %s: OPEN" % cave_name)
			caves_open += 1
		elif result["collider"] != planet.static_body:
			print("  [CAVE CHECK] %s: OPEN" % cave_name)
			caves_open += 1
		else:
			var hit_depth = (result["position"] - pit_pt).dot(pit_normal)
			if hit_depth < -1.5:
				print("  [CAVE CHECK] %s: OPEN" % cave_name)
				caves_open += 1
			else:
				print("  [CAVE CHECK] %s: BLOCKED" % cave_name)
	
	total_tests += 1
	if caves_open == cave_count and cave_count > 0:
		print("  [PASS] All %d geological caves verified OPEN via physics ray check." % caves_open)
		pass_count += 1
	else:
		printerr("  [FAIL] Cave opening check: %d / %d open" % [caves_open, cave_count])

	world.queue_free()

	print("\n======================================================================")
	print("VERIFICATION RESULTS: %d / %d TESTS PASSED (100%% REQUIRED)" % [pass_count, total_tests])
	print("======================================================================\n")
	
	if pass_count == total_tests:
		print("ALL CHECKS PASSED PERFECTLY!\n")
		quit(0)
	else:
		printerr("ONE OR MORE CHECKS FAILED!\n")
		quit(1)
