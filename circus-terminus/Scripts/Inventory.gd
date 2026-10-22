class_name Inventory
extends Node
## A 3x3 grid of carried items, plus a separate equipment list.
##
## This was three fixed slots on a hotbar. It is a grid now because the journal
## is the inventory screen, and a hotbar wide enough to hold everything the
## house contains would have covered a third of the viewport in a game whose
## whole point is peering into dark corners.
##
## Two things survive from the old design and both are deliberate:
##
## - There is still exactly one SELECTED slot, and locked doors still test that
##   slot rather than searching the whole bag. Holding up the right key has to
##   be a decision the player makes.
## - The grid is small and it fills up. Refusing a pickup is a real outcome, so
##   `rejected` is still a signal the HUD explains rather than a silent no-op.
##
## Equipment -- currently just the lens -- is kept out of the grid entirely.
## It is granted once and carried forever, and letting it sit on a slot meant
## the reward for finding it was one less place to put a key.

signal changed
signal selection_changed(index: int)
## Emitted when a pickup could not be stored. The HUD uses this to explain why.
signal rejected(item: ItemData)
## Emitted when a piece of equipment is granted, so the HUD can announce it.
signal equipped(item: ItemData)

const COLS := 3
const ROWS := 3
const SLOT_COUNT := COLS * ROWS

var slots: Array[ItemData] = []
var counts: PackedInt32Array = PackedInt32Array()
var equipment: Array[ItemData] = []
var selected := 0


func _init() -> void:
	slots.resize(SLOT_COUNT)
	counts.resize(SLOT_COUNT)


# ------------------------------------------------------------------ storing

## Returns false when there was nowhere to put it, having emitted `rejected`.
## Callers must honour that: a pickup that frees itself regardless drops the
## item into nothing and the player never gets it back.
func add(item: ItemData) -> bool:
	if item == null:
		return false

	if item.is_equipment:
		return _equip(item)

	# Top up an existing stack before opening a new slot, or a shelf of four
	# batteries eats four slots.
	if item.stackable:
		for index in SLOT_COUNT:
			if slots[index] == item and counts[index] < item.max_stack:
				counts[index] += 1
				changed.emit()
				return true

	# Prefer the slot the player has selected, so picking something up while an
	# empty slot is held puts it where they are already looking.
	if slots[selected] == null:
		_put(selected, item)
		return true

	for index in SLOT_COUNT:
		if slots[index] == null:
			_put(index, item)
			return true

	rejected.emit(item)
	return false


func _put(index: int, item: ItemData) -> void:
	slots[index] = item
	counts[index] = 1
	changed.emit()


func _equip(item: ItemData) -> bool:
	for held in equipment:
		if held.id == item.id:
			return true
	equipment.append(item)
	equipped.emit(item)
	changed.emit()
	return true


func has_equipment(item_id: String) -> bool:
	for held in equipment:
		if held.id == item_id:
			return true
	return false


# ---------------------------------------------------------------- selecting

func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or index == selected:
		return
	selected = index
	selection_changed.emit(selected)


## Moves the selection by one cell, wrapping at the edges of the grid rather
## than off the end of the array -- pressing right on the last column should
## come back to the first, not jump down a row.
func step(dx: int, dy: int) -> void:
	var col := wrapi(selected % COLS + dx, 0, COLS)
	# Integer division on purpose: a flat slot index divided by the row width
	# IS the row. `selected` is never negative -- select() refuses an index
	# outside the grid -- so truncating and flooring are the same thing here.
	@warning_ignore("integer_division")
	var row := wrapi(selected / COLS + dy, 0, ROWS)
	select(row * COLS + col)


func cycle(amount: int) -> void:
	select(wrapi(selected + amount, 0, SLOT_COUNT))


func get_selected() -> ItemData:
	return slots[selected]


func count_at(index: int) -> int:
	return counts[index] if slots[index] != null else 0


## True when the given item id is in the *selected* slot specifically. Locked
## doors use this rather than a whole-inventory search, so the player has to
## actually hold up the right thing.
func selected_is(item_id: String) -> bool:
	var item := get_selected()
	return item != null and item.id == item_id


func carries(item_id: String) -> bool:
	for item in slots:
		if item != null and item.id == item_id:
			return true
	return false


func is_full() -> bool:
	for item in slots:
		if item == null:
			return false
	return true


# ------------------------------------------------------------------ removing

## Takes ONE off the selected stack and returns it, or null if the slot is
## empty. Used by consume-on-use doors and by dropping.
func take_selected() -> ItemData:
	return take_at(selected)


func take_at(index: int) -> ItemData:
	if index < 0 or index >= SLOT_COUNT:
		return null
	var item := slots[index]
	if item == null:
		return null
	counts[index] -= 1
	if counts[index] <= 0:
		slots[index] = null
		counts[index] = 0
	changed.emit()
	return item


## Kept for callers written against the old three-slot inventory.
func drop_selected() -> ItemData:
	return take_selected()


## Swaps two cells. The journal calls this so the player can tidy the grid;
## a swap rather than an insert, because shuffling everything along would move
## items out from under the number keys the player just learned.
func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= SLOT_COUNT or b >= SLOT_COUNT:
		return
	var item := slots[a]
	var count := counts[a]
	slots[a] = slots[b]
	counts[a] = counts[b]
	slots[b] = item
	counts[b] = count
	changed.emit()
