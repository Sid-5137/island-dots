import QtQuick

import "root:/Services"
import "root:/Widgets"
import "root:/Widgets/Control"

// Arranging the control centre.
//
// The controls in the panel used to be a list in ControlMode.qml, so
// changing which ones were there, or where, meant editing QML and
// reloading the shell. saneAspect's answer to the same problem in
// Dynamite V3 is a drag-and-drop editor, and he is right that it is
// worth building: a control centre is the one part of a shell whose
// correct contents are different for every person using it.
//
//   https://www.youtube.com/watch?v=Ob98KFByTec
//
// Two things here are deliberately not what his does.
//
// The canvas is the panel, not a picture of one. Every card below is
// the same Widgets/Control/ControlItem.qml the island draws, at the
// same proportions, showing real state — the Wi-Fi card says which
// network, the month says which month. It is inert rather than
// redrawn: `live` is false, so a press starts a drag instead of
// turning your Wi-Fi off while you tidy up.
//
// And nothing is committed until you let go. Dragging onto a cell
// somebody else is in pushes them down while you hold it, the way a
// home screen does: you can see where they went, and letting go
// somewhere else puts them back, because the layout underneath has
// not changed yet. The canvas draws the arrangement you would get,
// not the one you have.

Column {
    id: page
    spacing: 4

    // nmcli and bluetoothctl poll by spawning processes, and they do
    // it only while something is reading them. This page is one of
    // the two places that does.
    Component.onCompleted: { Network.hold(); Bluetooth.hold() }
    Component.onDestruction: { Network.release(); Bluetooth.release() }

    // The item being dragged, and where it would land. While this is
    // set nothing is written, which is also what keeps the Repeater
    // below from rebuilding mid-drag and dropping the mouse grab.
    property int active: -1
    property int ghostX: 0
    property int ghostY: 0
    property int ghostW: 1
    property int ghostH: 1
    property bool resizing: false

    // What the canvas is drawing: the committed layout, or — while a
    // card is in hand — what that layout would become if you let go
    // here. Everything on the canvas measures itself against this, so
    // the cards being pushed aside move as you drag rather than after
    // you drop.
    //
    // Same order and length as the committed list, so a card can read
    // its own slot out of it by index without the Repeater above
    // having to rebuild — which mid-drag would drop the mouse grab.
    readonly property var layout: active >= 0
        ? ControlLayout.arrange(ControlLayout.items, active,
              { x: ghostX, y: ghostY, w: ghostW, h: ghostH })
        : ControlLayout.items

    // The grid has no fixed height: a push can grow it, and the rows
    // it grows by have to exist before the pushed card lands in them
    // or it is drawn outside the canvas and clipped.
    readonly property int rows: {
        let n = 0;
        for (const i of layout) n = Math.max(n, i.y + i.h);
        return Math.max(1, n);
    }

    function release() {
        if (active >= 0) {
            if (resizing) ControlLayout.resize(active, ghostW, ghostH);
            else ControlLayout.move(active, ghostX, ghostY);
        }
        active = -1;
        resizing = false;
    }

    SectionHeader { text: "Arrange" }

    Item {
        width: parent.width
        height: 44

        Text {
            id: toolLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Columns"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Row {
            id: columns
            anchors.left: toolLabel.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: [4, 5, 6, 7, 8]

                Rectangle {
                    required property var modelData
                    readonly property bool current:
                        modelData === ControlLayout.columns

                    width: 28
                    height: 28
                    radius: height / 2
                    color: current ? Theme.primary
                        : (colHover.containsMouse ? Theme.surfaceHigh
                                                  : "transparent")
                    border.width: 1
                    border.color: current ? Theme.primary : Theme.outlineVariant

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.current ? Theme.textOnPrimary : Theme.textDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: colHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ControlLayout.setColumns(parent.modelData)
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: [
                    { key: "tidy",  label: "Tidy" },
                    { key: "undo",  label: "Undo" },
                    { key: "reset", label: "Reset" }
                ]

                Rectangle {
                    required property var modelData
                    readonly property bool usable:
                        modelData.key !== "undo" || ControlLayout.canUndo

                    width: caption.implicitWidth + 22
                    height: 28
                    radius: Theme.radiusSmall
                    color: actHover.containsMouse && usable
                        ? Theme.surfaceHigh : "transparent"
                    border.width: 1
                    border.color: Theme.outlineVariant
                    opacity: usable ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: Motion.fadeIn } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fadeIn } }

                    Text {
                        id: caption
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: actHover
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: parent.usable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (parent.modelData.key) {
                                case "tidy":  ControlLayout.tidy(); break;
                                case "undo":  ControlLayout.undo(); break;
                                default:      ControlLayout.reset();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── The canvas ───────────────────────────────────────────

    Item {
        id: canvasBox
        width: parent.width
        height: canvas.height + 20

        Rectangle {
            id: canvas

            // The panel's real width where it fits, so the cards are
            // the size they will actually be. The settings pane is a
            // few pixels narrower than the widest panel anyone can
            // configure, which is the only case that scales.
            width: Math.min(parent.width, Config.island.controlWidth)
            height: Config.island.controlPad * 2
                  + ControlLayout.itemHeight(page.rows)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            // The panel's own line, against the panel's own height —
            // see Theme.corner. This canvas claims to be the control
            // centre at its real size, and it was drawing the slider's
            // number flat: 14 where the real panel, ten times taller
            // than the pill, opens its corner out to 36.
            radius: Theme.corner(height)
            color: page.tint(Theme.surfaceLowest, Config.island.opacity)
            border.width: 1
            border.color: Theme.outlineVariant
            clip: true

            // It claims to be the control centre at its real size, so
            // it carries the control centre's edge too. A canvas that
            // is right about the corner and wrong about what is drawn
            // on it is a preview of something else.
            Bezel { z: 99; outer: parent.radius }

            // The cells, so an empty part of the panel still reads as
            // somewhere a control could go.
            Repeater {
                model: ControlLayout.columns * page.rows

                Rectangle {
                    required property int index
                    readonly property int cx: index % ControlLayout.columns
                    readonly property int cy: Math.floor(index / ControlLayout.columns)

                    x: ControlLayout.itemX(canvas.width, cx)
                    y: ControlLayout.itemY(cy)
                    width: ControlLayout.itemWidth(canvas.width, 1)
                    height: ControlLayout.itemHeight(1)

                    visible: !ControlLayout.occupiedIn(page.layout, cx, cy)

                    radius: Theme.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            Repeater {
                id: cards
                model: ControlLayout.items

                Item {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property bool dragging: page.active === index

                    // Its slot in the arrangement the canvas is
                    // drawing — where it is, or where this drag would
                    // put it. The card being dragged is the preview
                    // itself, so there is no second rectangle chasing
                    // the cursor, and the ones it displaces animate to
                    // the slots they would end up in.
                    readonly property var slot: page.layout[index] || modelData

                    readonly property int cellX: slot.x
                    readonly property int cellY: slot.y
                    readonly property int cellW: slot.w
                    readonly property int cellH: slot.h

                    x: ControlLayout.itemX(canvas.width, cellX)
                    y: ControlLayout.itemY(cellY)
                    width: ControlLayout.itemWidth(canvas.width, cellW)
                    height: ControlLayout.itemHeight(cellH)

                    z: dragging ? 10 : 1

                    // The lift. A card in hand sits a little above the
                    // ones it is being dragged over, which is most of
                    // what makes a drag feel like picking something up
                    // rather than like editing two numbers.
                    scale: dragging ? 1.04 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.hover
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.arrive
                        }
                    }

                    // Snapping between cells is the whole feedback, so
                    // it is animated. Not while dragging: a spring
                    // between the pointer and the card is lag.
                    Behavior on x {
                        enabled: !card.dragging
                        NumberAnimation {
                            duration: Motion.hover
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.arrive
                        }
                    }
                    Behavior on y {
                        enabled: !card.dragging
                        NumberAnimation {
                            duration: Motion.hover
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Motion.arrive
                        }
                    }

                    ControlItem {
                        anchors.fill: parent
                        itemKey: card.modelData.key
                        labels: card.modelData.text !== false
                        live: false
                        opacity: card.dragging ? 0.85 : 1
                    }

                    // The card in hand, marked as such. It used to
                    // go red where a move was refused; a drop is not
                    // refused any more, because anything already there
                    // moves out of the way.
                    Rectangle {
                        anchors.fill: parent
                        visible: card.dragging
                        radius: Theme.radiusLarge
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: card.dragging
                            ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        // The page is a Flickable, and a Flickable
                        // takes the grab off whatever it contains the
                        // moment a press turns into a drag — so
                        // dragging a card upwards scrolled the
                        // settings page instead of moving the card,
                        // and the card stayed where it was. A card is
                        // never a scroll gesture: the wheel still
                        // scrolls, and the pointer over a card is
                        // holding it.
                        preventStealing: true

                        property real grabX: 0
                        property real grabY: 0

                        onPressed: function(m) {
                            page.active = card.index;
                            page.resizing = false;
                            page.ghostX = card.modelData.x;
                            page.ghostY = card.modelData.y;
                            page.ghostW = card.modelData.w;
                            page.ghostH = card.modelData.h;
                            grabX = m.x;
                            grabY = m.y;
                        }

                        onPositionChanged: function(m) {
                            if (!pressed || page.active !== card.index) return;

                            // Where the card's top-left has been
                            // dragged to, in cells, rounded to the
                            // nearest rather than the one it is over —
                            // otherwise a card only ever moves once
                            // its corner has fully crossed a line, and
                            // wide cards feel stuck.
                            const stepX = ControlLayout.itemWidth(canvas.width, 1)
                                        + Config.island.controlGap;
                            const stepY = ControlLayout.itemHeight(1)
                                        + Config.island.controlGap;

                            const px = card.x + m.x - grabX
                                     - Config.island.controlPad;
                            const py = card.y + m.y - grabY
                                     - Config.island.controlPad;

                            // Held to the grid rather than refused
                            // at the edge of it: a card dragged past
                            // the right-hand column stops against it,
                            // and one dragged off the bottom lands in
                            // a new row under everything rather than
                            // somewhere out in the void.
                            const cx = Math.max(0, Math.min(
                                ControlLayout.columns - page.ghostW,
                                Math.round(px / stepX)));
                            const cy = Math.max(0, Math.min(
                                ControlLayout.rows, Math.round(py / stepY)));

                            page.ghostX = cx;
                            page.ghostY = cy;
                        }

                        onReleased: page.release()
                        onCanceled: page.release()
                    }

                    // Remove. Top-left, away from the resize handle,
                    // and only while the pointer is on the card —
                    // fourteen permanent red dots would make the panel
                    // look like it was on fire.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: -4
                        width: 15
                        height: 15
                        radius: height / 2
                        visible: cardHover.containsMouse || killHover.containsMouse
                        color: killHover.containsMouse
                            ? Theme.error : Qt.darker(Theme.error, 1.3)
                        z: 20

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: Theme.textOnError
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: killHover
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ControlLayout.remove(card.index)
                        }
                    }

                    // Words on or off, next to the remove dot. Only
                    // for the controls that have words separable from
                    // what they are: a month is its dates.
                    Rectangle {
                        readonly property bool labelled: {
                            const spec = ControlLayout.spec(card.modelData.key);
                            return !!spec && spec.labelled === true;
                        }
                        readonly property bool on: card.modelData.text !== false

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: -4
                        width: 22
                        height: 15
                        radius: height / 2
                        visible: labelled
                                 && (cardHover.containsMouse
                                     || textHover.containsMouse)
                        color: on ? Theme.primary
                            : (textHover.containsMouse ? Theme.surfaceHighest
                                                       : Theme.surfaceHigh)
                        z: 20

                        Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                        Text {
                            anchors.centerIn: parent
                            text: "Aa"
                            color: parent.on ? Theme.textOnPrimary : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: textHover
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ControlLayout.setText(
                                card.index, !parent.on)
                        }
                    }

                    // Resize, from the corner.
                    Item {
                        id: grip
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 16
                        height: 16
                        visible: cardHover.containsMouse || gripDrag.pressed
                        z: 20

                        Repeater {
                            model: 2

                            Rectangle {
                                required property int index
                                x: 11 - index * 4
                                y: 3 + index * 4
                                width: 2 + index * 4
                                height: 2
                                radius: height / 2
                                color: Theme.text
                                opacity: 0.7
                                rotation: -45
                                transformOrigin: Item.Center
                            }
                        }

                        MouseArea {
                            id: gripDrag
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.SizeFDiagCursor

                            // As above: a resize that runs downwards
                            // is not the page asking to be scrolled.
                            preventStealing: true

                            onPressed: {
                                page.active = card.index;
                                page.resizing = true;
                                page.ghostX = card.modelData.x;
                                page.ghostY = card.modelData.y;
                                page.ghostW = card.modelData.w;
                                page.ghostH = card.modelData.h;
                            }

                            onPositionChanged: function(m) {
                                if (!pressed || page.active !== card.index) return;

                                const stepX = ControlLayout.itemWidth(canvas.width, 1)
                                            + Config.island.controlGap;
                                const stepY = ControlLayout.itemHeight(1)
                                            + Config.island.controlGap;

                                // Width in cells from the pointer's
                                // distance past the card's own left
                                // edge, so the arithmetic does not
                                // depend on where within the grip the
                                // press landed.
                                // n cells span n*step - gap, so the
                                // gap goes back on before dividing or
                                // every card reads a fraction narrow.
                                const spec = ControlLayout.spec(card.modelData.key);
                                const w = Math.max(spec.minW, Math.min(
                                    ControlLayout.columns - card.modelData.x,
                                    Math.round((grip.x + m.x
                                        + Config.island.controlGap) / stepX)));
                                const h = Math.max(spec.minH, Math.round(
                                    (grip.y + m.y + Config.island.controlGap) / stepY));

                                page.ghostW = w;
                                page.ghostH = h;
                            }

                            onReleased: page.release()
                            onCanceled: page.release()
                        }
                    }

                    // Declared last so it sits over the card and under
                    // nothing: it only reports hover, and the handles
                    // above it take their own clicks.
                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        z: -1
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Drag to move · corner to resize · Aa for words · × to remove"
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall - 1
        bottomPadding: 10
        renderType: Text.NativeRendering
    }

    // ── The palette ──────────────────────────────────────────

    SectionHeader { text: "Add" }

    Flow {
        width: parent.width
        spacing: 6
        bottomPadding: 12

        Repeater {
            model: ControlLayout.unplaced

            Rectangle {
                required property var modelData
                readonly property var spec: ControlLayout.spec(modelData)

                width: chip.implicitWidth + 44
                height: 34
                radius: Theme.radiusSmall
                color: addHover.containsMouse ? Theme.surfaceHigh : "transparent"
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color { ColorAnimation { duration: Motion.fadeIn } }

                Text {
                    id: chipGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.spec ? parent.spec.glyph : ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Text {
                    id: chip
                    anchors.left: chipGlyph.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.spec ? parent.spec.name : parent.modelData
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: addHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ControlLayout.add(parent.modelData)
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: ControlLayout.unplaced.length === 0
        text: "Everything is already in the panel."
        color: Theme.outline
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        bottomPadding: 12
        renderType: Text.NativeRendering
    }

    // ── The rest ─────────────────────────────────────────────

    SectionHeader { text: "Panel"; advanced: true }

    SliderRow {
        configKey: "island.controlWidth"
        advanced: true
        label: "Width"
        description: "The canvas above is this size."
        from: 420; to: 720; stepSize: 4; suffix: " px"
        value: Config.island.controlWidth
        onMoved: function(v) { Config.island.controlWidth = v }
    }

    SliderRow {
        configKey: "island.controlCell"
        advanced: true
        label: "Row height"
        description: "How tall one cell is."
        from: 36; to: 72; stepSize: 2; suffix: " px"
        value: Config.island.controlCell
        onMoved: function(v) { Config.island.controlCell = v }
    }

    SliderRow {
        configKey: "island.controlGap"
        advanced: true
        label: "Gap"
        from: 0; to: 20; stepSize: 1; suffix: " px"
        value: Config.island.controlGap
        onMoved: function(v) { Config.island.controlGap = v }
    }

    SliderRow {
        configKey: "island.controlPad"
        advanced: true
        label: "Padding"
        from: 8; to: 32; stepSize: 1; suffix: " px"
        value: Config.island.controlPad
        onMoved: function(v) { Config.island.controlPad = v }
    }

    // Theme colours are hex strings with no alpha; this re-emits one
    // with the island's, so the canvas is the same surface the panel
    // is rather than a flat approximation of it.
    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }
}
