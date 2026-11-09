#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 darkColor;
    vec4 brightColor;
    float hoverBoost;
    float contrast;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 sampleColor = texture(source, qt_TexCoord0);
    vec3 rgb = sampleColor.a > 0.0001 ? sampleColor.rgb / sampleColor.a : vec3(0.0);
    float luminance = clamp(dot(rgb, vec3(0.2126, 0.7152, 0.0722)) + hoverBoost, 0.0, 1.0);
    float tone = mix(luminance, smoothstep(0.0, 1.0, luminance), contrast);
    vec3 colour = mix(darkColor.rgb, brightColor.rgb, tone);
    float alpha = sampleColor.a * qt_Opacity;
    fragColor = vec4(colour * alpha, alpha);
}
