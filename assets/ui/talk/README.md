# Talk-box paintings

Each important character's talk box is painted by the user (the talk and quests spec, section 4, "Character skins").

- `<character>.json` (committed): the backdrop's crop, the reading pool, the swipe paint regions, the cursor's tip and tint, and where the faces and eyes are for the living painting.
- `<character>/` (gitignored): the paintings.
  - `originals/` holds the user's own files: `backdrop.webp`, `portrait.webp` and `cursor.webp`.
  - `backdrop.png`, `portrait.png` and `cursor.png` are made from them by `python3 -I tools/prepare_talk_art.py <character>`. The script keys the cursor's black and caps each painting at 2048 px, never upscaling.

The paintings' licence isn't recorded, so they are kept out of this public repository, as `textures/ps2` is. A checkout without them shows the plain talk box (`scripts/UI/TalkSkin.gd`), with no errors.

Skins now: `curandera`, and `librarian`, whose cursor is the curandera's, tinted red.
