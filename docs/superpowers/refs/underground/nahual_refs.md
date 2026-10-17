# The nahual's model: references (Oct 17 2026)

The user found the first nahual "too primitive" and asked for references before it was remade.
It is drawn flat black (spectre.gdshader), so its **silhouette** is what reads; its surface
shows only where the smoke frays it.

## What each reference gives

**The xoloitzcuintle** (breed standard FCI 234; [Kennel Club](https://www.thekennelclub.org.uk/breed-standards/utility/xoloitzcuintle-mex-hairless-int-imp),
[Dogs Australia](https://dogsaustralia.org.au/breed/detail/89),
[a show photo, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Helsinki2006_meksikonkarvatonkoira-iso.jpg)).
The Aztec dog that guides the dead through Mictlan (Wikipedia).
- The body is a little longer than it is tall (10:9).
- The chest is deep, to the elbow; the loin is tucked; the legs are long and fine.
- The tail is long, low-set and tapering.
- The head is a wedge: skull and muzzle are nearly equal in length, their planes nearly
  parallel.
- The ears are long, large and very elegant, set a little obliquely, erect when alert.
- Folds at the brow and neck when alert.

**The Dolores Olmedo museum's bronze xolos** ([Wikimedia Commons, Correogsk, CC BY-SA 3.0](https://commons.wikimedia.org/w/index.php?search=xoloitzcuintle+Dolores+Olmedo&title=Special:MediaSearch&type=image)).
- The breed simplified in sculpture.
- The tall ears and the long neck carry the silhouette.

**The sighthound's sphinx pose** (greyhounds lying, old photographs on Commons).
- Forelegs straight forward and parallel, elbows tucked in.
- Hind legs folded flat beside the belly, hocks on the floor.
- The long neck rises; the head is held up.

**The Colima dogs** (West Mexico, ceramic, 300 BCE–300 CE; [Wikimedia Commons](https://commons.wikimedia.org/w/index.php?search=Colima+dog+ceramic&title=Special:MediaSearch&type=image)).
- Mexico's own stylization of this dog.
- Smooth, burnished, simple volumes, upright ears, folds at the neck and brow; one lies curled.
- Our surface follows them: one fused smooth form, never tubes or balloons.

**Mignola** (supernatural_refs.md).
- Black as a shape, nothing drawn inside it.
- The eyes are the only colour.

## Rules for the model
1. **One fused surface:** the parts are skinned on a skeleton, fused by a voxel remesh and
   smoothed. No visible joins, no sausage limbs.
2. **The ears are the signature:** broad leaves, wide at the root, tapering to a rounded
   point, cupped forward, set obliquely and standing tall (about a third of the head's height
   again).
3. **Read from the side** (the bench view): chest deep to the floor line, waist tucked up,
   haunch rising again, neck long, head level.
4. **Paws:** defined toes are lost in black; what reads is the forelegs' straight parallel
   line and a rounded paw at each end.
5. **Its gate:** a creature's tight curves make faces of 4–10 mm, so it is gated at
   CREATURE_SLIVER, 4 mm (gate.py). Architecture keeps 1 cm.
