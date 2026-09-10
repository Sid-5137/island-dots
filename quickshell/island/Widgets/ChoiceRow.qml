import QtQuick
import "root:/Services"

// A labelled row with a segmented control. `options` is a list of
// { value, label } objects; `current` is the selected value.

Item {
    id: root

    property string label: ""
    property string description: ""
    property var options: []
    property string current: ""

    signal selected(string value)

    property string configKey: ""

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(48, text.implicitHeight + 20)

    Column {
        id: text
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: segments.left
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

    ResetDot {
        anchors.right: segments.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        configKey: root.configKey
        current: root.current
    }

    Row {
        id: segments
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: root.options

            Rectangle {
                required property var modelData
                required property int index

                readonly property bool active: modelData.value === root.current

                width: seg.implicitWidth + 22
                height: 28
                color: active ? Theme.primary : Theme.surfaceHigh

                // Round only the outer edges, so the group reads as one
                // control rather than separate buttons.
                topLeftRadius: index === 0 ? 8 : 0
                bottomLeftRadius: index === 0 ? 8 : 0
                topRightRadius: index === root.options.length - 1 ? 8 : 0
                bottomRightRadius: index === root.options.length - 1 ? 8 : 0

                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    id: seg
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.active ? Theme.textOnPrimary : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(modelData.value)
                }
            }
        }
    }
}
