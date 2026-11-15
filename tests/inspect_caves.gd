extends SceneTree

func _init() -> void:
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	print("\n--- CAVE VISIBILITY VERIFICATION ---")
	var player = world.get_node("Player")
	var p_pos = player.global_position
	print("Player Spawn Position: ", p_pos)
	
	for child in world.get_children():
		if "Tube" in child.name or "Fissure" in child.name or "Cavern" in child.name:
			var c_pos = child.global_position
			var dist = p_pos.distance_to(c_pos)
			print("Cave: %s | Pos: %s | Distance from player: %.1f meters" % [child.name, c_pos, dist])
	
	quit(0)
