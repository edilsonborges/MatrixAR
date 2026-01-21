// PerformanceMonitor.swift
// Monitors and reports performance metrics

import Foundation
import QuartzCore
import UIKit

/// Monitors and reports performance metrics
final class PerformanceMonitor {

    // MARK: - Properties

    private var frameTimestamps: [CFTimeInterval] = []
    private let maxSamples = 60

    private var memoryWarningObserver: NSObjectProtocol?

    /// Current frames per second
    var currentFPS: Double {
        guard frameTimestamps.count >= 2 else { return 0 }

        let duration = frameTimestamps.last! - frameTimestamps.first!
        guard duration > 0 else { return 0 }

        return Double(frameTimestamps.count - 1) / duration
    }

    /// Average frame time in milliseconds
    var averageFrameTime: Double {
        guard frameTimestamps.count >= 2 else { return 0 }

        let duration = frameTimestamps.last! - frameTimestamps.first!
        return (duration / Double(frameTimestamps.count - 1)) * 1000
    }

    /// Current memory usage in MB
    var memoryUsageMB: Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }

    // MARK: - Initialization

    init() {
        setupMemoryWarningObserver()
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Methods

    /// Records a frame timestamp (call each frame)
    func recordFrame() {
        let timestamp = CACurrentMediaTime()
        frameTimestamps.append(timestamp)

        // Keep only recent samples
        if frameTimestamps.count > maxSamples {
            frameTimestamps.removeFirst()
        }
    }

    /// Resets all recorded metrics
    func reset() {
        frameTimestamps.removeAll()
    }

    /// Returns a formatted performance report
    func generateReport() -> String {
        """
        Performance Report
        ------------------
        FPS: \(String(format: "%.1f", currentFPS))
        Frame Time: \(String(format: "%.2f", averageFrameTime)) ms
        Memory: \(String(format: "%.1f", memoryUsageMB)) MB
        """
    }

    // MARK: - Memory Warning

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        print("Memory warning received. Current usage: \(String(format: "%.1f", memoryUsageMB)) MB")
        // Notify relevant components to reduce memory usage
        NotificationCenter.default.post(name: .performanceMemoryWarning, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let performanceMemoryWarning = Notification.Name("performanceMemoryWarning")
}
