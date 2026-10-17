# Voxhop — prototype game art kit

Voxhop is a working name combining voice with playful movement. The art keeps the cyan anime host, petrol outlines, ivory highlights and coral accents, and frames the four voice games as a broadcast party show.

## Included

13 PNG assets: a wordmark, four host expressions, four game icons, a stage background, a blank button, a blank dialogue panel, and a reward sparkle. Open `preview.html` in a browser to inspect expression swaps, idle motion, game reactions and reward effects. All art except the stage has transparency. `manifest.json` records actual dimensions and alpha bounds. `Prompts/` contains generation briefs for further iterations.

## SpriteKit handoff

The `Host.atlas`, `Games.atlas` and `UI.atlas` folders group related textures. Import these into a separate prototype Xcode target when ready, or create Sprite Atlas assets in an asset catalog. Brand and Stage contain standalone images. This delivery has not modified the app or Xcode project, and has not been built or performance-tested in SpriteKit.

Use a single host sprite and swap its texture for facial expressions. The four host canvases are all 1024 × 1536; preserve that common canvas, size and position when switching. Start with a bottom-center anchor `(0.5, 0)` and judge registration visually. The character reaches the lower edge of the canvas, so leave scene-space margin beneath it.

Suggested scene ordering:

| Element | zPosition |
| --- | ---: |
| Stage | 0 |
| Host | 20 |
| Logo | 50 |
| Game controls | 100 |
| Dialogue | 110 |
| Reward particles | 120 |

Keep labels separate from the blank UI artwork so they remain editable and localisable. Give controls their own generously sized hit regions instead of using transparent image bounds. Preserve aspect ratios; the button and panel include transparent canvas padding. They are not prepared as nine-slice textures.

## Starting motion recipe

| Action | Proposed timing |
| --- | --- |
| Blink | Idle → blink for 100 ms → idle; repeat at varied intervals |
| Speaking | Alternate talk and idle, holding each for 140–220 ms |
| Celebration | Delight for 0.8–1.4 seconds, then idle |
| Idle | Gentle 3.4-second vertical bob; about 4 points at preview scale |
| Press | Scale control to 94% for 120 ms, then restore |
| Reward | Emit stars, rise and fade over about 900 ms |

Use texture animation for expressions, node transforms for bobbing and presses, and the star as a particle texture. These are starting values, not audio-driven lip sync. Keep reduced-motion behavior available.

## Prototype limits and next art pass

These are raster concept assets, not vectors or a skeletal rig. Limbs, hair, microphone and clothing are baked into each host frame. Expressions may show small generated differences, so inspect swaps before shipping; use short dissolves if necessary. Separate head, hair, arms and microphone layers would be the next pass for articulated animation. The stage is one flattened image; parallax requires separate foreground and background artwork.

The supplied images are full-resolution masters, not optimized runtime textures. Make scaled runtime copies sized for the final device layout, reduce the sparkle substantially, and profile atlas loading and memory on-device. Estimated uncompressed RGBA image memory is reported in the manifest; GPU packing and mipmaps may add overhead.

## References

- [Apple: SKTextureAtlas](https://developer.apple.com/documentation/spritekit/sktextureatlas)
- [Apple: About texture atlases](https://developer.apple.com/documentation/spritekit/about-texture-atlases)
- [Apple: Animating a sprite by changing its texture](https://developer.apple.com/documentation/spritekit/animating-a-sprite-by-changing-its-texture)
