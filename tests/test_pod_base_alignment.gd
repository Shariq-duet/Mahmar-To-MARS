extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	var model = pod.get_node("PodModel")
	model.position.y = -0.1619
	
	# Apply target root scale
	var sx = 6.0 / 2.747095 # ~2.184
	var sz = 6.0 / 2.711778 # ~2.213
	var sy = 3.5 / 5.579019 # ~0.627
	pod.scale = Vector3(sx, sy, sz)
	pod.force_update_transform()
	
	var aabb = AABB()
	var first = true
	for mi in model.find_children("", "MeshInstance3D", true, false):
		var m_aabb = mi.get_aabb()
		var trans_aabb = mi.global_transform * m_aabb
		if first:
			aabb = trans_aabb
			first = false
		else:
			aabb = aabb.merge(trans_aabb)
			
	print("Pod Global Scale: ", pod.global_transform.basis.get_scale())
	print("Enlarged Pod Shell AABB: ", aabb)
	print("Enlarged Pod Shell Size: Width X = %.3f, Height Y = %.3f, Depth Z = %.3f" % [aabb.size.x, aabb.size.y, aabb.size.z])
	print("Pod Base Min Y: %.4f" % aabb.position.y)
	print("Pod Top Max Y: %.4f" % (aabb.position.y + aabb.size.y))
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	print("Hatch 'Line0022' global pos: ", door.global_position)
	
	var door_mesh = pod.find_child("Line002_glass_02", true, false) as MeshInstance3D
	var door_aabb = door_mesh.global_transform * door_mesh.get_aabb()
	print("Hatch Doorway AABB in world: ", door_aabb)
	print("Hatch Doorway bottom Y: %.3f, top Y: %.3f, height: %.3f" % [door_aabb.position.y, door_aabb.position.y + door_aabb.size.y, door_aabb.size.y])
	print("Hatch Doorway center: ", door_aabb.get_center())
	
	pod.queue_free()
	quit(0)
	return true
