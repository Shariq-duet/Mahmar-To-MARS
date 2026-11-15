extends Node3D

# CameraArm.gd
# Third-person orbital camera designed for spherical planetary navigation.

@export var mouse_sensitivity: float = 0.0025
@export var pitch_min: float = -75.0
@export var pitch_max: float = 65.0
@export var camera_distance: float = 4.5

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var pitch: float = -15.0 # Initial slight downward tilt
var yaw: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if spring_arm:
		spring_arm.spring_length = camera_distance
		# Prevent colliding with the player itself
		spring_arm.add_excluded_object(get_parent().get_rid())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

func _process(_delta: float) -> void:
	# Local rotation on the arm
	# Rotation Y is horizontal yaw, Rotation X is vertical pitch
	rotation.y = yaw
	rotation.x = pitch

# Returns the forward direction on the tangent plane of the planet
func get_camera_forward_projected(surface_normal: Vector3) -> Vector3:
	var cam_forward = -camera.global_transform.basis.z
	var proj = cam_forward - surface_normal * cam_forward.dot(surface_normal)
	if proj.length_squared() < 0.001:
		var cam_up = camera.global_transform.basis.y
		proj = cam_up - surface_normal * cam_up.dot(surface_normal)
	return proj.normalized()
