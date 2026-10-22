// Circus Terminus -- the vision effect on the flip-up magnifying lens.
//
// This is NOT a full-screen post effect. It runs on the lens disc as an
// ordinary 3D surface in front of the camera, so everything outside the lens
// keeps rendering normally and the player looks *through* the glass.
//
// Forward+ only: needs the depth and normal-roughness buffers.
//
// The lens shape comes from vision_lens, not from the mesh UVs. A cylinder
// cap has no usable 0..1 UV square, and deriving the disc in screen space
// means this works whatever mesh is on the lens and however it is tilted.
//
// Reads the HDR key colours written by Vision/vision_tag.gdshader:
//   red channel -> enemy, green -> item, blue -> interactable.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never,
	blend_mix, fog_disabled, shadows_disabled;

// 0 = plain glass, 1 = full vision. The player script tweens this, which is
// what makes the effect boot in instead of snapping on.
global uniform float vision_mode;
// xy = lens centre in screen UV, zw = lens radii in screen UV. Pushed every
// frame by PlayerController to this material and to the three tag materials,
// so the tag clip and the visible disc are the same shape by construction.
//
// A plain uniform, not a global one: global uniforms have to be declared in
// Project Settings, and the editor only reads those at startup, so adding one
// breaks every already-open editor until it is restarted. Zero radii read as
// "there is no lens right now".
uniform vec4 vision_lens = vec4(0.5, 0.5, 0.0, 0.0);

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex  : hint_depth_texture,  filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

group_uniforms Look;
uniform vec3  bg_color    : source_color = vec3(0.018, 0.019, 0.021);
uniform vec3  line_color  : source_color = vec3(0.94, 0.95, 0.96);
uniform vec3  world_tint  : source_color = vec3(0.78, 0.79, 0.80);
uniform float see_through : hint_range(0.0, 1.0) = 0.50;
uniform float line_width  : hint_range(0.5, 4.0) = 1.2;
// 0 = fully black and white through the lens, 1 = the scene's own colour.
// Tags are applied after this and stay saturated either way.
uniform float world_saturation : hint_range(0.0, 1.0) = 0.0;
// The lens works as an image intensifier: it amplifies a scene far too dark
// to read by eye. Without gain, a horror-lit room is simply black through it.
uniform float world_gain : hint_range(0.0, 16.0) = 3.5;
// Soft shoulder on the gain, so lifting the shadows does not blow the torch
// beam into a white hole. Higher rolls off sooner.
uniform float world_rolloff : hint_range(0.0, 4.0) = 0.6;
// Pushes the greys apart so a desaturated scene does not turn to mush.
uniform float world_contrast : hint_range(0.5, 3.0) = 1.35;

group_uniforms Glass;
uniform vec3  glass_tint    : source_color = vec3(0.88, 0.90, 0.91);
uniform float idle_opacity  : hint_range(0.0, 1.0) = 0.22;
uniform float edge_softness : hint_range(0.001, 0.5) = 0.10;
uniform float rim_strength  : hint_range(0.0, 2.0) = 0.14;
uniform float frost         : hint_range(0.0, 4.0) = 0.45;
uniform float magnify       : hint_range(1.0, 3.0) = 1.18;
uniform float lens_strength : hint_range(0.0, 4.0) = 0.6;
uniform float scanline      : hint_range(0.0, 1.0) = 0.022;

group_uniforms Edges;
uniform float depth_threshold  : hint_range(0.0, 0.2) = 0.012;
uniform float depth_softness   : hint_range(0.001, 0.2) = 0.018;
uniform float normal_threshold : hint_range(0.0, 2.0) = 0.30;
uniform float normal_softness  : hint_range(0.001, 2.0) = 0.35;

group_uniforms Tags;
// Must sit between ordinary scene brightness and vision_tag's key_intensity.
uniform float key_threshold : hint_range(1.0, 32.0) = 4.0;
// How much the two non-dominant channels may contribute before a pixel is
// rejected as "not a key". Keeps blown-out white surfaces from classifying.
uniform float key_purity    : hint_range(0.0, 1.0) = 0.35;
uniform vec3  enemy_color    : source_color = vec3(1.00, 0.10, 0.12);
uniform vec3  item_color     : source_color = vec3(1.00, 0.82, 0.12);
uniform vec3  interact_color : source_color = vec3(0.16, 0.56, 1.00);
uniform float tag_glow   : hint_range(0.0, 4.0) = 0.6;
// Tags are composited before the scene tonemapper runs, and ACES desaturates
// and compresses whatever reaches it. Lifting them first keeps red reading as
// red instead of dusty pink.
uniform float tag_exposure : hint_range(0.5, 4.0) = 1.9;
uniform float tag_halo   : hint_range(0.0, 2.0) = 0.5;
uniform float halo_width : hint_range(1.0, 12.0) = 4.0;

group_uniforms Falloff;
uniform float fade_start = 2.0;   // metres: edges at full strength up to here
uniform float fade_end = 28.0;    // metres: edges gone past here
uniform float pane_vignette : hint_range(0.0, 1.0) = 0.30;

// Godot's depth buffer is reverse-Z and non-linear, so raw differences are
// meaningless at distance. Reconstruct metres in front of the camera.
// inv_proj is passed in rather than read as a built-in so this stays a
// self-contained function.
float view_depth(vec2 uv, mat4 inv_proj) {
	float raw = texture(depth_tex, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
	return clamp(-view.z / max(view.w, 1e-6), 0.0, 100000.0);
}

vec3 view_normal(vec2 uv) {
	return normalize(texture(normal_tex, uv).rgb * 2.0 - 1.0);
}

// Land exactly on a texel centre. Magnification and the lens offset put the
// sample between texels, and without this the bilinear filter would blend an
// 8.0 key with the world behind it and paint a one-pixel fringe around every
// tagged silhouette.
vec2 snap_uv(vec2 uv, vec2 viewport) {
	return (floor(uv * viewport) + 0.5) / viewport;
}

// .xyz selects the tag slot, .w is 1.0 when this pixel carries a key at all.
vec4 read_tag(vec2 uv, vec2 viewport) {
	vec3 c = textureLod(screen_tex, snap_uv(uv, viewport), 0.0).rgb;
	float peak = max(max(c.r, c.g), c.b);

	if (peak < key_threshold) {
		return vec4(0.0);
	}

	// A pure key normalises to one channel at 1.0 and the rest at 0.0, so
	// whatever is left after subtracting the dominant channel is impurity.
	vec3 unit = c / peak;
	if (unit.r + unit.g + unit.b - 1.0 > key_purity) {
		return vec4(0.0);
	}

	vec3 slot = step(vec3(peak * 0.999), c);
	return vec4(slot, 1.0);
}

vec3 tag_tint(vec4 tag) {
	return (enemy_color * tag.x + item_color * tag.y + interact_color * tag.z) * tag.w;
}

void fragment() {
	float on = clamp(vision_mode, 0.0, 1.0);
	vec2 viewport = VIEWPORT_SIZE;

	// ---- 1. lens disc, in screen space ----
	vec2 centre = vision_lens.xy;
	vec2 radius = max(vision_lens.zw, vec2(1e-4));
	// -1..1 across the lens on both axes, so the disc reads as a circle no
	// matter how the ellipse is squashed by tilt or aspect.
	vec2 disc = (SCREEN_UV - centre) / radius;
	float r = length(disc);

	// A soft rim instead of a hard cut-out: the lens dissolves into the real
	// view rather than slicing it.
	float pane = 1.0 - smoothstep(1.0 - edge_softness, 1.0, r);
	// Narrow band hugging the rim. A wide one was invisible against a bright
	// scene but reads as a blazing halo against a dark one.
	float rim = smoothstep(1.0 - edge_softness * 1.4, 1.0 - edge_softness * 0.15, r);

	// ---- 2. look through the glass ----
	vec2 texel = line_width / viewport;
	vec2 tap = 1.0 / viewport;
	// Actually magnify: pull the sample towards the lens centre. This also
	// means every sample lands further inside the disc, so nothing outside
	// the tag clip can ever be read back in.
	vec2 zoomed = centre + (SCREEN_UV - centre) / max(magnify, 0.001);
	// Grows towards the rim, so the disc reads as ground glass, not a hole.
	vec2 lens = disc * radius * (lens_strength * 0.004) * (0.35 + r * r);
	vec2 suv = clamp(zoomed + lens, vec2(0.0), vec2(1.0));

	float blur = frost * on;
	vec3 world = textureLod(screen_tex, suv, blur).rgb;

	// ---- 3. tags, antialiased across a 5-tap cross ----
	vec4 t0 = read_tag(suv, viewport);
	vec4 t1 = read_tag(suv + vec2( tap.x, 0.0), viewport);
	vec4 t2 = read_tag(suv + vec2(-tap.x, 0.0), viewport);
	vec4 t3 = read_tag(suv + vec2(0.0,  tap.y), viewport);
	vec4 t4 = read_tag(suv + vec2(0.0, -tap.y), viewport);

	float tag_hits = t0.w + t1.w + t2.w + t3.w + t4.w;
	float tag_mask = tag_hits * 0.2;

	// Average over the taps that actually hit, so a silhouette pixel fades in
	// the tag's own colour instead of fading towards black.
	vec3 tag_color = vec3(0.0);
	if (tag_hits > 0.0) {
		tag_color = (tag_tint(t0) + tag_tint(t1) + tag_tint(t2)
			+ tag_tint(t3) + tag_tint(t4)) / tag_hits;
	}

	// A wider diagonal ring gives tagged things a halo so they stay readable
	// against busy geometry.
	vec2 wide = tap * halo_width;
	float halo_hits =
		read_tag(suv + vec2( wide.x,  wide.y), viewport).w +
		read_tag(suv + vec2(-wide.x,  wide.y), viewport).w +
		read_tag(suv + vec2( wide.x, -wide.y), viewport).w +
		read_tag(suv + vec2(-wide.x, -wide.y), viewport).w;
	float halo = clamp(halo_hits * 0.25 - tag_mask, 0.0, 1.0);

	// ---- 4. depth edges ----
	float d  = view_depth(suv, INV_PROJECTION_MATRIX);
	float dl = view_depth(suv + vec2(-texel.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = view_depth(suv + vec2( texel.x, 0.0), INV_PROJECTION_MATRIX);
	float du = view_depth(suv + vec2(0.0, -texel.y), INV_PROJECTION_MATRIX);
	float dd = view_depth(suv + vec2(0.0,  texel.y), INV_PROJECTION_MATRIX);

	float depth_edge =
		(abs(d - dl) + abs(d - dr) + abs(d - du) + abs(d - dd)) / max(d, 0.001);

	// ---- 5. normal edges (creases) ----
	vec3 n  = view_normal(suv);
	vec3 nl = view_normal(suv + vec2(-texel.x, 0.0));
	vec3 nr = view_normal(suv + vec2( texel.x, 0.0));
	vec3 nu = view_normal(suv + vec2(0.0, -texel.y));
	vec3 nd = view_normal(suv + vec2(0.0,  texel.y));

	float normal_edge =
		(1.0 - dot(n, nl)) + (1.0 - dot(n, nr)) +
		(1.0 - dot(n, nu)) + (1.0 - dot(n, nd));

	// smoothstep, not step: this is the difference between crawling aliased
	// stair-steps and a clean line.
	float edge = max(
		smoothstep(depth_threshold, depth_threshold + depth_softness, depth_edge),
		smoothstep(normal_threshold, normal_threshold + normal_softness, normal_edge)
	);

	// ---- 6. falloff ----
	float distance_fade = 1.0 - smoothstep(fade_start, fade_end, d);
	float lens_fade = 1.0 - pane_vignette * smoothstep(0.25, 1.0, r);
	edge *= distance_fade * lens_fade;

	// ---- 7. compose ----
	// Rec. 709 luma, then a contrast push around mid grey. Straight
	// desaturation of a dim scene reads as flat sludge.
	float luma = dot(world, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luma), world, world_saturation) * world_gain;
	graded = graded / (vec3(1.0) + graded * world_rolloff);
	graded = max((graded - vec3(0.18)) * world_contrast + vec3(0.18), vec3(0.0));

	// Drop the raw key colour before it can tint anything; the tag colour
	// replaces these pixels outright a line later.
	vec3 backdrop = graded * (1.0 - tag_mask);

	vec3 xray = bg_color + backdrop * world_tint * see_through;
	xray = mix(xray, line_color, edge);
	xray = mix(xray, tag_color * tag_exposure, tag_mask);
	xray += tag_color * (halo * tag_halo + tag_mask * tag_glow * 0.25);

	float scan = 1.0 - scanline * 0.5 *
		(0.5 + 0.5 * sin(SCREEN_UV.y * viewport.y * 1.5708 - TIME * 6.0));
	xray *= scan;

	// Off, and mid-flip, the lens is just tinted glass in full colour, so the
	// colour visibly drains away as the effect boots in.
	vec3 idle = world * glass_tint;

	ALBEDO = mix(idle, xray, on) + line_color * rim * rim_strength;
	ALPHA = pane * mix(idle_opacity, 1.0, on);
}
