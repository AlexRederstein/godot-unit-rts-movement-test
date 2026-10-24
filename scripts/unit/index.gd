extends CharacterBody2D
class_name Unit




# ---- СИГНАЛЫ ----
signal died
signal state_changed(old_state, new_state)

@export var metadata: UnitMetaData
@export var stats: UnitStats

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var selection_visual: Sprite2D = $SelectionCircle
@onready var combat_module: UnitCombat = $CombatModule
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var heath_bar: ProgressBar = $HealthBar
@onready var attack_timer: Timer = $AttackDelayTimer
@onready var aggro_area: Area2D = $AggroArea

# --- СОСТОЯНИЕ ----
var current_state: UnitTypes.State = UnitTypes.State.IDLE
var current_target: Node2D = null
var _is_selected: bool = false

# ---- БАЗОВЫЕ ХАРАКТЕРИСТИКИ ----
var max_health: int = 100:
	set(value):
		max_health = value
		health = min(health, max_health)
		_update_health_bar()
var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		_update_health_bar()
# --- Бой ---
var attaсk_delay :float
# --- Технические переменные ---

var current_dir: String = "e"
var _is_attacking_anim: bool = false # Флаг: проигрывается ли анимация атаки
var _is_death_animation: bool = false # Флаг: проигрывается ли анимация смерти
var _enemies_in_range: Array[Unit] = []
var _idle_scan_timer: float = 0.5

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
	
	attaсk_delay = stats.attaсk_delay
	
	attack_timer.wait_time = attaсk_delay
	
	#combat_module.attack_performed.connect(_on_attack_performed)
	anim_sprite.animation_finished.connect(_on_animation_finished)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_existed)
	state_changed.connect(_on_state_changed)

	_setup_nav_agent()
	
	if selection_visual:
		selection_visual.modulate = Color.GRAY
		#selection_visual.visible = false
	
	set_state(UnitTypes.State.IDLE)	
	#if anim_sprite.sprite_frames.has_animation("idle"):
		#anim_sprite.play("idle")
	

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
	if selected:
		selection_visual.modulate = Color.GREEN
	else:
		selection_visual.modulate = Color.GRAY
	#if selection_visual:
		#selection_visual.visible = selected
		#if selected: 
			#selection_visual.modulate = Color.GREEN
		
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
		UnitTypes.State.MOVE:
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
	
	
	_update_facing()
	#_update_direction()

	_check_transitions()
	if metadata.fraction != UnitMetaData.Fraction.RADIANT:
		print(nav_agent.avoidance_enabled)
	match current_state:
		UnitTypes.State.IDLE:
			_process_idle()
		UnitTypes.State.MOVE:
			_process_move()
		UnitTypes.State.ATTACK:
			_process_attack(delta)
		
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
	
	_idle_scan_timer -= get_physics_process_delta_time()
	if _idle_scan_timer <= 0.0:
		_idle_scan_timer = 0.5
		_scan_for_enemies()
	

func _scan_for_enemies():
	if _enemies_in_range.is_empty():
		return
		
	var target = _enemies_in_range[0]
	
	if not is_instance_valid(target) or target.current_state == UnitTypes.State.DEAD:
		_enemies_in_range.remove_at(0)
		return
	
	attack(target)

func _process_move() -> void:
#	Преследование противника
	if current_target and is_instance_valid(current_target):
		nav_agent.target_position = current_target.global_position
		
	if nav_agent.is_navigation_finished():
		return
	#print("move")
		
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	
	_play_animation("walk")
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(dir * stats.speed)
	else:
		velocity = dir * stats.speed
		move_and_slide()
		
		
func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if not current_target or not is_instance_valid(current_target):
		set_state(UnitTypes.State.IDLE)
		return
		
	var dist = global_position.distance_to(current_target.global_position)
	
	if dist > stats.attack_range:
		set_state(UnitTypes.State.MOVE)
		return
	
	if attack_timer.is_stopped():
		_is_attacking_anim = true
		_play_animation("attack")
	#if dist <= stats.attack_range and not attaсk_delay > 0:
		#_play_animation("attack")
		##combat_module.try_attack(current_target)
	#else:
		#set_state(UnitTypes.State.MOVE)
		
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
	
	var has_d_n = anim_sprite.sprite_frames.has_animation("death_n")
	var has_d_s = anim_sprite.sprite_frames.has_animation("death_s")
	#
	if has_d_n and has_d_s:
		## Если есть обе — подбрасываем монетку (randi() % 2 возвращает 0 или 1)
		match current_dir:
			"n", "ne":
				chosen_anim = "death_n"
			"e", "se", "s":
				chosen_anim = "death_s"
				
		#if current_dir:
		#else:
	elif has_d_n:
		## Если есть только первая
		chosen_anim = "death_n"
	elif has_d_s:
		## Если есть только вторая
		chosen_anim = "has_d_s"
	elif not anim_sprite.sprite_frames.has_animation("death"):
		#push_warning("У юнита нет анимации смерти!")
		return
		
	anim_sprite.play(chosen_anim)
	
# ==========================================
# Сигналы
# ==========================================
	
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if current_state == UnitTypes.State.ATTACK or current_state == UnitTypes.State.IDLE:
		velocity = Vector2.ZERO
		return
	velocity = safe_velocity
	move_and_slide()
	

func _on_attack_performed(_target: Node2D) -> void:
	_play_animation("attack")
	await anim_sprite.animation_finished
	
	if current_state == UnitTypes.State.ATTACK:
		anim_sprite.play("idle")
	
func _on_animation_finished():
	# Если завершилась анимация атаки
	if _is_attacking_anim:
		_is_attacking_anim = false
		
		# Проверяем, что цель все еще существует и мы не умерли
		if current_state == UnitTypes.State.ATTACK and current_target and is_instance_valid(current_target):
			var dist = global_position.distance_to(current_target.global_position)
			
			# Проверяем дистанцию (вдруг цель убежала за время замаха)
			if dist <= stats.attack_range:
				if current_target.has_method("take_damage"):
					current_target.take_damage(stats.damage)
					attack_timer.wait_time = attaсk_delay
					attack_timer.start()
					
					# Здесь можно добавить звук удара или спавн частиц крови
			
		# Возвращаем анимацию покоя, если мы все еще в бою
		if current_state == UnitTypes.State.ATTACK:
			anim_sprite.play("idle")
			
func _on_aggro_body_entered(body: Node2D) -> void:
	if body is Unit and is_instance_valid(body) and body.current_state != UnitTypes.State.DEAD:
		if body.metadata.fraction != self.metadata.fraction:
			if not _enemies_in_range.has(body):
				_enemies_in_range.append(body)
				

func _on_aggro_body_existed(body: Node2D) -> void:
	if _enemies_in_range.has(body):
		_enemies_in_range.erase(body)
# ==========================================
# Анимации
# ==========================================

# ==========================================
# ОПРЕДЕЛЕНИЕ НАПРАВЛЕНИЯ
# ==========================================
func _update_facing() -> void:
	var look_dir := Vector2.ZERO
	
	# 1. Определяем, куда смотреть (на цель или по движению)
	if current_state == UnitTypes.State.ATTACK and current_target and is_instance_valid(current_target):
		look_dir = global_position.direction_to(current_target.global_position)
	elif velocity.length_squared() > 1.0:
		look_dir = velocity.normalized()
	else:
		return # Стоим — ничего не меняем

	# 2. Отзеркаливание (если смотрим влево, отражаем спрайт)
	if abs(look_dir.x) > 0.1:
		anim_sprite.flip_h = look_dir.x < 0

	# 3. Определяем "виртуальное" направление для анимации
	# Берем абсолютное значение X, чтобы запад и восток давали одинаковый суффикс
	var abs_dir = Vector2(abs(look_dir.x), look_dir.y).normalized()
	var angle_deg = rad_to_deg(abs_dir.angle())
	var sector = int(round(angle_deg / 45.0)) % 8
	
	# Так как у тебя только восточные анимации, мы используем только e, ne, se, n, s
	match sector:
		0: current_dir = "e"   # Восток (или Запад с flip_h)
		1: current_dir = "se"  # Юго-восток (или Юго-запад с flip_h)
		2: current_dir = "s"   # Юг
		3: current_dir = "se"  # Юго-восток (для нижней части)
		4, -4: current_dir = "e" # Восток (для запада)
		5, -3: current_dir = "ne" # Северо-восток (или северо-запад)
		6, -2: current_dir = "n"  # Север
		7, -1: current_dir = "ne" # Северо-восток

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
		
func _update_health_bar():
	if not is_inside_tree() or not heath_bar: return
	
	heath_bar.max_value = max_health
	heath_bar.value = health
	
	if health < max_health * 0.3:
		heath_bar.modulate = Color.RED   # Мало HP
	elif health < max_health * 0.6:
		heath_bar.modulate = Color.YELLOW # Среднее HP
	else:
		heath_bar.modulate = Color.GREEN  # Много HP
	
