@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING NEW ASSETS ---")
	var paths = [
		"res://Assets/space_cargo_transporter.glb",
		"res://Assets/oxygen_farm_1.glb",
		"res://Assets/spaceschmogue_reactor.glb"
	]
	for p in paths:
		var scene = load(p) as PackedScene
		if scene:
			var inst = scene.instantiate()
			print("Asset: ", p)
			_print_node(inst, 0)
			inst.queue_free()
		else:
			print("FAILED TO LOAD: ", p)
	quit()

func _print_node(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var extra = ""
	if node is VisualInstance3D:
		var aabb = node.get_aabb()
		extra = " (AABB: pos=%s, size=%s)" % [aabb.position, aabb.size]
	print(indent, "- ", node.name, " [", node.get_class(), "]", extra)
	if depth < 2:
		for c in node.get_children():
			_print_node(c, depth + 1)
