extends CharacterBody2D

const RUN_SPEED := 160.0
#需要 0.2 秒后到达这个速度
const ACCELERATION := RUN_SPEED / 0.2
const JUMP_VELOCITY := -320.0

var gravity := ProjectSettings.get("physics/2d/default_gravity") as float
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer


func _physics_process(delta:float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	#move_toward 起始值到目标值，速度的变化量
	#速度的变化量 = 加速度 * 时间
	#使用该方法后，人物会缓慢加速和减速，效果就是停止后，会往前滑行一段
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, ACCELERATION * delta)
	
	#设置重力，
	velocity.y += gravity * delta
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	
	if is_on_floor():
		if is_zero_approx(direction):
			animation_player.play("idle")
		else:
			animation_player.play("runing")
			
	if not is_zero_approx(direction):
		sprite_2d.flip_h = direction < 0
	
	move_and_slide()
