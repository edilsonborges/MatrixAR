// SceneDelegate.swift
// MatrixAR Scene Delegate

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MatrixARViewController()
        window.makeKeyAndVisible()

        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when the scene is released by the system
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene moves from inactive to active state
        // Re-enable idle timer prevention
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene moves from active to inactive state
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called when the scene transitions from background to foreground
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called when the scene transitions from foreground to background
        // Allow screen to dim when in background
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
