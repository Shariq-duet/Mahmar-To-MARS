extends Node3D
class_name PlanetGravity

# PlanetGravity.gd
# Handles Mars spherical gravity (5x upscaled planetary scale).

@export var planet_name: String = "Mars"
@export var planet_radius: float = 300.0
@export var atmosphere_radius: float = 550.0
@export var gravity_strength: float = 5.8 # Floatier than Earth (~9.8) for kid exploration

@onready var gravity_area: Area3D = $GravityArea

func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("register_planet"):
		gm.register_planet(self)
	
	if gravity_area:
		gravity_area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
		gravity_area.gravity_point = true
		gravity_area.gravity_point_center = Vector3.ZERO
		gravity_area.gravity = gravity_strength

func _exit_tree() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("unregister_planet"):
		gm.unregister_planet(self)

func get_gravity_direction(from_pos: Vector3) -> Vector3:
	return (global_position - from_pos).normalized()

func get_surface_normal(from_pos: Vector3) -> Vector3:
	return (from_pos - global_position).normalized()

func get_altitude(from_pos: Vector3) -> float:
	return from_pos.distance_to(global_position) - planet_radius
