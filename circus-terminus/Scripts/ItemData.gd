class_name ItemData
extends Resource
## One inventory item. Create these as .tres files under Items/.
##
## Deliberately data-only: pickups, doors, the journal and the HUD all refer to
## items through this, so adding a new item never means touching their code.

## Stable identifier. Locked doors match on this, so renaming display_name is
## safe but changing id is not.
@export var id := ""

@export var display_name := "Item"

@export_multiline var description := ""

## Tint for the item's name on the HUD and for the glow on a dropped one.
## No longer paints the mesh: items have real models now, and repainting a
## brass key green to match its slot colour undid the whole point of modelling
## it. See `model`.
@export var color := Color(0.9, 0.85, 0.6)

@export_group("Model")
## The object itself, from Scenes/items/. Used three times over: as the thing
## lying on the floor, as the thing that spawns when you drop it, and as the
## live 3D icon in the journal. One scene, so a key can never look like one
## object in the world and a different one in your bag.
@export var model: PackedScene

## Metres from the journal camera to the model. A crowbar and a key differ by
## nearly ten times in size, and a single framing distance either loses the key
## in the middle of the page or crops the bar at both ends.
@export var icon_distance := 0.30

## Degrees the journal spins the model round Y from its resting pose, so each
## item is framed from whichever side actually reads.
@export var icon_yaw := -28.0
@export var icon_pitch := 26.0

## Vertical nudge for the icon framing, in metres, for items whose mass sits
## well above their origin (the fuel can) or right on it (a key).
@export var icon_lift := 0.0

@export_group("Carrying")
## Several of these share one journal slot with a count on it. Off for keys:
## two different keys are two different problems and must never merge.
@export var stackable := false

@export var max_stack := 9

## Equipment rather than cargo -- the lens. Granted permanently, never takes a
## slot, and the journal lists it on the equipment line instead of the grid.
@export var is_equipment := false
