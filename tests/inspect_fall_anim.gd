extends SceneTree

func _init() -> void:
	var lib = load("res://Assets/astronaut_animations.tres") as AnimationLibrary
	if not lib:
		printerr("Cannot load lib")
		quit(1)
	
	var fall = lib.get_animation("fall")
	print("--- FALL ANIMATION INSPECTION ---")
	print("Length: ", fall.length)
	print("Loop mode: ", fall.loop_mode)
	print("Track count: ", fall.get_track_count())
	
	for t in range(min(10, fall.get_track_count())):
		var p = str(fall.track_get_path(t))
		var kc = fall.track_get_key_count(t)
		print("Track: ", p, " | type: ", fall.track_get_type(t), " | keys: ", kc)
		if kc > 0:
			print("   First key (0s): ", fall.track_get_key_value(t, 0))
			print("   Last key (", fall.track_get_key_time(t, kc - 1), "s): ", fall.track_get_key_value(t, kc - 1))
	
	quit(0)
