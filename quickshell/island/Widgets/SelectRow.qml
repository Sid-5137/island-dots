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

    property string configKey: ""

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 52

    // The popup has to escape the row's bounds, so it's parented to
    // the page and z-raised rather than clipped inside this Item.
    z: open ? 100 : 0
    property bool open: false

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
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
        anchors.right: field.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        configKey: root.configKey
        current: root.current
    }

    Rectangle {
        id: field
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 210
        height: 32
        radius: Theme.radiusNormal
        color: root.open || fieldHover.containsMouse
            ? Theme.surfaceHigh
            : Theme.surfaceContainer
        border.width: 1
        border.color: root.open ? Theme.primary : Theme.outlineVariant

        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padCard
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
            anchors.rightMargin: Theme.padCard
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
        radius: Theme.radiusLarge
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
                anchors.leftMargin: Theme.padCard
                anchors.rightMargin: Theme.padCard
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

            // Inset and rounded, for the same reason the launcher's
            // rows are: a square highlight running the full width of a
            // rounded popup meets the popup's corner and gets cut, and
            // the eye reads the cut rather than the selection. The row
            // keeps its text on the same line as the filter field
            // above it — the card's inset plus the text's inset inside
            // it come to the field's own margin.
            delegate: Item {
                id: opt

                required property var modelData

                readonly property bool active: modelData === root.current

                width: popup.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1

                    radius: Theme.radiusSmall

                    color: opt.active
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : (rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingSmall
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData
                        color: opt.active ? Theme.primary : Theme.textDim
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
                            root.selected(opt.modelData);
                            root.open = false;
                        }
                    }
                }
            }
        }
    }
}
