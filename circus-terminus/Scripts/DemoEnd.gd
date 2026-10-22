extends Area3D
## Closes the demo. Put this just past the study door, inside the dark room.
##
## Fires once and then disables itself: re-triggering a fade because the
## player drifted back across the threshold would look like a bug.

@export var fade_seconds := 2.5
@export var closing_text := "END OF DEMO"

## Kill the player's torch as they cross, so the room is genuinely black
## rather than black-with-a-flashlight-cone.
@export var douse_flashlight := true

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired or not body.has_method("fade_out"):
		return
	_fired = true

	if douse_flashlight and body.has_method("set_torch"):
		body.set_torch(false)

	body.fade_out(fade_seconds, closing_text)
