// One shader for every vision tag. The three tag_*.tres materials differ only
// in their tag_key, so there is no reason for three copies of this file.
//
// This writes an HDR "key colour" into the scene colour buffer which
// VisionEffect.gdshader reads back and swaps for the real tag colour:
//
//     tag_key (1,0,0) -> red    (enemy)
//     tag_key (0,1,0) -> yellow (item)
//     tag_key (0,0,1) -> blue   (interactable)
//
// Two things keep the encoding from ever being seen by the player:
//
//   1. vision_mode gates it off entirely when the lens is down.
//   2. vision_lens carries the lens disc as a screen-space ellipse. Anything
//      outside it discards, so the key colour only ever exists in the pixels
//      the lens is about to paint over. That is what lets the lens be a
//      *window* instead of a full-screen takeover.
//
// Apply as material_overlay, not material_override -- the object keeps its
// normal look and this rides on top.

shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

global uniform float vision_mode;

// xy = lens centre in screen UV, zw = lens radii in screen UV. VisionTags
// pushes this onto all three tag materials every frame.
//
// A plain uniform, not a global one: global uniforms have to be declared in
// Project Settings, and the editor only reads those at startup, so adding one
// breaks every already-open editor until it is restarted. Zero radii read as
// "there is no lens right now", which is the fail-closed default.
uniform vec4 vision_lens = vec4(0.5, 0.5, 0.0, 0.0);

// No source_color hint on purpose: these are data, not a colour, and must
// land in the buffer bit-exact for the post shader to classify them.
//
// The default is deliberately black rather than a real key. Godot strips
// shader_parameter entries that match the default when it re-saves a .tres,
// so a real default would silently turn every material that lost its key
// into an enemy. Black classifies as nothing and shows up as an obvious
// black silhouette instead.
uniform vec3 tag_key = vec3(0.0, 0.0, 0.0);

// Pushed well above anything natural lighting produces, so "is this a tag?"
// is a brightness test that ordinary geometry can never accidentally pass.
uniform float key_intensity : hint_range(1.0, 64.0) = 8.0;

// Fraction of the lens radius to stay clear of the rim, so the key never
// reaches the soft edge where the lens is only partly opaque.
uniform float mask_inset : hint_range(0.0, 0.25) = 0.04;

// The overlay pass sits at exactly the same depth as the surface it is drawn
// on, so the two z-fight: the key colour comes out as thin stripes, or loses
// outright and the object reads as untagged. Whether it wins depends on what
// material the object underneath happens to use, which makes it look random.
// Pushing the overlay a few millimetres along the normal turns it into a
// shell that always wins.
uniform float surface_offset : hint_range(0.0, 0.05) = 0.004;

void vertex() {
	VERTEX += NORMAL * surface_offset;
}

void fragment() {
	if (vision_mode < 0.5) {
		discard;
	}

	// Fail closed. The player script publishes a zero radius whenever the
	// lens is behind the camera mid-flip, and dividing by it would smear the
	// key colour across the whole screen.
	vec2 radius = vision_lens.zw;
	if (radius.x < 1e-5 || radius.y < 1e-5) {
		discard;
	}

	vec2 offset = (SCREEN_UV - vision_lens.xy) / radius;
	if (length(offset) > 1.0 - mask_inset) {
		discard;
	}

	ALBEDO = tag_key * key_intensity;
}
