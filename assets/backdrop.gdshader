shader_type sky;
render_mode disable_fog;

// Static, inexpensive sky color: no noise, texture lookups or time-dependent effects.
void sky() {
	float height = smoothstep(-0.4, 0.5, EYEDIR.y);
	COLOR = mix(vec3(0.10, 0.19, 0.25), vec3(0.025, 0.04, 0.085), height);
}
