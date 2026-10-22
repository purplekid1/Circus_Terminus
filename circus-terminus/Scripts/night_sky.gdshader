shader_type sky;
render_mode use_debanding;

// A moonlit overcast-clearing night, drawn entirely in the shader.
//
// ProceduralSkyMaterial gives you two colours and a blur, which is why the old
// sky was an empty grey dome: there is nothing up there to look at, so the
// house has no silhouette and the fog has nothing to sit against. This adds
// the three things that fix that -- a field of stars, one moon with a real
// disc and halo, and a thin band of cloud drifting across both.
//
// Everything is procedural because the project ships no textures: the noise
// is value noise off an integer hash, which is cheap enough at sky rates and
// tiles nowhere, so there is no repeat to spot along the horizon.
//
// MOON_DIRECTION MUST MATCH THE DIRECTIONAL LIGHT. There is no way for a sky
// shader to read the scene's light rotation, so the two are set side by side
// in the level and a moon that does not agree with its own moonlight is the
// single most obvious thing that can go wrong here.

group_uniforms Sky;
uniform vec3 zenith_color : source_color = vec3(0.020, 0.030, 0.062);
uniform vec3 horizon_color : source_color = vec3(0.062, 0.076, 0.104);
uniform vec3 ground_color : source_color = vec3(0.008, 0.009, 0.012);
uniform float horizon_falloff : hint_range(0.5, 8.0) = 2.4;

group_uniforms Moon;
uniform vec3 moon_direction = vec3(0.36, 0.46, -0.81);
// Angular radius in radians. The real moon is about 0.0045; this one is
// deliberately four times that, because a true-to-life moon is a dot and the
// point of putting one up there is for it to be an image.
uniform float moon_radius : hint_range(0.004, 0.09) = 0.030;
uniform vec3 moon_color : source_color = vec3(1.0, 0.972, 0.912);
uniform float moon_brightness : hint_range(0.0, 20.0) = 6.0;
// 0 full, 1 fully shadowed on the -X side of the disc. A sliver of terminator
// is what stops it reading as a white sticker.
uniform float moon_phase : hint_range(0.0, 1.0) = 0.22;
uniform float halo_strength : hint_range(0.0, 2.0) = 0.55;

group_uniforms Stars;
uniform float star_density : hint_range(0.0, 1.0) = 0.055;
uniform float star_brightness : hint_range(0.0, 6.0) = 1.5;
uniform float star_scale : hint_range(50.0, 900.0) = 340.0;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 2.1;
uniform float milky_way : hint_range(0.0, 2.0) = 0.42;

group_uniforms Cloud;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_sharpness : hint_range(0.5, 8.0) = 2.6;
uniform vec3 cloud_color : source_color = vec3(0.18, 0.20, 0.25);
uniform vec2 cloud_drift = vec2(0.006, 0.002);


// ---------------------------------------------------------------- hashing

float hash1(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 hash3(vec3 p) {
	return vec3(hash1(p), hash1(p + 19.19), hash1(p + 47.71));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash1(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash1(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash1(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash1(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash1(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash1(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash1(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash1(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z);
}

float fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		sum += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}


// ------------------------------------------------------------------ stars
//
// One candidate star per cell of a 3D grid laid over the view direction.
// Grid cells rather than a hashed sphere sampling, because it gives an even
// spread with no clumping at the poles and costs one hash per pixel.

vec3 starfield(vec3 dir, float time) {
	vec3 p = dir * star_scale;
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;

	vec3 r = hash3(cell);
	if (r.z > star_density) {
		return vec3(0.0);
	}

	// where in the cell the star sits, and how big it is
	vec2 offset = (r.xy - 0.5) * 0.7;
	float dist = length(f.xy - offset) + abs(f.z) * 0.6;
	float size = mix(0.030, 0.085, r.x);
	float core = smoothstep(size, 0.0, dist);
	// a wider, much fainter bloom so the brightest ones read as points of
	// light rather than as single lit pixels
	float bloom = smoothstep(size * 4.0, 0.0, dist) * 0.18;

	// twinkle: two rates again, and never all the way to zero
	float phase = r.y * 6.2831;
	float tw = 0.72 + 0.28 * sin(time * twinkle_speed + phase)
	                * sin(time * twinkle_speed * 0.41 + phase * 2.3);

	// cool blue-white through to amber, weighted towards white
	vec3 tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.86, 0.66), r.x * r.x);

	return tint * (core + bloom) * tw * star_brightness * mix(0.35, 1.0, r.y);
}


void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// ---- the dome itself ----
	float t = pow(clamp(up, 0.0, 1.0), 1.0 / horizon_falloff);
	vec3 col = mix(horizon_color, zenith_color, t);
	// below the horizon there is only unlit ground and fog
	col = mix(ground_color, col, smoothstep(-0.06, 0.02, up));

	// ---- stars ----
	// Faded out towards the horizon, where in a real night sky they are lost
	// in haze long before they reach it.
	float star_fade = smoothstep(-0.02, 0.28, up);
	vec3 stars = starfield(dir, TIME) * star_fade;

	// a soft band of unresolved stars across the sky, angled off the vertical
	vec3 band_axis = normalize(vec3(0.42, 0.30, 0.86));
	float band = 1.0 - abs(dot(dir, band_axis));
	band = pow(clamp(band, 0.0, 1.0), 9.0);
	float band_noise = fbm(dir * 7.0, 4);
	stars += vec3(0.58, 0.63, 0.82) * band * band_noise * milky_way * star_fade;

	col += stars;

	// ---- the moon ----
	vec3 mdir = normalize(moon_direction);
	float cosang = dot(dir, mdir);
	float ang = acos(clamp(cosang, -1.0, 1.0));

	// A basis across the disc, so the surface detail and the phase terminator
	// both have somewhere to live. The disc is tiny, so `right` can be built
	// off world up without ever hitting the degenerate case.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), mdir));
	vec3 upv = cross(mdir, right);
	vec2 uv = vec2(dot(dir, right), dot(dir, upv)) / max(moon_radius, 0.0001);
	float rr = length(uv);

	float disc = 1.0 - smoothstep(0.985, 1.0, rr);
	if (disc > 0.0) {
		// limb darkening, then maria as two octaves of blotchy noise
		float limb = sqrt(max(1.0 - rr * rr, 0.0));
		float maria = fbm(vec3(uv * 2.2, 0.0) + vec3(11.3, 4.7, 0.0), 3);
		float craters = fbm(vec3(uv * 9.0, 3.1), 2);
		float surface = mix(0.72, 1.0, maria) * mix(0.88, 1.0, craters);

		// phase: a shadow sweeping in from one limb, with a soft terminator
		float term = smoothstep(-0.25, 0.25, uv.x - (moon_phase * 2.0 - 1.0) * 1.35);
		float lit = mix(0.035, 1.0, term);

		vec3 face = moon_color * surface * lit * mix(0.62, 1.0, limb) * moon_brightness;
		col = mix(col, face, disc);
	}

	// halo: a tight corona plus a wide, very faint bloom through the haze
	float corona = pow(max(cosang, 0.0), 2200.0) * 1.4;
	float bloom = pow(max(cosang, 0.0), 22.0) * 0.16;
	col += moon_color * (corona + bloom) * halo_strength * moon_brightness * 0.25;

	// ---- cloud ----
	// Projected onto a flat plane above the viewer, which is what gives the
	// perspective stretch towards the horizon for free.
	if (up > 0.005) {
		vec3 plane = vec3(dir.xz / max(up, 0.005), 0.0) * 0.9;
		vec2 flow = cloud_drift * TIME;
		float n = fbm(vec3(plane.xy + flow, 0.4), 5);
		float cover = smoothstep(1.0 - cloud_amount, 1.0, n * 1.55);
		cover = pow(cover, cloud_sharpness);
		cover *= smoothstep(0.0, 0.16, up);

		// lit from the moon side, so the cloud has a shape rather than being
		// a flat grey smear
		float moonlit = pow(max(dot(dir, mdir), 0.0), 4.0);
		vec3 puff = cloud_color * (0.7 + 1.9 * moonlit);
		col = mix(col, puff, clamp(cover, 0.0, 1.0));
	}

	COLOR = col;
}
