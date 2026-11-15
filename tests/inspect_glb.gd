extends SceneTree

func _init() -> void:
	var glb = load("res://Assets/sci-fi_pod_collection.glb")
	var inst = glb.instantiate()
	_print_tree(inst, "")
	inst.queue_free()
	quit(0)

func _print_tree(n: Node, indent: String) -> void:
	print(indent + n.name + " (" + n.get_class() + ")")
	if n is AnimationPlayer:
		print(indent + "  Animations: " + str(n.get_animation_list()))
	for c in n.get_children():
		_print_tree(c, indent + "  ")
