pragma Singleton

// island-dots. GPL-3.0 — see LICENSE.

import Quickshell
import Quickshell.Io
import QtQuick

// Whether a fingerprint reader can be used at the lock screen, and
// which piece is missing if not. PAM does the authenticating; this
// only decides whether to mention fingerprints at all.
//
// Three things must line up, each failing silently on its own:
//
//   1. fprintd installed, and a reader the kernel can see
//   2. a finger enrolled for this user
//   3. /etc/pam.d/island present, with pamConfig pointing at it

Singleton {
    id: root

    property bool daemon: false      // fprintd is installed
    property bool device: false      // a reader is present
    property bool enrolled: false    // this user has a finger on file
    property bool pamFile: false     // /etc/pam.d/island exists

    // pamConfig has to name the file that carries pam_fprintd. Pointing
    // at "login" with a perfectly good /etc/pam.d/island sitting there
    // is the easiest of these to get wrong.
    readonly property bool pamSelected: Config.island.pamConfig === "island"

    readonly property bool ready:
        daemon && device && enrolled && pamFile && pamSelected

    // What to do next, or "" when there is nothing to say.
    readonly property string advice: {
        if (!daemon) return "fprintd is not installed.";
        if (!device) return "No fingerprint reader detected.";
        if (!enrolled)
            return "No finger enrolled. Run fprintd-enroll in a terminal.";
        if (!pamFile)
            return "/etc/pam.d/island is missing. Re-run install.sh to add it.";
        if (!pamSelected)
            return "Set PAM configuration to 'island' to use the reader.";
        return "";
    }

    function refresh() { probe.running = true }

    Process {
        id: probe
        running: true

        // One shell round trip rather than four. fprintd-list exits
        // non-zero and prints "No devices available" when there is no
        // reader, and lists the enrolled fingers when there is one.
        command: ["sh", "-c",
            'command -v fprintd-list >/dev/null 2>&1 && echo daemon; ' +
            '[ -e /etc/pam.d/island ] && echo pamfile; ' +
            'out=$(fprintd-list "$USER" 2>&1) || true; ' +
            'case "$out" in ' +
            '  *"No devices available"*) ;; ' +
            '  *) echo device ;; ' +
            'esac; ' +
            'case "$out" in ' +
            '  *"Fingerprints for user"*) echo enrolled ;; ' +
            'esac']

        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text.split("\n").map(l => l.trim());
                root.daemon   = found.indexOf("daemon") !== -1;
                root.pamFile  = found.indexOf("pamfile") !== -1;
                root.device   = root.daemon && found.indexOf("device") !== -1;
                root.enrolled = root.device && found.indexOf("enrolled") !== -1;
            }
        }
    }

    IpcHandler {
        target: "biometric"

        function status(): string {
            return "fprintd=" + root.daemon
                + " reader=" + root.device
                + " enrolled=" + root.enrolled
                + " pamFile=" + root.pamFile
                + " pamConfig=" + Config.island.pamConfig
                + " ready=" + root.ready
                + (root.advice !== "" ? "\n" + root.advice : "");
        }

        function refresh(): void { root.refresh() }
    }
}
