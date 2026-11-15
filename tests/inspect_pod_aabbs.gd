extends SceneTree

func _process(delta: float) -> bool:
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	pod.force_update_transform()
	
	for node in pod.find_children("*", "MeshInstance3D"):
		var mi = node as MeshInstance3D
		mi.force_update_transform()
		var aabb = mi.mesh.get_aabb()
		var xform = pod.global_transform.affine_inverse() * mi.global_transform
		var local_aabb = xform * aabb
		print("Mesh: ", mi.name, " Parent: ", mi.get_parent().name)
		print("  Transformed AABB in CrashedPod local space: Pos=", local_aabb.position, " Size=", local_aabb.size)
		print("  Center=", local_aabb.get_center())
		print("  Min=", local_aabb.position, " Max=", local_aabb.position + local_aabb.size)
	
	pod.queue_free()
	quit(0)
	return true
