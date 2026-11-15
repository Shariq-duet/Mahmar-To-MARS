extends SceneTree

func _process(delta):
	var pod_scene = load("res://Scenes/machines/crashed_pod.tscn")
	var pod = pod_scene.instantiate()
	root.add_child(pod)
	
	var sx = 6.0 / 2.747095 # ~2.184
	var sz = 6.0 / 2.711778 # ~2.213
	var sy = 3.5 / 5.579019 # ~0.627
	pod.scale = Vector3(sx, sy, sz)
	pod.force_update_transform()
	
	pod.set_door_open(true)
	pod.force_update_transform()
	
	var door = pod.find_child("Line0022", true, false) as Node3D
	print("Open Door global position: ", door.global_position)
	
	var door_mesh = pod.find_child("Line002_glass_02", true, false) as MeshInstance3D
	var door_aabb = door_mesh.global_transform * door_mesh.get_aabb()
	print("Open Door glass mesh AABB in world: ", door_aabb)
	print("Open Door bottom Y: %.3f, top Y: %.3f" % [door_aabb.position.y, door_aabb.position.y + door_aabb.size.y])
	
	# Check where the floor of the pod is
	# Cylinder004 is bottom ring:
	var ring = pod.find_child("Cylinder004_b_0", true, false) as MeshInstance3D
	var ring_aabb = ring.global_transform * ring.get_aabb()
	print("Bottom ring AABB: ", ring_aabb)
	print("Bottom ring Min Y (pod base): %.4f, Max Y: %.4f" % [ring_aabb.position.y, ring_aabb.position.y + ring_aabb.size.y])
	
	# Main body Object_25:
	var body_m = pod.find_child("62321108__7179P001_23_0", true, false) as MeshInstance3D
	var body_aabb = body_m.global_transform * body_m.get_aabb()
	print("Main body AABB: ", body_aabb)
	print("Main body Min Y: %.4f, Max Y: %.4f" % [body_aabb.position.y, body_aabb.position.y + body_aabb.size.y])
	
	pod.queue_free()
	quit(0)
	return true
