extends Node

enum SquadState {
	MARCHING,
	COMBAT
}

var current_state: SquadState = SquadState.MARCHING
var current_waypoint_index: int = 0
var waypoints: Array[Vector2] = []
var _scan_timer: float = 0.0


func set_waypoints(points: Array[Vector2]) -> void:
	waypoints = points
	current_waypoint_index = 0
	

func start_marching() -> void:
	current_state = SquadState.MARCHING
	_move_to_current_waypoint()
	
func _move_to_current_waypoint() -> void:
	if current_waypoint_index >= waypoints.size(): return
	var target = waypoints[current_waypoint_index]
	
	var alive = _get_alive_units()
	for i in range(alive.size()):
		var unit = alive[i]
		var offset = Vector2(0, i * 30)
		unit.move_to(target + offset)
		


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_scan_for_enemies()

	if current_state == SquadState.MARCHING:
		var alive = _get_alive_unit()
		if alive.is_empty(): return
		var front_unit = alive[0]
		if front_unit.global_position.distance_to(waypoints[current_waypoint_index] < 100.0):
			current_waypoint_index += 1
			if current_waypoint_index < waypoints.size():
				_move_to_current_waypoint()
				
				
func _scan_for_enemies() -> void:
	var alive = _get_alive_units()
	if alive.is_empty(): return
	
	var center = alive[0].global_position
	var enemies = _find_nearby_enemies(center, 250.0)
	
	if not enemies.is_empty():
		if current_state != SquadState.COMBAT:
			current_state = SquadState.COMBAT
			_start_combat(enemies)
			
	else:
		if current_state == SquadState.COMBAT:
			current_state = SquadState.MARCHING
			_move_to_current_waypoint()
			
func _start_combat(enemies: Array[Unit]) -> void:
	var alive = _get_alive_units()
	
	enemies.sort_custom(func(a, b): return alive[0].global_position.distance_squared_to(a.global_position)  < alive[0].global_position.distance_squared_to(b.global_position))
	
	var assigned_targets: Dictionary = {}
	var max_units_per_target = 2
	
	for unit in alive:
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
					
		if not target_found and not enemies.is_empty():
			var main_enmemy = enemies[0]
			var offset_angle = rangf() * TAU
			var surround_pos = main_enemy.global_position + Vector2(cos(offset_angle), sin(offset_angle)) * 60.0
			
			unit.current_target = main_enmemy
			unit.move_to(surround_pos)
			
			
		
			
	
	
