shader_type spatial;

uniform sampler2D tex : source_color;
uniform sampler2D gradient : source_color;

void fragment() {
	ALBEDO = texture(tex, UV).rgb;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), -1.0, 1.0);
	float sample = clamp((d + 1.0) * ATTENUATION / 2.0, 0.0, 1.0);
	vec4 shaded = texture(gradient, vec2(sample, 0.0));
	DIFFUSE_LIGHT += clamp(shaded.rgb * LIGHT_COLOR, 0.0, 1.0);
}
