"""Readies a character's talk-box paintings for the game (the talk and quests
spec, section 4, "Character skins").

    python3 -I tools/prepare_talk_art.py curandera
    python3 -I tools/prepare_talk_art.py librarian

Reads assets/ui/talk/<character>/originals/ (the user's paintings, kept out of
git) and writes beside them, in assets/ui/talk/<character>/:
  - backdrop.png   the panel's painting, whole (its frame is cropped away in
                   the game, by the crop in <character>.json, so the swipes
                   can still take paint from anywhere on it)
  - portrait.png   the speaker
  - cursor.png     the marker, its black background keyed out by flood-filling
                   from the image's border (what touches the border and is
                   near black goes; the black inside the painting stays)

Nothing is ever made bigger: a painting wider or taller than 2048 px is
scaled down to fit (Lanczos), the rest are copied as they are. A painting the
folder lacks is skipped (the librarian borrows the curandera's cursor, tinted,
by his .json).
"""
import os
import sys
from collections import deque

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TALK = os.path.join(HERE, "assets", "ui", "talk")
## The longest side a painting is imported at (px).
CAP = 2048
## How dark the cursor's background may be and still be keyed (0-255).
KEY_THRESHOLD = 18


def capped(im):
    """The painting, scaled down to fit CAP if it is bigger; never up."""
    longest = max(im.size)

    if longest <= CAP:
        return im

    k = CAP / longest
    return im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)


def key_black(im, threshold=KEY_THRESHOLD):
    """Clears the black that touches the border (draft 28's key_black): a
    flood fill from every border pixel through anything no brighter than
    `threshold`, then the alpha softened by a pixel."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    queue = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
        + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])

    while queue:
        x, y = queue.popleft()
        i = y * w + x

        if seen[i]:
            continue

        seen[i] = 1
        r, g, b, a = px[x, y]

        if max(r, g, b) > threshold:
            continue

        px[x, y] = (r, g, b, 0)

        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                queue.append((nx, ny))

    im.putalpha(im.getchannel("A").filter(ImageFilter.GaussianBlur(1.0)))
    return im


def prepare(character):
    folder = os.path.join(TALK, character)
    originals = os.path.join(folder, "originals")

    if not os.path.isdir(originals):
        sys.exit("no paintings for %s: %s is missing" % (character, originals))

    made = []

    for part in ("backdrop", "portrait", "cursor"):
        source = None

        for ext in ("webp", "png", "jpg", "jpeg"):
            path = os.path.join(originals, "%s.%s" % (part, ext))

            if os.path.exists(path):
                source = path
                break

        if source is None:
            continue

        im = Image.open(source)

        if part == "cursor":
            # Keyed at full size, so the fill finds every gap; then scaled.
            im = capped(key_black(im))
        else:
            im = capped(im.convert("RGB"))

        out = os.path.join(folder, part + ".png")
        im.save(out, optimize=True)
        made.append("%s %dx%d" % (os.path.relpath(out, HERE), im.width, im.height))

    for line in made:
        print(line)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    prepare(sys.argv[1])
