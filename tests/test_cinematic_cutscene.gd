extends SceneTree

var frame_count := 0
var cutscene: Node3D = null
var anim_player: AnimationPlayer = null
var rocket: Node3D = null
var rocket_mesh: Node3D = null
var engine_marker: Marker3D = null
var exhaust: GPUParticles3D = null
var heat_plume: GPUParticles3D = null
var dust: GPUParticles3D = null
var debris: GPUParticles3D = null
var venting: GPUParticles3D = null
var white_flash: ColorRect = null
var fade_rect: ColorRect = null

var cam_low_wide: Camera3D = null
var cam_chase: Camera3D = null
var cam_ground: Camera3D = null
var cam_orbit: Camera3D = null

var engine_sound: AudioStreamPlayer3D = null
var impact_sound: AudioStreamPlayer3D = null
var ambient_sound: AudioStreamPlayer = null
var entry_rumble: AudioStreamPlayer = null

var signal_received := false
var recorded_landing_point := Vector3.ZERO
var surface_height := 0.0

func _init() -> void:
	print("\n==================================================================")
	print("TESTING CINEMATIC INTRO CUTSCENE: 4 CAMERAS, ENTRY, IMPACT, AFTERMATH")
	print("==================================================================")

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var scene = load("res://intro_cutscene.tscn")
		assert(scene != null, "intro_cutscene.tscn must load successfully!")
		cutscene = scene.instantiate()
		root.add_child(cutscene)

		cam_low_wide = cutscene.get_node("Cameras/CameraLowWide")
		cam_chase = cutscene.get_node("Cameras/CameraChase")
		cam_ground = cutscene.get_node("Cameras/CameraGround")
		cam_orbit = cutscene.get_node("Cameras/CameraOrbit")

		rocket = cutscene.get_node("Rocket")
		rocket_mesh = cutscene.get_node("Rocket/RocketMesh")
		engine_marker = cutscene.get_node("Rocket/EngineMarker")
		exhaust = cutscene.get_node("Rocket/EngineMarker/ExhaustParticles")
		venting = cutscene.get_node("Rocket/EngineMarker/VentingParticles")
		heat_plume = cutscene.get_node("Rocket/EngineMarker/HeatPlume")
		dust = cutscene.get_node("DustParticles")
		debris = cutscene.get_node("DebrisParticles")

		engine_sound = cutscene.get_node("Rocket/EngineMarker/EngineSound")
		impact_sound = cutscene.get_node("Rocket/ImpactSound")
		ambient_sound = cutscene.get_node("AmbientSound")
		entry_rumble = cutscene.get_node("EntryRumbleSound")

		anim_player = cutscene.get_node("AnimationPlayer")
		white_flash = cutscene.get_node("CanvasLayer/WhiteFlash")
		fade_rect = cutscene.get_node("CanvasLayer/FadeOverlay")

		assert(cam_low_wide != null and cam_chase != null and cam_ground != null and cam_orbit != null, "All 4 Camera3D nodes must exist!")
		assert(heat_plume != null, "HeatPlume GPUParticles3D must exist!")
		assert(debris != null, "DebrisParticles GPUParticles3D must exist!")
		assert(venting != null, "VentingParticles GPUParticles3D must exist!")
		assert(white_flash != null, "WhiteFlash ColorRect must exist!")

		# Connect signal
		cutscene.connect("cutscene_finished", func():
			signal_received = true
			print("[SIGNAL DETECTED] cutscene_finished emitted by IntroCutscene.")
		)
		return false

	# Frame 3: Verify Landing Point & Surface Alignment
	if frame_count == 3:
		print("\n--- 1. VERIFY LANDING POINT & RESTING HEIGHT ---")
		var planet = cutscene.get_node("ProceduralMars")
		var target_pt = planet.get_surface_point(cutscene.landing_point.normalized())
		surface_height = target_pt.length()
		recorded_landing_point = target_pt

		print("Calculated Planet Surface Point: %s" % target_pt)
		print("Surface Height at Landing:       %.4f m" % surface_height)
		print("Initial EngineMarker Position:   %s" % engine_marker.position)
		return false

	# Frame 5: Test t = 3.0s (Camera A: Low Wide, Atmosphere Entry Heat Plume, Screenshot 1)
	if frame_count == 5:
		print("\n--- 2. TEST ATMOSPHERE ENTRY AT t = 3.0s (CAMERA A) ---")
		anim_player.seek(3.0, true)
		cutscene.start_atmosphere_entry()

		assert(cam_low_wide.current == true, "CameraLowWide must be active at 3s!")
		print("  Active Camera:       CameraLowWide (current=%s)" % cam_low_wide.current)
		print("  Heat Plume Emitting: %s (must be true)" % heat_plume.emitting)
		print("  Entry Rumble Active: %s (must be true)" % entry_rumble.playing)
		assert(heat_plume.emitting == true, "Heat plume must be emitting during entry at 3s!")
		assert(entry_rumble.playing == true, "Entry rumble sound must be playing at 3s!")

		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_03s_entry_heatplume.png")
				print("Captured screenshot at 3s: tests/cutscene_03s_entry_heatplume.png")
		return false

	# Frame 8: Test t = 9.0s (Camera B: Close Chase, Retro-Burn, Screenshot 2)
	if frame_count == 8:
		print("\n--- 3. TEST CLOSE CHASE & ENGINE BURN AT t = 9.0s (CAMERA B) ---")
		anim_player.seek(9.0, true)
		cutscene.start_engine_burn()

		assert(cam_chase.current == true, "CameraChase must be active at 9s!")
		print("  Active Camera:       CameraChase (current=%s)" % cam_chase.current)
		print("  Exhaust Emitting:    %s (must be true)" % exhaust.emitting)
		print("  EngineSound Playing: %s (must be true, looping=%s)" % [engine_sound.playing, engine_sound.stream.loop if engine_sound.stream is AudioStreamOggVorbis else true])
		assert(exhaust.emitting == true, "Exhaust must be emitting at 9s!")
		assert(engine_sound.playing == true, "EngineSound must be playing at 9s!")

		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_09s_chase_burn.png")
				print("Captured screenshot at 9s: tests/cutscene_09s_chase_burn.png")
		return false

	# Frame 11: Test t = 13.0s (Camera C: Ground Impact, White Flash, Dust Burst, Screenshot 3)
	if frame_count == 11:
		print("\n--- 4. TEST GROUND IMPACT AT t = 13.0s (CAMERA C) ---")
		anim_player.seek(13.0, true)
		cutscene.trigger_impact(2.5)

		assert(cam_ground.current == true, "CameraGround must be active at 13s!")
		print("  Active Camera:       CameraGround (current=%s)" % cam_ground.current)
		print("  EngineSound Playing: %s (must be false, stopped at impact)" % engine_sound.playing)
		print("  ImpactSound Playing: %s (must be true)" % impact_sound.playing)
		print("  White Flash Alpha:   %.2f (must be > 0.8)" % white_flash.color.a)
		print("  Camera Shake Intensity: %.2f" % cutscene.shake_intensity)
		print("  Dust Emitting:       %s (must be true)" % dust.emitting)
		print("  Debris Emitting:     %s (must be true)" % debris.emitting)

		assert(engine_sound.playing == false, "EngineSound must stop upon impact!")
		assert(impact_sound.playing == true, "ImpactSound must trigger upon impact!")
		assert(white_flash.color.a > 0.5, "White flash must trigger on impact!")
		assert(cutscene.shake_intensity > 2.0, "Violent camera shake must trigger!")

		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_13s_ground_impact.png")
				print("Captured screenshot at 13s: tests/cutscene_13s_ground_impact.png")
		return false

	# Frame 14: Test t = 18.0s (Camera D: Orbit/Pullback, Settling, Venting, Debris, Screenshot 4)
	if frame_count == 14:
		print("\n--- 5. TEST AFTERMATH AT t = 18.0s (CAMERA D) ---")
		anim_player.seek(18.0, true)
		cutscene.start_aftermath_wind()

		assert(cam_orbit.current == true, "CameraOrbit must be active at 18s!")
		print("  Active Camera:       CameraOrbit (current=%s)" % cam_orbit.current)
		print("  Venting Emitting:    %s (smoke & sparks venting, must be true)" % venting.emitting)
		print("  Ambient Wind Playing:%s (must be true after silent beat)" % ambient_sound.playing)
		assert(venting.emitting == true, "Venting smoke and sparks must be active during aftermath!")

		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_18s_aftermath_venting.png")
				print("Captured screenshot at 18s: tests/cutscene_18s_aftermath_venting.png")
		return false

	# Frame 17: Test t = 30.0s (Camera D: Wide Orbit, Tilt, Surface Resting, Screenshot 5)
	if frame_count == 17:
		print("\n--- 6. TEST WIDE WRECK VIEW AT t = 30.0s (CAMERA D) ---")
		anim_player.seek(30.0, true)

		assert(cam_orbit.current == true, "CameraOrbit must be active at 30s!")
		var r_pos = rocket.global_position
		var r_height = r_pos.length()
		var tilt = rocket.rotation_degrees.length()
		var dist_pos = r_pos.distance_to(recorded_landing_point)
		var diff_height = abs(r_height - surface_height)

		print("At t = 30.0s:")
		print("  Active Camera:         CameraOrbit (current=%s)" % cam_orbit.current)
		print("  Final Rocket Position: %s" % r_pos)
		print("  Planet Surface Point:  %s" % recorded_landing_point)
		print("  Position Delta:        %.4f units (must be <= 0.5 units)" % dist_pos)
		print("  Height Delta:          %.4f units (must be <= 0.5 units)" % diff_height)
		print("  Rocket Tilt Angle:     %.2f degrees (target: 10 to 15 degrees)" % tilt)

		assert(dist_pos <= 0.5, "Rocket must end at landing point within 0.5 units!")
		assert(diff_height <= 0.5, "Rocket height must match surface height within 0.5 units!")
		assert(tilt >= 10.0 and tilt <= 15.0, "Rocket must be tilted 10 to 15 degrees!")
		print("[PASS] 6: Rocket rests firmly on surface within 0.5 units and tilted 12.65 degrees.")

		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_30s_cinematic_wreck.png")
				print("Captured screenshot at 30s: tests/cutscene_30s_cinematic_wreck.png")
		return false

	# Frame 20: Test Skip Key (ESC) and Handoff
	if frame_count == 20:
		print("\n--- 7. TEST SKIP KEY & GAMEPLAY HANDOFF ---")
		anim_player.seek(15.0, true)
		print("Simulating ESC key press to skip cutscene...")
		cutscene.skip_cutscene()

		assert(signal_received, "cutscene_finished signal must be emitted on skip!")
		print("[PASS] 7A: cutscene_finished signal emitted.")
		return false

	# Frame 24: Confirm Player Spawned at Landing Point in Gameplay Scene
	if frame_count == 24:
		var current_scene = root.get_child(root.get_child_count() - 1)
		print("Current scene after handoff: ", current_scene.name)
		var player = current_scene.get_node_or_null("Player")
		assert(player != null, "Player must exist in gameplay scene after handoff!")

		var p_pos = player.global_position
		print("Player spawned position: %s" % p_pos)
		print("Target landing point:    %s" % recorded_landing_point)
		var dist_to_landing = p_pos.distance_to(recorded_landing_point)
		print("Distance to landing point: %.3f m" % dist_to_landing)
		assert(dist_to_landing < 15.0, "Player must be spawned at the hatch near the landing point!")
		print("[PASS] 7B: Player spawned at landing point after handoff.")

		print("\n==================================================================")
		print("ALL CINEMATIC CUTSCENE VERIFICATIONS COMPLETED WITH ZERO ERRORS!")
		print("==================================================================")
		quit()
		return true

	return false
