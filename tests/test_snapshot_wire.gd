extends "res://tests/case_base.gd"
const Wire := preload("res://scripts/core/snapshot_wire.gd")
const Pose := preload("res://scripts/core/network_pose.gd")

func fixture() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42115
	var entities: Array = []
	for index in 42:
		entities.append({"id": index, "kind": "animal", "species": "rabbit", "rare": false,
			"position": Vector3(rng.randf_range(-100, 100), rng.randf_range(0, 24), rng.randf_range(-100, 100)),
			"rotation": Vector3(0, rng.randf_range(-PI, PI), 0), "health": 25.0, "windup": 0.0})
	var players: Dictionary = {}
	for index in 4:
		players[index + 1] = {"position": Vector3(index, 24, 0), "yaw": 0.0, "pitch": 0.0, "health": 100.0, "stamina": 100.0}
	return {"entities": entities, "players": players, "state": preload("res://scripts/core/hunt_state.gd").new().snapshot()}

func test_full_population_roundtrips_reordered_bounded_packets() -> void:
	var snapshot := fixture()
	var chunks := Wire.encode(snapshot)
	assert_true(chunks.size() > 1, "fixture must exercise multipart delivery")
	var receiver := Wire.new()
	var decoded: Dictionary = {}
	var bytes := 0
	for index in range(chunks.size() - 1, -1, -1):
		assert_true(chunks[index].size() <= 1000)
		bytes += chunks[index].size()
		decoded = receiver.accept(1, index, chunks.size(), chunks[index])
		if index > 0:
			assert_true(decoded.is_empty(), "no partial world updates")
	assert_eq(decoded, snapshot)
	assert_true(receiver.accept(1, 0, chunks.size(), chunks[0]).is_empty(), "completed snapshot cannot replay")
	print("Snapshot fixture: seed 42115, 42 animals, 4 hunters, raw %d bytes, packed %d bytes, %d packets" % [var_to_bytes(snapshot).size(), bytes, chunks.size()])

func test_missing_packet_does_not_block_new_snapshot() -> void:
	var chunks := Wire.encode(fixture())
	var receiver := Wire.new()
	assert_true(receiver.accept(1, 0, chunks.size(), chunks[0]).is_empty())
	assert_true(receiver.accept(1, 0, chunks.size(), chunks[0]).is_empty(), "duplicate is ignored")
	var decoded: Dictionary = {}
	for index in chunks.size():
		decoded = receiver.accept(2, index, chunks.size(), chunks[index])
	assert_false(decoded.is_empty())
	assert_true(receiver.accept(1, 1, chunks.size(), chunks[1]).is_empty(), "late packet cannot roll back state")

func test_packet_metadata_and_memory_are_bounded() -> void:
	var receiver := Wire.new()
	assert_true(receiver.accept(1, 0, 65, PackedByteArray([1])).is_empty())
	assert_true(receiver.accept(1, -1, 1, PackedByteArray([1])).is_empty())
	assert_true(receiver.accept(1, 1, 1, PackedByteArray([1])).is_empty())
	var oversized := PackedByteArray()
	oversized.resize(1001)
	assert_true(receiver.accept(1, 0, 1, oversized).is_empty())
	assert_true(receiver.parts.is_empty())

func test_pose_interpolates_without_overshoot_and_snaps_teleports() -> void:
	var pose := Pose.new()
	pose.push(Vector3.ZERO, Vector3(0, deg_to_rad(179), 0))
	pose.push(Vector3(2, 0, 0), Vector3(0, deg_to_rad(-179), 0))
	pose.step(0.05)
	assert_vec3_near(pose.position, Vector3(1, 0, 0), "", 0.001)
	assert_near(absf(pose.rotation.y), PI, "", 0.001)
	pose.step(1.0)
	assert_vec3_near(pose.position, Vector3(2, 0, 0), "", 0.001)
	pose.push(Vector3(50, 24, 0), Vector3.ZERO)
	assert_vec3_near(pose.position, Vector3(50, 24, 0), "", 0.001)
