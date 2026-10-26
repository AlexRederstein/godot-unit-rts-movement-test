extends Node2D


#@export var creep_scene: PackedScene
@onready var selection: SelectionManager = $SelectionManager
@onready var units_container: Node2D = $Units

var creeps :Dictionary[String, PackedScene] = {
	"creep_melee_radiant": preload("res://unit/creep_melee_radiant/creep_melee_radiant_scene.tscn"),
	"creep_melee_dire": preload("res://unit/creep_melee_dire/creep_melee_dire_scene.tscn")
}


func _ready() -> void:
	selection.selection_changed.connect(_on_selection_changed)
	spawn_unit(creeps["creep_melee_radiant"], Vector2(100, 100), 1)
	spawn_unit(creeps["creep_melee_radiant"], Vector2(150, 100), 1)
	#create_unit("creep_melee_radiant", Vector2(100, 100))
	#create_unit("creep_melee_dire", Vector2(100, 200))

func _on_selection_changed(units: Array[Unit]):
	print("Выбрано юнитов: ", units.size())

func spawn_unit(scene: PackedScene, pos: Vector2, owner_id: int) -> void:
	var unit: Unit = scene.instantiate()
	unit.unit_id = GameManager.alloc_unit_id()   # сервер выдаёт
	unit.owner_id = owner_id
	unit.position = pos
	units_container.add_child(unit)
	# Регистрация произойдёт в _ready() юнита

	# В мультиплеере: разослать всем клиентам
	if multiplayer.is_server():
		_spawn_unit_networked.rpc(unit.unit_id, owner_id, pos, scene.resource_path)


func create_unit(name: String, pos: Vector2) -> void:
	if creeps.has(name):
		var new_unit = creeps[name].instantiate()
		units_container.add_child(new_unit)
		new_unit.global_position = pos
				
		
func issue_move_command(target: Vector2):
	var units = selection.get_selected()
	# Только свои юниты!
	var my_id = multiplayer.get_unique_id()
	for u in units:
		if u.owner_id != my_id:
			continue
		# В мультиплеере здесь НЕ двигаем локально, а шлём RPC на сервер:
		_request_move.rpc_id(1, u.get_path(), target)
		

@rpc("authority", "reliable")
func _spawn_unit_networked(unit_id: int, owner_id: int, pos: Vector2, scene_path: String) -> void:
	# На клиенте: создать юнит с ТЕМ ЖЕ unit_id
	var scene: PackedScene = load(scene_path)
	var unit: Unit = scene.instantiate()
	unit.unit_id = unit_id
	unit.owner_id = owner_id
	unit.position = pos
	add_child(unit)

@rpc("any_peer", "reliable")
func _request_move(unit_path: NodePath, target: Vector2):
	if not multiplayer.is_server():
		return
	# Сервер проверяет, что юнит принадлежит отправителю
	var sender = multiplayer.get_remote_sender_id()
	var unit = get_node_or_null(unit_path) as Unit
	if unit and unit.owner_id == sender:
		unit.move_to(target)	
