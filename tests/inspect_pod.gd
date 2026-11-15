extends SceneTree

func _init() -> void:
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	print("--- CrashedPod Children ---")
	for child in pod.get_children():
		print("Child: ", child.name, " (", child.get_class(), ") Transform: ", child.transform)
	
	var model = pod.get_node("PodModel")
	print("\n--- PodModel Children ---")
	for child in model.get_children():
		print("Model child: ", child.name, " (", child.get_class(), ") Transform: ", child.transform)
		for sub in child.get_children():
			print("  Subchild: ", sub.name, " (", sub.get_class(), ") Transform: ", sub.transform)
			if sub is MeshInstance3D and sub.mesh:
				print("    Mesh AABB: ", sub.mesh.get_aabb())
			for sub2 in sub.get_children():
				if sub2 is MeshInstance3D and sub2.mesh:
					print("    Sub2 Mesh AABB: ", sub2.mesh.get_aabb())
	
	pod.queue_free()
	quit(0)
