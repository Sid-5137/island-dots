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
| `picker` | `Super+Shift+W/T` | wallpapers and palettes, as a grid. `Super+Shift+I` opens Settings instead: an icon theme is picked once and then left, and twenty near-identical folder icons is a list, not a grid |
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

Every shape in the shell is on a spring, and a spring is described the
way Apple describes one: a **response**, which is its natural period
and reads as the speed of the thing, and a **bounce**, which is one
minus the damping fraction. That is the pair SwiftUI's
`Spring(duration:bounce:)` takes, so a figure read off Apple's
documentation means here what it means there.

| | Response | Bounce |
|:--|:--|:--|
| open | 240 ms | 0.15 — `.snappy`, about 0.6% overshoot |
| close | 190 ms | 0.05 |
| hover | 180 ms | 0.15 |
| pod peek | 280 ms | 0.40 |
| content in | 40 ms lead, then 150 ms | — an easing, not a spring |
| content out | 90 ms, immediately | — |

Those are the **snappy** tempo. The bounces are Apple's three exactly:
**smooth** is 0, **snappy** 0.15, **bouncy** 0.30. The responses are
not — SwiftUI's named springs all run at half a second, which is a
phone animation and reads as slow on a shell you drive with a pointer.
macOS's own chrome runs nearer a quarter second, and that is also
where the island already was: sampling [saneAspect's Dynamite
V3](https://www.youtube.com/watch?v=Ob98KFByTec) at 60fps — the
panel's height in one column of pixels, frame by frame — its control
centre opens in about 180 ms and overshoots by 1.4%. The two
references agree about the speed and differ only about how much
overshoot to spend on it, and Apple's answer is the smaller one.

**A spring, not a curve, because a curve cannot be interrupted.** An
easing is a function of one variable — how far through it is — so it
cannot know that the property was already moving when it started, or
how fast. Reverse a Qt `Behavior` mid-flight and it restarts from a
standstill at whatever value it had reached: brush the pill and leave
again, or open the control centre and shut it before it has arrived,
and there is a visible hitch at the turn. `Widgets/Spring.qml` carries
its velocity through the reversal instead. That continuity is most of
what makes motion feel attached to the pointer rather than played at
it, and it is why the springs are not Behaviors at all — a Behavior
owns a start and an end, and a spring has neither.

It is solved rather than stepped: the closed-form solution of the
damped oscillator, evaluated at each frame's own dt. So the motion is
identical at 60Hz and at 240Hz and a dropped frame costs a frame
rather than changing the curve. Qt ships a `SpringAnimation` and it is
not this one — it steps a fixed 16 ms Euler, which would run every
morph on a 120Hz panel at 62.5.

**Departures spring too, barely.** They used to be critically damped
on the argument that a spring on dismissal reads as the interface
arguing with you. macOS does not agree, and neither does this any
more; what it keeps from that argument is the size of the number.
Bounce on the way out is 0.05, because half of what the island
dismisses is collapsing to nothing and an overshoot past nothing is a
negative width. Every spring that can reach zero also carries a floor,
and clamps only what is read out — the oscillator keeps its true state
so it still settles from where it really is.

**Arriving is not only a fade.** A surface grows the last four percent
into place as it fades in, anchored at the top edge, which is the
edge it came out of. That is the macOS presentation everywhere from a
popover to Notification Centre, and it is the difference between
content appearing *over* the shape and content coming *out* of it. It
is applied to the panel modes as a group rather than to each of them,
which is also what makes it mean the right thing: going from the
launcher to the control centre is not an arrival, it is the same panel
showing something else, and it stays a plain cross-fade.

The content is choreographed against the shape rather than gated on
it. It used to wait until the pill had reached 97% of its final width
and only then fade in, which is why opening the control centre read as
a resize followed by a screen. Now the shape moves alone for 40 ms,
the content fades into it while it is still growing, and it is fully
in long before the shape settles. On the way out the content leaves
first: content still fading while the shape closes over it looks like
a mistake.

Fades stay easings, in both directions and everywhere. A cross-fade
has no velocity to carry and no overshoot to spend, and Apple eases
those too.

`Services/Motion.qml` holds the whole vocabulary and runs two engines
on purpose. The shapes get `Widgets/Spring.qml`. Everything small
enough that interrupting it is not a thing you can see — a toggle
knob, a row highlight, a button's press — gets a bezier spline sampled
from the same spring, which costs one curve rather than a physics step
per frame per control. Tempo is one control in Settings → Island;
response, bounce and the emerge scale are each their own slider a fold
below it, and **Reduce motion** drops the springs and the emerge while
keeping the cross-fades.

### Palette

The shell's colours are twenty-six Material role names —
`surface_container_high`, `on_surface_variant`, and so on — and
`Services/Theme.qml` is the only thing that reads them. Everything
else asks Theme. That indirection is what lets the roles be filled
from two completely different places without anything downstream
knowing which:

- **from the wallpaper**, by matugen, which derives a Material palette
  from the image;
- **from a preset**, by `bin/island-palette`, which fills the same
  templates from a table of twelve colours per theme.

Twelve, not twenty-six, because the rest is one shared mapping. A
preset says what its crust, base, three surfaces, overlay, text,
subtext, three accents and red are — under the names its own authors
use, so a gruvbox value looked up in gruvbox's documentation is
findable by the name it has there — and the mapping onto Material
happens once for all of them. Adding a theme is twelve hex values.

The ramp has to ascend, and the one step no theme names is
interpolated rather than invented: Material reads
`surface_container_*` as elevation, so a surface darker than the one
below it puts a card behind the thing it is sitting on.

**The accents are the quiet variants.** Every one of these palettes
has a loud set and a muted set, and `primary` here is not a swatch on
a page — it is the fill behind a selected row, the edge of whatever
the pointer is on, the active segment of a control. A colour chosen to
be noticed is the wrong one for something on screen all day. So
gruvbox is Gruvbox Material rather than the original's `#fb4934` and
`#b8bb26`, and Nord's accent is nord9 rather than the Frost cyan every
Nord preview leads with. Catppuccin is left as published: it is
high-value by design, and its accents are meant to carry dark text,
which is exactly how the shell uses them.

Under a preset the wallpaper had no say in the palette, so the two can
disagree. **Tint the wallpaper** washes the image toward the accent —
most of the way to grey, then back out in one hue, which leaves the
shapes and takes the argument away. A hue rotation would leave a blue
sky blue-ish and still wrong. It is a `MultiEffect` on the layer that
is already being drawn, enabled only while it is wanted, so the
ordinary case pays for no render target at all.

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
