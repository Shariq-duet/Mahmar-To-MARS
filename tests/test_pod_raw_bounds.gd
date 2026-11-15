extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	pod.scale = Vector3.ONE
	pod.force_update_transform()
	
	var total_aabb = AABB()
	var first = true
	var meshes = pod.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		if mi.mesh:
			var mb = mi.transform * mi.get_aabb()
			if first:
				total_aabb = mb
				first = false
			else:
				total_aabb = total_aabb.merge(mb)
	
	print("Raw unscaled Pod Total AABB: ", total_aabb)
	print("Raw size: X = %.3f, Y = %.3f, Z = %.3f" % [total_aabb.size.x, total_aabb.size.y, total_aabb.size.z])
	
	# Hatch doorway frame check:
	# What meshes make up the doorway/hatch?
	var door_nodes = pod.find_children("*door*", "", true, false) + pod.find_children("*Line*", "", true, false)
	for d in door_nodes:
		print("Door related node: ", d.name, " class: ", d.get_class(), " pos: ", d.position)
		
	pod.queue_free()
	quit(0)
	return true
