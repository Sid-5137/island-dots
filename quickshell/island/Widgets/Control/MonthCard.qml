import QtQuick

import "root:/Services"

// The month, and today's events under it.
//
// This is the same calendar the control centre always had, with one
// change: it measures itself against the card it is given rather than
// against a column of hard-coded 38px cells. It has to, now that the
// card is something you can drag to a different size — and it removes
// the arithmetic in ControlMode that used to derive the panel's height
// from the number of weeks in the month on screen.

Item {
    id: root

    property int monthOffset: 0

    readonly property var shown: {
        const d = new Date(Clock.now);
        d.setDate(1);
        d.setMonth(d.getMonth() + monthOffset);
        return d;
    }

    readonly property int daysInMonth:
        new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    // Monday-first, so Sunday shifts from 0 to 6.
    readonly property int firstWeekday:
        (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7

    readonly property int weeks:
        Math.ceil((firstWeekday + daysInMonth) / 7)

    readonly property var events:
        Calendar.available && Calendar.today ? Calendar.today.slice(0, 2) : []

    Surface { anchors.fill: parent }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padRow
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.Bold
            font.letterSpacing: 0.4
            renderType: Text.NativeRendering
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [{ g: "‹", d: -1 }, { g: "›", d: 1 }]

                Rectangle {
                    required property var modelData
                    width: 22; height: 22; radius: Theme.radiusSmall
                    color: nav.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.g
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: nav
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthOffset += parent.modelData.d
                    }
                }
            }
        }
    }

    // The grid claims what is left after the header and the events,
    // and divides it. Cells are square-ish rather than square: a wide
    // card should not leave a gutter down each side just because
    // seven columns did not divide evenly into it.
    Item {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        anchors.top: header.bottom
        anchors.bottom: events.visible ? events.top : parent.bottom
        anchors.bottomMargin: 6

        readonly property real cellW: width / 7
        readonly property real cellH:
            Math.max(14, (height - 16) / root.weeks)

        Row {
            id: weekdays
            width: parent.width
            height: 16

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]

                Text {
                    required property var modelData
                    width: grid.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    renderType: Text.NativeRendering
                }
            }
        }

        Grid {
            anchors.top: weekdays.bottom
            columns: 7

            Repeater {
                model: root.firstWeekday + root.daysInMonth

                Item {
                    required property int index
                    readonly property int day: index - root.firstWeekday + 1
                    readonly property bool isToday:
                        root.monthOffset === 0 && day === Clock.now.getDate()

                    width: grid.cellW
                    height: grid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 4
                        height: width
                        radius: Math.round(width * 0.3)
                        color: parent.isToday ? Theme.primary : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.day > 0
                        text: parent.day
                        color: parent.isToday ? Theme.textOnPrimary : Theme.text
                        font.family: Theme.fontFamily
                        font.weight: parent.isToday ? Font.Bold : Font.DemiBold
                        font.pixelSize: Math.min(
                            Theme.fontSizeSmall + 1,
                            Math.round(grid.cellH * 0.52))
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }

    // Today, under the month. Absent entirely when khal is not
    // installed, rather than showing an empty list — and absent again
    // when the card has been made too short to hold both.
    Column {
        id: events

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        anchors.bottomMargin: 10
        spacing: 3

        visible: root.events.length > 0
                 && root.height > 60 + root.weeks * 22 + root.events.length * 18

        Repeater {
            model: root.events

            Row {
                required property var modelData
                spacing: 7

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 11; radius: width / 2
                    color: Theme.primary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: modelData.allDay ? "all day" : modelData.time
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: events.width - 57
                    text: modelData.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
