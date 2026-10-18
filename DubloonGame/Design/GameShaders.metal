//
//  GameShaders.metal
//  DubloonGame
//
//  The game's SwiftUI effects, written for the GPU: the shine across a button, gold foil on
//  a star, a CRT on the show's screens, the wobble on a winning score. Applied from Swift in
//  GameEffects.swift through SwiftUI's shader modifiers.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A band of light that sweeps across now and then, like the gloss on a game-show button.
/// Only lights what is drawn: the view's own alpha keeps it inside the shape.
[[ stitchable ]] half4 gameShine(float2 position, half4 color, float2 size, float time, float strength) {
    float2 uv = position / max(size, float2(1.0));
    float t = fmod(time, 3.4) / 1.2;
    float band = uv.x + uv.y * 0.35 - t * 1.7 + 0.35;
    float glint = (1.0 - smoothstep(0.0, 0.10, abs(band))) * strength;
    return half4(color.rgb + half3(glint) * color.a, color.a);
}

/// Gold foil: a slow rainbow sheen over the bright parts of the art and a white glint that
/// runs through it, as on a trading-card star. Dark outlines stay as they are.
[[ stitchable ]] half4 gameFoil(float2 position, half4 color, float2 size, float time, float strength) {
    if (color.a < 0.01h) { return color; }
    float2 uv = position / max(size, float2(1.0));
    float3 rgb = float3(color.rgb) / max(float(color.a), 0.001);
    float lum = dot(rgb, float3(0.299, 0.587, 0.114));
    float phase = uv.x * 1.6 + uv.y * 1.1 - time * 0.45;
    float3 rainbow = 0.5 + 0.5 * cos(6.28318 * (phase + float3(0.0, 0.33, 0.67)));
    float bright = smoothstep(0.35, 0.85, lum);
    float3 tinted = mix(rgb, rgb * (0.75 + 0.5 * rainbow), bright * 0.55 * strength);
    float band = uv.x - uv.y * 0.5 - fmod(time * 0.6, 2.4) + 0.6;
    float glint = (1.0 - smoothstep(0.0, 0.08, abs(band))) * bright * strength;
    tinted += glint;
    return half4(half3(tinted) * color.a, color.a);
}

/// The show's screens: scanlines, a rolling refresh bar, a little barrel bulge and colour
/// fringing at the edges, darkened corners. `intensity` 0 leaves the layer untouched.
[[ stitchable ]] half4 gameCRT(float2 position, SwiftUI::Layer layer, float2 size, float time, float intensity) {
    float2 uv = position / max(size, float2(1.0));
    float2 c = uv * 2.0 - 1.0;
    float2 bent = c * (1.0 + 0.035 * intensity * dot(c, c));
    float2 p = (bent * 0.5 + 0.5) * size;
    if (p.x < 0.0 || p.y < 0.0 || p.x > size.x || p.y > size.y) {
        return half4(0.0h, 0.0h, 0.0h, 1.0h);
    }

    float split = 1.4 * intensity * (0.4 + length(c));
    half4 base = layer.sample(p);
    half r = layer.sample(p + float2(split, 0.0)).r;
    half b = layer.sample(p - float2(split, 0.0)).b;
    half4 col = half4(r, base.g, b, base.a);

    float scan = 0.84 + 0.16 * sin(position.y * 2.1);
    float roll = 1.0 + 0.07 * (1.0 - smoothstep(0.0, 0.08, abs(fract(uv.y - time * 0.18) - 0.5)));
    float flicker = 0.985 + 0.015 * sin(time * 47.0);
    float vignette = 1.0 - 0.28 * dot(c, c);
    float shade = mix(1.0, scan * roll * flicker * vignette, intensity);
    col.rgb *= half(shade);
    return col;
}

/// A jelly wobble, for a number that has just landed big.
[[ stitchable ]] float2 gameWobble(float2 position, float2 size, float time, float amount) {
    float2 uv = position / max(size, float2(1.0));
    return position + float2(
        sin(uv.y * 6.28318 + time * 9.0) * amount,
        cos(uv.x * 6.28318 + time * 7.0) * amount * 0.6
    );
}

/// A soft pulse of light from the centre, for a panel that is "on air".
[[ stitchable ]] half4 gameGlowPulse(float2 position, half4 color, float2 size, float time, half4 tint, float strength) {
    float2 uv = position / max(size, float2(1.0));
    float r = length(uv - 0.5) * 2.0;
    float pulse = 0.5 + 0.5 * sin(time * 4.0);
    float a = (1.0 - smoothstep(0.0, 1.0, r)) * strength * (0.6 + 0.4 * pulse);
    return half4(color.rgb + tint.rgb * half(a) * color.a, color.a);
}
