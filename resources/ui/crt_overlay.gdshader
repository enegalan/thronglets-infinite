shader_type canvas_item;

void fragment() {
	float scan = 0.82 + 0.18 * sin(FRAGCOORD.y * 1.7);
	float vig = smoothstep(0.85, 0.25, length(UV - vec2(0.5)));
	COLOR = vec4(0.0, 0.12, 0.02, (1.0 - scan * vig) * 0.55);
}
