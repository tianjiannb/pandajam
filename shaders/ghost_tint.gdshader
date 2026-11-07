shader_type canvas_item;

// 副本调色蒙版：与玩家共用同一张序列图，用随机色调区分"过去的自己"。
// 保留原贴图的明暗（亮度），只替换色相/饱和度，避免变成纯色色块。

uniform vec4 tint_color : source_color = vec4(0.85, 0.35, 0.95, 1.0);
// 蒙版强度：0 = 完全保留原色，1 = 完全替换成 tint_color（按亮度调制）。
uniform float tint_strength : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float luminance = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint_color.rgb * luminance;
	vec3 result = mix(tex_color.rgb, tinted, tint_strength);
	COLOR = vec4(result, tex_color.a);
}
