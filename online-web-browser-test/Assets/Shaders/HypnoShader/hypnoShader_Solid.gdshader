shader_type spatial;
// Forced Opaque rendering and disabled culling to match your visual fix
render_mode blend_mix, depth_draw_always, depth_test_default, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_vtx_2;
uniform sampler2D tex_frg_2;
uniform sampler2D tex_frg_6;
uniform sampler2D tex_frg_8;

void vertex() {
	float n_out8p0 = TIME;
	vec2 n_in7p2 = vec2(0.05000, 0.05000);
	
	// THE SEAMLESS FIX: 
	// 1. Multiply VERTEX.xy by 0.5 to scale the noise to fit the mesh size.
	// 2. Use fract() to force the numbers to always stay loop-wrapped between 0.0 and 1.0.
	vec2 mesh_uv = fract(VERTEX.xy * 0.5);
	
	vec2 n_out7p0 = n_in7p2 * vec2(n_out8p0) + mesh_uv;
	vec4 n_out2p0 = texture(tex_vtx_2, n_out7p0);
	
	float n_out5p0 = TIME;
	vec2 n_in4p2 = vec2(0.10000, 0.10000);
	vec2 n_out4p0 = n_in4p2 * vec2(n_out5p0) + mesh_uv;

	vec3 n_out6p0;
	vec3 n_in6p1 = vec3(0.00000, 0.00000, 0.00000);
	{
		float base = vec3(n_out4p0, 0.0).x;
		float blend = n_in6p1.x;
		if (base < 0.5) {
			n_out6p0.x = (base * (blend + 0.5));
		} else {
			n_out6p0.x = (1.0 - (1.0 - base) * (1.0 - (blend - 0.5)));
		}
	}
	{
		float base = vec3(n_out4p0, 0.0).y;
		float blend = n_in6p1.y;
		if (base < 0.5) {
			n_out6p0.y = (base * (blend + 0.5));
		} else {
			n_out6p0.y = (1.0 - (1.0 - base) * (1.0 - (blend - 0.5)));
		}
	}
	{
		float base = vec3(n_out4p0, 0.0).z;
		float blend = n_in6p1.z;
		if (base < 0.5) {
			n_out6p0.z = (base * (blend + 0.5));
		} else {
			n_out6p0.z = (1.0 - (1.0 - base) * (1.0 - (blend - 0.5)));
		}
	}

	UV = vec2(n_out2p0.xy);
	COLOR.rgb = n_out6p0;
}

void fragment() {
	float n_out4p0 = TIME;
	vec2 n_in7p1 = vec2(0.10000, 0.10000);
	vec2 n_out7p0 = vec2(n_out4p0) * n_in7p1 + UV;
	vec4 n_out2p0 = texture(tex_frg_2, n_out7p0);
	vec4 n_out6p0 = texture(tex_frg_6, n_out7p0);
	
	float n_out10p0 = TIME;
	vec2 n_in9p1 = vec2(-0.10000, -0.10000);
	vec2 n_out9p0 = vec2(n_out10p0) * n_in9p1 + UV;
	vec4 n_out8p0 = texture(tex_frg_8, n_out9p0);
	
	vec2 n_out11p0 = vec2(n_out6p0.xy) * vec2(n_out8p0.xy);
	vec4 n_in12p1 = vec4(1.25000, 1.25000, 1.25000, 1.25000);
	vec4 n_out12p0 = pow(vec4(n_out11p0, 0.0, 0.0), n_in12p1);
	vec4 n_out5p0 = n_out2p0 + n_out12p0;

	ALBEDO = vec3(n_out5p0.xyz);
}