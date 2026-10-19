extends CharacterBody2D
class_name Unit


# STATES
enum State { 
	IDLE, 
	MOVE, 
	ATTACK, 
	HOLD,
	DEAD 
}

# ---- СИГНАЛЫ ----
signal died
signal state_changed(old_state, new_state)

@export var stats: UnitStats

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var selection_visual: Sprite2D = $SelectionCircle
@onready var combat_module: UnitCombat = $CombatModule


# --- СОСТОЯНИЕ ----
var current_state: State = State.IDLE
var current_target: Node2D = null
var _is_selected: bool = false

# ---- БАЗОВЫЕ ХАРАКТЕРИСТИКИ ----
var health: int
# =================================================
# ИНИЦИАЛИЗАЦИЯ 
# ================================================= 
func _ready() -> void:
	if not stats:
		push_error("Unit: Не назначен UnitStats")
		return
	
	health = stats.max_health
	combat_module.setup(stats)
	
	combat_module.attack_performed.connect(_on_attack_performed)
	nav_agent.velocity_computed.connect(_on_velocity_computed)

	_setup_nav_agent()
	
	if selection_visual:
		selection_visual.visible = false


func _setup_nav_agent() -> void:
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 18.0 # Потом вынести в stats
	nav_agent.max_speed = stats.speed
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	
# =================================================
# =================================================
# =================================================
# API Внешних команд
# =================================================
# =================================================
# =================================================
func move_to(target_pos: Vector2) -> void:
	if current_state == State.DEAD: return
	
	current_target = null
	nav_agent.target_position = target_pos
	set_state(State.MOVE)
	
func attack(target: Node2D) -> void:
	if current_state == State.DEAD or not is_instance_valid(target): return
	
	current_target = target
	set_state(State.ATTACK)
	
func stop() -> void:
	if current_state == State.DEAD: return
	
	current_target = null
	nav_agent.target_position = global_position
	velocity = Vector2.ZERO
	set_state(State.IDLE)
	
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selection_visual:
		selection_visual.visible = selected
		
# =================================================
# =================================================
# =================================================
# Состояния
# =================================================
# =================================================
# =================================================


func set_state(new_state: State) -> void:
	if current_state == new_state or current_state == State.DEAD: return
	
	var old_state = current_state
	current_state = new_state
	
	match  current_state:
		State.IDLE, State.HOLD:
			nav_agent.avoidance_priority = 1.0
			#nav_agent.avoidance_enabled = false
		State.MOVE, State.ATTACK:
			nav_agent.avoidance_priority = 0.0
			#nav_agent.avoidance_enabled = true
			
	#print("avoidance ", nav_agent.avoidance_enabled)
	state_changed.emit(old_state, new_state)
	
func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	_check_transitions()
	
	match current_state:
		State.IDLE:
			_process_idle()
		State.MOVE:
			_process_move()
		State.ATTACK:
			_process_attack()
		
func _check_transitions() -> void:
	if current_target:
		if not is_instance_valid(current_target) or not current_target.is_inside_tree():
			current_target = null
			set_state(State.IDLE)
			return
		
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= stats.attack_range:
			set_state(State.ATTACK)
		else:
			set_state(State.MOVE)
	elif current_state == State.MOVE and nav_agent.is_navigation_finished():
		set_state(State.IDLE)
	

func _process_idle() -> void:
	velocity = Vector2.ZERO
	

func _process_move() -> void:
	if nav_agent.is_navigation_finished():
		return
		
#	Преследование противника
	if current_target and is_instance_valid(current_target):
		nav_agent.target_position = current_target.global_position
		
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(dir * stats.speed)
	else:
		velocity = dir * stats.speed
		move_and_slide()
		
		
func _process_attack() -> void:
	velocity = Vector2.ZERO
	
	if not current_target or not is_instance_valid(current_target):
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	if dist <= stats.attack_range:
		combat_module.try_attack(current_target)
	else:
		set_state(State.MOVE)
		
func take_damage(amount: int) -> void:
	if current_state == State.DEAD: return
	
	health -= amount
	if health <= 0:
		_die()
		
func _die() -> void:
	set_state(State.DEAD)
	died.emit()
	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false
	
	queue_free()
		
	
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()
	
func _on_attack_performed(_target: Node2D) -> void:
	pass # Потом будут анимации атаки
	
