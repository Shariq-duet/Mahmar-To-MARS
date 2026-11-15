@tool
extends SceneTree

const SurvivalSystem = preload("res://Scripts/survival/survival_system.gd")

func _init() -> void:
	print("Taking required screenshots at the pod...")
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		var GMScript = load("res://Scripts/autoloads/GameManager.gd")
		gm = GMScript.new()
		gm.name = "GameManager"
		root.add_child(gm)
		await process_frame
	gm.reset_session()
	
	var registry = root.get_node_or_null("PlacementRegistry")
	if not registry:
		var RegistryScript = load("res://Scripts/autoloads/placement_registry.gd")
		registry = RegistryScript.new()
		registry.name = "PlacementRegistry"
		root.add_child(registry)
		await process_frame

	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	for i in range(20):
		await process_frame
	
	var player = world.get_node("Player") as PlanetWalker
	var planet = world.get_node("ProceduralMars")
	var hud = world.get_node("HUD")
	var pod = world.crashed_pod_node as CrashedPod
	var survival = world.survival as SurvivalSystem
	
	# Skip opening sequence and stand up player
	player.is_cinematic_intro_active = false
	player.is_input_locked = false
	player.is_lying = false
	if player.astro_root and player.default_astro_transform != Transform3D():
		player.astro_root.transform = player.default_astro_transform
	
	# Position player right outside the pod facing the entrance / scrubber
	var pod_pos = registry.get_position("pod")
	var normal = (pod_pos - planet.global_position).normalized()
	var stand_pos = pod_pos - Vector3(0, 0, 4.0)
	var surface_stand = planet.get_surface_point(stand_pos.normalized())
	player.global_position = surface_stand
	player.look_at(pod_pos, normal)
	
	# Set camera behind player looking towards pod
	var cam = player.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true
	if player.spring_arm:
		player.spring_arm.spring_length = 3.5
	
	# Reveal HUD and set prompt
	hud.hud_revealed = true
	hud.outpost_revealed = true
	pod.overlapping_machines.append("OxygenScrubber")
	pod.active_machine = "OxygenScrubber"
	hud.set_interaction_prompt("[E] HOLD TO REPAIR SCRUBBER")
	hud.show_objective("REPAIR OXYGEN SCRUBBER WITH SALVAGED FILTER CORE")
	
	# Ensure stats visible
	survival.health = 85.0
	survival.oxygen = 72.0
	survival.power = 65.0
	hud.outpost_revealed = true
	hud._on_health_changed(85.0)
	hud._on_oxygen_changed(72.0)
	hud._on_power_changed(65.0)
	
	for i in range(30):
		await process_frame
	
	DirAccess.make_dir_absolute("res://tests/screenshots")
	var img1 = root.get_viewport().get_texture().get_image()
	if img1 and not img1.is_empty():
		img1.save_png("res://tests/screenshots/pod_hud_active.png")
		print("Saved pod_hud_active.png! (Full opacity HUD, readable prompt)")
	
	# Trigger idle fade to 40%
	hud.idle_timer = 5.1
	hud.is_idle_faded = false
	hud._fade_hud(true)
	hud.control_root.modulate.a = 0.40
	for i in range(15):
		await process_frame
		
	var img2 = root.get_viewport().get_texture().get_image()
	if img2 and not img2.is_empty():
		img2.save_png("res://tests/screenshots/pod_hud_faded.png")
		print("Saved pod_hud_faded.png! (40% opacity faded HUD)")
		
	# Copy to artifact directory
	var artifact_dir = "C:/Users/PMLS/.gemini/antigravity/brain/b04e393a-ab94-4657-aee4-85e6272fa4b3"
	if img1 and not img1.is_empty():
		img1.save_png(artifact_dir + "/pod_hud_active.png")
	if img2 and not img2.is_empty():
		img2.save_png(artifact_dir + "/pod_hud_faded.png")
	print("Screenshots copied to artifact directory.")
	
	quit()
