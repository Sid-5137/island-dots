import Quickshell
import Quickshell.Wayland
import QtQuick

import "root:/Services"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "island-wallpaper"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: Theme.background

        // Two images that swap which one is visible. Neither source is
        // ever cleared: clearing and reassigning during a fade meant a
        // wallpaper already held by the hidden layer could not be shown
        // again, which is why the one loaded at login could not be
        // returned to later in the session.
        Item {
            id: stage
            anchors.fill: parent

            property bool showA: true
            property Image pending: null

            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: win.screen.width
                sourceSize.height: win.screen.height
                opacity: stage.showA ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.wallpaper.crossfadeDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: win.screen.width
                sourceSize.height: win.screen.height
                opacity: stage.showA ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.wallpaper.crossfadeDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            readonly property Image visibleImage: showA ? imgA : imgB
            readonly property Image hiddenImage: showA ? imgB : imgA

            function show(url, animate) {
                if (visibleImage.source == url)
                    return;

                const incoming = hiddenImage;

                // Already decoded in the hidden layer — flip straight
                // to it. This is the path taken when returning to a
                // wallpaper shown earlier.
                if (incoming.source == url) {
                    if (incoming.status === Image.Ready) {
                        showA = !showA;
                        return;
                    }
                    pending = incoming;
                    return;
                }

                incoming.source = url;

                if (!animate) {
                    showA = !showA;
                    return;
                }

                if (incoming.status === Image.Ready)
                    showA = !showA;
                else
                    pending = incoming;
            }

            // Fade only once the incoming image has decoded, or the
            // crossfade runs against a blank rectangle.
            Connections {
                target: stage.pending
                enabled: stage.pending !== null

                function onStatusChanged() {
                    if (stage.pending.status === Image.Ready) {
                        stage.showA = !stage.showA;
                        stage.pending = null;
                    } else if (stage.pending.status === Image.Error) {
                        console.warn("WallpaperLayer: failed to load",
                                     stage.pending.source);
                        stage.pending = null;
                    }
                }
            }
        }

        // This screen's wallpaper, which is the shared one unless
        // per-monitor wallpapers are on and this screen has its own.
        readonly property string mine:
            Wallpaper.pathFor(win.screen ? win.screen.name : "")

        onMineChanged: {
            if (mine !== "") stage.show("file://" + mine, true);
        }

        Component.onCompleted: {
            if (mine !== "") {
                imgA.source = "file://" + mine;
                stage.showA = true;
            }
        }
    }
}
