extends SceneTree

func _init() -> void:
	print("Testing animation transitions on slopes...")
	var lib = load("res://Assets/astronaut_animations.tres") as AnimationLibrary
	print("Available animations:")
	for a in lib.get_animation_list():
		print(" - ", a)
	quit(0)
