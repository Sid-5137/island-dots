# Recording the demo

The README's hero clip does more than any screenshot: the whole point
of this shell is that one shape becomes several things, and a still
frame cannot show a morph. The clip is `docs/demo.webp`, and it was
made without installing a recorder.

## Why not wf-recorder

Nothing is wrong with it — it just is not here, and it needs root to
install. `grim` already is, and the reason it looks too slow is not
the capture:

    grim -g "$REGION" /dev/null          # ~17 fps
    grim -t ppm -g "$REGION" /dev/null   # ~89 fps, with a panel open

The cost is PNG compression, not the screencopy round-trip. Ask for
raw PPM and one `grim` per frame is fast enough to catch a 240ms
spring — the shell's own tempo — with about twenty frames in it.

## The frame rate is not one number

It depends on what is on screen, and not the way you would guess:

    idle pill only          ~60 fps
    control centre open     ~90 fps

Backwards, and it is the 60 that is the anomaly. Screencopy hands over
the next composited frame, so when nothing is animating the rate is
whatever the compositor is producing — the display's 60Hz. Open a panel
and the blur is being recomposited continuously, so grim never waits.

This matters because a take passes through both. Encoding at a single
`-framerate` makes one half of the clip play at the wrong speed, and
the halves are exactly the morphs you are recording and the pauses
between them.

## Capture

Drive the shell over its IPC rather than by hand: the timings come out
the same on every take, and there is no cursor wandering through the
shot.

    G="618,0 684x440"          # a region that fits the widest mode
    Q="qs -c island ipc call"

    (
      sleep 1.2
      $Q control open            ; sleep 2.2
      $Q control page bluetooth  ; sleep 1.5
      $Q control hide            ; sleep 1.2
      $Q launcher open           ; sleep 1.2
      $Q launcher query "fi"     ; sleep 2.0
      $Q launcher hide           ; sleep 1.5
    ) &

    DEADLINE=$(( $(date +%s%N) + 12200000000 ))
    ( while [ $(date +%s%N) -lt $DEADLINE ]; do grim -t ppm -g "$G" -; done ) \
      | ffmpeg -y -f image2pipe -vcodec ppm -use_wallclock_as_timestamps 1 -i - \
          -vsync cfr -r 60 \
          -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p demo_raw.mp4

Frames go straight down the pipe, so nothing touches the disk — at
900KB a frame, ten seconds would otherwise be 800MB.

`-use_wallclock_as_timestamps 1` is what makes the rate not mattering
true: ffmpeg stamps each frame with the time it arrived rather than
assuming they are evenly spaced, and `-r 60` resamples that to a
constant rate. Checked against a driver of known length, the encoded
duration comes out within about 1% of real time, through both the 60fps
and the 90fps stretches.

Bound the capture by a **deadline rather than a frame count**. A count
is a bet on the rate, and it is the bet that loses the end of the take:
at 90fps a 700-frame loop stops after 7.8 seconds of an 11-second
sequence, and the tail you trimmed for is simply not there.

`launcher query` rather than `open` is how the launcher gets into the
only state worth filming. `open` gives an empty field, and since the
launcher stopped listing every application at rest, an empty field is
all an empty field shows.

## Before recording

Move to an empty workspace — `qs -c island ipc call wm go 9` — so the
background is wallpaper rather than whatever you had open. It looks
better, it keeps your windows out of a public README, and on `smart`
visibility it is also what stops the island hiding mid-take.

Pick a wallpaper with some contrast. The blur is invisible against a
flat background, and the blur is half of what there is to look at.

## Editing

Trim the dead air at each end, then encode for the README:

    ffmpeg -y -ss 0.40 -to 10.70 -i demo_raw.mp4 \
        -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p -an demo.mp4

    ffmpeg -y -i demo.mp4 -vf "fps=24,scale=620:-2:flags=lanczos" \
        -c:v libwebp -q:v 40 -loop 0 -preset picture -an demo.webp

Trim so the clip **ends where it began**, on the pill at rest. The WebP
loops, and a loop that cuts from a full-width launcher back to a 152px
pill reads as a dropped frame rather than as a repeat.

`-q:v 40` rather than 60. Compared frame by frame at 3x on the small
text in the launcher and on the blurred calendar, 40 and 60 are not
distinguishable here, and 40 is what keeps a longer clip at the same
2.3MB the shorter one cost. `-compression_level 6` does nothing for
animated WebP — it was measured, not assumed.

Animated WebP rather than GIF: 256 colours turn a blurred panel into
bands, and the GIF of this clip is several times the size. GitHub
renders it inline from `![](docs/demo.webp)`; a committed `.mp4` does
not play inline, which is what the old README placeholder was working
around.

Around 2MB is the target, and this wallpaper is close to the worst case
for it — an illustration with fine detail behind a blur, which is
exactly what WebP spends bits on. Git keeps every version of a binary
forever, so re-record rather than committing takes you are not going to
use.

Note that ffmpeg cannot *decode* animated WebP even though it encodes
it. To check the result:

    python3 -c "from PIL import Image; i=Image.open('demo.webp'); \
        print(i.size, i.is_animated, i.n_frames)"

## Stills

Same idea, one frame, and PNG is fine when there is no frame rate to
keep up with:

    qs -c island ipc call control open
    grim -g "618,0 684x440" docs/control-centre.png

The ones in the README: the pill at rest, the control centre, a
sub-page, the launcher, and the Control settings page with the layout
editor. Crop to the island with a margin of wallpaper around it —
a full-screen shot at 1920 wide is mostly desktop, and it was 2MB a
piece before these were cropped.
