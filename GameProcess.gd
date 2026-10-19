extends Node2D


@export var creep_scene: PackedScene

var selected_units: Array[Unit] = []

@export var radiant_frames: SpriteFrames
@export var dire_frames: SpriteFrames

func _ready() -> void:
	spawn_creep(Unit.Fraction.RADIANT, Vector2(100, 100))

func spawn_creep(fraction: Unit.Fraction, pos: Vector2) -> void:
	var new_creep = creep_scene.instantiate()
	
	var chosen_frames: SpriteFrames
	if fraction == Unit.Fraction.RADIANT:
		chosen_frames = radiant_frames
	else:
		chosen_frames = dire_frames
		
	new_creep.setup_fraction(fraction, chosen_frames)
	
	add_child(new_creep)
	new_creep.global_position = pos


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
	
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	
	var results = space.intersect_point(query)
	for result in results:
		var candidate = result.collider
		if candidate is Unit:
			
			for unit in selected_units:
				if is_instance_valid(unit) and unit.has_method("set_selected"):
					unit.set_selected(false)
			
			selected_units.clear()
			
			selected_units.append(candidate)
			candidate.set_selected(true)
			break
				
			
		
