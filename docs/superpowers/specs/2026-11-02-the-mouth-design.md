# The torso: the mouth

## Why

The torso is the last stand-in among the ánimas: boxes on the shared logic. The user's idea replaces the original "withered torso dragged by its arms": "We can make the torso be like the mouth itself, like a grotesque conglomeration of several animas into one."

Its cause in the world: souls no one lit a candle for, clung together for want of anything else. A hunger that has swallowed others ([[world-built-by-its-events]]).

It stays the `torso` form in code (`Bestiary`, `Anima.form`). Nothing on screen names it.

## Goals

- The strongest silhouette of the three, and the worst one to be caught by.
- It reads as several souls fused into one, and as a mouth, from a distance and up close.
- It moves like too many arms dragging one mass, none quite in step.
- Being caught by it looks and feels unlike the hands or the face.
- A death with character, in the same fire as the others.

## Non-goals

- Changing what it deals and takes: health 130, grip 2 (two whips), power drain 12, life drain 4, swipe 14 damage at 2.2 m, or how the Bestiary rates rounds against it. Its pace was frozen here too, until the user played it: "It moves too quick and lunges in too quick, it's movements should be heavier since it is an amalgam." So it crawls at 0.85 in hauls, gathers for 1.5 s, lunges 3.6 m at up to 4.8 m/s, and winds up a rake for 0.95 s (`Bestiary`).
- New enemies from its death. It comes apart visibly; nothing it leaves can hurt you (Claude's call; a split can come later).
- A new spell or item against it.

## Anti-goals

- A modelled human body. Past ones were rejected as hideous ([[no-modelled-human-figures]]).
- A statue: one mass with nothing moving of its own.
- A swarm: loose pieces round a core that don't read as one mouth.
- Sawed-off ends or anything stuck on rather than grown: every place a limb or face enters the flesh is closed and sculpted ([[monsters-look-and-feel-good]], [[inspect-geometry-closely]], [[connected-topology-details-make-sense]]).
- Fire or gore drawn solid and cheap: judged in the game, frame by frame.

## What it is

The user's: the mouth, a conglomeration of several ánimas. The rest is Claude's proposal, which the user accepted ("sounds good").

- **The shape:** the fused ribcage is the mouth, split down the front, ribs for teeth, wet and dark inside. Dried faces and arms from the others press out of the mass, some still moving on their own. Burnt-out fire trails behind it, as the design for the torso always had it.
- **How it moves:** dragged by too many arms, none in step, so it heaves and lurches, slowly. It keeps the long, readable lunge, with the ribs opening wide before it comes.
- **Up close:** it rakes with several arms at once, and the ribs snap shut in front of it. This is its swipe: one wind-up, one hit, by the existing numbers.
- **When it gets you:** it doesn't hold you, it closes on you. The ribs come in round your view like a cage, with faces and hands on every side, and you are being drunk by several at once.
- **The whip:** two, as now. The first cracks the ribs open, visibly, and they stay cracked while it has you. The second throws it off.
- **Its death:** the ribs burst and the mass comes apart, each soul going its own way in the sick fire. The other forms have three acted deaths each; it gets the same, written for a mass.

The user's, from Claude's picks ("Yes, both"):

- **The ribcage:** edited from Aaron Olson's "Free low-poly PBR / BSDF textured human skeleton" (https://sketchfab.com/3d-models/free-low-poly-pbr-bsdf-textured-human-skeleton-d0c9919aec004fd39d65ce7a7960969b), CC BY 4.0, credited in `CREDITS.md`. No confirmed CC0 ribcage was found, and the user accepted a credit ("Yes, credit it"). The user downloads it. Its ribs are cut out and reduced from 466k triangles; that they are separate shapes is to be checked first.
- **Size and stance:** a heaped mass about waist high that crawls low and rears to chest height when the ribs open. Its height and hit radius in `Bestiary` change to match, so shots land where you see flesh; the checks that pin them change with them.
- **The dead candles** stay on its back: the candles nobody tended, answering the one lit for you on the death screen (`death_veil.gdshader`).

## Approaches

The user picked the first.

- **A fused core with real limbs (picked):** the ribcage mouth and mass of flesh modelled as one closed mesh with its own rig for the mouth. The arms and faces pushing out of it are the approved rigged hands and skull, their ends buried deep in the flesh. They keep their approved look and can move on their own, and it builds on what works. The cost is that the entries must be sculpted to look grown.
- One fused mesh with one rig: truly seamless, but most faces and hands would barely move, and it is closest to the bodies that were rejected.
- Pieces round a dark core: cheap and lively, but a swarm, not a mouth.

## Settled before planning

From the project as it stands:

- **Monsters and bodies:** the logic is `Anima.gd` with `form = &"torso"`; how it looks is `AnimaBody.gd`, sprung poses from `POSES`, as the hands and face. Its states are the existing ones, and they get torso poses: `rest`, `wake`, `rise`, `rush`, `circle`, `tell`, `leap`, `missed`, `thrown`, `wind_up`, `swipe`, `back_off`, `crowd`, `leave`, `on`.
- **The model's pipeline:** a Blender headless script in `tools/monsters/`, as `build_anima_face.py`, refusing open edges, colour attribute active. It reuses `assets/monsters/anima_hands.glb` and the skull in `anima_face.glb` for what pushes out of the mass. The flesh wears `anima_flesh.gdshader`, which carries the burn.
- **Being caught:** first-person pieces live on the viewmodel layer, as `LeechHands.gd` and `LeechFace.gd`, and `LifeLeech.holds_face` is how a form says what it does on you. The torso gets its own piece alongside them. It takes one slot of three like the others.
- **Deaths:** `AnimaDeaths.gd` and `AnimaBody.burn_away`, `AnimaBurn.gd`. Its three are added there.
- **Your death with it on you:** `PlayerDeath` treats it as feeding, so it plays the ánimas' or both. Its last gulp is the ribs closing all the way over your view, as the face's mouth comes down.
- **The HUD's drain:** `threads` and `pouring` run to where the torso's piece says its mouth is.

Claude's calls:

- **Where it is while it has you:** in front of you, as the face is. Its world body hides, you hit it where you see it, and a shot or whip aimed ahead finds it. So does its death if you kill it there: it bursts away from in front of you. Since a face works this way already, the fight's rules don't change.
- **The middle stays clear:** while you are alive, the cage stays out of the middle third of the view (`middle_kept_clear` covers it), even with the curse and two more on you. Only your death closes it.
- **The cracked ribs** show only after the first whip while it has you; a torso thrown off and coming back is whole again, since grip resets as it does today.
- **A review stop:** per [[models-one-by-one-supervised]], the model is shown as pictures, then in the game, before poses, the first-person cage or deaths are built on it.
- **How many:** about three arms and two or three faces pressing out, plus the two that drag it. Left to tune by eye, within the budget below.
- **The budget:** the mixed gym's worst wave still holds 60 fps at 1152x648 with vsync on, measured with `tests/diag_mixed_perf.tscn`.

## Constraints

- Godot 4.5.1, GDScript; failing checks first ([[failing-checks-kept]]); `--fixed-fps 60`.
- No `juice.punch` pitch for anything repeating.
- Sounds from approved packs as stand-ins; wanted takes go on `sounds_needed.md` and `elevenlabs_prompts.md`. Effects are made by us. No words of ours on screen.
- Stills from the real game, lit room and dark yard, each joint inspected close up, before anything is shown ([[finished-means-meticulous]]).

## Left to the builder

- The poses, within the beats above.
- The exact form of the first-person cage, within: ribs round the frame, faces and hands on every side, the middle clear.
- The three deaths, within: ribs burst, the mass comes apart, each soul its own way, in the fire already approved.
- Which approved sounds stand in.

## Later: the elite form

The user, Nov 2: "with certain cases it can absorb other hands and other skulls into it making it bigger, but that's an *elite* form of the torso enemy." Not the plain torso. To be designed once the mouth stands; what "certain cases" are is still open.
