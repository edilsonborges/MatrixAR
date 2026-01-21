// AppDelegate.swift
// MatrixAR Application Delegate

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure app appearance
        configureAppearance()

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when the user discards a scene session
    }

    // MARK: - Configuration

    private func configureAppearance() {
        // Configure global UI appearance if needed
        // For example, set navigation bar appearance, tint colors, etc.

        // Prevent screen dimming during AR experience
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
