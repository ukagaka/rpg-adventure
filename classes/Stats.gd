extends Node

class_name Stats

signal health_changed

@export var max_health:int = 3
@onready var health: int = max_health:
	set(v):
		v = clampi(v, 0, max_health)
		if health == v:
			return
		health = v
		health_changed.emit()
