# Recording the demo

The README's hero video does more than any screenshot: the whole point
of this shell is that one shape becomes several things, and a still
frame cannot show a morph.

## Capture

    sudo dnf install wf-recorder

    wf-recorder -f ~/island-dots/docs/demo.mp4 \
        -c libx264 -p crf=23 -p preset=slow -r 60

`Ctrl+C` to stop. 60fps matters here — the morph is the subject, and
30fps makes an easing curve look like a step.

For a region rather than the whole screen:

    wf-recorder -g "$(slurp)" -f ~/island-dots/docs/demo.mp4 -r 60

## What to show, in order

Twenty seconds is plenty. Longer and nobody watches to the end.

1. Idle pill, cursor away from it. Let it sit for a second.
2. Hover — workspaces and the playing indicator arrive.
3. Click — the control centre grows.
4. Toggle Wi-Fi, drag a slider.
5. Click away, then `Super+R` — the pill stretches into the launcher.
6. Type three letters, watch the list narrow, press Escape.
7. `notify-send "island" "a notification arrives"` — it becomes the
   notification and hands the shape back.
8. Change the wallpaper from the picker and let the palette follow.

That last one is the moment people remember. Save it for the end.

## Before recording

    qs -c island ipc call island setVisibility always

so the pill does not hide mid-take, and pick a wallpaper with some
contrast — the blur is invisible against a flat background.

## Compress before committing

Git keeps every version of a binary forever.

    ffmpeg -i demo.mp4 -vf scale=1280:-2 -c:v libx264 -crf 28 \
        -preset veryslow -an demo-small.mp4

Aim for under 5 MB. Above about 10 MB, upload it to the release page
or drag it into a GitHub issue and link the URL instead of committing
it.

## Putting it in the README

Dragging a video into any GitHub comment box uploads it and gives back
a URL like:

    https://github.com/user/repo/assets/12345/abcdef.mp4

Paste that URL on its own line in the README and GitHub renders a
player. That is what the placeholder near the top is for. A committed
`docs/demo.mp4` will *not* play inline — it renders as a download
link — so the upload URL is the one to use.

## Stills

Screenshots still earn their place for the things a video rushes past:

    hyprshot -z -m region -o ~/island-dots/docs

Worth having: the control centre, the launcher mid-search, the
notification popup, the settings window, and the lock screen.
