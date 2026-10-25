extends RefCounted
## Seedable spawn choices. Squared radius sampling distributes animals evenly by area.

const CATALOG_PATH := "res://data/gameplay.json"

var rng := RandomNumberGenerator.new()
var config: Dictionary = {}
var animals: Dictionary = {}


func _init(seed_value: int = 1, spawn_config: Dictionary = {}) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		config = parsed.get("spawn", {}).duplicate(true)
		animals = parsed.get("animals", {}).duplicate(true)
	config.merge(spawn_config, true)
	rng.seed = seed_value


func next_position(height: float = 0.8) -> Vector3:
	var inner := maxf(0.0, float(config.get("inner_radius", 44.0)))
	var outer := maxf(inner, float(config.get("outer_radius", 56.0)))
	var radius := sqrt(rng.randf_range(inner * inner, outer * outer))
	var angle := rng.randf_range(0.0, TAU)
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


func roll_rare(chance: float) -> bool:
	if not is_finite(chance) or chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return rng.randf() < chance


func choose_animal(eligible: Array[String] = []) -> String:
	var choices: Array[String] = []
	if eligible.is_empty():
		for id: String in animals:
			choices.append(id)
	else:
		for id in eligible:
			if animals.has(id):
				choices.append(id)
	choices.sort()
	if choices.is_empty():
		return ""
	return choices[rng.randi_range(0, choices.size() - 1)]


func next_spawn(eligible: Array[String] = []) -> Dictionary:
	var animal_id := choose_animal(eligible)
	if animal_id.is_empty():
		return {}
	return {"animal_id": animal_id, "position": next_position(),
		"rare": roll_rare(float(animals[animal_id]["rare_chance"]))}
