extends SceneTree
## Boots the level, opens the book and walks every tab, so a page that only
## builds when it is first turned to cannot break unnoticed.

var _root: Node = null
var _wait := 20
var _tab := 0

func _initialize() -> void:
	var ps: PackedScene = load("res://demo_level.tscn")
	_root = ps.instantiate()
	root.add_child(_root)

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var journal = _root.get_node("Player/Journal")
	if _tab == 0:
		journal.set_open(true)
	if _tab >= journal.TAB_NAMES.size():
		print("JOURNAL PASS  every page built")
		return true
	journal._select_tab(_tab)
	print("JOURNAL PASS  the %s page builds" % journal.TAB_NAMES[_tab])
	_tab += 1
	return false
