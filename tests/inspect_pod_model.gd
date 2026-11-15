extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	pod.force_update_transform()
	
	var aabb = AABB()
	var first = true
	var model = pod.get_node("PodModel")
	for mi in model.find_children("", "MeshInstance3D", true, false):
		var m_aabb = mi.get_aabb()
		var node_trans = pod.global_transform.affine_inverse() * mi.global_transform
		var trans_aabb = node_trans * m_aabb
		print("Model MeshInstance: ", mi.name, " parent: ", mi.get_parent().name, " rel AABB: ", trans_aabb)
		if first:
			aabb = trans_aabb
			first = false
		else:
			aabb = aabb.merge(trans_aabb)
			
	print("\n--- POD LOCAL BOUNDS (under CrashedPod root at current scale 1.0) ---")
	print("Pod Model Local AABB: ", aabb)
	print("Pod Model Local Size: (Width X = %.3f, Height Y = %.3f, Depth Z = %.3f)" % [aabb.size.x, aabb.size.y, aabb.size.z])
	print("Pod Model Min Y: %.3f, Max Y: %.3f" % [aabb.position.y, aabb.position.y + aabb.size.y])
	print("Pod Model Min X: %.3f, Max X: %.3f" % [aabb.position.x, aabb.position.x + aabb.size.x])
	print("Pod Model Min Z: %.3f, Max Z: %.3f" % [aabb.position.z, aabb.position.z + aabb.size.z])
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	var door_rel_pos = pod.global_transform.affine_inverse() * door.global_position
	print("Door 'Line0022' relative to CrashedPod root: ", door_rel_pos)
	
	pod.queue_free()
	quit(0)
	return true
