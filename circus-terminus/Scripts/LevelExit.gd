extends Area3D
## The end of a level: say a line, hold, fade, load the next one.
##
## Distinct from DemoEnd, which fades and stops. This one goes somewhere, and
## the difference matters: a fade that is followed by a load has to hold long
## enough for the line to be read AND for the screen to actually reach black
## before the new scene appears, or the player sees the next level pop in
## underneath the last word.
##
## Fires once. Re-triggering because the player drifted back across the
## threshold would stack two loads.

@export_file("*.tscn") var next_level := ""
## Spoken as the player crosses, before anything else happens.
@export var lines: PackedStringArray = []
## How long the line gets before the fade starts.
@export var hold := 2.0
@export var fade := 2.4
## Held on black before the load, so the fade finishes rather than being cut
## off by the scene change.
@export var settle := 0.5

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired or not body.is_in_group("player"):
		return
	_fired = true
	_run(body)


func _run(player: Node) -> void:
	# The controls go at once. Everything from here is on rails, and a player
	# who can still walk during a fade will walk back out of the trigger.
	if player.has_method("begin_focus"):
		player.begin_focus(self)

	for line: String in lines:
		if not line.is_empty() and player.has_method("say"):
			player.say(line)

	await _wait(hold)
	if player.has_method("fade_out"):
		player.fade_out(fade, "")
	await _wait(fade + settle)

	if next_level.is_empty() or not ResourceLoader.exists(next_level):
		push_warning("LevelExit: next_level is '%s', which does not exist. "
			% next_level + "Holding on black.")
		return
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file(next_level)


## The focus sink. PlayerController drops focus outright if the holder cannot
## take input, which would hand the controls back mid-fade.
func handle_focus_input(_event: InputEvent) -> void:
	pass


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
