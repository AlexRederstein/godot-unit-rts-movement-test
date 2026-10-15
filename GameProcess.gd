extends Node2D


var selected_units: Array = []

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.is_action("move_click"):
			_issue_move_command(get_global_mouse_position())
		elif event.is_action("select_click"):
			_select_unit_under_mouse()
		
func _issue_move_command(target_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("move_to"):
			unit.move_to(target_pos)

func _select_unit_under_mouse() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
			
	selected_units.clear()
	
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	
	var results = space.intersect_point(query)
	for result in results:
		var candidate = result.collider
		if candidate is Unit:
			selected_units.append(candidate)
			candidate.set_selected(true)
			break
				
			
		
