extends CharacterBody2D

const RUN_SPEED := 160.0
#需要 0.2 秒后到达这个速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.5
const AIR_ACCELERATION := RUN_SPEED / 0.02
const JUMP_VELOCITY := -320.0

var gravity := ProjectSettings.get("physics/2d/default_gravity") as float
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	#如果跳跃键按的快，这时候角色跳跃不够高的话，直接让跳跃高度只有一半
	#这样就是按的跳跃键时间长就跳的高，按的快就只跳了一半
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2


func _physics_process(delta:float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	#move_toward 起始值到目标值，速度的变化量
	#速度的变化量 = 加速度 * 时间
	#使用该方法后，人物会缓慢加速和减速，效果就是停止后
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, FLOOR_ACCELERATION * delta)
	
	#设置重力
	velocity.y += gravity * delta
	
	#如果离开了地面，并且定期器大于 0，说明是掉入悬崖掉下去了
	var can_jum := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jum and jump_request_timer.time_left > 0
	if should_jump:
		#如果快掉下去的瞬间，按住跳跃键的话，不让角色掉下去，而是跳跃
		velocity.y = JUMP_VELOCITY
		#离开地面瞬间起跳后，需要停止动画播放
		coyote_timer.stop()
		jump_request_timer.stop()
	
	if is_on_floor():
		if is_zero_approx(direction) and is_zero_approx(velocity.x):
			animation_player.play("idle")
		else:
			animation_player.play("runing")
			
	if not is_zero_approx(direction):
		sprite_2d.flip_h = direction < 0
		
	var was_on_floor := is_on_floor()
	
	move_and_slide()
	
	if is_on_floor() != was_on_floor:
		#如果角色离开了地板，并且不是跳跃的话，启动定时器
		#否则说明是角色主动跳跃所离开地面，不应该启动定时器
		if was_on_floor and not should_jump:
			coyote_timer.start()
		else:
			coyote_timer.stop()
