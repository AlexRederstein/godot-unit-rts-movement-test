extends Node2D


#@export var creep_scene: PackedScene

var selected_units: Array[Unit] = []

#@export var radiant_frames: SpriteFrames
#@export var dire_frames: SpriteFrames
var creeps :Dictionary[String, PackedScene] = {
	"creep_melee_radiant": preload("res://unit/creep_melee_radiant/creep_melee_radiant_scene.tscn"),
	"creep_melee_dire": preload("res://unit/creep_melee_dire/creep_melee_dire_scene.tscn")
}


func _ready() -> void:
	create_unit("creep_melee_radiant", Vector2(100, 100))
	create_unit("creep_melee_dire", Vector2(100, 200))

func create_unit(name: String, pos: Vector2) -> void:
	if creeps.has(name):
		var new_unit = creeps[name].instantiate()
		add_child(new_unit)
		new_unit.global_position = pos


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.is_action("move_click"):
			_issue_move_command(get_global_mouse_position())
		elif event.is_action("select_click"):
			_select_unit_under_mouse()
		
func _issue_move_command(target_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	
	var unit = _check_units_under_mouse(target_pos)
	
	if unit:
		#print(GameManager.local_player_fraction != unit.metadata.fraction)
		if GameManager.local_player_fraction != unit.metadata.fraction:
			for selected_unit in selected_units:
				if is_instance_valid(selected_unit) and selected_unit.has_method("attack"):
					selected_unit.attack(unit)
	else:
		for selected_unit in selected_units:
			if is_instance_valid(selected_unit) and selected_unit.has_method("move_to"):
				selected_unit.move_to(target_pos)
		

func _select_unit_under_mouse() -> void:
	var unit = _check_units_under_mouse(get_global_mouse_position())
	if unit and unit.metadata.fraction == GameManager.local_player_fraction:
		for old_selected in selected_units:
			if is_instance_valid(old_selected) and unit.has_method("set_selected"):
				old_selected.set_selected(false)
		selected_units.clear()
			
		selected_units.append(unit)
		unit.set_selected(true)
				
func _check_units_under_mouse(mouse_pos: Vector2) -> Unit:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_bodies = true
	
	var results = space.intersect_point(query)
	
	for result in results:
		var candidate = result.collider
		if candidate is Unit and is_instance_valid(candidate) and candidate.current_state != UnitTypes.State.DEAD:
			print(candidate.metadata.fraction)
			return candidate
		break
		
	return null
	
