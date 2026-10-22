extends SceneTree
## Checks the input map: defaults, rebinding, the two devices staying
## independent, and the round trip through user://controls.cfg.
##
## The autoload is fetched by NODE PATH, not by its global name. A script run
## with --script is compiled before the autoloads are registered, so the
## identifier `Controls` does not exist yet at compile time even though the
## singleton is perfectly real by the first frame.

var _controls: Node

func _ok(label: String, cond: bool) -> void:
	print("CONTROLS %s  %s" % ["PASS" if cond else "FAIL", label])

func _process(_d: float) -> bool:
	_controls = root.get_node_or_null("Controls")
	if _controls == null:
		print("CONTROLS FAIL  the autoload is not in the tree")
		return true
	var c := _controls

	_ok("every action is registered",
		InputMap.has_action("Sprint") and InputMap.has_action("Slot_9")
			and InputMap.has_action("Journal_Next"))

	# The pad COLUMN shows the rebindable button, not the stick: the stick is
	# listed separately as a fixed row, because it is not up for negotiation.
	_ok("the pad column shows the d-pad, not the stick",
		c.binding_name("Move_Forward", true) == "D-pad Up")
	_ok("sprint is Shift on the keyboard",
		c.binding_name("Sprint", false) == "Shift")
	_ok("sprint is L3 on the pad", c.binding_name("Sprint", true) == "L3")
	_ok("glyph brackets the name", c.glyph("Interact") == "[E]")

	# Rebinding one device must leave the other alone.
	c.rebind("Interact", c.key_event(KEY_R))
	_ok("rebinding moves the key", c.binding_name("Interact", false) == "R")
	_ok("and leaves the pad button", c.binding_name("Interact", true) == "X")
	_ok("the map holds both", InputMap.action_get_events("Interact").size() == 2)

	# Escape is refused, or a player who binds it cannot leave the page.
	_ok("escape is not bindable", not c.is_bindable(c.key_event(KEY_ESCAPE)))
	_ok("a stick half is not bindable", not c.is_bindable(c.axis_event("1-")))

	# Round trip through the config file.
	c.save_overrides()
	c._install_defaults()
	_ok("defaults come back", c.binding_name("Interact", false) == "E")
	c.load_overrides()
	_ok("the override reloads from disk", c.binding_name("Interact", false) == "R")
	_ok("and is not a default any more", not c.is_default("Interact"))

	c.reset_action("Interact")
	_ok("one action can be put back", c.binding_name("Interact", false) == "E")
	c.reset_all()
	_ok("and so can all of them", c.is_default("Interact"))

	# Leave no config behind for the next run.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.CONFIG_PATH))
	return true
