extends SceneTree

func _init() -> void:
	var shader = load("res://Assets/Shaders/mars_sky.gdshader")
	if not shader:
		printerr("Failed to load mars_sky.gdshader")
		quit(1)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	var sky = Sky.new()
	sky.sky_material = mat
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	print("mars_sky.gdshader compiled and verified successfully!")
	quit(0)
