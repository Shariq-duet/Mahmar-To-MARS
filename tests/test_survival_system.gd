@tool
extends SceneTree

# test_survival_system.gd
# Automated unit tests for SurvivalSystem logic.

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")

func _init() -> void:
	print("========================================")
	print("RUNNING SURVIVAL SYSTEM UNIT TESTS")
	print("========================================")

	var passed := 0
	var total := 0

	total += 1
	if test_oxygen_consumption(): passed += 1

	total += 1
	if test_suit_breach(): passed += 1

	total += 1
	if test_power_and_dust_storm(): passed += 1

	total += 1
	if test_solar_storm_radiation(): passed += 1

	total += 1
	if test_suffocation_death(): passed += 1

	total += 1
	if test_sol_advancement(): passed += 1

	print("========================================")
	print("TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("========================================")
	
	if passed == total:
		print("ALL UNIT TESTS PASSED SUCCESSFULLY!")
	else:
		printerr("SOME TESTS FAILED!")
	
	quit()

func test_oxygen_consumption() -> bool:
	var s = SurvivalSystem.new()
	s.is_in_shelter = false
	s.is_sprinting = false
	
	# 10 seconds of walking
	s.tick(10.0)
	var expected_o2 = 100.0 - (s.base_o2_rate * 10.0)
	var ok = is_equal_approx(s.oxygen, expected_o2)
	print("[TEST 1] Oxygen walk consumption: ", "PASS" if ok else "FAIL", " (O2 = %f)" % s.oxygen)
	
	# Enter shelter -> should refill
	s.is_in_shelter = true
	s.tick(2.0)
	var ok2 = s.oxygen > expected_o2
	print("[TEST 1b] Oxygen shelter refill: ", "PASS" if ok2 else "FAIL", " (O2 = %f)" % s.oxygen)
	return ok and ok2

func test_suit_breach() -> bool:
	var s = SurvivalSystem.new()
	s.is_in_shelter = false
	s.apply_suit_damage(80.0) # suit integrity down to 20 (< 25 = breach)
	
	var has_breach = s.has_suit_breach
	s.tick(5.0)
	# rate should be base (0.5) + breach (2.0) = 2.5/s -> 12.5 in 5s
	var ok = is_equal_approx(s.oxygen, 100.0 - 12.5)
	
	s.use_repair_kit() # suit integrity restored to 70 (> 25)
	var fixed = not s.has_suit_breach
	print("[TEST 2] Suit breach & repair kit: ", "PASS" if (has_breach and ok and fixed) else "FAIL")
	return has_breach and ok and fixed

func test_power_and_dust_storm() -> bool:
	var s = SurvivalSystem.new()
	s.power = 50.0
	s.dust_storm_active = false
	
	# Daylight solar generation: net +0.5/s
	s.tick(10.0)
	var gain_ok = s.power > 50.0
	
	# Turn on dust storm: net power drops
	s.dust_storm_active = true
	var p_before = s.power
	s.tick(10.0)
	var loss_ok = s.power < p_before
	print("[TEST 3] Power & dust storm generation: ", "PASS" if (gain_ok and loss_ok) else "FAIL")
	return gain_ok and loss_ok

func test_solar_storm_radiation() -> bool:
	var s = SurvivalSystem.new()
	s.is_in_shelter = false
	s.solar_storm_active = true
	
	s.tick(5.0)
	var rad_outside = s.radiation
	var outside_ok = rad_outside > 30.0 # rapid spike outside
	
	# Move to shelter with shield active
	s.is_in_shelter = true
	s.is_shield_active = true
	s.tick(5.0)
	var shield_ok = s.radiation < rad_outside
	print("[TEST 4] Solar storm radiation protection: ", "PASS" if (outside_ok and shield_ok) else "FAIL")
	return outside_ok and shield_ok

func test_suffocation_death() -> bool:
	var s = SurvivalSystem.new()
	s.oxygen = 0.0
	s.is_in_shelter = false
	var res = {"died": false, "reason": ""}
	s.player_died.connect(func(reason: String):
		res["died"] = true
		res["reason"] = reason
	)
	
	# Run 10 seconds with 0 O2 (12 dmg/sec = 120 dmg -> lethal)
	s.tick(10.0)
	var ok = (res["died"] and res["reason"] == "Oxygen Depletion" and s.health <= 0.0)
	print("[TEST 5] Suffocation death signal: ", "PASS" if ok else "FAIL", " (Reason: %s)" % res["reason"])
	return ok

func test_sol_advancement() -> bool:
	var s = SurvivalSystem.new()
	var res = {"new_sol": 1}
	s.sol_advanced.connect(func(sol: int):
		res["new_sol"] = sol
	)
	
	# Advance 605 seconds (1 sol duration = 600s)
	s.tick(605.0)
	var ok = (res["new_sol"] == 2 and s.current_sol == 2)
	print("[TEST 6] Sol day advancement: ", "PASS" if ok else "FAIL", " (Sol = %d)" % s.current_sol)
	return ok
