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
    grim -t ppm -g "$REGION" /dev/null   # ~89 fps

The cost is PNG compression, not the screencopy round-trip. Ask for
raw PPM and one `grim` per frame is fast enough to catch a 240ms
spring — the shell's own tempo — with about twenty frames in it.

## Capture

Drive the shell over its IPC rather than by hand: the timings come out
the same on every take, and there is no cursor wandering through the
shot.

    G="618,0 684x440"          # a region that fits the widest mode
    Q="qs -c island ipc call"

    (
      sleep 1.3
      $Q control open            ; sleep 2.2
      $Q control page bluetooth  ; sleep 1.9
      $Q control hide            ; sleep 1.3
      $Q launcher open           ; sleep 1.9
      $Q launcher hide
    ) &

    for i in $(seq 1 880); do grim -t ppm -g "$G" -; done \
      | ffmpeg -y -f image2pipe -vcodec ppm -framerate 88 -i - \
          -c:v libx264 -crf 20 -preset medium -pix_fmt yuv420p \
          -r 60 demo_raw.mp4

Frames go straight down the pipe, so nothing touches the disk — at
900KB a frame, ten seconds would otherwise be 800MB.

**Measure the frame rate first** and pass the real number to
`-framerate`, or the clip plays at the wrong speed:

    time (for i in $(seq 1 120); do grim -t ppm -g "$G" /dev/null; done)

It depends on the region: 684x440 gives about 89fps here, and a
full-screen region will be a good deal slower.

## Before recording

Move to an empty workspace — `qs -c island ipc call wm go 9` — so the
background is wallpaper rather than whatever you had open. It looks
better, it keeps your windows out of a public README, and on `smart`
visibility it is also what stops the island hiding mid-take.

Pick a wallpaper with some contrast. The blur is invisible against a
flat background, and the blur is half of what there is to look at.

## Editing

Trim the dead air at each end, then encode for the README:

    ffmpeg -y -ss 0.35 -to 8.85 -i demo_raw.mp4 \
        -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p -an demo.mp4

    ffmpeg -y -i demo.mp4 -vf "fps=24,scale=620:-2:flags=lanczos" \
        -c:v libwebp -q:v 60 -loop 0 -preset picture -an demo.webp

Animated WebP rather than GIF: 256 colours turn a blurred panel into
bands, and the GIF of this clip is several times the size. GitHub
renders it inline from `![](docs/demo.webp)`; a committed `.mp4` does
not play inline, which is what the old README placeholder was working
around.

Around 2MB is the target. Git keeps every version of a binary forever,
so re-record rather than committing takes you are not going to use.

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
