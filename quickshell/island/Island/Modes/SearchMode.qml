import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick

import "root:/Services"
import "root:/Widgets"

// Application launcher. The pill widens into a search field and
// grows downward as results arrive.
//
// QML ids do not resolve across files, so the surfaces this needs are
// passed in rather than looked up.

Item {
    id: root

    required property var win      // the PanelWindow
    required property var island   // mode flags and media state
    required property var pill     // the shape, for geometry gates
    anchors.fill: parent

    // Same geometry gate as the other content: the
    // field can't render inside a pill that hasn't
    // widened to hold it yet.
    readonly property bool shown: island.isSearching

    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity { ContentFade { revealing: root.shown } }

    Item {
        id: fieldRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.island.searchFieldHeight

        Text {
            id: caret
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "\u276f"
            color: Theme.primary
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Config.island.fontWeight
            renderType: Text.NativeRendering
        }

        TextInput {
            id: input
            Component.onCompleted: win.searchInput = input

            anchors.left: caret.right
            anchors.leftMargin: 12
            anchors.right: hitCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            selectionColor: Qt.rgba(1, 1, 1, 0.25)
            selectedTextColor: Theme.text
            clip: true

            onTextChanged: {
                Search.query = text;
                if (win.searchList) win.searchList.currentIndex = 0;
            }

            Keys.onEscapePressed: win.closeSearch()
            Keys.onReturnPressed: win.runSelected()
            Keys.onEnterPressed: win.runSelected()
            Keys.onDownPressed: results.incrementCurrentIndex()
            Keys.onUpPressed: results.decrementCurrentIndex()

            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        results.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        results.decrementCurrentIndex();
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: "Search"
                color: Theme.outline
                font: input.font
                renderType: Text.NativeRendering
            }
        }

        Text {
            id: hitCount
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: input.text === "" ? "" : Search.results.length
            color: Theme.outline
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: 1
            color: Theme.outlineVariant
            opacity: Search.results.length > 0 && input.text !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    ListView {
        id: results
        Component.onCompleted: win.searchList = results

        anchors.top: fieldRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 6

        model: ScriptModel {

            values: Search.results

        }
        clip: true
        currentIndex: 0
        highlightMoveDuration: 110
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 44
        preferredHighlightEnd: height - 44

        delegate: Rectangle {
            required property var modelData
            required property int index

            readonly property bool active: index === results.currentIndex

            width: results.width
            height: Config.island.searchRowHeight
            color: active ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.active ? 20 : 0
                color: Theme.primary
                Behavior on height {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
            }

            IconImage {
                id: rowIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 22
                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
            }

            Text {
                anchors.left: rowIcon.right
                anchors.leftMargin: 12
                anchors.right: rowGeneric.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: parent.active ? Theme.primary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Config.island.fontWeight
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                id: rowGeneric
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                horizontalAlignment: Text.AlignRight
                text: modelData.genericName || ""
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    results.currentIndex = index;
                    win.runSelected();
                }
            }
        }
    }
}
