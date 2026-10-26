extends Node

var local_peer_id: int = 0
# Ключ — peer_id игрока, значение — словарь с данными игрока
var player_data: Dictionary = {}
var game_phase: String = "lobby"
var units_by_id: Dictionary = {}  # unit_id -> Unit

var _next_unit_id: int = 1

func alloc_unit_id() -> int:
	var id := _next_unit_id
	_next_unit_id += 1
	return id

func register_unit(unit: Unit) -> void:
	units_by_id[unit.unit_id] = unit

func unregister_unit(unit: Unit) -> void:
	units_by_id.erase(unit.unit_id)

func get_unit(unit_id: int) -> Unit:
	return units_by_id.get(unit_id)


func get_current_player_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1   # оффлайн-заглушка
	return multiplayer.get_unique_id()

func get_faction(peer_id: int) -> String:
	var data: Dictionary = player_data.get(peer_id, {})
	return data.get("faction", "")

func set_faction(peer_id: int, faction: String) -> void:
	if not player_data.has(peer_id):
		player_data[peer_id] = {}
	player_data[peer_id]["faction"] = faction
