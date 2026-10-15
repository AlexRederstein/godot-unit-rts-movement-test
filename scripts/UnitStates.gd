extends CharacterBody2D
class_name Unit
enum State { IDLE, MOVE, ATTACK, HOLD }

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var current_state: State = State.IDLE
var current_target: Node2D = null
var speed: float = 150.0
var attack_range: float = 40.0

var _is_selected: bool = false

func _physics_process(delta: float) -> void:
	_check_state_transitions()
	_process_state(delta)
	
func _ready() -> void:
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 20.0

# --- API для внешних команд ---

func move_to(target_pos: Vector2) -> void:
	nav_agent.target_position = target_pos
	current_state = State.MOVE

func set_selected(selected: bool) -> void:
	_is_selected = selected
	print("selected!")

# --- внутренняя логика ---
func _check_state_transitions() -> void:
	if current_state and is_instance_valid(current_target):
		var distance = global_position.distance_to(current_target.global_position)
		if distance <= attack_range:
			current_state = State.ATTACK
		else:
			current_state = State.MOVE
			
	elif nav_agent.is_navigation_finished():
		current_state = State.IDLE
	elif current_state == State.IDLE and nav_agent.target_position != Vector2.ZERO:
		current_state = State.MOVE
		
		
func _process_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.MOVE:
			_process_move_state()
		State.ATTACK:
			_process_attack_state(delta)
		State.HOLD:
			velocity = Vector2.ZERO


func _process_move_state() -> void:
	if nav_agent.is_navigation_finished():
		return
		
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	nav_agent.set_velocity(direction * speed)
	
func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()
	
func _process_attack_state(delta: float) -> void:
	velocity = Vector2.ZERO
	
