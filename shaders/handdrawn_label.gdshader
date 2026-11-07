shader_type canvas_item;

// 手绘风格数字：在不更换字体的前提下，用噪声扭曲字形边缘 + 轻微抖动，
// 模拟手写涂鸦时笔画粗细不均、边缘毛糙、轻微晃动的效果。

// 扭曲强度（UV 偏移幅度），越大字形越"毛糙"。
uniform float wobble_strength : hint_range(0.0, 0.05) = 0.012;
// 扭曲噪声的缩放，越大纹理越细碎。
uniform float noise_scale : hint_range(1.0, 40.0) = 10.0;
// 整体抖动速度（时间系数）。
uniform float jitter_speed : hint_range(0.0, 10.0) = 2.4;
// 轻微旋转抖动幅度（弧度）。
uniform float rotation_jitter : hint_range(0.0, 0.2) = 0.04;
// 墨迹边缘加粗/做旧的透明度增益，让描边处更不均匀。
uniform float ink_edge_strength : hint_range(0.0, 1.0) = 0.35;

// 简单 2D 哈希噪声，避免额外纹理依赖。
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	float t = TIME * jitter_speed;

	// 整体轻微旋转抖动：围绕字形中心 (0.5, 0.5) 小幅摆动采样坐标，
	// 模拟手绘时线条的不稳定感，而不是单纯平移。
	vec2 centered = UV - vec2(0.5);
	float angle = sin(t * 0.7) * rotation_jitter;
	float ca = cos(angle);
	float sa = sin(angle);
	vec2 rotated = vec2(centered.x * ca - centered.y * sa, centered.x * sa + centered.y * ca);
	vec2 jittered_uv = rotated + vec2(0.5);

	// 噪声驱动的边缘扭曲：按像素位置 + 时间采样噪声场，产生随机但连续的偏移，
	// 让字形轮廓看起来像手绘笔触而非精确几何边缘。
	vec2 noise_uv = jittered_uv * noise_scale + vec2(t * 0.15, -t * 0.11);
	float n1 = noise(noise_uv) - 0.5;
	float n2 = noise(noise_uv + vec2(5.2, 1.3)) - 0.5;
	vec2 offset = vec2(n1, n2) * wobble_strength;

	vec4 col = texture(TEXTURE, jittered_uv + offset);

	// 墨迹边缘：在字形边缘（alpha 过渡区）叠加额外噪声，让描边粗细不均、
	// 带点"洇墨"的毛糙感，而不是锐利的矢量边缘。
	float edge_sample = texture(TEXTURE, jittered_uv + offset * 1.8).a;
	float edge_mask = edge_sample * (1.0 - edge_sample) * 4.0; // 在 alpha≈0.5 处最大
	float ink_noise = noise(noise_uv * 1.7 + vec2(3.1, -2.7));
	col.a = clamp(col.a + (ink_noise - 0.5) * ink_edge_strength * edge_mask, 0.0, 1.0);

	COLOR = col;
}
