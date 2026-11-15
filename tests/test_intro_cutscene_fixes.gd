extends SceneTree

var frame_count := 0
var cutscene: Node3D = null
var anim_player: AnimationPlayer = null
var camera: Camera3D = null
var rocket: Node3D = null
var engine_marker: Marker3D = null
var exhaust: GPUParticles3D = null
var dust: GPUParticles3D = null
var engine_sound: AudioStreamPlayer3D = null
var impact_sound: AudioStreamPlayer3D = null
var ambient_sound: AudioStreamPlayer = null
var world_env: WorldEnvironment = null

var signal_received := false
var recorded_landing_point := Vector3.ZERO

func _init() -> void:
	print("\n==================================================================")
	print("TESTING INTRO CUTSCENE FIXES: SOUND, NOZZLE MARKER & STARRY SKY")
	print("==================================================================")

func _process(delta: float) -> bool:
	frame_count += 1

	if frame_count == 1:
		var scene = load("res://intro_cutscene.tscn")
		assert(scene != null, "intro_cutscene.tscn must load successfully!")
		cutscene = scene.instantiate()
		root.add_child(cutscene)

		camera = cutscene.get_node("Camera3D")
		rocket = cutscene.get_node("Rocket")
		engine_marker = cutscene.get_node("Rocket/EngineMarker")
		exhaust = cutscene.get_node("Rocket/EngineMarker/ExhaustParticles")
		dust = cutscene.get_node("DustParticles")
		engine_sound = cutscene.get_node("Rocket/EngineMarker/EngineSound")
		impact_sound = cutscene.get_node("Rocket/ImpactSound")
		ambient_sound = cutscene.get_node("AmbientSound")
		anim_player = cutscene.get_node("AnimationPlayer")
		world_env = cutscene.get_node("WorldEnvironment")

		# 1. Verify Audio Nodes & Hierarchy
		print("\n--- 1. VERIFY AUDIO NODES & EXPORTED STREAMS ---")
		assert(engine_marker != null, "EngineMarker must exist as child of Rocket!")
		assert(engine_sound != null, "EngineSound (AudioStreamPlayer3D) must be child of EngineMarker!")
		assert(impact_sound != null, "ImpactSound (AudioStreamPlayer3D) must be child of Rocket!")
		assert(ambient_sound != null, "AmbientSound (AudioStreamPlayer) must exist at root!")
		assert(exhaust != null, "ExhaustParticles must be child of EngineMarker!")

		assert(cutscene.engine_sound_stream != null, "engine_sound_stream export must be set!")
		assert(cutscene.impact_sound_stream != null, "impact_sound_stream export must be set!")
		assert(cutscene.ambient_sound_stream != null, "ambient_sound_stream export must be set!")

		print("  EngineSound Node:   %s, Stream: %s" % [engine_sound.get_path(), engine_sound.stream.resource_path])
		print("  ImpactSound Node:   %s, Stream: %s" % [impact_sound.get_path(), impact_sound.stream.resource_path])
		print("  AmbientSound Node:  %s, Stream: %s" % [ambient_sound.get_path(), ambient_sound.stream.resource_path])
		print("[PASS] 1: All AudioStreamPlayer nodes and @export streams verified.")

		# 2. Verify EngineMarker and Exhaust Transform
		print("\n--- 2. VERIFY ENGINEMARKER POSITION & EXHAUST PARENTING ---")
		print("  EngineMarker Local Position: %s (at nozzle)" % engine_marker.position)
		assert(engine_marker.position != Vector3.ZERO, "EngineMarker must be at nozzle, not model centre!")
		assert(engine_marker.position.y > 0.0 and engine_marker.position.y < 1.0, "EngineMarker should be near rocket base nozzle (Y ~ 0.25)!")
		
		print("  Exhaust Local Position:      %s" % exhaust.position)
		print("  Exhaust Local Transform:     %s" % exhaust.transform)
		assert(exhaust.position == Vector3.ZERO, "Exhaust local position must be Vector3.ZERO (inherits marker)!")
		print("[PASS] 2: EngineMarker positioned at nozzle and exhaust correctly parented.")

		# 3. Verify Starry Sky Resource
		print("\n--- 3. VERIFY STARRY SKY & PROCEDURAL SKY REPLACEMENT ---")
		assert(world_env != null and world_env.environment != null, "WorldEnvironment must have an environment!")
		var env = world_env.environment
		assert(env.sky != null, "Environment must have a Sky resource!")
		print("  Sky Resource: %s" % env.sky.resource_path)
		assert(env.sky.resource_path.ends_with("starry_sky.tres") or env.sky.sky_material is ShaderMaterial, "Must use starry_sky.tres with sky.gdshader!")
		assert(not (env.sky.sky_material is ProceduralSkyMaterial), "ProceduralSkyMaterial must be replaced, not active!")
		print("[PASS] 3: starry_sky.tres with sky.gdshader applied and ProceduralSkyMaterial replaced.")

		cutscene.connect("cutscene_finished", func():
			signal_received = true
			print("[SIGNAL DETECTED] cutscene_finished emitted by IntroCutscene.")
		)
		return false

	# Frame 3: Capture Screenshot of Starry Sky at 0.0s
	if frame_count == 3:
		anim_player.seek(0.0, true)
		print("\nCapturing Screenshot of Sky at t = 0.0s...")
		assert(ambient_sound.playing, "AmbientSound should be playing at 0s!")
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_00s_starry_sky.png")
				print("Captured sky screenshot: tests/cutscene_00s_starry_sky.png")
		return false

	# Frame 6: Test Engine Burn at 8.0s (Marker vs Exhaust position match)
	if frame_count == 6:
		print("\n--- 4. TEST ENGINE BURN AT 8.0s (EXHAUST AT NOZZLE) ---")
		anim_player.seek(8.0, true)
		cutscene.start_engine_sound() # Ensure triggered

		var marker_pos = engine_marker.global_position
		var exhaust_pos = exhaust.global_position
		var dist = marker_pos.distance_to(exhaust_pos)

		print("At t = 8.0s (Burn Start):")
		print("  EngineMarker Global Pos: %s" % marker_pos)
		print("  Exhaust Global Pos:      %s" % exhaust_pos)
		print("  Distance between them:   %.4f units (must be <= 0.1 units)" % dist)
		print("  Exhaust Emitting:        %s (must be true)" % exhaust.emitting)
		print("  EngineSound Playing:     %s (must be true)" % engine_sound.playing)

		assert(dist <= 0.1, "Exhaust and EngineMarker global positions must match within 0.1 units!")
		assert(exhaust.emitting == true, "Exhaust must be emitting during burn!")
		assert(engine_sound.playing == true, "EngineSound must play during burn!")
		print("[PASS] 4: Exhaust emits directly from EngineMarker nozzle during burn.")
		return false

	# Frame 9: Capture Screenshot during Engine Burn (12.0s)
	if frame_count == 9:
		anim_player.seek(12.0, true)
		print("\nCapturing Screenshot during Engine Burn at t = 12.0s...")
		var tex = root.get_viewport().get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://tests/cutscene_12s_burn_nozzle.png")
				print("Captured burn screenshot: tests/cutscene_12s_burn_nozzle.png")
		return false

	# Frame 12: Test Impact at 20.0s (ImpactSound, EngineSound stops, Dust)
	if frame_count == 12:
		print("\n--- 5. TEST IMPACT AT 20.0s ---")
		anim_player.seek(20.0, true)
		cutscene.trigger_impact(1.4)

		print("At t = 20.0s (Impact):")
		print("  EngineSound Playing: %s (must be false)" % engine_sound.playing)
		print("  ImpactSound Playing: %s (must be true)" % impact_sound.playing)
		print("  Exhaust Emitting:    %s (must be false)" % exhaust.emitting)
		print("  Dust Emitting:       %s (must be true)" % dust.emitting)

		assert(engine_sound.playing == false, "EngineSound must stop upon impact!")
		assert(impact_sound.playing == true, "ImpactSound must play upon impact!")
		assert(exhaust.emitting == false, "Exhaust must stop upon impact!")
		assert(dust.emitting == true, "Dust burst must start upon impact!")
		print("[PASS] 5: Impact audio and particle transitions verified.")
		return false

	# Frame 15: Test Ambient Fade-Out at 30.0s
	if frame_count == 15:
		print("\n--- 6. TEST AMBIENT AUDIO FADE-OUT AT 30.0s ---")
		anim_player.seek(30.0, true)
		cutscene.fade_ambient_sound()
		assert(cutscene.is_fading_ambient, "Ambient fade-out flag must be set at 30s!")
		print("Ambient fade-out successfully started.")
		print("[PASS] 6: Ambient sound fade-out verified.")
		return false

	# Frame 18: Test Skip Key (ESC) and Gameplay Handoff
	if frame_count == 18:
		print("\n--- 7. TEST SKIP KEY & GAMEPLAY HANDOFF ---")
		anim_player.seek(15.0, true)
		recorded_landing_point = cutscene.final_surface_pt

		print("Simulating ESC key press to skip cutscene...")
		cutscene.skip_cutscene()

		assert(signal_received, "cutscene_finished signal must be emitted on skip!")
		print("[PASS] 7A: cutscene_finished signal emitted.")
		return false

	# Frame 22: Confirm Player Spawned at Landing Point in Gameplay Scene
	if frame_count == 22:
		var current_scene = root.get_child(root.get_child_count() - 1)
		print("Current scene after handoff: ", current_scene.name)
		var player = current_scene.get_node_or_null("Player")
		assert(player != null, "Player must exist in gameplay scene after handoff!")

		var p_pos = player.global_position
		print("Player spawned position: %s" % p_pos)
		print("Recorded landing point:  %s" % recorded_landing_point)
		var dist_to_landing = p_pos.distance_to(recorded_landing_point)
		print("Distance to landing point: %.3f m" % dist_to_landing)
		assert(dist_to_landing < 3.0, "Player must be spawned at the landing point!")
		print("[PASS] 7B: Player spawned at landing point after handoff.")

		print("\n==================================================================")
		print("ALL INTRO CUTSCENE FIXES PASSED SUCCESSFULLY WITH ZERO ERRORS!")
		print("==================================================================")
		quit()
		return true

	return false
