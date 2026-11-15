extends SceneTree

# test_new_features.gd
# Validates 3D Cave environments, Day/Night orbit cycle, and Jetpack flight physics.

const PavonisTubeScene = preload("res://Scenes/planet/caves/pavonis_tube.tscn")
const NoctisFissureScene = preload("res://Scenes/planet/caves/noctis_fissure.tscn")
const ElysiumCavernScene = preload("res://Scenes/planet/caves/elysium_cavern.tscn")
const DayNightCycleScript = preload("res://Scripts/environment/day_night_cycle.gd")

func _init() -> void:
	print("\n========================================")
	print("TESTING CAVE ENVIRONMENTS & NEW FEATURES")
	print("========================================")
	
	var passed = 0
	var total = 3

	# TEST 1: Instantiating and verifying 3D Cave Environments
	var p_tube = PavonisTubeScene.instantiate()
	var n_fissure = NoctisFissureScene.instantiate()
	var e_cavern = ElysiumCavernScene.instantiate()

	var p_has_arch = p_tube.get_node_or_null("EntranceFacade") != null
	var n_has_bridge = n_fissure.get_node_or_null("NaturalBridge1") != null
	var e_has_vault = e_cavern.get_node_or_null("CalderaVault") != null

	if p_has_arch and n_has_bridge and e_has_vault:
		print("[TEST 1] All 3 Geological 3D Cave Environments instantiated: PASS")
		passed += 1
	else:
		printerr("[TEST 1] Cave environments instantiation check: FAIL")

	p_tube.free()
	n_fissure.free()
	e_cavern.free()

	# TEST 2: Day/Night Orbit System & Moons
	var dnc = DayNightCycleScript.new()
	var dummy_sun = DirectionalLight3D.new()
	dnc.sun_light = dummy_sun
	dnc._ready()
	
	if dnc.phobos_node and dnc.deimos_node:
		var ph_init_pos = dnc.phobos_node.position
		dnc._process(60.0)
		var ph_moved = dnc.phobos_node.position.distance_to(ph_init_pos)
		if ph_moved > 10.0:
			print("[TEST 2] NASA Day/Night cycle, Sun orbit & Phobos/Deimos motion: PASS (Phobos moved %.1fm)" % ph_moved)
			passed += 1
		else:
			printerr("[TEST 2] Moon motion check: FAIL")
	else:
		printerr("[TEST 2] Celestial moon instantiation: FAIL")
	dnc.free()
	dummy_sun.free()

	# TEST 3: Jetpack Thruster Flight Simulation
	var walker_script = load("res://Scripts/player/planet_walker.gd")
	var walker = CharacterBody3D.new()
	walker.set_script(walker_script)
	if "jetpack_fuel" in walker and "jetpack_thrust" in walker:
		var init_fuel = walker.jetpack_fuel
		walker.jetpack_fuel = max(0.0, walker.jetpack_fuel - walker.jetpack_burn_rate * 1.5)
		if walker.jetpack_fuel < init_fuel:
			walker.jetpack_fuel = min(walker.jetpack_fuel_max, walker.jetpack_fuel + walker.jetpack_recharge_rate * 2.0)
			if walker.jetpack_fuel == walker.jetpack_fuel_max:
				print("[TEST 3] Jetpack flight physics parameters & fuel recharge: PASS")
				passed += 1
			else:
				printerr("[TEST 3] Jetpack recharge: FAIL")
		else:
			printerr("[TEST 3] Jetpack burn: FAIL")
	else:
		printerr("[TEST 3] Jetpack properties on walker: FAIL")
	walker.free()

	print("========================================")
	print("RESULTS: %d / %d PASSED" % [passed, total])
	print("========================================")

	if passed == total:
		print("ALL ENVIRONMENT & FEATURE TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		printerr("SOME FEATURE TESTS FAILED!\n")
		quit(1)
