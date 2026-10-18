//
//  StageShaders.swift
//  DubloonGame
//
//  The stage lighting, drawn on the GPU. SpriteKit compiles these to Metal.
//

import SpriteKit

/// Fragment shaders for the light on the stage. Each node gets its own `SKShader` so its
/// uniforms (colour, strength, phase) are its own.
enum StageShaders {

    /// A spotlight cone hanging from its lamp: narrow at the top of the sprite, wide at the
    /// floor, soft at the edges, with a slow flicker so the light reads as live.
    static func beam(color: SKColor, strength: Float, seed: Float) -> SKShader {
        let shader = SKShader(source: """
        void main() {
            vec2 uv = v_tex_coord;
            float d = 1.0 - uv.y;
            float halfWidth = mix(0.03, 0.5, d);
            float x = abs(uv.x - 0.5);
            float edge = 1.0 - smoothstep(halfWidth * 0.45, halfWidth, x);
            float core = 1.0 - smoothstep(0.0, halfWidth * 0.5, x);
            float fall = pow(1.0 - d, 0.7);
            float flicker = 0.88 + 0.12 * sin(u_time * 2.7 + u_seed * 6.283);
            float dust = 0.92 + 0.08 * sin(uv.y * 40.0 - u_time * 1.3 + u_seed * 3.0);
            float a = (edge * 0.75 + core * 0.35) * fall * flicker * dust * u_strength;
            gl_FragColor = vec4(u_color.rgb * a, a);
        }
        """)
        shader.uniforms = [
            SKUniform(name: "u_color", vectorFloat4: color.simdRGBA),
            SKUniform(name: "u_strength", float: strength),
            SKUniform(name: "u_seed", float: seed),
        ]
        return shader
    }

    /// A pool of light on the floor, breathing slowly.
    static func glow(color: SKColor, strength: Float) -> SKShader {
        let shader = SKShader(source: """
        void main() {
            vec2 p = v_tex_coord - 0.5;
            float r = length(p) * 2.0;
            float pulse = 0.82 + 0.18 * sin(u_time * 1.6);
            float a = pow(1.0 - smoothstep(0.0, 1.0, r), 1.6) * u_strength * pulse;
            gl_FragColor = vec4(u_color.rgb * a, a);
        }
        """)
        shader.uniforms = [
            SKUniform(name: "u_color", vectorFloat4: color.simdRGBA),
            SKUniform(name: "u_strength", float: strength),
        ]
        return shader
    }

    /// A band of light that sweeps across a sprite's texture now and then, as on a game-show
    /// button. Keeps the texture's own alpha, so only the drawn shape shines.
    static func shine() -> SKShader {
        SKShader(source: """
        void main() {
            vec4 c = texture2D(u_texture, v_tex_coord);
            float t = mod(u_time, 3.2) / 1.1;
            float band = v_tex_coord.x + v_tex_coord.y * 0.35 - t * 1.6 + 0.3;
            float s = (1.0 - smoothstep(0.0, 0.12, abs(band))) * 0.45;
            gl_FragColor = vec4(c.rgb + vec3(s) * c.a, c.a);
        }
        """)
    }
}

extension StageShaders {

    /// A game's cabinet: a rounded glass panel with a lit rim and a spark that runs around
    /// it, drawn entirely from a signed-distance rounded rectangle. The sprite's own size sets
    /// the panel's; `u_aspect` is width over height so the corners stay round.
    static func cabinet(rim: SKColor, aspect: Float, seed: Float) -> SKShader {
        let shader = SKShader(source: """
        float roundedBox(vec2 p, vec2 b, float r) {
            vec2 q = abs(p) - b + r;
            return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
        }
        void main() {
            vec2 uv = v_tex_coord - 0.5;
            vec2 p = vec2(uv.x * u_aspect, uv.y);
            vec2 box = vec2(0.5 * u_aspect, 0.5) - 0.03;
            float d = roundedBox(p, box, 0.16);

            // Glass: navy, lighter at the top, with a sheen across the upper third.
            vec3 glass = mix(vec3(0.03, 0.09, 0.14), vec3(0.08, 0.26, 0.36), v_tex_coord.y);
            float sheen = smoothstep(0.62, 0.66, v_tex_coord.y) * (1.0 - smoothstep(0.66, 0.95, v_tex_coord.y)) * 0.12;
            float fill = 1.0 - smoothstep(-0.004, 0.0, d);
            vec3 color = (glass + sheen) * fill;
            float alpha = fill * 0.82;

            // The navy outline, then the lit rim inside it.
            float outline = 1.0 - smoothstep(0.012, 0.02, abs(d - 0.004));
            float rim = 1.0 - smoothstep(0.004, 0.016, abs(d + 0.02));
            float angle = atan(p.y, p.x) / 6.28318 + 0.5;
            float run = fract(angle - u_time * 0.22 + u_seed);
            float spark = pow(1.0 - min(run, 1.0 - run) * 2.0, 18.0);
            float breathe = 0.65 + 0.35 * sin(u_time * 2.2 + u_seed * 6.0);
            vec3 lit = u_rim.rgb * (0.4 + breathe + spark * 1.8);
            color = mix(color, lit, rim);
            alpha = max(alpha, rim);
            color = mix(color, vec3(0.05, 0.13, 0.2), outline);
            alpha = max(alpha, outline);

            // A glow just outside the rim.
            float halo = (1.0 - smoothstep(0.0, 0.03, d)) * step(0.0, d) * 0.5 * breathe;
            color += u_rim.rgb * halo;
            alpha = max(alpha, halo);
            gl_FragColor = vec4(color * alpha, alpha);
        }
        """)
        shader.uniforms = [
            SKUniform(name: "u_rim", vectorFloat4: rim.simdRGBA),
            SKUniform(name: "u_aspect", float: aspect),
            SKUniform(name: "u_seed", float: seed),
        ]
        return shader
    }

    /// Repaints the kit's cyan button in another colour, keeping its navy outline, its pale
    /// highlight and its shading, with the same shine sweeping across.
    static func tintedShine(_ tint: SKColor) -> SKShader {
        let shader = SKShader(source: """
        void main() {
            vec4 c = texture2D(u_texture, v_tex_coord);
            if (c.a > 0.0) {
                vec3 rgb = c.rgb / c.a;
                float maxc = max(rgb.r, max(rgb.g, rgb.b));
                float minc = min(rgb.r, min(rgb.g, rgb.b));
                float sat = maxc - minc;
                // The kit's cyan family: saturated and bright. Outline and highlight stay.
                float cyanness = smoothstep(0.18, 0.35, sat) * smoothstep(0.25, 0.45, maxc);
                vec3 painted = u_tint.rgb * (maxc / 0.96);
                rgb = mix(rgb, painted, cyanness);
                c = vec4(rgb * c.a, c.a);
            }
            float t = mod(u_time, 3.2) / 1.1;
            float band = v_tex_coord.x + v_tex_coord.y * 0.35 - t * 1.6 + 0.3;
            float s = (1.0 - smoothstep(0.0, 0.12, abs(band))) * 0.45;
            gl_FragColor = vec4(c.rgb + vec3(s) * c.a, c.a);
        }
        """)
        shader.uniforms = [SKUniform(name: "u_tint", vectorFloat4: tint.simdRGBA)]
        return shader
    }
}

private extension SKColor {
    var simdRGBA: vector_float4 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return vector_float4(Float(r), Float(g), Float(b), Float(a))
    }
}
