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

    // Caps Lock, read off the keyboard's own LED — see the Process
    // below. A password field shows dots, so the one typo it cannot
    // show you is the one the keyboard is making on purpose.
    property bool capsLock: false

    // Seconds left before the field takes a password again. Counting
    // down rather than an end timestamp, because the surface wants to
    // print the number and a timestamp would have to be subtracted on
    // every tick anyway.
    property int cooldown: 0
    readonly property bool waiting: cooldown > 0

    function lock() {
        if (locked) return;
        entry = "";
        message = "";
        error = false;
        failures = 0;
        cooldown = 0;
        fingerprintTries = 0;
        locked = true;
        armFingerprint();
    }

    function submit() {
        if (busy || waiting || entry === "") return;

        // The reader and the password stack both want fprintd, and
        // only one of them can have it. The password is the one the
        // user just chose.
        if (fp.active) fp.abort();

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

    function unlock() {
        if (fp.active) fp.abort();
        entry = "";
        message = "";
        error = false;
        busy = false;
        cooldown = 0;
        locked = false;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.cooldown > 0
        onTriggered: root.cooldown -= 1
    }

    // ── Password ─────────────────────────────────────────────
    //
    // Unchanged from the day this worked: started on submit, answers
    // every prompt with whatever is in the field. If PAM is
    // misconfigured the only way back into the session is a TTY, so
    // this path stays the simplest thing that can possibly work and
    // the fingerprint experiment happens in its own context below.

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
                root.unlock();
            } else {
                root.failures += 1;
                root.entry = "";
                root.error = true;
                root.message = "Incorrect password";

                // Every nth wrong password buys a wait. Modulo rather
                // than a one-shot so the wait comes back on the next
                // run of failures instead of being spent once.
                const limit = Config.lock.attemptsBeforeDelay;
                if (limit > 0 && root.failures % limit === 0)
                    root.cooldown = Config.lock.delaySeconds;

                root.armFingerprint();
            }
        }

        onError: function(err) {
            root.busy = false;
            root.error = true;
            root.message = "Authentication unavailable";
            console.warn("[Lock] pam error:", err);
        }
    }

    // ── Fingerprint ──────────────────────────────────────────
    //
    // Its own conversation, started when the lock engages rather than
    // when a password is submitted.
    //
    // It cannot share the password one. PAM is a sequence and
    // pam_fprintd sits in front of pam_unix, so a single conversation
    // would make you wait for the reader to give up — three failed
    // swipes — before it would let you start typing. A reader that
    // takes the keyboard away from you is worse than no reader.
    //
    // Two conversations means two claims on fprintd, so exactly one is
    // ever live: submit() aborts this before starting the password,
    // and this aborts itself the moment its own stack falls through to
    // a password prompt, which is pam_fprintd's way of saying it is
    // finished with the device.

    readonly property bool fingerprintArmed: fp.active && locked

    // Swipes this lock has re-armed for. Bounded because the failure
    // that matters is not a finger the reader dislikes — it is a
    // conversation that ends the instant it starts, which a timer
    // would otherwise retry forever at a fixed interval. Generous
    // enough that nobody reaches it by fumbling.
    property int fingerprintTries: 0
    readonly property int fingerprintLimit: 20

    function armFingerprint() {
        if (!locked || !Biometric.ready || fp.active || busy) return;
        if (fingerprintTries >= fingerprintLimit) return;
        fingerprintTries += 1;
        fp.start();
    }

    // Re-arm after a swipe that was not recognised. Delayed, because
    // pam_fprintd can fail immediately — a reader that is unplugged,
    // a device another process is holding — and an immediate restart
    // on an immediate failure is a spin.
    Timer {
        id: rearm
        interval: 600
        onTriggered: root.armFingerprint()
    }

    PamContext {
        id: fp

        config: Config.island.pamConfig

        onPamMessage: {
            // A prompt means pam_fprintd has given up and the stack has
            // moved on to the password module. That module is the other
            // context's job, so let go of the device here.
            if (responseRequired) {
                fp.abort();
                root.message = "";
                return;
            }

            // "Place your finger on the fingerprint reader", and
            // whatever it says about a swipe it did not like. Never
            // overwrite a password error with it: the wrong password
            // you just typed is the more useful of the two.
            if (message !== "" && !root.error)
                root.message = message;
        }

        onCompleted: function(result) {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            // Not a failed password — nothing to count, and nothing to
            // say that the reader has not said already.
            if (root.locked && !root.busy) rearm.restart();
        }

        onError: function(err) {
            // Silent on purpose. The password field is right there and
            // works; a reader that cannot start is not worth a line of
            // red text over the one control that matters.
            console.warn("[Lock] fingerprint pam error:", err);
        }
    }

    // Enrolling a finger, or pointing pamConfig at the file that
    // carries pam_fprintd, should not need the lock cycling to take
    // effect.
    Connections {
        target: Biometric
        function onReadyChanged() { root.armFingerprint() }
    }

    // ── Caps Lock ────────────────────────────────────────────
    //
    // The keyboard LED, which is the only place the state is legible
    // without a compositor that reports modifiers. One shell loop for
    // the duration of the lock rather than a process per poll, and it
    // exits with the surface.
    //
    // Every keyboard gets its own led device, so this is the OR of all
    // of them: on a laptop with an external keyboard plugged in, the
    // one you are typing on is the one that is lit.

    Process {
        running: root.locked

        command: ["sh", "-c",
            'prev=""; ' +
            'while :; do ' +
            '  v=0; ' +
            '  for f in /sys/class/leds/*::capslock/brightness; do ' +
            '    [ -r "$f" ] || continue; ' +
            '    read -r b < "$f" || continue; ' +
            '    [ "$b" = "0" ] || v=1; ' +
            '  done; ' +
            '  [ "$v" = "$prev" ] || { echo "$v"; prev=$v; }; ' +
            '  sleep 0.2; ' +
            'done']

        stdout: SplitParser {
            onRead: function(line) { root.capsLock = line.trim() === "1" }
        }

        // No reader while unlocked, so the last value it saw would
        // otherwise be the one the next lock opens with.
        onRunningChanged: if (!running) root.capsLock = false
    }

    IpcHandler {
        target: "lock"

        function activate(): void { root.lock() }
        function status(): string { return root.locked ? "locked" : "unlocked" }
    }
}
