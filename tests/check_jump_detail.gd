extends SceneTree

func _init() -> void:
	var j = load("res://Assets/Jump.fbx") as PackedScene
	var inst = j.instantiate()
	var ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var a = ap.get_animation("mixamo_com")
	print("Jump.fbx length: ", a.length)
	
	var jl = load("res://Assets/Jump_Loop.fbx") as PackedScene
	var inst_jl = jl.instantiate()
	var ap_jl = inst_jl.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var a_jl = ap_jl.get_animation("mixamo_com")
	print("Jump_Loop.fbx length: ", a_jl.length)
	
	quit(0)
