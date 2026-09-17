import QtQuick
import "root:/Services"

// A labelled row with a toggle switch on the right.
// Bind `checked` two-way:  checked: Config.island.hideOnFullscreen
//                          onToggled: Config.island.hideOnFullscreen = value

Item {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false

    signal toggled(bool value)

    property string configKey: ""

    // Rows worth a glance, and rows worth a visit. Most of what a
    // settings page holds is a number you set once, and thirty of
    // them in a column is a page nobody reads — so a row can mark
    // itself `advanced` and the window hides it until the switch in
    // its corner is on. `shown` is the row's own condition, kept
    // apart so that setting one does not quietly cancel the other.
    property bool advanced: false
    property bool shown: true

    visible: shown && (!advanced || Config.ui.advanced)

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(44, text.implicitHeight + 20)

    Column {
        id: text
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // See ChoiceRow: anchoring to the control rather than to the
        // revert dot put the two on top of each other.
        anchors.right: revert.left
        anchors.rightMargin: 12
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: root.description
            visible: root.description !== ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

    ResetDot {
        id: revert
        anchors.right: knob.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        configKey: root.configKey
        current: root.checked
    }

    Rectangle {
        id: knob
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        // A switch is a capsule and its knob is a circle, whatever
        // the radius dial says. Those are facts about the shape rather
        // than preferences, so they are written against the shape.
        width: 44
        height: 24
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceHigh
        border.width: 1
        border.color: root.checked ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        Rectangle {
            width: 18
            height: 18
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.textOnPrimary : Theme.textDim

            // The knob travels on the arrival spring, so a switch
            // moves the way the rest of the shell does.
            Behavior on x {
                NumberAnimation {
                    duration: Motion.hover
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.arrive
                }
            }
            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }
}
