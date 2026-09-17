import QtQuick
import QtQuick.Window

// A runnable comparison. From this directory:
//
//     qml example.qml
//
// `qml` ships in Qt's declarative tooling — qt6-qtdeclarative-devel on
// Fedora, qt6-declarative-dev-tools on Debian. The component itself
// needs none of that; only this demo does.
//
// Left is Qt's Rectangle, right is a Squircle at the same radius, at
// four values of `smoothing`. At 2 the two are pixel-identical, which
// is the check that matters: the shape is a superellipse and a
// superellipse of exponent 2 is a circle.

Window {
    visible: true
    width: 560
    height: 460
    color: "#101014"
    title: "qml-squircle"

    Column {
        anchors.centerIn: parent
        spacing: 18

        Repeater {
            model: [2, 3, 4, 6]

            Row {
                required property var modelData
                spacing: 18

                Rectangle {
                    width: 230
                    height: 88
                    radius: 28
                    color: "#1c1c1e"
                    border.width: 1
                    border.color: "#4a4a4f"

                    Text {
                        anchors.centerIn: parent
                        text: "Rectangle"
                        color: "#8e8e93"
                        font.family: "monospace"
                    }
                }

                Squircle {
                    width: 230
                    height: 88
                    radius: 28
                    smoothing: parent.modelData
                    color: "#1c1c1e"
                    borderWidth: 1
                    borderColor: "#4a4a4f"

                    Text {
                        anchors.centerIn: parent
                        text: "Squircle  n=" + parent.smoothing
                        color: parent.smoothing === 2 ? "#8e8e93" : "#e5e5ea"
                        font.family: "monospace"
                    }
                }
            }
        }
    }
}
