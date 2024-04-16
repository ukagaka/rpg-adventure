extends CharacterBody2D

enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
}

const GROUND_STATES := [State.IDLE, State.RUNNING, State.LANDING]

const RUN_SPEED := 160.0
#需要 0.2 秒后到达这个速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.5
const AIR_ACCELERATION := RUN_SPEED / 0.02
const JUMP_VELOCITY := -320.0

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false


@onready var graphics: Node2D = $Graphics
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	#如果跳跃键按的快，这时候角色跳跃不够高的话，直接让跳跃高度只有一半
	#这样就是按的跳跃键时间长就跳的高，按的快就只跳了一半
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2

func tick_physics(state: State, delta:float) -> void:
	match state:
		State.IDLE:
			move(default_gravity, delta)
		State.RUNNING:
			move(default_gravity, delta)
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
		State.FALL:
			move(default_gravity, delta)
		State.LANDING:
			stand(delta)
		State.WALL_SLIDING:
			move(default_gravity /3, delta)
			graphics.scale.x = get_wall_normal().x
	
	is_first_tick = false
		

func move(gravity: float, delta:float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	
	#move_toward 起始值到目标值，速度的变化量
	#速度的变化量 = 加速度 * 时间
	#使用该方法后，人物会缓慢加速和减速，效果就是停止后
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	
	#设置重力
	velocity.y += gravity * delta
	
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else +1
	
	move_and_slide()


func stand(delta: float)-> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += default_gravity * delta
	
	move_and_slide()


			
func get_next_state(state: State) -> State:
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	var direction := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if not is_on_floor():
				return State.FALL
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if not is_on_floor():
				return State.FALL
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not is_still:
				return State.RUNNING
				
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALL_SLIDING:
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
	
	return state


func transition_state(from: State, to: State)-> void:
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
		
	match to:
		State.IDLE:
			animation_player.play("idle")
		State.RUNNING:
			animation_player.play("runing")
		State.JUMP:
			animation_player.play("jump")
			#如果快掉下去的瞬间，按住跳跃键的话，不让角色掉下去，而是跳跃
			velocity.y = JUMP_VELOCITY
			#离开地面瞬间起跳后，需要停止动画播放
			coyote_timer.stop()
			jump_request_timer.stop()
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
		State.LANDING:
			animation_player.play("landing")
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
				
	is_first_tick = true
