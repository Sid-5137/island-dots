//@ pragma UseQApplication

import Quickshell
import QtQuick

import "root:/Services"
import "root:/Background"
import "root:/Island"
import "root:/Settings"

// ─────────────────────────────────────────────────────────────
// Island — root
//
// Instantiates surfaces and nothing else. Logic lives in Services/,
// reusable controls in Widgets/, and each surface owns its folder.
// ─────────────────────────────────────────────────────────────

ShellRoot {
    WallpaperLayer {}
    Island {}
    Settings {}

    // QML creates singletons lazily, on first reference. These have no
    // visual component, so without touching them here they would only
    // load when some page happened to use them — and their startup
    // work (applying appearance, seeding polls) would never run.
    Component.onCompleted: {
        Compositor.apply();
        Theming.applyAll();
        Wm.refresh();
        Network.refresh();
        Bluetooth.refresh();
        Audio.refresh();
        Battery.refresh();
    }
}
