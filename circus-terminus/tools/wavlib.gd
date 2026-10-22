extends RefCounted
## Reading, writing and reshaping 16-bit PCM WAVs, for the offline audio tools.
##
## This exists because there is no ffmpeg, sox or Python on the machine this
## project is built on, and the footstep cut has to be reproducible rather than
## something that was done once by hand in an editor nobody else has. Godot is
## already a dependency, so Godot does the DSP.
##
## Everything works on PackedFloat32Array mono at a known rate. Sixteen-bit
## integers are an interchange format, not a working one: filtering, mixing and
## normalising in fixed point accumulates rounding you can hear as grit on a
## quiet tail.


## {rate, channels, frames, samples} -- samples is mono float in [-1, 1],
## downmixed by averaging, which is right for a recording where both channels
## carry the same event.
static func read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("wavlib: cannot open %s" % path)
		return {}
	var raw := f.get_buffer(f.get_length())
	f.close()

	if raw.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or raw.slice(8, 12).get_string_from_ascii() != "WAVE":
		push_error("wavlib: %s is not a RIFF/WAVE file" % path)
		return {}

	# Walk the chunk list rather than assuming fmt sits at 12 and data at 36.
	# Anything that has been through an editor tends to carry LIST/INFO or a
	# fact chunk in between, and a fixed offset reads the metadata as audio.
	var rate := 0
	var channels := 0
	var bits := 0
	var data_at := -1
	var data_len := 0
	var pos := 12
	while pos + 8 <= raw.size():
		var id := raw.slice(pos, pos + 4).get_string_from_ascii()
		var size := raw.decode_u32(pos + 4)
		var body := pos + 8
		if id == "fmt ":
			channels = raw.decode_u16(body + 2)
			rate = raw.decode_u32(body + 4)
			bits = raw.decode_u16(body + 14)
		elif id == "data":
			data_at = body
			data_len = size
		# Chunks are word-aligned: an odd size is followed by a pad byte.
		pos = body + size + (size & 1)

	if data_at < 0 or bits != 16 or channels < 1:
		push_error("wavlib: %s is not 16-bit PCM (bits=%d ch=%d)" % [path, bits, channels])
		return {}

	# A truncated file reports more data than it has. Trust the file.
	data_len = mini(data_len, raw.size() - data_at)
	var frames := data_len / (2 * channels)
	var out := PackedFloat32Array()
	out.resize(frames)
	var scale := 1.0 / 32768.0
	for i in frames:
		var base := data_at + i * 2 * channels
		var acc := 0.0
		for c in channels:
			acc += raw.decode_s16(base + c * 2)
		out[i] = acc * scale / channels
	return {"rate": rate, "channels": channels, "frames": frames, "samples": out}


## Mono 16-bit. Clipped, not scaled, so a caller that has not normalised hears
## the distortion rather than getting a silently quieter file back.
static func write(path: String, samples: PackedFloat32Array, rate: int) -> void:
	var n := samples.size()
	var raw := PackedByteArray()
	raw.resize(44 + n * 2)
	raw.encode_u32(0, 0x46464952)          # "RIFF"
	raw.encode_u32(4, 36 + n * 2)
	raw.encode_u32(8, 0x45564157)          # "WAVE"
	raw.encode_u32(12, 0x20746d66)         # "fmt "
	raw.encode_u32(16, 16)
	raw.encode_u16(20, 1)                  # PCM
	raw.encode_u16(22, 1)                  # mono
	raw.encode_u32(24, rate)
	raw.encode_u32(28, rate * 2)           # byte rate
	raw.encode_u16(32, 2)                  # block align
	raw.encode_u16(34, 16)
	raw.encode_u32(36, 0x61746164)         # "data"
	raw.encode_u32(40, n * 2)
	for i in n:
		raw.encode_s16(44 + i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("wavlib: cannot write %s" % path)
		return
	f.store_buffer(raw)
	f.close()


# --------------------------------------------------------------- measuring

## Short-window RMS, one value per sample, used for onset finding and for
## deciding where a tail has died away. Window in samples.
static func envelope(s: PackedFloat32Array, window: int) -> PackedFloat32Array:
	var n := s.size()
	var out := PackedFloat32Array()
	out.resize(n)
	# Running sum of squares, so this is O(n) rather than O(n * window) -- the
	# naive version takes minutes on a twelve-second file.
	var acc := 0.0
	for i in n:
		acc += s[i] * s[i]
		if i >= window:
			acc -= s[i - window] * s[i - window]
		out[i] = sqrt(acc / minf(float(i + 1), float(window)))
	return out


static func peak(s: PackedFloat32Array) -> float:
	var m := 0.0
	for v in s:
		m = maxf(m, absf(v))
	return m


# ------------------------------------------------------------------- shaping
# Enough DSP to make one pair of shoes sound like three floors. All of it is
# the cheap textbook form: these run offline, once, so clarity beats cleverness.

## One-pole low-pass. The workhorse -- "indoors" is mostly this.
static func low_pass(s: PackedFloat32Array, rate: int, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / rate)
	var out := PackedFloat32Array()
	out.resize(s.size())
	var z := 0.0
	for i in s.size():
		z += a * (s[i] - z)
		out[i] = z
	return out


## One-pole high-pass, as the residual of the low-pass. Used to keep rumble out
## of a surface that should be crisp, and to split a hit into body and click.
static func high_pass(s: PackedFloat32Array, rate: int, cutoff: float) -> PackedFloat32Array:
	var lp := low_pass(s, rate, cutoff)
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] - lp[i]
	return out


## RBJ peaking EQ. This is what puts a floor's resonance into a footstep --
## boards ring low-mid, concrete does not.
static func peaking(s: PackedFloat32Array, rate: int, freq: float, q: float,
		gain_db: float) -> PackedFloat32Array:
	var A := pow(10.0, gain_db / 40.0)
	var w := TAU * freq / rate
	var alpha := sin(w) / (2.0 * q)
	var b0 := 1.0 + alpha * A
	var b1 := -2.0 * cos(w)
	var b2 := 1.0 - alpha * A
	var a0 := 1.0 + alpha / A
	var a1 := b1
	var a2 := 1.0 - alpha / A
	var out := PackedFloat32Array()
	out.resize(s.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		var x := s[i]
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## A single damped echo. One of these at 50-90 ms is what a bare room with two
## hard parallel walls sounds like, and it is most of the cellar's character.
static func slapback(s: PackedFloat32Array, rate: int, time_s: float,
		level: float, damp_hz: float) -> PackedFloat32Array:
	var d := int(rate * time_s)
	var tail := low_pass(s, rate, damp_hz)
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] + (tail[i - d] * level if i >= d else 0.0)
	return out


## Schroeder reverb: four parallel combs into two series allpasses. Not a nice
## reverb -- it is metallic on anything sustained -- but a footstep is 300 ms of
## transient and that is exactly what this flatters.
##
## `size` scales the delays (1.0 is a cellar), `damp` is the low-pass inside
## each comb's loop, `mix` is how much wet is added to the dry.
static func reverb(s: PackedFloat32Array, rate: int, size: float, damp_hz: float,
		mix: float, decay: float) -> PackedFloat32Array:
	# Mutually prime-ish delays in ms, so the combs do not reinforce into a pitch.
	var combs := [29.7, 37.1, 41.1, 43.7]
	var allpasses := [5.0, 1.7]
	var n := s.size()
	# Room for the tail to actually decay into, rather than being cut off at the
	# end of the dry hit.
	var pad := int(rate * 0.6 * size)
	var wet := PackedFloat32Array()
	wet.resize(n + pad)

	for ms: float in combs:
		var d := maxi(int(rate * ms * 0.001 * size), 1)
		var buf := PackedFloat32Array()
		buf.resize(d)
		var lp := 0.0
		var a := 1.0 - exp(-TAU * damp_hz / rate)
		var p := 0
		for i in wet.size():
			var x := s[i] if i < n else 0.0
			var y := buf[p]
			lp += a * (y - lp)
			buf[p] = x + lp * decay
			p = (p + 1) % d
			wet[i] += y * 0.25

	for ms: float in allpasses:
		var d := maxi(int(rate * ms * 0.001 * size), 1)
		var buf := PackedFloat32Array()
		buf.resize(d)
		var p := 0
		var g := 0.5
		for i in wet.size():
			var x := wet[i]
			var y := buf[p]
			buf[p] = x + y * g
			wet[i] = y - x * g
			p = (p + 1) % d

	var out := PackedFloat32Array()
	out.resize(n + pad)
	for i in out.size():
		out[i] = (s[i] if i < n else 0.0) + wet[i] * mix
	return out


## Linear resample. Used as a pitch shift: a heavier boot is the same recording
## played a little slow. Ratio > 1 is longer and lower.
static func resample(s: PackedFloat32Array, ratio: float) -> PackedFloat32Array:
	var n := int(s.size() * ratio)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var src := i / ratio
		var i0 := int(src)
		var frac := src - i0
		var a := s[i0] if i0 < s.size() else 0.0
		var b := s[i0 + 1] if i0 + 1 < s.size() else 0.0
		out[i] = lerpf(a, b, frac)
	return out


## Grit: noise shaped by the signal's own envelope and band-limited. Gravel and
## dry leaves are mostly this, and the source recording has none of it.
static func scatter(s: PackedFloat32Array, rate: int, level: float,
		lo_hz: float, hi_hz: float, seed: int, decay_s: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var env := envelope(s, int(rate * 0.003))

	# Where the hit actually lands. The grit is hung off THIS, not off the
	# whole envelope: shaped by the envelope alone it runs for as long as the
	# step does, which is a sixth of a second of high-frequency noise after
	# every footfall -- and high-frequency noise is the most audible kind
	# there is. It measured 30 dB above the other two sets and read as hiss.
	var at := 0
	var best := 0.0
	for i in env.size():
		if env[i] > best:
			best = env[i]
			at = i

	var fall := maxf(rate * decay_s, 1.0)
	var noise := PackedFloat32Array()
	noise.resize(s.size())
	for i in s.size():
		# Loose material moves while the foot is coming down and for a moment
		# after. Not for the length of the reverb tail.
		var age := maxf(float(i - at), 0.0)
		noise[i] = rng.randf_range(-1.0, 1.0) * env[i] * exp(-age / fall)
	noise = high_pass(low_pass(noise, rate, hi_hz), rate, lo_hz)

	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] + noise[i] * level
	return out


## Scales so the loudest sample lands on `target`. The source recording peaks at
## about -24 dBFS, so without this every step is inaudible under the ambience.
static func normalise(s: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var p := peak(s)
	if p < 1e-9:
		return s
	var g := target / p
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] * g
	return out


## Ramps the ends. The out-fade is the important one: a slice that stops while
## the tail is still moving puts a click on the end of every step, and a click
## repeated every 0.6 s is the most obvious artefact there is.
static func fade(s: PackedFloat32Array, rate: int, in_ms: float,
		out_ms: float) -> PackedFloat32Array:
	var out := s.duplicate()
	var fi := mini(int(rate * in_ms * 0.001), out.size())
	var fo := mini(int(rate * out_ms * 0.001), out.size())
	for i in fi:
		out[i] *= float(i) / fi
	for i in fo:
		out[out.size() - 1 - i] *= float(i) / fo
	return out


## Constant-skirt RBJ bandpass. At a high Q this is a resonator: hit it with a
## transient and it rings at `freq`, decaying over roughly Q / (PI * freq)
## seconds. That ring is what a hollow wooden floor IS, and no amount of
## peaking EQ will produce it -- an EQ can only amplify a frequency the
## recording already contains, and this recording contains almost nothing
## below 120 Hz to amplify.
static func resonator(s: PackedFloat32Array, rate: int, freq: float,
		q: float) -> PackedFloat32Array:
	var w := TAU * freq / rate
	var alpha := sin(w) / (2.0 * q)
	var b0 := alpha
	var b1 := 0.0
	var b2 := -alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cos(w)
	var a2 := 1.0 - alpha
	var out := PackedFloat32Array()
	out.resize(s.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		var x := s[i]
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Mixes in one or more rings, each [freq, q, level], with `level` measured
## against the dry hit's peak so the balance does not drift with the source.
static func ring(s: PackedFloat32Array, rate: int, voices: Array,
		pad_s: float) -> PackedFloat32Array:
	# Room for the ring to decay into. Without this the resonator is cut off by
	# the end of the dry slice and the ring ends in a click.
	var padded := s.duplicate()
	padded.resize(s.size() + int(rate * pad_s))
	var dry := peak(s)
	var out := padded.duplicate()
	for v: Array in voices:
		var r := resonator(padded, rate, v[0], v[1])
		var rp := peak(r)
		if rp < 1e-9:
			continue
		var g: float = dry * v[2] / rp
		for i in out.size():
			out[i] += r[i] * g
	return out


## Drops trailing near-silence. The reverb and ring stages both pad the buffer
## to give their tails room to decay, and whatever they do not use is dead air
## that would otherwise be stored in the .wav and held in memory for the whole
## game. Threshold is relative to the file's own peak; -60 dB is below anything
## that survives being mixed under ambience.
static func trim_tail(s: PackedFloat32Array, rate: int, floor_db: float) -> PackedFloat32Array:
	var limit := peak(s) * pow(10.0, floor_db / 20.0)
	var env := envelope(s, int(rate * 0.005))
	var last := s.size() - 1
	while last > 0 and env[last] < limit:
		last -= 1
	return s.slice(0, mini(last + int(rate * 0.01), s.size()))


## Downward expander. Above `thresh` the signal passes untouched; below it, it
## is pushed further down, so the floor falls away while the hit does not.
##
## This is here because the source recording peaks at -24 dBFS and every slice
## is normalised by about 15x to be usable. That multiplies the room tone by 15
## as well, and on the outdoor set -- the only one that is not low-passed down
## to 5 kHz -- the result is audible hiss under every step. A gate is the honest
## fix: the quiet parts of a footstep recording are supposed to be quiet.
##
## `ratio` is how many dB the output falls for each dB the input is below the
## threshold, minus one. 2.0 means 10 dB under becomes 20 dB under.
static func gate(s: PackedFloat32Array, rate: int, thresh: float, ratio: float,
		attack_ms: float, release_ms: float) -> PackedFloat32Array:
	var env := envelope(s, int(rate * 0.004))
	var up := 1.0 - exp(-1.0 / maxf(rate * attack_ms * 0.001, 1.0))
	var down := 1.0 - exp(-1.0 / maxf(rate * release_ms * 0.001, 1.0))
	var out := PackedFloat32Array()
	out.resize(s.size())
	var g := 0.0
	for i in s.size():
		var want := 1.0
		if env[i] < thresh:
			# In dB: every dB below the threshold costs `ratio` extra dB.
			var under := linear_to_db(maxf(env[i], 1e-9)) - linear_to_db(thresh)
			want = db_to_linear(under * ratio)
		# Opening fast and closing slowly, so an attack is never clipped and a
		# decay is never chopped off mid-tail.
		g += (want - g) * (up if want > g else down)
		out[i] = s[i] * g
	return out


# ---------------------------------------------------------------- generating
# Sources rather than shapers. Everything above takes a recording and changes
# it; these make one out of nothing, for the sounds the project has no
# recording of.

static func silence(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	return out


static func noise(n: int, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


## A tone at a fixed pitch. `shape` is "sine", "saw" or "square"; a saw has the
## harmonics an engine needs, a sine does not.
static func tone(n: int, rate: int, freq: float, shape := "sine") -> PackedFloat32Array:
	return sweep(n, rate, freq, freq, shape)


## A tone that slides from one pitch to another, exponentially -- pitch is
## logarithmic, and a linear slide from 40 Hz to 400 Hz spends most of its time
## sounding high.
static func sweep(n: int, rate: int, f0: float, f1: float,
		shape := "sine") -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / maxf(float(n - 1), 1.0)
		var f: float = f0 * pow(maxf(f1, 1.0) / maxf(f0, 1.0), t)
		phase = fmod(phase + f / rate, 1.0)
		match shape:
			"saw":
				out[i] = phase * 2.0 - 1.0
			"square":
				out[i] = 1.0 if phase < 0.5 else -1.0
			_:
				out[i] = sin(phase * TAU)
	return out


## An attack-decay envelope, as an array to multiply by. `curve` above 1 makes
## the decay fall away faster at the start, which is what almost every real
## impact does.
static func ad(n: int, rate: int, attack_s: float, decay_s: float,
		curve := 2.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a := maxi(int(rate * attack_s), 1)
	var d := maxf(rate * decay_s, 1.0)
	for i in n:
		if i < a:
			out[i] = float(i) / a
		else:
			out[i] = pow(maxf(1.0 - (i - a) / d, 0.0), curve)
	return out


static func apply(s: PackedFloat32Array, env: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] * (env[i] if i < env.size() else 0.0)
	return out


## Adds b into a at `gain`, lengthening a if it has to. Offsets in samples, so
## a recipe can lay several hits along a timeline.
static func mix(a: PackedFloat32Array, b: PackedFloat32Array, gain: float,
		offset := 0) -> PackedFloat32Array:
	var need := maxi(a.size(), offset + b.size())
	var out := a.duplicate()
	out.resize(need)
	for i in b.size():
		var at := offset + i
		if at >= 0:
			out[at] += b[i] * gain
	return out


static func gain(s: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[i] * g
	return out


## A resonator whose pitch slides while it rings. This is what a creak is: wood
## slipping against wood in tiny steps, each one ringing the door at a slightly
## different frequency as the hinge turns.
static func sweep_resonator(s: PackedFloat32Array, rate: int, f0: float,
		f1: float, q: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var n := maxf(float(s.size() - 1), 1.0)
	for i in s.size():
		var t := i / n
		var freq: float = f0 * pow(maxf(f1, 1.0) / maxf(f0, 1.0), t)
		var w := TAU * freq / rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		var b0 := alpha / a0
		var a1 := -2.0 * cos(w) / a0
		var a2 := (1.0 - alpha) / a0
		var x := s[i]
		var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Turns a clip into a seamless loop by folding its tail back over its head.
## The result is SHORTER than the input by the crossfade, and the joint is
## inaudible because the two sides of it are the same samples faded past each
## other. Used for the engine and generator beds, which have to run forever.
static func loopify(s: PackedFloat32Array, rate: int, fade_s: float) -> PackedFloat32Array:
	var f := mini(int(rate * fade_s), s.size() / 2)
	if f <= 0:
		return s
	var n := s.size() - f
	var out := s.slice(0, n)
	for i in f:
		# Equal power, so the overlap does not bulge.
		var t := float(i) / f
		out[i] = out[i] * sqrt(t) + s[n + i] * sqrt(1.0 - t)
	return out


## Band-pass by cascading the two one-poles. Used often enough in the sound
## effect recipes to be worth a name of its own.
static func band(s: PackedFloat32Array, rate: int, lo_hz: float,
		hi_hz: float) -> PackedFloat32Array:
	return high_pass(low_pass(s, rate, hi_hz), rate, lo_hz)
