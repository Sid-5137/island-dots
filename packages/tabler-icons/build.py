#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["fonttools", "skia-pathops"]
# ///
"""Build the shell's icon fonts from Tabler's SVG sources.

The .ttf files are committed, so nobody running the shell needs this —
only somebody adding or changing an icon. Run it with uv, which
fetches the two dependencies above by itself:

    packages/tabler-icons/build.py           # check, then rebuild
    packages/tabler-icons/build.py --check   # check only; exit 1 on a problem

or with plain python3 if fonttools and skia-pathops are installed.

Why from the SVGs rather than Tabler's webfont: the webfont stops at a
2-unit stroke, and at the 11-15px the shell draws most icons that
reads as hairline. Here each path is stroked at whatever width
STROKES asks for, with the round caps and joins Tabler draws with, so
the bold cut is Tabler's own drawing with a heavier pen rather than an
emboldened outline.

In order:

1. Fetch @tabler/icons at the pinned version, cached under
   $XDG_CACHE_HOME/island, and check it against the published sha512
   so the same input always makes the same font.
2. Read every `glyph(0x....)  // ti-name` line in Icons.qml and stop
   if a codepoint is not the one Tabler gives that name. Tabler
   assigns a codepoint once and never moves it, so a mismatch is
   always a typo on our side.
3. Stop if any other QML file spells an icon as a raw character.
   Those are invisible in a diff and step 2 never sees them, which is
   how several icons had drifted onto the wrong glyph before.
4. For each width in STROKES, draw every named icon into one font
   with its own family name.

Restart the shell afterwards: Qt keeps a loaded font for the life of
the process, so a reload draws with the old one.
"""

import argparse
import base64
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SHELL = REPO / "quickshell/island"
ICONS = SHELL / "Services/Icons.qml"

VERSION = "3.48.0"
TARBALL = ("https://registry.npmjs.org/@tabler/icons/-/"
           f"icons-{VERSION}.tgz")
SHA512 = ("lQk06gVHNVBnJp0UOgtth54mcZBJM7rdYKsAxKOProj1bbSAx+/xiuOWfHlyvgdL"
          "3M+Y+I0HINrjHa3ygp8eXQ==")

# Stroke widths on Tabler's 24-unit grid, as Config.appearance.iconStroke
# spells them. 2 is Tabler's own default. 2.5 is the bold cut the shell
# ships with: the heaviest that still keeps a battery's bars and a
# calendar's date apart at 13px — 2.75 starts filling them in.
STROKES = ["2", "2.5"]

# Font units per SVG unit. Tabler keeps two units clear on every side
# of its 24-unit grid, so its ink fills a 20-unit live area; at 50 a
# unit, that live area is the 1000-unit em. Every pixelSize in the
# shell was set against glyphs that fill the em, so this is what makes
# a pixelSize mean what it meant.
UNIT = 50

# The line box is the frame: ascent 1000, descent 0, so the frame's
# centre, (12, 12) on the grid, lands at (500, 500). That is what lets
# anchors.centerIn centre an icon with no correction — the box Qt
# centres is the frame the icon was drawn in.
#
# The baseline at the bottom of the frame rather than Tabler's 900/100
# split is for the rasteriser. Qt lays text out with unrounded metrics
# and then snaps the baseline to a whole pixel, and at 0.9em the
# baseline lands on a fraction at almost every size — 13.5px down a
# 15px box — which rounds down, every time. Measured on screen, that
# put every icon in the shell half a pixel low and the slider icons a
# whole one. At 1em the baseline offset is the pixelSize itself, which
# is always whole.
ASCENT, DESCENT = 1000, 0

# Optical corrections, in grid units, (right, up). Tabler places every
# icon on the grid, and for a symmetric shape that already is the
# centre. These are the shapes where the centre of the box and the
# centre the eye finds disagree — each one judged on screen at the size
# the shell draws it, not worked out.
OPTICAL = {}

ENTRY = re.compile(r"glyph\(0x([0-9A-Fa-f]+)\)\s*//\s*ti-([a-z0-9-]+)")


def fail(problems):
    for p in problems:
        print(f"  {p}", file=sys.stderr)
    sys.exit(1)


def fetch():
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    path = cache / "island" / f"tabler-icons-{VERSION}.tgz"
    if not path.exists():
        print(f"Fetching Tabler Icons {VERSION}")
        path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(TARBALL) as r:
            data = r.read()
        tmp = path.with_suffix(".part")
        tmp.write_bytes(data)
        tmp.rename(path)

    data = path.read_bytes()
    digest = base64.b64encode(hashlib.sha512(data).digest()).decode()
    if digest != SHA512:
        path.unlink()
        fail([f"{path.name} does not match its published sha512;"
              " removed it, run again to re-fetch"])

    tar = tarfile.open(fileobj=io.BytesIO(data))
    read = lambda name: json.loads(tar.extractfile(f"package/{name}").read())
    return (read("icons.json"),
            {"outline": read("tabler-nodes-outline.json"),
             "filled": read("tabler-nodes-filled.json")})


def check(meta):
    """Icons.qml's entries as [(codepoint, name, style)], or stop."""
    problems, entries = [], []
    for n, line in enumerate(ICONS.read_text().splitlines(), 1):
        m = ENTRY.search(line)
        if not m:
            continue
        cp, name = int(m[1], 16), m[2]
        style, base = (("filled", name[:-len("-filled")])
                       if name.endswith("-filled") else ("outline", name))
        known = meta.get(base, {}).get("styles", {}).get(style)
        if not known:
            problems.append(f"Icons.qml:{n}: no Tabler icon named ti-{name}")
        elif int(known["unicode"], 16) != cp:
            problems.append(f"Icons.qml:{n}: ti-{name} is"
                            f" U+{known['unicode'].upper()}, not U+{cp:04X}")
        else:
            entries.append((cp, base, style))

    # The private-use planes, where every icon font lives, and the
    # stretch past U+FFFF where Tabler's newest icons sit. No QML file
    # has a reason to type a character from any of them.
    def is_icon(cp):
        return 0xE000 <= cp <= 0xF8FF or 0x10000 <= cp <= 0x10FFF or cp >= 0xF0000

    for qml in sorted(SHELL.rglob("*.qml")):
        if qml == ICONS:
            continue
        for n, line in enumerate(qml.read_text().splitlines(), 1):
            bad = next((ch for ch in line if is_icon(ord(ch))), None)
            if bad:
                problems.append(f"{qml.relative_to(SHELL)}:{n}: raw"
                                f" U+{ord(bad):04X}; name it in"
                                " Services/Icons.qml instead")

    if problems:
        print(f"Icons.qml does not match Tabler Icons {VERSION}:",
              file=sys.stderr)
        fail(problems)

    entries = sorted(set(entries))
    filled = sum(1 for e in entries if e[2] == "filled")
    print(f"  {len(entries) - filled} outline and {filled} filled glyphs,"
          " all named correctly")
    return entries


def draw(nodes, name, style, stroke):
    import pathops
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.svgLib.path import parse_path

    key = name + ("-filled" if style == "filled" else "")
    dx, dy = OPTICAL.get(key, (0, 0))
    # SVG is y-down from the top-left corner; a glyph is y-up from the
    # baseline. Grid (12, 12) goes to the middle of the line box.
    transform = (UNIT, 0, 0, -UNIT,
                 500 - (12 - dx) * UNIT, (ASCENT - 500) + (12 + dy) * UNIT)

    path = pathops.Path()
    for tag, attrs in nodes[style][name]:
        if tag != "path":
            raise SystemExit(f"ti-{key}: <{tag}> is not a path; teach"
                             " draw() about it")
        parse_path(attrs["d"], TransformPen(path.getPen(), transform))

    if style == "outline":
        path.stroke(float(stroke) * UNIT, pathops.LineCap.ROUND_CAP,
                    pathops.LineJoin.ROUND_JOIN, 4)
    # Round caps come out of the stroker as conics, which neither
    # simplify() nor TrueType can hold.
    path.convertConicsToQuads()
    # One outline per shape: strokes that cross are unioned, so the
    # rasteriser never sees an overlap to darken.
    path.simplify(fix_winding=True)

    pen = TTGlyphPen(None)
    path.draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
    return pen.glyph()


def build(entries, nodes, stroke):
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen

    glyph_names = [f"{style}.{name}" for _, name, style in entries]
    order = [".notdef"] + sorted(set(glyph_names))
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for _, name, style in entries:
        glyphs[f"{style}.{name}"] = draw(nodes, name, style, stroke)

    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: f"{style}.{name}" for cp, name, style in entries})
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(
        {g: (1000, getattr(glyphs[g], "xMin", 0)) for g in order})
    fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=-DESCENT, sTypoLineGap=0,
                usWinAscent=ASCENT, usWinDescent=DESCENT)

    # Its own family per stroke, so FontLoader switching files is a
    # switch of family too, rather than a second font answering to the
    # name the first one already holds.
    family = f"Island Tabler {stroke}"
    fb.setupNameTable({
        "copyright": "Tabler Icons, Copyright (c) 2020-2026 Paweł Kuna."
                     " MIT License.",
        "familyName": family,
        "styleName": "Regular",
        "uniqueFontIdentifier": f"{family};{VERSION}",
        "fullName": family,
        "version": f"Version {VERSION}",
        "psName": family.replace(" ", "").replace(".", "_"),
        "description": f"Tabler Icons {VERSION} stroked at {stroke}, for"
                       " island-dots by packages/tabler-icons/build.py",
    })
    fb.setupPost(keepGlyphNames=False)

    out = HERE / f"tabler-{stroke}.ttf"
    fb.save(out)
    print(f"  {out.relative_to(REPO)}  ({out.stat().st_size // 1024} KiB)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true",
                    help="verify Icons.qml and stop; build nothing")
    args = ap.parse_args()

    meta, nodes = fetch()
    print("Checking:")
    entries = check(meta)
    if args.check:
        return

    print("Building:")
    for stroke in STROKES:
        build(entries, nodes, stroke)


if __name__ == "__main__":
    main()
