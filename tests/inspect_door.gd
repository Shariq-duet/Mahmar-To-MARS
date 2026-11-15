extends SceneTree

func _process(delta: float) -> bool:
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	pod.force_update_transform()
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	print("Door node: ", door)
	if door:
		print("Door local transform in PodModel: ", door.transform)
		print("Door global transform: ", door.global_transform)
		var door_mesh = door.find_child("*", true, false) as MeshInstance3D
		if door_mesh:
			print("Door mesh local: ", door_mesh.transform)
			print("Door mesh AABB: ", door_mesh.mesh.get_aabb())
	
	pod.queue_free()
	quit(0)
	return true
