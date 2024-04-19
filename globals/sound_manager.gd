extends Node

@onready var sfx: Node = $SFX

func play_sfx(play_name: String) -> void:
	var player := sfx.get_node(play_name) as AudioStreamPlayer
	if not player:
		return
	player.play()
 
func setup_ui_sounds(node: Node) -> void:
	var button := node as Button
	if button:
		button.pressed.connect(play_sfx.bind("UIPress"))
		button.focus_entered.connect(play_sfx.bind("UIFocus"))
		
	for child in node.get_children():
		setup_ui_sounds(child)
