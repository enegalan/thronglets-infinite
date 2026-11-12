shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float intensity = 1.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float band = floor(SCREEN_UV.y * 52.0);
	float tick = floor(TIME * 16.0);
	float n = hash(band * 17.0 + tick);
	float shift = (n - 0.5) * 0.07 * step(0.38, hash(band + tick)) * intensity;
	vec2 uv = SCREEN_UV + vec2(shift, 0.0);
	float chroma = 0.012 * intensity;
	float r = texture(screen_tex, uv + vec2(chroma, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(chroma, 0.0)).b;
	COLOR = vec4(r, g, b, 1.0);
}
