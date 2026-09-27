extends RefCounted
## The render layers the game draws on. Cameras, lights and decals pick what
## they see and touch with these, so effects can never leak into gameplay:
## the lightgem's cameras do not see particles, effect lights do not light the
## lightgem's probe, and blood on the floor does not paint the guards.
##
##   layers 1-16   the world: level geometry and props (layer 16: the parts
##                 of light fixtures that glow from inside, which their own
##                 burners do not light: GLOWING)
##   layer 17      actors: guards and their bodies (wounds paint only these)
##   layer 18      effects: particles, blade trails, glints
##   layer 19      your hands (drawn over everything)
##   layer 20      the lightgem's probe

const WORLD := 1
## Everything a stain on the floor or a wall may paint: layers 1 to 16.
const WORLD_ALL := (1 << 16) - 1
## A fixture's glowing parts (a pitch head, coals, horn panes): they shine by
## their own glow, and a burner's light (a hand's breadth away) would blow
## them out, so burners leave this layer unlit.
const GLOWING := 1 << 15
const ACTORS := 1 << 16
const FX := 1 << 17
const VIEWMODEL := 1 << 18
const GEM_PROBE := 1 << 19

## Every layer but the lightgem's probe: what an effect light may touch.
const ALL_BUT_PROBE := ((1 << 20) - 1) & ~GEM_PROBE
