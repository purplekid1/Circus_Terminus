shader_type canvas_item;
render_mode blend_mix;

// The swirling tunnel the book drops you into.
//
// Built in POLAR coordinates rather than as geometry. A tunnel you fly down is
// a cylinder seen from inside, and a cylinder seen from inside is just angle
// and depth -- so the whole thing is one full-screen quad, with no mesh, no
// camera move and nothing to collide with. It also cannot clip through the
// level it is drawn over.
//
// Depth is 1/radius. That one line is what makes it read as distance: equal
// steps toward the middle of the screen become ever-larger steps down the
// tunnel, which is how perspective behaves, and it puts a vanishing point at
// the centre for free.
//
// THE WALL PATTERN IS SAMPLED ON A RING, not from the raw angle. atan() jumps
// from +PI to -PI across the negative x axis, and feeding that straight into
// noise draws a hard seam along the left of the screen -- which is exactly what
// the first version did. Sampling the noise at (cos a, sin a) has no seam
// because the ring closes on itself.

// How far along the tunnel we are. Driven from script rather than from TIME, so
// the travel can accelerate, hold and stop with the rest of the sequence.
uniform float travel : hint_range(0.0, 200.0) = 0.0;
// Overall presence. 0 is invisible, 1 is the only thing on screen.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// How fast the walls turn about the vanishing point.
uniform float spin = 1.0;
// How much the walls SPIRAL with distance. Without this the streaks are
// perfectly radial and the whole thing reads as a starburst rather than as a
// pipe you are falling down -- the twist is what makes it a tunnel.
uniform float twist : hint_range(0.0, 1.0) = 0.16;
// Brightness of the hole at the far end.
uniform float core : hint_range(0.0, 4.0) = 1.5;
// How wide that hole is, as a fraction of the screen.
uniform float core_size : hint_range(0.02, 1.0) = 0.34;

uniform vec3 wall_dark : source_color = vec3(0.04, 0.015, 0.03);
uniform vec3 wall_lit : source_color = vec3(0.85, 0.38, 0.11);
uniform vec3 core_tint : source_color = vec3(1.0, 0.94, 0.78);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Centred and aspect-corrected so the tunnel is ROUND on any window.
	// SCREEN_PIXEL_SIZE is 1/viewport, so y/x is width/height; x has to be
	// stretched BY that, not divided by it -- the other way round gives a wide
	// ellipse, which is what this did to begin with.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= aspect;

	float r = max(length(uv), 0.0015);
	float a = atan(uv.y, uv.x) + travel * spin * 0.05;

	// Down the pipe.
	float depth = 0.32 / r + travel;

	// Spiral: the further down the tunnel a point is, the further round it has
	// been carried.
	a += depth * twist;

	// Seam-free ring sampling. The big radius is what gives enough angular
	// detail to read as streaks rather than as four fat blobs.
	vec2 ring = vec2(cos(a), sin(a));
	float streak = fbm(ring * 9.0 + vec2(depth * 0.55, -depth * 0.55));
	float swirl = fbm(ring * 3.2 + vec2(depth * 0.14, depth * 0.11));
	float wall = clamp(mix(streak, swirl, 0.4) * 1.5 - 0.25, 0.0, 1.0);

	// Walls: dark, with lit streaks running away from you.
	vec3 col = mix(wall_dark, wall_lit, wall);

	// The hole at the end. Bright at the CENTRE and falling off outward --
	// the first version had this inverted and the vanishing point came out
	// black, which is the one thing a tunnel must never be.
	float glow = pow(clamp(1.0 - r / core_size, 0.0, 1.0), 2.2);
	col = mix(col, core_tint, glow * clamp(core, 0.0, 4.0) * 0.75);
	col += core_tint * glow * glow * 0.6;

	// Down toward black at the screen edges, so it reads as a pipe you are
	// inside rather than as fog filling the frame.
	col *= 1.0 - smoothstep(0.30, 0.78, r) * 0.85;

	COLOR = vec4(col, clamp(amount, 0.0, 1.0));
}
