extends CanvasLayer
class_name SelectionManager

signal selection_changed(units: Array[Unit])
@onready var box: Panel = $SelectionBox
var selected_units: Array[Unit] = []

var is_dragging := false
var drag_start := Vector2.ZERO

func _ready():
	box.visible = false

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start = event.position
			box.position = drag_start
			box.size = Vector2.ZERO
			box.visible = true
		elif is_dragging:
			is_dragging = false
			var rect = Rect2(drag_start, event.position - drag_start).abs()
			box.visible = false
			_finish_selection(rect)

	elif event is InputEventMouseMotion and is_dragging:
		var rect = Rect2(drag_start, event.position - drag_start).abs()
		box.position = rect.position
		box.size = rect.size

func _finish_selection(rect: Rect2):
	var current_player = GameManager.get_current_player_id()
	print(current_player)
	var selected := []
	for unit in get_tree().get_nodes_in_group("units"):
		print("unit id ", unit.owner_id)
		if unit.owner_id != current_player:
			continue
		var screen_pos = unit.get_global_transform_with_canvas().origin
		if rect.has_point(screen_pos):
			selected.append(unit)
	_apply_selection(selected)

func _apply_selection(units: Array):
	if not Input.is_key_pressed(KEY_SHIFT):
		for u in selected_units:
			if is_instance_valid(u):
				u.set_selected(false)
		selected_units.clear()

	for u in units:
		if is_instance_valid(u) and u not in selected_units:
			u.set_selected(true)
			selected_units.append(u)

	selection_changed.emit(selected_units)

func get_selected() -> Array[Unit]:
	# Очистка мёртвых ссылок на всякий случай
	selected_units = selected_units.filter(func(u): return is_instance_valid(u))
	return selected_units

func clear_selection():
	_apply_selection([])
