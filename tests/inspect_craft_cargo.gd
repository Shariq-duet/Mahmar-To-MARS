@tool
extends SceneTree

func _init():
	var scene = load("res://Assets/Models/craft_cargoA.glb")
	if not scene:
		print("Failed to load craft_cargoA!")
		quit(1)
	var inst = scene.instantiate()
	print("--- craft_cargoA NODE TREE ---")
	_print_tree(inst, "")
	quit(0)

func _print_tree(n: Node, indent: String):
	var extra = ""
	if n is MeshInstance3D and n.mesh:
		var aabb = n.get_aabb()
		extra = " | AABB: %s, size: %s" % [aabb, aabb.size]
	print("%s- %s (%s)%s" % [indent, n.name, n.get_class(), extra])
	for c in n.get_children():
		_print_tree(c, indent + "  ")
