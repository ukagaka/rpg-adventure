extends Control

@onready var resume: Button = $VBoxContainer/Actions/H/Resume


func _ready() -> void:
	hide()
	SoundManager.setup_ui_sounds(self)
	visibility_changed.connect(func():
		get_tree().paused = visible
	)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		hide()
		#如果隐藏掉以后，把后续执行该事件继续往下传播
		#如果不把该事件停掉则调用该方法的如果也检测pause 事件就变成了死循环
		get_window().set_input_as_handled()

func show_pause() -> void:
	show()
	resume.grab_focus()

func _on_resume_pressed() -> void:
	hide()


func _on_quit_pressed() -> void:
	Game.back_to_title()
