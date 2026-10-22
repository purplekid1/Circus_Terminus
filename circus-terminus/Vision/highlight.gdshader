// Rim glow drawn over whatever the player is currently aimed at.
//
// Applied as material_overlay, so the object keeps its own look and this
// rides on top. blend_add + depth_draw_never means it only ever brightens
// and never writes depth, which keeps it out of the lens edge detection.
//
// The lens already tags interactables blue when it is raised; the player
// script skips this highlight while the glass is up so the two never fight
// over the same overlay slot.

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 rim_color : source_color = vec3(0.62, 0.86, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float strength : hint_range(0.0, 4.0) = 1.1;
// A slow breath, so the highlight reads as "live" rather than as a decal.
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.4;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 1.0 - pulse_depth * 0.5 * (1.0 - cos(TIME * pulse_speed));
	ALBEDO = rim_color * rim * strength * pulse;
}
