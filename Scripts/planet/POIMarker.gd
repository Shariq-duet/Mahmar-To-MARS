extends Area3D
class_name POIMarker

# POIMarker.gd
# Educational points of interest for kids to discover on Mars!

@export var title: String = "Mars Base Alpha"
@export var fun_fact: String = "Did you know? A day on Mars is called a 'sol' and lasts 24 hours and 39 minutes!"
@export var sound_cue: String = "discovery"

signal discovered(title: String, fact: String)

var is_discovered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_discovered:
		is_discovered = true
		discovered.emit(title, fun_fact)
		# Animate the marker beacon
		var tween = create_tween()
		tween.tween_property($BeaconLight, "light_energy", 3.0, 0.3)
		tween.tween_property($BeaconLight, "light_energy", 1.2, 0.5)
