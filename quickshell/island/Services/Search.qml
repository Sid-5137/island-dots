pragma Singleton

import Quickshell
import QtQuick

// The launcher's index, and what it means for a query to match.
//
// Three things were wrong with doing this per keystroke, and they
// compounded: the work was redone from scratch every time, most of it
// was thrown away, and one whole tier of it could never be reached.
//
// The work is split now. An entry's searchable text is normalised once
// into the index below, when the desktop entries change; a keystroke
// only compares against strings that are already lowercase, already
// split into words, already joined. And a keystroke usually does not
// look at the whole index at all — see `refresh`.

Singleton {
    id: root

    property string query: ""

    // What the launcher shows: empty until you type, the way Spotlight
    // is. A list of everything is not an answer to a question nobody
    // has asked yet, and sorting one cost a localeCompare pass every
    // time the field went back to empty.
    //
    // A plain property rather than a binding, because `refresh` needs
    // to remember what it did last time.
    property var results: []

    // Everything a match is tested against, normalised once. None of
    // it depends on the query, so none of it belongs in the query path
    // — it was three C++ property reads, three toLowerCase calls and a
    // regex split per entry per keystroke.
    //
    // `starts` holds word OFFSETS rather than the words, so the
    // word-boundary test can use startsWith(pos) and never allocate.
    readonly property var index: {
        const all = DesktopEntries.applications.values;
        if (!all) return [];

        const out = [];

        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            if (e.noDisplay) continue;

            const name = (e.name || "").toLowerCase();

            // Word starts, and the string of first letters they spell
            // — "gnome color viewer" gives [0, 6, 12] and "gcv".
            const starts = [];
            let initials = "";
            let inWord = false;

            for (let j = 0; j < name.length; j++) {
                const c = name.charCodeAt(j);
                //  tab      space    -        .        _
                if (c === 9 || c === 32 || c === 45 || c === 46 || c === 95) {
                    inWord = false;
                    continue;
                }
                if (!inWord) {
                    inWord = true;
                    starts.push(j);
                    initials += name[j];
                }
            }

            // Keywords are a list on DesktopEntry. Flattened here
            // rather than walked per keystroke; the separator only has
            // to stop one keyword's tail matching the next one's head.
            const kw = e.keywords;

            out.push({
                entry:    e,
                name:     name,
                len:      name.length,
                starts:   starts,
                initials: initials,
                generic:  (e.genericName || "").toLowerCase(),
                comment:  (e.comment || "").toLowerCase(),
                keywords: (kw && kw.length ? kw.join(" ") : "").toLowerCase()
            });
        }

        return out;
    }

    // ── Narrowing ────────────────────────────────────────────
    //
    // The query this last ran for, and everything that matched it —
    // untruncated, which is the whole point: `results` is sliced for
    // display, and narrowing a sliced list would quietly lose entries
    // the next character was entitled to find.
    property string lastQuery: ""
    property var lastMatches: []

    onQueryChanged: refresh()

    onIndexChanged: {
        // An app was installed or removed, so the carried-over set is
        // no longer a safe pool to narrow from.
        lastQuery = "";
        lastMatches = [];
        refresh();
    }

    function refresh() {
        const q = query.trim().toLowerCase();

        if (q === "") {
            lastQuery = "";
            lastMatches = [];
            results = [];
            return;
        }

        // Every tier in `score` is prefix-monotone, so nothing can
        // match a longer query without having matched the shorter one
        // — the pool is last time's answer, not the whole index.
        // Backspacing breaks that relation and falls back to the
        // index.
        const pool = (lastQuery !== "" && q.startsWith(lastQuery))
            ? lastMatches : index;

        const scored = [];

        for (let i = 0; i < pool.length; i++) {
            const rec = pool[i];
            const s = score(rec, q);
            if (s > 0) scored.push({ rec: rec, score: s });
        }

        scored.sort(function(a, b) {
            if (b.score !== a.score) return b.score - a.score;
            return a.rec.len - b.rec.len;
        });

        const matches = new Array(scored.length);
        for (let i = 0; i < scored.length; i++) matches[i] = scored[i].rec;

        lastQuery = q;
        lastMatches = matches;

        const n = Math.min(matches.length, 40);
        const out = new Array(n);
        for (let i = 0; i < n; i++) out[i] = matches[i].entry;
        results = out;
    }

    // Tiers, best first. Written order IS test order, and it matters:
    // the word-boundary test must stay ABOVE the substring test. A
    // word starting with the query is also a substring containing it,
    // so indexOf wins first and the word tier becomes unreachable.
    function score(rec, q) {
        const name = rec.name;

        // The name, exactly.
        if (name === q) return 1000;

        // The name starts with it.
        if (name.startsWith(q)) return 900 - rec.len;

        // A word of the name starts with it: "ed" finds "text editor".
        const starts = rec.starts;
        for (let i = 1; i < starts.length; i++) {
            if (name.startsWith(q, starts[i])) return 800 - rec.len;
        }

        // The initials spell it: "gcv" finds "GNOME Color Viewer".
        // Two characters or more, because one initial is just a word
        // start and has already been answered above.
        if (q.length > 1 && rec.initials.startsWith(q)) return 750 - rec.len;

        // The name contains it somewhere.
        const idx = name.indexOf(q);
        if (idx > 0) return 700 - idx;

        // A keyword starts with it. Keywords are what the author of
        // the entry thought you might type, so they rank above the
        // prose fields underneath.
        if (rec.keywords.startsWith(q)) return 600;

        if (rec.generic.indexOf(q) >= 0) return 500;
        if (rec.keywords.indexOf(q) >= 0) return 400;
        if (rec.comment.indexOf(q) >= 0) return 300;

        // Last resort: the letters are all there, in order.
        if (subsequence(name, q)) return 200 - rec.len;

        return 0;
    }

    // Every character of q appears in s, in order.
    //
    // Indexed rather than `for (const ch of s)`, which iterates by code
    // point and hands back a one-character string each time — an
    // allocation per character of every name that got this far, on
    // every keystroke. Comparing char codes does the same job and
    // allocates nothing.
    function subsequence(s, q) {
        if (q.length > s.length) return false;

        let i = 0;
        for (let j = 0; j < s.length; j++) {
            if (s.charCodeAt(j) === q.charCodeAt(i) && ++i === q.length)
                return true;
        }
        return false;
    }

    function launch(entry) {
        if (entry) entry.execute();
    }
}
