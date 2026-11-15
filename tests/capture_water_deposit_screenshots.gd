@tool
extends SceneTree

# capture_water_deposit_screenshots.gd
# Captures screenshots of the water deposit site:
# 1. Lower slope view looking across the ice patch basin at the ridged mountain.
# 2. Peak view looking down from the summit across the slopes and ice patch basin.

func _init() -> void:
	print("\n==================================================")
	print("CAPTURING WATER DEPOSIT SCREENSHOTS")
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
	
	for i in range(15):
		await process_frame
	
	var planet = world.get_node("ProceduralMars")
	var metrics = planet.get_water_deposit_metrics()
	var peak_pos: Vector3 = metrics["peak_pos"]
	var ice_pos: Vector3 = metrics["ice_pos"]
	var planet_center: Vector3 = planet.global_position
	
	var cam = Camera3D.new()
	cam.name = "ScreenshotCam"
	cam.current = true
	cam.fov = 70.0
	root.add_child(cam)
	
	var vp = root.get_viewport()
	
	# ----------------------------------------------------
	# 1. Lower slope view (looking across the ice patch towards the peak)
	# ----------------------------------------------------
	var ice_up = (ice_pos - planet_center).normalized()
	var to_peak = (peak_pos - ice_pos).normalized()
	var ice_right = to_peak.cross(ice_up).normalized()
	to_peak = ice_up.cross(ice_right).normalized()
	
	# Stand at the outer edge of the ice basin (18m out from ice center away from peak), elevated 2.5m
	var cam_pos_low = ice_pos - to_peak * 16.0 + ice_up * 3.5
	var target_low = ice_pos + to_peak * 12.0 + ice_up * 6.0
	
	cam.global_position = cam_pos_low
	cam.look_at(target_low, ice_up)
	
	for i in range(10):
		await process_frame
	
	var img_low = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	img_low.save_png("res://tests/screenshots/water_deposit_lower_slope.png")
	print("Saved lower slope screenshot: res://tests/screenshots/water_deposit_lower_slope.png")
	
	# ----------------------------------------------------
	# 2. Peak view (looking down from summit towards the ice patch basin)
	# ----------------------------------------------------
	var peak_up = (peak_pos - planet_center).normalized()
	var to_ice = (ice_pos - peak_pos).normalized()
	var peak_right = to_ice.cross(peak_up).normalized()
	to_ice = peak_up.cross(peak_right).normalized()
	
	# Stand near summit, elevated 4.0m, looking down towards ice basin
	var cam_pos_peak = peak_pos - to_ice * 6.0 + peak_up * 4.5
	var target_peak = ice_pos + peak_up * 2.0
	
	cam.global_position = cam_pos_peak
	cam.look_at(target_peak, peak_up)
	
	for i in range(10):
		await process_frame
	
	var img_peak = vp.get_texture().get_image()
	img_peak.save_png("res://tests/screenshots/water_deposit_peak.png")
	print("Saved peak screenshot: res://tests/screenshots/water_deposit_peak.png")
	
	print("\n==================================================")
	print("WATER DEPOSIT SCREENSHOTS CAPTURED SUCCESSFULLY!")
	print("==================================================\n")
	quit()
