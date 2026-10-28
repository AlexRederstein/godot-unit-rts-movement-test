#host_game(port: int) -> void
#join_game(ip: String, port: int) -> void
#disconnect_from_game() -> void

# сигналы
signal player_joined(peer_id)
signal player_left(peer_id)
signal connection_failed()
