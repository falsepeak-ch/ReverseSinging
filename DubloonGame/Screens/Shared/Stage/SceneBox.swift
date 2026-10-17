//
//  SceneBox.swift
//  DubloonGame
//
//  Keeps one SpriteKit scene for the life of a view.
//

import SpriteKit
import Combine

/// Holds a scene behind `@StateObject`, whose autoclosure runs once.
///
/// `@State private var scene = SomeScene()` looks the same but evaluates `SomeScene()` every
/// time the view's struct is recreated, which on a round is many times a second while the
/// meter moves: a fresh scene, atlas lookups and shaders, thrown away each time.
@MainActor
final class SceneBox<Scene: SKScene>: ObservableObject {
    let scene: Scene

    init(_ scene: Scene) {
        self.scene = scene
    }
}
