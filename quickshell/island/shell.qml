//@ pragma UseQApplication

// island-dots — a Hyprland shell built around a morphing pill.
// Copyright (C) 2026 Siddhartha Mallavolu
//
// This program is free software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. See LICENSE.

import Quickshell
import QtQuick

import "root:/Services"
import "root:/Background"
import "root:/Island"
import "root:/Settings"

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
        // Touching this claims org.freedesktop.Notifications. Nothing
        // else references it until a notification arrives, so without
        // this line the shell would never register as the daemon.
        Notifications.count;
        Clock.time;
    }
}
