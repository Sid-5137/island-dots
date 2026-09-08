pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property var active: {
        const all = Mpris.players.values;
        if (!all || all.length === 0) return null;

        for (const p of all) {
            if (p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return all[0];
    }

    readonly property bool available: active !== null
    readonly property bool playing: active ? active.playbackState === MprisPlaybackState.Playing : false

    readonly property string title:  active && active.trackTitle  ? active.trackTitle  : ""
    readonly property string artist: active && active.trackArtist ? active.trackArtist : ""
    readonly property string album:  active && active.trackAlbum  ? active.trackAlbum  : ""
    readonly property string artUrl: active && active.trackArtUrl ? active.trackArtUrl : ""

    readonly property string identity: active && active.identity ? active.identity : ""

    readonly property real position: active ? active.position : 0
    readonly property real length:   active ? active.length : 0
    readonly property real progress: length > 0 ? position / length : 0

    readonly property bool canNext: active ? active.canGoNext : false
    readonly property bool canPrev: active ? active.canGoPrevious : false
    readonly property bool canToggle: active ? active.canTogglePlaying : false

    function toggle() { if (active && active.canTogglePlaying) active.togglePlaying() }
    function next()   { if (active && active.canGoNext)        active.next() }
    function prev()   { if (active && active.canGoPrevious)    active.previous() }

    signal trackChanged()

    property string _lastTitle: ""

    onTitleChanged: {
        if (title !== "" && title !== _lastTitle) {
            _lastTitle = title;
            root.trackChanged();
        }
    }

    // MPRIS position doesn't tick on its own — it has to be polled
    // while something is playing. 1s is enough for a progress bar.
    Timer {
        running: root.playing && root.active !== null
        interval: 1000
        repeat: true
        onTriggered: {
            // The player can vanish between ticks — poking a dead
            // D-Bus name throws ServiceUnknown into the log.
            if (root.active && root.playing)
                root.active.positionChanged();
        }
    }

    IpcHandler {
        target: "player"

        function toggle(): void { root.toggle() }
        function next(): void   { root.next() }
        function previous(): void { root.prev() }
        function status(): string {
            return root.available
                ? (root.playing ? "playing: " : "paused: ") + root.title
                : "no player";
        }
    }
}
