import QtQuick
import QtQuick.Effects
import "root:/Services"

// A panel over the wallpaper, blurred at the settings below it.
//
// Blur size, passes, brightness, contrast and panel opacity were five
// numbers describing something that only exists once a panel is over
// something busy — and the one panel in front of you while you set
// them is the settings window, which is drawn by the compositor and
// cannot show you its own blur changing.
//
// So: a strip of the current wallpaper, and a panel on it carrying the
// real settings. IslandPreview says "there is no blur available inside
// a settings window" — there is, through QtQuick.Effects; it just was
// not reached for.
//
// An approximation, and worth saying so. Hyprland runs a dual Kawase
// blur, where each pass samples further out than the last, and this is
// Qt's Gaussian one. The mapping below lands close enough that moving
// a slider moves the preview the same direction and about the same
// distance, which is what the preview is for. It is not a render of
// what the compositor will produce.

Item {
    id: root

    implicitWidth: parent ? parent.width : 400
    implicitHeight: 132

    readonly property var a: Config.appearance

    Rectangle {
        id: stage
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        radius: Theme.radiusNormal
        color: Theme.surfaceLowest
        clip: true

        Image {
            id: shot
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 900
            visible: status === Image.Ready
        }

        // The panel. Everything inside it is the wallpaper again,
        // blurred — which is what a compositor blur is: not a frosted
        // sheet laid on top, but the same pixels resampled.
        Item {
            id: panel
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.62)
            height: Math.round(parent.height * 0.62)

            Item {
                id: clipper
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                }

                // Offset so the crop under the panel is the part of
                // the wallpaper actually behind it, rather than the
                // top-left corner of it.
                MultiEffect {
                    x: -panel.x
                    y: -panel.y
                    width: stage.width
                    height: stage.height

                    source: shot
                    autoPaddingEnabled: false

                    blurEnabled: true
                    blurMax: 64
                    // Size is the sample radius and passes multiply how
                    // far it reaches. Hyprland's defaults — 8 and 3 —
                    // should land near the middle of the range rather
                    // than at either end of it.
                    blur: Math.max(0, Math.min(
                        1, root.a.blurSize * root.a.blurPasses / 48))

                    // Hyprland takes these as multipliers around 1.0;
                    // Qt takes them as offsets around 0.
                    brightness: Math.max(-1, Math.min(1, root.a.blurBrightness - 1))
                    contrast: Math.max(-1, Math.min(1, root.a.blurContrast - 1))

                    Behavior on blur {
                        NumberAnimation { duration: Motion.fadeIn }
                    }
                }
            }

            Item {
                id: mask
                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: root.a.panelRadius
                }
            }

            // The panel's own fill, at the opacity it is set to. Below
            // 1.0 this is what lets the blur show through at all, so
            // the two sliders are on the same picture on purpose.
            Rectangle {
                anchors.fill: parent
                radius: root.a.panelRadius
                color: Theme.surface
                opacity: root.a.panelOpacity

                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }
                Behavior on radius {
                    NumberAnimation {
                        duration: Motion.fadeIn
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Panel"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }
    }
}
