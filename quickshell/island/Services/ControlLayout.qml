pragma Singleton

import Quickshell
import QtQuick

// What the control centre is made of, and where each piece sits.
//
// The arrangement is data, in settings.json, on a grid of `columns`
// columns. Cells rather than pixels so a layout survives the panel
// being widened:
//
//     wifi:3,0,3,1
//     ^    ^ ^ ^ ^
//     key  x y w h
//
// Add a control by adding a catalogue entry below and a case in
// Widgets/Control/ControlItem.qml — not by editing a layout.

Singleton {
    id: root

    // ── The catalogue ────────────────────────────────────────
    //
    //   kind      which delegate draws it
    //   min       the smallest span that still reads
    //   def       what it gets when placed from the palette
    //   labelled  has words beside the glyph that can be turned off.
    //             Absent for the two whose words ARE the control: a
    //             month with no dates and a notification list with no
    //             notifications are not smaller, they are empty.
    readonly property var catalogue: ({
        calendar: {
            name: "Calendar", glyph: "", kind: "month",
            minW: 3, minH: 4, defW: 3, defH: 5
        },
        wifi: {
            name: "Wi-Fi", glyph: "", kind: "conn",
            minW: 1, minH: 1, defW: 3, defH: 1, labelled: true
        },
        bluetooth: {
            name: "Bluetooth", glyph: "", kind: "conn",
            minW: 1, minH: 1, defW: 3, defH: 1, labelled: true
        },
        media: {
            name: "Now playing", glyph: "", kind: "media",
            minW: 2, minH: 2, defW: 3, defH: 2, labelled: true
        },
        sound: {
            name: "Sound", glyph: "", kind: "level",
            minW: 1, minH: 1, defW: 6, defH: 1, labelled: true
        },
        display: {
            name: "Display", glyph: "", kind: "level",
            minW: 1, minH: 1, defW: 3, defH: 1, labelled: true
        },
        notifications: {
            name: "Notifications", glyph: "", kind: "notes",
            minW: 3, minH: 2, defW: 6, defH: 3
        },
        clock: {
            name: "Clock", glyph: "", kind: "clock",
            minW: 2, minH: 1, defW: 3, defH: 1, labelled: true
        },
        battery: {
            name: "Battery", glyph: "", kind: "battery",
            minW: 1, minH: 1, defW: 2, defH: 1, labelled: true
        },
        mic: {
            name: "Microphone", glyph: "", kind: "toggle",
            minW: 1, minH: 1, defW: 1, defH: 1, labelled: true
        },
        dnd: {
            name: "Focus", glyph: "", kind: "toggle",
            minW: 1, minH: 1, defW: 1, defH: 1, labelled: true
        },
        caffeine: {
            name: "Keep awake", glyph: "", kind: "toggle",
            minW: 1, minH: 1, defW: 1, defH: 1, labelled: true
        },
        lock: {
            name: "Lock", glyph: "", kind: "toggle",
            minW: 1, minH: 1, defW: 1, defH: 1, labelled: true
        },
        settings: {
            name: "Settings", glyph: "", kind: "toggle",
            minW: 1, minH: 1, defW: 1, defH: 1, labelled: true
        }
    })

    function spec(key) { return catalogue[key] || null }

    readonly property int columns: Config.island.controlColumns

    // The grid grows downwards as cards are pushed, but a card's own
    // height needs a ceiling: it feeds the island window's height, and
    // an unbounded drag makes a panel taller than the screen.
    readonly property int maxRows: 12

    // ── Reading and writing ──────────────────────────────────
    //
    // The parse is deliberately forgiving. This string is editable by
    // hand, and a typo in it should cost one control rather than the
    // whole panel: an unknown key, a bad number or a rectangle that
    // hangs off the right-hand edge is dropped, and what is left still
    // draws.

    readonly property var items: parse(Config.island.controlLayout)

    function parse(text) {
        const out = [];
        for (const chunk of String(text).split(";")) {
            const s = chunk.trim();
            if (s === "") continue;

            const colon = s.indexOf(":");
            if (colon < 0) continue;

            const key = s.slice(0, colon).trim();
            if (!catalogue[key]) continue;

            const n = s.slice(colon + 1).split(",").map(v => parseInt(v, 10));
            // Four fields, or five. The fifth is whether the control
            // shows its label, and it is optional so that every layout
            // written before it existed still means what it said.
            if (n.length < 4 || n.length > 5
                || n.some(v => !Number.isFinite(v))) continue;

            const spec = catalogue[key];
            const w = Math.max(spec.minW, n[2]);
            const h = Math.max(spec.minH, Math.min(maxRows, n[3]));
            if (n[0] < 0 || n[1] < 0 || n[0] + w > columns) continue;

            out.push({ key: key, x: n[0], y: n[1], w: w, h: h,
                       text: n.length < 5 || n[4] !== 0 });
        }
        return out;
    }

    // The fifth field is written only when it is off, so a layout
    // that has never been touched reads the way it always did.
    function serialise(list) {
        return list.map(i => i.key + ":" + i.x + "," + i.y
                           + "," + i.w + "," + i.h
                           + (i.text === false ? ",0" : ""))
                   .join(";");
    }

    // Every mutation goes through here, so undo needs no other hook
    // and nothing can change the layout without being undoable.
    //
    // An entry is the layout AND the column count. Undoing a column
    // change by restoring the string alone puts a six-column layout
    // back on a four-column grid, and parse — correctly — drops
    // everything hanging off the edge. The undo would delete
    // controls.
    property var history: []

    function remember() {
        const h = history.slice(-19);
        h.push({ layout: Config.island.controlLayout,
                 columns: Config.island.controlColumns });
        history = h;
    }

    function commit(list) {
        const next = serialise(list);
        if (next === Config.island.controlLayout) return;

        remember();
        Config.island.controlLayout = next;
    }

    readonly property bool canUndo: history.length > 0

    function undo() {
        if (history.length === 0) return;
        const h = history.slice();
        const previous = h.pop();
        history = h;

        // Columns first: the layout is parsed against them, so the
        // other order reads the old string through the new grid for
        // one pass and drops whatever does not fit.
        Config.island.controlColumns = previous.columns;
        Config.island.controlLayout = previous.layout;
    }

    function reset() {
        const shipped = Config.defaultFor("island.controlLayout");
        if (shipped === undefined) return;

        // The columns go back too. Reset with the grid left at four
        // would drop every shipped control that needs six, and call
        // the remains the default layout.
        remember();

        const cols = Config.defaultFor("island.controlColumns");
        if (cols !== undefined) Config.island.controlColumns = cols;

        Config.island.controlLayout = shipped;
    }

    // ── The grid ─────────────────────────────────────────────

    readonly property int rows: {
        let n = 0;
        for (const i of items) n = Math.max(n, i.y + i.h);
        // An empty panel is still a panel. One row of nothing is
        // better than a pill that has expanded to zero height.
        return Math.max(1, n);
    }

    function overlaps(a, b) {
        return a.x < b.x + b.w && b.x < a.x + a.w
            && a.y < b.y + b.h && b.y < a.y + a.h;
    }

    // Whether `rect` is on the grid at all. Separate from `fits`
    // because a drag no longer asks whether a cell is free — it asks
    // only whether the cell exists, and pushes whoever is in it.
    function inBounds(rect) {
        return rect.x >= 0 && rect.y >= 0 && rect.x + rect.w <= columns;
    }

    // Whether `rect` may sit at that position — on the grid, and clear
    // of everything except the item it replaces. Still what `add` asks
    // when it is looking for a gap to drop a new control into.
    function fits(list, ignore, rect) {
        if (!inBounds(rect)) return false;
        for (let i = 0; i < list.length; i++) {
            if (i === ignore) continue;
            if (overlaps(list[i], rect)) return false;
        }
        return true;
    }

    // Where everything ends up if `index` is dropped at `rect`.
    //
    // What the card lands on is pushed down the least it takes to
    // clear, cascading. Nothing else moves — a gap you left is a gap
    // you meant, and `tidy` is the only thing that closes one.
    //
    // Pure, and called on every step of a drag, so the list the editor
    // draws is the list it commits.
    function arrange(list, index, rect) {
        const out = list.slice();
        const it = out[index];
        if (!it) return out;

        const pinned = { key: it.key, x: rect.x, y: rect.y,
                         w: rect.w, h: rect.h, text: it.text };
        out[index] = pinned;

        // The home-screen case first: drop a card squarely onto one
        // the same shape and the two trade places, rather than one
        // shoving the other down a row and everything below it with
        // them. Only when the rectangles coincide exactly — a card
        // half over its neighbour is somebody aiming at a gap, and
        // that is a push.
        const landed = [];
        for (let i = 0; i < out.length; i++)
            if (i !== index && overlaps(out[i], pinned)) landed.push(i);

        if (landed.length === 1) {
            const o = out[landed[0]];
            if (o.x === pinned.x && o.y === pinned.y
                && o.w === pinned.w && o.h === pinned.h) {
                out[landed[0]] = { key: o.key, x: it.x, y: it.y,
                                   w: o.w, h: o.h, text: o.text };
                return out;
            }
        }

        // Reading order, so anything that has to move has already
        // moved by the time the card below it is considered — which
        // is what makes a push cascade instead of landing on top of
        // the next one down.
        const order = [];
        for (let i = 0; i < out.length; i++) if (i !== index) order.push(i);
        order.sort((a, b) => out[a].y !== out[b].y ? out[a].y - out[b].y
                                                  : out[a].x - out[b].x);

        const settled = [pinned];
        for (const i of order) {
            const o = out[i];
            const cand = { key: o.key, x: o.x, y: o.y, w: o.w, h: o.h,
                           text: o.text };

            // Down until it clears. The grid has no bottom, so this
            // always ends; the bound is there because a runaway loop
            // inside a drag handler is a settings window that has
            // stopped answering.
            for (let guard = 0; guard < 64; guard++) {
                let hit = false;
                for (const s of settled)
                    if (overlaps(s, cand)) { hit = true; break; }
                if (!hit) break;
                cand.y += 1;
            }

            settled.push(cand);
            out[i] = cand;
        }
        return out;
    }

    // Whether a cell has something in it. The editor draws its grid
    // guides through the gaps only: a card's surface is a translucent
    // wash, so a guide drawn under one is a guide you can see through
    // it, and the panel ends up looking like graph paper.
    function occupiedIn(list, x, y) {
        const cell = { x: x, y: y, w: 1, h: 1 };
        for (const it of list)
            if (overlaps(it, cell)) return true;
        return false;
    }

    // The committed layout's version. The editor asks the other one
    // against the layout it is previewing mid-drag.
    function occupied(x, y) { return occupiedIn(items, x, y) }

    function move(index, x, y) {
        const list = items;
        const it = list[index];
        if (!it) return false;

        const rect = { x: x, y: y, w: it.w, h: it.h };
        if (!inBounds(rect)) return false;

        commit(arrange(list, index, rect));
        return true;
    }

    function resize(index, w, h) {
        const list = items;
        const it = list[index];
        if (!it) return false;

        const spec = catalogue[it.key];
        const cw = Math.max(spec.minW, Math.min(columns - it.x, w));
        const ch = Math.max(spec.minH, Math.min(maxRows, h));

        const rect = { x: it.x, y: it.y, w: cw, h: ch };
        commit(arrange(list, index, rect));
        return true;
    }

    // Whether a control shows its words. A three-cell Wi-Fi card that
    // says "Wi-Fi / SIDDU2_4" is the right answer for most people and
    // the wrong one for anybody who knows their own panel by heart and
    // wants the glyphs back.
    function setText(index, on) {
        const next = items.slice();
        const it = next[index];
        if (!it) return;
        next[index] = { key: it.key, x: it.x, y: it.y, w: it.w, h: it.h,
                        text: on };
        commit(next);
    }

    function remove(index) {
        const next = items.slice();
        if (index < 0 || index >= next.length) return;
        next.splice(index, 1);
        commit(next);
    }

    readonly property var unplaced: {
        const placed = {};
        for (const i of items) placed[i.key] = true;
        return Object.keys(catalogue).filter(k => !placed[k]);
    }

    // Drops a control into the first gap it fits, scanning in reading
    // order and adding rows at the bottom rather than refusing.
    function add(key) {
        const spec = catalogue[key];
        if (!spec) return;

        const list = items.slice();
        const w = Math.min(columns, spec.defW);
        const h = spec.defH;

        for (let y = 0; y <= rows; y++) {
            for (let x = 0; x + w <= columns; x++) {
                const rect = { x: x, y: y, w: w, h: h };
                if (fits(list, -1, rect)) {
                    list.push({ key: key, x: x, y: y, w: w, h: h,
                                text: true });
                    commit(list);
                    return;
                }
            }
        }
    }

    // Repacks a layout upward and leftward, keeping reading order and
    // every span. Pure, because changing the column count needs the
    // same pass and one undo step rather than two.
    function pack(list) {
        const source = list.slice().sort((a, b) =>
            a.y !== b.y ? a.y - b.y : a.x - b.x);

        const out = [];
        for (const it of source) {
            let placed = false;
            for (let y = 0; y < 64 && !placed; y++) {
                for (let x = 0; x + it.w <= columns && !placed; x++) {
                    const rect = { x: x, y: y, w: it.w, h: it.h };
                    if (fits(out, -1, rect)) {
                        out.push({ key: it.key, x: x, y: y,
                                   w: it.w, h: it.h, text: it.text });
                        placed = true;
                    }
                }
            }
        }
        return out;
    }

    // This is the only operation that moves something the user did not
    // touch, which is why it is a button and not something that
    // happens on its own after a drag.
    function tidy() { commit(pack(items)) }

    // Changing the column count can strand anything that hung off the
    // new right-hand edge, so it is narrowed to fit and then the whole
    // layout is repacked. Doing this on write rather than on read
    // means the file always says what is on screen.
    function setColumns(n) {
        // Narrowed and repacked before the count changes, not after.
        // Writing the count first makes `items` re-parse against the
        // new width, and parse drops anything that no longer fits —
        // so the controls hanging off the right-hand edge would be
        // gone before there was a chance to bring them in.
        const clamped = items.map(i => ({
            key: i.key,
            x: Math.min(i.x, Math.max(0, n - 1)),
            y: i.y,
            w: Math.max(catalogue[i.key].minW, Math.min(n, i.w)),
            h: i.h,
            text: i.text
        }));

        // One history entry for one press, so Undo is one press back —
        // and it is taken before either half changes.
        remember();

        Config.island.controlColumns = n;
        Config.island.controlLayout = serialise(pack(clamped));
    }

    // ── Pixels ───────────────────────────────────────────────
    //
    // The one place cells become sizes. Both the panel and the editor
    // measure through these, so a layout is the same shape in the
    // preview as it is on screen.

    function cellWidth(panelWidth) {
        const inner = panelWidth - Config.island.controlPad * 2
                    - Config.island.controlGap * (columns - 1);
        return inner / columns;
    }

    function itemWidth(panelWidth, w) {
        return cellWidth(panelWidth) * w + Config.island.controlGap * (w - 1);
    }

    function itemHeight(h) {
        return Config.island.controlCell * h
             + Config.island.controlGap * (h - 1);
    }

    function itemX(panelWidth, x) {
        return Config.island.controlPad
             + (cellWidth(panelWidth) + Config.island.controlGap) * x;
    }

    function itemY(y) {
        return Config.island.controlPad
             + (Config.island.controlCell + Config.island.controlGap) * y;
    }

    // What the pill has to become to hold this layout.
    readonly property int panelHeight:
        Config.island.controlPad * 2 + itemHeight(rows)
}
