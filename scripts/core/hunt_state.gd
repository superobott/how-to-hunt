extends RefCounted
## Gameplay rules only: a hunt awards XP once, collecting adds a sellable item.

signal changed

const CATALOG_PATH := "res://data/gameplay.json"
const SAVE_VERSION := 2
const MAX_SAVE_INTEGER := 9007199254740991 # Largest exactly representable JSON integer.

var catalog: Dictionary = {}
var coins: int = 0
var xp: int = 0
var hunts: int = 0
var tool_id: String = "knife"
var inventory: Array[Dictionary] = []
var owned_gear: Array[String] = []


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


func collect_coins(animal_id: String, rare: bool = false, trick_shot: bool = false) -> int:
	var info := animal(animal_id)
	if info.is_empty():
		return 0
	var paid := roundi(float(info["value"]) * _loot_multiplier(info, rare, trick_shot) * gear_effect("coins", 1.0))
	coins += paid
	changed.emit()
	return paid


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
	return buy_tool(str(tool().get("next", "")))


func buy_tool(id: String) -> bool:
	var upgrade: Dictionary = catalog.get("tools", {}).get(id, {})
	if upgrade.is_empty() or int(upgrade["price"]) <= int(tool()["price"]) or coins < int(upgrade["price"]):
		return false
	coins -= int(upgrade["price"])
	tool_id = id
	changed.emit()
	return true


func gear_effect(effect: String, fallback: float) -> float:
	for id in owned_gear:
		var item: Dictionary = catalog["gear"][id]
		if str(item["effect"]) == effect:
			return float(item["multiplier"])
	return fallback


func buy_gear(id: String) -> bool:
	var item: Dictionary = catalog.get("gear", {}).get(id, {})
	if item.is_empty() or id in owned_gear or coins < int(item["price"]):
		return false
	coins -= int(item["price"])
	owned_gear.append(id)
	changed.emit()
	return true


func defeat_penalty() -> int:
	var lost := int(coins * 0.10)
	coins -= lost
	changed.emit()
	return lost


func snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "coins": coins, "xp": xp, "hunts": hunts,
		"tool_id": tool_id, "inventory": inventory.duplicate(true), "owned_gear": owned_gear.duplicate()}


## Validate everything first so a malformed save cannot change any live state.
func restore(data: Dictionary) -> bool:
	for field in ["version", "coins", "xp", "hunts"]:
		if not _valid_integer(data.get(field)):
			return false
	if data.size() != (6 if int(data["version"]) == 1 else 7):
		return false
	if int(data["version"]) not in [1, SAVE_VERSION]:
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
	var saved_gear: Variant = data.get("owned_gear", [] if int(data["version"]) == 1 else null)
	if not saved_gear is Array:
		return false
	var validated_gear: Array[String] = []
	for id: Variant in saved_gear:
		if not id is String or not catalog.get("gear", {}).has(id) or id in validated_gear:
			return false
		validated_gear.append(id)
	owned_gear = validated_gear
	coins = int(data["coins"])
	xp = int(data["xp"])
	hunts = int(data["hunts"])
	tool_id = data["tool_id"]
	# Unplayed older saves adopt the new starter; established hunters retain their gear.
	if tool_id == "starter_bow" and coins == 0 and xp == 0 and hunts == 0 and owned_gear.is_empty():
		tool_id = "knife"
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
