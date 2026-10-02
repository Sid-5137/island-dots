pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // One switch for every clock the shell draws — the pill, the lock
    // screen, the control centre's card, an event's start time — so no
    // two of them can disagree. Settings > Island > Clock.
    readonly property bool twelveHour: Config.island.clockFormat === "12h"

    readonly property string time:
        Qt.formatDateTime(source.date, twelveHour ? "h:mm AP" : "hh:mm")
    readonly property string timeLong:
        Qt.formatDateTime(source.date, twelveHour ? "h:mm:ss AP" : "hh:mm:ss")

    // The lock screen's: display type, where AM/PM at that size would be
    // the loudest thing on the screen and tell you nothing a glance at
    // the light outside doesn't. The way a phone's lock screen does it.
    readonly property string timeBare:
        Qt.formatDateTime(source.date, twelveHour ? "h:mm" : "hh:mm")

    readonly property string date:     Qt.formatDateTime(source.date, "ddd dd MMM")
    readonly property string dateLong: Qt.formatDateTime(source.date, "dddd, dd MMMM yyyy")

    // An "HH:MM" from elsewhere — the calendar hands its times over as
    // text — read the same way as the rest.
    function formatHM(hm) {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(hm || "").trim());
        if (!m || !twelveHour) return hm;
        const h = parseInt(m[1]);
        return ((h % 12) || 12) + ":" + m[2] + (h < 12 ? " AM" : " PM");
    }

    readonly property date now: source.date

    SystemClock {
        id: source
        precision: SystemClock.Seconds
    }
}
