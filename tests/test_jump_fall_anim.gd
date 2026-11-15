extends SceneTree

# test_jump_fall_anim.gd
# Validates jump vs running/walking downhill on slopes for PlanetWalker.

func _init() -> void:
	print("\n========================================")
	print("TESTING NATURAL GROUND & JUMP ANIMATION")
	print("========================================")
	
	var walker_script = load("res://Scripts/player/planet_walker.gd")
	var walker = CharacterBody3D.new()
	walker.set_script(walker_script)
	
	var ap = AnimationPlayer.new()
	var lib = load("res://Assets/astronaut_animations.tres") as AnimationLibrary
	ap.add_animation_library("", lib)
	walker.anim_player = ap
	walker.add_child(ap)
	
	var passed = 0
	var total = 4
	
	# Case 1: Intentional jump explicitly triggered
	walker.is_jumping = true
	walker._update_animation_state(2.0, false)
	if ap.current_animation == "jump":
		print("[TEST 1] Explicit jump plays 'jump': PASS")
		passed += 1
	else:
		printerr("[TEST 1] Explicit jump: FAIL (got: ", ap.current_animation, ")")
	
	# Case 2: Running downhill across crater slopes / bumps WITHOUT jumping
	walker.is_jumping = false
	walker.is_jetpacking = false
	walker._update_animation_state(8.0, true)
	if ap.current_animation == "run":
		print("[TEST 2] Running downhill/slopes stays in 'run' (NO jumping glitch): PASS")
		passed += 1
	else:
		printerr("[TEST 2] Running downhill: FAIL (got: ", ap.current_animation, ")")
	
	# Case 3: Walking across rough terrain WITHOUT jumping
	walker.is_jumping = false
	walker.is_jetpacking = false
	walker._update_animation_state(4.0, false)
	if ap.current_animation == "walk":
		print("[TEST 3] Walking across terrain stays in 'walk' (NO jumping glitch): PASS")
		passed += 1
	else:
		printerr("[TEST 3] Walking across terrain: FAIL (got: ", ap.current_animation, ")")
	
	# Case 4: Standing still on ground
	walker.is_jumping = false
	walker.is_jetpacking = false
	walker._update_animation_state(0.0, false)
	if ap.current_animation == "idle":
		print("[TEST 4] Standing still plays 'idle': PASS")
		passed += 1
	else:
		printerr("[TEST 4] Idle check: FAIL (got: ", ap.current_animation, ")")

	walker.free()

	print("========================================")
	print("RESULTS: %d / %d PASSED" % [passed, total])
	print("========================================")

	if passed == total:
		print("ALL ANIMATION TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		printerr("SOME ANIMATION TESTS FAILED!\n")
		quit(1)
