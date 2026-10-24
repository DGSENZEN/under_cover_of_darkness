# Gun and magic shader reference study — 2026-10-23

The user rejected the mesh-only passes and asked for actual Deadlock/Hellboy references and shaders. References below were viewed in a browser, rather than inferred from search snippets. They are study material, not redistributed game assets.

## Images inspected

- [Deadlock Life Drain screenshot](https://bitskins.com/blog/content/images/2024/09/image-58.webp), from [Lady Geist gameplay](https://bitskins.com/blog/all-about-deadlock-heroes-lady-geist/). Layered cyan-green wisps run from hand to target; narrow bright strands sit inside broader translucent shapes. This is an ability example, not a muzzle flash.
- [Deadlock flame/projectile screenshot](https://m.media-amazon.com/images/M/MV5BNWYyNGQyZGQtOTgwMy00NGYwLWE5OWEtZDAxYWQzNjJkYzg1XkEyXkFqcGc%40._V1_.jpg), surfaced in [this gameplay article listing](https://www.imdb.com/news/ni64826563/). The visible character is Infernus: bright yellow core, red-orange outer flame, stretched directional trails. This is flame-weapon reference, not evidence of Lady Geist's revolver VFX.
- [Hellboy: Wake the Devil preview page](https://images.darkhorse.com/common/salestools/previews/hbywd1/hbywd1p7.jpg), [Dark Horse publisher page](https://www.darkhorse.com/books/12-744/hellboy-volume-2-wake-the-devil-tpb/). Large connected black masses; cream, ochre and a few saturated accents; impacts read through a strong change of shape/value.
- [Hellboy gunfire sequence](https://3.bp.blogspot.com/-MDFlS92OuiE/XMtPwJpnhII/AAAAAAAAa8s/cV_piV7MvBkkjC_xdicBfBgldFP2ucxIgCLcBGAs/s1600/Dz0gie9WsAYt23Y.jpg), reproduced in [a discussion of the Monkey with a Gun miniature](https://the-art-of-caesura.blogspot.com/2019/05/hes-got-gun-monkey-with-gun.html). The gunfire panel uses a large flat yellow field against black silhouette and white lettering. It does not support adding literal floating star symbols to a 3D gun.
- [Valve's official City Never Sleeps page](https://www.playdeadlock.com/cityneversleeps) inspected for current overall art context.

## Translation into this game (our implementation decisions)

Muzzle: two crossed bore-aligned cards, animated distortion, hard heat bands, hot ivory center and orange edge. Short flash, then expanding, eroding smoke. Keep the effect at the actual muzzle using the viewmodel's FOV/depth projection.

Magic: flowing torn crescents, noise erosion, layered opacity and a bright inner edge; glass keeps near-black faces and sharply banded cyan highlights. Copal uses irregular smoke silhouettes with three light bands, rather than little solid balls or complete loops. Schools retain their existing meanings and palettes.

Shader clock/age are supplied by gameplay delta for repeatable capture. Temporary effects remain bounded and scene-owned. No downloaded art or reference imagery is used as a runtime texture.

Visual review must cover both initial flash and smoke breakup, charge and release, in the lit capture stage and the actual dark range. Passing gameplay checks alone does not establish visual quality.
