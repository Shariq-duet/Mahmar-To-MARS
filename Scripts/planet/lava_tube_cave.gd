extends Area3D
class_name LavaTubeCave

# lava_tube_cave.gd
# Authentic Martian volcanic lava tube & subsurface glacial ice cavern.
# Provides 100% protection from cosmic rays / solar storms and replenishes water.

signal ice_harvested

@export var cave_name: String = "Pavonis Lava Tube"
@onready var prompt_label: Label3D = $PromptLabel
@onready var crystal_light: OmniLight3D = $CrystalLight

var is_player_inside: bool = false
var is_player_near_ice: bool = false
var ice_harvested_count: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_prompt()

func _update_prompt() -> void:
	if not prompt_label:
		return
	if is_player_inside:
		prompt_label.text = "🕳️ %s\nNatural Basalt Radiation Shelter (0 mSv/h)\nPress [E] to Extract Glacial Ice Water" % cave_name
	else:
		prompt_label.text = "🕳️ %s Entrance\n(Natural Radiation Shelter)" % cave_name

func _unhandled_input(event: InputEvent) -> void:
	if is_player_inside and event.is_action_pressed("interact"):
		harvest_glacial_ice()

func harvest_glacial_ice() -> void:
	ice_harvested_count += 1
	ice_harvested.emit()
	if prompt_label:
		prompt_label.text = "💧 Ice Extracted & Purified into Drinking Water!\nWater reserves 100%!"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		_update_prompt()
