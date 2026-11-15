@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING POD AND PODSPAWN CHILDREN ---")
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	
	var pod_spawn = world.get_node_or_null("PodSpawn")
	if pod_spawn:
		print("PodSpawn Node: ", pod_spawn)
		for c in pod_spawn.get_children():
			print("  - PodSpawn child: ", c.name, " [", c.get_class(), "]")
	else:
		print("No PodSpawn node in world")
	
	var pod = world.crashed_pod_node
	if pod:
		print("CrashedPod Node: ", pod)
		for c in pod.get_children():
			print("  - Pod child: ", c.name, " [", c.get_class(), "]")
			if c.name == "PodModel":
				for m_c in c.get_children():
					print("    - PodModel child: ", m_c.name, " [", m_c.get_class(), "]")
	quit()
