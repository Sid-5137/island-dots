pragma Singleton

import Quickshell
import QtQuick

// The icon for a window, from its class.
//
// A window's class is not an icon name. Firefox's is
// org.mozilla.firefox; the icon its .desktop file asks for is
// `firefox`, and that is the name an icon theme ships. Looking the
// class up directly only worked while the theme happened to carry an
// alias for it — switch to one that does not and the switcher drew the
// missing-image checkerboard, because the fallback it named,
// application-x-executable, was missing too.
//
// So: the .desktop file's own icon first, then the class as written,
// then its last dotted part, each checked against the theme. "" means
// nothing matched, and the caller draws its own fallback rather than a
// checkerboard.

Singleton {
    id: root

    function forClass(cls) {
        if (!cls) return "";

        const names = [];
        const entry = DesktopEntries.heuristicLookup(cls);
        if (entry && entry.icon) names.push(entry.icon);
        names.push(cls, cls.toLowerCase());
        const tail = cls.split(".").pop();
        if (tail !== cls) names.push(tail, tail.toLowerCase());

        for (const name of names) {
            // A .desktop file may name a file rather than a theme icon.
            if (name.startsWith("/")) return "file://" + name;
            const path = Quickshell.iconPath(name, true);
            if (path !== "") return path;
        }
        return "";
    }
}
