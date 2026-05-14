shader_type spatial;
render_mode unshaded, cull_front, skip_vertex_transform;

uniform float outline_thickness : hint_range(0.0, 0.5) = 0.05;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float stealth_fade : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Push the vertex outward in pure local Object Space
	vec3 local_pos = VERTEX + NORMAL * outline_thickness;
	
	// Manually transform to View Space
	VERTEX = (MODELVIEW_MATRIX * vec4(local_pos, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0 - stealth_fade;
}
