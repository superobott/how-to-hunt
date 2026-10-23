extends RefCounted
## Gameplay rules only: a hunt awards XP once, collecting adds a sellable item.

signal changed

const CATALOG_PATH := "res://data/gameplay.json"
const SAVE_VERSION := 1
const MAX_SAVE_INTEGER := 9007199254740991 # Largest exactly representable JSON integer.

var catalog: Dictionary = {}
var coins: int = 0
var xp: int = 0
var hunts: int = 0
var tool_id: String = "starter_bow"
var inventory: Array[Dictionary] = []


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		catalog = parsed
	else:
		push_error("HuntState: gameplay catalog could not be loaded.")


func animal(id: String) -> Dictionary:
	return catalog.get("animals", {}).get(id, {})


func tool() -> Dictionary:
	return catalog.get("tools", {}).get(tool_id, {})


func next_tool() -> Dictionary:
	return catalog.get("tools", {}).get(str(tool().get("next", "")), {})


func capacity() -> int:
	return int(catalog.get("economy", {}).get("capacity", 8))


func level() -> int:
	var xp_per_level := maxi(1, int(catalog.get("progression", {}).get("xp_per_level", 100)))
	return 1 + int(xp / xp_per_level)


func record_hunt(animal_id: String, rare: bool = false, trick_shot: bool = false) -> void:
	var info := animal(animal_id)
	if info.is_empty():
		return
	xp += roundi(float(info["xp"]) * _loot_multiplier(info, rare, trick_shot))
	hunts += 1
	changed.emit()


func collect_loot(animal_id: String, rare: bool = false, trick_shot: bool = false) -> bool:
	if animal(animal_id).is_empty() or inventory.size() >= capacity():
		return false
	inventory.append({"animal_id": animal_id, "rare": rare, "trick_shot": trick_shot})
	changed.emit()
	return true


func bag_value() -> int:
	var total := 0
	for item in inventory:
		var info := animal(str(item["animal_id"]))
		total += roundi(float(info["value"]) * _loot_multiplier(info, item["rare"], item["trick_shot"]))
	return total


func sell_all() -> int:
	var paid := bag_value()
	if inventory.is_empty():
		return 0
	coins += paid
	inventory.clear()
	changed.emit()
	return paid


func buy_upgrade() -> bool:
	var upgrade := next_tool()
	if upgrade.is_empty() or coins < int(upgrade["price"]):
		return false
	coins -= int(upgrade["price"])
	tool_id = str(tool()["next"])
	changed.emit()
	return true


func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "coins": coins, "xp": xp, "hunts": hunts,
		"tool_id": tool_id, "inventory": inventory.duplicate(true)}


## Validate everything first so a malformed save cannot change any live state.
func restore(data: Dictionary) -> bool:
	if data.size() != 6:
		return false
	for field in ["version", "coins", "xp", "hunts"]:
		if not _valid_integer(data.get(field)):
			return false
	if int(data["version"]) != SAVE_VERSION:
		return false
	if not data.get("tool_id") is String or not catalog.get("tools", {}).has(data["tool_id"]):
		return false
	var items: Variant = data.get("inventory")
	if not items is Array or items.size() > capacity():
		return false
	var validated_inventory: Array[Dictionary] = []
	for item: Variant in items:
		if not item is Dictionary or item.size() != 3:
			return false
		if not item.get("animal_id") is String or animal(item["animal_id"]).is_empty():
			return false
		if not item.get("rare") is bool or not item.get("trick_shot") is bool:
			return false
		validated_inventory.append(item.duplicate(true))
	coins = int(data["coins"])
	xp = int(data["xp"])
	hunts = int(data["hunts"])
	tool_id = data["tool_id"]
	inventory = validated_inventory
	changed.emit()
	return true


func _loot_multiplier(info: Dictionary, rare: bool, trick_shot: bool) -> float:
	var multiplier := float(info["rare_multiplier"]) if rare else 1.0
	if trick_shot:
		multiplier *= float(catalog.get("economy", {}).get("trick_multiplier", 1.5))
	return multiplier


static func _valid_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number <= MAX_SAVE_INTEGER and floor(number) == number
