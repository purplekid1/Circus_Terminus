extends Area3D
## Speaks a few lines the first time the player walks through.
##
## Used for the beats that have no object to click: arriving at the house,
## stepping into the dark basement, hearing the generator catch.

@export var lines: Array[String] = []

## Fire again on later entries. Off by default -- a line the player has
## already heard is noise, and this is the character thinking aloud, not a
## reminder system.
@export var repeatable := false

## Hold the lines back until something else has happened, e.g. only comment on
## the dark after the player has actually tried the light switch.
@export var enabled := true

var _spoken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not enabled or not body.has_method("say"):
		return
	if _spoken and not repeatable:
		return
	_spoken = true
	for line in lines:
		body.say(line)
