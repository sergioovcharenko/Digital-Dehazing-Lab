varying highp vec2 qt_TexCoord0;
uniform sampler2D source;
uniform lowp float qt_Opacity;
uniform highp float strength;
uniform highp float mode;
uniform highp float autoBlend;

highp float lum(highp vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

highp float darkAt(highp vec2 uv) {
    highp vec2 d = vec2(0.0017, 0.0017);
    highp vec3 c0 = texture2D(source, uv).rgb;
    highp vec3 c1 = texture2D(source, uv + vec2(d.x, 0.0)).rgb;
    highp vec3 c2 = texture2D(source, uv - vec2(d.x, 0.0)).rgb;
    highp vec3 c3 = texture2D(source, uv + vec2(0.0, d.y)).rgb;
    highp vec3 c4 = texture2D(source, uv - vec2(0.0, d.y)).rgb;
    highp float m0 = min(c0.r, min(c0.g, c0.b));
    highp float m1 = min(c1.r, min(c1.g, c1.b));
    highp float m2 = min(c2.r, min(c2.g, c2.b));
    highp float m3 = min(c3.r, min(c3.g, c3.b));
    highp float m4 = min(c4.r, min(c4.g, c4.b));
    return min(m0, min(m1, min(m2, min(m3, m4))));
}

highp vec3 recoverDcp(highp vec3 c, highp float power, highp float floorT) {
    highp float dc = darkAt(qt_TexCoord0);
    highp float t = clamp(1.0 - power * dc, floorT, 1.0);
    highp vec3 A = vec3(0.94, 0.95, 0.97);
    return clamp((c - A) / t + A, 0.0, 1.0);
}

void main() {
    highp vec2 uv = qt_TexCoord0;
    highp vec3 c = texture2D(source, uv).rgb;
    highp vec3 outc = c;
    highp float s = clamp(strength, 0.0, 1.0);
    // Experimental adaptive strength, estimated from each frame's local haze.
    if (autoBlend > 0.5) {
        highp vec2 d = vec2(0.005, 0.005);
        highp float l0 = lum(c);
        highp float l1 = lum(texture2D(source, clamp(uv+vec2(d.x,0.0), 0.0, 1.0)).rgb);
        highp float l2 = lum(texture2D(source, clamp(uv-vec2(d.x,0.0), 0.0, 1.0)).rgb);
        highp float l3 = lum(texture2D(source, clamp(uv+vec2(0.0,d.y), 0.0, 1.0)).rgb);
        highp float l4 = lum(texture2D(source, clamp(uv-vec2(0.0,d.y), 0.0, 1.0)).rgb);
        highp float contrast = max(max(abs(l1-l0),abs(l2-l0)),max(abs(l3-l0),abs(l4-l0)));
        highp float fog = clamp((darkAt(uv)-0.12)*2.2 - contrast*2.0, 0.0, 1.0);
        s = mix(0.20, 0.92, smoothstep(0.08, 0.72, fog));
    }
    highp float y = lum(c);
    highp float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    highp float sky = smoothstep(0.72, 0.98, y) * (1.0 - smoothstep(0.10, 0.35, sat));
    highp float guard = 1.0 - 0.72 * sky;

    if (mode < 1.5) {
        highp vec3 dcp = recoverDcp(c, 0.72 + 0.20*s, 0.30 - 0.08*s);
        highp vec3 ctr = clamp((c - 0.5) * (1.08 + 0.22*s) + 0.5, 0.0, 1.0);
        outc = mix(c, mix(ctr, dcp, 0.60), (0.52 + 0.38*s) * guard);
    } else if (mode < 2.5) {
        outc = mix(c, recoverDcp(c, 0.70 + 0.15*s, 0.34 - 0.05*s), (0.55 + 0.30*s) * guard);
    } else if (mode < 3.5) {
        outc = mix(c, recoverDcp(c, 0.78 + 0.16*s, 0.30 - 0.05*s), (0.60 + 0.30*s) * guard);
    } else if (mode < 4.5) {
        highp vec3 classic = clamp((c - vec3(0.46)) * (1.10 + 0.24*s) + vec3(0.46), 0.0, 1.0);
        classic = pow(classic, vec3(0.94));
        outc = mix(c, classic, (0.55 + 0.34*s) * guard);
    } else if (mode < 5.5) {
        outc = mix(c, recoverDcp(c, 0.82 + 0.12*s, 0.27 - 0.04*s), (0.65 + 0.28*s) * guard);
    } else if (mode < 6.5) {
        outc = mix(c, recoverDcp(c, 0.91 + 0.07*s, 0.20 - 0.03*s), (0.75 + 0.22*s) * guard);
    } else if (mode < 7.5) {
        highp float mx = max(c.r, max(c.g, c.b));
        highp float mn = min(c.r, min(c.g, c.b));
        highp float saturation = mx > 0.001 ? (mx - mn) / mx : 0.0;
        highp float depth = max(0.0, 0.121779 + 0.959710 * mx - 0.780245 * saturation);
        highp float t = clamp(exp(-(0.85 + 0.45*s) * depth), 0.28, 1.0);
        highp vec3 A = vec3(0.94, 0.95, 0.97);
        highp vec3 cap = clamp((c - A) / t + A, 0.0, 1.0);
        outc = mix(c, cap, (0.58 + 0.32*s) * guard);
    } else if (mode < 8.5) {
        highp vec3 local = clamp((c - vec3(y)) * (1.20 + 0.45*s) + vec3(smoothstep(0.0, 1.0, y)), 0.0, 1.0);
        outc = mix(c, local, (0.50 + 0.38*s) * guard);
    } else {
        highp vec3 ret = log(vec3(1.0) + (4.0 + 3.0*s) * c) / log(5.0 + 3.0*s);
        ret = clamp((ret - 0.5) * (1.05 + 0.18*s) + 0.5, 0.0, 1.0);
        outc = mix(c, ret, (0.48 + 0.38*s) * guard);
    }

    highp float oy = lum(outc);
    if (oy > 0.94) {
        outc *= 0.94 / max(oy, 0.001);
    }
    gl_FragColor = vec4(outc, 1.0) * qt_Opacity;
}
