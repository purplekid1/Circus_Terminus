class_name Settings
extends Object
## Everything the settings page can change, for as long as the process lives.
##
## STATIC VARIABLES, NOT AN AUTOLOAD, for the same reason Carry gives: an
## autoload has to be declared in project.godot, which is editor-owned state,
## and entries added to that file from outside have already been silently
## dropped here once. GDScript statics live for the lifetime of the PROCESS and
## change_scene_to_file does not touch them.
##
## THEY LIVE HERE RATHER THAN ON THE PLAYER BECAUSE THE MENU HAS NO PLAYER.
## The title screen is a car, a road and a UI layer; there is no character to
## hang a field of view on. Putting the values here is what lets the same
## settings page work in both places and lets a choice made before the game
## starts survive into it -- the player reads them on the way in rather than
## owning them.
##
## NOT saved to disk. Quitting the process loses them, which is the same deal
## the rest of the game's state gets until there is a save file.

## Look. Degrees are the camera's business; this is a plain multiplier.
static var look_sensitivity := 1.0
static var invert_look := false

## The camera's field of view, in degrees. 75 is Godot's default and what the
## player scene authored before this existed.
static var fov := 75.0

## Torch brightness. Seeded ONCE from whatever light the player scene carries
## -- see torch_seeded -- and owned here from then on.
static var torch_energy := 4.0
## False until a player has handed its scene-authored torch value over. Without
## it every level load would stamp the scene's brightness back over a value
## chosen on the title screen, and the setting would appear to forget itself
## exactly when the player crossed from the house to the woods.
static var torch_seeded := false

static var head_bob := true

## Sprint held down, or pressed once to latch. Stored the way the player reads
## it; the settings page offers the opposite phrasing because "hold to run" is
## what people call it.
static var sprint_toggle := false

## Subtitle size, as PlayerController.SubtitleSize. Plain int rather than the
## enum, because this script must not depend on the player -- the menu loads it
## without one.
static var subtitle_size := 1


## Back to defaults. Not called by anything yet: a new game keeps your
## settings, which is what everyone expects. It exists so that a "restore
## defaults" button has something to call, and so the list of defaults is in
## one place rather than repeated down the file.
static func reset() -> void:
	look_sensitivity = 1.0
	invert_look = false
	fov = 75.0
	torch_energy = 4.0
	torch_seeded = false
	head_bob = true
	sprint_toggle = false
	subtitle_size = 1
