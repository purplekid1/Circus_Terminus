extends Node
## The ambience beds: night outside, room tone in the house, water and wind in
## the cellar -- and the muffling that happens to the OUTSIDE one when the
## player goes in.
##
## THIS USED TO BE ONE RECORDING PUT THROUGH A FILTER. That is the right model
## for weather, and wrong for everything else: going indoors does not just make
## the night quieter, it puts you somewhere that has a sound of its own. So
## there are three beds now, and they do two different jobs.
##
##   The outdoor bed plays ALL THE TIME and is filtered. Indoors it is the
##   night heard through a wall -- the low-pass closes and the level drops, but
##   the crickets are still out there, which is most of why a house feels
##   enclosed.
##
##   The interior beds fade in on top of it, unfiltered, because the room you
##   are standing in is not on the other side of anything.
##
## That split is why they sit on different buses: Ambience carries the filter
## and the outdoor bed, Interior is clean. One bus with one filter cannot do
## both at once.
##
## No crossfade machinery any more. The beds are 100 to 120 seconds long and
## loop from their import settings; a seam that comes round every two minutes
## on broadband night noise is not worth three players and a tween each. The
## short 10-second track this started with genuinely did need that, which is
## where all of it came from.

## Where each bed sits when it is the one you are in.
##
## THESE ARE NOT SET BY RMS, and the outdoor one sits 12 dB under the others
## for a reason. Crickets put 40% of their energy into 2-6 kHz, which is exactly
## where the ear is most sensitive; the house and cellar beds put 0.2% and 1%
## there. Levelled by plain RMS the three measure within 1 dB of each other and
## the crickets are deafening -- they carry 23 dB more than the room tone in
## the band that matters, and 8 dB more than the MUSIC, which is 9 dB louder
## overall. tools/bedlevels.gd prints both numbers; use the second one.
const OUT_DB := -16.0
const HOUSE_DB := -16.0
const CELLAR_DB := -16.0

## What the outdoor bed drops to once you are inside, on top of the low-pass.
## Not silence: you are meant to still know it is out there.
##
## These three move TOGETHER. They are absolute levels, not offsets from
## OUT_DB, so changing only the first one quietly rearranges how much the walls
## seem to block.
const OUT_INDOORS_DB := -35.0
const OUT_CELLAR_DB := -42.0

## The opening fade. Walking out of the menu's music into a wall of night is a
## jolt; this lets it arrive.
const RISE := 3.0

## How long a zone change takes. Fast enough to feel like a door closing, slow
## enough not to click. Doors take about this long to swing.
const BLEND := 0.55

@export var outside: AudioStream
@export var house: AudioStream
@export var cellar: AudioStream

var _out: AudioStreamPlayer
var _house: AudioStreamPlayer
var _cellar: AudioStreamPlayer

var _lp: AudioEffectLowPassFilter
var _verb: AudioEffectReverb

## ONE WRITER. Every audible value is a plain float tweened by whoever wants to
## change it, and pushed into the players and the effects once a frame by
## _push(). Nothing tweens volume_db on a player directly.
##
## An earlier version did, and the opening fade-in was destroyed without a word:
## _ready() started a three-second rise and then another call set volume_db to
## its final value on the spot. Two tweens and an assignment all writing the
## same property, last one each frame winning.
var _cutoff := 20500.0
var _wet := 0.0
var _room := 0.65
## Master fade for the whole bed set, which only the opening rise moves.
var _rise := -80.0
## Per-bed levels, in dB, moved only by the zone blend.
var _out_db := OUT_DB
var _house_db := -80.0
var _cellar_db := -80.0
var _blend: Tween


func _ready() -> void:
	var bus := AudioServer.get_bus_index("Ambience")
	if bus >= 0:
		for i in AudioServer.get_bus_effect_count(bus):
			var fx := AudioServer.get_bus_effect(bus, i)
			if fx is AudioEffectLowPassFilter:
				_lp = fx
			elif fx is AudioEffectReverb:
				_verb = fx
	if _lp == null or _verb == null:
		# Not fatal: the beds still play, they just stop caring about walls.
		push_warning("Ambience: the Ambience bus has no low-pass and reverb pair"
			+ " -- re-run tools/gen_audio.sh. The night will not be muffled indoors.")

	_out = _make(outside, "Ambience")
	_house = _make(house, "Interior")
	_cellar = _make(cellar, "Interior")

	# Filters first and at full strength, so the very first moment of the bed is
	# already the right side of the wall. Then the rise.
	_apply(Sound.settings(), 0.0)
	_push()
	create_tween().tween_property(self, "_rise", 0.0, RISE)

	Sound.zone_changed.connect(_on_zone_changed)


## All three run from the first frame and never stop. Starting a bed on entry
## means walking into the house begins its room tone at the same point every
## time, which turns a recording into a cue.
func _make(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	@warning_ignore("static_called_on_instance")
	p.bus = Sound.bus(bus)
	p.volume_db = -80.0
	add_child(p)
	if stream != null:
		# Somewhere other than the start, so the three are not phase-locked to
		# each other for the whole session.
		p.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	return p


func _process(_delta: float) -> void:
	_push()


func _on_zone_changed(_zone: int) -> void:
	_apply(Sound.settings(), BLEND)


func _apply(s: Dictionary, over: float) -> void:
	if _blend != null and _blend.is_valid():
		_blend.kill()

	var zone: int = Sound.zone
	var want_out := OUT_DB
	var want_house := -80.0
	var want_cellar := -80.0
	if zone == Sound.Zone.HOUSE:
		want_out = OUT_INDOORS_DB
		want_house = HOUSE_DB
	elif zone == Sound.Zone.CELLAR:
		want_out = OUT_CELLAR_DB
		want_cellar = CELLAR_DB

	if over <= 0.0:
		_cutoff = s["cutoff"]
		_wet = s["wet"]
		_room = s["room"]
		_out_db = want_out
		_house_db = want_house
		_cellar_db = want_cellar
		return

	_blend = create_tween()
	_blend.set_trans(Tween.TRANS_SINE)
	# The cutoff is tweened in LOG space. Swept linearly, a slide from 20500 Hz
	# to 3800 spends almost all of its time in the top octave where nothing is
	# happening and then falls through everything audible in the last few
	# milliseconds -- which sounds like a switch, not a door.
	_blend.tween_method(_set_cutoff_log, log(_cutoff), log(float(s["cutoff"])), over)
	_blend.parallel().tween_property(self, "_wet", s["wet"], over)
	_blend.parallel().tween_property(self, "_room", s["room"], over)
	_blend.parallel().tween_property(self, "_out_db", want_out, over)
	_blend.parallel().tween_property(self, "_house_db", want_house, over)
	_blend.parallel().tween_property(self, "_cellar_db", want_cellar, over)


func _set_cutoff_log(ln: float) -> void:
	_cutoff = exp(ln)


func _push() -> void:
	if _lp != null:
		_lp.cutoff_hz = _cutoff
	if _verb != null:
		_verb.wet = _wet
		_verb.room_size = _room

	# _rise is a master offset rather than a fourth tween on each player, so the
	# opening fade cannot fight the zone blend.
	_out.volume_db = _out_db + _rise
	_house.volume_db = _house_db + _rise
	_cellar.volume_db = _cellar_db + _rise
