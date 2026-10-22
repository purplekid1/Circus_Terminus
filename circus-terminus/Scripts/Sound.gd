extends Node
## Where the player is, acoustically, and which bus is which.
##
## An autoload because two unrelated things need the same answer: the ambience
## bed, which lives in the level, and the footstep player, which lives on the
## player. Passing it between them through the scene tree means either the
## player has to know about the level's audio node or the level has to reach
## into the player, and both break the moment one of them is instanced on its
## own in a test.
##
## It owns no sound of its own. It is a fact, plus a signal when the fact
## changes.

signal zone_changed(zone: int)

enum Zone { OUTSIDE, HOUSE, CELLAR }

## The name each zone puts in front of the footstep files, and the ambience
## treatment that goes with it. Kept together because they describe one place.
##
## cutoff/wet/db are what the Ambience bus is driven to. Outdoors is open and
## dry; the house is the same weather heard through a wall, which is a low-pass
## and a drop in level, not a different recording; the cellar is that again,
## harder, with the room's own reverb on top.
## `db` is 0 for every zone now and the cutoffs are back to textbook values.
## They were once 7000/3800 with trims of +20 and +19, which looked mad and was:
## the Ambience bus low-pass had `resonance = 0`, which over-damps it and costs
## 27 dB of insertion loss even wide open. Every number here had been bent to
## compensate for that one mistake. The filter is fixed in the bus layout; the
## per-bed levels live in Ambience.gd where they belong.
const ZONES := {
	Zone.OUTSIDE: {
		"steps": "out", "cutoff": 20500.0, "wet": 0.0, "db": 0.0, "room": 0.65,
	},
	Zone.HOUSE: {
		"steps": "house", "cutoff": 2600.0, "wet": 0.22, "db": 0.0, "room": 0.70,
	},
	Zone.CELLAR: {
		"steps": "cellar", "cutoff": 1100.0, "wet": 0.38, "db": 0.0, "room": 0.85,
	},
}

## Named rather than indexed. Bus indices shift the moment anybody inserts a bus
## in the editor's Audio panel, and a wrong index is silent rather than loud --
## the sound simply goes somewhere else and nobody notices for a week.
const BUSES := ["Music", "Ambience", "Interior", "Steps", "Sfx"]

var zone: int = Zone.OUTSIDE:
	set(value):
		if value == zone:
			return
		zone = value
		zone_changed.emit(zone)

## Every zone volume the player is currently standing in. The player is in
## exactly one zone acoustically, but they can be inside two boxes at once for
## a frame on a boundary, and a naive enter/exit pair would leave the zone set
## to whichever handler happened to run last.
var _inside: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _name: String in BUSES:
		if AudioServer.get_bus_index(_name) < 0:
			push_warning("Sound: no '%s' bus -- check default_bus_layout.tres. "
				% _name + "Sounds on it will fall back to Master.")


## Returns the bus name if it exists, or Master if it does not, so a clobbered
## bus layout makes the game loud rather than silent.
static func bus(_name: String) -> String:
	return _name if AudioServer.get_bus_index(_name) >= 0 else "Master"


func enter(z: int) -> void:
	_inside.append(z)
	_settle()


func exit(z: int) -> void:
	# erase() removes one occurrence, which is what is wanted: two overlapping
	# House volumes should need two exits.
	_inside.erase(z)
	_settle()


## The innermost zone wins. The enum is ordered outside-inward, so that is
## simply the largest value -- being in the House box and the Cellar box at the
## same time means you are on the cellar stairs, and the cellar is the answer.
func _settle() -> void:
	var best : Variant = Zone.OUTSIDE
	for z in _inside:
		best = maxi(best, z)
	zone = best


func settings() -> Dictionary:
	return ZONES[zone]


## For tests and for the intro, which starts the player outdoors in a car.
func reset() -> void:
	_inside.clear()
	zone = Zone.OUTSIDE


# ------------------------------------------------------------ sound effects
# One-shots, on the Sfx bus. Spawned and freed rather than pooled: these are
# rare compared with footsteps, and a pool that is one voice too small drops
# the sound you most wanted to hear.

const SFX_DIR := "res://Audio/sfx/"

## Cached on first use. Loading a wav on the frame a door opens is a stutter,
## and the same handful of files are used all game.
var _sfx: Dictionary = {}

## A little randomness on every one-shot, so a door used four times does not
## sound like a recording played four times. Smaller than the footsteps spread:
## a door that changes pitch is a different door.
const SFX_PITCH := 0.035


func sfx(_name: String) -> AudioStream:
	if _sfx.has(_name):
		return _sfx[_name]
	# Short effects are cut to .wav by tools/cut_sfx.gd; the long looping ones
	# stay .mp3 and loop from their import settings, because decoding three
	# minutes of generator in real time buys nothing.
	var s: AudioStream = null
	for ext: String in [".wav", ".mp3"]:
		var path := SFX_DIR + _name + ext
		if ResourceLoader.exists(path):
			s = load(path) as AudioStream
			break
	if s == null:
		push_warning("Sound: no effect '%s' in %s." % [_name, SFX_DIR])
	_sfx[_name] = s
	return s


## A one-shot in the world, heard from wherever it happens. `where` is the node
## it belongs to; the player is freed with it if the door is freed mid-swing.
func play_at(_name: String, where: Node3D, db := 0.0, max_distance := 22.0) -> void:
	var stream := sfx(_name)
	if stream == null or where == null or not where.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus("Sfx")
	p.volume_db = db
	p.max_distance = max_distance
	# Smaller than the default 10: these are things happening in a room, not
	# events that should carry across the house.
	p.unit_size = 3.0
	p.pitch_scale = randf_range(1.0 - SFX_PITCH, 1.0 + SFX_PITCH)
	where.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## A one-shot with no position: the player's own hands. Picking something up
## does not come from across the room, it comes from you.
func play_ui(_name: String, db := 0.0) -> void:
	var stream := sfx(_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus("Sfx")
	p.volume_db = db
	p.pitch_scale = randf_range(1.0 - SFX_PITCH, 1.0 + SFX_PITCH)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
