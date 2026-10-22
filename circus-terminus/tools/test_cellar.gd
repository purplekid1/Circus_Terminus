extends SceneTree
## Walks the cellar puzzle end to end: search in the dark, start the generator,
## search again, take the key, unlock the gate.

var _root: Node = null
var _wait := 20

func _initialize() -> void:
	var ps: PackedScene = load("res://demo_level.tscn")
	_root = ps.instantiate()
	root.add_child(_root)

func _ok(label: String, cond: bool) -> void:
	print("PUZZLE %s  %s" % ["PASS" if cond else "FAIL", label])

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false

	var m := _root.get_node("Mansion")
	var player := _root.get_node("Player")
	var inv: Inventory = player.inventory
	var gen := m.get_node("Generator")
	var gate := m.get_node("CellarGate")
	# Whichever spot is actually holding the key, rather than a hard-coded
	# one. This test used to name SearchCoal, and broke the moment the key
	# moved west -- which it had to, because the coal heap ended up behind
	# the gate the key is for. The chain is what matters here, not the
	# hiding place.
	var coal: Node = null
	for node in m.get_children():
		if node.get("contents") != null and node.contents.id == "cellar_key":
			coal = node
			break
	_ok("some search spot holds the cellar key", coal != null)
	if coal == null:
		return true
	print("PUZZLE ....  the key is in %s" % coal.name)
	var bench := m.get_node("SearchBench")

	_ok("gate starts locked", gate.locked)
	_ok("gate refuses without the key", not gate.available(player))
	_ok("the key's hiding place is dark before the generator", not coal.has_light())
	_ok("bench is dark before the generator", not bench.has_light())
	_ok("and reads as too dark to search", coal.describe(player) == coal.dark_prompt)

	coal.interact(player)
	_ok("searching in the dark yields nothing", not inv.carries("cellar_key"))
	_ok("and leaves the spot unsearched", not coal.is_searched)

	# Fuel the generator and pull it over, the way the player would.
	var fuel: ItemData = load("res://Items/fuel.tres")
	inv.add(fuel)
	inv.select(inv.slots.find(fuel))
	gen.interact(player)
	_ok("generator runs on the fuel", gen.running)
	_ok("the hiding place is lit once it runs", coal.has_light())

	coal.interact(player)
	_ok("searching it in the light yields the key", inv.carries("cellar_key"))
	_ok("and will not yield a second one", coal.is_searched and coal.contents == null)

	bench.interact(player)
	_ok("the bench holds nothing", bench.is_searched and not bench.contents)

	# Holding the wrong thing is not enough; the key has to be in hand.
	inv.select(0)
	var key_slot := -1
	for i in Inventory.SLOT_COUNT:
		if inv.slots[i] != null and inv.slots[i].id == "cellar_key":
			key_slot = i
	inv.select((key_slot + 1) % Inventory.SLOT_COUNT)
	_ok("gate still shut with the wrong slot held", not gate.available(player))

	inv.select(key_slot)
	_ok("gate accepts the key in hand", gate.available(player))
	gate.interact(player)
	_ok("gate unlocks", not gate.locked)
	return true
