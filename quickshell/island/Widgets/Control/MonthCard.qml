import QtQuick

import "root:/Services"

// The month, and today's events under it.
//
// The card is portrait — three cells across and five down where the
// shipped layout puts it — and a month is not. Seven columns by five
// rows is a landscape shape, so a month drawn in this card has height
// to give away, and the obvious places to put it are all wrong.
// Dividing the card's height by the number of weeks put fourteen
// pixels between one week and the next against four between one date
// and the date beside it, and the grid stopped reading as a grid.
// Square cells fixed the gaps and left seventy pixels of nothing under
// the last week. Centring the whole block moved that hole above the
// month's name instead.
//
// What absorbs it is a sixth row, and a seventh for the weekday names.
// Every month gets the sixth whether or not it needs one: the days
// either side of the month fill it, drawn dim the way a wall calendar
// prints them, so the grid is the same height in February as in August
// and no longer changes shape as you page through the year. The names
// take a row of their own on the same pitch, which is what makes the
// card read as one rhythm from the title down rather than as a header
// with a table under it. Seven rows of a card this size come out
// square, which is where the gaps between dates measure the same
// across as they do down; a card stretched taller than that stops at a
// quarter again and pads instead.

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

    // Day zero of a month is the last day of the month before it,
    // which is what the dim cells in the first row count back from.
    readonly property int daysInPrevMonth:
        new Date(shown.getFullYear(), shown.getMonth(), 0).getDate()

    // Sunday-first, which is what getDay() already counts.
    readonly property int firstWeekday:
        new Date(shown.getFullYear(), shown.getMonth(), 1).getDay()

    // Six, always. See the note at the top of the file.
    readonly property int rows: 6

    readonly property var events:
        Calendar.available && Calendar.today ? Calendar.today.slice(0, 2) : []

    // ── The rhythm ───────────────────────────────────────────
    //
    // One measure for the whole card, worked out here rather than
    // inside the grid because the weekday names are a row of it and a
    // row cannot ask the thing it sits above how tall to be.

    readonly property int headerHeight: 30

    readonly property real gridTop: Theme.padCard + headerHeight
    readonly property real gridBottom: events.visible
        ? events.y - Theme.padRow
        // The smaller inset at the foot: the last row of dates is
        // already holding half a cell of space under itself.
        : height - Theme.padRow

    readonly property real cellW: (width - Theme.padCard * 2) / 7
    readonly property real cellH: Math.max(14, Math.min(cellW * 1.25,
        (gridBottom - gridTop) / (rows + 1)))

    Surface { anchors.fill: parent }

    // The arrows are small and the card is not. Scrolling anywhere on
    // it pages the month, which is how every other calendar behaves
    // and costs nothing to offer.
    WheelHandler {
        onWheel: event => root.monthOffset += event.angleDelta.y > 0 ? -1 : 1
    }

    // The month's name, centred, with an arrow at each edge. Centred
    // because the card is a calendar rather than a row of settings:
    // the name is the thing the two arrows move, and putting it
    // between them says so.
    //
    // It is inset from the top by a card's padding rather than sitting
    // where the other titles in the panel sit, which costs a few
    // pixels of alignment with them and buys the tile its own balance:
    // a date sits in the middle of its cell, so the grid carries half
    // a cell of padding at the foot whatever the margin under it, and
    // a name pinned to the top edge left a tenth of that above it.
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        height: root.headerHeight

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall + 1
            font.weight: Font.Bold
            font.letterSpacing: 0.4
            renderType: Text.NativeRendering
        }

        Repeater {
            model: [{ g: "‹", d: -1, left: true },
                    { g: "›", d: 1,  left: false }]

            // A glyph that brightens, not a chip that fills. The 22px
            // hover square these used to sit in was the only hover
            // fill in the panel that was not a whole card, and it put
            // a second rounded rectangle on a surface that already is
            // one. The target is a margin round the glyph instead, the
            // way the transport buttons and the notification cross
            // take theirs.
            Text {
                required property var modelData

                anchors.left: modelData.left ? parent.left : undefined
                anchors.right: modelData.left ? undefined : parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: modelData.g
                color: nav.containsMouse ? Theme.text : Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 15

                Behavior on color {
                    ColorAnimation { duration: Motion.fadeIn }
                }

                MouseArea {
                    id: nav
                    anchors.fill: parent
                    anchors.margins: -9
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.monthOffset += parent.modelData.d
                }
            }
        }
    }

    // The weekday names and the weeks, on one pitch. The columns span
    // the card — a month floating between two gutters because seven
    // did not divide evenly into the width would be its own kind of
    // wrong — so it is the rows that give when the card is a shape the
    // month does not fit.
    Item {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        y: root.gridTop
        height: root.gridBottom - root.gridTop

        Column {
            // Centred, so a card too tall for a quarter-again grid
            // pads it evenly rather than hanging it off the weekday
            // names. On a card that fits, this does nothing.
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width

            Row {
                id: weekdays
                width: parent.width
                height: root.cellH

                Repeater {
                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

                    // Centred in the row, not left where a Row drops
                    // them: a Row stacks its children along one axis
                    // and leaves them at the top of the other.
                    Text {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.cellW
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.min(
                            Theme.fontSizeSmall - 1,
                            Math.round(root.cellW * 0.3))
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }
                }
            }

            Grid {
                columns: 7

                Repeater {
                    model: root.rows * 7

                    Item {
                        required property int index

                        readonly property int day: index - root.firstWeekday + 1
                        readonly property bool inMonth:
                            day >= 1 && day <= root.daysInMonth

                        // What the cell says: the day, or the day of
                        // the month either side of this one.
                        readonly property int number: inMonth ? day
                            : day < 1 ? root.daysInPrevMonth + day
                                      : day - root.daysInMonth

                        readonly property bool isToday:
                            inMonth && root.monthOffset === 0
                            && day === Clock.now.getDate()

                        width: root.cellW
                        height: root.cellH

                        // Square, and a share of the cell rather than
                        // a fixed inset, so it stays the same shape
                        // whatever shape the card leaves the cell.
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.round(
                                Math.min(parent.width, parent.height) * 0.78)
                            height: width
                            radius: Theme.radiusSmall
                            color: parent.isToday ? Theme.primary : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.number
                            color: parent.isToday ? Theme.textOnPrimary
                                 : parent.inMonth ? Theme.text
                                                  : Theme.outline
                            font.family: Theme.fontFamily
                            font.weight: parent.isToday ? Font.Bold : Font.DemiBold
                            font.pixelSize: Math.min(
                                Theme.fontSizeSmall + 1,
                                Math.round(Math.min(root.cellW, root.cellH) * 0.42))
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }

    // Today, under the month. Absent entirely when khal is not
    // installed, rather than showing an empty list — and absent again
    // when what is left would squeeze the weeks below the size at
    // which a date still reads.
    Column {
        id: events

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        anchors.bottomMargin: Theme.padCard
        spacing: 3

        visible: root.events.length > 0
                 && root.height > Theme.padCard + root.headerHeight
                    + (root.rows + 1) * 22 + Theme.padRow
                    + root.events.length * 18

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
