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

        Item {
            id: stage
            anchors.fill: parent

            // What's currently displayed.
            Image {
                id: back
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: win.screen.width
                sourceSize.height: win.screen.height
            }

            // The incoming image.
            Image {
                id: front
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: 0
                sourceSize.width: win.screen.width
                sourceSize.height: win.screen.height

                // Only start fading once the image has actually decoded,
                // or you fade in a blank rectangle.
                onStatusChanged: {
                    if (status === Image.Ready && source != "")
                        opacity = 1;
                    else if (status === Image.Error)
                        console.warn("WallpaperLayer: failed to load", source);
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.wallpaper.crossfadeDuration
                        easing.type: Easing.InOutQuad

                        onFinished: {
                            if (front.opacity === 1) {
                                back.source = front.source;
                                front.source = "";
                                front.opacity = 0;
                            }
                        }
                    }
                }
            }
        }

        // Drive the crossfade from the singleton.
        Connections {
            target: Wallpaper

            function onCurrentChanged() {
                const path = Wallpaper.current;
                if (path === "")
                    return;

                const url = "file://" + path;

                // First wallpaper of the session: no fade, just show it.
                if (back.source == "") {
                    back.source = url;
                    return;
                }

                if (url == back.source)
                    return;

                front.source = url;
            }
        }

        Component.onCompleted: {
            if (Wallpaper.current !== "")
                back.source = "file://" + Wallpaper.current;
        }
    }
}
