import Quickshell
import QtQuick

import "root:/Services"

// One notification's face — icon, title and age, body — shared by the
// popup (NotifyMode) and the history rows (CentreMode). They differ
// only in what sits around it, so neither can drift into looking like
// a different design from the other.
//
// After the macOS banner, set in the island's own type: the app's icon
// with nothing behind it, the title with the age right-aligned on the
// same line, the body dimmer underneath. The age is what gives the
// right edge something to hold, so the block is weighted at both ends
// instead of hanging off its icon. The type is the control centre's
// cards', so a notification reads as part of the same object.

Item {
    id: root

    property var entry: null
    property int iconSize: 38
    property int bodyLines: 2

    // The centre's rows swap the age for a close button under the
    // pointer. The row owns the hover; this only draws it.
    property bool dismissable: false
    property bool hovered: false
    signal dismissed()

    implicitHeight: Math.max(iconSize, words.implicitHeight)

    // A picture, as opposed to an icon — an avatar, a thumbnail.
    //
    // Senders hand over an icon name as often as a picture, and
    // Quickshell passes a name given as the image through as
    // image://icon/<name>. That loads, and draws the missing-texture
    // checkerboard, whenever no installed theme has the name. So a name
    // is taken out of the image and treated as the icon it is.
    readonly property string picture: {
        const img = entry && entry.image ? String(entry.image) : "";
        return img.startsWith("image://icon/") ? "" : img;
    }

    // The app's icon, through iconPath's existence check, which answers
    // "" for a name nothing provides and lets the bell stand in.
    readonly property string appIcon: {
        if (!entry) return "";
        const img = entry.image ? String(entry.image) : "";
        const name = img.startsWith("image://icon/")
            ? img.slice("image://icon/".length) : String(entry.appIcon || "");
        if (name === "") return "";
        if (name.startsWith("/")) return "file://" + name;
        if (name.startsWith("file:")) return name;
        return Quickshell.iconPath(name, true);
    }

    readonly property bool critical: !!entry && entry.critical === true

    // Rebuilt every second off Clock.now, which is what keeps a row in
    // the centre saying 3m rather than "now" forever.
    readonly property string age: {
        if (!entry || !entry.time) return "";
        const s = Math.max(0, (Clock.now.getTime() - entry.time) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    // ── Icon ─────────────────────────────────────────────────

    Item {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize

        // A picture is cropped into the app-icon shape: round to about
        // two-ninths of its side, which is what an app icon is on every
        // platform that draws one.
        Rectangle {
            anchors.fill: parent
            visible: picImg.visible
            radius: width * 0.225
            color: "transparent"
            clip: true

            Image {
                id: picImg
                anchors.fill: parent
                source: root.picture
                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        // The app icon alone: it has its own shape, and a tile behind
        // it is a second shape saying the same thing. Next to a
        // picture it shrinks to a badge on its corner, the way a
        // message shows whose avatar it is and which app it came from.
        Image {
            id: appImg
            readonly property bool badge: picImg.visible
            width: badge ? Math.round(root.iconSize * 0.42) : root.iconSize
            height: width
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: badge ? -3 : 0
            anchors.bottomMargin: badge ? -3 : 0
            source: root.appIcon
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        // Neither: a bell on the card's own wash, so the column still
        // starts with a shape. Critical takes the error colour here
        // because there is no app icon to carry anything else.
        Rectangle {
            anchors.fill: parent
            visible: !picImg.visible && !appImg.visible
            radius: width * 0.225
            color: root.critical ? Theme.error : Qt.rgba(1, 1, 1, 0.08)

            Text {
                anchors.centerIn: parent
                // The shell's own warnings get a glyph that says what
                // they are about; anything else from an app with no
                // icon gets the bell.
                text: root.entry && root.entry.appName === "Battery"
                    ? (root.critical ? Icons.batteryEmpty : Icons.batteryLow)
                    : Icons.bell
                color: root.critical ? Theme.textOnError : Theme.textDim
                font.family: Theme.fontIcons
                font.pixelSize: Math.round(root.iconSize * 0.42 / 2) * 2
                renderType: Text.NativeRendering
            }
        }
    }

    // ── Text ─────────────────────────────────────────────────

    Column {
        id: words
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Item {
            width: parent.width
            height: title.implicitHeight

            Text {
                id: title
                anchors.left: parent.left
                anchors.right: meta.left
                anchors.rightMargin: 10
                // A summary is optional in the spec; the app's name is
                // a better title than an empty line.
                text: root.entry
                    ? (root.entry.summary || root.entry.appName || "") : ""
                color: Theme.text
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeSmall + 1
                font.weight: Font.Bold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            // The age, or "Urgent" for a critical one: the slot that
            // says how much this matters now.
            Text {
                id: meta
                anchors.right: parent.right
                anchors.baseline: title.baseline
                text: root.critical ? "Urgent" : root.age
                color: root.critical ? Theme.error : Theme.outline
                font.family: Theme.fontIsland
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                opacity: root.dismissable && root.hovered ? 0 : 1

                Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
            }

            // In the age's place, the same size as the line it sits on,
            // so swapping one for the other moves nothing.
            Rectangle {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: title.verticalCenter
                width: 20
                height: 20
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.10)
                visible: root.dismissable
                opacity: root.hovered ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    color: Theme.text
                    font.family: Theme.fontIcons
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                // Not hoverEnabled: a hovering child takes the row's
                // hover away, and the button that hover revealed would
                // vanish from under the pointer reaching for it.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: root.hovered
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissed()
                }
            }
        }

        Text {
            width: parent.width
            text: root.entry ? (root.entry.body || "") : ""
            visible: text !== ""
            color: Theme.textDim
            font.family: Theme.fontIsland
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            lineHeight: 1.1
            // Senders send markup whether or not it's advertised;
            // rendering it raw shows tags.
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            maximumLineCount: root.bodyLines
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }
}
