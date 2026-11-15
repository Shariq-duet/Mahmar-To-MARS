@tool
extends SceneTree

func _init():
	var scene = load("res://models/space_cargo/space_cargo_transporter.glb")
	var inst = scene.instantiate()
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi = m as MeshInstance3D
		var mat_name = ""
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat = mi.mesh.surface_get_material(0)
			if mat:
				mat_name = mat.resource_name
		print("Mesh: %s | Parent: %s | AABB size: %s | Material: %s" % [mi.name, mi.get_parent().name, mi.get_aabb().size, mat_name])
	quit(0)
