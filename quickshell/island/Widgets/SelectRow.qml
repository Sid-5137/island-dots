import QtQuick
import "root:/Services"

// A labelled row with a dropdown. Unlike ChoiceRow's segmented
// control, this handles long lists — it opens a scrollable popup
// and filters as you type.

Item {
    id: root

    property string label: ""
    property string description: ""
    property var options: []        // list of strings
    property string current: ""
    property int popupHeight: 220

    signal selected(string value)

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 52

    // The popup has to escape the row's bounds, so it's parented to
    // the page and z-raised rather than clipped inside this Item.
    z: open ? 100 : 0
    property bool open: false

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: field.left
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
        id: field
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 210
        height: 32
        radius: 8
        color: root.open || fieldHover.containsMouse
            ? Theme.surfaceHigh
            : Theme.surfaceContainer
        border.width: 1
        border.color: root.open ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.current === "" ? "—" : root.current
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2304"
            color: Theme.outline
            font.pixelSize: Theme.fontSizeNormal
            rotation: root.open ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: fieldHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.open = !root.open;
                if (root.open) {
                    filter.text = "";
                    filter.forceActiveFocus();
                }
            }
        }
    }

    Rectangle {
        id: popup
        anchors.right: parent.right
        anchors.top: field.bottom
        anchors.topMargin: 6

        width: field.width
        height: root.open ? root.popupHeight : 0
        radius: 10
        color: Theme.surfaceLowest
        border.width: 1
        border.color: Theme.outlineVariant
        clip: true
        visible: height > 1

        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Item {
            id: filterRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32

            TextInput {
                id: filter
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                clip: true

                Keys.onEscapePressed: root.open = false

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: filter.text === ""
                    text: "Filter…"
                    color: Theme.outline
                    font: filter.font
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outlineVariant
            }
        }

        ListView {
            anchors.top: filterRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            clip: true

            model: {
                const q = filter.text.trim().toLowerCase();
                if (q === "") return root.options;
                return root.options.filter(o => o.toLowerCase().includes(q));
            }

            delegate: Rectangle {
                required property var modelData

                readonly property bool active: modelData === root.current

                width: popup.width
                height: 30
                color: active
                    ? Qt.rgba(1, 1, 1, 0.10)
                    : (rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: parent.active ? Theme.primary : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selected(modelData);
                        root.open = false;
                    }
                }
            }
        }
    }
}
