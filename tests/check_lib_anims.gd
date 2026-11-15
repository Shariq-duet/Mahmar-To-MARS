extends SceneTree

func _init() -> void:
	var lib = load("res://Assets/astronaut_animations.tres") as AnimationLibrary
	for name in lib.get_animation_list():
		var a = lib.get_animation(name)
		print("Anim: ", name, " | length: ", a.length, " | loop: ", a.loop_mode)
	quit(0)
