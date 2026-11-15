@tool
extends SceneTree

func _init() -> void:
	print("\n==================================================")
	print("SEARCHING FOR STRAY MODELS WITHIN 60 UNITS OF MAV_ROCKET")
	print("==================================================")
	
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		var GMScript = load("res://Scripts/autoloads/GameManager.gd")
		gm = GMScript.new()
		gm.name = "GameManager"
		root.add_child(gm)
		await process_frame
	
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
	
	for i in range(10):
		await process_frame
	
	var rocket_pos = registry.get_position("mav_rocket") as Vector3
	print("MAV Rocket Position: ", rocket_pos)
	
	var stray_nodes: Array[Dictionary] = []
	
	# Recursively check all nodes in world
	_check_node(world, rocket_pos, stray_nodes)
	
	print("\n--- FOUND MODELS WITHIN 60m OF ROCKET ---")
	print("Total found items: %d" % stray_nodes.size())
	for item in stray_nodes:
		print("  - Node: '%s' | Class: %s | Source/Parent: '%s' | Dist: %.2f m | Instances: %d" % [
			item["name"], item["class"], item["parent"], item["dist"], item["count"]
		])
	print("==================================================\n")
	quit()

func _check_node(node: Node, rocket_pos: Vector3, stray_nodes: Array[Dictionary]) -> void:
	if node.name == "ReturnVehicle" or node.name == "RocketShip" or node.name == "Player":
		return
	if node.owner != null and (node.owner.name == "ReturnVehicle" or node.owner.name == "Player"):
		return
	
	if node is MeshInstance3D:
		var d = node.global_position.distance_to(rocket_pos)
		if d <= 60.0 and node.name != "ProceduralMars" and node.name != "PlanetSurface":
			stray_nodes.append({
				"name": node.name,
				"class": "MeshInstance3D",
				"parent": node.get_parent().name if node.get_parent() else "none",
				"path": node.get_path(),
				"dist": d,
				"count": 1
			})
	elif node is MultiMeshInstance3D:
		var mm = node.multimesh
		if mm:
			var inside_count = 0
			var min_d = 999.0
			for i in range(mm.instance_count):
				var xform = mm.get_instance_transform(i)
				var gpos = node.global_transform * xform.origin
				var d = gpos.distance_to(rocket_pos)
				if d <= 60.0:
					inside_count += 1
					min_d = minf(min_d, d)
			if inside_count > 0:
				stray_nodes.append({
					"name": node.name,
					"class": "MultiMeshInstance3D",
					"parent": node.get_parent().name if node.get_parent() else "none",
					"path": node.get_path(),
					"dist": min_d,
					"count": inside_count
				})
	
	for c in node.get_children():
		_check_node(c, rocket_pos, stray_nodes)
