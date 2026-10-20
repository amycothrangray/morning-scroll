import DeviceActivity
import ManagedSettings

/// Runs at midnight every day and puts the shields back up until the morning reading is done.
final class MonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Shared.sync()
    }
}
