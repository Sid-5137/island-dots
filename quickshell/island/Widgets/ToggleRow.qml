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

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(44, text.implicitHeight + 20)

    Column {
        id: text
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: knob.left
        anchors.rightMargin: 16
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

    Rectangle {
        id: knob
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        width: 44
        height: 24
        radius: 12
        color: root.checked ? Theme.primary : Theme.surfaceHigh
        border.width: 1
        border.color: root.checked ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 18
            height: 18
            radius: 9
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.textOnPrimary : Theme.textDim

            Behavior on x {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }
}
