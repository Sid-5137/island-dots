pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Who is logged in.
//
// The lock screen is the only surface in the shell that names a person
// rather than a machine, so this is three values rather than a
// service: a login name, whatever the account was given for a full
// name, and a picture if one was ever set.
//
// All three are read once. A user who renames themselves mid-session
// has bigger things happening than a stale lock screen.

Singleton {
    id: root

    readonly property string login: Quickshell.env("USER") || ""

    // The GECOS field, which is where a full name lives on every unix
    // that has one. Falls back to the login name, which every account
    // has by definition.
    property string name: login

    // AccountsService is where every desktop that has ever asked for a
    // picture puts it. ~/.face is the older convention and costs one
    // line to honour.
    property string avatar: ""

    // For the circle when there is no picture. Two letters at most:
    // more than that stops being a monogram and starts being text set
    // too small to read.
    readonly property string initials: {
        const parts = (name || login).trim().split(/\s+/).filter(p => p !== "");
        if (parts.length === 0) return "?";
        if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
        return (parts[0].slice(0, 1) + parts[parts.length - 1].slice(0, 1))
            .toUpperCase();
    }

    Process {
        running: true

        // One round trip. `cut -d, -f1` because GECOS is a comma
        // separated list whose first field is the name and whose rest
        // is an office number nobody has filled in since 1985.
        command: ["sh", "-c",
            'printf "name=%s\\n" '
            + '"$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"; '
            + 'for p in "/var/lib/AccountsService/icons/$USER" '
            + '"$HOME/.face" "$HOME/.face.icon"; do '
            + '  [ -s "$p" ] && { printf "avatar=%s\\n" "$p"; break; }; '
            + 'done']

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq < 1) continue;
                    const key = line.slice(0, eq);
                    const val = line.slice(eq + 1).trim();
                    if (key === "name" && val !== "") root.name = val;
                    else if (key === "avatar" && val !== "") root.avatar = val;
                }
            }
        }
    }
}
