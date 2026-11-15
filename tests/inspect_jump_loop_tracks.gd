extends SceneTree

func _init() -> void:
	var jl = load("res://Assets/Jump_Loop.fbx") as PackedScene
	var inst = jl.instantiate()
	var ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var anim = ap.get_animation("mixamo_com")
	
	for t in range(anim.get_track_count()):
		var p = str(anim.track_get_path(t))
		if "Hips" in p and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			print("Jump_Loop Hips track found: ", p)
			var key_count = anim.track_get_key_count(t)
			print("Key count: ", key_count)
			for i in range(0, key_count, 5):
				var time = anim.track_get_key_time(t, i)
				var val = anim.track_get_key_value(t, i)
				print("Time: %.2f | Pos: %s" % [time, val])
	inst.free()
	quit(0)
