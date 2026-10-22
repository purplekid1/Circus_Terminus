// Floating dust motes for GPUParticles3D.
//
// render_mode notes, both of which matter for the vision lens:
//   depth_draw_never -- dust must stay out of the depth buffer, or the lens
//     edge detection finds a silhouette around every mote and the whole view
//     fills with speckle.
//   blend_add -- motes only ever brighten, so they stay far below the lens
//     key threshold and can never be mistaken for a tag.
//
// Put this on the QuadMesh in the particle system's draw pass.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never,
	shadows_disabled, fog_disabled;

uniform vec3 dust_color : source_color = vec3(0.78, 0.80, 0.90);
uniform float brightness : hint_range(0.0, 4.0) = 0.65;
// Higher values give a tighter, harder mote; lower is a soft haze.
uniform float softness : hint_range(0.5, 8.0) = 2.2;
// Motes closer than this fade out. Without it you get big blurry blobs
// pressed against the camera, and dust drifting in front of the lens.
uniform float near_fade : hint_range(0.0, 4.0) = 0.9;
uniform float far_fade : hint_range(1.0, 60.0) = 22.0;
// How fast each mote twinkles as it tumbles through the light.
uniform float shimmer_speed : hint_range(0.0, 8.0) = 1.6;
uniform float shimmer_depth : hint_range(0.0, 1.0) = 0.35;

// INSTANCE_CUSTOM is a vertex-stage built-in, so the per-particle data has to
// be handed to the fragment stage explicitly.
varying vec4 mote_custom;

void vertex() {
	mote_custom = INSTANCE_CUSTOM;

	// Billboard towards the camera while keeping the particle's own scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	// Soft round mote out of a square quad.
	vec2 offset = UV * 2.0 - 1.0;
	float mote = pow(clamp(1.0 - length(offset), 0.0, 1.0), softness);

	// ParticleProcessMaterial writes the lifetime fraction into CUSTOM.y, so
	// motes can fade in and out instead of popping.
	float life = clamp(mote_custom.y, 0.0, 1.0);
	float life_fade = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.72, 1.0, life));

	// VERTEX is view space here, so -z is metres in front of the camera.
	float distance_to_camera = -VERTEX.z;
	float range_fade =
		smoothstep(0.0, near_fade, distance_to_camera)
		* (1.0 - smoothstep(far_fade * 0.6, far_fade, distance_to_camera));

	// Per-mote phase, so they do not all blink together.
	float shimmer = 1.0 - shimmer_depth * 0.5
		* (1.0 + sin(TIME * shimmer_speed + mote_custom.x * 6.2831));

	ALBEDO = dust_color * brightness;
	ALPHA = mote * life_fade * range_fade * shimmer;
}
