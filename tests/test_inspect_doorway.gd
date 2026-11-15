extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	var sx = 2.912167
	var sy = 1.075458
	var sz = 2.950094
	pod.scale = Vector3(sx, sy, sz)
	pod.force_update_transform()
	
	# Check all meshes inside PodModel
	var meshes = pod.get_node("PodModel").find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi = m as MeshInstance3D
		var aabb = mi.global_transform * mi.get_aabb()
		print("Mesh: %-30s | Global AABB: Pos=%s, Size=%s" % [mi.name, aabb.position, aabb.size])
		
	# Check door
	var door = pod.find_child("Line0022", true, false) as Node3D
	print("Door node Line0022 global pos: ", door.global_position)
	print("Door node Line0022 local transform: ", door.transform)
	
	pod.queue_free()
	quit(0)
	return true
