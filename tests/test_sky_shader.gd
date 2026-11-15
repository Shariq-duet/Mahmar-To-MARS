extends SceneTree

func _init() -> void:
	var env = Environment.new()
	var sky = Sky.new()
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type sky;
	uniform vec4 sky_color : source_color = vec4(0.82, 0.58, 0.38, 1.0);
	void sky() {
		COLOR = sky_color.rgb;
	}
	"""
	mat.shader = shader
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	print("Sky shader compiled and instantiated successfully!")
	quit(0)
