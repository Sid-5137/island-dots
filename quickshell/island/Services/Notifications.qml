pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// ─────────────────────────────────────────────────────────────
// Notifications
//
// The shell IS the notification daemon — it claims
// org.freedesktop.Notifications, so mako or dunst must not be
// running alongside it.
//
// The server's own list is not used for history. Notifications are
// Retainable: they're destroyed once dismissed or expired, which
// would take them out of a history list too. Each one is copied to a
// plain object on arrival, and the live object kept alongside only
// while it's still valid, for invoking actions.
// ─────────────────────────────────────────────────────────────

Singleton {
    id: root

    // [{ id, summary, body, appName, appIcon, image, urgency,
    //    time, actions, live }]
    property var history: []
    property int maxHistory: 60

    // The most recent arrival, for the island's popup.
    property var latest: null

    signal arrived(var entry)

    readonly property int count: history.length
    readonly property bool hasUnread: unread > 0
    property int unread: 0

    function markRead() { unread = 0 }

    function dismiss(entry) {
        if (entry && entry.live) {
            try { entry.live.tracked = false } catch (e) { /* already gone */ }
        }
        history = history.filter(e => e.id !== entry.id);
        if (latest && latest.id === entry.id) latest = null;
    }

    function clear() {
        for (const e of history) {
            if (e.live) {
                try { e.live.tracked = false } catch (err) { /* already gone */ }
            }
        }
        history = [];
        latest = null;
        unread = 0;
    }

    function invoke(entry, index) {
        if (!entry || !entry.live) return;
        try {
            const a = entry.live.actions[index];
            if (a) a.invoke();
        } catch (e) { /* the sender went away */ }
    }

    function urgencyName(u) {
        if (u === NotificationUrgency.Critical) return "critical";
        if (u === NotificationUrgency.Low) return "low";
        return "normal";
    }

    NotificationServer {
        id: server

        // Advertised capabilities. Off by default in Quickshell, and
        // a client that isn't told images are supported won't send
        // one — so these have to be opted into.
        imageSupported: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(n) {
            // Carried over from a reload — already in history.
            if (n.lastGeneration) return;

            const entry = {
                id: n.id,
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                appIcon: n.appIcon,
                image: n.image,
                urgency: root.urgencyName(n.urgency),
                critical: n.urgency === NotificationUrgency.Critical,
                time: Date.now(),
                actions: n.actions.map(a => a.text),
                live: n
            };

            root.history = [entry, ...root.history].slice(0, root.maxHistory);
            root.unread += 1;

            // Focus mode records but doesn't interrupt. Critical
            // notifications ignore it — that's what critical means.
            if (!Config.island.dnd || entry.critical) {
                root.latest = entry;
                root.arrived(entry);
            }
        }
    }

    IpcHandler {
        target: "notifications"

        function count(): int { return root.history.length }
        function clear(): void { root.clear() }
        function last(): string {
            const e = root.history[0];
            return e ? e.appName + ": " + e.summary : "none";
        }
    }
}
