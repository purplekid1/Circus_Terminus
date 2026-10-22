extends Node
## Autoload. The one place that knows what every control is called, what it is
## bound to, and what to print on screen when the game wants to name a key.
##
## It exists because the bindings were in three places and none of them agreed.
## project.godot held some, PlayerController._ensure_actions() held the rest --
## registered from code precisely because the editor rewrites project.godot
## from its own in-memory copy and has dropped entries before -- and the HUD
## had "[E]" and "[Tab]" typed into string literals, so rebinding Interact
## still told the player to press E.
##
## Now: DEFAULTS below is the whole input map. _ready() writes it into
## InputMap, overrides from user://controls.cfg are applied on top, and
## anything that wants to print a control asks glyph().
##
## PAD AND KEYBOARD AT THE SAME TIME. Every action carries both, and neither
## has to be chosen in a menu -- the last device to send an event wins for the
## purposes of what the HUD prints, and both keep working regardless. A
## controller that only works after you find the setting is a controller that
## does not work.

## Emitted when anything is rebound, so open menus can redraw themselves.
signal bindings_changed
## Emitted when the player switches between keyboard and pad, so the HUD can
## swap [E] for (A) without waiting for the next prompt change.
signal device_changed(using_pad: bool)

const CONFIG_PATH := "user://controls.cfg"

## Deadzone applied to every stick axis binding. 0.2 was the value in
## project.godot and it is right for the cheap pads; the look stick gets its
## own, larger one in LOOK_DEADZONE because a drifting look is far more
## noticeable than a drifting walk.
const DEADZONE := 0.22
const LOOK_DEADZONE := 0.18

## Right stick, in radians per second at full deflection.
const PAD_LOOK_SPEED := 2.9
## Extra curve on the look stick. 1.0 is linear; higher is finer near centre,
## which is the only way a stick gets anywhere near a mouse for aiming at a
## door handle across a room.
const PAD_LOOK_CURVE := 2.4

## One row per rebindable control:
##   action, the label the menu shows, the section it is filed under,
##   the default keys, the default pad buttons, the default pad axes.
##
## Axes are written as "<axis>+" / "<axis>-" -- axis index and which half.
##
## MOVEMENT IS NOT REBINDABLE PER DIRECTION on the pad. Move_* keep their WASD
## keys and their stick axes, and the menu shows the stick as one row, because
## letting someone bind "walk forward" to the right stick's left half produces
## a control scheme that cannot be described, let alone played.
const BINDINGS := [
	# action            label                 section      keys                          buttons                      axes
	["Move_Forward",    "Walk forward",       "Movement",  [KEY_W, KEY_UP],              [JOY_BUTTON_DPAD_UP],        ["1-"]],
	["Move_Backward",   "Walk back",          "Movement",  [KEY_S, KEY_DOWN],            [JOY_BUTTON_DPAD_DOWN],      ["1+"]],
	["Move_Left",       "Step left",          "Movement",  [KEY_A, KEY_LEFT],            [JOY_BUTTON_DPAD_LEFT],      ["0-"]],
	["Move_Right",      "Step right",         "Movement",  [KEY_D, KEY_RIGHT],           [JOY_BUTTON_DPAD_RIGHT],     ["0+"]],
	["Sprint",          "Run",                "Movement",  [KEY_SHIFT],                  [JOY_BUTTON_LEFT_STICK],     []],
	["Crouch",          "Crouch",             "Movement",  [KEY_CTRL, KEY_C],            [JOY_BUTTON_B],              []],
	["Jump",            "Jump",               "Movement",  [KEY_SPACE],                  [JOY_BUTTON_A],              []],

	["Interact",        "Use / pick up",      "Hands",     [KEY_E],                      [JOY_BUTTON_X],              []],
	["Flashlight",      "Torch",              "Hands",     [KEY_F],                      [JOY_BUTTON_Y],              []],
	["Open_Magnify",    "Raise the glass",    "Hands",     [KEY_Q],                      [],                          ["4+"]],
	["Drop",            "Put down",           "Hands",     [KEY_G],                      [JOY_BUTTON_LEFT_SHOULDER],  []],

	["Journal",         "Open the book",      "Book",      [KEY_TAB],                    [JOY_BUTTON_BACK],           []],
	["Pause",           "Close / back",       "Book",      [KEY_ESCAPE],                 [JOY_BUTTON_START],          []],

	# Stepping out of a set piece -- the safe's dials, and anything else that
	# takes the controls off the player. Its OWN action rather than borrowing
	# Pause, because Pause also opens the book: one key doing both meant the
	# safe could not be left without also deciding whether the book should
	# open, and the book won.
	#
	# B on a pad is deliberately the same button as Crouch. While a set piece
	# holds focus the player cannot crouch anyway, and B is where every hand
	# reaches for "back". The keybinds page will list it twice; that is honest.
	["Back",            "Step back / leave",  "Book",      [KEY_X, KEY_BACKSPACE],       [JOY_BUTTON_B],              []],
	["Journal_Prev",    "Previous section",   "Book",      [KEY_Q],                      [JOY_BUTTON_LEFT_SHOULDER],  []],
	["Journal_Next",    "Next section",       "Book",      [KEY_E],                      [JOY_BUTTON_RIGHT_SHOULDER], []],
	["Skip",            "Skip the cutscene",  "Book",      [KEY_SPACE],                  [JOY_BUTTON_A],              []],
]

## The inventory slots. Nine near-identical rows would bury the fifteen
## controls that matter, so they are registered but kept out of the menu.
const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

## Sections, in the order the menu lists them.
const SECTIONS := ["Movement", "Hands", "Book"]

## The right stick, named so the menu can show it and the player can see it is
## spoken for. Not rebindable: see the note on movement above.
const LOOK_AXES := {"look_x": 2, "look_y": 3}

var using_pad := false

## action -> Array[InputEvent]. Written on every rebind and saved from here, so
## what is on disk is always what is in the map.
var _overridden: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_defaults()
	load_overrides()


# ------------------------------------------------------------------ defaults

func _install_defaults() -> void:
	for row in BINDINGS:
		_reset_action(row[0], row[3], row[4], row[5])
	for index in SLOT_KEYS.size():
		_reset_action("Slot_%d" % (index + 1), [SLOT_KEYS[index]], [], [])


## Clears an action and writes its defaults. add_action() with a fixed deadzone
## rather than trusting whatever project.godot had: a stick bound through an
## action whose deadzone is 0 reads every frame of controller drift as a step.
func _reset_action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	else:
		InputMap.action_set_deadzone(action, DEADZONE)
		InputMap.action_erase_events(action)

	for key in keys:
		InputMap.action_add_event(action, key_event(key))
	for button in buttons:
		InputMap.action_add_event(action, button_event(button))
	for axis in axes:
		InputMap.action_add_event(action, axis_event(axis))


## The int parameters are deliberate: these are called with values off the
## BINDINGS table and out of the config file, where a keycode is a plain
## number. The cast happens here, once, at the only place that knows which
## enum the number is supposed to belong to.
static func key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	# Physical, so WASD stays under the same fingers on an AZERTY keyboard.
	event.physical_keycode = keycode as Key
	return event


static func button_event(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	# -1: any pad. Binding to device 0 means the game stops responding when a
	# controller is unplugged and plugged back into a different port.
	event.device = -1
	return event


## "<index><sign>", e.g. "1-" for the left stick pushed up.
static func axis_event(spec: String) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = int(spec.substr(0, spec.length() - 1)) as JoyAxis
	event.axis_value = -1.0 if spec.ends_with("-") else 1.0
	event.device = -1
	return event


# ----------------------------------------------------------------- rebinding

## Escape, however it arrived. BOTH fields have to be tested: an event from
## the OS carries a keycode, and the ones this file builds carry only a
## physical_keycode -- so a check on one of them alone passes Escape straight
## through half the time, which is how you end up with Escape bound to crouch
## and no way out of the page that did it.
static func is_escape(event: InputEventKey) -> bool:
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE


## Whether an event is one this menu is willing to bind. Mouse motion and
## stick deflection are excluded: the first because it is not a button, the
## second because binding a stick half to one action is how you end up with a
## character who walks forward whenever they look up.
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return not is_escape(event as InputEventKey)
	if event is InputEventJoypadButton:
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT
	return false


## Replaces whichever half of an action's bindings the new event belongs to --
## a pad button replaces the pad button, a key replaces the keys -- and leaves
## the other half alone. Rebinding Interact to [R] on the keyboard must not
## silently unbind it from the controller.
func rebind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action) or not is_bindable(event):
		return

	var pad := event is InputEventJoypadButton
	var kept: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		var existing_pad := (
			existing is InputEventJoypadButton or existing is InputEventJoypadMotion
		)
		# Axes always survive: they are the stick, and the stick is not up for
		# negotiation.
		if existing is InputEventJoypadMotion or existing_pad != pad:
			kept.append(existing)

	kept.append(_normalise(event))
	InputMap.action_erase_events(action)
	for e in kept:
		InputMap.action_add_event(action, e)
	_overridden[action] = kept
	save_overrides()
	bindings_changed.emit()


## Strips modifiers, echo and the physical device off a captured event, so what
## goes in the map is the plain key or button and nothing about the moment it
## was pressed.
func _normalise(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		return key_event((event as InputEventKey).physical_keycode)
	if event is InputEventJoypadButton:
		return button_event((event as InputEventJoypadButton).button_index)
	return event.duplicate()


func reset_action(action: String) -> void:
	for row in BINDINGS:
		if row[0] == action:
			_reset_action(action, row[3], row[4], row[5])
			_overridden.erase(action)
			save_overrides()
			bindings_changed.emit()
			return


func reset_all() -> void:
	_overridden.clear()
	_install_defaults()
	save_overrides()
	bindings_changed.emit()


func is_default(action: String) -> bool:
	return not _overridden.has(action)


# ----------------------------------------------------------------- the disk

## Saved as a flat list of tokens per action -- "k:69", "b:2" -- rather than by
## serialising InputEvent, because a stored resource from one engine version is
## a way to make the controls stop working after an update.
func save_overrides() -> void:
	var config := ConfigFile.new()
	for action in _overridden:
		var tokens := PackedStringArray()
		for event in _overridden[action]:
			var token := _token(event)
			if not token.is_empty():
				tokens.append(token)
		config.set_value("bindings", action, tokens)
	config.save(CONFIG_PATH)


func load_overrides() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for action in config.get_section_keys("bindings"):
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = []
		for token in config.get_value("bindings", action, PackedStringArray()):
			var event := _from_token(token)
			if event != null:
				events.append(event)
		if events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event in events:
			InputMap.action_add_event(action, event)
		_overridden[action] = events
	bindings_changed.emit()


func _token(event: InputEvent) -> String:
	if event is InputEventKey:
		return "k:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventJoypadButton:
		return "b:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		return "a:%d%s" % [m.axis, "-" if m.axis_value < 0.0 else "+"]
	if event is InputEventMouseButton:
		return "m:%d" % (event as InputEventMouseButton).button_index
	return ""


func _from_token(token: String) -> InputEvent:
	var parts := token.split(":")
	if parts.size() != 2:
		return null
	match parts[0]:
		"k": return key_event(int(parts[1]))
		"b": return button_event(int(parts[1]))
		"a": return axis_event(parts[1])
		"m":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(parts[1]) as MouseButton
			return mb
	return null


# -------------------------------------------------------------------- naming

## What to print for an action, in brackets, ready to drop into a sentence:
## "[E]  Open the front door". Follows whichever device the player last
## touched, so a pad user is never told to press Tab.
func glyph(action: String) -> String:
	# `bound`, not `name`: a local called name shadows Node.name.
	var bound := binding_name(action, using_pad)
	if bound.is_empty():
		bound = binding_name(action, not using_pad)
	return "[%s]" % bound if not bound.is_empty() else ""


## The bare name of an action's binding on one device, with no brackets.
func binding_name(action: String, pad: bool) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if pad and event is InputEventJoypadButton:
			return pad_button_name((event as InputEventJoypadButton).button_index)
		if pad and event is InputEventJoypadMotion:
			return pad_axis_name(event as InputEventJoypadMotion)
		if not pad and event is InputEventKey:
			return key_name((event as InputEventKey).physical_keycode)
		if not pad and event is InputEventMouseButton:
			return "Mouse %d" % (event as InputEventMouseButton).button_index
	return ""


static func key_name(keycode: int) -> String:
	match keycode:
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_SPACE: return "Space"
		KEY_TAB: return "Tab"
		KEY_ESCAPE: return "Esc"
		KEY_UP: return "Up"
		KEY_DOWN: return "Down"
		KEY_LEFT: return "Left"
		KEY_RIGHT: return "Right"
	var text := OS.get_keycode_string(keycode)
	return text if not text.is_empty() else "key %d" % keycode


## Xbox letters. Not because the game assumes an Xbox pad, but because every
## pad's face buttons come back as these indices and "A" is the one everybody
## can find -- "button 0" is not a thing anyone has ever looked for.
static func pad_button_name(index: int) -> String:
	match index:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_BACK: return "View"
		JOY_BUTTON_START: return "Menu"
		JOY_BUTTON_DPAD_UP: return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad Right"
	return "Pad %d" % index


static func pad_axis_name(event: InputEventJoypadMotion) -> String:
	var up := event.axis_value < 0.0
	match event.axis:
		JOY_AXIS_LEFT_X: return "Stick Left" if up else "Stick Right"
		JOY_AXIS_LEFT_Y: return "Stick Up" if up else "Stick Down"
		JOY_AXIS_RIGHT_X: return "R-Stick Left" if up else "R-Stick Right"
		JOY_AXIS_RIGHT_Y: return "R-Stick Up" if up else "R-Stick Down"
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "Axis %d" % event.axis


# ------------------------------------------------------------- which device

## Called from _input so it sees everything, including events the game has
## already handled. Only a deliberate input flips the state: a stick resting
## off-centre reports motion forever, and without the threshold a pad on the
## desk would hold the HUD in controller mode while somebody typed.
func _input(event: InputEvent) -> void:
	var pad := false
	if event is InputEventJoypadButton:
		pad = (event as InputEventJoypadButton).pressed
	elif event is InputEventJoypadMotion:
		pad = absf((event as InputEventJoypadMotion).axis_value) > 0.5
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		pad = false
	else:
		return

	if pad == using_pad:
		return
	# A key or a click switches back immediately; stick drift does not, and the
	# branch above has already filtered that out.
	using_pad = pad
	device_changed.emit(using_pad)


# --------------------------------------------------------------- pad reading

## Right stick as a look delta in radians, deadzoned and curved. Returned
## rather than applied, so the caller keeps ownership of its own clamping and
## its own invert setting.
func pad_look(delta: float) -> Vector2:
	var raw := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	var length := raw.length()
	if length < LOOK_DEADZONE:
		return Vector2.ZERO
	# Rescale from the edge of the deadzone, not from zero, or the stick jumps
	# to a fifth of full speed the instant it leaves the dead area.
	var scaled: float = pow((length - LOOK_DEADZONE) / (1.0 - LOOK_DEADZONE), PAD_LOOK_CURVE)
	return raw.normalized() * scaled * PAD_LOOK_SPEED * delta
