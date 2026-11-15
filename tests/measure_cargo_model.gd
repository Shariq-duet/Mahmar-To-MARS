@tool
extends SceneTree

func _init() -> void:
	var cargo_scene = load("res://models/space_cargo/space_cargo_transporter.glb") as PackedScene
	var cargo = cargo_scene.instantiate()
	print("--- SPACE CARGO HIERARCHY ---")
	_print_tree(cargo, 0)
	cargo.queue_free()
	quit()

func _print_tree(n: Node, d: int) -> void:
	var extra = ""
	if n is VisualInstance3D:
		extra = " AABB: " + str(n.get_aabb())
	print("  ".repeat(d), n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_print_tree(c, d + 1)
