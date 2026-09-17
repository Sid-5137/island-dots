pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// What opens what.
//
// Almost all of this belongs to the desktop rather than to the shell.
// A browser choice lives in mimeapps.list, where a file manager, a
// chat client and a PDF viewer can all read it; storing it in
// settings.json would mean island knew a browser preference that
// nothing else on the machine could act on. So the page edits the
// association database, through bin/island-mime, and the only choice
// kept here is the terminal — which is the handler of no MIME type
// and so has nowhere else to go.
//
// The three that Super+X, Super+E and Super+B spawn are the same
// three. They were a hard-coded table in hypr/env.lua, which meant
// picking a browser in Settings and pressing Super+B could disagree
// with each other indefinitely. The table is still the shipped
// default; what is chosen here is written beside it as Lua and
// overlaid on top. See Paths.apps and hypr/env.lua.

Singleton {
    id: root

    // ── What can be chosen ───────────────────────────────────
    //
    // `spec` is the one type the candidate list is drawn from, and
    // `mimes` is everything the choice is then applied to — picking an
    // image viewer should not leave JPEGs behind with the old one.
    // They are deliberately not the same list: every app offered has
    // to claim the spec, but an app that claims image/png and not
    // image/bmp is still the right answer for both.
    //
    // `bind` names the key in hypr/env.lua's Apps table, for the three
    // that a keybind also spawns. Empty for the rest.
    readonly property var categories: [
        {
            key: "browser",
            group: "Programs",
            label: "Web browser",
            description: "Links from any application, and Super+B.",
            spec: "x-scheme-handler/http",
            mimes: ["x-scheme-handler/http", "x-scheme-handler/https",
                    "text/html", "application/xhtml+xml"],
            bind: "browser"
        },
        {
            key: "mail",
            group: "Programs",
            label: "Email",
            description: "Where a mailto: link goes.",
            spec: "x-scheme-handler/mailto",
            mimes: ["x-scheme-handler/mailto"],
            bind: ""
        },
        {
            key: "files",
            group: "Programs",
            label: "File manager",
            description: "Folders, and Super+E.",
            spec: "inode/directory",
            mimes: ["inode/directory"],
            bind: "fileManager"
        },
        {
            key: "terminal",
            group: "Programs",
            label: "Terminal",
            description: "Super+X. Unset runs the one hypr/env.lua names.",
            spec: "@TerminalEmulator",
            mimes: [],
            bind: "terminal"
        },
        {
            key: "text",
            group: "File types",
            label: "Text",
            description: "Plain text, and anything that reads as it.",
            spec: "text/plain",
            mimes: ["text/plain"],
            bind: ""
        },
        {
            key: "image",
            group: "File types",
            label: "Images",
            spec: "image/png",
            mimes: ["image/png", "image/jpeg", "image/gif", "image/webp",
                    "image/bmp", "image/tiff"],
            bind: ""
        },
        {
            key: "audio",
            group: "File types",
            label: "Audio",
            spec: "audio/mpeg",
            mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/opus",
                    "audio/x-wav", "audio/mp4", "audio/x-vorbis+ogg"],
            bind: ""
        },
        {
            key: "video",
            group: "File types",
            label: "Video",
            spec: "video/mp4",
            mimes: ["video/mp4", "video/x-matroska", "video/webm",
                    "video/quicktime", "video/x-msvideo", "video/mpeg"],
            bind: ""
        },
        {
            key: "pdf",
            group: "File types",
            label: "PDF",
            spec: "application/pdf",
            mimes: ["application/pdf"],
            bind: ""
        },
        {
            key: "archive",
            group: "File types",
            label: "Archives",
            spec: "application/zip",
            mimes: ["application/zip", "application/x-tar", "application/gzip",
                    "application/x-7z-compressed", "application/vnd.rar",
                    "application/x-xz", "application/x-bzip2"],
            bind: ""
        }
    ]

    readonly property var groups: ["Programs", "File types"]

    // ── State ────────────────────────────────────────────────
    //
    // Keyed by spec: { "default": id, "apps": [{id, name, exec}] }.
    // Empty until the page asks, which is the point — scanning every
    // .desktop file on the machine is work nobody has asked for until
    // the Apps page is open, and the answer is only wanted there.
    property var answers: ({})
    property bool loading: false
    property string problem: ""

    readonly property bool ready: Object.keys(answers).length > 0

    function categoryFor(key) {
        for (const cat of categories) if (cat.key === key) return cat;
        return null;
    }

    function optionsFor(cat) {
        const answer = cat ? answers[cat.spec] : null;
        return (answer && answer.apps) ? answer.apps : [];
    }

    // The id currently in force. The terminal is island's own setting;
    // everything else is whatever the association database says, which
    // is not necessarily what this page last wrote — another
    // application may have claimed a type since.
    function currentFor(cat) {
        if (!cat) return "";
        if (cat.bind === "terminal") return Config.apps.terminal;
        const answer = answers[cat.spec];
        // Bracketed because `default` is a keyword, and a dotted
        // access to one is the kind of thing a JS engine is entitled
        // to be fussy about.
        return (answer && answer["default"]) ? answer["default"] : "";
    }

    function appFor(cat, id) {
        if (id === "") return null;
        for (const app of optionsFor(cat)) if (app.id === id) return app;
        return null;
    }

    function nameFor(cat, id) {
        const app = appFor(cat, id);
        return app ? app.name : "";
    }

    // ── Reading ──────────────────────────────────────────────

    // island-mime is linked into ~/.local/bin by install.sh, and
    // Hyprland does not always start the shell with that on PATH —
    // the same reason Services/Theming.qml spells this out.
    function invoke(args) {
        return ["sh", "-c",
                'PATH="$HOME/.local/bin:$PATH"; exec island-mime "$@"',
                "sh"].concat(args);
    }

    function refresh() {
        if (query.running) return;
        problem = "";
        loading = true;
        query.command = invoke(["query"].concat(
            categories.map(cat => cat.spec)));
        query.running = true;
    }

    Process {
        id: query
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text === "") return;

                try {
                    root.answers = JSON.parse(text);
                } catch (e) {
                    root.problem = "island-mime returned something that is"
                        + " not JSON.";
                    return;
                }

                // Only once there is something to sync from. A failed
                // query leaves `answers` empty, and generating the
                // keybind table from nothing would write an empty one
                // over a perfectly good file.
                root.sync();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[DefaultApps]", this.text.trim());
            }
        }

        onExited: function(code) {
            root.loading = false;
            if (code === 127)
                root.problem = "island-mime is not on PATH — run install.sh"
                    + " to link it into ~/.local/bin.";
            else if (code !== 0 && root.problem === "")
                root.problem = "island-mime exited with " + code + ".";
        }
    }

    // ── Writing ──────────────────────────────────────────────

    function choose(key, appId) {
        const cat = categoryFor(key);
        if (!cat || appId === "" || appId === currentFor(cat)) return;

        if (cat.bind === "terminal") Config.apps.terminal = appId;

        if (cat.mimes.length === 0) {
            // Nothing for the desktop to be told: the choice was only
            // ever island's, so the keybind table is the whole of it.
            sync();
            return;
        }

        enqueue(["set", appId].concat(cat.mimes));
    }

    // A Process that is still running drops whatever is assigned to it
    // next, so two dropdowns changed in quick succession would lose
    // the first one silently. Queued rather than debounced: these are
    // separate choices, not repeats of one.
    property var queue: []

    function enqueue(args) {
        queue = queue.concat([args]);
        pump();
    }

    function pump() {
        if (setter.running) return;

        if (queue.length === 0) {
            // Everything applied, so re-read rather than assuming it
            // landed. The database has precedence rules of its own and
            // the honest answer is the one it gives back.
            refresh();
            return;
        }

        setter.command = invoke(queue[0]);
        queue = queue.slice(1);
        setter.running = true;
    }

    Process {
        id: setter
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("[DefaultApps]", this.text.trim());
            }
        }

        onExited: function(code) {
            if (code !== 0)
                root.problem = "Could not write mimeapps.list —"
                    + " island-mime exited with " + code + ".";
            root.pump();
        }
    }

    // ── The keybind table ────────────────────────────────────

    function quote(s) {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    }

    function table() {
        let body = "";

        for (const cat of categories) {
            if (cat.bind === "") continue;
            const app = appFor(cat, currentFor(cat));
            if (!app || app.exec === "") continue;
            body += "    " + cat.bind + " = " + quote(app.exec) + ",\n";
        }

        return "-- Generated by island's Settings -> Apps page.\n"
            + "--\n"
            + "-- hypr/env.lua declares the shipped defaults and then\n"
            + "-- overlays this file, so anything chosen in Settings wins\n"
            + "-- and anything left alone keeps the value in the repo.\n"
            + "-- Edit env.lua, not this: it is rewritten on every change.\n"
            + "\n"
            + "return {\n" + body + "}\n";
    }

    // What is on disk, so an open of the page that changes nothing
    // does not rewrite the file and reload the compositor.
    property string written: ""

    function sync() {
        if (!ready) return;

        const next = table();
        if (next === written) return;

        written = next;

        // The reload is fired from the FileView's `saved` signal
        // rather than from here. setText writes asynchronously, so a
        // reload on the next line re-reads the file as it was before
        // — which does not look like a race, it looks like the
        // setting quietly not working, because the keybind keeps the
        // value it already had until something else reloads.
        file.setText(next);
    }

    // The binds are built when Hyprland parses its config, so they
    // only pick up a new table on a reload. A reload also re-reads
    // look.lua, which would put the window appearance back to the
    // values in the repo and throw away everything the Appearance
    // settings had applied live — so Compositor.apply() sends the
    // stored ones again afterwards, which is what it is for.
    Process {
        id: reload
        running: false
        command: ["hyprctl", "reload"]
        onExited: Compositor.apply()
    }

    FileView {
        id: file
        path: Paths.apps
        printErrors: false

        // Creates the file, and its directory, on a first run.
        preload: true

        onLoaded: root.written = file.text()
        onSaved: reload.running = true
    }

    // The same reason Services/Audio.qml has one: working out whether
    // a dropdown showing the wrong application is the page's fault or
    // the database's should be one command, not a screenshot.
    IpcHandler {
        target: "apps"

        function status(): string {
            if (!root.ready) return "not read yet — call `apps refresh`";

            return root.categories.map(cat => {
                const id = root.currentFor(cat);
                const pad = "         ".slice(cat.key.length);
                return cat.key + pad
                    + (id === "" ? "—" : id)
                    + (cat.bind !== "" ? "  [" + cat.bind + "]" : "");
            }).join("\n");
        }

        function refresh(): void { root.refresh() }

        // The same two arguments the page passes, so a choice can be
        // scripted or checked without opening a settings window to
        // click a dropdown.
        function choose(category: string, app: string): string {
            if (!root.ready) return "not read yet — call `apps refresh`";
            const cat = root.categoryFor(category);
            if (!cat) return "no such category: " + category;
            if (!root.appFor(cat, app))
                return "nothing installed under " + cat.spec
                    + " is called " + app;
            root.choose(category, app);
            return "ok";
        }

        function binds(): string { return root.table() }
    }
}
