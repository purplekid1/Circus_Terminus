class_name ConcealArea
extends Area3D
## Marks the space under a desk or bed as somewhere the player counts as
## hidden, as long as they are crouched.
##
## Crouching low enough to fit is a physics fact; being *hidden* is a game
## rule, and enemies need to be able to ask about it. Keeping that rule in its
## own volume means the two can disagree -- you can crouch in the open, and
## you can stand in a nook without it counting.

@export var requires_crouch := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_conceal"):
		body.enter_conceal(self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_conceal"):
		body.exit_conceal(self)
