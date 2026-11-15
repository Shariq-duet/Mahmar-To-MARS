extends SceneTree

func _init() -> void:
	for f in ["res://Assets/Jump.fbx", "res://Assets/Jump_Loop.fbx"]:
		var sc = load(f) as PackedScene
		var inst = sc.instantiate()
		var ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var anim = ap.get_animation("mixamo_com")
		print(f, " duration: ", anim.length, " loop: ", anim.loop_mode)
		inst.free()
	quit(0)
