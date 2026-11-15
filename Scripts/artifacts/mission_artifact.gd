extends Area3D
class_name MissionArtifact

# mission_artifact.gd
# Deterministically placed historical NASA mission probes on crater rims.

signal artifact_collected(mission_name: String, lore: String, part_name: String)

@export var mission_name: String = "Viking 1 (1976)"
@export var lore_fact: String = "Viking 1 was the very first spacecraft to successfully land on Mars and operate for over 6 years!"
@export var repair_part: String = "Heat Shield Ceramic Tile" # empty if just lore
@export var has_been_collected: bool = false

@onready var beacon_light: OmniLight3D = $BeaconLight
@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if label_3d:
		label_3d.text = "🛰️ " + mission_name

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not has_been_collected:
		has_been_collected = true
		artifact_collected.emit(mission_name, lore_fact, repair_part)
		
		# Visual indication
		if beacon_light:
			beacon_light.light_color = Color(0.2, 0.9, 0.3)
			beacon_light.light_energy = 3.0
		if label_3d:
			label_3d.text = "✅ DISCOVERED: " + mission_name
