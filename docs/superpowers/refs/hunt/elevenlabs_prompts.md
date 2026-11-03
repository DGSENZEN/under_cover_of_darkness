# ElevenLabs prompts: monsters and abilities

For the Sound Effects generator. Everything is written to be generated **dry** (no room, no echo), because the game adds its own reverb and occlusion. Generate each 3 or 4 times and keep the best two or three as variations, so repeats don't sound identical. Durations are starting points.

Suffix for every prompt, if a take comes back with music, voice or room: `, isolated one-shot sound effect, dry, close-mic, no music, no speech, no reverb`

Name each file as in the **File** column. Tell me where they are and I'll trim, level and wire them in through `tools/prepare_sfx.py`, and credit them.

## The sound of each thing, in a line

- **Ánimas:** dry, hungry, papery. Old skin, cracking knuckles, breath with no lungs behind it. Never a roar.
- **The evil eye:** wet, soft and intimate, too close. Gristle and slick membrane. Its worst form is the same thing torn open.
- **Obsidian (Burst, Shard):** glass and stone, with a low violet hum under it. Heavy and sharp, never sparkly.
- **Copal (Ward, rounds):** resin, breath, embers, a soft holy hiss.
- **The burn:** a low, dirty fire with something drying out inside it.

## Ánimas

| File | Length | Prompt |
|---|---|---|
| `anima_swipe` | 0.5 s | A fast dry rake of long bony fingers tearing through the air, papery skin and clicking knuckles, a short sharp whoosh with a rasp at the end |
| `anima_rake_hit` | 0.5 s | Long dry fingernails raking hard across a leather coat and into flesh, a quick ripping scratch with a wet catch at the end |
| `anima_swipe_windup` | 0.4 s | Withered knuckles cracking in sequence as a dry hand draws back, tendons creaking, a thin hungry intake of breath |
| `anima_jaw_snap` | 0.3 s | A dried human jaw snapping shut, old teeth clacking hard together, hollow bone resonance, bites on nothing |
| `anima_leap` | 0.7 s | A starving, breathless hiss rising to a thin dry shriek as something withered lunges through the air, rushing cloth-like skin |
| `anima_latch` | 0.5 s | Dry fingers clamping tight onto a shoulder, a sudden grip of leather and bone, a short gasp of air pulled through a dry throat |
| `anima_drink_loop` | 4 s, looping | A slow rasping suck through a dry throat, papery wet swallowing, quiet and intimate, close to the ear, a rhythm of pulling and gulping |
| `anima_gulp` | 0.7 s | One deep thick swallow through a withered throat with a low body-felt pulse under it, like life being pulled out of someone |
| `anima_crawl` | 1.5 s, looping | Long bony fingers tapping and dragging quickly across stone, nails clicking, dry skin scraping, an insect-like scuttle |
| `anima_rest_twitch` | 0.6 s | A single dry finger twitching and tapping on stone, a faint knuckle click, then nothing |
| `anima_hunger` | 1.5 s | A ghostly moan from a throat with no breath left, cracked and hollow and pleading, more air than voice, unsettling and sad |
| `anima_wake` | 0.8 s | A sudden dry gasp and a jaw creaking open, bones clicking as something dead snaps awake |
| `anima_thrown` | 0.6 s | A brittle body hitting stone and skidding, bones rattling, dry skin scraping, a hollow clatter |

## Ánima deaths

| File | Length | Prompt |
|---|---|---|
| `anima_death_scream` | 1.5 s | A silent-film scream with no lungs behind it, a thin airless shriek through a dried throat, cracking apart as low fire catches in it |
| `anima_death_moan` | 1.5 s | A long tired exhale from an ancient dry throat, falling in pitch, almost relieved, ending in nothing |
| `anima_ignite` | 1 s | A low dirty fire catching on old dry parchment and bone, a soft hungry whump and then crackling |
| `anima_burn_loop` | 3 s, looping | Dry skin and old paper burning steadily, small crackles, soft flame flutter, sinew popping, quiet and close |
| `anima_ash_crumble` | 1.2 s | A burnt brittle shape collapsing into ash, soft powdery crumbling, charred fragments sliding and pattering onto stone |

## The evil eye

| File | Length | Prompt |
|---|---|---|
| `eye_tell` | 0.5 s | A wet eyelid peeling wide open, slick membrane stretching, a tiny wet click as the pupil snaps open, unnervingly close |
| `eye_swoop` | 0.8 s | Something soft and heavy rushing past through the air, a wet flapping whoosh with a trailing thread of gristle |
| `eye_bite` | 0.4 s | A sudden soft wet impact and a sharp nip, slick flesh slapping against skin |
| `eye_float_loop` | 3 s, looping | A faint wet pulsing and quiet slick muscle moving, a soft heartbeat-like throb, close and intimate |
| `eye_stare_loop` | 3 s, looping | A thin pressure in the ears, a very low unsettling hum with a slow wet pulse, the feeling of being watched |
| `eye_hurt` | 0.5 s | A soft wet squelch and a thin high squeal from something with no mouth, slick and pained |
| `eye_burst` | 0.8 s | A large eyeball bursting, a thick wet pop, fluid spattering across stone, gristle slapping down |
| `eye_remains_land` | 0.4 s | A wet lump of meat slapping onto a stone floor and settling |

## The eye turning worse

| File | Length | Prompt |
|---|---|---|
| `eye_turn_tear` | 1.5 s | Wet flesh tearing wide open, membrane ripping, gristle stretching and snapping, a thick wet burst, then a rising gurgling shriek from no mouth |
| `eye_turned_loop` | 3 s, looping | A torn living thing weeping as it hangs in the air, constant wet dripping and slick gurgling, gristle shifting, a raw throb |
| `eye_spit_windup` | 0.6 s | A wet swelling gurgle rising fast, thick liquid gathering in a torn throat, slick flesh tensing |
| `eye_spit` | 0.4 s | A thick wet hork, a gob of something heavy forced out of raw flesh with a spatter |
| `eye_gob_flight` | 1 s, looping | A wet blob wobbling through the air, a low slimy flutter with faint whispers of hissing |
| `eye_gob_hit` | 0.6 s | A thick wet splat against a person, then a sour hissing fizz, as something sinks into skin |
| `eye_gob_wall` | 0.5 s | A thick wet splat against stone, with a spatter and a slow hissing drip |

## The curse and the egg

| File | Length | Prompt |
|---|---|---|
| `curse_settle` | 1 s | A cold dread settling on the skin, a soft wet opening sound under a low dark swell, close to the ear |
| `curse_eye_opens` | 0.6 s | A wet eyelid splitting open in living flesh, a tiny tearing of skin and a slick blink |
| `curse_lifts` | 1 s | A heavy held breath released, a dark pressure draining away upward, a soft fading exhale |
| `egg_draw_in` | 1.5 s | Something thin and wet being pulled quickly through air into a small shell, a rising inward suction, with whispered hissing |
| `egg_ribbon_lands` | 0.3 s | A small wet thread snapping into a fragile eggshell, a soft tap and a sizzle |
| `egg_crack` | 0.7 s | A chicken egg cracking sharply in the hand, a sour hiss escaping, a small clean sting of ringing air |

## The Burst

| File | Length | Prompt |
|---|---|---|
| `burst_windup` | 0.4 s | Stone floor beginning to crack under great pressure, hairline splitting, a low glassy groan rising, a violet-feeling hum |
| `burst_slam` | 0.8 s | A hand slamming down on stone with enormous force, a deep sub-heavy impact, the ground cracks, a low shockwave thump |
| `burst_tear` | 1.2 s | A wave of huge obsidian glass spikes tearing up through a stone floor, stone ripping apart, heavy crystalline grinding and shrieking glass racing away into the distance |
| `burst_spike` | 0.3 s | A single thick glass spike punching up through stone, a sharp crunch and a short ringing edge |
| `burst_hit` | 0.4 s | Thick black glass driving up through a body, a wet crunch and a short glass ring |
| `burst_collapse` | 1.5 s | Many large glass spikes cracking and collapsing one after another, heavy shards sliding and shattering on stone, settling into rubble |
| `burst_rubble` | 0.5 s | Chunks of dark volcanic glass clattering down on stone, a heavy brittle tinkle |

## The Shard

| File | Length | Prompt |
|---|---|---|
| `shard_form` | 0.5 s | A dark glass splinter growing in the air, a thin rising crystalline creak with a low hum |
| `shard_loose` | 0.5 s | A heavy glass spear thrown extremely fast, a tight sharp whoosh with a rising crystalline ring |
| `shard_fly_loop` | 1 s, looping | A thin high hiss of black glass cutting through the air, spinning with a slight wobble |
| `shard_through` | 0.4 s | A glass spear punching clean through a body, a tight wet crunch and a short bright ring passing out of the other side |
| `shard_wall` | 0.6 s | A heavy glass spear bursting against stone, a sharp shattering crack with shards spraying out into a star |
| `shard_crumble` | 0.8 s | Small black glass spikes crumbling and falling away from a wall, brittle little tinkles |

## The other spells

| File | Length | Prompt |
|---|---|---|
| `ward_pour` | 1.2 s | Thick resin smoke pouring out of a hand and running across a floor, a soft breathy rush with tiny ember crackles |
| `ward_rise_loop` | 3 s, looping | A slow wall of sacred incense smoke turning in place, a soft hushed hiss, tiny embers ticking, a calm low hum |
| `ward_stop` | 0.5 s | Something fast being stopped dead by a wall of smoke, a soft dull puncture with a ripple and a hiss |
| `ward_fall` | 1.2 s | Smoke sinking and draining away across stone, a long fading breath, embers going out |
| `blink_rush` | 0.4 s | A body jumping through space in an instant, air sucked in hard then snapping shut, a sharp vacuum pop |
| `blink_crack` | 0.5 s | A sheet of glass cracking in the air behind you and falling, thin splintering and a fading shimmer |
| `empower_read` | 1.2 s | Old pages turning fast by themselves, a low growl rising under them, a slow heavy heartbeat |
| `empower_change` | 0.8 s | Knuckles cracking and hair and skin stretching over a hand changing into a beast's, a deep animal grunt of effort |
| `empower_rake` | 0.5 s | A huge clawed hand raking through the air and flesh, four heavy tearing strokes at once |

## The rounds and the hits

| File | Length | Prompt |
|---|---|---|
| `hit_weak` | 0.3 s | A satisfying hit in exactly the right place, a sharp bright crack with a meaty thump and a high sting |
| `hit_resisted` | 0.3 s | A bullet passing uselessly through something, a dull hollow puff with almost no impact |
| `copal_round_hit` | 0.6 s | A resin bullet bursting into hot sacred smoke, a soft bright pop and a wide hissing bloom |
| `copal_line_lay` | 1 s | Hot resin poured in a line across a stone floor, sizzling as it lands, thin smoke rising |

## The Exsecrator's deaths

| File | Length | Prompt |
|---|---|---|
| `death_last_gulp` | 1 s | One long deep swallow through a withered throat, slowing down, with a low body-felt pull, the last of something being taken |
| `death_heart_stops` | 3 s | A human heartbeat heard from inside the chest, racing faster and faster, then two weak beats, then nothing |
| `death_eye_tears_open` | 0.8 s | Living wet flesh tearing open slowly right against the ear, membrane stretching and parting, a slick wet click at the end |
| `death_flesh_slack` | 1.2 s | A heavy mass of wet flesh going limp and sagging, slow slick sliding, a last settling, quiet and close |
| `death_candle_lit` | 1.5 s | In total silence, a single match struck and a small candle wick catching, very quiet and very close, a soft flutter of flame |
| `death_breath_out` | 1.5 s | A man's long last breath out, weak and rattling, fading to nothing, no voice |

## The mouth

| Name | Length | Prompt |
|---|---|---|
| `mouth_drag_loop` | 1 s | Fingers driven into packed earth and a great wet weight hauled forward a little way, heavy, slow, close |
| `mouth_ribs_open` | 1.2 s | A huge old ribcage slowly creaking open, dry bone and stretching wet sinew, heavy and close, no voice |
| `mouth_snap` | 0.5 s | A huge ribcage snapping shut, bone on bone, wet, sudden |
| `mouth_close_on_you` | 1 s | Huge bones closing around the listener, wet flesh pressing in on all sides, many faint breaths, very close |
| `mouth_ribs_crack` | 0.6 s | Thick old ribs breaking under a blow, sharp dry crack, then a wet give |
| `mouth_burst` | 1.5 s | A huge rotten ribcage bursting open from inside, bone fragments and wet flesh flying, dry and wet at once |
| `mouth_seize` | 0.5 s | A long wet limb lashing out and snapping shut on something, a wet grip, a stifled airy gasp, no words |
| `mouth_takes_in` | 1.5 s | Something thrashing being dragged wetly into thick flesh, swallowed, skin closing over it, many faint airy moans under it, no words |
| `mouth_full` | 2 s | Many starved airy voices rising together inside one huge body, low, then held, no words, not human speech |

## If a take is wrong

- **Too clean or synthetic:** add `organic, physical, recorded foley`.
- **Too big and cinematic:** add `small, close, intimate, no bass drop, no riser`.
- **Too long a tail:** add `tight, cuts off quickly`.
- **Comes back as a voice or words:** swap "scream" or "moan" for `airy vocal texture, no words, not human speech`.

## The revenant

| Name | Length | Prompt |
|---|---|---|
| `revenant_step` | 0.8 s | Very heavy wet bare foot coming down on old stone, slow drag at the end, recorded foley, dry room |
| `revenant_hand` | 0.6 s | Huge wet knuckles and a palm slapping down on stone, recorded foley, close |
| `revenant_surge` | 1.2 s | A big wet body scrabbling suddenly on hands and feet over stone, galloping, recorded foley |
| `revenant_breath` | 3 s | Slow wet breath with water in the throat, airy vocal texture, no words, not human speech |
| `revenant_gape` | 1 s | A jaw hinge cracking open too far, wet cartilage, close, recorded foley |
| `revenant_bite` | 0.4 s | Big teeth snapping shut hard on nothing, close, tight, cuts off quickly |
| `revenant_grasp` | 0.5 s | Long wet fingers closing fast round something, cold grip, recorded foley |
| `revenant_slam` | 1 s | A very heavy wet body coming down on a stone floor, low thud felt more than heard, small, no bass drop |
| `revenant_fall` | 1.2 s | A huge wet body collapsing on stone, bones knocking, recorded foley |
| `revenant_rise` | 2 s | Something very heavy hauling itself up off stone, water running off it, a low strained breath, no words |
| `revenant_burn` | 2 s | Wet flesh catching fire and spitting, recorded foley, no music |
