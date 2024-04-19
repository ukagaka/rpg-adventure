extends Node

@onready var sfx: Node = $SFX

func play_sfx(play_name: String) -> void:
	var player := sfx.get_node(play_name) as AudioStreamPlayer
	if not player:
		return
	player.play()
 
