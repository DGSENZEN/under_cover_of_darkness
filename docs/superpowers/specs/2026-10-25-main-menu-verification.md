# Main menu and Metro transition verification

Normal startup opens the painted menu. New Game now targets `maps/metro.tscn`,
imported from `metro-standard`, rather than the separate surface Zócalo map.
Existing shared gameplay files were preserved; required Metro interfaces were
added to Sfx, Layers, Painterly and Vfx. Missing glyph metadata, dialogue and
content resources accompany the map.

The native Forward+ run `/private/tmp/menu-metro-verified.log` records nine
passing checks: moving background pixels; mouse Settings; Escape/focus;
arrows; Enter/Lore; the artwork loading cover; the Metro/player; the completed
candle lane and Library effects; and removal of the cover with gameplay resumed.
Captures are `/private/tmp/main-menu-idle.png`, `main-menu-hover.png`,
`main-menu-loading.png` and `main-menu-metro.png`.

Targeted suites: menu 16 passes, loading 5, sound 19, painterly materials 6.
All have zero failed checks. Painterly's old three-preset assumption was updated
for the required Metro bespoke preset. Source whitespace checks pass. Independent
review's three initial findings (missing sound interfaces, premature readiness,
and weak destination assertions) were corrected and re-reviewed successfully.

The final native run has no script or shader errors. It prints an ObjectDB
instances warning at process exit; this does not occur during the transition.
The full repository suite was not rerun for this menu/content integration.

## Dialogue restoration and candle-lane spawn

Restored the metro-standard conversation UI, player interaction hooks,
PeopleState, job/letter integration and dialogue item looks. Existing painted
skins remain in use. PlayerController changes are limited to conversation
holding, input suppression, damage/death interruption and inventory lifecycle.
An independent reviewer found no actionable integration issue.

The actual Metro now starts at (7.8, -11, 75.35), in the candle lane's clear
walk, facing the curandera. Native verification in
`/private/tmp/metro-dialogue-native.log` records 13 passes, including the nearby
spawn, the real raycast Talk prompt across her counter, E opening the painted
TalkBox, and control returning after interruption. The original dialogue suite
records 74 passes; the shipped quest suite records nine, including walking to
both NPCs and opening their painted boxes. Existing job, interaction and menu
regression checks also pass.
