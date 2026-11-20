extends RefCounted
## Host-owned wallet and per-hunter equipment. Guest state never touches solo files.
const HuntState := preload("res://scripts/core/hunt_state.gd")
const MAX_HUNTERS := 4
var host: RefCounted
var hunters: Dictionary = {}
var retained: Dictionary = {}
var identities: Dictionary = {}

func _init(host_state: RefCounted) -> void:
	host = host_state
	hunters[1] = host

func add_hunter(peer: int, identity: String) -> bool:
	if peer <= 1 or hunters.has(peer) or hunters.size() >= MAX_HUNTERS or identity.is_empty() or identity in identities.values():
		return false
	var state: RefCounted = retained.get(identity, HuntState.new())
	state.coins = host.coins
	hunters[peer] = state
	identities[peer] = identity
	retained[identity] = state
	return true

func remove_hunter(peer: int) -> void:
	if peer != 1:
		hunters.erase(peer)
		identities.erase(peer)

func sync_wallet() -> void:
	for peer in hunters:
		if peer != 1:
			hunters[peer].coins = host.coins

func purchase(peer: int, item: String) -> bool:
	if not hunters.has(peer):
		return false
	var state: RefCounted = hunters[peer]
	state.coins = host.coins
	var bought: bool = state.buy_gear(item) if state.catalog.get("gear", {}).has(item) else state.buy_tool(item)
	if bought:
		host.coins = state.coins
		host.changed.emit()
		sync_wallet()
	return bought

func collect(peer: int, animal: String, rare: bool, trick: bool) -> int:
	if not hunters.has(peer):
		return 0
	var state: RefCounted = hunters[peer]
	state.coins = host.coins
	var amount: int = state.collect_coins(animal, rare, trick)
	host.coins = state.coins
	host.changed.emit()
	sync_wallet()
	return amount

func record_hunt(animal: String, rare: bool, trick: bool) -> void:
	for state in hunters.values():
		state.record_hunt(animal, rare, trick)

func defeat() -> void:
	host.defeat_penalty()
	sync_wallet()
