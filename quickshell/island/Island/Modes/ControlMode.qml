import QtQuick

import "root:/Services"
import "root:/Widgets"
import "root:/Widgets/Control"

// Control centre: a grid of controls, and the pages behind them.
//
// This used to be four cards at four hard-coded positions — a calendar
// on the left, a 3x2 block of glyphs and two sliders on the right —
// with every dimension in the file derived from three other dimensions
// so that moving one thing moved four. It is now a grid whose contents
// are data: Services/ControlLayout.qml holds where everything sits,
// Widgets/Control/ControlItem.qml draws whichever control a cell names,
// and the settings page lets you drag them around. What is left here is
// the two things that are genuinely this file's job — turning cells
// into rectangles, and owning the sub-pages.
//
// The sub-pages are the other half of the change. Clicking Wi-Fi used
// to open the Settings window on the Network page, which is a strange
// thing for a control centre to do: you asked which networks are
// around and got a different window, on a different layer, covering
// the screen. Now the panel keeps its shape and the list slides in
// over the grid, with a chevron back. It is the same panel throughout,
// which is the whole promise the shape is making while it morphs.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up. The pill is no longer one of them:
// the grid fills whatever it is given, so there is nothing left here
// that has to measure the shape.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags

    anchors.fill: parent

    readonly property bool shown: island.isControl

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    // "" | "wifi" | "bluetooth" | "sound"
    property string page: ""

    // Closing the panel has to close the page with it, or reopening
    // the control centre lands you back inside a network list you left
    // three hours ago.
    //
    // It also lets nmcli and bluetoothctl go back to sleep. Those two
    // poll by spawning processes, and this is the only thing on screen
    // that reads them.
    onShownChanged: {
        if (shown) {
            Network.hold();
            Bluetooth.hold();
        } else {
            page = "";
            Network.release();
            Bluetooth.release();
        }
    }

    function openPage(name) {
        switch (name) {
            case "wifi":
                Network.scan();
                page = "wifi";
                break;
            case "bluetooth":
                Bluetooth.scan();
                page = "bluetooth";
                break;
            case "sound":
                page = "sound";
                break;

            // Not pages: things that are somewhere else, which close
            // the panel on their way out. A control centre that stays
            // open behind the window it just opened is a control
            // centre you then have to dismiss.
            case "notifications":
                win.closeControl();
                win.openCentre();
                break;
            case "lock":
                win.closeControl();
                Lock.lock();
                break;
            case "settings":
                win.closeControl();
                win.openSettings("control");
                break;
        }
    }

    // ── The grid ─────────────────────────────────────────────
    //
    // Measured against the pill as it morphs rather than against the
    // width it is heading for, so the cards grow with the panel
    // instead of being revealed by its clip. Both read well; this one
    // is the one where the panel and its contents are visibly the same
    // object, which is the point of the shape.

    Item {
        id: grid

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: ControlLayout.panelHeight

        // A page slides in from the right, so the grid steps left as
        // it goes. Far enough to read as displacement, not so far that
        // it looks like a second thing moving.
        x: root.page === "" ? 0 : -18
        opacity: root.page === "" ? 1 : 0
        visible: opacity > 0.01

        Behavior on x {
            NumberAnimation {
                duration: Motion.hover
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.arrive
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.fadeOut }
        }

        Repeater {
            model: ControlLayout.items

            ControlItem {
                required property var modelData

                itemKey: modelData.key
                labels: modelData.text !== false

                x: ControlLayout.itemX(grid.width, modelData.x)
                y: ControlLayout.itemY(modelData.y)
                width: ControlLayout.itemWidth(grid.width, modelData.w)
                height: ControlLayout.itemHeight(modelData.h)

                onOpenPage: function(name) { root.openPage(name) }
            }
        }
    }

    // ── The pages ────────────────────────────────────────────

    Item {
        id: pages

        anchors.fill: parent
        anchors.margins: Config.island.controlPad

        x: root.page === "" ? 18 : 0
        opacity: root.page === "" ? 0 : 1
        visible: opacity > 0.01

        Behavior on x {
            NumberAnimation {
                duration: Motion.hover
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.arrive
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.fadeIn }
        }

        // ── Wi-Fi ────────────────────────────────────────

        PanelPage {
            anchors.fill: parent
            visible: root.page === "wifi"

            title: "Wi-Fi"
            note: Network.scanning ? "Scanning…" : ""
            hasSwitch: true
            on: Network.wifiEnabled

            onBack: root.page = ""
            onToggled: Network.toggle()

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Network.networks

                delegate: DeviceRow {
                    required property var modelData
                    width: ListView.view.width

                    // Three bars, not five: nmcli reports a percentage
                    // and the glyphs are the only thing between it and
                    // a number nobody reads.
                    glyph: modelData.signal > 66 ? ""
                         : modelData.signal > 33 ? ""
                                                 : ""
                    name: modelData.ssid
                    sub: modelData.active
                        ? "Connected"
                        : (modelData.secure ? "Secured" : "Open")
                    lit: modelData.active
                    action: modelData.active ? "Disconnect" : "Connect"

                    onTriggered: {
                        if (modelData.active) Network.disconnect();
                        // A password prompt inside a panel this size
                        // is a text field, a keyboard grab and an
                        // error state, and getting any of the three
                        // wrong locks you out of your own shell. Known
                        // networks connect from here; a new one is
                        // still Settings' job.
                        else Network.connect(modelData.ssid, "");
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: Network.networks.length === 0
                text: Network.wifiEnabled ? "Looking…" : "Wi-Fi is off"
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        // ── Bluetooth ────────────────────────────────────

        PanelPage {
            anchors.fill: parent
            visible: root.page === "bluetooth"

            title: "Bluetooth"
            note: Bluetooth.scanning ? "Scanning…" : ""
            hasSwitch: true
            on: Bluetooth.powered

            onBack: root.page = ""
            onToggled: Bluetooth.toggle()

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                // Connected first. The list is otherwise in whatever
                // order bluetoothctl prints, which is neither
                // alphabetical nor by recency, and the one device you
                // care about is the one already attached.
                model: Bluetooth.devices.slice().sort((a, b) =>
                    (b.connected ? 1 : 0) - (a.connected ? 1 : 0))

                delegate: DeviceRow {
                    required property var modelData
                    width: ListView.view.width

                    glyph: ""
                    name: modelData.name
                    sub: modelData.connected ? "Connected" : "Paired"
                    lit: modelData.connected
                    action: modelData.connected ? "Disconnect" : "Connect"

                    onTriggered: {
                        if (modelData.connected)
                            Bluetooth.disconnect(modelData.mac);
                        else
                            Bluetooth.connect(modelData.mac);
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: Bluetooth.devices.length === 0
                text: Bluetooth.powered ? "No devices" : "Bluetooth is off"
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        // ── Sound ────────────────────────────────────────

        PanelPage {
            anchors.fill: parent
            visible: root.page === "sound"

            title: "Sound"
            note: Audio.muted ? "Muted" : ""

            onBack: root.page = ""

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Audio.sinks

                delegate: DeviceRow {
                    required property var modelData
                    width: ListView.view.width

                    readonly property bool current:
                        Audio.sink && modelData
                        && modelData.id === Audio.sink.id

                    glyph: ""
                    name: Audio.sinkLabel(modelData)
                    sub: current ? "Output" : ""
                    lit: current
                    action: current ? "" : "Use"

                    onTriggered: Audio.setSink(modelData)
                }
            }
        }
    }

    // Escape backs out of a page before it closes the panel, which is
    // what the chevron does and therefore what Escape should do. Two
    // presses to leave a sub-page is right; one press throwing away
    // both the page and the panel is not.
    Item {
        anchors.fill: parent
        focus: island.isControl
        Keys.onEscapePressed: {
            if (root.page !== "") root.page = "";
            else win.closeControl();
        }
    }
}
