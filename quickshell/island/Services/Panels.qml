pragma Singleton

import Quickshell
import QtQuick

// Whether the island has a panel open, for the catcher underneath it.
//
// The island owns its panels; Island/Catcher.qml only needs to know
// that one is open and to ask for it to close. This is the whole of
// what passes between them, so neither has to reach into the other.

Singleton {
    id: root

    // Set by the primary island. See Island.qml's panelOpen.
    property bool open: false

    // A click landed outside the island. The primary island answers.
    signal closeRequested()
}
