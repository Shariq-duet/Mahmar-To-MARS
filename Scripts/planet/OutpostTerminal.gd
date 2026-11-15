extends Area3D
class_name OutpostTerminal

# OutpostTerminal.gd
# Interactive computer console for managing Mars Base Alpha outpost systems.

signal terminal_opened
signal terminal_closed

var player_nearby: bool = false
var is_open: bool = false

@onready var prompt_label: Label3D = $PromptLabel
@onready var screen_light: OmniLight3D = $ScreenLight

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_nearby and event.is_action_pressed("interact"):
		toggle_terminal()

func toggle_terminal() -> void:
	is_open = not is_open
	if is_open:
		terminal_opened.emit()
		if prompt_label:
			prompt_label.text = "Press E to Exit Console"
	else:
		terminal_closed.emit()
		if prompt_label:
			prompt_label.text = "Press E to Access Console"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "Press E to Access Console"
		if screen_light:
			screen_light.light_energy = 2.5

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		if is_open:
			toggle_terminal()
		if prompt_label:
			prompt_label.visible = false
		if screen_light:
			screen_light.light_energy = 1.0
