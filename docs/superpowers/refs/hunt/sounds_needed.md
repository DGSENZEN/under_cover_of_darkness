# Sounds the hunts need

Stand-ins from the existing library until the user chooses real ones.

| Sound | Where | Today |
|---|---|---|
| A weak hit: the right answer landing | `Revolver.SOUNDS hit_weak` | `ting` high |
| A resisted hit: it barely told | `Revolver.SOUNDS hit_resisted` | `thud` low, quiet |
| The eye's tell | `FloatingEye.gd` | None yet |
| The eye's swoop, bite | `FloatingEye.gd` | `whoosh_light`, `thud` |
| The eye bursting (the wet pop) | `FloatingEye._die` | `flesh_heavy` + `coal_pop` |
| Its remains landing | `Remains.gd` | `flesh` |
| A copal cloud bursting and hanging | `CopalCloud.gd` | `whoosh_light` |
| A slide's scrape | `PlayerController._update_slide` | `cloth`, repeated |
| The evil eye settling on you, and lifting | `PlayerController._feel_statuses` | None yet |
| The egg drawing the curse in, rising | `Loadout.use_item` | `whoosh_heavy` low |
| A ribbon of the curse landing in the egg | `Loadout._land_ribbons` | `flesh` quiet, rising pitch |
| The egg's release: the crack and sting of a dispel | `Loadout._release` | `ting` + `bone_crack` |

## Ravenous ánimas

| Sound | Where | Stand-in |
|---|---|---|
| A rasping drink, while one is on you | `LifeLeech._physics_process` | `anima_moan`, pitched down |
| The Burst: glass tearing up through stone | `ObsidianBurst._go` | `thud` + `whoosh_heavy` + `ting` |
| The Burst's spikes falling to pieces | `BurstWave._break` | `ting`, low |
| An ánima's swing and cut (`anima_swipe`, `anima_rake_hit`) | `Anima._cut` | `whoosh_light` + `flesh` |
| An ánima's wind-up (`anima_swipe_windup`) | `Anima._wish` | `anima_voice`, high and quiet |

## The mouth

| Sound | Where | Stand-in |
|---|---|---|
| Each haul: a hand into the earth, all of it dragged on (`mouth_drag_loop`) | `Anima._pace` | `flesh`, low |
| Its ribs opening, gathering or drawing back (`mouth_ribs_open`) | `Anima._sounds_for` | `bone_crack` + `flesh`, low |
| Its ribs and arms coming over (`mouth_snap`) | `Anima._sounds_for` | `flesh` + `bone_crack` |
| It closes on you (`mouth_close_on_you`) | `Anima._sounds_for` | `flesh_heavy` + `anima_moan`, low |
| The first whip breaks its ribs (`mouth_ribs_crack`) | `Anima._on_struck` | `bone_crack` |
| It dies: its ribs burst (`mouth_burst`) | `AnimaMouth.tick_dying` | `bone_crack`, `flesh`, low |
| The elite seizes one (`mouth_seize`) | `Anima._sounds_for` | `whoosh_light` + `flesh` |
| It takes one in (`mouth_takes_in`) | `Anima.take_in` | `flesh_heavy`, low |
| It has all it can hold (`mouth_full`) | `Anima.take_in` | `anima_moan`, very low |

## The turned eye

| Sound | Where | Stand-in |
|---|---|---|
| Tearing open (`eye_turn_tear`) | `FloatingEye.turn` | `flesh_heavy` + `bone_crack`, low |
| The spit (`eye_spit`) | `EyeGob._launch` | `flesh`, low |
| A gob on you, and on a wall (`eye_gob_hit`, `eye_gob_wall`) | `EyeGob._burst` | `flesh_heavy` |

## The Exsecrator's deaths

| Sound | Where | Stand-in |
|---|---|---|
| The last long gulp (`death_last_gulp`) | `PlayerDeath._sound` | `flesh_heavy`, `anima_moan`, low |
| The heart racing, and stopping (`death_heart_stops`) | `PlayerDeath._sound` | `heartbeat` |
| The last eye tearing open (`death_eye_tears_open`) | `PlayerDeath._sound` | `flesh_heavy`, low |
| The flesh going slack (`death_flesh_slack`) | not yet played | |
| The last breath out (`death_breath_out`) | not yet played | |
| A match, a candle catching, very quiet (`death_candle_lit`) | `DeathQuote.after` | `ignite`, quiet |

