# Main menu

Normal project startup opens `main_menu.tscn`. Its CanvasLayer is above the
world's retro postprocess, preserving the supplied painted artwork. The city
uses aspect-cover sizing. Controls scale together inside a centered 1600×900
design area, so they remain visible at different window aspect ratios.

The transparent `assets/ui/main_menu/buttons.png` atlas holds four independent
buttons in reading order: New Game, Continue, Settings and Lore. White exterior
background removal used the image generation tool; the original city painting
is copied without edits. Each button owns its ShaderMaterial, hover state,
click pulse and music energy. Keyboard focus uses the same visual treatment
as hover. The shader samples only that button's atlas region and uses its
transparent gutters for a growing pigment border. The quad extends beyond
the button's layout bounds so wet paint can spill outward without clipping.
`paint_flow.tres` supplies seamless noise normals as a flow map. Two overlapping
advection phases move the paint continuously, hiding each phase's reset. New
Game drags warm pigment, Continue uses cold upward washes, Settings combs cobalt
strokes, and Lore curls copper and crimson. Source-colored daubs, pigment-ridge
sheen and cursor response replace a scanning light outline. `living_paint`
applies the same flow to the city's sky and reflections, with much smaller
displacement around the architectural horizon.

The main screen shows only the two-line game title and the four painted
actions. There are no subtitles, footnotes, navigation hints or tooltips.
New Game resets CityState and opens `maps/metro.tscn`, the actual Metro
Underground, including the built candle lane and library. This content was
brought from the `metro-standard` worktree at `fc81e985`, with its then-current
Animas edits. Only missing content files were copied; existing shared APIs
received the required additive audio, lighting and smoke support. The surface
district `maps/zocalo.tscn` is a separate map.
Continue currently opens an explicit unavailable explanation: CityState keeps
district state between scenes, but there is no disk-save loader in this build.
Settings persists master volume and the existing guard-awareness preference in
`user://settings.cfg`; the master gain applies through to gameplay. Lore draws
its short introduction from the existing Eclipse and Zócalo design records.
Escape/Back closes overlays and restores focus to the selected painting.

`ArtLoadingScreen` is a transient root-owned CanvasLayer above both scenes. It
shows the user's `loading.png`, a bar and a drawn rotating circle, without text.
It polls `ResourceLoader.load_threaded_get_status` before retrieving the packed
scene. Scene resource progress covers the first half; the Metro's runtime build
yields through `stage(owner, fraction)` for the rest. Gameplay remains paused
under the cover. The Metro sets `loading_complete` only after its candle lane
and library finish; reported errors or a 60-second runtime-build timeout restore
the previous scene. Once ready, the bar completes and the cover fades out.

The paint-motion references are RoughSkin's [hand-painted animation](https://godotshaders.com/shader/wobbly-effect-hand-painted-animation/)
and Catlike Coding's [two-phase texture flow](https://catlikecoding.com/unity/tutorials/flow/texture-distortion/).
Background loading follows [Godot's ResourceLoader guidance](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

The menu does not play the combat score. When the distinct menu theme is ready,
its authored section/part events can call
`music_marker(marker: StringName, strength := 1.0)` on the active menu. Valid
markers are `new_game`, `continue`, `settings` and `lore`; strength clamps to
0–1 and decays. No elapsed-time approximation is treated as a music event.

`tests/main_menu_test.tscn` checks navigation, state isolation, settings and music
marker routing headlessly. `tests/visual/main_menu_preview.gd` runs with a native
renderer, captures idle/hover/click/overlays/resizing to `/private/tmp`, and then
activates New Game to verify the actual scene transition, loading cover,
completed candle lane/library and unpause. It also samples rendered sky pixels
over time to verify background movement. `tests/art_loading_test.tscn` checks the
art, text-free indicators, monotonic progress and spinner clock.

The Metro currently spawns in the clear walk five metres west of the candle
lane stall, facing the curandera. The restored PlayerFrob/TalkBox integration
opens conversations with E; CityState.people holds conversation flags, moods,
goals and notes. Talk holds movement/look and suppresses combat while the world
continues. Damage or leaving the scene interrupts it. Existing painted
curandera/librarian skins are preserved.
