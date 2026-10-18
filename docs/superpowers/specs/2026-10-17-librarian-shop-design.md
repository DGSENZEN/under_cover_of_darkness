# The rare-book librarian's shop: design

Oct 17 2026. The second stand of the Metro Underground, after the curandera's stall. It lives in
its own look-dev bay until the user approves it; then it is placed in the real map (`maps/metro`,
the approved layout) with the rest of the bay's pieces.

The parent spec is `docs/superpowers/specs/2026-10-16-metro-underground-design.md`. Every piece
follows `docs/superpowers/refs/underground/recipe.md`, and every effect follows
`docs/superpowers/refs/underground/vfx_method.md` (the Deadlock way).

## 1. Intent

A rare-book dealer who is also the Church's specialist exorcist keeps a shop off the corridor. The
user wants it to be the Underground's showpiece of the uncanny, "really inspired by Deadlock". The
books are alive with what is written in them.

**Why now.** The librarian is a character the player will meet later. He will be modelled "soon
enough" (the user), but first the shop must say everything about him without him in it: his trade,
his faith, his hunt, the danger of what he keeps. When he arrives, the room has already told the
player who he is.

**What success looks like.**
- The player walks in and reads the man from his corner before reading anything else.
- Walking the shelves is a show: books open as you come near and close as you leave, each in its
  own way. Words stream between the stands like living things, books drift overhead, and each
  section glows with its own art.
- Each section is recognisable at a glance by its shelves, its effect and the colour of its light.

## 2. What it is (the user's decisions)

**A shop you walk into**, not an open stall. It is an old vaulted room off the corridor with an
open shopfront onto it. Shelves rise toward the vault. The librarian's corner is at the back.

**The first thing seen: the librarian's own corner.** He is a **Catholic exorcist, a specialist,
akin to a venator**: Church-trained, and he hunts what he exorcises. The user approved this
corner:
- **The dealer:**
  - a high desk facing the customers, a green-shaded lamp on it;
  - the acquisitions ledger lying open;
  - a magnifier, white cotton gloves, a repair kit (bone folder, glue pot, waxed thread);
  - his coat and hat on a hook, and the chair he has just left.
- **The rite:**
  - a worn Rituale Romanum bristling with ribbon markers;
  - his purple stole;
  - a crucifix, a holy-water sprinkler (aspergillum), a tin of blessed salt, a phial of holy oil;
  - a reliquary with a saint's bone behind glass;
  - a St Benedict medal nailed to the desk's edge.
- **The hunt:** a rack behind him with his working tools:
  - silver-tipped stakes;
  - a sword cane;
  - a heavy revolver and a box of engraved rounds;
  - a crossbow;
  - a bandolier of holy-water phials;
  - chains;
  - bear-trap jaws hung like a trophy.
- **The work in progress:** one book chained and padlocked to the desk, iron nails through its
  cover. Now and then it strains against its chain and its words try to crawl out, and a ward
  flares to push them back. Behind him, a caged quarantine shelf of books still waiting to be
  exorcised, each one stirring.
- **The floor:** a chalk ward circle round the desk, its open side closed by a salt line.

**Five sections, each with its own shelf aesthetic and its own effect** (approved):

| Section | Its shelves | What opens out of its books |
|---|---|---|
| Chronology | brass and clockwork | clock hands and astrolabe rings turning, sand falling upward, a page that ages and un-ages |
| Necromancy | bone and black lacquer | a skeletal hand, a skull rising in green spirit-fire, the dead's faces in smoke |
| Alchemy | copper and glass | a turning ouroboros, a homunculus in a glass flask, alchemical symbols burning gold |
| Occult metaphysics | dark wood cut with sigils | nested geometric sigils, an eye opening, planes folding |
| Monster hunting | iron, hooks, trophies | the creatures he hunts rising as spectres (a lechuza, a chupacabra, a nahual), the weapon for each |

**The books.**
- **Large shelves,** and **books floating about** the room.
- **Certain books open when you come close and close again when you move away.**
- **What happens when one opens depends on its kind:**
  - a **novel** shows **spectres of its characters, in different colours**;
  - a **book of occult study** shows its section's effect (the table above);
  - a **spellbook** throws **sigils, wards and auras**.
- **Some books pour out chains of text,** "as if the words carried life"; **waves of words fly
  from one bookstand to another**.
- **Auras rise from the sections.**

**Spectres** can be figures, but "the models need to be well made!" They can also be specific
things (weapons, creatures, ghosts), and shapes and sigils work too.

**A novel's characters start as stand-ins** (the user, after the builder check). Each character is
drawn without a body: a Mignola-black silhouette with a coloured rim, or their emblem (a mask, a
hat, a sword, a rose). Real figures replace them once one passes the user's review.

**Words.** The user writes all words: titles, ledger lines, labels, section names. Meanwhile a
**random script that looks like writing** fills the text chains, the pages and the spines. The
user's words can replace it later.

## 3. Goals, non-goals, anti-goals

**Goals**
- A walk-in shop that communicates the librarian with no figure of him.
- Five readable sections, each with its own shelf kit, colour and effect.
- Proximity books with distinct effects by kind (novel, occult study, spellbook), drawn the
  Deadlock way.
- Floating books, word-chains and waves of words between the stands.
- Built to the recipe, model by model, each reviewed by the user.

**Non-goals**
- The librarian himself (modelled later, separately).
- Dialogue, quests, buying and selling (talk and quests come later; the user writes them).
- Placing the shop in the real map. That is the next project ("build the real map").
- Sound. The user is sourcing new metro recordings; the shop's sound waits for them.

**Anti-goals: this fails even if it works if...**
- the effects read as sprite cards or soft particle fog ("smoke quads"); it must be meshes, hard
  erosion, colour bands, fresnel rims;
- any figure is crude (skin blobs, mannequins, ring-built shrouds; see the Oct 17 rejections);
- it is sprinkled: uniform spacing of books or effects, magic with no cause;
- the room is a box of identical shelves. Each section must differ in shape, not only in colour;
- the corner says "generic wizard" instead of "Catholic exorcist, hunter, book dealer";
- it looks low-detail or "primitive", or is painted with smeared textures.

## 4. Constraints

- **Recipe:**
  - build scripts in `tools/eclipse/`, the gate, the painter layers, the `bespoke` material;
  - the player capsule rules (ways in at least 1.1 m, clear to 2.1 m, aisles a metre deep);
  - kit tests in `tools/eclipse/test_kit_bpy.py`;
  - bay tests in a headless suite, plus a stills tool.
- **Models one by one, supervised:** the user reviews each piece or family before the next.
- **Visual defects:**
  - never call one harmless;
  - inspect geometry closely before calling anything done;
  - no layered quads (the 3 cm gate).
- **Effects:**
  - no free VFX assets; everything is our own mesh effects (`vfx_mesh.gdshader`, `MeshVfx.gd`);
  - effects are skipped by the F2 form light.
- **Textures:**
  - CC0 or self-made only;
  - the user's brush sheets are read by rank, soft and painterly;
  - the raw sheets stay out of the repo.
- **Words and art:** the user writes all words and paints all signature art. Blank faces wait for
  them.
- **Figures:** only if built to a high bar (references first, supervised). Prefer objects,
  creatures, shapes and sigils.
- **Every strange thing has a cause:** the books are alive because of what is written in them. The
  quarantine and the chained book are why the exorcist keeps the shop.
- **Git:** nothing merged or pushed without the user's OK.

## 5. Claude's calls (the user can overturn any)

- **The room.**
  - About 8 m wide and 6 m deep.
  - A brick barrel vault, 4.5 m at the crown, its springing at 3 m.
  - An open shopfront 3 m wide onto the corridor, under an arch, with a sign board left blank for
    the user's art.
  - Floor: worn boards over the Metro tile, with a runner rug to the corner.
- **The layout.**
  - The corner sits at the back, centred on the shopfront, so it is the first thing seen through
    the arch.
  - The five sections sit in bays: two down each side wall and monster hunting flanking the
    corner. Necromancy is next to the quarantine cage.
  - A free-standing double-sided case in the middle splits the floor into two aisles of 1.2 m.
  - The tallest shelves (3.2 m) have a rolling library ladder, and a gallery is only implied by
    shelves above reach.
- **Section colours,** within our colour rule:
  - chronology: amber-gold;
  - necromancy: the chartreuse of Graves' spirits (shared with the ánimas);
  - alchemy: copper-orange with gold;
  - occult metaphysics: violet;
  - monster hunting: iron red.
  Novels' character spectres take any colour; spellbooks' sigils take their section's colour.
- **The proximity books.**
  - About a dozen live books: two or three per section, plus novels on a front table and two
    spellbooks on lecterns. All the other books are static set dressing.
  - A live book opens when the player comes within about 1.5 m and closes when they leave. The
    covers are hinged meshes, and the pages fan.
- **Floating books:** six to ten drifting slowly under the vault, turning their pages. A few
  return to the shelves and others leave them, so the room never looks the same.
- **Word-chains:** ribbons of glyph meshes, the made-up script laid as quads along a ribbon path,
  each letter a hard-edged mesh glyph and never a soft card. They flow out of open books and in
  slow waves between the stands. The chained book's words strain toward the floor and are pushed
  back by its ward.
- **The made-up script:** a set of about 40 glyphs of our own, drawn as an SDF texture atlas, so
  they stay crisp at any distance.
- **Spectres:** mesh effects. The colour bands, erosion and fresnel of `vfx_mesh` are used on real
  meshes: kit-built objects (hourglass, astrolabe, flask, ouroboros, sigil rings, weapons) and, for
  creatures and ghosts, reference-built models reviewed one by one. No spectre is a human figure
  until one has been approved as well made.
- **The order of work** (each reviewed by the user before the next):
  1. the room shell and the shopfront;
  2. the corner (desk, chair, lamp, rite things, the hunt rack, the chained book, the cage);
  3. the shelf kit per section;
  4. the books kit (spines, stacks, live books with hinged covers);
  5. the effects: book opening, the section effects, word-chains, floating books, auras;
  6. the dressing pass.
- **The bay:** `maps/library_lab.tscn`, with the player, F-keys like the underground bay, and its
  own test suite and stills tool (or the same stills tool generalised).
- **Review granularity:** the user reviews by family, as the parent spec's "models in sets" says.
  Each family is shown with stills of every piece in it, close and in place. The corner is four
  families: the dealer, the rite, the hunt, the work in progress. Any piece the user flags is
  redone before the next family.
- **Creatures:**
  - the nahual spectre reuses the approved nahual model (`underground_uncanny.py`), drawn in the
    spectre's effect;
  - the lechuza and the chupacabra are new creature models, references first, each reviewed on
    its own;
  - the monster-hunting section first ships with its weapons and sigils, and the creatures join it
    as they are approved.
- **Words:** the text system takes any font. Glyphs are drawn from an SDF atlas built from a font
  file, laid out along the chains. Our made-up script is one font; the user's readable words
  (Spanish, Latin, with accents) can replace it later without rebuilding the chains.
- **Interaction:** everything in the shop is static set dressing for now; nothing can be taken or
  knocked over. The corner's notable objects and the live books stay separate objects, so frob,
  carry or theft can be added later without rebuilding them.
- **Placement-ready shell:** the room's build script takes its width, depth and crown height as
  parameters, so it can fit the space the real map gives it. The Pasaje market layer (-11, 4.5 m)
  is its likely home: brick vault, Metro tile floor.

## 6. Left to the builder

- Exact dimensions within the calls above, the kit pieces' counts and variants, triangle budgets
  within the recipe.
- How the hinged covers and fanned pages are rigged.
- How the word-chains' paths are authored: splines between named stand points are fine.
- How many glyphs, and their exact shapes.
- Which section effects come first, so long as each section has one before the dressing pass.
