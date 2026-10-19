extends Unit

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_dir: String = "e"
var _pending_frames: SpriteFrames = null 

func setup_fraction(new_fraction: Fraction, frames: SpriteFrames) -> void:
	fraction = new_fraction
	_pending_frames = frames
	
	if is_node_ready():
		_apply_frames()
	
	if frames != null:
		anim_sprite.sprite_frames = frames
	else:
		push_warning("Крипу не передан SpriteFrames для фракции: " + str(new_fraction))

func _ready() -> void:
	
	super._ready()
	
	_apply_frames()
	
	#if anim_sprite.sprite_frames == null:
		#push_error("Крип заспавнен без анимаций! Назначьте SpriteFrames в инспекторе или через setup_faction.")
		#return
		
		
	
	state_changed.connect(_on_state_changed)
	
	if combat_module:
		combat_module.attack_performed.connect(_on_attack_performed)
		
	_play_animation("idle")
	#died.disconnect(_on_died)

func _apply_frames() -> void:
	if _pending_frames != null and anim_sprite != null:
		anim_sprite.sprite_frames = _pending_frames
		_pending_frames = null
		
		if current_state == Unit.State.IDLE:
			_play_animation("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if velocity.x > 0:
		anim_sprite.flip_h = false
	elif velocity.x < 0:
		anim_sprite.flip_h = true
		
	
# ==========================================
# ОБРАБОТКА АНИМАЦИЙ
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
			3: current_dir = "sw"
			4, -4: current_dir = "w"
			5, -3: current_dir = "nw"
			6, -2: current_dir = "n"
			7, -1: current_dir = "ne"

# Вспомогательная функция для запуска анимации с нужным суффиксом
func _play_animation(base_name: String) -> void:
	# Проверяем, существует ли такая анимация (защита от вылетов)
	var anim_name = base_name + "_" + current_dir
	if anim_sprite.sprite_frames.has_animation(anim_name):
		anim_sprite.play(anim_name)
	else:
		# Если анимации нет, пробуем запустить без суффикса (например, для смерти)
		anim_sprite.play(base_name)

# ==========================================
# ОБРАБОТКА СОСТОЯНИЙ
# ==========================================

func _on_state_changed(_old_state: State, new_state: State) -> void:
	# Не перебиваем анимацию смерти
	if current_state == State.DEAD:
		return
		
	match new_state:
		State.IDLE:
#			anim.idle
			_play_animation("idle")
		State.MOVE:
			_play_animation("walk")
		
func _on_attack_performed(_target: Node2D) -> void:
	_play_animation("attack")
	await anim_sprite.animation_finished
	
	if current_state == State.ATTACK:
		_play_animation("idle")
		
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
