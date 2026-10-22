shader_type spatial;
render_mode world_vertex_coords;

// Procedural surfaces for everything outdoors: the drive, the paving, the
// lawn, the road and the estate wall.
//
// The yard was five flat greys. It reads as a car park because nothing out
// there has a pattern on it -- no courses in the wall, no joints in the
// paving, no clumps in the grass -- and a surface with no pattern has no
// scale, so the whole garden could be five metres across or fifty.
//
// This ships no images. The project has no texture files and adding a set
// would mean authoring, importing and keeping them in step with the
// generators; the sky is already a shader, and so is the dust, so the ground
// is one too. Everything below comes out of an integer hash.
//
// PATTERN picks which surface. One shader rather than five because they all
// want the same machinery -- a tiling coordinate, a joint mask, a height
// field and a normal derived from it -- and only the middle step differs.

#define P_ASPHALT 0
#define P_FLAGSTONE 1
#define P_GRAVEL 2
#define P_GRASS 3
#define P_COBBLE 4
#define P_ASHLAR 5

group_uniforms Surface;
uniform int pattern : hint_range(0, 5) = 0;
uniform vec3 tint_a : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 tint_b : source_color = vec3(0.30, 0.29, 0.27);
uniform vec3 joint_tint : source_color = vec3(0.10, 0.10, 0.10);
// Metres per tile of the pattern. This is the only number that sets the
// apparent SIZE of the ground, so it is worth getting right: 0.9 gives a
// paving slab you could stand one foot on.
uniform float tile_size = 1.0;
uniform float joint_width : hint_range(0.0, 0.3) = 0.05;

group_uniforms Shading;
uniform float roughness_lo : hint_range(0.0, 1.0) = 0.75;
uniform float roughness_hi : hint_range(0.0, 1.0) = 1.0;
uniform float bump : hint_range(0.0, 4.0) = 1.0;
// Broad blotches over the top of everything: damp patches, worn tracks, moss.
uniform float weathering : hint_range(0.0, 1.0) = 0.35;
uniform float weather_scale = 0.06;
uniform vec3 weather_tint : source_color = vec3(0.10, 0.12, 0.09);

varying vec3 world_pos;
varying vec3 world_norm;


// ------------------------------------------------------------------ hashing

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 19.19));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		s += vnoise(p) * a;
		p *= 2.07;
		a *= 0.5;
	}
	return s;
}


// ------------------------------------------------------------------ layouts
//
// Each of these returns:
//   x  height of the surface at p, 0 in a joint and 1 on top of a unit
//   y  a per-unit random, so no two slabs are the same colour
//   z  distance to the nearest joint, for widening the mortar

// Running bond: rows of fixed depth, each offset along its length by a random
// amount, and each row split into units of varying width. This is what a
// paved path, a brick course and an ashlar wall all are.
vec3 running_bond(vec2 p, float row_depth, float unit_min, float unit_max, float jw) {
	float row = floor(p.y / row_depth);
	float row_rand = hash21(vec2(row, 7.7));
	float along = p.x + row_rand * 4.0;

	// walk the row in units of varying width by quantising a warped axis
	float unit_w = mix(unit_min, unit_max, hash21(vec2(floor(along / unit_min), row)));
	float unit = floor(along / unit_w);
	vec2 id = vec2(unit, row);

	float fx = fract(along / unit_w);
	float fy = fract(p.y / row_depth);
	// distance to the nearest edge of this unit, in metres
	float dx = min(fx, 1.0 - fx) * unit_w;
	float dy = min(fy, 1.0 - fy) * row_depth;
	float d = min(dx, dy);

	float h = smoothstep(0.0, jw, d);
	return vec3(h, hash21(id), d);
}

// Voronoi cells, for cobbles and gravel: nearest of a jittered point per cell.
vec3 cells(vec2 p, float jitter) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float second = 8.0;
	vec2 best_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + mix(vec2(0.5), hash22(i + o), jitter) - f;
			float d = dot(c, c);
			if (d < best) {
				second = best;
				best = d;
				best_id = i + o;
			} else if (d < second) {
				second = d;
			}
		}
	}
	float edge = sqrt(second) - sqrt(best);   // 0 on a cell border
	return vec3(edge, hash21(best_id), edge);
}


// ------------------------------------------------------------------ surface

// Returns height in .x, per-unit random in .y, joint distance in .z.
vec3 surface(vec2 p) {
	if (pattern == P_FLAGSTONE) {
		vec3 r = running_bond(p, 1.0, 0.85, 1.45, joint_width);
		// slabs are not flat: a shallow dish worn into each one
		r.x *= 1.0 - 0.25 * fbm(p * 3.0 + r.y * 40.0, 2);
		return r;
	}
	if (pattern == P_ASHLAR) {
		vec3 r = running_bond(p, 0.55, 0.9, 1.7, joint_width);
		r.x *= 0.85 + 0.15 * fbm(p * 5.0 + r.y * 31.0, 3);
		return r;
	}
	if (pattern == P_COBBLE) {
		vec3 c = cells(p, 0.85);
		float h = smoothstep(0.0, joint_width * 3.0, c.x);
		return vec3(h, c.y, c.x);
	}
	if (pattern == P_GRAVEL) {
		// two scales of chippings, so it does not read as one regular grain
		vec3 c1 = cells(p * 3.0, 1.0);
		vec3 c2 = cells(p * 7.0 + 31.0, 1.0);
		float h = smoothstep(0.0, 0.25, c1.x) * 0.6 + smoothstep(0.0, 0.3, c2.x) * 0.4;
		return vec3(h, c1.y, c1.x);
	}
	if (pattern == P_GRASS) {
		// clumps at two scales plus a fine blade streak, stretched so it has
		// a lie to it rather than looking like moss
		float clump = fbm(p * 1.6, 4);
		float blades = fbm(vec2(p.x * 26.0, p.y * 7.0), 2);
		float h = clump * 0.75 + blades * 0.25;
		return vec3(h, hash21(floor(p * 1.6)), 1.0);
	}
	// asphalt: fine aggregate, no joints
	float g = fbm(p * 18.0, 3) * 0.6 + fbm(p * 60.0, 2) * 0.4;
	return vec3(g, g, 1.0);
}


void vertex() {
	world_pos = VERTEX;
	world_norm = normalize(NORMAL);
	// world_vertex_coords gives VERTEX in world space but NORMAL still needs
	// taking out of model space by hand.
	world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec3 n = normalize(world_norm);
	vec3 an = abs(n);

	// Project onto whichever plane the surface most faces. Ground is XZ; the
	// estate wall is XY or ZY. A full triplanar blend would cost three
	// evaluations of the pattern for a seam nobody will stand on.
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = world_pos.xz;
	} else if (an.x >= an.z) {
		uv = vec2(world_pos.z, world_pos.y);
	} else {
		uv = vec2(world_pos.x, world_pos.y);
	}
	uv /= max(tile_size, 0.001);

	vec3 s = surface(uv);
	float h = s.x;

	// ---- colour ----
	vec3 col = mix(tint_a, tint_b, s.y);
	// mortar / soil in the joints
	col = mix(joint_tint, col, smoothstep(0.0, 0.7, h));
	// and a little dirt in the low spots generally
	col *= 0.80 + 0.20 * h;

	// broad weathering over the top of everything
	float w = fbm(world_pos.xz * weather_scale, 4);
	col = mix(col, weather_tint, smoothstep(0.45, 0.95, w) * weathering);

	ALBEDO = col;
	ROUGHNESS = mix(roughness_hi, roughness_lo, h * (1.0 - 0.5 * w));
	SPECULAR = 0.35;

	// ---- normal, from the gradient of the height field ----
	// Finite differences rather than an authored normal map: the height is
	// already a function, so its slope is free and always agrees with it.
	float e = 0.5 / max(tile_size, 0.001) * 0.02;
	float hx = surface(uv + vec2(e, 0.0)).x - surface(uv - vec2(e, 0.0)).x;
	float hy = surface(uv + vec2(0.0, e)).x - surface(uv - vec2(0.0, e)).x;

	vec3 t = normalize(abs(n.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), n)));
	vec3 b = cross(n, t);
	vec3 bumped = normalize(n - (t * hx + b * hy) * bump * 4.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
}
