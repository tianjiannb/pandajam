shader_type canvas_item;
render_mode blend_add, unshaded;

// 位移刀光：一条沿局部 X 轴的白色直线，用于强调跳跃/位移方向。
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_length : hint_range(0.05, 1.0) = 0.72;
uniform float line_width : hint_range(0.005, 0.3) = 0.055;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// UV 中心为线段中心，X 轴即特效节点的局部方向。
	vec2 p = UV - vec2(0.5);
	float half_length = line_length * 0.5;
	float along = abs(p.x);
	float across = abs(p.y);

	// 线段两端收尖，避免矩形贴图边缘过硬。
	float end_taper = 1.0 - smoothstep(half_length * 0.72, half_length, along);
	float body = 1.0 - smoothstep(line_width * 0.18, line_width, across);
	float segment = 1.0 - smoothstep(half_length, half_length + 0.015, along);

	// 先快速显现，再在位移末段淡出。
	float appear = smoothstep(0.0, 0.10, progress);
	float fade = 1.0 - smoothstep(0.42, 1.0, progress);
	float alpha = body * segment * end_taper * appear * fade;

	COLOR = vec4(line_color.rgb, alpha);
}
