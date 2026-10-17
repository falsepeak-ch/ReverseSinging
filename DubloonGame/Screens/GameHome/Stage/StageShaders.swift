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

private extension SKColor {
    var simdRGBA: vector_float4 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return vector_float4(Float(r), Float(g), Float(b), Float(a))
    }
}
