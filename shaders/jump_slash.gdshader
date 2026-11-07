shader_type canvas_item;
render_mode blend_add, unshaded;

// 位移刀光：一条沿局部 X 轴的白色直线，用于强调跳跃/位移方向。
// line_length 以 UV（0..1）为单位：0.5 表示贴图半宽，配合 Visual 节点的 scale.x
// 可让视觉长度跟实际位移距离（像素）一致，由 jump_slash.gd 动态设置。
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_length : hint_range(0.05, 1.0) = 0.72;
uniform float line_width : hint_range(0.005, 0.3) = 0.055;
// 中心到边缘的渐变强度：越大，线条中心越亮、边缘越快消隐。
uniform float core_sharpness : hint_range(0.5, 6.0) = 2.2;
// 两端的渐变范围（占半长比例），营造头尾淡出的拖影感。
uniform float tip_fade : hint_range(0.0, 0.6) = 0.32;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// UV 中心为线段中心，X 轴即特效节点的局部方向；线段头部朝 +X（跳跃方向）。
	vec2 p = UV - vec2(0.5);
	float half_length = line_length * 0.5;
	float along = p.x / max(half_length, 0.0001); // -1..1，0=中心，±1=端点
	float across = abs(p.y);

	// 横向（粗细）渐变：中心最亮，往两侧快速变暗，形成柔和光核。
	float width_falloff = 1.0 - smoothstep(0.0, line_width, across);
	float core = pow(clamp(1.0 - across / max(line_width, 0.0001), 0.0, 1.0), core_sharpness);

	// 纵向（长度方向）渐变：头部（跳跃前进方向）最亮，尾部更快淡出，强调位移方向。
	float head_dist = clamp(along, 0.0, 1.0);       // 0=中心, 1=前端
	float tail_dist = clamp(-along, 0.0, 1.0);      // 0=中心, 1=尾端
	float head_fade = 1.0 - smoothstep(1.0 - tip_fade, 1.0, head_dist);
	float tail_fade = 1.0 - smoothstep(1.0 - tip_fade * 1.4, 1.0, tail_dist);
	float length_mask = step(abs(along), 1.0) * head_fade * tail_fade;

	// 位移时间轴：快速显现，随后整体淡出。
	float appear = smoothstep(0.0, 0.08, progress);
	float fade = 1.0 - smoothstep(0.35, 1.0, progress);

	float alpha = width_falloff * length_mask * appear * fade;
	vec3 col = mix(line_color.rgb, core_color.rgb, core);

	COLOR = vec4(col, alpha * mix(0.55, 1.0, core));
}
