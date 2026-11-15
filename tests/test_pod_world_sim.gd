extends SceneTree

func _process(delta):
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	world.force_update_transform()
	
	var player = world.get_node("Player") as PlanetWalker
	var pod = world.get_node_or_null("CrashedPod") as CrashedPod
	if not pod:
		for c in world.get_children():
			if c is CrashedPod:
				pod = c
				break
				
	print("World loaded. CrashedPod global pos: ", pod.global_position)
	print("CrashedPod global scale: ", pod.global_transform.basis.get_scale())
	
	quit(0)
	return true
