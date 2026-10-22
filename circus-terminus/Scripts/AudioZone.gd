extends Area3D
## One acoustic space. Tells the Sound autoload when the player is inside it.
##
## Authored in Scenes/audio.tscn by tools/gen_audio.sh, and selectable in the
## editor like anything else -- the point of using volumes rather than testing
## the player's Y coordinate in code is that the house can move without anybody
## remembering to update a magic number.

## Which Sound.Zone this volume is. Exported as a plain int with a hint rather
## than the enum type, because the enum lives on the autoload and a scene that
## names an autoload's type will not open if the autoload is missing.
@export_enum("Outside:0", "House:1", "Cellar:2") var zone: int = 1

var _inside := false


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(body: Node3D) -> void:
	# The mask is the default physics layer, which almost everything is on, so
	# the group is what actually identifies the player.
	if _inside or not body.is_in_group("player"):
		return
	_inside = true
	Sound.enter(zone)


func _on_exited(body: Node3D) -> void:
	if not _inside or not body.is_in_group("player"):
		return
	_inside = false
	Sound.exit(zone)


## Leaving the scene while the player is still inside -- a scene change, or the
## level being freed by a test -- would otherwise leave the count standing and
## the next level would start in the cellar.
func _exit_tree() -> void:
	if _inside:
		_inside = false
		Sound.exit(zone)
