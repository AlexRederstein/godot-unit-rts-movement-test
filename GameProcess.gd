extends Node2D


#@export var creep_scene: PackedScene
@onready var selection: SelectionManager = $SelectionManager
@onready var camera: Camera2D = $Camera2D
@onready var units_container: Node2D = $Units

var creeps :Dictionary[String, PackedScene] = {
	"creep_melee_radiant": preload("res://unit/creep_melee_radiant/creep_melee_radiant_scene.tscn"),
	"creep_melee_dire": preload("res://unit/creep_melee_dire/creep_melee_dire_scene.tscn")
}


func _ready() -> void:
	selection.selection_changed.connect(_on_selection_changed)

func _on_selection_changed(units: Array[Unit]):
	print("Выбрано юнитов: ", units.size())


	# В мультиплеере: разослать всем клиентам
	#if multiplayer.is_server():
		#_spawn_unit_networked.rpc(unit.unit_id, owner_id, pos, scene.resource_path)
				
		
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("move_click"):
		var target := get_global_mouse_position()
		issue_move_command(target)		
		
func issue_move_command(target: Vector2):
	var units = selection.get_selected()
	# Только свои юниты!
	var my_id = GameManager.get_current_player_id()
	for u in units:
		if u.owner_id != my_id:
			continue
			
		if not (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
			u.move_to(target)
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
