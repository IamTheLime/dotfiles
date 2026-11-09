#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    vec4 leftBox;
    vec4 rightBox;
    vec4 tail;
    float softness;
    float split;
    float tailSoftness;
    float hasRunning;
    float wobble;
    float wavePhase;
    vec2 streak;
    vec4 tint;
};
float capsule(vec2 p, vec4 box) {
    float r = min(box.z, box.w) * 0.5;
    vec2 q = abs(p - box.xy - box.zw * 0.5) - box.zw * 0.5 + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}
float merge(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
float shapeDistance(vec2 p) {
    float across = (p.x - surfaceSize.x * 0.5) / max(leftBox.w, rightBox.x + rightBox.z - leftBox.x);
    p.x += wobble * 0.55 * sin(wavePhase) * (p.y - leftBox.y - leftBox.w * 0.5) / leftBox.w;
    p.y += wobble * (0.65 * sin(across * 6.2831853 + wavePhase)
        + 0.35 * sin(across * 12.566371 - wavePhase * 0.7));
    float d = capsule(p, leftBox);
    if (hasRunning > 0.5) {
        float whole = capsule(p, vec4(leftBox.xy, rightBox.x + rightBox.z - leftBox.x, leftBox.w));
        d = mix(whole, merge(d, capsule(p, rightBox), softness), split);
    }
    if (tail.w > 0.01) {
        float t = clamp((p.y - tail.y) / max(0.01, tail.z - tail.y), 0.0, 1.0);
        float drop = length(p - vec2(tail.x, mix(tail.y, tail.z, t))) - tail.w * (1.0 - 0.8 * t);
        d = merge(d, drop, tailSoftness);
    }
    return d;
}
void main() {
    vec2 p = qt_TexCoord0 * surfaceSize;
    float d = shapeDistance(p);
    float edge = max(fwidth(d), 0.75);
    float coverage = 1.0 - smoothstep(-edge, edge, d);
    if (dot(streak, streak) > 0.01) {
        float across = clamp((p.x - surfaceSize.x * 0.5) / max(1.0, (rightBox.x + rightBox.z - leftBox.x) * 0.5), -1.0, 1.0);
        vec2 direction = vec2(streak.x * across, streak.y);
        coverage *= 7.0;
        for (int i = 1; i < 7; ++i) {
            float sampleDistance = shapeDistance(p + direction * (float(i) / 6.0));
            coverage += (7.0 - float(i)) * (1.0 - smoothstep(-edge, edge, sampleDistance));
        }
        coverage /= 28.0;
    }
    float alpha = tint.a * coverage * qt_Opacity;
    fragColor = vec4(tint.rgb * alpha, alpha);
}
