extends SceneTree

func _process(_delta: float) -> bool:
	var astro_scene = load("res://Scenes/player/astronaut_model.tscn")
	var astro = astro_scene.instantiate()
	root.add_child(astro)
	
	print("\n==========================================")
	print("INSPECTING ASTRONAUT MODEL ANIMATIONS")
	print("==========================================")
	
	var anim_players = astro.find_children("*", "AnimationPlayer")
	print("Found AnimationPlayers: ", anim_players.size())
	for ap in anim_players:
		print("AnimationPlayer: ", ap.name, " path: ", ap.get_path())
		for lib_name in ap.get_animation_library_list():
			var lib = ap.get_animation_library(lib_name)
			print("  Library: '", lib_name, "'")
			for anim_name in lib.get_animation_list():
				var anim = lib.get_animation(anim_name)
				print("    Animation: '", anim_name, "' | Length: %.3fs | Loop: %s | Track count: %d" % [anim.length, anim.loop_mode, anim.get_track_count()])

	# Also check Assets/astronaut_animations.tres directly
	var res = load("res://Assets/astronaut_animations.tres")
	if res is AnimationLibrary:
		print("\nDirect load Assets/astronaut_animations.tres:")
		for anim_name in res.get_animation_list():
			var anim = res.get_animation(anim_name)
			print("  Animation: '", anim_name, "' | Length: %.3fs | Loop: %s" % [anim.length, anim.loop_mode])

	# Check Skeleton
	var skeletons = astro.find_children("*", "Skeleton3D")
	print("\nSkeletons found: ", skeletons.size())
	for sk in skeletons:
		print("  Skeleton: ", sk.name, " bone count: ", sk.get_bone_count())
		for i in min(10, sk.get_bone_count()):
			print("    Bone ", i, ": ", sk.get_bone_name(i))

	# Check player script (planet_walker.gd) to see how animations and movement are currently handled
	quit()
	return true
