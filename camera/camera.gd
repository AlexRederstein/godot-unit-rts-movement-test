extends Camera2D

@export var edge_margin: float = 20.0 # Порог расстояния от края
@export var pan_speed: float = 800.0 # Скорость скроллинга

var target_zoom: Vector2 = Vector2.ONE
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_smooth: float = 10.0

var is_dragging = false
var drag_start_mouse = Vector2.ZERO
var drag_start_cam_pos = Vector2.ZERO

func _process(delta):
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var move_dir = Vector2.ZERO
	zoom = zoom.lerp(target_zoom, zoom_smooth * delta)
	
	# Определение краёв
	#if mouse_pos.x < edge_margin:
		#move_dir.x -= 1
	#elif mouse_pos.x > viewport_size.x - edge_margin:
		#move_dir.x += 1
		#
	#if mouse_pos.y < edge_margin:
		#move_dir.y -= 1
	#elif mouse_pos.y > viewport_size.y - edge_margin:
		#move_dir.y += 1

	if move_dir != Vector2.ZERO:
		# Учёт коэффициента масштабирования, чтобы скорость не менялась при увеличении
		position += move_dir.normalized() * pan_speed * delta / zoom.x
		

func _unhandled_input(event):
	if event is InputEventMouseButton:
		# Нажатие средней кнопки
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = (target_zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = (target_zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_mouse = event.position
				drag_start_cam_pos = position
			else:
				is_dragging = false
				
	elif event is InputEventMouseMotion and is_dragging:
		# Вычисление смещения, деление на zoom для соответствия визуальному перемещению
		var offset = (event.position - drag_start_mouse) / zoom.x
		position = drag_start_cam_pos - offset
