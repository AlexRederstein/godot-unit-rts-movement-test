extends Node2D
class_name GroupManager

enum Formation { LINE, GRID, WEDGE, COLUMN }

@export var formation: Formation = Formation.GRID
@export var spacing: float = 40.0   # расстояние между слотами
@export var rows: int = 2           # для GRID/WEDGE

var units: Array[Unit] = []
var anchor_position: Vector2
var anchor_velocity: Vector2 = Vector2.ZERO

# Слоты в локальных координатах якоря (без поворота)
var _slot_offsets: Array[Vector2] = []

# Для движения якоря по пути
var _anchor_path: PackedVector2Array = []
var _anchor_path_index: int = 0

func add_unit(unit: Unit) -> void:
	if unit in units: return
	units.append(unit)
	_recalculate_slots()

func remove_unit(unit: Unit) -> void:
	units.erase(unit)
	_recalculate_slots()

# === Публичный API ===
func move_to(destination: Vector2) -> void:
	anchor_position = _centroid_of_units()
	_build_anchor_path(anchor_position, destination)

func stop() -> void:
	_anchor_path.clear()
	for u in units:
		u.stop()
		
		
func _recalculate_slots() -> void:
	_slot_offsets.clear()
	var count := units.size()
	if count == 0: return

	match formation:
		Formation.LINE:
			var start_x := -(count - 1) * spacing * 0.5
			for i in count:
				_slot_offsets.append(Vector2(start_x + i * spacing, 0))
		Formation.GRID:
			var cols := int(ceil(count / float(rows)))
			var start_x := -(cols - 1) * spacing * 0.5
			var start_y := -(rows - 1) * spacing * 0.5
			for i in count:
				var c := i % cols
				var r := i / cols
				_slot_offsets.append(Vector2(
					start_x + c * spacing,
					start_y + r * spacing
				))
		Formation.WEDGE:
			# Простой клин: 1, 3, 5, 7... юнитов в ряду
			var placed := 0
			var row := 0
			while placed < count:
				var row_count := 1 + row * 2
				var start_x := -(row_count - 1) * spacing * 0.5
				for c in row_count:
					if placed >= count: break
					_slot_offsets.append(Vector2(
						start_x + c * spacing,
						row * spacing
					))
					placed += 1
				row += 1
		Formation.COLUMN:
			for i in count:
				_slot_offsets.append(Vector2(0, i * spacing))
				
				
func _physics_process(delta: float) -> void:
	if _anchor_path.is_empty():
		return

	# 1. Двигаем якорь по пути
	var target := _anchor_path[_anchor_path_index]
	var to_target := target - anchor_position
	var step := anchor_velocity.length() * delta
	
	# Скорость якоря = минимальная скорость в группе (чтобы никто не отставал)
	var anchor_speed := _min_group_speed()
	anchor_velocity = to_target.normalized() * anchor_speed
	
	if to_target.length() <= anchor_speed * delta:
		anchor_position = target
		_anchor_path_index += 1
		if _anchor_path_index >= _anchor_path.size():
			_anchor_path.clear()
			_assign_slots_and_move()  # финальная раздача
			return
	else:
		anchor_position += to_target.normalized() * anchor_speed * delta

	# 2. Раздаём юнитам их слоты
	_assign_slots_and_move()

func _assign_slots_and_move() -> void:
	for i in units.size():
		var u := units[i]
		if not is_instance_valid(u): continue
		var slot_world := anchor_position + _slot_offsets[i]
		# ВАЖНО: только если юнит ещё не пришёл в свой слот
		# (иначе он будет дёргаться каждый кадр)
		if u.global_position.distance_to(slot_world) > 8.0:
			u.move_to(slot_world)
			
