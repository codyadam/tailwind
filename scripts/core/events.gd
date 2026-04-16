extends Node

@warning_ignore("unused_signal")
signal after_server_player_joined(peer_id: int)

@warning_ignore("unused_signal")
signal after_server_player_left(peer_id: int)

@warning_ignore("unused_signal")
signal after_connected()

@warning_ignore("unused_signal")
signal after_disconnected()

@warning_ignore("unused_signal")
signal after_ability_switched(ability: Ability, player: Player)