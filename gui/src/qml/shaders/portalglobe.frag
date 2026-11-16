#version 440
// Procedural "particle globe" for the home and connection screens.
// One full-screen pass draws the background, the particle sphere (several
// concentric shells of spherical-Fibonacci points), the rim, the pulsing corona
// and, for the connection hand-off, a growing transparent hole that reveals
// the video rendered underneath the QML overlay.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in px
    vec2 center;      // globe centre in px
    float radius;     // globe radius in px
    float time;       // seconds, for twinkle
    float spin;       // globe rotation, radians
    float pulse;      // corona pulse phase, radians
    float energy;     // 0 idle .. 1 connecting
    float reveal;     // 0 closed .. 1 hole covers the whole item
    float backdrop;   // 1 = draw the background, 0 = only the globe
};

const float PI = 3.14159265;
const float PHI = 1.61803399;
const int SHELLS = 5;

// Float-only hashes (Dave Hoskins) so the shader also bakes for GLSL ES 2 targets.
float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash31(vec3 p3)
{
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

float noise3(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash31(i), n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0)), n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0)), n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0)), n111 = hash31(i + vec3(1.0, 1.0, 1.0));
    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p)
{
    return 0.6 * noise3(p) + 0.3 * noise3(p * 2.03 + 7.1) + 0.1 * noise3(p * 4.11 + 3.7);
}

// Point i of an n-point spherical Fibonacci set.
vec3 sfPoint(float i, float n)
{
    float phi = 2.0 * PI * fract(i * (PHI - 1.0));
    float cosTheta = 1.0 - (2.0 * i + 1.0) / n;
    float sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta));
    return vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Index of the spherical Fibonacci point nearest to unit vector p
// (Keinert et al., "Spherical Fibonacci Mapping", 2015).
float inverseSF(vec3 p, float n)
{
    float m = 1.0 - 1.0 / n;
    float phi = min(atan(p.y, p.x), PI);
    float cosTheta = p.z;
    float k = max(2.0, floor(log(n * PI * sqrt(5.0) * (1.0 - cosTheta * cosTheta)) / log(PHI * PHI)));
    float Fk = pow(PHI, k) / sqrt(5.0);
    vec2 F = vec2(round(Fk), round(Fk * PHI));
    vec2 ka = 2.0 * F / n;
    vec2 kb = 2.0 * PI * (fract((F + 1.0) * PHI) - (PHI - 1.0));
    mat2 iB = mat2(ka.y, -ka.x, kb.y, -kb.x) / (ka.y * kb.x - ka.x * kb.y);
    vec2 c = floor(iB * vec2(phi, cosTheta - m));
    float best = 8.0;
    float j = 0.0;
    for (int s = 0; s < 4; ++s) {
        vec2 o = vec2(float(s - 2 * (s / 2)), float(s / 2));
        float i = clamp(dot(F, o + c), 0.0, n - 1.0);
        vec3 q = sfPoint(i, n);
        float d = dot(q - p, q - p);
        if (d < best) { best = d; j = i; }
    }
    return j;
}

mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }

void main()
{
    vec2 px = qt_TexCoord0 * size;
    vec2 p = (px - center) / radius;
    p.y = -p.y;
    // During the reveal the globe also rushes towards the viewer.
    float holeSpace = length(p);
    p /= 1.0 + 1.8 * reveal * reveal;
    float r = length(p);
    float pxUnit = 1.0 / radius;            // one pixel in globe units
    float breathe = 0.5 + 0.5 * sin(pulse);

    // Background: near-black top fading into a soft grey-violet floor.
    vec2 uv = qt_TexCoord0;
    vec3 col = mix(vec3(0.016, 0.020, 0.035), vec3(0.060, 0.070, 0.100), smoothstep(0.15, 1.0, uv.y));
    col += vec3(0.0, 0.025, 0.065) * smoothstep(0.6, 1.0, uv.y) * (1.0 - abs(uv.x - 0.5));
    col *= backdrop;
    float alpha = backdrop;

    // Ambient violet light thrown by the globe into the room.
    float spill = exp(-max(r - 1.0, 0.0) * 1.35) * (0.10 + 0.05 * breathe + 0.10 * energy);
    col += vec3(0.0, 0.12, 0.40) * spill;

    // Corona: tight hot rim, wide breathing glow, and outward ripples while connecting.
    float outside = max(r - 1.0, 0.0);
    float corona = exp(-outside * 9.0) * (0.55 + 0.25 * breathe + 0.45 * energy)
                 + exp(-outside * 3.2) * (0.16 + 0.10 * breathe + 0.20 * energy);
    float wave = fract(pulse / (2.0 * PI));
    float ripple = exp(-pow((r - (1.0 + wave * 0.55)) / 0.035, 2.0)) * (1.0 - wave) * (1.0 - wave) * energy * 0.55;
    vec3 coronaCol = mix(vec3(0.0, 0.25, 0.72), vec3(0.10, 0.42, 0.90), breathe);
    col += coronaCol * (corona + ripple) * step(1.0, r);
    alpha = max(alpha, clamp((corona + ripple + spill) * 1.2, 0.0, 1.0) * step(1.0, r));

    if (r < 1.0 + 1.5 * pxUnit) {
        float edgeAA = smoothstep(1.0 + 1.5 * pxUnit, 1.0 - 1.5 * pxUnit, r);
        float zFront = sqrt(max(0.0, 1.0 - r * r));

        // Body: deep indigo, brighter towards the limb.
        vec3 body = mix(vec3(0.0, 0.022, 0.10), vec3(0.0, 0.075, 0.25), pow(r, 2.5));
        mat3 toObject = rotY(-spin) * rotX(-0.32);
        mat3 toView = rotX(0.32) * rotY(spin);
        float haze = fbm(toObject * vec3(p, zFront) * 2.4 + vec3(0.0, time * 0.015, 0.0));
        body += vec3(0.0, 0.07, 0.20) * smoothstep(0.45, 0.9, haze) * 0.8;
        body += vec3(0.18, 0.50, 0.92) * (exp(-pow((1.0 - r) / 0.018, 2.0)) * (0.65 + 0.35 * breathe + 0.4 * energy)
                                         + smoothstep(0.80, 1.0, r) * 0.10);

        // Particles: shells from the surface inwards; front and back intersections.
        // Dense layer = small dots; sparse layer = bright stars with a halo. The halo must
        // stay inside the star's lookup cell, hence the separate low-count set.
        vec3 stars = vec3(0.0);
        float sizeScale = radius / 300.0;
        for (int k = 0; k < SHELLS; ++k) {
            float s = 1.0 - float(k) * 0.16;
            if (r >= s)
                continue;
            float z = sqrt(s * s - r * r);
            // Fade each shell where it is seen edge-on, otherwise its limb reads as a ring.
            float limb = smoothstep(0.0, 0.45, z / s);
            mat3 shellTwist = rotY(float(k) * 1.37) * rotX(float(k) * 0.71);
            for (int layer = 0; layer < 2; ++layer) {
                bool bright = layer == 1;
                float n = bright ? floor(46.0 * s * s + 14.0) : floor(1500.0 * s * s + 260.0);
                for (int side = 0; side < 2; ++side) {
                    vec3 v = vec3(p, side == 0 ? z : -z);
                    vec3 o = shellTwist * (toObject * v) / s;
                    float idx = inverseSF(o, n);
                    float seed = idx + float(k) * 7919.0 + (bright ? 50021.0 : 0.0);
                    float h1 = hash11(seed), h2 = hash11(seed * 1.37 + 0.37), h3 = hash11(seed * 0.71 + 0.71), h4 = hash11(seed * 2.13 + 0.13);
                    vec3 q = sfPoint(idx, n);
                    q = normalize(q + (vec3(h2, h3, h4) - 0.5) * (bright ? 1.2 : 2.6) / sqrt(n));
                    // Cluster particles into drifting "continents" and leave dark gaps between them.
                    float cluster = fbm(q * 2.1 + float(k) * 3.3);
                    float density = bright ? 0.55 * smoothstep(0.35, 0.6, cluster) + 0.05
                                           : smoothstep(0.38, 0.70, cluster) * 0.9 + 0.08;
                    if (h1 > density)
                        continue;
                    vec3 sv = toView * (transpose(shellTwist) * q) * s;
                    float dpx = length(sv.xy - p) * radius;
                    float sizePx = (bright ? mix(1.5, 2.6, h3) : mix(0.55, 1.25, h3)) * sizeScale;
                    float twinkle = 0.62 + 0.38 * sin(time * (1.2 + h2 * 2.6) + h3 * 6.2831);
                    float depth = mix(0.22, 1.0, sv.z * 0.5 + 0.5);
                    float core = smoothstep(sizePx + 0.9, max(sizePx - 0.6, 0.0), dpx);
                    float glowR = sizePx * (bright ? 4.0 : 1.8);
                    float glow = exp(-dpx * dpx / (glowR * glowR)) * (bright ? 0.6 : 0.2);
                    vec3 tint = bright ? mix(vec3(0.55, 0.76, 1.0), vec3(0.86, 0.94, 1.0), h2)
                                       : mix(vec3(0.03, 0.28, 0.90), vec3(0.12, 0.42, 0.96), h2);
                    stars += tint * (core + glow) * twinkle * depth * limb * (1.0 + 0.5 * energy);
                }
            }
        }
        body += stars;
        col = mix(col, body, edgeAA);
        alpha = max(alpha, edgeAA);
    }

    // Reveal: a hole grows from the globe centre, edged by a short-lived bright ring.
    if (reveal > 0.0) {
        vec2 c0 = center / radius, c1 = (size - center) / radius;
        float maxR = length(vec2(max(c0.x, c1.x), max(c0.y, c1.y))) + 0.05;
        float holeR = reveal * maxR;
        float soft = 0.015 + 0.06 * reveal;
        float keep = smoothstep(holeR, holeR + soft, holeSpace);
        float ring = exp(-pow((holeSpace - holeR - soft * 0.5) / (0.02 + 0.03 * reveal), 2.0)) * (1.0 - reveal) * smoothstep(0.0, 0.05, reveal);
        col = col * keep + vec3(0.45, 0.70, 0.98) * ring;
        alpha = alpha * keep + ring * 0.9;
    }

    alpha = clamp(alpha, 0.0, 1.0);
    // Premultiplied output: colour is already weighted by coverage where alpha < 1.
    fragColor = vec4(min(col, vec3(alpha + 0.001)), alpha) * qt_Opacity;
}
