pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // [{ id, summary, body, appName, appIcon, image, urgency,
    //    time, actions, hasReply, replyHint }]
    //
    // Plain copies, with no reference to the Notification object —
    // see liveFor() for why.
    property var history: []
    property int maxHistory: 60

    // The most recent arrival, for the island's popup.
    property var latest: null

    signal arrived(var entry)

    readonly property int count: history.length
    readonly property bool hasUnread: unread > 0
    property int unread: 0

    function markRead() { unread = 0 }

    // The live Notification for a history entry, or null once the
    // sender has closed it.
    //
    // History deliberately stores plain copies and looks the object up
    // by id when it needs one. Holding the QObject directly does not
    // work: Notification is Retainable, so the instance handed to
    // onNotification is destroyed once that handler returns. The
    // JavaScript wrapper stays truthy afterwards and every property
    // read comes back undefined, so the failure surfaces as a
    // TypeError at the call site rather than anywhere informative —
    // which is what made inline reply and invoking an action from
    // history look like they were not implemented.
    //
    // The server keeps the ones it is tracking alive for us, and that
    // is exactly the set that can still be replied to or acted on.
    function liveFor(id) {
        const tracked = server.trackedNotifications;
        if (!tracked || !tracked.values) return null;
        for (const n of tracked.values) {
            if (n && n.id === id) return n;
        }
        return null;
    }

    function isLive(entry) { return !!entry && liveFor(entry.id) !== null }

    function release(entry) {
        if (!entry) return;
        const n = liveFor(entry.id);
        if (n) {
            try { n.tracked = false } catch (e) { /* already gone */ }
        }
    }

    function dismiss(entry) {
        if (!entry) return;
        release(entry);
        history = history.filter(e => e.id !== entry.id);
        if (latest && latest.id === entry.id) latest = null;
    }

    function clear() {
        for (const e of history) release(e);
        history = [];
        latest = null;
        unread = 0;
    }

    function invoke(entry, index) {
        const n = liveFor(entry ? entry.id : -1);
        if (!n) return;
        try {
            const a = n.actions[index];
            if (a) a.invoke();
        } catch (e) { /* the sender went away mid-click */ }
    }

    // Chat clients that advertise a reply expect the text back over
    // the same notification rather than through an action.
    function reply(entry, text) {
        if (!text) return false;
        const n = liveFor(entry ? entry.id : -1);
        if (!n) return false;
        try {
            n.sendInlineReply(text);
            return true;
        } catch (e) {
            // The sender closed the conversation, or went away
            // entirely, between the popup appearing and Enter.
            console.warn("[Notifications] inline reply failed:", e);
            return false;
        }
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
        // Clients only offer a reply box when the daemon says it can
        // take one, so this has to be on before any notification
        // arrives carrying hasInlineReply.
        inlineReplySupported: true

        onNotification: function(n) {
            // Carried over from a reload — already in history.
            if (n.lastGeneration) return;

            // The server discards a notification as soon as this
            // handler returns unless it is asked to keep it. Nothing
            // did, so trackedNotifications was always empty and every
            // reach back to the sender — an action invoked from
            // history, an inline reply — had nothing to reach.
            n.tracked = true;

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
                hasReply: n.hasInlineReply,
                replyHint: n.inlineReplyPlaceholder || "Reply"
            };

            const next = [entry, ...root.history];
            // Anything falling off the end still holds a lock, and a
            // lock nothing will ever release is a leak.
            for (const old of next.slice(root.maxHistory)) root.release(old);

            root.history = next.slice(0, root.maxHistory);
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

        // Whether the most recent notification offered a reply box,
        // and a way to exercise it without a pointer. Chat clients
        // are the only thing that sets this, so it is otherwise
        // awkward to test that the D-Bus side works.
        function replyState(): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            return e.appName + ": hasReply=" + (e.hasReply === true)
                 + " placeholder='" + (e.replyHint || "") + "'"
                 + " stillLive=" + root.isLive(e);
        }

        function invoke(index: int): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            if (!root.isLive(e)) return "the sender has closed it";
            if (index < 0 || index >= e.actions.length)
                return "no action " + index + " (has " + e.actions.length + ")";
            root.invoke(e, index);
            return "invoked '" + e.actions[index] + "'";
        }

        function reply(text: string): string {
            const e = root.history[0];
            if (!e) return "no notifications";
            if (e.hasReply !== true) return "that notification takes no reply";
            return root.reply(e, text) ? "sent" : "failed";
        }
        function last(): string {
            const e = root.history[0];
            return e ? e.appName + ": " + e.summary : "none";
        }
    }
}
