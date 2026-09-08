pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string time:     Qt.formatDateTime(source.date, "hh:mm")
    readonly property string date:     Qt.formatDateTime(source.date, "ddd dd MMM")
    readonly property string timeLong: Qt.formatDateTime(source.date, "hh:mm:ss")
    readonly property string dateLong: Qt.formatDateTime(source.date, "dddd, dd MMMM yyyy")

    readonly property date now: source.date

    SystemClock {
        id: source
        precision: SystemClock.Seconds
    }
}
