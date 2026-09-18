import QtQuick
import "root:/Services"

// A section that stays folded until you ask for it.
//
// Most of what the settings app exposes is not what you came to
// change. The island alone has a dozen pixel sizes that exist so the
// shape can be tuned once and then left alone; listing them beside
// the two or three switches people actually reach for made the page
// long enough that the useful controls were hard to find.
//
// Nothing is removed — everything is still here, and still in the
// same file it always was. It just does not compete for attention
// until it is opened.

Item {
    id: root

    property string text: "Advanced"

    // Shown next to the heading, e.g. "12 settings". Worth setting:
    // it tells you whether opening this is worth the scroll.
    property string hint: ""

    property bool open: false

    // A fold can sit behind the Advanced switch too — see
    // Settings/Settings.qml. Nothing inside one is ever marked: the
    // fold is already the gate there, and a row hidden as well would
    // mean opening a section to find it empty.
    property bool advanced: false
    property bool shown: true

    visible: shown && (!advanced || Config.ui.advanced)

    default property alias content: holder.data

    implicitWidth: parent ? parent.width : 400
    implicitHeight: header.height + (open ? holder.implicitHeight + 10 : 0)

    // Contents are laid out at full height whether or not they show,
    // so the fold has to cut them off rather than merely hide them.
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Item {
        id: header
        width: parent.width
        height: 40

        Text {
            id: chevron
            anchors.left: parent.left
            anchors.verticalCenter: caption.verticalCenter
            text: "›"
            color: hover.containsMouse ? Theme.primary : Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.Bold
            renderType: Text.NativeRendering
            rotation: root.open ? 90 : 0
            transformOrigin: Item.Center

            Behavior on rotation {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: caption
            anchors.left: chevron.right
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: root.text.toUpperCase()
            color: hover.containsMouse || root.open ? Theme.primary : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            font.letterSpacing: 2.4
            renderType: Text.NativeRendering

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.left: caption.right
            anchors.leftMargin: 10
            anchors.baseline: caption.baseline
            text: root.hint
            visible: root.hint !== ""
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall - 1
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Column {
        id: holder
        y: header.height + 10
        width: root.width
        spacing: 4
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
    }
}
