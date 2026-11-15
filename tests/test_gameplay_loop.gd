extends SceneTree

# test_gameplay_loop.gd
# Headless integration test for NASA Space Apps Mars Mission Trainer.
# Validates crash pod solar deployment, NASA artifact collection, MAV repair, and liftoff.

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")
const ReturnVehicleScene = preload("res://Scenes/machines/return_vehicle.tscn")
const CrashedPodScene = preload("res://Scenes/machines/crashed_pod.tscn")
const MissionEventMgr = preload("res://Scripts/events/mission_event_manager.gd")

func _init() -> void:
	print("\n========================================")
	print("RUNNING MARS GAMEPLAY INTEGRATION TESTS")
	print("========================================")
	
	var passed = 0
	var total = 5

	# TEST 1: Crashed Pod & Solar Deployment
	var pod: CrashedPod = CrashedPodScene.instantiate()
	var survival := SurvivalSystem.new()
	survival.solar_power_gain = 0.0
	
	pod.solar_deployed.connect(func():
		survival.solar_power_gain = 0.8
	)
	pod.deploy_solar()
	if pod.solar_is_deployed and survival.solar_power_gain == 0.8:
		print("[INTEGRATION 1] Crashed pod solar deployment: PASS")
		passed += 1
	else:
		printerr("[INTEGRATION 1] Crashed pod solar deployment: FAIL")
	pod.free()

	# TEST 2: MAV Rocket Repair Progression
	var mav: ReturnVehicle = ReturnVehicleScene.instantiate()
	var p1 = mav.install_part("Navigation Gyroscope")
	var p2 = mav.install_part("Heat Shield Ceramic Tile")
	var p3 = mav.install_part("Solar Array Relay")
	if p1 and p2 and p3 and not mav.is_fully_repaired() and mav.installed_parts.size() == 3:
		print("[INTEGRATION 2] Partial MAV repairs (3/4 parts): PASS")
		passed += 1
	else:
		printerr("[INTEGRATION 2] Partial MAV repairs: FAIL")

	# TEST 3: Final Part & Repair Completion
	var p4 = mav.install_part("Methane Fuel Injector")
	if p4 and mav.is_fully_repaired():
		print("[INTEGRATION 3] Full MAV restoration (4/4 parts): PASS")
		passed += 1
	else:
		printerr("[INTEGRATION 3] Full MAV restoration: FAIL")

	# TEST 4: Rocket Launch & Victory Trigger
	var win_triggered = {"won": false}
	mav.launch_success.connect(func():
		win_triggered["won"] = true
	)
	mav.launch_rocket()
	if mav.is_launched:
		print("[INTEGRATION 4] Rocket liftoff initialization: PASS")
		passed += 1
	else:
		printerr("[INTEGRATION 4] Rocket liftoff initialization: FAIL")
	mav.free()

	# TEST 5: Mission Event Manager Simulation
	var event_mgr = MissionEventMgr.new()
	var survival2 = SurvivalSystem.new()
	event_mgr.initialize(survival2, null)
	event_mgr.tutorial_sol_safe = false
	event_mgr._trigger_dust_storm()
	if survival2.dust_storm_active:
		event_mgr._end_current_event()
		if not survival2.dust_storm_active:
			print("[INTEGRATION 5] Dust storm event trigger & clearing: PASS")
			passed += 1
		else:
			printerr("[INTEGRATION 5] Dust storm clear: FAIL")
	else:
		printerr("[INTEGRATION 5] Dust storm trigger: FAIL")
	event_mgr.free()

	print("========================================")
	print("INTEGRATION RESULTS: %d / %d PASSED" % [passed, total])
	print("========================================")

	if passed == total:
		print("ALL INTEGRATION TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		printerr("SOME INTEGRATION TESTS FAILED!\n")
		quit(1)
