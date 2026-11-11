shader_type canvas_item;

uniform int h_frames = 4;
uniform int v_frames = 6;
uniform sampler2D dirt_tex : hint_default_transparent, filter_nearest;

varying vec4 custom_data;
varying vec4 inst_color;

void vertex() {
	custom_data = INSTANCE_CUSTOM;
	inst_color = COLOR;
}

void fragment() {
	vec2 size = 1.0 / vec2(float(h_frames), float(v_frames));
	int current_frame = int(custom_data.x + 0.5);
	int frame_x = current_frame % h_frames;
	int frame_y = current_frame / h_frames;
	vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * size;
	vec2 corrected_uv = vec2(UV.x, 1.0 - UV.y);
	vec2 sample_uv = corrected_uv * size + frame_offset;
	vec4 tex = texture(TEXTURE, sample_uv);
	if (tex.a < 0.15) {
		discard;
	}
	float dirty = clamp(custom_data.y, 0.0, 1.0);
	if (dirty > 0.001) {
		vec4 dirt = texture(dirt_tex, sample_uv);
		float factor = dirt.a * dirty;
		tex.rgb = mix(tex.rgb, tex.rgb * dirt.rgb, factor);
	}
	COLOR = (current_frame < 24 || current_frame >= 144) ? tex : tex * inst_color;
}
