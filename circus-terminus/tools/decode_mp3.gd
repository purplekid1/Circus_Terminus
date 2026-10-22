extends SceneTree
## Decodes an mp3 to a mono WAV, so the offline tools can work on it.
##
##     MP3_IN=Audio/source/x.mp3 WAV_OUT=Audio/source/x.wav \
##       godot --path . --script tools/decode_mp3.gd
##
## There is no ffmpeg on this machine (see tools/README.md), and wavlib reads
## RIFF only. Godot can decode an mp3 but will not hand you the samples, so the
## file is PLAYED on a bus of its own with an AudioEffectCapture on it and the
## decoded frames are read back out. That makes this a real-time job: a
## fifteen-second file takes fifteen seconds.
##
## Must run WINDOWED, not headless -- the dummy audio driver does not turn the
## mixer, so the capture stays empty. Master is pulled to -80 dB for the
## duration so the decode does not blare out of the speakers; the capture sits
## on the source bus, ahead of that, and still sees full level.

const WAV := preload("res://tools/wavlib.gd")

var _cap: AudioEffectCapture
var _p: AudioStreamPlayer
var _out := PackedFloat32Array()
var _started := false
var _rate := 44100
var _master_was := 0.0


func _initialize() -> void:
	var src := OS.get_environment("MP3_IN")
	var dst := OS.get_environment("WAV_OUT")
	if src == "" or dst == "":
		push_error("decode_mp3: set MP3_IN and WAV_OUT")
		quit(1)
		return

	var bytes := FileAccess.get_file_as_bytes(src)
	if bytes.is_empty():
		push_error("decode_mp3: cannot read %s" % src)
		quit(1)
		return
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	print("decoding %s -- %.2f s, %d bytes" % [src, stream.get_length(), bytes.size()])

	_rate = int(AudioServer.get_mix_rate())
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Decode")
	AudioServer.set_bus_send(bus, "Master")
	_cap = AudioEffectCapture.new()
	# Generous, because a dropped buffer is a hole in the middle of the file and
	# there is no way to tell from the waveform which one it was.
	_cap.buffer_length = 8.0
	AudioServer.add_bus_effect(bus, _cap)

	_master_was = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -80.0)

	_p = AudioStreamPlayer.new()
	_p.stream = stream
	_p.bus = "Decode"
	_p.volume_db = 0.0
	root.add_child(_p)


func _process(_d: float) -> bool:
	if not _started:
		_p.play()
		_started = true
		return false

	_drain()
	if _p.playing:
		return false

	# One last sweep: the tail is still in the buffer when playing goes false.
	for _i in 4:
		_drain()

	AudioServer.set_bus_volume_db(0, _master_was)
	var dst := OS.get_environment("WAV_OUT")
	WAV.write(ProjectSettings.globalize_path(dst) if dst.begins_with("res://") else dst,
		_out, _rate)
	print("wrote %s -- %.2f s, %d frames at %d Hz, peak %.4f" % [
		dst, float(_out.size()) / _rate, _out.size(), _rate, WAV.peak(_out)])
	var lost := _cap.get_discarded_frames()
	if lost > 0:
		push_error("decode_mp3: %d frames were DISCARDED -- the file has holes in"
			% lost + " it. Raise buffer_length and run it again.")
	else:
		print("no frames discarded")
	return true


func _drain() -> void:
	var n := _cap.get_frames_available()
	if n <= 0:
		return
	var buf := _cap.get_buffer(n)
	var at := _out.size()
	_out.resize(at + buf.size())
	for i in buf.size():
		_out[at + i] = (buf[i].x + buf[i].y) * 0.5
