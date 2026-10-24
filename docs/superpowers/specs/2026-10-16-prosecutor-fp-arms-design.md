# The Prosecutor's first-person arms

Agreed with the user on 2026-10-16. Lines marked *(Claude's call)* were proposed by Claude and not objected to; the rest is the user's.

## Why

The first-person arms are borrowed from the full body model the guards also use (`Humanoid.build(&"player")`, a Quaternius character).
- Its arms are short: 0.5 m from shoulder to wrist. Free-run had to stretch the joints to 0.65 m (`ArmReach.arm_length`).
- Its hands are low-detail, with fingers that barely articulate.
- Every free-run arm fix since (weight, true-depth grabbing, hand over hand) has worked around it.

The user: "I feel the model itself is not working to the rig and alterations we are doing."

These arms are on screen every moment of play, and climbing now shows them gripping stone at true size and depth. They need to be made for that.

## Goals

- A first-person arms model made for the view, independent of any body: **shoulders to fingertips**, both arms.
- Real proportions: **0.65 m shoulder to wrist** *(Claude's call: about 0.34 m upper arm, 0.31 m forearm, and an adult man's hand of about 0.19 m)*.
- Hands that can genuinely grab:
  - three jointed bones per finger and per thumb;
  - weights that bend cleanly at the knuckles, wrist and elbow;
  - palms and fingers that wrap a ledge, a pipe or a rung, and close on a sword grip.
- The **Deadlock × Hellboy** look at full detail, not the PS2 budget: more polygons and detailed painted textures (user).

## Who he is (the user)

- **An older man.** Adult, weathered hands: visible knuckles and tendons, hair on the backs of the hands and the forearms, scars across both palms. The palms show whenever he grips a ledge.
- **Sleeves:** a **blue trench coat**, heavy and worn, creasing at the elbow, ending a little above the wrist (Constantine, Hellboy).
  - *(Claude's call: a white shirt cuff shows at each wrist; the coat is a heavy wool or gabardine.)*
- **Bare hands.**
- **Two rings:** one on the **middle finger** and one on the **ring finger**, engraved with **hex and ward inscriptions**.
  - *(Claude's call: both on the left hand; dark worn silver or iron, not gold; the engraving is cut deep enough to read as lines catching light when the hand is near the eye.)*
  - *(Claude's call: Claude drafts the glyphs from the six schools in `2026-10-16-mexico-city-demo-program.md` — Obsidian, Copal, Séance, Nahual, Lumen, Relic — for the user to approve or replace. No words are put in the Prosecutor's mouth.)*

## Look and how it is made

The Metro Underground's new art standard applies (`2026-10-16-metro-underground-design.md`, section 4):

- **Built in a live Blender session** over the Blender connection, with renders as it develops, so the user can open the same file.
- **Shape first:** big forms and a clear silhouette (the hand's mass, the sleeve's weight), then secondary detail (knuckle creases, veins, tendons, nails, scars, hair, sleeve seams and wear).
  - *(Claude's call: the fine detail — creases, veins, scar tissue, sleeve weave — is sculpted on a high-detail version and baked to a normal map on a game mesh; hair is painted, not geometry.)*
- **Textures painted in layers, Deadlock-style:**
  1. a flat colour field per material (skin, coat, shirt cuff, ring metal);
  2. a top-down light gradient;
  3. baked AO and curvature driving bright worn edges and dark grime in creases;
  4. brush-stroke breakup from **the user's brush sheets**, `~/Downloads/Texture_Abstract00.png` to `04.png` (one is named `Texture_Abstract01 .png`, with a space);
  5. Mignola's solid black in the deepest recesses.

  The game's existing light shader goes on top.
- **The raw brush sheets stay out of the public repo** (user). The textures painted with them are self-made and committed.
- **Budget** *(Claude's call)*:
  - game mesh about **20–30k triangles for both arms together**, most of it in the hands;
  - **2048×2048** colour and normal maps for the arms and sleeves, and a separate small set for the rings.
- **Hands painted, not photographed:** paint from scratch, using the brush sheets for breakup (user).

## The rig

The rig must fit the arm solver as it stands (`scripts/Visual/ArmReach.gd`, driven by `ViewArms.gd` / `HandSlot.gd`):

- **Bone names:**
  - per side: `clavicle_l/r`, `upperarm_l/r`, `lowerarm_l/r`, `hand_l/r`;
  - fingers: `index|middle|ring|pinky|thumb` joints `01|02|03` per side, e.g. `index_02_l`;
  - a root bone holding the two clavicles.
- **Pose library:** the solver learns its closed fist from an animation pose (`ArmReach.FIST_FROM`, which today reads `Idle` / `Sword_Idle` from the body's clips). The new rig ships its own small poses:
  - open hand;
  - closed fist;
  - ledge hook (fingers over, thumb under);
  - sword grip;
  - flat push (pressing down on a top).
- **Proportions are real**, so `ArmReach.arm_length` is no longer needed for these arms and is set back to 0 (the model's own) once they are in.
- **Independent of the body.** The rig is its own scene with no torso or head. Today's free-run placement rules are kept: the chest hangs under the face below the view while holding, and the arms switch to true size and depth on a hold in view.

## Settled after the builder review *(Claude's calls)*

- **The poses are used, not just made.** The hand picks its pose from what it holds:
  - ledge hook on an edge or sill;
  - wrap on a pipe, rung or rope;
  - flat push on a top while pulling up or mantling;
  - sword grip on a held weapon;
  - open while reaching;
  - fist otherwise.

  This is what makes the hands read as grabbing. HandContacts reports the kind of hold, and ArmReach/HandSlot blend between poses as they blend the curl today. It is built in piece 2, the hand.
- **Nothing of the old body is drawn but the kick leg and boot.** The torso, head and other leg are hidden. The coat sleeves end in closed shoulder caps, a small yoke, so no open cut can show from any angle, including the roll and looking down while hanging.
- **The new arms sit behind a switch** (a key, as F10 compared the old and new locomotion) from piece 1 until piece 6. The suites stay on the old arms until integration retires them. At piece 6 the new arms become the default and the switch is removed.
- **Material:** the arms keep the depth handling the free-run work depends on (squeezed in front while free, true depth while holding: FR61/FR62).
  - They use a standard material whose colour map carries the painted layers (flat colour, AO and curvature wear, brush breakup, Mignola blacks).
  - The top-down light gradient is baked in gently.
  - If the painterly shader is wanted on them, it gets the same view-space depth scaling added. The builder chooses, and FR61/FR62 must hold either way.
- **The arms are lit by the game's lights.** In a stealth game your hands must go dark in the shadows and catch the lamplight. The paint carries the form and the blacks; the lights carry the scene.

## What else uses the old body (left to the builder, Claude's call on the default)

- **The kick:** the first-person kick shows a boot and drives the old body's right leg (`ViewArms.set_foot`).
  - *(Claude's call: the old body stays for the leg and boot only. Everything else on it is hidden. A first-person leg is a later piece.)*
- **Held items:** sword, bow, purse, keys and the letter are posed against the old hand's grip offsets (`HAND_GRIP`, `BOW_GRIP`, `PURSE_GRIP`, `PINCH_GRIP`, `STRING_GRIP` in `HandSlot.gd`). They are retuned to the new hands in the integration piece.

## Pieces, each reviewed by the user before the next

Following the one-model-at-a-time rule:

1. **Blockout.** Both arms as simple forms at real proportions, rigged, in the game: shown climbing station 17, holding the sword, and in the roll. Proves the length, the shoulder and chest placement and the silhouette in frame.
2. **The hand.** Full topology, every finger joint, weights. Shown in the pose library and gripping a sill in game, from the player's view and close up.
3. **The sleeve and cuff.** The blue trench coat and the shirt cuff, with the elbow crease under bend.
4. **The rings.** Modelled with engraving, and the drafted glyphs for the user's approval.
5. **The paint.** All five texture layers on skin, coat, cuff and rings, and the scars and hair.
6. **Integration.** The old arms retired, held items retuned, the arm-length stretch removed. Clips of climbing, grabbing, combat and the roll.

## Done means

- Every existing suite that passed still passes (`freerun_test`, `traversal_test`, `ledge_polish_test`, `movement_gym_test`, the combat suites, `sturdy_test`, `life_test`, `interaction_test`).
- New checks:
  - the arms are 0.65 m shoulder to wrist with no stretching;
  - every bone name the solver needs exists;
  - each pose in the library closes or opens the fingers as named;
  - held hands are drawn at their grips at true depth (FR61, FR62 stay green).
- The user has approved each of the six pieces from renders and in-game play.

## Not in scope

- A third-person or full-body Prosecutor model.
- First-person legs (the kick keeps the old leg for now).
- Any NPC or guard model.
