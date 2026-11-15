@tool
extends SceneTree

func _init() -> void:
	print("--- CHECKING SPAWNERS WITHIN 60m OF ROCKET ---")
	var registry = load("res://Scripts/autoloads/placement_registry.gd").new()
	registry.name = "PlacementRegistry"
	root.add_child(registry)
	await process_frame
	
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	for i in range(15):
		await process_frame
	
	var rocket_pos = registry.get_position("mav_rocket") as Vector3
	print("Rocket Position: ", rocket_pos)
	
	# 1. Check boulder_spawner rocks
	var planet = world.get_node("ProceduralMars")
	var b_spawner = planet.get_node_or_null("BouldersContainer")
	var rocks_near_rocket = 0
	if b_spawner:
		print("Checking BouldersContainer...")
		for r in b_spawner.rocks_data:
			var d = (r["pos"] as Vector3).distance_to(rocket_pos)
			if d <= 60.0:
				rocks_near_rocket += 1
		print("  -> BouldersContainer small rocks in rocks_data within 60m: %d" % rocks_near_rocket)
		var colliders_near = 0
		for col in b_spawner.large_medium_colliders:
			if col.position.distance_to(rocket_pos) <= 60.0:
				colliders_near += 1
		print("  -> BouldersContainer large/med colliders within 60m: %d" % colliders_near)
		
		# Check multimeshes in patches
		var mm_instances_near = 0
		for p in b_spawner.patches:
			for mm in p["multimeshes"]:
				var mmesh = mm.multimesh
				for i in range(mmesh.instance_count):
					var xf = mmesh.get_instance_transform(i)
					var gp = mm.global_transform * xf.origin
					if gp.distance_to(rocket_pos) <= 60.0:
						mm_instances_near += 1
		print("  -> BouldersContainer total MultiMesh rock instances within 60m: %d" % mm_instances_near)
	
	# 2. Check RouteObstacles
	var obs_root = world.get_node_or_null("RouteObstacles")
	if obs_root:
		print("Checking RouteObstacles...")
		var count = 0
		for child in obs_root.get_children():
			var d = child.global_position.distance_to(rocket_pos)
			if d <= 60.0:
				count += 1
				print("  -> Route obstacle '%s' at %.2fm from rocket" % [child.name, d])
		print("  -> Total RouteObstacles within 60m: %d" % count)
	
	# 3. Check CrashBase
	var crash_base = world.get_node_or_null("CrashBase")
	if crash_base:
		var d = crash_base.global_position.distance_to(rocket_pos)
		print("Checking CrashBase at distance: %.2fm" % d)
	
	# 4. Check RoverSite
	var rover = world.get_node_or_null("RoverSite")
	if rover:
		var d = rover.global_position.distance_to(rocket_pos)
		print("Checking RoverSite at distance: %.2fm" % d)
	
	# 5. Check Pod and PodSurroundings
	var pod = world.crashed_pod_node
	if pod:
		var d = pod.global_position.distance_to(rocket_pos)
		print("Checking Pod at distance: %.2fm" % d)
	var pod_surround = world.get_node_or_null("PodSurroundings")
	if pod_surround:
		var count = 0
		for c in pod_surround.get_children():
			for sub in c.get_children():
				if sub.global_position.distance_to(rocket_pos) <= 60.0:
					count += 1
		print("Checking PodSurroundings within 60m: %d items" % count)
	
	quit()
