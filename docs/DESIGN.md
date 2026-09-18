# How the island is built

The shape, the pods, the panel behind them, and the motion that moves
between. Split out of the README, which is the front door rather than
the drawings.

---

## The island

| Mode | Trigger | Shows |
|:--|:--|:--|
| `idle` | — | time and date, or the track that is playing |
| `compact` | hover | lifts all three shapes; the pill gains transport |
| `expanded` | click | calendar, battery, toggles, sliders, media |
| `search` | `Super+R` | application launcher |
| `clipboard` | `Super+V` | clipboard history |
| `picker` | `Super+Shift+W/T/I` | wallpapers, palettes, icon themes |
| `session` | `Super+Shift+Q` | lock, log out, suspend, reboot, shut down |
| `centre` | `Super+N` | notification history |
| `notify` | on arrival | a notification, briefly |
| `osd` | media keys | volume, brightness, mic |
| `auth` | on request | polkit authorization |

The pill's collapsed width is derived from its content plus a padding
constant, so nothing ever runs into the edges regardless of what's in
it. It is also what morphs: a track starting grows an equaliser out of
nothing and the shape follows. The title is deliberately not there —
it is as long as whoever named the track decided and it changes while
you are not looking, so the shape at rest would be a different shape
every few minutes. `island.pillTitle` puts it back.

Scrolling the collapsed pill moves one workspace either way. It can be
set to volume, or to nothing, in Settings → Island.

### The pods

Two capsules flank the pill. They never move the island's centre —
they hang off its edges and grow outwards.

| Pod | At rest | Open |
|:--|:--|:--|
| workspaces | dashes: long for where you are, short for occupied, a stub for empty | numbered chips, clickable |
| tray | the first four icons, quiet | every icon, at full size |

The workspace pod has four ways of saying the same thing at rest, on
the Island page: **dashes**, **dots**, **numbers**, or **icons** — the
app you last used on each workspace, which is the only one that says
what is over there, and the widest. Open, every style becomes the same
numbered chips.

A pod opens while you point at it, for a moment after what it shows
changes, and until you click it again if you click it — clicking the
capsule itself pins it open, and the outline says so. Both collapse to
nothing when they have nothing to show: an empty tray leaves no
capsule behind, and either can be switched off entirely.

Every other mode undocks them. The control centre, the launcher and a
notification each own the whole shape, and satellites orbiting a
search field are debris.

### The control centre

The panel is a grid, and what is on it is configuration rather than
code. Each control holds a rectangle in cells:

```
calendar:0,0,3,5;wifi:3,0,3,1;bluetooth:3,1,3,1;media:3,2,3,2
         │ │ │ │
         x y w h
```

A fifth field turns a control's words off — `wifi:3,0,3,1,0` is the
badge and nothing else, at any size. It is optional, so a layout
written without it means what it always did.

Settings → Control draws that grid at full size with the real cards
in it — the Wi-Fi card says which network, the month says which month
— and you drag them around. Corner to resize, `Aa` for words, `×` to
remove, and a palette underneath for everything not currently placed.
The column count is 4 to 8; **Tidy** repacks; **Undo** goes back. The
panel's height is whatever the layout reaches, so there is no height
to set and none to disagree with what is in it.

Controls change shape rather than scaling. A Wi-Fi card three cells
wide carries the network name and a chevron into the list; squeezed to
one — or with its words turned off — it is the badge alone and keeps
only the power toggle. A slider
wide enough for a label has one, and taller than it is wide it stands
up and fills from the bottom.

Wi-Fi, Bluetooth and Sound have lists behind their chevrons, drawn
over the grid inside the same panel — the shape does not change, the
grid steps aside, the list slides in, and the chevron comes back.
Clicking Wi-Fi used to open the Settings window on the Network page,
which is a strange answer to "what networks are around".

Album art in a media card is washed with the accent colour, so a card
belongs to the theme whatever the record label chose. That detail, the
lists-in-the-panel and the layout editor are all taken from
[saneAspect's Dynamite V3](https://www.youtube.com/watch?v=Ob98KFByTec).

### Motion

The shape springs open and settles shut. Those are different curves,
because they are different events: a spring on arrival feels
responsive, and a spring on dismissal feels like the interface arguing
with you.

| | Curve | Time |
|:--|:--|:--|
| open | spring, damping 0.78 — about 1.5% overshoot | 240 ms |
| close | critically damped, no overshoot | 200 ms |
| hover | spring, damping 0.78 | 200 ms |
| pod peek | spring, damping 0.55 | 300 ms |
| content in | 40 ms lead, then 150 ms | 190 ms |
| content out | immediately, and quicker | 90 ms |

Those are the **fluid** tempo, and the numbers are measured rather
than invented. Sampling [saneAspect's Dynamite
V3](https://www.youtube.com/watch?v=Ob98KFByTec) at 60fps — the
panel's height in one column of pixels, frame by frame — its control
centre opens in about 180 ms and overshoots its final height by 1.4%,
which is a damping fraction of roughly 0.8. That was already this
spring. The only thing that differed was the clock: 460 ms against his
180. Two and a half times slower is the whole of the difference
between motion you feel and motion you wait for.

**calm** is the old tempo, kept for anyone who wants the extra beat on
a large screen. **springy** keeps the speed and spends the damping
instead: 0.62 is an overshoot you watch rather than feel.

The content is choreographed against the shape rather than gated on
it. It used to wait until the pill had reached 97% of its final width
and only then fade in, which is why opening the control centre read as
a resize followed by a screen. Now the shape moves alone for 80ms, the
content fades into it while it is still growing, and it is fully in
long before the shape settles. On the way out the content leaves
first: content still fading while the shape closes over it looks like
a mistake.

`Services/Motion.qml` holds the whole vocabulary — it samples a damped
second-order step response and hands Qt a bezier spline, since Qt has
no spring easing. Tempo is one control in Settings → Island; damping,
durations and the content lead are each their own slider a fold below
it, and **Reduce motion** drops the springs and the shape morphs while
keeping the cross-fades.

### Shape

One radius is set; everything else derives from it. `Theme.radiusSmall`,
`radiusNormal` and `radiusLarge` are 0.6x, 1x and 1.2x of the panel
radius, so the slider in Settings → Theme moves every corner in the
shell together rather than the two that happened to reference it.

Which of the three a shape gets is a question about what kind of thing
it is, not about how big it is — size is already in the answer, because
Qt clamps a radius to half the shorter side, so at a large setting a
28px button becomes a capsule while the panel behind it stays a rounded
rectangle:

| Token | What it is for |
|:--|:--|
| `radiusLarge` | a **card** — something that holds other things and sits on a surface: control-centre cards, a selected row in a list, overview and picker cards, an icon tile, a popup |
| `radiusNormal` | a **panel**, or a field you type into: the settings window and its sidebar, a segmented control, a password box |
| `radiusSmall` | a **chip** — a small control holding one word or one glyph: buttons, tabs, a thumbnail inside a card |

There is a fourth case and it is deliberately not a token: a shape whose
roundness is a fact about the shape rather than a preference. A toggle
knob, a slider handle, a workspace dash, the cap on a 3px tick — those
are `height / 2`, written where they are drawn. `radius: 1.5` beside
`width: 3` is the same number with the reason taken out of it, and it
stops being a capsule the moment somebody changes the 3.

The island's own corner is a function of its height, not a constant:

```
Theme.corner(h) = min(h / 2, island.radius + h * 0.06)
```

A single number cannot serve both ends of a shape that morphs from a
34px pill to a 374px panel — at 14 the pill is three pixels short of a
capsule, and the panel gets that same 14 on something ten times taller.
The height is already spring-animated, so **the corner opens up as the
shape does**, for free.

---
