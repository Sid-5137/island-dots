pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string query: ""

    readonly property var results: {
        const all = DesktopEntries.applications.values;
        if (!all) return [];

        const q = query.trim().toLowerCase();

        // Empty query: everything, alphabetical.
        if (q === "") {
            return all
                .filter(e => !e.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))
                .slice(0, 60);
        }

        const scored = [];
        for (const e of all) {
            if (e.noDisplay) continue;
            const s = score(e, q);
            if (s > 0) scored.push({ entry: e, score: s });
        }

        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            return a.entry.name.length - b.entry.name.length;
        });

        return scored.slice(0, 40).map(x => x.entry);
    }

    function score(entry, q) {
        const name = (entry.name || "").toLowerCase();
        if (name === q) return 1000;
        if (name.startsWith(q)) return 900 - name.length;

        const idx = name.indexOf(q);
        if (idx > 0) return 700 - idx;

        // Word-boundary start: "text editor" matched by "ed"
        for (const word of name.split(/[\s\-_]+/)) {
            if (word.startsWith(q)) return 800 - name.length;
        }

        const generic = (entry.genericName || "").toLowerCase();
        if (generic.includes(q)) return 500;

        const comment = (entry.comment || "").toLowerCase();
        if (comment.includes(q)) return 300;

        if (subsequence(name, q)) return 200 - name.length;

        return 0;
    }

    // Every character of q appears in s, in order.
    function subsequence(s, q) {
        let i = 0;
        for (const ch of s) {
            if (ch === q[i]) i++;
            if (i === q.length) return true;
        }
        return false;
    }

    function launch(entry) {
        if (entry) entry.execute();
    }
}
