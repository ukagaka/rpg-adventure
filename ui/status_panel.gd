extends HBoxContainer

@export var stats: Stats

@onready var health_bar: TextureProgressBar = $VBoxContainer/HealthBar
@onready var eased_health_bar: TextureProgressBar = $VBoxContainer/HealthBar/EasedHealthBar
@onready var energy_bar: TextureProgressBar = $VBoxContainer/EnergyBar



func _ready() -> void:
	if not stats:
		stats = Game.player_stats
		
	stats.health_changed.connect(update_health)
	update_health(true)
	
	stats.energy_changed.connect(update_energy)
	update_energy()
	
	#在 game.gd 里 change_scene 方法里，调用 tree.change_scene_to_file(path) 销毁场景后，
	#后续如果有继续调用连接的会提示方法为空，所以这里在销毁时，把连接关闭
	tree_exited.connect(func ():
		stats.health_changed.disconnect(update_health)
		stats.energy_changed.disconnect(update_energy)
	)
	

func update_health(skip_anim := false) -> void:
	var percentage := stats.health / float(stats.max_health)
	health_bar.value = percentage

	if skip_anim:
		eased_health_bar.value = percentage
	else:
		create_tween().tween_property(eased_health_bar, "value", percentage, 0.3)

func update_energy() -> void:
	var percentage := stats.energy / stats.max_energy
	energy_bar.value = percentage
