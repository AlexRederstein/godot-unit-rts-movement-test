extends Node2D
class_name UnitsManager

# --- Настройки TEST ---
@export var unit_scene: PackedScene # Перетащи сюда сцену юнита в инспекторе
@export var spawn_count: int = 4
@export var move_target: Vector2 = Vector2(600, 400) # Куда поведём якорь

# --- Состояние ---
var units: Array[Unit] = []
var _anchor_position: Vector2
var _anchor_path: PackedVector2Array = []
var _anchor_path_index: int = 0
var _anchor_speed: float = 120.0 # Скорость якоря (пикселей в секунду)

func _ready() -> void:
	_setup_navigation.call_deferred()
	

func _setup_navigation() -> void:
	await get_tree().physics_frame
	_spawn_units()
	
	# --- ПРИНУДИТЕЛЬНАЯ РЕГИСТРАЦИЯ РЕГИОНА ---
	# Найди свой регион (путь может отличаться, проверь в сцене)
	var region_node = get_node_or_null("../World/NavigationRegion2D")
	if region_node:
		var poly = region_node.navigation_polygon
		# Сбрасываем и возвращаем полигон, чтобы заставить сервер обновиться
		region_node.navigation_polygon = null
		await get_tree().process_frame
		await get_tree().process_frame
		region_node.navigation_polygon = poly
		print("Полигон перерегистрирован принудительно.")
	
	# Теперь ждем, пока сервер обработает это изменение
	var map_rid := get_world_2d().navigation_map
	var iteration_id = NavigationServer2D.map_get_iteration_id(map_rid)
	var start_iter = iteration_id
	# Ждем, пока итерация не увеличится (сервер обработал изменение)
	while iteration_id == start_iter:
		await get_tree().physics_frame
		iteration_id = NavigationServer2D.map_get_iteration_id(map_rid)
	
	print("Сервер обновлен после перерегистрации. Итерация: ", iteration_id)
	_start_anchor_move()
	
#func _setup_navigation() -> void:
	## Ждем один физический кадр для завершения синхронизации сервера
	#await get_tree().physics_frame
	#
	## Теперь можно безопасно спавнить юнитов и строить путь
	#_spawn_units()
	#_start_anchor_move()
	
	
func _spawn_units() -> void:
	if not unit_scene:
		push_error("UnitsManager: Не назначена сцена юнита!")
		return
		
	# Спавним юнитов в ряд, чтобы они не накладывались друг на друга
	var start_pos := global_position
	for i in spawn_count:
		var unit := unit_scene.instantiate() as Unit
		if unit:
			# Расставляем их с небольшим смещением
			unit.global_position = start_pos + Vector2(i * 50.0, 0)
			add_child(unit)
			units.append(unit)
	
	# Начальная позиция якоря — центр группы
	_anchor_position = _get_group_center()
	
	
func _get_group_center() -> Vector2:
	if units.is_empty():
		return global_position
	var sum := Vector2.ZERO
	for u in units:
		sum += u.global_position
	return sum / units.size()
	
	
func _start_anchor_move() -> void:
	var map_rid := get_world_2d().navigation_map
	NavigationServer2D.map_force_update(map_rid)
	
	# 1. Магнитим старт и финиш к проходимой зоне
	var safe_start := NavigationServer2D.map_get_closest_point(map_rid, _anchor_position)
	var safe_target := NavigationServer2D.map_get_closest_point(map_rid, move_target)
	
	print("Скорректированный старт: ", safe_start)
	print("Скорректированная цель: ", safe_target)

	# 2. Строим путь уже по безопасным точкам
	_anchor_path = _build_path(safe_start, safe_target)
	_anchor_path_index = 0
	
	if _anchor_path.is_empty():
		push_warning("UnitsManager: Путь всё ещё не найден. Возможно, старт и финиш в разных несвязанных зонах навмеша.")
	else:
		print("Якорь: путь построен, точек: ", _anchor_path.size())
		# Телепортируем якорь в безопасный старт, чтобы он не летел через стену к первой точке
		_anchor_position = safe_start 
		
		
	
func _build_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map_rid := get_world_2d().navigation_map
	# optimize=true сглаживает углы, что нам и нужно для "кривой"
	return NavigationServer2D.map_get_path(map_rid, from, to, true)
	
func _physics_process(delta: float) -> void:
	if _anchor_path.is_empty() or _anchor_path_index >= _anchor_path.size():
		return
	
	var target_point := _anchor_path[_anchor_path_index]
	var distance := _anchor_position.distance_to(target_point)
	var step := _anchor_speed * delta
	
	if distance <= step:
		# Дошли до точки, переключаемся на следующую
		_anchor_position = target_point
		_anchor_path_index += 1
	else:
		# Двигаемся по направлению к точке
		_anchor_position = _anchor_position.move_toward(target_point, step)
	
	# Просим Godot перерисовать якорь
	queue_redraw()
	
	
func _draw() -> void:
	# Рисуем путь якоря (тонкая линия)
	if not _anchor_path.is_empty():
		for i in range(_anchor_path.size() - 1):
			draw_line(_anchor_path[i], _anchor_path[i+1], Color(0.5, 0.5, 1.0, 0.3), 2.0)
	
	# Рисуем сам якорь (яркая точка)
	if not _anchor_path.is_empty():
		draw_circle(_anchor_position, 8.0, Color.ORANGE_RED)
		# Для наглядности — крестик
		draw_line(_anchor_position - Vector2(12, 0), _anchor_position + Vector2(12, 0), Color.WHITE, 1.0)
		draw_line(_anchor_position - Vector2(0, 12), _anchor_position + Vector2(0, 12), Color.WHITE, 1.0)


#
#func units_move_to(units: Array[Unit], pos: Vector2) -> void:
	#pass
