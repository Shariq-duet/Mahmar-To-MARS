extends SceneTree

func _init() -> void:
	var jl = load("res://Assets/Jump_Loop.fbx") as PackedScene
	var inst = jl.instantiate()
	var ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var a = ap.get_animation("mixamo_com")
	print("--- JUMP_LOOP.FBX INSPECTION ---")
	print("Duration: ", a.length)
	for t in range(min(6, a.get_track_count())):
		var p = str(a.track_get_path(t))
		var kc = a.track_get_key_count(t)
		print("Track: ", p, " | keys: ", kc)
		if kc > 1:
			print("   First: ", a.track_get_key_value(t, 0))
			print("   Last:  ", a.track_get_key_value(t, kc - 1))
	inst.free()
	quit(0)
