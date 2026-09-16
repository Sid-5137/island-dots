import QtQuick
import "root:/Services"
import "root:/Widgets"

// Wi-Fi and Bluetooth. The island's control centre only toggles the
// radios; anything that needs a list, a password or a pairing prompt
// belongs here where there's room for it.

Column {
    id: page
    spacing: 4

    // nmcli and bluetoothctl poll by spawning processes, and they do
    // it only while something is reading them. This page is one of
    // the two places that does.
    Component.onCompleted: { Network.hold(); Bluetooth.hold() }
    Component.onDestruction: { Network.release(); Bluetooth.release() }

    // Which network's password field is open. Empty means none.
    property string promptFor: ""
    property string password: ""

    SectionHeader { text: "Wi-Fi" }

    ToggleRow {
        label: "Wi-Fi"
        description: Network.label
        checked: Network.wifiEnabled
        onToggled: function(v) {
            Network.toggle();
            if (v) scanDelay.restart();
        }
    }

    Timer {
        id: scanDelay
        interval: 1200
        onTriggered: Network.scan()
    }

    Item {
        width: parent.width
        height: 36
        visible: Network.wifiEnabled

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Network.scanning
                ? "Scanning…"
                : Network.networks.length + " networks"
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall

            Button {
                implicitHeight: 28
                text: "Rescan"
                onClicked: Network.scan()
            }

            Button {
                implicitHeight: 28
                visible: Network.connected && Network.connType === "wifi"
                text: "Disconnect"
                onClicked: Network.disconnect()
            }
        }
    }

    Text {
        width: parent.width
        visible: Network.lastError !== ""
        text: Network.lastError
        color: Theme.error
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        renderType: Text.NativeRendering
    }

    Repeater {
        model: Network.wifiEnabled ? Network.networks : []

        Column {
            required property var modelData
            width: page.width
            spacing: 0

            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.radiusLarge
                color: modelData.active
                    ? Qt.rgba(1, 1, 1, 0.08)
                    : (netHover.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                Text {
                    id: sig
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    // Four bars, and until now not one of them: the
                    // codepoints were a nibble off, so 70% drew a text
                    // icon, 40% a star face, 15% a square-root box and
                    // the floor a shower head. See Services/Icons.qml.
                    text: modelData.signal > 70 ? Icons.wifi4
                        : modelData.signal > 40 ? Icons.wifi3
                        : modelData.signal > 15 ? Icons.wifi2 : Icons.wifi1
                    color: modelData.active ? Theme.primary : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }

                Text {
                    anchors.left: sig.right
                    anchors.leftMargin: 10
                    anchors.right: netAction.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.ssid + (modelData.secure ? "  " + Icons.secure : "")
                    color: modelData.active ? Theme.primary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    id: netAction
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.active ? "Connected" : (netHover.containsMouse ? "Connect" : "")
                    color: modelData.active ? Theme.primary : Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: netHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.active) return;
                        // Try without a password first — nmcli reuses a
                        // stored one for known networks, so most clicks
                        // never need the prompt.
                        if (!modelData.secure) {
                            Network.connect(modelData.ssid, "");
                        } else if (page.promptFor === modelData.ssid) {
                            page.promptFor = "";
                        } else {
                            page.promptFor = modelData.ssid;
                            page.password = "";
                        }
                    }
                }
            }

            // Password row, shown only for the network being joined.
            Item {
                width: parent.width
                height: page.promptFor === modelData.ssid ? 42 : 0
                visible: height > 0
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: joinBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    radius: Theme.radiusSmall
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Theme.outlineVariant

                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true

                        onTextChanged: page.password = text
                        onAccepted: {
                            Network.connect(modelData.ssid, text);
                            page.promptFor = "";
                        }

                        // Focus follows the row opening, so you can type
                        // straight away rather than clicking twice.
                        Connections {
                            target: page
                            function onPromptForChanged() {
                                if (page.promptFor === modelData.ssid) {
                                    pwField.text = "";
                                    pwField.forceActiveFocus();
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: pwField.text === ""
                            text: "Password"
                            color: Theme.outline
                            font: pwField.font
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Button {
                    id: joinBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padCard
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 28
                    text: "Join"
                    kind: "primary"

                    onClicked: {
                        Network.connect(modelData.ssid, page.password);
                        page.promptFor = "";
                    }
                }
            }
        }
    }

    SectionHeader { text: "Bluetooth" }

    ToggleRow {
        label: "Bluetooth"
        description: Bluetooth.label
        checked: Bluetooth.powered
        onToggled: function(v) { Bluetooth.toggle() }
    }

    Item {
        width: parent.width
        height: 36
        visible: Bluetooth.powered

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Bluetooth.scanning ? "Scanning…" : Bluetooth.devices.length + " devices"
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Text.NativeRendering
        }

        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 28
            text: "Scan"
            onClicked: Bluetooth.scan()
        }
    }

    Repeater {
        model: Bluetooth.powered ? Bluetooth.devices : []

        Rectangle {
            required property var modelData

            width: page.width
            height: 44
            radius: Theme.radiusLarge
            color: modelData.connected
                ? Qt.rgba(1, 1, 1, 0.08)
                : (btHover.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

            Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

            Text {
                id: btIcon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: Icons.bluetoothDevice
                color: modelData.connected ? Theme.primary : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }

            Text {
                anchors.left: btIcon.right
                anchors.leftMargin: 10
                anchors.right: btAction.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: modelData.connected ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                id: btAction
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.connected
                    ? (btHover.containsMouse ? "Disconnect" : "Connected")
                    : (btHover.containsMouse ? "Connect" : "")
                color: modelData.connected ? Theme.primary : Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: btHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.connected
                    ? Bluetooth.disconnect(modelData.mac)
                    : Bluetooth.connect(modelData.mac)
            }
        }
    }
}
