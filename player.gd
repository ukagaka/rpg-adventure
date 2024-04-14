extends CharacterBody2D

var gravity := ProjectSettings.get("physics/2d/default_gravity") as float

func _physics_process(delta:float) -> void:
	velocity.y += gravity * delta
	move_and_slide()
