class_name Carry
extends Object
## What the player keeps when the level changes.
##
## STATIC VARIABLES, NOT AN AUTOLOAD, and that is a deliberate choice about
## this project rather than a general preference. An autoload has to be
## declared in project.godot, which is editor-owned state: the editor holds its
## own copy and re-saves it, and entries added to that file from outside have
## already been silently dropped here once. GDScript statics live for the
## lifetime of the *process*, which is exactly as long as a playthrough, and
## change_scene_to_file does not touch them. Same durability, no shared file to
## lose the fight over.
##
## The rule for what belongs here: things the character is still carrying when
## the ground changes under them. The lens is the whole of it for now -- it is
## the one object the game is built around, and walking into the woods without
## it makes the next level unplayable rather than merely harder.
##
## NOT saved to disk. Quitting to the menu and starting again clears it, which
## is what reset() is for and why the menu calls it.

## The magnifying glass. The one piece of equipment that is granted once and
## carried forever, including across a level boundary.
static var has_magnifier := false


## Called when a new game starts. Without this, the second playthrough in a
## session begins with the lens already in hand and the whole of the house's
## first act -- finding it -- silently skipped.
static func reset() -> void:
	has_magnifier = false
