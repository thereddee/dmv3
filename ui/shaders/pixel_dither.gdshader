shader_type canvas_item;
// Pixel mode of the table: snaps every pixel of the low-res render to a fixed palette after an
// ordered-dither nudge (ported from quantize()/ditherAt() in reference/table-des-joueurs.html).
// Sample the source with nearest filtering so one texel is one big pixel.

const int MAX_COLORS = 64;
const float DITHER_REACH = 0.9;  // strength 100 shifts a channel by 90 of 255

uniform vec3 palette[MAX_COLORS];
uniform int palette_size = 0;  // 0 = pass the image through (used to sample the palette)
uniform float dither_strength : hint_range(0.0, 100.0) = 35.0;
uniform int pattern : hint_range(0, 3) = 0;  // 0 Bayer 4x4, 1 Bayer 2x2, 2 lines, 3 noise

const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const float BAYER2[4] = float[4](0.0, 2.0, 3.0, 1.0);

// Threshold in [-0.5, 0.5) for the pixel at p.
float threshold(ivec2 p) {
	if (pattern == 1) {
		return BAYER2[(p.y & 1) * 2 + (p.x & 1)] / 4.0 + 0.125 - 0.5;
	}
	if (pattern == 2) {
		return (p.y & 1) == 1 ? 0.25 : -0.25;
	}
	if (pattern == 3) {
		return fract(sin(dot(vec2(p), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	}
	return BAYER4[(p.y & 3) * 4 + (p.x & 3)] / 16.0 + 0.03125 - 0.5;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (palette_size <= 0) {
		COLOR = src;
	} else {
		ivec2 p = ivec2(UV / TEXTURE_PIXEL_SIZE);
		float amount = threshold(p) * dither_strength * DITHER_REACH / 255.0;
		vec3 rgb = clamp(src.rgb + vec3(amount), 0.0, 1.0);
		vec3 best = palette[0];
		float best_d = 1e9;
		for (int i = 0; i < MAX_COLORS; i++) {
			if (i >= palette_size) {
				break;
			}
			vec3 d = palette[i] - rgb;
			float dd = dot(d, d);
			if (dd < best_d) {
				best_d = dd;
				best = palette[i];
			}
		}
		COLOR = vec4(best, 1.0);
	}
}