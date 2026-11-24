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
	// INSTANCE_CUSTOM.z > 0: solid silhouette for tool select outline.
	// INSTANCE_CUSTOM.w > 0: multiply instance tint (props). Throngs leave w=0.
	if (custom_data.z > 0.5) {
		COLOR = vec4(inst_color.rgb, tex.a * inst_color.a);
	} else {
		float dirty = clamp(custom_data.y, 0.0, 1.0);
		if (dirty > 0.001) {
			// Unity Venice dirt: lerp toward DirtTex.rgb (not multiply).
			vec4 dirt = texture(dirt_tex, sample_uv);
			float factor = clamp(dirt.a * dirty, 0.0, 1.0);
			tex.rgb = mix(tex.rgb, dirt.rgb, factor);
		}
		COLOR = mix(tex, tex * inst_color, clamp(custom_data.w, 0.0, 1.0));
	}
}
