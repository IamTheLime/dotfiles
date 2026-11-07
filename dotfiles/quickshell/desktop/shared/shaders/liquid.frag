#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    vec4 leftBox;
    vec4 middleBox;
    vec4 rightBox;
    vec4 tint;
    float joined;
    float phase;
    float singleShape;
    float cornerRadius;
    float edgeFeather;
};

float roundedBox(vec2 p, vec4 box, vec4 corners) {
    vec2 local = p - box.xy - box.zw * 0.5;
    float radius = local.x < 0.0
        ? (local.y < 0.0 ? corners.x : corners.w)
        : (local.y < 0.0 ? corners.y : corners.z);
    vec2 q = abs(local) - box.zw * 0.5 + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

float mergeDistance(float a, float b, float softness) {
    float h = clamp(0.5 + 0.5 * (b - a) / softness, 0.0, 1.0);
    return mix(b, a, h) - softness * h * (1.0 - h);
}

void main() {
    vec2 p = qt_TexCoord0 * surfaceSize;
    float pulse = sin(clamp(phase, 0.0, 1.0) * 3.14159265);
    float crest = exp(-pow((qt_TexCoord0.x - phase) * 5.0, 2.0));
    vec2 warped = p;
    warped.y += sin(qt_TexCoord0.x * 15.0 - phase * 9.0) * pulse * 1.8;
    float d;
    if (singleShape > 0.5) {
        d = roundedBox(warped, leftBox, vec4(cornerRadius));
    } else {
        float r = 17.0 * (1.0 - joined);
        float a = roundedBox(warped, leftBox, vec4(r));
        float b = roundedBox(warped, middleBox, vec4(r));
        float c = roundedBox(warped, rightBox, vec4(r));
        float softness = 1.0 + 18.0 * pulse;
        d = mergeDistance(mergeDistance(a, b, softness), c, softness);
        float whole = roundedBox(p, vec4(0.0, 0.0, surfaceSize.x, 34.0), vec4(0.0));
        float overhang = 12.0;
        float leftCorner = max(
            roundedBox(p, vec4(0.0, 34.0, overhang, overhang), vec4(0.0)),
            overhang - length(p - vec2(overhang, 34.0 + overhang)));
        float rightCorner = max(
            roundedBox(p, vec4(surfaceSize.x - overhang, 34.0, overhang, overhang), vec4(0.0)),
            overhang - length(p - vec2(surfaceSize.x - overhang, 34.0 + overhang)));
        whole = min(whole, min(leftCorner, rightCorner));
        d = mix(d, whole, smoothstep(0.8, 1.0, joined));
    }
    float coverage = edgeFeather > 0.0
        ? 1.0 - smoothstep(-edgeFeather, 0.0, d)
        : 1.0 - smoothstep(-0.7, 0.7, d);
    float glint = exp(-abs(d + 2.0) * 0.5) * 0.10 + crest * 0.09;
    vec3 colour = tint.rgb + vec3(0.65, 0.8, 1.0) * glint * pulse;
    float alpha = tint.a * coverage * qt_Opacity;
    fragColor = vec4(colour * alpha, alpha);
}
