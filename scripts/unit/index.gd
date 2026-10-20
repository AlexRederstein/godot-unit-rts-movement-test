extends CharacterBody2D
class_name Unit


enum Fraction {
	RADIANT,
	DIRE
}

# ---- СИГНАЛЫ ----
signal died
signal state_changed(old_state, new_state)

@export var metadata: UnitMetaData
@export var stats: UnitStats

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var selection_visual: Sprite2D = $SelectionCircle
@onready var combat_module: UnitCombat = $CombatModule
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var heath_bar: ProgressBar = $HeatlhBar

# --- ФРАКЦИЯ ----
var fraction: Fraction = Fraction.RADIANT

# --- СОСТОЯНИЕ ----
var current_state: UnitTypes.State = UnitTypes.State.IDLE
var current_target: Node2D = null
var _is_selected: bool = false

# ---- БАЗОВЫЕ ХАРАКТЕРИСТИКИ ----
var health: int

# --- Технические переменные ---

var current_dir: String = "e"

# =================================================
# ИНИЦИАЛИЗАЦИЯ 
# ================================================= 
func _ready() -> void:
	if not stats:
		push_error("Unit: Не назначен UnitStats")
		return
		
	if anim_sprite.sprite_frames == null:
		push_error("Юнит заспавнен без анимаций! Назначьте SpriteFrames в инспекторе или через setup_fraction.")
		return
		
	heath_bar.max_value = stats.max_health
	heath_bar.value = stats.health
		
	health = stats.max_health
	combat_module.setup(stats)
	
	combat_module.attack_performed.connect(_on_attack_performed)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	state_changed.connect(_on_state_changed)

	_setup_nav_agent()
	
	if selection_visual:
		selection_visual.visible = false
		
	if anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.play("idle")
	

func setup_unit_visual(p_visuals: UnitVisuals) -> void:
	if p_visuals and p_visuals.sprite_frames:
		# Используем $ напрямую, так как @onready еще null до add_child()
		var sprite = $AnimatedSprite2D
		sprite.sprite_frames = p_visuals.sprite_frames

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
func setup_sprites(new_sprites: SpriteFrames) -> void:
	if new_sprites:
		anim_sprite.sprite_frames = new_sprites 

func move_to(target_pos: Vector2) -> void:
	if current_state == UnitTypes.State.DEAD: return
	
	current_target = null
	nav_agent.target_position = target_pos
	set_state(UnitTypes.State.MOVE)
	
func attack(target: Node2D) -> void:
	if current_state == UnitTypes.State.DEAD or not is_instance_valid(target): return
	
	current_target = target
	set_state(UnitTypes.State.ATTACK)
	
func stop() -> void:
	if current_state == UnitTypes.State.DEAD: return
	
	current_target = null
	nav_agent.target_position = global_position
	velocity = Vector2.ZERO
	set_state(UnitTypes.State.IDLE)
	
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

func set_state(new_state: UnitTypes.State) -> void:
	if current_state == new_state or current_state == UnitTypes.State.DEAD: return
	
	var old_state = current_state
	current_state = new_state
	
	match  current_state:
		UnitTypes.State.IDLE, UnitTypes.State.HOLD:
			nav_agent.avoidance_priority = 1.0
			#nav_agent.avoidance_enabled = false
		UnitTypes.State.MOVE, UnitTypes.State.ATTACK:
			nav_agent.avoidance_priority = 0.0
			#nav_agent.avoidance_enabled = true
			
	#print("avoidance ", nav_agent.avoidance_enabled)
	state_changed.emit(old_state, new_state)
	
# Возможно такое придется прописывать отдельно для юнитов, что бы разнообразить поведение
func _on_state_changed(_old_state: UnitTypes.State, new_state: UnitTypes.State) -> void:
	# Не перебиваем анимацию смерти
	if current_state == UnitTypes.State.DEAD:
		return
		
	match new_state:
		UnitTypes.State.IDLE:
#			anim.idle
			anim_sprite.play("idle")
		#UnitTypes.State.MOVE:
			#_play_animation("walk")
	
	
func _physics_process(delta: float) -> void:
	if current_state == UnitTypes.State.DEAD: return
	
	if velocity.x != 0:
		anim_sprite.flip_h = velocity.x < 0
	
	_update_direction()
	#print(current_dir)
	_check_transitions()
	
	match current_state:
		UnitTypes.State.IDLE:
			_process_idle()
		UnitTypes.State.MOVE:
			_process_move()
		UnitTypes.State.ATTACK:
			_process_attack()
		
func _check_transitions() -> void:
	if current_target:
		if not is_instance_valid(current_target) or not current_target.is_inside_tree():
			current_target = null
			set_state(UnitTypes.State.IDLE)
			return
		
		var dist = global_position.distance_to(current_target.global_position)
		if dist <= stats.attack_range:
			set_state(UnitTypes.State.ATTACK)
		else:
			set_state(UnitTypes.State.MOVE)
	elif current_state == UnitTypes.State.MOVE and nav_agent.is_navigation_finished():
		set_state(UnitTypes.State.IDLE)
	

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
	
	_play_animation("walk")
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
		set_state(UnitTypes.State.MOVE)
		
func take_damage(amount: int) -> void:
	if current_state == UnitTypes.State.DEAD: return
	
	health -= amount
	if health <= 0:
		_die()
		
		
func _die() -> void:
	set_state(UnitTypes.State.DEAD)
	died.emit()
	collision_layer = 0
	collision_mask = 0
	nav_agent.avoidance_enabled = false
	
	_on_died() 
	
	# Ждем, пока анимация доиграет, и только потом удаляем
	await anim_sprite.animation_finished
	
	queue_free()
		
func _on_died() -> void:
	var chosen_anim := "death"
	var has_d1 = anim_sprite.sprite_frames.has_animation("death_1")
	var has_d2 = anim_sprite.sprite_frames.has_animation("death_2")
	
	if has_d1 and has_d2:
		# Если есть обе — подбрасываем монетку (randi() % 2 возвращает 0 или 1)
		if randi() % 2 == 0:
			chosen_anim = "death_1"
		else:
			chosen_anim = "death_2"
	elif has_d1:
		# Если есть только первая
		chosen_anim = "death_1"
	elif has_d2:
		# Если есть только вторая
		chosen_anim = "death_2"
	elif not anim_sprite.sprite_frames.has_animation("death"):
		push_warning("У юнита нет анимации смерти!")
		return
		
	anim_sprite.play(chosen_anim)
	
# ==========================================
# Сигналы
# ==========================================
	
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()
	

func _on_attack_performed(_target: Node2D) -> void:
	_play_animation("attack")
	await anim_sprite.animation_finished
	
	if current_state == UnitTypes.State.ATTACK:
		anim_sprite.play("idle")
	
	
# ==========================================
# Анимации
# ==========================================

# ==========================================
# ОПРЕДЕЛЕНИЕ НАПРАВЛЕНИЯ
# ==========================================
func _update_direction() -> void:
	# Если юнит движется (скорость больше 1 пикселя в секунду)
	if velocity.length_squared() > 1.0:
		# Получаем угол в градусах (от -180 до 180)
		# В Godot: 0 = восток (E), 90 = юг (S), 180/-180 = запад (W), -90 = север (N)
		var angle_deg = rad_to_deg(velocity.angle())
		
		# Разбиваем 360 градусов на 8 секторов по 45 градусов
		var sector = int(round(angle_deg / 45.0)) % 8
		
		match sector:
			0: current_dir = "e"
			1: current_dir = "se"
			2: current_dir = "s"
			3: current_dir = "se"
			4, -4: current_dir = "e"
			5, -3: current_dir = "ne"
			6, -2: current_dir = "n"
			7, -1: current_dir = "ne"

# Вспомогательная функция для запуска анимации с нужным суффиксом
func _play_animation(base_name: String) -> void:
	# Проверяем, существует ли такая анимация (защита от вылетов)
	var anim_name = base_name + "_" + current_dir
	#print(anim_name)
	if anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
	else:
		# Если анимации нет, пробуем запустить без суффикса (например, для смерти)
		anim_sprite.play(base_name)
	
