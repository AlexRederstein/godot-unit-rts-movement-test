extends Node

enum GamePhase {
	LOBBY,
	PLAYING,
	PAUSED,
	ENDED
}
var local_peer_id: int = 0
# Ключ — peer_id игрока, значение — словарь с данными игрока
var player_data: Dictionary = {}
var game_phase: GamePhase = GamePhase.LOBBY
var units_by_id: Dictionary = {}  # unit_id -> Unit

var _next_unit_id: int = 1

# Получить id игрока
func get_current_player_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1   # оффлайн-заглушка
	return multiplayer.get_unique_id()

func get_faction(peer_id: int) -> String:
	var data: Dictionary = player_data.get(peer_id, {})
	return data.get("faction", "")


func register_unit(unit: Unit) -> void:
	units_by_id[unit.unit_id] = unit

func unregister_unit(unit: Unit) -> void:
	units_by_id.erase(unit.unit_id)


# найти юнита по id (для RPC)
func get_unit(unit_id: int) -> Unit:
	return units_by_id.get(unit_id)
	
	
func alloc_unit_id() -> int:
	var id := _next_unit_id
	_next_unit_id += 1
	return id
