import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Polkit authorization prompt.

Item {
    id: root

    required property var win
    required property var island
    required property var pill

    anchors.fill: parent
    anchors.margins: 20

    readonly property bool shown: island.isAuth

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    IconImage {
        id: authIcon
        anchors.left: parent.left
        anchors.top: parent.top
        implicitSize: 34
        source: Quickshell.iconPath(Polkit.iconName, "dialog-password")
    }

    Column {
        anchors.left: authIcon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 3

        Text {
            width: parent.width
            text: Polkit.message !== "" ? Polkit.message : "Authentication required"
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            text: Polkit.action
            visible: text !== ""
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: buttons.top
        anchors.bottomMargin: 12
        height: 40
        radius: Theme.radiusNormal
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Polkit.failed
            ? Theme.error
            : (input.activeFocus ? Theme.outline : Theme.outlineVariant)

        Behavior on border.color { ColorAnimation { duration: Motion.fadeIn } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: Text.AlignVCenter

            // polkit says whether the response should be visible — a
            // one-time code is shown, a password is not.
            echoMode: Polkit.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "\u2022"
            color: Theme.text
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeNormal
            clip: true

            text: Polkit.entry
            onTextChanged: Polkit.entry = text
            onAccepted: Polkit.submit()

            Keys.onEscapePressed: Polkit.cancel()

            Connections {
                target: Polkit
                function onEntryChanged() {
                    if (input.text !== Polkit.entry) input.text = Polkit.entry;
                }
                function onActiveChanged() {
                    if (Polkit.active) input.forceActiveFocus();
                }
            }

            Component.onCompleted: forceActiveFocus()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: Polkit.prompt
                color: Theme.outline
                font: input.font
                renderType: Text.NativeRendering
            }
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Theme.spacingSmall

        Button {
            implicitHeight: 32
            text: "Cancel"
            onClicked: Polkit.cancel()
        }

        Button {
            implicitHeight: 32
            text: "Authenticate"
            kind: "primary"
            // Nothing to submit is not the same as a button that
            // submits nothing. `enabled` dims it and stops the click
            // in one move.
            enabled: Polkit.entry !== ""
            onClicked: Polkit.submit()
        }
    }

    // Whatever polkit has to say, in the room the buttons leave it.
    // Anchored rather than sitting in the Row, where its width was
    // `root.width - 200` — the two buttons' hard-coded widths added up
    // by hand, which stopped being true the moment either of them was
    // allowed to size itself to its own label.
    Text {
        anchors.left: parent.left
        anchors.right: buttons.left
        anchors.rightMargin: Theme.spacingNormal
        anchors.verticalCenter: buttons.verticalCenter
        text: Polkit.supplementary
        color: Polkit.supplementaryIsError ? Theme.error : Theme.outline
        font.family: Theme.fontIsland
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }
}
