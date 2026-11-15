extends SceneTree

func _init() -> void:
	var j1 = load("res://Assets/Jump.fbx")
	var j2 = load("res://Assets/Jump_Loop.fbx")
	print("Jump.fbx: ", j1)
	print("Jump_Loop.fbx: ", j2)
	
	# Check animation names inside imported scenes
	if j1 is PackedScene:
		var inst = j1.instantiate()
		var ap = inst.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0:
			print("Jump.fbx animations: ", (ap[0] as AnimationPlayer).get_animation_list())
		inst.free()
		
	if j2 is PackedScene:
		var inst = j2.instantiate()
		var ap = inst.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0:
			print("Jump_Loop.fbx animations: ", (ap[0] as AnimationPlayer).get_animation_list())
		inst.free()
	quit(0)
