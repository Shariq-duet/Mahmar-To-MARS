extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	var sx = 8.0 / 2.747095 # ~2.912167
	var sz = 8.0 / 2.711778 # ~2.950094
	var sy = 6.0 / 5.579019 # ~1.075458
	pod.scale = Vector3(sx, sy, sz)
	pod.force_update_transform()
	
	# Open door
	pod.set_door_open(true)
	pod.force_update_transform()
	
	var body_m = pod.find_child("62321108__7179P001_23_0", true, false) as MeshInstance3D
	var body_aabb = body_m.global_transform * body_m.get_aabb()
	print("Pod Global Scale: ", pod.scale)
	print("Pod Bounding Size: Width X = %.2f m, Height Y = %.2f m, Depth Z = %.2f m" % [body_aabb.size.x, body_aabb.size.y, body_aabb.size.z])
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	var door_mesh = pod.find_child("Line002_glass_02", true, false) as MeshInstance3D
	var door_aabb = door_mesh.global_transform * door_mesh.get_aabb()
	print("Hatch Opening Bounds: ", door_aabb)
	print("Hatch Opening: Width X = %.2f m, Height Y = %.2f m, Depth Z = %.2f m" % [door_aabb.size.x, door_aabb.size.y, door_aabb.size.z])
	
	# Check interior floor & walls
	var floor_body = pod.get_node_or_null("InteriorFloor")
	if floor_body:
		var floor_col = floor_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if floor_col and floor_col.shape is BoxShape3D:
			var fs = floor_col.shape.size * pod.scale
			print("Interior Floor: Width X = %.2f m, Depth Z = %.2f m, Height Y = %.2f m" % [fs.x, fs.z, fs.y])
			
	var trigger = pod.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if trigger:
		print("Trigger Global Pos: ", trigger.global_position)
		if trigger.shape is BoxShape3D:
			print("Trigger Global Size: ", trigger.shape.size * pod.scale)
			
	pod.queue_free()
	quit(0)
	return true
