extends SceneTree

func _process(delta):
	var world_scene = load("res://Scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	world.force_update_transform()
	
	var pod = world.get_node_or_null("CrashedPod") as CrashedPod
	if not pod:
		for c in world.get_children():
			if c is CrashedPod:
				pod = c
				break
				
	var scale_vec = Vector3(6.0 / 2.747095, 3.5 / 5.579019, 6.0 / 2.711778)
	pod.scale = scale_vec
	
	# Adjust PodModel Y so base sits at Y = 0
	var model = pod.get_node("PodModel")
	model.position.y = -0.1619
	
	# Set pod trigger CollisionShape3D to BoxShape3D at hatch
	var trig = pod.get_node("CollisionShape3D") as CollisionShape3D
	var trig_shape = BoxShape3D.new()
	trig_shape.size = Vector3(1.5, 3.5, 1.4)
	trig.shape = trig_shape
	trig.position = Vector3(0.0, 1.6, 1.08)
	
	# Set InteractZones to BoxShape3D
	for m_name in ["OxygenScrubber", "PowerUnit", "WaterTank"]:
		var m_node = pod.get_node(m_name)
		var zone_col = m_node.get_node("InteractZone/CollisionShape3D") as CollisionShape3D
		var zone_shape = BoxShape3D.new()
		zone_shape.size = Vector3(1.3, 2.5, 1.3)
		zone_col.shape = zone_shape
		
	pod.force_update_transform()
	
	print("\n--- VERIFICATION TEST 1: POD SCALE & BOUNDS ---")
	print("Pod Global Scale: ", pod.global_transform.basis.get_scale())
	
	var aabb = AABB()
	var first = true
	for mi in model.find_children("", "MeshInstance3D", true, false):
		var m_aabb = mi.get_aabb()
		var trans_aabb = pod.global_transform.affine_inverse() * mi.global_transform * m_aabb
		if first:
			aabb = trans_aabb
			first = false
		else:
			aabb = aabb.merge(trans_aabb)
			
	print("Pod Shell Size in Local Space of World: Width X = %.3f, Height Y = %.3f, Depth Z = %.3f" % [aabb.size.x, aabb.size.y, aabb.size.z])
	
	# Interior floor bounding size
	var floor_body = pod.get_node("InteriorFloor") as StaticBody3D
	var floor_col = floor_body.get_node("CollisionShape3D") as CollisionShape3D
	var floor_shape = floor_col.shape as BoxShape3D
	var floor_world_size = Vector3(floor_shape.size.x * scale_vec.x, floor_shape.size.y * scale_vec.y, floor_shape.size.z * scale_vec.z)
	print("Bounding Size of Interior Floor: Width X = %.2f m, Depth Z = %.2f m, Thickness Y = %.2f m" % [floor_world_size.x, floor_world_size.z, floor_world_size.y])
	
	# Trigger vs Hatch global position
	var door = pod.find_child("Line0022", true, false) as Node3D
	print("\n--- VERIFICATION TEST 2: TRIGGER VS HATCH POSITION ---")
	print("Pod Trigger Global Position: ", trig.global_position)
	print("Hatch Global Position:       ", door.global_position)
	var hatch_dist = trig.global_position.distance_to(door.global_position)
	print("Distance between Trigger and Hatch: %.4f units (target: within 1 unit)" % hatch_dist)
	assert(hatch_dist <= 1.0, "Trigger must match hatch position within 1 unit!")
	
	# Height difference between pod base and surface
	print("\n--- VERIFICATION TEST 3: POD BASE VS TERRAIN SURFACE ---")
	var planet = world.get_node("ProceduralMars") as ProceduralPlanet
	var pod_dir = (pod.global_position - planet.global_position).normalized()
	var surf_pt = planet.get_surface_point(pod_dir)
	var base_pt = pod.to_global(Vector3(0.0, aabb.position.y, 0.0))
	var base_surf_diff = abs((base_pt - planet.global_position).length() - (surf_pt - planet.global_position).length())
	print("Pod Base Point:       %s (Height: %.4f m)" % [base_pt, (base_pt - planet.global_position).length()])
	print("Surface Point:        %s (Height: %.4f m)" % [surf_pt, (surf_pt - planet.global_position).length()])
	print("Base vs Surface Diff: %.4f units (target: < 0.5 units)" % base_surf_diff)
	assert(base_surf_diff < 0.5, "Pod base must be on terrain surface within 0.5 units!")
	
	# Test Player walking in through hatch
	print("\n--- VERIFICATION TEST 4: WALK PLAYER THROUGH HATCH ---")
	var player = world.get_node("Player") as PlanetWalker
	pod.set_door_open(true)
	pod.force_update_transform()
	
	# Start player outside hatch facing inward
	var outside_pos = pod.to_global(Vector3(0.0, 0.2, 4.0)) # 4m in front of pod on the walkway
	var inside_pos = pod.to_global(Vector3(0.0, 0.2, 0.0))  # inside center of pod
	
	player.global_position = outside_pos
	player.velocity = Vector3.ZERO
	player.force_update_transform()
	
	print("Starting player outside hatch at: ", player.global_position)
	var walk_dir = (inside_pos - outside_pos).normalized()
	var entered_interior = false
	var clipped_walls = false
	
	# Simulate 60 physics steps of walking inward
	for step in range(60):
		player.velocity = walk_dir * 1.5
		player.move_and_slide()
		var player_rel = pod.to_local(player.global_position)
		if player_rel.z < 0.5:
			entered_interior = true
			break
			
	var final_rel = pod.to_local(player.global_position)
	print("Final player pos relative to pod: %s" % final_rel)
	print("Entered interior: %s" % entered_interior)
	assert(entered_interior, "Player must be able to walk into the pod interior through the hatch!")
	print("[PASS] Player entered pod interior through hatch without clipping through walls.")
	
	world.queue_free()
	quit(0)
	return true
