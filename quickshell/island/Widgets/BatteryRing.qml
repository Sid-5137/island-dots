import QtQuick
import "root:/Services"

// A ring rather than a battery outline. The arc reads as a level at
// a glance without needing the number, and it stays legible at small
// sizes where a segmented battery icon turns to mush.

Item {
    id: root

    property int level: 0
    property bool charging: false
    property bool low: false
    // Thin enough to read as a gauge rather than a donut.
    property int thickness: Math.max(2, Math.round(width * 0.075))

    implicitWidth: 38
    implicitHeight: 38

    readonly property color ringColor:
        charging ? Theme.tertiary
        : low ? Theme.error
        : Theme.primary

    Canvas {
        id: canvas
        anchors.fill: parent

        // Repaint whenever anything it draws changes — a Canvas has
        // no bindings of its own.
        Connections {
            target: root
            function onLevelChanged() { canvas.requestPaint() }
            function onChargingChanged() { canvas.requestPaint() }
            function onLowChanged() { canvas.requestPaint() }
        }
        Connections {
            target: Theme
            function onPaletteChanged() { canvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            const r = Math.min(w, h) / 2 - root.thickness / 2;
            const cx = w / 2, cy = h / 2;

            ctx.reset();
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";

            // Track
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
            ctx.stroke();

            // Level. Starts at twelve o'clock and runs clockwise,
            // which is what people expect a gauge to do. A small gap
            // is left at the top even at 100% — a closed circle reads
            // as a plain outline rather than a full gauge.
            if (root.level > 0) {
                const gap = 0.10;
                const start = -Math.PI / 2 + gap;
                const span = (Math.PI * 2 - gap * 2) * (root.level / 100);
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + span);
                ctx.strokeStyle = root.ringColor;
                ctx.stroke();
            }
        }
    }

    // Charging shows a bolt instead of the number: the exact
    // percentage matters less than the fact that it's going up.
    Text {
        anchors.centerIn: parent
        visible: root.charging
        text: "\uf0e7"
        color: root.ringColor
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.height * 0.40)
    }

    Text {
        anchors.centerIn: parent
        visible: !root.charging
        text: root.level
        color: root.low ? Theme.error : Theme.text
        font.family: Theme.fontMono
        // 100 needs three digits in a 38px circle, so the type has to
        // stay small; two digits get the space they'd have had anyway.
        font.pixelSize: Math.round(root.height * (root.level >= 100 ? 0.28 : 0.34))
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
    }
}
