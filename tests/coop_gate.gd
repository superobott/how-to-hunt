extends Node
## Test-only handshake: all guests must observe rewards before host teardown.
var received: Dictionary = {}
var confirmed := false

@rpc("any_peer", "call_remote", "reliable")
func ready_to_leave() -> void:
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		received[sender] = true
		confirm.rpc_id(sender)

@rpc("authority", "call_remote", "reliable")
func confirm() -> void:
	confirmed = true
