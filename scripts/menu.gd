extends Control
## Main menu stub. Pure UI wiring only; gameplay rules live elsewhere.

const PRACTICE_SCENE := "res://scenes/practice.tscn"

@onready var practice_button: Button = $Center/Options/Practice


func _ready() -> void:
	practice_button.pressed.connect(_on_practice_pressed)
	practice_button.grab_focus()


func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file(PRACTICE_SCENE)
