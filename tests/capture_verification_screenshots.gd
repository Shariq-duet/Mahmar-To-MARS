@tool
extends SceneTree

# capture_verification_screenshots.gd
# Captures 3 required screenshots:
# 1. The space cargo on the crevasse rim with its pickup (space_cargo_crevasse_rim.png)
# 2. The rover with its power core pickup (rover_site_power_core.png)
# 3. The water deposit ice patch from the new pod location (water_deposit_from_new_pod.png)

func _init() -> void:
	print("\n==================================================")
	print("CAPTURING VERIFICATION SCREENSHOTS")
	print("==================================================")
	
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
	
	for i in range(25):
		await process_frame
	
	var planet = world.get_node("ProceduralMars")
	var planet_center = planet.global_position
	var pod = world.crashed_pod_node as CrashedPod
	var cargo = world.cargo_site_node as SpaceCargo
	var rover = world.rover_site_node as RoverSite
	
	var cam = Camera3D.new()
	cam.name = "ScreenshotCam"
	cam.current = true
	cam.fov = 70.0
	root.add_child(cam)
	
	var vp = root.get_viewport()
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	
	# ----------------------------------------------------
	# 1. Space Cargo on Crevasse Rim with Pickup
	# ----------------------------------------------------
	var cargo_pos = cargo.global_position
	var cargo_up = (cargo_pos - planet_center).normalized()
	var filter_pickup = cargo.get_node_or_null("FilterCorePickup") as Node3D
	var pickup_pos = filter_pickup.global_position if filter_pickup else cargo_pos + cargo_up * 0.8
	
	# Compute camera offset so we see the cargo model, glowing cyan core, and the crevasse edge
	var cargo_fwd = cargo.global_transform.basis.z.normalized()
	var cargo_right = cargo_up.cross(cargo_fwd).normalized()
	cargo_fwd = cargo_right.cross(cargo_up).normalized()
	
	cam.global_position = cargo_pos - cargo_fwd * 6.5 - cargo_right * 3.5 + cargo_up * 3.0
	cam.look_at(pickup_pos + cargo_up * 0.5, cargo_up)
	
	for i in range(12):
		await process_frame
	
	var img1 = vp.get_texture().get_image()
	if img1:
		img1.save_png("res://tests/screenshots/space_cargo_crevasse_rim.png")
		print("Saved: res://tests/screenshots/space_cargo_crevasse_rim.png")
	else:
		print("Warning: viewport texture image is null for space cargo")
	
	# ----------------------------------------------------
	# 2. Rover with Power Core Pickup
	# ----------------------------------------------------
	var rover_pos = rover.global_position
	var rover_up = (rover_pos - planet_center).normalized()
	var rover_fwd = rover.global_transform.basis.z.normalized()
	var rover_right = rover_up.cross(rover_fwd).normalized()
	rover_fwd = rover_right.cross(rover_up).normalized()
	
	var power_pickup = rover.get_node_or_null("PowerCorePickup") as Node3D
	var power_pos = power_pickup.global_position if power_pickup else rover_pos + rover_up * 1.0
	
	cam.global_position = rover_pos - rover_fwd * 5.0 + rover_right * 3.5 + rover_up * 2.8
	cam.look_at(power_pos + rover_up * 0.2, rover_up)
	
	for i in range(12):
		await process_frame
	
	var img2 = vp.get_texture().get_image()
	if img2:
		img2.save_png("res://tests/screenshots/rover_site_power_core.png")
		print("Saved: res://tests/screenshots/rover_site_power_core.png")
	else:
		print("Warning: viewport texture image is null for rover site")
	
	# ----------------------------------------------------
	# 3. Water Deposit Ice Patch from New Pod Location
	# ----------------------------------------------------
	var pod_pos = pod.global_position
	var pod_up = (pod_pos - planet_center).normalized()
	
	var water_metrics = planet.get_water_deposit_metrics()
	var ice_pos: Vector3 = water_metrics["ice_pos"]
	var peak_pos: Vector3 = water_metrics["peak_pos"]
	
	var to_ice = (ice_pos - pod_pos).normalized()
	var pod_right = to_ice.cross(pod_up).normalized()
	to_ice = pod_up.cross(pod_right).normalized()
	
	# Position camera near the pod, showing the pod in the left foreground and looking towards the water mountain & ice patch
	cam.global_position = pod_pos - pod_right * 5.0 - to_ice * 3.0 + pod_up * 3.5
	cam.look_at(ice_pos + (peak_pos - ice_pos) * 0.2 + pod_up * 10.0, pod_up)
	
	for i in range(12):
		await process_frame
	
	var img3 = vp.get_texture().get_image()
	if img3:
		img3.save_png("res://tests/screenshots/water_deposit_from_new_pod.png")
		print("Saved: res://tests/screenshots/water_deposit_from_new_pod.png")
	else:
		print("Warning: viewport texture image is null for water deposit from pod")
	
	print("\n==================================================")
	print("ALL SCREENSHOTS CAPTURED!")
	print("==================================================")
	quit(0)
