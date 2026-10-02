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

    // ── Low battery ──────────────────────────────────────────
    //
    // Three stages, Config.idle.battery*: a warning, an urgent warning,
    // and a minute's notice before suspending. Each fires once on the
    // way down — `stage` is how far down this discharge has got — and
    // plugging in starts the count over. A shell that only drew the
    // number let the laptop run flat mid-sentence.
    property int stage: 0

    // On battery, as UPower sees it — not inferred from the status
    // text, which says "Not charging" for a laptop plugged in and held
    // at a charge limit.
    readonly property bool draining: present && UPower.onBattery

    onLevelChanged: check()
    onDrainingChanged: check()

    function check() {
        if (!draining) {
            stage = 0;
            suspendCountdown.stop();
            return;
        }

        const i = Config.idle;
        const time = timeToEmpty > 0 ? " — about " + label.replace(" left", "") + " left." : ".";

        if (i.batterySuspend > 0 && level <= i.batterySuspend && stage < 3) {
            stage = 3;
            notify("critical", "Battery at " + level + "%",
                   "Suspending in a minute to keep your work. Plug in to cancel.");
            suspendCountdown.restart();
        } else if (i.batteryUrgent > 0 && level <= i.batteryUrgent && stage < 2) {
            stage = 2;
            notify("critical", "Battery critically low",
                   level + "% remaining" + time + " Plug in soon.");
        } else if (i.batteryWarn > 0 && level <= i.batteryWarn && stage < 1) {
            stage = 1;
            notify("normal", "Battery low", level + "% remaining" + time);
        }
    }

    // Through the notification server — this shell — so it arrives as
    // the island's own popup and stays in the centre's history.
    function notify(urgency, summary, body) {
        // No -i: the card draws the shell's own battery glyph for
        // these (see NoticeFace), sharper than any themed icon here.
        Quickshell.execDetached(["notify-send", "-a", "Battery",
                                 "-u", urgency, summary, body]);
    }

    // Checked again when it fires: plugged in, or charged past the
    // line, and nothing happens.
    Timer {
        id: suspendCountdown
        interval: 60000
        onTriggered: {
            if (root.draining && root.level <= Config.idle.batterySuspend)
                Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    IpcHandler {
        target: "battery"
        function status(): string {
            return root.present
                ? root.level + "% · " + root.label
                : "no battery";
        }
    }
}
