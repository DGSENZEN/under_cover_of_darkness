# The revolver's model and its muzzle flash — design

The user showed a Deadlock revolver (the "Case Closed" skin) and asked: "think you can make a better mesh for the revolver itself? … more akin to this, plus make the muzzle flash for the revolver and itself much prettier, more stylized."

It replaces the stand-in of boxes (`Weapon.revolver_mesh`) with a modelled gun, and restyles the shot's flash. Built one at a time and shown to the user ([[models-one-by-one-supervised]]). Lines marked *(Claude's call)* fill in what the request left open.

## The gun

**Read from the reference** (reference, not imitate): chunky, rounded, hand-made forms with soft bevelled edges that catch the light.
- A fat fluted cylinder with brass showing in the chambers.
- A heavy frame with a solid top strap, and a slab-sided barrel with a full-length lug under it.
- A big hammer spur and a fat, filled-out grip.
- Warm gunmetal, brass and wood.

**Ours stays a LeMat × Samaritan:** the second, fatter shot barrel runs under the main one, as the full-length lug *(Claude's call)*.

**Fits the game as it is:** same size and frame as the stand-in, so the hand poses, aim, recoil and the points the game reads still line up:
- the handle at the origin, the barrel along -Z;
- the muzzle at (0, 0.1, -0.32);
- the shot muzzle at (0, 0.072, -0.25);
- the cylinder at (0, 0.088, -0.065);
- the hammer pivot at (0, 0.11, 0.012);
- the loading gate's hinge at (0.021, 0.088, -0.045).

**Its moving parts:** the cylinder, hammer and loading gate are separate meshes, each built about its own pivot and axis, as the game turns them:
- the cylinder about its Y;
- the hammer about its X;
- the gate about its Y.

**How it's made:** built by a script in Blender (`tools/weapons/build_revolver.py`), so it can be rebuilt as it is tuned. It saves `assets/weapons/source/revolver.blend` (for the user to edit) and exports `assets/weapons/revolver.glb`. `Weapon.revolver_mesh` takes the model and its parts from it, and falls back to the stand-in if it's missing.

**Its look:**
- **Materials:** flat to begin with: warm gunmetal, darker blued parts, brass, walnut.
- **Shading:** bevelled edges and weighted normals do the stylised highlight work.
- **Textures:** painted textures come later, if the user wants them.
- **Limits:** solid, closed meshes, no overlapping layered quads ([[kit-pieces-built-right]]).

## The muzzle flash

It stays a two-frame flash in your view, in the shot's approved colours (cream core, amber, burnt-orange edge), made more stylised *(Claude's call)*:
- **Frame one:**
  - a hot round core;
  - a burst of sharp, uneven spikes like a drawn flash;
  - a long tongue of flame along the bore.
- **Frame two:** smaller, turning orange, its spikes eaten away.
- **Sparks:** a few short sparks streak forward out of the muzzle.
- **Smoke ring:** a ring of smoke puffs out from the muzzle and drifts as it fades, alongside the curls that already hang there.
- **The shell:** a wider burst with more spikes, more sparks, and a bigger, slower ring.

## Checks

- **Model:** loads with its three parts, its points where the game expects them, closed meshes, a sensible triangle count.
- **Flash:** core, spikes and tongue in frame one; sparks and smoke ring made and gone in time; none with effects off.
- **For the user:** stills and clips of the gun at rest, firing, reloading, and the flash, by day and at night.

## What was built: silhouette D, after Case Closed

The first two builds were rejected: "the revolver looks hideous", then "its not looking at all like i want it too, look at case closed from deadlock … abes weapon". The reference is Abrams' gun, Case Closed, measured from the Deadlock wiki's reference sheet (four views).

Two side-view silhouettes were drawn from those measurements. The user picked D: "Build D, the walnut forend like Case Closed."

**The gun:**
- **Cylinder:** a long, fat cylinder (6.7 cm across, 7.7 cm long) with long rounded slot flutes, brass noses at its face and brass rims at its back.
- **Frame and barrel:** a thin light-steel frame (2.2 cm across) outlining it, and a short round barrel with a raised ring.
- **The shot barrel:** a walnut forend under the barrel, whose steel nose holds the shot barrel's bore (our LeMat).
- **Rear and grip:** a slim hooked hammer, a latch screw each side, a round guard with a sickle trigger, and a long walnut grip raked back hard.

**In the game:**
- **Scale:** the whole gun is 1.3 times the drawing's size about the fist, so it fills the view as the reference does (`SCALE` in the build, `Weapon.MODEL_SCALE`).
- **New points:**
  - the muzzle at (0, 0.0695, -0.227) × 1.3;
  - the shot muzzle at (0, 0.038, -0.223) × 1.3;
  - the cylinder at (0, 0.046, -0.1055) × 1.3;
  - the hammer at (0, 0.072, -0.04) × 1.3;
  - the gate at (0.0125, 0.046, -0.06) × 1.3.
- **Materials** *(Claude's call after the first in-game stills)*: steel at metalness 0.55 and brass at 0.6. At full metalness both reflected the dark stage and went black.
- **Still open:** the hand holds the hard-raked grip with the old handle's pose, so the wood runs straight down through the fist. Re-posing the grip in Blender with the user is still to come.

**A fix found on the way:** the viewmodel now sets each surface's look on a copy of the mesh, not as per-surface overrides. With overrides, the headless renderer reported a null material for every surface of an imported multi-surface model (the sword did it too).
