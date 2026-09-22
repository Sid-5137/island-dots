# Notes for anyone reading the source

Things that cost real time to work out, and the reason a few lines in
the source look the way they do. The code carries the terse warning;
this is the long version behind it.

---

- **A bezier spline easing can take the whole process down.** Qt does
  not validate `easing.bezierCurve`, and it does not warn: a malformed
  spline segfaults the shell the first time something animates, with a
  stack trace pointing at whatever socket happened to be dispatching.
  Two separate shapes do it, and a sampled spring curve hits both by
  accident:
  - segments of different widths in x — twelve narrow ones and one
    wide one is enough;
  - segment endpoints that step back down in y, which is exactly what
    an overshoot looks like if you sample it naively.

  Control points are unconstrained, so the fix is to keep the segments
  uniform, clamp the endpoints to a non-decreasing sequence, and let
  the control points carry the overshoot. `Services/Motion.qml` does
  that, and the comment there says so.

  That clamp is also why the sampled curves cannot be the whole story.
  A spline whose y steps back down crashes Qt, and stepping back down
  is exactly what an interrupted spring has to do: reverse a shape
  halfway open and the progress toward the *new* target starts
  negative, because the thing is still travelling the other way. So
  velocity cannot be carried through a bezier at all, at any price.
  The shapes are solved analytically instead — `Widgets/Spring.qml` —
  and the sampled curves are kept for the controls small enough that
  nobody can interrupt them visibly.

- **Qt's `SpringAnimation` runs at 62.5fps, whatever your monitor
  does.** It is a fixed 16 ms Euler step: `velocity += spring * (to -
  value) - damping * velocity`, then `value += velocity * 0.016`, and
  it refuses to update at all when less than 16 ms has elapsed. On a
  120Hz panel that is every other frame, and the staircase is visible
  on anything that travels far. Simulating that loop in Python
  reproduces Qt's output to five decimal places, which is how the step
  was identified — it is not documented.

  It also means its two numbers are not a frequency and a damping
  ratio but artefacts of that discretisation. `spring: 2, damping:
  0.2` from Qt's own example measures as a 0.50 s response at a
  damping fraction of 0.59, and the continuous-limit conversion that
  ought to give those numbers is off by enough to see. Solving the
  oscillator in closed form at each frame's real dt costs a handful of
  lines, is frame-rate independent, and takes Apple's response and
  bounce directly.

- **Hyprland's Lua migration breaks things silently.** Three separate
  APIs stopped working with no error and no log line:
  - `hyprctl keyword` — rejected outright with "keyword can't work
    with non-legacy parsers". Use `hyprctl eval` with an
    `hl.config({...})` block.
  - `hyprctl dispatch workspace 2` — wrapped as
    `hl.dispatch(workspace 2)`, which is not valid Lua. Dispatchers
    take Lua now: `hl.dsp.focus({ workspace = 2 })`.
  - Argument names changed with it. Focusing a window is
    `hl.dsp.focus({ window = "address:0x..." })`. A top-level
    `address =` used to be accepted and silently ignored; as of 0.56.2
    it names the fields it will take instead, and unknown fields on
    `hl.layer_rule` are rejected the same way. Check the version
    before assuming a key is being read.

  After a Hyprland update, test each of these by hand before assuming
  the shell is at fault:

  ```bash
  hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'
  hyprctl eval 'hl.config({ decoration = { rounding = 12 } })'
  qs -c island ipc call wm windows      # then focus one by address
  ```

- Do not make the pill's own properties conditional per mode. Colour,
  border width and `clip` switching mid-morph were the cause of every
  flicker in the control centre. Content inside a mode can vary
  freely; the surface it sits on should not.
- A `PropertyChanges` that overrides a *bound* property replaces the
  binding rather than animating through it. The island uses plain
  bindings and no QML `States` for that reason.
- A `readonly` property nothing reads is evaluated lazily, so its
  change signal never fires.
- `clip: true` clips to the bounding rectangle, not the rounded shape.
  Anything opaque touching a rounded corner must round it itself.
- `anchors.centerIn` centres a text's line box, not its glyph. Icon
  fonts reserve descent space they never use.
- A `Grid` takes its width from its children — deriving a child size
  from the Grid's width is circular and collapses silently.
- **Notifications are destroyed the moment the handler returns**
  unless you set `tracked = true` on them. Nothing did, so
  `trackedNotifications` was always empty and the object each history
  entry held was already dead. The JavaScript wrapper stays *truthy*
  after that and every property read comes back `undefined`, so it
  fails as a `TypeError` at the call site rather than anywhere near
  the cause — which is why action buttons silently did nothing for
  the entire life of the project. History stores copies and looks the
  live object up by id.

- **`Qt.callLater` is not "after the surface is down".** It runs
  before the event loop returns to Wayland. Dispatching a focus change
  from it while a layer still holds `WlrKeyboardFocus.Exclusive` means
  the compositor restores focus over the top of you a moment later.
  This is the whole of the Alt+Tab bug. Use a short timer.

  It hid behind a coincidence: focusing a window on *another*
  workspace also switches workspace, which leaves the restore nothing
  on screen to put focus back onto. So it worked across workspaces
  and failed within one, which reads like anything except a focus
  race.

- **One shape is not always one shape.** The launcher and the
  clipboard were a field and a list inside a single pill, and the pill
  took its height from how many rows there were. That makes the field
  stop reading as a field the moment it has results — it becomes the
  top edge of a box — and it moves the shape under the cursor on every
  keystroke.

  They are two surfaces now: the pill holds the field and keeps one
  height, and a shelf below it holds the rows, at `island.podGap` —
  the number that already governs the space between the pill and the
  pods, rather than a second one invented for this. `Island.qml` owns
  the shelf; `SearchList.qml` and `ClipList.qml` are what sit on it.

  The empty launcher is now literally empty: no rows, no shelf, just
  the bar. The clipboard keeps its shelf either way, because it was
  opened deliberately and "No matches" is an answer to that.

- **A `Shape` makes its window opaque under a blur rule.** Qt's
  `Rectangle` draws circular corners and has no corner smoothing, so a
  macOS-style superellipse corner has to come from somewhere else. The
  obvious somewhere is `QtQuick.Shapes`, and it cannot be used here: a
  `Shape` anywhere in the island's window turns that window's whole
  bounding rectangle opaque in the Wayland buffer, and `hypr/rules.lua`
  blurs that layer — so Hyprland dimmed a dark square behind every
  rounded surface in the shell, hiding the corner the `Shape` was drawn
  to improve.

  Four fixes do not work, and each was measured rather than assumed:
  `Shape.GeometryRenderer` instead of `CurveRenderer`; `layer.enabled`
  on the Shape; raising the layer's `ignore_alpha` from 0.03 to 0.5;
  and keeping the Shape offscreen as a `visible: false` layer source
  composited by a `MultiEffect`. Swapping the same geometry back to a
  plain `Rectangle` clears it every time, which is what makes it the
  Shape rather than the path. That it survives an `ignore_alpha` of 0.5
  is the useful half: the alpha being written is not faint, so no
  threshold saves you.

  A `ShaderEffect` does work — one quad, an SDF with the `L^n` norm in
  place of `length()`, and the alpha it writes is the alpha you get —
  and so does `Canvas`, which rasterises with `QPainter` into its own
  texture. Neither adds a `Shape` node. That is `packages/qml-squircle`:
  the shader as `Squircle.qml` with its baked `.qsb` committed, and
  the Canvas as a no-binary fallback. The shell uses it for the pill,
  the shelf, the pods and both windows, and Hyprland draws the
  matching curve for windows from the same `appearance.cornerSmoothing`
  via `decoration:rounding_power`.

- **A file watcher can eat the setting you just made.** `Config.qml`
  wrote `settings.json` on every property change and reloaded it on
  every file change. For a slider — one key, one write — that is fine.
  For anything setting several keys in one call it is lossy: each
  write queues a file change, each file change triggers a reload, and
  a reload landing between two writes puts the adapter back to what
  was on disk before the second one.

  Picking a Tempo writes twelve motion keys. Five of them did not
  survive, the file was left holding a mixture of two tempos, and the
  row read back as **Custom** — so the symptom was the settings app
  disagreeing with the setting you had just made, with nothing
  anywhere reporting an error. Reproducible in about fifteen lines:

  ```qml
  Motion.setTempo("smooth");
  // then, a tick later, compare Config.motion against Motion.tempos.smooth
  ```

  The fix is a zero-interval timer, which is not a delay — it fires on
  the next turn of the event loop, after the whole burst has landed on
  the adapter and before anything can observe the file. Plus a flag so
  the watcher ignores the shell's own writes coming back around.

- **PipeWire's volume is not the volume anyone shows you.** The number
  in `channelVolumes` is a linear gain — what the samples get
  multiplied by — and what `wpctl`, `pactl` and `pavucontrol` all
  print is its cube root. Setting 0.5 with `wpctl` writes 0.125.
  Quickshell's `sink.audio.volume` is on the *displayed* scale, so the
  percentage the shell shows agrees with every other tool exactly, in
  both directions.

  That agreement is also why half way along the slider does not sound
  half as loud, and it is not a bug in anything: a displayed `p` means
  `p³` of gain, loudness goes roughly as `gain^0.6`, so loudness goes
  as `p^1.8`. 50% is −18 dB, which the ear reads as under a third.
  `Settings → System → Sound` can swap the scale for one where the
  number tracks loudness instead — `gain = p^(5/3)`, so island's 50%
  is `wpctl 0.68` and −10 dB. It is off by default, because a shell
  whose numbers disagree with `wpctl` is worth choosing on purpose.

  Check both scales at once with:

  ```bash
  qs -c island ipc call audio status
  ```

- **A `Repeater` needs a visual parent.** In a singleton it has none,
  so its delegates are never created and whatever they were supposed
  to do silently does not happen. `Instantiator` is the non-visual
  one.

- **Everything inside `Variants` exists once per screen**, including
  `IpcHandler`. Two handlers claiming one target collide and the loser
  is not registered, so on a second monitor it is load order that
  decides which of your keybinds work. `Services/Screens.qml` names
  one island the owner.

- **`qs ipc call <target> show` cannot work.** `show` is eaten by
  `qs ipc show` before it reaches the function name, and `--` does not
  help. Every `show()` here also answers to `open()`.

- **A declared property is not a drawn one.** `SliderRow` had a
  `description` for years and never rendered it, so every explanation
  written for a slider was invisible and nobody could tell from the
  source that it should not have been.

---
