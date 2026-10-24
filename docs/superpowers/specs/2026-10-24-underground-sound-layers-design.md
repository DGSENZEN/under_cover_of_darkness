# Underground sound layers: neon, pipes, books, and a focus director

Oct 24 2026. Follows the ánimas' voices (0ddfd98, approved by ear).

## Intent

The user: the game's audio is "too rough and not super professional, it needs to feel layered". Things like the
ánimas, "the piping, the neon buzz of lights, the books moving" each need their own sounds, "but without making it
completely overwhelming". Every Underground bay sound was judged bad on Oct 17 (too loud/harsh, fake, repetitive,
dry, wrong space) and the candle lane plays none of them now (`_hush`). So this is a rebuild from the ground up, one
layer at a time, each judged by ear before it goes in.

What "professional" means here:
- every sound has a cause you can see (a tube stuttering, a book landing, a knock along a main), never a loop for
  its own sake (see the "world built by its events" memory);
- many varied takes, never the same twice running, with small pitch and level drift;
- quiet: details sit well under voices; you lean in to hear them;
- placed: each comes from its thing, moves with it, sits in the room's reverb, dulled round corners;
- one mix that decides what is heard when many things sound at once (the focus director).

## Goals

1. **Neon buzz.** Each NeonSign hums with its own loop; its level follows the sign's actual flicker
   (`NeonSign.level()` × `dim`). A stutter to off cuts the hum with a tick; coming back, a short zap. Brownouts (the
   train, `dim`) sag the hum with the light.
2. **Pipes.** Each service main is heard along its length: one emitter per main slides along its run to the point
   nearest the listener (a line source). Per main:
   - water main (green): a slow trickle bed, very quiet; now and then a gurgle; the weeping joint by her stall drips
     (DRIP_AT);
   - fire main (red): a knock that travels: a clank at one point, a fainter one a few metres on, then further
     (water hammer); a breath of hiss at its gate valve;
   - air line (blue): a faint breath;
   - gas line (ochre): silent but for a rare tick at a joint.
3. **Books (the librarian's shop).**
   - ShelfStir: each change is heard at its board, by its kind: books shuffled tallest-first, a book pushed home, a
     gap closed (a slide), a book stood up (a tock), a stack squared. It happens unwatched, so it is heard behind you.
   - FloatingBooks: each aloft has a very quiet page flutter that follows it; coming down onto its board, a set-down
     on wood; rising off it, a lift.
   - LiveBook: opening, a cover creak and the leaves riffling after; shutting, a soft clap.
4. **The focus director** (`scripts/Audio/Focus.gd`): the mix's one say over what is heard.
   - Tiers, as target loudness (LUFS) of a source at 1 m: room bed −42, loops −36, details −30, featured −26.
     Within a tier a source may sit lower (the trickle −40, the air line −42).
   - Every looping source registers with it (its node, its tier, a priority). Every 0.2 s it ranks the audible ones
     by priority × how loud they arrive (distance, occlusion); per tier, the top few (loops 3, details 4) play at
     their level, the rest sink by up to −12 dB, eased over ~1 s.
   - One-shots ask it first (`Focus.allow(tier, at)`): at most a few per tier in any 2 s window (details 3, featured
     2); the ánimas' own two-at-once cap stays.
   - While a featured sound plays near you, loops and details dip a little (−3 dB) under it.

## Non-goals

- The crowd, the train, the vents and steam, the room bed's final source: not this round (the user may still source
  metro recordings). A room bed is cut and listened to as layer 0, but only goes in if approved.
- Procedural synthesis: none (the Sept 26 rule). Everything is cut from recordings by `tools/prepare_sfx.py`.
- Music.

## Anti-goals

- It ends up as loud and busy as Oct 17's bay: every source audible at once, hums you notice.
- Loops you can hear cycling, the same take twice running.
- A sound with no visible cause.

## Constraints

- Sources only from approved packs on disk (CREDITS.md): NOX Essentials (Electromagnetic neon loops 01-05, phone
  pole), FilmCow Recorded (water moving through, metal hit with hammer, book flopping around, paper handled, plate
  take off shelf, wood drawer), FilmCow Designed (space metal), the 400 Sounds Pack (gurgling, metal_blunt_tap,
  subtle_knock, book_open/close, page_turn, paper_move, slide_and_click, razor_buzz), rubberduck's 80 RPG (book_01-04)
  and 100 CC0 (paper, metal), and the user's two Sonic takes (book shelf take, paperback on a small wooden table). New
  sources need the user's approval.
- Godot 4.5; Sfx's buses (World, WorldFar, Souls); occlusion via `Sfx.occlusion_at`; headless tests with
  `--fixed-fps 60` (Sfx is off headless: decisions must be counted with sound off, as Animas' `spoken` is).
- Seeded suites must not shift: new random draws use their own RNGs.
- Another session is building the candle lane and its Metro hookup in this worktree right now: the work goes in
  shared scripts (NeonSign, a new Pipes sound node, the library scripts, Focus); map hookups stay small, and the
  candle lane's `_hush` must keep sparing them.

## Approaches (the mix)

1. **Focus director (picked by the user).** Fixed tiers plus a director that ranks, ducks and caps. It holds up when
   a spot gets busy; costs a small ranking pass every 0.2 s.
2. **Fixed tiers only.** Each source set to its tier and given a short reach. Simpler, but a crowded spot still
   stacks up.

For the pipes, a line source (one emitter sliding along each main) was Claude's call over fixed emitters every few
metres (a chorus of loops that phase) or one-shots only (no sense of water in them).

## Order and the user's gate

Per layer: cut the takes in `prepare_sfx.py` (`--layers`), record a listening file through the game's own chain
(`tests/diag_layer_sounds.tscn`, as the ánimas' was, with the Souls/World buses and a tiled room) to
`docs/superpowers/refs/underground/sound/`, send it, and wire nothing until the user approves it. Then: Focus, the
hookups, tests, and a recording of the bay with everything on at once.

## Calls settled after the builder check (Claude's, for the user to check)

- **Neon stutters.** The stall's one sign (the only NeonSign; the Pasaje's neon is a plain light) goes off twice in
  every ~4.7 s of its pattern. The hum dips with every stutter, but the tick and zap roll per stutter (35%), and come
  at least 5 s apart, so they never fall into the pattern's repeat.
- **Surviving `_hush`.** The candle lane's `_hush` (another session's file) stops every player and nulls its stream
  once, after the bay is built. Every new loop sets its stream itself when it starts and starts on its first frame,
  so `_hush` is left alone.
- **The lab's old emitters.** Its neon `hum` (neon_hum) and `drip_sound` are replaced by the neon buzz and the
  weeping joint's drips. The junction box's electric hum is retired and stays silent this round (judged bad Oct 17,
  no layer here). Their bay tests change with them.
- **The ánimas** keep their own two-at-once cap and their approved levels (voices −30, moans −28); Focus does not
  gate them. Their moans count as featured for the dip under them.
- **Tiers of the pipes:** the trickle and the air line are loops (Focus keeps the 3 nearest loops at full); knocks,
  gurgles, hisses and drips are details.
- **Books:** floating books are LiveBooks with processing off, so their sounds hang off FloatingBooks' own states
  (rising off a board, the 3.2 s descent, the 1.4 s slide on, its rest); a live book's creak starts as its turn
  starts (not at `opened`, which fires at the turn's end). ShelfStir's `_change` gives each change's kind.

## Left to the builder

Exact takes and slice times, flanger-free; reach per source (neon ~4 m, pipes ~8 m, books ~6 m); the ranking
formula's details; test names.
