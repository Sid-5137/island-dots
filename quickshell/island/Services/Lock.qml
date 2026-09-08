pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

// Session lock state and authentication.
//
// The surface itself is in Lock/LockScreen.qml — this holds only the
// state, so the lock can be triggered from anywhere without the UI
// having to be reachable.
//
// If quickshell exits while locked, a conformant compositor leaves the
// screen locked and painted a solid colour. That is the protocol
// working as intended: a crashed locker must not expose the session.

Singleton {
    id: root

    property bool locked: false
    property string entry: ""
    property string message: ""
    property bool error: false
    property bool busy: false
    property int failures: 0

    function lock() {
        if (locked) return;
        entry = "";
        message = "";
        error = false;
        failures = 0;
        locked = true;
    }

    function submit() {
        if (busy || entry === "") return;
        busy = true;
        message = "";
        error = false;
        pam.start();
    }

    function cancel() {
        if (pam.active) pam.abort();
        busy = false;
        entry = "";
    }

    PamContext {
        id: pam

        // Defaults to "login", which exists on every distribution.
        // A dedicated file under /etc/pam.d would let fingerprint
        // readers work without also enabling them for tty logins.
        config: Config.island.pamConfig

        onPamMessage: {
            if (responseRequired) {
                pam.respond(root.entry);
                return;
            }
            if (message !== "") {
                root.message = message;
                root.error = messageIsError;
            }
        }

        onCompleted: function(result) {
            root.busy = false;
            if (result === PamResult.Success) {
                root.entry = "";
                root.message = "";
                root.error = false;
                root.locked = false;
            } else {
                root.failures += 1;
                root.entry = "";
                root.error = true;
                root.message = "Incorrect password";
            }
        }

        onError: function(err) {
            root.busy = false;
            root.error = true;
            root.message = "Authentication unavailable";
            console.warn("[Lock] pam error:", err);
        }
    }

    IpcHandler {
        target: "lock"

        function activate(): void { root.lock() }
        function status(): string { return root.locked ? "locked" : "unlocked" }
    }
}
