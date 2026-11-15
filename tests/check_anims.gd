extends SceneTree

func _init() -> void:
	var lib = load("res://Assets/astronaut_animations.tres") as AnimationLibrary
	if lib:
		print("Animations in library:")
		for anim_name in lib.get_animation_list():
			print(" - ", anim_name)
	else:
		print("Could not load astronaut_animations.tres")
	quit(0)
