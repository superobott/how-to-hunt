extends RefCounted
## The playable area of the island: a disc around the origin with a cliff edge.
## Walking off the cliff means falling below `kill_height`, which respawns the player.
## `outer_radius` is a hard limit so nobody can wander into the void while falling.

var plateau_radius: float
var outer_radius: float
var kill_height: float
var spawn_point: Vector3


func _init(
	plateau_radius_: float = 60.0,
	outer_radius_: float = 90.0,
	kill_height_: float = -40.0,
	spawn_point_: Vector3 = Vector3(0.0, 1.5, 0.0)
) -> void:
	assert(plateau_radius_ > 0.0, "plateau_radius must be positive")
	assert(outer_radius_ >= plateau_radius_, "outer_radius must not be inside the plateau")
	plateau_radius = plateau_radius_
	outer_radius = outer_radius_
	kill_height = kill_height_
	spawn_point = spawn_point_


static func horizontal_distance(position: Vector3) -> float:
	return Vector2(position.x, position.z).length()


## True when the position is over the cliff edge (past the plateau) and not on solid ground yet.
func is_past_edge(position: Vector3) -> bool:
	return horizontal_distance(position) > plateau_radius


## True when the player has fallen far enough to be sent back to the spawn point.
func should_respawn(position: Vector3) -> bool:
	return position.y < kill_height


## Keeps the horizontal position inside `outer_radius`. Height is unchanged.
func clamp_to_outer(position: Vector3) -> Vector3:
	var flat := Vector2(position.x, position.z)
	if flat.length() <= outer_radius:
		return position
	flat = flat.limit_length(outer_radius)
	return Vector3(flat.x, position.y, flat.y)


func respawn_position() -> Vector3:
	return spawn_point
