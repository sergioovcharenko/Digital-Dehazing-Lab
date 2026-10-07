#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float dehazeMode;
    float dehazeStrength;
    vec2 texel;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float dark3(vec3 c) { return min(c.r, min(c.g, c.b)); }

vec3 sampleBlur(vec2 uv) {
    vec2 t = ubuf.texel * 2.0;
    vec3 c = texture(source, uv).rgb * 0.28;
    c += texture(source, uv + vec2(t.x, 0.0)).rgb * 0.12;
    c += texture(source, uv - vec2(t.x, 0.0)).rgb * 0.12;
    c += texture(source, uv + vec2(0.0, t.y)).rgb * 0.12;
    c += texture(source, uv - vec2(0.0, t.y)).rgb * 0.12;
    c += texture(source, uv + t).rgb * 0.06;
    c += texture(source, uv - t).rgb * 0.06;
    c += texture(source, uv + vec2(t.x, -t.y)).rgb * 0.06;
    c += texture(source, uv + vec2(-t.x, t.y)).rgb * 0.06;
    return c;
}

float localDark(vec2 uv) {
    vec2 t = ubuf.texel * 2.5;
    float d = dark3(texture(source, uv).rgb);
    d = min(d, dark3(texture(source, uv + vec2(t.x,0)).rgb));
    d = min(d, dark3(texture(source, uv - vec2(t.x,0)).rgb));
    d = min(d, dark3(texture(source, uv + vec2(0,t.y)).rgb));
    d = min(d, dark3(texture(source, uv - vec2(0,t.y)).rgb));
    return d;
}

vec3 dcpRecover(vec3 c, float darkv, float omega, float floorT) {
    vec3 A = vec3(0.92, 0.94, 0.96);
    float t = clamp(1.0 - omega * darkv, floorT, 1.0);
    return clamp((c - A) / t + A, 0.0, 1.0);
}

vec3 applyMode(vec2 uv, vec3 c) {
    float s = clamp(ubuf.dehazeStrength, 0.0, 1.0);
    vec3 blur = sampleBlur(uv);
    float y = luma(c);
    float d = localDark(uv);
    vec3 outc = c;

    if (ubuf.dehazeMode < 1.5) { // ADAPTIVE
        float haze = clamp(d * 1.25 + (1.0 - abs(y - 0.5) * 2.0) * 0.15, 0.0, 1.0);
        vec3 clear = dcpRecover(c, d, 0.68 + 0.22 * s, 0.32 - 0.08 * s);
        vec3 detail = c + (c - blur) * (0.35 + 0.65 * s);
        outc = mix(c, mix(clear, detail, 0.35), clamp(haze * (0.45 + 0.55*s), 0.0, 1.0));
    } else if (ubuf.dehazeMode < 2.5) { // FAST DCP
        outc = dcpRecover(c, d, 0.62 + 0.18*s, 0.36 - 0.06*s);
    } else if (ubuf.dehazeMode < 3.5) { // LIVE DCP
        vec3 r = dcpRecover(c, d, 0.70 + 0.18*s, 0.32 - 0.07*s);
        outc = mix(r, r + (r - blur) * 0.22*s, 0.75);
    } else if (ubuf.dehazeMode < 4.5) { // CLASSIC
        float contrast = 1.08 + 0.22*s;
        outc = (c - 0.5) * contrast + 0.5;
        outc = pow(max(outc, vec3(0.0)), vec3(0.96 - 0.08*s));
    } else if (ubuf.dehazeMode < 5.5) { // DCP BALANCED
        outc = dcpRecover(c, d, 0.78 + 0.12*s, 0.28 - 0.05*s);
    } else if (ubuf.dehazeMode < 6.5) { // DCP STRONG
        outc = dcpRecover(c, d, 0.88 + 0.08*s, 0.20 - 0.05*s);
        outc += (outc - blur) * (0.25 + 0.30*s);
    } else if (ubuf.dehazeMode < 7.5) { // CAP
        float mx = max(c.r, max(c.g, c.b));
        float mn = min(c.r, min(c.g, c.b));
        float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
        float depth = max(0.0, 0.121779 + 0.959710*mx - 0.780245*sat);
        float t = clamp(exp(-(0.70 + 0.65*s) * depth), 0.25, 1.0);
        vec3 A = vec3(0.94);
        outc = (c - A) / t + A;
    } else if (ubuf.dehazeMode < 8.5) { // CLAHE-like local contrast
        float ly = luma(blur);
        float gain = 1.0 + (0.45 + 0.75*s) * (0.55 - ly);
        outc = c * gain + (c - blur) * (0.30 + 0.55*s);
    } else { // RETINEX-like
        vec3 illum = max(blur, vec3(0.035));
        vec3 ret = log(max(c, vec3(0.003))) - log(illum);
        ret = ret * (0.22 + 0.10*s) + 0.52;
        outc = mix(c, ret, 0.55 + 0.30*s);
    }

    // highlight/sky protection and saturation guard
    float hi = smoothstep(0.76, 1.0, y);
    outc = mix(outc, c, hi * (0.35 + 0.25*(1.0-s)));
    float outY = luma(outc);
    outc = mix(vec3(outY), outc, 0.93);
    return clamp(outc, 0.0, 1.0);
}

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    vec3 c = applyMode(qt_TexCoord0, src.rgb);
    fragColor = vec4(c, src.a) * ubuf.qt_Opacity;
}
