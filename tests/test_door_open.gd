extends SceneTree

func _process(delta: float) -> bool:
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	pod.force_update_transform()
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	var closed_t = door.transform
	print("Closed door local transform: ", closed_t)
	
	# Open door: pitch up around local X by 85 degrees and slide slightly up
	door.rotate_x(deg_to_rad(85.0))
	door.position.y += 200.0
	door.force_update_transform()
	print("Open door local transform: ", door.transform)
	print("Open door global pos: ", door.global_position)
	
	pod.queue_free()
	quit(0)
	return true
