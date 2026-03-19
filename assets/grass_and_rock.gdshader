shader_type spatial;

uniform sampler2D top_texture : source_color, repeat_enable;
uniform sampler2D side_texture : source_color, repeat_enable;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	float upness = clamp(dot(NORMAL, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	
	vec3 top_color = texture(top_texture, UV).rgb;
    vec3 side_color = texture(side_texture, UV).rgb;

    ALBEDO = mix(side_color, top_color, upness);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
