pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

// The battery, from UPower.
//
// UPower already watches the battery and says when anything changes,
// so this reads its answer instead of asking the kernel itself. It used
// to: a shell script every twenty seconds, which was sh, ls, head and
// four cats — eight processes a minute's worth of them, for five
// numbers that had usually not moved.

Singleton {
    id: root

    // The combined device UPower keeps for "the battery", however many
    // packs the machine has. Not a laptop battery on a desktop, which
    // is what `present` asks.
    readonly property var device: UPower.displayDevice

    readonly property bool present:
        !!device && device.ready && device.isLaptopBattery && device.isPresent

    // percentage is a fraction here, not a percent.
    readonly property int level: present ? Math.round(device.percentage * 100) : 0

    // The words sysfs uses, which is what everything below was written
    // against.
    readonly property string status: {
        if (!present) return "Unknown";
        switch (device.state) {
            case UPowerDeviceState.Charging:         return "Charging";
            case UPowerDeviceState.Discharging:
            case UPowerDeviceState.PendingDischarge:
            case UPowerDeviceState.Empty:            return "Discharging";
            case UPowerDeviceState.FullyCharged:     return "Full";
            case UPowerDeviceState.PendingCharge:    return "Not charging";
            default:                                 return "Unknown";
        }
    }

    // Minutes, 0 when unknown. UPower counts seconds.
    readonly property int timeToEmpty:
        present ? Math.round(device.timeToEmpty / 60) : 0

    readonly property bool charging: status === "Charging"
    readonly property bool full: status === "Full" || (charging && level >= 99)
    readonly property bool low: !charging && level <= 20
    readonly property bool critical: !charging && level <= 10

    readonly property string icon:
        charging ? Icons.batteryCharging
        : level > 80 ? Icons.batteryFull
        : level > 60 ? Icons.batteryHigh
        : level > 40 ? Icons.batteryHalf
        : level > 20 ? Icons.batteryLow
        : Icons.batteryEmpty

    readonly property string label: {
        if (!present) return "No battery";
        if (full) return "Full";
        if (charging) return "Charging";
        if (timeToEmpty > 0) {
            const h = Math.floor(timeToEmpty / 60);
            const m = timeToEmpty % 60;
            return h > 0 ? h + "h " + m + "m left" : m + "m left";
        }
        return "On battery";
    }

    // Nothing to ask for — UPower pushes every change. Kept because
    // shell.qml calls it at startup to bring the singleton up, the same
    // as every other service.
    function refresh() {}

    IpcHandler {
        target: "battery"
        function status(): string {
            return root.present
                ? root.level + "% · " + root.label
                : "no battery";
        }
    }
}
