import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "root:/Services"
import "root:/Widgets"

// The lock surface, one per screen.
//
// Laid out the way macOS lays one out, because that layout is right
// about two things: the clock belongs at the top where it is readable
// from across the room, and everything you have to touch belongs low,
// together, under your hands — a field in the centre of the screen is
// a field you look for.
//
// The middle is left empty on purpose. It is the only part of the
// wallpaper you get to see.
//
// Built out of the island's own material rather than a rectangle: a
// Squircle for the field and the Bezel's two concentric strokes, so
// the one surface the shell shows on a black screen is recognisably
// the same object as the pill.
//
// Still not a place for widgets. The avatar and the one line under the
// field are identity and diagnosis: who this machine thinks you are,
// and why the last password did not work.

WlSessionLock {
    id: lock

    locked: Lock.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.background

        // This screen's wallpaper, which is the shared one unless
        // per-monitor wallpapers are on — the same question
        // Background/WallpaperLayer.qml asks, and the lock is per
        // screen too, so it gets the same answer.
        readonly property string mine:
            Wallpaper.pathFor(surface.screen ? surface.screen.name : "")

        // The lock is the one surface in the shell with no panel
        // behind it, so the palette has to reach it through the scrim
        // rather than through a fill. surfaceLowest is the darkest
        // thing the theme has, which is what a scrim wants.
        readonly property color scrim: Theme.surfaceLowest

        // The same luminance test Theme.text makes, against the scrim
        // instead of the surface. At the opacities this runs at the
        // scrim is most of what you are looking at, so it is the scrim
        // that decides whether white text or dark text survives on top
        // of it — a light palette used to get white on near-white.
        readonly property color ink: {
            const c = Qt.color(surface.scrim);
            const lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
            return lum < 0.5 ? "#ffffff" : "#0b0b0d";
        }

        // Ink at some fraction of itself. Every dimmed thing here is
        // the same colour at a lower alpha rather than its own grey, so
        // one palette change moves all of them.
        function wash(a) {
            return Qt.rgba(surface.ink.r, surface.ink.g, surface.ink.b, a);
        }

        // One line under the field, and the order is the order of use:
        // what is stopping you, then what went wrong, then what you
        // could do instead.
        //
        // Caps Lock outranks the error it almost certainly caused —
        // "Incorrect password" is true and useless when the answer is
        // that the keyboard is shouting.
        readonly property string hint: {
            if (Lock.waiting)
                return "Try again in " + Lock.cooldown + "s";
            if (Lock.busy)
                return "Checking…";
            if (Lock.capsLock)
                return "Caps Lock is on";
            if (Lock.error)
                return Lock.message !== "" ? Lock.message : "Incorrect password";
            if (Lock.fingerprintArmed)
                return "Touch the reader or enter your password";
            return Lock.message;
        }

        readonly property bool hintIsFault:
            Lock.waiting || Lock.error || Lock.capsLock

        Image {
            id: shot
            anchors.fill: parent
            source: surface.mine !== "" ? "file://" + surface.mine : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: surface.screen ? surface.screen.width : 0
            sourceSize.height: surface.screen ? surface.screen.height : 0

            // Drawn by the effect below unless there is no blur to
            // apply, in which case there is nothing for the effect to
            // do and the image may as well draw itself.
            visible: status === Image.Ready && Config.lock.blur <= 0
        }

        // Qt's Gaussian rather than Hyprland's dual Kawase, because the
        // compositor cannot blur this: a session lock surface is above
        // everything, and the wallpaper under it is an image we are
        // drawing ourselves. Static, so it costs one frame when the
        // lock engages and nothing after.
        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready && Config.lock.blur > 0

            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Math.max(0, Math.min(1, Config.lock.blur))
        }

        // The wallpaper is there for recognition, not for looking at.
        Rectangle {
            anchors.fill: parent
            color: surface.scrim
            opacity: Math.max(0, Math.min(1, Config.lock.scrimOpacity))
        }

        // Everything above the scrim arrives together, a beat after the
        // surface does. Without it the lock cuts in at full strength,
        // which on an idle timeout is the screen shouting at you.
        Item {
            id: content
            anchors.fill: parent

            opacity: 0
            Component.onCompleted: opacity = 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.contentIn
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.reveal
                }
            }

            // ── The clock, high ──────────────────────────────
            //
            // Date above the time, both centred. A fraction of the
            // height rather than a margin, so it sits in the same place
            // on a laptop panel and on a 32-inch monitor.
            Column {
                id: head
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.13)
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.dateLong
                    color: surface.wash(0.72)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.time
                    color: surface.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeClock
                    font.weight: Font.Thin
                    font.letterSpacing: -2
                    renderType: Text.NativeRendering
                }
            }

            // ── Who, and the way in — low ────────────────────
            Column {
                id: foot
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(parent.height * 0.17)
                spacing: Theme.spacingSmall

                // The avatar. A circle because a face is a circle
                // everywhere else on this machine — the one shape in
                // the shell that is not the island's, and deliberately
                // so: it is a photograph, not a surface.
                Item {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96
                    height: 96

                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: User.avatar !== "" ? "file://" + User.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 192
                        sourceSize.height: 192
                        visible: false
                    }

                    Item {
                        id: faceMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: faceImg
                        visible: faceImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                    }

                    // No picture set, which is the common case on a
                    // machine that was never through a desktop's
                    // first-run wizard. Initials rather than a stock
                    // silhouette: it is at least about you.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: faceImg.status !== Image.Ready
                        color: surface.wash(0.12)
                        border.width: 1
                        border.color: surface.wash(0.22)

                        Text {
                            anchors.centerIn: parent
                            text: User.initials
                            color: surface.wash(0.8)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.Light
                            font.letterSpacing: 1
                            renderType: Text.NativeRendering
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: User.name
                    color: surface.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    topPadding: 4
                    bottomPadding: 10
                }

                // The field. A capsule because that is what the shape
                // is rather than what it was set to — see DESIGN.md on
                // the fourth case that is deliberately not a token —
                // and a Squircle because every other edge in the shell
                // is a superellipse and one arc among them shows.
                Item {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 264
                    height: 40

                    readonly property real corner: height / 2

                    // A wrong password says so in words underneath. The
                    // shake is for the case where the words are not
                    // where you are looking, which on a lock screen is
                    // most of the time — you are watching what you type.
                    transform: Translate { id: nudge }

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: nudge; property: "x"; to:  9; duration: 45 }
                        NumberAnimation { target: nudge; property: "x"; to: -7; duration: 60 }
                        NumberAnimation { target: nudge; property: "x"; to:  5; duration: 60 }
                        NumberAnimation { target: nudge; property: "x"; to:  0; duration: 55 }
                    }

                    Connections {
                        target: Lock
                        function onErrorChanged() {
                            if (Lock.error && !Motion.reduced) shake.restart();
                        }
                    }

                    Squircle {
                        anchors.fill: parent
                        radius: field.corner
                        smoothing: Config.appearance.cornerSmoothing
                        color: surface.wash(0.14)
                        borderWidth: 1
                        borderColor: Lock.error
                            ? Theme.error
                            : (input.activeFocus ? surface.wash(0.42)
                                                 : surface.wash(0.18))

                        Behavior on borderColor {
                            ColorAnimation { duration: Motion.fadeIn }
                        }
                    }

                    Bezel { outer: field.corner }

                    TextInput {
                        id: input
                        anchors.fill: parent

                        // Both margins clear the trailing glyph, not
                        // just the one beside it: an inset on one side
                        // only would move the centre by half a glyph
                        // every time Caps Lock came on.
                        anchors.leftMargin: 16 + trailing.width
                        anchors.rightMargin: 16 + trailing.width

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        echoMode: TextInput.Password

                        // U+25CF, not the U+2022 bullet this started
                        // as. A bullet is punctuation, sized to sit in
                        // a line of prose, and at the size prose is set
                        // to it reads as grit in the field rather than
                        // as characters you typed. The black circle is
                        // a glyph whose whole job is to be a dot, so it
                        // fills the line it is on.
                        passwordCharacter: "●"

                        color: surface.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge

                        // The dots are round and identical, so nothing
                        // in their shape says where one ends. The gap
                        // has to.
                        font.letterSpacing: 3
                        renderType: Text.NativeRendering
                        enabled: !Lock.busy && !Lock.waiting
                        clip: true

                        text: Lock.entry
                        onTextChanged: Lock.entry = text
                        onAccepted: Lock.submit()

                        // The surface is created when the lock engages,
                        // so focus has to be taken then rather than at
                        // load.
                        Component.onCompleted: forceActiveFocus()

                        // Losing focus to the wait would leave the
                        // field dead after the count reached zero.
                        onEnabledChanged: if (enabled) forceActiveFocus()

                        Connections {
                            target: Lock
                            function onEntryChanged() {
                                if (input.text !== Lock.entry) input.text = Lock.entry;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === "" && !Lock.busy
                            text: "Enter Password"
                            color: surface.wash(0.38)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            renderType: Text.NativeRendering
                        }
                    }

                    // The right end of the field says one thing at a
                    // time: the keyboard is shouting, or there is
                    // something to submit. Caps Lock wins, because it
                    // is the one you did not choose.
                    Item {
                        id: trailing
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: glyph.text !== "" ? glyph.implicitWidth : 0
                        height: parent.height

                        Text {
                            id: glyph
                            anchors.centerIn: parent
                            text: Lock.capsLock ? Icons.capsLock
                                : (Lock.fingerprintArmed ? Icons.fingerprint : "")
                            color: Lock.capsLock ? Theme.error : Theme.primary
                            font.family: Theme.fontIcons
                            font.pixelSize: Theme.fontSizeNormal
                            renderType: Text.NativeRendering

                            // A reader gives no sign that it is
                            // listening, so the glyph has to. Slow
                            // enough to read as waiting rather than as
                            // something needing an answer.
                            SequentialAnimation on opacity {
                                running: Lock.fingerprintArmed && !Lock.capsLock
                                    && !Motion.reduced
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.40; duration: 900; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // One line, one height, whatever it is saying. A status
                // that changes the height of the column moves the field
                // you are typing into.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 18
                    text: surface.hint
                    color: surface.hintIsFault ? Theme.error : surface.wash(0.55)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                    topPadding: 4
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 34
                visible: Config.lock.showBattery && Battery.present
                text: Battery.icon + "  " + Battery.level + "%"
                color: surface.wash(0.42)
                font.family: Theme.fontIcons
                font.pixelSize: Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }
        }
    }
}
