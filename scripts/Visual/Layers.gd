extends RefCounted
## The render layers the game draws on. Cameras, lights and decals pick what
## they see and touch with these, so effects can never leak into gameplay:
## the lightgem's cameras do not see particles, effect lights do not light the
## lightgem's probe, and blood on the floor does not paint the guards.
##
##   layers 1-16   the world: level geometry and props (layer 2: what stands
##                 under a roof, ROOFED; layer 3: the ground, GROUND;
##                 layer 4: what the god's breath moves, BREATHED;
##                 layer 16: the parts of light
##                 fixtures that glow from inside, which their own burners do
##                 not light: GLOWING)
##   layer 17      actors: guards and their bodies (wounds paint only these)
##   layer 18      effects: particles, blade trails, glints
##   layer 19      your hands (drawn over everything)
##   layer 20      the lightgem's probe

const WORLD := 1
## Everything a stain on the floor or a wall may paint: layers 1 to 16.
const WORLD_ALL := (1 << 16) - 1
## Level pieces that only ever stand under a roof (the level's "roofed"):
## drawn and lit as the world, but the moon, which could never reach them,
## leaves them out of its shadow pass (its shadow_caster_mask).
const ROOFED := 1 << 1
## The ground (layer 3): what drifting petals and leaves settle on; the
## particles' heightfield sees only this (a tree's crown would catch them).
const GROUND := 1 << 2
## What the caged god's breath draws in and pushes out (layer 4): copal,
## dust, petals (their particles also draw on it; the breath's attractor
## moves only these). Effects all the same: the lightgem's cameras leave
## it out (Player.tscn).
const BREATHED := 1 << 3
## What a shaded lamp's shade keeps its light off (layer 5): the Metro corridor's vault above its work lamps, which
## leave this layer out of their cull mask (lit by them, the vault showed a bright disc, a moon in a night sky).
const SHADED_ABOVE := 1 << 4
## What a colour spill close under it leaves unlit (layer 6): the candle lane's blank station sign, which the Pasaje's
## teal neon a metre below washed into the brightest thing seen from the mouth.
const SPILL_SHY := 1 << 5
## A fixture's glowing parts (a pitch head, coals, horn panes): they shine by
## their own glow, and a burner's light (a hand's breadth away) would blow
## them out, so burners leave this layer unlit.
const GLOWING := 1 << 15
const ACTORS := 1 << 16
const FX := 1 << 17
const VIEWMODEL := 1 << 18
const GEM_PROBE := 1 << 19

## What an effect draws on: FX unless it was put elsewhere (on BREATHED
## alone, smoke the breath moves but the wind's attractor must not).
static func effect(visual: VisualInstance3D) -> void:
	if visual.layers == WORLD:
		visual.layers = FX


## Every layer but the lightgem's probe: what an effect light may touch.
const ALL_BUT_PROBE := ((1 << 20) - 1) & ~GEM_PROBE
