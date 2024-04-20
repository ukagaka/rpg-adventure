extends CharacterBody2D

class_name Player

enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

enum State {
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
}

const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3,
]

const RUN_SPEED := 160.0
#需要 0.2 秒后到达这个速度
const FLOOR_ACCELERATION := RUN_SPEED / 0.5
const AIR_ACCELERATION := RUN_SPEED / 0.02
const JUMP_VELOCITY := -320.0  
const WALL_JUMP_VELOCITY := Vector2(380, -280)
const KNOCKBACK_AMOUNT := 512.0
const SLIDING_DURATION := 0.3
const SLIDING_SPEED := 256.0
const SLIDING_ENERGY := 4.0
const LANDING_HEIGHT := 100.0

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var is_first_tick := false
var is_combo_requested := false
var pending_damage: Damage
var fall_from_y : float
var interacting_with : Array[Interactable]


#是否可以连击
@export var can_combo := false

@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction

@onready var graphics: Node2D = $Graphics
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = Game.player_stats
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var slide_request_timer: Timer = $SlideRequestTimer
@onready var interaction_icon: AnimatedSprite2D = $InteractionIcon
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var pause_screen: Control = $CanvasLayer/PauseScreen


func _ready() -> void:
	stand(default_gravity, 0.01)
	stats = Game.player_stats

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	
	#如果跳跃键按的快，这时候角色跳跃不够高的话，直接让跳跃高度只有一半
	#这样就是按的跳跃键时间长就跳的高，按的快就只跳了一半
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
			
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true
		
	if event.is_action_pressed("slide"):
		slide_request_timer.start()
	
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.back().interact()
	
	if event.is_action_pressed("pause"):
		pause_screen.show_pause()

func tick_physics(state: State, delta:float) -> void:
	interaction_icon.visible = not interacting_with.is_empty()
	
	if invincible_timer.time_left > 0 :
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20 ) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
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
			stand(default_gravity, delta)
		State.WALL_SLIDING:
			move(default_gravity /3, delta)
			direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
			else:
				move(default_gravity, delta)
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
	
		State.HURT, State.DYING:
			stand(default_gravity, delta)
		State.SLIDING_END:
			stand(default_gravity, delta)
		
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
			
	is_first_tick = false

func move(gravity: float, delta:float) -> void:
	var movement := Input.get_axis("move_left", "move_right")
	
	#move_toward 起始值到目标值，速度的变化量
	#速度的变化量 = 加速度 * 时间
	#使用该方法后，人物会缓慢加速和减速，效果就是停止后
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta)
	
	#设置重力
	velocity.y += gravity * delta
	
	if not is_zero_approx(movement):
		direction = Direction.LEFT if movement < 0 else Direction.RIGHT
	
	move_and_slide()


func stand(gravity:float, delta: float)->   void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()
	
func slide(delta: float) -> void:
	velocity.x = graphics.scale.x * SLIDING_SPEED
	velocity.y += default_gravity * delta
	move_and_slide()

func die() -> void:
	game_over_screen.show_game_over()


func register_interactable(v: Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	
	interacting_with.append(v)
	

func unregister_interactable(v: Interactable) -> void:
	interacting_with.erase(v)
	

func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()

func should_slide() -> bool:
	if slide_request_timer.is_stopped():
		return false
	if stats.energy < SLIDING_ENERGY:
		return false
	return not foot_checker.is_colliding()

#负责状态转换
func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(movement) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if should_slide():
				return State.SLIDING_START
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				var height := global_position.y - fall_from_y
				return State.LANDING if height >= LANDING_HEIGHT else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
		
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE
		
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
				
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		State.SLIDING_LOOP:
			if state_machine.state_time > SLIDING_DURATION or is_on_wall():
				return State.SLIDING_END
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
	
	return StateMachine.KEEP_CURRENT



#负责播放动画
func transition_state(from: State, to: State)-> void:
	print("[%s] %s => %s" %[
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to],
	])
	
	
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
			SoundManager.play_sfx("Jump")
			
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
			fall_from_y = global_position.y
		State.LANDING:
			animation_player.play("landing")
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		State.WALL_JUMP:
			animation_player.play("jump")
			#如果快掉下去的瞬间，按住跳跃键的话，不让角色掉下去，而是跳跃
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
			
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
			SoundManager.play_sfx("Attack")
			
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
		
		State.HURT:
			animation_player.play("hurt")
			
			stats.health -= pending_damage.amount
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			pending_damage = null
			invincible_timer.start()
			
		State.DYING:
			animation_player.play("die")
			invincible_timer.stop()
			interacting_with.clear()
		State.SLIDING_START:
			animation_player.play("sliding_start")
			slide_request_timer.stop()
			stats.energy -= SLIDING_ENERGY
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		State.SLIDING_END:
			animation_player.play("sliding_end")
	
	#调试用
	#if to == State.WALL_JUMP:
		#Engine.time_scale = 0.3
	#
	#if from == State.WALL_JUMP:
		#Engine.time_scale = 1.0
				
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
		
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
