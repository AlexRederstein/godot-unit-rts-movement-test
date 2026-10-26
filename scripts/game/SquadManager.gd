# res://scripts/squad_manager.gd
class_name SquadManager

const SPACING: float = 50.0 # Расстояние между юнитами (16 коллизия + 18 навигация + запас)

# ==========================================
# 1. КОМАНДА ДВИЖЕНИЯ (Строем)
# ==========================================
static func command_move(units: Array[Unit], target_pos: Vector2) -> void:
	var alive_units = _filter_alive(units)
	if alive_units.is_empty(): return

	var count = alive_units.size()
	
	# Вычисляем размеры сетки (квадрат)
	var columns = int(ceil(sqrt(count)))
	var rows = int(ceil(float(count) / columns))
	
	# Центрируем строй относительно точки клика
	var start_offset = Vector2(-(columns - 1) * SPACING / 2.0, -(rows - 1) * SPACING / 2.0)
	
	for i in range(count):
		var unit = alive_units[i]
		
		# Вычисляем позицию в сетке
		var col = i % columns
		var row = i / columns
		var offset = start_offset + Vector2(col * SPACING, row * SPACING)
		
		# Отдаем команду юниту
		unit.move_to(target_pos + offset)

# ==========================================
# 2. КОМАНДА АТАКИ (Распределение целей)
# ==========================================
static func command_attack(units: Array[Unit], primary_target: Unit) -> void:
	var alive_units = _filter_alive(units)
	if alive_units.is_empty(): return

	# Ищем врагов рядом с главной целью (радиус 250 пикселей)
	var enemies = _find_nearby_enemies(primary_target.global_position, 250.0)
	if enemies.is_empty():
		enemies.append(primary_target)

	# Сортируем врагов по удаленности от нашего отряда (ближайшие первыми)
	var squad_center = alive_units[0].global_position
	enemies.sort_custom(func(a, b): return squad_center.distance_squared_to(a.global_position) < squad_center.distance_squared_to(b.global_position))

	var assigned_targets: Dictionary = {} # target -> count
	var max_units_per_target = 3 # Максимум 3 крипа на одну цель (чтобы не толкались)
	
	var surround_index = 0 # Счетчик для тех, кто встает в окружение
	var total_surrounders = 0
	
	# Сначала считаем, сколько нам нужно "окружающих"
	for i in range(alive_units.size()):
		var enemy_idx = min(i / max_units_per_target, enemies.size() - 1)
		if (i / max_units_per_target) >= enemies.size():
			total_surrounders += 1

	for i in range(alive_units.size()):
		var unit = alive_units[i]
		
		# Пытаемся найти врага, на которого еще не набился лимит
		var target_found = false
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.current_state == UnitTypes.State.DEAD:
				continue
				
			var count = assigned_targets.get(enemy, 0)
			if count < max_units_per_target:
				unit.attack(enemy)
				assigned_targets[enemy] = count + 1
				target_found = true
				break
		
		# Если всем врагам уже хватает атакующих, остальные встают в окружение
		if not target_found and not enemies.is_empty():
			var main_enemy = enemies[0] # Берем главного
			if is_instance_valid(main_enemy):
				# Вычисляем угол для окружения
				var angle = (float(surround_index) / total_surrounders) * TAU
				surround_index += 1
				
				# Ставим их на расстоянии чуть меньше радиуса атаки, чтобы они точно доставали
				var surround_dist = main_enemy.stats.attack_range * 0.8
				var offset = Vector2(cos(angle), sin(angle)) * surround_dist
				var destination = main_enemy.global_position + offset
				
				# ГОВОРИМ ЮНИТУ: "Беги в точку, но помни, что цель — этот враг"
				unit.command_attack_move(main_enemy, destination)

# ==========================================
# ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
# ==========================================
static func _filter_alive(units: Array[Unit]) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.is_inside_tree() and unit.current_state != UnitTypes.State.DEAD:
			result.append(unit)
	return result

static func _find_nearby_enemies(center: Vector2, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	var enemies = GameManager.get_all_enemies_of_fraction(GameManager.local_player_fraction) # Нужен метод в GameManager
	
	# Если GameManager нет, используем группы (в твоем коде ты делишь по metadata.fraction)
	# Для примера, просто перебираем всех юнитов на сцене
	# (В реальном проекте лучше использовать PhysicsShapeQuery или группы)
	for node in Engine.get_main_loop().current_scene.get_children():
		if node is Unit and is_instance_valid(node) and node.current_state != UnitTypes.State.DEAD:
			if node.metadata.fraction != GameManager.local_player_fraction:
				if center.distance_to(node.global_position) <= radius:
					result.append(node)
	return result
