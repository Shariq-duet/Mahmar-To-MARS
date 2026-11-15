@tool
extends SceneTree

# bake_animations.gd
# Extracts animations from FBX, adapts track paths and in-place motion,
# and saves a unified AnimationLibrary for the J-Toastie Rigged Astronaut.

func _init() -> void:
	print("--- Baking Animations into AnimationLibrary ---")
	var library = AnimationLibrary.new()
	
	var sources = {
		"idle": {"file": "res://Assets/Idle.fbx", "loop": true, "in_place": false},
		"walk": {"file": "res://Assets/Walking.fbx", "loop": true, "in_place": true},
		"run": {"file": "res://Assets/Fast_Run.fbx", "loop": true, "in_place": true},
		"jump": {"file": "res://Assets/Jump_Loop.fbx", "loop": true, "in_place": false}
	}
	
	for anim_name in sources:
		var config = sources[anim_name]
		var scene = load(config["file"]) as PackedScene
		if not scene:
			printerr("Could not load ", config["file"])
			continue
		
		var inst = scene.instantiate()
		var player_node: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var orig_anim: Animation = player_node.get_animation("mixamo_com")
		if not orig_anim:
			printerr("mixamo_com not found in ", config["file"])
			continue
		
		var new_anim: Animation = orig_anim.duplicate()
		new_anim.loop_mode = Animation.LOOP_LINEAR if config["loop"] else Animation.LOOP_NONE
		
		# Adjust track paths to point to RootNode/Armature/Skeleton3D
		for t in range(new_anim.get_track_count()):
			var p = str(new_anim.track_get_path(t))
			if p.begins_with("Skeleton3D:"):
				var bone_sub = p.substr("Skeleton3D:".length())
				new_anim.track_set_path(t, NodePath("RootNode/Armature/Skeleton3D:" + bone_sub))
			
			# In-place Z-lock for Hips translation track
			if config["in_place"] and new_anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var path_str = str(new_anim.track_get_path(t))
				if "mixamorig_Hips" in path_str:
					var first_z = (new_anim.track_get_key_value(t, 0) as Vector3).z
					for k in range(new_anim.track_get_key_count(t)):
						var v: Vector3 = new_anim.track_get_key_value(t, k)
						v.z = first_z
						new_anim.track_set_key_value(t, k, v)
		
		library.add_animation(anim_name, new_anim)
		print("Successfully baked animation: '", anim_name, "' (length: ", new_anim.length, "s)")
		inst.free()
	
	# Save library to disk
	var err = ResourceSaver.save(library, "res://Assets/astronaut_animations.tres")
	if err == OK:
		print("SUCCESS: Saved AnimationLibrary to res://Assets/astronaut_animations.tres")
	else:
		printerr("FAILED to save AnimationLibrary: ", err)
	
	quit()
