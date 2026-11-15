extends SceneTree

func _init() -> void:
	var j_scene = load("res://Assets/Jump.fbx") as PackedScene
	var inst = j_scene.instantiate()
	var ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var orig_anim = ap.get_animation("mixamo_com")
	
	var fall_anim = Animation.new()
	fall_anim.loop_mode = Animation.LOOP_LINEAR
	
	var t_start = 1.18
	var t_end = 1.55
	var duration = t_end - t_start
	fall_anim.length = duration
	
	for t in range(orig_anim.get_track_count()):
		var track_type = orig_anim.track_get_type(t)
		var track_path = orig_anim.track_get_path(t)
		var p_str = str(track_path)
		if p_str.begins_with("Skeleton3D:"):
			p_str = "RootNode/Armature/Skeleton3D:" + p_str.substr("Skeleton3D:".length())
		
		var new_t = fall_anim.add_track(track_type)
		fall_anim.track_set_path(new_t, NodePath(p_str))
		
		# Sample keys in [t_start, t_end]
		var key_count = orig_anim.track_get_key_count(t)
		var keys_added = 0
		for k in key_count:
			var kt = orig_anim.track_get_key_time(t, k)
			if kt >= t_start and kt <= t_end:
				var val = orig_anim.track_get_key_value(t, k)
				fall_anim.track_insert_key(new_t, kt - t_start, val)
				keys_added += 1
		
		# If no keys in window, sample start and end
		if keys_added == 0:
			var val_start = orig_anim.track_get_key_value(t, 0)
			fall_anim.track_insert_key(new_t, 0.0, val_start)
			fall_anim.track_insert_key(new_t, duration, val_start)
			
	print("Extracted fall animation with duration: ", fall_anim.length, " and tracks: ", fall_anim.get_track_count())
	inst.free()
	quit(0)
