shader_type canvas_item;

void fragment() {
	float scan = 0.55 + 0.45 * sin(FRAGCOORD.y * 2.4);
	float vig = smoothstep(0.95, 0.18, length(UV - vec2(0.5)));
	COLOR = vec4(0.0, 0.18, 0.04, (1.0 - scan * vig) * 0.78);
}
