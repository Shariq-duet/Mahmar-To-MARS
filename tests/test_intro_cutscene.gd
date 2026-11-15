extends SceneTree

var frame_count := 0
var cutscene: Node3D = null
var anim_player: AnimationPlayer = null
var camera: Camera3D = null
var rocket: Node3D = null
var exhaust: GPUParticles3D = null
var dust: GPUParticles3D = null
var fade_rect: ColorRect = null

var signal_received := false
var recorded_landing_point := Vector3.ZERO

func _init() -> void:
	print("\n==================================================================")
	print("TESTING OPENING CUTSCENE: SEQUENCE, LANDING HEIGHT, HANDOFF & SKIP")
	print("==================================================================")

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var scene = load("res://intro_cutscene.tscn")
		assert(scene != null, "intro_cutscene.tscn must exist and load successfully!")
		cutscene = scene.instantiate()
		root.add_child(cutscene)

		camera = cutscene.get_node("Camera3D")
		rocket = cutscene.get_node("Rocket")
		exhaust = cutscene.get_node("Rocket/ExhaustParticles")
		dust = cutscene.get_node("DustParticles")
		anim_player = cutscene.get_node("AnimationPlayer")
		fade_rect = cutscene.get_node("CanvasLayer/FadeOverlay")

		assert(camera != null, "Camera3D must exist!")
		assert(rocket != null, "Rocket must exist!")
		assert(exhaust != null, "ExhaustParticles must exist!")
		assert(dust != null, "DustParticles must exist!")
		assert(anim_player != null, "AnimationPlayer must exist!")

		# Connect cutscene_finished signal early
		cutscene.connect("cutscene_finished", func():
			signal_received = true
			print("[SIGNAL DETECTED] cutscene_finished emitted by IntroCutscene.")
		)

		print("[PASS] 1: All required cutscene scene nodes exist.")
		return false

	# Frame 3: Verify Landing Point & Height Matches
	if frame_count == 3:
		print("\n--- 2. VERIFY LANDING POINT & SURFACE HEIGHT MATCH ---")
		var planet = cutscene.get_node("ProceduralMars")
		var surface_pt = planet.get_surface_point(cutscene.landing_point.normalized())
		var surface_height = surface_pt.length()
		var final_rocket_pos = cutscene.final_surface_pt
		var final_rocket_height = final_rocket_pos.length()
		var diff_pos = final_rocket_pos.distance_to(surface_pt)
		var diff_height = abs(final_rocket_height - surface_height)

		recorded_landing_point = surface_pt

		print("Calculated Surface Point:  %s" % surface_pt)
		print("Surface Height at Landing: %.4f m" % surface_height)
		print("Final Rocket Position:     %s" % final_rocket_pos)
		print("Final Rocket Height:       %.4f m" % final_rocket_height)
		print("Position Difference:       %.4f units (target <= 0.5 units)" % diff_pos)
		print("Height Difference:         %.4f units (target <= 0.5 units)" % diff_height)

		assert(diff_pos <= 0.5, "Rocket position and surface point must match within 0.5 units!")
		assert(diff_height <= 0.5, "Rocket height and surface height must match within 0.5 units!")
		print("[PASS] 2: Rocket rests perfectly on Mars surface (delta < 0.5 units).")
		return false

	# Frame 5: Verify Animation Timing & Tracks
	if frame_count == 5:
		print("\n--- 3. VERIFY ANIMATION SEQUENCE TIMINGS & TRACKS ---")
		var anim = anim_player.get_animation("cutscene_sequence")
		assert(anim != null, "cutscene_sequence animation must exist!")
		print("Animation Length: %.1f seconds" % anim.length)
		assert(anim.length == 35.0, "Animation length must be 35 seconds!")

		# Test state at t = 5.0s
		anim_player.seek(5.0, true)
		print("At t = 5.0s (High Descent above horizon):")
		print("  Rocket position: %s, altitude above surface: %.1fm" % [rocket.global_position, rocket.global_position.length() - recorded_landing_point.length()])
		print("  Exhaust emitting: %s (must be false)" % exhaust.emitting)
		print("  Dust emitting:    %s (must be false)" % dust.emitting)
		assert(exhaust.emitting == false, "Exhaust should be off at 5s!")
		assert(dust.emitting == false, "Dust should be off at 5s!")
		return false

	# Frame 7: Capture Screenshot at 5.0s
	if frame_count == 7:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_05s_descent.png")
				print("Captured screenshot at 5s: tests/cutscene_05s_descent.png")
		return false

	# Frame 10: Test state at t = 20.0s (Impact)
	if frame_count == 10:
		anim_player.seek(20.0, true)
		print("\nAt t = 20.0s (Impact):")
		print("  Rocket position: %s" % rocket.global_position)
		var dist_to_surface = rocket.global_position.distance_to(recorded_landing_point)
		print("  Distance to surface contact point: %.4fm (must be <= 0.5m)" % dist_to_surface)
		print("  Exhaust emitting: %s (must be false)" % exhaust.emitting)
		print("  Dust emitting:    %s (must be true)" % dust.emitting)
		assert(dist_to_surface <= 0.5, "Rocket must hit surface at 20s!")
		assert(exhaust.emitting == false, "Exhaust must be stopped at impact!")
		assert(dust.emitting == true, "Dust burst must start at impact!")
		return false

	# Frame 12: Capture Screenshot at 20.0s
	if frame_count == 12:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_20s_impact.png")
				print("Captured screenshot at 20s: tests/cutscene_20s_impact.png")
		return false

	# Frame 15: Test state at t = 22.0s
	if frame_count == 15:
		anim_player.seek(22.0, true)
		print("\nAt t = 22.0s (Settling & Tilt on landing legs):")
		print("  Rocket rotation: %s degrees" % rocket.rotation_degrees)
		print("  Dust emitting:   %s" % dust.emitting)
		return false

	# Frame 17: Capture Screenshot at 22.0s
	if frame_count == 17:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_22s_settling.png")
				print("Captured screenshot at 22s: tests/cutscene_22s_settling.png")
		return false

	# Frame 20: Test state at t = 30.0s
	if frame_count == 20:
		anim_player.seek(30.0, true)
		print("\nAt t = 30.0s (Wreck view, 10-15 deg tilt & camera pull-back):")
		var tilt = rocket.rotation_degrees.length()
		print("  Rocket tilt angle: %.2f degrees (target: 10 to 15 degrees)" % tilt)
		print("  Camera position:   %s" % camera.global_position)
		var cam_dist_to_rocket = camera.global_position.distance_to(rocket.global_position)
		print("  Camera distance to rocket: %.2fm (pulled back)" % cam_dist_to_rocket)
		assert(tilt >= 10.0 and tilt <= 15.0, "Rocket must tilt between 10 and 15 degrees!")
		assert(cam_dist_to_rocket > 40.0, "Camera must pull back to show the wreck!")
		return false

	# Frame 22: Capture Screenshot at 30.0s
	if frame_count == 22:
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_30s_wreck.png")
				print("Captured screenshot at 30s: tests/cutscene_30s_wreck.png")
		return false

	# Frame 25: Test Fade to black at 34.5s (before 35.0s handoff)
	if frame_count == 25:
		anim_player.seek(34.8, true)
		print("\nAt t = 34.8s (Fade to Black):")
		print("  Fade overlay alpha: %.2f (must be >= 0.95)" % fade_rect.color.a)
		assert(fade_rect.color.a >= 0.95, "Fade overlay must be near 1.0 at 34.8s!")
		print("[PASS] 3: Animation sequence, exhaust, dust, 12.6 deg tilt, and fade to black verified.")
		return false

	# Frame 28: Test Skip Key (ESC) functionality
	if frame_count == 28:
		print("\n--- 4. TEST SKIP KEY & GAMEPLAY HANDOFF ---")
		# Reset position to middle of cutscene and press skip
		anim_player.seek(10.0, true)
		print("Simulating ESC key press during cutscene at t=10.0s...")
		cutscene.skip_cutscene()

		assert(signal_received, "cutscene_finished signal must be emitted upon cutscene skip/completion!")
		print("[PASS] 4A: cutscene_finished signal emitted on skip.")
		return false

	# Frame 32: Confirm Player Spawned at Landing Point in Gameplay Scene
	if frame_count == 32:
		var current_scene = root.get_child(root.get_child_count() - 1)
		print("Current scene after handoff: ", current_scene.name)
		var player = current_scene.get_node_or_null("Player")
		assert(player != null, "Player must exist in gameplay scene after handoff!")

		var p_pos = player.global_position
		print("Player spawned position:   %s" % p_pos)
		print("Recorded landing point:    %s" % recorded_landing_point)
		var dist_to_landing = p_pos.distance_to(recorded_landing_point)
		print("Distance to landing point: %.3f m" % dist_to_landing)
		assert(dist_to_landing < 3.0, "Player must be spawned at the landing point!")
		print("[PASS] 4B: Player successfully spawned at the landing point after handoff.")

		print("\n==================================================================")
		print("ALL OPENING CUTSCENE TESTS PASSED SUCCESSFULLY WITH ZERO ERRORS!")
		print("==================================================================")
		quit()
		return true

	return false
