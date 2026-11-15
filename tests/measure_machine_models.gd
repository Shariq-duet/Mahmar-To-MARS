@tool
extends SceneTree

func _init() -> void:
	var oxy_scene = load("res://Assets/oxygen_farm_1.glb") as PackedScene
	var oxy = oxy_scene.instantiate()
	var r_scene = load("res://Assets/spaceschmogue_reactor.glb") as PackedScene
	var r = r_scene.instantiate()
	
	print("--- OXYGEN FARM AABB ---")
	print("Oxy children:")
	_print_tree(oxy, 0)
	
	print("--- REACTOR AABB ---")
	print("Reactor children:")
	_print_tree(r, 0)
	
	quit()

func _print_tree(n: Node, d: int) -> void:
	var extra = ""
	if n is VisualInstance3D:
		extra = " AABB: " + str(n.get_aabb())
	print("  ".repeat(d), n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_print_tree(c, d + 1)
