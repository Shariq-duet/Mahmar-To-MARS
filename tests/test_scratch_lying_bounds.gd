extends SceneTree

func _process(delta):
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	var player = world.get_node("Player") as PlanetWalker
	var space = world.get_world_3d().direct_space_state
	
	var up = (player.global_position - world.planet.global_position).normalized()
	var ray_start = player.global_position + up * 5.0
	var ray_end = player.global_position - up * 5.0
	var q = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit = space.intersect_ray(q)
	
	print("Ray hit planet: ", not hit.is_empty())
	var ground_pt = hit["position"] if not hit.is_empty() else world.planet.get_surface_point(player.global_position.normalized())
	print("Ground hit point: ", ground_pt)
	print("Ground distance from center: %.4f" % ground_pt.length())
	
	# Test side pose vs back pose
	var astro = player.get_node("VisualMesh/Astronaut") as Node3D
	
	# 1. Back pose
	var t_back = player.default_astro_transform.rotated_local(Vector3.RIGHT, deg_to_rad(-85.0))
	astro.transform = t_back
	var min_y_back = get_min_mesh_y(astro)
	print("Back pose min_y: %.4f" % min_y_back)
	
	# 2. Side pose (85 deg pitch + 75 deg roll)
	var t_side = player.default_astro_transform.rotated_local(Vector3.RIGHT, deg_to_rad(-80.0)).rotated_local(Vector3.FORWARD, deg_to_rad(70.0))
	astro.transform = t_side
	var min_y_side = get_min_mesh_y(astro)
	print("Side pose min_y: %.4f" % min_y_side)
	
	world.queue_free()
	quit(0)
	return true

func get_min_mesh_y(root_node: Node3D) -> float:
	var min_y = 999999.0
	var meshes = root_node.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if mi.mesh:
			var aabb = mi.get_aabb()
			var m_trans = root_node.transform * mi.transform
			for i in range(8):
				var corner = aabb.get_endpoint(i)
				var pt = m_trans * corner
				if pt.y < min_y:
					min_y = pt.y
	return min_y
